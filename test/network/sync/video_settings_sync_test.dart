import 'sync_installed_fixture.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';

class _Remote implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  bool rejectUpload = false;
  String path(String value) => value.startsWith('/')
      ? value.substring(1)
      : value.startsWith('${ComicSyncCore.syncRemoteRootName}/')
      ? value
      : '${ComicSyncCore.syncRemoteRootName}/$value';
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String remotePath) async =>
      files[path(remotePath)] ?? (throw StateError('404'));
  @override
  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    if (rejectUpload) throw StateError('offline');
    files[path(remotePath)] = List.of(data);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> remotePaths) async {
    for (final p in remotePaths) {
      files.remove(path(p));
    }
  }

  Map<String, dynamic> get payload =>
      jsonDecode(
            utf8.decode(
              files.entries.where((e) => e.key.endsWith('.bin')).last.value,
            ),
          )
          as Map<String, dynamic>;
  void replacePayload(Map<String, dynamic> payload) {
    final key = files.keys.where((p) => p.endsWith('.bin')).last;
    final bytes = utf8.encode(jsonEncode(payload));
    files[key] = bytes;
    files[path(ComicSyncCore.settingsMd5FileName)] = utf8.encode(
      ComicSyncCore.calculateMd5(bytes),
    );
  }
}

Future<List<int>> _identity(List<int> value) async => value;
const _codec = SettingsSyncCodec(encode: _identity, decode: _identity);
const _enabled = GlobalSettingState(
  syncSetting: SyncSettingState(syncSettings: true, syncPlugins: true),
);

