import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';

import '../test_helper.dart';

UnifiedComicListItem _entry({
  bool rich = true,
  bool actions = false,
  int likes = 0,
  List<String> tags = const [],
  List<String> authors = const ['作者甲'],
}) => UnifiedComicListItem.fromJson({
  'source': 'copy-fixture',
  'id': 'work-1',
  'title': '作品标题',
  'subtitle': rich ? '作者甲 · 连载中 · 第12话' : '',
  'finished': false,
  'likesCount': likes,
  'viewsCount': 0,
  'updatedAt': rich ? '2026-10-26' : '1970-01-01T00:00:00.000Z',
  'cover': {'id': 'work-1', 'url': '', 'path': '', 'extern': {}},
  'metadata': rich
      ? [
          {'type': 'author', 'name': '作者', 'value': authors},
          {
            'type': 'status',
            'name': '状态',
            'value': ['连载中'],
          },
          {
            'type': 'latest',
            'name': '更新',
            'value': ['第12话'],
          },
          {
            'type': 'aliases',
            'name': '别名',
            'value': ['作品标题', 'Another name'],
          },
          {
            'type': 'categories',
            'name': '题材',
            'value': ['冒险'],
          },
          {
            'type': 'popularity',
            'name': '热度',
            'value': ['12345'],
          },
          if (tags.isNotEmpty) {'type': 'tags', 'name': '标签', 'value': tags},
        ]
      : [],
  'raw': rich ? {'description': '真实的作品简介'} : {},
  'extern': actions
      ? {
          'authorActions': [
            {
              'label': '作者甲',
              'action': {
                'type': 'openComicList',
                'payload': {
                  'scene': {
                    'title': '作者作品',
                    'source': 'copy-fixture',
                    'body': {
                      'type': 'pluginPagedComicList',
                      'request': {
                        'fnPath': 'fixtureAuthor',
                        'core': {'author': 'artist-1'},
                        'extern': {},
                      },
                    },
                  },
                },
              },
            },
          ],
        }
      : {},
});

Widget _list(UnifiedComicListItem entry, {VoidCallback? onReturned}) =>
    SourceSearchDetailList(
      entries: [entry],
      hasReachedMax: true,
      isLoadingMore: false,
      loadMoreFailed: false,
      onRetryLoadMore: () {},
      onLoadMore: () {},
      onReturned: onReturned,
    );

