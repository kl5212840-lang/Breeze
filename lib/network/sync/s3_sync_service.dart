import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:minio/minio.dart';
import 'package:zephyr/config/global/global_setting.dart';

import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_failure.dart';

class S3SyncService
    implements
        ComicSyncRemoteAdapter,
        BoundedSyncFileReader,
        LegacyPluginPurgeTransport,
        FullCloudReplaceTransport {
  S3SyncService(
    this._settings, {
    this.archive = SyncArchiveContext.current,
    this.operationTimeout = const Duration(minutes: 2),
  }) : _minio = _createMinio(_settings) {
    if (!isConfigured(_settings)) {
      throw Exception('S3 配置不完整');
    }
  }

  final GlobalSettingState _settings;
  final SyncArchiveContext archive;
  final Duration operationTimeout;
  String get _root => archive.root;
  void _writable() {
    if (archive.readOnly) throw const LegacyArchiveReadOnly();
  }

  final Minio _minio;

  Future<T> _request<T>(Future<T> Function() action) async {
    final scope = _S3HttpScope(HttpOverrides.current);
    try {
      return await HttpOverrides.runWithHttpOverrides(
        () => Future<T>.sync(action).timeout(operationTimeout),
        scope,
      );
    } finally {
      scope.close();
    }
  }

  static bool isConfigured(GlobalSettingState settings) {
    return settings.syncSetting.s3Setting.endpoint.trim().isNotEmpty &&
        settings.syncSetting.s3Setting.accessKey.trim().isNotEmpty &&
        settings.syncSetting.s3Setting.secretKey.isNotEmpty &&
        settings.syncSetting.s3Setting.bucket.trim().isNotEmpty;
  }

  @override
  Future<void> testConnection() async {
    final exists = await _request(
      () => _minio.bucketExists(_settings.syncSetting.s3Setting.bucket),
    );
    if (!exists) {
      throw Exception(
        'S3 Bucket 不存在或没有访问权限: ${_settings.syncSetting.s3Setting.bucket}',
      );
    }
  }

  @override
  Future<void> ensureRemoteReady() async {}

  @override
  Future<String> downloadRemoteMd5() async {
    for (final candidate in _md5ObjectKeyCandidates) {
      try {
        final bytes = await _readObject(candidate, 1024);
        final value = utf8.decode(bytes).trim();
        if (value.isNotEmpty) {
          return value;
        }
      } on MinioS3Error catch (e) {
        if (_isMissingObject(e)) continue;
        throw Exception('S3 md5 下载失败: ${e.message}');
      }
    }
    return '';
  }

  @override
  Future<void> uploadRemoteMd5(String value) async {
    _writable();
    final bytes = utf8.encode(value);
    final data = Uint8List.fromList(bytes);
    await _request(
      () => _minio.putObject(
        _settings.syncSetting.s3Setting.bucket,
        _md5ObjectKey,
        Stream<Uint8List>.value(data),
        size: bytes.length,
      ),
    );
  }

  @override
  Future<List<String>> listRemoteDataFiles() => _request(() async {
    final files = <String>{};
    final markers = <String>{};
    String? marker;
    while (true) {
      final page = await _minio.listObjectsQuery(
        _settings.syncSetting.s3Setting.bucket,
        _syncRootPrefix,
        marker,
        '',
        1000,
      );
      final keys = <String>[
        for (final object in page.contents ?? [])
          if (object.key case final String key when key.isNotEmpty) key,
      ];
      files.addAll(keys.map(_normalizeObjectKey));
      if (page.isTruncated == false) return files.toList();
      final next = page.nextMarker ?? (keys.isEmpty ? null : keys.last);
      if (page.isTruncated == null ||
          next == null ||
          next.isEmpty ||
          !markers.add(next)) {
        throw const FormatException('Cloud listing could not be completed');
      }
      marker = next;
    }
  });

  @override
  Future<List<int>> downloadRemoteFile(String remotePath) =>
      downloadBoundedFile(remotePath, syncArchiveWireMaxBytes);

  @override
  Future<List<int>> downloadBoundedFile(String remotePath, int maxBytes) async {
    try {
      return await _readObject(
        _toManagedObjectKey(remotePath),
        maxBytes.clamp(0, syncArchiveWireMaxBytes),
      );
    } on MinioS3Error catch (error) {
      if (_isMissingObject(error)) throw const SyncRemoteFileNotFound();
      rethrow;
    }
  }

  @override
  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    _writable();
    final remoteObject = _toManagedObjectKey(remotePath);

    await _request(
      () => _minio.putObject(
        _settings.syncSetting.s3Setting.bucket,
        remoteObject,
        Stream<Uint8List>.value(Uint8List.fromList(data)),
        size: data.length,
      ),
    );
  }

  /// Separate, explicit source-deletion capability. Ordinary upload/delete
  /// retain _writable(); only canonical managed legacy files can reach here.
  @override
  Future<void> rewriteLegacySnapshotForPluginPurge(
    String physicalPath,
    List<int> data,
  ) async {
    final path = validateLegacyPluginPurgePath(archive, physicalPath);
    await _request(
      () => _minio.putObject(
        _settings.syncSetting.s3Setting.bucket,
        path,
        Stream<Uint8List>.value(Uint8List.fromList(data)),
        size: data.length,
      ),
    );
  }

  @override
  Future<void> deleteLegacyFilesForFullReplace(
    List<String> physicalPaths,
  ) async {
    final paths = physicalPaths
        .map((path) => validateFullReplaceLegacyPath(archive, path))
        .toList();
    for (final path in paths) {
      await _request(
        () => _minio.removeObject(_settings.syncSetting.s3Setting.bucket, path),
      );
    }
  }

  @override
  Future<void> deleteRemoteFiles(List<String> remotePaths) async {
    _writable();
    if (remotePaths.isEmpty) {
      return;
    }

    final normalizedPaths = remotePaths
        .map(_toManagedObjectKey)
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedPaths.isEmpty) {
      return;
    }

    for (final path in normalizedPaths) {
      try {
        await _request(
          () =>
              _minio.removeObject(_settings.syncSetting.s3Setting.bucket, path),
        );
      } on MinioS3Error catch (e) {
        if (_isMissingObject(e)) continue;
        throw Exception('S3 文件删除失败: ${e.message}');
      }
    }
  }

  bool _isMissingObject(MinioS3Error error) => switch (error.error?.code) {
    'NoSuchKey' || 'NotFound' || 'NoSuchObject' => true,
    _ => false,
  };

  String get _syncRootPrefix => '$_root/';

  String get _md5ObjectKey =>
      '$_syncRootPrefix${ComicSyncCore.comicMd5FileName}';

  List<String> get _md5ObjectKeyCandidates => [_md5ObjectKey];

  String _toManagedObjectKey(String key) {
    final normalized = _normalizeObjectKey(key);
    if (normalized.isEmpty) {
      return _syncRootPrefix;
    }
    if (normalized.startsWith(_syncRootPrefix)) {
      return normalized;
    }
    if (normalized.contains('/')) {
      throw StateError('Archive path is outside its root');
    }
    return '$_syncRootPrefix$normalized';
  }

  String _normalizeObjectKey(String key) {
    return key.replaceFirst(RegExp(r'^/+'), '');
  }

  Future<List<int>> _readObject(String key, int maxBytes) => _request(() async {
    final stream = await _minio.getObject(
      _settings.syncSetting.s3Setting.bucket,
      key,
    );
    if ((stream.contentLength ?? 0) > maxBytes) {
      throw const SyncRemoteFileTooLarge();
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(const Duration(seconds: 30))) {
      if (chunk.length > maxBytes - data.length) {
        throw const SyncRemoteFileTooLarge();
      }
      data.add(chunk);
    }
    return data.takeBytes();
  });
}

