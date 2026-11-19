import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';

Future<void> main() async {
  final client = SabbathSchoolClient(owner: 'joshuamumbere', repo: 'sabbath-school-lessons', branch: 'stage');
  final all = await client.audio('en', '2026-04');
  print('all audio for quarter: ${all.length}');
  for (final item in all.take(5)) {
    print('${item.artist} -> ${item.target}');
  }
  final filtered = await client.audio('en', '2026-04', lesson: 1);
  print('audio via client.audio(lesson: 1): ${filtered.length}');
  final day1 = await client.audio('en', '2026-04', lesson: 1, day: 1);
  print('audio via client.audio(lesson: 1, day: 1): ${day1.length}');
  client.close();
}
