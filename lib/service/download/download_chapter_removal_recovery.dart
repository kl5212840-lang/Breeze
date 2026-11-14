import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart' show LocalStorageCommit;
import 'package:zephyr/object_box/objectbox.g.dart' show LocalStorageCommit_;
import 'package:zephyr/util/get_path.dart';

Future<String?> safeChapterRemovalFile(
  String root,
  String canonicalRoot,
  String path,
) async {
  if (!p.isWithin(root, path)) {
    throw const FileSystemException('Path outside download root');
  }
  var current = path;
  while (current != root) {
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const FileSystemException('Linked download path');
    }
    if (current == path && type == FileSystemEntityType.notFound) return null;
    current = p.dirname(current);
  }
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const FileSystemException('Download candidate is not a file');
  }
  final resolved = p.normalize(await File(path).resolveSymbolicLinks());
  if (!p.isWithin(canonicalRoot, resolved)) {
    throw const FileSystemException('Resolved path outside download root');
  }
  return resolved;
}

/// One checkpoint per operation, written before any page leaves its read path.
/// The proof row commits with the download records, without a database snapshot.
class DownloadChapterRemovalRecovery {
  DownloadChapterRemovalRecovery._(
    this._checkpoint,
    this._token,
    this._root,
    this._canonicalRoot,
    this._paths,
    this._committed,
  );

  final File _checkpoint;
  final String _token, _root, _canonicalRoot;
  final List<String> _paths;
  bool _committed;

  static final _journalName = RegExp(r'^([a-f0-9]{32})\.json$');
  static final _temporaryName = RegExp(r'^[a-f0-9]{32}\.json\.pending$');

  static Future<Directory> _directory() async => Directory(
    p.join(await getFilePath(create: false), 'download-chapter-removal'),
  );

  static Future<DownloadChapterRemovalRecovery> begin({
    required String root,
    required String canonicalRoot,
    required List<String> paths,
  }) async {
    final directory = await _directory();
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) await directory.create();
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException('Unsafe download removal journal');
    }
    final token = const Uuid().v4().replaceAll('-', '');
    final journal = DownloadChapterRemovalRecovery._(
      File(p.join(directory.path, '$token.json')),
      token,
      root,
      canonicalRoot,
      paths,
      false,
    );
    await journal._save();
    return journal;
  }

  String stagedPath(String original) => '$original.breeze-removal-$_token';
  File get _temporary => File('${_checkpoint.path}.pending');

  Future<void> _save() async {
    final type = await FileSystemEntity.type(
      _temporary.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const FileSystemException('Unsafe download removal journal');
    }
    await _temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'committed': _committed,
        'files': _paths.map((path) => p.relative(path, from: _root)).toList(),
      }),
      flush: true,
    );
    await _temporary.rename(_checkpoint.path);
  }

  /// Called inside the transaction that removes the download records.
  void markDatabaseCommitted() {
    objectbox.store.box<LocalStorageCommit>().put(
      LocalStorageCommit(operationToken: _token),
    );
  }

  int? _commitId() {
    final query = objectbox.store
        .box<LocalStorageCommit>()
        .query(LocalStorageCommit_.operationToken.equals(_token))
        .build();
    try {
      return query.findFirst()?.id;
    } finally {
      query.close();
    }
  }

  /// Settle either interrupted phase. An uncommitted checkpoint never replaces
  /// a file subsequently created at the original path.
  Future<void> settle() async {
    final commitId = _commitId();
    final committed = _committed || commitId != null;
    var failed = false;
    for (final path in _paths.reversed) {
      try {
        final staged = stagedPath(path);
        if (await safeChapterRemovalFile(_root, _canonicalRoot, staged) ==
            null) {
          continue;
        }
        if (committed) {
          await File(staged).delete();
        } else {
          if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.notFound) {
            throw const FileSystemException(
              'Download path changed during removal',
            );
          }
          await File(staged).rename(path);
        }
      } catch (_) {
        failed = true;
      }
    }
    if (failed)
      throw const FileSystemException('Download removal recovery incomplete');
    if (commitId != null) {
      if (!_committed) {
        _committed = true;
        await _save();
      }
      objectbox.store.box<LocalStorageCommit>().remove(commitId);
    }
    await _checkpoint.delete();
  }

  static Future<bool> recover() async {
    final directory = await _directory();
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return true;
    if (type != FileSystemEntityType.directory) return false;
    return runExclusiveStorageOperation(() async {
      final entries = await directory.list(followLinks: false).toList();
      String? root, canonicalRoot;
      var complete = true;
      for (final entry in entries) {
        final name = p.basename(entry.path);
        final token = _journalName.firstMatch(name)?.group(1);
        if (token == null) continue;
        try {
          if (entry is! File)
            throw const FormatException('Unsafe removal journal');
          root ??= p.normalize(p.absolute(await getDownloadPath()));
          if (await FileSystemEntity.type(root, followLinks: false) !=
              FileSystemEntityType.directory) {
            throw const FormatException('Unsafe download root');
          }
          canonicalRoot ??= await Directory(root).resolveSymbolicLinks();
          final data = jsonDecode(await entry.readAsString());
          if (data is! Map ||
              data['version'] != 1 ||
              data['committed'] is! bool ||
              data['files'] is! List) {
            throw const FormatException('Invalid removal journal');
          }
          final paths = <String>{};
          for (final relative in data['files'] as List) {
            if (relative is! String ||
                p.isAbsolute(relative) ||
                p.normalize(relative) != relative) {
              throw const FormatException('Invalid removal path');
            }
            final path = p.normalize(p.join(root, relative));
            if (!p.isWithin(root, path) || !paths.add(path)) {
              throw const FormatException('Invalid removal path');
            }
          }
          await DownloadChapterRemovalRecovery._(
            entry,
            token,
            root,
            canonicalRoot,
            paths.toList(),
            data['committed'] as bool,
          ).settle();
        } catch (_) {
          complete = false;
        }
      }
      for (final entry in entries.whereType<File>()) {
        if (_temporaryName.hasMatch(p.basename(entry.path)) &&
            await entry.exists()) {
          try {
            await entry.delete();
          } catch (_) {
            complete = false;
          }
        }
      }
      return complete;
    });
  }
}
