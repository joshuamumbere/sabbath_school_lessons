import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';
import 'package:test/test.dart';

void main() {
  test('listLanguages reads the committed index with zero API requests', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    final languages = await client.listLanguages();

    expect(languages, ['en', 'pt']);
    expect(fake.apiRequests, 0);
    client.close();
  });

  test('quarter and quarterLessons come from the language index only', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    final quarter = await client.quarter('en', '2026-01');
    final lessons = await client.quarterLessons('en', '2026-01');

    expect(quarter.id, '2026-01');
    expect(quarter.title, 'Uniting Heaven and Earth');
    expect(quarter.startDate, DateTime(2025, 12, 27));
    expect(quarter.lessonNumbers, [1, 2]);
    expect(lessons, hasLength(2));
    expect(lessons.first.title, 'Lesson 1 title');
    // Exactly one request total: the CDN-cached index fetch.
    expect(fake.requests, hasLength(1));
    client.close();
  });

  test('repeated calls within the TTL make no further requests', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    await client.listLanguages();
    final afterFirst = fake.requests.length;
    await client.listQuarterIds('en');
    await client.listQuarterIds('en'); // second served from cache

    expect(fake.requests.length, afterFirst + 1);
    client.close();
  });

  test('expired entries are revalidated with a 304, not re-downloaded', () async {
    final fake = _FakeClient();
    final client = _client(fake, indexTtl: Duration.zero);

    final first = await client.listLanguages();
    final afterFirst = fake.requests.length;
    final second = await client.listLanguages();

    expect(first, second);
    expect(fake.requests.length, greaterThan(afterFirst)); // a revalidation happened
    expect(fake.revalidations304, greaterThan(0)); // and it was answered with 304
    client.close();
  });

  test('falls back to the Contents API when the index is missing', () async {
    final fake = _FakeClient(serveIndex: false);
    final client = _client(fake);

    final languages = await client.listLanguages();
    final lessons = await client.quarterLessons('en', '2026-01');

    expect(languages, ['af', 'bg', 'en', 'pt']);
    expect(lessons.map((l) => l.number), [1, 2]);
    expect(fake.apiRequests, greaterThan(0));
    client.close();
  });

  test('lesson() is served from the index', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    final lesson = await client.lesson('en', '2026-01', 2);

    expect(lesson.number, 2);
    expect(fake.requests, hasLength(1));
    client.close();
  });

  test('day parses markdown front matter', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    final day = await client.day('en', '2026-01', 1, 1);

    expect(day.title, 'Persecuted but Not Forsaken');
    expect(day.date, DateTime(2025, 12, 27));
    expect(day.markdown, contains('Memory Text'));
    client.close();
  });

  test('day content is cached within contentTtl', () async {
    final fake = _FakeClient();
    final client = _client(fake);

    await client.day('en', '2026-01', 1, 1);
    final afterFirst = fake.requests.length;
    await client.day('en', '2026-01', 1, 1);

    expect(fake.requests.length, afterFirst);
    client.close();
  });

  test('feature returns null for missing files and text when present', () async {
    final client = _client(_FakeClient());

    expect(await client.feature('en', '2026-01', 1, 'teacher-comments'), 'Teacher comments.');
    expect(await client.feature('en', '2026-01', 1, 'missing'), isNull);
    client.close();
  });

  test('audio filters by lesson and day, matching both manifest shapes', () async {
    final client = _client(_FakeClient());

    final all = await client.audio('en', '2026-01');
    final lesson1 = await client.audio('en', '2026-01', lesson: 1);
    final lesson1Day1 = await client.audio('en', '2026-01', lesson: 1, day: 1);

    expect(all, hasLength(4));
    expect(lesson1, hasLength(3)); // per-lesson target + per-day targets
    expect(lesson1Day1, hasLength(1));
    expect(lesson1Day1.every((i) => i.target == 'en/2026-01/01/01'), isTrue);
    client.close();
  });

  test('language resolves name from the index', () async {
    final client = _client(_FakeClient());

    final language = await client.language('en');

    expect(language?.name, 'English');
    client.close();
  });

  test('throws SabbathSchoolApiException on 404 for a missing quarter', () async {
    final client = _client(_FakeClient());

    await expectLater(client.quarter('en', '9999-99'),
        throwsA(isA<SabbathSchoolApiException>().having((e) => e.statusCode, 'statusCode', 404)));
    client.close();
  });
}

/// Builds a client against a fake transport serving realistic fixtures.
SabbathSchoolClient _client(
  _FakeClient fake, {
  Duration indexTtl = const Duration(hours: 12),
}) =>
    SabbathSchoolClient(
      owner: 'o',
      repo: 'r',
      branch: 'main',
      indexTtl: indexTtl,
      httpClient: fake,
    );

