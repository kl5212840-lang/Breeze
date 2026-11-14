import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show LocalStorageCommit_;
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_comic_file_removal.dart'
    show PluginRemovalFileMove;
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';

const _preferenceBeforeKeys = {
  LocalAppearanceImages.preferencesKey,
  VideoLibraryStore.prefsKey,
  VideoDownloadedDetails.durableStorageKey,
  PortablePreferences.journalKey,
};

bool _preferenceValue(dynamic value) =>
    value == null ||
    value is String ||
    value is bool ||
    value is num ||
    value is List && value.every((v) => v is String);

bool _validPreferenceBefore(dynamic key, dynamic value) {
  if (key is! String) return false;
  if (_preferenceBeforeKeys.contains(key) ||
      ComicChapterReadingProgress.ownsPreference(key)) {
    return value == null || value is String;
  }
  return PortablePreferences.owns(key) && _preferenceValue(value);
}

/// No exception text includes user data, paths, or submitted backup contents.
class LocalImportRecoveryFailed implements Exception {
  const LocalImportRecoveryFailed();
  @override
  String toString() => 'local_import_recovery_failed';
}

class _Table {
  _Table(this.name, this.read, this.parse);
  final String name;
  final List<Map<String, dynamic>> Function() read;
  final void Function(List<dynamic>, bool) parse;
}

Map<String, dynamic> _withUtcDates(Object? value, Map<String, dynamic> row) {
  // Read the typed instant before toJson loses its offset. Parsing a local
  // string again is ambiguous during a daylight-saving clock overlap.
  final Map<String, DateTime?> dates = switch (value) {
    BikaComicHistory v => {
      'updatedAt': v.updatedAt,
      'createdAt': v.createdAt,
      'history': v.history,
    },
    BikaComicDownload v => {
      'updatedAt': v.updatedAt,
      'createdAt': v.createdAt,
      'downloadTime': v.downloadTime,
    },
    JmFavorite v => {'history': v.history},
    JmHistory v => {'history': v.history},
    JmDownload v => {'downloadTime': v.downloadTime},
    UnifiedComicFavorite v => {
      'createdAt': v.createdAt,
      'updatedAt': v.updatedAt,
    },
    UnifiedComicHistory v => {
      'createdAt': v.createdAt,
      'lastReadAt': v.lastReadAt,
      'updatedAt': v.updatedAt,
    },
    UnifiedComicDownload v => {
      'createdAt': v.createdAt,
      'updatedAt': v.updatedAt,
      'downloadedAt': v.downloadedAt,
    },
    PluginInfo v => {
      'insertedAt': v.insertedAt,
      'updatedAt': v.updatedAt,
      'deletedAt': v.deletedAt,
    },
    ComicFollow v => {
      'updateTime': v.updateTime,
      'createdAt': v.createdAt,
      'updatedAt': v.updatedAt,
    },
    ComicReadPreference v => {'updatedAt': v.updatedAt},
    _ => const {},
  };
  for (final entry in dates.entries) {
    row[entry.key] = entry.value?.toUtc().toIso8601String();
  }
  return row;
}

_Table _table<T>(
  Store store,
  String name,
  Map<String, dynamic> Function(T) encodeRaw,
  T Function(Map<String, dynamic>) decode,
) {
  final box = store.box<T>();
  Map<String, dynamic> encode(T value) =>
      _withUtcDates(value, encodeRaw(value));
  return _Table(name, () => box.getAll().map(encode).toList(), (rows, write) {
    final ids = <int>{};
    final values = rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      final id = json['id'];
      if (id is! int || id <= 0 || !ids.add(id)) {
        throw const LocalImportRecoveryFailed();
      }
      final value = decode(json);
      final normalized = encode(value);
      if (json.length != normalized.length ||
          json.keys.any((key) => !normalized.containsKey(key))) {
        throw const LocalImportRecoveryFailed();
      }
      return value;
    }).toList();
    if (write) {
      box.removeAll();
      if (values.isNotEmpty) box.putMany(values);
    }
  });
}

