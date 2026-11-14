import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart';
import 'package:zephyr/page/comic_follow/view/follow_display.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';
import 'package:zephyr/service/comic_follow/comic_follow_foreground_scheduler.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _FollowSearchTextApi extends RustLibApi {
  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => config == 'tw2sp.json' ? text.replaceAll('蹤', '踪') : text;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected test API ${invocation.memberName}');
}

class _FollowHostRepository implements ComicFollowRepository {
  _FollowHostRepository(DateTime now)
    : row = ComicFollow(
        id: 1,
        uniqueKey: 'fixture:1',
        source: 'fixture',
        comicId: '1',
        title: 'Fixture followed title',
        description: '',
        cover: '',
        creator: '',
        titleMeta: '',
        metadata: '',
        lastChapterCount: 10,
        detectedChapterCount: 10,
        detectedChapterTitle: 'Previously observed chapter',
        hasUpdate: false,
        updateTime: now.subtract(const Duration(hours: 1)),
        deleted: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        schemaVersion: 1,
      );
  ComicFollow row;
  int calls = 0;
  final additionalRows = <String, ComicFollow>{};
  final histories = <String, UnifiedComicHistory>{};
  final pending = Completer<ComicFollowDetection?>();
  ComicFollowDetection nextDetection = const ComicFollowDetection.failed(
    ComicFollowCheckFailure.sourceUnavailable,
  );
  @override
  List<ComicFollow> listActiveFollows() => [row, ...additionalRows.values];
  @override
  Map<String, UnifiedComicHistory> listActiveHistories() => {...histories};
  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String key) =>
      histories[key];
  @override
  ComicFollow? getFollowByUniqueKey(String key) =>
      (key == row.uniqueKey ? row : additionalRows[key])?.copyWith();
  @override
  void putFollow(ComicFollow value) {
    if (value.uniqueKey == row.uniqueKey) {
      row = value;
    } else {
      additionalRows[value.uniqueKey] = value;
    }
  }

  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow value, {
    bool Function()? canContinue,
  }) async {
    calls++;
    if (pending.isCompleted) return nextDetection;
    return pending.future;
  }

  @override
  Future<void> notifyUpdate(
    int count, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  }) async {}
}

class _FollowHostRegistry extends PluginRegistryCubit {
  void setSource({required bool? enabled}) {
    final now = DateTime.utc(2026, 11, 2, 12);
    emit({
      if (enabled != null)
        'fixture': PluginRuntimeState(
          uuid: 'fixture',
          version: '1.0.0',
          originScript: '',
          isEnabled: enabled,
          isDeleted: false,
          debug: false,
          debugUrl: null,
          lastLoadSuccess: true,
          lastLoadError: null,
          sortOrder: null,
          insertedAt: now,
          updatedAt: now,
          deletedAt: null,
        ),
    });
  }
}

