# sabbath_school_lessons

[![pub package](https://img.shields.io/pub/v/sabbath_school_lessons.svg)](https://pub.dev/packages/sabbath_school_lessons)
[![GitHub](https://img.shields.io/badge/github-joshuamumbere%2Fsabbath__school__lessons-blue)](https://github.com/joshuamumbere/sabbath_school_lessons)

A Dart/Flutter client package for the
[sabbath-school-lessons](https://github.com/Adventech/sabbath-school-lessons)
content repository (or any fork of it).

It fetches quarterly Sabbath School lessons by language and exposes them as
typed models: quarters, lessons, daily readings, plus audio/PDF/video
manifests. Built for apps of any size — all metadata is served from committed,
CDN-cached index files, with zero GitHub API requests in the hot path.

## Platform support

This is a **pure Dart package** — no platform channels, no native code. It
works on iOS, Android, web, macOS, Windows, Linux, and server-side Dart out
of the box.

## Installation

### With Flutter

```sh
flutter pub add sabbath_school_lessons
```

### With plain Dart

```sh
dart pub add sabbath_school_lessons
```

### In `pubspec.yaml`

```yaml
dependencies:
  sabbath_school_lessons: ^0.2.0
```

### Development alternatives (package maintainers only)

```yaml
dependencies:
  sabbath_school_lessons:
    path: ../sabbath_school_lessons   # local development
    # git:
    #   url: https://github.com/joshuamumbere/sabbath_school_lessons.git
```

## Quick start

```dart
import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';

Future<void> main() async {
  final client = SabbathSchoolClient(); // defaults to joshuamumbere/sabbath-school-lessons @ stage

  // Latest main quarterly for English
  final quarterIds = await client.listQuarterIds('en');
  final mainQuarterId =
      quarterIds.where((q) => RegExp(r'^\d{4}-\d{2}$').hasMatch(q)).last;

  final quarter = await client.quarter('en', mainQuarterId);
  print('${quarter.title} — ${quarter.humanDate}');
  print('Theme colors: ${quarter.colorPrimary} / ${quarter.colorPrimaryDark}');

  // All 13 lessons with titles (served from the index — no extra requests)
  final lessons = await client.quarterLessons('en', mainQuarterId);

  // Today's reading
  final day = await client.day('en', mainQuarterId, 1, 1);
  print('${day.title} (${day.date})');
  print(day.markdown); // markdown body, render with your favorite renderer
}
```

## Usage guide

### Languages

```dart
final languages = await client.listLanguages();      // ['af', 'am', 'ar', ...]
final language = await client.language('en');        // Language(en, English)
```

### Quarters

```dart
final quarters = await client.listQuarterIds('en');  // ['2026-01', '2026-01-cc', ...]
final quarter = await client.quarter('en', '2026-01');

quarter.id;              // '2026-01'
quarter.title;           // 'Uniting Heaven and Earth. Christ in Philippians and Colossians'
quarter.humanDate;       // 'January · February · March 2026'
quarter.startDate;       // DateTime(2025, 12, 27)
quarter.endDate;         // DateTime(2026, 3, 27)
quarter.colorPrimary;    // '#2E4161'
quarter.colorPrimaryDark;// '#1E2C44'
quarter.splash;          // bool
quarter.credits;         // List<Credit> (name/value pairs)
quarter.lessonNumbers;   // [1, 2, ..., 13]
```

> Variant quarters (suffixes like `-cc`, `-pp`, `-rt`, teacher/student YAQ
> editions) have no numbered lesson folders; `quarterLessons` returns `[]`
> for them.

### Lessons and daily readings

```dart
// All lessons (titles + week dates) — zero requests after the index is cached
final lessons = await client.quarterLessons('en', '2026-01');
final first = lessons.first;         // Lesson 1
first.number;                        // 1
first.title;                         // 'Persecuted but Not Forsaken'
first.startDate;                     // DateTime(2025, 12, 27)
first.endDate;                       // DateTime(2026, 1, 2)

// A single lesson
final lesson = await client.lesson('en', '2026-01', 1);

// A daily reading. Day is 1..7 (Sabbath..Friday)
final day = await client.day('en', '2026-01', 1, 1);
day.title;                           // from the markdown front matter
day.date;                            // DateTime from dd/mm/yyyy front matter
day.markdown;                        // full markdown body

// The quarterly introduction essay
final intro = await client.quarterIntroduction('en', '2026-01');

// Optional lesson extras (return null when absent)
final teacherComments = await client.feature('en', '2026-01', 1, 'teacher-comments');
final insideStory     = await client.feature('en', '2026-01', 1, 'inside-story');
final hopeSS          = await client.feature('en', '2026-01', 1, 'hope-ss');
```

### Media (audio, PDF, video)

```dart
// Audio for a lesson; day: narrows to a single day of that lesson
final audio = await client.audio('en', '2026-01', lesson: 1, day: 1);

// PDFs and videos for a lesson
final pdfs   = await client.pdf('en', '2026-01', lesson: 1);
final videos = await client.video('en', '2026-01', lesson: 1);

// Every item: src (URL), target ('en/2026-01/01[/01]'), title, artist, thumbnail
for (final track in audio) {
  print('${track.artist}: ${track.src}');
}

// Whole manifests without filtering
final allAudio = await client.audio('en', '2026-01');
```

> Some quarters target media per lesson (`en/2026-01/01`), newer ones per day
> (`en/2026-04/01/01`); `audio(lesson: 1)` matches both shapes.

### Cover images and other raw files

```dart
final coverUrl = client.rawUri('src/en/2026-01/cover.png').toString();
// https://raw.githubusercontent.com/.../src/en/2026-01/cover.png
```

## Configuration

```dart
final client = SabbathSchoolClient(
  owner: 'joshuamumbere',              // GitHub owner of the content repo
  repo: 'sabbath-school-lessons',      // repository name
  branch: 'stage',                     // branch to read
  githubToken: null,                   // API-fallback token only (see below)
  indexTtl: const Duration(hours: 12), // metadata cache TTL
  contentTtl: const Duration(hours: 24),// content cache TTL
  cacheStore: myCacheStore,            // optional persistent cache
  httpClient: myHttpClient,            // optional custom http.Client
);
```

### Persistent cache across app launches

By default the cache lives in memory for the session. Implement the tiny
`CacheStore` interface to persist it (values are opaque JSON strings):

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';

class PrefsCacheStore implements CacheStore {
  @override
  Future<String?> get(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> put(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

final client = SabbathSchoolClient(cacheStore: PrefsCacheStore());
```

This makes the "fork is up to date ⇒ users make essentially no requests"
guarantee hold across app restarts, not just within a session.

### Rendering the markdown

Daily readings are raw markdown. Render them with e.g.
[`markdown`](https://pub.dev/packages/markdown) (to HTML) or
[`flutter_markdown`](https://pub.dev/packages/flutter_markdown) (widgets).

## API summary

| Method | Returns | Requests after warm-up |
| --- | --- | --- |
| `listLanguages()` | `List<String>` | 0 (cached index) |
| `language(code)` | `Language?` | 0 |
| `listQuarterIds(lang)` | `List<String>` | 0 |
| `quarter(lang, id)` | `Quarter` | 0 |
| `quarterLessons(lang, id)` | `List<Lesson>` | 0 |
| `lesson(lang, id, n)` | `Lesson` | 0 |
| `day(lang, id, lesson, day)` | `DayContent` | 0 if cached < 24 h |
| `quarterIntroduction(lang, id)` | `String` | 0 if cached |
| `feature(lang, id, lesson, name)` | `String?` | 0 if cached |
| `audio/pdf/video(...)` | `List<MediaItem>` | 0 if cached |

A cold session with a warm persistent cache: **0 requests**. A cold session
with no persistent cache: **2 small requests** (language index + your
language's index), all CDN-cached.

## How requests work at scale (important for large user bases)

The package is built so millions of users produce almost no load and no
GitHub API traffic:

1. **Committed index files.** The content repo carries `index/languages.json`
   (all languages) and `index/<lang>.json` (quarters + full metadata + lesson
   titles per language), generated by `tool/generate_index.dart`. Metadata
   calls — `listLanguages`, `listQuarterIds`, `quarter`, `quarterLessons`,
   `lesson` — read these files and make **zero GitHub API requests**.
2. **GitHub's CDN does the fan-out.** Everything is fetched from
   raw.githubusercontent.com, which is edge-cached by GitHub (Fastly) with a
   ~5-minute cache window. Every user requesting the same index file shares
   one origin fetch per edge location — the first user warms the cache for
   everyone else. No token needed.
3. **Local caching with revalidation.** Index responses are cached for
   `indexTtl` (default 12 h) and content for `contentTtl` (default 24 h).
   Expired entries are revalidated with `If-None-Match`; a `304` refreshes
   the entry without re-downloading. If the fork is unchanged, users make
   essentially no requests. Pass a `CacheStore` to keep the cache across
   app launches.
4. **Stale-safe.** If a revalidation request fails transiently, the cached
   content is served instead of surfacing an error.
5. **API fallback only when the index is absent** — e.g. an old fork. That
   path uses the GitHub Contents API (60 requests/hour unauthenticated,
   5000/hour with `githubToken`), so the token is a fallback-only concern.

## Content repository maintenance (package owner)

Regenerate the index whenever the fork is synced with upstream — or let the
committed GitHub Action (`regenerate-index.yml`) do it automatically on every
push that touches `src/`:

```sh
dart run tool/generate_index.dart --repo ../sabbath-school-lessons
git -C ../sabbath-school-lessons add index
git -C ../sabbath-school-lessons commit -m "Regenerate index"
```

| Content path | Contents |
| --- | --- |
| `src/<lang>/` | one folder per language |
| `src/<lang>/<quarter>/` | one folder per quarter, e.g. `2026-01` |
| `<quarter>/info.yml` | title, dates, theme colors, credits |
| `<quarter>/NN/info.yml` | lesson title and week dates |
| `<quarter>/NN/01..07.md` | daily readings (markdown with front matter) |
| `<quarter>/NN/teacher-comments.md`, `inside-story.md`, `hope-ss.md` | optional features |
| `<quarter>/audio.yml`, `pdf.yml`, `video.yml` | media manifests keyed by `target` |
| `index/languages.json`, `index/<lang>.json` | generated index files consumed by this package |

## Publishing new versions

1. Bump `version` in `pubspec.yaml`.
2. Add a matching entry to `CHANGELOG.md` (required by pub.dev).
3. `dart pub publish --dry-run` — fix anything it flags.
4. `dart pub publish`.
5. Tag the release: `git tag vX.Y.Z && git push origin vX.Y.Z`.

## License

The package code is MIT licensed (see `LICENSE`). The lesson **content**
itself is © General Conference of Seventh-day Adventists® — this package
only reads it.
