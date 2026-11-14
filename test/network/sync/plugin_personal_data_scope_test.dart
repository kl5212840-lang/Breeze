import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_data_clear.dart';
import 'package:zephyr/service/plugin_portable_data_clear.dart';

import '../../test_helper.dart';

const _source = '99999999-1111-4222-8333-444444444444';
const _other = '88888888-1111-4222-8333-444444444444';
const _enabled = GlobalSettingState(
  syncSetting: SyncSettingState(syncPlugins: true),
);
Future<List<int>> _identity(List<int> value) async => value;
const _codec = SettingsSyncCodec(encode: _identity, decode: _identity);

class _Archive extends ComicSyncRemoteAdapter {
  _Archive(Map<String, dynamic> data)
    : bytes = utf8.encode(
        jsonEncode({
          'version': 'v1',
          'schemaVersion': 'v2',
          'syncTime': 90000,
          'blocks': {
            'plugins': {'updatedAt': 90000, 'data': data},
          },
        }),
      );
  final List<int> bytes;
  @override
  Future<List<String>> listRemoteDataFiles() async => [
    '${ComicSyncCore.syncRemoteRootName}/settings_90000.bin',
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
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async => throw StateError('read only');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw StateError('read only');
}

class _EmptyWritable extends ComicSyncRemoteAdapter {
  final writes = <String>[];
  Future<void> Function()? afterDataWrite;
  @override
  Future<List<String>> listRemoteDataFiles() async => [];
  @override
  Future<List<int>> downloadRemoteFile(String path) async =>
      throw StateError('404');
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<void> uploadRemoteMd5(String value) async {}
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    writes.add(path);
    if (path.endsWith('.bin')) await afterDataWrite?.call();
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = _enabled;
    objectbox.userSettingBox.put(user);
  });

  Future<int> exclude(Set<PluginDataScope> scopes) =>
      LocalPluginInstallationState.instance.setDataExclusions(
        _source,
        scopes,
        beforeWrite: (_) async {},
      );
  Future<SettingsArchiveImportPlan> mergeRemote(String config) async {
    final remote = await readSettingsArchiveData(
      _Archive({
        'pluginInfos': <dynamic>[],
        'pluginConfigs': [PluginConfig(name: _source, config: config).toJson()],
      }),
      codec: _codec,
    );
    return prepareSettingsArchiveImport(remote, state: _enabled);
  }

  String projectedConfig(SettingsArchiveImportPlan plan) =>
      (plan.compatibilityPayload['pluginConfigs'] as List).single['config']
          as String;

  test(
    'local account purge blocks refill while full cloud merge retains remote credentials',
    () async {
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: _source,
          config:
              '{"account.credentials":{"account":"synthetic"},"theme":"dark"}',
        ),
      );
      final epoch = await exclude({PluginDataScope.accountSettings});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: false,
        expectedEpoch: epoch,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      final plan = await mergeRemote(
        '{"account.credentials":{"account":"synthetic"},"theme":"dark"}',
      );
      expect(jsonDecode(projectedConfig(plan))['account.credentials'], {
        'account': 'synthetic',
      });
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      await LocalPluginInstallationState.instance
          .clearDataExclusionsForExplicitRestore([
            _source,
          ], beforeWrite: (_) async {});
      final restored = await mergeRemote(
        '{"account.credentials":{"account":"synthetic"},"theme":"dark"}',
      );
      objectbox.store.runInTransaction(TxMode.write, restored.persistDatabase);
      expect(
        jsonDecode(objectbox.pluginConfigBox.getAll().single.config)['theme'],
        'dark',
      );
    },
  );

  test(
    'cloud account purge creates per-key tombstones without deleting installation rows',
    () async {
      final info = PluginInfo(
        uuid: _source,
        version: '1',
        originScript: 'synthetic',
        insertedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        isEnabled: false,
        isDeleted: false,
        lastLoadSuccess: false,
        debug: false,
      );
      objectbox.pluginInfoBox.put(info);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: _source,
          config: '{"account.credentials":"synthetic","theme":"dark"}',
        ),
      );
      final epoch = await exclude({PluginDataScope.accountSettings});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
        nowMs: 2000,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      final local =
          jsonDecode(objectbox.pluginConfigBox.getAll().single.config)
              as Map<String, dynamic>;
      expect(visiblePluginConfig(local), isEmpty);
      expect(
        local[pluginConfigSyncFields]['account.credentials']['deleted'],
        isTrue,
      );
      final plan = await mergeRemote(
        '{"account.credentials":"synthetic","theme":"dark"}',
      );
      final cloud = jsonDecode(projectedConfig(plan)) as Map<String, dynamic>;
      expect(
        visiblePluginConfig(cloud),
        isEmpty,
        reason: 'a legacy block clock cannot resurrect deleted fields',
      );
      expect(projectedConfig(plan), isNot(contains('localPurge')));
      expect(
        (plan.compatibilityPayload['pluginInfos'] as List).single['isDeleted'],
        isFalse,
      );
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      expect(objectbox.pluginInfoBox.getAll().single.isDeleted, isFalse);
    },
  );

  test(
    'reinstall withdraws only matching local purge revisions and stale clear plans stop',
    () async {
      objectbox.pluginConfigBox.put(
        PluginConfig(name: _source, config: '{"account":"old","theme":"old"}'),
      );
      final epoch = await exclude({PluginDataScope.accountSettings});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
        nowMs: 2000,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      final row = objectbox.pluginConfigBox.getAll().single;
      var data = jsonDecode(row.config) as Map<String, dynamic>;
      data = updatePluginConfigField(data, 'theme', 'new', nowMs: 3000);
      data = updatePluginConfigField(data, 'ordinary', 'value', nowMs: 3000);
      data = deletePluginConfigField(data, 'ordinary', nowMs: 4000);
      row.config = jsonEncode(data);
      objectbox.pluginConfigBox.put(row);
      discardPluginAccountDeletionTombstones(_source, expectedEpoch: epoch);
      final after = jsonDecode(
        objectbox.pluginConfigBox.getAll().single.config,
      );
      expect(after['theme'], 'new');
      expect(after[pluginConfigSyncFields].containsKey('account'), isFalse);
      expect(after[pluginConfigSyncFields]['ordinary']['deleted'], isTrue);
      final stale = preparePluginAccountDataClear(
        _source,
        cloudDelete: false,
        expectedEpoch: epoch,
      );
      await LocalPluginInstallationState.instance.completeExplicitInstallation(
        _source,
      );
      expect(
        () => objectbox.store.runInTransaction(
          TxMode.write,
          stale.persistDatabase,
        ),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(
        jsonDecode(objectbox.pluginConfigBox.getAll().single.config)['theme'],
        'new',
      );
    },
  );

  Future<PortablePreferencesSnapshot> seedPortable() async {
    final prefs = await SharedPreferences.getInstance();
    final watch = Uri.parse('https://fixture.invalid/watch?v=7');
    final record = VideoWatchRecord(
      watchUrl: watch,
      title: 'synthetic',
      position: const Duration(seconds: 3),
      duration: const Duration(seconds: 20),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      completed: false,
    );
    await prefs.setString(
      '${PortablePreferences.historyPrefix}$_source',
      jsonEncode([record.toJson()]),
    );
    await prefs.setStringList('${PortablePreferences.searchPrefix}$_source', [
      'synthetic search',
    ]);
    await prefs.setBool('breeze.source.list-details.v1.$_source', true);
    await prefs.setString('breeze.video.library.view.$_source', 'grid');
    await prefs.setInt(videoPlaybackProgressKey(watch), 3000);
    await prefs.setString(
      'breeze.private.unregistered.$_source',
      'private value remains',
    );
    await prefs.setString(
      VideoExportRecords.storageKey,
      jsonEncode([
        for (final source in [_source, _other])
          {
            'key': '$source|$watch',
            'source': source,
            'url': watch.toString(),
            'title': 'synthetic',
            'at': 1000,
          },
      ]),
    );
    return PortablePreferences.capture();
  }

  test(
    'local portable clear preserves cloud projection and masks only known source rows',
    () async {
      final original = await seedPortable();
      final scopes = PluginDataScope.values.toSet();
      final epoch = await exclude(scopes);
      final plan = await preparePluginPortableDataClear(
        _source,
        scopes: scopes,
        cloudDelete: false,
        expectedEpoch: epoch,
      );
      final writes = <String, dynamic>{};
      await plan.applyPreferences(
        beforeWrite: (updates) async => writes.addAll(updates),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${PortablePreferences.historyPrefix}$_source'),
        isNull,
      );
      expect(prefs.getBool('breeze.source.list-details.v1.$_source'), isNull);
      expect(
        prefs.getInt(
          videoPlaybackProgressKey(
            Uri.parse('https://fixture.invalid/watch?v=7'),
          ),
        ),
        isNull,
      );
      expect(
        prefs.getString('breeze.private.unregistered.$_source'),
        'private value remains',
      );
      expect(
        (jsonDecode(prefs.getString(VideoExportRecords.storageKey)!) as List)
            .single['source'],
        _other,
      );
      final cloud = await PortablePreferences.capture(persist: false);
      expect(
        cloud.toJson(),
        original.toJson(),
        reason: 'local absence is not an instruction to delete cloud data',
      );
      await PortablePreferences.restore(original);
      expect(
        prefs.getString('${PortablePreferences.historyPrefix}$_source'),
        isNull,
      );
      expect(prefs.getString('breeze.video.library.view.$_source'), isNull);
      expect(
        (jsonDecode(prefs.getString(VideoExportRecords.storageKey)!) as List)
            .single['source'],
        _other,
      );
      expect(
        writes.containsKey('breeze.private.unregistered.$_source'),
        isFalse,
      );
      await LocalPluginInstallationState.instance
          .clearDataExclusionsForExplicitRestore([
            _source,
          ], beforeWrite: (_) async {});
      await PortablePreferences.restore(original);
      expect(
        prefs.getString('${PortablePreferences.historyPrefix}$_source'),
        isNotNull,
      );
    },
  );

  test(
    'cloud portable clear emits ordinary tombstones and reinstall removes only local purge projection',
    () async {
      final original = await seedPortable();
      final epoch = await exclude(PluginDataScope.values.toSet());
      final plan = await preparePluginPortableDataClear(
        _source,
        scopes: PluginDataScope.values.toSet(),
        cloudDelete: true,
        expectedEpoch: epoch,
        nowMs: 2000,
      );
      await plan.applyPreferences(beforeWrite: (_) async {});
      final cloud = await PortablePreferences.capture(persist: false);
      expect(jsonEncode(cloud.toJson()), isNot(contains('localPurge')));
      expect(
        cloud.entries.values.where((row) => row['deleted'] == true),
        isNotEmpty,
      );
      await PortablePreferences.restore(original, preferIncomingOnTie: true);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${PortablePreferences.historyPrefix}$_source'),
        isNull,
      );
      await prefs.setString('breeze.video.library.view.$_source', 'list');
      await PortablePreferences.capture();
      await discardPluginPortableDeletionTombstones(
        _source,
        expectedEpoch: epoch,
        beforeWrite: (_) async {},
      );
      await LocalPluginInstallationState.instance.completeExplicitInstallation(
        _source,
      );
      final after = await PortablePreferences.capture(persist: false);
      expect(
        after.entries.values.any((row) => row['deleted'] == true),
        isFalse,
      );
      expect(
        prefs.getString('${PortablePreferences.historyPrefix}$_source'),
        isNull,
        reason: 'withdrawal does not restore private values',
      );
      expect(
        prefs.getString('breeze.video.library.view.$_source'),
        'list',
        reason: 'later explicit edits survive reinstall',
      );
    },
  );

  test(
    'source aliases are exact and unknown private preference identities stay outside scope',
    () {
      final names = pluginConfigNamesForSource(_source);
      expect(names, contains('(plugin_info_${_source.replaceAll('-', '_')})'));
      expect(names, isNot(contains('${_source}x')));
      expect(
        PortablePreferences.owns('breeze.private.unregistered.$_source'),
        isFalse,
      );
    },
  );

  test(
    'a later local preference edit during journal preparation aborts the stale clear',
    () async {
      await seedPortable();
      final epoch = await exclude({PluginDataScope.accountSettings});
      final plan = await preparePluginPortableDataClear(
        _source,
        scopes: {PluginDataScope.accountSettings},
        cloudDelete: false,
        expectedEpoch: epoch,
      );
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        plan.applyPreferences(
          beforeWrite: (_) async {
            await prefs.setString('breeze.video.library.view.$_source', 'list');
          },
        ),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(prefs.getString('breeze.video.library.view.$_source'), 'list');
      expect(prefs.getBool('breeze.source.list-details.v1.$_source'), isTrue);
    },
  );

  test(
    'reinstall during encoding rejects a stale settings capture before its first upload',
    () async {
      objectbox.pluginConfigBox.put(
        PluginConfig(name: _source, config: '{"account":"synthetic"}'),
      );
      final epoch = await exclude({PluginDataScope.accountSettings});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      final remote = _EmptyWritable();
      final codec = SettingsSyncCodec(
        encode: (bytes) async {
          discardPluginAccountDeletionTombstones(_source, expectedEpoch: epoch);
          await LocalPluginInstallationState.instance
              .completeExplicitInstallation(_source);
          return bytes;
        },
        decode: _identity,
      );
      await expectLater(
        uploadSettingsData(remote, state: _enabled, codec: codec),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(remote.writes, isEmpty);
    },
  );

  test(
    'reinstall after data upload prevents committing its stale authoritative settings pointer',
    () async {
      objectbox.pluginConfigBox.put(
        PluginConfig(name: _source, config: '{"account":"synthetic"}'),
      );
      final epoch = await exclude({PluginDataScope.accountSettings});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      final remote = _EmptyWritable()
        ..afterDataWrite = () async {
          discardPluginAccountDeletionTombstones(_source, expectedEpoch: epoch);
          await LocalPluginInstallationState.instance
              .completeExplicitInstallation(_source);
        };
      await expectLater(
        uploadSettingsData(remote, state: _enabled, codec: _codec),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(remote.writes, hasLength(1));
      expect(remote.writes.single, endsWith('.bin'));
    },
  );
}
