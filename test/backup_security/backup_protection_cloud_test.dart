import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';

class MemoryProfiles implements BackupProtectionProfileStore {
  BackupProtectionProfile? profile;
  int writes = 0;
  @override
  Future<BackupProtectionProfile?> read() async => profile;
  @override
  Future<void> write(BackupProtectionProfile? value) async {
    writes++;
    profile = value;
  }
}

class NoDeviceKeys implements BackupDeviceKeyStore {
  @override
  Future<Uint8List?> readKey(String archiveId) async => null;
  @override
  Future<void> writeKey(String archiveId, Uint8List key) async =>
      throw StateError('Tests must explicitly opt out of device trust');
  @override
  Future<void> deleteKey(String archiveId) async {}
}

class MemoryCloud extends ComicSyncRemoteAdapter {
  final Map<String, Uint8List> files = {};
  final List<String> events = [];
  bool Function(String path, List<int> bytes)? failNextWrite;
  bool failDelete = false;
  String path(String value) {
    final clean = value.replaceFirst(RegExp(r'^/+'), '');
    return clean.contains('/')
        ? clean
        : '${SyncArchiveContext.currentRoot}/$clean';
  }

  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {
    events.add('ensure');
  }

  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String remotePath) async {
    final value = files[path(remotePath)];
    if (value == null) throw StateError('404');
    return Uint8List.fromList(value);
  }

  @override
  Future<String> downloadRemoteMd5() async =>
      utf8.decode(files[path('comic.md5')] ?? Uint8List(0));
  @override
  Future<void> uploadRemoteMd5(String value) =>
      uploadRemoteFile('comic.md5', utf8.encode(value));
  @override
  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    final key = path(remotePath);
    events.add('put:$key');
    if (failNextWrite?.call(key, data) == true) {
      failNextWrite = null;
      files[key] = Uint8List.fromList(data.take(3).toList());
      throw StateError('Synthetic interrupted PUT');
    }
    files[key] = Uint8List.fromList(data);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> remotePaths) async {
    if (failDelete) throw StateError('Synthetic cleanup interruption');
    for (final remote in remotePaths) {
      final key = path(remote);
      events.add('delete:$key');
      files.remove(key);
    }
  }
}

BackupProtectionManager manager(MemoryProfiles profiles) =>
    BackupProtectionManager(
      service: BackupProtectionService(deviceKeys: NoDeviceKeys()),
      profileStore: profiles,
      operationRunner: (action) => action(),
    );
Matcher failure(String code) =>
    isA<BackupProtectionException>().having((e) => e.code, 'code', code);
Map<String, Uint8List> seed(MemoryCloud cloud) {
  final entries = {
    cloud.path('comic_1.bin'): Uint8List.fromList(
      utf8.encode('standard-coded comic snapshot'),
    ),
    cloud.path('settings_2.bin'): Uint8List.fromList(
      utf8.encode('standard-coded settings snapshot'),
    ),
    cloud.path('video_library_0123456789abcdef0123456789abcdef.bin'):
        Uint8List.fromList(utf8.encode('standard-coded video snapshot')),
  };
  cloud.files.addAll(entries);
  cloud.files[cloud.path('comic.md5')] = Uint8List.fromList(
    utf8.encode('same-logical-md5'),
  );
  cloud.files[cloud.path('settings.md5')] = Uint8List.fromList(
    utf8.encode('same-settings-md5'),
  );
  return entries;
}

Future<String> setup(BackupProtectionManager manager) async {
  final pending = await manager.create('correct horse battery staple');
  final code = pending.recoveryCode;
  await manager.confirmSetup(pending, code, trustDevice: false);
  return code;
}

