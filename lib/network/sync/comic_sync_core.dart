import 'package:zephyr/network/sync/sync_direction.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/config/global/global.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/comic_follow/comic_follow_merge.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

const String syncDataVersion = 'v1';

enum _VectorRelation { equal, leftDominates, rightDominates, conflict }

class ComicSyncCodec {
  const ComicSyncCodec({
    this.encode = ComicSyncCore.encodeEncryptedPayload,
    this.decode = ComicSyncCore.decodeEncryptedPayload,
  });
  final Future<List<int>> Function(List<int>) encode, decode;
}

abstract class ComicSyncRemoteAdapter {
  Future<void> testConnection();

  Future<void> ensureRemoteReady();

  Future<String> downloadRemoteMd5();

  Future<void> uploadRemoteMd5(String value);

  Future<List<String>> listRemoteDataFiles();

  Future<List<int>> downloadRemoteFile(String remotePath);

  Future<void> uploadRemoteFile(
    String remotePath,
    List<int> data, {
    String contentType,
  });

  Future<void> deleteRemoteFiles(List<String> remotePaths);
}

class ComicSyncCore {
  static String get syncRemoteRootName => SyncArchiveContext.currentRoot;

  static String get legacyDataRootName => appName;

  static String get legacySettingsRootName => '${appName}_setting';

  static String get comicMd5FileName => 'comic.md5';

  static String get settingsMd5FileName => 'settings.md5';

  static String buildComicDataFileName([int? timestamp]) {
    final ts = timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'comic_$ts.bin';
  }

  static String buildSettingsDataFileName([int? timestamp]) {
    final ts = timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'settings_$ts.bin';
  }

  static bool isComicDataFileName(String fileName) {
    return _comicDataRegex.hasMatch(fileName);
  }

  static bool isSettingsDataFileName(String fileName) {
    return _settingsDataRegex.hasMatch(fileName);
  }

