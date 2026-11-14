import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';

class MemoryDeviceKeys implements BackupDeviceKeyStore {
  final Map<String, Uint8List> _keys = {};

  @override
  Future<Uint8List?> readKey(String archiveId) async {
    final key = _keys[archiveId];
    return key == null ? null : Uint8List.fromList(key);
  }

  @override
  Future<void> writeKey(String archiveId, Uint8List key) async {
    _keys[archiveId] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteKey(String archiveId) async {
    _keys.remove(archiveId);
  }
}

const password = 'correct horse battery staple';
const changedPassword = 'a different password for backup';

Matcher protectionFailure([String? code]) => isA<BackupProtectionException>()
    .having((error) => error.code, 'code', code ?? isNotEmpty);

Uint8List mutateHeader(
  Uint8List archive,
  void Function(Map<String, dynamic>) mutate,
) {
  final size = ByteData.sublistView(archive).getUint32(8);
  final json =
      jsonDecode(utf8.decode(archive.sublist(12, 12 + size)))
          as Map<String, dynamic>;
  mutate(json);
  final header = utf8.encode(jsonEncode(json));
  final prefix = ByteData(4)..setUint32(0, header.length);
  return Uint8List.fromList([
    ...archive.take(8),
    ...prefix.buffer.asUint8List(),
    ...header,
    ...archive.skip(12 + size),
  ]);
}

int payloadOffset(Uint8List archive) =>
    12 + ByteData.sublistView(archive).getUint32(8);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a file-only password opens its archive without trusting a device',
    () async {
      final keys = MemoryDeviceKeys();
      final service = BackupProtectionService(deviceKeys: keys);
      final session = await service.createFileSession(password);
      final profile = session.profile;
      final payload = Uint8List.fromList(utf8.encode('offline test payload'));
      final encrypted = await session.encryptBytes(payload);
      session.dispose();
      expect(await keys.readKey(profile.archiveId), isNull);
      final reopened = await service.unlockProfile(profile, password: password);
      try {
        expect(await reopened.decryptBytes(encrypted), payload);
      } finally {
        reopened.dispose();
      }
    },
  );

  test(
    'setup verifies saved recovery material before trusting a device',
    () async {
      final keys = MemoryDeviceKeys();
      final service = BackupProtectionService(deviceKeys: keys);
      final pending = await service.create(password);
      expect(await keys.readKey(pending.profile.archiveId), isNull);
      expect(pending.toString(), isNot(contains(pending.recoveryCode)));
      expect(pending.profile.toJson().toString(), isNot(contains(password)));
      await expectLater(
        service.confirmRecovery(pending, 'BR1-invalid'),
        throwsA(protectionFailure('invalid_recovery_code')),
      );
      expect(await keys.readKey(pending.profile.archiveId), isNull);
      final recoveryFile = pending.recoveryFile;
      final code = pending.recoveryCode;
      final session = await service.confirmRecovery(pending, code);
      final trusted = await service.unlockProfile(
        session.profile,
        useTrustedDevice: true,
      );
      final recovered = await service.unlockProfile(
        session.profile,
        recoveryFile: recoveryFile,
      );
      final foreignRecoveryFile =
          jsonDecode(recoveryFile) as Map<String, dynamic>;
      foreignRecoveryFile['archiveId'] = '00000000000000000000000000000000';
      await expectLater(
        service.unlockProfile(
          session.profile,
          recoveryFile: jsonEncode(foreignRecoveryFile),
        ),
        throwsA(protectionFailure('invalid_recovery_file')),
      );
      final plain = Uint8List.fromList(
        utf8.encode('test private reading data'),
      );
      final encrypted = await session.encryptBytes(plain);
      expect(await trusted.decryptBytes(encrypted), plain);
      expect(await recovered.decryptBytes(encrypted), plain);
      await expectLater(
        service.confirmRecovery(pending, code),
        throwsA(protectionFailure('setup_already_consumed')),
      );
      await service.forgetDevice(session.profile.archiveId);
      await expectLater(
        service.unlockProfile(session.profile, useTrustedDevice: true),
        throwsA(protectionFailure('device_not_authorized')),
      );
      session.dispose();
      trusted.dispose();
      recovered.dispose();
    },
  );

  test(
    'new device unlocks with password or recovery; wrong factors fail',
    () async {
      final service = BackupProtectionService(deviceKeys: MemoryDeviceKeys());
      final pending = await service.create(password);
      final recovery = pending.recoveryCode;
      final session = await service.confirmRecovery(
        pending,
        recovery,
        trustDevice: false,
      );
      final original = Uint8List.fromList(
        List.generate(1024 * 1024 + 73, (i) => i % 251),
      );
      final archive = await session.encryptBytes(original);
      final second = await session.encryptBytes(original);
      expect(
        archive,
        isNot(second),
        reason: 'independent payload IDs/keys for each backup',
      );
      expect(BackupProtectionService.isProtectedBytes(archive), isTrue);
      final parsed = BackupProtectionService.readProfileFromBytes(archive);
      final newDevice = BackupProtectionService(deviceKeys: MemoryDeviceKeys());
      final byPassword = await newDevice.unlockProfile(
        parsed,
        password: password,
      );
      final byRecovery = await newDevice.unlockProfile(
        parsed,
        recoveryCode: recovery.toLowerCase(),
      );
      expect(await byPassword.decryptBytes(archive), original);
      expect(await byRecovery.decryptBytes(archive), original);
      await expectLater(
        newDevice.unlockProfile(parsed, password: 'wrong password'),
        throwsA(protectionFailure()),
      );
      await expectLater(
        newDevice.unlockProfile(parsed, useTrustedDevice: true),
        throwsA(protectionFailure('device_not_authorized')),
      );
      await expectLater(
        newDevice.unlockProfile(
          parsed,
          password: password,
          recoveryCode: recovery,
        ),
        throwsA(protectionFailure('choose_one_unlock_factor')),
      );
      session.dispose();
      byPassword.dispose();
      byRecovery.dispose();
    },
  );

  test(
    'tags reject tamper, truncation, reordered frames, metadata and trailing bytes',
    () async {
      final service = BackupProtectionService(deviceKeys: MemoryDeviceKeys());
      final pending = await service.create(password);
      final session = await service.confirmRecovery(
        pending,
        pending.recoveryCode,
        trustDevice: false,
      );
      final archive = await session.encryptBytes(Uint8List(2 * 1024 * 1024));
      final offset = payloadOffset(archive);
      final frameSize = 4 + 1024 * 1024 + 16;
      final corrupted = Uint8List.fromList(archive)..[offset + 11] ^= 1;
      final reordered = Uint8List.fromList([
        ...archive.take(offset),
        ...archive.sublist(offset + frameSize, offset + frameSize * 2),
        ...archive.sublist(offset, offset + frameSize),
        ...archive.skip(offset + frameSize * 2),
      ]);
      final headerTampered = mutateHeader(archive, (json) {
        (json['descriptor'] as Map<String, dynamic>)['length'] = 1;
      });
      final slotTampered = mutateHeader(archive, (json) {
        final profile = json['profile'] as Map<String, dynamic>;
        final slot = profile['recovery'] as Map<String, dynamic>;
        slot['nonce'] = base64Encode(Uint8List(12));
      });
      for (final invalid in [
        corrupted, reordered, headerTampered, slotTampered,
        Uint8List.fromList(
          archive.sublist(0, archive.length - 20),
        ), // Missing terminal record.
        Uint8List.fromList(archive.sublist(0, archive.length - 1)),
        Uint8List.fromList([...archive, 0]),
      ]) {
        await expectLater(
          session.decryptBytes(invalid),
          throwsA(protectionFailure()),
        );
      }
      final future = Uint8List.fromList(archive)..[7] = 50;
      expect(BackupProtectionService.isProtectedBytes(future), isTrue);
      expect(
        () => BackupProtectionService.readProfileFromBytes(future),
        throwsA(protectionFailure('unsupported_version')),
      );
      final unboundedHeader = Uint8List.fromList(archive.take(12).toList());
      ByteData.sublistView(unboundedHeader).setUint32(8, 0xffffffff);
      expect(
        () => BackupProtectionService.readProfileFromBytes(unboundedHeader),
        throwsA(protectionFailure('invalid_header')),
      );
      final badKdf = mutateHeader(archive, (json) {
        final profile = json['profile'] as Map<String, dynamic>;
        (profile['password'] as Map<String, dynamic>)['iterations'] =
            2000000000;
      });
      expect(
        () => BackupProtectionService.readProfileFromBytes(badKdf),
        throwsA(protectionFailure('unsupported_kdf')),
      );
      final oversized = mutateHeader(archive, (json) {
        (json['descriptor'] as Map<String, dynamic>)['length'] =
            BackupProtectionSession.maxFilePayload + 1;
      });
      expect(
        () => BackupProtectionService.readProfileFromBytes(oversized),
        throwsA(protectionFailure('invalid_size')),
      );
      session.dispose();
      await expectLater(
        session.encryptBytes(Uint8List(0)),
        throwsA(protectionFailure('session_closed')),
      );
    },
  );

  test(
    'recovery resets password by rewrapping header and preserves ciphertext',
    () async {
      final service = BackupProtectionService(deviceKeys: MemoryDeviceKeys());
      final pending = await service.create(password);
      final recovery = pending.recoveryCode;
      final old = await service.confirmRecovery(
        pending,
        recovery,
        trustDevice: false,
      );
      final original = Uint8List.fromList(utf8.encode('preserve this payload'));
      final archive = await old.encryptBytes(original);
      final recovered = await service.unlockProfile(
        old.profile,
        recoveryCode: recovery,
      );
      final changed = await recovered.changePassword(changedPassword);
      final rewrapped = await changed.rewrapBytesHeader(archive);
      expect(
        rewrapped.sublist(payloadOffset(rewrapped)),
        archive.sublist(payloadOffset(archive)),
      );
      final updatedProfile = BackupProtectionService.readProfileFromBytes(
        rewrapped,
      );
      await expectLater(
        service.unlockProfile(updatedProfile, password: password),
        throwsA(protectionFailure()),
      );
      final unlocked = await service.unlockProfile(
        updatedProfile,
        password: changedPassword,
      );
      final recoveryStillWorks = await service.unlockProfile(
        updatedProfile,
        recoveryCode: recovery,
      );
      expect(await unlocked.decryptBytes(rewrapped), original);
      expect(await recoveryStillWorks.decryptBytes(rewrapped), original);
      // Rewrapping cannot revoke already copied historical ciphertext/passwords.
      expect(await old.decryptBytes(archive), original);
      for (final session in [
        old,
        recovered,
        changed,
        unlocked,
        recoveryStillWorks,
      ]) {
        session.dispose();
      }
    },
  );

  test(
    'file path stages complete validation and never publishes partial plaintext',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'breeze_security_test_',
      );
      final service = BackupProtectionService(deviceKeys: MemoryDeviceKeys());
      final pending = await service.create(password);
      final session = await service.confirmRecovery(
        pending,
        pending.recoveryCode,
        trustDevice: false,
      );
      try {
        final source = File('${directory.path}/source');
        final encrypted = File('${directory.path}/backup.breeze');
        final restored = File('${directory.path}/restored');
        final bytes = Uint8List.fromList(
          List.generate(2 * 1024 * 1024 + 9, (i) => i % 239),
        );
        await source.writeAsBytes(bytes);
        await session.encryptFile(source.path, encrypted.path);
        expect(
          await BackupProtectionService.isProtectedFile(encrypted.path),
          isTrue,
        );
        final profile = await BackupProtectionService.readProfileFromFile(
          encrypted.path,
        );
        expect(profile.archiveId, session.profile.archiveId);
        await session.decryptFile(encrypted.path, restored.path);
        expect(await restored.readAsBytes(), bytes);
        await expectLater(
          session.decryptFile(encrypted.path, restored.path),
          throwsA(protectionFailure('destination_exists')),
        );
        expect(await restored.readAsBytes(), bytes);
        final changed = await session.changePassword(changedPassword);
        final rewrapped = File('${directory.path}/rewrapped');
        await changed.rewrapFileHeader(encrypted.path, rewrapped.path);
        final oldBytes = await encrypted.readAsBytes();
        final newBytes = await rewrapped.readAsBytes();
        expect(
          oldBytes.sublist(payloadOffset(oldBytes)),
          newBytes.sublist(payloadOffset(newBytes)),
        );
        final bad = File('${directory.path}/corrupt');
        await bad.writeAsBytes(oldBytes.sublist(0, oldBytes.length - 1));
        final rejectedOutput = File('${directory.path}/must-not-exist');
        await expectLater(
          session.decryptFile(bad.path, rejectedOutput.path),
          throwsA(protectionFailure()),
        );
        expect(await rejectedOutput.exists(), isFalse);
        expect(
          await directory
              .list()
              .where((file) => file.path.contains('.breeze-protected-'))
              .isEmpty,
          isTrue,
          reason: 'private staging removed on failure and success',
        );
        changed.dispose();
        // Empty payload still has an authenticated terminal record.
        final empty = await session.encryptBytes(Uint8List(0));
        expect(await session.decryptBytes(empty), isEmpty);
        await expectLater(
          session.decryptBytes(
            Uint8List.fromList(empty.sublist(0, empty.length - 20)),
          ),
          throwsA(protectionFailure()),
        );
      } finally {
        session.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'native secure storage unavailable fails closed with no plaintext fallback',
    () async {
      const channel = MethodChannel('breeze/backup_security_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unsupported'),
          );
      const keys = MethodChannelBackupDeviceKeyStore(channel: channel);
      expect(await keys.isSupported(), isFalse);
      await expectLater(
        keys.readKey('synthetic'),
        throwsA(protectionFailure('device_storage_unavailable')),
      );
      await expectLater(
        keys.writeKey('synthetic', Uint8List(32)),
        throwsA(protectionFailure('device_storage_unavailable')),
      );
      await expectLater(
        keys.deleteKey('synthetic'),
        throwsA(protectionFailure('device_storage_unavailable')),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  test(
    'native availability reports supported and missing implementations without requiring a key',
    () async {
      const channel = MethodChannel('breeze/backup_security_availability_test');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'supported') return true;
            throw PlatformException(code: 'unexpected_key_access');
          });
      const native = MethodChannelBackupDeviceKeyStore(channel: channel);
      final BackupDeviceKeyStore store = native;
      try {
        expect(await native.isSupported(), isTrue);
        expect(await store.isSupported(), isTrue);
        expect(calls, ['supported', 'supported']);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
      expect(await native.isSupported(), isFalse);
    },
  );
}
