/// Generates committed index files for the sabbath-school-lessons content
/// repository so that apps never need the GitHub Contents API:
///
/// - `index/languages.json` — every language code and display name (~5 KB)
/// - `index/<lang>.json` — quarters with full metadata and lesson titles
///   for that language (~50-100 KB each)
///
/// Run it after the fork is synced with upstream, then commit and push the
/// regenerated files:
///
/// ```sh
/// dart run tool/generate_index.dart --repo ../sabbath-school-lessons
/// git -C ../sabbath-school-lessons add index && git -C ../sabbath-school-lessons commit -m "Regenerate index"
/// ```
///
/// Clients fetch these files from raw.githubusercontent.com, which is
/// edge-cached by GitHub's CDN — one fetch per user language per session,
/// shared by every user hitting the same edge location.
library;

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

final _quarterPattern = RegExp(r'^\d{4}-\d{2}');
final _lessonPattern = RegExp(r'^\d{1,2}$');

Future<void> main(List<String> args) async {
  String repoPath = '../sabbath-school-lessons';
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--repo') repoPath = args[i + 1];
  }
  final src = Directory('$repoPath/src');
  if (!src.existsSync()) {
    stderr.writeln('No src/ directory found at $repoPath');
    exitCode = 1;
    return;
  }

  final outDir = Directory('$repoPath/index');
  outDir.createSync(recursive: true);

  final languageCodes =
      src.listSync().whereType<Directory>().map((d) => d.path.split('/').last).where((name) {
    return !name.startsWith('.') && !name.startsWith('_');
  }).toList()
        ..sort();

  var quartersWritten = 0;
  final languagesOut = <Map<String, String>>[];

  for (final code in languageCodes) {
    final languageDir = Directory('${src.path}/$code');
    final infoFile = File('${languageDir.path}/info.yml');
    String name = code;
    if (infoFile.existsSync()) {
      final info = loadYaml(infoFile.readAsStringSync());
      if (info is Map && info['name'] is String) name = info['name'] as String;
    }
    languagesOut.add({'code': code, 'name': name});

    final quartersOut = <Map<String, Object?>>[];
    for (final entity in languageDir.listSync().whereType<Directory>()) {
      final quarterId = entity.path.split('/').last;
      if (!_quarterPattern.hasMatch(quarterId)) continue;

      final infoYml = File('${entity.path}/info.yml');
      if (!infoYml.existsSync()) continue;
      final info = _asMap(loadYaml(infoYml.readAsStringSync()));

      final lessonsOut = <Map<String, Object?>>[];
      final lessonDirs = entity
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .where((n) => _lessonPattern.hasMatch(n))
          .map((n) => int.parse(n))
          .where((n) => n >= 1 && n <= 13)
          .toList()
        ..sort();
      for (final number in lessonDirs) {
        final lessonInfoFile = File('${entity.path}/${number.toString().padLeft(2, '0')}/info.yml');
        if (!lessonInfoFile.existsSync()) continue;
        final lessonInfo = _asMap(loadYaml(lessonInfoFile.readAsStringSync()));
        lessonsOut.add({
          'number': number,
          'title': lessonInfo['title'],
          'start_date': lessonInfo['start_date'],
          'end_date': lessonInfo['end_date'],
        });
      }

      quartersOut.add({
        'id': quarterId,
        'title': info['title'],
        'description': info['description'],
        'human_date': info['human_date'],
        'start_date': info['start_date'],
        'end_date': info['end_date'],
        'color_primary': info['color_primary'],
        'color_primary_dark': info['color_primary_dark'],
        'splash': info['splash'] == true,
        'credits': [
          for (final c in _asList(info['credits']))
            {'name': _asMap(c)['name'], 'value': _asMap(c)['value']},
        ],
        'lessons': lessonsOut,
      });
      quartersWritten++;
    }

    final languageJson = jsonEncode({'code': code, 'quarters': quartersOut});
    File('${outDir.path}/$code.json').writeAsStringSync(languageJson);
  }

  File('${outDir.path}/languages.json')
      .writeAsStringSync(jsonEncode({'languages': languagesOut}));

  final totalSize = outDir
      .listSync()
      .whereType<File>()
      .fold<int>(0, (sum, f) => sum + f.lengthSync());

  stdout.writeln('Generated index for ${languagesOut.length} languages, '
      '$quartersWritten quarters, ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB total');
}

Map<dynamic, dynamic> _asMap(Object? node) =>
    node is Map ? node : const {};

List<Object?> _asList(Object? node) => node is YamlList ? node : (node is List ? node : const []);
