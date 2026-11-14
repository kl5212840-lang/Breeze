import 'dart:convert';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_chapter_assets.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/network/http/picture/picture.dart'
    show deleteComicDownloadDirectory;

/// 单章删除的结果。
enum DeleteDownloadedChapterResult {
  /// 删除了一个章节，漫画还有剩余章节。
  chapterDeleted,

  /// 删除的是最后一个章节，整本下载记录已一并删除。
  wholeComicDeleted,

  /// 本地没有该章节（或没有本漫画），什么都没做。
  notFound,
}

class ActiveChapterDownloadRemoval implements Exception {}

/// 删除本地已下载的单个章节及对应任务。
///
/// 只删该章独占的图片文件，并从 `chapters` 和 `detailJson.eps` 移除该条目。
/// 删的是最后一个章节时走整本删除。
Future<DeleteDownloadedChapterResult> deleteDownloadedChapter({
  required String from,
  required String comicId,
  required String chapterKey,
}) async {
  const repository = DownloadTaskRepository();
  const adapter = DownloadChapterAdapter();
  final workKey = buildDownloadTaskKey(from, comicId);
  final lease = DownloadResourceLifecycle.acquireRemoval(
    DownloadResourceLifecycle.comic(workKey),
  );
  try {
    final workTasks = <(DownloadTask, DownloadTaskJson)>[];
    for (final task in repository.getAll()) {
      if (task.comicId.trim() != comicId.trim()) continue;
      final payload = repository.readPayload(task);
      if (payload != null &&
          payload.from.trim() == from.trim() &&
          payload.comicId.trim() == comicId.trim()) {
        workTasks.add((task, payload));
      }
    }
    // Capture worker ownership before reading the resource snapshot. A worker
    // already in flight can commit while a file deletion is awaiting disk I/O.
    final active = workTasks.any(
      (entry) => entry.$1.isDownloading || entry.$2.phaseCode == 'cancelling',
    );
    final record = repository.findDownloadRecord(from, comicId);
    if (record == null) return DeleteDownloadedChapterResult.notFound;

    final storedChapters = resolveStoredDownloadChapters(record).toList();
    final chapters = storedChapters
        .map((stored) => adapter.fromStoredMap(stored.toMap()))
        .toList();
    final key = chapterKey.trim();
    var index = chapters.indexWhere((chapter) => chapter.id == key);
    if (index < 0) {
      final aliases = [
        for (var i = 0; i < chapters.length; i++)
          if (chapters[i].effectiveRequestId == key) i,
      ];
      if (aliases.length > 1) throw StateError('Ambiguous chapter identity');
      index = aliases.firstOrNull ?? -1;
    }
    if (index < 0) return DeleteDownloadedChapterResult.notFound;

    final candidate = chapters[index];
    final alias = candidate.effectiveRequestId;
    final ownsAlias = !chapters.indexed.any(
      (entry) =>
          entry.$1 != index &&
          (entry.$2.id == alias || entry.$2.effectiveRequestId == alias),
    );
    final removedTasks = workTasks.where((entry) {
      final key = entry.$2.chapterKey;
      return key == candidate.id || (ownsAlias && key == alias);
    }).toList();
    if (removedTasks.any((entry) => !entry.$1.isCompleted)) {
      throw ActiveChapterDownloadRemoval();
    }

    if (storedChapters.length == 1) {
      // The whole-work path acquires the same lease synchronously and owns
      // the existing cancellation behavior.
      lease.release();
      await deleteWholeComicDownload(from: from, comicId: comicId);
      return DeleteDownloadedChapterResult.wholeComicDeleted;
    }
    if (active) throw ActiveChapterDownloadRemoval();

    storedChapters.removeAt(index);

    final detail = NormalComicAllInfo.fromJson(
      jsonDecode(record.detailJson) as Map<String, dynamic>,
    );
    final updatedDetail = detail.copyWith(
      eps: buildDownloadEps(storedChapters),
      extern: {
        ...detail.extern,
        'downloadChapters': storedChapters.map((e) => e.toMap()).toList(),
      },
    );
    final bound = bindComicDownloadRemoval(from: from, comicId: comicId);
    void check() => _requireExpectedComicVersion(
      bindComicDownloadRemoval(from: from, comicId: comicId),
      bound,
    );
    final stopped = DownloadQueueManager.instance.pendingComicWorkerStop(
      from: from,
      comicId: comicId,
    );
    if (stopped != null) await stopped;
    await runExclusiveStorageOperation(() async {
      for (final (_, payload) in removedTasks) {
        await repository.flushTaskWrites(payload.taskKey);
      }
      void commit() {
        if (objectbox.unifiedDownloadBox.get(record.id) != null) {
          record
            ..chapters = jsonEncode(
              storedChapters.map((e) => e.toMap()).toList(),
            )
            ..detailJson = jsonEncode(updatedDetail.toJson())
            ..updatedAt = DateTime.now().toUtc();
          objectbox.unifiedDownloadBox.put(record);
        }
        objectbox.downloadTaskBox.removeMany(
          removedTasks.map((entry) => entry.$1.id).toList(),
        );
      }

      await removeOwnedDownloadAssets(
        keeping: [
          for (final stored in storedChapters)
            ...chapterDownloadAssets(
              from,
              comicId,
              adapter.fromStoredMap(stored.toMap()),
              stored.images.map((image) => image.path),
            ),
          for (final (task, payload) in workTasks)
            if (!task.isCompleted)
              ...chapterDownloadAssets(
                from,
                comicId,
                adapter.fromTaskRef(payload.chapterRef),
                payload.imagePaths,
              ),
        ],
        removing: [
          ...chapterDownloadAssets(
            from,
            comicId,
            candidate,
            candidate.images
                .where((image) => image.extern['downloadSkipped'] != true)
                .map((image) => image.path),
          ),
          for (final (_, payload) in removedTasks)
            ...chapterDownloadAssets(
              from,
              comicId,
              adapter.fromTaskRef(payload.chapterRef),
              payload.imagePaths,
            ),
        ],
        check: check,
        commit: commit,
      );
    });

    logger.i('已删除下载章节: $from:$comicId chapter=$chapterKey');
    return DeleteDownloadedChapterResult.chapterDeleted;
  } finally {
    lease.release();
  }
}

