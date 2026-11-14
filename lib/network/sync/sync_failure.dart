import 'dart:async';
import 'dart:io';

/// User-facing categories use structured errors only. An opaque plugin or
/// transport exception is not evidence that the user's network is at fault.
enum SyncFailureKind {
  timeout,
  connection,
  secureConnection,
  storage,
  format,
  noCloudBackup,
  unknown,
}

/// A transport confirmed that the requested object is absent.
class SyncRemoteFileNotFound implements Exception {
  const SyncRemoteFileNotFound();
}

class NoCloudBackup implements Exception {
  const NoCloudBackup();
}

SyncFailureKind classifySyncFailure(Object error) => switch (error) {
  TimeoutException() => SyncFailureKind.timeout,
  SocketException() => SyncFailureKind.connection,
  HandshakeException() => SyncFailureKind.secureConnection,
  FileSystemException() => SyncFailureKind.storage,
  FormatException() => SyncFailureKind.format,
  NoCloudBackup() => SyncFailureKind.noCloudBackup,
  _ => SyncFailureKind.unknown,
};
