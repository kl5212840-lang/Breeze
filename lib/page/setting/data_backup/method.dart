import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:objectbox/objectbox.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show clearOfflineCloudConnectionMetadata, runExclusiveStorageOperation;
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/backup_security/private_backup_workspace.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';

import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/src/rust/api/data_backup.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/widgets/toast.dart';

export 'package:zephyr/service/offline_backup_merge.dart' show BackupImportMode;

dynamic _decodeBackupJson(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {
    throw const FormatException('Invalid backup data');
  }
}

class BackupCompatibilityException implements Exception {
  const BackupCompatibilityException();
  @override
  String toString() => t.dataBackup.unsupportedData;
}

class BackupRestoreIncomplete implements Exception {
  const BackupRestoreIncomplete();
  @override
  String toString() => t.dataBackup.restoreIncomplete;
}

const _cloudSyncAccountFile = 'cloud-sync-account.breezebackup';
const _cloudSyncAccountFormat = 'breeze-local-cloud-sync-account';

/// This data enters the import transaction only through authenticated files.
class _CloudSyncAccount {
  const _CloudSyncAccount(this.service, this.webdav, this.s3);

  final SyncServiceType service;
  final WebDavSettingState webdav;
  final S3SettingState s3;

  // Keep v1 fields stable if the app adds another connection preference.
  static Map<String, dynamic> _webdavFields(WebDavSettingState value) => {
    'host': value.host,
    'username': value.username,
    'password': value.password,
  };

  static Map<String, dynamic> _s3Fields(S3SettingState value) => {
    'endpoint': value.endpoint,
    'accessKey': value.accessKey,
    'secretKey': value.secretKey,
    'bucket': value.bucket,
    'region': value.region,
    'useSSL': value.useSSL,
    'port': value.port,
    'pathStyle': value.pathStyle,
  };

  static _CloudSyncAccount? capture(SyncSettingState state) {
    final webdav = state.webdavSetting;
    final s3 = state.s3Setting;
    return webdav == const WebDavSettingState() && s3 == const S3SettingState()
        ? null
        : _CloudSyncAccount(state.syncServiceType, webdav, s3);
  }