List<_Table> _tables(Store s) => [
  _table<BikaComicHistory>(
    s,
    'bikaComicHistory',
    (v) => v.toJson(),
    BikaComicHistory.fromJson,
  ),
  _table<BikaComicDownload>(
    s,
    'bikaComicDownload',
    (v) => v.toJson(),
    BikaComicDownload.fromJson,
  ),
  _table<JmFavorite>(s, 'jmFavorite', (v) => v.toJson(), JmFavorite.fromJson),
  _table<JmHistory>(s, 'jmHistory', (v) => v.toJson(), JmHistory.fromJson),
  _table<JmDownload>(s, 'jmDownload', (v) => v.toJson(), JmDownload.fromJson),
  _table<UnifiedComicFavorite>(
    s,
    'unifiedComicFavorite',
    (v) => v.toJson(),
    UnifiedComicFavorite.fromJson,
  ),
  _table<UnifiedComicHistory>(
    s,
    'unifiedComicHistory',
    (v) => v.toJson(),
    UnifiedComicHistory.fromJson,
  ),
  _table<UnifiedComicDownload>(
    s,
    'unifiedComicDownload',
    (v) => v.toJson(),
    UnifiedComicDownload.fromJson,
  ),
  _table<ComicFollow>(
    s,
    'comicFollow',
    (v) => v.toJson(),
    ComicFollow.fromJson,
  ),
  _table<PluginConfig>(
    s,
    'pluginConfig',
    (v) => v.toJson(),
    PluginConfig.fromJson,
  ),
  _table<PluginInfo>(s, 'pluginInfo', (v) => v.toJson(), PluginInfo.fromJson),
  _table<ComicFolder>(
    s,
    'comicFolder',
    (v) => v.toJson(),
    ComicFolder.fromJson,
  ),
  _table<ComicLink>(s, 'comicLink', (v) => v.toJson(), ComicLink.fromJson),
  _table<ComicReadPreference>(
    s,
    'comicReadPreference',
    (v) => {...v.toJson(), 'readMode': v.readMode},
    (j) => ComicReadPreference(
      id: j['id'] as int,
      uniqueKey: j['uniqueKey'] as String,
      source: j['source'] as String,
      comicId: j['comicId'] as String,
      overridesJson: j['overridesJson'] as String,
      readMode: j['readMode'] as int,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      deleted: j['deleted'] as bool,
    ),
  ),
  _table<UserSetting>(
    s,
    'userSetting',
    (v) => {
      'id': v.id,
      'globalSettingData': v.globalSettingData,
      'bikaSettingData': v.bikaSettingData,
      'jmSettingData': v.jmSettingData,
      'jmJwt': v.jmJwt,
    },
    (j) => UserSetting(
      id: j['id'] as int,
      globalSettingData: j['globalSettingData'] as String?,
      bikaSettingData: j['bikaSettingData'] as String?,
      jmSettingData: j['jmSettingData'] as String?,
      jmJwt: j['jmJwt'] as String,
    ),
  ),
  _table<DownloadTask>(
    s,
    'downloadTask',
    (v) => {
      'id': v.id,
      'comicId': v.comicId,
      'comicName': v.comicName,
      'isCompleted': v.isCompleted,
      'isDownloading': v.isDownloading,
      'status': v.status,
      'dbTaskInfoStr': v.dbTaskInfoStr,
    },
    (j) => DownloadTask()
      ..id = j['id'] as int
      ..comicId = j['comicId'] as String
      ..comicName = j['comicName'] as String
      ..isCompleted = j['isCompleted'] as bool
      ..isDownloading = j['isDownloading'] as bool
      ..status = j['status'] as String
      ..dbTaskInfoStr = j['dbTaskInfoStr'] as String?,
  ),
];

String _captureDatabase(Store store, int _) =>
    jsonEncode({for (final t in _tables(store)) t.name: t.read()});

/// Private local checkpoint, excluded from exports, Portable and cloud data.
/// Snapshot bytes are written once; small progress records are atomic renames.
class LocalImportRecovery {
  LocalImportRecovery._(
    this.root,
    this.downloads,
    this.images,
    this.snapshot,
    this.journal,
  );
  final Directory root, downloads;
  final LocalAppearanceImages images;
  final Map<String, dynamic> snapshot, journal;
  static bool _pending = false;
  static void requireRecovered() {
    if (_pending) throw const LocalImportRecoveryFailed();
  }

  File get _record => File(p.join(root.path, 'pending.json'));

