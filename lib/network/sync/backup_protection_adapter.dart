import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_resource_paths.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';

/// Translates only managed payload bytes. Domain codecs and semantic MD5s keep
/// their standard representation; protected mode is an outer authenticated layer.
class BackupProtectionSyncAdapter
    implements ComicSyncRemoteAdapter, BackupProtectionTransportAccess {
  BackupProtectionSyncAdapter(
    this.protectionTransport, {
    BackupProtectionManager? manager,
  }) : manager = manager ?? BackupProtectionManager.shared;

  @override
  final ComicSyncRemoteAdapter protectionTransport;
  final BackupProtectionManager manager;
  Future<void>? _preparing;
  CloudBackupProtectionStatus? _status;
  int _preparedRevision = -1;
  final Map<String, Uint8List> _decoded = {};
  int _cacheBytes = 0;
  Set<String> _fullReplaceStaging = const {};
  bool _fullReplaceReadOnlyDiscovery = false;
  static const _cacheLimit = 16 * 1024 * 1024;
  static final _payload = RegExp(
    r'^(?:comic_\d+\.bin|settings_\d+\.bin|video_library_[a-f0-9]{32}\.bin|chapter_progress_v1_[a-f0-9]{32}\.bin|appearance_[a-f0-9]{32}(?:_[a-f0-9]{64})?\.bin|appearance_resource_[a-f0-9]{64}\.bin)$',
  );

  String _path(String path) {
    final normalized = path.replaceFirst(RegExp(r'^/+'), '');
    return normalized.contains('/')
        ? normalized
        : '${SyncArchiveContext.currentRoot}/$normalized';
  }

  bool _isPayload(String path) =>
      _payload.hasMatch(_path(path).split('/').last);

  @override
  void invalidateProtection() {
    _status = null;
    _preparedRevision = -1;
    _decoded.clear();
    _cacheBytes = 0;
  }

  Future<void> _prepare() async {
    if (_status != null && _preparedRevision == manager.revision) return;
    final active = _preparing;
    if (active != null) return active;
    final operation = _prepareNow();
    _preparing = operation;
    try {
      await operation;
    } finally {
      if (identical(_preparing, operation)) _preparing = null;
    }
  }

  Future<void> _prepareNow() async {
    _decoded.clear();
    _cacheBytes = 0;
    _status = await manager.prepareCloud(
      protectionTransport,
      authenticateResources: false,
      fullReplaceStagingPaths: _fullReplaceStaging,
      fullReplaceReadOnlyDiscovery: _fullReplaceReadOnlyDiscovery,
      onDecoded: (path, bytes) {
        if (_cacheBytes + bytes.length <= _cacheLimit) {
          _decoded[_path(path)] = bytes;
          _cacheBytes += bytes.length;
        }
      },
    );
    _preparedRevision = manager.revision;
  }

  Future<void> _guard() async {
    await _prepare();
    await manager.guardCloudMutation(protectionTransport, _status!);
  }

  @override
  Future<void> testConnection() => protectionTransport.testConnection();

  @override
  Future<void> ensureRemoteReady() async {
    await _guard();
    await protectionTransport.ensureRemoteReady();
  }

  @override
  Future<List<String>> listRemoteDataFiles() async {
    await _prepare();
    return protectionTransport.listRemoteDataFiles();
  }

  @override
  Future<List<int>> downloadRemoteFile(String path) async {
    await _prepare();
    if (!_isPayload(path)) return protectionTransport.downloadRemoteFile(path);
    final cached = _decoded[_path(path)];
    if (cached != null) return cached;
    final raw = await protectionTransport.downloadRemoteFile(path);
    if (raw.length > BackupProtectionSession.maxBytesPayload + 65536 + 4096) {
      throw const BackupProtectionException(
        'cloud_protection_payload_too_large',
      );
    }
    final protected = BackupProtectionService.isProtectedBytes(raw);
    if (_status!.mode == BackupProtectionMode.passwordProtected) {
      if (!protected) {
        throw const BackupProtectionException(
          'cloud_protection_payload_unprotected',
        );
      }
      final session = manager.sessionForProfile(_status!.profile)!;
      return session.decryptBytes(
        raw is Uint8List ? raw : Uint8List.fromList(raw),
      );
    }
    if (protected) {
      // Includes unknown protected-family versions; never send them to legacy.
      BackupProtectionService.readProfileFromBytes(raw);
      throw const BackupProtectionException('cloud_protection_changed_retry');
    }
    return raw;
  }

  /// The explicit full replacement must observe current remote bytes, rather
  /// than the authenticated cache populated during its earlier preview.
  void useFullReplaceStaging(Set<String> paths, {bool reset = true}) {
    _fullReplaceReadOnlyDiscovery = true;
    _fullReplaceStaging = Set.unmodifiable(paths);
    if (reset) invalidateProtection();
  }

  Future<List<int>> readFreshForFullReplace(String path) async {
    await _guard();
    final removed = _decoded.remove(_path(path));
    if (removed != null) _cacheBytes -= removed.length;
    try {
      return await downloadRemoteFile(path);
    } on BackupProtectionException catch (error) {
      if (!_fullReplaceStaging.contains(_path(path)) ||
          !{
            'invalid_header',
            'authentication_failed',
            'cloud_protection_payload_unprotected',
          }.contains(error.code))
        rethrow;
      // Only an explicitly journalled uncommitted publication may be a partial
      // envelope. Its raw digest is previewed; it never becomes imported data.
      return protectionTransport.downloadRemoteFile(path);
    }
  }

  Future<void> guardFullReplace() => _guard();

  @override
  Future<String> downloadRemoteMd5() async {
    await _prepare();
    return protectionTransport.downloadRemoteMd5();
  }

  @override
  Future<void> uploadRemoteMd5(String value) async {
    await _guard();
    await protectionTransport.uploadRemoteMd5(value);
  }

  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    await _guard();
    final protection = _status!;
    final revision = manager.revision;
    if (isAppearanceResourcePath(path)) {
      final digest = path
          .split('/')
          .last
          .substring('appearance_resource_'.length)
          .replaceFirst('.bin', '');
      if (sha256.convert(data).toString() != digest) {
        throw const BackupProtectionException(
          'cloud_resource_integrity_failed',
        );
      }
      final existing = await protectionTransport.listRemoteDataFiles();
      if (existing.any((candidate) => _path(candidate) == _path(path)) &&
          !_fullReplaceStaging.contains(_path(path))) {
        // Even an orphan protected blob may not be overwritten after metadata
        // loss. Authenticate its envelope before resource replacement, except
        // a full-replacement retry that has verified its own staged digest.
        await downloadRemoteFile(path);
      }
    }
    List<int> outgoing = data;
    if (_isPayload(path) &&
        protection.mode == BackupProtectionMode.passwordProtected) {
      final session = manager.sessionForProfile(protection.profile)!;
      outgoing = await session.encryptBytes(
        data is Uint8List ? data : Uint8List.fromList(data),
      );
    }
    if (manager.revision != revision) {
      throw const BackupProtectionException('cloud_protection_changed_retry');
    }
    await protectionTransport.uploadRemoteFile(
      path,
      outgoing,
      contentType: contentType,
    );
    final removed = _decoded.remove(_path(path));
    if (removed != null) _cacheBytes -= removed.length;
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    await _guard();
    await protectionTransport.deleteRemoteFiles(paths);
    for (final path in paths) {
      final removed = _decoded.remove(_path(path));
      if (removed != null) _cacheBytes -= removed.length;
    }
  }
}
