import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';

final _managedArchiveFile = RegExp(
  r'^(?:comic\.md5|settings\.md5|comic_\d+\.bin|settings_\d+\.bin|video_library_[a-f0-9]{32}\.bin|chapter_progress_v1_[a-f0-9]{32}\.bin|appearance_[a-f0-9]{32}(?:_[a-f0-9]{64})?\.bin|appearance_resource_[a-f0-9]{64}\.bin)$',
);

bool _hasManagedArchiveData(List<String> paths) => paths.any((path) {
  final parts = path.replaceFirst(RegExp(r'^/+'), '').split('/');
  return parts.length == 2 &&
      parts.first == SyncArchiveContext.currentRoot &&
      _managedArchiveFile.hasMatch(parts.last);
});

/// A separate capability for user-confirmed source deletion. Implementations
/// keep ordinary legacy upload/delete methods read-only; no writable legacy
/// adapter or mutable context is handed to ordinary synchronization.
abstract interface class LegacyPluginPurgeTransport {
  Future<void> rewriteLegacySnapshotForPluginPurge(
    String physicalPath,
    List<int> data,
  );
}

/// Only the separately confirmed full-cloud replacement may remove legacy
/// managed files. Ordinary legacy synchronization remains read-only.
abstract interface class FullCloudReplaceTransport {
  Future<void> deleteLegacyFilesForFullReplace(List<String> physicalPaths);
}

bool isManagedSyncArchivePath(String input) {
  final parts = input.replaceFirst(RegExp(r'^/+'), '').split('/');
  return parts.length == 2 &&
      parts.first == SyncArchiveContext.currentRoot &&
      _managedArchiveFile.hasMatch(parts.last);
}

String validateFullReplaceLegacyPath(SyncArchiveContext context, String input) {
  final path = input.replaceFirst(RegExp(r'^/+'), '');
  final parts = path.split('/');
  if (!context.legacy ||
      !context.readOnly ||
      parts.length != 2 ||
      parts.first != SyncArchiveContext.legacyRoot ||
      !_managedArchiveFile.hasMatch(parts.last)) {
    throw StateError('Full replacement is outside the managed legacy archive');
  }
  return path;
}

String validateLegacyPluginPurgePath(SyncArchiveContext context, String input) {
  final path = input.replaceFirst(RegExp(r'^/+'), '');
  final parts = path.split('/');
  if (!context.legacy ||
      !context.readOnly ||
      parts.length != 2 ||
      parts.first != SyncArchiveContext.legacyRoot ||
      !_managedArchiveFile.hasMatch(parts.last)) {
    throw StateError('Explicit plugin purge is outside the legacy archive');
  }
  return path;
}

class SyncArchiveStatus {
  const SyncArchiveStatus({
    required this.hasCurrentData,
    required this.hasLegacyData,
  });
  final bool hasCurrentData, hasLegacyData;
}

/// Domain sync code uses one logical root. Only this boundary translates it
/// into a physical archive, so old-root import cannot reuse a cleanup by mistake.
class ScopedSyncArchiveAdapter implements ComicSyncRemoteAdapter {
  ScopedSyncArchiveAdapter(
    this.transport,
    this.context, {
    this.legacyReader,
    this.identity = 'default',
  });
  final ComicSyncRemoteAdapter transport;
  final SyncArchiveContext context;
  final ScopedSyncArchiveAdapter? legacyReader;
  final String identity;
  Future<void> Function()? roundPreflight;
  void Function()? onInvalidate;
  Future<void>? _preparing;
  bool _validated = false;
  void validated() => _validated = true;
  void invalidate() {
    _validated = false;
    onInvalidate?.call();
  }

  Future<void> prepare() async {
    if (_validated || roundPreflight == null) return;
    final job = _preparing ??= roundPreflight!();
    try {
      await job;
    } finally {
      if (identical(_preparing, job)) _preparing = null;
    }
  }

