import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

const _accountEntry = 'cloud-sync-account.breezebackup';
const _deviceKey = 'sync.device_id';
const _settingsMetadata = 'sync.settings.block.meta.v3';
const _videoDigest = 'breeze.video.library.v1.syncedDigest';
const _device = 'target-device-id';
const _selected = BackupImportOptions(
  importSettings: false,
  importPlugins: false,
  importCloudSyncAccount: true,
);

const _source = SyncSettingState(
  syncServiceType: SyncServiceType.s3,
  webdavSetting: WebDavSettingState(
    host: 'https://source-webdav.invalid/dav',
    username: 'source-webdav-user',
    password: 'source-webdav-pass',
  ),
  s3Setting: S3SettingState(
    endpoint: 'source-s3.invalid',
    accessKey: 'source-s3-access',
    secretKey: 'source-s3-secret',
    bucket: 'source-s3-bucket',
    region: 'test-region-1',
    useSSL: false,
    port: 8181,
    pathStyle: true,
  ),
  legacyCompatibilityEnabled: true,
  autoSync: true,
  syncSettings: true,
  syncPlugins: true,
  settingsSyncTime: 1234,
);

const _target = SyncSettingState(
  syncServiceType: SyncServiceType.webdav,
  webdavSetting: WebDavSettingState(
    host: 'https://target-webdav.invalid',
    username: 'target-user',
    password: 'target-pass',
  ),
  s3Setting: S3SettingState(endpoint: 'target-s3.invalid'),
  legacyCompatibilityEnabled: true,
  autoSync: true,
  syncSettings: true,
  syncPlugins: true,
  syncNotify: false,
  settingsSyncTime: 5678,
);

/// Model the existing ZIP transport with a root-entry map. The file envelope
/// and credential entry still use production authenticated encryption.
class _FileArchiveApi extends RustLibApi {
  static Future<Map<String, String>> read(String path) async =>
      Map<String, String>.from(
        jsonDecode(await File(path).readAsString()) as Map,
      );

  @override
  Future<void> crateApiDataBackupCreateDataBackupZip({
    required String zipPath,
    required String dataDir,
    String? downloadDir,
  }) async {
    final entries = <String, String>{};
    await for (final entry in Directory(dataDir).list(recursive: true)) {
      if (entry is File) {
        entries[p.relative(entry.path, from: dataDir)] = base64Encode(
          await entry.readAsBytes(),
        );
      }
    }
    await File(zipPath).writeAsString(jsonEncode(entries));
  }

  @override
  Future<String> crateApiDataBackupReadDataBackupConfig({
    required String zipPath,
  }) async => utf8.decode(base64Decode((await read(zipPath))['config.json']!));

  @override
  Future<void> crateApiDataBackupExtractDataBackupZip({
    required String zipPath,
    required String extractDir,
  }) async {
    for (final entry in (await read(zipPath)).entries) {
      final file = File(p.join(extractDir, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(base64Decode(entry.value));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call in local file backup');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupProtectionSession session;
  late SharedPreferences prefs;
  late Directory root;
  late String zipPath, encryptedPath;

  void save(SyncSettingState state) {
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = user.globalSetting.copyWith(syncSetting: state);
    objectbox.userSettingBox.put(user);
  }

  SyncSettingState saved() =>
      objectbox.userSettingBox.get(1)!.globalSetting.syncSetting;

  Future<void> export({bool protect = true}) => exportBreezeBackup(
    zipPath: zipPath,
    includeDownloads: false,
    protectionSession: protect ? session : null,
  );

  Future<BackupConfig> readProtected() async {
    await session.encryptFile(zipPath, encryptedPath);
    return readProtectedBackupConfig(encryptedPath, session);
  }

  void expectTarget() {
    expect(saved(), _target);
    expect(prefs.getString(_deviceKey), _device);
    expect(prefs.getString(_settingsMetadata), '{}');
    expect(prefs.getString(_videoDigest), 'old-digest');
  }

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _FileArchiveApi());
    PackageInfo.setMockInitialValues(
      appName: 'Breeze',
      packageName: 'fixture',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final security = BackupProtectionService();
    final pending = await security.create('synthetic file backup password');
    session = await security.confirmRecovery(
      pending,
      pending.recoveryCode,
      trustDevice: false,
    );
  });

  tearDownAll(() async {
    session.dispose();
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      _deviceKey: _device,
      _settingsMetadata: '{}',
      _videoDigest: 'old-digest',
    });
    prefs = await SharedPreferences.getInstance();
    syncDeviceId = _device;
    root = await Directory(
      TestObjectBoxHelper.tempPath,
    ).createTemp('accounts-');
    zipPath = p.join(root.path, 'archive.zip');
    encryptedPath = p.join(root.path, 'archive.breezebackup');
    save(_source);
  });

  tearDown(() async => root.delete(recursive: true));

  test('ordinary ZIP keeps cloud credentials out of every entry', () async {
    await export(protect: false);
    final files = await _FileArchiveApi.read(zipPath);
    expect(files, isNot(contains(_accountEntry)));
    for (final content in files.values) {
      final decoded = utf8.decode(base64Decode(content), allowMalformed: true);
      expect(decoded, isNot(contains('source-s3-')));
      expect(decoded, isNot(contains('source-webdav')));
    }
    // A protected file written by an older client still imports normally.
    final older = await readProtected();
    expect(older.hasCloudSyncAccount, isFalse);
    save(_target);
    await applyBreezeBackupImport(
      older,
      mode: BackupImportMode.restore,
      options: _selected,
    );
    expectTarget();
  });

