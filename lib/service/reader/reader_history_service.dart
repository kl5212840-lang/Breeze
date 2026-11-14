import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/util/worker_isolate.dart';
import 'package:zephyr/service/reader/reader_history_metadata.dart';

/// 供 [ReaderHistoryService] 周期性保存时使用的快照。
class HistorySnapshot {
  const HistorySnapshot({
    required this.pageIndex,
    required this.chapterOrder,
    required this.epInfo,
    this.chapterPages = const [],
  });

  final int pageIndex;
  final int chapterOrder;
  final NormalComicEpInfo epInfo;
  final List<ReaderChapterPage> chapterPages;
}

typedef ReaderChapterPage = ({
  String chapterId,
  int pageIndex,
  int lastVisiblePage,
  int pageCount,
});

typedef ReaderResumePosition = ({
  String chapterId,
  int chapterOrder,
  int pageIndex,
});

/// 阅读器历史记录服务。
///
/// 封装 ObjectBox 历史记录查询、worker isolate 写入与序列化逻辑，
/// 通过 [statusStream] 把左下角状态文本暴露给 controller，自身不依赖任何 cubit。
class ReaderHistoryService {
  static final ReaderHistoryService instance = ReaderHistoryService._();
  ReaderHistoryService._()
    : _readHistory = _loadStoredHistory,
      _chapterProgress = ComicChapterReadingProgress.instance,
      _writePayload = _writePayloadOnWorker,
      _dbRootPath = (() => p.dirname(objectbox.store.directoryPath));

  /// Uses the same session/timer/queue behavior with controlled storage in tests.
  ReaderHistoryService.forTesting({
    required UnifiedComicHistory? Function(String, String) readHistory,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    writePayload,
    ComicChapterReadingProgress? chapterProgress,
  }) : _readHistory = readHistory,
       _chapterProgress = chapterProgress,
       _writePayload = writePayload,
       _dbRootPath = (() => '/test-history');

  final UnifiedComicHistory? Function(String, String) _readHistory;
  final ComicChapterReadingProgress? _chapterProgress;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  _writePayload;
  final String Function() _dbRootPath;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // A route replacement may finish disposing after its successor has loaded.
  // Every entry point therefore requires the owner returned by loadHistory.
  int _generation = 0;
  bool owns(int owner) => owner == _generation && _source != null;
  String? _source;
  String? _comicId;
  normal.ComicInfo? _comicInfo;
  Set<String>? _fieldsMissing;
  ReaderResumePosition? _entryPosition;
  final _pendingPositions =
      <
        (String, String),
        ({ReaderResumePosition position, DateTime capturedAt})
      >{};
  String? _lastQueuedPosition;
  Timer? _timer;
  bool _isLoading = true;
  HistorySnapshot? Function()? _snapshotProvider;
  Future<void> _writes = Future<void>.value();
  Future<void> _chapterWrites = Future<void>.value();
  final _observedChapterPages = <String, ReaderChapterPage>{};
  final _lastFlushedChapterPages = <String, ReaderChapterPage>{};
  final _pausedSources = <String, int>{};
  int _replacementPauses = 0;

  bool get _writesPaused =>
      _replacementPauses > 0 || _pausedSources.containsKey(_source?.trim());

  Future<T> withWritesPausedForReplacement<T>(
    Future<T> Function() action,
  ) async {
    _replacementPauses++;
    try {
      await settlePendingWrites();
      return await action();
    } finally {
      _replacementPauses--;
    }
  }

  /// Wait for already captured positions before an explicit history replacement.
  Future<void> settlePendingWrites() async {
    await Future.wait([_writes, _chapterWrites]);
  }

  /// Personal-data removal holds the storage queue. Settle snapshots already
  /// captured before taking the deletion snapshot and refuse new ones for
  /// this source while the operation is running.
  Future<T> withWritesPausedForSource<T>(
    String source,
    Future<T> Function() action,
  ) async {
    final key = source.trim();
    _pausedSources.update(key, (count) => count + 1, ifAbsent: () => 1);
    if (_source?.trim() == key) _observedChapterPages.clear();
    try {
      await settlePendingWrites();
      return await action();
    } finally {
      if (_pausedSources.update(key, (count) => count - 1) == 0) {
        _pausedSources.remove(key);
      }
    }
  }

