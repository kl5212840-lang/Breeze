import 'dart:io';

import 'package:path/path.dart' as p;

/// Only partitions produced by DownloadAssetStore's canonical image layout.
/// Callers supply exact source hashes; no domain, filename or directory scan
/// is used to infer ownership. Other cache/workspace roots are never visited.
class SourceImageCacheStore {
  SourceImageCacheStore({
    required this.root,
    required Iterable<String> sourceSegments,
  }) : sourceSegments = Set<String>.unmodifiable(sourceSegments) {
    if (this.sourceSegments.any(
      (value) => !RegExp(r'^f_[0-9]{1,39}$').hasMatch(value),
    )) {
      throw ArgumentError('Invalid image-cache source partition');
    }
  }

  final String root;
  final Set<String> sourceSegments;

  Future<int> sizeBytes() async {
    var bytes = 0;
    for (final segment in sourceSegments) {
      await for (final file in _files(p.join(root, segment))) {
        bytes += await file.length();
      }
    }
    return bytes;
  }

  Future<void> clear() async {
    for (final segment in sourceSegments) {
      // Keep directories so active image fetches can finish normally. Do not
      // recursively delete a directory that could contain a symbolic link.
      await for (final file in _files(p.join(root, segment))) {
        try {
          await file.delete();
        } on FileSystemException {
          if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.notFound)
            rethrow;
        }
      }
    }
  }

  Stream<File> _files(String directory, {String? resolvedRoot}) async* {
    final type = await FileSystemEntity.type(directory, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw const FileSystemException('Invalid image-cache partition');
    }
    // The OS cache root itself may be reached through a platform alias.
    // Each partition/subdirectory must still resolve under that exact root.
    final actualRoot =
        resolvedRoot ?? await Directory(root).resolveSymbolicLinks();
    final expected = p.join(actualRoot, p.relative(directory, from: root));
    if (!p.equals(
      await Directory(directory).resolveSymbolicLinks(),
      expected,
    )) {
      throw const FileSystemException('Linked image-cache partition');
    }
    await for (final entry in Directory(directory).list(followLinks: false)) {
      final entryType = await FileSystemEntity.type(
        entry.path,
        followLinks: false,
      );
      if (entryType == FileSystemEntityType.directory) {
        yield* _files(entry.path, resolvedRoot: actualRoot);
      } else if (entryType == FileSystemEntityType.file) {
        yield File(entry.path);
      } else if (entryType != FileSystemEntityType.notFound) {
        throw const FileSystemException('Linked image-cache entry');
      }
    }
  }
}
