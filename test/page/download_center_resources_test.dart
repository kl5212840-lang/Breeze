import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _source = 'download-center-fixture';
const _id = 'work-1';
String get _key => buildDownloadTaskKey(_source, _id);

DownloadTask _completed() => DownloadTask()
  ..comicId = _id
  ..comicName = '本地作品'
  ..isCompleted = true
  ..taskInfo = const DownloadTaskJson(
    from: _source,
    comicId: _id,
    comicName: '本地作品',
    stateCode: 'completed',
    chapterRef: DownloadChapterTaskRef(chapterId: '1', title: '第一话', order: 1),
  );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  Future<Directory> seed() async {
    await useIsolatedDownloadFixture();
    final directory = await createDownloadFixture(_source, _id);
    await File('${directory.path}/page.png').writeAsString('fixture page');
    objectbox.downloadTaskBox.put(_completed());
    objectbox.unifiedDownloadBox.put(createTestDownload(_key));
    // The helper's synthetic row identity is independent of this test's source.
    final row = objectbox.unifiedDownloadBox.getAll().single;
    row.source = _source;
    row.comicId = _id;
    objectbox.unifiedDownloadBox.put(row);
    objectbox.unifiedFavoriteBox.put(createTestFavorite(_key));
    objectbox.unifiedHistoryBox.put(createTestHistory(_key));
    return directory;
  }

  test(
    'explicit clear removes only the task log, preserving files and shelf data',
    () async {
      final directory = await seed();
      final id = objectbox.downloadTaskBox.getAll().single.id;
      await const DownloadTaskRepository().removeRecords([id]);
      expect(objectbox.downloadTaskBox.count(), 0);
      expect(await File('${directory.path}/page.png').exists(), isTrue);
      expect(objectbox.unifiedDownloadBox.count(), 1);
      expect(objectbox.unifiedFavoriteBox.count(), 1);
      expect(objectbox.unifiedHistoryBox.count(), 1);
    },
  );

  test(
    'resource deletion removes the transfer row and keeps favorite/history',
    () async {
      final directory = await seed();
      ComicLinkService.addComic(_key, null, ComicFolderType.download);
      final item = DownloadCenterItem(
        key: 'comic:$_key',
        source: _source,
        title: '本地作品',
        priority: 3,
        at: 0,
      );
      await DownloadWorkPins.setPinnedItems([item], true);
      expect(
        DownloadWorkPins.rankFor(item, await DownloadWorkPins.read()),
        isNotNull,
      );
      await deleteWholeComicDownload(from: _source, comicId: _id);
      expect(
        DownloadWorkPins.rankFor(item, await DownloadWorkPins.read()),
        isNull,
      );
      expect(await directory.exists(), isFalse);
      expect(objectbox.unifiedDownloadBox.count(), 0);
      expect(
        ComicLinkService.linksOfComic(_key, ComicFolderType.download),
        isEmpty,
      );
      expect(objectbox.downloadTaskBox.getAll(), isEmpty);
      expect(objectbox.unifiedFavoriteBox.count(), 1);
      expect(objectbox.unifiedHistoryBox.count(), 1);
    },
  );

  test(
    'removing one folder association retains files; last association removes resource and task',
    () async {
      final directory = await seed();
      ComicFolderService.createFolder('', 'A', ComicFolderType.download);
      ComicFolderService.createFolder('', 'B', ComicFolderType.download);
      ComicLinkService.addComic(_key, '/A', ComicFolderType.download);
      ComicLinkService.addComic(_key, '/B', ComicFolderType.download);
      ComicLinkService.removeComic(_key, '/A', ComicFolderType.download);
      expect(await directory.exists(), isTrue);
      expect(objectbox.unifiedDownloadBox.count(), 1);
      expect(
        objectbox.downloadTaskBox.getAll().single.taskInfo!.phaseCode,
        isNot('fileRemoved'),
      );
      ComicLinkService.removeComic(_key, '/B', ComicFolderType.download);
      await expectDownloadRemoved(directory);
      for (var i = 0; i < 50 && objectbox.downloadTaskBox.count() != 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(objectbox.unifiedDownloadBox.count(), 0);
      expect(objectbox.downloadTaskBox.getAll(), isEmpty);
      expect(objectbox.unifiedFavoriteBox.count(), 1);
      expect(objectbox.unifiedHistoryBox.count(), 1);
    },
  );
}
