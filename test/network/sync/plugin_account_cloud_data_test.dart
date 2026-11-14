import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_cloud_data.dart';
import 'package:zephyr/service/plugin_account_data_clear.dart';
import 'package:zephyr/service/plugin_portable_data_clear.dart';

import '../../test_helper.dart';

const _source = '99999999-1111-4222-8333-444444444444';
const _other = '88888888-1111-4222-8333-444444444444';
Future<List<int>> _identity(List<int> bytes) async => bytes;
const _settingsCodec = SettingsSyncCodec(encode: _identity, decode: _identity);
const _videoCodec = VideoLibrarySyncCodec(encode: _identity, decode: _identity);

class _Cloud extends ComicSyncRemoteAdapter {
  final files = <String, Uint8List>{};
  int reads = 0, mutations = 0;
  String? failRead;
  String path(String raw) => raw.contains('/')
      ? raw.replaceFirst(RegExp(r'^/+'), '')
      : '${SyncArchiveContext.currentRoot}/$raw';
  @override
  Future<void> testConnection() async {
    reads++;
  }

  @override
  Future<List<String>> listRemoteDataFiles() async {
    reads++;
    return files.keys.toList();
  }

  @override
  Future<List<int>> downloadRemoteFile(String raw) async {
    reads++;
    final key = path(raw);
    if (key == failRead) throw StateError('Synthetic network failure');
    if (!files.containsKey(key)) throw StateError('404');
    return Uint8List.fromList(files[key]!);
  }

  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> ensureRemoteReady() async {
    mutations++;
    throw StateError('read only');
  }

  @override
  Future<void> uploadRemoteMd5(String value) async {
    mutations++;
    throw StateError('read only');
  }

  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    mutations++;
    throw StateError('read only');
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    mutations++;
    throw StateError('read only');
  }
}

class _Keys implements BackupDeviceKeyStore {
  @override
  Future<Uint8List?> readKey(String source) async => null;
  @override
  Future<void> writeKey(String source, Uint8List key) async =>
      throw StateError('No trust requested');
  @override
  Future<void> deleteKey(String source) async {}
}

class _Profiles implements BackupProtectionProfileStore {
  BackupProtectionProfile? value;
  @override
  Future<BackupProtectionProfile?> read() async => value;
  @override
  Future<void> write(BackupProtectionProfile? profile) async {
    value = profile;
  }
}

PortablePreferencesSnapshot _portable() {
  final entries = <String, Map<String, dynamic>>{};
  for (final source in [_source, _other]) {
    final key = 'breeze.source.list-details.v1.$source';
    entries['$key#${sha256.convert(utf8.encode(''))}'] = {
      'key': key,
      'kind': 'preference',
      'value': true,
      'deleted': false,
      'updatedAt': 1000,
    };
  }
  return PortablePreferencesSnapshot(entries);
}

