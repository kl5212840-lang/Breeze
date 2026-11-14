import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/sync_failure.dart';

void main() {
  test('structured connection and storage errors remain distinct', () {
    expect(
      classifySyncFailure(TimeoutException('synthetic')),
      SyncFailureKind.timeout,
    );
    expect(
      classifySyncFailure(const SocketException('synthetic')),
      SyncFailureKind.connection,
    );
    expect(
      classifySyncFailure(const HandshakeException('synthetic')),
      SyncFailureKind.secureConnection,
    );
    expect(
      classifySyncFailure(const FileSystemException('synthetic')),
      SyncFailureKind.storage,
    );
    expect(
      classifySyncFailure(const FormatException('synthetic')),
      SyncFailureKind.format,
    );
  });
  test('unknown failures must not be guessed to be a network issue', () {
    expect(
      classifySyncFailure(StateError('connection refused')),
      SyncFailureKind.unknown,
    );
  });
}
