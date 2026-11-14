import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/service/comic_follow/comic_follow_foreground_scheduler.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';

class _Repository implements ComicFollowRepository {
  ComicFollow? row;
  int checks = 0;

  @override
  List<ComicFollow> listActiveFollows() => [?row];

  @override
  Map<String, UnifiedComicHistory> listActiveHistories() => {};

  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String key) => null;

  @override
  ComicFollow? getFollowByUniqueKey(String uniqueKey) => row;

  @override
  void putFollow(ComicFollow follow) => row = follow;

  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow follow, {
    bool Function()? canContinue,
  }) async {
    checks++;
    return const ComicFollowDetection(
      chapterCount: 10,
      latestChapterTitle: 'Chapter 10',
    );
  }

  @override
  Future<void> notifyUpdate(
    int count, {
    Map<String, int> updates = const {},
    bool Function(String key, int chapterCount)? canDeliver,
  }) async {}
}

void main() {
  testWidgets('a due follow restored while idle wakes the foreground check', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 12, 12);
    final repository = _Repository();
    final cubit = ComicFollowCubit(repository: repository, now: () => now);
    final scheduler = ComicFollowForegroundScheduler(
      cubit: cubit,
      observeLifecycle: false,
      lifecycleState: () => AppLifecycleState.resumed,
    );
    const minute = Duration(minutes: 1);
    try {
      scheduler.start();
      now = now.add(minute);
      await tester.pump(minute);
      expect(repository.checks, 0);

      final previousCheck = now.subtract(const Duration(hours: 1));
      repository.row = ComicFollow(
        uniqueKey: 'fixture:1',
        source: 'fixture',
        comicId: '1',
        title: 'Example',
        description: '',
        cover: '',
        creator: '',
        titleMeta: '',
        metadata: '',
        lastChapterCount: 10,
        detectedChapterCount: 10,
        detectedChapterTitle: 'Chapter 10',
        hasUpdate: false,
        updateTime: previousCheck,
        deleted: false,
        createdAt: previousCheck,
        updatedAt: previousCheck,
        schemaVersion: 1,
      );
      await cubit.loadFromDatabase();
      await tester.pump();
      expect(repository.checks, 0);

      now = now.add(minute);
      await tester.pump(minute);
      await tester.pump();
      expect(repository.checks, 1);
    } finally {
      scheduler.dispose();
      await cubit.close();
    }
  });
}
