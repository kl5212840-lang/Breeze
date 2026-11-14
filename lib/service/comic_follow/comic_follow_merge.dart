import 'package:zephyr/object_box/model.dart';

/// Follow membership and acknowledgement belong to the user's edit clock.
/// A successful source observation has its own clock and cannot re-follow a
/// deleted work or roll back a read acknowledgement.
ComicFollow mergeComicFollowRecord(ComicFollow local, ComicFollow incoming) {
  final sameSubscription = local.createdAt.isAtSameMomentAs(incoming.createdAt);
  if (local.deleted != incoming.deleted) {
    final removed = local.deleted ? local : incoming;
    final active = local.deleted ? incoming : local;
    // Older builds stamped updatedAt on automatic checks. A later updateTime
    // or updatedAt is not evidence of following again: only a new subscription
    // created after the recorded removal is.
    return !sameSubscription && active.createdAt.isAfter(removed.updatedAt)
        ? active
        : removed;
  }

  final edit = incoming.updatedAt.compareTo(local.updatedAt);
  final latestEdit = edit > 0 ? incoming : local;
  if (latestEdit.deleted) return latestEdit;
  if (!sameSubscription) {
    return incoming.createdAt.isAfter(local.createdAt) ? incoming : local;
  }

  final other = identical(latestEdit, local) ? incoming : local;
  final observed = other.updateTime.isAfter(latestEdit.updateTime)
      ? other
      : latestEdit;
  final acknowledged = local.lastChapterCount >= incoming.lastChapterCount
      ? local.lastChapterCount
      : incoming.lastChapterCount;
  final hasUpdate =
      observed.hasUpdate && observed.detectedChapterCount > acknowledged;
  if (identical(observed, latestEdit) &&
      latestEdit.lastChapterCount == acknowledged &&
      latestEdit.hasUpdate == hasUpdate) {
    return latestEdit;
  }
  return latestEdit.copyWith(
    lastChapterCount: acknowledged,
    detectedChapterCount: observed.detectedChapterCount,
    detectedChapterTitle: observed.detectedChapterTitle,
    hasUpdate: hasUpdate,
    updateTime: observed.updateTime,
  );
}

Map<String, dynamic> mergeComicFollowRecordJson(
  Map<String, dynamic> local,
  Map<String, dynamic> incoming,
) {
  final left = ComicFollow.fromJson(local);
  final right = ComicFollow.fromJson(incoming);
  final result = mergeComicFollowRecord(left, right);
  if (identical(result, left)) return local;
  if (identical(result, right)) return incoming;
  return result.toJson();
}
