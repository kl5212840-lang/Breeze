import 'dart:typed_data';

import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/local_appearance_images.dart';

class FolderCoverTarget {
  const FolderCoverTarget({
    required this.key,
    required this.name,
    required this.isCurrent,
    required this.save,
    required this.restore,
  });
  final String key, name;
  final bool Function() isCurrent;
  final Future<String> Function(Uint8List bytes, int imageRevision) save;
  final Future<bool> Function(int imageRevision) restore;
}

abstract final class FolderCoverService {
  static FolderCoverTarget comic(
    ComicFolder folder, {
    bool Function()? canRun,
    LocalAppearanceImages? images,
  }) {
    final store = images ?? LocalAppearanceImages.instance;
    final key = FolderCoverIdentity.comic(folder.syncId);
    // Capture values, never the mutable ObjectBox entity handed to the widget.
    final id = folder.syncId,
        revision = folder.versionVectorJson,
        updated = folder.updatedAt;
    bool current() {
      if (canRun?.call() == false) return false;
      final query = objectbox.comicFolderBox
          .query(ComicFolder_.syncId.equals(id))
          .build();
      try {
        final latest = query.findFirst();
        return latest != null &&
            latest.deletedAt == null &&
            latest.versionVectorJson == revision &&
            latest.updatedAt == updated;
      } finally {
        query.close();
      }
    }

    return FolderCoverTarget(
      key: key,
      name: folder.name,
      isCurrent: current,
      save: (bytes, imageRevision) => store.saveIfRevision(
        key,
        bytes,
        expectedRevision: imageRevision,
        canCommit: current,
      ),
      restore: (imageRevision) => store.removeIfRevision(
        key,
        expectedRevision: imageRevision,
        canCommit: current,
      ),
    );
  }

  static FolderCoverTarget video(
    String id,
    VideoLibraryEntry folder,
    VideoLibraryStore library, {
    bool Function()? canRun,
    LocalAppearanceImages? images,
  }) {
    final store = images ?? LocalAppearanceImages.instance;
    final key = FolderCoverIdentity.video(id);
    bool current() => canRun?.call() != false;
    return FolderCoverTarget(
      key: key,
      name: folder.data['name'] as String? ?? '',
      isCurrent: current,
      save: (bytes, imageRevision) => library.withCurrentFolder(
        id,
        folder,
        () => store.saveIfRevision(
          key,
          bytes,
          expectedRevision: imageRevision,
          canCommit: current,
        ),
      ),
      restore: (imageRevision) => library.withCurrentFolder(
        id,
        folder,
        () => store.removeIfRevision(
          key,
          expectedRevision: imageRevision,
          canCommit: current,
        ),
      ),
    );
  }

  /// Explicit folder tombstones win over artwork. Unknown IDs are retained:
  /// image and record archives may arrive separately, and names are not identity.
  static Future<void> reconcileDeleted({
    LocalAppearanceImages? images,
    VideoLibraryStore? library,
  }) async {
    final store = images ?? LocalAppearanceImages.instance;
    await store.load();
    final keys = store.paths.value.keys
        .where(FolderCoverIdentity.valid)
        .toList();
    if (keys.isEmpty) return;
    final retired = await retiredKeys(keys, library: library);
    for (final key in retired) await store.remove(key);
  }

  /// Absence is never deletion. Only an explicit tombstone or an identity
  /// retired by the committed comic merge can retire its artwork.
  static Future<Set<String>> retiredKeys(
    Iterable<String> candidates, {
    VideoLibraryStore? library,
    Set<String> retiredComicIds = const {},
  }) async {
    final keys = candidates.where(FolderCoverIdentity.valid).toSet();
    if (keys.isEmpty) return {};
    final retired = <String>{
      for (final id in retiredComicIds) FolderCoverIdentity.comic(id),
    };
    for (final folder in objectbox.comicFolderBox.getAll()) {
      if (folder.syncId.isNotEmpty && folder.deletedAt != null)
        retired.add(FolderCoverIdentity.comic(folder.syncId));
    }
    if (keys.any((key) => key.startsWith('folder-cover:video:'))) {
      final videos = await (library ?? VideoLibraryStore.shared).read();
      for (final entry in videos.folders.entries) {
        if (entry.value.deleted)
          retired.add(FolderCoverIdentity.video(entry.key));
      }
    }
    return keys.intersection(retired);
  }
}
