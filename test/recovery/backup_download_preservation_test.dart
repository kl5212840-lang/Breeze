import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/util/manage_cache.dart';

import '../test_helper.dart';

BikaComicDownload _bika(String id) => BikaComicDownload.fromJson({
  for (final name
      in 'creatorId creatorGender creatorName creatorCharactersString creatorRole creatorTitle creatorAvatarOriginalName creatorAvatarPath creatorAvatarFileServer creatorSlogan description thumbOriginalName thumbPath thumbFileServer author chineseTeam categoriesString tagsString'
          .split(' '))
    name: '',
  for (final name
      in 'creatorVerified finished allowDownload allowComment isFavourite isLiked'
          .split(' '))
    name: false,
  for (final name
      in 'creatorExp creatorLevel pagesCount epsCount totalLikes totalViews totalComments viewsCount likesCount commentsCount'
          .split(' '))
    name: 0,
  for (final name in ['creatorCharacters', 'categories', 'tags', 'epsTitle'])
    name: <String>[],
  for (final name in ['createdAt', 'updatedAt', 'downloadTime'])
    name: DateTime.utc(2026).toIso8601String(),
  'comicId': id,
  'title': id,
  'comicInfoAll': '{}',
});

JmDownload _jm(String id) => JmDownload.fromJson({
  for (final name
      in 'addtime description totalViews likes seriesId commentTotal price purchased'
          .split(' '))
    name: '',
  for (final name in ['liked', 'isFavorite', 'isAids']) name: false,
  for (final name in ['author', 'tags', 'works', 'actors', 'epsIds'])
    name: <String>[],
  'comicId': id,
  'name': id,
  'allInfo': '{}',
  'downloadTime': DateTime.utc(2026).toIso8601String(),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, extract, downloads, outside;
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sync.device_id': 'local-fixture'});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.bikaDownloadBox.removeAll();
    objectbox.jmDownloadBox.removeAll();
    root = await Directory.systemTemp.createTemp('backup_download_guard_');
    extract = await Directory(p.join(root.path, 'extract')).create();
    downloads = await Directory(p.join(root.path, 'downloads')).create();
    outside = await Directory(p.join(root.path, 'unrelated')).create();
    await File(p.join(outside.path, 'keep.txt')).writeAsString('unrelated');
    await File(
      p.join(downloads.path, 'old.txt'),
    ).writeAsString('original download');
    objectbox.bikaDownloadBox.put(_bika('local-bika'));
    objectbox.jmDownloadBox.put(_jm('local-jm'));
    objectbox.unifiedDownloadBox.put(
      createTestDownload('fixture:shared', storageRoot: downloads.path)
        ..source = 'fixture'
        ..comicId = 'shared'
        ..title = 'Local download',
    );
    ComicFolderService.createFolder('', 'Local', ComicFolderType.download);
    ComicLinkService.addComic(
      'fixture:shared',
      '/Local',
      ComicFolderType.download,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Map<String, dynamic> localDownloads() => {
    'bika': objectbox.bikaDownloadBox
        .getAll()
        .map((row) => row.toJson())
        .toList(),
    'jm': objectbox.jmDownloadBox.getAll().map((row) => row.toJson()).toList(),
    'unified': objectbox.unifiedDownloadBox
        .getAll()
        .map((row) => row.toJson())
        .toList(),
    'folders': objectbox.comicFolderBox
        .getAll()
        .where((row) => row.typeData == 'download')
        .map((row) => row.toJson())
        .toList(),
    'links': objectbox.comicLinkBox
        .getAll()
        .where((row) => row.typeData == 'download')
        .map((row) => row.toJson())
        .toList(),
  };

  Future<Map<String, dynamic>> incoming({
    required bool include,
    bool duplicate = false,
  }) async {
    final raw =
        jsonDecode(objectbox.collectAllDataJson(removeIds: true))
            as Map<String, dynamic>;
    final key = duplicate ? 'fixture:shared' : 'fixture:foreign';
    raw['bikaComicDownload'] = [_bika('foreign-bika').toJson()..remove('id')];
    raw['jmDownload'] = [_jm('foreign-jm').toJson()..remove('id')];
    raw['unifiedComicDownload'] = [
      (createTestDownload(key, storageRoot: outside.path)
            ..source = 'fixture'
            ..comicId = (duplicate ? 'shared' : 'foreign')
            ..title = 'Foreign download')
          .toJson()
        ..remove('id'),
    ];
    raw['comicFolder'] = [
      ComicFolder(
        syncId: 'foreign-folder',
        uniqueKey: '|Foreign|download',
        name: 'Foreign',
        typeData: 'download',
        versionVectorJson: '{}',
        createdAt: 1,
        updatedAt: 1,
      ).toJson()..remove('id'),
    ];
    raw['comicLink'] = [
      ComicLink(
        uniqueKey: '$key|foreign-folder|download',
        comicUniqueKey: key,
        folderSyncId: 'foreign-folder',
        typeData: 'download',
        versionVectorJson: '{}',
        createdAt: 1,
        updatedAt: 1,
      ).toJson()..remove('id'),
    ];
    raw['unifiedComicFavorite'] = [
      (createTestFavorite(
          'fixture:favorite',
        )..metadata = '[{"type":"future","value":"opaque"}]').toJson()
        ..remove('id'),
    ];
    await File(
      p.join(extract.path, 'config.json'),
    ).writeAsString(jsonEncode({'includeDownloads': include}));
    await File(
      p.join(extract.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(raw));
    if (include) {
      final source = await Directory(
        p.join(extract.path, 'downloads'),
      ).create();
      await File(
        p.join(source.path, 'new.txt'),
      ).writeAsString('imported download');
    }
    return raw;
  }

  for (final duplicate in [false, true]) {
    test(
      'backup without files preserves all three local download tables and associations, duplicate=$duplicate',
      () async {
        await incoming(include: false, duplicate: duplicate);
        final before = jsonEncode(localDownloads());
        await importExtractedBreezeData(
          extract.path, mode: BackupImportMode.restore,
          restoreDownloadFiles: true,
          hooks: BackupImportHooks(downloadDirectory: downloads),
        );
        expect(jsonEncode(localDownloads()), before);
        expect(
          await File(p.join(downloads.path, 'old.txt')).readAsString(),
          'original download',
        );
        expect(
          await File(p.join(outside.path, 'keep.txt')).readAsString(),
          'unrelated',
        );
        expect(
          objectbox.unifiedFavoriteBox.getAll().single.metadata,
          '[{"type":"future","value":"opaque"}]',
        );
        expect(
          (await SharedPreferences.getInstance()).getString('sync.device_id'),
          'local-fixture',
        );
      },
    );
  }

  test(
    'included downloads replace files and records together without importing foreign absolute paths',
    () async {
      await incoming(include: true);
      await importExtractedBreezeData(
        extract.path, mode: BackupImportMode.restore,
        restoreDownloadFiles: true,
        hooks: BackupImportHooks(downloadDirectory: downloads),
      );
      expect(await File(p.join(downloads.path, 'old.txt')).exists(), isFalse);
      expect(
        await File(p.join(downloads.path, 'new.txt')).readAsString(),
        'imported download',
      );
      expect(
        objectbox.unifiedDownloadBox.getAll().single.uniqueKey,
        'fixture:foreign',
      );
      expect(objectbox.unifiedDownloadBox.getAll().single.storageRoot, isEmpty);
      expect(objectbox.bikaDownloadBox.getAll().single.comicId, 'foreign-bika');
      expect(objectbox.jmDownloadBox.getAll().single.comicId, 'foreign-jm');
      expect(objectbox.comicFolderBox.getAll().single.name, 'Foreign');
      expect(
        await File(p.join(outside.path, 'keep.txt')).readAsString(),
        'unrelated',
      );
      expect(
        root.listSync().where(
          (entry) =>
              p.basename(entry.path).startsWith('.breeze-download-restore-'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'a failed installation rename restores the original tree and database',
    () async {
      await incoming(include: true);
      final before = jsonEncode(localDownloads());
      var renames = 0;
      await expectLater(
        importExtractedBreezeData(
          extract.path, mode: BackupImportMode.restore,
          restoreDownloadFiles: true,
          hooks: BackupImportHooks(
            downloadDirectory: downloads,
            rename: (source, target) async {
              if (++renames == 2) {
                throw const FileSystemException('synthetic install failure');
              }
              await source.rename(target);
            },
          ),
        ),
        throwsA(isA<BackupRestoreIncomplete>()),
      );
      expect(renames, 3);
      expect(
        await File(p.join(downloads.path, 'old.txt')).readAsString(),
        'original download',
      );
      expect(await File(p.join(downloads.path, 'new.txt')).exists(), isFalse);
      expect(jsonEncode(localDownloads()), before);
      expect(
        await File(p.join(outside.path, 'keep.txt')).readAsString(),
        'unrelated',
      );
    },
  );

  test(
    'a failed real transaction after the swap restores original files and rows',
    () async {
      await incoming(include: true);
      final before = jsonEncode(localDownloads());
      await expectLater(
        importExtractedBreezeData(
          extract.path, mode: BackupImportMode.restore,
          restoreDownloadFiles: true,
          hooks: BackupImportHooks(
            downloadDirectory: downloads,
            beforeCommit: () {
              throw StateError('synthetic database commit failure');
            },
          ),
        ),
        throwsA(isA<BackupRestoreIncomplete>()),
      );
      expect(
        await File(p.join(downloads.path, 'old.txt')).readAsString(),
        'original download',
      );
      expect(await File(p.join(downloads.path, 'new.txt')).exists(), isFalse);
      expect(jsonEncode(localDownloads()), before);
    },
  );

  test(
    'nested or symbolic download roots are rejected before originals change',
    () async {
      await incoming(include: true);
      final before = jsonEncode(localDownloads());
      await expectLater(
        importExtractedBreezeData(
          extract.path, mode: BackupImportMode.restore,
          restoreDownloadFiles: true,
          hooks: BackupImportHooks(
            downloadDirectory: Directory(p.join(extract.path, 'nested')),
          ),
        ),
        throwsA(isA<BackupRestoreIncomplete>()),
      );
      final link = Link(p.join(root.path, 'linked-downloads'));
      await link.create(downloads.path);
      await expectLater(
        importExtractedBreezeData(
          extract.path, mode: BackupImportMode.restore,
          restoreDownloadFiles: true,
          hooks: BackupImportHooks(downloadDirectory: Directory(link.path)),
        ),
        throwsA(isA<BackupRestoreIncomplete>()),
      );
      expect(
        await File(p.join(downloads.path, 'old.txt')).readAsString(),
        'original download',
      );
      expect(jsonEncode(localDownloads()), before);
    },
  );

  test(
    'real import queues behind active sync work and keeps its waiting workspace protected',
    () async {
      await incoming(include: false, duplicate: true);
      final started = Completer<void>(), release = Completer<void>();
      final order = <String>[];
      final syncing = runExclusiveStorageOperation(() async {
        order.add('sync');
        started.complete();
        await release.future;
        order.add('sync complete');
      });
      await started.future;
      var committed = false;
      final importing = importExtractedBreezeData(
        extract.path, mode: BackupImportMode.restore,
        hooks: BackupImportHooks(
          beforeCommit: () {
            committed = true;
            order.add('import');
          },
        ),
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(committed, isFalse);
        await expectLater(
          clearCache(root.path),
          throwsA(isA<CacheWorkspaceBusy>()),
        );
        expect(await extract.exists(), isTrue);
      } finally {
        release.complete();
        await syncing;
      }
      await importing.timeout(const Duration(seconds: 10));
      expect(order, ['sync', 'sync complete', 'import']);
      expect(committed, isTrue);
    },
  );
  test('local backup import preserves this device connection and compatibility choice', () async {
    final user = objectbox.userSettingBox.get(1)!;
    final previous = user.globalSetting;
    const connection = SyncSettingState(
      legacyCompatibilityEnabled: true,
      syncSettings: false,
      syncPlugins: true,
      webdavSetting: WebDavSettingState(
        host: 'https://local.synthetic.test', username: 'synthetic-device',
        password: 'LOCAL_SYNTHETIC_TRANSPORT'),
    );
    try {
      user.globalSetting = previous.copyWith(dynamicColor: true, syncSetting: connection);
      objectbox.userSettingBox.put(user);
      final raw = await incoming(include: false);
      final foreign = UserSetting()..globalSetting = const GlobalSettingState(
        dynamicColor: false,
        syncSetting: SyncSettingState(legacyCompatibilityEnabled: false,
          webdavSetting: WebDavSettingState(host: 'https://foreign.synthetic.test')),
      );
      raw['userSetting'] = [foreign.toJson()..remove('id')];
      await File(p.join(extract.path, 'objectbox.json')).writeAsString(jsonEncode(raw));
      await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore);
      final restored = objectbox.userSettingBox.get(1)!.globalSetting;
      expect(restored.dynamicColor, isFalse);
      expect(restored.syncSetting, connection);
    } finally {
      final current = objectbox.userSettingBox.get(1)!;
      current.globalSetting = previous;
      objectbox.userSettingBox.put(current);
    }
  });

  test('shipped schema2 backup rows and the old readMode column restore through the real importer', () async {
    final raw = await incoming(include: true);
    for (final key in ['unifiedComicFavorite', 'unifiedComicDownload']) {
      ((raw[key] as List).single as Map)['schemaVersion'] = 2;
    }
    raw['unifiedComicHistory'] = [(createTestHistory('shipped:history')..schemaVersion = 2).toJson()..remove('id')];
    raw['comicReadPreference'] = [{
      'uniqueKey': 'shipped:history', 'source': 'test', 'comicId': 'shipped:history',
      'readMode': 2, 'updatedAt': DateTime.utc(2024).toIso8601String(), 'deleted': false,
    }];
    await File(p.join(extract.path, 'objectbox.json')).writeAsString(jsonEncode(raw));
    expect(await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore), isTrue);
    expect(objectbox.unifiedFavoriteBox.getAll().single.schemaVersion, 2);
    expect(objectbox.unifiedHistoryBox.getAll().single.schemaVersion, 2);
    expect(objectbox.unifiedDownloadBox.getAll().single.schemaVersion, 2);
    expect(jsonDecode(objectbox.comicReadPreferenceBox.getAll().single.overridesJson), {'readMode': 2});
    expect(objectbox.unifiedFavoriteBox.getAll().single.metadata, '[{"type":"future","value":"opaque"}]');
  });

  test('future backup schema beside shipped schema2 rolls back without changing local records or files', () async {
    final raw = await incoming(include: true);
    ((raw['unifiedComicFavorite'] as List).single as Map)['schemaVersion'] = 2;
    ((raw['unifiedComicDownload'] as List).single as Map)['schemaVersion'] = 3;
    await File(p.join(extract.path, 'objectbox.json')).writeAsString(jsonEncode(raw));
    final before = objectbox.collectAllDataJson(removeIds: true);
    await expectLater(importExtractedBreezeData(extract.path, mode: BackupImportMode.restore), throwsA(isA<BackupCompatibilityException>()));
    expect(objectbox.collectAllDataJson(removeIds: true), before);
    expect(await File(p.join(downloads.path, 'old.txt')).readAsString(), 'original download');
    expect(await File(p.join(outside.path, 'keep.txt')).readAsString(), 'unrelated');
  });

  test('excluding downloads preserves local completed and active task history without importing foreign jobs', () async {
    objectbox.downloadTaskBox.removeAll();
    final completed = DownloadTask()..comicId = 'local-completed'..comicName = 'Local completed'
      ..isCompleted = true..isDownloading = false..status = 'completed';
    final active = DownloadTask()..comicId = 'local-active'..comicName = 'Local active'
      ..isCompleted = false..isDownloading = true..status = 'downloading';
    objectbox.downloadTaskBox.putMany([completed, active]);
    final before = objectbox.downloadTaskBox.getAll().map((row) => row.toJson()).toList();
    final raw = await incoming(include: false);
    final foreign = DownloadTask()..comicId = 'foreign-active'..comicName = 'Foreign active'
      ..isCompleted = false..isDownloading = true..status = 'downloading';
    raw['downloadTask'] = [foreign.toJson()..remove('id')];
    await File(p.join(extract.path, 'objectbox.json')).writeAsString(jsonEncode(raw));
    await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore);
    expect(objectbox.downloadTaskBox.getAll().map((row) => row.toJson()).toList(), before);
    expect(objectbox.downloadTaskBox.getAll().any((row) => row.comicId == 'foreign-active'), isFalse);
  });

}
