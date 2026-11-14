import 'dart:convert';
import 'dart:async';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Private, device-only public-card snapshots. Never portable preferences.
class VideoPersonalSnapshotStore implements TemporaryDataCache {
  VideoPersonalSnapshotStore({this.cacheSource = ''}) {
    TemporaryDataCaches.register(this);
  }
  @override
  final String cacheSource;
  @override
  int get cacheEntryCount => _entries.length;
  @override
  void clearTemporaryData() {
    invalidate();
  }

  static Future<void> clearDisk({String? source}) async {
    final store = await SharedPreferences.getInstance();
    for (final key
        in store.getKeys().where((key) => key.startsWith(prefix)).toList()) {
      final suffix = key.substring(prefix.length);
      var matches = source == null;
      if (!matches) {
        try {
          matches =
              suffix == 'invalidated.${Uri.encodeComponent(source)}' ||
              Uri.decodeComponent(suffix).startsWith('plugin|$source|');
        } on FormatException {
          matches = false;
        }
      }
      if (matches && !await store.remove(key))
        throw StateError('Snapshot cache was not cleared');
    }
  }

  static final _invalidations = <String, DateTime>{};
  static final _generations = <String, int>{};
  DateTime? get _invalidatedAt => _invalidations[cacheSource];
  set _invalidatedAt(DateTime? value) {
    if (value == null) {
      _invalidations.remove(cacheSource);
    } else {
      _invalidations[cacheSource] = value;
    }
  }

  Future<void> _persistInvalidation() async {
    final at = _invalidatedAt;
    if (at == null) return;
    final store = await SharedPreferences.getInstance();
    await store.setString(
      '${prefix}invalidated.${Uri.encodeComponent(cacheSource)}',
      at.toIso8601String(),
    );
  }

  static const prefix = 'breeze.video.personal.snapshot.v1.';
  static const freshFor = Duration(minutes: 2);
  static const capacity = 32;
  int get generation => _generations[cacheSource] ?? 0;
  final _entries = <String, Map<String, dynamic>>{};

  static String scope(String source, Uri owner, Uri page) =>
      'plugin|$source|$owner|${page.replace(fragment: '')}';

  bool fresh(Map<String, dynamic> snapshot) {
    final saved = DateTime.tryParse('${snapshot['savedAt']}');
    final invalidatedAt = _invalidatedAt;
    final age = saved == null ? null : DateTime.now().difference(saved);
    return (saved != null &&
            (invalidatedAt == null || saved.isAfter(invalidatedAt))) &&
        age != null &&
        !age.isNegative &&
        age < freshFor;
  }

  void invalidate() {
    _generations[cacheSource] = generation + 1;
    _invalidatedAt = DateTime.now();
    unawaited(_persistInvalidation().catchError((Object _) {}));
    // Generation fences invalidate pending disk reads and pending site writes.
    // Existing disk data remains available as a stale fallback.
    _entries.clear();
  }

  Future<Map<String, dynamic>?> read(String scope) async {
    final epoch = generation;
    if (_entries[scope] case final value?) return value;
    try {
      final store = await SharedPreferences.getInstance();
      final invalidated = DateTime.tryParse(
        store.getString(
              '${prefix}invalidated.${Uri.encodeComponent(cacheSource)}',
            ) ??
            '',
      );
      if (invalidated != null &&
          (_invalidatedAt == null || invalidated.isAfter(_invalidatedAt!)))
        _invalidatedAt = invalidated;
      final raw = store.getString('$prefix${Uri.encodeComponent(scope)}');
      if (raw == null || raw.length > 1500000) return null;
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (epoch != generation ||
          value['scope'] != scope ||
          value['videos'] is! List)
        return null;
      _entries[scope] = value;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String scope, Map<String, dynamic> data, int epoch) async {
    if (epoch != generation) return;
    // Refuse oversized pages rather than caching a truncated "complete" page.
    if (data['videos'] is List && (data['videos'] as List).length > 160) return;
    final videos = (data['videos'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => {
            for (final key in const [
              'title',
              'subtitle',
              'watchUrl',
              'pageUrl',
              'coverUrl',
              'creatorName',
              'tags',
              'genres',
              'category',
              'year',
              'area',
              'language',
              'duration',
              'views',
              'likes',
              'rating',
              'ratingCount',
              'counters',
              'contentRating',
              'ratingPercent',
              'ratingPercentRaw',
              'viewCount',
              'viewCountRaw',
              'publishedRelative',
              'publishedDate',
              'totalVotes',
              'positiveVotes',
              'negativeVotes',
            ])
              if (row[key] is String ||
                  row[key] is num ||
                  row[key] is List &&
                      (row[key] as List).every((v) => v is String))
                key: row[key],
          },
        )
        .toList();
    final value = <String, dynamic>{
      'scope': scope,
      'savedAt': DateTime.now().toIso8601String(),
      'title': data['title'] is String ? data['title'] : '',
      'videos': videos,
      'paging': {
        for (final key in const [
          'page',
          'currentPage',
          'totalPages',
          'previousUrl',
          'nextUrl',
        ])
          if ((data['paging'] as Map?)?[key] is String ||
              (data['paging'] as Map?)?[key] is num)
            key: (data['paging'] as Map)[key],
      },
    };
    final store = await SharedPreferences.getInstance();
    if (epoch != generation) return;
    if (!_entries.containsKey(scope) && _entries.length >= capacity)
      _entries.remove(_entries.keys.first);
    _entries[scope] = value;
    await store.setString(
      '$prefix${Uri.encodeComponent(scope)}',
      jsonEncode(value),
    );
    final keys = store
        .getKeys()
        .where(
          (key) =>
              key.startsWith(prefix) &&
              !key.startsWith('${prefix}invalidated.'),
        )
        .toList();
    if (keys.length > capacity) {
      keys.sort((a, b) {
        String saved(String key) {
          try {
            return '${(jsonDecode(store.getString(key) ?? '{}') as Map)['savedAt'] ?? ''}';
          } catch (_) {
            return '';
          }
        }

        return saved(a).compareTo(saved(b));
      });
      for (final key in keys.take(keys.length - capacity)) {
        await store.remove(key);
      }
    }
  }
}