  static Future<Directory> directory() async =>
      Directory(p.join(await getFilePath(), 'local-import-recovery'));

  /// Persisted fields only; portable exporters must project their own scope.
  static Future<Map<String, dynamic>> captureDatabaseSnapshot() async =>
      Map<String, dynamic>.from(
        jsonDecode(
              await objectbox.store.runInTransactionAsync<String, int>(
                TxMode.read,
                _captureDatabase,
                0,
              ),
            )
            as Map,
      );

  static Future<void> _plainDirectory(Directory directory) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const LocalImportRecoveryFailed();
    }
  }

  static Future<void> _atomic(File file, String data) async {
    final pending = File('${file.path}.new');
    if (await FileSystemEntity.type(pending.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const LocalImportRecoveryFailed();
    }
    await pending.writeAsString(data, flush: true);
    await pending.rename(file.path);
  }

  static Future<LocalImportRecovery> begin({
    Directory? recoveryDirectory,
    required Directory downloads,
    required LocalAppearanceImages images,
  }) async {
    final root = recoveryDirectory ?? await directory();
    if (await FileSystemEntity.type(root.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      await root.create(recursive: true);
    }
    await _plainDirectory(root);
    if (await File(p.join(root.path, 'pending.json')).exists()) {
      _pending = true;
      throw const LocalImportRecoveryFailed();
    }
    final prefs = await SharedPreferences.getInstance();
    final database = await objectbox.store.runInTransactionAsync<String, int>(
      TxMode.read,
      _captureDatabase,
      0,
    );
    final snapshot = {
      'database': jsonDecode(database),
      'preferences': {for (final key in prefs.getKeys()) key: prefs.get(key)},
    };
    final bytes = jsonEncode(snapshot);
    final journal = <String, dynamic>{
      'format': 'breeze-local-import-recovery',
      'version': 1,
      'phase': 'prepared',
      'sha256': sha256.convert(utf8.encode(bytes)).toString(),
      'preferences': <String, dynamic>{},
      'images': <String>[],
      'operationToken': List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    };
    await _atomic(File(p.join(root.path, 'snapshot.json')), bytes);
    final result = LocalImportRecovery._(
      root,
      downloads.absolute,
      images,
      snapshot,
      journal,
    );
    _pending = true;
    await result._save();
    return result;
  }

  Future<void> _save() => _atomic(
    _record,
    jsonEncode({
      'journal': journal,
      'sha256': sha256.convert(utf8.encode(jsonEncode(journal))).toString(),
    }),
  );

  Future<void> beforePreferences(
    Map<String, dynamic> updates, {
    Map<String, dynamic>? beforeValues,
  }) async {
    if (beforeValues != null) {
      // A value captured under its owner's write queue supersedes the initial
      // snapshot. Seal the override in the atomic, checksummed progress record.
      if (beforeValues.entries.any(
        (entry) =>
            !updates.containsKey(entry.key) ||
            !_validPreferenceBefore(entry.key, entry.value),
      )) {
        throw const LocalImportRecoveryFailed();
      }
      final initial = snapshot['preferences'] as Map;
      final prepared = journal['preferences'] as Map;
      for (final entry in beforeValues.entries) {
        if (prepared.containsKey(entry.key) ||
            initial[entry.key] == entry.value) {
          continue;
        }
        final before =
            journal.putIfAbsent('preferenceBefore', () => <String, dynamic>{})
                as Map;
        before[entry.key] = entry.value;
      }
    }
    (journal['preferences'] as Map).addAll(updates);
    await _save();
  }

  Future<void> beforeImages(
    Set<String> basenames, {
    bool strict = false,
  }) async {
    final old =
        (snapshot['preferences'] as Map)[LocalAppearanceImages.preferencesKey];
    if (old is String) {
      try {
        final mapping = jsonDecode(old);
        if (mapping is Map) {
          basenames = {
            ...basenames,
            ...mapping.values.whereType<String>().where(
              LocalAppearanceImages.isRecoveryBasename,
            ),
          };
        }
      } catch (_) {
        /* Invalid unreferenced choices are not deletion candidates. */
      }
    }
    journal['images'] = basenames.toList();
    if (strict) journal['strictImages'] = true;
    await _save();
  }

  Future<void> beforeDownloadSwap(
    Directory staging, {
    required bool hadTarget,
  }) async {
    if (p.dirname(staging.absolute.path) != p.dirname(downloads.path) ||
        !RegExp(
          r'^\.breeze-download-restore-[A-Za-z0-9_-]+$',
        ).hasMatch(p.basename(staging.path))) {
      throw const LocalImportRecoveryFailed();
    }
    await _plainDirectory(staging);
    journal['downloads'] = {
      'stage': p.basename(staging.path),
      'hadTarget': hadTarget,
    };
    await _save();
  }

  Future<void> markCommitted() async {
    journal['phase'] = 'committed';
    await _save();
    _clearDatabaseCommit();
  }

  Future<void> beforeNativeHlsRemoval(String token) async {
    if (journal['phase'] != 'prepared' ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(token) ||
        (journal['nativeHlsRemoval'] != null &&
            journal['nativeHlsRemoval'] != token)) {
      throw const LocalImportRecoveryFailed();
    }
    journal['nativeHlsRemoval'] = token;
    await _save();
  }

  /// Must be the last write inside the operation's actual ObjectBox transaction.
  /// The token and application rows therefore commit or roll back together.
  void markDatabaseCommitted() {
    final token = journal['operationToken'];
    if (journal['phase'] != 'prepared' ||
        token is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(token)) {
      throw const LocalImportRecoveryFailed();
    }
    final box = objectbox.store.box<LocalStorageCommit>();
    box.put(LocalStorageCommit(operationToken: token));
  }

  bool get hasDatabaseCommit {
    final token = journal['operationToken'];
    if (token is! String) return false;
    final query = objectbox.store
        .box<LocalStorageCommit>()
        .query(LocalStorageCommit_.operationToken.equals(token))
        .build();
    try {
      return query.findFirst() != null;
    } finally {
      query.close();
    }
  }

  void _clearDatabaseCommit() {
    final token = journal['operationToken'];
    if (token is! String) return;
    final box = objectbox.store.box<LocalStorageCommit>();
    final query = box
        .query(LocalStorageCommit_.operationToken.equals(token))
        .build();
    try {
      box.removeMany(query.findIds());
    } finally {
      query.close();
    }
  }

  /// Register every source-scoped same-volume move before its first rename.
  /// Replacement hashes authorize rollback of an index written by this action;
  /// an unrelated/newer file is never removed just to make rollback succeed.
  Future<void> beforeFileMoves(List<PluginRemovalFileMove> moves) async {
    final existing = (journal['fileMoves'] as List? ?? const [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    for (final move in moves) {
      final value = <String, dynamic>{
        'original': p.normalize(p.absolute(move.original)),
        'staged': p.normalize(p.absolute(move.staged)),
        'replacementSha256': move.replacementSha256,
      };
      await _validateFileMove(value);
      if (existing.any(
        (item) =>
            item['original'] == value['original'] ||
            item['staged'] == value['staged'],
      )) {
        throw const LocalImportRecoveryFailed();
      }
      existing.add(value);
    }
    journal['fileMoves'] = existing;
    await _save();
  }

  Future<void> _validateFileMove(Map<String, dynamic> move) async {
    if (move.length != 3 ||
        move['original'] is! String ||
        move['staged'] is! String ||
        (move['replacementSha256'] != null &&
            (move['replacementSha256'] is! String ||
                !RegExp(
                  r'^[a-f0-9]{64}$',
                ).hasMatch(move['replacementSha256'] as String)))) {
      throw const LocalImportRecoveryFailed();
    }
    final original = move['original'] as String,
        staged = move['staged'] as String;
    final root = p.normalize(downloads.absolute.path);
    if (p.normalize(p.absolute(original)) != original ||
        p.normalize(p.absolute(staged)) != staged ||
        !p.isWithin(root, original) ||
        p.dirname(original) != p.dirname(staged) ||
        !staged.startsWith('$original.breeze-removal-') ||
        !RegExp(
          r'^[A-Za-z0-9_-]{1,100}$',
        ).hasMatch(staged.substring('$original.breeze-removal-'.length))) {
      throw const LocalImportRecoveryFailed();
    }
    var parent = p.dirname(original);
    while (true) {
      await _plainDirectory(Directory(parent));
      if (parent == root) break;
      if (!p.isWithin(root, parent)) throw const LocalImportRecoveryFailed();
      parent = p.dirname(parent);
    }
    for (final path in [
      original,
      staged,
      if (move['replacementSha256'] != null) '$staged-replacement',
    ]) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        throw const LocalImportRecoveryFailed();
      }
      if (path == '$staged-replacement' &&
          type == FileSystemEntityType.directory) {
        throw const LocalImportRecoveryFailed();
      }
    }
  }

  Future<void> _restoreFileMoves() async {
    for (final raw in (journal['fileMoves'] as List? ?? const []).reversed) {
      final move = Map<String, dynamic>.from(raw as Map);
      final original = move['original'] as String,
          staged = move['staged'] as String;
      if (move['replacementSha256'] != null) {
        final candidate = File('$staged-replacement');
        if (await candidate.exists()) await candidate.delete();
      }
      final stagedType = await FileSystemEntity.type(
        staged,
        followLinks: false,
      );
      if (stagedType == FileSystemEntityType.notFound) {
        if (await FileSystemEntity.type(original, followLinks: false) ==
            FileSystemEntityType.notFound) {
          throw const LocalImportRecoveryFailed();
        }
        continue;
      }
      final originalType = await FileSystemEntity.type(
        original,
        followLinks: false,
      );
      if (originalType != FileSystemEntityType.notFound) {
        final replacement = move['replacementSha256'];
        if (replacement == null ||
            originalType != FileSystemEntityType.file ||
            (await sha256.bind(File(original).openRead()).first).toString() !=
                replacement) {
          throw const LocalImportRecoveryFailed();
        }
        await File(original).delete();
      }
      if (stagedType == FileSystemEntityType.directory) {
        await Directory(staged).rename(original);
      } else if (stagedType == FileSystemEntityType.file)
        await File(staged).rename(original);
      else
        throw const LocalImportRecoveryFailed();
    }
  }

  Future<void> _finishFileMoves() async {
    final moves = journal['fileMoves'] as List? ?? const [];
    if (moves.isNotEmpty && journal['phase'] == 'prepared') {
      throw const LocalImportRecoveryFailed();
    }
    // Check every replacement before deleting any retained original bytes.
    for (final raw in moves) {
      final move = Map<String, dynamic>.from(raw as Map);
      await _validateFileMove(move);
      final stagedType = await FileSystemEntity.type(
        move['staged'] as String,
        followLinks: false,
      );
      if (stagedType == FileSystemEntityType.notFound) continue;
      if (journal['phase'] != 'committed') {
        throw const LocalImportRecoveryFailed();
      }
      if (move['replacementSha256'] != null) {
        final original = File(move['original'] as String);
        if (stagedType != FileSystemEntityType.file ||
            await FileSystemEntity.type(original.path, followLinks: false) !=
                FileSystemEntityType.file ||
            (await sha256.bind(original.openRead()).first).toString() !=
                move['replacementSha256']) {
          throw const LocalImportRecoveryFailed();
        }
      }
    }
    for (final raw in moves) {
      final move = Map<String, dynamic>.from(raw as Map);
      if (move['replacementSha256'] != null) {
        final candidate = File('${move['staged']}-replacement');
        if (await candidate.exists()) await candidate.delete();
      }
      final type = await FileSystemEntity.type(
        move['staged'] as String,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (journal['phase'] != 'committed') {
        throw const LocalImportRecoveryFailed();
      }
      if (type == FileSystemEntityType.directory) {
        await Directory(move['staged'] as String).delete(recursive: true);
      } else if (type == FileSystemEntityType.file)
        await File(move['staged'] as String).delete();
      else
        throw const LocalImportRecoveryFailed();
    }
  }

  Future<void> markRolledBack() async {
    journal['phase'] = 'rolledback';
    await _save();
  }

  Future<void> restoreDatabase() async {
    final data = Map<String, dynamic>.from(snapshot['database'] as Map);
    final tables = _tables(objectbox.store);
    // Parse every row and check all constraints in the same atomic transaction.
    objectbox.store.runInTransaction(TxMode.write, () {
      for (final table in tables) {
        table.parse(data[table.name] as List, true);
      }
    });
  }

  Future<void> restorePreferences({bool onlyOwnedValues = false}) =>
      VideoWatchHistory.serializePortableWrite(
        () => ShelfFacetPreferences.serializePortableWrite(
          () =>
              ComicChapterReadingProgress.instance.serializeRecovery(() async {
                final prefs = await SharedPreferences.getInstance();
                final before = <dynamic, dynamic>{
                  ...snapshot['preferences'] as Map,
                  ...?journal['preferenceBefore'] as Map?,
                };
                for (final entry in (journal['preferences'] as Map).entries) {
                  final key = entry.key as String, value = before[entry.key];
                  if (onlyOwnedValues && key == VideoLibraryStore.prefsKey) {
                    await VideoLibraryStore.shared.restoreSnapshotIfCurrent(
                      entry.value as String?,
                      value as String?,
                    );
                    continue;
                  }
                  if (onlyOwnedValues &&
                      jsonEncode(prefs.get(key)) != jsonEncode(entry.value)) {
                    continue;
                  }
                  final bool ok;
                  if (value == null) {
                    ok = await prefs.remove(key);
                  } else if (value is String) {
                    ok = await prefs.setString(key, value);
                  } else if (value is bool) {
                    ok = await prefs.setBool(key, value);
                  } else if (value is int) {
                    ok = await prefs.setInt(key, value);
                  } else if (value is double) {
                    ok = await prefs.setDouble(key, value);
                  } else {
                    ok = await prefs.setStringList(
                      key,
                      (value as List).cast<String>(),
                    );
                  }
                  if (!ok) throw const LocalImportRecoveryFailed();
                }
              }),
        ),
      );

  Future<void> _restoreDownloads() async {
    final swap = journal['downloads'];
    if (swap == null) return;
    final stage = Directory(p.join(downloads.parent.path, swap['stage']));
    final previous = Directory(p.join(stage.path, 'previous'));
    final incoming = Directory(p.join(stage.path, 'incoming'));
    if (await previous.exists()) {
      if (await downloads.exists()) {
        if (await incoming.exists()) throw const LocalImportRecoveryFailed();
        await downloads.rename(incoming.path);
      }
      await previous.rename(downloads.path);
    } else if (swap['hadTarget'] == false && await downloads.exists()) {
      if (await incoming.exists()) throw const LocalImportRecoveryFailed();
      await downloads.rename(incoming.path);
    } else if (swap['hadTarget'] == true && !await downloads.exists()) {
      throw const LocalImportRecoveryFailed();
    }
  }

  Future<void> _validate() async {
    await _plainDirectory(root);
    if (journal['format'] != 'breeze-local-import-recovery' ||
        journal['version'] != 1 ||
        !const [
          'prepared',
          'committed',
          'rolledback',
        ].contains(journal['phase']) ||
        journal['preferences'] is! Map ||
        journal['images'] is! List ||
        snapshot['preferences'] is! Map ||
        snapshot['database'] is! Map) {
      throw const LocalImportRecoveryFailed();
    }
    if (journal.keys.any(
          (key) => !const {
            'format',
            'version',
            'phase',
            'sha256',
            'preferences',
            'preferenceBefore',
            'images',
            'downloads',
            'fileMoves',
            'operationToken',
            'strictImages',
            'nativeHlsRemoval',
          }.contains(key),
        ) ||
        snapshot.keys.any(
          (key) => !const {'database', 'preferences'}.contains(key),
        )) {
      throw const LocalImportRecoveryFailed();
    }
    if (journal['strictImages'] != null && journal['strictImages'] is! bool) {
      throw const LocalImportRecoveryFailed();
    }
    final nativeHls = journal['nativeHlsRemoval'];
    if (nativeHls != null &&
        (nativeHls is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(nativeHls))) {
      throw const LocalImportRecoveryFailed();
    }
    if (journal['operationToken'] != null &&
        (journal['operationToken'] is! String ||
            !RegExp(
              r'^[a-f0-9]{32}$',
            ).hasMatch(journal['operationToken'] as String))) {
      throw const LocalImportRecoveryFailed();
    }
    final moves = journal['fileMoves'];
    if (moves != null) {
      if (moves is! List || moves.length > 50000) {
        throw const LocalImportRecoveryFailed();
      }
      final paths = <String>{};
      for (final raw in moves) {
        if (raw is! Map) throw const LocalImportRecoveryFailed();
        final move = Map<String, dynamic>.from(raw);
        await _validateFileMove(move);
        if (!paths.add(move['original'] as String) ||
            !paths.add(move['staged'] as String)) {
          throw const LocalImportRecoveryFailed();
        }
      }
      final sorted = paths.toList()..sort();
      for (var index = 1; index < sorted.length; index++) {
        if (p.isWithin(sorted[index - 1], sorted[index])) {
          throw const LocalImportRecoveryFailed();
        }
      }
    }
    for (final map in [
      snapshot['preferences'] as Map,
      journal['preferences'] as Map,
      if (journal['preferenceBefore'] is Map)
        journal['preferenceBefore'] as Map,
    ]) {
      if (map.entries.any(
        (e) => e.key is! String || !_preferenceValue(e.value),
      )) {
        throw const LocalImportRecoveryFailed();
      }
    }
    final prior = journal['preferenceBefore'];
    if (prior != null &&
        (prior is! Map ||
            prior.entries.any(
              (entry) =>
                  !(journal['preferences'] as Map).containsKey(entry.key) ||
                  !_validPreferenceBefore(entry.key, entry.value),
            ))) {
      throw const LocalImportRecoveryFailed();
    }
    final data = snapshot['database'] as Map, tables = _tables(objectbox.store);
    if (data.length != tables.length ||
        !tables.every((t) => data[t.name] is List)) {
      throw const LocalImportRecoveryFailed();
    }
    for (final table in tables) {
      table.parse(data[table.name] as List, false);
    }
    for (final value in (snapshot['preferences'] as Map).values) {
      if (value is! String &&
          value is! bool &&
          value is! num &&
          (value is! List || value.any((v) => v is! String))) {
        throw const LocalImportRecoveryFailed();
      }
    }
    if ((journal['images'] as List).any(
      (v) => v is! String || !LocalAppearanceImages.isRecoveryBasename(v),
    )) {
      throw const LocalImportRecoveryFailed();
    }
    final swap = journal['downloads'];
    if (swap != null) {
      if (swap is! Map ||
          swap['hadTarget'] is! bool ||
          swap['stage'] is! String ||
          !RegExp(
            r'^\.breeze-download-restore-[A-Za-z0-9_-]+$',
          ).hasMatch(swap['stage'] as String)) {
        throw const LocalImportRecoveryFailed();
      }
      await _plainDirectory(downloads.parent);
      for (final dir in [
        downloads,
        Directory(p.join(downloads.parent.path, swap['stage'])),
        Directory(p.join(downloads.parent.path, swap['stage'], 'previous')),
        Directory(p.join(downloads.parent.path, swap['stage'], 'incoming')),
      ]) {
        if (await FileSystemEntity.type(dir.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          await _plainDirectory(dir);
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            final type = await FileSystemEntity.type(
              entity.path,
              followLinks: false,
            );
            if (type != FileSystemEntityType.file &&
                type != FileSystemEntityType.directory) {
              throw const LocalImportRecoveryFailed();
            }
          }
        }
      }
      final stage = Directory(p.join(downloads.parent.path, swap['stage']));
      final target = await downloads.exists(),
          previous = await Directory(p.join(stage.path, 'previous')).exists(),
          incoming = await Directory(p.join(stage.path, 'incoming')).exists();
      if (journal['phase'] == 'prepared' &&
          (previous && target && incoming ||
              swap['hadTarget'] == false && previous ||
              swap['hadTarget'] == true && !previous && !target ||
              swap['hadTarget'] == false && target && incoming ||
              target && !await stage.exists())) {
        throw const LocalImportRecoveryFailed();
      }
      if (journal['phase'] == 'committed' && !target) {
        throw const LocalImportRecoveryFailed();
      }
    }
  }

  Future<void> finish() async {
    if (journal['phase'] == 'prepared') throw const LocalImportRecoveryFailed();
    final nativeHls = journal['nativeHlsRemoval'];
    if (nativeHls is String) {
      await VideoHlsAssets.finishRemoval(
        nativeHls,
        committed: journal['phase'] == 'committed',
      );
    }
    await _finishFileMoves();
    final swap = journal['downloads'];
    if (swap != null) {
      final stage = Directory(p.join(downloads.parent.path, swap['stage']));
      if (await stage.exists()) await stage.delete(recursive: true);
    }
    await images.finishInterruptedBackup(
      (journal['images'] as List).cast<String>().toSet(),
      strict: journal['strictImages'] == true,
    );
    _clearDatabaseCommit();
    if (await _record.exists()) await _record.delete();
    for (final name in [
      'snapshot.json',
      'snapshot.json.new',
      'pending.json.new',
    ]) {
      final file = File(p.join(root.path, name));
      if (await file.exists()) await file.delete();
    }
    _pending = false;
  }

  static Future<void> recover({
    Directory? recoveryDirectory,
    Directory? downloadDirectory,
    LocalAppearanceImages? appearanceImages,
  }) async {
    final root = recoveryDirectory ?? await directory();
    if (await FileSystemEntity.type(root.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      _pending = false;
      return;
    }
    _pending = true;
    await _plainDirectory(root);
    final record = File(p.join(root.path, 'pending.json'));
    if (await FileSystemEntity.type(record.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      // A crash before the first intent rename, or after successful cleanup's
      // final intent removal, can leave only private snapshot scratch files.
      for (final name in [
        'snapshot.json',
        'snapshot.json.new',
        'pending.json.new',
      ]) {
        final file = File(p.join(root.path, name));
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.file) {
          throw const LocalImportRecoveryFailed();
        }
        await file.delete();
      }
      _pending = false;
      return;
    }
    _pending = true;
    try {
      final snapshotFile = File(p.join(root.path, 'snapshot.json'));
      for (final file in [record, snapshotFile]) {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw const LocalImportRecoveryFailed();
        }
      }
      final envelope = Map<String, dynamic>.from(
        jsonDecode(await record.readAsString()) as Map,
      );
      if (envelope.length != 2 ||
          envelope['journal'] is! Map ||
          envelope['sha256'] !=
              sha256
                  .convert(utf8.encode(jsonEncode(envelope['journal'])))
                  .toString()) {
        throw const LocalImportRecoveryFailed();
      }
      final journal = Map<String, dynamic>.from(envelope['journal'] as Map);
      final bytes = await snapshotFile.readAsString();
      if (journal['sha256'] != sha256.convert(utf8.encode(bytes)).toString()) {
        throw const LocalImportRecoveryFailed();
      }
      final result = LocalImportRecovery._(
        root,
        downloadDirectory ??
            Directory(p.join(await getFilePath(), 'downloads')),
        appearanceImages ?? LocalAppearanceImages.instance,
        Map<String, dynamic>.from(jsonDecode(bytes) as Map),
        journal,
      );
      await result._validate();
      if (journal['phase'] == 'prepared' && result.hasDatabaseCommit) {
        // Data + token committed atomically. Keep the activated files/prefs and
        // finish the new state; restoring old IDs here would corrupt the round.
        await result.markCommitted();
      } else if (journal['phase'] == 'prepared') {
        // New callers publish their proof in the same atomic application write.
        // Without it that transaction did not commit: replaying the whole old
        // database could erase unrelated source writes made after preparation.
        final atomic = journal['operationToken'] != null;
        if (!atomic) await result.restoreDatabase();
        await result.restorePreferences(onlyOwnedValues: atomic);
        await LocalPluginInstallationState.instance.reload();
        await result._restoreDownloads();
        await result._restoreFileMoves();
        await result.markRolledBack();
      } else if (journal['phase'] == 'committed' &&
          journal['downloads'] != null &&
          !await result.downloads.exists()) {
        throw const LocalImportRecoveryFailed();
      }
      await result.finish();
    } catch (_) {
      throw const LocalImportRecoveryFailed();
    }
  }
}

/// Must run immediately after opening ObjectBox, before readers or producers.
Future<void> recoverPendingBackupImport({
  Directory? recoveryDirectory,
  Directory? downloadDirectory,
  LocalAppearanceImages? appearanceImages,
}) => CacheWorkspaceGuard.withWorkspace(
  () => runExclusiveStorageOperation(
    () => LocalImportRecovery.recover(
      recoveryDirectory: recoveryDirectory,
      downloadDirectory: downloadDirectory,
      appearanceImages: appearanceImages,
    ),
    allowPendingRecovery: true,
  ),
);
