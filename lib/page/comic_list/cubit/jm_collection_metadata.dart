import 'dart:async';
import 'package:zephyr/service/comic_public_metadata.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/search_result/view/source_comic_search.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

typedef JmDetailRead = Future<Map<String, dynamic>> Function(String id);

/// Public detail fields only. One account owns at most two read-only requests;
/// failed IDs stay unknown and are not retried by every rebuild/page response.
class JmCollectionMetadata {
  static final instance = JmCollectionMetadata();
  static const prefix = 'breeze.local.jm-metadata.v1.';
  final _loaded = <String, Future<void>>{};
  final _values = <String, Map<String, List<UnifiedComicMetadata>>>{};
  final _attempted = <String, Set<String>>{};
  final _pending = <String, Map<String, UnifiedComicListItem>>{};
  final _pendingSources = <String, Map<String, String>>{};
  final _running = <String, Future<void>>{};
  final _writes = <String, Future<void>>{};
  final _epochs = <String, int>{};
  final _blocked = <String>{};
  final _dirty = <String>{};
  final _permits = Queue<Completer<void>>();
  int _activeReads = 0;
  Future<void> _acquire() {
    if (_activeReads < 2) {
      _activeReads++;
      return Future<void>.value();
    }
    final pending = Completer<void>();
    _permits.add(pending);
    return pending.future;
  }

  void _release() {
    if (_permits.isNotEmpty)
      _permits.removeFirst().complete();
    else
      _activeReads--;
  }

  Future<void> _load(String account) => _loaded.putIfAbsent(account, () async {
    final works = _values.putIfAbsent(account, () => {});
    try {
      final text = (await SharedPreferences.getInstance()).getString(
        '$prefix$account',
      );
      if (text == null || text.length > 4 * 1024 * 1024) return;
      final raw = jsonDecode(text);
      if (raw is! Map || raw['version'] != 1 || raw['works'] is! Map) return;
      for (final e in (raw['works'] as Map).entries.take(1500)) {
        if (e.key is! String || e.value is! List) continue;
        works[e.key as String] = [
          for (final m in e.value as List)
            if (m is Map)
              UnifiedComicMetadata.fromJson(Map<String, dynamic>.from(m)),
        ];
      }
    } catch (_) {
      /* A missing cache does not claim successful detail metadata. */
    }
  });

