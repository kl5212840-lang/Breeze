import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ComicChapterProgress = ({int pageIndex, int pageCount, bool completed});
typedef ChapterProgressIdentity = (String source, String work, String chapter);
typedef ChapterProgressRevision = ({ComicChapterProgress? progress, int at});

class ChapterProgressArchive {
  ChapterProgressArchive([
    Map<ChapterProgressIdentity, ChapterProgressRevision> rows = const {},
  ]) : rows = Map.unmodifiable(rows);

  static const filename = 'comic-chapter-progress.json';
  static const byteLimit = 16 * 1024 * 1024;
  final Map<ChapterProgressIdentity, ChapterProgressRevision> rows;

  factory ChapterProgressArchive.decode(List<int> bytes) {
    if (bytes.length > byteLimit)
      throw const FormatException('Chapter history is too large');
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map ||
        raw.length != 3 ||
        raw['format'] != 'BreezeComicChapterProgress' ||
        raw['version'] != 1 ||
        raw['rows'] is! List) {
      throw const FormatException('Unsupported chapter history');
    }
    final rows = <ChapterProgressIdentity, ChapterProgressRevision>{};
    for (final row in raw['rows'] as List) {
      if (row case [
        final String source,
        final String work,
        final String chapter,
        final List value,
      ] when _validIdentity((source, work, chapter))) {
        final id = (source, work, chapter);
        final revision = _decodeRevision(value);
        if (revision != null && !rows.containsKey(id)) {
          rows[id] = revision;
          continue;
        }
      }
      throw const FormatException('Invalid chapter history');
    }
    return ChapterProgressArchive(rows);
  }

  List<int> encode() {
    final entries = rows.entries.toList()
      ..sort(
        (a, b) => jsonEncode([
          a.key.$1,
          a.key.$2,
          a.key.$3,
        ]).compareTo(jsonEncode([b.key.$1, b.key.$2, b.key.$3])),
      );
    final bytes = utf8.encode(
      jsonEncode({
        'format': 'BreezeComicChapterProgress',
        'version': 1,
        'rows': [
          for (final entry in entries)
            [
              entry.key.$1,
              entry.key.$2,
              entry.key.$3,
              _encodeRevision(entry.value),
            ],
        ],
      }),
    );
    if (bytes.length > byteLimit)
      throw const FormatException('Chapter history is too large');
    return bytes;
  }

  ChapterProgressArchive merged(ChapterProgressArchive other) {
    final result = {...rows};
    for (final entry in other.rows.entries) {
      final old = result[entry.key], next = entry.value;
      if (old == null) {
        result[entry.key] = next;
        continue;
      }
      final a = old.progress, b = next.progress;
      final chooseNext =
          next.at > old.at ||
          next.at == old.at &&
              (b == null ||
                  a != null &&
                      (b.pageCount > a.pageCount ||
                          b.pageCount == a.pageCount &&
                              b.pageIndex > a.pageIndex));
      final winner = chooseNext ? next : old;
      final progress = winner.progress;
      result[entry.key] =
          progress != null &&
              a != null &&
              b != null &&
              a.pageCount == b.pageCount &&
              (a.completed || b.completed)
          ? (
              at: winner.at,
              progress: (
                pageIndex: progress.pageIndex,
                pageCount: progress.pageCount,
                completed: true,
              ),
            )
          : winner;
    }
    return ChapterProgressArchive(result);
  }
}

bool _validIdentity(ChapterProgressIdentity id) => [
  id.$1,
  id.$2,
  id.$3,
].every((value) => value.trim().isNotEmpty && value.length <= 1024);

List<Object> _encodeRevision(ChapterProgressRevision revision) {
  final progress = revision.progress;
  return progress == null
      ? [revision.at]
      : [
          progress.pageIndex,
          progress.pageCount,
          progress.completed,
          revision.at,
        ];
}

ChapterProgressRevision? _decodeRevision(List value) {
  const maxTime = 8640000000000000;
  if (value case [final int at] when at > 0 && at <= maxTime) {
    return (progress: null, at: at);
  }
  if (value case [
    final int page,
    final int total,
    final bool completed,
    ...final tail,
  ] when page > 0 && (page <= total || total == 0 && !completed)) {
    final at = tail.isEmpty
        ? 0
        : tail.length == 1
        ? tail.single
        : null;
    if (at is int && at >= 0 && at <= maxTime) {
      return (
        progress: (pageIndex: page, pageCount: total, completed: completed),
        at: at,
      );
    }
  }
  return null;
}

