import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';
import 'package:test/test.dart';

void main() {
  test('listLanguages returns sorted dirs from Contents API', () async {
    final client = _client();

    final languages = await client.listLanguages();

    expect(languages, ['af', 'bg', 'en', 'pt']);
    client.close();
  });

  test('quarter parses info.yml from raw URL', () async {
    final client = _client();

    final quarter = await client.quarter('en', '2026-01');

    expect(quarter.id, '2026-01');
    expect(quarter.title, 'Uniting Heaven and Earth');
    expect(quarter.startDate, DateTime(2025, 12, 27));
    client.close();
  });

  test('quarterLessons fetches each lesson info.yml', () async {
    final client = _client();

    final lessons = await client.quarterLessons('en', '2026-01');

    expect(lessons, hasLength(2));
    expect(lessons.map((l) => l.number), [1, 2]);
    expect(lessons.first.title, 'Lesson 01 title');
    client.close();
  });

  test('quarterLessons respects limit', () async {
    final client = _client();

    final lessons = await client.quarterLessons('en', '2026-01', limit: 1);

    expect(lessons, hasLength(1));
    client.close();
  });

  test('day parses markdown front matter', () async {
    final client = _client();

    final day = await client.day('en', '2026-01', 1, 1);

    expect(day.title, 'Persecuted but Not Forsaken');
    expect(day.date, DateTime(2025, 12, 27));
    expect(day.markdown, contains('Memory Text'));
    client.close();
  });

  test('feature returns null for missing files and text when present', () async {
    final client = _client();

    expect(await client.feature('en', '2026-01', 1, 'teacher-comments'), 'Teacher comments.');
    expect(await client.feature('en', '2026-01', 1, 'missing'), isNull);
    client.close();
  });

  test('audio filters by lesson target', () async {
    final client = _client();

    final all = await client.audio('en', '2026-01');
    final lesson1 = await client.audio('en', '2026-01', lesson: 1);

    expect(all, hasLength(3));
    expect(lesson1, hasLength(2));
    expect(lesson1.every((i) => i.target == 'en/2026-01/01'), isTrue);
    client.close();
  });

  test('language resolves name', () async {
    final client = _client();

    final language = await client.language('en');

    expect(language?.name, 'English');
    client.close();
  });

  test('throws SabbathSchoolApiException on 404', () async {
    final client = _client();

    await expectLater(client.quarter('en', '9999-99'),
        throwsA(isA<SabbathSchoolApiException>().having((e) => e.statusCode, 'statusCode', 404)));
    client.close();
  });
}

/// Builds a client against a fake transport serving realistic fixtures.
SabbathSchoolClient _client() => SabbathSchoolClient(
      owner: 'o',
      repo: 'r',
      branch: 'main',
      httpClient: _FakeClient(),
    );

class _FakeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();

    // Contents API directory listings.
    if (url.contains('api.github.com/repos/o/r/contents/src?ref=main')) {
      return _json([
        {'type': 'dir', 'name': 'en'},
        {'type': 'dir', 'name': 'pt'},
        {'type': 'dir', 'name': 'bg'},
        {'type': 'dir', 'name': 'af'},
      ]);
    }
    if (url.contains('contents/src/en?ref=main')) {
      return _json([
        {'type': 'dir', 'name': '2026-01'},
        {'type': 'file', 'name': 'info.yml'},
      ]);
    }
    if (url.contains('contents/src/en/2026-01?ref=main')) {
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

http.StreamedResponse _json(Object? body) => _text(jsonEncode(body),
    headers: {'content-type': 'application/json'});

http.StreamedResponse _text(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: headers,
    );

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
        - src: https://example.com/audio/1b.mp3
          target: en/2026-01/01
        - src: https://example.com/audio/2.mp3
          target: en/2026-01/02
''';
