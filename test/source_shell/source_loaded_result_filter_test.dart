import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';

UnifiedComicListItem _comic(
  String id,
  String title,
  String category,
  String tag,
) => UnifiedComicListItem.fromJson({
  'source': 'unknown-third-party',
  'id': id,
  'title': title,
  'subtitle': '',
  'finished': false,
  'likesCount': 0,
  'viewsCount': 0,
  'updatedAt': '',
  'cover': {'id': id, 'url': '', 'path': '', 'extern': {}},
  'metadata': [
    {
      'type': 'category',
      'name': '分类',
      'value': [category],
    },
    {
      'type': 'tags',
      'name': '标签',
      'value': [tag],
    },
    {
      'type': 'author',
      'name': '作者',
      'value': ['作者甲'],
    },
  ],
  'raw': {'secret': 'must-not-be-searchable'},
  'extern': {},
});

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all declared metadata segments remain in their own facet with no arbitrary cap',
    () {
      final base = _comic('many', 'Public metadata', '分类甲', '标签甲');
      final item = base.copyWith(
        metadata: [
          ...base.metadata,
          const UnifiedComicMetadata(type: 'tags', name: '标签', value: ['后续标签']),
          const UnifiedComicMetadata(
            type: 'author',
            name: '作者',
            value: ['后续作者'],
          ),
          const UnifiedComicMetadata(
            type: 'category',
            name: '分类',
            value: ['后续分类'],
          ),
          UnifiedComicMetadata(
            type: 'tags',
            name: '标签',
            value: List.generate(140, (index) => 'tag-$index'),
          ),
        ],
      );
      final facet = sourceLoadedComicFacet(item);
      expect(facet.fields['tags'], containsAll(['标签甲', '后续标签', 'tag-139']));
      expect(facet.fields['tags'], hasLength(142));
      expect(facet.fields['author'], {'作者甲', '后续作者'});
      expect(facet.fields['category'], {'分类甲', '后续分类'});
      expect(facet.fields['tags'], isNot(contains('后续作者')));
      expect(facet.fields['tags'], isNot(contains('后续分类')));
    },
  );

  test(
    'public facets preserve unknown plugin identity and never infer title metadata',
    () {
      final comic = _comic('first', '2026 北美 漫画', '短篇', '真实标签');
      final facet = sourceLoadedComicFacet(comic);
      expect(facet.source, 'unknown-third-party');
      expect(facet.key, 'unknown-third-party:first');
      expect(facet.fields['category'], {'短篇'});
      expect(facet.fields['tags'], {'真实标签'});
      expect(facet.fields.containsKey('year'), isFalse);
      expect(facet.fields.containsKey('area'), isFalse);
      expect(
        sourceLoadedComicMatches(comic, '作者甲', const ShelfFacetSelection()),
        isTrue,
      );
      expect(
        sourceLoadedComicMatches(
          comic,
          'must-not-be-searchable',
          const ShelfFacetSelection(),
        ),
        isFalse,
      );
      expect(
        sourceLoadedComicMatches(
          comic,
          '',
          const ShelfFacetSelection(
            values: {
              'tags': {'真实标签'},
            },
          ),
        ),
        isTrue,
      );
      expect(
        sourceLoadedComicMatches(
          comic,
          '',
          const ShelfFacetSelection(
            values: {
              'tags': {'不存在'},
            },
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'a confirmed expired session clears the last private page on refresh',
    () async {
      var signedOut = false;
      final cubit = PluginPagedComicListCubit(
        pluginId: 'private-fixture',
        fnPath: 'favorites',
        privateCollection: true,
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {},
        requestPage: (source, fn, core, extern) async {
          if (signedOut)
            throw const PluginLoginRequiredException(
              UnauthorizedPayload(
                pluginId: 'private-fixture',
                message: '登录已失效',
              ),
            );
          return {
            'source': source,
            'data': {
              'items': [_comic('first', '私有作品', '短篇', '标签甲').toJson()],
              'hasReachedMax': true,
            },
          };
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.state.list, hasLength(1));
      signedOut = true;
      expect(await cubit.refresh(), isFalse);
      expect(cubit.state.list, isEmpty);
      expect(cubit.state.status, PluginPagedComicListStatus.failure);
      expect(cubit.privateDataRevision, 1);
    },
  );

  testWidgets('compact collection tools keep loaded scope and fit large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var reads = 0;
    for (final width in [320.0, 390.0, 440.0]) {
      for (final scale in [1.0, 1.4, 2.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SourceLoadedResultFilter(
                key: ValueKey((width, scale)),
                compactControls: true,
                entries: [_comic('one', '已读取的作品', '短篇', '标签甲')],
                scope: 'unknown-third-party|cloudFavorite',
                complete: false,
                onLoadMore: () => reads++,
                builder: (_, visible, controls) => Column(
                  children: [
                    controls,
                    for (final entry in visible) Text(entry.title),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('source-loaded.search'));
        final filter = find.byKey(const ValueKey('source-loaded.filters'));
        expect(
          tester.getRect(search).center.dy,
          closeTo(tester.getRect(filter).center.dy, 1),
        );
        expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
        await tester.enterText(search, '尚未读取');
        await tester.pump();
        expect(
          find.text(
            t.videoLibrary.localCatalogUnknownTotal(loaded: 1, shown: 0),
          ),
          findsOneWidget,
        );
        expect(
          reads,
          0,
          reason: 'local searching never implies loading all remote favorites',
        );
        expect(
          find.byKey(const ValueKey('source-loaded.continue')),
          findsNothing,
        );
        expect(tester.takeException(), isNull, reason: '$width / $scale');
      }
    }
  });

  testWidgets(
    'loaded search distinguishes partial results and keeps the query when more arrive',
    (tester) async {
      var entries = [_comic('first', '已读第一部', '短篇', '标签甲')];
      var complete = false;
      var reads = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SourceLoadedResultFilter(
                  entries: entries,
                  scope: 'unknown-third-party|cloudFavorite',
                  complete: complete,
                  onLoadMore: () {
                    reads++;
                    update(() {
                      entries = [
                        ...entries,
                        _comic('second', '待查目标', '长篇', '标签乙'),
                      ];
                      complete = true;
                    });
                  },
                  builder: (context, visible, controls) => Column(
                    children: [
                      controls,
                      for (final entry in visible)
                        Text(entry.title, key: ValueKey(entry.id)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('source-loaded.search')),
        '待查目标',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first')), findsNothing);
      expect(
        find.text(t.videoLibrary.localCatalogUnknownTotal(loaded: 1, shown: 0)),
        findsOneWidget,
      );
      expect(reads, 0, reason: 'Typing must not fetch the whole collection');
      update(() {
        entries = [...entries, _comic('second', '待查目标', '长篇', '标签乙')];
        complete = true;
      });
      await tester.pumpAndSettle();
      expect(reads, 0);
      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('source-loaded.continue')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('source-loaded.search')),
            )
            .controller!
            .text,
        '待查目标',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inclusive filter draft cancels independently of exclusions and applies once',
    (tester) async {
      final entries = [
        _comic('first', '作品甲', '短篇', '标签甲'),
        _comic('second', '作品乙', '长篇', '标签乙'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceLoadedResultFilter(
              entries: entries,
              scope: 'fixture|cloudFavorite',
              blockedCategories: const {'短篇'},
              builder: (context, visible, controls) => Column(
                children: [
                  controls,
                  for (final entry in visible)
                    Text(entry.title, key: ValueKey(entry.id)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first')), findsNothing);
      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      final tag = find.byKey(const ValueKey('shelf-option-tags-标签乙'));
      // Open the real expandable tag group rather than selecting a block chip.
      final group = find.textContaining(t.bookshelf.facets.tags).first;
      await tester.tap(group);
      await tester.pumpAndSettle();
      await tester.ensureVisible(tag);
      await tester.tap(tag);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-loaded.reset')), findsNothing);
      expect(find.byKey(const ValueKey('first')), findsNothing);
      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(t.bookshelf.facets.tags).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(tag);
      await tester.tap(tag);
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-loaded.reset')), findsOneWidget);
      expect(find.byKey(const ValueKey('first')), findsNothing);
      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a refreshed snapshot refuses the old draft with a visible explanation',
    (tester) async {
      var entries = [_comic('first', '作品甲', '短篇', '标签甲')];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SourceLoadedResultFilter(
                  entries: entries,
                  scope: 'fixture|cloudFavorite',
                  builder: (context, visible, controls) => Column(
                    children: [
                      controls,
                      for (final entry in visible) Text(entry.title),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-option-tags-标签甲')));
      update(() => entries = [_comic('second', '作品乙', '长篇', '标签乙')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.text(t.comicList.loadedFiltersChanged), findsOneWidget);
      expect(find.byKey(const ValueKey('source-loaded.reset')), findsNothing);
      expect(find.text('作品乙'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('source-loaded.filters')),
            )
            .onPressed,
        isNotNull,
        reason:
            'Refreshing while the sheet is open must not leave its trigger disabled after closing',
      );
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shelf-option-tags-标签乙')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('shelf-option-tags-标签甲')), findsNothing);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing a private result closes only its own obsolete filter sheet',
    (tester) async {
      var active = true;
      late StateSetter update;
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return active
                    ? SourceLoadedResultFilter(
                        entries: [_comic('first', '私有作品', '短篇', '私有标签')],
                        scope: 'fixture|cloudFavorite',
                        builder: (context, visible, controls) => controls,
                      )
                    : const Text('新的账号');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
      await tester.pumpAndSettle();
      showDialog<void>(
        context: navigation.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(title: Text('较新的弹窗')),
      );
      await tester.pumpAndSettle();
      update(() => active = false);
      await tester.pumpAndSettle();
      expect(find.text('较新的弹窗'), findsOneWidget);
      navigation.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('新的账号'), findsOneWidget);
      expect(find.byKey(const ValueKey('shelf-filter-fields')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