/// Positions indexed by source, work and logical chapter.
class ComicChapterReadingProgress {
  ComicChapterReadingProgress({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static final instance = ComicChapterReadingProgress();
  static const _prefix = 'breeze.comic.chapterReadingProgress.v1.';

  static bool ownsPreference(String key) => key.startsWith(_prefix);

  final Future<SharedPreferences> Function() _preferences;
  final _changes = ValueNotifier(0);
  Listenable get changes => _changes;
  SharedPreferences? _store;
  Future<void>? _loading;
  final _pending = <String, ChapterProgressRevision>{};
  Future<void>? _writing;
  Future<void>? _restoring;

  Future<void> ensureLoaded() {
    if (_store != null) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _store = await _preferences();
      _changes.value++;
    } finally {
      _loading = null;
    }
  }

  ComicChapterProgress? lookup(
    String source,
    String comicId,
    Iterable<String> chapterKeys,
  ) => lookupRevision(source, comicId, chapterKeys)?.progress;

  ChapterProgressRevision? lookupRevision(
    String source,
    String comicId,
    Iterable<String> chapterKeys,
  ) {
    for (final chapter in chapterKeys) {
      final key = _key(source, comicId, chapter);
      if (key == null) continue;
      final revision = _lookupRevision(key);
      if (revision?.progress != null) return revision;
    }
    return null;
  }

  Future<void> record({
    required String source,
    required String comicId,
    required String chapterId,
    required int pageIndex,
    required int lastVisiblePage,
    required int pageCount,
    int? observedAt,
  }) {
    final key = _key(source, comicId, chapterId);
    if (key == null ||
        pageIndex <= 0 ||
        lastVisiblePage < pageIndex ||
        lastVisiblePage > pageCount) {
      return Future<void>.value();
    }
    final restoring = _restoring;
    final wait = restoring ?? (_store == null ? ensureLoaded() : null);
    if (wait != null) {
      final capturedAt =
          observedAt ??
          (restoring == null ? null : DateTime.now().millisecondsSinceEpoch);
      return wait.then(
        (_) => record(
          source: source,
          comicId: comicId,
          chapterId: chapterId,
          pageIndex: pageIndex,
          lastVisiblePage: lastVisiblePage,
          pageCount: pageCount,
          observedAt: capturedAt,
        ),
      );
    }
    final previous = _lookupKey(key);
    final progress = (
      pageIndex: pageIndex,
      pageCount: pageCount,
      completed:
          lastVisiblePage == pageCount ||
          (previous?.pageCount == pageCount && previous!.completed),
    );
    if (progress != previous) {
      final previous = _lookupRevision(key);
      final at = observedAt ?? _nextTime(key);
      if (previous != null && at <= previous.at) return Future<void>.value();
      _pending[key] = (progress: progress, at: at);
      _changes.value++;
    }
    if (_pending.isEmpty) return Future<void>.value();
    return _writing ??= Future<void>.microtask(_drain);
  }

  /// Preserve the exact pre-upgrade chapter before the work's single
  /// last-read position is overwritten. A legacy record has no page total.
  Future<void> seedLegacy(
    String source,
    String comicId,
    String chapterId,
    int pageIndex,
  ) async {
    final key = _key(source, comicId, chapterId);
    if (key == null || pageIndex <= 0) return;
    if (_store == null) await ensureLoaded();
    while (_restoring != null) {
      await _restoring;
    }
    if (_lookupRevision(key) != null) return;
    _pending[key] = (
      progress: (pageIndex: pageIndex, pageCount: 0, completed: false),
      at: 0,
    );
    _changes.value++;
    await (_writing ??= Future<void>.microtask(_drain));
  }

  Future<void> _drain() async {
    final store = _store!;
    try {
      while (_pending.isNotEmpty) {
        final entry = _pending.entries.first;
        final previous = store.get(entry.key);
        try {
          if (!await store.setString(
            entry.key,
            jsonEncode(_encodeRevision(entry.value)),
          )) {
            throw StateError('Comic chapter progress was not saved');
          }
        } catch (_) {
          // SharedPreferences updates its cache before persistence.
          try {
            if (previous is String) {
              await store.setString(entry.key, previous);
            } else {
              await store.remove(entry.key);
            }
          } catch (_) {}
          rethrow;
        }
        if (_pending[entry.key] == entry.value) _pending.remove(entry.key);
      }
    } finally {
      _writing = null;
    }
  }

  ComicChapterProgress? _lookupKey(String key) =>
      _lookupRevision(key)?.progress;

  ChapterProgressRevision? _lookupRevision(String key) {
    final pending = _pending[key];
    if (pending != null) return pending;
    final encoded = _store?.get(key);
    if (encoded is! String) return null;
    try {
      final value = jsonDecode(encoded);
      return value is List ? _decodeRevision(value) : null;
    } on FormatException {
      return null;
    }
  }

  int _nextTime(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lookupRevision(key)?.at ?? 0;
    return now > last ? now : last + 1;
  }

  Future<ChapterProgressArchive> capture() => _exclusive(_capture);

  Future<T> serializeRecovery<T>(Future<T> Function() action) =>
      _exclusive(() async {
        try {
          return await action();
        } finally {
          _changes.value++;
        }
      });

  ChapterProgressArchive _capture() {
    final rows = <ChapterProgressIdentity, ChapterProgressRevision>{};
    for (final key in _store!.getKeys().where(ownsPreference)) {
      try {
        if (jsonDecode(Uri.decodeComponent(key.substring(_prefix.length)))
            case [final String source, final String work, final String chapter]
            when _validIdentity((source, work, chapter))) {
          final revision = _lookupRevision(key);
          if (revision != null) rows[(source, work, chapter)] = revision;
        }
      } on FormatException {
        continue;
      }
    }
    return ChapterProgressArchive(rows);
  }

  Future<T> _exclusive<T>(FutureOr<T> Function() action) {
    final previous = _restoring;
    final operation = Future<T>.microtask(() async {
      await previous;
      if (_store == null) {
        await ensureLoaded();
      } else {
        _store = await _preferences();
      }
      await _writing;
      if (_pending.isNotEmpty) await (_writing ??= _drain());
      return action();
    });
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _restoring = tail;
    unawaited(
      tail.then((_) {
        if (identical(_restoring, tail)) _restoring = null;
      }),
    );
    return operation;
  }

  Future<ChapterProgressArchive> restore(
    ChapterProgressArchive incoming, {
    bool replace = false,
    Map<(String, String), int> deletedWorks = const {},
    Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })?
    beforeWrite,
  }) => _exclusive(() async {
    final local = _capture();
    final merged = replace ? incoming : local.merged(incoming);
    final retained = ChapterProgressArchive({
      for (final entry in merged.rows.entries)
        entry.key: switch (deletedWorks[(entry.key.$1, entry.key.$2)]) {
          final int deletion when deletion >= entry.value.at => (
            progress: null,
            at: deletion,
          ),
          _ => entry.value,
        },
    });
    final updates = <String, dynamic>{
      if (replace)
        for (final id in local.rows.keys)
          if (!retained.rows.containsKey(id)) _key(id.$1, id.$2, id.$3)!: null,
      for (final entry in retained.rows.entries)
        if (entry.value != local.rows[entry.key])
          _key(entry.key.$1, entry.key.$2, entry.key.$3)!: jsonEncode(
            _encodeRevision(entry.value),
          ),
    };
    await _apply(updates, beforeWrite: beforeWrite);
    return retained;
  });

  Future<void> _apply(
    Map<String, dynamic> updates, {
    Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })?
    beforeWrite,
  }) async {
    if (updates.isEmpty) return;
    final store = _store!;
    final before = {for (final key in updates.keys) key: store.get(key)};
    await beforeWrite?.call(updates, beforeValues: before);
    Future<bool> write(String key, dynamic value) =>
        value is String ? store.setString(key, value) : store.remove(key);
    try {
      final results = await Future.wait([
        for (final entry in updates.entries) write(entry.key, entry.value),
      ]);
      if (results.contains(false))
        throw StateError('Chapter history was not saved');
    } catch (_) {
      await Future.wait([
        for (final entry in before.entries) write(entry.key, entry.value),
      ]);
      rethrow;
    } finally {
      _changes.value++;
    }
  }

  Future<void> clearWork(String source, String comicId) =>
      _clearScope([source.trim(), comicId]);

  Future<void> clearSource(
    String source, {
    Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })?
    beforeWrite,
  }) => _clearScope([source.trim()], beforeWrite: beforeWrite);

  Future<void> _clearScope(
    List<String> scope, {
    Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })?
    beforeWrite,
  }) => _exclusive(() async {
    if (scope.any((part) => part.trim().isEmpty)) return;
    final encoded = jsonEncode(scope);
    final prefix =
        '$_prefix${Uri.encodeComponent('${encoded.substring(0, encoded.length - 1)},')}';
    final store = _store!;
    _pending.removeWhere((key, _) => key.startsWith(prefix));
    final keys = store
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    await _apply({
      for (final key in keys)
        key: scope.length == 1 ? null : jsonEncode([_nextTime(key)]),
    }, beforeWrite: beforeWrite);
  });

  static String? _key(String source, String comicId, String chapterId) {
    final identity = [source.trim(), comicId, chapterId.trim()];
    if (!_validIdentity((identity[0], identity[1], identity[2]))) return null;
    return '$_prefix${Uri.encodeComponent(jsonEncode(identity))}';
  }
}
