import 'package:yaml/yaml.dart';

import 'models.dart';

/// Parses `dd/mm/yyyy` date strings used across the repository.
DateTime? parseDate(Object? value) {
  if (value is DateTime) return value;
  if (value is! String) return null;
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value.trim());
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}

/// Parses `src/<lang>/info.yml` (`name`, `code`).
Language parseLanguage(String code, Object? node) {
  final map = _asMap(node);
  return Language(
    code: code,
    name: map['name'] is String ? map['name'] as String : null,
  );
}

/// Parses a quarter's `info.yml`.
Quarter parseQuarter(String language, String quarterId, Object? node) {
  final map = _asMap(node);
  final credits = _asList(map['credits'])
      .map((e) => Credit(name: _str(_asMap(e)['name']), value: _str(_asMap(e)['value'])))
      .toList();

  return Quarter(
    language: language,
    id: quarterId,
    title: _str(map['title']),
    description: _str(map['description']),
    humanDate: _str(map['human_date']),
    startDate: parseDate(map['start_date'])!,
    endDate: parseDate(map['end_date'])!,
    colorPrimary: _str(map['color_primary']),
    colorPrimaryDark: _str(map['color_primary_dark']),
    splash: map['splash'] == true,
    credits: credits,
    lessonNumbers: [],
  );
}

/// Parses a lesson's `info.yml`.
Lesson parseLesson(String language, String quarterId, int number, Object? node) {
  final map = _asMap(node);
  return Lesson(
    language: language,
    quarterId: quarterId,
    number: number,
    title: _str(map['title']),
    startDate: parseDate(map['start_date'])!,
    endDate: parseDate(map['end_date'])!,
  );
}

/// Parses one media manifest (`audio.yml`, `pdf.yml`, or `video.yml`).
///
/// Audio and video manifests group clips under an artist with a `tracks` or
/// `clips` list; the PDF manifest lists clips directly. Both shapes are
/// accepted.
List<MediaItem> parseMedia(String kind, Object? node) {
  final items = <MediaItem>[];
  for (final groupNode in _asList(node)) {
    final group = _asMap(groupNode);
    final clips = _asList(group['tracks'] ?? group['clips']);
    if (clips.isEmpty) {
      // Direct clip entry (e.g. pdf.yml), the group itself is the clip.
      final item = _parseClip(kind, group, _optionalStr(group['artist'] ?? group['title']));
      if (item != null) items.add(item);
      continue;
    }
    final artist = _optionalStr(group['artist'] ?? group['title']);
    for (final clipNode in clips) {
      final item = _parseClip(kind, _asMap(clipNode), artist);
      if (item != null) items.add(item);
    }
  }
  return items;
}

MediaItem? _parseClip(String kind, Map<Object?, Object?> clip, String? artist) {
  final src = _str(clip['src']);
  if (src.isEmpty) return null;
  return MediaItem(
    kind: kind,
    src: src,
    target: _str(clip['target']),
    title: _optionalStr(clip['title']),
    artist: artist,
    thumbnail: _optionalStr(clip['thumbnail']),
  );
}

/// Parses a lesson-day markdown file (`01.md`..`07.md`).
///
/// Day files start with a front matter block (`title`, `date`) delimited
/// by `---` lines, followed by the markdown body.
DayContent parseDayMarkdown(
  String language,
  String quarterId,
  int lessonNumber,
  int day,
  String markdown,
) {
  var body = markdown;
  String title = '';
  DateTime? date;

  final trimmed = body.trimLeft();
  if (trimmed.startsWith('---')) {
    final end = trimmed.indexOf('\n---');
    if (end != -1) {
      final frontMatter = trimmed.substring(3, end);
      for (final line in frontMatter.split('\n')) {
        final titleMatch = RegExp(r'^title:\s*(.+)$').firstMatch(line.trim());
        if (titleMatch != null) title = titleMatch.group(1)!.trim().replaceAll('"', '');
        final dateMatch = RegExp(r'^date:\s*(.+)$').firstMatch(line.trim());
        if (dateMatch != null) date = parseDate(dateMatch.group(1));
      }
      body = trimmed.substring(end + 4).trim();
    }
  }

  return DayContent(
    language: language,
    quarterId: quarterId,
    lessonNumber: lessonNumber,
    day: day,
    title: title,
    date: date,
    markdown: body,
  );
}

Map<Object?, Object?> _asMap(Object? node) {
  if (node is YamlMap) return node;
  return node is Map ? node : {};
}

List<Object?> _asList(Object? node) {
  if (node is YamlList) return node;
  return node is List ? node : [];
}

String _str(Object? value) => value == null ? '' : value.toString();

String? _optionalStr(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return value;
}
