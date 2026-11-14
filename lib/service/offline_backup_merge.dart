import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/comic_follow/comic_follow_merge.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/util/get_path.dart';

enum BackupImportMode { merge, restore }

/// A draft for one file import, independent of persistent cloud sync choices.
class BackupImportOptions {
  const BackupImportOptions({
    this.importSettings = true,
    this.importPlugins = true,
    this.importCloudSyncAccount = false,
  });
  final bool importSettings, importPlugins, importCloudSyncAccount;

  bool includesImage(String key) => FolderCoverIdentity.valid(key)
      ? true
      : key == 'collection-cover' || key.startsWith('collection-cover:')
      ? importSettings
      : importPlugins;

  bool includesPortable(Map<String, dynamic> row) {
    final key = row['key'] as String;
    if (row['kind'] != 'preference' || key.startsWith('breeze.video.progress.'))
      return true;
    return pluginPortableScope(row)?.scope == PluginDataScope.accountSettings
        ? importPlugins
        : importSettings;
  }

  PortablePreferencesSnapshot selectPortable(
    PortablePreferencesSnapshot incoming,
    PortablePreferencesSnapshot local, {
    required bool merge,
  }) {
    final selected = PortablePreferencesSnapshot({
      for (final entry in incoming.entries.entries)
        if (includesPortable(entry.value)) entry.key: entry.value,
    });
    if (merge) return local.merged(selected);
    return PortablePreferencesSnapshot({
      ...selected.entries,
      for (final entry in local.entries.entries)
        if (!includesPortable(entry.value)) entry.key: entry.value,
    });
  }

  /// Only unselected categories are replaced with local rows. Record tables
  /// remain untouched so the existing merge/replace behavior stays authoritative.
  void preserveUnselectedDatabase(
    Map<String, dynamic> incoming,
    Map<String, dynamic> local,
  ) {
    if (!importPlugins) {
      incoming['pluginInfo'] = local['pluginInfo'] ?? [];
      incoming['pluginConfig'] = local['pluginConfig'] ?? [];
    }
    final users = incoming['userSetting'] as List? ?? const [];
    final localUsers = local['userSetting'] as List? ?? const [];
    if (users.isEmpty || localUsers.isEmpty) return;
    final row = users.first as Map, retained = localUsers.first as Map;
    for (final field in [
      if (!importSettings) ...['globalSettingData', 'globalSetting'],
      if (!importPlugins) ...[
        'bikaSettingData',
        'bikaSetting',
        'jmSettingData',
        'jmSetting',
        'jmJwt',
      ],
    ])
      row[field] = retained[field];
  }

  /// Old UserSetting credentials have no revision clock. Treat an account and
  /// its credentials as one identity: only fill empty values for that account,
  /// never attach a backup token to a different or unidentified local account.
  void mergeLegacyAccounts(
    Map<String, dynamic> incoming,
    Map<String, dynamic> local,
  ) {
    if (!importPlugins) return;
    final users = incoming['userSetting'] as List? ?? const [];
    if (users.isEmpty) return;
    final localUsers = local['userSetting'] as List? ?? const [];
    final before = localUsers.isEmpty
        ? UserSetting()
        : UserSetting.fromJson(
            Map<String, dynamic>.from(localUsers.first as Map),
          );
    final saved = UserSetting.fromJson(
      Map<String, dynamic>.from(users.first as Map),
    );
    var bika = before.bikaSetting;
    final incomingBika = saved.bikaSetting;
    final emptyBika =
        bika.account.isEmpty &&
        bika.password.isEmpty &&
        bika.authorization.isEmpty;
    if (incomingBika.account.isNotEmpty &&
        (emptyBika || bika.account == incomingBika.account)) {
      bika = bika.copyWith(
        account: bika.account.isEmpty ? incomingBika.account : bika.account,
        password: bika.password.isEmpty ? incomingBika.password : bika.password,
        authorization: bika.authorization.isEmpty
            ? incomingBika.authorization
            : bika.authorization,
      );
    }
    var jm = before.jmSetting;
    var jwt = before.jmJwt;
    final incomingJm = saved.jmSetting;
    final emptyJm =
        jm.account.isEmpty &&
        jm.password.isEmpty &&
        jm.userInfo.isEmpty &&
        jwt.isEmpty;
    if (incomingJm.account.isNotEmpty &&
        (emptyJm || jm.account == incomingJm.account)) {
      jm = jm.copyWith(
        account: jm.account.isEmpty ? incomingJm.account : jm.account,
        password: jm.password.isEmpty ? incomingJm.password : jm.password,
        userInfo: jm.userInfo.isEmpty ? incomingJm.userInfo : jm.userInfo,
        loginStatus: emptyJm ? incomingJm.loginStatus : jm.loginStatus,
      );
      if (jwt.isEmpty) jwt = saved.jmJwt;
    }
    final row = users.first as Map;
    row['bikaSetting'] = bika.toJson();
    row['bikaSettingData'] = jsonEncode(bika.toJson());
    row['jmSetting'] = jm.toJson();
    row['jmSettingData'] = jsonEncode(jm.toJson());
    row['jmJwt'] = jwt;
  }
}

