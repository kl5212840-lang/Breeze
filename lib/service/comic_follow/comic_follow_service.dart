import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';

export 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart'
    show ComicFollowDetection;

abstract interface class ComicFollowRepository {
  void putFollow(ComicFollow follow);
  List<ComicFollow> listActiveFollows();
  Map<String, UnifiedComicHistory> listActiveHistories();
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String uniqueKey);
  ComicFollow? getFollowByUniqueKey(String uniqueKey);
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow follow, {
    bool Function()? canContinue,
  });
  Future<void> notifyUpdate(
    int updateCount, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  });
}

class ComicFollowService implements ComicFollowRepository {
  static final ComicFollowService instance = ComicFollowService._();

  ComicFollowService._();
  final _chapterReader = ComicFollowChapterReader();

  String uniqueKey(String source, String comicId) {
    return '${source.trim()}:${comicId.trim()}';
  }

  /// 保存或更新追更记录（直接写入数据库）
  @override
  void putFollow(ComicFollow follow) {
    objectbox.comicFollowBox.put(follow);
  }

  /// 查询全部未删除的追更记录
  @override
  List<ComicFollow> listActiveFollows() {
    final query = objectbox.comicFollowBox
        .query(ComicFollow_.deleted.equals(false))
        .order(ComicFollow_.hasUpdate, flags: Order.descending)
        .order(ComicFollow_.updateTime, flags: Order.descending)
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  /// 查询未删除的阅读历史，供追更页关联阅读进度和最后阅读时间。
  @override
  Map<String, UnifiedComicHistory> listActiveHistories() {
    return {
      for (final history in objectbox.unifiedHistoryBox.getAll())
        if (!history.deleted) history.uniqueKey: history,
    };
  }

  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String uniqueKey) {
    final query = objectbox.unifiedHistoryBox
        .query(
          UnifiedComicHistory_.uniqueKey
              .equals(uniqueKey)
              .and(UnifiedComicHistory_.deleted.equals(false)),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  /// 按 uniqueKey 查询追更记录（包含已删除的），用于更新或复活旧记录
  @override
  ComicFollow? getFollowByUniqueKey(String uniqueKey) {
    final query = objectbox.comicFollowBox
        .query(ComicFollow_.uniqueKey.equals(uniqueKey))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  /// 检查章节时无需登录；只有具体作品的权限响应能要求登录。
  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow follow, {
    bool Function()? canContinue,
  }) async {
    final result = await _chapterReader.detect(
      follow,
      canContinue: canContinue,
    );
    if (result?.failure case final failure?) {
      logger.d('追更检查 ${follow.source}: ${failure.name}');
    }
    return result;
  }

  /// In-app attention follows a local preference; this never posts to the OS.
  @override
  Future<void> notifyUpdate(
    int updateCount, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  }) async {
    if (updateCount <= 0 || updates.isEmpty) return;
    try {
      await ComicFollowReminderController.instance.notifyUpdates(
        updates,
        canDeliver: canDeliver,
      );
    } catch (error, stackTrace) {
      logger.e('追更应用内提醒未能保存或显示', error: error, stackTrace: stackTrace);
    }
  }
}
