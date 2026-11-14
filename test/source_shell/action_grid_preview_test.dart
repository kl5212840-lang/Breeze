import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets(
    'web category with no verified artwork uses its semantic icon and keeps its action',
    (tester) async {
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const DiscoverSchemeRenderer().buildPage(
                context,
                from: 'bika-source',
                scheme: {
                  'body': {'type': 'action-grid', 'key': 'items'},
                },
                data: {
                  'items': [
                    {
                      'title': '互动小说',
                      'icon': 'ai_story',
                      'cover': {'url': '', 'path': ''},
                      'action': {
                        'type': 'openWeb',
                        'payload': {'url': 'https://example.test/home'},
                      },
                    },
                  ],
                },
                onReachBottom: () async {},
                onAction: (action) async => selected = action,
                isLoadingMore: false,
                showLoadMoreRetry: false,
                onRetryLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsNothing);
      expect(find.byType(CoverWidget), findsNothing);
      await tester.tap(find.text('互动小说'));
      expect(selected?['type'], 'openWeb');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source categories keep their preview images and actions', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const DiscoverSchemeRenderer().buildPage(
              context,
              from: 'personal-source',
              scheme: {
                'body': {'type': 'action-grid', 'key': 'items'},
              },
              data: {
                'items': [
                  {
                    'title': '短篇',
                    'cover': {
                      'url': 'https://img.example/category.jpg',
                      'path': 'category.jpg',
                    },
                    'action': {
                      'type': 'openSearch',
                      'payload': {'source': 'personal-source'},
                    },
                  },
                ],
              },
              onReachBottom: () async {},
              onAction: (action) async => selected = action,
              isLoadingMore: false,
              showLoadMoreRetry: false,
              onRetryLoadMore: () {},
            ),
          ),
        ),
      ),
    );

    final preview = tester.widget<CoverWidget>(find.byType(CoverWidget));
    expect(preview.fileServer, 'https://img.example/category.jpg');
    expect(preview.path, 'category.jpg');
    expect(find.text('短篇'), findsOneWidget);
    await tester.tap(find.text('短篇'));
    expect(selected?['type'], 'openSearch');
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('JM recommendations keep one scope above both scroll axes', (
    tester,
  ) async {
    const source = JmListLikeCounts.source;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadRecoveryScope(
            active: false,
            child: Builder(
              builder: (context) => const DiscoverSchemeRenderer().buildPage(
                context,
                from: source,
                scheme: {
                  'body': {'type': 'comic-section-list', 'key': 'sections'},
                },
                data: {
                  'sections': [
                    {
                      'title': '推荐',
                      'body': {'titleBelow': true},
                      'items': [
                        {
                          'source': source,
                          'id': '12345',
                          'title': '推荐漫画',
                          'cover': {'id': '12345', 'url': ''},
                        },
                      ],
                    },
                  ],
                },
                onReachBottom: () async {},
                onAction: (_) async {},
                isLoadingMore: false,
                showLoadMoreRetry: false,
                onRetryLoadMore: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final scope = find.byType(JmCoverLikeScope);
    expect(scope, findsOneWidget);
    expect(
      find.descendant(of: scope, matching: find.byType(ListView)),
      findsNWidgets(2),
    );
    final strip = tester.widget<ComicFixedSizeHorizontalList>(
      find.byType(ComicFixedSizeHorizontalList),
    );
    expect(strip.entries.single.from, source);
    expect(strip.entries.single.id, '12345');
    expect(strip.titleBelow, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('禁漫分类卡片保留文字、图标与列表动作', (tester) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const DiscoverSchemeRenderer().buildPage(
              context,
              from: 'jm-source',
              scheme: {
                'body': {'type': 'source-category-grid', 'key': 'categories'},
              },
              data: {
                'categories': [
                  {
                    'title': '同人',
                    'subtitle': '系列与角色同人',
                    'icon': 'people',
                    'action': {
                      'type': 'openComicList',
                      'payload': {'scene': {}},
                    },
                  },
                ],
              },
              onReachBottom: () async {},
              onAction: (action) async => selected = action,
              isLoadingMore: false,
              showLoadMoreRetry: false,
              onRetryLoadMore: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('同人'), findsOneWidget);
    expect(find.text('系列与角色同人'), findsOneWidget);
    await tester.tap(find.text('同人'));
    expect(selected?['type'], 'openComicList');
  });
}