/// Replace selected artwork categories and retain unselected local categories.
/// The returned plan owns verified bytes, so the temporary projection can go.
Future<LocalAppearanceRestorePlan?> prepareSelectedBackupAppearanceRestore(
  Directory incoming,
  LocalAppearanceImages images,
  BackupImportOptions? options,
) async {
  return images.prepareBackupRestore(
    incoming,
    preserveKey:
        options == null || options.importSettings && options.importPlugins
        ? null
        : (key) => !options.includesImage(key),
  );
}

class OfflineBackupPreview {
  const OfflineBackupPreview({
    required this.version,
    required this.exportedAt,
    required this.includeDownloads,
    required this.counts,
  });
  final String version;
  final DateTime? exportedAt;
  final bool includeDownloads;
  final Map<String, int> counts;
}

/// A staging-only result. The caller holds the storage-operation queue and must
/// journal preferences before applying this plan. No incoming directory changes.
class OfflineBackupMergePlan {
  OfflineBackupMergePlan._(
    this.directory,
    this._settings,
    this._comicRecords,
    this._unversionedComicKeys,
    this._excludedComicSources, {
    required this.localPortableAtPreparation,
    this.skippedPluginSources = const {},
  });
  final Directory directory;
  final SettingsArchiveImportPlan _settings;
  final Map<String, List<Map<String, dynamic>>> _comicRecords;
  final Map<String, Set<String>> _unversionedComicKeys;
  final Set<String> _excludedComicSources;
  final PortablePreferencesSnapshot localPortableAtPreparation;
  final Set<String> skippedPluginSources;
  Future<void> applySettingsPreferences(
    Future<void> Function(Map<String, dynamic>) beforeWrite, {
    bool persistMetadata = true,
  }) =>
      _settings.applyPreferences(beforeWrite, persistMetadata: persistMetadata);

  /// Re-read these records inside the final write transaction. The reader and
  /// follow checks can finish a write while the backup is preparing files.
  void mergeCurrentComicRecords() {
    void merge<T>(
      String name,
      Box<T> box,
      Map<String, dynamic> Function(T) toJson,
      T Function(Map<String, dynamic>) fromJson, {
      Map<String, dynamic> Function(Map<String, dynamic>, Map<String, dynamic>)?
      reconcile,
    }) {
      final local = box.getAll().map(toJson).toList();
      final incoming = _withoutLegacyResurrections(
        _comicRecords[name]!,
        _unversionedComicKeys[name]!,
        local,
      ).where((row) => !_excludedComicSources.contains(row['source']));
      final byKey = {for (final row in local) row['uniqueKey']: row};
      final merged = ComicSyncCore.mergeByUniqueKey(
        local,
        incoming,
        keyOf: (row) => row['uniqueKey'] as String,
        updatedAtOf: (row) => DateTime.parse(row['updatedAt'] as String),
        reconcile: reconcile,
      );
      final updates = [
        for (final row in merged)
          if (!identical(row, byKey[row['uniqueKey']]))
            fromJson({...row, 'id': byKey[row['uniqueKey']]?['id'] ?? 0}),
      ];
      if (updates.isNotEmpty) box.putMany(updates);
    }

    merge(
      'unifiedComicFavorite',
      objectbox.unifiedFavoriteBox,
      (row) => row.toJson(),
      UnifiedComicFavorite.fromJson,
    );
    merge(
      'unifiedComicHistory',
      objectbox.unifiedHistoryBox,
      (row) => row.toJson(),
      UnifiedComicHistory.fromJson,
    );
    merge(
      'comicFollow',
      objectbox.comicFollowBox,
      (row) => row.toJson(),
      ComicFollow.fromJson,
      reconcile: mergeComicFollowRecordJson,
    );
  }

  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

const _comicEntities = <String, String>{
  'unifiedComicFavorite': 'favorites',
  'unifiedComicHistory': 'histories',
  'comicFollow': 'follows',
  'comicFolder': 'folders',
  'comicLink': 'links',
  'comicReadPreference': 'readPreferences',
};

const _comicRecordTables = [
  'unifiedComicFavorite',
  'unifiedComicHistory',
  'comicFollow',
];

Iterable<Map<String, dynamic>> _withoutLegacyResurrections(
  List<Map<String, dynamic>> incoming,
  Set<String> unversioned,
  Iterable<Map<String, dynamic>> local,
) {
  if (unversioned.isEmpty) return incoming;
  final tombstones = {
    for (final row in local)
      if (row['deleted'] == true) row['uniqueKey'],
  };
  return incoming.where((row) {
    final key = row['uniqueKey'];
    return !unversioned.contains(key) || !tombstones.contains(key);
  });
}

// These are the same supported entities as the file restore contract. Opaque
// plugin configuration remains opaque; unknown host fields never disappear.
final _factories = <String, dynamic Function(Map<String, dynamic>)>{
  // ignore: deprecated_member_use_from_same_package
  'bikaComicHistory': BikaComicHistory.fromJson,
  // ignore: deprecated_member_use_from_same_package
  'bikaComicDownload': BikaComicDownload.fromJson,
  // ignore: deprecated_member_use_from_same_package
  'jmFavorite': JmFavorite.fromJson,
  // ignore: deprecated_member_use_from_same_package
  'jmHistory': JmHistory.fromJson,
  // ignore: deprecated_member_use_from_same_package
  'jmDownload': JmDownload.fromJson,
  'unifiedComicFavorite': UnifiedComicFavorite.fromJson,
  'unifiedComicHistory': UnifiedComicHistory.fromJson,
  'comicFollow': ComicFollow.fromJson,
  'unifiedComicDownload': UnifiedComicDownload.fromJson,
  'userSetting': UserSetting.fromJson, 'downloadTask': DownloadTask.fromJson,
  'pluginConfig': PluginConfig.fromJson, 'pluginInfo': PluginInfo.fromJson,
  'comicFolder': ComicFolder.fromJson, 'comicLink': ComicLink.fromJson,
  'comicReadPreference': ComicReadPreference.fromJson,
};

Future<Map<String, dynamic>> _json(
  File file, {
  int limit = 64 * 1024 * 1024,
}) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await file.length() > limit) {
    throw const FormatException('Invalid backup file');
  }
  final Object? value;
  try {
    value = jsonDecode(await file.readAsString());
  } on FormatException {
    // JSON parser errors include source excerpts, potentially account secrets.
    // This preview decoder runs before the importer's sanitized parser.
    throw const FormatException('Invalid backup data');
  }
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid backup object');
  }
  return value;
}