  Future<List<UnifiedComicListItem>> hydrate(
    String account,
    List<UnifiedComicListItem> rows, {
    bool Function()? canApply,
  }) async {
    await _load(account);
    final values = _values[account]!;
    final bySource = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final row in rows) {
      if (values[row.id] case final metadata?)
        bySource.putIfAbsent(row.source, () => {})[row.id] = metadata
            .map((m) => m.toJson())
            .toList();
    }
    if (canApply?.call() != false) {
      for (final entry in bySource.entries) {
        try {
          ComicPublicMetadata.apply(entry.key, entry.value);
        } catch (_) {}
      }
    }
    return mergeKnownSourceComicMetadata(rows, [
      for (final row in rows)
        if (values[row.id] case final metadata?)
          row.copyWith(
            metadata: metadata,
            raw: {'metadata': metadata.map((m) => m.toJson()).toList()},
          ),
    ]);
  }

  void start({
    required String account,
    required int generation,
    required List<UnifiedComicListItem> rows,
    required bool Function() current,
    bool Function()? active,
    required JmDetailRead read,
    required void Function(Map<String, List<UnifiedComicMetadata>>) onBatch,
  }) {
    if (_epochs[account] != generation) {
      _epochs[account] = generation;
      _attempted.remove(account);
      _blocked.remove(account);
    }
    if (_blocked.contains(account)) return;
    final attempted = _attempted.putIfAbsent(account, () => {});
    final pending = _pending.putIfAbsent(account, () => {});
    for (final row in rows) {
      _pendingSources.putIfAbsent(account, () => {})[row.id] = row.source;
      final known = _values[account]?[row.id] ?? row.metadata;
      if (!known.any((m) => m.type == 'tags' || m.type == 'tag') &&
          !attempted.contains(row.id))
        pending[row.id] = row;
    }
    if (!current() || active?.call() == false || pending.isEmpty) return;
    if (_running[account] case final running?) {
      unawaited(
        running.then((_) {
          if (current())
            start(
              account: account,
              generation: generation,
              rows: rows,
              current: current,
              active: active,
              read: read,
              onBatch: onBatch,
            );
        }),
      );
      return;
    }
    final task = _run(account, current, read, onBatch, active);
    _running[account] = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_running[account], task)) _running.remove(account);
      }),
    );
  }

  Future<void> _run(
    String account,
    bool Function() current,
    JmDetailRead read,
    void Function(Map<String, List<UnifiedComicMetadata>>) onBatch,
    bool Function()? active,
  ) async {
    await _load(account);
    final batch = <String, List<UnifiedComicMetadata>>{};
    var nextStart = DateTime.now();
    Future<void> publish() async {
      if (batch.isEmpty || !current()) return;
      await _persist(account);
      if (!current()) return;
      final update = Map<String, List<UnifiedComicMetadata>>.from(batch);
      batch.clear();
      final bySource = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final row
          in _pendingSources[account]?.entries ??
              const <MapEntry<String, String>>[]) {
        if (update[row.key] case final metadata?)
          bySource.putIfAbsent(row.value, () => {})[row.key] = metadata
              .map((m) => m.toJson())
              .toList();
      }
      for (final entry in bySource.entries) {
        try {
          ComicPublicMetadata.apply(entry.key, entry.value);
        } catch (_) {}
      }
      onBatch(update);
    }

    Future<void> worker() async {
      while (current() &&
          active?.call() != false &&
          !_blocked.contains(account)) {
        final pending = _pending[account]!;
        if (pending.isEmpty) break;
        final id = pending.keys.first;
        final work = pending.remove(id)!;
        final cached = _values[account]?[id];
        if (cached != null &&
            cached.any((m) => m.type == 'tags' || m.type == 'tag')) {
          batch[id] = cached;
          if (batch.length >= 8) await publish();
          continue;
        }
        if (!_attempted[account]!.add(id)) continue;
        final now = DateTime.now();
        final start = nextStart.isAfter(now) ? nextStart : now;
        nextStart = start.add(const Duration(milliseconds: 400));
        if (start.isAfter(now))
          await Future<void>.delayed(start.difference(now));
        if (!current() || active?.call() == false) break;
        try {
          await _acquire();
          late Map<String, dynamic> response;
          try {
            if (!current()) break;
            response = await read(id);
          } finally {
            _release();
          }
          if (!current()) break;
          if (response['source'] is String && response['source'] != work.source)
            continue;
          final data = response['data'];
          final normal = data is Map ? data['normal'] : response['normal'];
          final info = normal is Map ? normal['comicInfo'] : null;
          if (info is! Map ||
              info['id']?.toString() != id ||
              info['title'] is! String ||
              (info['title'] as String).trim().isEmpty ||
              info['metadata'] is! List)
            continue;
          final metadata = <UnifiedComicMetadata>[];
          for (final raw in info['metadata'] as List) {
            if (raw is! Map ||
                !const {
                  'tags',
                  'tag',
                  'author',
                  'category',
                  'categories',
                  'works',
                  'actors',
                }.contains(raw['type']) ||
                raw['value'] is! List)
              continue;
            final values = <Object>[];
            for (final v in raw['value'] as List) {
              final value = v is Map ? v['name'] : v;
              if ((value is String || value is num) &&
                  value.toString().trim().isNotEmpty)
                values.add(value.toString().trim());
            }
            metadata.add(
              UnifiedComicMetadata(
                type: raw['type'] as String,
                name: raw['name'] is String ? raw['name'] as String : '',
                value: values,
              ),
            );
          }
          final extern = normal is Map ? normal['extern'] : null;
          final missing = extern is Map ? extern['fieldsMissing'] : null;
          if (missing is List &&
              !missing.contains('tags') &&
              !metadata.any((m) => m.type == 'tags' || m.type == 'tag')) {
            metadata.add(
              const UnifiedComicMetadata(type: 'tags', name: '', value: []),
            );
          }
          if (metadata.isNotEmpty) {
            _values[account]![id] = metadata;
            batch[id] = metadata;
            _dirty.add(account);
            if (batch.length >= 8) await publish();
          }
        } catch (error) {
          if (parseUnauthorizedPayload(error, fallbackPluginId: work.source) !=
              null) {
            _blocked.add(account);
            _pending[account]?.clear();
            break;
          }
          // A failed detail remains unknown; it is not retried by list rebuilds.
        }
      }
    }

    await Future.wait([worker(), worker()]);
    await publish();
    if (!current()) {
      _pending.remove(account);
      _attempted.remove(account);
    }
  }

  Future<void> _persist(String account) {
    _dirty.remove(account);
    final previous = _writes[account] ?? Future<void>.value();
    final task = previous.catchError((Object _) {}).then((_) async {
      final rows = _values[account]!;
      while (rows.length > 1500) rows.remove(rows.keys.first);
      final text = jsonEncode({
        'version': 1,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'sources':
            _pendingSources[account]?.values.toSet().toList() ?? <String>[],
        'works': {
          for (final e in rows.entries)
            e.key: e.value.map((m) => m.toJson()).toList(),
        },
      });
      if (text.length <= 4 * 1024 * 1024) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$prefix$account', text);
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith(prefix))
            .toList();
        keys.sort((a, b) {
          int stamp(String key) {
            try {
              return (jsonDecode(prefs.getString(key)!) as Map)['savedAt']
                  as int;
            } catch (_) {
              return 0;
            }
          }

          return stamp(b).compareTo(stamp(a));
        });
        for (final key in keys.skip(8)) await prefs.remove(key);
      }
    });
    final tail = task.then<void>((_) {}, onError: (Object _) {});
    _writes[account] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_writes[account], tail)) _writes.remove(account);
      }),
    );
    return task.catchError((Object _) {});
  }

  Future<void> flush() async {
    for (final account in _dirty.toList()) {
      unawaited(_persist(account));
    }
    await Future.wait(_writes.values.toList());
  }

  Future<void> settle() async {
    await Future.wait(_running.values.toList());
    await flush();
  }

  Future<void> clearDisk({
    String? source,
    Set<String> accounts = const {},
  }) async {
    final owners = <String>{
      ...accounts,
      for (final e in _pendingSources.entries)
        if (source == null || e.value.values.contains(source)) e.key,
    };
    _blocked.addAll(owners);
    await Future.wait([
      for (final owner in owners)
        if (_running[owner] case final running?) running,
    ]);
    await flush();
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((key) => key.startsWith(prefix)).toList()) {
      var matches =
          source == null || owners.contains(key.substring(prefix.length));
      try {
        final raw = jsonDecode(prefs.getString(key)!) as Map;
        matches |=
            raw['sources'] is List && (raw['sources'] as List).contains(source);
      } catch (_) {
        matches |= source == null;
      }
      if (matches) await prefs.remove(key);
    }
    if (source == null) {
      clearMemory();
    } else {
      for (final account in owners) {
        _loaded.remove(account);
        _values.remove(account);
        _attempted.remove(account);
        _pending.remove(account);
        _pendingSources.remove(account);
        _epochs.remove(account);
        _blocked.remove(account);
        _dirty.remove(account);
      }
    }
  }

  void clearMemory() {
    _loaded.clear();
    _values.clear();
    _attempted.clear();
    _pending.clear();
    _pendingSources.clear();
    _epochs.clear();
    _blocked.clear();
    _dirty.clear();
  }
}
