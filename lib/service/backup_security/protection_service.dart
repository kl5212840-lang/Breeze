import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:zephyr/service/backup_security/device_key_store.dart';
import 'package:zephyr/service/backup_security/protection_error.dart';

part 'protection_crypto.dart';
part 'protection_envelope.dart';

/// Public metadata only: contains wrapped keys, never a password or unwrapped key.
/// Keep this profile when protected mode is enabled; a local standard default
/// must never replace a protected remote archive without explicit authorization.
class BackupProtectionProfile {
  BackupProtectionProfile._(this._encoded);

  factory BackupProtectionProfile.fromJson(Map<String, dynamic> json) {
    final encoded = _canonical(json);
    if (utf8.encode(encoded).length > _maxHeaderBytes) {
      throw const BackupProtectionException('invalid_header');
    }
    final copy = _object(jsonDecode(encoded));
    _validateProfile(copy);
    return BackupProtectionProfile._(_canonical(copy));
  }

  final String _encoded;
  Map<String, dynamic> toJson() => _object(jsonDecode(_encoded));
  String get archiveId => toJson()['archiveId'] as String;

  @override
  String toString() => 'BackupProtectionProfile(protected)';
}

/// Recovery material is a key-equivalent secret. Display/save it explicitly,
/// separately from backup data; never put this object in logs or preferences.
class PendingBackupProtection {
  PendingBackupProtection._(this.profile, this.recoveryCode, this._key);
  final BackupProtectionProfile profile;
  final String recoveryCode;
  final Uint8List _key;
  bool _consumed = false;

  String get recoveryFile => jsonEncode({
    'format': 'breeze-recovery-key',
    'version': 1,
    'archiveId': profile.archiveId,
    'recoveryCode': recoveryCode,
  });

  /// Cancelling setup releases the in-memory root key without trusting a device.
  void dispose() {
    _key.fillRange(0, _key.length, 0);
    _consumed = true;
  }

  @override
  String toString() => 'PendingBackupProtection(secret)';
}

class BackupProtectionService {
  BackupProtectionService({BackupDeviceKeyStore? deviceKeys})
    : deviceKeys = deviceKeys ?? const MethodChannelBackupDeviceKeyStore();

  final BackupDeviceKeyStore deviceKeys;

  /// Setup remains pending until the saved recovery material is re-entered.
  Future<PendingBackupProtection> create(String password) async {
    _validatePassword(password);
    return Isolate.run(() {
      final key = _random(32);
      final recovery = _random(32);
      final id = _hex(_random(16));
      final profile = _makeProfile(id, key, password, recovery);
      return PendingBackupProtection._(profile, _recoveryCode(recovery), key);
    });
  }

  /// A single export uses its own password and never changes the current
  /// cloud protection profile or creates a trusted-device key.
  Future<BackupProtectionSession> createFileSession(String password) async {
    final pending = await create(password);
    try {
      return BackupProtectionSession._(
        pending.profile,
        Uint8List.fromList(pending._key),
      );
    } finally {
      pending.dispose();
    }
  }

  Future<BackupProtectionSession> confirmRecovery(
    PendingBackupProtection pending,
    String recoveryCode, {
    bool trustDevice = true,
  }) async {
    if (pending._consumed) {
      throw const BackupProtectionException('setup_already_consumed');
    }
    final session = await unlockProfile(
      pending.profile,
      recoveryCode: recoveryCode,
    );
    if (trustDevice) await trust(session);
    pending.dispose();
    return session;
  }