Map<String, dynamic> _database(Map<String, dynamic> raw) {
  SyncPayloadCompatibility.keys(raw, _factories.keys);
  if (raw.isEmpty) throw const FormatException('Empty database backup');
  final result = <String, dynamic>{};
  for (final entry in raw.entries) {
    if (entry.value is! List || (entry.value as List).length > 200000) {
      throw const FormatException('Invalid backup rows');
    }
    result[entry.key] = [
      for (final value in entry.value as List)
        () {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid backup row');
          }
          final source = <String, dynamic>{'id': 0, ...value};
          final dynamic entity = _factories[entry.key]!(source);
          final normalized = Map<String, dynamic>.from(entity.toJson() as Map);
          SyncPayloadCompatibility.keys(source, {
            ...normalized.keys,
            if (entry.key == 'comicReadPreference') 'readMode',
          });
          final schema = source['schemaVersion'];
          if (schema != null &&
              !(entry.key.startsWith('unifiedComic') ? {1, 2} : {1}).contains(
                schema,
              )) {
            throw const SyncCompatibilityException();
          }
          if (entity is UserSetting &&
              entity.globalSettingData?.isNotEmpty == true) {
            SyncPayloadCompatibility.tree(
              jsonDecode(entity.globalSettingData!),
              jsonDecode(jsonEncode(const GlobalSettingState().toJson())),
            );
          }
          normalized['id'] = 0;
          return normalized;
        }(),
    ];
  }
  return result;
}

Future<OfflineBackupPreview> readOfflineBackupPreview(
  Directory incoming,
) async {
  final config = await _json(
    File(p.join(incoming.path, 'config.json')),
    limit: 131072,
  );
  SyncPayloadCompatibility.keys(config, {
    'format',
    'schemaVersion',
    'version',
    'buildNumber',
    'includeDownloads',
    'exportedAt',
  });
  if (config['format'] != null && config['format'] != 'BreezeBackup' ||
      config['schemaVersion'] != null && config['schemaVersion'] != 1 ||
      config['includeDownloads'] != null &&
          config['includeDownloads'] is! bool) {
    throw const SyncCompatibilityException();
  }
  final database = _database(
    await _json(File(p.join(incoming.path, 'objectbox.json'))),
  );
  final portable = await _readPortable(incoming);
  final chapters = await readBackupChapterProgress(incoming);
  await _readSettings(incoming, database);
  return OfflineBackupPreview(
    version: config['version'] is String ? config['version'] as String : '',
    exportedAt: DateTime.tryParse('${config['exportedAt'] ?? ''}'),
    includeDownloads: config['includeDownloads'] == true,
    counts: Map.unmodifiable({
      for (final row in database.entries) row.key: (row.value as List).length,
      if (chapters != null)
        'comicChapterProgress': chapters.rows.values
            .where((row) => row.progress != null)
            .length,
      if (portable != null) ...{
        'portableEntries': portable.preferences.entries.length,
        'videoFavorites': portable.library.favorites.length,
        'videoFolders': portable.library.folders.length,
        'videoMemberships': portable.library.memberships.length,
        'videoTracking': portable.library.tracking.length,
      },
    }),
  );
}

