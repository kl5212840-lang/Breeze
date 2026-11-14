import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import '../../test_helper.dart';

const _uuid = '99999999-1111-4222-8333-444444444444';
const _enabled = GlobalSettingState(
  syncSetting: SyncSettingState(syncPlugins: true),
);
Future<List<int>> _identity(List<int> value) async => value;
const _codec = SettingsSyncCodec(encode: _identity, decode: _identity);

class _Archive implements ComicSyncRemoteAdapter {
  _Archive(Map<String, dynamic> value) : bytes = utf8.encode(jsonEncode(value));
  final List<int> bytes;
  String get root => ComicSyncCore.syncRemoteRootName;
  @override
  Future<List<String>> listRemoteDataFiles() async => [
    '$root/settings_10000.bin',
  ];
  @override
  Future<List<int>> downloadRemoteFile(String path) async =>
      path.endsWith('settings.md5')
      ? utf8.encode(ComicSyncCore.calculateMd5(bytes))
      : bytes;
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('read only');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async => throw StateError('read only');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw StateError('read only');
}

PluginInfo _info(int clock, {bool deleted = false, int installedAt = 100}) =>
    PluginInfo(
      uuid: _uuid,
      version: '1.0.$clock',
      originScript: deleted ? '' : 'fixture-source-$clock',
      insertedAt: DateTime.fromMillisecondsSinceEpoch(installedAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true),
      isEnabled: !deleted,
      isDeleted: deleted,
      deletedAt: deleted
          ? DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true)
          : null,
      lastLoadSuccess: false,
      debug: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = _enabled;
    objectbox.userSettingBox.put(user);
  });

  Future<SettingsArchiveImportPlan> incoming(
    PluginInfo info, {
    int blockClock = 10000,
    bool legacy = false,
    GlobalSettingState state = _enabled,
  }) async {
    final data = {
      'pluginInfos': [info.toJson()],
      'pluginConfigs': [
        PluginConfig(name: _uuid, config: '{"setting":"incoming"}').toJson(),
      ],
    };
    final payload = legacy
        ? {
            'version': 'v1',
            'schemaVersion': 'v1',
            'syncTime': blockClock,
            'globalSetting': <String, dynamic>{},
            ...data,
          }
        : {
            'version': 'v1',
            'schemaVersion': 'v2',
            'syncTime': blockClock,
            'blocks': {
              'plugins': {'updatedAt': blockClock, 'data': data},
            },
          };
    return prepareSettingsArchiveImport(
      await readSettingsArchiveData(_Archive(payload), codec: _codec),
      state: state,
      protectVersionedLocalFields: legacy,
    );
  }

  PluginInfo current() => objectbox.pluginInfoBox.getAll().single;
  List<dynamic> rows(SettingsArchiveImportPlan plan) =>
      plan.compatibilityPayload['pluginInfos'] as List;

  test(
    'local deletion remains in exported payload, not only hidden in UI',
    () async {
      objectbox.pluginInfoBox.put(_info(2000, deleted: true));
      final plan = await prepareSettingsArchiveImport(
        null,
        state: _enabled,
        includeAll: true,
      );
      expect(rows(plan), hasLength(1));
      expect(rows(plan).single['isDeleted'], isTrue);
      expect(
        rows(plan).single['deletedAt'],
        _info(2000, deleted: true).toJson()['deletedAt'],
      );
      for (final field in ['insertedAt', 'updatedAt', 'deletedAt']) {
        expect(
          DateTime.parse(rows(plan).single[field] as String).isUtc,
          isTrue,
          reason:
              '$field must retain its instant when the backup changes timezone',
        );
      }
    },
  );

  test(
    'older active file cannot revive a newer local deletion or its config',
    () async {
      objectbox.pluginInfoBox.put(_info(2000, deleted: true));
      final plan = await incoming(_info(1000), blockClock: 90000);
      expect(rows(plan).single['isDeleted'], isTrue);
      expect(plan.compatibilityPayload['pluginConfigs'], isEmpty);
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(current().isDeleted, isTrue);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
    },
  );

  test(
    'newer remote deletion commits tombstone and removes only its config',
    () async {
      objectbox.pluginInfoBox.put(_info(1000));
      objectbox.pluginConfigBox.putMany([
        PluginConfig(name: _uuid, config: '{"setting":"local"}'),
        PluginConfig(name: 'unrelated', config: '{"keep":true}'),
      ]);
      final plan = await incoming(_info(2000, deleted: true));
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(current().isDeleted, isTrue);
      expect(current().updatedAt.millisecondsSinceEpoch, 2000);
      expect(objectbox.pluginConfigBox.getAll().map((e) => e.name), [
        'unrelated',
      ]);
      expect(rows(plan).single['isDeleted'], isTrue);
    },
  );

  test(
    'confirmed newer v2 reinstall clears old tombstone and restores config',
    () async {
      objectbox.pluginInfoBox.put(_info(1000, deleted: true));
      final plan = await incoming(_info(2000, installedAt: 2000));
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(current().isDeleted, isFalse);
      expect(current().deletedAt, isNull);
      expect(current().updatedAt.millisecondsSinceEpoch, 2000);
      expect(current().insertedAt.millisecondsSinceEpoch, 2000);
      expect(
        jsonDecode(objectbox.pluginConfigBox.getAll().single.config)['setting'],
        'incoming',
      );
    },
  );

  for (final localDeleted in [true, false]) {
    test(
      'equal revision deletion wins in either merge direction: $localDeleted',
      () async {
        objectbox.pluginInfoBox.put(_info(2000, deleted: localDeleted));
        final plan = await incoming(
          _info(2000, deleted: !localDeleted),
          blockClock: 90000,
        );
        expect(rows(plan).single['isDeleted'], isTrue);
        objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
        expect(current().isDeleted, isTrue);
        expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      },
    );
  }

  test(
    'legacy block clock cannot certify reinstall after local deletion',
    () async {
      objectbox.pluginInfoBox.put(_info(1000, deleted: true));
      final plan = await incoming(
        _info(2000, installedAt: 2000),
        blockClock: 90000,
        legacy: true,
      );
      expect(rows(plan).single['isDeleted'], isTrue);
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(current().isDeleted, isTrue);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
    },
  );

  test(
    'ordinary fetch with a newer updatedAt cannot certify reinstall',
    () async {
      objectbox.pluginInfoBox.put(_info(1000, deleted: true));
      final refreshed = _info(9000)..lastLoadSuccess = true;
      final plan = await incoming(refreshed, blockClock: 90000);
      expect(rows(plan).single['isDeleted'], isTrue);
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(current().isDeleted, isTrue);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
    },
  );

  test('disabled plugin sync preserves local plugin and config', () async {
    objectbox.pluginInfoBox.put(_info(1000));
    objectbox.pluginConfigBox.put(
      PluginConfig(name: _uuid, config: '{"keep":true}'),
    );
    final plan = await incoming(
      _info(2000, deleted: true),
      state: const GlobalSettingState(),
    );
    objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
    expect(current().isDeleted, isFalse);
    expect(
      jsonDecode(objectbox.pluginConfigBox.getAll().single.config)['keep'],
      isTrue,
    );
  });
}