  /// Exactly one factor must be chosen. There is no account/server recovery.
  /// A trusted device can reset the password because it already owns the key.
  Future<BackupProtectionSession> unlockProfile(
    BackupProtectionProfile profile, {
    String? password,
    String? recoveryCode,
    String? recoveryFile,
    bool useTrustedDevice = false,
    bool trustDevice = false,
  }) async {
    final factors = [
      password != null,
      recoveryCode != null,
      recoveryFile != null,
      useTrustedDevice,
    ].where((value) => value).length;
    if (factors != 1) {
      throw const BackupProtectionException('choose_one_unlock_factor');
    }
    Uint8List? trusted;
    if (useTrustedDevice) {
      trusted = await deviceKeys.readKey(profile.archiveId);
      if (trusted == null) {
        throw const BackupProtectionException('device_not_authorized');
      }
    }
    final key = await Isolate.run(() {
      try {
        final json = profile.toJson();
        Uint8List key;
        if (trusted != null) {
          key = Uint8List.fromList(trusted);
        } else if (password != null) {
          _validatePassword(password, creating: false);
          final slot = _object(json['password']);
          final wrappingKey = _passwordKey(password, _bytes(slot['salt'], 16));
          key = _openSlot(profile.archiveId, 'password', slot, wrappingKey);
        } else {
          final code = recoveryFile == null
              ? recoveryCode!
              : _readRecoveryFile(recoveryFile, profile.archiveId);
          key = _openSlot(
            profile.archiveId,
            'recovery',
            _object(json['recovery']),
            _decodeRecoveryCode(code),
          );
        }
        _verifyProfile(profile, key);
        return key;
      } on BackupProtectionException {
        rethrow;
      } catch (_) {
        throw const BackupProtectionException('unlock_failed');
      }
    });
    final session = BackupProtectionSession._(profile, key);
    if (trustDevice) await trust(session);
    return session;
  }

  Future<void> trust(BackupProtectionSession session) async {
    session._ensureOpen();
    await deviceKeys.writeKey(
      session.profile.archiveId,
      Uint8List.fromList(session._key),
    );
  }

  Future<void> forgetDevice(String archiveId) =>
      deviceKeys.deleteKey(archiveId);

  /// The entire protected family is recognized, including unsupported versions;
  /// callers must dispatch it here instead of attempting a legacy decrypt.
  static bool isProtectedBytes(List<int> bytes) {
    if (bytes.length < _family.length) return false;
    for (var index = 0; index < _family.length; index++) {
      if (bytes[index] != _family[index]) return false;
    }
    return true;
  }

  static Future<bool> isProtectedFile(String path) async {
    final input = await File(path).open();
    try {
      return isProtectedBytes(await input.read(_magic.length));
    } finally {
      await input.close();
    }
  }

  static BackupProtectionProfile readProfileFromBytes(List<int> bytes) {
    if (bytes.length < 12) {
      throw const BackupProtectionException('invalid_header');
    }
    _checkMagic(bytes.take(8).toList());
    final size = _u32(Uint8List.fromList(bytes.sublist(8, 12)));
    if (size > _maxHeaderBytes || size == 0 || bytes.length < 12 + size) {
      throw const BackupProtectionException('invalid_header');
    }
    final header = _parseHeader(
      Uint8List.fromList(bytes.sublist(12, 12 + size)),
    );
    return BackupProtectionProfile.fromJson(_object(header['profile']));
  }

  static Future<BackupProtectionProfile> readProfileFromFile(String path) =>
      Isolate.run(() {
        final input = File(path).openSync();
        try {
          final header = _readHeader(input);
          return BackupProtectionProfile.fromJson(_object(header['profile']));
        } finally {
          input.closeSync();
        }
      });
}

/// An unlocked session never serializes its root key. Dispose it on lock/logout.
/// Large archives use file methods: they process at most one 1 MiB chunk in an
/// isolate and publish plaintext only after all tags and the terminal record pass.
class BackupProtectionSession {
  BackupProtectionSession._(this.profile, this._key);
  final BackupProtectionProfile profile;
  final Uint8List _key;
  bool _closed = false;

  static const maxBytesPayload = 64 * 1024 * 1024;
  static const maxFilePayload = 1024 * 1024 * 1024 * 1024; // 1 TiB.

  void _ensureOpen() {
    if (_closed) throw const BackupProtectionException('session_closed');
  }

  void dispose() {
    _key.fillRange(0, _key.length, 0);
    _closed = true;
  }

