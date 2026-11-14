
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 150 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(ready(), isTrue);
  }

  test('visible download shelf observes actual resource and root-link commits without tab switching', () async {
    final bloc = FolderShelfBloc(mode: ShelfPageMode.download);
    addTearDown(bloc.close);
    expect(await bloc.refresh(), isTrue);
    expect(bloc.state.comics, isEmpty);
    final record = createTestDownload('test:live-download')..comicId = 'live-download';
    objectbox.unifiedDownloadBox.put(record);
    // Mirrors the worker's two commits: resource first, then its real link.
    ComicLinkService.addComic(record.uniqueKey, null, ComicFolderType.download);
    await until(() => !bloc.state.isLoading && bloc.state.comics.isNotEmpty);
    expect(bloc.state.comics.single.title, record.title);
    expect(bloc.state.currentPath, '');
    // A metadata commit must also refresh an already visible card.
    record.title = '下载资料已更新';
    objectbox.unifiedDownloadBox.put(record);
    await until(() => !bloc.state.isLoading && bloc.state.comics.single.title == '下载资料已更新');
    objectbox.unifiedDownloadBox.remove(record.id);
    await until(() => !bloc.state.isLoading && bloc.state.comics.isEmpty);
    expect(bloc.state.error, isNull);
  });
}
