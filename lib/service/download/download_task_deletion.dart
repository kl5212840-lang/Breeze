import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_chapter_assets.dart';
import 'package:zephyr/service/download/download_chapter_cancellation.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';

class ComicTaskDeletionReceipt {
  ComicTaskDeletionReceipt({
    required Set<int> removed,
    required Set<int> skipped,
    required Map<int, Object> failures,
  }) : removed = Set.unmodifiable(removed),
       skipped = Set.unmodifiable(skipped),
       failures = Map.unmodifiable(failures);

  final Set<int> removed;
  final Set<int> skipped;
  final Map<int, Object> failures;
}

/// The worker and other queue commands can no longer change a fenced row.
bool matchesComicTaskDeletion(DownloadTask expected) {
  final current = objectbox.downloadTaskBox.get(expected.id);
  return current != null &&
      !current.isDownloading &&
      !current.isCompleted &&
      current.dbTaskInfoStr == expected.dbTaskInfoStr;
}

Map<String, int> newestComicTaskIds(Iterable<String> taskKeys) {
  final keys = taskKeys.toSet();
  final newest = <String, int>{};
  const repository = DownloadTaskRepository();
  for (final task in repository.getAll()) {
    final payload = repository.readPayload(task);
    if (payload != null &&
        keys.contains(payload.taskKey) &&
        task.id > (newest[payload.taskKey] ?? 0)) {
      newest[payload.taskKey] = task.id;
    }
  }
  return newest;
}

/// Remove only unfinished task files. The caller holds the work's removal
/// lease and has already waited for every selected writer to settle.
Future<void> removeStoppedComicTasks(List<DownloadTask> expected) async {
  if (expected.isEmpty) return;
  const repository = DownloadTaskRepository();
  const adapter = DownloadChapterAdapter();
  final payloads = [for (final task in expected) repository.readPayload(task)!];
  final source = payloads.first.from.trim();
  final comicId = payloads.first.comicId.trim();
  final selectedIds = {for (final task in expected) task.id};
  final versions = {
    for (var i = 0; i < expected.length; i++)
      payloads[i].taskKey: expected[i].id,
  };
  final storageIds = {
    for (final task in payloads)
      adapter.fromTaskRef(task.chapterRef).effectiveStorageId,
  };
  final removing = [
    for (final task in payloads)
      for (final asset in chapterDownloadAssets(
        source,
        comicId,
        adapter.fromTaskRef(task.chapterRef),
        task.imagePaths,
      ))
        (asset: asset, taskKey: task.taskKey),
  ];

  void check() {
    for (final task in expected) {
      if (!matchesComicTaskDeletion(task)) {
        throw StateError('Download task changed during removal');
      }
    }
    final newest = newestComicTaskIds(versions.keys);
    if (versions.entries.any((entry) => newest[entry.key] != entry.value)) {
      throw StateError('A newer download task owns the chapter');
    }
  }

  await runExclusiveStorageOperation(
    () => withDownloadChapterAssetClaims(payloads, (active) async {
      final keep = <DownloadAssetStore>[
        for (final entry in active.entries)
          for (final path in entry.value)
            if (path.trim().isNotEmpty)
              DownloadAssetStore(
                from: source,
                cartoonId: comicId,
                chapterId: '',
                storageChapterId: entry.key,
                path: path,
                pictureType: PictureType.page,
              ),
      ];
      for (final task in repository.getAll(incompleteOnly: true)) {
        if (selectedIds.contains(task.id)) continue;
        final payload = repository.readPayload(task);
        if (payload == null ||
            payload.from.trim() != source ||
            payload.comicId.trim() != comicId) {
          continue;
        }
        final chapter = adapter.fromTaskRef(payload.chapterRef);
        if (storageIds.contains(chapter.effectiveStorageId)) {
          keep.addAll(
            chapterDownloadAssets(source, comicId, chapter, payload.imagePaths),
          );
        }
      }
      // A sibling committing during this read is protected by its claim or
      // its durable chapter, including an already published copy of the target.
      final query = objectbox.unifiedDownloadBox
          .query(
            UnifiedComicDownload_.uniqueKey.equals(
              buildDownloadTaskKey(source, comicId),
            ),
          )
          .build();
      try {
        final record = query.findFirst();
        if (record != null && !record.deleted) {
          for (final chapter in resolveDownloadChapters(record)) {
            if (!storageIds.contains(chapter.effectiveStorageId)) continue;
            keep.addAll(
              chapterDownloadAssets(
                source,
                comicId,
                chapter,
                chapter.images.map((image) => image.path),
              ),
            );
          }
        }
      } finally {
        query.close();
      }
      await removeOwnedDownloadAssets(
        keeping: keep,
        removing: removing.map((entry) => entry.asset),
        removingCanonicalOnly: true,
        temporaryFiles: removing,
        checkEachFile: false,
        check: check,
        commit: () {
          repository.removeSupersededCancelledRecordsInTransaction(
            beforeIds: versions,
          );
          final count = objectbox.downloadTaskBox.removeMany(
            selectedIds.toList(),
          );
          if (count != selectedIds.length) {
            throw StateError('Download task deletion was incomplete');
          }
        },
      );
    }),
  );
}
