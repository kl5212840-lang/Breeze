import 'dart:convert';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/comic_download_task.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  DownloadTask makeTask() {
    final task = DownloadTask()
      ..isDownloading = true
      ..taskInfo = const DownloadTaskJson(
        from: 'source',
        comicId: 'work',
        comicName: 'Work',
        attempt: 3,
        stateCode: 'running',
        phaseCode: 'committingChapter',
        completedImages: 2,
        totalImages: 2,
        imagePaths: ['one.jpg', 'two.jpg'],
        chapterRef: DownloadChapterTaskRef(logicalKey: 'chapter'),
      );
    objectbox.downloadTaskBox.put(task);
    return task;
  }

  Map<String, dynamic> args(DownloadTask task) => {
    'taskId': task.id,
    'taskKey': task.taskInfo!.taskKey,
    'attempt': 3,
    'completedImages': 2,
    'reusedImages': 1,
    'imagePaths': ['one.jpg', 'two.jpg'],
    'entity': {
      'id': 0,
      'uniqueKey': 'source|work',
      'source': 'source',
      'comicId': 'work',
      'title': 'Work',
      'description': '',
      'cover': '{}',
      'creator': '[]',
      'titleMeta': '{}',
      'metadata': '{}',
      'totalViews': 0,
      'totalLikes': 0,
      'totalComments': 0,
      'isFavourite': false,
      'isLiked': false,
      'allowComment': false,
      'allowLike': false,
      'allowFavorite': false,
      'allowDownload': true,
      'chapters': '[]',
      'detailJson': '{}',
      'storageRoot': '/fixture',
      'createdAtMs': 1,
      'nowMs': 2,
    },
    'linkUniqueKey': 'source|work|download',
    'linkComicKey': 'source|work',
    'deviceId': 'fixture',
  };
  int commit(Map<String, dynamic> request) => objectbox.store.runInTransaction(
    TxMode.write,
    () => commitDownloadChapterOnWorker(objectbox.store, request),
  );

  test(
    'cancel wins before commit: no resource or download link is resurrected',
    () {
      final task = makeTask(), request = <String, dynamic>{};
      request.addAll(args(task));
      task
        ..isCompleted = true
        ..isDownloading = false
        ..taskInfo = task.taskInfo!.copyWith(
          stateCode: 'cancelled',
          phaseCode: 'cancelling',
        );
      objectbox.downloadTaskBox.put(task);
      expect(commit(request), -1);
      expect(objectbox.unifiedDownloadBox.getAll(), isEmpty);
      expect(objectbox.comicLinkBox.getAll(), isEmpty);
      expect(
        objectbox.downloadTaskBox.get(task.id)!.taskInfo!.stateCode,
        'cancelled',
      );
    },
  );
  test(
    'commit publishes the final page progress even with a stale checkpoint',
    () {
      final task = makeTask();
      task.taskInfo = task.taskInfo!.copyWith(
        completedImages: 1,
        reusedImages: 0,
        imagePaths: ['one.jpg'],
      );
      objectbox.downloadTaskBox.put(task);
      expect(commit(args(task)), 0);
      final current = objectbox.downloadTaskBox.get(task.id)!;
      expect(current.isCompleted, true);
      expect(current.isDownloading, false);
      expect(current.taskInfo!.stateCode, 'completed');
      expect(current.taskInfo!.attempt, 3);
      expect(current.taskInfo!.imagePaths, ['one.jpg', 'two.jpg']);
      expect(current.taskInfo!.completedImages, 2);
      expect(current.taskInfo!.reusedImages, 1);
      expect(current.taskInfo!.totalImages, 2);
      expect(objectbox.unifiedDownloadBox.getAll(), hasLength(1));
      expect(objectbox.comicLinkBox.getAll(), hasLength(1));
      expect(
        commit(args(task)),
        -1,
        reason: 'duplicate late worker cannot commit twice',
      );
    },
  );
  test(
    'deleted or retried task rejects the old worker without touching its new attempt',
    () {
      final task = makeTask(), request = <String, dynamic>{};
      request.addAll(args(task));
      task.taskInfo = task.taskInfo!.copyWith(attempt: 4);
      objectbox.downloadTaskBox.put(task);
      expect(commit(request), -1);
      expect(objectbox.downloadTaskBox.get(task.id)!.taskInfo!.attempt, 4);
      objectbox.downloadTaskBox.remove(task.id);
      expect(commit(request), -1);
      expect(objectbox.unifiedDownloadBox.getAll(), isEmpty);
    },
  );
  test(
    'late checkpoint cannot overwrite cancellation or a newer attempt',
    () async {
      const repository = DownloadTaskRepository();
      final task = makeTask();
      final old = task.taskInfo!;
      await repository.putTaskWriteBackground(
        taskKey: old.taskKey,
        taskId: task.id,
        expectedAttempt: 3,
        requireRunning: true,
        payloadJson: jsonEncode(old.copyWith(completedImages: 1).toJson()),
      );
      expect(
        objectbox.downloadTaskBox.get(task.id)!.taskInfo!.completedImages,
        1,
      );
      task
        ..isCompleted = true
        ..isDownloading = false
        ..taskInfo = old.copyWith(
          stateCode: 'cancelled',
          phaseCode: 'cancelled',
        );
      objectbox.downloadTaskBox.put(task);
      await repository.putTaskWriteBackground(
        taskKey: old.taskKey,
        taskId: task.id,
        expectedAttempt: 3,
        requireRunning: true,
        payloadJson: jsonEncode(old.toJson()),
      );
      expect(
        objectbox.downloadTaskBox.get(task.id)!.taskInfo!.stateCode,
        'cancelled',
      );
      task
        ..isCompleted = false
        ..isDownloading = true
        ..taskInfo = old.copyWith(attempt: 4, completedImages: 0);
      objectbox.downloadTaskBox.put(task);
      await repository.putTaskWriteBackground(
        taskKey: old.taskKey,
        taskId: task.id,
        expectedAttempt: 3,
        requireRunning: true,
        payloadJson: jsonEncode(old.toJson()),
      );
      final current = objectbox.downloadTaskBox.get(task.id)!.taskInfo!;
      expect(current.attempt, 4);
      expect(current.completedImages, 0);
    },
  );
}
