import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import 'models.dart';
import 'parsers.dart';
import 'sabbath_school_lessons_base.dart';

/// Thrown when a GitHub request fails.
class SabbathSchoolApiException implements Exception {
  SabbathSchoolApiException(this.statusCode, this.message);

  /// HTTP status code returned by GitHub.
  final int statusCode;
  final String message;

  @override
  String toString() => 'SabbathSchoolApiException($statusCode): $message';
}

/// Client for the [sabbath-school-lessons](https://github.com/Adventech/sabbath-school-lessons)
/// content repository (or any fork of it).
///
/// Directory listings use the GitHub Contents API; file contents (YAML and
/// markdown) are fetched from raw.githubusercontent.com. All content paths
/// are relative to `src/` in the repository.
///
/// ```dart
/// final client = SabbathSchoolClient(
///   owner: 'joshuamumbere',
///   repo: 'sabbath-school-lessons',
///   branch: 'stage',
/// );
/// final quarter = await client.quarter('en', '2026-01');
/// print(quarter.title);
/// ```
class SabbathSchoolClient {
  /// Creates a client for the given GitHub repository.
  ///
  /// [githubToken] optionally raises the Contents API rate limit from
  /// 60 to 5000 requests per hour.
  SabbathSchoolClient({
    this.owner = defaultOwner,
    this.repo = defaultRepo,
    this.branch = defaultBranch,
    this.githubToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// GitHub owner (user or organization) of the content repository.
  final String owner;

  /// Repository name.
  final String repo;

  /// Branch to read from.
  final String branch;

  /// Optional GitHub personal access token used for API requests.
  final String? githubToken;

  final http.Client _httpClient;

  /// Closes the underlying HTTP client. The client cannot be used afterwards.
  void close() => _httpClient.close();

  // ---------------------------------------------------------------------------
  // Languages
  // ---------------------------------------------------------------------------

  /// Lists language codes present under `src/`, sorted alphabetically.
  Future<List<String>> listLanguages() async {
    final entries = await _listDirs('src');
    return entries.toList()..sort();
  }

  /// Fetches language metadata (name) from `src/<code>/info.yml`.
  /// Returns `null` when the language does not exist.
  Future<Language?> language(String code) async {
    final yaml = await _tryRawYaml(_contentPath('$code/info.yml'));
    if (yaml == null) return null;
    return parseLanguage(code, yaml);
  }

  // ---------------------------------------------------------------------------
  // Quarters
  // ---------------------------------------------------------------------------

  /// Lists quarter folder names for a language, e.g. `2026-01`, sorted.
  Future<List<String>> listQuarterIds(String language) async {
    final entries = await _listDirs('src/$language');
    final quarters = entries.where((e) => RegExp(r'^\d{4}-\d{2}').hasMatch(e)).toList()
      ..sort();
    return quarters;
  }

  /// Loads a quarter's metadata from `src/<language>/<quarterId>/info.yml`.
  ///
  /// Throws [SabbathSchoolApiException] with status 404 when the quarter
  /// does not exist.
  Future<Quarter> quarter(String language, String quarterId) async {
    final yaml = await _rawYaml(_contentPath('$language/$quarterId/info.yml'));
    return parseQuarter(language, quarterId, yaml);
  }

  // ---------------------------------------------------------------------------
  // Lessons and days
  // ---------------------------------------------------------------------------

  /// Loads a single lesson's metadata from its `info.yml`.
  Future<Lesson> lesson(
    String language,
    String quarterId,
    int lessonNumber,
  ) async {
    final yaml = await _rawYaml(_contentPath('$language/$quarterId/${_lessonDir(lessonNumber)}/info.yml'));
    return parseLesson(language, quarterId, lessonNumber, yaml);
  }

  /// Loads all lessons of a quarter (one request per lesson).
  ///
  /// Pass [limit] to fetch only the first N lessons.
  Future<List<Lesson>> quarterLessons(
    String language,
    String quarterId, {
    int? limit,
  }) async {
    final lessonDirs = await _listDirs('src/$language/$quarterId');
    final numbers = lessonDirs
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .where((n) => n >= 1 && n <= 13)
        .toList()
      ..sort();
    final wanted = limit == null ? numbers : numbers.take(limit).toList();
    return [
      for (final n in wanted) await lesson(language, quarterId, n),
    ];
  }

  /// Loads the quarterly introduction (`introduction.md`).
  Future<String> quarterIntroduction(String language, String quarterId) =>
      _rawText(_contentPath('$language/$quarterId/introduction.md'));

  /// Loads one daily reading (`day` is `1..7`).
  Future<DayContent> day(
    String language,
    String quarterId,
    int lessonNumber,
    int day,
  ) async {
    final text =
        await _rawText(_contentPath('$language/$quarterId/${_lessonDir(lessonNumber)}/${_lessonDir(day)}.md'));
    return parseDayMarkdown(language, quarterId, lessonNumber, day, text);
  }

  /// Loads an extra feature file of a lesson, e.g. `teacher-comments`,
  /// `inside-story`, or `hope-ss` (`<name>.md` inside the lesson folder).
  /// Returns `null` when the feature is not present.
  Future<String?> feature(
    String language,
    String quarterId,
    int lessonNumber,
    String featureName,
  ) async {
    return _tryRawText(
      _contentPath('$language/$quarterId/${_lessonDir(lessonNumber)}/$featureName.md'),
    );
  }

  // ---------------------------------------------------------------------------
  // Media manifests
  // ---------------------------------------------------------------------------

  /// Loads audio tracks for a quarter, optionally filtered to one lesson
  /// (and, if [day] is given, to one day of that lesson).
  ///
  /// Some quarters target audio per lesson (`en/2026-01/01`) and newer ones
  /// per day (`en/2026-04/01/01`); both shapes are matched.
  Future<List<MediaItem>> audio(
    String language,
    String quarterId, {
    int? lesson,
    int? day,
  }) =>
      _media('audio', language, quarterId, lesson, day);

  /// Loads PDF documents for a quarter, optionally filtered to one lesson.
  Future<List<MediaItem>> pdf(
    String language,
    String quarterId, {
    int? lesson,
  }) =>
      _media('pdf', language, quarterId, lesson, null);

  /// Loads video clips for a quarter, optionally filtered to one lesson.
  Future<List<MediaItem>> video(
    String language,
    String quarterId, {
    int? lesson,
  }) =>
      _media('video', language, quarterId, lesson, null);

  Future<List<MediaItem>> _media(
    String kind,
    String language,
    String quarterId,
    int? lesson,
    int? day,
  ) async {
    final yaml = await _tryRawYaml(_contentPath('$language/$quarterId/$kind.yml'));
    if (yaml == null) return [];
    final root = _asMap(yaml);
    var items = parseMedia(kind, _asList(root[kind]));
    if (lesson != null) {
      final base = '$language/$quarterId/${_lessonDir(lesson)}';
      final exact = day == null ? base : '$base/${_lessonDir(day)}';
      items = items
          .where((i) => i.target == exact || (day == null && i.target.startsWith('$base/')))
          .toList();
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // URL helpers (also useful for fetching covers/images yourself)
  // ---------------------------------------------------------------------------

  /// Raw file URL for a path relative to `src/`.
  Uri rawUri(String contentPath) => Uri.https('raw.githubusercontent.com', '/$owner/$repo/$branch/src/$contentPath');

  /// Contents-API URL for a path relative to the repository root.
  Uri apiUri(String repoPath) =>
      Uri.https('api.github.com', '/repos/$owner/$repo/contents/$repoPath', {'ref': branch});

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  String _contentPath(String relative) => relative;

  /// Lesson folder names are zero-padded (`01`, `02`, ...).
  String _lessonDir(int lessonNumber) => lessonNumber.toString().padLeft(2, '0');

  /// Lists child directories of a repository path via the Contents API.
  Future<List<String>> _listDirs(String repoPath) async {
    final response = await _apiGet(apiUri(repoPath));
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map && entry['type'] == 'dir' && entry['name'] is String)
          entry['name'] as String,
    ];
  }

  Future<http.Response> _apiGet(Uri uri) async {
    final response = await _httpClient.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        if (githubToken != null) 'Authorization': 'Bearer $githubToken',
      },
    );
    if (response.statusCode != 200) {
      throw SabbathSchoolApiException(response.statusCode, 'GET $uri failed');
    }
    return response;
  }

  Future<Object?> _tryRawYaml(String contentPath) async {
    final text = await _tryRawText(contentPath);
    if (text == null) return null;
    return loadYaml(text);
  }

  Future<Object?> _rawYaml(String contentPath) async {
    return loadYaml(await _rawText(contentPath));
  }

  Future<String> _rawText(String contentPath) async {
    final response = await _httpClient.get(rawUri(contentPath));
    if (response.statusCode != 200) {
      throw SabbathSchoolApiException(response.statusCode, 'GET ${rawUri(contentPath)} failed');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<String?> _tryRawText(String contentPath) async {
    final response = await _httpClient.get(rawUri(contentPath));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw SabbathSchoolApiException(response.statusCode, 'GET ${rawUri(contentPath)} failed');
    }
    return utf8.decode(response.bodyBytes);
  }
}

List<Object?> _asList(Object? node) {
  if (node is YamlList) return node;
  return node is List ? node : [];
}

Map<Object?, Object?> _asMap(Object? node) {
  if (node is YamlMap) return node;
  return node is Map ? node : {};
}