Future<ChapterProgressArchive?> readBackupChapterProgress(
  Directory root,
) async {
  final file = File(p.join(root.path, ChapterProgressArchive.filename));
  if (!await file.exists()) return null;
  if (await file.length() > ChapterProgressArchive.byteLimit) {
    throw const SyncCompatibilityException();
  }
  try {
    return ChapterProgressArchive.decode(await file.readAsBytes());
  } on FormatException {
    throw const SyncCompatibilityException();
  }
}

/// Capture block/field revisions using exactly the cloud settings serializer.
Future<Map<String, dynamic>> captureOfflineSettingsPayload() async =>
    (await prepareSettingsArchiveImport(
      null,
      state: objectbox.userSettingBox.get(1)!.globalSetting,
      includeAll: true,
    )).compatibilityPayload;

class _SettingsInput implements ComicSyncRemoteAdapter {
  _SettingsInput(this.payload);
  final List<int> payload;
  final String file = '${ComicSyncCore.syncRemoteRootName}/settings_1.bin';
  @override
  Future<List<String>> listRemoteDataFiles() async => [file];
  @override
  Future<List<int>> downloadRemoteFile(String path) async =>
      path.endsWith('settings.md5')
      ? utf8.encode(ComicSyncCore.calculateMd5(payload))
      : payload;
  @override
  Future<String> downloadRemoteMd5() async =>
      ComicSyncCore.calculateMd5(payload);
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('Read only');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async => throw StateError('Read only');
  @override
  Future<void> deleteRemoteFiles(List<String> paths) async =>
      throw StateError('Read only');
}

Future<SettingsArchiveData?> _readSettings(
  Directory incoming,
  Map<String, dynamic> database,
) async {
  final metadata = File(p.join(incoming.path, 'sync-settings.json'));
  final Map<String, dynamic> payload;
  if (await metadata.exists()) {
    payload = await _json(metadata, limit: 32 * 1024 * 1024);
  } else {
    final users = database['userSetting'] as List? ?? [];
    final user = users.isEmpty
        ? null
        : UserSetting.fromJson(Map<String, dynamic>.from(users.first as Map));
    // A legacy export date does not prove an individual setting changed then.
    payload = {
      'version': 'v1',
      'schemaVersion': 'v1',
      'syncTime': 1,
      'globalSetting': user?.globalSetting.toJson() ?? <String, dynamic>{},
      'pluginConfigs': database['pluginConfig'] ?? [],
      'pluginInfos': database['pluginInfo'] ?? [],
    };
  }
  return readSettingsArchiveData(
    _SettingsInput(utf8.encode(jsonEncode(payload))),
    codec: SettingsSyncCodec(
      encode: (bytes) async => bytes,
      decode: (bytes) async => bytes,
    ),
  );
}

Future<
  ({PortablePreferencesSnapshot preferences, VideoLibrarySnapshot library})?
>
_readPortable(Directory root) async {
  final file = File(p.join(root.path, 'portable-data.json'));
  if (!await file.exists()) return null;
  final raw = await _json(file);
  SyncPayloadCompatibility.keys(raw, {
    'format',
    'version',
    'preferences',
    'videoLibrary',
  });
  if (raw['format'] != 'breeze-portable-data' ||
      raw['version'] != 1 ||
      raw['videoLibrary'] is! Map<String, dynamic>) {
    throw const SyncCompatibilityException();
  }
  return (
    preferences: PortablePreferencesSnapshot.fromJson(raw['preferences']),
    library: VideoLibrarySnapshot.fromJson(
      raw['videoLibrary'] as Map<String, dynamic>,
    ),
  );
}

class _MergedSnapshot implements Exception {
  const _MergedSnapshot();
}

