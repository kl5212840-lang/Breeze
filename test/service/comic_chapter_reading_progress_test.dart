import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';

import 'reader_history_session_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('archive preserves independent chapters and newer deletions', () async {
    final store = ComicChapterReadingProgress();
    Future<void> record(String chapter, int page) => store.record(
      source: 'source',
      comicId: 'work',
      chapterId: chapter,
      pageIndex: page,
      lastVisiblePage: page,
      pageCount: 10,
    );
    await record('first', 10);
    await record('second', 4);
    final firstArchive = ChapterProgressArchive.decode(
      (await store.capture()).encode(),
    );
    expect(firstArchive.rows.length, 2);
    await store.clearWork('source', 'work');
    await store.restore(firstArchive);
    expect(store.lookup('source', 'work', ['first', 'second']), isNull);
    await record('first', 3);
    expect(store.lookup('source', 'work', ['first'])?.pageIndex, 3);
    expect(store.lookup('source', 'work', ['second']), isNull);
  });

  test(
    'positions survive reopening with source and logical chapter isolation',
    () async {
      final store = ComicChapterReadingProgress();
      var changes = 0;
      store.changes.addListener(() => changes++);
      await store.ensureLoaded();
      final first = store.record(
        source: 'source',
        comicId: 'work',
        chapterId: 'logical-1',
        pageIndex: 9,
        lastVisiblePage: 10,
        pageCount: 10,
      );
      final second = store.record(
        source: 'source',
        comicId: 'work',
        chapterId: 'logical-2',
        pageIndex: 3,
        lastVisiblePage: 3,
        pageCount: 12,
      );
      final reread = store.record(
        source: 'source',
        comicId: 'work',
        chapterId: 'logical-1',
        pageIndex: 1,
        lastVisiblePage: 2,
        pageCount: 10,
      );
      expect(store.lookup('source', 'work', ['logical-1'])?.completed, isTrue);
      await Future.wait([first, second, reread]);
      expect(changes, 4);
      final reopened = ComicChapterReadingProgress();
      await reopened.ensureLoaded();
      expect(reopened.lookup('source', 'work', ['logical-1']), (
        pageIndex: 1,
        pageCount: 10,
        completed: true,
      ));
      expect(reopened.lookup('source', 'work', ['missing', 'logical-2']), (
        pageIndex: 3,
        pageCount: 12,
        completed: false,
      ));
      expect(reopened.lookup('other', 'work', ['logical-1']), isNull);
      expect(reopened.lookup('source', 'other', ['logical-1']), isNull);
      expect(reopened.lookup('source', 'work', ['shared-storage']), isNull);
    },
  );

  test(
    'observed chapters survive route handoff with exact legacy fallback',
    () async {
      final store = ComicChapterReadingProgress();
      await store.ensureLoaded();
      final workSaves = <String>[];
      final service = ReaderHistoryService.forTesting(
        chapterProgress: store,
        readHistory: (_, _) => fixture.history(),
        writePayload: (payload) async {
          workSaves.add(payload['chapterId'] as String);
          return {};
        },
      );
      int open() => service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: fixture.info,
      );
      final first = open();
      expect(service.downloadedHistoryPageIndex(first, 'logical-2', 20), 9);
      expect(service.downloadedHistoryPageIndex(first, 'logical-3', 20), 0);
      service.markLoaded(first);
      service.startPeriodicSave(
        first,
        () => HistorySnapshot(
          pageIndex: 4,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-3'),
          chapterPages: const [
            (
              chapterId: 'logical-3',
              pageIndex: 3,
              lastVisiblePage: 4,
              pageCount: 12,
            ),
          ],
        ),
      );
      service.observeChapterPage(first, (
        chapterId: 'logical-1',
        pageIndex: 9,
        lastVisiblePage: 10,
        pageCount: 10,
      ));
      service.observeChapterPage(first, (
        chapterId: 'logical-1',
        pageIndex: 7,
        lastVisiblePage: 8,
        pageCount: 10,
      ));
      final second = open();
      addTearDown(() => service.stop(second));
      await service.loadChapterProgress();
      expect(service.downloadedHistoryPageIndex(second, 'logical-1', 20), 8);
      expect(service.downloadedHistoryPageIndex(second, 'logical-1', 5), 6);
      expect(service.downloadedHistoryPageIndex(second, 'logical-3', 20), 4);
      expect(service.downloadedHistoryPageIndex(second, 'logical-2', 20), 9);
      expect(service.downloadedHistoryPageIndex(first, 'logical-1', 20), 0);
      await service.settlePendingWrites();
      expect(store.lookup('source', 'work', ['logical-1'])?.completed, isTrue);
      expect(store.lookup('source', 'work', ['logical-3'])?.completed, isFalse);
      expect(workSaves, ['logical-3']);
    },
  );

  test('offline work history resumes through an accepted legacy alias', () {
    final service = ReaderHistoryService.forTesting(
      readHistory: (_, _) => fixture.history()..chapterId = 'old-request-id',
      writePayload: (_) async => {},
    );
    final owner = service.loadHistory(
      source: 'source',
      comicId: 'work',
      comicInfo: fixture.info,
    );
    addTearDown(() => service.stop(owner));

    expect(service.historyPageIndex(owner, 'logical-2'), 0);
    expect(service.downloadedHistoryPageIndex(owner, 'logical-2', 20), 0);
    expect(
      service.downloadedHistoryPageIndex(
        owner,
        'logical-2',
        5,
        chapterKeys: ['logical-2', 'old-request-id'],
      ),
      6,
    );
  });

  test(
    'unchanged reader polling does not overwrite a restored chapter',
    () async {
      final store = ComicChapterReadingProgress();
      final service = ReaderHistoryService.forTesting(
        chapterProgress: store,
        readHistory: (_, _) => null,
        writePayload: (_) async => {},
      );
      final owner = service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: fixture.info,
      );
      addTearDown(() => service.stop(owner));
      service.markLoaded(owner);
      service.startPeriodicSave(
        owner,
        () => HistorySnapshot(
          pageIndex: 4,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'one'),
          chapterPages: const [
            (chapterId: 'one', pageIndex: 3, lastVisiblePage: 3, pageCount: 10),
          ],
        ),
      );
      await service.flush(owner);
      await service.settlePendingWrites();
      await store.restore(
        ChapterProgressArchive({
          ('source', 'work', 'one'): (
            at: DateTime.now().millisecondsSinceEpoch + 100,
            progress: (pageIndex: 7, pageCount: 10, completed: false),
          ),
        }),
      );
      await service.flush(owner);
      await service.settlePendingWrites();
      expect(store.lookup('source', 'work', ['one'])?.pageIndex, 7);
    },
  );
}
