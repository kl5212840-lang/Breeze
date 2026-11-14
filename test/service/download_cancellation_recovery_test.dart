import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _payload = DownloadTaskJson(
  from: 'cancel-recovery-fixture',
  comicId: 'work',
  comicName: 'Work',
  chapterRef: DownloadChapterTaskRef(
    logicalKey: 'chapter',
    storageChapterId: 'chapter',
  ),
);
const _page = 'page.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(useIsolatedDownloadFixture);
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    objectbox.unifiedDownloadBox.removeAll();
  });

  final queue = DownloadQueueManager.instance;
  Future<void> cancelChapter() => queue.cancelChapterTask(
    from: _payload.from,
    comicId: _payload.comicId,
    chapterKey: _payload.chapterKey,
  );

  int seedTask({
    required bool interruptedCancellation,
    DownloadTaskJson payload = _payload,
    List<String> paths = const [_page],
  }) {
    return objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = payload.comicId
        ..comicName = payload.comicName
        ..isCompleted = interruptedCancellation
        ..taskInfo = payload.copyWith(
          stateCode: interruptedCancellation ? 'running' : 'queued',
          phaseCode: interruptedCancellation ? 'cancelling' : 'resume',
          imagePaths: paths,
          attempt: 1,
        ),
    );
  }

  Future<File> writePage([
    String path = _page,
    DownloadTaskJson payload = _payload,
  ]) async {
    final candidate = await DownloadAssetStore(
      from: payload.from,
      path: path,
      cartoonId: payload.comicId,
      chapterId: payload.chapterKey,
      storageChapterId: payload.chapterRef.storageChapterId,
      pictureType: PictureType.page,
    ).canonicalDownloadCandidate();
    await DownloadAssetStore.writeBytesAtomically(
      Uint8List.fromList([1]),
      finalPath: candidate.path,
    );
    return File(candidate.path);
  }

  test(
    'stop and delete reports a file failure and removes a separate work',
    () async {
      final original = await writePage('intact.png');
      final invalid = await writePage('invalid.png');
      await invalid.delete();
      await Directory(invalid.path).create();
      final badId = seedTask(
        interruptedCancellation: false,
        paths: ['intact.png', 'invalid.png'],
      );
      final other = _payload.copyWith(comicId: 'other-work');
      final owned = await writePage(_page, other);
      final ownTemporary = await File(
        DownloadAssetStore.temporaryPathFor(owned.path, taskId: other.taskKey),
      ).writeAsString('owned temporary');
      final unrelated = await writePage('unrelated.png');
      final unrelatedTemporary = await File(
        DownloadAssetStore.temporaryPathFor(
          unrelated.path,
          taskId: other.taskKey,
        ),
      ).writeAsString('outside the selected path');
      final goodId = seedTask(interruptedCancellation: false, payload: other);

      final receipt = await queue.stopAndDeleteTasks([
        objectbox.downloadTaskBox.get(badId)!,
        objectbox.downloadTaskBox.get(goodId)!,
      ]);
      expect(receipt.removed, {goodId});
      expect(receipt.skipped, isEmpty);
      expect(receipt.failures.keys, [badId]);
      expect(receipt.failures[badId], isA<FileSystemException>());
      expect(objectbox.downloadTaskBox.get(goodId), isNull);
      expect(await owned.exists(), isFalse);
      expect(await ownTemporary.exists(), isFalse);
      expect(
        await unrelatedTemporary.readAsString(),
        'outside the selected path',
      );
      final paused = objectbox.downloadTaskBox.get(badId)!;
      expect(paused.taskInfo!.stateCode, 'paused');
      expect(paused.taskInfo!.phaseCode, 'userPaused');
      expect(paused.taskInfo!.imagePaths, ['intact.png', 'invalid.png']);
      expect(queue.canResumeTask(paused), isTrue);
      expect(await original.readAsBytes(), [1]);
      expect(await Directory(invalid.path).exists(), isTrue);
    },
  );

  test(
    'deletion waiting for storage skips a newly created same-chapter task',
    () async {
      const deadline = Duration(seconds: 5);
      final page = await writePage();
      final oldId = seedTask(interruptedCancellation: false);
      final entered = Completer<void>(), release = Completer<void>();
      final storage = runExclusiveStorageOperation(() async {
        entered.complete();
        await release.future;
      });
      await entered.future.timeout(deadline);
      Future<ComicTaskDeletionReceipt>? deleting;
      try {
        deleting = queue.stopAndDeleteTasks([
          objectbox.downloadTaskBox.get(oldId)!,
        ]);
        expect(
          objectbox.downloadTaskBox.get(oldId)!.taskInfo!.phaseCode,
          downloadTaskDeletionPhase,
        );
        final nextId = seedTask(interruptedCancellation: false);
        final next = objectbox.downloadTaskBox.get(nextId)!;
        release.complete();
        final receipt = await deleting.timeout(deadline);
        expect(receipt.removed, isEmpty);
        expect(receipt.skipped, {oldId});
        expect(receipt.failures, isEmpty);
        expect(
          objectbox.downloadTaskBox.get(nextId)!.dbTaskInfoStr,
          next.dbTaskInfoStr,
        );
        expect(await page.readAsBytes(), [1]);
      } finally {
        if (!release.isCompleted) release.complete();
        await storage.timeout(deadline);
        if (deleting != null) await deleting.timeout(deadline);
      }
    },
  );

  test('an interrupted deletion comes back as a manageable pause', () async {
    final page = await writePage();
    final id = seedTask(interruptedCancellation: false);
    final task = objectbox.downloadTaskBox.get(id)!;
    objectbox.downloadTaskBox.put(
      task
        ..taskInfo = task.taskInfo!.copyWith(
          stateCode: 'paused',
          phaseCode: downloadTaskDeletionPhase,
        ),
    );
    queue.resetStuckTasks();

    final paused = objectbox.downloadTaskBox.get(id)!;
    expect(paused.taskInfo!.phaseCode, 'userPaused');
    expect(paused.taskInfo!.attempt, 1);
    expect(queue.canResumeTask(paused), isTrue);
    expect(await page.readAsBytes(), [1]);
  });

  test('same-chapter requeue waits for cancellation file cleanup', () async {
    final page = await writePage();
    final id = seedTask(interruptedCancellation: false);
    final cancelling = cancelChapter();
    try {
      queue.addTask(_payload);
      expect(objectbox.downloadTaskBox.count(), 1);
      expect(
        objectbox.downloadTaskBox.get(id)!.taskInfo!.phaseCode,
        'cancelling',
      );
    } finally {
      await cancelling;
    }
    expect(await page.exists(), isFalse);
    final rows = objectbox.downloadTaskBox.getAll();
    expect(rows, hasLength(2));
    expect(
      rows.singleWhere((row) => row.id == id).taskInfo!.stateCode,
      'cancelled',
    );
    expect(
      rows.singleWhere((row) => row.id != id).taskInfo!.stateCode,
      'queued',
    );
  });

  test(
    'startup finishes persisted cancellation and clears its old files',
    () async {
      final page = await writePage();
      final temporary = await File(
        DownloadAssetStore.temporaryPathFor(
          page.path,
          taskId: _payload.taskKey,
        ),
      ).writeAsString('old partial download');
      final id = seedTask(interruptedCancellation: true);

      queue.resetStuckTasks();
      await cancelChapter(); // Joins the same cancellation cleanup.

      final row = objectbox.downloadTaskBox.get(id)!;
      expect(row.isCompleted, isTrue);
      expect(row.isDownloading, isFalse);
      expect(row.taskInfo!.stateCode, 'cancelled');
      expect(row.taskInfo!.phaseCode, 'cancelled');
      expect(await page.exists(), isFalse);
      expect(await temporary.exists(), isFalse);
    },
  );

  test('startup preserves a newer same-chapter checkpoint', () async {
    final page = await writePage();
    final oldId = seedTask(interruptedCancellation: true);
    final newId = seedTask(interruptedCancellation: false);

    queue.resetStuckTasks();

    expect(
      objectbox.downloadTaskBox.get(oldId)!.taskInfo!.stateCode,
      'cancelled',
    );
    expect(objectbox.downloadTaskBox.get(newId)!.taskInfo!.stateCode, 'queued');
    expect(await page.exists(), isTrue);
  });

  test(
    'cancelling a queued chapter preserves a completed sibling page',
    () async {
      final shared = await writePage();
      final exclusive = await writePage('exclusive.png');
      final recordId = objectbox.unifiedDownloadBox.put(
        createTestDownload('${_payload.from}:${_payload.comicId}')
          ..source = _payload.from
          ..comicId = _payload.comicId
          ..chapters = jsonEncode([
            {
              'id': 'finished-sibling',
              'storageChapterId': _payload.chapterRef.storageChapterId,
              'images': [
                {'path': File('old/images/$_page').absolute.path},
              ],
            },
          ]),
      );
      final id = seedTask(
        interruptedCancellation: false,
        paths: [File('reuse/$_page').absolute.path, 'exclusive.png'],
      );

      await cancelChapter();

      expect(await shared.readAsBytes(), [1]);
      expect(await exclusive.exists(), isFalse);
      expect(objectbox.unifiedDownloadBox.get(recordId), isNotNull);
      expect(
        objectbox.downloadTaskBox.get(id)!.taskInfo!.stateCode,
        'cancelled',
      );
    },
  );

  test(
    'recovered cancellation preserves a sibling checkpoint in the same bucket',
    () async {
      final shared = await writePage();
      final exclusive = await writePage('exclusive.png');
      final id = seedTask(
        interruptedCancellation: true,
        paths: [_page, 'exclusive.png'],
      );
      final siblingId = seedTask(
        interruptedCancellation: false,
        payload: _payload.copyWith(
          chapterRef: _payload.chapterRef.copyWith(
            logicalKey: 'queued-sibling',
          ),
        ),
        paths: [File('checkpoint/$_page').absolute.path],
      );
      seedTask(
        interruptedCancellation: false,
        payload: _payload.copyWith(
          chapterRef: _payload.chapterRef.copyWith(
            logicalKey: 'other-bucket',
            storageChapterId: 'different-bucket',
          ),
        ),
        paths: ['exclusive.png'],
      );

      queue.resetStuckTasks();
      await cancelChapter();

      expect(await shared.readAsBytes(), [1]);
      expect(await exclusive.exists(), isFalse);
      expect(
        objectbox.downloadTaskBox.get(siblingId)!.taskInfo!.stateCode,
        'queued',
      );
      expect(
        objectbox.downloadTaskBox.get(id)!.taskInfo!.stateCode,
        'cancelled',
      );
    },
  );
}
