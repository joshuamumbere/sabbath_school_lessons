import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('parseQuarter', () {
    test('parses a real-shaped quarter info.yml', () {
      const yamlText = '''
  title: "Uniting Heaven and Earth. Christ in Philippians and Colossians"
  description: "Think of the hardest job you've ever done."
  human_date: "January · February · March 2026"
  start_date: "27/12/2025"
  end_date: "27/03/2026"
  color_primary: "#2E4161"
  color_primary_dark: "#1E2C44"
  splash: true
  credits:
    - name: Principal Contributor
      value: "Clinton Wahlen"
    - name: Editor
      value: "Clifford R. Goldstein"
''';
      final quarter = parseQuarter('en', '2026-01', loadYaml(yamlText));

      expect(quarter.language, 'en');
      expect(quarter.id, '2026-01');
      expect(quarter.title, contains('Philippians'));
      expect(quarter.humanDate, 'January · February · March 2026');
      expect(quarter.startDate, DateTime(2025, 12, 27));
      expect(quarter.endDate, DateTime(2026, 3, 27));
      expect(quarter.colorPrimary, '#2E4161');
      expect(quarter.splash, isTrue);
      expect(quarter.credits, hasLength(2));
      expect(quarter.credits.first.name, 'Principal Contributor');
    });
  });

  group('parseLesson', () {
    test('parses a lesson info.yml', () {
      const yamlText = '''
title: "Persecuted but Not Forsaken"
start_date: "27/12/2025"
end_date: "02/01/2026"
''';
      final lesson = parseLesson('en', '2026-01', 1, loadYaml(yamlText));

      expect(lesson.number, 1);
      expect(lesson.title, 'Persecuted but Not Forsaken');
      expect(lesson.startDate, DateTime(2025, 12, 27));
      expect(lesson.endDate, DateTime(2026, 1, 2));
    });
  });

  group('parseDayMarkdown', () {
    test('extracts front matter and body', () {
      const markdown = '''
---
title:  Persecuted but Not Forsaken
date:  27/12/2025
---

### Read for This Week's Study
Eph. 3:1; 2 Cor. 4:7–12; Acts 9:16.

> <p>Memory Text:</p>
> "Rejoice in the Lord always." (Philippians 4:4, NKJV).
''';
      final day = parseDayMarkdown('en', '2026-01', 1, 1, markdown);

      expect(day.day, 1);
      expect(day.title, 'Persecuted but Not Forsaken');
      expect(day.date, DateTime(2025, 12, 27));
      expect(day.markdown, startsWith("### Read for This Week's Study"));
      expect(day.markdown, isNot(contains('---')));
    });

    test('handles markdown without front matter', () {
      final day = parseDayMarkdown('en', '2026-01', 1, 2, 'Just a body.');
      expect(day.title, isEmpty);
      expect(day.date, isNull);
      expect(day.markdown, 'Just a body.');
    });
  });

  group('parseMedia', () {
    test('parses audio.yml with artist/tracks', () {
      const yamlText = '''
  audio:
    - artist: Adult Bible Study Guides
      tracks:
        - src: https://example.com/audio/lesson-1.mp3
          target: en/2026-01/01
        - src: https://example.com/audio/lesson-2.mp3
          target: en/2026-01/02
''';
      final items = parseMedia('audio', _node(yamlText)['audio']);

      expect(items, hasLength(2));
      expect(items.first.kind, 'audio');
      expect(items.first.artist, 'Adult Bible Study Guides');
      expect(items.first.src, 'https://example.com/audio/lesson-1.mp3');
      expect(items.first.target, 'en/2026-01/01');
    });

    test('parses pdf.yml with title entries', () {
      const yamlText = '''
  pdf:
    - src: https://example.com/pdf/intro.pdf
      title: Introduction
      target: en/2026-01/01
    - src: https://example.com/pdf/01.pdf
      target: en/2026-01/01
''';
      final items = parseMedia('pdf', _node(yamlText)['pdf']);

      expect(items, hasLength(2));
      expect(items.first.title, 'Introduction');
      expect(items.last.title, isNull);
    });

    test('parses video.yml with artist/clips and thumbnails', () {
      const yamlText = '''
  video:
    - artist: Hope Sabbath School
      clips:
        - src: https://example.com/video/01.mp4
          target: en/2026-01/01
          thumbnail: https://example.com/video/01.webp
''';
      final items = parseMedia('video', _node(yamlText)['video']);

      expect(items, hasLength(1));
      expect(items.first.artist, 'Hope Sabbath School');
      expect(items.first.thumbnail, 'https://example.com/video/01.webp');
    });
  });

  group('parseDate', () {
    test('parses dd/mm/yyyy', () {
      expect(parseDate('27/12/2025'), DateTime(2025, 12, 27));
      expect(parseDate('02/01/2026'), DateTime(2026, 1, 2));
      expect(parseDate('nonsense'), isNull);
      expect(parseDate(null), isNull);
    });
  });
}

YamlMap _node(String yamlText) => loadYaml(yamlText) as YamlMap;