// Minio creates its own HTTP clients. Keep the deadline and socket ownership
// local to this operation, including any subsequent SDK pagination requests.
class _S3HttpScope extends HttpOverrides {
  _S3HttpScope(this.parent);

  final HttpOverrides? parent;
  final _clients = <HttpClient>{};
  bool _closed = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (_closed) throw TimeoutException('Cloud request ended');
    final client =
        parent?.createHttpClient(context) ?? super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 10);
    _clients.add(client);
    return client;
  }

  void close() {
    _closed = true;
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }
}

Minio _createMinio(GlobalSettingState settings) {
  final resolved = _resolveEndpoint(
    settings.syncSetting.s3Setting.endpoint,
    settings.syncSetting.s3Setting.port,
  );
  return Minio(
    endPoint: resolved.host,
    port: resolved.port,
    accessKey: settings.syncSetting.s3Setting.accessKey,
    secretKey: settings.syncSetting.s3Setting.secretKey,
    useSSL: settings.syncSetting.s3Setting.useSSL,
    region: settings.syncSetting.s3Setting.region.isEmpty
        ? null
        : settings.syncSetting.s3Setting.region,
    pathStyle: settings.syncSetting.s3Setting.pathStyle,
  );
}

class _S3Endpoint {
  const _S3Endpoint({required this.host, required this.port});

  final String host;
  final int? port;
}

_S3Endpoint _resolveEndpoint(String endpoint, int configuredPort) {
  final trimmed = endpoint.trim();
  if (trimmed.isEmpty) {
    throw Exception('S3 Endpoint 不能为空');
  }

  final raw = trimmed.startsWith('http://') || trimmed.startsWith('https://')
      ? trimmed
      : 'https://$trimmed';
  final uri = Uri.tryParse(raw);

  if (uri == null || uri.host.isEmpty) {
    throw Exception('S3 Endpoint 格式错误: $endpoint');
  }

  final port = configuredPort > 0
      ? configuredPort
      : (uri.hasPort ? uri.port : null);

  return _S3Endpoint(host: uri.host, port: port);
}
