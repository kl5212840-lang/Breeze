import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_info/bloc/get_comic_info_bloc.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_info/models/comic_detail_presentation.dart';
import 'package:zephyr/page/comic_info/view/comic_info.dart';
import 'package:zephyr/page/comic_info/widgets/comic_detail_partial_notice.dart';
import 'package:zephyr/page/comic_info/widgets/particulars.dart';
import 'package:zephyr/page/comic_info/widgets/eps.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

PluginComicDetail detail({bool partial = true}) {
  final normal = NormalComicAllInfo.fromJson({
    'comicInfo': {
      'id': '51',
      'title': 'usable title',
      'titleMeta': [],
      'description': '',
      'cover': {'id': '51', 'url': '', 'name': ''},
      'metadata': [],
    },
    'eps': [],
    'recommend': [],
    'extern': {
      'fieldsMissing': partial ? ['description', 'tags'] : [],
    },
  });
  return PluginComicDetail(
    normalInfo: normal,
    source: PluginComicDetailSource(
      from: 'fixture',
      normalInfo: normal,
      raw: const {},
    ),
  );
}

Future<void> mountChapterDetail(
  WidgetTester tester, {
  required int count,
  double width = 430,
  TextDirection direction = TextDirection.ltr,
  bool grouped = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = Size(width, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  const source = 'fixture', comicId = '51', key = '$source:$comicId';
  objectbox.unifiedDownloadBox.put(
    createTestDownload(key)
      ..source = source
      ..comicId = comicId
      ..detailJson = jsonEncode(
        detail(partial: false).normalInfo
            .copyWith(
              eps: [
                for (var i = 1; i <= count; i++)
                  Ep(
                    id: 'ep-$i',
                    name: 'Chapter $i',
                    order: i,
                    groupTitle: grouped ? (i < 30 ? 'Group A' : 'Group B') : '',
                  ),
              ],
            )
            .toJson(),
      ),
  );
  addTearDown(TestObjectBoxHelper.cleanComicFolderBoxes);
  final style = ValueNotifier('breeze');
  addTearDown(style.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GlobalSettingCubit()),
        BlocProvider(create: (_) => ComicFollowCubit()),
      ],
      child: AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (_, child) =>
              Directionality(textDirection: direction, child: child!),
          home: const ComicInfoPage(
            comicId: comicId,
            from: source,
            type: ComicEntryType.download,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition chapterScrollPosition(WidgetTester tester, Finder scrollView) =>
    tester
        .state<ScrollableState>(
          find
              .descendant(of: scrollView, matching: find.byType(Scrollable))
              .first,
        )
        .position;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(() async {
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
  });
  for (final hasHistory in [false, true]) {
    testWidgets(
      'first comic detail frame includes the read action ($hasHistory)',
      (tester) async {
        const source = 'fixture', comicId = '51', key = '$source:$comicId';
        final download = createTestDownload(key)
          ..source = source
          ..comicId = comicId
          ..detailJson = jsonEncode(detail(partial: false).normalInfo.toJson());
        objectbox.unifiedDownloadBox.put(download);
        if (hasHistory) {
          objectbox.unifiedHistoryBox.put(
            createTestHistory(key)
              ..source = source
              ..comicId = comicId,
          );
        }
        addTearDown(TestObjectBoxHelper.cleanComicFolderBoxes);
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => GlobalSettingCubit()),
              BlocProvider(create: (_) => ComicFollowCubit()),
            ],
            child: AppInterfaceStyleScope(
              style: style,
              child: const MaterialApp(
                home: ComicInfoPage(
                  comicId: comicId,
                  from: source,
                  type: ComicEntryType.download,
                ),
              ),
            ),
          ),
        );
        final details = find.byType(ComicParticularsWidget);
        Finder readAction(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        );
        final start = readAction(t.comicInfo.startRead);
        final resume = readAction(t.comicInfo.continueRead);
        for (var frame = 0; frame < 10 && details.evaluate().isEmpty; frame++) {
          expect(start, findsNothing);
          expect(resume, findsNothing);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(details, findsOneWidget);
        expect(hasHistory ? resume : start, findsOneWidget);
        expect(hasHistory ? start : resume, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('six-chapter detail swipes from a chapter row toward the top', (
    tester,
  ) async {
    await mountChapterDetail(tester, count: 6);
    final chapter = find.widgetWithText(EpButtonWidget, 'Chapter 4');
    final returnToTop = find.byKey(
      const ValueKey('comic-detail.return-to-top'),
    );
    expect(returnToTop, findsNothing);
    final outerScroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final position = tester.state<ScrollableState>(outerScroll).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.text(t.comicInfo.episodeCount(count: 6)), findsOneWidget);
    expect(chapter.hitTestable(), findsOneWidget);
    expect(returnToTop.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: returnToTop),
      findsNothing,
    );
    expect(
      tester.getCenter(returnToTop).dx,
      greaterThan(tester.getCenter(chapter).dx),
    );
    expect(
      tester.getRect(returnToTop).bottom,
      lessThan(tester.getTopLeft(find.text(t.comicInfo.startRead)).dy),
    );
    final before = position.pixels;
    final gesture = await tester.startGesture(tester.getCenter(chapter));
    await gesture.moveBy(const Offset(0, 32));
    await gesture.moveBy(const Offset(0, 88));
    expect(position.pixels, lessThan(before));
    await gesture.up();
    await tester.pumpAndSettle();

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(returnToTop);
    await tester.pumpAndSettle();
    expect(position.pixels, position.minScrollExtent);
    expect(returnToTop, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (width, direction, grouped) in [
    (430.0, TextDirection.ltr, false),
    (320.0, TextDirection.rtl, true),
  ]) {
    testWidgets(
      'long chapter gutters drag the outer page while preserving chapter offset ($direction)',
      (tester) async {
        await mountChapterDetail(
          tester,
          count: 60,
          width: width,
          direction: direction,
          grouped: grouped,
          platform: TargetPlatform.iOS,
        );
        final inner = find.byKey(const PageStorageKey('chapters:fixture:51'));
        final outer = find.ancestor(
          of: inner,
          matching: find.byType(CustomScrollView),
        );
        final innerPosition = chapterScrollPosition(tester, inner);
        final outerPosition = chapterScrollPosition(tester, outer);
        final initialOuter = outerPosition.maxScrollExtent * .8;
        const initialInner = 200.0;
        for (final (x, outerOnly) in [
          (10.0, true),
          (width / 2, false),
          (width - 10, true),
        ]) {
          outerPosition.jumpTo(initialOuter);
          innerPosition.jumpTo(initialInner);
          await tester.pumpAndSettle();
          final viewport = tester.getRect(inner);
          final row = tester.getRect(
            find.byType(EpButtonWidget).hitTestable().first,
          );
          final gesture = await tester.startGesture(
            Offset(x, viewport.center.dy),
          );
          await gesture.moveBy(const Offset(0, 32));
          await gesture.moveBy(const Offset(0, 72));
          if (outerOnly) {
            expect(outerPosition.pixels, lessThan(initialOuter));
            expect(innerPosition.pixels, initialInner);
          } else {
            expect(outerPosition.pixels, initialOuter);
            expect(innerPosition.pixels, lessThan(initialInner));
          }
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(row.left, 20);
          expect(row.right, width - 20);
          expect(viewport.left, row.left);
          expect(viewport.right, row.right);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'grouped chapters open one volume, recover adjacent headers and follow sort',
    (tester) async {
      await mountChapterDetail(tester, count: 60, grouped: true);
      final inner = find.byKey(const PageStorageKey('chapters:fixture:51'));
      final outer = find.ancestor(
        of: inner,
        matching: find.byType(CustomScrollView),
      );
      final innerPosition = chapterScrollPosition(tester, inner);
      final outerPosition = chapterScrollPosition(tester, outer);
      outerPosition.jumpTo(outerPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      final originalOuterOffset = outerPosition.pixels;
      final groupA = find.text('Group A');
      final groupB = find.text('Group B');
      final total = find.text(t.comicInfo.episodeCount(count: 60));
      final groups = find.byType(SliverStickyHeader, skipOffstage: false);

      List<bool> openGroups() => tester
          .widgetList<SliverStickyHeader>(groups)
          .map((group) => group.sliver != null)
          .toList();
      expect(openGroups(), [true, false]);
      expect(groupA.hitTestable(), findsOneWidget);
      expect(groupB.hitTestable(), findsNothing);
      expect(total, findsOneWidget);
      expect(
        find.descendant(
          of: groups,
          matching: find.textContaining(' · ', findRichText: true),
        ),
        findsNothing,
      );
      expect(
        find.byTooltip(t.comicInfo.downloadGroup, skipOffstage: false),
        findsNWidgets(2),
      );

      innerPosition.jumpTo(800);
      await tester.pumpAndSettle();
      expect(groupA.hitTestable(), findsOneWidget);
      await tester.tap(groupA);
      await tester.pumpAndSettle();
      expect(openGroups(), [false, false]);
      expect(groupB.hitTestable(), findsOneWidget);
      expect(outerPosition.pixels, originalOuterOffset);

      await tester.tap(groupB);
      await tester.pumpAndSettle();
      expect(openGroups(), [false, true]);
      expect(find.text('Chapter 30').hitTestable(), findsOneWidget);
      expect(groupA.hitTestable(), findsOneWidget);
      await tester.tap(groupA);
      await tester.pumpAndSettle();
      expect(openGroups(), [true, false]);
      expect(outerPosition.pixels, originalOuterOffset);

      innerPosition.jumpTo(innerPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(groupB.hitTestable(), findsOneWidget);
      await tester.tap(groupB);
      await tester.pumpAndSettle();
      expect(openGroups(), [false, true]);
      expect(find.text('Chapter 30').hitTestable(), findsOneWidget);
      expect(outerPosition.pixels, originalOuterOffset);
      innerPosition.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(groupA);
      await tester.pumpAndSettle();
      expect(openGroups(), [true, false]);

      await tester.ensureVisible(total);
      await tester.pumpAndSettle();
      await tester.tap(total);
      await tester.pumpAndSettle();
      expect(openGroups(), [true, false]);
      expect(groupB.hitTestable(), findsOneWidget);
      expect(find.text('Chapter 60').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'partial detail retries await the actual load and retain usable content: $style $brightness',
        (tester) async {
          final gates = <Completer<PluginComicDetail>>[];
          late GetComicInfoBloc bloc;
          // Own the async* event transformer and its cancellation futures in
          // the real zone, independently of the widget host's fake frame clock.
          await tester.runAsync(() async {
            bloc = GetComicInfoBloc(
              readDetail: (_) {
                final gate = Completer<PluginComicDetail>();
                gates.add(gate);
                return gate.future;
              },
            );
          });
          final event = GetComicInfoEvent(
            comicId: '51',
            from: 'fixture',
            type: ComicEntryType.normal,
          );
          await tester.runAsync(() async {
            final first = bloc.refresh(event);
            await Future<void>.delayed(Duration.zero);
            gates.single.complete(detail());
            expect(await first, isTrue);
          });
          final notifier = ValueNotifier(style);
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          try {
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: notifier,
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.7)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: BlocBuilder<GetComicInfoBloc, GetComicInfoState>(
                      bloc: bloc,
                      builder: (context, state) => Column(
                        children: [
                          Text(state.allInfo!.comicInfo.title),
                          if (comicDetailHasMissingFields(state.allInfo!))
                            ComicDetailPartialNotice(
                              onRetry: () async {
                                await bloc.refresh(
                                  GetComicInfoEvent(
                                    comicId: '51',
                                    from: 'fixture',
                                    type: ComicEntryType.normal,
                                  ),
                                );
                              },
                            ),
                          if (bloc.refreshError != null)
                            Text(bloc.refreshError!),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(t.comicInfo.partialDetails), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey('comic-detail-partial-retry')),
            );
            await tester.pump();
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            expect(gates, hasLength(2));
            expect(
              tester
                  .widget<TextButton>(
                    find.byKey(const ValueKey('comic-detail-partial-retry')),
                  )
                  .onPressed,
              isNull,
            );
            expect(find.text('usable title'), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            await tester.runAsync(() async {
              gates[1].completeError(StateError('fixture read failed'));
              await Future<void>.delayed(Duration.zero);
            });
            await tester.pumpAndSettle();
            expect(find.text('usable title'), findsOneWidget);
            expect(bloc.refreshError, isNotEmpty);
            expect(
              tester
                  .widget<TextButton>(
                    find.byKey(const ValueKey('comic-detail-partial-retry')),
                  )
                  .onPressed,
              isNotNull,
            );
            await tester.tap(
              find.byKey(const ValueKey('comic-detail-partial-retry')),
            );
            await tester.pump();
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            expect(gates, hasLength(3));
            await tester.runAsync(() async {
              gates[2].complete(detail(partial: false));
              await Future<void>.delayed(Duration.zero);
            });
            await tester.pumpAndSettle();
            expect(find.byType(ComicDetailPartialNotice), findsNothing);
            expect(find.text('usable title'), findsOneWidget);
            expect(bloc.refreshError, isNull);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            // Release fixture-owned reads even when an earlier expectation
            // failed. Closing an async* transformer with an unresolved read
            // otherwise masks that failure by waiting forever for cancellation.
            await tester.runAsync(() async {
              for (final gate in gates) {
                if (!gate.isCompleted) gate.complete(detail(partial: false));
              }
              await Future<void>.delayed(Duration.zero);
              await bloc.close().timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  throw TestFailure(
                    'Partial detail fixture bloc.close did not drain',
                  );
                },
              );
            });
            notifier.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  }
}
