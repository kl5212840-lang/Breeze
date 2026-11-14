import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/service/offline_backup_merge.dart'
    show prepareOfflineBackupMerge;
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/get_path.dart';

import '../test_helper.dart';

class _PackApi extends RustLibApi {
  final files = <String, List<int>>{};
  String? downloadArgument;
  @override
  Future<void> crateApiDataBackupCreateDataBackupZip({
    required String zipPath,
    required String dataDir,
    String? downloadDir,
  }) async {
    files.clear();
    downloadArgument = downloadDir;
    Future<void> capture(String root, String prefix) async {
      await for (final entry in Directory(
        root,
      ).list(recursive: true, followLinks: false)) {
        if (entry is File)
          files['$prefix${p.relative(entry.path, from: root)}'] = await entry
              .readAsBytes();
      }
    }

    await capture(dataDir, '');
    if (downloadDir != null) await capture(downloadDir, 'downloads/');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native fixture call');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _PackApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
    PackageInfo.setMockInitialValues(
      appName: 'Breeze',
      packageName: 'fixture',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  const account =
      '{ "account.credentials" : {"account":"SITE_ACCOUNT","password":"SITE_PASSWORD"},"future-private":{"proxy":"PLUGIN_OPAQUE_ALLOWED","updatedAt":"2026-11-01T21:37:00+08:00"}}';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.downloadTaskBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState(
      dynamicColor: false,
      switchStyle: BreezeSwitchStyle.ring,
      locale: Locale('en'),
      localeFollowsSystem: false,
      retryDownloadUntilSuccess: false,
      videoDownloadConcurrency: 3,
      downloadWifiOnly: true,
      downloadCompletionNotice: 'episode',
      eInkSetting: EInkSettingState(
        enabled: true,
        detectionHandled: true,
        autoRefreshEveryNTurns: 9,
      ),
      maskedKeywords: ['portable-keyword'],
      syncSetting: SyncSettingState(
        webdavSetting: WebDavSettingState(
          host: 'https://HOST_ONLY.invalid',
          password: 'HOST_ONLY_WEBDAV',
        ),
        s3Setting: S3SettingState(
          endpoint: 'HOST_ONLY_S3',
          secretKey: 'HOST_ONLY_SECRET',
        ),
      ),
      appLockSetting: AppLockSettingState(
        enabled: true,
        gesturePasswordHash: 'HOST_ONLY_LOCK',
        resetPinHash: 'HOST_ONLY_PIN',
      ),
      customExportPath: '/HOST_ONLY_EXPORT',
      socks5Proxy: 'HOST_ONLY_SOCKS',
      proxySetting: ProxySettingState(
        enabled: true,
        address: 'HOST_ONLY_PROXY',
      ),
      logAddress: '/HOST_ONLY_LOG',
      windowX: 77123,
      compatibleVersion: 'HOST_ONLY_DEVICE',
    );
    user.jmJwt = 'SITE_SESSION';
    objectbox.userSettingBox.put(user);
    objectbox.pluginConfigBox.put(
      PluginConfig(name: 'plugin-fixture', config: account),
    );
    objectbox.pluginInfoBox.put(
      PluginInfo(
        uuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        version: '1',
        originScript: 'synthetic plugin',
        insertedAt: DateTime.parse('2026-11-01T21:37:00+08:00').toLocal(),
        updatedAt: DateTime.parse('2026-11-01T01:37:00-05:00').toLocal(),
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: true,
        debugUrl: 'http://HOST_ONLY_DEBUG',
        lastLoadError: '/HOST_ONLY_ERROR',
      ),
    );
    objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = 'HOST_ONLY_ACTIVE_TASK'
        ..isDownloading = true
        ..dbTaskInfoStr = ' {"future-runtime":"opaque"} ',
    );
    objectbox.unifiedFavoriteBox.put(
      createTestFavorite(
        'fixture:comic',
        updatedAt: DateTime.parse('2026-11-01T21:37:00+08:00').toLocal(),
      ),
    );
    objectbox.unifiedDownloadBox.put(
      createTestDownload(
        'fixture:download',
        storageRoot: '/HOST_ONLY_DOWNLOAD_ROOT',
      ),
    );
    for (final (syncId, parent) in [
      ('folder-parent', null),
      ('folder-child', 'folder-parent'),
    ]) {
      objectbox.comicFolderBox.put(
        ComicFolder(
          syncId: syncId,
          parentSyncId: parent,
          uniqueKey: '${parent ?? ''}|$syncId|favorite',
          name: syncId,
          typeData: 'favorite',
          versionVectorJson: '{"causal-device":7}',
          createdAt: 10,
          updatedAt: 10,
        ),
      );
    }
    objectbox.comicLinkBox.put(
      ComicLink(
        uniqueKey: 'fixture:comic|folder-child|favorite',
        comicUniqueKey: 'fixture:comic',
        folderSyncId: 'folder-child',
        typeData: 'favorite',
        versionVectorJson: '{"causal-device":7}',
        createdAt: 10,
        updatedAt: 10,
      ),
    );
    await File(
      p.join(await getDownloadPath(), 'fixture.txt'),
    ).writeAsString('selected download');
    await LocalAppearanceImages.instance.save(
      'collection-cover',
      img.encodeJpg(img.Image(width: 2, height: 2)),
    );
  });

  for (final include in [false, true]) {
    test(
      'public export includeDownloads=$include emits portable JSON bytes and preserves account and folder identities',
      () async {
        final chapters = ComicChapterReadingProgress.instance;
        await chapters.capture();
        await chapters.record(
          source: 'fixture',
          comicId: 'work',
          chapterId: 'one',
          pageIndex: 4,
          lastVisiblePage: 5,
          pageCount: 5,
        );
        await exportBreezeBackup(
          zipPath: p.join(TestObjectBoxHelper.tempPath, 'fixture.zip'),
          includeDownloads: include,
        );
        final jsonFiles = api.files.entries
            .where((e) => e.key.endsWith('.json'))
            .map((e) => utf8.decode(e.value))
            .join('\n');
        expect(jsonFiles, isNot(contains('HOST_ONLY_')));
        expect(jsonFiles, contains('SITE_ACCOUNT'));
        expect(jsonFiles, contains('SITE_PASSWORD'));
        expect(jsonFiles, contains('SITE_SESSION'));
        expect(
          api.files.keys.any((name) => name.startsWith('appearance-local/')),
          isTrue,
        );
        expect(api.files.containsKey('downloads/fixture.txt'), include);
        expect(api.downloadArgument != null, include);
        final chapterArchive = ChapterProgressArchive.decode(
          api.files[ChapterProgressArchive.filename]!,
        );
        expect(
          chapterArchive.rows[('fixture', 'work', 'one')]?.progress?.completed,
          isTrue,
        );
        final database =
            jsonDecode(utf8.decode(api.files['objectbox.json']!)) as Map;
        expect(database['downloadTask'], isEmpty);
        expect((database['pluginConfig'] as List).single['config'], account);
        expect(
          (database['pluginInfo'] as List).single['insertedAt'],
          '2026-11-01T13:37:00.000Z',
        );
        expect(
          (database['pluginInfo'] as List).single['updatedAt'],
          '2026-11-01T06:37:00.000Z',
        );
        expect(
          (database['unifiedComicFavorite'] as List).single['updatedAt'],
          '2026-11-01T13:37:00.000Z',
        );
        for (final rows in database.values) {
          expect(
            (rows as List).every((row) => !(row as Map).containsKey('id')),
            isTrue,
          );
        }
        final folder = (database['comicFolder'] as List).singleWhere(
          (row) => row['syncId'] == 'folder-child',
        );
        expect(folder['parentSyncId'], 'folder-parent');
        expect(folder['versionVectorJson'], '{"causal-device":7}');
        expect(
          (database['comicLink'] as List).single['folderSyncId'],
          folder['syncId'],
        );
        final user = (database['userSetting'] as List).single;
        for (final global in [
          user['globalSetting'],
          jsonDecode(user['globalSettingData'] as String),
        ]) {
          expect((global as Map).keys, isNot(contains('syncSetting')));
          expect(global.keys, isNot(contains('proxySetting')));
          expect(global.keys, isNot(contains('appLockSetting')));
          expect(global['maskedKeywords'], ['portable-keyword']);
          expect(global['switchStyle'], 'ring');
          expect(global['locale'], 'en');
          expect(global['localeFollowsSystem'], isFalse);
          expect(global['retryDownloadUntilSuccess'], isFalse);
          expect(global['videoDownloadConcurrency'], 3);
          expect(global['downloadWifiOnly'], isTrue);
          expect(global['downloadCompletionNotice'], 'episode');
          final expectedEink = const EInkSettingState(
            enabled: true,
            autoRefreshEveryNTurns: 9,
          ).toJson()..remove('detectionHandled');
          expect(global['eInkSetting'], expectedEink);
        }
        final directory = await Directory.systemTemp.createTemp(
          'portable_scope_replay_',
        );
        try {
          for (final entry in api.files.entries) {
            final file = File(p.join(directory.path, entry.key));
            await file.parent.create(recursive: true);
            await file.writeAsBytes(entry.value);
          }
          final current = objectbox.userSettingBox.get(1)!;
          current.globalSetting = current.globalSetting.copyWith(
            switchStyle: BreezeSwitchStyle.classic,
            locale: const Locale('zh', 'CN'),
            localeFollowsSystem: true,
            eInkSetting: const EInkSettingState(
              detectionHandled: false,
              autoRefreshEveryNTurns: 2,
            ),
            proxySetting: const ProxySettingState(
              enabled: true,
              address: 'KEEP_LOCAL_PROXY',
            ),
          );
          objectbox.userSettingBox.put(current);
          objectbox.unifiedFavoriteBox.removeAll();
          objectbox.comicFolderBox.removeAll();
          objectbox.comicLinkBox.removeAll();
          await importExtractedBreezeData(
            directory.path,
            mode: BackupImportMode.restore,
          );
          expect(
            objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
            'fixture:comic',
          );
          expect(
            objectbox.unifiedFavoriteBox
                .getAll()
                .single
                .updatedAt
                .isAtSameMomentAs(DateTime.parse('2026-11-01T21:37:00+08:00')),
            isTrue,
          );
          expect(
            objectbox.pluginInfoBox.getAll().single.updatedAt.isAtSameMomentAs(
              DateTime.parse('2026-11-01T01:37:00-05:00'),
            ),
            isTrue,
          );
          final child = objectbox.comicFolderBox.getAll().singleWhere(
            (f) => f.syncId == 'folder-child',
          );
          expect(child.parentSyncId, 'folder-parent');
          expect(
            objectbox.comicLinkBox.getAll().single.folderSyncId,
            child.syncId,
          );
          expect(
            objectbox.userSettingBox.get(1)!.globalSetting.proxySetting.address,
            'KEEP_LOCAL_PROXY',
          );
          final restored = objectbox.userSettingBox.get(1)!.globalSetting;
          expect(restored.switchStyle, BreezeSwitchStyle.ring);
          expect(restored.locale, const Locale('en'));
          expect(restored.localeFollowsSystem, isFalse);
          expect(restored.retryDownloadUntilSuccess, isFalse);
          expect(restored.videoDownloadConcurrency, 3);
          expect(restored.downloadWifiOnly, isTrue);
          expect(restored.downloadCompletionNotice, 'episode');
          expect(
            restored.eInkSetting,
            const EInkSettingState(
              enabled: true,
              detectionHandled: false,
              autoRefreshEveryNTurns: 9,
            ),
          );
          expect(
            objectbox.userSettingBox
                .get(1)!
                .globalSetting
                .appLockSetting
                .gesturePasswordHash,
            'HOST_ONLY_LOCK',
          );
          expect(
            objectbox.userSettingBox
                .get(1)!
                .globalSetting
                .syncSetting
                .webdavSetting
                .password,
            'HOST_ONLY_WEBDAV',
          );
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test(
    'legacy file merge preparation and commit preserve target hardware detection',
    () async {
      await exportBreezeBackup(
        zipPath: p.join(TestObjectBoxHelper.tempPath, 'settings-merge.zip'),
        includeDownloads: false,
      );
      final directory = await Directory.systemTemp.createTemp(
        'portable_settings_merge_',
      );
      try {
        // A settings archive is optional in the existing format. Exercise the
        // legacy database-backed preparation path as well as the final commit.
        for (final entry in api.files.entries) {
          if (entry.key == 'sync-settings.json') continue;
          final file = File(p.join(directory.path, entry.key));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.value);
        }
        final databaseFile = File(p.join(directory.path, 'objectbox.json'));
        final database = jsonDecode(await databaseFile.readAsString()) as Map;
        final row = (database['userSetting'] as List).single as Map;
        final global = jsonDecode(row['globalSettingData'] as String) as Map;
        (global['eInkSetting'] as Map)['detectionHandled'] = false;
        row['globalSetting'] = global;
        row['globalSettingData'] = jsonEncode(global);
        await databaseFile.writeAsString(jsonEncode(database));
        final current = objectbox.userSettingBox.get(1)!;
        current.globalSetting = current.globalSetting.copyWith(
          switchStyle: BreezeSwitchStyle.classic,
          eInkSetting: const EInkSettingState(
            enabled: true,
            detectionHandled: true,
            autoRefreshEveryNTurns: 9,
          ),
        );
        objectbox.userSettingBox.put(current);
        // The export-scope fixture deliberately contains an opaque runtime task.
        // This settings-only merge uses no local download tasks.
        objectbox.downloadTaskBox.removeAll();
        final before = current.globalSetting;
        final plan = await prepareOfflineBackupMerge(
          directory,
          stagingParent: directory.parent,
        );
        try {
          expect(objectbox.userSettingBox.get(1)!.globalSetting, before);
          final staged =
              jsonDecode(
                    await File(
                      p.join(plan.directory.path, 'objectbox.json'),
                    ).readAsString(),
                  )
                  as Map;
          final stagedUser = (staged['userSetting'] as List).single as Map;
          final stagedGlobal =
              jsonDecode(stagedUser['globalSettingData'] as String) as Map;
          // A legacy backup has no revision for this locally changed block.
          expect(stagedGlobal['switchStyle'], 'classic');
          expect(stagedGlobal['locale'], 'en');
          expect(stagedGlobal['localeFollowsSystem'], isFalse);
          expect(
            (stagedGlobal['eInkSetting'] as Map)['detectionHandled'],
            isTrue,
          );
          expect(
            (stagedGlobal['eInkSetting'] as Map)['autoRefreshEveryNTurns'],
            9,
          );
        } finally {
          await plan.dispose();
        }
        await importExtractedBreezeData(
          directory.path,
          mode: BackupImportMode.merge,
        );
        final restored = objectbox.userSettingBox.get(1)!.globalSetting;
        expect(restored.switchStyle, BreezeSwitchStyle.classic);
        expect(restored.locale, const Locale('en'));
        expect(restored.localeFollowsSystem, isFalse);
        expect(restored.eInkSetting.detectionHandled, isTrue);
        expect(restored.eInkSetting.enabled, isTrue);
        expect(restored.eInkSetting.autoRefreshEveryNTurns, 9);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Copy backup omits device measurements and keeps portable route preferences',
    () async {
      const copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
      const route = 'network.autoRoute.v1';
      const speed = 'network.speed.v1';
      const revisions = '__breezeSyncFields';
      final config = {
        'api.domain': 'auto',
        'api.platform': '3',
        route: '大陆专线1',
        speed: {'local': 'fixture'},
        revisions: {
          route: {'updatedAt': 1},
          speed: {'updatedAt': 2},
        },
      };
      objectbox.pluginConfigBox.put(
        PluginConfig(name: copy, config: jsonEncode(config)),
      );
      await exportBreezeBackup(
        zipPath: p.join(TestObjectBoxHelper.tempPath, 'copy-route.zip'),
        includeDownloads: false,
      );

      final database =
          jsonDecode(utf8.decode(api.files['objectbox.json']!)) as Map;
      final settings =
          jsonDecode(utf8.decode(api.files['sync-settings.json']!)) as Map;
      for (final rows in [
        database['pluginConfig'],
        settings['pluginConfigs'],
        settings['blocks']['plugins']['data']['pluginConfigs'],
      ]) {
        final row = (rows as List).cast<Map>().singleWhere(
          (row) => row['name'] == copy,
        );
        final saved = jsonDecode(row['config'] as String);
        expect(saved, {'api.domain': 'auto', 'api.platform': '3'});
      }
      final savedLocal = objectbox.pluginConfigBox.getAll().singleWhere(
        (row) => row.name == copy,
      );
      expect(jsonDecode(savedLocal.config), config);
    },
  );

  test(
    'legacy full restore ignores a foreign Copy result and keeps this device’s fallback',
    () async {
      const copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
      const route = 'network.autoRoute.v1';
      const speed = 'network.speed.v1';
      final savedConfig = PluginConfig(
        name: copy,
        config: jsonEncode({
          'api.domain': '大陆专线1',
          'api.platform': '1',
          speed: {'device': 'local'},
        }),
      );
      objectbox.pluginConfigBox.put(savedConfig);
      await exportBreezeBackup(
        zipPath: p.join(TestObjectBoxHelper.tempPath, 'copy-legacy.zip'),
        includeDownloads: false,
      );
      final directory = await Directory.systemTemp.createTemp(
        'copy_legacy_restore_',
      );
      try {
        for (final entry in api.files.entries) {
          if (entry.key == 'sync-settings.json') continue;
          final file = File(p.join(directory.path, entry.key));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.value);
        }
        final databaseFile = File(p.join(directory.path, 'objectbox.json'));
        final database = jsonDecode(await databaseFile.readAsString()) as Map;
        final row = (database['pluginConfig'] as List).cast<Map>().singleWhere(
          (row) => row['name'] == copy,
        );
        row['config'] = jsonEncode({
          'api.domain': 'auto',
          'api.platform': '3',
          route: '热辣漫画线路4',
          speed: {'device': 'foreign'},
        });
        await databaseFile.writeAsString(jsonEncode(database));

        await importExtractedBreezeData(
          directory.path,
          mode: BackupImportMode.restore,
        );
        final restored = objectbox.pluginConfigBox.getAll().singleWhere(
          (row) => row.name == copy,
        );
        final active = jsonDecode(restored.config) as Map;
        expect(active['api.domain'], 'auto');
        expect(active['api.platform'], '3');
        expect(active[route], '大陆专线1');
        expect(active[speed], {'device': 'local'});
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  for (final field in ['schemaVersion', 'unknown-block']) {
    test(
      'public restore rejects future settings metadata $field before any user write',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'future_backup_metadata_',
        );
        try {
          await File(
            p.join(directory.path, 'config.json'),
          ).writeAsString('{"includeDownloads":false}');
          await File(p.join(directory.path, 'objectbox.json')).writeAsString(
            jsonEncode({
              'unifiedComicFavorite': [
                createTestFavorite('incoming').toJson()..remove('id'),
              ],
            }),
          );
          final metadata = {
            'version': 'v1',
            'schemaVersion': field == 'schemaVersion' ? 'v99' : 'v2',
            'syncTime': 1,
            'globalSetting': <String, dynamic>{},
            'blocks': field == 'unknown-block'
                ? {
                    'future': {
                      'updatedAt': 1,
                      'data': {'x': true},
                    },
                  }
                : <String, dynamic>{},
          };
          await File(
            p.join(directory.path, 'sync-settings.json'),
          ).writeAsString(jsonEncode(metadata));
          final before = await LocalImportRecovery.captureDatabaseSnapshot();
          await expectLater(
            importExtractedBreezeData(
              directory.path,
              mode: BackupImportMode.restore,
            ),
            throwsA(isA<BackupCompatibilityException>()),
          );
          expect(await LocalImportRecovery.captureDatabaseSnapshot(), before);
          expect(
            await File(
              p.join(
                await LocalImportRecovery.directory().then((d) => d.path),
                'pending.json',
              ),
            ).exists(),
            isFalse,
          );
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
