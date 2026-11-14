import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/src/rust/api/webdav.dart' as rust_webdav;

import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';

class WebDavSyncService
    implements
        ComicSyncRemoteAdapter,
        LegacyPluginPurgeTransport,
        FullCloudReplaceTransport {
  WebDavSyncService(
    this._settings, {
    this.archive = SyncArchiveContext.current,
  }) {
    if (!isConfigured(_settings)) {
      throw Exception('WebDAV 配置不完整');
    }
  }

  final GlobalSettingState _settings;
  final SyncArchiveContext archive;
  String get _root => archive.root;
  void _writable() {
    if (archive.readOnly) throw const LegacyArchiveReadOnly();
  }

  static bool isConfigured(GlobalSettingState settings) {
    return settings.syncSetting.webdavSetting.host.trim().isNotEmpty &&
        settings.syncSetting.webdavSetting.username.trim().isNotEmpty &&
        settings.syncSetting.webdavSetting.password.isNotEmpty;
  }

  @override
  Future<void> testConnection() {
    return rust_webdav.webdavTestConnection(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
    );
  }

  @override
  Future<void> ensureRemoteReady() {
    if (archive.readOnly) return Future<void>.value();
    return rust_webdav.webdavEnsureRemoteReady(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
    );
  }

  @override
  Future<String> downloadRemoteMd5() {
    return rust_webdav.webdavDownloadText(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
      remotePath: _remoteMd5Path,
    );
  }

  @override
  Future<void> uploadRemoteMd5(String value) {
    _writable();
    return rust_webdav.webdavUploadText(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
      remotePath: _remoteMd5Path,
      value: value,
    );
  }

  @override
  Future<List<String>> listRemoteDataFiles() {
    return rust_webdav.webdavListRemoteDataFiles(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
    );
  }

  @override
  Future<List<int>> downloadRemoteFile(String remotePath) {
    return rust_webdav.webdavDownloadFile(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
      remotePath: remotePath,
    );
  }

  @override
  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) {
    _writable();
    return rust_webdav.webdavUploadBytes(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
      remotePath: remotePath,
      data: data,
      contentType: contentType,
    );
  }

  /// Separate, explicit source-deletion capability. Ordinary upload/delete
  /// retain _writable(); only canonical managed legacy files can reach here.
  @override
  Future<void> rewriteLegacySnapshotForPluginPurge(
    String physicalPath,
    List<int> data,
  ) {
    final path = validateLegacyPluginPurgePath(archive, physicalPath);
    return rust_webdav.webdavUploadBytes(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
      remotePath: path,
      data: data,
      contentType: 'application/octet-stream',
    );
  }

  @override
  Future<void> deleteLegacyFilesForFullReplace(List<String> physicalPaths) {
    final paths = physicalPaths
        .map((path) => validateFullReplaceLegacyPath(archive, path))
        .toList();
    return rust_webdav.webdavDeleteRemoteFiles(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      remotePaths: paths,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
    );
  }

  @override
  Future<void> deleteRemoteFiles(List<String> remotePaths) {
    _writable();
    return rust_webdav.webdavDeleteRemoteFiles(
      host: _settings.syncSetting.webdavSetting.host,
      username: _settings.syncSetting.webdavSetting.username,
      password: _settings.syncSetting.webdavSetting.password,
      remotePaths: remotePaths,
      syncRootName: _root,
      legacyDataRootName: _root,
      legacySettingsRootName: _root,
    );
  }

  String get _remoteMd5Path => '/$_root/${ComicSyncCore.comicMd5FileName}';
}