  Future<Uint8List> encryptBytes(Uint8List plaintext) async {
    _ensureOpen();
    if (plaintext.length > maxBytesPayload) {
      throw const BackupProtectionException('use_streaming_file_backup');
    }
    final key = Uint8List.fromList(_key);
    final current = profile;
    return Isolate.run(() => _encryptBytes(plaintext, current, key));
  }

  Future<Uint8List> decryptBytes(Uint8List envelope) async {
    _ensureOpen();
    // Include worst-case bounded framing overhead without allocating plaintext.
    if (envelope.length > maxBytesPayload + _maxHeaderBytes + 4096) {
      throw const BackupProtectionException('use_streaming_file_backup');
    }
    final key = Uint8List.fromList(_key);
    return Isolate.run(() => _decryptBytes(envelope, key));
  }

  Future<void> encryptFile(String sourcePath, String destinationPath) async {
    _ensureOpen();
    final key = Uint8List.fromList(_key);
    final current = profile;
    await Isolate.run(
      () => _cryptFile(sourcePath, destinationPath, current, key, true),
    );
  }

  Future<void> decryptFile(String sourcePath, String destinationPath) async {
    _ensureOpen();
    final key = Uint8List.fromList(_key);
    final current = profile;
    await Isolate.run(
      () => _cryptFile(sourcePath, destinationPath, current, key, false),
    );
  }

  /// Requires this already-unlocked session. Does not alter the recovery factor
  /// or rewrite payloads. Previous external copies retain their old password.
  Future<BackupProtectionSession> changePassword(String newPassword) async {
    _ensureOpen();
    _validatePassword(newPassword);
    final key = Uint8List.fromList(_key);
    final current = profile;
    return Isolate.run(() {
      final json = current.toJson();
      final salt = _random(16);
      json['password'] = _sealSlot(
        current.archiveId,
        'password',
        key,
        _passwordKey(newPassword, salt),
        salt: salt,
      );
      final updated = _authenticateProfile(json, key);
      return BackupProtectionSession._(updated, key);
    });
  }

  /// Refreshes public wrapping metadata using an already-authorized root key.
  /// A trusted device may keep syncing after another device changes the password.
  Future<BackupProtectionSession> adoptProfile(
    BackupProtectionProfile updated,
  ) async {
    _ensureOpen();
    if (updated.archiveId != profile.archiveId) {
      throw const BackupProtectionException('profile_mismatch');
    }
    final key = Uint8List.fromList(_key);
    return Isolate.run(() {
      _verifyProfile(updated, key);
      return BackupProtectionSession._(updated, key);
    });
  }

  /// Replaces only the authenticated header, copying payload chunks verbatim.
  /// Authenticate the complete source first, so damaged archives are not blessed.
  /// Destination must not exist; caller controls its eventual atomic promotion.
  Future<void> rewrapFileHeader(
    String sourcePath,
    String destinationPath,
  ) async {
    _ensureOpen();
    final key = Uint8List.fromList(_key);
    final current = profile;
    await Isolate.run(
      () => _rewrapFile(sourcePath, destinationPath, current, key),
    );
  }

  /// Bounded equivalent used by the cloud adapter for existing small archives.
  Future<Uint8List> rewrapBytesHeader(Uint8List envelope) async {
    _ensureOpen();
    if (envelope.length > maxBytesPayload + _maxHeaderBytes + 4096) {
      throw const BackupProtectionException('use_streaming_file_backup');
    }
    final key = Uint8List.fromList(_key);
    final current = profile;
    return Isolate.run(() {
      final header = _headerFromBytes(envelope);
      _verifyHeader(header, key);
      _walkBytes(envelope, header, key, discard: true);
      final previous = BackupProtectionProfile.fromJson(
        _object(header['profile']),
      );
      if (previous.archiveId != current.archiveId) {
        throw const BackupProtectionException('profile_mismatch');
      }
      final replacement = _makeHeader(
        _object(header['descriptor']),
        current,
        key,
      );
      return (BytesBuilder(copy: false)
            ..add(_headerBytes(replacement))
            ..add(Uint8List.sublistView(envelope, _headerOffset(envelope))))
          .takeBytes();
    });
  }

  @override
  String toString() => 'BackupProtectionSession(unlocked)';
}