void main() {
  late Directory temporary;
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('breeze_video_sync_');
    ObjectBox.resetForTests();
    objectbox = await ObjectBox.create(dbRootPath: temporary.path);
  });
  tearDownAll(() async {
    objectbox.close();
    await temporary.delete(recursive: true);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    await installSyncPlugins([
      'bika',
      'jm',
      'copy',
      'hanime',
      'omo',
      'ikun',
      'modu',
      'oscar',
    ]);
    objectbox.userSettingBox.removeAll();
  });

  test(
    'explicit full backup restores account details and all eight plugin configurations even when auto options are off',
    () async {
      // Explicit full backups include retained data even with no installed package.
      objectbox.pluginInfoBox.removeAll();
      const disabled = GlobalSettingState(
        syncSetting: SyncSettingState(syncSettings: false, syncPlugins: false),
      );
      objectbox.userSettingBox.put(UserSetting()..globalSetting = disabled);
      const sources = [
        'bika',
        'jm',
        'copy',
        'hanime',
        'omo',
        'ikun',
        'modu',
        'oscar',
      ];
      final remote = _Remote();
      for (final source in sources) {
        await savePluginConfigValue(source, 'personal.option', source);
        if (['bika', 'jm'].contains(source)) {
          await savePluginConfigValue(
            source,
            'auth.account',
            'fixture-$source',
          );
          await savePluginConfigValue(
            source,
            'auth.password',
            'fixture-password',
          );
        } else if (['copy', 'hanime', 'omo'].contains(source)) {
          await savePluginConfigValue(source, 'account.credentials', {
            'version': 1,
            'account': 'fixture-$source',
            'password': 'fixture-password',
            'origin': 'https://$source.test',
            'deleted': false,
            'updatedAt': 1,
          });
        }
      }
      await VideoPlaybackPreferences.save('defaultSpeed', 1.5);
      await uploadSettingsData(remote, state: disabled, codec: _codec);
      expect(
        remote.files,
        isEmpty,
        reason: 'disabled automatic setting choices remain respected',
      );
      await uploadSettingsData(
        remote,
        state: disabled,
        codec: _codec,
        includeAll: true,
      );
      expect(remote.payload['pluginConfigs'], hasLength(8));
      SharedPreferences.setMockInitialValues({'sync.device_id': 'new-device'});
      objectbox.pluginConfigBox.removeAll();
      await downloadSettingsData(
        remote,
        state: disabled,
        codec: _codec,
        includeAll: true,
      );
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.5);
      for (final source in sources) {
        expect(
          loadPluginConfigValue<String>(
            source,
            'personal.option',
            fallback: '',
          ),
          source,
        );
        if (['bika', 'jm'].contains(source)) {
          expect(
            loadPluginConfigValue<String>(
              source,
              'auth.password',
              fallback: '',
            ),
            'fixture-password',
          );
        } else if (['copy', 'hanime', 'omo'].contains(source)) {
          expect(
            loadPluginConfigValue<Map>(
              source,
              'account.credentials',
              fallback: {},
            )['account'],
            'fixture-$source',
          );
        } else {
          expect(
            loadPluginConfigValue<Map>(
              source,
              'account.credentials',
              fallback: {},
            ),
            isEmpty,
          );
        }
      }
      expect(
        (await SharedPreferences.getInstance()).getString('sync.device_id'),
        'new-device',
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.syncSetting.syncPlugins,
        isFalse,
      );
    },
  );

  test(
    'upload and restore use the existing payload and preserve other plugins',
    () async {
      final remote = _Remote();
      await VideoPlaybackPreferences.save('defaultSpeed', 1.5);
      await VideoPlaybackPreferences.save('fullscreenOrientation', 'portrait');
      await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
      await VideoPlaybackPreferences.save('portraitMode', 'episodes');
      await savePluginConfigValue('hanime', 'account.backup', {
        'version': 1,
        'name': 'Example',
        'cookies': [],
      });
      await savePluginConfigValue(
        'bika',
        'auth.authorization',
        'fake-bika-session',
      );
      await uploadSettingsData(remote, state: _enabled, codec: _codec);
      expect(remote.payload['schemaVersion'], 'v2');
      expect(
        remote.payload['blocks']['video']['data']['values']['defaultSpeed'],
        1.5,
      );
      expect(
        remote.payload['blocks'].keys,
        containsAll(['appearance', 'library', 'reader', 'video', 'plugins']),
      );
      expect(
        remote.files.keys.every(
          (p) => p.startsWith('${ComicSyncCore.syncRemoteRootName}/'),
        ),
        isTrue,
      );
      SharedPreferences.setMockInitialValues({});
      objectbox.pluginConfigBox.removeAll();
      await savePluginConfigValue('unrelated', 'keep', true);
      await downloadSettingsData(remote, state: _enabled, codec: _codec);
      final p = await VideoPlaybackPreferences.read();
      expect(p.defaultSpeed, 1.5);
      expect(p.fullscreenOrientation, 'portrait');
      expect(p.controlsStyle, 'breeze');
      expect(
        p.portraitMode,
        'focus',
        reason: 'Removed swipe workflow cannot be reenabled by legacy sync',
      );
      expect(
        loadPluginConfigValue<String>(
          'bika',
          'auth.authorization',
          fallback: '',
        ),
        'fake-bika-session',
      );
      expect(
        loadPluginConfigValue<bool>('unrelated', 'keep', fallback: false),
        isTrue,
      );
      expect(
        loadPluginConfigValue<Map>(
          'hanime',
          'account.backup',
          fallback: {},
        )['name'],
        'Example',
      );
    },
  );

  test(
    'a fresh device does not overwrite older cloud preferences with defaults',
    () async {
      final remote = _Remote();
      await VideoPlaybackPreferences.save('defaultSpeed', 2.0);
      await uploadSettingsData(remote, state: _enabled, codec: _codec);
      SharedPreferences.setMockInitialValues({});
      await runSettingsSync(
        remote,
        currentGlobalSetting: _enabled,
        codec: _codec,
      );
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 2.0);
      expect(
        remote.payload['blocks']['video']['data']['values']['defaultSpeed'],
        2.0,
      );
    },
  );

  test(
    'disabled switches exclude upload and leave local restored values untouched',
    () async {
      final remote = _Remote();
      await VideoPlaybackPreferences.save('defaultSpeed', 2.0);
      await uploadSettingsData(remote, state: _enabled, codec: _codec);
      await VideoPlaybackPreferences.save('defaultSpeed', 0.75);
      await savePluginConfigValue('bika', 'auth.authorization', 'local-only');
      const disabled = GlobalSettingState();
      await downloadSettingsData(remote, state: disabled, codec: _codec);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 0.75);
      expect(
        loadPluginConfigValue<String>(
          'bika',
          'auth.authorization',
          fallback: '',
        ),
        'local-only',
      );
      final clean = _Remote();
      await uploadSettingsData(
        clean,
        state: const GlobalSettingState(
          syncSetting: SyncSettingState(syncPlugins: true),
        ),
        codec: _codec,
      );
      expect(clean.payload['blocks'].keys, ['plugins']);
    },
  );

  test(
    'legacy and future video blocks cannot reset current video settings',
    () async {
      final remote = _Remote();
      await uploadSettingsData(remote, state: _enabled, codec: _codec);
      final legacy = remote.payload;
      (legacy['blocks'] as Map).remove('video');
      remote.replacePayload(legacy);
      await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
      await downloadSettingsData(remote, state: _enabled, codec: _codec);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.25);
      legacy['blocks']['video'] = {
        'updatedAt': 9999999999999,
        'data': {
          'version': 99,
          'values': {'defaultSpeed': 2.0},
        },
      };
      remote.replacePayload(legacy);
      final before = jsonEncode(remote.files);
      await expectLater(
        downloadSettingsData(remote, state: _enabled, codec: _codec),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(jsonEncode(remote.files), before);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.25);
    },
  );

  test('failed upload does not delete the previous cloud snapshot', () async {
    final remote = _Remote();
    await uploadSettingsData(remote, state: _enabled, codec: _codec);
    final previous = jsonEncode(remote.files);
    remote.rejectUpload = true;
    await VideoPlaybackPreferences.save('defaultSpeed', 1.5);
    await expectLater(
      uploadSettingsData(remote, state: _enabled, codec: _codec),
      throwsStateError,
    );
    expect(jsonEncode(remote.files), previous);
  });

  for (final archiveContent in [
    'settings',
    'other plugin',
    'same backup',
    'different backup',
  ]) {
    test(
      'browser restore only schedules the archived backup ($archiveContent)',
      () async {
        final remote = _Remote();
        Future<void> saveBackup(String host) =>
            savePluginConfigValue('hanime', 'account.backup', {
              'version': 1,
              'origin': 'https://$host.fixture.test',
              'deleted': true,
            });
        final hasBackup = archiveContent.endsWith('backup');
        if (hasBackup) await saveBackup('archive');
        if (archiveContent == 'other plugin') {
          await savePluginConfigValue('bika', 'fixture.option', 'remote');
        }
        final uploadState = archiveContent == 'settings'
            ? _enabled.copyWith(
                syncSetting: _enabled.syncSetting.copyWith(syncPlugins: false),
              )
            : _enabled;
        await uploadSettingsData(remote, state: uploadState, codec: _codec);
        if (archiveContent == 'other plugin') {
          await savePluginConfigValue('bika', 'fixture.option', 'local');
        }
        if (archiveContent != 'same backup') await saveBackup('device');

        await downloadSettingsData(remote, state: _enabled, codec: _codec);

        final preferences = await SharedPreferences.getInstance();
        final pending =
            jsonDecode(
                  preferences.getString(
                        PluginAccountSyncCoordinator.pendingKey,
                      ) ??
                      '{}',
                )
                as Map;
        expect(pending.keys, hasBackup ? ['hanime'] : isEmpty);
      },
    );
  }

  test('forgetting an account is uploaded as an explicit value', () async {
    final remote = _Remote();
    await savePluginConfigValue('hanime', 'account.backup', {
      'deleted': true,
      'version': 1,
    });
    await uploadSettingsData(remote, state: _enabled, codec: _codec);
    objectbox.pluginConfigBox.removeAll();
    await downloadSettingsData(remote, state: _enabled, codec: _codec);
    expect(
      loadPluginConfigValue<Map>(
        'hanime',
        'account.backup',
        fallback: {},
      )['deleted'],
      isTrue,
    );
  });
  test(
    'main navigation syncs both placements and explicit defaults atomically',
    () async {
      const enabled = GlobalSettingState(
        syncSetting: SyncSettingState(syncSettings: true),
      );
      final remote = _Remote();
      final user = UserSetting(id: 1)..globalSetting = enabled;
      objectbox.userSettingBox.put(user);
      await uploadSettingsData(remote, state: enabled, codec: _codec);
      expect(remote.payload['blocks'], isNot(contains('mainNavigation')));
      expect(
        remote.payload['globalSetting'],
        isNot(contains('mainNavigationSlots')),
      );

      const placement = 'left,more';
      user.globalSetting = enabled.copyWith(mainNavigationSlots: placement);
      objectbox.userSettingBox.put(user);
      await uploadSettingsData(remote, state: enabled, codec: _codec);
      final blocks = remote.payload['blocks'] as Map;
      expect(blocks['mainNavigation']['data'], {
        'mainNavigationSlots': placement,
      });
      expect(
        blocks['appearance']['data'],
        isNot(contains('mainNavigationSlots')),
      );
      final customizedArchive = remote.payload;

      SharedPreferences.setMockInitialValues({'sync.device_id': 'receiver'});
      user.globalSetting = enabled;
      objectbox.userSettingBox.put(user);
      await downloadSettingsData(remote, state: enabled, codec: _codec);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.mainNavigationSlots,
        placement,
      );

      final legacy = remote.payload;
      (legacy['blocks'] as Map).remove('mainNavigation');
      (legacy['globalSetting'] as Map).remove('mainNavigationSlots');
      remote.replacePayload(legacy);
      await downloadSettingsData(remote, state: enabled, codec: _codec);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.mainNavigationSlots,
        placement,
      );

      remote.replacePayload(customizedArchive);
      user.globalSetting = enabled;
      objectbox.userSettingBox.put(user);
      await uploadSettingsData(remote, state: enabled, codec: _codec);
      expect(remote.payload['blocks']['mainNavigation']['data'], {
        'mainNavigationSlots': '',
      });
      user.globalSetting = enabled.copyWith(mainNavigationSlots: 'more,left');
      objectbox.userSettingBox.put(user);
      await downloadSettingsData(remote, state: enabled, codec: _codec);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.mainNavigationSlots,
        isEmpty,
      );
    },
  );
}