// Stream closure in a widget test can require fake-zone continuations after
// native assets/subscriptions settle. Never await it without pumping, and never
// put widget expectations in an async callback running beside tester.pump.
Future<void> _followFixtureStage(
  WidgetTester tester,
  Future<void> Function() operation,
  String stage,
) async {
  debugPrint('follow fixture stage started: $stage');
  var completed = false;
  Object? failure;
  StackTrace? trace;
  unawaited(
    Future<void>.sync(operation).then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        completed = true;
      },
    ),
  );
  final elapsed = Stopwatch()..start();
  while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(completed, isTrue, reason: 'follow fixture stage completes: $stage');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  debugPrint('follow fixture stage completed: $stage');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RustLib.initMock(api: _FollowSearchTextApi()));
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityChanges = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityChanges, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityChanges, null);
  });

  testWidgets('main follow shows only comics and keeps the unread filter', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _FollowHostRepository(now);
    repository.row = repository.row.copyWith(updateTime: now);
    final cubit = ComicFollowCubit(repository: repository, now: () => now);
    final registry = PluginRegistryCubit();
    const source = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
    final detail = Uri.parse('https://www.ikunzy.com/voddetail/1.html');
    ApiVideoItem item(int count) => ApiVideoItem(
      id: '1',
      title: 'Tracked video',
      detailUrl: detail,
      plannedEpisodes: 12,
      lines: [
        ApiVideoLine(
          id: 'main',
          label: 'Main',
          episodes: [
            for (var number = 1; number <= count; number++)
              ApiVideoEpisode(
                id: '$number',
                title: '$number',
                url: Uri.parse('https://media.invalid/$number.m3u8'),
                watchUrl: detail.replace(
                  queryParameters: {'line': 'main', 'episode': '$number'},
                ),
              ),
          ],
        ),
      ],
    );
    final store = VideoLibraryStore(deviceId: 'follow-test');
    addTearDown(store.dispose);
    await _followFixtureStage(tester, () async {
      await store.setFollow(source, item(1), true);
      await store.observeItems(source, [item(2)]);
    }, 'save portable video follow');
    try {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: registry),
          ],
          child: const MaterialApp(home: ComicFollowPage()),
        ),
      );
      await tester.pumpAndSettle();
      final comic = find.text(repository.row.title),
          video = find.text('Tracked video');
      expect(comic, findsOneWidget);
      expect(video, findsNothing);
      expect(find.text(t.videoLibrary.newEpisodes(count: 1)), findsNothing);
      final filter = find.byKey(const ValueKey('follow-filter'));
      final control = tester.widget<NativeVideoSegmentedControl>(filter);
      expect(
        control.options.keys,
        orderedEquals([
          ComicFollowFilter.all.name,
          ComicFollowFilter.unread.name,
        ]),
      );
      Future<void> select(String label) async {
        await tester.tap(
          find.descendant(of: filter, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('video-host-menu')), findsNothing);
      }

      await select(t.comicFollow.unread);
      expect(comic, findsNothing);
      expect(cubit.state.filter, ComicFollowFilter.unread);
      await select(t.common.all);
      expect(video, findsNothing);
      expect(comic, findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _followFixtureStage(
        tester,
        cubit.close,
        'close comic follow cubit',
      );
      await _followFixtureStage(
        tester,
        registry.close,
        'close comic follow registry',
      );
    }
  });

  for (final style in ['system', 'breeze']) {
    testWidgets('follow sort shares the more-button trailing slot in $style', (
      tester,
    ) async {
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final channel = MethodChannel('${args['viewType']}.${args['id']}');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      repository.row = repository.row.copyWith(updateTime: now);
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final registry = PluginRegistryCubit();
      final preference = ValueNotifier(style);
      addTearDown(preference.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        final more = find.byKey(const ValueKey('follow-more'));
        final sort = find.byKey(const ValueKey('follow-sort'));
        final filter = find.byKey(const ValueKey('follow-filter'));
        final markAll = find.byWidgetPredicate(
          (widget) =>
              widget is SourceChromeIconButton &&
              widget.tooltip == t.comicFollow.markAllReadHint,
        );
        for (final direction in TextDirection.values) {
          for (final (width, scale) in [
            (430.0, 1.0),
            (320.0, 2.5),
            (1050.0, 1.0),
          ]) {
            tester.view.physicalSize = Size(width, 850);
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: cubit),
                  BlocProvider.value(value: registry),
                ],
                child: AppInterfaceStyleScope(
                  style: preference,
                  child: MaterialApp(
                    builder: (context, child) => Directionality(
                      textDirection: direction,
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!,
                      ),
                    ),
                    home: const ComicFollowPage(),
                  ),
                ),
              ),
            );
            for (final unread in [false, true]) {
              repository.row = repository.row.copyWith(
                hasUpdate: unread,
                detectedChapterCount: unread ? 11 : 10,
              );
              await cubit.loadFromDatabase();
              await tester.pumpAndSettle();
              final sortRect = tester.getRect(sort);
              final moreRect = tester.getRect(more);
              final filterRect = tester.getRect(filter);
              final rtl = direction == TextDirection.rtl;
              final trailing = rtl ? sortRect.left : width - sortRect.right;
              final expectedInset = 16 + ((width - 768) / 2).clamp(0, width);
              expect(
                sortRect.center.dx,
                closeTo(moreRect.center.dx, .01),
                reason: '$direction, width $width, unread $unread',
              );
              expect(trailing, closeTo(expectedInset, .01));
              expect(filterRect.height, greaterThanOrEqualTo(44));
              expect(sortRect.width, 44);
              expect(tester.getSize(sort).height, greaterThanOrEqualTo(44));
              if (sortRect.top >= filterRect.bottom) {
                expect(
                  scale,
                  greaterThan(2),
                  reason: 'only narrow accessibility layouts may wrap',
                );
                expect(
                  filterRect.width,
                  closeTo(width - expectedInset * 2, .01),
                );
              } else {
                expect(sortRect.center.dy, closeTo(filterRect.center.dy, .01));
                final gap = rtl
                    ? filterRect.left - sortRect.right
                    : sortRect.left - filterRect.right;
                expect(gap, greaterThanOrEqualTo(8));
              }
              expect(markAll, unread ? findsOneWidget : findsNothing);
              if (unread) {
                final markRect = tester.getRect(markAll);
                expect(markRect.center.dy, closeTo(sortRect.center.dy, .01));
                expect(
                  markRect.center.dx,
                  rtl
                      ? greaterThan(sortRect.center.dx)
                      : lessThan(sortRect.center.dx),
                );
              }
              expect(tester.takeException(), isNull);
            }
          }
        }
        expect(repository.calls, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _followFixtureStage(tester, cubit.close, 'close alignment cubit');
        await _followFixtureStage(
          tester,
          registry.close,
          'close alignment registry',
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets(
    'embedded follow reserves the island and checks only when active',
    (tester) async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final registry = PluginRegistryCubit();
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: MaterialApp(
              home: NativeNavigationInset(
                bottom: 61,
                child: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, value, _) =>
                      ComicFollowPage(embedded: true, active: value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.calls, 0);
        expect(find.byType(SourceBackButton), findsNothing);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.automaticallyImplyLeading, isFalse);
        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.padding!.resolve(TextDirection.ltr).bottom, 77);

        active.value = true;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 1);

        active.value = false;
        await tester.pump();
        repository.pending.complete(
          const ComicFollowDetection(chapterCount: 10, latestChapterTitle: ''),
        );
        await tester.pumpAndSettle();
        now = now.add(const Duration(hours: 1));
        await cubit.checkDueUpdates();
        expect(repository.calls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _followFixtureStage(tester, cubit.close, 'close embedded cubit');
        await _followFixtureStage(
          tester,
          registry.close,
          'close embedded registry',
        );
      }
    },
  );

  testWidgets('follow search is local and keeps the active sort and filter', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final repository = _FollowHostRepository(now);
    repository.row = repository.row.copyWith(
      title: '追蹤 Fixture followed title',
      metadata: '[{"type":"tags","value":["Mystery Genre"]}]',
      updateTime: now,
    );
    final cubit = ComicFollowCubit(repository: repository, now: () => now);
    final registry = PluginRegistryCubit();
    try {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: registry),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ComicFollowPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sort = find.byKey(const ValueKey('follow-sort'));
      expect(tester.widget<NativeVideoMenu>(sort).label, isEmpty);
      expect(tester.getSize(sort).width, 44);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicFollow.lastUpdate));
      await tester.pumpAndSettle();
      expect(cubit.state.sort, ComicFollowSort.update);

      final toggle = find.byKey(const ValueKey('follow-search-toggle'));
      final input = find.byType(TextField);
      final privacy = find.byKey(const ValueKey('follow-cover-privacy'));
      final more = find.byKey(const ValueKey('follow-more'));
      final privacyPosition = tester.getCenter(privacy);
      final morePosition = tester.getCenter(more);
      final toolsTop = tester.getTopLeft(sort).dy;
      expect(input, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(input, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: input),
        findsOneWidget,
      );
      expect(tester.getTopLeft(sort).dy, closeTo(toolsTop, .01));
      expect(tester.getCenter(privacy), privacyPosition);
      expect(tester.getCenter(more), morePosition);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(input, '追踪 fixture');
      await tester.pumpAndSettle();
      final title = find.text(repository.row.title);
      expect(title, findsOneWidget);
      final filter = find.byKey(const ValueKey('follow-filter'));
      await tester.tap(
        find.descendant(of: filter, matching: find.text(t.comicFollow.unread)),
      );
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      await tester.tap(
        find.descendant(of: filter, matching: find.text(t.common.all)),
      );
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      await tester.enterText(input, 'different work');
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
      await tester.enterText(input, 'mystery genre');
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      final keywordScope = find.byType(KeywordScopeMenu);
      await tester.tap(keywordScope);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('video-host-menu')),
          matching: find.text(t.sourceShell.searchScopeTitle),
        ),
      );
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      await tester.tap(keywordScope);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('video-host-menu')),
          matching: find.text(t.common.all),
        ),
      );
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      await tester.tap(find.byTooltip(t.common.clear));
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      expect(input, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(tester.getTopLeft(sort).dy, closeTo(toolsTop, .01));
      expect(title, findsOneWidget);
      expect(cubit.state.sort, ComicFollowSort.update);
      expect(repository.calls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _followFixtureStage(tester, cubit.close, 'close search cubit');
      await _followFixtureStage(
        tester,
        registry.close,
        'close search registry',
      );
    }
  });

  testWidgets(
    'pull on unread empty waits and distinguishes unchanged from failure',
    (tester) async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      repository.row = repository.row.copyWith(updateTime: now);
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final registry = PluginRegistryCubit();
      try {
        cubit.setFilter(ComicFollowFilter.unread);
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: const MaterialApp(home: ComicFollowPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.calls, 0);
        expect(find.text(t.comicFollow.noUnread), findsOneWidget);
        expect(find.byTooltip(t.common.refresh), findsNothing);
        expect(find.byKey(const ValueKey('follow-more')), findsOneWidget);

        Future<void> pull() async {
          final previousCalls = repository.calls;
          await tester.drag(find.byType(Scrollable), const Offset(0, 350));
          for (var i = 0; i < 30 && repository.calls == previousCalls; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(repository.calls, previousCalls + 1);
        }

        await pull();
        expect(repository.calls, 1);
        expect(find.text(t.common.refreshUnchanged), findsNothing);
        expect(cubit.state.isCheckingUpdates, isTrue);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        repository.pending.complete(
          const ComicFollowDetection(
            chapterCount: 10,
            latestChapterTitle: 'Previously observed chapter',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.common.refreshUnchanged), findsOneWidget);
        expect(find.text(t.comicFollow.noUnread), findsOneWidget);

        await pull();
        await tester.pumpAndSettle();
        expect(repository.calls, 2);
        expect(find.text(t.common.refreshUnchanged), findsNothing);
        expect(find.text(t.common.refreshRetained), findsOneWidget);
        expect(
          find.text(t.comicFollow.checkIncomplete(count: 1)),
          findsOneWidget,
        );
        expect(
          repository.row.detectedChapterTitle,
          'Previously observed chapter',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _followFixtureStage(tester, cubit.close, 'close pull cubit');
        await _followFixtureStage(
          tester,
          registry.close,
          'close pull registry',
        );
      }
    },
  );

  for (final initialFailure in [
    ComicFollowCheckFailure.pluginMissing,
    ComicFollowCheckFailure.pluginDisabled,
  ]) {
    testWidgets(
      'follow retry becomes available after ${initialFailure.name} is resolved',
      (tester) async {
        final now = DateTime.utc(2026, 11, 2, 12);
        final repository = _FollowHostRepository(now);
        final cubit = ComicFollowCubit(repository: repository, now: () => now);
        final registry = _FollowHostRegistry()
          ..setSource(
            enabled: initialFailure == ComicFollowCheckFailure.pluginMissing
                ? null
                : false,
          );
        try {
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider<PluginRegistryCubit>.value(value: registry),
              ],
              child: const MaterialApp(home: ComicFollowPage()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(repository.calls, 1);
          repository.pending.complete(
            ComicFollowDetection.failed(initialFailure),
          );
          await tester.pumpAndSettle();

          final retry = find.byKey(const ValueKey('follow-retry-fixture:1'));
          final missing = find.text(t.comicFollow.checkPluginMissing);
          final disabled = find.text(t.comicFollow.checkPluginDisabled);
          expect(
            initialFailure == ComicFollowCheckFailure.pluginMissing
                ? missing
                : disabled,
            findsOneWidget,
          );
          expect(retry, findsNothing);

          registry.setSource(enabled: false);
          await tester.pumpAndSettle();
          expect(missing, findsNothing);
          expect(disabled, findsOneWidget);
          expect(retry, findsNothing);

          registry.setSource(enabled: true);
          await tester.pumpAndSettle();
          expect(disabled, findsNothing);
          expect(retry, findsOneWidget);
          expect(repository.calls, 1);
          expect(
            find.textContaining('Previously observed chapter'),
            findsOneWidget,
          );

          repository.nextDetection = const ComicFollowDetection(
            chapterCount: 10,
            latestChapterTitle: 'Confirmed chapter',
          );
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(repository.calls, 2);
          expect(retry, findsNothing);
          expect(find.textContaining('Confirmed chapter'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await _followFixtureStage(tester, cubit.close, 'close retry cubit');
          await _followFixtureStage(
            tester,
            registry.close,
            'close retry registry',
          );
        }
      },
    );
  }

  testWidgets('unread empty counts rows deferred by a source outage', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final repository = _FollowHostRepository(now);
    repository.row = repository.row.copyWith(updateTime: now);
    for (var i = 2; i <= 3; i++) {
      repository.additionalRows['fixture:$i'] = repository.row.copyWith(
        id: i,
        uniqueKey: 'fixture:$i',
        comicId: '$i',
        updateTime: now.add(Duration(seconds: i)),
      );
    }
    repository.pending.complete(repository.nextDetection);
    final cubit = ComicFollowCubit(repository: repository, now: () => now);
    final registry = PluginRegistryCubit();
    try {
      cubit.setFilter(ComicFollowFilter.unread);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: registry),
          ],
          child: const MaterialApp(home: ComicFollowPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.comicFollow.noUnread), findsOneWidget);

      await tester.drag(find.byType(Scrollable), const Offset(0, 350));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(cubit.state.lastAttempts['fixture:3'], isNull);
      expect(
        find.text(t.comicFollow.checkIncomplete(count: 3)),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _followFixtureStage(tester, cubit.close, 'close outage cubit');
      await _followFixtureStage(
        tester,
        registry.close,
        'close outage registry',
      );
    }
  });

  testWidgets(
    'reading progress uses confirmed chapter position and survives a failed check',
    (tester) async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      repository.row = repository.row.copyWith(
        lastChapterCount: 3,
        detectedChapterCount: 3,
        updateTime: now,
      );
      final row = repository.row;
      repository.histories[row.uniqueKey] = UnifiedComicHistory(
        uniqueKey: row.uniqueKey,
        source: row.source,
        comicId: row.comicId,
        title: row.title,
        description: '',
        cover: '',
        creator: '',
        titleMeta: '',
        metadata: '',
        chapterId: 'logical-start',
        chapterTitle: 'Starting chapter',
        chapterOrder: 2,
        pageIndex: 0,
        createdAt: now,
        lastReadAt: now,
        updatedAt: now,
        deleted: false,
        schemaVersion: 2,
      );
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, comicId, _) async => {
          'data': {
            'normal': {
              'comicInfo': {'id': comicId},
              'eps': [
                {'id': 'last', 'name': 'Last', 'order': 30},
                {
                  'id': 'start',
                  'logicalKey': 'logical-start',
                  'name': 'Start',
                  'order': 2,
                },
                {'id': 'mid', 'name': 'Middle', 'order': 20},
              ],
            },
          },
        },
      );
      repository.pending.complete(await reader.detect(row));
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final registry = PluginRegistryCubit();
      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: const MaterialApp(home: ComicFollowPage()),
          ),
        );
        await tester.pumpAndSettle();
        final track = find.byType(LinearProgressIndicator);
        expect(find.textContaining('Starting chapter'), findsOneWidget);
        expect(track, findsNothing);

        repository.nextDetection = (await reader.detect(row))!;
        await cubit.checkUpdateForItem(row);
        await tester.pumpAndSettle();
        expect(
          tester.widget<LinearProgressIndicator>(track).value,
          closeTo(1 / 3, 0.001),
        );

        repository.nextDetection = const ComicFollowDetection.failed(
          ComicFollowCheckFailure.network,
        );
        await cubit.checkUpdateForItem(row);
        await tester.pumpAndSettle();
        expect(
          tester.widget<LinearProgressIndicator>(track).value,
          closeTo(1 / 3, 0.001),
        );
        expect(find.textContaining('Starting chapter'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _followFixtureStage(tester, cubit.close, 'close progress cubit');
        await _followFixtureStage(
          tester,
          registry.close,
          'close progress registry',
        );
      }
    },
  );

  testWidgets(
    'real page retains old chapters and hides diagnostics; app checks pause in background and continue on another page',
    (tester) async {
      var now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final scheduler = ComicFollowForegroundScheduler(cubit: cubit)..start();
      // Source names can be rendered without accessing a real plugin or account.
      final registry = PluginRegistryCubit();
      try {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        debugPrint('follow fixture checkpoint: mount real page');
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const ComicFollowPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 1);
        expect(
          find.textContaining('Previously observed chapter'),
          findsOneWidget,
        );
        expect(find.text(t.comicFollow.noUnread), findsNothing);
        expect(find.text(t.comicFollow.checkingUpdates), findsWidgets);
        repository.pending.completeError(
          const FormatException("unexpected token: 'error'"),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining("unexpected token: 'error'"), findsNothing);
        expect(find.text(t.comicFollow.checkInvalidResponse), findsOneWidget);
        expect(find.text(t.common.retry), findsOneWidget);
        expect(find.byTooltip(t.common.refresh), findsNothing);
        expect(
          find.text(
            t.comicFollow.knownChapter(
              count: 10,
              chapter: 'Previously observed chapter',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            t.comicFollow.lastCheckAttempt(time: formatFollowCheckTime(now)),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            t.comicFollow.lastSuccessfulCheck(
              time: formatFollowCheckTime(repository.row.updateTime),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        debugPrint('follow fixture checkpoint: background then resume');
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        expect(repository.calls, 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 1);
        now = now.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 2);
        debugPrint(
          'follow fixture checkpoint: check on another foreground page',
        );
        final navigator = Navigator.of(
          tester.element(find.byType(ComicFollowPage)),
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covered route')),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        now = now.add(const Duration(minutes: 4));
        await tester.pump(const Duration(minutes: 4));
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 3);
        debugPrint('follow fixture checkpoint: return to follow page');
        navigator.pop();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.calls, 3);

        repository.nextDetection = const ComicFollowDetection(
          chapterCount: 10,
          latestChapterTitle: 'Confirmed chapter',
        );
        final retry = find.byKey(const ValueKey('follow-retry-fixture:1'));
        expect(tester.getSize(retry).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(repository.calls, 4);
        expect(find.textContaining('Confirmed chapter'), findsOneWidget);
        expect(find.text(t.comicFollow.checkSourceUnavailable), findsNothing);
        expect(retry, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        scheduler.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        try {
          debugPrint(
            'follow fixture checkpoint: unmount before stream cleanup',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          try {
            await _followFixtureStage(
              tester,
              cubit.close,
              'close follow cubit',
            );
          } finally {
            await _followFixtureStage(
              tester,
              registry.close,
              'close registry subscription',
            );
          }
        } finally {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    },
  );
}
