import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/util/get_path.dart';

typedef PluginRemovalFileMove = ({
  String original,
  String staged,
  String? replacementSha256,
});

class _SourceTree {
  const _SourceTree(
    this.directory,
    this.realPath,
    this.fingerprint,
    this.files,
  );
  final Directory directory;
  final String realPath;
  final String fingerprint;
  final int files;
}

/// A source-scoped, same-volume move plan. No bytes are removed before the
/// recovery owner has durably registered every move. Download records are
/// changed by the caller's existing database transaction, never here.
class PluginComicFileRemovalPlan {
  PluginComicFileRemovalPlan._(this._trees, this.moves);
  final List<_SourceTree> _trees;
  final List<PluginRemovalFileMove> moves;
  int get fileCount => _trees.fold(0, (count, tree) => count + tree.files);
  int get directoryCount => _trees.length;

  static Future<PluginComicFileRemovalPlan> prepare(
    String source, {
    Directory? downloadsRoot,
    Iterable<String> ownedStorageRoots = const [],
    String Function(String)? encodeSource,
  }) async {
    source = source.trim();
    if (source.isEmpty ||
        source.length > 200 ||
        source == '.' ||
        source == '..' ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(source)) {
      throw const FormatException('Invalid plugin identity');
    }
    final root =
        downloadsRoot ?? Directory(p.join(await getFilePath(), 'downloads'));
    final rootPath = p.normalize(root.absolute.path);
    final type = await FileSystemEntity.type(rootPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return PluginComicFileRemovalPlan._([], const []);
    }
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Invalid managed download root');
    }
    final realRoot = p.normalize(await root.resolveSymbolicLinks());
    final encoded = (encodeSource ?? (value) => encodePath(path: value))(
      source,
    );
    if (!RegExp(r'^f_[0-9]{1,40}$').hasMatch(encoded)) {
      throw const FormatException('Invalid managed source directory');
    }
    final candidates = <String>{p.join(rootPath, encoded)};
    // Historical layouts used the raw source directory. Never infer ownership
    // of a shared video/index directory from an arbitrary plugin identifier.
    final legacy = p.join(rootPath, source);
    final hasOwnedLegacy = ownedStorageRoots.any((value) {
      final path = p.normalize(p.absolute(value));
      return path == legacy || p.isWithin(legacy, path);
    });
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(source);
    if ((isUuid || hasOwnedLegacy) &&
        !{
          'video',
          'video-v1',
          'local-import-recovery',
        }.contains(source.toLowerCase()) &&
        !source.startsWith('.') &&
        !RegExp(r'^f_[0-9]+$').hasMatch(source)) {
      candidates.add(legacy);
    }
    final trees = <_SourceTree>[];
    for (final candidate in candidates) {
      final found = await FileSystemEntity.type(candidate, followLinks: false);
      if (found == FileSystemEntityType.notFound) continue;
      if (found != FileSystemEntityType.directory) {
        throw const FormatException('Invalid source download tree');
      }
      trees.add(
        await _inspect(
          Directory(candidate),
          p.join(realRoot, p.basename(candidate)),
        ),
      );
    }
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    final moves = <PluginRemovalFileMove>[
      for (final tree in trees)
        (
          original: tree.directory.path,
          staged: '${tree.directory.path}.breeze-removal-$token',
          replacementSha256: null,
        ),
    ];
    return PluginComicFileRemovalPlan._(trees, List.unmodifiable(moves));
  }

  static Future<_SourceTree> _inspect(
    Directory directory,
    String realPath,
  ) async {
    final expected = p.normalize(directory.absolute.path);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        p.normalize(await directory.resolveSymbolicLinks()) != realPath) {
      throw const FormatException('Invalid source download tree');
    }
    // An order-independent metadata fingerprint avoids retaining every path or
    // depending on filesystem enumeration order. Ownership validation above is
    // separate; this detects changes between preview and staging, not trust.
    var fingerprint = BigInt.zero;
    var files = 0, entries = 0, bytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file &&
          stat.type != FileSystemEntityType.directory) {
        throw const FormatException('Unsupported source download entry');
      }
      // stat follows links; reject them separately, including directory links.
      if (await FileSystemEntity.type(entity.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Linked source download entry');
      }
      final relative = p.relative(entity.path, from: expected);
      bytes += relative.length;
      if (++entries > 250000 || bytes > 32 * 1024 * 1024) {
        throw const FormatException('Source download tree is too large');
      }
      if (stat.type == FileSystemEntityType.file) files++;
      fingerprint ^= BigInt.parse(
        sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  relative,
                  stat.type == FileSystemEntityType.file,
                  stat.size,
                  stat.modified.microsecondsSinceEpoch,
                ]),
              ),
            )
            .toString(),
        radix: 16,
      );
    }
    return _SourceTree(
      directory,
      realPath,
      '$entries/$files/${fingerprint.toRadixString(16)}',
      files,
    );
  }

  Future<void> stage({
    required Future<void> Function(List<PluginRemovalFileMove>) beforeFileMoves,
  }) async {
    if (moves.isEmpty) return;
    for (var index = 0; index < _trees.length; index++) {
      if ((await _inspect(
                _trees[index].directory,
                _trees[index].realPath,
              )).fingerprint !=
              _trees[index].fingerprint ||
          await FileSystemEntity.type(
                moves[index].staged,
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound) {
        throw StateError('Source files changed before removal');
      }
    }
    await beforeFileMoves(moves);
    for (var index = 0; index < _trees.length; index++) {
      // Recheck after journal I/O, before the first mutation of this tree.
      if ((await _inspect(
            _trees[index].directory,
            _trees[index].realPath,
          )).fingerprint !=
          _trees[index].fingerprint) {
        throw StateError('Source files changed before removal');
      }
      await _trees[index].directory.rename(moves[index].staged);
    }
  }

  Future<void> rollback() async {
    for (final move in moves.reversed) {
      final stagedType = await FileSystemEntity.type(
        move.staged,
        followLinks: false,
      );
      if (stagedType == FileSystemEntityType.notFound) continue;
      if (stagedType != FileSystemEntityType.directory ||
          await FileSystemEntity.type(move.original, followLinks: false) !=
              FileSystemEntityType.notFound) {
        throw StateError('Source file rollback needs recovery');
      }
      await Directory(move.staged).rename(move.original);
    }
  }

  /// False retains the recoverable staged tree for a later cleanup attempt.
  Future<bool> finish({required bool committed}) async {
    if (!committed) {
      await rollback();
      return true;
    }
    var cleaned = true;
    for (final move in moves) {
      try {
        final type = await FileSystemEntity.type(
          move.staged,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.directory) {
          cleaned = false;
          continue;
        }
        await Directory(move.staged).delete(recursive: true);
      } catch (_) {
        cleaned = false;
      }
    }
    return cleaned;
  }
}
