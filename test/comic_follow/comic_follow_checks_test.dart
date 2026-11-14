import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/service/comic_follow/comic_follow_foreground_scheduler.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';

import '../test_helper.dart';

ComicFollow _follow(String id, DateTime time, {String source = 'fixture'}) =>
    ComicFollow(
      id: int.parse(id),
      uniqueKey: '$source:$id',
      source: source,
      comicId: id,
      title: 'Fixture $id',
      description: '',
      cover: '',
      creator: '',
      titleMeta: '',
      metadata: '',
      lastChapterCount: 10,
      detectedChapterCount: 10,
      detectedChapterTitle: 'Previous chapter',
      hasUpdate: false,
      updateTime: time,
      deleted: false,
      createdAt: time,
      updatedAt: time,
      schemaVersion: 1,
    );

UnifiedComicHistory _history(ComicFollow row, String chapterId, DateTime now) =>
    UnifiedComicHistory(
      uniqueKey: row.uniqueKey,
      source: row.source,
      comicId: row.comicId,
      title: row.title,
      description: '',
      cover: '',
      creator: '',
      titleMeta: '',
      metadata: '',
      chapterId: chapterId,
      chapterTitle: '',
      chapterOrder: 100,
      pageIndex: 0,
      createdAt: now,
      lastReadAt: now,
      updatedAt: now,
      deleted: false,
      schemaVersion: 2,
    );

class _Repository implements ComicFollowRepository {
  _Repository(List<ComicFollow> items)
    : rows = {for (final row in items) row.uniqueKey: row};
  final Map<String, ComicFollow> rows;
  final histories = <String, UnifiedComicHistory>{};
  final calls = <String>[];
  int writes = 0;
  final notifications = <Map<String, int>>[];
  Future<ComicFollowDetection?> Function(ComicFollow)? detect;
  @override
  List<ComicFollow> listActiveFollows() => rows.values
      .where((row) => !row.deleted)
      .map((row) => row.copyWith())
      .toList();
  @override
  Map<String, UnifiedComicHistory> listActiveHistories() => {...histories};
  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String key) =>
      histories[key];
  @override
  ComicFollow? getFollowByUniqueKey(String key) =>
      rows[key]?.copyWith(lastCheckFailed: false);
  @override
  void putFollow(ComicFollow follow) {
    writes++;
    rows[follow.uniqueKey] = follow.copyWith();
  }

  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow follow, {
    bool Function()? canContinue,
  }) async {
    calls.add(follow.uniqueKey);
    return detect != null
        ? await detect!(follow)
        : const ComicFollowDetection(
            chapterCount: 12,
            latestChapterTitle: 'New chapter',
          );
  }

  @override
  Future<void> notifyUpdate(
    int count, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  }) async {
    notifications.add({...updates});
  }
}

class _FollowTimer implements Timer {
  _FollowTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool _active = true;
  int _tick = 0;
  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  @override
  void cancel() => _active = false;
  void fire() {
    if (!_active) return;
    _active = false;
    _tick++;
    callback();
  }
}

