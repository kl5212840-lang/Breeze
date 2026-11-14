import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_read/widgets/transition/chapter_transition_card.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/model/seamless_transition_state.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';
import '../test_helper.dart';

NormalComicEpInfo chapter(int order) => NormalComicEpInfo(
  epId: 'logical-$order',
  length: 1,
  docs: [
    Doc(originalName: 'page', path: '$order.jpg', fileServer: '', id: '$order'),
  ],
);

Map<String, Object> savedChapter(int order, {bool saved = true}) => {
  'id': 'logical-$order',
  'order': order,
  'name': 'Chapter $order',
  'images': [
    if (saved) {'path': '$order.jpg'},
  ],
};

void main() {
  testWidgets(
    'local transition displays two chapter names and a tappable arrow',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTransitionCard(
              previousChapterOrder: 15,
              previousChapterTitle: 'Chapter 15',
              nextChapterOrder: 16,
              nextChapterTitle: 'Chapter 16',
              transitionStatus: SeamlessTransitionStatus.local,
              onTap: () => taps++,
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );
      expect(find.text('Chapter 15'), findsOneWidget);
      expect(find.text('Chapter 16'), findsOneWidget);
      final arrow = find.byIcon(Icons.arrow_downward_rounded);
      expect(arrow, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(arrow);
      expect(taps, 1);
    },
  );

  test(
    'online prefetch warms the next chapter before crossing its card',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([
          savedChapter(11),
          savedChapter(12),
          savedChapter(13),
        ]);
      final first = chapter(11);
      first.docs = [first.docs.single, first.docs.single, first.docs.single];
      first.length = first.docs.length;
      final reads = <int>[];
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.normal,
        comicInfo: record,
        initialOrder: 11,
        readChapter: (order) async {
          reads.add(order);
          return chapter(order);
        },
      );
      addTearDown(cubit.close);
      const settings = ReadSettingState(preloadChapterCount: 1);
      cubit.bootstrap(first, 11, settings);
      await Future<void>.delayed(Duration.zero);
      expect(reads, [12]);
      expect(
        cubit
            .resolveImageEntriesForPrefetch(
              globalSlot: 2,
              readSetting: settings,
              count: 1,
            )
            .map((entry) => entry.chapterId),
        ['logical-12'],
      );
      expect(cubit.state.loadedChapters.map((chapter) => chapter.order), [11]);
      final boundary = await cubit.onGlobalSlotObserved(3, settings);
      expect(boundary.didLoad, isTrue);
      expect(reads.where((order) => order == 12), [12]);
      expect(
        cubit.resolveHistorySlotImages(4, settings)?.$1.chapterId,
        'logical-12',
      );
      expect(
        (await cubit.onTransitionAction(12, settings, 3)).targetGlobalSlot,
        4,
      );
      await cubit.onGlobalSlotObserved(4, settings);
      expect(cubit.currentChapterOrder, 12);
    },
  );

  for (final mode in [kReadModeColumn, kReadModeRowLtr, kReadModeRowRtl]) {
    for (final doublePage in [false, true]) {
      test(
        'local chapters keep a stable transition in layout $mode, double=$doublePage',
        () async {
          final record = createTestDownload('source:work')
            ..chapters = jsonEncode([
              savedChapter(11),
              savedChapter(12, saved: false),
              savedChapter(13),
            ]);
          final reads = <int>[];
          final cubit = ReaderSeamlessCubit(
            comicId: 'work',
            from: 'source',
            type: ComicEntryType.download,
            comicInfo: record,
            initialOrder: 11,
            readChapter: (order) async {
              reads.add(order);
              return chapter(order);
            },
          );
          addTearDown(cubit.close);
          final setting = ReadSettingState(
            readMode: mode,
            doublePageMode: doublePage,
            doublePageLeadingBlank: true,
          );
          cubit.bootstrap(chapter(11), 11, setting);
          expect(cubit.resolveTotalSlots(setting), 2);
          expect(cubit.transitionNextOrderByGlobalSlot(1, setting), 13);
          await cubit.onGlobalSlotObserved(0, setting);
          expect(cubit.catalogLength, 2);
          expect(reads, [13]);
          expect(cubit.resolveTotalSlots(setting), 3);
          expect(cubit.transitionNextOrderByGlobalSlot(1, setting), 13);
          expect(cubit.resolveHistorySlotImages(1, setting), isNull);
          await cubit.onGlobalSlotObserved(1, setting);
          expect(cubit.currentChapterOrder, 11);
          expect(
            (await cubit.onTransitionAction(13, setting, 1)).targetGlobalSlot,
            2,
          );
          await cubit.onGlobalSlotObserved(2, setting);
          expect(cubit.currentChapterOrder, 13);
          final next = cubit.resolveHistorySlotImages(2, setting);
          expect(next?.$1.chapterId, 'logical-13');
          expect(next?.$1.chapterPageIndex, 0);
          expect(next?.$2, isNull);
          final entries = cubit.buildRowEntries(setting);
          expect(entries.map((entry) => entry.chapterId), [
            'logical-11',
            null,
            'logical-13',
          ]);
          expect(entries[1].transitionStatus, SeamlessTransitionStatus.local);
          expect(entries[1].previousChapterTitle, 'Chapter 11');
          expect(entries[1].chapterTitle, 'Chapter 13');
          if (doublePage) {
            final spreads = buildReadModeDoublePageSlots(
              entries,
              insertLeadingBlank: true,
            );
            expect(spreads.map((slot) => slot.right?.entry.chapterId), [
              'logical-11',
              null,
              'logical-13',
            ]);
            expect(spreads[1].transition, isNotNull);
            expect(spreads.every((slot) => slot.left == null), isTrue);
          }
        },
      );
    }
  }

  test(
    'missing local metadata has one retry card and preserves history',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([savedChapter(11), savedChapter(12)]);
      var attempts = 0;
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 11,
        readChapter: (order) async {
          if (++attempts == 1) throw StateError('local index unavailable');
          return chapter(order);
        },
      );
      addTearDown(cubit.close);
      const setting = ReadSettingState();
      cubit.bootstrap(chapter(11), 11, setting);
      await Future<void>.delayed(Duration.zero);
      for (var repeat = 0; repeat < 3; repeat++) {
        await cubit.onGlobalSlotObserved(1, setting);
      }
      expect(attempts, 1);
      expect(
        cubit.buildColumnEntries(setting).last.transitionStatus,
        SeamlessTransitionStatus.error,
      );
      expect(cubit.currentChapterOrder, 11);
      expect(cubit.resolveHistorySlotImages(1, setting), isNull);
      final retry = await cubit.onTransitionAction(12, setting, 1);
      expect(retry.targetGlobalSlot, 2);
      expect(attempts, 2);
      expect(
        cubit.buildColumnEntries(setting)[1].transitionStatus,
        SeamlessTransitionStatus.local,
      );
    },
  );

  test(
    'double-page offset uses the tallest image and actual transition height',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([savedChapter(11), savedChapter(12)]);
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 11,
        readChapter: (order) async => chapter(order),
      );
      addTearDown(cubit.close);
      final initial = chapter(11);
      initial.docs = List.filled(2, initial.docs.single);
      initial.length = 2;
      const setting = ReadSettingState(
        readMode: kReadModeColumn,
        doublePageMode: true,
      );
      cubit.bootstrap(initial, 11, setting);
      await cubit.onGlobalSlotObserved(0, setting);
      final sizes = ImageSizeCubit.create(
        defaultWidth: 400,
        count: 2,
        sourceTag: 'source',
        pageKeys: const [],
        chapterOrder: 11,
        persistedCache: const {},
      );
      addTearDown(sizes.close);
      expect(
        cubit.estimateColumnHeightBeforeGlobalSlot(
          2,
          setting,
          sizes,
          400,
          viewportHeight: 300,
        ),
        240 + 300 + 36,
      );
    },
  );

  test('a late previous chapter follows the latest visible slot', () async {
    final record = createTestDownload('source:work')
      ..chapters = jsonEncode([savedChapter(1), savedChapter(2)]);
    final previous = Completer<NormalComicEpInfo>();
    final cubit = ReaderSeamlessCubit(
      comicId: 'work',
      from: 'source',
      type: ComicEntryType.download,
      comicInfo: record,
      initialOrder: 2,
      readChapter: (_) => previous.future,
    );
    addTearDown(cubit.close);
    const settings = ReadSettingState();
    final current = chapter(2);
    current.docs = [
      current.docs.single,
      current.docs.single,
      current.docs.single,
    ];
    current.length = current.docs.length;
    cubit.bootstrap(current, 2, settings);
    var visibleSlot = 1;
    final append = cubit.onTransitionAction(
      2,
      settings,
      visibleSlot,
      readAnchor: () => (slot: visibleSlot, setting: settings),
    );
    visibleSlot = 2;
    previous.complete(chapter(1));
    final shifted = await append;
    expect(shifted.prependedSlotCount, greaterThan(0));
    expect(shifted.targetGlobalSlot, visibleSlot + shifted.prependedSlotCount);
  });

  test(
    'duplicate chapter numbers retain exact route navigation without prefetching the wrong chapter',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([
          savedChapter(1),
          {...savedChapter(1), 'id': 'extra-1', 'name': 'Extra 1'},
          savedChapter(2),
        ]);
      final reads = <int>[];
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 1,
        readChapter: (order) async {
          reads.add(order);
          return chapter(order);
        },
      );
      addTearDown(cubit.close);
      const settings = ReadSettingState();
      cubit.bootstrap(chapter(1), 1, settings);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isSeamlessEnabled(), isFalse);
      expect(reads, isEmpty);
      expect(cubit.buildRowEntries(settings).single.chapterId, 'logical-1');
    },
  );

  test(
    'lowering chapter count and backgrounding stops the old three-chapter chain',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([for (var n = 1; n <= 5; n++) savedChapter(n)]);
      final started = <int>[];
      final gates = <int, Completer<NormalComicEpInfo>>{};
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 1,
        readChapter: (order) {
          started.add(order);
          return (gates[order] = Completer()).future;
        },
      );
      cubit.bootstrap(
        chapter(1),
        1,
        const ReadSettingState(preloadChapterCount: 3),
      );
      expect(started, [2]);
      cubit.configurePrefetch(count: 1, active: true);
      gates[2]!.complete(chapter(2));
      await Future<void>.delayed(Duration.zero);
      expect(started, [2]);
      expect(cubit.state.prefetchedChapterInfoByOrder[2]?.epId, 'logical-2');
      cubit.configurePrefetch(count: 3, active: true);
      await Future<void>.delayed(Duration.zero);
      // The completed old generation is re-read only when it was discarded;
      // there is never more than one in-flight request for the same chapter.
      final pendingOrder = started.last;
      cubit.configurePrefetch(count: 3, active: false);
      if (!gates[pendingOrder]!.isCompleted)
        gates[pendingOrder]!.complete(chapter(pendingOrder));
      await Future<void>.delayed(Duration.zero);
      expect(started.where((order) => order >= 4), isEmpty);
      expect(
        cubit.state.prefetchedChapterInfoByOrder.length,
        lessThanOrEqualTo(3),
      );
      await cubit.close();
    },
  );
  test(
    'a failed shared chapter during three-to-one reduction does not escape or continue stale chapter work',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([for (var n = 1; n <= 4; n++) savedChapter(n)]);
      final started = <int>[];
      final gate = Completer<NormalComicEpInfo>();
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 1,
        readChapter: (order) {
          started.add(order);
          return gate.future;
        },
      );
      const setting = ReadSettingState(preloadChapterCount: 3);
      cubit.bootstrap(chapter(1), 1, setting);
      cubit.configurePrefetch(count: 1, active: true);
      expect(started, [2]);
      gate.completeError(StateError('fixture chapter failed'));
      await Future<void>.delayed(Duration.zero);
      expect(started, [2]);
      expect(cubit.state.prefetchedChapterInfoByOrder, isEmpty);
      expect(cubit.state.prefetchingChapterOrders, isEmpty);
      // Stopping after this failure must not leave an unhandled stale chain.
      cubit.configurePrefetch(count: 1, active: false);
      await cubit.close();
    },
  );

  test(
    'a boundary finishing after a setting change uses the new prefetch count',
    () async {
      final record = createTestDownload('source:work')
        ..chapters = jsonEncode([for (var n = 1; n <= 6; n++) savedChapter(n)]);
      final chapterTwo = Completer<NormalComicEpInfo>();
      final started = <int>[];
      final cubit = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: record,
        initialOrder: 1,
        readChapter: (order) async {
          started.add(order);
          return order == 2 ? await chapterTwo.future : chapter(order);
        },
      );
      addTearDown(cubit.close);
      const olderSettings = ReadSettingState(preloadChapterCount: 3);
      cubit.bootstrap(chapter(1), 1, olderSettings);
      final boundary = cubit.onTransitionAction(2, olderSettings, 0);
      cubit.configurePrefetch(count: 1, active: true);
      chapterTwo.complete(chapter(2));
      expect((await boundary).didLoad, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(started, [2, 3]);
      expect(cubit.state.prefetchedChapterInfoByOrder.keys, [3]);
    },
  );
}
