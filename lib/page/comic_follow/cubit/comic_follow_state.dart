import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';

part 'comic_follow_state.freezed.dart';

enum ComicFollowStatus { initial, loading, success, failure }

enum ComicFollowFilter { all, unread }

enum ComicFollowSort { lastRead, update }

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
    if (filter == ComicFollowFilter.unread) {
      final rightUnread = hasUnreadUpdate(right);
      final leftUnread = hasUnreadUpdate(left);
      final unreadCompare = rightUnread == leftUnread
          ? 0
          : (rightUnread ? 1 : -1);
      if (unreadCompare != 0) return unreadCompare;
    }

    if (sort == ComicFollowSort.lastRead) {
      final leftTime = historyFor(left)?.lastReadAt;
      final rightTime = historyFor(right)?.lastReadAt;
      if (leftTime == null && rightTime != null) return 1;
      if (leftTime != null && rightTime == null) return -1;
      if (leftTime != null && rightTime != null) {
        final timeCompare = rightTime.compareTo(leftTime);
        if (timeCompare != 0) return timeCompare;
      }
    } else {
      final timeCompare = right.updateTime.compareTo(left.updateTime);
      if (timeCompare != 0) return timeCompare;
    }

    return right.createdAt.compareTo(left.createdAt);
  }

  bool isFollowing(String source, String comicId) {
    final key = '${source.trim()}:${comicId.trim()}';
    return items.any((item) => item.uniqueKey == key && !item.deleted);
  }
}
