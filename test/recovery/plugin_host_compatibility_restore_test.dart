import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/offline_backup_merge.dart';

import '../test_helper.dart';

const source = '99999999-1111-4222-8333-444444444444';
const peer = '99999999-1111-4222-8333-444444444445';
const enabled = GlobalSettingState(syncSetting: SyncSettingState(syncPlugins: true));
Future<List<int>> identity(List<int> bytes) async => bytes;
const codec = SettingsSyncCodec(encode: identity, decode: identity);

PluginInfo info(String uuid, int clock, int protocol) => PluginInfo(
  uuid: uuid, version: '0.1.$clock', originScript: 'fixture-script-$clock',
  insertedAt: DateTime.fromMillisecondsSinceEpoch(100, isUtc: true),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true),
  isEnabled: true, isDeleted: false, lastLoadSuccess: false, debug: false,
  getInfoJson: jsonEncode({'uuid': uuid, 'name': 'Fixture $uuid', 'version': '0.1.$clock',
    'function': [{'action': {'type': 'openVideoLibrary', 'payload': {'protocol': protocol}}}]}),
);
Map<String, dynamic> settings(List<PluginInfo> infos) => {
  'version': 'v1', 'schemaVersion': 'v2', 'syncTime': 10000,
  'blocks': {'plugins': {'updatedAt': 10000, 'data': {
    'pluginInfos': infos.map((row) => row.toJson()).toList(),
    'pluginConfigs': [PluginConfig(name: source, config: '{"account":"backup-account"}').toJson()],
  }}},
};

