/// A Dart/Flutter client for the sabbath-school-lessons content repository.
///
/// The repository publishes quarterly Sabbath School lessons for many
/// languages. This package fetches that content over GitHub and exposes it
/// as typed models: quarters, lessons, daily readings, and audio/PDF/video
/// manifests.
///
/// ```dart
/// import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';
///
/// final client = SabbathSchoolClient();
/// final quarter = await client.quarter('en', '2026-01');
/// final day = await client.day('en', '2026-01', 1, 1);
/// ```
library;

export 'src/client.dart';
export 'src/models.dart';
export 'src/parsers.dart' show parseDate, parseDayMarkdown, parseLesson, parseMedia, parseQuarter;
export 'src/sabbath_school_lessons_base.dart';
