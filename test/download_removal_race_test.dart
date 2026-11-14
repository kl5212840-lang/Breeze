import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import 'download_fixture.dart';
import 'test_helper.dart';

const _source = 'removal-race-fixture', _comic = 'opaque:work';
const _payload = DownloadTaskJson(from: _source, comicId: _comic, comicName: '绑定作品',
  chapterRef: DownloadChapterTaskRef(chapterId: 'chapter:1', title: '第一章'));

DownloadTask _done() => DownloadTask()..comicId = _comic..comicName = '绑定作品'
  ..isCompleted = true..taskInfo = _payload.copyWith(stateCode: 'completed');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
  });
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  Future<Directory> seedComic() async {
    final directory = await createDownloadFixture(_source, _comic);
    await File('${directory.path}/page.png').writeAsString('old');
    objectbox.downloadTaskBox.put(_done());
    objectbox.unifiedDownloadBox.put(createTestDownload('$_source:$_comic')
      ..source = _source..comicId = _comic);
    ComicLinkService.addComic('$_source:$_comic', null, ComicFolderType.download);
    return directory;
  }

  test('same-work add during file I/O waits until bound removal commits, then survives', () async {
    final directory = await seedComic();
    final service = ComicDownloadRemoval(removeFiles: (source, comic) async {
      DownloadQueueManager.instance.addTask(_payload);
      expect(objectbox.downloadTaskBox.getAll().where((row) => !row.isCompleted), isEmpty,
        reason: 'a newly requested generation cannot start inside old file removal');
      await directory.delete(recursive: true);
    });
    await service.remove(from: _source, comicId: _comic);
    await Future<void>.delayed(Duration.zero);
    final latest = objectbox.downloadTaskBox.getAll();
    expect(latest, hasLength(1));
    expect(latest.single.isCompleted, isFalse);
    expect(latest.single.taskInfo!.taskKey, _payload.taskKey);
    await directory.create(recursive: true);
    await File('${directory.path}/page.png').writeAsString('new generation');
    await Future<void>.delayed(Duration.zero);
    expect(await File('${directory.path}/page.png').readAsString(), 'new generation',
      reason: 'association deletion schedules no late directory remover');
  });

  test('replacement resource and completed task arriving during I/O are not rebound into old deletion', () async {
    final directory = await seedComic();
    final originalTaskId = objectbox.downloadTaskBox.getAll().single.id;
    final service = ComicDownloadRemoval(removeFiles: (source, comic) async {
      await directory.delete(recursive: true);
      await directory.create(recursive: true);
      await File('${directory.path}/page.png').writeAsString('new resource');
      final record = objectbox.unifiedDownloadBox.getAll().single;
      record..title = '新一代资源'..updatedAt = record.updatedAt.add(const Duration(seconds: 1));
      objectbox.unifiedDownloadBox.put(record);
      objectbox.downloadTaskBox.put(_done());
    });
    await expectLater(service.remove(from: _source, comicId: _comic), throwsStateError);
    expect(objectbox.unifiedDownloadBox.getAll().single.title, '新一代资源');
    expect(objectbox.downloadTaskBox.count(), 2);
    expect(objectbox.downloadTaskBox.get(originalTaskId), isNotNull);
    expect(await File('${directory.path}/page.png').readAsString(), 'new resource');
  });

  test('file failure retains bound database data and releases the work lease', () async {
    await seedComic();
    final service = ComicDownloadRemoval(removeFiles: (_, _) =>
      Future<void>.error(const FileSystemException('controlled I/O failure')));
    await expectLater(service.remove(from: _source, comicId: _comic), throwsA(isA<FileSystemException>()));
    expect(objectbox.unifiedDownloadBox.count(), 1);
    expect(objectbox.downloadTaskBox.count(), 1);
    DownloadQueueManager.instance.addTask(_payload);
    expect(objectbox.downloadTaskBox.count(), 2,
      reason: 'failed removal cannot retain a lifecycle lease');
  });

  Future<({String id, String key, Uri page})> seedVideo() async {
    final page = Uri.parse('https://removal.test/watch?v=123');
    final id = VideoLocalResources.identity(_source, page, '720p');
    final key = await VideoExportRecords.beginTransfer(source: _source, video: page,
      title: '旧视频', quality: '720p', resourceId: id);
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112, ...List.filled(16, 0)]));
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: _source,
      video: page, title: '旧视频', quality: '720p', taskKey: key);
    await VideoExportRecords.updateTransfer(key, received: 24, total: 24,
      status: 'saved', terminal: true, resourceId: id);
    await VideoExportRecords.add(source: _source, video: page, title: '旧导出', quality: '720p');
    return (id: id, key: key, page: page);
  }

  test('video execution lease blocks new transfer and preserves a later same-key export acknowledgment', () async {
    final video = await seedVideo();
    final service = VideoDownloadRemoval(removeResource: (lease) async {
      expect(VideoLocalResources.tryHold(video.id), isFalse);
      await expectLater(VideoExportRecords.beginTransfer(source: _source, video: video.page,
        title: '新传输', quality: '720p', resourceId: video.id), throwsStateError);
      await VideoExportRecords.add(source: _source, video: video.page,
        title: '稍后导出', quality: '720p');
      await lease.remove();
    });
    await service.remove(source: _source, page: video.page, quality: '720p');
    expect(await (await VideoLocalResources.file(video.id)).exists(), isFalse);
    expect(await VideoLocalResources.read(), isEmpty);
    final rows = await VideoExportRecords.readTasks();
    expect(rows.any((row) => row['key'] == video.key), isFalse);
    expect((await VideoExportRecords.read()).single['title'], '稍后导出');
    expect(VideoLocalResources.tryHold(video.id), isTrue);
    VideoLocalResources.release(video.id);
  });

  test('video file failure leaves log and index intact and releases the resource lease', () async {
    final video = await seedVideo();
    final service = VideoDownloadRemoval(removeResource: (_) =>
      Future<void>.error(const FileSystemException('controlled I/O failure')));
    await expectLater(service.remove(source: _source, page: video.page, quality: '720p'),
      throwsA(isA<FileSystemException>()));
    expect((await VideoExportRecords.readTasks()).any((row) => row['key'] == video.key), isTrue);
    expect((await VideoLocalResources.read()).single['available'], isTrue);
    expect(VideoLocalResources.tryHold(video.id), isTrue);
    VideoLocalResources.release(video.id);
  });

  test('invalid video index fails before the callback and releases both execution holds', () async {
    final video = await seedVideo();
    await File('${(await VideoLocalResources.root()).path}/index.json').writeAsString('{}');
    VideoLocalResources.invalidate();
    await expectLater(removeVideoDownload(source: _source, page: video.page, quality: '720p'),
      throwsA(isA<FormatException>()));
    expect(DownloadResourceLifecycle.removing(DownloadResourceLifecycle.video(video.id)), isNull);
    expect(VideoLocalResources.tryHold(video.id), isTrue);
    VideoLocalResources.release(video.id);
  });

  test('failure after physical video removal retains truthful transfer evidence', () async {
    final video = await seedVideo();
    final service = VideoDownloadRemoval(removeResource: (lease) async {
      await lease.remove();
      throw const FileSystemException('controlled failure after removing owned file');
    });
    await expectLater(service.remove(source: _source, page: video.page, quality: '720p'),
      throwsA(isA<FileSystemException>()));
    expect(await (await VideoLocalResources.file(video.id)).exists(), isFalse);
    final task = (await VideoExportRecords.readTasks()).singleWhere((row) => row['key'] == video.key);
    expect(task['fileRemoved'], isTrue);
    expect((await VideoExportRecords.read()).single['title'], '旧导出');
  });

  test('managed transfer authorizes its indexed-ID file when index is absent', () async {
    final video = await seedVideo();
    await File('${(await VideoLocalResources.root()).path}/index.json').delete();
    VideoLocalResources.invalidate();
    await removeVideoDownload(source: _source, page: video.page, quality: '720p');
    expect(await (await VideoLocalResources.file(video.id)).exists(), isFalse);
    expect(await VideoExportRecords.readTasks(), isEmpty);
  });


  test('comic confirmation token rejects a newer resource version before file I/O', () async {
    final directory = await seedComic();
    final expected = bindComicDownloadRemoval(from: _source, comicId: _comic);
    final record = objectbox.unifiedDownloadBox.getAll().single;
    record..title = '确认后完成的新资源'..downloadedAt = record.downloadedAt.add(const Duration(seconds: 1));
    objectbox.unifiedDownloadBox.put(record);
    var touchedFiles = false;
    final service = ComicDownloadRemoval(removeFiles: (_, _) async { touchedFiles = true; });
    await expectLater(service.remove(from: _source, comicId: _comic, expected: expected), throwsStateError);
    expect(touchedFiles, isFalse);
    expect(await directory.exists(), isTrue);
    expect(objectbox.unifiedDownloadBox.getAll().single.title, '确认后完成的新资源');
  });

  test('comic confirmation token rejects a new completed task and accepts already-deleted targets', () async {
    await seedComic();
    final expected = bindComicDownloadRemoval(from: _source, comicId: _comic);
    final later = _done();
    objectbox.downloadTaskBox.put(later);
    await expectLater(removeComicDownload(from: _source, comicId: _comic, expected: expected), throwsStateError);
    expect(objectbox.downloadTaskBox.get(later.id), isNotNull);
    await removeComicDownload(from: _source, comicId: _comic);
    await removeComicDownload(from: _source, comicId: _comic, expected: expected);
    expect(objectbox.downloadTaskBox.count(), 0);
  });

  test('video confirmation token rejects a newly completed generation of the same identity', () async {
    final original = await seedVideo();
    final expected = await bindVideoDownloadRemoval(source: _source, page: original.page, quality: '720p');
    final newer = await seedVideo();
    await expectLater(removeVideoDownload(source: _source, page: original.page,
      quality: '720p', expected: expected), throwsStateError);
    expect(await (await VideoLocalResources.file(newer.id)).exists(), isTrue);
    expect((await VideoLocalResources.read()).single['taskKey'], newer.key);
    expect((await VideoExportRecords.readTasks()).any((row) => row['key'] == newer.key), isTrue);
  });

  test('a stale resource-only video cannot authorize a replacement before confirmation', () async {
    final original = await seedVideo();
    final displayed = DownloadCenterResources.mergeVideos(
      [],
      await VideoLocalResources.read(),
    ).single;
    expect(displayed['resourceOnly'], isTrue);
    expect(displayed['resourceVersion'], isA<String>());

    final replacement = await seedVideo();
    await expectLater(
      bindVideoDownloadRemoval(
        source: _source,
        page: original.page,
        quality: '720p',
        displayedTask: displayed,
      ),
      throwsStateError,
    );
    expect((await VideoLocalResources.read()).single['taskKey'], replacement.key);
    expect(await (await VideoLocalResources.file(replacement.id)).exists(), isTrue);
  });

  test('export opens native sharing only for the displayed resource generation', () async {
    final original = await seedVideo();
    final displayed = DownloadCenterResources.mergeVideos(
      [],
      await VideoLocalResources.read(),
    ).single;
    final replacement = await seedVideo();
    expect(replacement.id, original.id);
    final latest = DownloadCenterResources.mergeVideos(
      [],
      await VideoLocalResources.read(),
    ).single;
    const channel = MethodChannel('breeze.video.download');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var exports = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'export');
      expect(call.arguments['resourceId'], replacement.id);
      exports++;
      return 'saved';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await VideoSystemDownload.exportLocal(
        original.id,
        displayed['title'] as String,
        expectedResourceVersion: displayed['resourceVersion'] as String,
      ),
      VideoDownloadStatus.failed,
    );
    expect(exports, 0);
    expect(
      await VideoSystemDownload.exportLocal(
        replacement.id,
        latest['title'] as String,
        expectedResourceVersion: latest['resourceVersion'] as String,
      ),
      VideoDownloadStatus.saved,
    );
    expect(exports, 1);
  });

  test('video confirmation token is idempotent after another complete removal', () async {
    final video = await seedVideo();
    final expected = await bindVideoDownloadRemoval(source: _source, page: video.page, quality: '720p');
    await removeVideoDownload(source: _source, page: video.page, quality: '720p');
    await removeVideoDownload(source: _source, page: video.page, quality: '720p', expected: expected);
    expect(await VideoExportRecords.readTasks(), isEmpty);
  });

  test('unknown legacy confirmation binds exact IDs without parsing or expanding to later rows', () async {
    final old = DownloadTask()..comicName = '旧未知任务'..isCompleted = true..dbTaskInfoStr = '{malformed';
    objectbox.downloadTaskBox.put(old);
    final expected = bindUnknownDownloadTaskRemoval(old.id);
    final later = DownloadTask()..comicName = '同名新未知任务'..isCompleted = true..dbTaskInfoStr = '{malformed';
    objectbox.downloadTaskBox.put(later);
    await removeUnknownDownloadTasks(expected: [expected]);
    expect(objectbox.downloadTaskBox.get(old.id), isNull);
    expect(objectbox.downloadTaskBox.get(later.id), isNotNull);
    final next = bindUnknownDownloadTaskRemoval(later.id);
    later.comicName = '确认后替换的任务';
    objectbox.downloadTaskBox.put(later);
    await expectLater(removeUnknownDownloadTasks(expected: [next]), throwsStateError);
    expect(objectbox.downloadTaskBox.get(later.id)!.comicName, '确认后替换的任务');
    objectbox.downloadTaskBox.remove(later.id);
    await removeUnknownDownloadTasks(expected: [next]);
  });

}
