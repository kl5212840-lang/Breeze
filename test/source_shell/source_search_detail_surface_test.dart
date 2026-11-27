import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
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
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
  });

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

  testWidgets('record menus keep settings and folders with old exclusions', (
    tester,
  ) async {
    const source = 'record-menu-fixture';
    SharedPreferences.setMockInitialValues({
      SourceListBlockPreferences.key('$source|profile:favorite'): '["冒险"]',
    });
    final entry = _entry().copyWith(source: source);
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceProfileRecordsView(
              key: ValueKey(compact),
              mode: ShelfPageMode.favorite,
              entries: [entry],
              source: source,
              compactLayout: compact,
              onBack: () {},
              onRefresh: () {},
              onManageFolders: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.title), findsOneWidget);
      final menu = tester.widget<NativeVideoMenu>(
        find.byKey(
          ValueKey(compact ? 'jm-record.more' : 'profile-record.more'),
        ),
      );
      expect(menu.options.values, contains(t.plugin.pluginSettings));
      expect(menu.options.values, contains(t.videoSource.manageFolders));
      expect(
        menu.options.keys.any(
          (key) => key.startsWith('category.') || key == 'clear-blocked',
        ),
        isFalse,
      );
    }
  });

  testWidgets('JM search keeps confirmed likes on list and grid covers', (
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
            subtleBadge: true,
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
    final captionCount = find.descendant(
      of: find.byType(ComicDetailedCaption),
      matching: find.text('0'),
    );
    expect(captionCount, findsNothing);
    expect(find.byType(JmCoverLikeBadge), findsNWidgets(2));
    final badgeFill = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(JmCoverLikeBadge),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((badgeFill.decoration as BoxDecoration).color?.a, closeTo(.60, .01));
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
    'list covers preserve their original proportions across text sizes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 440.0]) {
        for (final scale in [1.0, 1.4, 2.0]) {
          for (final collection in [false, true]) {
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
                  body: ListView(
                    children: [
                      SourceSearchDetailTile(
                        entry: _entry(
                          tags: List.generate(12, (i) => '主题$i'),
                        ).copyWith(title: List.filled(5, '很长的作品标题').join()),
                        collectionLayout: collection,
                      ),
                      SourceSearchDetailTile(
                        entry: _entry(rich: false).copyWith(id: 'sparse'),
                        collectionLayout: collection,
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final covers = find.byType(CoverWidget);
            final firstCover = tester.getSize(covers.first);
            expect(
              firstCover,
              collection ? const Size(80, 120) : const Size(84, 116),
            );
            expect(tester.getSize(covers.last), firstCover);
            final caption = tester.getRect(
              find.byType(ComicDetailedCaption).first,
            );
            expect(tester.getRect(covers.first).top, caption.top);
            if (scale == 1) {
              expect(
                caption.bottom,
                lessThanOrEqualTo(tester.getRect(covers.first).bottom),
              );
            }
            expect(find.text('真实的作品简介'), findsNothing);
            expect(
              tester.widget<CoverWidget>(covers.first).containBackground,
              collection,
            );
            expect(find.text('作者甲'), findsOneWidget);
            expect(tester.takeException(), isNull, reason: '$width / $scale');
          }
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
              entry: _entry(
                likes: 43,
                tags: const ['短篇', '校园', '喜剧'],
              ).copyWith(source: 'another-plugin', raw: {'pagesCount': 26}),
              collectionLayout: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('作者甲'), findsOneWidget);
      expect(find.text('连载中 · 第12话 · 冒险 …'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(find.text('热度 12345'), findsOneWidget);
      expect(
        find.text(t.searchResult.itemPageCount(count: 26)),
        findsOneWidget,
      );
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
      expect(find.text('连载中 · 第12话 · 冒险'), findsOneWidget);
      expect(find.textContaining('Another name'), findsNothing);
      expect(find.text('热度 12345'), findsOneWidget);
      expect(find.text('更新: 2026-10-26'), findsNothing);
      expect(find.text('真实的作品简介'), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(t.download.workDetails));
      await tester.pumpAndSettle();
      final update = find.text('更新: 2026-10-26');
      await tester.scrollUntilVisible(
        update,
        140,
        scrollable: find.byType(Scrollable).last,
      );
      expect(update, findsOneWidget);
    },
  );

  testWidgets('saved comic title facts keep page and chapter counts accessible', (
    tester,
  ) async {
    final entry = _entry(rich: false).copyWith(
      raw: {
        'titleMeta':
            '[{"name":"页数：27"},{"name":"章节数：4"},{"name":"更新时间：2025-03-11T15:08:00"}]',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceSearchDetailTile(
            entry: entry,
            collectionLayout: true,
            localRecord: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.searchResult.itemPageCount(count: 27)), findsOneWidget);
    expect(find.text('章节数'), findsNothing);
    await tester.tap(find.byTooltip(t.download.workDetails));
    await tester.pumpAndSettle();
    expect(find.text('章节数'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      find.text(t.comicEntry.updatedAt(time: '2025-03-11 15:08')),
      findsOneWidget,
    );
  });

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
    final unknown = _entry(rich: false).copyWith(id: 'unknown');
    final zero = _entry(
      rich: false,
      likes: 0,
    ).copyWith(id: 'zero', raw: {'likesCount': 0});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SourceSearchDetailTile(entry: _entry(rich: false, likes: 42)),
              SourceSearchDetailTile(entry: unknown),
              SourceSearchDetailTile(entry: zero),
            ],
          ),
        ),
      ),
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('又名'), findsNothing);
    expect(find.textContaining('热度'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets(
    'collection metadata opens every tag and the synopsis without resizing the row',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tags = List.generate(12, (index) => '独立主题$index');
      final entry = _entry(tags: tags, actions: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceSearchDetailTile(entry: entry, collectionLayout: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = tester.getRect(find.byType(CoverWidget));
      expect(find.text(tags.join(' · ')), findsNothing);
      await tester.tap(find.byTooltip(t.download.workDetails));
      await tester.pumpAndSettle();
      final allTags = find.text(tags.join(' · '));
      expect(allTags, findsOneWidget);
      expect(tester.widget<Text>(allTags).maxLines, isNull);
      expect(find.text('真实的作品简介'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(CoverWidget)), cover);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'metadata preserves exact JM likes, measured zero views and completion beside rank',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fence = PluginSessionWriteFence();
      final counts = JmListLikeCounts(sessionFence: fence);
      addTearDown(counts.dispose);
      final entry = _entry(rich: false).copyWith(
        source: JmListLikeCounts.source,
        finished: true,
        extern: {
          'metricAvailability': {'totalLikes': false, 'totalViews': true},
        },
      );
      counts.remember({entry.id: 12543}, generation: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JmCoverLikeScope(
              counts: counts,
              child: SizedBox(
                height: 180,
                child: ComicDetailedCaption(
                  entry: entry,
                  rankCount: 'Rank evidence',
                  showViews: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.likes(count: 12543)), findsNothing);
      await tester.tap(find.byTooltip(t.download.workDetails));
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.likes(count: 12543)), findsOneWidget);
      expect(find.text(t.comicEntry.views(count: 0)), findsOneWidget);
      expect(find.text(t.comicEntry.finished), findsOneWidget);
      expect(find.text('Rank evidence'), findsNWidgets(2));
      counts.remember({entry.id: 0}, generation: 0);
      await tester.pump();
      expect(find.text(t.comicInfo.likes(count: 12543)), findsNothing);
      expect(find.text(t.comicInfo.likes(count: 0)), findsOneWidget);
      fence.advance(JmListLikeCounts.source);
      await tester.pump();
    },
  );

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

  testWidgets('Copy author text on the cover card opens the work', (
    tester,
  ) async {
    final entry = _entry(
      rich: false,
      actions: true,
    ).copyWith(source: 'b28da416-f2d4-4208-a85e-8b4c7c648e48');
    final router = RootStackRouter.build(
      routes: [
        NamedRouteDef(
          name: 'FixtureHome',
          path: '/',
          initial: true,
          builder: (_, _) => Scaffold(body: _list(entry)),
        ),
        NamedRouteDef(
          name: ComicInfoRoute.name,
          path: '/comic',
          builder: (_, data) =>
              Scaffold(body: Text(data.argsAs<ComicInfoRouteArgs>().comicId)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '作者甲'), findsNothing);
    await tester.tap(find.text('作者甲'));
    await tester.pumpAndSettle();
    expect(find.text('work-1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
