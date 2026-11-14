import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/src/rust/compressed/compressed.dart';
import 'package:zephyr/src/rust/api/simple.dart' show packFolderZip;
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

enum ComicArchiveExportStatus { saved, cancelled, failed, unavailable, busy }

class ComicArchiveEmpty implements Exception {
  const ComicArchiveEmpty();
}

enum ComicArchiveFailure { changed, noSpace, limit, unsafe, io, cancelled }

class ComicArchiveException implements Exception {
  const ComicArchiveException(this.reason);
  final ComicArchiveFailure reason;
}

Future<void> _pack(String path, PackInfo info) =>
    packFolderZip(destPath: path, packInfo: info);
Future<String?> _present(String id, String title) => const MethodChannel(
  'breeze.video.download',
).invokeMethod<String>('exportArchive', {'archiveId': id, 'title': title});

/// A single work's immutable, device-only snapshot. No source URLs or remote
/// chapter/image fetches participate in collection, packing or presentation.
class DownloadComicArchiveService {
  static bool get supported =>
      !kIsWeb &&
      const [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);
  const DownloadComicArchiveService({
    this.pack = _pack,
    this.present = _present,
    this.maxFiles = 100000,
  });
  final Future<void> Function(String, PackInfo) pack;
  final Future<String?> Function(String, String) present;
  final int maxFiles;