bool pendingFiles(MemoryCloud cloud) => cloud.files.keys.any(
  (path) =>
      path.contains('protection_stage_') ||
      path.contains('protection_transition_'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('device protection profile is excluded from portable preferences', () {
    expect(
      PortablePreferences.owns(PreferencesBackupProtectionProfileStore.key),
      isFalse,
    );
    expect(PortablePreferences.owns('breeze.local.synthetic-secret'), isFalse);
  });

  test(
    'local password changes future file exports while old exports retain their password',
    () async {
      final owner = manager(MemoryProfiles());
      final recovery = await setup(owner);
      final old = await owner.session!.encryptBytes(
        Uint8List.fromList([11, 22, 33]),
      );
      final originalProfile = BackupProtectionService.readProfileFromBytes(old);
      await owner.changeLocalPassword('the replacement file password');
      final newer = await owner.session!.encryptBytes(
        Uint8List.fromList([44, 55]),
      );
      final newerProfile = BackupProtectionService.readProfileFromBytes(newer);
      final originalUnlock = await owner.service.unlockProfile(
        originalProfile,
        password: 'correct horse battery staple',
      );
      expect(await originalUnlock.decryptBytes(old), [11, 22, 33]);
      await expectLater(
        owner.service.unlockProfile(
          newerProfile,
          password: 'correct horse battery staple',
        ),
        throwsA(isA<BackupProtectionException>()),
      );
      final recoveryUnlock = await owner.service.unlockProfile(
        newerProfile,
        recoveryCode: recovery,
      );
      expect(await recoveryUnlock.decryptBytes(newer), [44, 55]);
      originalUnlock.dispose();
      recoveryUnlock.dispose();
      owner.lock();
      await expectLater(
        owner.changeLocalPassword('another replacement password'),
        throwsA(failure('backup_locked')),
      );
    },
  );

  test(
    'standard file choice never disables or downgrades a protected cloud archive',
    () async {
      final profiles = MemoryProfiles();
      final owner = manager(profiles);
      await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      await owner.enableCloud(cloud);
      final before = cloud.events.length;
      final marker = Uint8List.fromList(
        cloud.files[cloud.path('protection.json')]!,
      );
      await owner.useStandardFileBackups();
      expect(owner.mode, BackupProtectionMode.standard);
      expect(owner.session, isNull);
      expect(profiles.profile, isNull);
      expect(cloud.events.length, before);
      expect(cloud.files[cloud.path('protection.json')], marker);
      for (final path in originals.keys) {
        expect(
          BackupProtectionService.isProtectedBytes(cloud.files[path]!),
          isTrue,
        );
      }
      final adapter = BackupProtectionSyncAdapter(cloud, manager: owner);
      await expectLater(
        adapter.uploadRemoteFile('comic_9.bin', [9]),
        throwsA(failure('backup_locked')),
      );
      expect(cloud.events.length, before);
    },
  );

  test(
    'enable transforms every payload and keeps logical domain bytes and MD5',
    () async {
      final profiles = MemoryProfiles();
      final owner = manager(profiles);
      await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      await owner.enableCloud(cloud);
      expect(pendingFiles(cloud), isFalse);
      final writesBeforeInspection = profiles.writes;
      await owner.inspectCloud(cloud);
      await owner.inspectCloud(cloud);
      expect(
        profiles.writes,
        writesBeforeInspection,
        reason: 'unchanged authenticated profiles do not rewrite preferences',
      );
      for (final entry in originals.entries) {
        expect(
          BackupProtectionService.isProtectedBytes(cloud.files[entry.key]!),
          isTrue,
        );
      }
      await expectLater(
        ComicSyncCore.decodeEncryptedPayload(
          cloud.files[originals.keys.first]!,
        ),
        throwsA(failure('backup_locked')),
      );
      final adapter = BackupProtectionSyncAdapter(cloud, manager: owner);
      for (final entry in originals.entries) {
        expect(await adapter.downloadRemoteFile(entry.key), entry.value);
      }
      expect(await adapter.downloadRemoteMd5(), 'same-logical-md5');
      await adapter.uploadRemoteFile(
        'comic_3.bin',
        utf8.encode('next domain payload'),
      );
      expect(
        BackupProtectionService.isProtectedBytes(
          cloud.files[cloud.path('comic_3.bin')]!,
        ),
        isTrue,
      );
      final standardClient = manager(MemoryProfiles());
      final locked = BackupProtectionSyncAdapter(
        cloud,
        manager: standardClient,
      );
      final before = cloud.events.length;
      await expectLater(
        locked.uploadRemoteFile('comic_4.bin', [1, 2, 3]),
        throwsA(failure('backup_locked')),
      );
      expect(
        cloud.events.length,
        before,
        reason: 'no mkdir/upload/delete before unlock',
      );
      expect(standardClient.mode, BackupProtectionMode.passwordProtected);
      owner.lock();
    },
  );

  test(
    'partial authoritative PUT resumes from verified stage on another device',
    () async {
      final owner = manager(MemoryProfiles());
      final recovery = await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      cloud.failNextWrite = (path, _) => path.endsWith('settings_2.bin');
      await expectLater(owner.enableCloud(cloud), throwsStateError);
      expect(cloud.files[cloud.path('settings_2.bin')]!.length, 3);
      expect(pendingFiles(cloud), isTrue);
      expect(
        cloud.events.where((event) => event.startsWith('delete:')),
        isEmpty,
      );
      final newDevice = manager(MemoryProfiles());
      final status = await newDevice.inspectCloud(cloud);
      expect(status.transitionOperation, 'enable');
      final guarded = BackupProtectionSyncAdapter(cloud, manager: newDevice);
      final before = cloud.events.length;
      await expectLater(
        guarded.uploadRemoteMd5('must not commit'),
        throwsA(failure('cloud_protection_transition_pending')),
      );
      expect(cloud.events.length, before);
      await newDevice.unlock(recoveryCode: recovery);
      await newDevice.resumeCloudTransition(cloud);
      expect(pendingFiles(cloud), isFalse);
      final adapter = BackupProtectionSyncAdapter(cloud, manager: newDevice);
      for (final entry in originals.entries) {
        expect(await adapter.downloadRemoteFile(entry.key), entry.value);
      }
      owner.lock();
      newDevice.lock();
    },
  );

  test(
    'partial final marker preserves immutable journal and resumes safely',
    () async {
      final owner = manager(MemoryProfiles());
      await setup(owner);
      final cloud = MemoryCloud();
      seed(cloud);
      cloud.failNextWrite = (path, bytes) =>
          path.endsWith('protection.json') &&
          utf8.decode(bytes).contains('"phase":"ready"');
      await expectLater(owner.enableCloud(cloud), throwsStateError);
      expect(pendingFiles(cloud), isTrue);
      expect((await owner.inspectCloud(cloud)).transitionPending, isTrue);
      await owner.resumeCloudTransition(cloud);
      expect((await owner.inspectCloud(cloud)).transitionPending, isFalse);
      expect(pendingFiles(cloud), isFalse);
      owner.lock();
    },
  );

  test(
    'disable retry requires explicit approval and converts every existing payload',
    () async {
      final owner = manager(MemoryProfiles());
      final recovery = await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      await owner.enableCloud(cloud);
      cloud.failNextWrite = (path, _) => path.endsWith('settings_2.bin');
      await expectLater(owner.disableCloud(cloud), throwsStateError);
      final newDevice = manager(MemoryProfiles());
      expect(
        (await newDevice.inspectCloud(cloud)).transitionOperation,
        'disable',
      );
      await newDevice.unlock(recoveryCode: recovery);
      final before = cloud.events.length;
      await expectLater(
        newDevice.resumeCloudTransition(cloud),
        throwsA(failure('disable_confirmation_required')),
      );
      expect(cloud.events.length, before);
      await newDevice.resumeCloudTransition(cloud, approveDisable: true);
      expect(newDevice.mode, BackupProtectionMode.standard);
      expect(newDevice.session, isNull);
      for (final entry in originals.entries) {
        expect(cloud.files[entry.key], entry.value);
      }
      expect(pendingFiles(cloud), isFalse);
      owner.lock();
    },
  );

  test(
    'password conversion rewraps all headers while preserving payload ciphertext',
    () async {
      final owner = manager(MemoryProfiles());
      final recovery = await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      await owner.enableCloud(cloud);
      final encryptedBefore = {
        for (final path in originals.keys) path: cloud.files[path]!,
      };
      await owner.changeCloudPassword(cloud, 'the replacement password');
      for (final path in originals.keys) {
        final before = encryptedBefore[path]!;
        final after = cloud.files[path]!;
        final oldOffset = 12 + ByteData.sublistView(before).getUint32(8);
        final newOffset = 12 + ByteData.sublistView(after).getUint32(8);
        expect(after.sublist(newOffset), before.sublist(oldOffset));
      }
      final fresh = manager(MemoryProfiles());
      await fresh.inspectCloud(cloud);
      await expectLater(
        fresh.unlock(password: 'correct horse battery staple'),
        throwsA(isA<BackupProtectionException>()),
      );
      await fresh.unlock(password: 'the replacement password');
      final adapter = BackupProtectionSyncAdapter(cloud, manager: fresh);
      expect(
        await adapter.downloadRemoteFile(originals.keys.first),
        originals.values.first,
      );
      fresh.lock();
      await fresh.unlock(recoveryCode: recovery);
      expect(fresh.isUnlocked, isTrue);
      owner.lock();
      fresh.lock();
    },
  );

  test(
    'future formats and marker removal reject before any normal mutation',
    () async {
      final owner = manager(MemoryProfiles());
      await setup(owner);
      final cloud = MemoryCloud();
      seed(cloud);
      await owner.enableCloud(cloud);
      cloud.files.remove(cloud.path('protection.json'));
      final adapter = BackupProtectionSyncAdapter(cloud, manager: owner);
      final before = cloud.events.length;
      await expectLater(
        adapter.deleteRemoteFiles([cloud.path('comic_1.bin')]),
        throwsA(failure('cloud_protection_metadata_missing')),
      );
      expect(cloud.events.length, before);
      final first = cloud.files[cloud.path('comic_1.bin')]!;
      first[7] = 50;
      adapter.invalidateProtection();
      await expectLater(
        adapter.uploadRemoteMd5('unchanged'),
        throwsA(failure('unsupported_version')),
      );
      expect(cloud.events.length, before);
      cloud.files[cloud.path('protection.json')] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'BreezeBackupProtection',
            'version': 2,
            'futureField': true,
          }),
        ),
      );
      adapter.invalidateProtection();
      await expectLater(
        adapter.uploadRemoteMd5('unchanged'),
        throwsA(failure('unsupported_cloud_protection_version')),
      );
      expect(cloud.events.length, before);
      owner.lock();
    },
  );

  test(
    'interrupted initial journal can be retried without touching original data',
    () async {
      final owner = manager(MemoryProfiles());
      await setup(owner);
      final cloud = MemoryCloud();
      final originals = seed(cloud);
      cloud.failNextWrite = (path, _) =>
          path.contains('protection_transition_');
      await expectLater(owner.enableCloud(cloud), throwsStateError);
      for (final entry in originals.entries) {
        expect(cloud.files[entry.key], entry.value);
      }
      expect(
        (await owner.inspectCloud(cloud)).transitionOperation,
        'preparing',
      );
      await owner.enableCloud(cloud);
      expect(
        (await owner.inspectCloud(cloud)).mode,
        BackupProtectionMode.passwordProtected,
      );
      expect(pendingFiles(cloud), isFalse);
      owner.lock();
    },
  );

  test(
    'cleanup keeps the verified stage when current data no longer matches',
    () async {
      final owner = manager(MemoryProfiles());
      await setup(owner);
      final cloud = MemoryCloud();
      seed(cloud);
      cloud.failDelete = true;
      await expectLater(owner.enableCloud(cloud), throwsStateError);
      expect((await owner.inspectCloud(cloud)).cleanupPending, isTrue);
      cloud.failDelete = false;
      cloud.files[cloud.path('comic_1.bin')] = Uint8List.fromList([1, 2, 3]);
      final stagesBefore = cloud.files.keys
          .where((path) => path.contains('protection_stage_'))
          .length;
      await expectLater(
        owner.resumeCloudTransition(cloud),
        throwsA(failure('cloud_protection_cleanup_not_safe')),
      );
      expect(
        cloud.files.keys
            .where((path) => path.contains('protection_stage_'))
            .length,
        stagesBefore,
      );
      owner.lock();
    },
  );
}