/// 删除整本漫画的下载记录、书架链接与文件，可复用的公共逻辑。
///
/// 与书架“删除下载”、漫画入口“删除下载”行为一致。
Future<void> deleteWholeComicDownload({
  required String from,
  required String comicId,
  Future<void> Function(String from, String comicId) removeFiles =
      _removeOwnedComicFiles,
}) async {
  final uniqueKey = buildDownloadTaskKey(from, comicId);
  // Legacy detail/bookshelf entry points share the same execution ownership as
  // download-center removal. New requests wait, then become a new generation.
  final lease = DownloadResourceLifecycle.acquireRemoval(
    DownloadResourceLifecycle.comic(uniqueKey),
  );
  try {
    // 先取消同漫画的所有排队任务，否则 worker 跑起来会重建下载记录。
    final pendingQuery = objectbox.downloadTaskBox
        .query(
          DownloadTask_.isCompleted
              .equals(false)
              .and(DownloadTask_.comicId.equals(comicId.trim())),
        )
        .build();
    late final List<DownloadTask> pending;
    try {
      pending = pendingQuery.find();
    } finally {
      pendingQuery.close();
    }
    for (final task in pending) {
      String? chapterKey;
      try {
        final payload = task.taskInfo;
        if (payload == null ||
            payload.from.trim() != from.trim() ||
            payload.stateCode == 'failed') {
          continue;
        }
        chapterKey = payload.chapterKey;
      } catch (_) {
        chapterKey = null;
      }
      if (chapterKey == null || chapterKey.isEmpty) {
        continue;
      }
      await DownloadQueueManager.instance.cancelChapterTask(
        from: from,
        comicId: comicId,
        chapterKey: chapterKey,
      );
    }
    final stopped = DownloadQueueManager.instance.pendingComicWorkerStop(
      from: from,
      comicId: comicId,
    );
    if (stopped != null) await stopped;
    await runExclusiveStorageOperation(() async {
      final bound = bindComicDownloadRemoval(from: from, comicId: comicId);
      await _removeBoundComicDownload(bound, removeFiles);
    });
    logger.i('已删除整本下载: $uniqueKey');
  } finally {
    lease.release();
  }
}

