import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

UnifiedComicListItem _entry({
  bool rich = true,
  bool actions = false,
  int likes = 0,
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
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

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
