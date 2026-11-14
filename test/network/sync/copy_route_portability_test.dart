import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';

import '../../test_helper.dart';

const _speed = 'network.speed.v1';
const _winner = 'network.autoRoute.v1';
const _state = GlobalSettingState(
  syncSetting: SyncSettingState(syncPlugins: true),
);
Future<List<int>> _identity(List<int> bytes) async => bytes;
const _codec = SettingsSyncCodec(encode: _identity, decode: _identity);

class _Archive extends ComicSyncRemoteAdapter {
  _Archive(String encoded) : bytes = utf8.encode(encoded);
  final List<int> bytes;
  @override
  Future<List<String>> listRemoteDataFiles() async => [
    '${ComicSyncCore.syncRemoteRootName}/settings_10000.bin',
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
      throw UnimplementedError();
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw UnimplementedError();
}

Future<SettingsArchiveImportPlan> _restore(Map<String, dynamic> config) async {
  final adapter = _Archive(
    jsonEncode({
      'version': 'v1',
      'schemaVersion': 'v2',
      'syncTime': 10000,
      'blocks': {
        'plugins': {
          'updatedAt': 10000,
          'data': {
            'pluginInfos': [],
            'pluginConfigs': [
              {'name': copyPluginConfigSource, 'config': jsonEncode(config)},
            ],
          },
        },
      },
    }),
  );
  final remote = await readSettingsArchiveData(adapter, codec: _codec);
  return prepareSettingsArchiveImport(
    remote,
    state: _state,
    includeAll: true,
    importSettings: false,
    importPlugins: true,
    direction: SyncDirection.restore,
  );
}

Map<String, dynamic> _config(String mode, String platform, String device) {
  var result = <String, dynamic>{'api.domain': mode, 'api.platform': platform};
  result = updatePluginConfigField(result, _winner, '热辣漫画线路4', nowMs: 100);
  return updatePluginConfigField(result, _speed, {
    'device': device,
  }, nowMs: 101);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = _state;
    objectbox.userSettingBox.put(user);
  });

  test(
    'cloud restore preserves Copy local route results and refreshes a changed request platform',
    () async {
      final local = _config('大陆专线1', '1', 'local');
      objectbox.pluginConfigBox.put(
        PluginConfig(name: copyPluginConfigSource, config: jsonEncode(local)),
      );
      final remote = _config('auto', '3', 'remote');
      final restore = await _restore(remote);
      final rows = restore.compatibilityPayload['pluginConfigs'] as List;
      expect(jsonDecode(rows.single['config'] as String), {
        'api.domain': 'auto',
        'api.platform': '3',
      });

      final before = pluginEndpointRevision(copyPluginConfigSource);
      final changed = pluginEndpointChanges.firstWhere(
        (source) => source == copyPluginConfigSource,
      );
      objectbox.store.runInTransaction(TxMode.write, restore.persistDatabase);
      await changed.timeout(const Duration(seconds: 2));
      final active = readHostPluginConfiguration(copyPluginConfigSource);
      expect(pluginEndpointRevision(copyPluginConfigSource), before + 1);
      expect(active['api.domain'], 'auto');
      expect(active['api.platform'], '3');
      expect(active[_winner], '大陆专线1');
      expect(active[_speed], {'device': 'local'});
      expect(pluginConfigFieldRevision(active, _speed), 101);
    },
  );

  test(
    'remote route measurements alone neither replace this Copy winner nor refresh the account',
    () async {
      final local = _config('auto', '1', 'local');
      objectbox.pluginConfigBox.put(
        PluginConfig(name: copyPluginConfigSource, config: jsonEncode(local)),
      );
      final remote = updatePluginConfigField(
        _config('auto', '1', 'remote'),
        _winner,
        '国际服2',
        nowMs: 102,
      );
      final restore = await _restore(remote);
      final before = pluginEndpointRevision(copyPluginConfigSource);
      objectbox.store.runInTransaction(TxMode.write, restore.persistDatabase);
      await Future<void>.delayed(Duration.zero);
      expect(readHostPluginConfiguration(copyPluginConfigSource), local);
      expect(pluginEndpointRevision(copyPluginConfigSource), before);
    },
  );
}
