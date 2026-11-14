import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/full_cloud_replace.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/video_library_store.dart';

Future<List<int>> identityFullReplaceCodec(List<int> bytes) async => bytes;

FullCloudLocalSnapshot emptyFullReplaceSnapshot({Map<String, dynamic>? comic}) {
  final video = VideoLibrarySnapshot().toJson();
  final portable = {'version': 1, 'entries': <String, dynamic>{}};
  return FullCloudLocalSnapshot(
    comic: comic ?? {'version': 'v1', 'favorites': []},
    settings: {'version': 'v1', 'schemaVersion': 'v2', 'syncTime': 1,
      'globalSetting': <String, dynamic>{}, 'pluginConfigs': [], 'pluginInfos': [],
      'blocks': <String, dynamic>{}},
    video: {'format': 'BreezeVideoLibrary', 'version': 1, 'snapshot': video,
      'sha256': sha256.convert(utf8.encode(jsonEncode(video))).toString(),
      'portable': portable, 'portableSha256': sha256.convert(utf8.encode(jsonEncode(portable))).toString()},
    appearance: AppearanceSyncManifest({}),
  );
}

class FullReplaceMemoryServer {
  final files = <String, List<int>>{};
  final writes = <String>[];
  bool Function(String path)? failPut, failDelete;
  void Function(String path)? beforePut, beforeDelete;
  bool truncateFailedPut = false;
  int ensureCalls = 0;
  String path(String name, {bool legacy = false}) => '${legacy ? SyncArchiveContext.legacyRoot : SyncArchiveContext.currentRoot}/$name';
  void comic(Map<String, dynamic> payload, {bool legacy = false, int stamp = 1}) {
    final bytes = utf8.encode(jsonEncode(payload));
    files[path('comic_$stamp.bin', legacy: legacy)] = bytes;
    files[path('comic.md5', legacy: legacy)] = utf8.encode(ComicSyncCore.calculateMd5(bytes));
  }
  Map<String, String> get saved => {for (final e in files.entries) e.key: base64Encode(e.value)};
  ScopedSyncArchiveAdapter adapters() => ScopedSyncArchiveAdapter(
    FullReplaceMemoryTransport(this, SyncArchiveContext.current), SyncArchiveContext.current,
    identity: 'full-replace-fixture',
    legacyReader: ScopedSyncArchiveAdapter(FullReplaceMemoryTransport(this, SyncArchiveContext.legacyReadOnly),
      SyncArchiveContext.legacyReadOnly, identity: 'full-replace-fixture'),
  );
  FullCloudReplaceService service(FullCloudLocalSnapshot Function() local, {ScopedSyncArchiveAdapter? adapter}) => FullCloudReplaceService(
    adapter: adapter ?? adapters(), captureLocal: () async => local(),
    comicCodec: const ComicSyncCodec(encode: identityFullReplaceCodec, decode: identityFullReplaceCodec),
    settingsCodec: const SettingsSyncCodec(encode: identityFullReplaceCodec, decode: identityFullReplaceCodec),
    videoCodec: const VideoLibrarySyncCodec(encode: identityFullReplaceCodec, decode: identityFullReplaceCodec),
  );
}

class FullReplaceMemoryTransport implements ComicSyncRemoteAdapter, FullCloudReplaceTransport {
  FullReplaceMemoryTransport(this.server, this.scope);
  final FullReplaceMemoryServer server;
  final SyncArchiveContext scope;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async { server.ensureCalls++; }
  @override
  Future<List<String>> listRemoteDataFiles() async => server.files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String path) async => List.of(server.files[path] ?? (throw StateError('404')));
  @override
  Future<String> downloadRemoteMd5() async => utf8.decode(server.files['${scope.root}/comic.md5'] ?? []);
  @override
  Future<void> uploadRemoteMd5(String value) => uploadRemoteFile('${scope.root}/comic.md5', utf8.encode(value));
  @override
  Future<void> uploadRemoteFile(String path, List<int> bytes, {String contentType = 'application/octet-stream'}) async {
    if (scope.readOnly) throw const LegacyArchiveReadOnly();
    server.beforePut?.call(path);
    server.writes.add('put:$path');
    if (server.failPut?.call(path) == true) {
      if (server.truncateFailedPut) server.files[path] = bytes.take(3).toList();
      throw StateError('Synthetic interrupted PUT');
    }
    server.files[path] = List.of(bytes);
  }
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    if (scope.readOnly) throw const LegacyArchiveReadOnly();
    await _delete(paths);
  }
  @override
  Future<void> deleteLegacyFilesForFullReplace(List<String> paths) async {
    for (final path in paths) { validateFullReplaceLegacyPath(scope, path); }
    await _delete(paths);
  }
  Future<void> _delete(List<String> paths) async {
    for (final path in paths) {
      server.beforeDelete?.call(path);
      server.writes.add('delete:$path');
      if (server.failDelete?.call(path) == true) throw StateError('Synthetic interrupted DELETE');
      server.files.remove(path);
    }
  }
}