/// Download removal is one user action: owned files, persistent resource
/// and matching transfer rows.
/// An active or cancelling transfer must be stopped explicitly before removal.
class ComicDownloadRemovalToken {
  ComicDownloadRemovalToken._(
    this.from,
    this.comicId,
    Map<int, String> tasks,
    Map<int, String> resources,
    Map<int, String> links,
  ) : _tasks = Map.unmodifiable(tasks),
      _resources = Map.unmodifiable(resources),
      _links = Map.unmodifiable(links);
  final String from, comicId;
  final Map<int, String> _tasks, _resources, _links;
}

/// Read-only confirmation token. No lease is held while the user decides.
ComicDownloadRemovalToken bindComicDownloadRemoval({
  required String from,
  required String comicId,
}) {
  const repository = DownloadTaskRepository();
  final uniqueKey = buildDownloadTaskKey(from, comicId);
  final tasks = repository.getAll().where((task) {
    final payload = repository.readPayload(task);
    return payload?.from.trim() == from.trim() &&
        payload?.comicId.trim() == comicId.trim();
  });
  final record = repository.findDownloadRecord(from, comicId);
  final query = objectbox.comicLinkBox
      .query(
        ComicLink_.comicUniqueKey
            .equals(uniqueKey)
            .and(ComicLink_.typeData.equals(ComicFolderType.download.name)),
      )
      .build();
  try {
    return ComicDownloadRemovalToken._(
      from,
      comicId,
      {for (final task in tasks) task.id: jsonEncode(task.toJson())},
      {if (record != null) record.id: jsonEncode(record.toJson())},
      {for (final link in query.find()) link.id: jsonEncode(link.toJson())},
    );
  } finally {
    query.close();
  }
}

void _requireExpectedComicVersion(
  ComicDownloadRemovalToken current,
  ComicDownloadRemovalToken expected,
) {
  if (current.from != expected.from || current.comicId != expected.comicId) {
    throw ArgumentError('Download removal token belongs to a different work');
  }
  bool subset(Map<int, String> values, Map<int, String> bound) =>
      values.entries.every((entry) => bound[entry.key] == entry.value);
  if (!subset(current._tasks, expected._tasks) ||
      !subset(current._resources, expected._resources) ||
      !subset(current._links, expected._links)) {
    throw StateError(
      'Download changed after confirmation; retry with the current resource',
    );
  }
}

/// Recheck a read-only confirmation snapshot without taking another lease.
void requireExpectedComicDownloadRemoval(
  ComicDownloadRemovalToken current,
  ComicDownloadRemovalToken expected,
) => _requireExpectedComicVersion(current, expected);

Future<void> removeComicDownload({
  required String from,
  required String comicId,
  ComicDownloadRemovalToken? expected,
}) => const ComicDownloadRemoval().remove(
  from: from,
  comicId: comicId,
  expected: expected,
);

Future<void> _removeOwnedComicFiles(String from, String comicId) =>
    deleteComicDownloadDirectory(from, comicId, strict: true);

Iterable<DownloadTaskJson> _removableComicTasks(
  ComicDownloadRemovalToken bound,
) sync* {
  const repository = DownloadTaskRepository();
  final tasks = bound._tasks.keys
      .map(objectbox.downloadTaskBox.get)
      .whereType<DownloadTask>();
  for (final task in tasks) {
    final payload = repository.readPayload(task);
    if (payload == null) continue;
    if (payload.phaseCode == 'cancelling' ||
        task.isDownloading ||
        (!task.isCompleted &&
            !{'failed', 'paused'}.contains(payload.stateCode))) {
      throw StateError('Download is still active');
    }
    yield payload;
  }
}

