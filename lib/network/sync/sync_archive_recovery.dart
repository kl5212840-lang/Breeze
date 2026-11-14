import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show LocalStorageCommit_;
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/util/get_path.dart';

Future<bool> writeArchivePreference(
  SharedPreferences prefs,
  String key,
  Object? value,
) {
  return switch (value) {
    null => prefs.remove(key),
    String value => prefs.setString(key, value),
    bool value => prefs.setBool(key, value),
    int value => prefs.setInt(key, value),
    double value => prefs.setDouble(key, value),
    List value => prefs.setStringList(key, value.cast<String>()),
    _ => throw const ArchiveRestoreFailed(),
  };
}

/// The file is durable before any preference changes. The ObjectBox token
/// distinguishes a fully committed import from a cut before the database commit.
class ArchivePreferenceTransaction {
  ArchivePreferenceTransaction._(this.identity, this.file, this.prefs);
  final String identity;
  final File? file;
  final SharedPreferences prefs;
  final _before = <String, dynamic>{};
  final _expected = <String, List<dynamic>>{};
  String? _operationToken;
  bool _committed = false;

  static final _validIdentity = RegExp(r'^[a-f0-9]{32}$');
  static bool supportsIdentity(String identity) =>
      _validIdentity.hasMatch(identity);

  static String pendingKey(String identity) =>
      'breeze.local.sync-archive.v2.$identity.recovery';

  static Future<Directory> _root(Directory? directory) async =>
      directory ??
      Directory(p.join(await getFilePath(create: false), 'archive-recovery'));

