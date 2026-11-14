import 'dart:convert';

import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_chapter_assets.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';

export 'package:zephyr/service/download/download_delete_service.dart'
    show ActiveChapterDownloadRemoval;

class ChapterDownloadRemovalToken {
  ChapterDownloadRemovalToken._(
    this.from,
    this.comicId,
    this.chapterKey,
    this.work,
  );
  final String from, comicId, chapterKey;
  final ComicDownloadRemovalToken work;
}

ChapterDownloadRemovalToken bindChapterDownloadRemoval({
  required String from,
  required String comicId,
  required String chapterKey,
}) => ChapterDownloadRemovalToken._(
  from,
  comicId,
  chapterKey,
  bindComicDownloadRemoval(from: from, comicId: comicId),
);

/// Download-center chapter removal. This intentionally does not call the legacy
/// file-only deletion, nor turn a last chapter into whole-work cancellation.
class ChapterDownloadRemoval {
  const ChapterDownloadRemoval({this.stageFile = stageDownloadAssetFile});
  final Future<void> Function(String original, String staged) stageFile;

  Future<void> remove(ChapterDownloadRemovalToken expected) =>
      removeChapters(expected.work, [expected.chapterKey]);

  /// Bind the work once before confirmation and remove the selected chapter
  /// identities in a single lease, without rebinding after each deletion.
  Future<void> removeChapters(
    ComicDownloadRemovalToken expected,
    Iterable<String> chapterKeys,
  ) async {
    final keys = chapterKeys.map((key) => key.trim()).toSet();
    if (keys.isEmpty || keys.contains('')) {
      throw ArgumentError('Empty chapter identity');
    }
    final from = expected.from, comicId = expected.comicId;
    final workKey = buildDownloadTaskKey(from, comicId);
    final lease = DownloadResourceLifecycle.acquireRemoval(
      DownloadResourceLifecycle.comic(workKey),
    );
    const repository = DownloadTaskRepository();
    void check() => requireExpectedComicDownloadRemoval(
      bindComicDownloadRemoval(from: from, comicId: comicId),
      expected,
    );
    List<DownloadTask> removableWorkTasks() {
      final tasks = repository.getAll().where((task) {
        final payload = repository.readPayload(task);
        return payload?.from == from && payload?.comicId == comicId;
      }).toList();
      if (tasks.any((task) {
        final payload = repository.readPayload(task)!;
        return task.isDownloading ||
            payload.phaseCode == 'cancelling' ||
            (!task.isCompleted &&
                !{
                  'failed',
                  'paused',
                  'cancelled',
                  'completed',
                }.contains(payload.stateCode));
      })) {
        throw ActiveChapterDownloadRemoval();
      }
      return tasks;
    }

    try {
      final stopped = DownloadQueueManager.instance.pendingComicWorkerStop(
        from: from,
        comicId: comicId,
      );
      if (stopped != null) {
        check();
        removableWorkTasks();
        await stopped;
      }
      await runExclusiveStorageOperation(() async {
        const adapter = DownloadChapterAdapter();
        check();
        final tasks = removableWorkTasks();
        for (final task in tasks) {
          await repository.flushTaskWrites(
            repository.readPayload(task)!.taskKey,
          );
        }
        check();
        final record = repository.findDownloadRecord(from, comicId);
        final stored = record == null
            ? <UnifiedComicDownloadStoredChapter>[]
            : resolveStoredDownloadChapters(record).toList();
        final mapped = stored
            .map((chapter) => adapter.fromStoredMap(chapter.toMap()))
            .toList();
        // Canonical logical IDs win. Never use order/title/storage identity for
        // destruction; an old request alias must identify exactly one chapter.
        final targets = <String>{};
        final taskKeys = <String>{};
        for (final key in keys) {
          var matches = mapped.where((chapter) => chapter.id == key).toList();
          if (matches.isEmpty) {
            matches = mapped
                .where((chapter) => chapter.effectiveRequestId == key)
                .toList();
          }
          if (matches.length > 1)
            throw StateError('Ambiguous chapter identity');
          final target = matches.firstOrNull;
          if (target == null) {
            taskKeys.add(key);
            continue;
          }
          targets.add(target.id);
          taskKeys.add(target.id);
          final alias = target.effectiveRequestId;
          if (!mapped.any(
            (chapter) =>
                chapter.id != target.id &&
                (chapter.id == alias || chapter.effectiveRequestId == alias),
          )) {
            taskKeys.add(alias);
          }
        }
        bool ownsTask(DownloadTask task) {
          final chapter = adapter.fromTaskRef(
            repository.readPayload(task)!.chapterRef,
          );
          return taskKeys.contains(chapter.id);
        }

        final removedTasks = tasks.where(ownsTask).toList();
        if (targets.isEmpty && removedTasks.isEmpty) return;
        final remaining = [
          for (var i = 0; i < stored.length; i++)
            if (!targets.contains(mapped[i].id)) stored[i],
        ];
        final remainingTasks = tasks.where((task) => !ownsTask(task)).toList();
        String? detail;
        if (record != null && remaining.isNotEmpty) {
          final raw = record.detailJson.trim();
          if (raw.isNotEmpty) {
            final data = jsonDecode(raw);
            if (data is! Map<String, dynamic> ||
                (data['extern'] != null && data['extern'] is! Map)) {
              throw const FormatException('Invalid offline detail');
            }
            final extern = data['extern'] == null
                ? <String, dynamic>{}
                : Map<String, dynamic>.from(data['extern'] as Map);
            detail = jsonEncode({
              ...data,
              'eps': buildDownloadEps(
                remaining,
              ).map((ep) => ep.toJson()).toList(),
              'extern': {
                ...extern,
                'downloadChapters': remaining
                    .map((chapter) => chapter.toMap())
                    .toList(),
              },
            });
          }
        }
        Iterable<DownloadAssetStore> taskAssets(DownloadTask task) {
          final payload = repository.readPayload(task)!;
          return chapterDownloadAssets(
            from,
            comicId,
            adapter.fromTaskRef(payload.chapterRef),
            payload.imagePaths,
          );
        }

        final keep = [
          for (final chapter in remaining)
            ...chapterDownloadAssets(
              from,
              comicId,
              adapter.fromStoredMap(chapter.toMap()),
              chapter.images.map((image) => image.path),
            ),
          ...remainingTasks.expand(taskAssets),
        ];
        final remove = [
          for (final target in mapped.where(
            (chapter) => targets.contains(chapter.id),
          ))
            ...chapterDownloadAssets(
              from,
              comicId,
              target,
              target.images
                  .where((image) => image.extern['downloadSkipped'] != true)
                  .map((image) => image.path),
            ),
          ...removedTasks.expand(taskAssets),
        ];
        if (record != null &&
            targets.isNotEmpty &&
            remaining.isEmpty &&
            remainingTasks.isEmpty &&
            record.cover.trim().isNotEmpty) {
          final cover = jsonDecode(record.cover);
          if (cover is! Map)
            throw const FormatException('Invalid offline cover');
          final rawPath = cover['path'] is String
              ? cover['path'] as String
              : '';
          final extern = cover['extern'];
          final coverPath = rawPath.trim().isNotEmpty
              ? rawPath
              : extern is Map && extern['path'] is String
              ? extern['path'] as String
              : '';
          remove.add(
            DownloadAssetStore(
              from: from,
              cartoonId: comicId,
              chapterId: '',
              path: coverPath,
              pictureType: PictureType.cover,
            ),
          );
        }
        void commit() {
          if (record != null && targets.isNotEmpty) {
            if (remaining.isEmpty) {
              objectbox.unifiedDownloadBox.remove(record.id);
              final query = objectbox.comicLinkBox
                  .query(
                    ComicLink_.comicUniqueKey
                        .equals(workKey)
                        .and(
                          ComicLink_.typeData.equals(
                            ComicFolderType.download.name,
                          ),
                        ),
                  )
                  .build();
              try {
                objectbox.comicLinkBox.removeMany(query.findIds());
              } finally {
                query.close();
              }
            } else {
              record.chapters = jsonEncode(
                remaining.map((chapter) => chapter.toMap()).toList(),
              );
              if (detail != null) record.detailJson = detail;
              record.updatedAt = DateTime.now().toUtc();
              objectbox.unifiedDownloadBox.put(record);
            }
          }
          for (final task in removedTasks)
            objectbox.downloadTaskBox.remove(task.id);
        }

        await removeOwnedDownloadAssets(
          keeping: keep,
          removing: remove,
          check: check,
          commit: commit,
          stageFile: stageFile,
        );
      });
    } finally {
      lease.release();
    }
  }
}
