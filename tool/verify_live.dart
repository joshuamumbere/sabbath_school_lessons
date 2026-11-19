import 'package:http/http.dart' as http;
import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';

/// Live verification of the zero-API architecture against the real fork.
Future<void> main() async {
  final requests = <Uri>[];
  final tracked = _TrackingClient(requests);
  final c = SabbathSchoolClient(httpClient: tracked);

  // 1. Languages: should be one raw fetch of index/languages.json (no API).
  final languages = await c.listLanguages();
  print('languages: ${languages.length}, requests so far: ${requests.length} '
      '(api: ${tracked.apiRequests})');

  // 2. Quarters + all lesson titles: one more raw fetch of index/en.json.
  final quarters = await c.listQuarterIds('en');
  final lessons = await c.quarterLessons('en', '2026-01');
  print('en quarters: ${quarters.length}, lessons in 2026-01: ${lessons.length}, '
      'requests so far: ${requests.length} (api: ${tracked.apiRequests})');
  print('lesson 1: ${lessons.first.title}');

  // 3. Repeat reads: must be fully cached, zero new requests.
  await c.listLanguages();
  await c.quarter('en', '2026-01');
  final before = requests.length;
  await c.quarterLessons('en', '2026-01');
  print('cached re-reads added requests: ${requests.length - before}');

  // 4. Day content + audio still work.
  final day = await c.day('en', '2026-01', 1, 1);
  final audio = await c.audio('en', '2026-01', lesson: 1);
  print('day 1 of lesson 1: ${day.title}; audio for lesson 1: ${audio.length}');

  c.close();
}

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.requests);

  final List<Uri> requests;
  final http.Client _inner = http.Client();
  var apiRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    if (request.url.host == 'api.github.com') apiRequests++;
    return _inner.send(request);
  }
}
