/// Data models for the sabbath-school-lessons content repository.
library;

/// A content language available in the repository, e.g. `en`, `pt`, `bg`.
class Language {
  const Language({required this.code, this.name});

  /// ISO-like code used as the folder name under `src/`, e.g. `en`.
  final String code;

  /// Human-readable name from `src/<code>/info.yml`, e.g. `English`.
  /// `null` until [SabbathSchoolClient.language] has resolved it.
  final String? name;

  @override
  String toString() => name == null ? 'Language($code)' : 'Language($code, $name)';
}

/// A contributor credit from a quarter's `info.yml`.
class Credit {
  const Credit({required this.name, required this.value});

  /// Role, e.g. `Principal Contributor`.
  final String name;

  /// Person, e.g. `Clinton Wahlen`.
  final String value;
}

/// Metadata of a quarterly (e.g. `2026-01`) parsed from `info.yml`.
class Quarter {
  const Quarter({
    required this.language,
    required this.id,
    required this.title,
    required this.description,
    required this.humanDate,
    required this.startDate,
    required this.endDate,
    required this.colorPrimary,
    required this.colorPrimaryDark,
    required this.splash,
    required this.credits,
    required this.lessonNumbers,
  });

  /// Language code this quarter belongs to.
  final String language;

  /// Quarter folder name, e.g. `2026-01`.
  final String id;

  /// Quarterly title, e.g. `Uniting Heaven and Earth. Christ in Philippians and Colossians`.
  final String title;

  /// Short intro paragraph of the quarterly.
  final String description;

  /// Display date range, e.g. `January · February · March 2026`.
  final String humanDate;

  /// First day of the first lesson.
  final DateTime startDate;

  /// Last day of the last lesson.
  final DateTime endDate;

  /// Primary theme color as a hex string, e.g. `#2E4161`.
  final String colorPrimary;

  /// Darker theme color variant as a hex string, e.g. `#1E2C44`.
  final String colorPrimaryDark;

  /// Whether the quarter should use a splash cover in the app.
  final bool splash;

  /// Contributor credits.
  final List<Credit> credits;

  /// Lesson numbers found in the quarter folder, e.g. `[1, 2, ..., 13]`.
  final List<int> lessonNumbers;

  @override
  String toString() => 'Quarter($language/$id, $title)';
}

/// Metadata of a single lesson parsed from its `info.yml`.
class Lesson {
  const Lesson({
    required this.language,
    required this.quarterId,
    required this.number,
    required this.title,
    required this.startDate,
    required this.endDate,
  });

  /// Language code this lesson belongs to.
  final String language;

  /// Quarter folder name, e.g. `2026-01`.
  final String quarterId;

  /// Lesson number within the quarter, `1..13`.
  final int number;

  /// Lesson title, e.g. `Persecuted but Not Forsaken`.
  final String title;

  /// First day (Sabbath) of the lesson week.
  final DateTime startDate;

  /// Last day (Friday) of the lesson week.
  final DateTime endDate;

  @override
  String toString() => 'Lesson($language/$quarterId/$number, $title)';
}

/// One daily reading parsed from the front matter of its markdown file.
class DayContent {
  const DayContent({
    required this.language,
    required this.quarterId,
    required this.lessonNumber,
    required this.day,
    required this.title,
    required this.date,
    required this.markdown,
  });

  /// Language code.
  final String language;

  /// Quarter folder name.
  final String quarterId;

  /// Lesson number, `1..13`.
  final int lessonNumber;

  /// Day of the lesson week, `1..7`.
  final int day;

  /// Day title from the markdown front matter.
  final String title;

  /// Day date, parsed from `dd/mm/yyyy` in the front matter.
  final DateTime? date;

  /// Full markdown body of the day, without the front matter.
  final String markdown;

  @override
  String toString() => 'DayContent($language/$quarterId/$lessonNumber/$day, $title)';
}

/// An audio track, PDF document, or video clip entry from the media manifests.
class MediaItem {
  const MediaItem({
    required this.kind,
    required this.src,
    required this.target,
    this.title,
    this.artist,
    this.thumbnail,
  });

  /// Manifest kind: `audio`, `pdf`, or `video`.
  final String kind;

  /// Absolute URL of the media file.
  final String src;

  /// Content path the item belongs to, e.g. `en/2026-01/01`.
  final String target;

  /// Optional display title (PDFs and some video entries).
  final String? title;

  /// Optional artist or provider name (audio and video entries).
  final String? artist;

  /// Optional thumbnail URL (video entries).
  final String? thumbnail;

  @override
  String toString() => 'MediaItem($kind, $target, $src)';
}
