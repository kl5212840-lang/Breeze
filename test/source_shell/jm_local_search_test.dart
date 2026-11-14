import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/search_result/view/source_comic_search.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import '../test_helper.dart';

UnifiedComicListItem row(
  String id, {
  String source = 'jm-search',
  List<UnifiedComicMetadata> metadata = const [],
}) => UnifiedComicListItem.fromJson({
  'source': source,
  'id': id,
  'title': '标题 $id',
  'subtitle': '第一章',
  'finished': false,
  'likesCount': 0,
  'viewsCount': 0,
  'updatedAt': '',
  'cover': {'id': id, 'url': '', 'path': '', 'extern': {}},
  'metadata': metadata.map((m) => m.toJson()).toList(),
  'raw': {'description': '公开简介', 'secret': 'private-session'},
  'extern': {},
});

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  test(
    'local enrichment uses exact source/id and respects explicit dimensions',
    () {
      for (final (source, id, tag) in [
        ('jm-search', 'one', '本机标签'),
        ('other-source', 'one', '跨源标签'),
        ('jm-search', 'two', '其他作品'),
      ]) {
        final favorite = createTestFavorite('$source:$id')
          ..source = source
          ..comicId = id
          ..metadata = jsonEncode([
            {
              'type': 'tags',
              'value': [
                {'name': tag},
              ],
            },
            {
              'type': 'author',
              'value': [
                {'name': '本机作者'},
              ],
            },
          ]);
        objectbox.unifiedFavoriteBox.put(favorite);
      }
      final enriched = enrichSourceComicMetadata([row('one')]).single;
      expect(sourceLoadedComicFacet(enriched).fields['tags'], {'本机标签'});
      expect(enriched.toSimplifyEntryInfo().detailMetadata, contains('本机标签'));
      expect(
        sourceComicSearchText(enriched, SourceComicSearchScope.author),
        '本机作者',
      );
      expect(
        sourceComicSearchText(enriched, SourceComicSearchScope.tags),
        '本机标签',
      );
      expect(
        sourceComicSearchText(enriched, SourceComicSearchScope.title),
        '标题 one',
      );
      expect(
        sourceComicSearchText(enriched, SourceComicSearchScope.all),
        contains('公开简介'),
      );
      expect(
        sourceComicSearchText(enriched, SourceComicSearchScope.all),
        isNot(contains('private-session')),
      );
      final explicit = enrichSourceComicMetadata([
        row(
          'one',
          metadata: const [
            UnifiedComicMetadata(type: 'tags', name: '标签', value: []),
          ],
        ),
      ]).single;
      expect(
        sourceLoadedComicFacet(explicit).fields.containsKey('tags'),
        isFalse,
      );
      expect(sourceLoadedComicFacet(explicit).fields['author'], {'本机作者'});
    },
  );

  test(
    'a newer known-empty local tag dimension blocks older fallback tags',
    () {
      final old = row(
        'one',
        metadata: const [
          UnifiedComicMetadata(type: 'tags', name: '标签', value: ['旧标签']),
        ],
      ).copyWith(updatedAt: '2026-11-01');
      final empty = row('one').copyWith(
        updatedAt: '2026-11-07',
        raw: {
          'metadata': [
            {'type': 'tags', 'value': []},
          ],
        },
      );
      final result = mergeKnownSourceComicMetadata(
        [row('one')],
        [old, empty],
      ).single;
      expect(
        sourceLoadedComicFacet(result).fields.containsKey('tags'),
        isFalse,
      );
      final explicit = row('one').copyWith(
        raw: {
          'metadata': [
            {'type': 'tags', 'value': []},
          ],
        },
      );
      expect(
        sourceLoadedComicFacet(
          mergeKnownSourceComicMetadata([explicit], [old]).single,
        ).fields.containsKey('tags'),
        isFalse,
      );
    },
  );

  testWidgets(
    'JM records search reopens with focus and scopes the same local result',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: SourceProfileRecordsView(
                mode: ShelfPageMode.favorite,
                source: 'jm-search',
                jmCollection: true,
                entries: [
                  row(
                    'one',
                    metadata: const [
                      UnifiedComicMetadata(
                        type: 'tags',
                        name: '标签',
                        value: ['标签词'],
                      ),
                      UnifiedComicMetadata(
                        type: 'author',
                        name: '作者',
                        value: ['作者词'],
                      ),
                    ],
                  ),
                ],
                onBack: () {},
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-loaded.search')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('jm-record.search')));
      await tester.pumpAndSettle();
      TextField search() => tester.widget<TextField>(
        find.byKey(const ValueKey('source-loaded.search')),
      );
      expect(search().focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      final ownedFocus = search().focusNode;
      expect(
        tester
            .widget<SourceLoadedResultFilter>(
              find.byType(SourceLoadedResultFilter),
            )
            .searchFocusNode,
        same(ownedFocus),
        reason: 'The actual JM record owner supplies the editor node',
      );
      tester.testTextInput.hide();
      expect(ownedFocus!.hasFocus, isTrue);
      await tester.tap(find.byKey(const ValueKey('source-loaded.search')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('source-loaded.search')),
        '作者词',
      );
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      final refreshed = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pumpAndSettle();
      await refreshed;
      expect(search().focusNode, same(ownedFocus));
      expect(search().controller!.text, '作者词');
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'Refreshing rows is not another search-open gesture',
      );
      expect(
        find.byKey(const ValueKey('profile-record.jm-search:one')),
        findsOneWidget,
        reason: 'New local searches default to all public fields',
      );
      await tester.tap(
        find.byKey(const ValueKey('source-loaded.search-scope')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.searchScopeTitle).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-record.jm-search:one')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('source-loaded.search-scope')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.all).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-record.jm-search:one')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('jm-record.search')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const ValueKey('jm-record.search')));
      final changing = pluginSessionWriteFence.beginSessionChange('jm-search');
      try {
        await tester.pumpAndSettle();
        expect(
          tester.testTextInput.isVisible,
          isFalse,
          reason:
              'An old account\'s pending search-open cannot take keyboard ownership',
        );
      } finally {
        pluginSessionWriteFence.seal('jm-search', changing);
      }
      await tester.tap(find.byKey(const ValueKey('jm-record.search')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jm-record.search')));
      await tester.pumpAndSettle();
      expect(search().focusNode!.hasFocus, isTrue);
      expect(
        search().controller!.text,
        '作者词',
        reason:
            'Closing the editor retains its query; this fixture only changes the write fence, not the record owner',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'JM local view choice survives reopen and another record mode without crossing sources',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      Future<void> mount(String source, ShelfPageMode mode) async {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: Scaffold(
                body: SourceProfileRecordsView(
                  mode: mode,
                  source: source,
                  jmCollection: true,
                  entries: [row('one', source: source)],
                  onBack: () {},
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount('jm-search', ShelfPageMode.favorite);
      expect(
        find.byKey(const ValueKey('profile-detailed-list')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('jm-record-view')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-cover-grid')), findsOneWidget);
      expect(await SourceListPreferences.read('jm-search'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount('jm-search', ShelfPageMode.history);
      expect(find.byKey(const ValueKey('profile-cover-grid')), findsOneWidget);
      await mount('other-source', ShelfPageMode.favorite);
      expect(
        find.byKey(const ValueKey('profile-detailed-list')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('arriving JM metadata does not discard a valid filter draft', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    final entries = ValueNotifier([
      row(
        'one',
        metadata: const [
          UnifiedComicMetadata(type: 'tags', name: '标签', value: ['已知标签']),
        ],
      ),
    ]);
    addTearDown(style.dispose);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<UnifiedComicListItem>>(
              valueListenable: entries,
              builder: (context, rows, _) => SourceLoadedResultFilter(
                focusedFacets: true,
                searchExpanded: false,
                entries: rows,
                scope: 'jm-filter-account',
                chromeBuilder: (_, chrome) => Column(
                  children: [chrome.filterButton, ?chrome.appliedFilters],
                ),
                builder: (_, visible, chrome) => Column(
                  children: [chrome, Text('visible:${visible.length}')],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-loaded.filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-option-tags-已知标签')));
    entries.value = [
      ...entries.value,
      row(
        'two',
        metadata: const [
          UnifiedComicMetadata(type: 'tags', name: '标签', value: ['已知标签']),
        ],
      ),
    ];
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.text('visible:2'), findsOneWidget);
    expect(find.byKey(const ValueKey('source-loaded.applied')), findsOneWidget);
    expect(find.text(t.comicList.loadedFiltersChanged), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