  static int? extractComicTimestampFromRemotePath(String remotePath) {
    final fileName = extractFileName(remotePath);
    final match = _comicDataRegex.firstMatch(fileName);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  static int? extractSettingsTimestampFromRemotePath(String remotePath) {
    final fileName = extractFileName(remotePath);
    final match = _settingsDataRegex.firstMatch(fileName);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  static List<String> sortComicFilesByTimestampDesc(List<String> remotePaths) {
    final candidates = remotePaths.where((remotePath) {
      return isComicDataFileName(extractFileName(remotePath));
    }).toList();
    candidates.sort((a, b) {
      final aTs = extractComicTimestampFromRemotePath(a) ?? -1;
      final bTs = extractComicTimestampFromRemotePath(b) ?? -1;
      if (aTs == bTs) {
        return b.compareTo(a);
      }
      return bTs.compareTo(aTs);
    });
    return candidates;
  }

  static List<String> sortSettingsFilesByTimestampDesc(
    List<String> remotePaths,
  ) {
    final candidates = remotePaths.where((remotePath) {
      return isSettingsDataFileName(extractFileName(remotePath));
    }).toList();
    candidates.sort((a, b) {
      final aTs = extractSettingsTimestampFromRemotePath(a) ?? -1;
      final bTs = extractSettingsTimestampFromRemotePath(b) ?? -1;
      if (aTs == bTs) {
        return b.compareTo(a);
      }
      return bTs.compareTo(aTs);
    });
    return candidates;
  }

  static String calculateMd5(List<int> data) {
    return md5.convert(data).toString();
  }

  static Map<String, dynamic> captureData() {
    final favorites = objectbox.unifiedFavoriteBox.getAll();
    favorites.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final histories = objectbox.unifiedHistoryBox.getAll();
    histories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final follows = objectbox.comicFollowBox.getAll();
    follows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final readPreferences = objectbox.comicReadPreferenceBox.getAll();
    readPreferences.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final folders = objectbox.comicFolderBox
        .getAll()
        .where(
          (f) =>
              f.type == ComicFolderType.favorite ||
              f.type == ComicFolderType.history,
        )
        .toList();
    final links = objectbox.comicLinkBox
        .getAll()
        .where(
          (l) =>
              l.type == ComicFolderType.favorite ||
              l.type == ComicFolderType.history,
        )
        .toList();

    final data = {
      'version': syncDataVersion,
      'favorites': favorites.map(_archiveComicRecord).toList(),
      'histories': histories.map(_archiveComicRecord).toList(),
      'follows': follows.map(_archiveComicRecord).toList(),
      'folders': folders.map((e) => _stripLocalId(e.toJson())).toList(),
      'links': links.map((e) => _stripLocalId(e.toJson())).toList(),
      'readPreferences': readPreferences.map(_archiveComicRecord).toList(),
    };

    return data;
  }

  static Future<List<int>> buildCompressedPayload({
    ComicSyncCodec codec = const ComicSyncCodec(),
  }) => codec.encode(utf8.encode(jsonEncode(captureData())));

  static Future<Map<String, dynamic>> decodeCompressedPayload(
    List<int> encryptedCompressedBytes, {
    ComicSyncCodec codec = const ComicSyncCodec(),
  }) async {
    final raw = await codec.decode(encryptedCompressedBytes);
    final jsonString = utf8.decode(raw);
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    validatePayload(data);
    return data;
  }

  static void validatePayload(Map<String, dynamic> data) {
    SyncPayloadCompatibility.version(data, 'version', {
      'v1',
    }, legacyMissing: true);
    SyncPayloadCompatibility.keys(data, {
      'version',
      'favorites',
      'histories',
      'follows',
      'folders',
      'links',
      'readPreferences',
    });
    void rows(
      String name,
      Map<String, dynamic> Function(Map<String, dynamic>) normalize, {
      Set<int>? supportedSchemas,
      Set<String> legacyKeys = const {},
    }) {
      if (data[name] == null) return;
      if (data[name] is! List) throw const SyncCompatibilityException();
      for (final raw in data[name] as List) {
        if (raw is! Map<String, dynamic> ||
            (supportedSchemas != null &&
                !supportedSchemas.contains(raw['schemaVersion']))) {
          throw const SyncCompatibilityException();
        }
        try {
          SyncPayloadCompatibility.keys(raw, {
            ...normalize(raw).keys,
            ...legacyKeys,
          });
        } catch (_) {
          throw const SyncCompatibilityException();
        }
      }
    }

    // The shipped collection/history writers and v1-to-v2 migration use v2.
    // This is the entity format, independent of the outer archive version.
    rows(
      'favorites',
      (row) => UnifiedComicFavorite.fromJson(row).toJson(),
      supportedSchemas: {1, 2},
    );
    rows(
      'histories',
      (row) => UnifiedComicHistory.fromJson(row).toJson(),
      supportedSchemas: {1, 2},
    );
    rows(
      'follows',
      (row) => ComicFollow.fromJson(row).toJson(),
      supportedSchemas: {1},
    );
    rows('folders', (row) => ComicFolder.fromJson(row).toJson());
    rows('links', (row) => ComicLink.fromJson(row).toJson());
    rows(
      'readPreferences',
      (row) => ComicReadPreference.fromJson(row).toJson(),
      // The model converts the shipped single-column format into overridesJson.
      legacyKeys: {'readMode'},
    );
  }

  static Future<List<int>> encodeEncryptedPayload(List<int> raw) async {
    final compressed = await compressExtreme(data: raw);
    final encrypted = _encryptBytes(compressed);
    return encrypted;
  }

  static Future<List<int>> decodeEncryptedPayload(
    List<int> encryptedCompressedBytes,
  ) async {
    if (BackupProtectionService.isProtectedBytes(encryptedCompressedBytes)) {
      BackupProtectionService.readProfileFromBytes(encryptedCompressedBytes);
      throw const BackupProtectionException('backup_locked');
    }
    final compressed = _decryptBytes(encryptedCompressedBytes);
    final raw = await decompressExtreme(data: compressed);
    return raw;
  }

  static int mergeUnifiedDataInIsolate(Store store, Map<String, dynamic> arg) {
    syncDeviceId = arg['_deviceId'] as String;
    return mergeUnifiedData(
      store,
      arg['_data'] as Map<String, dynamic>,
      excludedSources: Set<String>.from(
        arg['_excludedSources'] as List? ?? const [],
      ),
      preferenceDirection: SyncDirection.values.byName(
        arg['_preferenceDirection'] as String? ?? 'merge',
      ),
      participatingSources: arg['_participatingSources'] == null
          ? null
          : Set<String>.from(arg['_participatingSources'] as List),
    );
  }

  static String mergeUnifiedDataProjectionInIsolate(
    Store store,
    Map<String, dynamic> arg,
  ) {
    syncDeviceId = arg['_deviceId'] as String;
    final projection = <String, dynamic>{};
    mergeUnifiedData(
      store,
      arg['_data'] as Map<String, dynamic>,
      excludedSources: Set<String>.from(
        arg['_excludedSources'] as List? ?? const [],
      ),
      preferenceDirection: SyncDirection.values.byName(
        arg['_preferenceDirection'] as String? ?? 'merge',
      ),
      participatingSources: arg['_participatingSources'] == null
          ? null
          : Set<String>.from(arg['_participatingSources'] as List),
      cloudProjection: projection,
    );
    return jsonEncode(projection);
  }

  static int mergeUnifiedData(
    Store store,
    Map<String, dynamic> data, {
    Set<String>? excludedSources,
    Set<String>? participatingSources,
    Map<String, dynamic>? cloudProjection,
    SyncDirection preferenceDirection = SyncDirection.merge,
  }) {
    excludedSources ??= participatingSources == null
        ? LocalPluginInstallationState.instance.excludedSources(
            PluginDataScope.records,
          )
        : <String>{};
    validatePayload(data);
    final favoriteBox = store.box<UnifiedComicFavorite>();
    final historyBox = store.box<UnifiedComicHistory>();
    final followBox = store.box<ComicFollow>();
    final folderBox = store.box<ComicFolder>();
    final linkBox = store.box<ComicLink>();
    final readPreferenceBox = store.box<ComicReadPreference>();

    final localFavorites = favoriteBox.getAll();
    final localHistories = historyBox.getAll();
    final localFollows = followBox.getAll();
    var localFolders = folderBox.getAll();
    var localLinks = linkBox.getAll();
    final localReadPreferences = readPreferenceBox.getAll();
    if (participatingSources != null) {
      excludedSources = {
        ...excludedSources,
        ...comicPayloadSources(data).difference(participatingSources),
        ...localFavorites
            .map((row) => row.source)
            .where((source) => !participatingSources.contains(source)),
        ...localHistories
            .map((row) => row.source)
            .where((source) => !participatingSources.contains(source)),
        ...localFollows
            .map((row) => row.source)
            .where((source) => !participatingSources.contains(source)),
        ...localReadPreferences
            .map((row) => row.source)
            .where((source) => !participatingSources.contains(source)),
      };
    }

    final favoriteRows = _parseJsonList(data['favorites']);
    final historyRows = _parseJsonList(data['histories']);
    final followRows = _parseJsonList(data['follows']);
    final preferenceRows = _parseJsonList(data['readPreferences']);
    final cloudFavorites = favoriteRows
        .map(UnifiedComicFavorite.fromJson)
        .toList();
    final cloudHistories = historyRows
        .map(UnifiedComicHistory.fromJson)
        .toList();
    final cloudFollows = followRows.map(ComicFollow.fromJson).toList();
    var cloudFolders = _parseJsonList(
      data['folders'],
    ).map(ComicFolder.fromJson).toList();
    var cloudLinks = _parseJsonList(
      data['links'],
    ).map(ComicLink.fromJson).toList();
    final cloudReadPreferences = preferenceRows
        .map(ComicReadPreference.fromJson)
        .toList();

    // 旧数据可能没有 syncId，先兜底补一遍，确保后续按 syncId 合并能正常进行。
    for (final folder in [...localFolders, ...cloudFolders]) {
      if (folder.syncId.isEmpty) {
        folder.syncId = const Uuid().v4();
      }
    }

    final mergedFavorites = mergeByUniqueKey(
      localFavorites,
      cloudFavorites,
      keyOf: (item) => item.uniqueKey,
      updatedAtOf: (item) => item.updatedAt,
    );
    final mergedHistories = mergeByUniqueKey(
      localHistories,
      cloudHistories,
      keyOf: (item) => item.uniqueKey,
      updatedAtOf: (item) => item.updatedAt,
    );
    final mergedFollows = mergeByUniqueKey(
      localFollows,
      cloudFollows,
      keyOf: (item) => item.uniqueKey,
      updatedAtOf: (item) => item.updatedAt,
      reconcile: mergeComicFollowRecord,
    );
    // 单本阅读偏好：unix 时间戳更大的保留，相等保留本地。
    final mergedReadPreferences = preferenceDirection == SyncDirection.merge
        ? mergeByUniqueKey(
            localReadPreferences,
            cloudReadPreferences,
            keyOf: (item) => item.uniqueKey,
            updatedAtOf: (item) => item.updatedAt,
          )
        : preferenceDirection == SyncDirection.restore
        ? <String, ComicReadPreference>{
            for (final row in localReadPreferences) row.uniqueKey: row,
            for (final row in cloudReadPreferences) row.uniqueKey: row,
          }.values.toList()
        : List<ComicReadPreference>.of(localReadPreferences);
    var mergedFolders = _mergeByVersionVector<ComicFolder>(
      localFolders,
      cloudFolders,
      keyOf: (item) => item.syncId,
      vectorJsonOf: (item) => item.versionVectorJson,
      updatedAtMsOf: (item) => item.updatedAt,
      deterministicTieBreakerOf: (item) =>
          jsonEncode(_stripLocalId(item.toJson())),
      updateOf: (item, vector, updatedAt) {
        item.versionVectorJson = vector;
        item.updatedAt = updatedAt;
      },
    );

    // 先把 folder 的 uniqueKey 索引建起来，给 link 补 folderSyncId 用。
    var folderByUniqueKey = <String, ComicFolder>{
      for (final folder in mergedFolders) folder.uniqueKey: folder,
    };

    // 补齐旧版 folder 的 parentSyncId（旧版 uniqueKey 为 path|type）。
    for (final folder in mergedFolders) {
      _ensureFolderParentSyncId(folder, folder.typeData, folderByUniqueKey);
    }
    // parentSyncId 可能已更新，重建索引。
    folderByUniqueKey = {
      for (final folder in mergedFolders) folder.uniqueKey: folder,
    };

    for (final link in [...localLinks, ...cloudLinks]) {
      _ensureLinkFolderSyncId(link, folderByUniqueKey);
    }

    var mergedLinks = _mergeByVersionVector<ComicLink>(
      localLinks,
      cloudLinks,
      keyOf: (item) =>
          '${item.comicUniqueKey}|${item.folderSyncId ?? ''}|${item.typeData}',
      vectorJsonOf: (item) => item.versionVectorJson,
      updatedAtMsOf: (item) => item.updatedAt,
      deterministicTieBreakerOf: (item) =>
          jsonEncode(_stripLocalId(item.toJson())),
      updateOf: (item, vector, updatedAt) {
        item.versionVectorJson = vector;
        item.updatedAt = updatedAt;
      },
    );

    // 将旧版 path|type 格式的 folder uniqueKey 规范化为
    // parentSyncId|name|type，保证后续本地查询/冲突处理一致。
    _normalizeFolderUniqueKeys(mergedFolders);

    // 处理相同 uniqueKey 但不同 syncId 的文件夹冲突：选一个 winner，
    // 内容合并进去，输家从列表中移除。
    _resolveFolderUniqueKeyConflicts(mergedFolders, mergedLinks);

    // 先修复链接指向：可能复活被 tombstone 的父文件夹，或补全旧版路径链。
    _repairOrphanLinks(mergedFolders, mergedLinks);

    // 再处理仍孤儿的 active folder：把 parent 已删除/不存在的子树 tombstone，
    // 同时清理指向这些文件夹的 active link。
    _repairOrphanFolders(mergedFolders, mergedLinks);

    // 兜底：从旧版本同步过来的记录可能没有 syncId，在这里补齐。
    for (final folder in mergedFolders) {
      if (folder.syncId.isEmpty) {
        folder.syncId = const Uuid().v4();
      }
    }

    for (final item in mergedFavorites) {
      item.id = 0;
    }
    for (final item in mergedHistories) {
      item.id = 0;
    }
    for (final item in mergedFollows) {
      item.id = 0;
    }
    for (final item in mergedReadPreferences) {
      item.id = 0;
    }
    for (final item in mergedFolders) {
      item.id = 0;
    }
    for (final item in mergedLinks) {
      item.id = 0;
    }

    mergedFavorites.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    mergedHistories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    mergedFollows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    mergedReadPreferences.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    cloudProjection?.addAll({
      'version': syncDataVersion,
      'favorites': _projectArchiveRecords(
        mergedFavorites,
        cloudFavorites,
        favoriteRows,
      ),
      'histories': _projectArchiveRecords(
        mergedHistories,
        cloudHistories,
        historyRows,
      ),
      'follows': _projectArchiveRecords(
        mergedFollows,
        cloudFollows,
        followRows,
      ),
      'readPreferences': _projectArchiveRecords(
        preferenceDirection == SyncDirection.recordsOnly ||
                preferenceDirection == SyncDirection.restore
            ? cloudReadPreferences
            : preferenceDirection == SyncDirection.upload
            ? <String, ComicReadPreference>{
                for (final row in cloudReadPreferences) row.uniqueKey: row,
                for (final row in mergedReadPreferences) row.uniqueKey: row,
              }.values
            : mergedReadPreferences,
        cloudReadPreferences,
        preferenceRows,
      ),
      'folders': mergedFolders
          .where((row) => row.typeData != 'download')
          .map((row) => _stripLocalId(row.toJson()))
          .toList(),
      'links': mergedLinks
          .where((row) => row.typeData != 'download')
          .map((row) => _stripLocalId(row.toJson()))
          .toList(),
    });
    if (participatingSources != null && cloudProjection != null) {
      final projected = projectPluginComicData(
        cloudProjection,
        data,
        participatingSources,
      );
      cloudProjection
        ..clear()
        ..addAll(projected);
    }
    final blockedKeys = <String>{
      for (final row in mergedFavorites)
        if (excludedSources.contains(row.source)) row.uniqueKey,
      for (final row in mergedHistories)
        if (excludedSources.contains(row.source)) row.uniqueKey,
      for (final row in mergedFollows)
        if (excludedSources.contains(row.source)) row.uniqueKey,
      for (final row in mergedReadPreferences)
        if (excludedSources.contains(row.source)) row.uniqueKey,
    };
    final visibleFavorites = [
      ...mergedFavorites.where((row) => !excludedSources!.contains(row.source)),
      ...localFavorites.where((row) => excludedSources!.contains(row.source)),
    ];
    final visibleHistories = [
      ...mergedHistories.where((row) => !excludedSources!.contains(row.source)),
      ...localHistories.where((row) => excludedSources!.contains(row.source)),
    ];
    final visibleFollows = [
      ...mergedFollows.where((row) => !excludedSources!.contains(row.source)),
      ...localFollows.where((row) => excludedSources!.contains(row.source)),
    ];
    final visibleReadPreferences = [
      ...mergedReadPreferences.where(
        (row) => !excludedSources!.contains(row.source),
      ),
      ...localReadPreferences.where(
        (row) => excludedSources!.contains(row.source),
      ),
    ];
    bool blockedLink(ComicLink row) =>
        row.typeData != 'download' && blockedKeys.contains(row.comicUniqueKey);
    mergedLinks = [
      ...mergedLinks.where((row) => !blockedLink(row)),
      ...localLinks.where(blockedLink),
    ];

    favoriteBox.removeAll();
    historyBox.removeAll();
    followBox.removeAll();
    folderBox.removeAll();
    linkBox.removeAll();
    readPreferenceBox.removeAll();

    if (visibleFavorites.isNotEmpty) {
      favoriteBox.putMany(visibleFavorites);
    }
    if (visibleHistories.isNotEmpty) {
      historyBox.putMany(visibleHistories);
    }
    if (visibleFollows.isNotEmpty) {
      followBox.putMany(visibleFollows);
    }
    if (visibleReadPreferences.isNotEmpty) {
      readPreferenceBox.putMany(visibleReadPreferences);
    }
    if (mergedFolders.isNotEmpty) {
      folderBox.putMany(mergedFolders);
    }
    if (mergedLinks.isNotEmpty) {
      linkBox.putMany(mergedLinks);
    }

    return mergedFavorites.length +
        mergedHistories.length +
        mergedFollows.length +
        mergedFolders.length +
        mergedLinks.length +
        mergedReadPreferences.length;
  }

  static String extractFileName(String remotePath) {
    final normalized = remotePath.replaceAll('\\', '/');
    final segments = normalized.split('/').where((item) => item.isNotEmpty);
    if (segments.isEmpty) {
      return '';
    }
    return segments.last;
  }

  static String normalizeRemotePathNoLeadingSlash(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  static bool isLegacyRemotePath(String path) {
    final normalized = normalizeRemotePathNoLeadingSlash(path);
    return normalized == legacyDataRootName ||
        normalized.startsWith('$legacyDataRootName/') ||
        normalized == legacySettingsRootName ||
        normalized.startsWith('$legacySettingsRootName/');
  }

  static bool isSyncRootPath(String path) {
    final normalized = normalizeRemotePathNoLeadingSlash(path);
    return normalized == syncRemoteRootName ||
        normalized.startsWith('$syncRemoteRootName/');
  }

  static List<Map<String, dynamic>> _parseJsonList(Object? value) {
    final list = (value as List? ?? const []);
    return list
        .map((item) {
          if (item is Map<String, dynamic>) {
            return Map<String, dynamic>.from(item);
          }
          if (item is Map) {
            return item.map((key, val) => MapEntry(key.toString(), val));
          }
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Used by cloud and file merges. Equal timestamps retain the local row.
  static List<T> mergeByUniqueKey<T>(
    List<T> local,
    Iterable<T> incoming, {
    required String Function(T item) keyOf,
    required DateTime Function(T item) updatedAtOf,
    T Function(T local, T incoming)? reconcile,
  }) {
    final merged = <String, T>{for (final item in local) keyOf(item): item};
    for (final incomingItem in incoming) {
      final key = keyOf(incomingItem);
      final localItem = merged[key];
      if (localItem != null && reconcile != null) {
        merged[key] = reconcile(localItem, incomingItem);
      } else if (localItem == null ||
          updatedAtOf(incomingItem).isAfter(updatedAtOf(localItem))) {
        merged[key] = incomingItem;
      }
    }
    return merged.values.toList();
  }

  // ==================== 版本向量合并（ComicFolder / ComicLink） ====================

  static List<T> _mergeByVersionVector<T extends Object>(
    List<T> local,
    List<T> cloud, {
    required String Function(T item) keyOf,
    required String Function(T item) vectorJsonOf,
    required int Function(T item) updatedAtMsOf,
    required String Function(T item) deterministicTieBreakerOf,
    required void Function(T item, String newVectorJson, int newUpdatedAtMs)
    updateOf,
  }) {
    final localMap = {for (final item in local) keyOf(item): item};
    final cloudMap = {for (final item in cloud) keyOf(item): item};
    final merged = <T>[];
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final key in {...localMap.keys, ...cloudMap.keys}) {
      final localItem = localMap[key];
      final cloudItem = cloudMap[key];
      if (localItem == null) {
        merged.add(cloudItem!);
        continue;
      }
      if (cloudItem == null) {
        merged.add(localItem);
        continue;
      }

      final localVector = _parseVersionVector(vectorJsonOf(localItem));
      final cloudVector = _parseVersionVector(vectorJsonOf(cloudItem));
      final relation = _compareVersionVectors(localVector, cloudVector);

      switch (relation) {
        case _VectorRelation.equal:
          // 向量相等但内容可能不同（例如旧数据默认向量、并发巧合）。
          // 用 updatedAt + 确定性内容 tie-breaker 选出唯一 winner，
          // 并提升版本向量，确保两端收敛到同一结果。
          final localUpdatedAt = updatedAtMsOf(localItem);
          final cloudUpdatedAt = updatedAtMsOf(cloudItem);
          if (localUpdatedAt == cloudUpdatedAt &&
              deterministicTieBreakerOf(localItem) ==
                  deterministicTieBreakerOf(cloudItem)) {
            // 内容和 updatedAt 都完全相同：真正的 identical，无需 bump。
            merged.add(localItem);
            break;
          }
          final winner = _resolveEqualVectorConflict(
            localItem,
            cloudItem,
            updatedAtMsOf: updatedAtMsOf,
            deterministicTieBreakerOf: deterministicTieBreakerOf,
          );
          final loser = identical(winner, localItem) ? cloudItem : localItem;
          final winnerVector = _parseVersionVector(vectorJsonOf(winner));
          final loserVector = _parseVersionVector(vectorJsonOf(loser));
          final mergedVector = _mergeVectors(winnerVector, loserVector);
          final bumpedVector = _bumpVector(mergedVector);
          updateOf(winner, _encodeVersionVector(bumpedVector), now);
          merged.add(winner);
        case _VectorRelation.leftDominates:
          merged.add(localItem);
        case _VectorRelation.rightDominates:
          merged.add(cloudItem);
        case _VectorRelation.conflict:
          final localUpdatedAt = updatedAtMsOf(localItem);
          final cloudUpdatedAt = updatedAtMsOf(cloudItem);
          final T winner;
          if (localUpdatedAt == cloudUpdatedAt) {
            final localTie = deterministicTieBreakerOf(localItem);
            final cloudTie = deterministicTieBreakerOf(cloudItem);
            winner = localTie.compareTo(cloudTie) >= 0 ? localItem : cloudItem;
          } else {
            winner = localUpdatedAt > cloudUpdatedAt ? localItem : cloudItem;
          }
          final loser = identical(winner, localItem) ? cloudItem : localItem;
          final winnerVector = _parseVersionVector(vectorJsonOf(winner));
          final loserVector = _parseVersionVector(vectorJsonOf(loser));
          final mergedVector = _mergeVectors(winnerVector, loserVector);
          final bumpedVector = _bumpVector(mergedVector);
          updateOf(winner, _encodeVersionVector(bumpedVector), now);
          merged.add(winner);
      }
    }
    return merged;
  }

  static T _resolveEqualVectorConflict<T>(
    T localItem,
    T cloudItem, {
    required int Function(T item) updatedAtMsOf,
    required String Function(T item) deterministicTieBreakerOf,
  }) {
    final localUpdatedAt = updatedAtMsOf(localItem);
    final cloudUpdatedAt = updatedAtMsOf(cloudItem);
    if (localUpdatedAt != cloudUpdatedAt) {
      return localUpdatedAt > cloudUpdatedAt ? localItem : cloudItem;
    }
    // updatedAt 也相同：用内容的确定性序作为最终 tie-breaker。
    final localTie = deterministicTieBreakerOf(localItem);
    final cloudTie = deterministicTieBreakerOf(cloudItem);
    return localTie.compareTo(cloudTie) >= 0 ? localItem : cloudItem;
  }

  static Map<String, int> _parseVersionVector(String json) {
    if (json.trim().isEmpty) return <String, int>{};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return <String, int>{};
    }
  }

  static String _encodeVersionVector(Map<String, int> vector) {
    return jsonEncode(vector);
  }

  static _VectorRelation _compareVersionVectors(
    Map<String, int> a,
    Map<String, int> b,
  ) {
    final keys = {...a.keys, ...b.keys};
    var leftGreater = false;
    var rightGreater = false;
    for (final key in keys) {
      final av = a[key] ?? 0;
      final bv = b[key] ?? 0;
      if (av > bv) leftGreater = true;
      if (bv > av) rightGreater = true;
    }
    if (!leftGreater && !rightGreater) return _VectorRelation.equal;
    if (leftGreater && !rightGreater) return _VectorRelation.leftDominates;
    if (rightGreater && !leftGreater) return _VectorRelation.rightDominates;
    return _VectorRelation.conflict;
  }

  static Map<String, int> _mergeVectors(
    Map<String, int> a,
    Map<String, int> b,
  ) {
    final keys = {...a.keys, ...b.keys};
    return {for (final key in keys) key: max(a[key] ?? 0, b[key] ?? 0)};
  }

  static Map<String, int> _bumpVector(Map<String, int> vector) {
    final copy = Map<String, int>.from(vector);
    copy[syncDeviceId] = (copy[syncDeviceId] ?? 0) + 1;
    return copy;
  }

  static String _parentFolderPath(String path) {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) return '';
    return trimmed.substring(0, index);
  }

  static String _linkUniqueKey(
    String comicUniqueKey,
    String? folderSyncId,
    String typeData,
  ) {
    return '$comicUniqueKey|${folderSyncId ?? ''}|$typeData';
  }

  /// 从旧版 folder uniqueKey（path|type）中解析 path。
  static String? _folderPathFromUniqueKey(String uniqueKey, String typeData) {
    final suffix = '|$typeData';
    if (!uniqueKey.endsWith(suffix)) return null;
    return uniqueKey.substring(0, uniqueKey.length - suffix.length);
  }

  /// 从旧版 link uniqueKey（comic|folderPath|type）中解析 folderPath。
  /// 若无法解析或不是旧格式，返回 null。
  static String? _folderPathFromLinkUniqueKey(String uniqueKey) {
    final lastPipe = uniqueKey.lastIndexOf('|');
    if (lastPipe <= 0) return null;
    final secondLastPipe = uniqueKey.lastIndexOf('|', lastPipe - 1);
    if (secondLastPipe < 0) return null;
    final folderPath = uniqueKey.substring(secondLastPipe + 1, lastPipe);
    // 旧格式 folderPath 以 '/' 开头；新格式为 syncId（UUID），不用于路径。
    return folderPath.startsWith('/') ? folderPath : null;
  }

  /// 收集 [rootSyncId] 下所有后代文件夹的 syncId（包含自身）。
  static Set<String> _collectSubtreeSyncIds(
    String rootSyncId,
    List<ComicFolder> folders,
    String typeData,
  ) {
    final childrenByParent = <String, List<ComicFolder>>{};
    for (final folder in folders) {
      if (folder.typeData != typeData) continue;
      childrenByParent
          .putIfAbsent(folder.parentSyncId ?? '', () => [])
          .add(folder);
    }
    final result = <String>{rootSyncId};
    final queue = [rootSyncId];
    while (queue.isNotEmpty) {
      final parentId = queue.removeLast();
      for (final child in childrenByParent[parentId] ?? const []) {
        if (result.add(child.syncId)) queue.add(child.syncId);
      }
    }
    return result;
  }

  /// 将 folder uniqueKey 规范化为 parentSyncId|name|type。
  static void _normalizeFolderUniqueKeys(List<ComicFolder> folders) {
    for (final folder in folders) {
      folder.uniqueKey =
          '${folder.parentSyncId ?? ''}|${folder.name}|${folder.typeData}';
    }
  }

  static void _ensureFolderParentSyncId(
    ComicFolder folder,
    String typeData,
    Map<String, ComicFolder> folderByUniqueKey,
  ) {
    if (folder.parentSyncId != null && folder.parentSyncId!.isNotEmpty) return;
    // 旧版数据 uniqueKey 为 path|type，可从中反推出 parentSyncId。
    if (!folder.uniqueKey.startsWith('/')) return;
    final path = _folderPathFromUniqueKey(folder.uniqueKey, typeData);
    if (path == null || path.isEmpty) return;
    final parentPath = _parentFolderPath(path);
    if (parentPath.isEmpty) return;
    final parent = folderByUniqueKey['$parentPath|$typeData'];
    if (parent != null && parent.deletedAt == null) {
      folder.parentSyncId = parent.syncId;
    }
  }

  static void _ensureLinkFolderSyncId(
    ComicLink link,
    Map<String, ComicFolder> folderByUniqueKey,
  ) {
    if (link.folderSyncId != null && link.folderSyncId!.isNotEmpty) return;
    final folderPath = _folderPathFromLinkUniqueKey(link.uniqueKey);
    if (folderPath == null || folderPath.isEmpty) return;
    final folder = folderByUniqueKey['$folderPath|${link.typeData}'];
    if (folder != null) {
      link.folderSyncId = folder.syncId;
    }
  }

  /// 处理同一个 parentSyncId|name|type（或旧版 path|type）下存在多个 syncId
  /// 的文件夹冲突。
  ///
  /// 对每一组 uniqueKey 相同的文件夹（无论 active 还是 tombstone），
  /// 按版本向量 / LWW 选一个 winner：
  /// - winner 是 active：把输家的直接链接迁到 winner，输家从列表中移除。
  /// - winner 是 tombstone：把输家（及其子树）tombstone，并清理对应链接。
  static void _resolveFolderUniqueKeyConflicts(
    List<ComicFolder> folders,
    List<ComicLink> links,
  ) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final keyMap = <String, List<ComicFolder>>{};
    for (final folder in folders) {
      keyMap.putIfAbsent(folder.uniqueKey, () => []).add(folder);
    }

    final conflicts = keyMap.values.where((group) => group.length > 1).toList();

    for (final group in conflicts) {
      if (group.length < 2) continue;

      var winner = group.first;
      for (final candidate in group.skip(1)) {
        winner = _resolveFolderConflict(winner, candidate);
      }

      if (winner.deletedAt != null) {
        // winner 是 tombstone：整棵子树都应该被清理。
        _tombstoneFolderSubtree(winner, folders, links, now);
      }

      for (final loser in group) {
        if (identical(loser, winner)) continue;
        if (winner.deletedAt != null) {
          _tombstoneFolderSubtree(loser, folders, links, now);
        } else {
          _mergeFolderLinks(loser, winner, folders, links, now);
        }
        folders.remove(loser);
      }
    }
  }

  static ComicFolder _resolveFolderConflict(ComicFolder a, ComicFolder b) {
    final aVector = _parseVersionVector(a.versionVectorJson);
    final bVector = _parseVersionVector(b.versionVectorJson);
    final relation = _compareVersionVectors(aVector, bVector);
    return switch (relation) {
      _VectorRelation.leftDominates => a,
      _VectorRelation.rightDominates => b,
      _VectorRelation.equal ||
      _VectorRelation.conflict => _resolveEqualVectorConflict(
        a,
        b,
        updatedAtMsOf: (folder) => folder.updatedAt,
        deterministicTieBreakerOf: (folder) => folder.syncId,
      ),
    };
  }

  /// 把 [loser] 文件夹下的直接子文件夹和链接合并到 [winner]，并提升 winner 的版本向量。
  static void _mergeFolderLinks(
    ComicFolder loser,
    ComicFolder winner,
    List<ComicFolder> folders,
    List<ComicLink> links,
    int now,
  ) {
    winner
      ..versionVectorJson = _encodeVersionVector(
        _bumpVector(
          _mergeVectors(
            _parseVersionVector(winner.versionVectorJson),
            _parseVersionVector(loser.versionVectorJson),
          ),
        ),
      )
      ..updatedAt = now;

    // 把 loser 的直接子文件夹挂到 winner 下。
    for (final child in folders) {
      if (child.deletedAt != null) continue;
      if (child.typeData != loser.typeData) continue;
      if (child.parentSyncId != loser.syncId) continue;
      child
        ..parentSyncId = winner.syncId
        ..updatedAt = now;
    }

    for (var i = links.length - 1; i >= 0; i--) {
      final link = links[i];
      if (link.deletedAt != null) continue;
      if (link.folderSyncId != loser.syncId) continue;

      final existingWinnerLink = links.firstWhereOrNull(
        (l) =>
            l.deletedAt == null &&
            l.folderSyncId == winner.syncId &&
            l.comicUniqueKey == link.comicUniqueKey &&
            l.typeData == link.typeData,
      );
      if (existingWinnerLink != null) {
        final kept = _resolveLinkConflict(existingWinnerLink, link, now);
        final removed = identical(kept, existingWinnerLink)
            ? link
            : existingWinnerLink;
        links.remove(removed);
        // 保留的 link 必须指向 winner 文件夹。
        if (kept.folderSyncId != winner.syncId) {
          kept
            ..folderSyncId = winner.syncId
            ..uniqueKey =
                '${kept.comicUniqueKey}|${winner.syncId}|${kept.typeData}';
        }
      } else {
        link
          ..folderSyncId = winner.syncId
          ..uniqueKey =
              '${link.comicUniqueKey}|${winner.syncId}|${link.typeData}'
          ..versionVectorJson = _encodeVersionVector(
            _bumpVector(_parseVersionVector(link.versionVectorJson)),
          )
          ..updatedAt = now;
      }
    }
  }

  /// 比较两个指向同一文件夹的 link，返回应该保留的那个，并提升其版本向量。
  /// 另一个 link 会被调用方从列表中移除，因此这里不设置 deletedAt。
  ///
  /// 向量相等或冲突且 updatedAt 相同时，使用内容 JSON 的确定性序作为
  /// tie-breaker，保证不同客户端对同一对记录能选出同一个 winner。
  static ComicLink _resolveLinkConflict(ComicLink a, ComicLink b, int now) {
    final aVector = _parseVersionVector(a.versionVectorJson);
    final bVector = _parseVersionVector(b.versionVectorJson);
    final relation = _compareVersionVectors(aVector, bVector);

    final ComicLink winner;
    final ComicLink loser;
    switch (relation) {
      case _VectorRelation.leftDominates:
        winner = a;
        loser = b;
      case _VectorRelation.rightDominates:
        winner = b;
        loser = a;
      case _VectorRelation.equal:
      case _VectorRelation.conflict:
        winner = _resolveEqualVectorConflict(
          a,
          b,
          updatedAtMsOf: (link) => link.updatedAt,
          deterministicTieBreakerOf: (link) =>
              jsonEncode(_stripLocalId(link.toJson())),
        );
        loser = identical(winner, a) ? b : a;
    }

    final mergedVector = _mergeVectors(
      _parseVersionVector(winner.versionVectorJson),
      _parseVersionVector(loser.versionVectorJson),
    );
    winner
      ..versionVectorJson = _encodeVersionVector(_bumpVector(mergedVector))
      ..updatedAt = now;
    return winner;
  }

  /// 把 [root] 文件夹及其子树全部 tombstone，并清理指向它们的 active link。
  static void _tombstoneFolderSubtree(
    ComicFolder root,
    List<ComicFolder> folders,
    List<ComicLink> links,
    int now,
  ) {
    final type = root.typeData;
    final subtreeSyncIds = _collectSubtreeSyncIds(root.syncId, folders, type);

    for (final folder in folders) {
      if (folder.typeData != type) continue;
      if (folder.deletedAt != null) continue;
      if (!subtreeSyncIds.contains(folder.syncId)) continue;
      folder
        ..deletedAt = now
        ..updatedAt = now
        ..versionVectorJson = _encodeVersionVector(
          _bumpVector(_parseVersionVector(folder.versionVectorJson)),
        );
    }

    for (final link in links) {
      if (link.deletedAt != null) continue;
      if (link.typeData != type) continue;
      if (link.folderSyncId != null &&
          subtreeSyncIds.contains(link.folderSyncId)) {
        link
          ..deletedAt = now
          ..updatedAt = now
          ..versionVectorJson = _encodeVersionVector(
            _bumpVector(_parseVersionVector(link.versionVectorJson)),
          );
      }
    }
  }

  /// 修复 active Folder 的 parentSyncId 指向已删除/不存在文件夹的孤儿问题。
  ///
  /// 父文件夹已不存在时，该子文件夹在 UI 上已不可达，直接 tombstone，并清理
  /// 指向这些文件夹的 active link。
  /// 递归处理，直到没有新的孤儿 folder 产生。
  static void _repairOrphanFolders(
    List<ComicFolder> folders,
    List<ComicLink> links,
  ) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final activeBySyncId = <String, ComicFolder>{};
    for (final folder in folders) {
      if (folder.syncId.isNotEmpty && folder.deletedAt == null) {
        activeBySyncId[folder.syncId] = folder;
      }
    }

    final newlyTombstoned = <String>{};
    while (true) {
      var changed = false;
      for (final folder in folders) {
        if (folder.deletedAt != null) continue;
        final parentId = folder.parentSyncId;
        if (parentId == null || parentId.isEmpty) continue;
        final parent = activeBySyncId[parentId];
        if (parent == null) {
          folder
            ..deletedAt = now
            ..updatedAt = now
            ..versionVectorJson = _encodeVersionVector(
              _bumpVector(_parseVersionVector(folder.versionVectorJson)),
            );
          activeBySyncId.remove(folder.syncId);
          newlyTombstoned.add(folder.syncId);
          changed = true;
        }
      }
      if (!changed) break;
    }

    // 同步清理指向刚被 tombstone 的文件夹的 active link。
    if (newlyTombstoned.isNotEmpty) {
      for (final link in links) {
        if (link.deletedAt != null) continue;
        final folderSyncId = link.folderSyncId;
        if (folderSyncId != null &&
            folderSyncId.isNotEmpty &&
            newlyTombstoned.contains(folderSyncId)) {
          link
            ..deletedAt = now
            ..updatedAt = now
            ..versionVectorJson = _encodeVersionVector(
              _bumpVector(_parseVersionVector(link.versionVectorJson)),
            );
        }
      }
    }
  }

  /// 修复 active Link 指向已删除/不存在文件夹的孤儿问题。
  ///
  /// 先按 folderSyncId 处理，再按路径补全祖先文件夹，最后补齐 link 的指向。
  static void _repairOrphanLinks(
    List<ComicFolder> folders,
    List<ComicLink> links,
  ) {
    final folderBySyncId = <String, ComicFolder>{};
    final childrenByParentSyncId = <String, List<ComicFolder>>{};
    for (final folder in folders) {
      if (folder.syncId.isNotEmpty) folderBySyncId[folder.syncId] = folder;
      childrenByParentSyncId
          .putIfAbsent(folder.parentSyncId ?? '', () => [])
          .add(folder);
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final link in links) {
      if (link.deletedAt != null) continue;

      // 1) 如果 link 有 folderSyncId，先按 syncId 处理 tombstone 冲突。
      final folderSyncId = link.folderSyncId;
      if (folderSyncId != null && folderSyncId.isNotEmpty) {
        final folder = folderBySyncId[folderSyncId];
        if (folder != null) {
          if (folder.deletedAt != null) {
            final linkVector = _parseVersionVector(link.versionVectorJson);
            final folderVector = _parseVersionVector(folder.versionVectorJson);
            final relation = _compareVersionVectors(linkVector, folderVector);
            final shouldResurrect = switch (relation) {
              _VectorRelation.leftDominates => true,
              _VectorRelation.conflict => link.updatedAt >= folder.updatedAt,
              _VectorRelation.equal => link.updatedAt >= folder.updatedAt,
              _VectorRelation.rightDominates => false,
            };
            if (shouldResurrect) {
              folder
                ..deletedAt = null
                ..versionVectorJson = _encodeVersionVector(
                  _bumpVector(_mergeVectors(linkVector, folderVector)),
                )
                ..updatedAt = now;
            } else {
              link
                ..deletedAt = now
                ..versionVectorJson = _encodeVersionVector(
                  _bumpVector(_mergeVectors(linkVector, folderVector)),
                )
                ..updatedAt = now;
              continue;
            }
          }
          link.uniqueKey = _linkUniqueKey(
            link.comicUniqueKey,
            folder.syncId,
            link.typeData,
          );
          continue;
        }
      }

      // 2) 从旧版 uniqueKey 中解析目标路径，并按路径补全祖先文件夹。
      final targetPath = _folderPathFromLinkUniqueKey(link.uniqueKey);
      if (targetPath == null || targetPath.isEmpty) {
        link
          ..folderSyncId = null
          ..uniqueKey = _linkUniqueKey(
            link.comicUniqueKey,
            null,
            link.typeData,
          );
        continue;
      }

      final segments = targetPath
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      String? currentParentSyncId;
      ComicFolder? deepestFolder;

      for (final segment in segments) {
        final siblings =
            childrenByParentSyncId[currentParentSyncId ?? ''] ?? const [];
        var folder = siblings.firstWhereOrNull(
          (f) => f.name == segment && f.typeData == link.typeData,
        );

        if (folder == null) {
          final linkVector = _parseVersionVector(link.versionVectorJson);
          final newSyncId = const Uuid().v4();
          folder = ComicFolder(
            syncId: newSyncId,
            parentSyncId: currentParentSyncId,
            uniqueKey: '${currentParentSyncId ?? ''}|$segment|${link.typeData}',
            name: segment,
            typeData: link.typeData,
            versionVectorJson: _encodeVersionVector(_bumpVector(linkVector)),
            createdAt: now,
            updatedAt: now,
          );
          folders.add(folder);
          folderBySyncId[newSyncId] = folder;
          childrenByParentSyncId
              .putIfAbsent(currentParentSyncId ?? '', () => [])
              .add(folder);
        } else if (folder.deletedAt != null) {
          final linkVector = _parseVersionVector(link.versionVectorJson);
          final folderVector = _parseVersionVector(folder.versionVectorJson);
          final relation = _compareVersionVectors(linkVector, folderVector);
          final shouldResurrect = switch (relation) {
            _VectorRelation.leftDominates => true,
            _VectorRelation.conflict => link.updatedAt >= folder.updatedAt,
            _VectorRelation.equal => link.updatedAt >= folder.updatedAt,
            _VectorRelation.rightDominates => false,
          };
          if (shouldResurrect) {
            folder
              ..deletedAt = null
              ..versionVectorJson = _encodeVersionVector(
                _bumpVector(_mergeVectors(linkVector, folderVector)),
              )
              ..updatedAt = now;
          } else {
            link
              ..deletedAt = now
              ..versionVectorJson = _encodeVersionVector(
                _bumpVector(_mergeVectors(linkVector, folderVector)),
              )
              ..updatedAt = now;
            break;
          }
        }
        currentParentSyncId = folder.syncId;
        deepestFolder = folder;
      }

      // 3) 最终补齐 link 的 folderSyncId 和 uniqueKey。
      if (link.deletedAt == null && deepestFolder != null) {
        link
          ..folderSyncId = deepestFolder.syncId
          ..uniqueKey = _linkUniqueKey(
            link.comicUniqueKey,
            deepestFolder.syncId,
            link.typeData,
          );
      }
    }
  }

  static List<int> _encryptBytes(List<int> bytes) {
    final key = Key.fromUtf8('XY!Ex3j3hP^BGPFanYEjBA!L!oD2kkCN');
    final iv = IV.fromUtf8('7qFwTxwH&iyuw35f');
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    return encrypter.encryptBytes(bytes, iv: iv).bytes;
  }

  static List<int> _decryptBytes(List<int> bytes) {
    final key = Key.fromUtf8('XY!Ex3j3hP^BGPFanYEjBA!L!oD2kkCN');
    final iv = IV.fromUtf8('7qFwTxwH&iyuw35f');
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    return encrypter.decryptBytes(Encrypted(Uint8List.fromList(bytes)), iv: iv);
  }

  static Map<String, dynamic> _stripLocalId(Map<String, dynamic> json) {
    json.remove('id');
    return json;
  }

  static Map<String, dynamic> _archiveComicRecord(Object record) {
    final (json, dates) = switch (record) {
      UnifiedComicFavorite row => (
        row.toJson(),
        {'createdAt': row.createdAt, 'updatedAt': row.updatedAt},
      ),
      UnifiedComicHistory row => (
        row.toJson(),
        {
          'createdAt': row.createdAt,
          'lastReadAt': row.lastReadAt,
          'updatedAt': row.updatedAt,
        },
      ),
      ComicFollow row => (
        row.toJson(),
        {
          'createdAt': row.createdAt,
          'updateTime': row.updateTime,
          'updatedAt': row.updatedAt,
        },
      ),
      ComicReadPreference row => (row.toJson(), {'updatedAt': row.updatedAt}),
      _ => throw ArgumentError.value(
        record,
        'record',
        'Expected a comic record',
      ),
    };
    return _stripLocalId(json)..addAll({
      for (final entry in dates.entries)
        entry.key: entry.value.toUtc().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> _projectArchiveRecords<T extends Object>(
    Iterable<T> records,
    List<T> remoteRecords,
    List<Map<String, dynamic>> remoteRows,
  ) {
    final remoteByKey = {
      for (var i = 0; i < remoteRows.length; i++)
        remoteRows[i]['uniqueKey']: (
          record: remoteRecords[i],
          row: remoteRows[i],
        ),
    };
    return records.map((record) {
      final next = _archiveComicRecord(record);
      final previous = remoteByKey[next['uniqueKey']];
      // Offset-less legacy dates cannot recover the original device timezone.
      // Preserve their spelling when publishing an otherwise unchanged record.
      if (previous != null &&
          (identical(record, previous.record) ||
              const MapEquality<String, dynamic>().equals(
                next,
                _archiveComicRecord(previous.record),
              ))) {
        for (final field in [
          'createdAt',
          'lastReadAt',
          'updateTime',
          'updatedAt',
        ]) {
          if (previous.row.containsKey(field))
            next[field] = previous.row[field];
        }
      }
      return next;
    }).toList();
  }

  static final RegExp _comicDataRegex = RegExp(r'^comic_(\d+)\.bin$');
  static final RegExp _settingsDataRegex = RegExp(r'^settings_(\d+)\.bin$');
}

Future<void> preflightComicSync(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec codec = const ComicSyncCodec(),
}) async {
  await readComicArchiveData(adapter, codec: codec);
}

Future<Map<String, dynamic>?> readComicArchiveData(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec codec = const ComicSyncCodec(),
}) async {
  await LocalPluginInstallationState.instance.load();
  final files = (await adapter.listRemoteDataFiles())
      .where(ComicSyncCore.isSyncRootPath)
      .toList();
  final digest = await adapter.downloadRemoteMd5();
  final remote = await _readCommittedComicSnapshot(adapter, files, digest);
  if (remote == null) return null;
  return ComicSyncCore.decodeCompressedPayload(remote.bytes, codec: codec);
}

Future<void> runComicSync(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec codec = const ComicSyncCodec(),
  SyncPluginParticipation? participation,
  SyncDirection preferenceDirection = SyncDirection.merge,
  void Function(Set<String> ids)? onRetiredFolders,
}) async {
  participation ??= await SyncPluginParticipation.capture();
  participation.check();
  await prepareScopedSyncArchive(adapter);
  await adapter.testConnection();
  await adapter.ensureRemoteReady();
  await preflightComicSync(adapter, codec: codec);
  await LocalPluginInstallationState.instance.load();
  final lifecycle = _ComicRecordCaptureGuard();

  final localPayload = await codec.encode(
    utf8.encode(
      jsonEncode(
        projectPluginComicData(
          {
            ...ComicSyncCore.captureData(),
            if (preferenceDirection == SyncDirection.recordsOnly ||
                preferenceDirection == SyncDirection.restore)
              'readPreferences': <dynamic>[],
          },
          const {},
          participation.sources,
        ),
      ),
    ),
  );
  final localMd5 = ComicSyncCore.calculateMd5(localPayload);

  final allRemoteFiles = await adapter.listRemoteDataFiles();
  final legacyFiles = allRemoteFiles
      .where(ComicSyncCore.isLegacyRemotePath)
      .toList();
  if (legacyFiles.isNotEmpty) {
    participation.check();
    lifecycle.check();
    await adapter.deleteRemoteFiles(legacyFiles);
  }

  final syncRootFiles = allRemoteFiles
      .where(ComicSyncCore.isSyncRootPath)
      .toList();
  final remoteMd5 = await adapter.downloadRemoteMd5();

  logger.d(
    '[sync][comic] precheck localMd5=$localMd5 remoteMd5=$remoteMd5 remoteFiles=${syncRootFiles.length}',
  );

  if (remoteMd5.isNotEmpty && remoteMd5 == localMd5) {
    logger.d('[sync][comic] decision=skip reason=md5_equal');
    await _cleanupRemoteComicFiles(
      adapter,
      allSyncRootFiles: allRemoteFiles,
      keepComicPath:
          '${ComicSyncCore.syncRemoteRootName}/${ComicSyncCore.buildComicDataFileName()}',
      beforeDelete: () {
        participation!.check();
        lifecycle.check();
      },
    );
    return;
  }

  final remoteData = await _readCommittedComicSnapshot(
    adapter,
    syncRootFiles,
    remoteMd5,
  );

  Map<String, dynamic>? cloudProjection;
  if (remoteData != null) {
    final cloudData = await ComicSyncCore.decodeCompressedPayload(
      remoteData.bytes,
      codec: codec,
    );
    participation.check();
    lifecycle.check();
    final knownFolderIds = <String>{
      for (final folder in objectbox.comicFolderBox.getAll())
        if (folder.syncId.isNotEmpty) folder.syncId,
      for (final raw in (cloudData['folders'] as List? ?? const []))
        if (raw is Map &&
            raw['syncId'] is String &&
            (raw['syncId'] as String).isNotEmpty)
          raw['syncId'] as String,
    };
    final mergeArg = <String, dynamic>{
      '_data': cloudData,
      '_preferenceDirection': preferenceDirection.name,
      '_deviceId': syncDeviceId,
      '_participatingSources': participation.sources.toList(),
      '_excludedSources': <String>[],
    };
    final projection = await objectbox.store
        .runInTransactionAsync<String, Map<String, dynamic>>(
          TxMode.write,
          ComicSyncCore.mergeUnifiedDataProjectionInIsolate,
          mergeArg,
        );
    cloudProjection = Map<String, dynamic>.from(jsonDecode(projection) as Map);
    knownFolderIds.removeAll(
      objectbox.comicFolderBox.getAll().map((folder) => folder.syncId),
    );
    if (knownFolderIds.isNotEmpty) onRetiredFolders?.call(knownFolderIds);
  }

  final currentPayload = cloudProjection == null
      ? await codec.encode(
          utf8.encode(
            jsonEncode(
              projectPluginComicData(
                {
                  ...ComicSyncCore.captureData(),
                  if (preferenceDirection == SyncDirection.recordsOnly ||
                      preferenceDirection == SyncDirection.restore)
                    'readPreferences': <dynamic>[],
                },
                const {},
                participation.sources,
              ),
            ),
          ),
        )
      : await codec.encode(utf8.encode(jsonEncode(cloudProjection)));
  final currentMd5 = ComicSyncCore.calculateMd5(currentPayload);
  if (currentMd5 == remoteMd5 && remoteData != null) {
    logger.d('[sync][comic] decision=skip_upload reason=post_merge_md5_equal');
    return;
  }

  final uploadFile = await _uploadComicPayload(
    adapter,
    currentPayload,
    currentMd5,
    beforeWrite: () {
      participation!.check();
      lifecycle.check();
    },
  );
  logger.d('[sync][comic] decision=upload file=$uploadFile md5=$currentMd5');

  await _cleanupRemoteComicFiles(
    adapter,
    allSyncRootFiles: await adapter.listRemoteDataFiles(),
    keepComicPath: '${ComicSyncCore.syncRemoteRootName}/$uploadFile',
    beforeDelete: () {
      participation!.check();
      lifecycle.check();
    },
  );
}

/// 手动上传：以本机漫画数据为准，直接覆盖云端（不做合并）。
Future<void> uploadComicData(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec codec = const ComicSyncCodec(),
  SyncPluginParticipation? participation,
}) async {
  participation ??= await SyncPluginParticipation.capture();
  final lifecycle = _ComicRecordCaptureGuard();
  await prepareScopedSyncArchive(adapter);
  await adapter.testConnection();
  await adapter.ensureRemoteReady();
  // Retain unsupported-format protection before selecting participating rows.
  final remote = await readComicArchiveData(adapter, codec: codec);
  participation.check();
  final localPayload = await codec.encode(
    utf8.encode(
      jsonEncode(
        projectPluginComicData(
          ComicSyncCore.captureData(),
          remote ?? const {},
          participation.sources,
        ),
      ),
    ),
  );
  final localMd5 = ComicSyncCore.calculateMd5(localPayload);
  final uploadFile = await _uploadComicPayload(
    adapter,
    localPayload,
    localMd5,
    beforeWrite: () {
      participation!.check();
      lifecycle.check();
    },
  );
  await _cleanupRemoteComicFiles(
    adapter,
    allSyncRootFiles: await adapter.listRemoteDataFiles(),
    keepComicPath: '${ComicSyncCore.syncRemoteRootName}/$uploadFile',
    beforeDelete: () {
      participation!.check();
      lifecycle.check();
    },
  );
}