class Input implements ComicSyncRemoteAdapter {
  Input(Map<String, dynamic> raw) : bytes = utf8.encode(jsonEncode(raw));
  final List<int> bytes;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => ['${ComicSyncCore.syncRemoteRootName}/settings_10000.bin'];
  @override
  Future<List<int>> downloadRemoteFile(String path) async => path.endsWith('settings.md5')
    ? utf8.encode(ComicSyncCore.calculateMd5(bytes)) : bytes;
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async => throw StateError('read-only fixture');
  @override
  Future<void> uploadRemoteFile(String path, List<int> data, {String contentType = 'application/octet-stream'}) async => throw StateError('read-only fixture');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async => throw StateError('read-only fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root, incoming;
  late LocalAppearanceImages images;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sync.device_id': 'host-compat-fixture'});
    await LocalPluginInstallationState.instance.reload();
    PluginHostCompatibilityNotices.instance.takePending();
    objectbox.pluginInfoBox.removeAll(); objectbox.pluginConfigBox.removeAll();
    objectbox.unifiedFavoriteBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!..globalSetting = enabled;
    objectbox.userSettingBox.put(user);
    root = await Directory.systemTemp.createTemp('breeze-host-compat-');
    incoming = await Directory(p.join(root.path, 'incoming')).create();
    images = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'images')));
    await images.load();
  });
  tearDown(() async { images.paths.dispose(); await root.delete(recursive: true); });

  Future<void> writeBackup({required bool metadata}) async {
    final db = jsonDecode(objectbox.collectAllDataJson(removeIds: true)) as Map<String, dynamic>;
    // A real backup contains legal database rows, not an empty placeholder.
    db['pluginInfo'] = [info(source, 2000, 3).toJson(), info(peer, 2000, 2).toJson()];
    db['pluginConfig'] = [PluginConfig(name: source, config: '{"account":"backup-account"}').toJson()];
    db['unifiedComicFavorite'] = [UnifiedComicFavorite(
      uniqueKey: '$source::work', source: source, comicId: 'work', title: 'Kept favorite',
      description: '', cover: '', creator: '', titleMeta: '', metadata: '{"fixture":"kept"}',
      createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026), deleted: false, schemaVersion: 2,
    ).toJson()];
    await File(p.join(incoming.path, 'config.json')).writeAsString(jsonEncode({
      'format': 'BreezeBackup', 'schemaVersion': 1, 'version': 'fixture', 'includeDownloads': false,
    }));
    await File(p.join(incoming.path, 'objectbox.json')).writeAsString(jsonEncode(db));
    if (metadata) await File(p.join(incoming.path, 'sync-settings.json'))
      .writeAsString(jsonEncode(settings([info(source, 2000, 3), info(peer, 2000, 2)])));
  }

  test('settings apply skips only future script and keeps account config plus compatible peer', () async {
    objectbox.pluginInfoBox.put(info(source, 1000, 1));
    final plan = await prepareSettingsArchiveImport(
      await readSettingsArchiveData(Input(settings([info(source, 2000, 3), info(peer, 2000, 2)])), codec: codec),
      state: enabled, includeAll: true,
    );
    objectbox.store.runInTransaction<void>(TxMode.write, plan.persistDatabase);
    final rows = {for (final row in objectbox.pluginInfoBox.getAll()) row.uuid: row};
    expect(rows[source]!.originScript, 'fixture-script-1000');
    expect(rows[peer]!.originScript, 'fixture-script-2000');
    expect(objectbox.pluginConfigBox.getAll().single.config, contains('backup-account'));
    expect(PluginHostCompatibilityNotices.instance.takePending().single.uuid, source);
  });

  test('unsupported uninstalled source keeps restored account data without installing its script', () async {
    final plan = await prepareSettingsArchiveImport(
      await readSettingsArchiveData(Input(settings([info(source, 2000, 3)])), codec: codec),
      state: enabled, includeAll: true,
    );
    objectbox.store.runInTransaction<void>(TxMode.write, plan.persistDatabase);
    expect(objectbox.pluginInfoBox.getAll(), isEmpty);
    expect(objectbox.pluginConfigBox.getAll().single.config, contains('backup-account'));
    expect(PluginHostCompatibilityNotices.instance.takePending().single.uuid, source);
  });

  for (final metadata in [false, true]) {
    test('file merge keeps script and data through ${metadata ? 'sync-settings' : 'legacy database fallback'}', () async {
      objectbox.pluginInfoBox.put(info(source, 1000, 1));
      await writeBackup(metadata: metadata);
      final plan = await prepareOfflineBackupMerge(incoming, stagingParent: root, appearanceImages: images);
      try {
        final db = jsonDecode(await File(p.join(plan.directory.path, 'objectbox.json')).readAsString()) as Map;
        final rows = {for (final row in db['pluginInfo'] as List) row['uuid']: row};
        expect(rows[source]['originScript'], 'fixture-script-1000');
        expect(rows[peer]['originScript'], 'fixture-script-2000');
        expect((db['pluginConfig'] as List).single['config'], contains('backup-account'));
        expect((db['unifiedComicFavorite'] as List).single['title'], 'Kept favorite');
        expect(PluginHostCompatibilityNotices.instance.takePending().single.uuid, source);
      } finally { await plan.dispose(); }
    });
  }

  test('full restore preserves old same-source script before clear and retains all compatible data', () async {
    objectbox.pluginInfoBox.put(info(source, 1000, 1));
    await writeBackup(metadata: true);
    await importExtractedBreezeData(incoming.path, mode: BackupImportMode.restore,
      hooks: BackupImportHooks(appearanceImages: images, recoveryDirectory: Directory(p.join(root.path, 'recovery'))));
    final rows = {for (final row in objectbox.pluginInfoBox.getAll()) row.uuid: row};
    expect(rows[source]!.originScript, 'fixture-script-1000');
    expect(rows[peer]!.originScript, 'fixture-script-2000');
    expect(objectbox.pluginConfigBox.getAll().single.config, contains('backup-account'));
    expect(objectbox.unifiedFavoriteBox.getAll().single.title, 'Kept favorite');
    expect(PluginHostCompatibilityNotices.instance.takePending().single.uuid, source);
  });

  test('full restore on a new device skips future plugin but keeps its account and favorite', () async {
    await writeBackup(metadata: false);
    await importExtractedBreezeData(incoming.path, mode: BackupImportMode.restore,
      hooks: BackupImportHooks(appearanceImages: images, recoveryDirectory: Directory(p.join(root.path, 'recovery'))));
    expect(objectbox.pluginInfoBox.getAll().single.uuid, peer);
    expect(objectbox.pluginConfigBox.getAll().single.config, contains('backup-account'));
    expect(objectbox.unifiedFavoriteBox.getAll().single.source, source);
    expect(PluginHostCompatibilityNotices.instance.takePending().single.uuid, source);
  });

  test('full restore keeps account-only ownership even when unsupported plugin has no other records', () async {
    await LocalPluginInstallationState.instance.setDataExclusions(source,
      {PluginDataScope.accountSettings}, beforeWrite: (_) async {});
    await writeBackup(metadata: false);
    final file = File(p.join(incoming.path, 'objectbox.json'));
    final db = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    db['unifiedComicFavorite'] = [];
    await file.writeAsString(jsonEncode(db));
    await importExtractedBreezeData(incoming.path, mode: BackupImportMode.restore,
      hooks: BackupImportHooks(appearanceImages: images, recoveryDirectory: Directory(p.join(root.path, 'recovery'))));
    expect(objectbox.pluginInfoBox.getAll().single.uuid, peer);
    expect(objectbox.pluginConfigBox.getAll().single.config, contains('backup-account'));
    expect(LocalPluginInstallationState.instance.isDataExcluded(source, PluginDataScope.accountSettings), isFalse);
  });
}
