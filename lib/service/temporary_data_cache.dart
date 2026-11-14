/// Explicitly registered reloadable data only. Plugin key/value stores may
/// contain sessions and are never scanned or cleared by cache maintenance.
abstract interface class TemporaryDataCache {
  String get cacheSource;
  int get cacheEntryCount;
  void clearTemporaryData();
}

abstract final class TemporaryDataCaches {
  static final _caches = <WeakReference<TemporaryDataCache>>[];

  static void register(TemporaryDataCache cache) {
    _caches.removeWhere((entry) => entry.target == null);
    if (!_caches.any((entry) => identical(entry.target, cache))) {
      _caches.add(WeakReference(cache));
    }
  }

  static Iterable<TemporaryDataCache> _matching(String? source) sync* {
    _caches.removeWhere((entry) => entry.target == null);
    for (final entry in _caches) {
      final cache = entry.target;
      if (cache != null && (source == null || cache.cacheSource == source))
        yield cache;
    }
  }

  static int count({String? source}) => _matching(
    source,
  ).fold(0, (total, cache) => total + cache.cacheEntryCount);

  static void clear({String? source}) {
    for (final cache in _matching(source).toList()) {
      cache.clearTemporaryData();
    }
  }
}