  Future<void> write(
    Directory directory,
    BackupProtectionSession session,
  ) async {
    final plaintext = utf8.encode(
      jsonEncode({
        'format': _cloudSyncAccountFormat,
        'version': 1,
        'service': service.name,
        'webdav': _webdavFields(webdav),
        's3': _s3Fields(s3),
      }),
    );
    try {
      await File(
        p.join(directory.path, _cloudSyncAccountFile),
      ).writeAsBytes(await session.encryptBytes(plaintext));
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  static Future<_CloudSyncAccount?> read(
    Directory directory,
    BackupProtectionSession session,
  ) async {
    final path = p.join(directory.path, _cloudSyncAccountFile);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const BackupCompatibilityException();
    }
    final file = File(path);
    if (await file.length() >
        BackupProtectionSession.maxBytesPayload + 1024 * 1024) {
      throw const BackupCompatibilityException();
    }
    final plaintext = await session.decryptBytes(await file.readAsBytes());
    try {
      final data = jsonDecode(utf8.decode(plaintext));
      if (data is! Map<String, dynamic> ||
          data['format'] != _cloudSyncAccountFormat ||
          data['version'] != 1 ||
          !data.keys.every(
            {'format', 'version', 'service', 'webdav', 's3'}.contains,
          )) {
        throw const BackupCompatibilityException();
      }
      Map<String, dynamic> readProvider(
        String key,
        Map<String, dynamic> schema,
      ) {
        final config = data[key];
        if (config is! Map<String, dynamic> ||
            config.length != schema.length ||
            schema.entries.any(
              (field) => switch (field.value) {
                String _ => config[field.key] is! String,
                bool _ => config[field.key] is! bool,
                int _ => config[field.key] is! int,
                _ => true,
              },
            )) {
          throw const BackupCompatibilityException();
        }
        return config;
      }

      final service = SyncServiceType.values.byName(data['service'] as String);
      final webdav = readProvider(
        'webdav',
        _webdavFields(const WebDavSettingState()),
      );
      final s3 = readProvider('s3', _s3Fields(const S3SettingState()));
      return _CloudSyncAccount(
        service,
        WebDavSettingState.fromJson(webdav),
        S3SettingState.fromJson(s3),
      );
    } catch (_) {
      // JSON parser/type errors can include the credential text.
      throw const BackupCompatibilityException();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  SyncSettingState restoreInto(SyncSettingState current) => current.copyWith(
    syncServiceType: service,
    webdavSetting: webdav,
    s3Setting: s3,
    autoSync: false,
    syncSettings: false,
    syncPlugins: false,
    legacyCompatibilityEnabled: false,
    settingsSyncTime: 0,
  );
}

Future<List<Map<String, dynamic>>> _readBackupVideoRows(
  Directory downloads,
) async {
  try {
    return await VideoLocalResources.readBackupRows(downloads);
  } catch (_) {
    throw const BackupCompatibilityException();
  }
}

const _backupArtistsFile = 'downloaded-video-artists.json';
const _backupArtistsFormat = 'breeze-downloaded-video-artists';
const _maxBackupArtistBytes = 4 * 1024 * 1024;

Future<Map<String, ({Uri watch, String title, String artist})>>
_readBackupArtists(Directory extract, List<Map<String, dynamic>> rows) async {
  final file = File(p.join(extract.path, _backupArtistsFile));
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return {};
  if (type != FileSystemEntityType.file ||
      await file.length() > _maxBackupArtistBytes) {
    throw const BackupCompatibilityException();
  }
  try {
    final data = _decodeBackupJson(await file.readAsString());
    if (data is! Map ||
        data['format'] != _backupArtistsFormat ||
        data['version'] != 1 ||
        data['artists'] is! Map) {
      throw const BackupCompatibilityException();
    }
    SyncPayloadCompatibility.keys(data, {'format', 'version', 'artists'});
    final verified = {
      for (final row in rows)
        if (row['available'] == true) row['resourceId']: row,
    };
    final result = <String, ({Uri watch, String title, String artist})>{};
    for (final entry in (data['artists'] as Map).entries) {
      final row = verified[entry.key];
      final artist = entry.value;
      if (row == null ||
          artist is! String ||
          artist.isEmpty ||
          artist.length > 120 ||
          artist.trim() != artist ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(artist)) {
        throw const BackupCompatibilityException();
      }
      final watch = Uri.parse(row['url'] as String);
      if (!VideoDownloadedDetails.isHanimeWatch(
        row['source'] as String,
        watch,
      )) {
        throw const BackupCompatibilityException();
      }
      result[entry.key as String] = (
        watch: watch,
        title: row['title'] as String,
        artist: artist,
      );
    }
    return result;
  } catch (_) {
    throw const BackupCompatibilityException();
  }
}

/// Offline failure injection; production always uses the normal download root.
class BackupImportHooks {
  const BackupImportHooks({
    this.downloadDirectory,
    this.rename,
    this.beforeCommit,
    this.appearanceImages,
    this.recoveryDirectory,
    this.checkpoint,
    this.settleReaderHistoryWrites,
  });
  final Directory? downloadDirectory;
  final Future<void> Function(Directory source, String target)? rename;
  final void Function()? beforeCommit;
  final LocalAppearanceImages? appearanceImages;
  final Directory? recoveryDirectory;
  final Future<void> Function(String phase)? checkpoint;
  final Future<void> Function()? settleReaderHistoryWrites;
}

void _validateBackupConfig(Map config) {
  try {
    SyncPayloadCompatibility.keys(config, {
      'format',
      'schemaVersion',
      'version',
      'buildNumber',
      'includeDownloads',
      'exportedAt',
    });
  } on SyncCompatibilityException {
    throw const BackupCompatibilityException();
  }
  if ((config.containsKey('format') && config['format'] != 'BreezeBackup') ||
      (config.containsKey('schemaVersion') && config['schemaVersion'] != 1)) {
    throw const BackupCompatibilityException();
  }
}

/// 备份包配置信息。
class BackupConfig {
  bool _prepared = false;
  _CloudSyncAccount? _cloudSyncAccount;
  final String version;
  final bool includeDownloads;

  /// 本次导入使用的临时根目录，包含 zip 缓存副本与解压目录。
  final String cacheDir;

  /// 解压目录路径。
  final String extractDir;

  /// 缓存目录中的 zip 副本路径。
  final String zipPath;
  final CacheWorkspaceLease? _workspace;

  bool get hasCloudSyncAccount => _cloudSyncAccount != null;

  void releaseWorkspace() {
    _cloudSyncAccount = null;
    _workspace?.release();
  }

  BackupConfig({
    required this.version,
    required this.includeDownloads,
    required this.cacheDir,
    required this.extractDir,
    required this.zipPath,
    this._workspace,
  });
}

const _portableBackupGlobalKeys = {
  'dynamicColor',
  'themeMode',
  'isAMOLED',
  'seedColor',
  'locale',
  'localeFollowsSystem',
  'welcomePageNum',
  'mainNavigationSlots',
  'maskedKeywords',
  'comicChoice',
  'disableBika',
  'backPressExitEnabled',
  'updateAccelerate',
  'retryDownloadUntilSuccess',
  'videoDownloadConcurrency',
  'downloadWifiOnly',
  'downloadCompletionNotice',
  'oldPageRollbackEnabled',
  'cloudFavoritePreferred',
  'autoFollowOnCollect',
  'leftHandModeEnabled',
  'clickCoverToStartReading',
  'searchHistory',
  'readSetting',
  'chineseConvertMode',
  'bookshelfSetting',
  'eInkSetting',
};

Map<String, dynamic> _portableBackupGlobal(Map<String, dynamic> value) {
  final portable = <String, dynamic>{
    for (final key in _portableBackupGlobalKeys)
      if (value.containsKey(key)) key: value[key],
  };
  final eink = portable['eInkSetting'];
  if (eink is Map) {
    portable['eInkSetting'] = Map<String, dynamic>.from(eink)
      ..remove('detectionHandled');
  }
  return portable;
}

void _portablePluginDiagnostics(List rows) {
  for (final row in rows) {
    (row as Map)['debug'] = false;
    row['debugUrl'] = null;
    row['lastLoadError'] = null;
  }
}

Map<String, dynamic> _portableBackupDatabase(Map<String, dynamic> database) {
  for (final rows in database.values) {
    for (final row in rows as List) {
      (row as Map).remove('id');
    }
  }
  // Task/runtime identities never represent portable downloaded files.
  database['downloadTask'] = <dynamic>[];
  for (final row in database['userSetting'] as List) {
    final user = row as Map;
    Map<String, dynamic> stored(String key) {
      final raw = user[key];
      if (raw == null || raw == '') return {};
      final value = _decodeBackupJson(raw as String);
      if (value is! Map<String, dynamic>) {
        throw const BackupCompatibilityException();
      }
      return value;
    }

    final global = _portableBackupGlobal(stored('globalSettingData'));
    user['globalSettingData'] = jsonEncode(global);
    // Older serializers require these typed companions. Both representations
    // must be scoped; clearing only the raw field still leaks its duplicate.
    user['globalSetting'] = global;
    user['bikaSetting'] = stored('bikaSettingData');
    user['jmSetting'] = stored('jmSettingData');
  }
  for (final row in database['unifiedComicDownload'] as List) {
    (row as Map)['storageRoot'] = '';
  }
  _portablePluginDiagnostics(database['pluginInfo'] as List);
  for (final row in (database['pluginConfig'] as List).whereType<Map>()) {
    if (row['name'] case final String name) {
      if (row['config'] case final String config) {
        row['config'] = stripCopyDeviceRouteSettings(name, config);
      }
    }
  }
  return database;
}

/// 导出完整数据备份到 [zipPath]。
///
/// 当 [includeDownloads] 为 true 时，会一并打包 `getDownloadPath()` 下的漫画文件。
/// [protectionSession] 仅用于受保护文件的临时 ZIP，由调用方再加密整个 ZIP。
Future<String> exportBreezeBackup({
  required String zipPath,
  required bool includeDownloads,
  BackupProtectionSession? protectionSession,
}) => CacheWorkspaceGuard.withWorkspace(
  () => runExclusiveStorageOperation(() {
    Future<String> export() => _exportBreezeBackup(
      zipPath: zipPath,
      includeDownloads: includeDownloads,
      protectionSession: protectionSession,
    );
    return includeDownloads
        ? DownloadQueueManager.instance.withStableDownloadTree(export)
        : export();
  }),
);

Future<String> _exportBreezeBackup({
  required String zipPath,
  required bool includeDownloads,
  required BackupProtectionSession? protectionSession,
}) async {
  if (includeDownloads) await VideoLocalResources.requirePortableBackup();
  final cachePath = await getCachePath();
  final tempDir = await Directory(
    p.join(
      cachePath,
      'breeze_backup',
      DateTime.now().millisecondsSinceEpoch.toString(),
    ),
  ).create(recursive: true);

  try {
    // 1. 写入 config.json
    final packageInfo = await PackageInfo.fromPlatform();
    final config = <String, dynamic>{
      'format': 'BreezeBackup',
      'schemaVersion': 1,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'includeDownloads': includeDownloads,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    await File(
      p.join(tempDir.path, 'config.json'),
    ).writeAsString(jsonEncode(config));

    // 2. 写入 objectbox.json
    final database = _portableBackupDatabase(
      await LocalImportRecovery.captureDatabaseSnapshot(),
    );
    if (protectionSession != null) {
      final sync = objectbox.userSettingBox.get(1)?.globalSetting.syncSetting;
      if (sync != null) {
        await _CloudSyncAccount.capture(
          sync,
        )?.write(tempDir, protectionSession);
      }
    }
    if (!includeDownloads) {
      for (final key in [
        'bikaComicDownload',
        'jmDownload',
        'unifiedComicDownload',
      ]) {
        database[key] = [];
      }
      for (final key in ['comicFolder', 'comicLink']) {
        database[key] = (database[key] as List)
            .where((row) => row['typeData'] != ComicFolderType.download.name)
            .toList();
      }
    }
    await File(
      p.join(tempDir.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(database));

    // read() waits for queued library mutations before taking the snapshot.
    final library = await VideoLibraryStore.shared.read();
    final settingsMetadata = await captureOfflineSettingsPayload();
    _portablePluginDiagnostics(settingsMetadata['pluginInfos'] as List);
    final pluginMetadata = (settingsMetadata['blocks'] as Map)['plugins'];
    if (pluginMetadata != null) {
      _portablePluginDiagnostics(
        (pluginMetadata['data'] as Map)['pluginInfos'] as List,
      );
    }
    await File(
      p.join(tempDir.path, 'sync-settings.json'),
    ).writeAsString(jsonEncode(settingsMetadata));
    final preferences = await PortablePreferences.capture();
    await File(p.join(tempDir.path, 'portable-data.json')).writeAsString(
      jsonEncode({
        'format': 'breeze-portable-data',
        'version': 1,
        'preferences': preferences.toJson(),
        'videoLibrary': library.toJson(),
      }),
    );
    final chapters = await ComicChapterReadingProgress.instance.capture();
    await File(
      p.join(tempDir.path, ChapterProgressArchive.filename),
    ).writeAsBytes(chapters.encode());

    // Local artwork travels in a local backup, never in cloud preferences.
    await LocalAppearanceImages.instance.exportBackup(tempDir);
    if (includeDownloads) {
      final rows = await _readBackupVideoRows(
        Directory(await getDownloadPath()),
      );
      final artists = await VideoDownloadedDetails.captureBackupArtists(
        rows.where((row) => row['available'] == true).toList(),
      );
      if (artists.isNotEmpty) {
        final bytes = utf8.encode(
          jsonEncode({
            'format': _backupArtistsFormat,
            'version': 1,
            'artists': artists,
          }),
        );
        if (bytes.length > _maxBackupArtistBytes) {
          throw const BackupCompatibilityException();
        }
        await File(
          p.join(tempDir.path, _backupArtistsFile),
        ).writeAsBytes(bytes);
      }
    }

    // 3. 调用 Rust 流式打包
    await createDataBackupZip(
      zipPath: zipPath,
      dataDir: tempDir.path,
      downloadDir: includeDownloads ? await getDownloadPath() : null,
    );

    return zipPath;
  } finally {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

/// 读取备份包中的 config.json，并把 zip 复制到应用缓存目录后返回配置信息。
///
/// 先把源 zip 复制到私有缓存，再读取 config.json，避免在确认导入前因权限
/// 回收或源文件变动导致第二次读取失败。本函数不会解压整个 zip。
/// 调用方在确认导入后应使用 [applyBreezeBackupImport]；若取消导入，
/// 请自行删除 [BackupConfig.cacheDir]。
///
/// 当 [skipCopy] 为 true 时，[sourceZipPath] 应已是私有缓存中的路径，
/// 不再重复复制（用于 Android 原生选择器直接拷贝到目标位置的场景）。
Future<BackupConfig> readBackupConfig(
  String sourceZipPath, {
  bool skipCopy = false,
}) async {
  final lease = CacheWorkspaceGuard.acquire();
  try {
    return await _readBackupConfig(
      sourceZipPath,
      skipCopy: skipCopy,
      lease: lease,
    );
  } catch (_) {
    lease.release();
    rethrow;
  }
}

/// Authenticates the entire protected archive before unlocking its local-only
/// connection entry directly into memory.
Future<BackupConfig> readProtectedBackupConfig(
  String encryptedPath,
  BackupProtectionSession session,
) async {
  final lease = CacheWorkspaceGuard.acquire();
  Directory? workspace;
  try {
    workspace = await createPrivateBackupWorkspace();
    final zip = File(p.join(workspace.path, 'zip', 'backup.zip'));
    await zip.parent.create();
    await session.decryptFile(encryptedPath, zip.path);
    final config = await _readBackupConfig(
      zip.path,
      skipCopy: true,
      lease: lease,
    );
    await prepareBreezeBackupImport(config);
    config._cloudSyncAccount = await _CloudSyncAccount.read(
      Directory(config.extractDir),
      session,
    );
    return config;
  } catch (_) {
    try {
      await workspace?.delete(recursive: true);
    } catch (_) {}
    lease.release();
    rethrow;
  }
}

Future<BackupConfig> _readBackupConfig(
  String sourceZipPath, {
  required bool skipCopy,
  required CacheWorkspaceLease lease,
}) async {
  final cachePath = await getCachePath();
  // Android 原生选择器已经直接拷贝到私有缓存，复用该目录避免重复拷贝和路径不一致
  final cacheDir = skipCopy
      ? Directory(p.dirname(p.dirname(sourceZipPath)))
      : Directory(
          p.join(
            cachePath,
            'breeze_backup_import',
            DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        );
  final extractDir = Directory(p.join(cacheDir.path, 'extract'));
  final cacheZipFile = File(p.join(cacheDir.path, 'zip', 'backup.zip'));

  try {
    await extractDir.create(recursive: true);
    await cacheZipFile.parent.create(recursive: true);
    if (!skipCopy) {
      await File(sourceZipPath).copy(cacheZipFile.path);
    }

    final configJson = await readDataBackupConfig(zipPath: cacheZipFile.path);
    final config = _decodeBackupJson(configJson) as Map<String, dynamic>;
    _validateBackupConfig(config);
    return BackupConfig(
      version: config['version'] as String? ?? 'Unknown',
      includeDownloads: config['includeDownloads'] as bool? ?? false,
      cacheDir: cacheDir.path,
      extractDir: extractDir.path,
      zipPath: cacheZipFile.path,
      workspace: lease,
    );
  } catch (e) {
    showErrorToast('${t.dataBackup.importFailed}：$e');
    // 失败时清理全部临时目录，避免残留
    try {
      await cacheDir.delete(recursive: true);
    } catch (_) {}
    rethrow;
  }
}

const _filePickerChannel = MethodChannel('com.zephyr.breeze/file_picker');

/// Android 原生选择 zip 文件并直接拷贝到应用缓存目录。
///
/// 返回缓存中的 zip 路径；用户取消时返回 null。该路径可直接交给
/// [readBackupConfig] 且应设置 [skipCopy] 为 true，避免重复拷贝。
Future<String?> pickBackupZipAndroid() async {
  final cachePath = await getCachePath();
  final cacheDir = Directory(
    p.join(
      cachePath,
      'breeze_backup_import',
      DateTime.now().millisecondsSinceEpoch.toString(),
    ),
  );
  final cacheZipFile = File(p.join(cacheDir.path, 'zip', 'backup.zip'));
  await cacheZipFile.parent.create(recursive: true);

  logger.i('调用 Android 原生选择器，目标路径：${cacheZipFile.path}');
  final result = await _filePickerChannel.invokeMethod<String>(
    'pickBackupZip',
    {'destPath': cacheZipFile.path},
  );
  logger.i('Android 原生选择器返回：$result');
  if (result == null) {
    // 用户取消选择，清理已创建的临时目录
    try {
      await cacheDir.delete(recursive: true);
    } catch (_) {}
  }
  return result;
}

/// 将备份数据解压并应用到当前应用。
///
/// [config] 应来自 [readBackupConfig] 的返回值。执行完成后会删除
/// [BackupConfig.cacheDir] 下的缓存副本与解压目录。
Future<void> prepareBreezeBackupImport(BackupConfig config) async {
  if (config._prepared) return;
  await extractDataBackupZip(
    zipPath: config.zipPath,
    extractDir: config.extractDir,
  );
  config._prepared = true;
}

Future<void> applyBreezeBackupImport(
  BackupConfig config, {
  BackupImportMode mode = BackupImportMode.merge,
  BackupImportOptions? options,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  BackupImportHooks? hooks,
}) async {
  final lease = CacheWorkspaceGuard.acquire();
  final cacheDirectory = Directory(config.cacheDir);
  final cloudSyncAccount = options?.importCloudSyncAccount == true
      ? config._cloudSyncAccount
      : null;
  config._cloudSyncAccount = null;
  try {
    // 1. 解压完整备份包
    await prepareBreezeBackupImport(config);

    // 解压完成后即可删除缓存的 zip 副本，减少磁盘占用
    try {
      await File(config.zipPath).delete();
    } catch (_) {}

    await _runBackupImport(
      config.extractDir,
      restoreDownloadFiles: true,
      mode: mode,
      options: options,
      hooks: hooks,
      cloudSyncAccount: cloudSyncAccount,
      globalSettingCubit: globalSettingCubit,
      comicFollowCubit: comicFollowCubit,
    );
  } finally {
    try {
      await cacheDirectory.delete(recursive: true);
    } catch (_) {}
    config.releaseWorkspace();
    lease.release();
  }
}

/// Validate extracted metadata before replacing any local data. Exposed so the
/// same import path can be exercised with temporary stores without native ZIP.
Future<bool> importExtractedBreezeData(
  String extractDir, {
  bool restoreDownloadFiles = false,
  BackupImportHooks? hooks,
  BackupImportMode mode = BackupImportMode.merge,
  BackupImportOptions? options,
}) => _runBackupImport(
  extractDir,
  restoreDownloadFiles: restoreDownloadFiles,
  hooks: hooks,
  mode: mode,
  options: options,
);

Future<bool> _runBackupImport(
  String extractDir, {
  required bool restoreDownloadFiles,
  required BackupImportHooks? hooks,
  required BackupImportMode mode,
  required BackupImportOptions? options,
  _CloudSyncAccount? cloudSyncAccount,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
}) => CacheWorkspaceGuard.withWorkspace(
  () => runExclusiveStorageOperation(() async {
    final incomingConfig = _decodeBackupJson(
      await File(p.join(extractDir, 'config.json')).readAsString(),
    );
    final replacesFiles =
        restoreDownloadFiles &&
        incomingConfig is Map &&
        incomingConfig['includeDownloads'] == true;

    Future<bool> apply() async {
      OfflineBackupMergePlan? plan;
      final treeLease = replacesFiles
          ? VideoLocalResources.acquireTreeMutationLease()
          : null;
      try {
        if (mode == BackupImportMode.merge) {
          plan = await prepareOfflineBackupMerge(
            Directory(extractDir),
            stagingParent: Directory(extractDir).parent,
            restoreDownloadFiles: restoreDownloadFiles,
            appearanceImages: hooks?.appearanceImages,
            downloadDirectory: hooks?.downloadDirectory,
            options: options,
          );
        }
        Future<bool> importData() => _importExtractedBreezeData(
          plan?.directory.path ?? extractDir,
          restoreDownloadFiles: restoreDownloadFiles,
          hooks: hooks,
          mergePlan: plan,
          originalExtract: plan == null ? null : Directory(extractDir),
          options: options,
          cloudSyncAccount: cloudSyncAccount,
          globalSettingCubit: globalSettingCubit,
          comicFollowCubit: comicFollowCubit,
        );
        return mode == BackupImportMode.restore
            ? await ReaderHistoryService.instance
                  .withWritesPausedForReplacement(importData)
            : await importData();
      } finally {
        try {
          await plan?.dispose();
        } finally {
          treeLease?.release();
        }
      }
    }

    return replacesFiles
        ? DownloadQueueManager.instance.withStableDownloadTree(apply)
        : apply();
  }),
);

Future<bool> _importExtractedBreezeData(
  String extractDir, {
  required bool restoreDownloadFiles,
  BackupImportHooks? hooks,
  OfflineBackupMergePlan? mergePlan,
  Directory? originalExtract,
  BackupImportOptions? options,
  _CloudSyncAccount? cloudSyncAccount,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
}) async {
  try {
    await readOfflineBackupPreview(Directory(extractDir));
  } on SyncCompatibilityException {
    throw const BackupCompatibilityException();
  }
  final config = _decodeBackupJson(
    await File(p.join(extractDir, 'config.json')).readAsString(),
  );
  if (config is! Map<String, dynamic> ||
      (config['includeDownloads'] != null &&
          config['includeDownloads'] is! bool)) {
    throw const FormatException('Invalid backup configuration');
  }
  _validateBackupConfig(config);
  final includeDownloads = config['includeDownloads'] as bool? ?? false;
  final incomingChapters = await readBackupChapterProgress(
    Directory(extractDir),
  );
  final raw = _decodeBackupJson(
    await File(p.join(extractDir, 'objectbox.json')).readAsString(),
  );
  const entityNames = {
    'bikaComicHistory',
    'bikaComicDownload',
    'jmFavorite',
    'jmHistory',
    'jmDownload',
    'unifiedComicFavorite',
    'unifiedComicHistory',
    'comicFollow',
    'unifiedComicDownload',
    'userSetting',
    'downloadTask',
    'pluginConfig',
    'pluginInfo',
    'comicFolder',
    'comicLink',
    'comicReadPreference',
  };
  if (raw is! Map<String, dynamic> ||
      !raw.keys.any(entityNames.contains) ||
      raw.entries.any((e) => entityNames.contains(e.key) && e.value is! List)) {
    throw const FormatException('Invalid database backup');
  }
  if (raw.keys.any((key) => !entityNames.contains(key))) {
    throw const BackupCompatibilityException();
  }
  PortablePreferencesSnapshot? incomingPreferences;
  VideoLibrarySnapshot? incomingLibrary;
  final portableFile = File(p.join(extractDir, 'portable-data.json'));
  if (await portableFile.exists()) {
    final portable = _decodeBackupJson(await portableFile.readAsString());
    if (portable is! Map<String, dynamic> ||
        portable['format'] != 'breeze-portable-data' ||
        portable['version'] != 1 ||
        portable['videoLibrary'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid portable backup');
    }
    try {
      SyncPayloadCompatibility.keys(portable, {
        'format',
        'version',
        'preferences',
        'videoLibrary',
      });
    } on SyncCompatibilityException {
      throw const BackupCompatibilityException();
    }
    incomingPreferences = PortablePreferencesSnapshot.fromJson(
      portable['preferences'],
    );
    incomingLibrary = VideoLibrarySnapshot.fromJson(
      portable['videoLibrary'] as Map<String, dynamic>,
    );
  }
  final deviceId = await ensureSyncDeviceId();
  Map<String, dynamic> currentImportCategories() => {
    'pluginInfo': objectbox.pluginInfoBox
        .getAll()
        .map((row) => row.toJson())
        .toList(),
    'pluginConfig': objectbox.pluginConfigBox
        .getAll()
        .map((row) => row.toJson())
        .toList(),
    'userSetting': [
      if (objectbox.userSettingBox.get(1) case final UserSetting user)
        user.toJson(),
    ],
  };
  if (options != null) {
    options.preserveUnselectedDatabase(raw, currentImportCategories());
    if (incomingPreferences != null && mergePlan == null) {
      incomingPreferences = options.selectPortable(
        incomingPreferences,
        await PortablePreferences.capture(persist: false),
        merge: false,
      );
    }
  }
  // Keep the full restore's data ownership even if its executable is skipped.
  // Clearing a prior local data-removal marker must not depend on installing a
  // compatible script, nor may the script filter discard restored account data.
  final incomingPluginDataSources = <String>{
    if (mergePlan == null)
      for (final row in raw['pluginInfo'] as List? ?? const [])
        if (row is Map && row['isDeleted'] != true && row['uuid'] is String)
          (row['uuid'] as String).trim(),
  }..removeWhere((value) => value.isEmpty);
  final skippedPluginSources = <String>{
    ...?mergePlan?.skippedPluginSources,
    for (final row in raw['pluginInfo'] as List? ?? const [])
      if (row is Map &&
          PluginHostCompatibility.unsupportedPluginInfo(row) != null &&
          row['uuid'] is String)
        row['uuid'] as String,
  };
  raw['pluginInfo'] = PluginHostCompatibility.projectRestoredPluginInfos(
    raw['pluginInfo'] as List? ?? const [],
    objectbox.pluginInfoBox.getAll().map((row) => row.toJson()).toList(),
  );
  // Validate every entity and database constraint before touching preferences.
  // Throwing the private sentinel deliberately rolls the trial transaction back.
  try {
    objectbox.store.runInTransaction(TxMode.write, () {
      _clearObjectBoxData(
        preserveDownloads: !includeDownloads,
        preserveLocalTasks: mergePlan != null,
      );
      _restoreObjectBoxData(raw, deviceId, includeDownloads: includeDownloads);
      if (raw.isNotEmpty) throw const _BackupValidationComplete();
    });
  } on _BackupValidationComplete {
    // All rows parsed and were accepted; the transaction was rolled back.
  }
  LocalAppearanceRestorePlan? appearance;
  try {
    appearance = await prepareSelectedBackupAppearanceRestore(
      Directory(extractDir),
      hooks?.appearanceImages ?? LocalAppearanceImages.instance,
      options,
    );
  } catch (_) {
    throw const BackupCompatibilityException();
  }
  final incomingDownloads = Directory(p.join(extractDir, 'downloads'));
  final incomingVideoRows = includeDownloads
      ? await _readBackupVideoRows(incomingDownloads)
      : const <Map<String, dynamic>>[];
  final incomingArtists = includeDownloads && restoreDownloadFiles
      ? await _readBackupArtists(
          originalExtract ?? Directory(extractDir),
          originalExtract == null
              ? incomingVideoRows
              : await _readBackupVideoRows(
                  Directory(p.join(originalExtract.path, 'downloads')),
                ),
        )
      : const <String, ({Uri watch, String title, String artist})>{};
  final restoredVideoIds = {
    for (final row in incomingVideoRows)
      if (row['available'] == true) row['resourceId'],
  };
  if (includeDownloads && restoreDownloadFiles) {
    VideoLocalResources.requireNoReadLeases();
  }
  final swap = includeDownloads && restoreDownloadFiles
      ? await _BackupDownloadSwap.prepare(
          Directory(extractDir),
          hooks?.downloadDirectory ?? Directory(await getDownloadPath()),
          hasRecords: [
            'bikaComicDownload',
            'jmDownload',
            'unifiedComicDownload',
          ].any((key) => (raw[key] as List?)?.isNotEmpty == true),
          rename: hooks?.rename,
          checkpoint: hooks?.checkpoint,
        )
      : null;
  final recovery = await LocalImportRecovery.begin(
    recoveryDirectory: hooks?.recoveryDirectory,
    downloads:
        swap?.target ??
        hooks?.downloadDirectory ??
        Directory(p.join(await getFilePath(), 'downloads')),
    images: hooks?.appearanceImages ?? LocalAppearanceImages.instance,
  );
  var committed = false;
  var databaseCommitted = false;
  var rolledBack = false;
  final portableKeys = <String>{};
  try {
    if (swap != null) {
      await recovery.beforeDownloadSwap(
        swap.staging,
        hadTarget: await swap.target.exists(),
      );
    }
    if (appearance != null) {
      await recovery.beforeImages(appearance.recoveryBasenames);
    }
    await hooks?.checkpoint?.call('prepared');
    // This path is the explicitly confirmed full restore. Ordinary merge
    // imports never clear device installation/data choices.
    final restoredSources = <String>{
      ...incomingPluginDataSources,
      for (final value in raw['pluginInfo'] as List? ?? const [])
        if (value is Map &&
            value['isDeleted'] != true &&
            value['uuid'] is String)
          (value['uuid'] as String).trim(),
      for (final table in [
        'unifiedComicFavorite',
        'unifiedComicHistory',
        'comicFollow',
        'comicReadPreference',
      ])
        for (final value in raw[table] as List? ?? const [])
          if (value is Map && value['source'] is String)
            (value['source'] as String).trim(),
      if (incomingLibrary != null)
        for (final value in incomingLibrary.favorites.values)
          if (value.data['source'] is String) value.data['source'] as String,
    }..removeWhere((value) => value.isEmpty);
    if (options?.importPlugins != false) {
      await LocalPluginInstallationState.instance.clearForExplicitRestore(
        restoredSources,
        beforeWrite: recovery.beforePreferences,
      );
    }
    if (swap != null) VideoLocalResources.requireNoReadLeases();
    await swap?.activate();
    if (swap != null) {
      await VideoDownloadedDetails.restoreBackupArtists(
        {
          for (final entry in incomingArtists.entries)
            if (restoredVideoIds.contains(entry.key)) entry.key: entry.value,
        },
        merge: mergePlan != null,
        beforeWrite: recovery.beforePreferences,
      );
    }
    await appearance?.activate(
      beforePersist: (mapping) async {
        final prefs = await SharedPreferences.getInstance();
        await recovery.beforePreferences(
          {LocalAppearanceImages.preferencesKey: mapping},
          beforeValues: {
            LocalAppearanceImages.preferencesKey: prefs.getString(
              LocalAppearanceImages.preferencesKey,
            ),
          },
        );
      },
    );
    await hooks?.checkpoint?.call('images-applied');
    await mergePlan?.applySettingsPreferences(
      recovery.beforePreferences,
      persistMetadata: cloudSyncAccount == null,
    );
    if (incomingPreferences != null) {
      await PortablePreferences.restore(
        incomingPreferences,
        replace: mergePlan == null,
        localAtPreparation: mergePlan?.localPortableAtPreparation,
        beforeWrite: (updates) async {
          final prefs = await SharedPreferences.getInstance();
          await recovery.beforePreferences(
            updates,
            beforeValues: {for (final key in updates.keys) key: prefs.get(key)},
          );
          portableKeys.addAll(updates.keys);
          await hooks?.checkpoint?.call('preferences-planned');
        },
        shouldWriteKey: options == null
            ? null
            : (key) => options.includesPortable({
                'key': key,
                'kind': PortablePreferences.kind(key),
              }),
      );
      await hooks?.checkpoint?.call('preferences-applied');
      final library = incomingLibrary!;
      await VideoLibraryStore.shared.updateSnapshot(
        (current) => mergePlan == null ? library : current.merged(library),
        beforeWrite: (before, after) => recovery.beforePreferences(
          {VideoLibraryStore.prefsKey: after},
          beforeValues: {VideoLibraryStore.prefsKey: before},
        ),
      );
      await hooks?.checkpoint?.call('library-applied');
    }
    if (cloudSyncAccount != null) {
      await clearOfflineCloudConnectionMetadata(recovery.beforePreferences);
    }
    if (mergePlan == null) {
      // Let the reader finish writes already captured before this explicit
      // replacement. If the transaction rolls back, those writes still stand.
      await (hooks?.settleReaderHistoryWrites?.call() ??
          ReaderHistoryService.instance.settlePendingWrites());
    }
    if (incomingChapters != null) {
      await ComicChapterReadingProgress.instance.restore(
        incomingChapters,
        replace: mergePlan == null,
        deletedWorks: {
          for (final history
              in (raw['unifiedComicHistory'] as List? ?? const [])
                  .whereType<Map>()
                  .map(
                    (row) => UnifiedComicHistory.fromJson(
                      _withDefaultId(Map<String, dynamic>.from(row)),
                    ),
                  ))
            if (history.deleted)
              (history.source, history.comicId):
                  history.updatedAt.millisecondsSinceEpoch,
        },
        beforeWrite: recovery.beforePreferences,
      );
    }
    final previousCopyConfig = options?.importPlugins == false
        ? null
        : jsonEncode(readHostPluginConfiguration(copyPluginConfigSource));
    // Parsing and insertion happen in one transaction: malformed records or
    // database errors roll back both the clear and all prior writes.
    objectbox.store.runInTransaction(TxMode.write, () {
      if (options != null || skippedPluginSources.isNotEmpty) {
        final latest = currentImportCategories();
        options?.preserveUnselectedDatabase(raw, latest);
        if (mergePlan != null) options?.mergeLegacyAccounts(raw, latest);
        if (options?.importPlugins != false &&
            skippedPluginSources.isNotEmpty) {
          final current = {
            for (final row in latest['pluginInfo'] as List)
              (row as Map)['uuid']: row,
          };
          raw['pluginInfo'] = [
            for (final row in raw['pluginInfo'] as List? ?? const [])
              if (!skippedPluginSources.contains((row as Map)['uuid'])) row,
            for (final source in skippedPluginSources)
              if (current[source] != null)
                {...Map<String, dynamic>.from(current[source] as Map), 'id': 0},
          ];
        }
      }
      if (options?.importPlugins != false) {
        final current = {
          for (final row in objectbox.pluginConfigBox.getAll())
            row.name.trim(): row.config,
        };
        for (final row
            in (raw['pluginConfig'] as List? ?? const []).whereType<Map>()) {
          if (row['name'] case final String name) {
            if (row['config'] case final String config) {
              row['config'] = preserveCopyDeviceRouteSettings(
                name,
                current[name.trim()],
                config,
              );
            }
          }
        }
      }
      _clearObjectBoxData(
        preserveDownloads: !includeDownloads,
        preserveLocalTasks: mergePlan != null,
        preserveComicRecords: mergePlan != null,
      );
      _restoreObjectBoxData(
        raw,
        deviceId,
        includeDownloads: includeDownloads,
        restoreComicRecords: mergePlan == null,
      );
      if (cloudSyncAccount != null) {
        final user = objectbox.userSettingBox.get(1);
        if (user == null) throw const BackupCompatibilityException();
        final state = user.globalSetting;
        user.globalSetting = state.copyWith(
          syncSetting: cloudSyncAccount.restoreInto(state.syncSetting),
        );
        objectbox.userSettingBox.put(user);
      }
      mergePlan?.mergeCurrentComicRecords();
      hooks?.beforeCommit?.call();
      recovery.markDatabaseCommitted();
    });
    databaseCommitted = true;
    if (comicFollowCubit != null && !comicFollowCubit.isClosed) {
      await comicFollowCubit.loadFromDatabase();
    }
    if (previousCopyConfig != null) {
      notifyCopyEndpointAfterExternalRestore(previousCopyConfig);
    }
    if (cloudSyncAccount != null) {
      globalSettingCubit?.refreshAfterBackupImport();
    }
    await hooks?.checkpoint?.call('database-committed');
    await recovery.markCommitted();
    committed = true;
    await hooks?.checkpoint?.call('committed');
    if (swap != null) VideoLocalResources.invalidate();
  } catch (_) {
    if (committed || databaseCommitted || recovery.hasDatabaseCommit) {
      // The database transaction is the commit point. Preserve its matching
      // files/preferences and durable proof for cold completion, never apply a
      // partial old-state compensation after that point.
      await appearance?.releaseForRecovery();
      throw const BackupRestoreIncomplete();
    }
    var compensationFailed = false;
    try {
      await appearance?.rollback();
    } catch (_) {
      compensationFailed = true;
    }
    try {
      await swap?.rollback();
    } catch (_) {
      compensationFailed = true;
    }
    try {
      if (databaseCommitted) await recovery.restoreDatabase();
      await recovery.restorePreferences(onlyOwnedValues: true);
      if (portableKeys.isNotEmpty) {
        await PortablePreferences.notifyRestored(keys: portableKeys);
      }
      await LocalPluginInstallationState.instance.reload();
      if (!compensationFailed) {
        await recovery.markRolledBack();
        rolledBack = true;
      }
    } catch (_) {
      compensationFailed = true;
    }
    if (swap != null || appearance != null || compensationFailed) {
      throw const BackupRestoreIncomplete();
    }
    rethrow;
  } finally {
    if (committed || rolledBack) {
      // Do not release retained originals while compensation is incomplete.
      // A cold start must still have every checkpoint resource available.
      try {
        await swap?.finish(committed: committed);
        await appearance?.finish(committed: committed);
        await recovery.finish();
      } catch (_) {
        throw const BackupRestoreIncomplete();
      }
    }
  }
  // Only reached after the backup and its recovery journal have committed.
  // A cancelled or failed import never enters folder artwork cleanup.
  await FolderCoverService.reconcileDeleted(images: hooks?.appearanceImages);
  return includeDownloads;
}

class _BackupDownloadSwap {
  _BackupDownloadSwap(
    this.target,
    this.staging,
    this.incoming,
    this.previous,
    this.rename,
    this.checkpoint,
  );
  final Directory target, staging, incoming, previous;
  final Future<void> Function(Directory, String) rename;
  final Future<void> Function(String)? checkpoint;
  bool _savedPrevious = false, _installed = false, _rollbackFailed = false;

  static Future<void> _plainTree(Directory root) async {
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const BackupRestoreIncomplete();
    }
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.directory &&
          type != FileSystemEntityType.file) {
        throw const BackupRestoreIncomplete();
      }
    }
  }

  static Future<_BackupDownloadSwap> prepare(
    Directory extract,
    Directory requestedTarget, {
    required bool hasRecords,
    Future<void> Function(Directory, String)? rename,
    Future<void> Function(String)? checkpoint,
  }) async {
    await _plainTree(extract);
    final extractPath = await extract.resolveSymbolicLinks();
    final targetType = await FileSystemEntity.type(
      requestedTarget.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.directory &&
        targetType != FileSystemEntityType.notFound) {
      throw const BackupRestoreIncomplete();
    }
    final parent = requestedTarget.absolute.parent;
    if (await FileSystemEntity.type(parent.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const BackupRestoreIncomplete();
    }
    final targetPath = p.join(
      await parent.resolveSymbolicLinks(),
      p.basename(requestedTarget.path),
    );
    if (p.equals(extractPath, targetPath) ||
        p.isWithin(extractPath, targetPath) ||
        p.isWithin(targetPath, extractPath)) {
      throw const BackupRestoreIncomplete();
    }
    final target = Directory(targetPath);
    if (targetType == FileSystemEntityType.directory) await _plainTree(target);
    final source = Directory(p.join(extractPath, 'downloads'));
    final sourceType = await FileSystemEntity.type(
      source.path,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.notFound &&
        sourceType != FileSystemEntityType.directory) {
      throw const BackupRestoreIncomplete();
    }
    if (sourceType == FileSystemEntityType.notFound && hasRecords) {
      throw const BackupRestoreIncomplete();
    }
    final staging = await target.parent.createTemp('.breeze-download-restore-');
    try {
      await _plainTree(staging);
      final incoming = Directory(p.join(staging.path, 'incoming'));
      if (sourceType == FileSystemEntityType.directory) {
        await _moveDirectory(source, incoming);
      } else {
        await incoming.create();
      }
      await _plainTree(incoming);
      return _BackupDownloadSwap(
        target,
        staging,
        incoming,
        Directory(p.join(staging.path, 'previous')),
        rename ??
            (source, path) async {
              await source.rename(path);
            },
        checkpoint,
      );
    } catch (_) {
      try {
        await staging.delete(recursive: true);
      } catch (_) {}
      throw const BackupRestoreIncomplete();
    }
  }

  Future<void> activate() async {
    try {
      if (await target.exists()) {
        await rename(target, previous.path);
        _savedPrevious = true;
        await checkpoint?.call('download-saved');
      }
      await rename(incoming, target.path);
      _installed = true;
      await checkpoint?.call('download-installed');
    } catch (_) {
      throw const BackupRestoreIncomplete();
    }
  }

  Future<void> rollback() async {
    try {
      if (_installed) {
        await rename(target, incoming.path);
        _installed = false;
      }
      if (_savedPrevious) {
        await rename(previous, target.path);
        _savedPrevious = false;
      }
    } catch (_) {
      _rollbackFailed = true;
      // Preserve the entire sibling staging tree for recovery; never delete
      // the only remaining copy of the previous download files.
      throw const BackupRestoreIncomplete();
    }
  }

  Future<void> finish({required bool committed}) async {
    if (_rollbackFailed || (!committed && _savedPrevious)) return;
    try {
      await staging.delete(recursive: true);
    } catch (_) {}
  }
}

class _BackupValidationComplete implements Exception {
  const _BackupValidationComplete();
}

/// 清空所有 ObjectBox Box。
///
/// 当 [preserveDownloads] 为 true 时，保留下载记录，用于导入
/// 不含下载文件的备份，避免本机已下载文件变成无记录的孤儿文件。
///
/// 不导入其它设备的下载运行态；保留本机下载时也保留本机任务及历史。
void _clearObjectBoxData({
  bool preserveDownloads = false,
  bool preserveLocalTasks = false,
  bool preserveComicRecords = false,
}) {
  objectbox.bikaHistoryBox.removeAll();
  if (!preserveDownloads) objectbox.bikaDownloadBox.removeAll();
  objectbox.jmFavoriteBox.removeAll();
  objectbox.jmHistoryBox.removeAll();
  if (!preserveDownloads) objectbox.jmDownloadBox.removeAll();
  if (!preserveComicRecords) {
    objectbox.unifiedFavoriteBox.removeAll();
    objectbox.unifiedHistoryBox.removeAll();
    objectbox.comicFollowBox.removeAll();
  }
  if (!preserveDownloads) objectbox.unifiedDownloadBox.removeAll();
  // 注意：UserSetting 不在这里清除，而是在 _restoreUserSetting 中直接替换/更新，
  // 因为应用其他位置假设 UserSetting 的 id 始终为 1。
  // Restoring settings without downloads must not erase this device's jobs.
  // Foreign active tasks are never replayed from the backup.
  if (!preserveDownloads && !preserveLocalTasks) {
    objectbox.downloadTaskBox.removeAll();
  }
  objectbox.pluginConfigBox.removeAll();
  objectbox.pluginInfoBox.removeAll();
  if (preserveDownloads) {
    objectbox.comicFolderBox.removeMany([
      for (final row in objectbox.comicFolderBox.getAll())
        if (row.typeData != ComicFolderType.download.name) row.id,
    ]);
    objectbox.comicLinkBox.removeMany([
      for (final row in objectbox.comicLinkBox.getAll())
        if (row.typeData != ComicFolderType.download.name) row.id,
    ]);
  } else {
    objectbox.comicFolderBox.removeAll();
    objectbox.comicLinkBox.removeAll();
  }
  objectbox.comicReadPreferenceBox.removeAll();
}

/// 为缺少 `id` 的 JSON 补一个默认 0，避免 json_serializable 生成代码里对 `id` 做非空强制转换时崩溃。
Map<String, dynamic> _withDefaultId(Map<String, dynamic> json) {
  if (!json.containsKey('id') || json['id'] == null) {
    json['id'] = 0;
  }
  return json;
}

/// 从 JSON 恢复所有 ObjectBox 实体；导入时重置 id 让 ObjectBox 重新分配主键。
///
/// 对于 ComicFolder / ComicLink，还会用当前设备的 syncDeviceId 对
/// versionVectorJson 做一次 bump，避免导入后同步时出现设备 ID 不一致的冲突。
void _restoreObjectBoxData(
  Map<String, dynamic> json,
  String currentDeviceId, {
  bool includeDownloads = true,
  bool restoreComicRecords = true,
}) {
  String bumpVersionVector(String raw) {
    final map = _parseVersionVector(raw);
    map[currentDeviceId] = (map[currentDeviceId] ?? 0) + 1;
    return jsonEncode(map);
  }

  void putAll<T>(
    Box<T> box,
    List<dynamic>? list,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = (list ?? const <dynamic>[]).map((e) {
      final row = _withDefaultId(Map<String, dynamic>.from(e as Map));
      final parsed = fromJson(row);
      final dynamic entity = parsed;
      final schemas =
          parsed is UnifiedComicFavorite ||
              parsed is UnifiedComicHistory ||
              parsed is UnifiedComicDownload
          ? const {1, 2}
          : const {1};
      if (row['schemaVersion'] is num &&
          !schemas.contains(row['schemaVersion'])) {
        throw const BackupCompatibilityException();
      }
      try {
        SyncPayloadCompatibility.keys(row, {
          ...(entity.toJson() as Map).keys.cast<String>(),
          if (parsed is ComicReadPreference) 'readMode',
        });
      } on SyncCompatibilityException {
        throw const BackupCompatibilityException();
      }
      return parsed;
    }).toList();
    if (items.isNotEmpty) {
      box.putMany(items);
    }
  }

  putAll(
    objectbox.bikaHistoryBox,
    json['bikaComicHistory'] as List?,
    (j) => BikaComicHistory.fromJson(j),
  );
  if (includeDownloads) {
    putAll(
      objectbox.bikaDownloadBox,
      json['bikaComicDownload'] as List?,
      (j) => BikaComicDownload.fromJson(j),
    );
  }
  putAll(
    objectbox.jmFavoriteBox,
    json['jmFavorite'] as List?,
    (j) => JmFavorite.fromJson(j),
  );
  putAll(
    objectbox.jmHistoryBox,
    json['jmHistory'] as List?,
    (j) => JmHistory.fromJson(j),
  );
  if (includeDownloads) {
    putAll(
      objectbox.jmDownloadBox,
      json['jmDownload'] as List?,
      (j) => JmDownload.fromJson(j),
    );
  }
  if (restoreComicRecords) {
    putAll(
      objectbox.unifiedFavoriteBox,
      json['unifiedComicFavorite'] as List?,
      (j) => UnifiedComicFavorite.fromJson(j),
    );
    putAll(
      objectbox.unifiedHistoryBox,
      json['unifiedComicHistory'] as List?,
      (j) => UnifiedComicHistory.fromJson(j),
    );
    putAll(
      objectbox.comicFollowBox,
      json['comicFollow'] as List?,
      (j) => ComicFollow.fromJson(j),
    );
  }
  if (includeDownloads) {
    putAll(
      objectbox.unifiedDownloadBox,
      json['unifiedComicDownload'] as List?,
      // Absolute paths belong to the exporting device. Keep resolving downloaded
      // assets inside this device's download root, never an imported arbitrary path.
      (j) => UnifiedComicDownload.fromJson(j)..storageRoot = '',
    );
  }
  _restoreUserSetting(json['userSetting'] as List?);
  // 下载任务不导入，避免恢复后继续执行已过期的下载任务。
  putAll(
    objectbox.pluginConfigBox,
    json['pluginConfig'] as List?,
    (j) => PluginConfig.fromJson(j),
  );
  putAll(
    objectbox.pluginInfoBox,
    json['pluginInfo'] as List?,
    (j) => PluginInfo.fromJson(j),
  );
  List<dynamic>? directories(String name) => (json[name] as List?)
      ?.where(
        (row) =>
            includeDownloads ||
            (row as Map)['typeData'] != ComicFolderType.download.name,
      )
      .toList();
  putAll(objectbox.comicFolderBox, directories('comicFolder'), (j) {
    final folder = ComicFolder.fromJson(j);
    folder.versionVectorJson = bumpVersionVector(folder.versionVectorJson);
    return folder;
  });
  putAll(objectbox.comicLinkBox, directories('comicLink'), (j) {
    final link = ComicLink.fromJson(j);
    link.versionVectorJson = bumpVersionVector(link.versionVectorJson);
    return link;
  });
  putAll(
    objectbox.comicReadPreferenceBox,
    json['comicReadPreference'] as List?,
    (j) => ComicReadPreference.fromJson(j),
  );
}

/// 恢复 UserSetting。
///
/// 应用大量代码假设 UserSetting 的 ObjectBox id 为 1，因此这里不先清空再插入，
/// 而是直接替换现有 id=1 记录的内容；没有记录时再插入新记录。
///
/// 导入时会保留当前设备上的平台相关/本地-only 设置，避免被备份覆盖：
/// 自定义导出目录、代理、应用锁（手势密码/PIN）、窗口几何、日志地址、
/// Impeller 强制启用标志等。
void _restoreUserSetting(List<dynamic>? list) {
  if (list == null || list.isEmpty) return;

  final row = _withDefaultId(Map<String, dynamic>.from(list.first as Map));
  final backup = UserSetting.fromJson(row);
  try {
    SyncPayloadCompatibility.keys(row, backup.toJson().keys);
    if (backup.globalSettingData?.isNotEmpty == true) {
      SyncPayloadCompatibility.tree(
        _decodeBackupJson(backup.globalSettingData!),
        jsonDecode(jsonEncode(const GlobalSettingState().toJson())),
      );
    }
  } on SyncCompatibilityException {
    throw const BackupCompatibilityException();
  }

  final current = objectbox.userSettingBox.get(1);
  if (current != null) {
    // 复用现有 id=1 的 slot，直接覆盖设置数据
    if (backup.globalSettingData != null &&
        backup.globalSettingData!.isNotEmpty) {
      current.globalSetting = _mergeGlobalSettingForImport(
        backup.globalSetting,
        current.globalSetting,
      );
    }
    if (backup.bikaSettingData != null && backup.bikaSettingData!.isNotEmpty) {
      current.bikaSettingData = backup.bikaSettingData;
    }
    if (backup.jmSettingData != null && backup.jmSettingData!.isNotEmpty) {
      current.jmSettingData = backup.jmSettingData;
    }
    current.jmJwt = backup.jmJwt;
    objectbox.userSettingBox.put(current);
  } else {
    // 没有现有记录时直接插入备份数据，让 ObjectBox 自动分配 id（空盒时通常为 1）
    backup.id = 0;
    if (backup.globalSettingData != null &&
        backup.globalSettingData!.isNotEmpty) {
      backup.globalSetting = _mergeGlobalSettingForImport(
        backup.globalSetting,
        const GlobalSettingState(),
      );
    }
    objectbox.userSettingBox.put(backup);
  }
}

/// 合并备份的 [GlobalSettingState] 与当前设备的本地设置。
///
/// 备份中的通用偏好设置会被采用，但跟平台强相关或不应跨设备同步的字段
/// 会被 [current] 的值覆盖：
/// - 自定义导出目录（[customExportPath]）
/// - SOCKS5 代理（[socks5Proxy] / [socks5ProxyEnabled]）
/// - 应用锁（[appLockSetting]，含手势密码哈希与 PIN 重置哈希）
/// - 本机墨水屏首次检测状态（[EInkSettingState.detectionHandled]）
/// - 桌面端窗口位置与大小（[windowWidth]/[windowHeight]/[windowX]/[windowY]）
/// - 日志保存地址（[logAddress]）
/// - Rust HTTP 请求拦截开关（[blockRustHttpRequests]）
/// - iOS Impeller 强制启用标志（[forceEnableImpeller]）
/// - Android 后台保活（[androidKeepAliveEnabled]）
GlobalSettingState _mergeGlobalSettingForImport(
  GlobalSettingState backup,
  GlobalSettingState current,
) {
  final local =
      jsonDecode(jsonEncode(current.toJson())) as Map<String, dynamic>;
  final incoming =
      jsonDecode(jsonEncode(backup.toJson())) as Map<String, dynamic>;
  final restored = GlobalSettingState.fromJson({
    ...local,
    ..._portableBackupGlobal(incoming),
  });
  return restored.copyWith(
    eInkSetting: restored.eInkSetting.copyWith(
      detectionHandled: current.eInkSetting.detectionHandled,
    ),
  );
}

/// 尽可能使用重命名移动目录；失败时回退到递归复制。
Map<String, int> _parseVersionVector(String raw) {
  if (raw.trim().isEmpty) return <String, int>{};
  try {
    final map = _decodeBackupJson(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return <String, int>{};
  }
}

Future<void> _moveDirectory(Directory source, Directory target) async {
  try {
    await source.rename(target.path);
  } on FileSystemException catch (_) {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _moveDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
    await source.delete(recursive: true);
  }
}