  Future<void> deleteHistoryRecord(
    UnifiedComicHistory history, {
    bool updateLastReadAt = false,
  }) => withWritesPausedForSource(history.source, () async {
    final existing = objectbox.unifiedHistoryBox.get(history.id);
    if (existing == null || existing.uniqueKey != history.uniqueKey) return;
    await _chapterProgress?.clearWork(history.source, history.comicId);
    final current = objectbox.unifiedHistoryBox.get(history.id);
    if (current == null || current.uniqueKey != history.uniqueKey) return;
    current
      ..deleted = true
      ..updatedAt = DateTime.now().toUtc();
    if (updateLastReadAt) current.lastReadAt = current.updatedAt;
    objectbox.unifiedHistoryBox.put(current);
  });

  Future<void> clearSourceProgress(
    String source, {
    required Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })
    beforeWrite,
  }) async {
    await _chapterProgress?.clearSource(source, beforeWrite: beforeWrite);
  }

  /// Synchronously claims ownership before any caller can schedule callbacks.
  int loadHistory({
    required String source,
    required String comicId,
    required dynamic comicInfo,
  }) {
    if (_source != null) unawaited(flush(_generation));
    _timer?.cancel();
    final owner = ++_generation;
    _snapshotProvider = null;
    _observedChapterPages.clear();
    _lastFlushedChapterPages.clear();
    _source = source;
    _comicId = comicId;
    _entryPosition = null;
    _lastQueuedPosition = null;
    _comicInfo = null;
    _isLoading = true;
    _comicInfo = _resolveNormalComicInfo(comicInfo);
    _entryPosition = currentResumePosition(source: source, comicId: comicId);
    return owner;
  }

  /// Route selection and in-reader restoration use the same chapter and page
  /// rules while the latest write is still waiting for ObjectBox.
  ReaderResumePosition? currentResumePosition({
    required String source,
    required String comicId,
  }) {
    final sourceKey = source.trim();
    final history = _readHistory(sourceKey, comicId);
    final stored =
        history?.source.trim() == sourceKey && history?.comicId == comicId
        ? history
        : null;
    final pending = _pendingPositions[(sourceKey, comicId)];
    if (pending != null &&
        (stored == null || !_storedHistoryWins(stored, pending.capturedAt))) {
      return pending.position;
    }
    if (stored == null || stored.deleted) return null;
    return (
      chapterId: stored.chapterId,
      chapterOrder: stored.chapterOrder,
      pageIndex: stored.pageIndex,
    );
  }

  /// Page numbers only belong to the exact logical chapter, never its order,
  /// request ID, or shared storage ID.
  int historyPageIndex(int owner, String chapterId) =>
      owns(owner) &&
          chapterId.isNotEmpty &&
          _entryPosition?.chapterId == chapterId
      ? _entryPosition!.pageIndex
      : 0;

  Future<void>? loadChapterProgress() => _chapterProgress?.ensureLoaded();

  int downloadedHistoryPageIndex(
    int owner,
    String chapterId,
    int pageCount, {
    Iterable<String>? chapterKeys,
  }) {
    if (!owns(owner)) return 0;
    final keys = chapterKeys ?? [chapterId];
    final chapter = _chapterProgress?.lookup(_source!, _comicId!, keys);
    final legacy = _entryPosition;
    final page = chapter == null
        ? legacy != null &&
                  legacy.chapterId.isNotEmpty &&
                  (legacy.chapterId == chapterId ||
                      keys.contains(legacy.chapterId))
              ? legacy.pageIndex
              : 0
        : chapter.pageIndex + 1;
    return pageCount > 0 && page > pageCount + 1 ? pageCount + 1 : page;
  }

  /// Keep observations in memory until the normal history flush. Preserve a
  /// last-page observation even when the reader turns back before that flush.
  void observeChapterPage(int owner, ReaderChapterPage? page) {
    if (_chapterProgress == null ||
        !owns(owner) ||
        _isLoading ||
        page == null ||
        _writesPaused) {
      return;
    }
    final previous = _observedChapterPages[page.chapterId];
    _observedChapterPages[page.chapterId] = (
      chapterId: page.chapterId,
      pageIndex: page.pageIndex,
      pageCount: page.pageCount,
      lastVisiblePage:
          previous?.pageCount == page.pageCount &&
              previous?.lastVisiblePage == page.pageCount
          ? page.pageCount
          : page.lastVisiblePage,
    );
  }

  void _flushChapterPages({ReaderResumePosition? previous}) {
    final progress = _chapterProgress;
    if (progress == null || _observedChapterPages.isEmpty && previous == null) {
      return;
    }
    final source = _source!;
    final comicId = _comicId!;
    final owner = _generation;
    final pages = _observedChapterPages.values
        .where((page) => _lastFlushedChapterPages[page.chapterId] != page)
        .toList();
    _observedChapterPages.clear();
    for (final page in pages) {
      _lastFlushedChapterPages[page.chapterId] = page;
    }
    _chapterWrites =
        Future.wait([
          for (final page in pages)
            progress.record(
              source: source,
              comicId: comicId,
              chapterId: page.chapterId,
              pageIndex: page.pageIndex,
              lastVisiblePage: page.lastVisiblePage,
              pageCount: page.pageCount,
            ),
          if (previous != null && previous.pageIndex > 1)
            progress.seedLegacy(
              source,
              comicId,
              previous.chapterId,
              previous.pageIndex - 1,
            ),
        ]).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (owns(owner)) {
              for (final page in pages) {
                if (_lastFlushedChapterPages[page.chapterId] == page) {
                  _lastFlushedChapterPages.remove(page.chapterId);
                }
              }
            }
            logger.w('Comic chapter progress could not be saved', error: error);
            logger.d(stackTrace);
          },
        );
  }

  void markLoaded(int owner) {
    if (owns(owner)) _isLoading = false;
  }

  void startPeriodicSave(int owner, HistorySnapshot? Function() provider) {
    if (!owns(owner)) return;
    _snapshotProvider = provider;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(flush(owner));
    });
  }

  /// Captures the final position before releasing the provider. The queued
  /// payload is immutable with respect to the next reader session.
  Future<void> stop(int owner) {
    if (!owns(owner)) return Future<void>.value();
    final pending = flush(owner);
    _timer?.cancel();
    _snapshotProvider = null;
    _source = null;
    ++_generation;
    return Future.wait([pending, _chapterWrites]).then((_) {});
  }

  Future<void> flush(int owner) {
    if (!owns(owner) || _isLoading || _comicInfo == null || _writesPaused) {
      return _writes;
    }
    final snapshot = _snapshotProvider?.call();
    for (final page in snapshot?.chapterPages ?? const <ReaderChapterPage>[]) {
      observeChapterPage(owner, page);
    }
    final firstWorkSave =
        _lastQueuedPosition == null &&
        snapshot != null &&
        snapshot.epInfo.epId.isNotEmpty;
    _flushChapterPages(previous: firstWorkSave ? _entryPosition : null);
    if (snapshot == null || snapshot.epInfo.epId.isEmpty) return _writes;

    final timestamp = DateTime.now().toUtc();
    final position = (
      chapterId: snapshot.epInfo.epId,
      chapterOrder: snapshot.chapterOrder,
      pageIndex: snapshot.pageIndex,
    );
    final pending = (position: position, capturedAt: timestamp);
    final positionKey = jsonEncode([
      position.chapterId,
      position.pageIndex,
      position.chapterOrder,
    ]);
    if (_lastQueuedPosition == positionKey) return _writes;
    _lastQueuedPosition = positionKey;
    final key = (_source!.trim(), _comicId!);
    _pendingPositions[key] = pending;
    final payload = <String, dynamic>{
      'dbRootPath': _dbRootPath(),
      'source': _source,
      'comicId': _comicId,
      'normalInfo': _serializeComicInfoForWorker(_comicInfo!),
      'fieldsMissing': _fieldsMissing?.toList(),
      'chapterId': snapshot.epInfo.epId,
      'chapterTitle': snapshot.epInfo.epName,
      'chapterOrder': snapshot.chapterOrder,
      'pageIndex': snapshot.pageIndex,
      'timestamp': timestamp.toIso8601String(),
    };
    final currentTime = timestamp.toLocal().toString().substring(0, 19);
    _statusController.add(
      '${snapshot.chapterOrder > 0 ? '${snapshot.chapterOrder}-' : ''}'
      '${snapshot.epInfo.epName} / ${snapshot.pageIndex - 1} / $currentTime',
    );
    // Serialize old final saves and new periodic saves. A busy worker must not
    // cause the final snapshot to be skipped or to overtake a newer session.
    _writes = _writes.then((_) async {
      try {
        await _writePayload(payload);
      } catch (e, s) {
        if (owns(owner) && _pendingPositions[key] == pending) {
          _lastQueuedPosition = null;
        }
        logger.w('history write offloaded to worker failed', error: e);
        logger.d(s);
      } finally {
        if (_pendingPositions[key] == pending) _pendingPositions.remove(key);
      }
    });
    return _writes;
  }

  normal.ComicInfo _resolveNormalComicInfo(dynamic comicInfo) {
    _fieldsMissing = null;
    if (comicInfo is PluginComicDetailSource) {
      _readMissingFields(comicInfo.normalInfo.extern);
      return comicInfo.normalInfo.comicInfo;
    }
    if (comicInfo is UnifiedComicDownload) {
      final detail = jsonDecode(comicInfo.detailJson) as Map<String, dynamic>;
      final info = normal.NormalComicAllInfo.fromJson(detail);
      _readMissingFields(info.extern);
      return info.comicInfo;
    }

    final map = _toDynamicMap(comicInfo);
    _readMissingFields(_toDynamicMap(map['extern']));
    final comicInfoMap = _toDynamicMap(map['comicInfo']);
    if (comicInfoMap.isNotEmpty) {
      return normal.ComicInfo.fromJson(comicInfoMap);
    }
    if (_looksLikeComicInfoMap(map)) {
      return normal.ComicInfo.fromJson(map);
    }

    throw StateError('Unsupported comicInfo type: ${comicInfo.runtimeType}');
  }

  void _readMissingFields(Map<String, dynamic> extern) {
    final fields = extern['fieldsMissing'];
    _fieldsMissing = fields is List ? fields.whereType<String>().toSet() : null;
  }

  Map<String, dynamic> _toDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    try {
      final normalized = jsonDecode(jsonEncode(value));
      if (normalized is Map) {
        return Map<String, dynamic>.from(normalized);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  bool _looksLikeComicInfoMap(Map<String, dynamic> map) {
    return map['id'] != null &&
        map['title'] != null &&
        map['cover'] is Map &&
        map['creator'] is Map;
  }

  Map<String, dynamic> _serializeComicInfoForWorker(normal.ComicInfo info) {
    final normalized = jsonDecode(jsonEncode(info.toJson()));
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    throw StateError('Failed to serialize ComicInfo for worker isolate');
  }
}

UnifiedComicHistory? _loadStoredHistory(String source, String comicId) {
  final query = objectbox.unifiedHistoryBox
      .query(UnifiedComicHistory_.uniqueKey.equals('$source:$comicId'))
      .build();
  try {
    return query.findFirst();
  } finally {
    query.close();
  }
}

Future<Map<String, dynamic>> _writePayloadOnWorker(
  Map<String, dynamic> payload,
) {
  final rootIsolateToken = captureWorkerIsolateToken();
  return workerManager.execute<Map<String, dynamic>>(
    () => _upsertUnifiedHistoryOnWorker(payload, rootIsolateToken),
  );
}

Future<Map<String, dynamic>> _upsertUnifiedHistoryOnWorker(
  Map<String, dynamic> payload,
  RootIsolateToken? rootIsolateToken,
) async {
  ensureWorkerIsolateInitialized(rootIsolateToken);

  final dbRootPath = payload['dbRootPath']?.toString() ?? '';
  if (dbRootPath.trim().isEmpty) {
    throw StateError('missing dbRootPath for history worker write');
  }

  final box = await ObjectBox.create(dbRootPath: dbRootPath);
  return applyReaderHistorySnapshot(box, payload);
}

bool _storedHistoryWins(UnifiedComicHistory row, DateTime capturedAt) {
  // ObjectBox stores these timestamps with millisecond precision.
  final stored = row.updatedAt.millisecondsSinceEpoch;
  final incoming = capturedAt.millisecondsSinceEpoch;
  return stored > incoming || (row.deleted && stored == incoming);
}

@visibleForTesting
Map<String, dynamic> applyReaderHistorySnapshot(
  ObjectBox box,
  Map<String, dynamic> payload,
) {
  final source = payload['source']?.toString() ?? '';
  final comicId = payload['comicId']?.toString() ?? '';
  final normalInfo = normal.ComicInfo.fromJson(
    _toWorkerMap(payload['normalInfo']),
  );
  final chapterId = payload['chapterId']?.toString() ?? '';
  final chapterTitle = payload['chapterTitle']?.toString() ?? '';
  final chapterOrder = (payload['chapterOrder'] as num?)?.toInt() ?? 0;
  final pageIndex = (payload['pageIndex'] as num?)?.toInt() ?? 0;
  final timestamp = DateTime.parse(
    payload['timestamp']?.toString() ??
        DateTime.now().toUtc().toIso8601String(),
  ).toUtc();

  final key = '$source:$comicId';
  final query = box.unifiedHistoryBox
      .query(UnifiedComicHistory_.uniqueKey.equals(key))
      .build();

  try {
    return box.store.runInTransaction(TxMode.write, () {
      final existing = query.findFirst();
      if (existing != null && _storedHistoryWins(existing, timestamp)) {
        return existing.toJson();
      }
      final entity =
          existing ??
          UnifiedComicHistory(
            uniqueKey: key,
            source: source,
            comicId: comicId,
            title: normalInfo.title,
            description: normalInfo.description,
            cover: _normalizeWorkerFlexMapString(normalInfo.cover),
            creator: _normalizeWorkerFlexMapString(normalInfo.creator),
            titleMeta: _normalizeWorkerFlexListString(normalInfo.titleMeta),
            metadata: _normalizeWorkerMetadataString(normalInfo.metadata),
            chapterId: chapterId,
            chapterTitle: chapterTitle,
            chapterOrder: chapterOrder,
            pageIndex: pageIndex,
            createdAt: timestamp,
            lastReadAt: timestamp,
            updatedAt: timestamp,
            deleted: false,
            schemaVersion: 2,
          );

      final missing = (payload['fieldsMissing'] as List?)
          ?.whereType<String>()
          .toSet();
      final metadata = readerHistoryMetadataForWrite(
        incoming: _normalizeWorkerMetadataString(normalInfo.metadata),
        previous: entity.metadata,
        fieldsMissing: missing,
      );
      entity
        ..title = normalInfo.title
        ..description = missing?.contains('description') == true
            ? entity.description
            : normalInfo.description
        ..cover = _normalizeWorkerFlexMapString(normalInfo.cover)
        ..creator = _normalizeWorkerFlexMapString(normalInfo.creator)
        ..titleMeta = _normalizeWorkerFlexListString(normalInfo.titleMeta)
        ..metadata = metadata
        ..chapterId = chapterId
        ..chapterTitle = chapterTitle
        ..chapterOrder = chapterOrder
        ..pageIndex = pageIndex
        ..lastReadAt = timestamp
        ..updatedAt = timestamp
        ..deleted = false;

      entity.id = box.unifiedHistoryBox.put(entity);
      return entity.toJson();
    });
  } finally {
    query.close();
  }
}

Map<String, dynamic> _toWorkerMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _normalizeWorkerFlexMap(dynamic value) {
  final encoded = jsonEncode(value);
  final decoded = jsonDecode(encoded);
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _normalizeWorkerFlexList(List<dynamic> value) {
  final encoded = jsonEncode(value);
  final decoded = jsonDecode(encoded);
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return <Map<String, dynamic>>[];
}

String _normalizeWorkerFlexMapString(dynamic value) {
  return jsonEncode(_normalizeWorkerFlexMap(value));
}

String _normalizeWorkerFlexListString(List<dynamic> value) {
  return jsonEncode(_normalizeWorkerFlexList(value));
}

String _normalizeWorkerMetadataString(List<dynamic> value) {
  final normalized = _normalizeWorkerFlexList(value);
  return jsonEncode(normalized);
}