/// 手动下载：把云端漫画数据合并到本机（不主动回传）。
///
/// 返回 false 表示云端尚未创建漫画归档。
Future<bool> downloadComicData(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec codec = const ComicSyncCodec(),
  SyncPluginParticipation? participation,
}) async {
  participation ??= await SyncPluginParticipation.capture();
  await prepareScopedSyncArchive(adapter);
  await adapter.testConnection();
  await adapter.ensureRemoteReady();

  final allRemoteFiles = await adapter.listRemoteDataFiles();
  final syncRootFiles = allRemoteFiles
      .where(ComicSyncCore.isSyncRootPath)
      .toList();
  final remoteMd5 = await adapter.downloadRemoteMd5();
  final remoteData = await _readCommittedComicSnapshot(
    adapter,
    syncRootFiles,
    remoteMd5,
  );
  if (remoteData == null) {
    logger.d('[sync][comic] manual_download skipped reason=remote_missing');
    return false;
  }

  final cloudData = await ComicSyncCore.decodeCompressedPayload(
    remoteData.bytes,
    codec: codec,
  );
  final mergeArg = <String, dynamic>{
    '_data': cloudData,
    '_deviceId': syncDeviceId,
    '_participatingSources': participation.sources.toList(),
    '_excludedSources': <String>[],
  };
  participation.check();
  await objectbox.store.runInTransactionAsync<int, Map<String, dynamic>>(
    TxMode.write,
    ComicSyncCore.mergeUnifiedDataInIsolate,
    mergeArg,
  );
  logger.d('[sync][comic] manual_download file=${remoteData.path}');
  return true;
}

