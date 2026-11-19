# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0

- Committed index architecture: `index/languages.json` and `index/<lang>.json`
  serve all metadata with zero GitHub API requests.
- Local caching with configurable TTLs (`indexTtl`, `contentTtl`) and ETag
  revalidation; stale content is served on transient errors.
- Pluggable `CacheStore` for persisting the cache across app launches.
- `tool/generate_index.dart` to regenerate the index after syncing the fork.
- Falls back to the GitHub Contents API (with optional `githubToken`) when
  index files are absent.

## 0.1.0

- Initial release.
- `SabbathSchoolClient` with configurable owner/repo/branch and optional
  GitHub token.
- Languages and quarters listing, quarter/lesson metadata, daily readings,
  extra feature markdown files, and audio/PDF/video manifests.
