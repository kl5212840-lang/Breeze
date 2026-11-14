import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(() { objectbox.downloadTaskBox.removeAll(); TestObjectBoxHelper.cleanComicFolderBoxes(); });
  const source = 'legacy-delete-fixture', comic = 'work';
  const next = DownloadTaskJson(from: source, comicId: comic, comicName: 'Work',
    stateCode: 'queued', chapterRef: DownloadChapterTaskRef(logicalKey: 'new-chapter'));
  final identity = DownloadResourceLifecycle.comic(buildDownloadTaskKey(source, comic));

  Future<DownloadTask> newRequestArrived() => objectbox.downloadTaskBox.query()
    .watch(triggerImmediately: true)
    .map((query) => query.find().where((task) => task.taskInfo?.taskKey == next.taskKey).toList())
    .firstWhere((rows) => rows.isNotEmpty).then((rows) => rows.single);

  test('new same-work download waits for legacy directory removal and is not marked fileRemoved', () async {
    final directory = await Directory.systemTemp.createTemp('legacy-removal-race-');
    addTearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });
    final oldFile = File('${directory.path}/old.jpg');
    await oldFile.writeAsBytes([1, 2, 3]);
    final deleting = Completer<void>(), finishDeletion = Completer<void>();
    final removal = deleteWholeComicDownload(from: source, comicId: comic,
      removeFiles: (from, id) async {
        expect(from, source); expect(id, comic);
        deleting.complete();
        await finishDeletion.future;
        await directory.delete(recursive: true);
      });
    await deleting.future;
    final lease = DownloadResourceLifecycle.removing(identity);
    expect(lease, isNotNull);
    final arrived = newRequestArrived();
    DownloadQueueManager.instance.addTask(next);
    expect(objectbox.downloadTaskBox.getAll(), isEmpty,
      reason: 'new request cannot enter the directory while old deletion owns it');
    expect(await oldFile.exists(), true);
    finishDeletion.complete();
    await removal;
    final queued = await arrived;
    expect(DownloadResourceLifecycle.removing(identity), null);
    expect(queued.isCompleted, false);
    expect(queued.isDownloading, false);
    expect(queued.taskInfo!.stateCode, 'queued');
    expect(queued.taskInfo!.phaseCode, isNot('fileRemoved'));
    // Its directory can now be recreated without the old deletion removing it.
    await directory.create();
    final newFile = File('${directory.path}/new.jpg');
    await newFile.writeAsBytes([4, 5]);
    expect(await newFile.readAsBytes(), [4, 5]);
  });
  test('failed legacy deletion releases the same lease and preserves the later request', () async {
    final deleting = Completer<void>(), failDeletion = Completer<void>();
    final removal = deleteWholeComicDownload(from: source, comicId: comic,
      removeFiles: (_, __) async { deleting.complete(); await failDeletion.future; throw FileSystemException('fixture deletion failed'); });
    final failure = expectLater(removal, throwsA(isA<FileSystemException>()));
    await deleting.future;
    final arrived = newRequestArrived();
    DownloadQueueManager.instance.addTask(next);
    expect(objectbox.downloadTaskBox.getAll(), isEmpty);
    failDeletion.complete();
    await failure;
    final queued = await arrived;
    expect(DownloadResourceLifecycle.removing(identity), null);
    expect(queued.taskInfo!.stateCode, 'queued');
  });
}