Future<String> _uploadComicPayload(
  ComicSyncRemoteAdapter adapter,
  List<int> bytes,
  String digest, {
  required void Function() beforeWrite,
}) async {
  final occupied = {
    for (final path in await adapter.listRemoteDataFiles())
      if (ComicSyncCore.isSyncRootPath(path))
        ComicSyncCore.extractFileName(path),
  };
  var timestamp = DateTime.now().millisecondsSinceEpoch;
  var file = ComicSyncCore.buildComicDataFileName(timestamp);
  // An occupied path may still be referenced by the committed digest.
  while (occupied.contains(file)) {
    file = ComicSyncCore.buildComicDataFileName(++timestamp);
  }
  beforeWrite();
  await adapter.uploadRemoteFile(file, bytes);
  beforeWrite();
  await adapter.uploadRemoteMd5(digest);
  return file;
}

Future<void> _cleanupRemoteComicFiles(
  ComicSyncRemoteAdapter adapter, {
  required List<String> allSyncRootFiles,
  required String keepComicPath,
  void Function()? beforeDelete,
}) async {
  final syncRootFiles = allSyncRootFiles
      .where(ComicSyncCore.isSyncRootPath)
      .toList();
  final comicCandidates = syncRootFiles.where((path) {
    final fileName = ComicSyncCore.extractFileName(path);
    return ComicSyncCore.isComicDataFileName(fileName);
  }).toList();

  final sortedComic = ComicSyncCore.sortComicFilesByTimestampDesc(
    comicCandidates,
  );
  final keep = <String>{
    ComicSyncCore.normalizeRemotePathNoLeadingSlash(keepComicPath),
    '${ComicSyncCore.syncRemoteRootName}/${ComicSyncCore.comicMd5FileName}',
  };
  if (sortedComic.length > 3) {
    final active = await _selectLatestRemoteComicData(
      adapter,
      syncRootFiles,
      await adapter.downloadRemoteMd5(),
    );
    // Without the verified commit target, an older file may still be active.
    if (active == null) return;
    keep.add(ComicSyncCore.normalizeRemotePathNoLeadingSlash(active.path));
  }

  for (var i = 0; i < sortedComic.length; i++) {
    if (i < 3) {
      keep.add(ComicSyncCore.normalizeRemotePathNoLeadingSlash(sortedComic[i]));
    }
  }

  final stale = syncRootFiles.where((path) {
    final normalized = ComicSyncCore.normalizeRemotePathNoLeadingSlash(path);
    return !keep.contains(normalized) &&
        ComicSyncCore.isComicDataFileName(ComicSyncCore.extractFileName(path));
  }).toList();

  if (stale.isNotEmpty) {
    beforeDelete?.call();
    await adapter.deleteRemoteFiles(stale);
  }
}