class _FakeClient extends http.BaseClient {
  _FakeClient({this.serveIndex = true});

  final bool serveIndex;
  final List<Uri> requests = [];
  var apiRequests = 0;
  var revalidations304 = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final url = request.url.toString();
    final conditional = request.headers['If-None-Match'];

    // Any conditional request we know the URL for is answered with 304.
    if (conditional == '"v1"') {
      revalidations304++;
      return http.StreamedResponse(Stream.value(const []), 304);
    }

    // Committed index files.
    if (serveIndex && url.endsWith('/index/languages.json')) return _json(_languagesJson);
    if (serveIndex && url.endsWith('/index/en.json')) return _json(_enIndexJson);

    // Contents API directory listings (fallback path).
    if (url.contains('api.github.com/repos/o/r/contents/src?ref=main')) {
      apiRequests++;
      return _json([
        {'type': 'dir', 'name': 'en'},
        {'type': 'dir', 'name': 'pt'},
        {'type': 'dir', 'name': 'bg'},
        {'type': 'dir', 'name': 'af'},
      ]);
    }
    if (url.contains('contents/src/en?ref=main')) {
      apiRequests++;
      return _json([
        {'type': 'dir', 'name': '2026-01'},
      ]);
    }
    if (url.contains('contents/src/en/2026-01?ref=main')) {
      apiRequests++;
      return _json([
        {'type': 'dir', 'name': '01'},
        {'type': 'dir', 'name': '02'},
      ]);
    }

    // Raw file contents.
    if (url.endsWith('/src/en/2026-01/info.yml')) return _text(_quarterInfoYaml);
    if (RegExp(r'/src/en/2026-01/\d+/info\.yml$').hasMatch(url)) {
      final n = RegExp(r'/(\d+)/info').firstMatch(url)!.group(1)!;
      return _text(_lessonInfoTemplate.replaceAll('@n', n));
    }
    if (url.endsWith('/src/en/2026-01/01/01.md')) return _text(_dayMarkdown);
    if (url.endsWith('/src/en/2026-01/01/teacher-comments.md')) {
      return _text('Teacher comments.');
    }
    if (url.endsWith('/src/en/2026-01/audio.yml')) return _text(_audioYaml);
    if (url.endsWith('/src/en/info.yml')) return _text('name: "English"\ncode: "en"\n');

    return _text('not found', statusCode: 404);
  }
}

http.StreamedResponse _json(Object? body) =>
    _text(body is String ? body : jsonEncode(body),
        headers: {'content-type': 'application/json'});

http.StreamedResponse _text(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {...headers, 'etag': '"v1"'},
    );

const _languagesJson = '''
{"languages": [
  {"code": "en", "name": "English"},
  {"code": "pt", "name": "Português"}
]}
''';

const _enIndexJson = '''
{"code": "en", "quarters": [
  {
    "id": "2026-01",
    "title": "Uniting Heaven and Earth",
    "description": "Think of the hardest job you've ever done.",
    "human_date": "January · February · March 2026",
    "start_date": "27/12/2025",
    "end_date": "27/03/2026",
    "color_primary": "#2E4161",
    "color_primary_dark": "#1E2C44",
    "splash": true,
    "credits": [],
    "lessons": [
      {"number": 1, "title": "Lesson 1 title", "start_date": "27/12/2025", "end_date": "02/01/2026"},
      {"number": 2, "title": "Lesson 2 title", "start_date": "03/01/2026", "end_date": "09/01/2026"}
    ]
  }
]}
''';

const _quarterInfoYaml = '''
  title: "Uniting Heaven and Earth"
  description: "Think of the hardest job you've ever done."
  human_date: "January · February · March 2026"
  start_date: "27/12/2025"
  end_date: "27/03/2026"
  color_primary: "#2E4161"
  color_primary_dark: "#1E2C44"
  splash: true
''';

const _lessonInfoTemplate = '''
title: "Lesson @n title"
start_date: "27/12/2025"
end_date: "02/01/2026"
''';

const _dayMarkdown = '''
---
title:  Persecuted but Not Forsaken
date:  27/12/2025
---

### Read for This Week's Study

> <p>Memory Text:</p>
> "Rejoice in the Lord always."
''';

const _audioYaml = '''
  audio:
    - artist: Adult Bible Study Guides
      tracks:
        - src: https://example.com/audio/1a.mp3
          target: en/2026-01/01
        - src: https://example.com/audio/1d1.mp3
          target: en/2026-01/01/01
        - src: https://example.com/audio/1d2.mp3
          target: en/2026-01/01/02
        - src: https://example.com/audio/2.mp3
          target: en/2026-01/02
''';