Future<OfflineBackupMergePlan> prepareOfflineBackupMerge(
  Directory incoming, {
  required Directory stagingParent,
  bool restoreDownloadFiles = false,
  LocalAppearanceImages? appearanceImages,
  Directory? downloadDirectory,
  BackupImportOptions? options,
}) async {
  final preview = await readOfflineBackupPreview(incoming);
  final original = await _json(File(p.join(incoming.path, 'objectbox.json')));
  final source = _database(original);
  final comicRecords = {
    for (final name in _comicRecordTables)
      name: List<Map<String, dynamic>>.from(source[name] as List? ?? const []),
  };
  final unversionedComicKeys = {
    for (final name in _comicRecordTables)
      name: <String>{
        for (final row in original[name] as List? ?? const [])
          if (!(row as Map).containsKey('updatedAt') ||
              !row.containsKey('deleted'))
            row['uniqueKey'] as String,
      },
  };
  final excludedComicSources = LocalPluginInstallationState.instance
      .excludedSources(PluginDataScope.records);
  final selection = objectbox.userSettingBox.get(1)!.globalSetting.syncSetting;
  final settings = await prepareSettingsArchiveImport(
    await _readSettings(incoming, source),
    state: objectbox.userSettingBox.get(1)!.globalSetting,
    protectVersionedLocalFields: true,
    importSettings: options?.importSettings,
    importPlugins: options?.importPlugins,
  );
  final portable = await _readPortable(incoming);
  final localPreferences = await PortablePreferences.capture(persist: false);
  final localLibrary = await VideoLibraryStore.shared.read();
  await stagingParent.create(recursive: true);
  final target = await stagingParent.createTemp('breeze-merged-');
  try {
    final merged =
        jsonDecode(await objectbox.collectAllDataJsonAsync(removeIds: true))
            as Map<String, dynamic>;
    final knownComicFolderIds = <String>{
      for (final folder in objectbox.comicFolderBox.getAll())
        if (folder.syncId.isNotEmpty) folder.syncId,
      for (final raw in source['comicFolder'] as List? ?? const [])
        if (raw is Map &&
            raw['syncId'] is String &&
            (raw['syncId'] as String).isNotEmpty)
          raw['syncId'] as String,
    };
    final comic = <String, dynamic>{
      'version': 'v1',
      for (final entity in _comicEntities.entries)
        entity.value: source[entity.key] ?? [],
    };
    // Legacy unversioned rows cannot revive an explicit local tombstone.
    for (final name in _comicRecordTables) {
      comic[_comicEntities[name]!] = _withoutLegacyResurrections(
        comicRecords[name]!,
        unversionedComicKeys[name]!,
        (merged[name] as List? ?? const []).cast<Map<String, dynamic>>(),
      ).toList();
    }
    ComicSyncCore.validatePayload(comic);
    // Reuse actual cloud transactions/mergers without committing trial state.
    // The synchronous collector runs inside this rollback-only transaction.
    // An explicit void function is essential: an always-throwing closure is
    // inferred as Never Function(), which ObjectBox rejects before opening a
    // transaction (it must not run a Never callback outside rollback protection).
    void collectMergedSnapshot() {
      ComicSyncCore.mergeUnifiedData(
        objectbox.store,
        comic,
        excludedSources: excludedComicSources,
      );
      settings.persistDatabase();
      final trial =
          jsonDecode(objectbox.collectAllDataJson(removeIds: true))
              as Map<String, dynamic>;
      for (final name in {
        ..._comicEntities.keys,
        'userSetting',
        'pluginConfig',
        'pluginInfo',
      }) {
        merged[name] = trial[name];
      }
      final sourceUsers = source['userSetting'] as List? ?? const [];
      final mergedUsers = merged['userSetting'] as List? ?? const [];
      if (options?.importPlugins == true &&
          sourceUsers.isNotEmpty &&
          mergedUsers.isNotEmpty) {
        final accounts = <String, dynamic>{
          'userSetting': [Map<String, dynamic>.from(sourceUsers.first as Map)],
        };
        options!.mergeLegacyAccounts(accounts, merged);
        final accountRow = (accounts['userSetting'] as List).first as Map;
        final mergedRow = mergedUsers.first as Map;
        for (final field in [
          'bikaSetting',
          'bikaSettingData',
          'jmSetting',
          'jmSettingData',
          'jmJwt',
        ]) {
          mergedRow[field] = accountRow[field];
        }
      }
      throw const _MergedSnapshot();
    }

    try {
      objectbox.store.runInTransaction<void>(
        TxMode.write,
        collectMergedSnapshot,
      );
    } on _MergedSnapshot {
      /* The authoritative database is unchanged. */
    }
    for (final name in ['bikaComicHistory', 'jmHistory', 'jmFavorite']) {
      merged[name] = _legacyRows(
        merged[name] as List? ?? [],
        source[name] as List? ?? [],
      );
    }
    if (preview.includeDownloads) {
      for (final name in [
        'bikaComicDownload',
        'jmDownload',
        'unifiedComicDownload',
      ]) {
        merged[name] = _downloadRows(
          merged[name] as List? ?? [],
          source[name] as List? ?? [],
        );
      }
    }
    // Local tasks retain their owner; the journal importer separately preserves
    // their real IDs. Foreign task state is never admitted from the file.
    merged['downloadTask'] = [];
    final config = await _json(File(p.join(incoming.path, 'config.json')));
    await File(
      p.join(target.path, 'config.json'),
    ).writeAsString(jsonEncode(config));
    await File(
      p.join(target.path, 'objectbox.json'),
    ).writeAsString(jsonEncode(merged));
    final chapters = await readBackupChapterProgress(incoming);
    if (chapters != null) {
      await File(
        p.join(target.path, ChapterProgressArchive.filename),
      ).writeAsBytes(chapters.encode());
    }
    final mergedLibrary = portable == null
        ? localLibrary
        : localLibrary.merged(portable.library);
    knownComicFolderIds.removeAll({
      for (final raw in merged['comicFolder'] as List? ?? const [])
        if (raw is Map && raw['deletedAt'] == null && raw['syncId'] is String)
          raw['syncId'] as String,
    });
    final retiredArtwork = <String>{
      for (final id in knownComicFolderIds) FolderCoverIdentity.comic(id),
      for (final entry in mergedLibrary.folders.entries)
        if (entry.value.deleted) FolderCoverIdentity.video(entry.key),
    };
    await File(p.join(target.path, 'portable-data.json')).writeAsString(
      jsonEncode({
        'format': 'breeze-portable-data',
        'version': 1,
        'preferences':
            (portable == null
                    ? localPreferences
                    : options != null
                    ? options.selectPortable(
                        portable.preferences,
                        localPreferences,
                        merge: true,
                      )
                    : localPreferences.merged(
                        PortablePreferencesSnapshot({
                          for (final entry
                              in portable.preferences.entries.entries)
                            if (selection.syncSettings ||
                                entry.value['kind'] != 'preference')
                              entry.key: entry.value,
                        }),
                      ))
                .toJson(),
        'videoLibrary': mergedLibrary.toJson(),
      }),
    );
    await _mergeImages(
      incoming,
      target,
      appearanceImages ?? LocalAppearanceImages.instance,
      options: options,
      retiredFolderKeys: retiredArtwork,
    );
    if (preview.includeDownloads && restoreDownloadFiles) {
      final downloads = Directory(p.join(target.path, 'downloads'));
      final currentDownloads =
          downloadDirectory ?? Directory(await getDownloadPath());
      final incomingDownloads = Directory(p.join(incoming.path, 'downloads'));
      await VideoLocalResources.validateBackupDirectory(currentDownloads);
      await VideoLocalResources.validateBackupDirectory(incomingDownloads);
      await _copyTree(currentDownloads, downloads);
      await _copyTree(incomingDownloads, downloads, skipVideoIndex: true);
      await _mergeVideoIndex(currentDownloads, incomingDownloads, downloads);
    }
    return OfflineBackupMergePlan._(
      target,
      settings,
      comicRecords,
      unversionedComicKeys,
      excludedComicSources,
      localPortableAtPreparation: localPreferences,
      skippedPluginSources: {
        if (settings.applyPlugins)
          for (final row
              in settings.compatibilityPayload['pluginInfos'] as List? ??
                  const [])
            if (row is Map &&
                PluginHostCompatibility.unsupportedPluginInfo(row) != null &&
                row['uuid'] is String)
              row['uuid'] as String,
      },
    );
  } catch (_) {
    await target.delete(recursive: true);
    rethrow;
  }
}

