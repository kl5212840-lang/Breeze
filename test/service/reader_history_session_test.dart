import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';

import '../test_helper.dart';

const info = normal.ComicInfo(
  id: 'work',
  title: 'Work',
  titleMeta: [],
  description: '',
  cover: normal.ComicImage(id: '', url: '', name: ''),
  metadata: [],
);

UnifiedComicHistory history({
  String source = 'source',
  String comicId = 'work',
  String chapterId = 'logical-2',
  int pageIndex = 9,
  bool deleted = false,
}) => UnifiedComicHistory(
  uniqueKey: '$source:$comicId',
  source: source,
  comicId: comicId,
  title: 'Work',
  description: '',
  cover: '{}',
  creator: '{}',
  titleMeta: '[]',
  metadata: '[]',
  chapterId: chapterId,
  chapterTitle: 'Chapter',
  chapterOrder: 1,
  pageIndex: pageIndex,
  createdAt: DateTime.utc(2026),
  lastReadAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deleted: deleted,
  schemaVersion: 2,
);

void main() {
  test(
    'resume requires source, work and real chapter, never duplicate order',
    () {
      UnifiedComicHistory? stored = history();
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => stored,
        writePayload: (_) async => {},
      );
      int open() => service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      var owner = open();
      expect(service.historyPageIndex(owner, 'logical-2'), 9);
      for (final chapter in ['logical-1', 'request-2', 'shared-storage', '']) {
        expect(service.historyPageIndex(owner, chapter), 0);
      }
      for (final mismatch in [
        history(source: 'other'),
        history(comicId: 'other'),
        history(deleted: true),
      ]) {
        stored = mismatch;
        owner = open();
        expect(service.historyPageIndex(owner, 'logical-2'), 0);
      }
      unawaited(service.stop(owner));
    },
  );

  test(
    'pending reader progress cannot mask newer stored history or a deletion',
    () async {
      UnifiedComicHistory? stored;
      final gate = Completer<Map<String, dynamic>>();
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => stored,
        writePayload: (_) => gate.future,
      );
      int open() => service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      final first = open();
      service.markLoaded(first);
      service.startPeriodicSave(
        first,
        () => HistorySnapshot(
          pageIndex: 5,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-2'),
        ),
      );
      final saving = service.flush(first);
      final queued = open();
      expect(service.historyPageIndex(queued, 'logical-2'), 5);
      stored = history(pageIndex: 17)
        ..updatedAt = DateTime.now().toUtc().add(const Duration(minutes: 1));
      final latest = open();
      expect(service.historyPageIndex(latest, 'logical-2'), 17);
      stored!.deleted = true;
      final deleted = open();
      expect(service.historyPageIndex(deleted, 'logical-2'), 0);
      gate.complete({});
      await saving;
      await service.stop(deleted);
    },
  );

  test(
    'failed final reader write does not become a permanent resume override',
    () async {
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => history(),
        writePayload: (_) async => throw StateError('disk write failed'),
      );
      int open() => service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      final first = open();
      service.markLoaded(first);
      service.startPeriodicSave(
        first,
        () => HistorySnapshot(
          pageIndex: 20,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-2'),
        ),
      );
      await service.stop(first);
      final reopened = open();
      expect(service.historyPageIndex(reopened, 'logical-2'), 9);
      await service.stop(reopened);
    },
  );

  test(
    'delayed history writes preserve newer rows and explicit deletion in storage',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await TestObjectBoxHelper.setUpTestObjectBox();
      addTearDown(TestObjectBoxHelper.tearDownTestObjectBox);
      final record = history(pageIndex: 19);
      objectbox.unifiedHistoryBox.put(record);

      void write(int page, DateTime timestamp) {
        applyReaderHistorySnapshot(objectbox, {
          'source': 'source',
          'comicId': 'work',
          'normalInfo': info.toJson(),
          'chapterId': 'logical-2',
          'chapterTitle': 'Chapter',
          'chapterOrder': 1,
          'pageIndex': page,
          'timestamp': timestamp.toIso8601String(),
        });
      }

      write(5, record.updatedAt.subtract(const Duration(seconds: 1)));
      expect(objectbox.unifiedHistoryBox.getAll().single.pageIndex, 19);

      record.deleted = true;
      objectbox.unifiedHistoryBox.put(record);
      write(7, record.updatedAt);
      expect(objectbox.unifiedHistoryBox.getAll().single.deleted, isTrue);

      write(8, record.updatedAt.add(const Duration(seconds: 1)));
      final updated = objectbox.unifiedHistoryBox.getAll().single;
      expect(updated.deleted, isFalse);
      expect(updated.pageIndex, 8);
    },
  );

  testWidgets('stop saves a page turned within the 500ms interval', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    final service = ReaderHistoryService.forTesting(
      readHistory: (_, _) => null,
      writePayload: (payload) async {
        writes.add(payload);
        return {};
      },
    );
    final owner = service.loadHistory(
      source: 'source',
      comicId: 'work',
      comicInfo: info,
    );
    var page = 3;
    service.markLoaded(owner);
    service.startPeriodicSave(
      owner,
      () => HistorySnapshot(
        pageIndex: page,
        chapterOrder: 1,
        epInfo: NormalComicEpInfo(epId: 'logical-2', epName: 'Chapter'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(writes.single['pageIndex'], 3);
    page = 7;
    final stopped = service.stop(owner);
    await tester.pump();
    await stopped;
    expect(writes.map((row) => row['pageIndex']), [3, 7]);
    await tester.pump(const Duration(seconds: 1));
    expect(writes.length, 2);
  });

  test(
    'busy old write cannot discard final save or overwrite new session',
    () async {
      final blocker = Completer<void>();
      final writes = <Map<String, dynamic>>[];
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => history(),
        writePayload: (payload) async {
          writes.add(payload);
          if (writes.length == 1) await blocker.future;
          return history(
            source: payload['source'] as String,
            chapterId: payload['chapterId'] as String,
            pageIndex: payload['pageIndex'] as int,
          ).toJson();
        },
      );
      final first = service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      var page = 4;
      service.markLoaded(first);
      service.startPeriodicSave(
        first,
        () => HistorySnapshot(
          pageIndex: page,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-2'),
        ),
      );
      unawaited(service.flush(first));
      await Future<void>.delayed(Duration.zero);
      page = 8;
      // Opening its successor itself captures the old final page synchronously.
      final second = service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      expect(service.historyPageIndex(second, 'logical-2'), 8);
      var staleProviderCalled = false;
      service.markLoaded(first);
      service.startPeriodicSave(first, () {
        staleProviderCalled = true;
        return HistorySnapshot(
          pageIndex: 99,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'wrong'),
        );
      });
      await service.stop(first);
      service.markLoaded(second);
      service.startPeriodicSave(
        second,
        () => HistorySnapshot(
          pageIndex: 12,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-2'),
        ),
      );
      final saved = service.stop(second);
      blocker.complete();
      await saved;
      expect(staleProviderCalled, isFalse);
      expect(writes.map((row) => row['pageIndex']), [4, 8, 12]);
      expect(writes.every((row) => row['chapterId'] == 'logical-2'), isTrue);
      expect(service.owns(first), isFalse);
      expect(service.owns(second), isFalse);
    },
  );

  testWidgets(
    'background flush saves promptly and unchanged timers do no extra work',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => null,
        writePayload: (payload) async {
          writes.add(payload);
          return {};
        },
      );
      final owner = service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: info,
      );
      var page = 3;
      service.markLoaded(owner);
      service.startPeriodicSave(
        owner,
        () => HistorySnapshot(
          pageIndex: page,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-1'),
        ),
      );
      final flushed = service.flush(owner);
      await tester.pump();
      await flushed;
      await tester.pump(const Duration(seconds: 2));
      expect(writes.length, 1);
      page = 4;
      final stopped = service.stop(owner);
      await tester.pump();
      await stopped;
      expect(writes.map((row) => row['pageIndex']), [3, 4]);
    },
  );
}