class _ComicRecordCaptureGuard {
  _ComicRecordCaptureGuard()
    : epochs = {
        for (final source
            in LocalPluginInstallationState.instance.excludedSources(
              PluginDataScope.records,
            ))
          source: LocalPluginInstallationState.instance.installationEpoch(
            source,
          ),
      };
  final Map<String, int> epochs;
  void check() {
    final state = LocalPluginInstallationState.instance;
    final excluded = state.excludedSources(PluginDataScope.records);
    if (excluded.length != epochs.length ||
        excluded.any((source) => !epochs.containsKey(source)) ||
        epochs.entries.any(
          (entry) =>
              state.installationEpoch(entry.key) != entry.value ||
              state.isInstalling(entry.key),
        )) {
      throw const PluginLifecycleChanged();
    }
  }
}

Future<_RemoteFileData?> _readCommittedComicSnapshot(
  ComicSyncRemoteAdapter adapter,
  List<String> remotePaths,
  String remoteMd5,
) async {
  if (remoteMd5.isEmpty &&
      !remotePaths.any((path) {
        final name = ComicSyncCore.extractFileName(path);
        return name == ComicSyncCore.comicMd5FileName ||
            ComicSyncCore.isComicDataFileName(name);
      })) {
    return null;
  }
  final remote = await _selectLatestRemoteComicData(
    adapter,
    remotePaths,
    remoteMd5,
  );
  if (remote == null) throw const SyncCompatibilityException();
  return remote;
}

Future<_RemoteFileData?> _selectLatestRemoteComicData(
  ComicSyncRemoteAdapter adapter,
  List<String> remotePaths,
  String remoteMd5,
) async {
  final sortedFiles = ComicSyncCore.sortComicFilesByTimestampDesc(remotePaths);
  if (sortedFiles.isEmpty || remoteMd5.isEmpty) {
    return null;
  }

  for (final remotePath in sortedFiles) {
    try {
      final remoteBytes = await adapter.downloadRemoteFile(remotePath);
      final fileMd5 = ComicSyncCore.calculateMd5(remoteBytes);
      if (fileMd5 == remoteMd5) {
        return _RemoteFileData(path: remotePath, bytes: remoteBytes);
      }
      logger.w('远端漫画文件 md5 不匹配，尝试更旧版本: $remotePath');
    } catch (e) {
      logger.w('远端漫画文件下载失败，尝试更旧版本: $remotePath, error: $e');
    }
  }

  return null;
}

class _RemoteFileData {
  const _RemoteFileData({required this.path, required this.bytes});

  final String path;
  final List<int> bytes;
}
