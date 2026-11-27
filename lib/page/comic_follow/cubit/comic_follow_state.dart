import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';

part 'comic_follow_state.freezed.dart';

enum ComicFollowStatus { initial, loading, success, failure }

enum ComicFollowFilter { all, unread }

enum ComicFollowSort { lastRead, recentUpdate, update }

@freezed
abstract class ComicFollowState with _$ComicFollowState {
  const ComicFollowState._();

  const factory ComicFollowState({
    @Default(ComicFollowStatus.initial) ComicFollowStatus status,
    @Default(<ComicFollow>[]) List<ComicFollow> items,
    @Default(false) bool isCheckingUpdates,
    @Default(<String>{}) Set<String> checkingKeys,
    @Default(<String, ComicFollowCheckFailure>{})
    Map<String, ComicFollowCheckFailure> checkErrors,
    @Default(<String, DateTime>{}) Map<String, DateTime> lastAttempts,
    @Default('') String result,
    @Default(0) int revision,
    @Default(<String, UnifiedComicHistory>{})
    Map<String, UnifiedComicHistory> histories,
    @Default(ComicFollowFilter.all) ComicFollowFilter filter,
    @Default(ComicFollowSort.lastRead) ComicFollowSort sort,
  }) = _ComicFollowState;

  int get updateCount => items.where(hasUnreadUpdate).length;

  List<ComicFollow> get visibleItems {
    final result = items
        .where(
          (item) => filter == ComicFollowFilter.all || hasUnreadUpdate(item),
        )
        .toList();
    result.sort(_compareItems);
    return result;
  }

  UnifiedComicHistory? historyFor(ComicFollow follow) =>
      histories[follow.uniqueKey];

  // A plugin's order is a sorting key, not a count of read chapters.
  bool hasUnreadUpdate(ComicFollow follow) =>
      follow.hasUpdate && follow.detectedChapterCount > follow.lastChapterCount;

  int unreadChapterCount(ComicFollow follow) {
    if (!hasUnreadUpdate(follow)) return 0;

    return (follow.detectedChapterCount - follow.lastChapterCount).clamp(
      0,
      follow.detectedChapterCount,
    );
  }

  int _compareItems(ComicFollow left, ComicFollow right) {
    final (leftTime, rightTime) = switch (sort) {
      ComicFollowSort.lastRead => (
        historyFor(left)?.lastReadAt,
        historyFor(right)?.lastReadAt,
      ),
      ComicFollowSort.recentUpdate => (
        left.lastChapterUpdateAt,
        right.lastChapterUpdateAt,
      ),
      ComicFollowSort.update => (left.updateTime, right.updateTime),
    };
    if (leftTime == null && rightTime != null) return 1;
    if (leftTime != null && rightTime == null) return -1;
    if (leftTime != null && rightTime != null) {
      final byTime = rightTime.compareTo(leftTime);
      if (byTime != 0) return byTime;
    }

    // Older rows have no observation time. Put their unseen updates first
    // without treating later routine checks as chapter arrivals.
    if (sort == ComicFollowSort.recentUpdate && leftTime == null) {
      final leftUnread = hasUnreadUpdate(left);
      if (leftUnread != hasUnreadUpdate(right)) return leftUnread ? -1 : 1;
    }

    final byCreated = right.createdAt.compareTo(left.createdAt);
    return byCreated != 0
        ? byCreated
        : left.uniqueKey.compareTo(right.uniqueKey);
  }

  bool isFollowing(String source, String comicId) {
    final key = '${source.trim()}:${comicId.trim()}';
    return items.any((item) => item.uniqueKey == key && !item.deleted);
  }
}