List<dynamic> _legacyRows(List<dynamic> local, List<dynamic> incoming) {
  final result = {for (final row in local) (row as Map)['comicId']: row};
  for (final row in incoming) {
    // Retired source-specific boxes have no common revision contract. They can
    // add an unseen identity, never silently replace an existing local record.
    result.putIfAbsent((row as Map)['comicId'], () => row);
  }
  return result.values.toList();
}

List<dynamic> _downloadRows(List<dynamic> local, List<dynamic> incoming) {
  final result = {
    for (final row in local) ((row as Map)['uniqueKey'] ?? row['comicId']): row,
  };
  for (final row in incoming) {
    final key = (row as Map)['uniqueKey'] ?? row['comicId'];
    result.putIfAbsent(key, () => row);
  }
  return result.values.toList();
}

Future<void> _mergeImages(
  Directory incoming,
  Directory target,
  LocalAppearanceImages current, {
  BackupImportOptions? options,
  Set<String> retiredFolderKeys = const {},
}) async {
  final validation = Directory(p.join(target.path, '.image-validation'));
  final validator = LocalAppearanceImages(rootDirectory: validation);
  LocalAppearanceRestorePlan? plan;
  try {
    plan = await validator.prepareBackupRestore(incoming);
    await current.exportBackup(target);
    final oldFile = File(
      p.join(incoming.path, 'appearance-local', 'manifest.json'),
    );
    if (!await oldFile.exists()) return;
    final nextFile = File(
      p.join(target.path, 'appearance-local', 'manifest.json'),
    );
    final before = await _json(oldFile, limit: 131072),
        next = await _json(nextFile, limit: 131072);
    if (options != null) {
      for (final name in ['images', 'changes']) {
        if (before[name] is Map)
          before[name] = {
            for (final entry in (before[name] as Map).entries)
              if (options.includesImage(entry.key as String))
                entry.key: entry.value,
          };
      }
    }
    final galleryKey = RegExp(r'^collection-cover:[0-9a-f]{64}$');
    final legacySlot = RegExp(r'^collection-cover:[1-7]$');
    const alias = LocalAppearanceImages.collectionCoverKey;
    final images = Map<String, dynamic>.from(next['images'] as Map);
    final changes = Map<String, dynamic>.from(next['changes'] as Map);
    final importedImages = <String, dynamic>{};
    final importedChanges = <String, dynamic>{};
    for (final entry in (before['images'] as Map).entries) {
      if (entry.key == alias) continue;
      final key = legacySlot.hasMatch(entry.key as String)
          ? LocalAppearanceImages.collectionImageKey(
              (entry.value as Map)['sha256'] as String,
            )
          : entry.key as String;
      importedImages[key] = entry.value;
    }
    // The old single-image format has no gallery identity. Its image identity
    // is migrated separately from the optional versioned selection below.
    final oldSelected = (before['images'] as Map)[alias];
    String? singleImageKey;
    if (!importedImages.keys.any(galleryKey.hasMatch) && oldSelected is Map) {
      singleImageKey = LocalAppearanceImages.collectionImageKey(
        oldSelected['sha256'] as String,
      );
      importedImages[singleImageKey] = oldSelected;
    }
    for (final entry in (before['changes'] as Map? ?? {}).entries) {
      if (entry.key == alias) continue;
      final key = legacySlot.hasMatch(entry.key as String)
          ? LocalAppearanceImages.collectionImageKey(
              (entry.value as Map)['digest'] as String,
            )
          : entry.key as String;
      final prior = importedChanges[key] as Map?;
      if (prior == null ||
          ((entry.value as Map)['modifiedAt'] as int) >
              (prior['modifiedAt'] as int)) {
        importedChanges[key] = entry.value;
      }
    }
    final oldSelectionChange = (before['changes'] as Map?)?[alias];
    if (singleImageKey != null && oldSelectionChange != null) {
      importedChanges.putIfAbsent(singleImageKey, () => oldSelectionChange);
    }
    for (final key in {...importedImages.keys, ...importedChanges.keys}) {
      final image = importedImages[key] as Map?;
      var change = importedChanges[key] as Map?;
      final local = changes[key] as Map?;
      if (change == null) {
        // Unversioned images can add an unseen identity, but cannot resurrect
        // a tombstone or replace any image this device has already known.
        if (local != null || images.containsKey(key)) continue;
        final name = image!['file'] as String;
        change = {
          'modifiedAt': 1,
          'deleted': false,
          'digest': image['sha256'],
          'size': await File(
            p.join(incoming.path, 'appearance-local', name),
          ).length(),
        };
      } else if (local != null) {
        final time = change['modifiedAt'] as int;
        final localTime = local['modifiedAt'] as int;
        if (time < localTime) continue;
        if (time == localTime) {
          if (change['deleted'] != local['deleted']) {
            if (local['deleted'] == true) continue;
          } else {
            if (change['digest'] != local['digest'] ||
                change['size'] != local['size']) {
              throw const FormatException('Conflicting artwork revisions');
            }
          }
        }
      }
      changes[key] = change;
      if (change['deleted'] == true) {
        images.remove(key);
      } else if (image != null) {
        final name = image['file'] as String;
        await File(
          p.join(incoming.path, 'appearance-local', name),
        ).copy(p.join(target.path, 'appearance-local', name));
        images[key] = image;
      } else if ((images[key] as Map?)?['sha256'] != change['digest']) {
        // Missing bytes preserve a live record, never manufacture a deletion.
        images.remove(key);
      }
    }
    // This is only the temporary merged artifact. The user's images remain
    // untouched until the normal backup transaction actually commits.
    final retiredAt = DateTime.now().toUtc().microsecondsSinceEpoch;
    for (final key in retiredFolderKeys) {
      final previous = changes[key] as Map?, image = images[key] as Map?;
      if (previous == null && image == null) continue;
      final size =
          previous?['size'] ??
          await File(
            p.join(target.path, 'appearance-local', image!['file'] as String),
          ).length();
      final oldRevision = previous?['modifiedAt'] as int? ?? 0;
      changes[key] = {
        'modifiedAt': retiredAt > oldRevision ? retiredAt : oldRevision + 1,
        'deleted': true,
        'digest': previous?['digest'] ?? image!['sha256'],
        'size': size,
      };
      images.remove(key);
    }
    if (changes.entries
            .where(
              (entry) =>
                  galleryKey.hasMatch(entry.key) &&
                  (entry.value as Map)['deleted'] == false,
            )
            .length >
        LocalAppearanceImages.maximumCollectionCovers) {
      throw StateError('Collection cover gallery is full');
    }
    AppearanceGallerySelection? selectionOf(Object? raw) {
      if (raw is! Map) return null;
      return AppearanceGallerySelection(
        key: raw['deleted'] == true
            ? null
            : LocalAppearanceImages.collectionImageKey(raw['digest'] as String),
        modifiedAt: raw['modifiedAt'] as int,
      );
    }

    final localSelection = selectionOf(changes[alias]);
    // A legacy alias without its revision cannot overwrite the local choice.
    final importedSelection = selectionOf(oldSelectionChange);
    var selection = AppearanceGallerySelection.newer(
      localSelection,
      importedSelection,
    );
    final gallery = images.keys.where(galleryKey.hasMatch).toList()..sort();
    if (!gallery.contains(selection?.key)) {
      final localKey = localSelection?.key;
      final fallback = gallery.contains(localKey)
          ? localKey
          : gallery.isEmpty
          ? null
          : gallery.first;
      if (selection?.key != fallback ||
          (selection == null && fallback != null)) {
        final latest = changes.entries
            .where((entry) => galleryKey.hasMatch(entry.key))
            .fold<int>(selection?.modifiedAt ?? 0, (time, entry) {
              final revision = (entry.value as Map)['modifiedAt'] as int;
              return time > revision ? time : revision;
            });
        selection = AppearanceGallerySelection(
          key: fallback,
          modifiedAt: latest + 1,
        );
      }
    }
    images.remove(alias);
    if (selection != null) {
      final image = images[selection.key] as Map?;
      final previous = identical(selection, importedSelection)
          ? oldSelectionChange as Map?
          : changes[alias] as Map? ?? oldSelectionChange as Map?;
      if (image != null) images[alias] = image;
      changes[alias] = {
        'modifiedAt': selection.modifiedAt,
        'deleted': image == null,
        'digest':
            image?['sha256'] ??
            previous?['digest'] ??
            '0000000000000000000000000000000000000000000000000000000000000000',
        'size': image == null
            ? (previous?['size'] ?? 0)
            : (changes[selection.key] as Map)['size'],
      };
    }
    final referenced = images.values
        .map((value) => (value as Map)['file'])
        .toSet();
    await for (final file in nextFile.parent.list()) {
      if (p.basename(file.path) != 'manifest.json' &&
          !referenced.contains(p.basename(file.path))) {
        await file.delete();
      }
    }
    if ({...images.keys, ...changes.keys}.any(FolderCoverIdentity.valid))
      next['version'] = 2;
    next['images'] = images;
    next['changes'] = changes;
    await nextFile.writeAsString(jsonEncode(next));
    final merged = await validator.prepareBackupRestore(target);
    await merged?.finish(committed: false);
  } finally {
    await plan?.finish(committed: false);
    validator.paths.dispose();
    if (await validation.exists()) await validation.delete(recursive: true);
  }
}

