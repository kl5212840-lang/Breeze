import 'sync_installed_fixture.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/object_box/model.dart';

import '../../test_helper.dart';

Future<List<int>> compatibilityIdentity(List<int> bytes) async => bytes;
const compatibilitySettingsCodec = SettingsSyncCodec(
  encode: compatibilityIdentity,
  decode: compatibilityIdentity,
);

/// A real protocol fixture; the public sync entrypoints choose and validate it.
class CompatibilityRemote implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  int uploads = 0, deletions = 0;
  String path(String name) =>
      name.startsWith('${ComicSyncCore.syncRemoteRootName}/')
      ? name
      : '${ComicSyncCore.syncRemoteRootName}/$name';
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String remotePath) async =>
      files[path(remotePath)] ?? (throw StateError('404'));
  @override
  Future<String> downloadRemoteMd5() async =>
      utf8.decode(files[path('comic.md5')] ?? []);
  @override
  Future<void> uploadRemoteMd5(String value) async {
    uploads++;
    files[path('comic.md5')] = utf8.encode(value);
  }

  @override
  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    uploads++;
    files[path(remotePath)] = List.of(bytes);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    deletions += paths.length;
    for (final name in paths) {
      files.remove(path(name));
    }
  }

  void payload(String kind, Map<String, dynamic> data) {
    final bytes = utf8.encode(jsonEncode(data));
    files[path('${kind}_1.bin')] = bytes;
    files[path('$kind.md5')] = utf8.encode(ComicSyncCore.calculateMd5(bytes));
  }

  Map<String, dynamic> get settings =>
      jsonDecode(
            utf8.decode(
              files.entries
                  .lastWhere((entry) => entry.key.contains('/settings_'))
                  .value,
            ),
          )
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    await installSyncPlugins(['future-plugin']);
    // The application owns the persistent id=1 slot. removeAll() advances the
    // ObjectBox sequence, so a later id=0 insertion would not recreate it.
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState();
    objectbox.userSettingBox.put(user);
  });
  const enabled = GlobalSettingState(
    syncSetting: SyncSettingState(syncSettings: true, syncPlugins: true),
  );

  test(
    'cloud compatibility settings allow public preferences and retain private plugin namespaces',
    () async {
      const account =
          '{"account.credentials":{"version":1,"deleted":false,"account":"fixture-account","password":"fixture-password"},"future-private-key":{"opaque":[1,2]}}';
      objectbox.pluginConfigBox.put(
        PluginConfig(name: 'future-plugin', config: account),
      );
      final remote = CompatibilityRemote();
      final local = enabled.copyWith(
        syncSetting: enabled.syncSetting.copyWith(
          webdavSetting: const WebDavSettingState(
            host: 'https://sync.example.test',
            username: 'transport-fixture',
            password: 'TRANSPORT_SECRET_MARKER',
          ),
          s3Setting: const S3SettingState(
            endpoint: 's3.example.test',
            accessKey: 'TRANSPORT_ACCESS_MARKER',
            secretKey: 'TRANSPORT_SECRET_MARKER',
          ),
        ),
        proxySetting: const ProxySettingState(
          enabled: true,
          address: 'http://proxy.example.test',
        ),
        customExportPath: '/synthetic/local/export',
        switchStyle: BreezeSwitchStyle.spark,
        retryDownloadUntilSuccess: false,
        comicDownloadConcurrency: 4,
        videoDownloadConcurrency: 2,
        downloadWifiOnly: true,
        downloadCompletionNotice: 'chapter',
      );
      final user = objectbox.userSettingBox.get(1)!;
      user.globalSetting = local;
      objectbox.userSettingBox.put(user);
      await uploadSettingsData(
        remote,
        state: local,
        codec: compatibilitySettingsCodec,
        includeAll: true,
      );
      expect(
        jsonEncode(remote.settings),
        isNot(contains('TRANSPORT_SECRET_MARKER')),
      );
      expect(
        jsonEncode(remote.settings),
        isNot(contains('TRANSPORT_ACCESS_MARKER')),
      );
      expect(
        jsonEncode(remote.settings),
        isNot(contains('proxy.example.test')),
      );
      final global = remote.settings['globalSetting'] as Map;
      expect(global.keys.toSet(), {
        'dynamicColor',
        'themeMode',
        'isAMOLED',
        'seedColor',
        'switchStyle',
        'locale',
        'localeFollowsSystem',
        'eInkSetting',
        'welcomePageNum',
        'maskedKeywords',
        'comicChoice',
        'disableBika',
        'updateAccelerate',
        'retryDownloadUntilSuccess',
        'videoDownloadConcurrency',
        'downloadWifiOnly',
        'downloadCompletionNotice',
        'oldPageRollbackEnabled',
        'autoFollowOnCollect',
        'clickCoverToStartReading',
        'bookshelfSetting',
        'backPressExitEnabled',
        'cloudFavoritePreferred',
        'leftHandModeEnabled',
        'chineseConvertMode',
        'searchHistory',
        'readSetting',
      });
      expect(global['switchStyle'], 'spark');
      expect(global['retryDownloadUntilSuccess'], isFalse);
      expect(global['videoDownloadConcurrency'], 2);
      expect(global['downloadWifiOnly'], isTrue);
      expect(global['downloadCompletionNotice'], 'chapter');
      expect(global['localeFollowsSystem'], local.localeFollowsSystem);
      expect(global['autoFollowOnCollect'], local.autoFollowOnCollect);
      expect(
        global['clickCoverToStartReading'],
        local.clickCoverToStartReading,
      );
      expect(global['bookshelfSetting'], local.bookshelfSetting.toJson());
      expect(global['backPressExitEnabled'], local.backPressExitEnabled);
      expect(global['cloudFavoritePreferred'], local.cloudFavoritePreferred);
      expect(global['leftHandModeEnabled'], local.leftHandModeEnabled);
      expect(
        global['chineseConvertMode'],
        local.toJson()['chineseConvertMode'],
      );
      expect(global['oldPageRollbackEnabled'], isFalse);
      expect(
        global['eInkSetting'],
        (Map<String, dynamic>.from(local.eInkSetting.toJson())
          ..remove('detectionHandled')),
      );
      for (final name in [
        'syncSetting',
        'proxySetting',
        'socks5Proxy',
        'appLockSetting',
        'customExportPath',
        'cacheSetting',
      ]) {
        expect(global, isNot(contains(name)));
      }
      final plugin = (remote.settings['pluginConfigs'] as List).single as Map;
      expect(plugin['config'], account);
      expect(objectbox.pluginConfigBox.getAll().single.config, account);
    },
  );

  for (final custom in [false, true]) {
    test(
      'settings writers omit fields unknown to published 3.0.38 (custom=$custom)',
      () async {
        final state = custom
            ? enabled.copyWith(
                comicDownloadConcurrency: 7,
                readSetting: enabled.readSetting.copyWith(
                  showSystemStatusBar: true,
                ),
              )
            : enabled;
        final user = objectbox.userSettingBox.get(1)!;
        user.globalSetting = state;
        objectbox.userSettingBox.put(user);
        final remote = CompatibilityRemote();
        await uploadSettingsData(
          remote,
          state: state,
          codec: compatibilitySettingsCodec,
          includeAll: true,
        );
        for (final payload in [
          remote.settings,
          await captureFullCloudSettings(state),
        ]) {
          // f3ca37ff rejects unknown keys in both wire representations.
          final blocks = payload['blocks'] as Map;
          final global = payload['globalSetting'] as Map;
          expect(
            (blocks['library'] as Map)['data'],
            isNot(contains('comicDownloadConcurrency')),
          );
          expect(
            (blocks['reader'] as Map)['data'],
            isNot(contains('showSystemStatusBar')),
          );
          expect(global, isNot(contains('comicDownloadConcurrency')));
          expect(global['readSetting'], isNot(contains('showSystemStatusBar')));
          expect(global, containsPair('videoDownloadConcurrency', 1));
          expect(
            global['readSetting'],
            containsPair('pageInfoTopInStatusBar', false),
          );
        }
      },
    );
  }

  for (final legacyGlobalOnly in [false, true]) {
    test(
      'restores prerelease settings without importing device preferences (legacy=$legacyGlobalOnly)',
      () async {
        final state = enabled.copyWith(
          comicDownloadConcurrency: 7,
          readSetting: enabled.readSetting.copyWith(showSystemStatusBar: true),
        );
        final user = objectbox.userSettingBox.get(1)!;
        user.globalSetting = state;
        objectbox.userSettingBox.put(user);
        final remote = CompatibilityRemote()
          ..payload('settings', {
            'version': 'v1',
            'schemaVersion': 'v2',
            'syncTime': 20,
            'globalSetting': {
              'comicDownloadConcurrency': 2,
              'videoDownloadConcurrency': 3,
              'readSetting': {
                'showSystemStatusBar': false,
                'pageInfoTopInStatusBar': true,
              },
            },
            if (!legacyGlobalOnly)
              'blocks': {
                'library': {
                  'updatedAt': 20,
                  'data': {
                    'comicDownloadConcurrency': 2,
                    'videoDownloadConcurrency': 3,
                  },
                },
                'reader': {
                  'updatedAt': 20,
                  'data': {
                    'showSystemStatusBar': false,
                    'pageInfoTopInStatusBar': true,
                  },
                },
              },
          });
        await downloadSettingsData(
          remote,
          state: state,
          codec: compatibilitySettingsCodec,
        );
        final restored = objectbox.userSettingBox.get(1)!.globalSetting;
        expect(restored.comicDownloadConcurrency, 7);
        expect(restored.videoDownloadConcurrency, 3);
        expect(restored.readSetting.showSystemStatusBar, isTrue);
        expect(restored.readSetting.pageInfoTopInStatusBar, isTrue);
      },
    );
  }

  test('recognizes prerelease hashes without advancing the local library or reader clocks', () async {
    final state = enabled.copyWith(
      comicDownloadConcurrency: 7,
      readSetting: enabled.readSetting.copyWith(showSystemStatusBar: true),
    );
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = state;
    objectbox.userSettingBox.put(user);
    final before = await captureFullCloudSettings(state);
    final blocks = before['blocks'] as Map;
    Map<String, Object?> prereleaseBlock(
      String block,
      String precedingKey,
      String field,
      Object value,
    ) => {
      for (final entry in ((blocks[block] as Map)['data'] as Map).entries) ...{
        entry.key as String: entry.value,
        if (entry.key == precedingKey) field: value,
      },
    };

    final prefs = await SharedPreferences.getInstance();
    final olderBlocks = {
      'library': prereleaseBlock(
        'library',
        'retryDownloadUntilSuccess',
        'comicDownloadConcurrency',
        5,
      ),
      'reader': prereleaseBlock(
        'reader',
        'pageInfoTopInStatusBar',
        'showSystemStatusBar',
        false,
      ),
    };
    await prefs.setString(
      'sync.settings.block.meta.v3',
      jsonEncode({
        for (final entry in olderBlocks.entries)
          entry.key: {
            'hash': ComicSyncCore.calculateMd5(
              utf8.encode(jsonEncode(entry.value)),
            ),
            'updatedAt': 10,
          },
      }),
    );
    final remote = CompatibilityRemote()
      ..payload('settings', {
        'version': 'v1',
        'schemaVersion': 'v2',
        'syncTime': 20,
        'globalSetting': {},
        'blocks': {
          'library': {
            'updatedAt': 20,
            'data': {...olderBlocks['library']!, 'videoDownloadConcurrency': 3},
          },
          'reader': {
            'updatedAt': 20,
            'data': {...olderBlocks['reader']!, 'pageInfoTopInStatusBar': true},
          },
        },
      });
    await runSettingsSync(
      remote,
      currentGlobalSetting: state,
      codec: compatibilitySettingsCodec,
    );
    final restored = objectbox.userSettingBox.get(1)!.globalSetting;
    expect(restored.videoDownloadConcurrency, 3);
    expect(restored.readSetting.pageInfoTopInStatusBar, isTrue);
    expect(restored.comicDownloadConcurrency, 7);
    expect(restored.readSetting.showSystemStatusBar, isTrue);
  });

  for (final change in ['version', 'schema', 'block', 'field', 'video']) {
    test(
      'public settings upload refuses future $change before any writes or cleanup',
      () async {
        final remote = CompatibilityRemote();
        await uploadSettingsData(
          remote,
          state: enabled,
          codec: compatibilitySettingsCodec,
          includeAll: true,
        );
        final payload = remote.settings;
        if (change == 'version') payload['version'] = 'v99';
        if (change == 'schema') payload['schemaVersion'] = 'v99';
        if (change == 'block') {
          (payload['blocks'] as Map)['future-block'] = {
            'updatedAt': 2,
            'data': {'flag': true},
          };
        }
        if (change == 'field') {
          (((payload['blocks'] as Map)['reader'] as Map)['data']
                  as Map)['future-reader-field'] =
              true;
        }
        if (change == 'video') {
          (((payload['blocks'] as Map)['video'] as Map)['data']
                  as Map)['version'] =
              99;
        }
        remote.payload('settings', payload);
        final before = jsonEncode(
          remote.files.map((key, value) => MapEntry(key, base64Encode(value))),
        );
        final count = remote.uploads;
        await expectLater(
          uploadSettingsData(
            remote,
            state: enabled,
            codec: compatibilitySettingsCodec,
            includeAll: true,
          ),
          throwsA(isA<SyncCompatibilityException>()),
        );
        expect(remote.uploads, count);
        expect(remote.deletions, 0);
        expect(
          jsonEncode(
            remote.files.map(
              (key, value) => MapEntry(key, base64Encode(value)),
            ),
          ),
          before,
        );
      },
    );
  }

  test(
    'whole-round preflight reaches future settings before any channel applies or uploads',
    () async {
      final remote = CompatibilityRemote()
        ..payload('settings', {'version': 'v99'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth.fixture', 'local-only');
      await expectLater(
        preflightSyncRound(
          remote,
          comicCodec: const ComicSyncCodec(
            encode: compatibilityIdentity,
            decode: compatibilityIdentity,
          ),
          settingsCodec: compatibilitySettingsCodec,
          videoCodec: const VideoLibrarySyncCodec(
            encode: compatibilityIdentity,
            decode: compatibilityIdentity,
          ),
        ),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(remote.uploads, 0);
      expect(remote.deletions, 0);
      expect(prefs.getString('auth.fixture'), 'local-only');
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
    },
  );

  test(
    'known legacy settings without schema blocks still read through the public download',
    () async {
      final remote = CompatibilityRemote()
        ..payload('settings', {
          'version': 'v1',
          'syncTime': 1,
          'globalSetting': {'dynamicColor': false},
          'pluginConfigs': [],
          'pluginInfos': [],
        });
      final user = objectbox.userSettingBox.get(1)!;
      user.globalSetting = enabled.copyWith(dynamicColor: true);
      objectbox.userSettingBox.put(user);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isTrue,
      );
      await downloadSettingsData(
        remote,
        state: enabled,
        codec: compatibilitySettingsCodec,
        includeAll: true,
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isFalse,
      );
      expect(remote.uploads, 0);
      expect(remote.deletions, 0);
    },
  );

  test(
    'orphaned newer settings candidates cannot evict the active MD5 snapshot',
    () async {
      final remote = CompatibilityRemote();
      await uploadSettingsData(
        remote,
        state: enabled,
        codec: compatibilitySettingsCodec,
        includeAll: true,
      );
      final active = remote.files.keys.singleWhere(
        (path) => path.contains('/settings_'),
      );
      final bytes = List<int>.of(remote.files[active]!);
      final stamp = ComicSyncCore.extractSettingsTimestampFromRemotePath(
        active,
      )!;
      for (var i = 1; i <= 4; i++) {
        remote.files[remote.path('settings_${stamp + i}.bin')] = [i];
      }
      final before = remote.uploads;
      await runSettingsSync(
        remote,
        currentGlobalSetting: enabled,
        codec: compatibilitySettingsCodec,
      );
      expect(remote.files[active], bytes);
      expect(remote.uploads, before);
    },
  );
}
