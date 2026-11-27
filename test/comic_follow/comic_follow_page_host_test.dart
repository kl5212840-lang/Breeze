import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDialogRoute;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
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
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/tab_reselect_scope.dart';
import 'package:zephyr/widgets/toast.dart';

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
  bool failWrites = false;
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
    if (failWrites) throw StateError('Fixture write failure');
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

  test(
    'follow sort keeps the last rapid selection across a cold read',
    () async {
      const key = 'breeze.local.comic-follow.sort.v1';
      SharedPreferences.setMockInitialValues({key: 99});
      final preferences = await SharedPreferences.getInstance();
      final repository = _FollowHostRepository(DateTime.utc(2026));
      final cubit = ComicFollowCubit(
        repository: repository,
        sortPreferences: preferences,
      );
      expect(cubit.state.sort, ComicFollowSort.lastRead);
      cubit.setSort(ComicFollowSort.recentUpdate);
      cubit.setSort(ComicFollowSort.update);
      cubit.setSort(ComicFollowSort.recentUpdate);
      expect(cubit.state.sort, ComicFollowSort.recentUpdate);
      await cubit.close();
      await preferences.reload();
      expect(preferences.get(key), ComicFollowSort.recentUpdate.name);

      final reopened = ComicFollowCubit(
        repository: repository,
        sortPreferences: preferences,
      );
      addTearDown(reopened.close);
      expect(reopened.state.sort, ComicFollowSort.recentUpdate);
    },
  );

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

  testWidgets('follow swipe is bounded and opens actions without confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 11, 23, 12);
    final repository = _FollowHostRepository(now);
    repository.row = repository.row.copyWith(
      detectedChapterCount: 12,
      hasUpdate: true,
    );
    final cubit = ComicFollowCubit(repository: repository, now: () => now);
    final registry = PluginRegistryCubit();
    final notices = <ToastEvent>[];
    final subscription = eventBus.on<ToastEvent>().listen(notices.add);
    addTearDown(subscription.cancel);
    final router = RootStackRouter.build(
      routes: [
        NamedRouteDef(
          name: 'FollowFixture',
          path: '/',
          builder: (_, _) => const ComicFollowPage(active: false),
        ),
        NamedRouteDef(
          name: ComicInfoRoute.name,
          path: '/comic-detail',
          builder: (_, data) => Scaffold(
            body: Text(
              'Detail opened for ${data.argsAs<ComicInfoRouteArgs>().comicId}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    try {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: registry),
          ],
          child: MaterialApp.router(routerConfig: router.config()),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey(repository.row.uniqueKey));
      final title = find.text(repository.row.title);
      final read = find.text(t.sourceNotices.read);
      final unfollow = find.text(t.comicFollow.unfollow);
      final dialog = find.byType(AlertDialog);
      final badge = find.byKey(
        ValueKey('follow-update-${repository.row.uniqueKey}'),
      );
      final dot = find.byKey(
        ValueKey('follow-update-dot-${repository.row.uniqueKey}'),
      );
      final closedLeft = tester.getTopLeft(title).dx;
      final point = tester.getCenter(row);

      Future<void> reveal() async {
        await tester.flingFrom(point, const Offset(-145, 0), 1800);
        await tester.pumpAndSettle();
        expect(unfollow.hitTestable(), findsOneWidget);
        expect(dialog, findsNothing);
      }

      expect(badge, findsOneWidget);
      expect(dot, findsOneWidget);
      await tester.dragFrom(Offset(20, point.dy), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(unfollow, findsNothing);

      final touch = await tester.startGesture(tester.getCenter(row));
      await touch.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 70));
      await touch.moveBy(const Offset(-24, 0));
      await tester.pump(const Duration(milliseconds: 70));
      await touch.moveBy(const Offset(-220, 0));
      await tester.pump();
      final displacement = closedLeft - tester.getTopLeft(title).dx;
      await touch.moveBy(const Offset(40, 0));
      await tester.pump();
      final reversed = closedLeft - tester.getTopLeft(title).dx;
      await touch.moveBy(const Offset(-50, 0));
      await touch.up();
      await tester.pumpAndSettle();

      expect(
        (displacement <= 152, find.byType(AlertDialog).evaluate().isEmpty),
        (true, true),
        reason:
            'A swipe moved the row by $displacement and must only reveal actions.',
      );
      expect(displacement, greaterThanOrEqualTo(88));
      expect(reversed, closeTo(displacement - 40, 1));
      expect(read.hitTestable(), findsOneWidget);
      expect(unfollow.hitTestable(), findsOneWidget);
      expect(repository.row.deleted, isFalse);

      final cancelled = await tester.startGesture(tester.getCenter(unfollow));
      await cancelled.moveBy(const Offset(110, 0));
      await tester.pump();
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(unfollow.hitTestable(), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(unfollow, findsNothing);

      await reveal();
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.text('Detail opened for 1'), findsNothing);
      expect(unfollow, findsNothing);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text('Detail opened for 1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(unfollow, findsNothing);

      await reveal();
      await tester.tap(unfollow);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(repository.row.deleted, isFalse);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      repository.failWrites = true;
      await reveal();
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(notices.last.type, ToastType.error);
      expect(badge, findsOneWidget);
      expect(dot, findsOneWidget);
      expect(repository.row.hasUpdate, isTrue);

      repository.failWrites = false;
      final filter = find.byKey(const ValueKey('follow-filter'));
      await tester.tap(
        find.descendant(of: filter, matching: find.text(t.comicFollow.unread)),
      );
      await tester.pumpAndSettle();
      await reveal();
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(notices.last.type, ToastType.success);
      expect(row, findsNothing);
      expect(repository.row.lastChapterCount, 12);
      expect(repository.row.deleted, isFalse);

      await tester.tap(find.text(t.comicFollow.showAll));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(badge, findsNothing);
      expect(dot, findsNothing);
      await reveal();
      expect(read, findsNothing);
      await tester.tap(unfollow);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: dialog, matching: find.text(t.comicInfo.unfollow)),
      );
      await tester.pumpAndSettle();
      expect(repository.row.deleted, isTrue);
      expect(row, findsNothing);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await _followFixtureStage(tester, cubit.close, 'close swipe cubit');
      await _followFixtureStage(tester, registry.close, 'close swipe registry');
    }
  });

  for (final (style, platform, brightness, size) in [
    ('system', TargetPlatform.iOS, Brightness.light, const Size(320, 568)),
    ('breeze', TargetPlatform.iOS, Brightness.dark, const Size(844, 390)),
    ('system', TargetPlatform.android, Brightness.light, const Size(320, 568)),
  ]) {
    testWidgets('follow confirmation stays modal in $style on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preference = ValueNotifier(style);
      addTearDown(preference.dispose);
      final now = DateTime.utc(2026, 11, 23, 12);
      final repository = _FollowHostRepository(now);
      repository.row = repository.row.copyWith(
        title: List.filled(24, '很长的漫画标题').join(' · '),
      );
      repository.additionalRows['fixture:2'] = repository.row.copyWith(
        id: 2,
        uniqueKey: 'fixture:2',
        comicId: '2',
        title: 'Other followed work',
      );
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final registry = PluginRegistryCubit();
      final systemIos = style == 'system' && platform == TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(platform: platform, brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2.2)),
                  child: child!,
                ),
                home: const ComicFollowPage(active: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(ValueKey(repository.row.uniqueKey));
        final alert = find.byType(AlertDialog);
        final cancel = find.descendant(
          of: alert,
          matching: find.widgetWithText(TextButton, t.common.cancel),
        );
        final confirm = find.descendant(
          of: alert,
          matching: find.widgetWithText(TextButton, t.comicInfo.unfollow),
        );
        Future<void> open() async {
          await tester.longPress(row);
          await tester.pumpAndSettle();
          await tester.tap(find.text(t.comicFollow.unfollow));
          await tester.pumpAndSettle();
          expect(alert, findsOneWidget);
        }

        await open();
        final body = find.descendant(
          of: alert,
          matching: find.text(
            t.comicFollow.unfollowConfirm(title: repository.row.title),
          ),
        );
        final alertTitle = find.descendant(
          of: alert,
          matching: find.text(t.comicFollow.unfollow),
        );
        for (final text in [alertTitle, body]) {
          expect(
            tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
          );
        }
        final scrollable = find
            .ancestor(of: body, matching: find.byType(Scrollable))
            .first;
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
        for (final button in [cancel, confirm]) {
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));
        }
        expect(
          ModalRoute.of(tester.element(alert)) is CupertinoDialogRoute<bool>,
          systemIos,
        );
        final dialog = tester.widget<AlertDialog>(alert);
        final destructive = tester.widget<TextButton>(confirm);
        final ink = destructive.style!.foregroundColor!.resolve({})!;
        expect(dialog.backgroundColor!.a, 1);
        expect(
          BreezeThemeColors.contrast(ink, dialog.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        final surface = find.descendant(
          of: alert,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material && widget.color == dialog.backgroundColor,
          ),
        );
        expect(
          tester.getSize(surface).width,
          lessThanOrEqualTo(systemIos ? 360 : 400),
        );
        final rowRect = tester.getRect(row);
        await tester.tapAt(Offset(rowRect.left + 3, rowRect.center.dy));
        await tester.pumpAndSettle();
        expect(alert, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(repository.row.deleted, isFalse);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(alert, findsNothing);
        expect(repository.row.deleted, isFalse);

        await open();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(alert, findsNothing);
        expect(repository.row.deleted, isFalse);

        await open();
        final replacementTime = now.add(const Duration(seconds: 1));
        repository.row = repository.row.copyWith(
          title: 'Replacement subscription for the same work',
          createdAt: replacementTime,
          updatedAt: replacementTime,
        );
        await cubit.loadFromDatabase();
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(alert, findsNothing);
        expect(repository.row.deleted, isFalse);
        expect(repository.row.createdAt, replacementTime);

        await open();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(alert, findsNothing);
        expect(repository.row.deleted, isTrue);
        expect(repository.additionalRows['fixture:2']!.deleted, isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _followFixtureStage(
          tester,
          cubit.close,
          'close confirmation cubit',
        );
        await _followFixtureStage(
          tester,
          registry.close,
          'close confirmation registry',
        );
      }
    });
  }

  for (final style in ['system', 'breeze']) {
    testWidgets('follow toolbar stays aligned across unread states in $style', (
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
      final mode = ComicFollowReminderController.instance.mode;
      final previousMode = mode.value;
      mode.value = ComicFollowReminderMode.badge;
      addTearDown(() => mode.value = previousMode);
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
          for (final (width, scale, brightness) in [
            (430.0, 1.0, Brightness.dark),
            (320.0, 2.5, Brightness.light),
            (1050.0, 1.0, Brightness.light),
          ]) {
            tester.view.physicalSize = Size(width, 850);
            final scheme = BreezeThemeColors.fromSeed(
              brightness == Brightness.dark
                  ? const Color(0xFFE05272)
                  : const Color(0xFF007B84),
              brightness,
            );
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: cubit),
                  BlocProvider.value(value: registry),
                ],
                child: AppInterfaceStyleScope(
                  style: preference,
                  child: MaterialApp(
                    theme: ThemeData(colorScheme: scheme),
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
            (Rect, Rect)? initialLayout;
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
                rtl ? sortRect.left : sortRect.right,
                closeTo(rtl ? moreRect.left : moreRect.right, .01),
                reason: '$direction, width $width, unread $unread',
              );
              expect(trailing, closeTo(expectedInset, .01));
              expect(filterRect.height, greaterThanOrEqualTo(44));
              expect(sortRect.width, greaterThanOrEqualTo(44));
              expect(tester.getSize(sort).height, greaterThanOrEqualTo(44));
              final sortMenu = tester.widget<NativeVideoMenu>(sort);
              expect(sortMenu.bare, isTrue);
              if (width >= 430 && scale == 1) {
                expect(sortMenu.label, t.comicFollow.lastRead);
              }
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
              expect(markAll, findsNothing);
              final latest = find.byKey(
                const ValueKey('follow-latest-fixture:1'),
              );
              final cover = find.byKey(
                const ValueKey('follow-cover-fixture:1'),
              );
              final badge = find.byKey(
                const ValueKey('follow-update-fixture:1'),
              );
              final dot = find.byKey(
                const ValueKey('follow-update-dot-fixture:1'),
              );
              expect(badge, unread ? findsOneWidget : findsNothing);
              expect(dot, unread ? findsOneWidget : findsNothing);
              if (unread) {
                final bounds = tester.getRect(cover);
                final badgeBounds = tester.getRect(badge);
                final dotBounds = tester.getRect(dot);
                expect(dotBounds.top, closeTo(bounds.top - 4, .01));
                expect(
                  rtl
                      ? dotBounds.right - bounds.right
                      : bounds.left - dotBounds.left,
                  closeTo(4, .01),
                );
                expect(dotBounds.overlaps(bounds), isTrue);
                expect(badgeBounds.overlaps(bounds), isFalse);
                final latestBounds = tester.getRect(latest);
                expect(latestBounds.overlaps(badgeBounds), isFalse);
                if (badgeBounds.top < latestBounds.bottom) {
                  expect(
                    badgeBounds.center.dy,
                    closeTo(latestBounds.center.dy, .01),
                  );
                  expect(
                    rtl
                        ? latestBounds.left - badgeBounds.right
                        : badgeBounds.left - latestBounds.right,
                    closeTo(8, .01),
                  );
                } else {
                  expect(
                    rtl ? badgeBounds.right : badgeBounds.left,
                    closeTo(rtl ? latestBounds.right : latestBounds.left, .01),
                  );
                }
                final label = t.comicFollow.newChaptersShort(diff: 1);
                expect(find.text(label), findsOneWidget);
                if (scale == 1) {
                  expect(find.text(label), findsOneWidget);
                  final ink = tester
                      .widget<Text>(find.text(label))
                      .style!
                      .color!;
                  final badgeBox = tester.widget<DecoratedBox>(
                    find.descendant(
                      of: badge,
                      matching: find.byType(DecoratedBox),
                    ),
                  );
                  final fill = (badgeBox.decoration as BoxDecoration).color!;
                  expect(fill, scheme.primary);
                  expect(
                    BreezeThemeColors.contrast(ink, fill),
                    greaterThanOrEqualTo(4.5),
                  );
                }
              }
              expect(
                tester
                    .widget<NativeVideoMenu>(more)
                    .options
                    .containsValue(t.comicFollow.markAllReadHint),
                unread,
              );
              initialLayout ??= (filterRect, sortRect);
              expect((filterRect, sortRect), initialLayout);
              expect(tester.takeException(), isNull);
            }
          }
        }
        if (style == 'breeze') {
          await tester.tap(more);
          await tester.pumpAndSettle();
          await tester.tap(find.text(t.comicFollow.markAllReadHint));
          await tester.pumpAndSettle();
          expect(cubit.state.updateCount, 0);
          expect(repository.row.lastChapterCount, 11);
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
    final preferences = await SharedPreferences.getInstance();
    final cubit = ComicFollowCubit(
      repository: repository,
      now: () => now,
      sortPreferences: preferences,
    );
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
      final sortMenu = tester.widget<NativeVideoMenu>(sort);
      expect(sortMenu.tooltip, contains(t.comicFollow.lastRead));
      expect(tester.getSize(sort).width, greaterThanOrEqualTo(44));
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicFollow.lastUpdate));
      await tester.pumpAndSettle();
      expect(cubit.state.sort, ComicFollowSort.update);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comicFollow.recentUpdate));
      await tester.pumpAndSettle();
      expect(cubit.state.sort, ComicFollowSort.recentUpdate);
      expect(
        preferences.getString('breeze.local.comic-follow.sort.v1'),
        ComicFollowSort.recentUpdate.name,
      );

      final toggle = find.byKey(const ValueKey('follow-search-toggle'));
      final input = find.byType(TextField);
      final privacy = find.byKey(const ValueKey('follow-cover-privacy'));
      final more = find.byKey(const ValueKey('follow-more'));
      final appBar = find.byType(AppBar);
      final bounds = tester.getRect(appBar);
      final sortCenter = tester.getCenter(sort);
      expect(tester.getRect(more).right, tester.getRect(sort).right);
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
      expect(privacy, findsNothing);
      expect(more, findsNothing);
      expect(tester.getRect(input).left, bounds.left + 16);
      expect(tester.getRect(input).right, bounds.right - 16);
      expect(tester.getCenter(sort), sortCenter);
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
      await tester.enterText(input, 'different work');
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(tester.getTopLeft(sort).dy, closeTo(toolsTop, .01));
      expect(title, findsOneWidget);
      expect(cubit.state.sort, ComicFollowSort.recentUpdate);
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
    'follow reselect preserves the open search, filter, and sort after editing',
    (tester) async {
      final now = DateTime.utc(2026, 11, 2, 12);
      final repository = _FollowHostRepository(now);
      repository.row = repository.row.copyWith(
        title: 'Match entry 0',
        hasUpdate: true,
        detectedChapterCount: 11,
        updateTime: now,
      );
      for (var i = 1; i <= 12; i++) {
        repository.additionalRows['fixture:extra-$i'] = repository.row.copyWith(
          id: i + 1,
          uniqueKey: 'fixture:extra-$i',
          comicId: 'extra-$i',
          title: 'Match entry $i',
          updateTime: now.subtract(Duration(minutes: i)),
        );
      }
      final cubit = ComicFollowCubit(repository: repository, now: () => now);
      final tabs = TabReselectController();
      final registry = PluginRegistryCubit();
      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: registry),
            ],
            child: MaterialApp(
              home: TabReselectScope(
                controller: tabs,
                child: const ComicFollowPage(embedded: true, active: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        cubit.setFilter(ComicFollowFilter.unread);
        cubit.setSort(ComicFollowSort.update);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('follow-search-toggle')));
        await tester.pumpAndSettle();
        final search = find.byType(TextField);
        await tester.enterText(search, 'match');
        await tester.pumpAndSettle();
        final controller = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        controller.jumpTo(400);
        await tester.pump();
        tabs.request();
        await tester.pumpAndSettle();
        expect(controller.offset, 400);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        tabs.request();
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.minScrollExtent);
        expect(tester.widget<TextField>(search).controller!.text, 'match');
        expect(find.text('Match entry 0'), findsOneWidget);
        expect(cubit.state.filter, ComicFollowFilter.unread);
        expect(cubit.state.sort, ComicFollowSort.update);
        expect(repository.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tabs.dispose();
        await _followFixtureStage(tester, cubit.close, 'close reselect cubit');
        await _followFixtureStage(
          tester,
          registry.close,
          'close reselect registry',
        );
      }
    },
  );

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
    'reading and chapter text survive a failed check without a progress bar',
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
        final reading = find.text(
          t.comicFollow.lastReadChapter(chapter: 'Starting chapter'),
        );
        expect(reading, findsOneWidget);
        expect(track, findsNothing);

        repository.nextDetection = (await reader.detect(row))!;
        await cubit.checkUpdateForItem(row);
        await tester.pumpAndSettle();
        final latest = find.text(
          t.comicFollow.chapterSummary(count: 3, chapter: 'Last'),
        );
        expect(latest, findsOneWidget);
        expect(reading, findsOneWidget);
        expect(track, findsNothing);

        repository.nextDetection = const ComicFollowDetection.failed(
          ComicFollowCheckFailure.network,
        );
        await cubit.checkUpdateForItem(row);
        await tester.pumpAndSettle();
        expect(latest, findsOneWidget);
        expect(reading, findsOneWidget);
        expect(track, findsNothing);
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
        final card = find.byKey(const ValueKey('fixture:1'));
        final checkingHeight = tester.getSize(card).height;
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
            t.comicFollow.chapterSummary(
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
          findsNothing,
        );
        expect(
          find.text(
            t.comicFollow.lastSuccessfulCheck(
              time: formatFollowCheckTime(repository.row.updateTime),
            ),
          ),
          findsNothing,
        );
        expect(tester.getSize(card).height, checkingHeight);
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