Future<void> _removeBoundComicDownload(
  ComicDownloadRemovalToken bound,
  Future<void> Function(String from, String comicId) removeFiles,
) async {
  const repository = DownloadTaskRepository();
  for (final payload in _removableComicTasks(bound)) {
    await repository.flushTaskWrites(payload.taskKey);
  }
  void check() => _requireExpectedComicVersion(
    bindComicDownloadRemoval(from: bound.from, comicId: bound.comicId),
    bound,
  );
  check();
  await removeFiles(bound.from, bound.comicId);
  objectbox.store.runInTransaction(TxMode.write, () {
    check();
    objectbox.unifiedDownloadBox.removeMany(bound._resources.keys.toList());
    objectbox.comicLinkBox.removeMany(bound._links.keys.toList());
    objectbox.downloadTaskBox.removeMany(bound._tasks.keys.toList());
  });
  try {
    await DownloadWorkPins.forget(
      'comic:${buildDownloadTaskKey(bound.from, bound.comicId)}',
    );
  } catch (_) {
    // File and record removal has already committed.
  }
}

/// Injectable file boundary also allows offline tests to exercise real database
/// replacement while removal is suspended in file I/O.
class ComicDownloadRemoval {
  const ComicDownloadRemoval({this.removeFiles = _removeOwnedComicFiles});
  final Future<void> Function(String from, String comicId) removeFiles;

  Future<void> remove({
    required String from,
    required String comicId,
    ComicDownloadRemovalToken? expected,
  }) async {
    final uniqueKey = buildDownloadTaskKey(from, comicId);
    final lease = DownloadResourceLifecycle.acquireRemoval(
      DownloadResourceLifecycle.comic(uniqueKey),
    );
    try {
      final stopped = DownloadQueueManager.instance.pendingComicWorkerStop(
        from: from,
        comicId: comicId,
      );
      if (stopped != null) {
        final bound = bindComicDownloadRemoval(from: from, comicId: comicId);
        if (expected != null) _requireExpectedComicVersion(bound, expected);
        // Validate all states before waiting on the worker that owns this work.
        _removableComicTasks(bound).toList();
        await stopped;
      }
      await runExclusiveStorageOperation(() async {
        final bound = bindComicDownloadRemoval(from: from, comicId: comicId);
        if (expected != null) _requireExpectedComicVersion(bound, expected);
        await _removeBoundComicDownload(bound, removeFiles);
      });
    } finally {
      lease.release();
    }
  }
}

class UnknownDownloadTaskRemovalToken {
  UnknownDownloadTaskRemovalToken._(this.id, this._fingerprint);
  final int id;
  final String? _fingerprint;
}

/// Malformed legacy rows authorize only their exact row ID, never a work/files.
UnknownDownloadTaskRemovalToken bindUnknownDownloadTaskRemoval(int id) {
  final task = objectbox.downloadTaskBox.get(id);
  if (task != null &&
      const DownloadTaskRepository().readPayload(task) != null) {
    throw ArgumentError('Readable tasks must use their resource identity');
  }
  // Do not call toJson: its taskInfo getter may throw on the malformed payload.
  return UnknownDownloadTaskRemovalToken._(
    id,
    task == null ? null : _unknownTaskFingerprint(task),
  );
}

String _unknownTaskFingerprint(DownloadTask task) => jsonEncode([
  task.id,
  task.comicId,
  task.comicName,
  task.isCompleted,
  task.isDownloading,
  task.status,
  task.dbTaskInfoStr,
]);

Future<void> removeUnknownDownloadTasks({
  required Iterable<UnknownDownloadTaskRemovalToken> expected,
}) async {
  final bound = List<UnknownDownloadTaskRemovalToken>.unmodifiable(expected);
  objectbox.store.runInTransaction(TxMode.write, () {
    for (final token in bound) {
      final current = objectbox.downloadTaskBox.get(token.id);
      if (current == null) continue;
      if (token._fingerprint != _unknownTaskFingerprint(current) ||
          current.isDownloading ||
          !current.isCompleted) {
        throw StateError('Legacy download task changed after confirmation');
      }
    }
    for (final token in bound) {
      objectbox.downloadTaskBox.remove(token.id);
    }
  });
}
