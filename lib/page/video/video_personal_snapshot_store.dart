import 'dart:convert';
import 'dart:async';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Private, device-only public-card snapshots. Never portable preferences.
class VideoPersonalSnapshotStore implements TemporaryDataCache {
  VideoPersonalSnapshotStore({this.cacheSource = ''}) {
    if (identical(_sources.putIfAbsent(cacheSource, () => this), this)) {
      TemporaryDataCaches.register(this);
    }
  }
  @override
  final String cacheSource;
  @override
  int get cacheEntryCount => _entries.length;
  @override
  void clearTemporaryData() {
    invalidate();
  }

  static Future<void> clearDisk({String? source}) {
    final sources = source == null ? _sources.keys.toList() : [source];
    for (final id in sources) {
      _generations[id] = (_generations[id] ?? 0) + 1;
      _sources[id]?._resident.clear();
      _invalidations.remove(id);
    }
    return _serialize((store) => _clearDisk(store, source));
  }

  static Future<void> _clearDisk(
    SharedPreferences store,
    String? source,
  ) async {
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
      if (matches && !await store.remove(key)) {
        throw StateError('Snapshot cache was not cleared');
      }
    }
  }

  static Future<void>? _diskOperations;

  static Future<void> _serialize(
    Future<void> Function(SharedPreferences) operation,
  ) {
    Future<void> run() async =>
        operation(await SharedPreferences.getInstance());
    final pending = _diskOperations?.then((_) => run()) ?? run();
    final tail = pending.catchError((Object _) {});
    _diskOperations = tail;
    unawaited(
      tail.then((_) {
        if (identical(_diskOperations, tail)) _diskOperations = null;
      }),
    );
    return pending;
  }

  static final _sources = <String, VideoPersonalSnapshotStore>{};
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

  Future<void> _persistInvalidation(DateTime at, int epoch) =>
      _serialize((store) async {
        if (epoch != generation) return;
        await store.setString(
          '${prefix}invalidated.${Uri.encodeComponent(cacheSource)}',
          at.toIso8601String(),
        );
      });

  static const prefix = 'breeze.video.personal.snapshot.v1.';
  static const freshFor = Duration(minutes: 2);
  static const capacity = 32;
  int get generation => _generations[cacheSource] ?? 0;
  final _resident = <String, Map<String, dynamic>>{};
  Map<String, Map<String, dynamic>> get _entries =>
      _sources[cacheSource]!._resident;

  void _remember(String scope, Map<String, dynamic> data) {
    _entries.remove(scope);
    _entries[scope] = data;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
  }

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
    final at = _invalidatedAt = DateTime.now();
    unawaited(_persistInvalidation(at, generation).catchError((Object _) {}));
    // Generation fences invalidate pending disk reads and pending site writes.
    // Existing disk data remains available as a stale fallback.
    _entries.clear();
  }

  Future<Map<String, dynamic>?> read(String scope) async {
    final epoch = generation;
    if (_entries[scope] case final value?) return value;
    try {
      if (_diskOperations case final pending?) await pending;
      if (epoch != generation) return null;
      if (_entries[scope] case final value?) return value;
      final store = await SharedPreferences.getInstance();
      final invalidated = DateTime.tryParse(
        store.getString(
              '${prefix}invalidated.${Uri.encodeComponent(cacheSource)}',
            ) ??
            '',
      );
      if (invalidated != null &&
          (_invalidatedAt == null || invalidated.isAfter(_invalidatedAt!))) {
        _invalidatedAt = invalidated;
      }
      final raw = store.getString('$prefix${Uri.encodeComponent(scope)}');
      if (raw == null || raw.length > 1500000) return null;
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (epoch != generation ||
          value['scope'] != scope ||
          value['videos'] is! List) {
        return null;
      }
      _remember(scope, value);
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
      if (data['previewCount'] is int) 'previewCount': data['previewCount'],
      if (data['previewComplete'] is bool)
        'previewComplete': data['previewComplete'],
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
    final encoded = jsonEncode(value);
    if (encoded.length > 1500000) return;
    await _serialize((store) async {
      if (epoch != generation) return;
      _remember(scope, value);
      await store.setString('$prefix${Uri.encodeComponent(scope)}', encoded);
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
    });
  }
}