  static Future<ArchivePreferenceTransaction?> _open(
    String identity, {
    Directory? directory,
    required bool create,
  }) async {
    if (!supportsIdentity(identity)) {
      throw const ArchiveRestoreFailed();
    }
    final root = await _root(directory);
    final type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!create) return null;
      await root.create(recursive: true);
    }
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const ArchiveRestoreFailed();
    }
    return ArchivePreferenceTransaction._(
      identity,
      File(p.join(await root.resolveSymbolicLinks(), '$identity.json')),
      await SharedPreferences.getInstance(),
    );
  }

  static Future<ArchivePreferenceTransaction> create(
    String identity, {
    Directory? directory,
  }) async {
    final transaction = (await _open(
      identity,
      directory: directory,
      create: true,
    ))!;
    transaction._operationToken = const Uuid().v4().replaceAll('-', '');
    return transaction;
  }

  /// An unscoped adapter has no stable archive identity for cold recovery.
  static Future<ArchivePreferenceTransaction> createTransient() async =>
      ArchivePreferenceTransaction._(
        '',
        null,
        await SharedPreferences.getInstance(),
      );

  static File _staged(File file) => File('${file.path}.pending');

  Future<void> _save() async {
    final checkpoint = file;
    if (checkpoint == null) return;
    final staged = _staged(checkpoint);
    await staged.writeAsString(
      jsonEncode({
        'version': 2,
        'operationToken': _operationToken,
        'committed': _committed,
        'before': _before,
        'expected': _expected,
      }),
      flush: true,
    );
    await staged.rename(checkpoint.path);
  }

  Future<void> prepare(Map<String, dynamic> updates) async {
    for (final entry in updates.entries) {
      _before.putIfAbsent(entry.key, () {
        final old = prefs.get(entry.key);
        return old is List ? List<String>.from(old) : old;
      });
      // The same key can be staged by both old settings and video archives.
      // A cut before the second write can leave either value in preferences.
      (_expected[entry.key] ??= []).add(entry.value);
    }
    await _save();
  }

  /// Must be called within the database transaction that imports the rows.
  void markDatabaseCommitted() {
    final token = _operationToken;
    if (token == null) return;
    objectbox.store.box<LocalStorageCommit>().put(
      LocalStorageCommit(operationToken: token),
    );
  }

  int? _databaseCommitId() {
    final token = _operationToken;
    if (token == null) return null;
    final query = objectbox.store
        .box<LocalStorageCommit>()
        .query(LocalStorageCommit_.operationToken.equals(token))
        .build();
    try {
      return query.findFirst()?.id;
    } finally {
      query.close();
    }
  }

  Future<void> finishCommitted() async {
    if (file == null) return;
    final id = _databaseCommitId();
    if (!_committed) {
      if (id == null) throw const ArchiveRestoreFailed();
      _committed = true;
      await _save();
    }
    // The committed file must survive until the token is removed. Recovery
    // can then clean up in either order of interruption without undoing data.
    if (id != null) objectbox.store.box<LocalStorageCommit>().remove(id);
    await _discard();
  }

  Future<void> rollback() async {
    var failed = false;
    for (final entry in _before.entries) {
      final expected = _expected[entry.key]!;
      if (entry.key == VideoLibraryStore.prefsKey) {
        try {
          // The video library snapshot is staged once under its write queue.
          await VideoLibraryStore.shared.restoreSnapshotIfCurrent(
            expected.single as String?,
            entry.value as String?,
          );
        } catch (_) {
          failed = true;
        }
        continue;
      }
      if (entry.key == VideoPlaybackPreferences.snapshotKey) {
        try {
          await VideoPlaybackPreferences.restoreSnapshotIfCurrent(
            expected.cast<String?>(),
            entry.value as String?,
          );
        } catch (_) {
          failed = true;
        }
        continue;
      }
      final current = jsonEncode(prefs.get(entry.key));
      if (current == jsonEncode(entry.value) ||
          !expected.any((value) => current == jsonEncode(value))) {
        continue;
      }
      try {
        if (!await writeArchivePreference(prefs, entry.key, entry.value)) {
          failed = true;
        }
      } catch (_) {
        failed = true;
      }
    }
    if (failed) throw const ArchiveRestoreFailed();
    await PortablePreferences.notifyRestored(keys: _before.keys.toSet());
    await _discard();
  }

  Future<void> _discard() async {
    final checkpoint = file;
    if (checkpoint == null) return;
    final staged = _staged(checkpoint);
    // Remove the old compatibility flag first; its recovery needs this file.
    if (prefs.getBool(pendingKey(identity)) == true &&
        !await prefs.remove(pendingKey(identity))) {
      throw const ArchiveRestoreFailed();
    }
    if (await staged.exists()) await staged.delete();
    if (await checkpoint.exists()) await checkpoint.delete();
  }

  static Future<void> recover(String identity, {Directory? directory}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldPending = prefs.getBool(pendingKey(identity)) == true;
      // Unscoped adapters cannot create an archive recovery checkpoint.
      if (!supportsIdentity(identity) && !oldPending) return;
      final transaction = await _open(
        identity,
        directory: directory,
        create: false,
      );
      final checkpoint = transaction?.file;
      if (transaction == null ||
          checkpoint == null ||
          !await checkpoint.exists()) {
        if (oldPending) throw const ArchiveRestoreFailed();
        return;
      }
      final raw = jsonDecode(await checkpoint.readAsString());
      if (raw is! Map) throw const ArchiveRestoreFailed();
      final version = raw['version'];
      // A v1 file without its explicit error flag may belong to an already
      // committed import. It has no database proof, so never roll it back.
      if (version == 1 && !oldPending) return;
      if ((version != 1 && version != 2) ||
          raw['before'] is! Map ||
          raw['expected'] is! Map) {
        throw const ArchiveRestoreFailed();
      }
      transaction._before.addAll(
        Map<String, dynamic>.from(raw['before'] as Map),
      );
      transaction._expected.addAll({
        for (final entry in (raw['expected'] as Map).entries)
          entry.key as String: version == 1
              ? [entry.value]
              : List<dynamic>.from(entry.value as List),
      });
      if (version == 2) {
        final token = raw['operationToken'];
        final committed = raw['committed'];
        if (token is! String ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(token) ||
            committed is! bool) {
          throw const ArchiveRestoreFailed();
        }
        transaction._operationToken = token;
        transaction._committed = committed;
        if (committed || transaction._databaseCommitId() != null) {
          await transaction.finishCommitted();
          return;
        }
      }
      await transaction.rollback();
    } catch (_) {
      throw const ArchiveRestoreFailed();
    }
  }
}
