import 'package:flutter/services.dart';
import 'package:zephyr/service/backup_security/protection_error.dart';

/// Keys belong in device-only Keychain / Android Keystore backed storage.
/// Implementations must never fall back to preferences or a plaintext file.
abstract interface class BackupDeviceKeyStore {
  Future<Uint8List?> readKey(String archiveId);
  Future<void> writeKey(String archiveId, Uint8List key);
  Future<void> deleteKey(String archiveId);
}

/// Optional platform capability query. Injected stores are considered supported
/// unless they explicitly implement this interface and report otherwise.
abstract interface class BackupDeviceKeyStoreAvailability {
  Future<bool> isSupported();
}

extension BackupDeviceKeyStoreSupport on BackupDeviceKeyStore {
  Future<bool> isSupported() {
    final storage = this;
    if (storage is BackupDeviceKeyStoreAvailability) {
      return (storage as BackupDeviceKeyStoreAvailability).isSupported();
    }
    return Future<bool>.value(true);
  }
}

/// Native contract: channel `breeze/backup_security`; readKey/writeKey/deleteKey;
/// arguments `archiveId` and (write only) 32-byte `key`. read returns bytes/null.
/// Unsupported platforms fail closed. Native keys must not sync to cloud.
class MethodChannelBackupDeviceKeyStore
    implements BackupDeviceKeyStore, BackupDeviceKeyStoreAvailability {
  const MethodChannelBackupDeviceKeyStore({
    this._channel = const MethodChannel('breeze/backup_security'),
  });

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Uint8List?> readKey(String archiveId) async {
    try {
      final key = await _channel.invokeMethod<Uint8List>('readKey', {
        'archiveId': archiveId,
      });
      if (key != null && key.length != 32) {
        throw const BackupProtectionException('device_key_invalid');
      }
      return key;
    } on PlatformException {
      throw const BackupProtectionException('device_storage_unavailable');
    } on MissingPluginException {
      throw const BackupProtectionException('device_storage_unavailable');
    }
  }

  @override
  Future<void> writeKey(String archiveId, Uint8List key) async {
    if (key.length != 32) {
      throw const BackupProtectionException('device_key_invalid');
    }
    try {
      await _channel.invokeMethod<void>('writeKey', {
        'archiveId': archiveId,
        'key': key,
      });
    } on PlatformException {
      throw const BackupProtectionException('device_storage_unavailable');
    } on MissingPluginException {
      throw const BackupProtectionException('device_storage_unavailable');
    }
  }

  @override
  Future<void> deleteKey(String archiveId) async {
    try {
      await _channel.invokeMethod<void>('deleteKey', {'archiveId': archiveId});
    } on PlatformException {
      throw const BackupProtectionException('device_storage_unavailable');
    } on MissingPluginException {
      throw const BackupProtectionException('device_storage_unavailable');
    }
  }
}
