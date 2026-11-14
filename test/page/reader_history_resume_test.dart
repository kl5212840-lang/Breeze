import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_read/controller/reader_history_controller.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/view/comic_read.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/type/enum.dart';

import '../service/reader_history_session_test.dart' as fixture;
import '../test_helper.dart';

class _Settings extends GlobalSettingCubit {
  _Settings({required bool doublePage, required bool leadingBlank}) {
    emit(
      state.copyWith(
        readSetting: state.readSetting.copyWith(
          doublePageMode: doublePage,
          doublePageLeadingBlank: leadingBlank,
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('leaving an offline reader releases its reading preferences', (
    tester,
  ) async {
    final global = _Settings(doublePage: false, leadingBlank: false);
    final preference = ComicReadPreferenceCubit();
    final stringSelect = StringSelectCubit();
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(global.close);
    addTearDown(preference.close);
    addTearDown(stringSelect.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GlobalSettingCubit>.value(value: global),
          BlocProvider.value(value: preference),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Download list')),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ComicReadPage(
            comicId: 'reader-exit-fixture',
            order: 1,
            epsNumber: 1,
            from: 'reader-exit-source',
            stringSelectCubit: stringSelect,
            type: ComicEntryType.download,
            comicInfo: {'comicInfo': fixture.info.toJson()},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(preference.state.comicId, 'reader-exit-fixture');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(preference.state.uniqueKey, isEmpty);
    expect(find.text('Download list'), findsOneWidget);
  });

  for (final mode in [
    (doublePage: false, leadingBlank: false, chapterId: 'logical-2', target: 7),
    (doublePage: true, leadingBlank: false, chapterId: 'logical-2', target: 3),
    (doublePage: true, leadingBlank: true, chapterId: 'logical-2', target: 4),
    (
      doublePage: false,
      leadingBlank: false,
      chapterId: 'logical-1',
      target: -1,
    ),
  ]) {
    testWidgets('download resume preserves page conversion $mode', (
      tester,
    ) async {
      final jumps = <int>[];
      final saves = <int>[];
      final layoutReady = Completer<void>();
      var currentPage = 2;
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => fixture.history(),
        writePayload: (payload) async {
          saves.add(payload['pageIndex'] as int);
          return {};
        },
      );
      final status = StringSelectCubit();
      final controller = ReaderHistoryController(
        comicId: 'work',
        order: 1,
        from: 'source',
        comicInfo: fixture.info,
        stringSelectCubit: status,
        getSnapshot: () => HistorySnapshot(
          pageIndex: currentPage,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: mode.chapterId),
        ),
        getEntryChapterId: () => mode.chapterId,
        isHistoryEntry: () => false,
        isDownloadEntry: () => true,
        jumpToGlobalSlot: (target) async {
          jumps.add(target);
          await layoutReady.future;
          currentPage = 9;
        },
        historyService: service,
      );
      await controller.init();
      addTearDown(controller.stop);
      addTearDown(status.close);
      final global = _Settings(
        doublePage: mode.doublePage,
        leadingBlank: mode.leadingBlank,
      );
      final preference = ComicReadPreferenceCubit();
      final reader = ReaderCubit()..updateTotalSlots(20);
      final seamless = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: const {'eps': <dynamic>[]},
        initialOrder: 1,
      );
      addTearDown(global.close);
      addTearDown(preference.close);
      addTearDown(reader.close);
      addTearDown(seamless.close);
      late BuildContext readerContext;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GlobalSettingCubit>.value(value: global),
            BlocProvider.value(value: preference),
            BlocProvider.value(value: reader),
            BlocProvider.value(value: seamless),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                readerContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      controller.handleHistoryScroll(readerContext);
      if (mode.target >= 0) {
        // A system background event may occur before the resume frame.
        controller.flush();
        await tester.idle();
        expect(saves, isEmpty);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(jumps, mode.target < 0 ? isEmpty : [mode.target]);
      if (mode.target >= 0) {
        controller.flush();
        await tester.idle();
        expect(saves, isEmpty, reason: 'The jump has not settled yet');
        layoutReady.complete();
        await tester.idle();
        controller.flush();
        await tester.idle();
        expect(saves, [9]);
      }
      controller.stop();
      controller.handleHistoryScroll(readerContext);
      await tester.pump();
      expect(jumps, mode.target < 0 ? isEmpty : [mode.target]);
      expect(global.state.readSetting.doublePageMode, mode.doublePage);
      expect(
        global.state.readSetting.doublePageLeadingBlank,
        mode.leadingBlank,
      );
    });
  }

  testWidgets(
    'queued restore belongs to its owner and cannot jump a successor',
    (tester) async {
      final service = ReaderHistoryService.forTesting(
        readHistory: (_, _) => fixture.history(),
        writePayload: (_) async => {},
      );
      final status = StringSelectCubit();
      addTearDown(status.close);
      final jumps = <int>[];
      final controller = ReaderHistoryController(
        comicId: 'work',
        order: 1,
        from: 'source',
        comicInfo: fixture.info,
        stringSelectCubit: status,
        getSnapshot: () => HistorySnapshot(
          pageIndex: 2,
          chapterOrder: 1,
          epInfo: NormalComicEpInfo(epId: 'logical-2'),
        ),
        getEntryChapterId: () => 'logical-2',
        isHistoryEntry: () => false,
        isDownloadEntry: () => true,
        jumpToGlobalSlot: (target) async {
          jumps.add(target);
        },
        historyService: service,
      );
      await controller.init();
      final global = _Settings(doublePage: false, leadingBlank: false);
      final preference = ComicReadPreferenceCubit();
      final reader = ReaderCubit()..updateTotalSlots(20);
      final seamless = ReaderSeamlessCubit(
        comicId: 'work',
        from: 'source',
        type: ComicEntryType.download,
        comicInfo: const {'eps': <dynamic>[]},
        initialOrder: 1,
      );
      addTearDown(global.close);
      addTearDown(preference.close);
      addTearDown(reader.close);
      addTearDown(seamless.close);
      late BuildContext readerContext;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GlobalSettingCubit>.value(value: global),
            BlocProvider.value(value: preference),
            BlocProvider.value(value: reader),
            BlocProvider.value(value: seamless),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                readerContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // Replace the owner while its restore is waiting for the next frame.
      controller.handleHistoryScroll(readerContext);
      final successor = service.loadHistory(
        source: 'source',
        comicId: 'work',
        comicInfo: fixture.info,
      );
      controller.stop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(jumps, isEmpty);
      expect(service.owns(successor), isTrue);
      await service.stop(successor);
    },
  );
}
