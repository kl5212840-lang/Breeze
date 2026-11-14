import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String database;
  setUpAll(() async => TestObjectBoxHelper.setUpTestObjectBox());
  tearDownAll(() async => TestObjectBoxHelper.tearDownTestObjectBox());
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sync.device_id': 'local-device'});
    dir = await Directory.systemTemp.createTemp('breeze_backup_test_');
    database = objectbox.collectAllDataJson(removeIds: true);
    await File(
      p.join(dir.path, 'config.json'),
    ).writeAsString('{"includeDownloads":false}');
    await File(p.join(dir.path, 'objectbox.json')).writeAsString(database);
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<void> writePortable(
    PortablePreferencesSnapshot prefs,
    VideoLibrarySnapshot library,
  ) => File(p.join(dir.path, 'portable-data.json')).writeAsString(
    jsonEncode({
      'format': 'breeze-portable-data',
      'version': 1,
      'preferences': prefs.toJson(),
      'videoLibrary': library.toJson(),
    }),
  );

  test(
    'new device restores portable settings and complete video library',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('breeze.video.progress.fixture', 16000);
      await SourceListBlockPreferences.write('fixture|cloudFavorite', {'Public category'});
      await BookshelfSourcePreferenceStore().save(BookshelfSourceMedium.download, BookshelfSourcePreferences(hidden: ['fixture']));
      await RoutingObservedMediaDomains.commitProbe(source: '1e600cff-8ebe-4517-8aa4-6678aec46424', domains: ['media.fixture.tv'], complete: true);
      await VideoLibraryStore.shared.createFolder('fixture', 'saved folder');
      final portable = await PortablePreferences.capture();
      final library = await VideoLibraryStore.shared.read();
      await writePortable(portable, library);
      await prefs.remove('breeze.video.progress.fixture');
      await prefs.remove(SourceListBlockPreferences.key('fixture|cloudFavorite'));
      await prefs.remove(BookshelfSourcePreferenceStore.key(BookshelfSourceMedium.download));
      await prefs.remove(RoutingObservedMediaDomains.storageKey);
      await VideoLibraryStore.shared.replaceSnapshot(VideoLibrarySnapshot());
      await importExtractedBreezeData(dir.path, mode: BackupImportMode.restore);
      expect(prefs.getInt('breeze.video.progress.fixture'), 16000);
      expect(await SourceListBlockPreferences.read('fixture|cloudFavorite'), {'Public category'});
      expect((await BookshelfSourcePreferenceStore().read(BookshelfSourceMedium.download)).hidden, {'fixture'});
      expect((await RoutingObservedMediaDomains.read())['1e600cff-8ebe-4517-8aa4-6678aec46424']!.single.host, 'media.fixture.tv');
      expect((await VideoLibraryStore.shared.read()).folders, hasLength(1));
      expect(prefs.getString('sync.device_id'), 'local-device');
    },
  );

  test('legacy backup keeps local video data', () async {
    await VideoLibraryStore.shared.createFolder('fixture', 'local folder');
    final before = (await VideoLibraryStore.shared.read()).toJson();
    await importExtractedBreezeData(dir.path, mode: BackupImportMode.restore);
    expect((await VideoLibraryStore.shared.read()).toJson(), before);
  });

  test('extracted backup restores distinct chapters and older file keeps them', () async {
    final sidecar = File(p.join(dir.path, ChapterProgressArchive.filename));
    await sidecar.writeAsBytes(ChapterProgressArchive({
      ('fixture', 'work', 'one'): (at: 10, progress: (pageIndex: 8, pageCount: 8, completed: true)),
      ('fixture', 'work', 'two'): (at: 11, progress: (pageIndex: 3, pageCount: 8, completed: false)),
    }).encode());
    await importExtractedBreezeData(dir.path, mode: BackupImportMode.merge);
    final store = ComicChapterReadingProgress.instance;
    expect(store.lookup('fixture', 'work', ['one'])?.completed, isTrue);
    expect(store.lookup('fixture', 'work', ['two'])?.pageIndex, 3);
    await sidecar.delete();
    await importExtractedBreezeData(dir.path, mode: BackupImportMode.restore);
    expect(store.lookup('fixture', 'work', ['two'])?.pageIndex, 3);
  });

  test('bad objectbox or portable input leaves local data intact', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('breeze.video.progress.fixture', 24000);
    await VideoLibraryStore.shared.createFolder('fixture', 'local folder');
    final before = (await VideoLibraryStore.shared.read()).toJson();
    objectbox.pluginConfigBox.put(
      PluginConfig(name: 'local-fixture', config: '{}'),
    );
    final rows = jsonDecode(database) as Map<String, dynamic>;
    rows['pluginConfig'] = [42];
    await File(
      p.join(dir.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(rows));
    await expectLater(importExtractedBreezeData(dir.path, mode: BackupImportMode.restore), throwsA(anything));
    expect((await VideoLibraryStore.shared.read()).toJson(), before);
    expect(prefs.getInt('breeze.video.progress.fixture'), 24000);
    expect(
      objectbox.pluginConfigBox.getAll().any(
        (row) => row.name == 'local-fixture',
      ),
      isTrue,
    );
    await File(p.join(dir.path, 'objectbox.json')).writeAsString(database);
    await File(
      p.join(dir.path, 'portable-data.json'),
    ).writeAsString('{"version":1}');
    await expectLater(
      importExtractedBreezeData(dir.path, mode: BackupImportMode.restore),
      throwsA(isA<BackupCompatibilityException>()),
    );
    expect((await VideoLibraryStore.shared.read()).toJson(), before);
    expect(prefs.getInt('breeze.video.progress.fixture'), 24000);
  });
  test(
    'malformed backup errors never echo remembered credential data',
    () async {
      await File(
        p.join(dir.path, 'objectbox.json'),
      ).writeAsString('{"pluginConfig":[{"config":"DUMMY_SECRET_MARKER');
      try {
        await importExtractedBreezeData(dir.path, mode: BackupImportMode.restore);
        fail('Expected invalid backup');
      } catch (error) {
        expect(error, isFormatException);
        expect(error.toString(), isNot(contains('DUMMY_SECRET_MARKER')));
      }
    },
  );
}
