import 'dart:convert';

/// A pluggable store for cached HTTP responses.
///
/// The default implementation is in-memory ([MemoryCacheStore]); apps can
/// persist entries across launches by providing their own implementation
/// (e.g. backed by shared_preferences, SQLite, or files). Values are opaque
/// JSON strings produced by the client.
abstract class CacheStore {
  Future<String?> get(String key);

  Future<void> put(String key, String value);

  Future<void> remove(String key);
}

/// Simple in-memory [CacheStore].
class MemoryCacheStore implements CacheStore {
  final Map<String, String> _entries = {};

  @override
  Future<String?> get(String key) async => _entries[key];

  @override
  Future<void> put(String key, String value) async => _entries[key] = value;

  @override
  Future<void> remove(String key) async => _entries.remove(key);

  /// Removes all entries.
  void clear() => _entries.clear();
}

/// A cached response with revalidation metadata, serialized as JSON so any
/// [CacheStore] can persist it.
class CacheEntry {
  CacheEntry({
    required this.body,
    this.etag,
    this.lastModified,
    required this.fetchedAt,
  });
  CacheEntry._(this.body, this.etag, this.lastModified, this.fetchedAt);

  factory CacheEntry.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return CacheEntry._(
      map['body'] as String,
      map['etag'] as String?,
      map['lastModified'] as String?,
      DateTime.fromMillisecondsSinceEpoch(map['fetchedAt'] as int),
    );
  }

  /// Response body.
  final String body;

  /// `ETag` for conditional revalidation, if the server sent one.
  final String? etag;

  /// `Last-Modified` for conditional revalidation, if the server sent one.
  final String? lastModified;

  /// When the entry was last confirmed (200 or 304).
  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) < ttl;

  CacheEntry touched() => CacheEntry._(body, etag, lastModified, DateTime.now());

  String toJson() => jsonEncode({
        'body': body,
        if (etag != null) 'etag': etag,
        if (lastModified != null) 'lastModified': lastModified,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      });
}