Future<void> _mergeVideoIndex(
  Directory local,
  Directory incoming,
  Directory target,
) async {
  final relative = p.join(VideoLocalResources.directoryName, 'index.json');
  final oldFile = File(p.join(local.path, relative)),
      nextFile = File(p.join(incoming.path, relative));
  if (!await nextFile.exists()) return;
  final next = await _json(nextFile, limit: 24 * 1024 * 1024);
  final old = await oldFile.exists()
      ? await _json(oldFile, limit: 24 * 1024 * 1024)
      : null;
  final rows = <String, dynamic>{
    for (final row in old?['resources'] as List? ?? [])
      (row as Map)['resourceId'] as String: row,
  };
  for (final row in next['resources'] as List) {
    rows.putIfAbsent((row as Map)['resourceId'] as String, () => row);
  }
  final output = File(p.join(target.path, relative));
  await output.parent.create(recursive: true);
  await output.writeAsString(
    jsonEncode({...next, 'resources': rows.values.toList()}),
  );
  await VideoLocalResources.validateBackupDirectory(target);
}

Future<void> _copyTree(
  Directory source,
  Directory destination, {
  bool skipVideoIndex = false,
}) async {
  if (!await source.exists()) return;
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = p.relative(entity.path, from: source.path);
    if (skipVideoIndex &&
        relative == p.join(VideoLocalResources.directoryName, 'index.json')) {
      continue;
    }
    final target = p.join(destination.path, relative);
    if (entity is Link) throw const FormatException('Linked backup resource');
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
      continue;
    }
    if (entity is! File) throw const FormatException('Invalid backup resource');
    await File(target).parent.create(recursive: true);
    if (await File(target).exists()) {
      if (await entity.length() != await File(target).length() ||
          (await sha256.bind(entity.openRead()).first) !=
              (await sha256.bind(File(target).openRead()).first)) {
        throw const FormatException(
          'Downloaded file conflicts with local content',
        );
      }
    } else {
      await entity.copy(target);
    }
  }
}