  String _physical(String input) {
    var path = input.replaceFirst(RegExp(r'^/+'), '');
    if (!path.contains('/')) path = '${SyncArchiveContext.currentRoot}/$path';
    final parts = path.split('/');
    if (parts.length != 2 ||
        parts.first != SyncArchiveContext.currentRoot ||
        !_managedArchiveFile.hasMatch(parts.last)) {
      throw StateError('Archive path is outside its managed files');
    }
    return '${context.root}/${parts.last}';
  }

  void _writable() {
    if (context.readOnly) throw const LegacyArchiveReadOnly();
  }

  @override
  Future<void> testConnection() => transport.testConnection();
  @override
  Future<void> ensureRemoteReady() =>
      context.readOnly ? Future<void>.value() : transport.ensureRemoteReady();
  @override
  Future<List<String>> listRemoteDataFiles() async {
    final List<String> files;
    try {
      files = await transport.listRemoteDataFiles();
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('404') ||
          message.contains('not found') ||
          message.contains('nosuchkey')) {
        return [];
      }
      rethrow;
    }
    return [
      for (final raw in files)
        if (raw.replaceFirst(RegExp(r'^/+'), '').startsWith('${context.root}/'))
          if (raw.replaceFirst(RegExp(r'^/+'), '').split('/').length == 2)
            if (raw.split('/').last.isNotEmpty)
              '${SyncArchiveContext.currentRoot}/${raw.split('/').last}',
    ];
  }

  @override
  Future<List<int>> downloadRemoteFile(String path) =>
      transport.downloadRemoteFile(_physical(path));
  @override
  Future<String> downloadRemoteMd5() => transport.downloadRemoteMd5();
  @override
  Future<void> uploadRemoteMd5(String value) {
    _writable();
    return transport.uploadRemoteMd5(value);
  }

  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) {
    _writable();
    return transport.uploadRemoteFile(
      _physical(path),
      data,
      contentType: contentType,
    );
  }

  /// Called only by the explicit plugin purge after both archive plans pass
  /// validation. Normal upload/delete still call _writable() and reject legacy.
  Future<void> rewriteLegacySnapshotForPluginPurge(
    String logicalPath,
    List<int> data,
  ) {
    final physical = validateLegacyPluginPurgePath(
      context,
      _physical(logicalPath),
    );
    final target = transport;
    if (target is! LegacyPluginPurgeTransport) {
      throw StateError(
        'Transport does not support explicit legacy plugin purge',
      );
    }
    return (target as LegacyPluginPurgeTransport)
        .rewriteLegacySnapshotForPluginPurge(physical, data);
  }

  bool get supportsFullLegacyReplace => transport is FullCloudReplaceTransport;

  Future<void> deleteLegacyFilesForFullReplace(List<String> paths) {
    final physical = paths
        .map((path) => validateFullReplaceLegacyPath(context, _physical(path)))
        .toList();
    final target = transport;
    if (target is! FullCloudReplaceTransport) {
      throw StateError(
        'Transport does not support complete legacy replacement',
      );
    }
    return (target as FullCloudReplaceTransport)
        .deleteLegacyFilesForFullReplace(physical);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) {
    _writable();
    final physical = paths.map(_physical).toList();
    return transport.deleteRemoteFiles(physical);
  }
}

Future<SyncArchiveStatus> readScopedArchiveStatus(
  ComicSyncRemoteAdapter current,
  ComicSyncRemoteAdapter legacy,
) async => SyncArchiveStatus(
  hasCurrentData: _hasManagedArchiveData(await current.listRemoteDataFiles()),
  hasLegacyData: _hasManagedArchiveData(await legacy.listRemoteDataFiles()),
);

Future<void> prepareScopedSyncArchive(ComicSyncRemoteAdapter adapter) async {
  if (adapter is ScopedSyncArchiveAdapter) await adapter.prepare();
}
