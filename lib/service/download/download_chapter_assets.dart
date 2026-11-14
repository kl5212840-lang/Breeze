import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zephyr/main.dart' show logger, objectbox;
import 'package:zephyr/object_box/objectbox.g.dart' show TxMode;
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_chapter_removal_recovery.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

Iterable<DownloadAssetStore> chapterDownloadAssets(
  String from,
  String comicId,
  DownloadChapter chapter,
  Iterable<String> images,
) sync* {
  for (final image in images) {
    if (image.trim().isEmpty) continue;
    yield DownloadAssetStore(
      from: from,
      cartoonId: comicId,
      chapterId: chapter.id,
      storageChapterId: chapter.effectiveStorageId,
      path: image,
      pictureType: PictureType.page,
    );
  }
}

Future<void> stageDownloadAssetFile(String original, String staged) async {
  await File(original).rename(staged);
}

/// Move exclusively owned files out of their read paths, then commit metadata.
/// The caller holds the removal lease throughout staging and rollback.
Future<void> removeOwnedDownloadAssets({
  required Iterable<DownloadAssetStore> keeping,
  required Iterable<DownloadAssetStore> removing,
  required void Function() check,
  required void Function() commit,
  Future<void> Function(String original, String staged) stageFile =
      stageDownloadAssetFile,
  bool removingCanonicalOnly = false,
  bool checkEachFile = true,
  Iterable<({DownloadAssetStore asset, String taskKey})> temporaryFiles =
      const [],
}) async {
  final root = p.normalize(p.absolute(await getDownloadPath()));
  final rootType = await FileSystemEntity.type(root, followLinks: false);
  if (rootType != FileSystemEntityType.directory &&
      rootType != FileSystemEntityType.notFound) {
    throw const FileSystemException('Unsafe download root');
  }
  final canonicalRoot = rootType == FileSystemEntityType.directory
      ? await Directory(root).resolveSymbolicLinks()
      : root;

  Future<Set<String>> candidatePaths(
    Iterable<DownloadAssetStore> assets, {
    bool canonicalOnly = false,
  }) async {
    final paths = <String>{};
    for (final asset in assets) {
      final candidates = canonicalOnly
          ? [await asset.canonicalDownloadCandidate()]
          : await asset.downloadCandidates(forRemoval: true);
      for (final candidate in candidates) {
        paths.add(p.normalize(p.absolute(candidate.path)));
      }
    }
    return paths;
  }

  Future<String?> safeFile(String path) =>
      safeChapterRemovalFile(root, canonicalRoot, path);

  final keep = await candidatePaths(keeping);
  final remove = await candidatePaths(
    removing,
    canonicalOnly: removingCanonicalOnly,
  );
  for (final (:asset, :taskKey) in temporaryFiles) {
    final path = p.normalize(p.absolute(await asset.canonicalDownloadPath()));
    // Another chapter can share a legacy base filename. Leave that owner's
    // temporary path alone even when the old task suffixes happen to collide.
    if (!keep.contains(path)) {
      remove.add(DownloadAssetStore.temporaryPathFor(path, taskId: taskKey));
    }
  }
  final keepPhysical = <String>{};
  for (final path in keep) {
    final resolved = await safeFile(path);
    if (resolved != null) keepPhysical.add(resolved);
  }
  final files = <String>[];
  for (final path in remove.difference(keep)) {
    final resolved = await safeFile(path);
    if (resolved != null && !keepPhysical.contains(resolved)) files.add(path);
  }
  final recovery = files.isEmpty
      ? null
      : await DownloadChapterRemovalRecovery.begin(
          root: root,
          canonicalRoot: canonicalRoot,
          paths: files,
        );
  try {
    check();
    if (recovery != null) {
      for (final path in files) {
        if (await safeFile(path) == null) continue;
        final staged = recovery.stagedPath(path);
        if (await FileSystemEntity.type(staged, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const FileSystemException('Download staging path is in use');
        }
        if (checkEachFile) check();
        await stageFile(path, staged);
      }
    }
    objectbox.store.runInTransaction(TxMode.write, () {
      check();
      commit();
      recovery?.markDatabaseCommitted();
    });
  } catch (_) {
    await recovery?.settle();
    rethrow;
  }
  try {
    await recovery?.settle();
  } catch (_) {
    // The metadata has committed. Startup can resume cleaning the staging files.
    logger.w('已移除下载文件的清理将稍后继续');
  }
}
