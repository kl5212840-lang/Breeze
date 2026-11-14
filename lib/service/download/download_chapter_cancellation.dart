import 'dart:async';

import 'package:zephyr/main.dart' show logger;
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

typedef _StorageBucket = (String from, String comicId, String storageChapterId);

final _cleanups = <_StorageBucket, Completer<void>>{};
final _activePages = <_StorageBucket, Set<Iterable<String>>>{};
final _startedPages = <(String, int), Set<String>>{};

Iterable<String> startedDownloadChapterPages(DownloadTaskJson task) =>
    _startedPages[(task.taskKey, task.attempt)] ?? const [];

_StorageBucket _storageBucket(DownloadTaskJson task, String comicId) => (
  task.from.trim(),
  comicId.trim(),
  const DownloadChapterAdapter()
      .fromTaskRef(task.chapterRef)
      .effectiveStorageId,
);

Future<T> _withChapterAssetBuckets<T>(
  Set<_StorageBucket> buckets,
  Future<T> Function() action,
) async {
  final previous = [for (final bucket in buckets) _cleanups[bucket]?.future];
  final current = {
    for (final bucket in buckets) bucket: _cleanups[bucket] = Completer<void>(),
  };
  try {
    await Future.wait(previous.nonNulls);
    return await action();
  } finally {
    for (final entry in current.entries) {
      if (identical(_cleanups[entry.key], entry.value)) {
        _cleanups.remove(entry.key);
      }
      entry.value.complete();
    }
  }
}

/// Wait for older cleanup in the selected work's storage buckets. A sibling
/// already using a bucket keeps its planned paths, even before checkpointing.
Future<T> withDownloadChapterAssetClaims<T>(
  Iterable<DownloadTaskJson> tasks,
  Future<T> Function(Map<String, Set<String>> activePathsByStorage) action,
) {
  final buckets = {
    for (final task in tasks) _storageBucket(task, task.comicId),
  };
  return _withChapterAssetBuckets(buckets, () {
    return action({
      for (final bucket in buckets)
        bucket.$3: {
          for (final paths
              in _activePages[bucket] ?? const <Iterable<String>>{})
            ...paths,
        },
    });
  });
}

/// Announce all pages before the worker can reuse a file, including pages that
/// have yet to reach a checkpoint. A cleanup already in progress goes first.
Future<void Function()> claimDownloadChapterPages({
  required DownloadTaskJson task,
  required String comicId,
  required Iterable<String> docPaths,
  required Set<String> startedPaths,
}) async {
  final bucket = _storageBucket(task, comicId);
  while (true) {
    final cleanup = _cleanups[bucket];
    if (cleanup == null) break;
    await cleanup.future;
  }
  final claims = _activePages.putIfAbsent(bucket, () => {});
  claims.add(docPaths);
  final attempt = (task.taskKey, task.attempt);
  _startedPages[attempt] = startedPaths;
  return () {
    claims.remove(docPaths);
    if (claims.isEmpty) _activePages.remove(bucket);
    if (identical(_startedPages[attempt], startedPaths)) {
      _startedPages.remove(attempt);
    }
  };
}

/// Clean only canonical pages with no other owner in the same storage bucket.
Future<void> deleteCancelledChapterPages({
  required DownloadTaskJson task,
  required int? taskId,
  required String comicId,
  required Iterable<String> docPaths,
}) async {
  if (docPaths.isEmpty) return;
  final bucket = _storageBucket(task, comicId);
  final (from, id, storageChapterId) = bucket;
  try {
    await _withChapterAssetBuckets({bucket}, () async {
      const repository = DownloadTaskRepository();
      final keep = <String>{};
      void retain(Iterable<String> paths) {
        for (final path in paths) {
          keep.add(normalizeStoredAssetPath(path, allowEmpty: true));
        }
      }

      for (final paths in _activePages[bucket] ?? const <Iterable<String>>{}) {
        retain(paths);
      }
      // Read pending checkpoints first. A commit between these reads will
      // still be visible in the downloaded chapter record below.
      for (final row in repository.getAll(incompleteOnly: true)) {
        final payload = repository.readPayload(row);
        if (payload == null || payload.imagePaths.isEmpty) continue;
        if (row.id == taskId &&
            payload.taskKey == task.taskKey &&
            payload.attempt == task.attempt) {
          continue;
        }
        if (_storageBucket(payload, payload.comicId) == bucket) {
          retain(payload.imagePaths);
        }
      }
      final record = repository.findDownloadRecord(from, id);
      if (record != null) {
        for (final chapter in resolveDownloadChapters(record)) {
          if (chapter.effectiveStorageId == storageChapterId) {
            retain(chapter.images.map((image) => image.path));
          }
        }
      }

      await DownloadAssetStore.deleteDownloadedFiles(
        from: from,
        cartoonId: id,
        effectiveStorageChapterId: storageChapterId,
        docPaths: docPaths.where(
          (path) =>
              !keep.contains(normalizeStoredAssetPath(path, allowEmpty: true)),
        ),
      );
    });
  } catch (error, stackTrace) {
    logger.w('取消下载时无法清理章节图片', error: error, stackTrace: stackTrace);
  }
}