  test(
    'a standard ZIP ignores an attached protected credential entry',
    () async {
      await export();
      save(_target);
      final config = await readBackupConfig(zipPath);
      expect(config.hasCloudSyncAccount, isFalse);
      await applyBreezeBackupImport(
        config,
        mode: BackupImportMode.restore,
        options: _selected,
      );
      expectTarget();
    },
  );

  test(
    'unlock does not restore the account without an explicit choice',
    () async {
      await export();
      final config = await readProtected();
      expect(config.hasCloudSyncAccount, isTrue);
      save(_target);
      await applyBreezeBackupImport(config, mode: BackupImportMode.restore);
      expectTarget();
      expect(config.hasCloudSyncAccount, isFalse);
    },
  );

  for (final mode in BackupImportMode.values) {
    test(
      'selected ${mode.name} restores both providers and disables sync',
      () async {
        await export();
        final files = await _FileArchiveApi.read(zipPath);
        final account = base64Decode(files[_accountEntry]!);
        expect(BackupProtectionService.isProtectedBytes(account), isTrue);
        for (final content in files.values) {
          final decoded = utf8.decode(
            base64Decode(content),
            allowMalformed: true,
          );
          expect(decoded, isNot(contains('source-s3-')));
          expect(decoded, isNot(contains('source-webdav')));
        }

        final config = await readProtected();
        expect(config.hasCloudSyncAccount, isTrue);
        save(_target);
        final cubit = GlobalSettingCubit();
        addTearDown(cubit.close);
        await cubit.initBox();
        await applyBreezeBackupImport(
          config,
          mode: mode,
          options: _selected,
          globalSettingCubit: cubit,
        );
        final result = saved();
        expect(
          result,
          _source.copyWith(
            autoSync: false,
            syncSettings: false,
            syncPlugins: false,
            legacyCompatibilityEnabled: false,
            syncNotify: false,
            settingsSyncTime: 0,
          ),
        );
        expect(cubit.state.syncSetting, result);
        expect(prefs.getString(_deviceKey), _device);
        expect(syncDeviceId, _device);
        expect(prefs.containsKey(_settingsMetadata), isFalse);
        expect(prefs.containsKey(_videoDigest), isFalse);
        expect(await Directory(config.cacheDir).exists(), isFalse);
      },
    );
  }

  test('empty source profile clears a stale target configuration', () async {
    save(
      _source.copyWith(
        syncServiceType: SyncServiceType.webdav,
        webdavSetting: const WebDavSettingState(),
      ),
    );
    await export();
    final config = await readProtected();
    save(_target);
    await applyBreezeBackupImport(
      config,
      mode: BackupImportMode.restore,
      options: _selected,
    );
    expect(saved().syncServiceType, SyncServiceType.webdav);
    expect(saved().webdavSetting, const WebDavSettingState());
  });

  test('a protected export with no accounts has no credential entry', () async {
    save(const SyncSettingState());
    await export();
    expect(await _FileArchiveApi.read(zipPath), isNot(contains(_accountEntry)));
    final config = await readProtected();
    expect(config.hasCloudSyncAccount, isFalse);
    save(_target);
    await applyBreezeBackupImport(
      config,
      mode: BackupImportMode.restore,
      options: _selected,
    );
    expectTarget();
  });

  test(
    'nested and outer authentication failures leave local data intact',
    () async {
      await export();
      final files = await _FileArchiveApi.read(zipPath);
      final account = base64Decode(files[_accountEntry]!);
      account[account.length - 1] ^= 1;
      files[_accountEntry] = base64Encode(account);
      await File(zipPath).writeAsString(jsonEncode(files));
      save(_target);

      await expectLater(
        readProtected(),
        throwsA(isA<BackupProtectionException>()),
      );
      expectTarget();

      final outer = await File(encryptedPath).readAsBytes();
      outer[outer.length - 1] ^= 1;
      await File(encryptedPath).writeAsBytes(outer);
      await expectLater(
        readProtectedBackupConfig(encryptedPath, session),
        throwsA(isA<BackupProtectionException>()),
      );
      expectTarget();
    },
  );

  test(
    'authenticated malformed account rejects without exposing content',
    () async {
      await export();
      final files = await _FileArchiveApi.read(zipPath);
      const invalid = 'broken-json-secret';
      files[_accountEntry] = base64Encode(
        await session.encryptBytes(utf8.encode(invalid)),
      );
      await File(zipPath).writeAsString(jsonEncode(files));
      save(_target);
      await expectLater(
        readProtected(),
        throwsA(
          isA<BackupCompatibilityException>().having(
            (error) => error.toString(),
            'redacted error',
            isNot(contains(invalid)),
          ),
        ),
      );
      expectTarget();
    },
  );

  test('failed database commit rolls back account and sync metadata', () async {
    await export();
    final config = await readProtected();
    save(_target);
    final cubit = GlobalSettingCubit();
    addTearDown(cubit.close);
    await cubit.initBox();
    await expectLater(
      applyBreezeBackupImport(
        config,
        options: _selected,
        globalSettingCubit: cubit,
        hooks: BackupImportHooks(
          beforeCommit: () => throw StateError('fixture rollback'),
        ),
      ),
      throwsA(anyOf(isA<StateError>(), isA<BackupRestoreIncomplete>())),
    );
    expectTarget();
    expect(cubit.state.syncSetting, _target);
    expect(await Directory(config.cacheDir).exists(), isFalse);
  });
}
