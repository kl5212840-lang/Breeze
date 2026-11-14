import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus, objectbox;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_info/bloc/get_comic_info_bloc.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_info/view/comic_info.dart';
import 'package:zephyr/page/comic_info/widgets/eps.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/event/event.dart';

import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';
const _comic = 'detail-session-fixture';

class _DetailApi extends RustLibApi {
  late Completer<String> entered;
  late Completer<Map<String, dynamic>> response;
  final cancelledGroups = <String>[];

  void prepare() {
    entered = Completer<String>();
    response = Completer<Map<String, dynamic>>();
  }

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('detail-session-fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    if (fnPath == 'init') {
      return Uint8List.fromList(utf8.encode('{"data":{"ok":true}}'));
    }
    expect(fnPath, 'getComicDetail');
    entered.complete(taskGroupKey);
    return Uint8List.fromList(utf8.encode(jsonEncode(await response.future)));
  }

  @override
  Future<QjsCancelTasksByGroupResult> crateApiQjsQjsCancelTasksByGroup({
    required String runtimeName,
    required String taskGroupKey,
  }) async {
    cancelledGroups.add(taskGroupKey);
    return const QjsCancelTasksByGroupResult(
      cancelled: 1,
      notFound: 0,
      failedRuntimeGroups: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture API ${invocation.memberName}');
}

Map<String, dynamic> _detail(String tag) => {
  'normal': {
    'comicInfo': {
      'id': _comic,
      'title': 'Fixture detail',
      'titleMeta': [],
      'description': '',
      'cover': {'id': '', 'url': '', 'name': ''},
      'metadata': [
        {
          'type': 'tags',
          'name': 'Tags',
          'value': [
            {'name': tag},
          ],
        },
      ],
    },
    'eps': [],
    'recommend': [],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _DetailApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('detail keeps one catalog and opens this comic’s download page', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const channels = [
      MethodChannel('dev.fluttercommunity.plus/connectivity'),
      MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    ];
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (_) async => ['wifi']);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const source = 'detail-fixture';
    const key = '$source:$_comic';
    final savedId = objectbox.unifiedDownloadBox.put(
      createTestDownload(key)
        ..source = source
        ..comicId = _comic
        ..chapters = jsonEncode([
          {
            'id': 'episode-1',
            'order': 1,
            'name': 'Saved episode',
            'images': [
              {'path': '1.jpg'},
              {'path': '2.jpg'},
              {'path': '3.jpg'},
            ],
          },
          {
            'id': 'episode-2',
            'order': 2,
            'name': 'Unread saved episode',
            'images': [
              {'path': 'unread.jpg'},
            ],
          },
        ]),
    );
    final historyId = objectbox.unifiedHistoryBox.put(
      createTestHistory(key)
        ..source = source
        ..comicId = _comic
        ..chapterId = 'episode-1'
        ..pageIndex = 3,
    );
    addTearDown(() {
      objectbox.unifiedDownloadBox.remove(savedId);
      objectbox.unifiedHistoryBox.remove(historyId);
    });
    final launches = <ComicReadRouteArgs>[];
    final router = RootStackRouter.build(
      routes: [
        NamedRouteDef(
          name: 'ChapterDetails',
          path: '/',
          builder: (_, _) => const ComicInfoPage(
            comicId: _comic,
            from: source,
            type: ComicEntryType.normal,
          ),
        ),
        NamedRouteDef(
          name: ComicReadRoute.name,
          path: '/read',
          builder: (_, data) {
            launches.add(data.argsAs<ComicReadRouteArgs>());
            return const Scaffold(body: Text('Reader route'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    api.prepare();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => GlobalSettingCubit()),
          BlocProvider(create: (_) => ComicFollowCubit()),
        ],
        child: MaterialApp.router(routerConfig: router.config()),
      ),
    );
    for (var i = 0; i < 60 && !api.entered.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(api.entered.isCompleted, isTrue);
    final detail = _detail('Fixture tag');
    (detail['normal'] as Map)['eps'] = [
      {'id': 'episode-1', 'name': 'Online episode', 'order': 1},
      {'id': 'episode-2', 'name': 'Unread online episode', 'order': 2},
    ];
    api.response.complete(detail);
    await tester.pumpAndSettle();
    expect(find.text(t.comicInfo.chapterList), findsOneWidget);
    final online = find.text('Online episode');
    final shortcut = find.text(t.comicInfo.openDownloads);
    expect(shortcut, findsOneWidget);
    expect(find.text('Saved episode'), findsNothing);
    await tester.ensureVisible(online);
    final detailRow = find.widgetWithText(EpButtonWidget, 'Online episode');
    final rowStatus = find.descendant(
      of: detailRow,
      matching: find.text(t.comicInfo.readProgressPage(page: 2)),
    );
    final download = find.byKey(
      const ValueKey('chapter-download-action:episode-1'),
    );
    expect(rowStatus, findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(EpButtonWidget, 'Unread online episode'),
        matching: find.text(t.comicInfo.readProgressPage(page: 2)),
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(rowStatus).dx,
      greaterThan(tester.getTopRight(online).dx),
    );
    expect(
      tester.getTopLeft(download).dx - tester.getTopRight(rowStatus).dx,
      greaterThanOrEqualTo(12),
    );
    Rect actionWithinChapter() =>
        tester.getRect(download).shift(-tester.getTopLeft(detailRow));
    final actionRect = actionWithinChapter();
    final chapterHeight = tester.getSize(detailRow).height;
    await tester.runAsync(
      () => ComicChapterReadingProgress.instance.record(
        source: source,
        comicId: _comic,
        chapterId: 'episode-1',
        pageIndex: 2,
        lastVisiblePage: 3,
        pageCount: 3,
      ),
    );
    await tester.pump();
    expect(find.text(t.comicInfo.chapterReadComplete), findsOneWidget);
    expect(actionWithinChapter(), actionRect);
    expect(tester.getSize(detailRow).height, chapterHeight);
    await tester.tap(online);
    await tester.pumpAndSettle();
    expect(launches.last.type, ComicEntryType.normal);
    expect(launches.last.chapterId, 'episode-1');
    await router.maybePop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    final resume = find.byKey(const ValueKey('download-resume-entry'));
    expect(resume, findsOneWidget);
    final existingChapter = find.byKey(
      const ValueKey('download-chapter-open.episode-1'),
    );
    final offlineStatus = find.descendant(
      of: existingChapter,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data == 'Read' || widget.data == '已读完'),
      ),
    );
    expect(offlineStatus, findsOneWidget);
    final unreadChapter = find.byKey(
      const ValueKey('download-chapter-open.episode-2'),
    );
    expect(
      find.descendant(
        of: unreadChapter,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == '1 pages' || widget.data == '1 页'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(offlineStatus).dy,
      greaterThan(tester.getTopLeft(find.text('Saved episode').last).dy),
    );
    expect(
      find.descendant(
        of: resume,
        matching: find.textContaining(t.comicInfo.readProgressPage(page: 2)),
      ),
      findsOneWidget,
    );
    await tester.tap(resume);
    await tester.pumpAndSettle();
    expect(launches.last.type, ComicEntryType.download);
    expect(launches.last.chapterId, 'episode-1');
    await router.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved episode').last);
    await tester.pumpAndSettle();
    expect(launches.map((args) => args.type), [
      ComicEntryType.normal,
      ComicEntryType.download,
      ComicEntryType.download,
    ]);
    await router.maybePop();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(shortcut, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the detail route localizes malformed responses and retries both states',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const changes = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
      messenger.setMockMethodCallHandler(changes, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(connectivity, null);
        messenger.setMockMethodCallHandler(changes, null);
      });
      Future<void> reachRequest() async {
        for (var i = 0; i < 60 && !api.entered.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(api.entered.isCompleted, isTrue);
      }

      api.prepare();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GlobalSettingCubit()),
            BlocProvider(create: (_) => ComicFollowCubit()),
          ],
          child: const MaterialApp(
            home: ComicInfoPage(
              comicId: _comic,
              from: 'detail-fixture',
              type: ComicEntryType.normal,
            ),
          ),
        ),
      );
      try {
        await reachRequest();
        api.response.completeError(
          AnyhowException("unexpected token: 'error'"),
        );
        await tester.pump();
        final invalid = find.text(t.comicFollow.checkInvalidResponse);
        expect(invalid, findsOneWidget);
        expect(find.textContaining('unexpected token'), findsNothing);
        final reload = find.text(t.common.reload);
        expect(reload, findsOneWidget);

        api.prepare();
        await tester.tap(reload);
        await reachRequest();
        api.response.complete(_detail('retry-metadata'));
        await tester.pumpAndSettle();
        final title = find.text('Fixture detail');
        expect(title, findsOneWidget);
        expect(invalid, findsNothing);

        api.prepare();
        final indicator = tester.state<RefreshIndicatorState>(
          find.byType(RefreshIndicator),
        );
        unawaited(indicator.show());
        await reachRequest();
        api.response.completeError(
          AnyhowException("unexpected token: 'error'"),
        );
        await tester.pumpAndSettle();
        expect(title, findsOneWidget);
        expect(invalid, findsOneWidget);
        expect(find.textContaining('unexpected token'), findsNothing);

        api.prepare();
        await tester.tap(find.text(t.common.retry));
        await reachRequest();
        api.response.complete(_detail('refresh-retry'));
        await tester.pumpAndSettle();
        expect(title, findsOneWidget);
        expect(invalid, findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  test(
    'an error envelope cannot replace a working detail with its payload',
    () async {
      const event = GetComicInfoEvent(
        comicId: _comic,
        from: _source,
        type: ComicEntryType.normal,
      );
      final bloc = GetComicInfoBloc();
      addTearDown(bloc.close);
      api.prepare();
      final initial = bloc.refresh(event);
      await api.entered.future.timeout(const Duration(seconds: 3));
      api.response.complete(_detail('old'));
      expect(await initial, isTrue);
      final previous = bloc.state.allInfo;

      api.prepare();
      final refresh = bloc.refresh(event.copyWith());
      await api.entered.future.timeout(const Duration(seconds: 3));
      api.response.complete({
        'data': {
          'type': 'comic_detail_error',
          'reason': 'sourceUnavailable',
          ..._detail('unconfirmed'),
        },
      });
      expect(await refresh, isFalse);
      expect(bloc.state.allInfo, same(previous));
      expect(bloc.refreshError, t.comicFollow.checkSourceUnavailable);
    },
  );

  test('closing a detail cancels only its own native read', () async {
    const event = GetComicInfoEvent(
      comicId: _comic,
      from: _source,
      type: ComicEntryType.normal,
    );
    api.cancelledGroups.clear();
    api.prepare();
    final first = GetComicInfoBloc();
    final firstLoad = first.refresh(event);
    final firstGroup = await api.entered.future.timeout(
      const Duration(seconds: 3),
    );
    final firstResponse = api.response;
    api.prepare();
    final second = GetComicInfoBloc();
    final secondLoad = second.refresh(event);
    final secondGroup = await api.entered.future.timeout(
      const Duration(seconds: 3),
    );

    try {
      await first.close();
      expect(await firstLoad, isFalse);
      expect(firstGroup, isNotEmpty);
      expect(secondGroup, isNot(firstGroup));
      expect(api.cancelledGroups, [firstGroup]);
      api.response.complete(_detail('open-detail'));
      expect(await secondLoad, isTrue);
    } finally {
      firstResponse.complete(_detail('closed-detail'));
      if (!api.response.isCompleted) api.response.complete(_detail('cleanup'));
      await second.close();
    }
  });

  test('late old-account detail cannot publish public metadata', () async {
    final saved = createTestFavorite('$_source:$_comic')
      ..source = _source
      ..comicId = _comic
      ..metadata = '[]';
    objectbox.unifiedFavoriteBox.put(saved);
    addTearDown(() => objectbox.unifiedFavoriteBox.remove(saved.id));

    api.prepare();
    final old = getComicDetailByPlugin(_comic, _source);
    await api.entered.future.timeout(const Duration(seconds: 3));
    pluginSessionWriteFence.advance(_source);
    api.response.complete(_detail('old-tag'));
    await old;
    expect(objectbox.unifiedFavoriteBox.get(saved.id)!.metadata, '[]');

    api.prepare();
    final current = getComicDetailByPlugin(_comic, _source);
    await api.entered.future.timeout(const Duration(seconds: 3));
    api.response.complete(_detail('current-tag'));
    await current;
    expect(
      objectbox.unifiedFavoriteBox.get(saved.id)!.metadata,
      contains('current-tag'),
    );
  });

  test(
    'only the current detail account may dispatch its login request',
    () async {
      final events = <NeedLogin>[];
      final listener = eventBus.on<NeedLogin>().listen(events.add);
      addTearDown(listener.cancel);
      AnyhowException unauthorized(String message) => AnyhowException(
        jsonEncode({
          'type': 'unauthorized',
          'source': _source,
          'message': message,
        }),
      );

      api.prepare();
      final old = expectLater(
        getComicDetailByPlugin(_comic, _source),
        throwsA(isA<PluginLoginRequiredException>()),
      );
      await api.entered.future.timeout(const Duration(seconds: 3));
      pluginSessionWriteFence.advance(_source);
      api.response.completeError(unauthorized('Previous account'));
      await old;
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      api.prepare();
      final current = expectLater(
        getComicDetailByPlugin(_comic, _source),
        throwsA(isA<PluginLoginRequiredException>()),
      );
      await api.entered.future.timeout(const Duration(seconds: 3));
      api.response.completeError(unauthorized('Current account'));
      await current;
      await Future<void>.delayed(Duration.zero);
      expect(events.single.message, 'Current account');
    },
  );
}