  Future<PreparedComicArchive> prepare(
    String source,
    String comicId, {
    bool Function()? cancelled,
  }) async {
    if (source.isEmpty || comicId.isEmpty)
      throw const FormatException('Invalid work');
    final lease = CacheWorkspaceGuard.acquire();
    Directory? folder;
    try {
      final cache = await getApplicationCacheDirectory();
      await cache.create(recursive: true);
      final cacheRoot = await cache.resolveSymbolicLinks();
      final parent = Directory(p.join(cacheRoot, 'breeze-comic-export'));
      if (await FileSystemEntity.type(parent.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileSystemException('Unsafe export staging');
      }
      await parent.create(recursive: true);
      final id = const Uuid().v4().replaceAll('-', '');
      folder = await Directory(p.join(parent.path, id)).create();
      final work = sha256.convert(utf8.encode('$source|$comicId')).toString();
      final staged = Directory(p.join(folder.path, work));
      await staged.create();
      final originals = <String>[], entries = <String>[];
      var missing = 0, emptyChapters = 0, chaptersWithFiles = 0;
      final lifecycle = DownloadResourceLifecycle.comic(
        buildDownloadTaskKey(source, comicId),
      );
      void checkCancelled() {
        if (cancelled?.call() == true)
          throw const ComicArchiveException(ComicArchiveFailure.cancelled);
      }

      final record = await runExclusiveStorageOperation(() async {
        checkCancelled();
        DownloadResourceLifecycle.requireAvailable(lifecycle);
        final current = const DownloadTaskRepository().findDownloadRecord(
          source,
          comicId,
        );
        if (current == null ||
            current.deleted ||
            current.source != source ||
            current.comicId != comicId) {
          throw const ComicArchiveException(ComicArchiveFailure.changed);
        }
        return current;
      });
      final title = record.title;
      void checkVersion() {
        checkCancelled();
        DownloadResourceLifecycle.requireAvailable(lifecycle);
        final current = const DownloadTaskRepository().findDownloadRecord(
          source,
          comicId,
        );
        if (current == null || !_sameVersion(record, current)) {
          throw const ComicArchiveException(ComicArchiveFailure.changed);
        }
      }

      final root = p.normalize(p.absolute(await getDownloadPath()));
      final canonical = await Directory(root).resolveSymbolicLinks();
      if (await FileSystemEntity.type(root, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const ComicArchiveException(ComicArchiveFailure.unsafe);
      }
      final chapterSummary = <Map<String, Object>>[];
      final signatures = <(File, FileStat)>[];
      final chapters = resolveDownloadChapters(record);
      if (chapters.length > maxFiles)
        throw const ComicArchiveException(ComicArchiveFailure.limit);
      for (var ci = 0; ci < chapters.length; ci++) {
        final chapter = chapters[ci];
        var count = 0;
        if (chapter.images.length > maxFiles)
          throw const ComicArchiveException(ComicArchiveFailure.limit);
        for (var pi = 0; pi < chapter.images.length; pi++) {
          checkCancelled();
          final image = chapter.images[pi];
          if (image.extern['downloadSkipped'] == true) continue;
          // Yield the shared operation queue between files. Packing and the
          // user's picker interaction never hold this storage mutex.
          final copied = await runExclusiveStorageOperation(() async {
            checkVersion();
            final store = DownloadAssetStore(
              from: source,
              cartoonId: comicId,
              chapterId: chapter.id,
              storageChapterId: chapter.effectiveStorageId,
              path: image.path,
              pictureType: PictureType.page,
            );
            File? owned;
            for (final candidate in await store.downloadCandidates()) {
              final type = await FileSystemEntity.type(
                candidate.path,
                followLinks: false,
              );
              if (type == FileSystemEntityType.notFound) continue;
              if (type != FileSystemEntityType.file)
                throw const ComicArchiveException(ComicArchiveFailure.unsafe);
              final file = File(candidate.path);
              final actual = await file.resolveSymbolicLinks();
              final logical = p.normalize(p.absolute(file.path));
              if (!p.isWithin(root, logical) ||
                  actual !=
                      p.join(canonical, p.relative(logical, from: root))) {
                throw const ComicArchiveException(ComicArchiveFailure.unsafe);
              }
              if (await file.length() > 0) {
                owned = file;
                break;
              }
            }
            if (owned == null) {
              missing++;
              return false;
            }
            if (originals.length >= maxFiles)
              throw const ComicArchiveException(ComicArchiveFailure.limit);
            final before = await owned.stat();
            final entry =
                '${(ci + 1).toString().padLeft(4, '0')}_${_safe(chapter.displayName)}/${(pi + 1).toString().padLeft(5, '0')}${await _extension(owned)}';
            final target = File(
              p.join(staged.path, '${originals.length}.image'),
            );
            final input = await owned.open();
            var length = 0;
            try {
              final output = await target.open(mode: FileMode.write);
              try {
                while (true) {
                  checkCancelled();
                  final block = await input.read(128 * 1024);
                  if (block.isEmpty) break;
                  length += block.length;
                  if (length > before.size)
                    throw const ComicArchiveException(
                      ComicArchiveFailure.changed,
                    );
                  await output.writeFrom(block);
                }
                await output.flush();
              } finally {
                await output.close();
              }
            } finally {
              await input.close();
            }
            final after = await owned.stat();
            if (length != before.size || !_sameFile(before, after)) {
              throw const ComicArchiveException(ComicArchiveFailure.changed);
            }
            checkVersion();
            signatures.add((owned, after));
            originals.add(target.path);
            entries.add(entry);
            return true;
          });
          if (copied) count++;
        }
        if (count == 0) {
          emptyChapters++;
        } else {
          chaptersWithFiles++;
        }
        chapterSummary.add({'name': chapter.displayName, 'files': count});
      }
      // File-only writers can run outside the metadata queue: reject a changed
      // source signature as well as a changed work version before confirmation.
      for (final entry in signatures) {
        checkCancelled();
        if (!_sameFile(entry.$2, await entry.$1.stat())) {
          throw const ComicArchiveException(ComicArchiveFailure.changed);
        }
      }
      await runExclusiveStorageOperation(() async {
        checkVersion();
      });
      if (originals.isEmpty) throw const ComicArchiveEmpty();
      final summary = jsonEncode({
        'source': source,
        'comicId': comicId,
        'title': title,
        'scope': 'downloaded-files-only',
        'missingImages': missing,
        'chaptersWithoutFiles': emptyChapters,
        'chapters': chapterSummary,
      });
      return PreparedComicArchive._(
        id,
        title,
        chaptersWithFiles,
        originals.length,
        missing,
        emptyChapters,
        folder,
        staged,
        lease,
        PackInfo(
          comicInfoString: summary,
          processedComicInfoString: summary,
          originalImagePaths: originals,
          packImagePaths: entries,
        ),
        pack,
        present,
        cancelled,
      );
    } catch (error) {
      try {
        if (folder != null && await folder.exists())
          await folder.delete(recursive: true);
      } finally {
        lease.release();
      }
      if (error is ComicArchiveEmpty || error is ComicArchiveException) rethrow;
      throw ComicArchiveException(_reason(error));
    }
  }
}

class PreparedComicArchive {
  PreparedComicArchive._(
    this.archiveId,
    this.title,
    this.chapters,
    this.pages,
    this.missingPages,
    this.unavailableChapters,
    this._folder,
    this._staged,
    this._lease,
    this._info,
    this._pack,
    this._present,
    this._cancelled,
  );
  final String archiveId, title;
  final int chapters, pages, missingPages, unavailableChapters;
  final Directory _folder;
  final Directory _staged;
  final CacheWorkspaceLease _lease;
  final PackInfo _info;
  final Future<void> Function(String, PackInfo) _pack;
  final Future<String?> Function(String, String) _present;
  final bool Function()? _cancelled;
  ComicArchiveFailure? failure;
  Future<ComicArchiveExportStatus>? _running;
  var _disposed = false, _used = false;
  Future<ComicArchiveExportStatus> export() {
    if (_used || _disposed)
      return Future.value(ComicArchiveExportStatus.failed);
    _used = true;
    return _running = _export();
  }

  Future<ComicArchiveExportStatus> _export() async {
    try {
      if (_cancelled?.call() == true) return ComicArchiveExportStatus.cancelled;
      final file = File(p.join(_folder.path, 'archive.zip'));
      await _pack(file.path, _info);
      if (_disposed || _cancelled?.call() == true)
        return ComicArchiveExportStatus.cancelled;
      if (!await file.exists() || await file.length() < 4)
        return ComicArchiveExportStatus.failed;
      try {
        await _staged.delete(recursive: true);
      } on FileSystemException {
        // A complete archive can still be saved. Disposal retries cleanup.
      }
      if (_disposed || _cancelled?.call() == true)
        return ComicArchiveExportStatus.cancelled;
      final status = await _present(archiveId, title);
      return ComicArchiveExportStatus.values.firstWhere(
        (value) => value.name == status,
        orElse: () => ComicArchiveExportStatus.failed,
      );
    } on MissingPluginException {
      return ComicArchiveExportStatus.unavailable;
    } catch (error) {
      failure = _reason(error);
      return ComicArchiveExportStatus.failed;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _running;
    try {
      if (await _folder.exists()) await _folder.delete(recursive: true);
    } finally {
      _lease.release();
    }
  }
}

// Reuse the stored strings so each page check does not re-encode the work.
bool _sameVersion(UnifiedComicDownload a, UnifiedComicDownload b) =>
    a.id == b.id &&
    a.uniqueKey == b.uniqueKey &&
    a.source == b.source &&
    a.comicId == b.comicId &&
    a.deleted == b.deleted &&
    a.updatedAt.microsecondsSinceEpoch == b.updatedAt.microsecondsSinceEpoch &&
    a.chapters == b.chapters &&
    a.detailJson == b.detailJson;
String _safe(String text) {
  final clean = text.replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), ' ').trim();
  return clean.isEmpty ? 'chapter' : String.fromCharCodes(clean.runes.take(60));
}

Future<String> _extension(File file) async {
  final input = await file.open();
  try {
    final b = await input.read(12);
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff)
      return '.jpg';
    if (b.length >= 4 &&
        b[0] == 137 &&
        ascii.decode(b.sublist(1, 4), allowInvalid: true) == 'PNG')
      return '.png';
    if (b.length >= 3 &&
        ascii.decode(b.sublist(0, 3), allowInvalid: true) == 'GIF')
      return '.gif';
    if (b.length >= 12 &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP')
      return '.webp';
    return '.bin';
  } finally {
    await input.close();
  }
}

bool _sameFile(FileStat a, FileStat b) =>
    a.type == FileSystemEntityType.file &&
    b.type == FileSystemEntityType.file &&
    a.size == b.size &&
    a.modified == b.modified &&
    a.changed == b.changed;
ComicArchiveFailure _reason(Object error) {
  if (error is ComicArchiveException) return error.reason;
  if (error is StateError) return ComicArchiveFailure.changed;
  if (error is FileSystemException &&
      const [28, 112, 122].contains(error.osError?.errorCode))
    return ComicArchiveFailure.noSpace;
  final text = error.toString().toLowerCase();
  if (text.contains('no space left') ||
      text.contains('os error 28') ||
      text.contains('disk full'))
    return ComicArchiveFailure.noSpace;
  return ComicArchiveFailure.io;
}