_Cloud _seed({int videoVersion = 1}) {
  final cloud = _Cloud();
  final settings = utf8.encode(
    jsonEncode({
      'version': 'v1',
      'schemaVersion': 'v2',
      'syncTime': 1000,
      'blocks': {
        'plugins': {
          'updatedAt': 1000,
          'data': {
            'pluginInfos': [],
            'pluginConfigs': [
              PluginConfig(
                name: _source,
                config:
                    '{"remote.only":"synthetic secret","account.credentials":{"account":"synthetic"}}',
              ).toJson(),
              PluginConfig(
                name: _other,
                config: '{"unrelated":"keep"}',
              ).toJson(),
            ],
          },
        },
      },
    }),
  );
  final snapshot = VideoLibrarySnapshot().toJson(),
      portable = _portable().toJson();
  final video = utf8.encode(
    jsonEncode({
      'format': 'BreezeVideoLibrary',
      'version': videoVersion,
      'sha256': sha256.convert(utf8.encode(jsonEncode(snapshot))).toString(),
      'snapshot': snapshot,
      'portable': portable,
      'portableSha256': sha256
          .convert(utf8.encode(jsonEncode(portable)))
          .toString(),
    }),
  );
  cloud.files[cloud.path('settings_1000.bin')] = Uint8List.fromList(settings);
  cloud.files[cloud.path('settings.md5')] = Uint8List.fromList(
    utf8.encode(ComicSyncCore.calculateMd5(settings)),
  );
  cloud.files[cloud.path(
    'video_library_0123456789abcdef0123456789abcdef.bin',
  )] = Uint8List.fromList(
    video,
  );
  return cloud;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'synthetic.local': 'intact'});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.put(
      PluginConfig(name: _other, config: '{"unrelated":"local"}'),
    );
  });
  Future<CloudPluginAccountData> read(_Cloud cloud) =>
      readCloudPluginAccountData(
        ScopedSyncArchiveAdapter(cloud, SyncArchiveContext.current),
        _source,
        settingsCodec: _settingsCodec,
        videoCodec: _videoCodec,
      );

  test(
    'explicit cloud preview reads only the requested source without any mutation',
    () async {
      final cloud = _seed();
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final preview = await read(cloud);
      expect(preview.configs.single.name, _source);
      expect(
        jsonDecode(preview.configs.single.config)['remote.only'],
        'synthetic secret',
      );
      expect(
        preview.portable.entries.values.single['key'],
        'breeze.source.list-details.v1.$_source',
      );
      expect(preview.toString(), isNot(contains('synthetic secret')));
      expect(cloud.reads, greaterThan(0));
      expect(cloud.mutations, 0);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      expect(objectbox.pluginConfigBox.getAll().single.name, _other);
    },
  );

  test(
    'remote-only fields and portable entries become current ordinary tombstones in the journaled plan',
    () async {
      final cloud = _seed();
      final preview = await read(cloud);
      final epoch = await LocalPluginInstallationState.instance
          .setDataExclusions(
            _source,
            PluginDataScope.values.toSet(),
            beforeWrite: (_) async {},
          );
      final account = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
        knownCloudConfigs: preview.configs,
        nowMs: 2000,
      );
      final portable = await preparePluginPortableDataClear(
        _source,
        scopes: PluginDataScope.values.toSet(),
        cloudDelete: true,
        expectedEpoch: epoch,
        knownCloudPortable: preview.portable,
        nowMs: 2000,
      );
      objectbox.store.runInTransaction(TxMode.write, account.persistDatabase);
      await portable.applyPreferences(beforeWrite: (_) async {});
      final own = objectbox.pluginConfigBox.getAll().singleWhere(
        (row) => row.name == _source,
      );
      final metadata = jsonDecode(own.config)['__breezeSyncFields'];
      expect(metadata['remote.only']['deleted'], isTrue);
      expect(metadata['account.credentials']['deleted'], isTrue);
      expect(
        objectbox.pluginConfigBox
            .getAll()
            .singleWhere((row) => row.name == _other)
            .config,
        '{"unrelated":"local"}',
      );
      final projection = await PortablePreferences.capture(persist: false);
      expect(projection.entries.values.single['deleted'], isTrue);
      expect(jsonEncode(projection.toJson()), isNot(contains('localPurge')));
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'breeze.source.list-details.v1.$_source',
        ),
        isNull,
      );
      expect(
        cloud.mutations,
        0,
        reason:
            'only the explicitly committed local state is changed; Sync is separate',
      );
    },
  );

  test(
    'future domain data and network failures stop preview before any purge state changes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final future = _seed(videoVersion: 2);
      await expectLater(read(future), throwsA(isA<Exception>()));
      expect(future.mutations, 0);
      final failed = _seed()
        ..failRead = '${SyncArchiveContext.currentRoot}/settings_1000.bin';
      await expectLater(read(failed), throwsA(isA<Exception>()));
      expect(failed.mutations, 0);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      expect(objectbox.pluginConfigBox.getAll().single.name, _other);
    },
  );

  test(
    'locked protected preview requires explicit unlock and retry without silently syncing',
    () async {
      final cloud = _seed();
      final service = BackupProtectionService(deviceKeys: _Keys());
      final pending = await service.create('correct horse battery staple');
      final code = pending.recoveryCode;
      final owner = await service.confirmRecovery(
        pending,
        code,
        trustDevice: false,
      );
      for (final path
          in cloud.files.keys.where((path) => path.endsWith('.bin')).toList()) {
        cloud.files[path] = await owner.encryptBytes(cloud.files[path]!);
      }
      cloud.files[cloud.path('protection.json')] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'BreezeBackupProtection',
            'version': 1,
            'phase': 'ready',
            'mode': 'protected',
            'profile': owner.profile.toJson(),
            'lastTransition': List.filled(32, 'a').join(),
          }),
        ),
      );
      final manager = BackupProtectionManager(
        service: service,
        profileStore: _Profiles(),
        operationRunner: (action) => action(),
      );
      final protected = BackupProtectionSyncAdapter(cloud, manager: manager);
      final scoped = ScopedSyncArchiveAdapter(
        protected,
        SyncArchiveContext.current,
      );
      await expectLater(
        readCloudPluginAccountData(
          scoped,
          _source,
          settingsCodec: _settingsCodec,
          videoCodec: _videoCodec,
        ),
        throwsA(
          isA<BackupProtectionException>().having(
            (error) => error.code,
            'code',
            'backup_locked',
          ),
        ),
      );
      expect(cloud.mutations, 0);
      expect(objectbox.pluginConfigBox.getAll().single.name, _other);
      await manager.unlock(recoveryCode: code);
      final preview = await readCloudPluginAccountData(
        scoped,
        _source,
        settingsCodec: _settingsCodec,
        videoCodec: _videoCodec,
      );
      expect(preview.configs.single.name, _source);
      expect(cloud.mutations, 0);
      cloud.files[cloud.path('settings_1000.bin')]![7] = 50;
      protected.invalidateProtection();
      await expectLater(
        readCloudPluginAccountData(
          scoped,
          _source,
          settingsCodec: _settingsCodec,
          videoCodec: _videoCodec,
        ),
        throwsA(
          isA<BackupProtectionException>().having(
            (error) => error.code,
            'code',
            'unsupported_version',
          ),
        ),
      );
      expect(cloud.mutations, 0);
      owner.dispose();
      manager.lock();
    },
  );

  test(
    'local-only clear ignores cloud inputs and performs no cloud read',
    () async {
      final cloud = _seed();
      final account = preparePluginAccountDataClear(
        _source,
        cloudDelete: false,
        knownCloudConfigs: [
          PluginConfig(name: _source, config: '{"remote.only":"not local"}'),
        ],
      );
      final portable = await preparePluginPortableDataClear(
        _source,
        scopes: PluginDataScope.values.toSet(),
        cloudDelete: false,
        knownCloudPortable: _portable(),
      );
      objectbox.store.runInTransaction(TxMode.write, account.persistDatabase);
      await portable.applyPreferences(beforeWrite: (_) async {});
      expect(objectbox.pluginConfigBox.getAll().single.name, _other);
      expect(
        (await PortablePreferences.capture(persist: false)).entries,
        isEmpty,
      );
      expect(cloud.reads, 0);
      expect(cloud.mutations, 0);
    },
  );
}
