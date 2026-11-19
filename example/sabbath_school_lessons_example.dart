import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';

Future<void> main() async {
  final client = SabbathSchoolClient();

  // 1. List available languages.
  final languages = await client.listLanguages();
  print('Languages (${languages.length}): ${languages.take(5).join(', ')} ...');

  // 2. List quarters for a language and pick the most recent main quarterly.
  //    Variant quarters (e.g. 2026-01-cq, 2026-01-er) have their own layout,
  //    so the example uses the plain `YYYY-NN` folder.
  final quarters = await client.listQuarterIds('en');
  final mainQuarterId =
      quarters.where((q) => RegExp(r'^\d{4}-\d{2}$').hasMatch(q)).last;
  print('English quarters: ${quarters.length} (latest main: $mainQuarterId)');

  // 3. Load the quarter's metadata.
  final quarter = await client.quarter('en', mainQuarterId);
  print('Quarter: ${quarter.title} (${quarter.humanDate})');
  print('Colors: ${quarter.colorPrimary} / ${quarter.colorPrimaryDark}');

  // 4. List lessons and read the first day of lesson 1.
  final lessons = await client.quarterLessons('en', quarter.id);
  print('Lessons: ${lessons.map((l) => '${l.number}. ${l.title}').join(' | ')}');

  final day = await client.day('en', quarter.id, lessons.first.number, 1);
  print('Day 1 of lesson 1: ${day.title} (${day.date})');
  print(day.markdown.substring(0, 120));

  // 5. Media: audio and PDFs for lesson 1.
  final audio = await client.audio('en', quarter.id, lesson: lessons.first.number);
  final pdfs = await client.pdf('en', quarter.id, lesson: lessons.first.number);
  print('Audio tracks for lesson 1: ${audio.length}');
  print('PDFs for lesson 1: ${pdfs.map((p) => p.title ?? p.src).join(', ')}');

  client.close();
}