void main() {
  test(
    'comic timestamps format ISO values without inventing another time meaning',
    () {
      expect(
        formatSourceComicTimestamp('2026-11-01T09:05:27.987'),
        '2026-11-01 09:05',
      );
      expect(formatSourceComicTimestamp('2026-11-01'), '2026-11-01');
      expect(formatSourceComicTimestamp('3天前'), '3天前');
      expect(formatSourceComicTimestamp('1970-01-01T00:00:00.000Z'), isEmpty);
      expect(formatSourceComicTimestamp('0'), isEmpty);
    },
  );

  testWidgets(
    'source update, local revision and last reading retain their own meanings',
    (tester) async {
      final updated = _entry(rich: false).copyWith(
        updatedAt: '2030-02-03T04:05:06.123',
        raw: {'lastReadAt': '2026-11-01T09:05:27.987'},
      );
      for (final kind in ComicEntryType.values.where(
        (value) => [
          ComicEntryType.normal,
          ComicEntryType.favorite,
          ComicEntryType.history,
        ].contains(value),
      )) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SourceSearchDetailTile(entry: updated, type: kind),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (kind == ComicEntryType.history) {
          expect(
            find.text(t.comicEntry.lastReadAt(time: '2026-11-01 09:05')),
            findsOneWidget,
          );
          expect(
            find.text(t.comicEntry.updatedAt(time: '2030-02-03 04:05')),
            findsNothing,
          );
        } else {
          expect(
            find.text(t.comicEntry.updatedAt(time: '2030-02-03 04:05')),
            findsOneWidget,
          );
        }
        expect(find.textContaining('T04:05'), findsNothing);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceSearchDetailTile(
              entry: updated,
              type: ComicEntryType.favorite,
              localRecord: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(t.comicEntry.recordUpdatedAt(time: '2030-02-03 04:05')),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceSearchDetailTile(
              entry: updated.copyWith(raw: {}),
              type: ComicEntryType.history,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('2030-02-03'),
        findsNothing,
        reason: 'record revision cannot stand in for missing lastReadAt',
      );
      expect(tester.takeException(), isNull);
    },
  );

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('JM list and grid covers observe confirmed likes in place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fence = PluginSessionWriteFence();
    var elapsed = Duration.zero;
    final counts = JmListLikeCounts(
      sessionFence: fence,
      elapsed: () => elapsed,
      lifetime: const Duration(minutes: 1),
    );
    addTearDown(counts.dispose);
    final entry = _entry(
      rich: false,
      likes: 99,
    ).copyWith(source: JmListLikeCounts.source);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JmCoverLikeScope(
            counts: counts,
            child: Column(
              children: [
                SourceSearchDetailTile(entry: entry),
                SizedBox(
                  width: 105,
                  child: ComicSimplifyEntry(
                    info: entry.toSimplifyEntryInfo(),
                    type: ComicEntryType.normal,
                    selectionMode: true,
                    isSelected: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('99'), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    final covers = tester.stateList(find.byType(CoverWidget)).toList();
    expect(covers, hasLength(2));

    counts.remember({entry.id: 0}, generation: 0);
    await tester.pump();
    expect(find.text('0'), findsNWidgets(2));
    expect(tester.stateList(find.byType(CoverWidget)), orderedEquals(covers));

    elapsed += const Duration(minutes: 1);
    await tester.pump(const Duration(minutes: 1));
    expect(find.byIcon(Icons.favorite_border), findsNothing);

    counts.remember({entry.id: 25}, generation: 0);
    await tester.pump();
    expect(find.text('25'), findsNWidgets(2));
    fence.advance(JmListLikeCounts.source);
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(tester.stateList(find.byType(CoverWidget)), orderedEquals(covers));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'collection cards keep the bookshelf poster frame across text sizes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 440.0]) {
        for (final scale in [1.0, 1.4, 2.0]) {
          tester.view.physicalSize = Size(width, 1000);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SourceSearchDetailTile(
                    entry: _entry(),
                    collectionLayout: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byType(CoverWidget)), const Size(80, 120));
          expect(
            tester
                .widget<CoverWidget>(find.byType(CoverWidget))
                .containBackground,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('shelf-detail.metadata')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: '$width / $scale');
        }
      }
    },
  );

  testWidgets(
    'collection details retain stable frame and expose real popularity',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceSearchDetailTile(
              entry: _entry(likes: 43, tags: const ['短篇', '校园', '喜剧']),
              collectionLayout: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final details = tester.widget<Text>(
        find.byKey(const ValueKey('shelf-detail.metadata')),
      );
      expect(details.data, contains('点赞 43'));
      expect(details.data, contains('热度 12345'));
      expect(details.data, contains('冒险'));
      expect(details.data, contains('短篇'));
      expect(details.data, isNot(contains('校园')));
      expect(details.data, contains('+2'));
      expect(tester.getSize(find.byType(CoverWidget)), const Size(80, 120));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'available copy metadata is distinct and popularity is not a like',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: _list(_entry())),
        ),
      );
      expect(find.text('作者甲'), findsOneWidget);
      expect(find.text('作者甲 · 连载中 · 第12话'), findsNothing);
      expect(find.text('连载中 · 第12话'), findsOneWidget);
      expect(find.text('又名：Another name'), findsOneWidget);
      expect(find.text('热度 12345'), findsOneWidget);
      expect(find.text('更新: 2026-10-26'), findsOneWidget);
      expect(find.text('真实的作品简介'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
    },
  );

  testWidgets(
    'authors without a navigation slug remain credited beside linked authors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _list(_entry(actions: true, authors: const ['作者甲', '作者乙'])),
          ),
        ),
      );
      expect(find.widgetWithText(TextButton, '作者甲'), findsOneWidget);
      expect(find.text('作者乙'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '作者乙'), findsNothing);
      expect(find.text('作者甲'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
    },
  );

  testWidgets('missing metadata stays absent and genuine likes stay likes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _list(_entry(rich: false, likes: 42)))),
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('又名'), findsNothing);
    expect(find.textContaining('热度'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets(
    'author navigation preserves its scene and only refreshes after return',
    (tester) async {
      var returns = 0;
      var detailVisits = 0;
      String? author;
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'FixtureHome',
            path: '/',
            initial: true,
            builder: (_, _) => Scaffold(
              body: _list(_entry(actions: true), onReturned: () => returns++),
            ),
          ),
          NamedRouteDef(
            name: ComicListRoute.name,
            path: '/author',
            builder: (context, data) {
              author = data
                  .argsAs<ComicListRouteArgs>()
                  .scene
                  ?.body
                  .request
                  ?.core['author']
                  ?.toString();
              return const Scaffold(body: Text('Author works fixture'));
            },
          ),
          NamedRouteDef(
            name: ComicInfoRoute.name,
            path: '/comic',
            builder: (_, _) {
              detailVisits++;
              return const Scaffold(body: Text('Comic detail fixture'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await tester.pumpAndSettle();
      final authorButton = find.widgetWithText(TextButton, '作者甲');
      expect(tester.getRect(authorButton).height, greaterThanOrEqualTo(44));
      await tester.tap(authorButton);
      await tester.pumpAndSettle();
      expect(find.text('Author works fixture'), findsOneWidget);
      expect(author, 'artist-1');
      expect(detailVisits, 0, reason: 'author tap must not bubble to the work');
      expect(returns, 0);
      await router.maybePop();
      await tester.pumpAndSettle();
      expect(returns, 1);
      await tester.tap(find.text('作品标题'));
      await tester.pumpAndSettle();
      expect(find.text('Comic detail fixture'), findsOneWidget);
      expect(returns, 1);
      await router.maybePop();
      await tester.pumpAndSettle();
      expect(returns, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