Future<void> _drainFollowWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'follow reads the saved reader chapter and excludes deleted history',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await TestObjectBoxHelper.setUpTestObjectBox();
      addTearDown(TestObjectBoxHelper.tearDownTestObjectBox);
      final now = DateTime.utc(2026, 11, 12);
      final row = _follow('1', now);
      final service = ComicFollowService.instance;

      expect(service.getActiveHistoryByUniqueKey(row.uniqueKey), isNull);
      applyReaderHistorySnapshot(objectbox, {
        'source': row.source,
        'comicId': row.comicId,
        'normalInfo': {
          'id': row.comicId,
          'title': row.title,
          'description': '',
          'titleMeta': [],
          'cover': {'id': '', 'name': '', 'url': ''},
          'metadata': [],
        },
        'chapterId': 'saved-logical-id',
        'chapterTitle': 'Saved chapter',
        'chapterOrder': 200,
        'pageIndex': 6,
        'timestamp': now.toIso8601String(),
      });
      final history = service.getActiveHistoryByUniqueKey(row.uniqueKey)!;
      expect(history.chapterId, 'saved-logical-id');
      expect(history.chapterOrder, 200);
      expect(history.pageIndex, 6);
      objectbox.unifiedHistoryBox.put(history..deleted = true);
      expect(service.getActiveHistoryByUniqueKey(row.uniqueKey), isNull);
    },
  );

  test(
    'automatic checks require a visible page, respect freshness, and bound each batch',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repo = _Repository([
        for (var i = 1; i <= 6; i++)
          _follow('$i', now.subtract(const Duration(hours: 1))),
      ]);
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      expect(await cubit.checkDueUpdates(), 0);
      expect(repo.calls, isEmpty);
      cubit.setAutomaticCheckingActive(true);
      await cubit.checkDueUpdates();
      expect(repo.calls.length, 4);
      await cubit.checkDueUpdates();
      expect(
        repo.calls.length,
        4,
        reason: 'rapid re-entry must not start another automatic batch',
      );
      now = now.add(const Duration(minutes: 1));
      await cubit.checkDueUpdates();
      expect(repo.calls.length, 6);
      now = now.add(const Duration(minutes: 1));
      await cubit.checkDueUpdates();
      expect(
        repo.calls.length,
        6,
        reason: 'fresh successful observations are not polled again',
      );
    },
  );

  test('row retry and whole-list refresh share real in-flight work', () async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final row = _follow('1', now.subtract(const Duration(hours: 1)));
    final pending = Completer<ComicFollowDetection?>();
    final repo = _Repository([row])..detect = (_) => pending.future;
    final cubit = ComicFollowCubit(repository: repo, now: () => now);
    addTearDown(cubit.close);
    cubit.setAutomaticCheckingActive(true);
    final single = cubit.checkUpdateForItem(row);
    final duplicate = cubit.checkUpdateForItem(row);
    final whole = cubit.checkUpdates();
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, [row.uniqueKey]);
    expect(cubit.state.checkingKeys, {row.uniqueKey});
    expect(cubit.state.isCheckingUpdates, isTrue);
    pending.complete(
      const ComicFollowDetection(
        chapterCount: 12,
        latestChapterTitle: 'New chapter',
      ),
    );
    await Future.wait([single, duplicate, whole]);
    expect(repo.writes, 1);
    expect(cubit.state.checkingKeys, isEmpty);
    expect(cubit.state.isCheckingUpdates, isFalse);
  });

  test(
    'a pull after resume waits for the obsolete check, then reads fresh',
    () async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final row = _follow('1', now.subtract(const Duration(hours: 1)));
      final old = Completer<ComicFollowDetection?>();
      final repo = _Repository([row]);
      repo.detect = (_) => repo.calls.length == 1
          ? old.future
          : Future.value(
              const ComicFollowDetection(
                chapterCount: 11,
                latestChapterTitle: 'Current chapter',
              ),
            );
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      final first = cubit.checkDueUpdates();
      await _drainFollowWork();
      cubit.setAutomaticCheckingActive(false);
      cubit.setAutomaticCheckingActive(true);
      final pull = cubit.checkUpdatesForRefresh();
      expect(repo.calls, [row.uniqueKey]);
      old.complete(
        const ComicFollowDetection(
          chapterCount: 99,
          latestChapterTitle: 'Obsolete response',
        ),
      );
      await first;
      expect(await pull, ComicFollowRefreshStatus.updated);
      expect(repo.calls, [row.uniqueKey, row.uniqueKey]);
      expect(cubit.state.items.single.detectedChapterCount, 11);
      expect(repo.notifications, [
        {row.uniqueKey: 11},
      ]);
    },
  );

  test('an observation does not become a newer user change', () async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final row = _follow('1', now.subtract(const Duration(hours: 1)));
    final repo = _Repository([row]);
    final cubit = ComicFollowCubit(repository: repo, now: () => now);
    addTearDown(cubit.close);
    cubit.setAutomaticCheckingActive(true);
    await cubit.checkDueUpdates();
    expect(repo.rows[row.uniqueKey]!.updateTime, now);
    expect(repo.rows[row.uniqueKey]!.updatedAt, row.updatedAt);
    expect(repo.rows[row.uniqueKey]!.detectedChapterCount, 12);
    expect(repo.rows[row.uniqueKey]!.lastChapterCount, 10);
  });

  test(
    'a source outage leaves unattempted rows alone and other sources run',
    () async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final due = now.subtract(const Duration(hours: 1));
      final repo =
          _Repository([
              _follow('1', due),
              _follow('2', due.add(const Duration(seconds: 1))),
              _follow('3', due.add(const Duration(seconds: 2))),
              _follow(
                '4',
                due.add(const Duration(seconds: 3)),
                source: 'healthy',
              ),
            ])
            ..detect = (row) async => row.source == 'fixture'
                ? const ComicFollowDetection.failed(
                    ComicFollowCheckFailure.sourceUnavailable,
                  )
                : const ComicFollowDetection(
                    chapterCount: 12,
                    latestChapterTitle: 'Public chapter',
                  );
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      expect(
        await cubit.checkUpdatesForRefresh(),
        ComicFollowRefreshStatus.partial,
      );
      expect(repo.calls, ['fixture:1', 'fixture:2', 'healthy:4']);
      expect(cubit.state.lastAttempts['fixture:3'], isNull);
      expect(cubit.incompleteCheckCount, 3);
      expect(repo.notifications, [
        {'healthy:4': 12},
      ]);
      repo.detect = (_) async => const ComicFollowDetection(
        chapterCount: 10,
        latestChapterTitle: 'Previous chapter',
      );
      await cubit.checkUpdateForItem(repo.rows['fixture:3']!);
      expect(repo.calls.last, 'fixture:3');
      expect(cubit.incompleteCheckCount, 2);
    },
  );

  test('an explicit sign-in requirement only affects that title', () async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final due = now.subtract(const Duration(hours: 1));
    final repo =
        _Repository([
            _follow('1', due),
            _follow('2', due.add(const Duration(seconds: 1))),
            _follow('3', due.add(const Duration(seconds: 2))),
          ])
          ..detect = (row) async => row.comicId != '3'
              ? const ComicFollowDetection.failed(
                  ComicFollowCheckFailure.signInRequired,
                )
              : const ComicFollowDetection(
                  chapterCount: 12,
                  latestChapterTitle: 'Public chapter',
                );
    final cubit = ComicFollowCubit(repository: repo, now: () => now);
    addTearDown(cubit.close);
    cubit.setAutomaticCheckingActive(true);
    expect(
      await cubit.checkUpdatesForRefresh(),
      ComicFollowRefreshStatus.partial,
    );
    expect(repo.calls, ['fixture:1', 'fixture:2', 'fixture:3']);
    expect(repo.notifications, [
      {'fixture:3': 12},
    ]);
  });

  test('a new update is acknowledged by chapter identity, not order', () async {
    final now = DateTime.utc(2026, 11, 12);
    final rows = [_follow('1', now), _follow('2', now)];
    final repo = _Repository(rows)
      ..detect = (_) async => const ComicFollowDetection(
        chapterCount: 12,
        latestChapterTitle: 'New chapter',
        latestChapterId: 'latest',
      );
    for (final row in rows) {
      repo.histories[row.uniqueKey] = _history(
        row,
        row.comicId == '1' ? 'earlier' : 'latest',
        now,
      );
    }
    final cubit = ComicFollowCubit(repository: repo, now: () => now);
    addTearDown(cubit.close);
    cubit.setAutomaticCheckingActive(true);
    await cubit.checkUpdatesForRefresh();
    expect(cubit.state.updateCount, 1);
    expect(repo.rows['fixture:1']?.lastChapterCount, 10);
    expect(repo.rows['fixture:2']?.lastChapterCount, 12);
    expect(repo.notifications, [
      {'fixture:1': 12},
    ]);
  });

  test(
    'foreground checks use a newly saved reader identity without opening follow',
    () async {
      final now = DateTime.utc(2026, 11, 12);
      final row = _follow('1', now);
      final repo = _Repository([row])
        ..detect = (_) async => const ComicFollowDetection(
          chapterCount: 12,
          latestChapterTitle: 'Latest chapter',
          latestChapterId: 'latest',
        );
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      expect(cubit.state.historyFor(row), isNull);
      repo.histories[row.uniqueKey] = _history(row, 'latest', now);

      await cubit.checkUpdatesForRefresh();

      expect(cubit.state.updateCount, 0);
      expect(repo.rows[row.uniqueKey]?.lastChapterCount, 12);
      expect(repo.notifications, isEmpty);
    },
  );

  test(
    'reading the latest chapter mid-batch cancels its pending reminder',
    () async {
      final now = DateTime.utc(2026, 11, 12);
      final first = _follow('1', now.subtract(const Duration(hours: 2)));
      final second = _follow('2', now.subtract(const Duration(hours: 1)));
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([first, second])
        ..detect = (row) => row.comicId == '1'
            ? Future.value(
                const ComicFollowDetection(
                  chapterCount: 12,
                  latestChapterTitle: 'Latest chapter',
                  latestChapterId: 'latest',
                ),
              )
            : pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      final refresh = cubit.checkUpdatesForRefresh();
      await _drainFollowWork();
      expect(repo.calls, [first.uniqueKey, second.uniqueKey]);
      expect(cubit.state.updateCount, 1);
      repo.histories[first.uniqueKey] = _history(first, 'latest', now);
      pending.complete(
        const ComicFollowDetection(
          chapterCount: 10,
          latestChapterTitle: 'Previous chapter',
        ),
      );

      await refresh;

      expect(repo.notifications, isEmpty);
      await cubit.refreshHistories();
      expect(cubit.state.updateCount, 0);
      expect(repo.rows[first.uniqueKey]?.lastChapterCount, 12);
    },
  );

  test(
    'full chapter lists recognize a unique legacy chapter ID without replaying reminders',
    () async {
      final now = DateTime.utc(2026, 11, 12);
      final row = _follow(
        '1',
        now,
      ).copyWith(lastChapterCount: 1, detectedChapterCount: 1);
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, comicId, _) async => {
          'data': {
            'normal': {
              'comicInfo': {'id': comicId},
              'eps': [
                {'id': 'opening', 'name': 'Opening', 'order': 100},
                {
                  'id': 'ending',
                  'logicalKey': 'ending-key',
                  'requestId': 'old-request-ending',
                  'name': 'Ending',
                  'order': 0,
                },
              ],
            },
          },
        },
      );
      final repo = _Repository([row])
        ..histories[row.uniqueKey] = _history(row, 'old-request-ending', now)
        ..detect = (follow) => reader.detect(follow);
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);

      await cubit.checkUpdatesForRefresh();
      await cubit.checkUpdatesForRefresh();

      expect(repo.rows[row.uniqueKey]?.detectedChapterTitle, 'Ending');
      expect(repo.rows[row.uniqueKey]?.lastChapterCount, 2);
      expect(cubit.state.updateCount, 0);
      expect(repo.notifications, isEmpty);
    },
  );

  test(
    'a pull finishes the remaining rows of an automatic batch without duplicate requests',
    () async {
      final now = DateTime.utc(2026, 11, 2, 12);
      const unchanged = ComicFollowDetection(
        chapterCount: 10,
        latestChapterTitle: 'Previous chapter',
      );
      final first = Completer<ComicFollowDetection?>();
      final remaining = Completer<ComicFollowDetection?>();
      final repo = _Repository(
        [
          _follow('1', now.subtract(const Duration(hours: 1))),
          _follow('2', now),
        ],
      )..detect = (row) => row.comicId == '1' ? first.future : remaining.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      final background = cubit.checkDueUpdates();
      await _drainFollowWork();
      expect(repo.calls, ['fixture:1']);
      final pull = cubit.checkUpdatesForRefresh();
      final repeat = cubit.checkUpdatesForRefresh();
      first.complete(unchanged);
      await _drainFollowWork();
      expect(repo.calls, ['fixture:1', 'fixture:2']);
      expect(cubit.state.checkingKeys, {'fixture:2'});
      expect(cubit.state.isCheckingUpdates, isTrue);
      remaining.complete(unchanged);
      expect(await pull, ComicFollowRefreshStatus.unchanged);
      expect(await repeat, ComicFollowRefreshStatus.unchanged);
      expect(await background, 0);
      expect(repo.calls, ['fixture:1', 'fixture:2']);
    },
  );

  test(
    'failures preserve the last successful source result and use exponential backoff',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final old = now.subtract(const Duration(hours: 1));
      final row = _follow('1', old);
      final repo = _Repository([row])
        ..detect = (_) async => const ComicFollowDetection(
          chapterCount: null,
          latestChapterTitle: '',
          failure: ComicFollowCheckFailure.network,
        );
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      await cubit.checkDueUpdates();
      expect(cubit.state.items.single.detectedChapterTitle, 'Previous chapter');
      expect(cubit.state.items.single.updateTime, old);
      expect(cubit.state.items.single.updatedAt, old);
      expect(
        cubit.state.checkErrors[row.uniqueKey],
        ComicFollowCheckFailure.network,
      );
      expect(
        repo.writes,
        0,
        reason:
            'a failed check must not publish stale content as a newer database observation',
      );
      expect(cubit.nextAutomaticCheckDelay, const Duration(minutes: 1));
      now = now.add(const Duration(minutes: 1));
      await cubit.checkDueUpdates();
      expect(cubit.nextAutomaticCheckDelay, const Duration(minutes: 2));
      now = now.add(const Duration(minutes: 1));
      await cubit.checkDueUpdates();
      expect(repo.calls.length, 2);
    },
  );

  for (final mutation in [
    'delete',
    'detail',
    'reload',
    'leave',
    'close',
    'account',
  ]) {
    test('late result cannot overwrite $mutation', () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final row = _follow('1', now.subtract(const Duration(hours: 1)));
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([row])..detect = (_) => pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      cubit.setAutomaticCheckingActive(true);
      final work = cubit.checkUpdateForItem(row);
      now = now.add(const Duration(seconds: 1));
      switch (mutation) {
        case 'delete':
          await cubit.removeFollow(row.source, row.comicId);
        case 'detail':
          cubit.syncFollowFromDetailAndPersist(
            source: row.source,
            comicId: row.comicId,
            onlineChapterCount: 20,
            onlineLatestTitle: 'Newer detail result',
          );
        case 'reload':
          await cubit.loadFromDatabase();
        case 'leave':
          cubit.setAutomaticCheckingActive(false);
        case 'close':
          await cubit.close();
        case 'account':
          final owner = pluginSessionWriteFence.beginSessionChange(row.source);
          pluginSessionWriteFence.seal(row.source, owner);
      }
      final writesBefore = repo.writes;
      pending.complete(
        const ComicFollowDetection(
          chapterCount: 12,
          latestChapterTitle: 'Late result',
        ),
      );
      expect(await work, isFalse);
      expect(repo.writes, writesBefore);
      if (mutation == 'delete') expect(cubit.state.items, isEmpty);
      if (mutation == 'detail') {
        expect(cubit.state.items.single.detectedChapterCount, 20);
      }
      if (mutation == 'account') {
        expect(repo.notifications, isEmpty);
        expect(cubit.state.checkErrors, isEmpty);
        repo.detect = null;
        expect(await cubit.checkUpdateForItem(row), isTrue);
        expect(repo.writes, writesBefore + 1);
      }
      if (!cubit.isClosed) await cubit.close();
    });
  }

  test(
    'late detail cannot revive a follow removed by external restore',
    () async {
      final time = DateTime.utc(2026, 11, 12);
      final row = _follow('1', time);
      final repo = _Repository([row]);
      final cubit = ComicFollowCubit(repository: repo);
      addTearDown(cubit.close);
      repo.rows.clear();

      expect(
        cubit.syncFollowFromDetailAndPersist(
          source: row.source,
          comicId: row.comicId,
          onlineChapterCount: 14,
          onlineLatestTitle: 'Late detail',
        ),
        isNull,
      );
      expect(repo.rows, isEmpty);
      expect(repo.writes, 0);
    },
  );

  test(
    'unfollow writes the persisted row identity and metadata after merge',
    () async {
      final time = DateTime.utc(2026, 11, 12);
      final row = _follow('1', time);
      final repo = _Repository([row]);
      final cubit = ComicFollowCubit(repository: repo, now: () => time);
      addTearDown(cubit.close);
      final restored = row.copyWith(id: 23, title: 'Restored title');
      repo.rows[row.uniqueKey] = restored;

      await cubit.removeFollow(row.source, row.comicId);

      final saved = repo.rows[row.uniqueKey]!;
      expect(saved.deleted, isTrue);
      expect(saved.id, restored.id);
      expect(saved.title, restored.title);
      expect(saved.updatedAt.isAfter(restored.updatedAt), isTrue);
    },
  );

  test(
    'mark all as read preserves the newest persisted chapter observation',
    () async {
      final time = DateTime.utc(2026, 11, 12);
      final row = _follow(
        '1',
        time,
      ).copyWith(detectedChapterCount: 11, hasUpdate: true);
      final repo = _Repository([row]);
      final cubit = ComicFollowCubit(repository: repo, now: () => time);
      addTearDown(cubit.close);
      final restored = row.copyWith(id: 23, detectedChapterCount: 13);
      repo.rows[row.uniqueKey] = restored;

      await cubit.markAllAsRead();

      final saved = repo.rows[row.uniqueKey]!;
      expect(saved.id, restored.id);
      expect(saved.detectedChapterCount, 13);
      expect(saved.lastChapterCount, 13);
      expect(saved.hasUpdate, isFalse);
    },
  );

  test(
    'leaving during an automatic batch prevents subsequent source calls',
    () async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([
        _follow('1', now.subtract(const Duration(hours: 1))),
        _follow('2', now.subtract(const Duration(hours: 1))),
      ])..detect = (_) => pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      final batch = cubit.checkDueUpdates();
      await Future<void>.delayed(Duration.zero);
      cubit.setAutomaticCheckingActive(false);
      pending.complete(
        const ComicFollowDetection(
          chapterCount: 12,
          latestChapterTitle: 'Late result',
        ),
      );
      await batch;
      expect(repo.calls.length, 1);
      expect(repo.writes, 0);
    },
  );
  test(
    'fresh successful growth is merged once and repeated reads do not repeat attention',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repo = _Repository([
        _follow('1', now.subtract(const Duration(hours: 1))),
        _follow('2', now.subtract(const Duration(hours: 1))),
      ]);
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      addTearDown(cubit.close);
      cubit.setAutomaticCheckingActive(true);
      await cubit.checkUpdates();
      expect(repo.notifications, [
        {'fixture:1': 12, 'fixture:2': 12},
      ]);
      now = now.add(const Duration(minutes: 1));
      await cubit.checkUpdates();
      expect(repo.notifications, hasLength(1));
      repo.detect = (_) async => const ComicFollowDetection(
        chapterCount: 13,
        latestChapterTitle: 'Another new chapter',
      );
      await cubit.checkUpdateForItem(cubit.state.items.first);
      expect(repo.notifications, hasLength(2));
      expect(repo.notifications.last, {'fixture:1': 13});
      await cubit.checkUpdateForItem(cubit.state.items.first);
      expect(repo.notifications, hasLength(2));
    },
  );

  test(
    'application foreground checks run on any page with delayed, rate-limited batches',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repo = _Repository([
        for (var i = 1; i <= 6; i++)
          _follow('$i', now.subtract(const Duration(hours: 1))),
      ]);
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      final timers = <_FollowTimer>[];
      final scheduler = ComicFollowForegroundScheduler(
        cubit: cubit,
        observeLifecycle: false,
        lifecycleState: () => AppLifecycleState.resumed,
        timerFactory: (delay, callback) {
          final timer = _FollowTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      try {
        scheduler.start();
        expect(
          repo.calls,
          isEmpty,
          reason: 'startup is not an immediate whole-library sweep',
        );
        expect(timers.single.delay, const Duration(minutes: 1));
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        expect(repo.calls.length, 4);
        expect(repo.notifications.single.length, 4);
        cubit.setAutomaticCheckingActive(false);
        final page = Object();
        cubit.setPageCheckingActive(page, true);
        cubit.setPageCheckingActive(page, false);
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        expect(
          repo.calls.length,
          6,
          reason: 'page departure cannot disable the application owner',
        );
        expect(repo.notifications.length, 2);
        expect(
          timers.last.delay,
          greaterThanOrEqualTo(const Duration(minutes: 1)),
        );
      } finally {
        scheduler.dispose();
        await cubit.close();
      }
    },
  );

  test(
    'foreground scheduler shares an existing page batch instead of duplicating source reads',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([
        _follow('1', now.subtract(const Duration(hours: 1))),
      ])..detect = (_) => pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      final timers = <_FollowTimer>[];
      final scheduler = ComicFollowForegroundScheduler(
        cubit: cubit,
        observeLifecycle: false,
        lifecycleState: () => AppLifecycleState.resumed,
        timerFactory: (delay, callback) {
          final timer = _FollowTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      try {
        scheduler.start();
        final page = Object();
        cubit.setPageCheckingActive(page, true);
        final pageBatch = cubit.checkDueUpdates();
        await _drainFollowWork();
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        cubit.setPageCheckingActive(page, false);
        expect(repo.calls.length, 1);
        pending.complete(
          const ComicFollowDetection(
            chapterCount: 12,
            latestChapterTitle: 'Shared result',
          ),
        );
        await pageBatch;
        await _drainFollowWork();
        expect(repo.writes, 1);
        expect(repo.notifications, hasLength(1));
      } finally {
        scheduler.dispose();
        await cubit.close();
      }
    },
  );

  test(
    'background invalidates a pending result and stops the next item; resume waits a minute',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([
        for (var i = 1; i <= 4; i++)
          _follow('$i', now.subtract(const Duration(hours: 1))),
      ])..detect = (_) => pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      final timers = <_FollowTimer>[];
      final scheduler = ComicFollowForegroundScheduler(
        cubit: cubit,
        observeLifecycle: false,
        lifecycleState: () => AppLifecycleState.resumed,
        timerFactory: (delay, callback) {
          final timer = _FollowTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      try {
        scheduler.start();
        cubit.setPageCheckingActive(Object(), true);
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        expect(repo.calls.length, 1);
        scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
        pending.complete(
          const ComicFollowDetection(
            chapterCount: 12,
            latestChapterTitle: 'Stale background result',
          ),
        );
        await _drainFollowWork();
        expect(repo.calls.length, 1);
        expect(repo.writes, 0);
        expect(repo.notifications, isEmpty);
        expect(scheduler.hasScheduledCheck, isFalse);
        scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _drainFollowWork();
        expect(repo.calls.length, 1);
        expect(timers.last.delay, const Duration(minutes: 1));
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        expect(repo.calls.length, 5);
        expect(repo.writes, 4);
      } finally {
        scheduler.dispose();
        await cubit.close();
      }
    },
  );

  test(
    'application scheduler disposal cannot be overridden by an old visible page',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final pending = Completer<ComicFollowDetection?>();
      final repo = _Repository([
        _follow('1', now.subtract(const Duration(hours: 1))),
      ])..detect = (_) => pending.future;
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      final timers = <_FollowTimer>[];
      final scheduler = ComicFollowForegroundScheduler(
        cubit: cubit,
        observeLifecycle: false,
        lifecycleState: () => AppLifecycleState.resumed,
        timerFactory: (delay, callback) {
          final timer = _FollowTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      try {
        scheduler.start();
        cubit.setPageCheckingActive(Object(), true);
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        scheduler.dispose();
        pending.complete(
          const ComicFollowDetection(
            chapterCount: 12,
            latestChapterTitle: 'Disposed result',
          ),
        );
        await _drainFollowWork();
        cubit.setAutomaticCheckingActive(true);
        expect(await cubit.checkDueUpdates(), 0);
        expect(repo.calls.length, 1);
        expect(repo.writes, 0);
        expect(scheduler.hasScheduledCheck, isFalse);
      } finally {
        scheduler.dispose();
        await cubit.close();
      }
    },
  );

  test(
    'an old main-navigation owner cannot stop a replacement scheduler',
    () async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repo = _Repository([
        _follow('1', now.subtract(const Duration(hours: 1))),
      ]);
      final cubit = ComicFollowCubit(repository: repo, now: () => now);
      final timers = <_FollowTimer>[];
      ComicFollowForegroundScheduler create() => ComicFollowForegroundScheduler(
        cubit: cubit,
        observeLifecycle: false,
        lifecycleState: () => AppLifecycleState.resumed,
        timerFactory: (delay, callback) {
          final timer = _FollowTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      final old = create(), current = create();
      try {
        old.start();
        current.start();
        old.dispose();
        now = now.add(const Duration(minutes: 1));
        timers.last.fire();
        await _drainFollowWork();
        expect(repo.calls.length, 1);
        expect(repo.writes, 1);
        expect(cubit.isApplicationCheckingOwner(current), isTrue);
      } finally {
        old.dispose();
        current.dispose();
        await cubit.close();
      }
    },
  );
}
