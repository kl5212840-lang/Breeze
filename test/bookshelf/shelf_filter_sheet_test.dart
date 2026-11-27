import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';

List<ShelfFacetEntry> _entries() => [
  const ShelfFacetEntry(
    key: 'a',
    source: 'one',
    searchText: 'first',
    fields: {
      'tags': {'A'},
      'author': {'X'},
    },
  ),
  const ShelfFacetEntry(
    key: 'b',
    source: 'two',
    searchText: 'second',
    folders: {'child'},
    fields: {
      'tags': {'B'},
      'author': {'Y'},
    },
  ),
];

Future<void> _mount(
  WidgetTester tester, {
  required ValueNotifier<String> style,
  required void Function(ShelfFacetSelection?) onResult,
  ShelfFacetSelection initial = const ShelfFacetSelection(),
  List<ShelfFacetEntry>? entries,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool hierarchical = true,
  String? currentFolder,
  ShelfFilterKeyword? keyword,
  bool keywordAsFacet = false,
  bool autoLoadMetadata = false,
  ValueNotifier<ShelfFilterSnapshot>? liveSnapshot,
  VoidCallback? onLoadMetadata,
}) async {
  await tester.pumpWidget(
    AppInterfaceStyleScope(
      style: style,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open filters'),
              onPressed: () async => onResult(
                await showShelfFilterSheet(
                  context,
                  entries: entries ?? _entries(),
                  initial: initial,
                  preferenceKey: 'comic',
                  scopeLabel: '本机收藏',
                  currentFolder: currentFolder,
                  hierarchical: hierarchical,
                  keyword: keyword,
                  keywordAsFacet: keywordAsFacet,
                  focusedLayout: keywordAsFacet,
                  showScopeLabel: keywordAsFacet || autoLoadMetadata,
                  autoLoadMetadata: autoLoadMetadata,
                  loadMetadataLabel: 'Load another page',
                  liveSnapshot: liveSnapshot,
                  onLoadMetadata: onLoadMetadata,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open filters'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('title facet shares the filter panel and keeps one editor', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    const added = ShelfFacetEntry(
      key: 'c',
      source: 'one',
      searchText: 'New work',
      fields: {
        'tags': {'C'},
        'team': {'Team three'},
      },
    );
    final entries = _entries();
    final live = ValueNotifier<ShelfFilterSnapshot>((
      entries: entries,
      scopeLabel: 'Loaded scope',
      loadingMetadata: false,
      canLoadMetadata: true,
    ));
    addTearDown(live.dispose);
    (String, KeywordSearchScope)? applied;
    await _mount(
      tester,
      style: style,
      onResult: (_) {},
      liveSnapshot: live,
      onLoadMetadata: () {
        live.value = (
          entries: [...entries, added],
          scopeLabel: 'Updated loaded scope',
          loadingMetadata: false,
          canLoadMetadata: false,
        );
      },
      keywordAsFacet: true,
      keyword: (
        query: '',
        scope: KeywordSearchScope.title,
        entriesFor: (query, _) => live.value.entries
            .where((entry) => entry.searchText.contains(query))
            .toList(),
        onApply: (query, scope) => applied = (query, scope),
      ),
    );

    final options = find.byKey(const ValueKey('shelf-facet-search'));
    final titleInput = find.byKey(const ValueKey('shelf-filter-work-query'));
    final tags = find.byKey(const ValueKey('shelf-facet-tags'));
    final title = find.byKey(const ValueKey('shelf-facet-title'));
    expect(tester.widget<ChoiceChip>(tags).selected, isTrue);
    expect(find.byKey(const ValueKey('shelf-star-A')), findsOneWidget);
    expect(options, findsOneWidget);
    expect(titleInput, findsNothing);

    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(options, findsNothing);
    expect(titleInput, findsOneWidget);
    expect(find.byType(KeywordScopeMenu), findsNothing);
    await tester.enterText(
      find.descendant(of: titleInput, matching: find.byType(TextField)),
      'first',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load another page'));
    await tester.pumpAndSettle();
    expect(find.text('Updated loaded scope'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(title).selected, isTrue);
    expect(find.text('first'), findsOneWidget);

    await tester.tap(tags);
    await tester.pumpAndSettle();
    expect(options, findsOneWidget);
    expect(titleInput, findsNothing);
    expect(find.byKey(const ValueKey('shelf-facet-team')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
    await tester.pumpAndSettle();
    expect(applied, ('first', KeywordSearchScope.title));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('background pages run singly and stop after three', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    final entries = _entries();
    final live = ValueNotifier<ShelfFilterSnapshot>((
      entries: entries,
      scopeLabel: 'Loaded scope',
      loadingMetadata: false,
      canLoadMetadata: true,
    ));
    addTearDown(live.dispose);
    var loads = 0;
    void publish(bool loading) {
      live.value = (
        entries: entries,
        scopeLabel: loading ? 'Loading scope' : 'Loaded scope',
        loadingMetadata: loading,
        canLoadMetadata: !loading,
      );
    }

    await _mount(
      tester,
      style: style,
      onResult: (_) {},
      liveSnapshot: live,
      autoLoadMetadata: true,
      onLoadMetadata: () {
        expect(live.value.loadingMetadata, isFalse);
        loads++;
        publish(true);
      },
    );

    final loadAction = find.byKey(const ValueKey('shelf-filter-more-metadata'));
    expect(loadAction, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (var page = 1; page <= 3; page++) {
      expect(loads, page);
      expect(find.text('Loading scope'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(loads, page);
      publish(false);
      await tester.pumpAndSettle();
    }
    expect(loads, 3);
    expect(find.text('Loaded scope'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('background pages stay stopped after the sheet closes', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    final entries = _entries();
    final initial = (
      entries: entries,
      scopeLabel: 'Loaded scope',
      loadingMetadata: false,
      canLoadMetadata: true,
    );
    final live = ValueNotifier<ShelfFilterSnapshot>(initial);
    addTearDown(live.dispose);
    var loads = 0;
    await _mount(
      tester,
      style: style,
      onResult: (_) {},
      liveSnapshot: live,
      autoLoadMetadata: true,
      onLoadMetadata: () {
        loads++;
        live.value = (
          entries: entries,
          scopeLabel: 'Loading scope',
          loadingMetadata: true,
          canLoadMetadata: false,
        );
      },
    );
    expect(loads, 1);

    await tester.tap(find.byKey(const ValueKey('shelf-focused-cancel')));
    live.value = initial;
    await tester.pumpAndSettle();
    expect(loads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final completesInSameFrame in [false, true]) {
    testWidgets(
      completesInSameFrame
          ? 'background paging observes loading cycles within one frame'
          : 'background paging stays idle when the callback is a no-op',
      (tester) async {
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        final entries = _entries();
        final idle = (
          entries: entries,
          scopeLabel: 'Loaded scope',
          loadingMetadata: false,
          canLoadMetadata: true,
        );
        final live = ValueNotifier<ShelfFilterSnapshot>(idle);
        addTearDown(live.dispose);
        var loads = 0;
        await _mount(
          tester,
          style: style,
          onResult: (_) {},
          liveSnapshot: live,
          autoLoadMetadata: true,
          onLoadMetadata: () {
            loads++;
            if (completesInSameFrame) {
              live.value = (
                entries: entries,
                scopeLabel: 'Loading scope',
                loadingMetadata: true,
                canLoadMetadata: false,
              );
              live.value = idle;
            }
          },
        );

        final expectedLoads = completesInSameFrame ? 3 : 1;
        expect(loads, expectedLoads);
        live.value = (
          entries: entries,
          scopeLabel: 'Changed scope',
          loadingMetadata: false,
          canLoadMetadata: true,
        );
        await tester.pumpAndSettle();
        expect(loads, expectedLoads);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('shelf filter reopens on its applied facet with outlined chips', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await _mount(
      tester,
      style: style,
      initial: const ShelfFacetSelection(
        values: {
          'author': {'Y'},
        },
      ),
      onResult: (_) {},
    );
    final author = find.byKey(const ValueKey('shelf-facet-author'));
    final applied = find.byKey(const ValueKey('shelf-option-author-Y'));
    final other = find.byKey(const ValueKey('shelf-option-author-X'));
    expect(tester.widget<ChoiceChip>(author).selected, isTrue);
    expect(
      tester.getTopLeft(applied).dy,
      lessThan(tester.getTopLeft(other).dy),
    );
    final side = ChipTheme.of(tester.element(author)).side;
    expect(side, isA<WidgetStateBorderSide>());
    expect(
      (side as WidgetStateBorderSide).resolve({WidgetState.selected})?.style,
      BorderStyle.solid,
    );
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(applied).dy,
      lessThan(tester.getTopLeft(other).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final styleName in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final large in [false, true]) {
        testWidgets(
          'shelf panel $styleName ${brightness.name} content fit and accessible at large=$large',
          (tester) async {
            tester.view.physicalSize = Size(large ? 320 : 390, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final style = ValueNotifier(styleName);
            addTearDown(style.dispose);
            ShelfFacetSelection? result;
            await _mount(
              tester,
              style: style,
              brightness: brightness,
              scale: large ? 2 : 1,
              onResult: (value) => result = value,
            );
            expect(
              find.byKey(const ValueKey('shelf-facet-year')),
              findsNothing,
            );
            expect(
              find.text(t.bookshelf.facets.resultTitle(count: 2)),
              findsOneWidget,
            );
            final footer = find.byKey(const ValueKey('shelf-filter-apply'));
            expect(footer.hitTestable(), findsOneWidget);
            expect(tester.getRect(footer).bottom, lessThanOrEqualTo(740));
            if (!large) {
              final body = tester.getRect(
                find.byKey(const ValueKey('shelf-filter-fields')),
              );
              expect(
                body.height,
                lessThanOrEqualTo(600),
                reason:
                    'The common panel has a stable bounded height, independent of option counts',
              );
            }
            await tester.ensureVisible(
              find.byKey(const ValueKey('shelf-facet-tags')),
            );
            await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const ValueKey('shelf-option-tags-A')),
            );
            await tester.tap(find.byKey(const ValueKey('shelf-option-tags-A')));
            await tester.pumpAndSettle();
            expect(
              find.text(t.bookshelf.facets.resultTitle(count: 1)),
              findsOneWidget,
            );
            expect(footer.hitTestable(), findsOneWidget);
            await tester.tap(footer);
            await tester.pumpAndSettle();
            expect(result?.values['tags'], {'A'});
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'star is an independent 44pt action, survives cancelling draft and keeps zero favorite removable',
    (tester) async {
      await ShelfFacetPreferences.save('comic', {'B'});
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      const original = ShelfFacetSelection(
        values: {
          'author': {'X'},
        },
      );
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        initial: original,
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      final b = tester.widget<TextButton>(
        find.byKey(const ValueKey('shelf-option-tags-B')),
      );
      expect(b.onPressed, isNull);
      final star = find.byKey(const ValueKey('shelf-star-B'));
      expect(tester.getSize(star).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(star).height, greaterThanOrEqualTo(44));
      expect(
        tester.getRect(star).top,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('shelf-star-A'))).top,
        ),
      );
      await tester.tap(star);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(original.values, {
        'author': {'X'},
      });
      expect(await ShelfFacetPreferences.load('comic'), isEmpty);
    },
  );

  testWidgets(
    'reset clears scope and draft only; flat video scope excludes descendants',
    (tester) async {
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      const original = ShelfFacetSelection(
        scope: ShelfFacetScope.all,
        values: {
          'tags': {'A'},
        },
      );
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        initial: original,
        hierarchical: false,
        onResult: (value) => result = value,
      );
      expect(
        find.byKey(const ValueKey('shelf-scope-descendants')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result, const ShelfFacetSelection());
      expect(original.values['tags'], {'A'});
      expect(original.scope, ShelfFacetScope.all);
    },
  );

  testWidgets(
    'comic root maps old descendants to all and a child keeps three scopes',
    (tester) async {
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      const initial = ShelfFacetSelection(scope: ShelfFacetScope.descendants);
      ShelfFacetSelection? result;
      Finder scope(ShelfFacetScope scope) =>
          find.byKey(ValueKey('shelf-scope-${scope.name}'));
      await _mount(
        tester,
        style: style,
        initial: initial,
        currentFolder: '',
        onResult: (value) => result = value,
      );
      expect(scope(ShelfFacetScope.current), findsOneWidget);
      expect(scope(ShelfFacetScope.descendants), findsNothing);
      expect(
        tester.widget<ChoiceChip>(scope(ShelfFacetScope.all)).selected,
        isTrue,
      );
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 2)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result?.scope, ShelfFacetScope.all);
      expect(result?.isActive, isTrue);

      await _mount(
        tester,
        style: style,
        initial: initial,
        currentFolder: 'child',
        onResult: (value) => result = value,
      );
      for (final value in ShelfFacetScope.values) {
        expect(scope(value), findsOneWidget);
      }
      expect(
        tester.widget<ChoiceChip>(scope(ShelfFacetScope.descendants)).selected,
        isTrue,
      );
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 1)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large tag set is searchable within bounded scroll and selected zero can be cleared',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        scale: 1.8,
        initial: const ShelfFacetSelection(
          values: {
            'tags': {'Missing'},
          },
        ),
        entries: [
          for (var i = 0; i < 50; i++)
            ShelfFacetEntry(
              key: '$i',
              source: 'fixture',
              searchText: '',
              fields: {
                'tags': {'Tag$i 很长的标签'},
              },
            ),
        ],
        onResult: (value) => result = value,
      );
      // A single dimension is already active; it no longer needs expanding.
      await tester.enterText(
        find.byKey(const ValueKey('shelf-facet-search')),
        'Missing',
      );
      await tester.pumpAndSettle();
      final missing = find.byKey(const ValueKey('shelf-option-tags-Missing'));
      await tester.ensureVisible(missing);
      await tester.pumpAndSettle();
      expect(
        missing.hitTestable(),
        findsOneWidget,
        reason: 'selected zero-count tag must be reachable after scrolling',
      );
      await tester.tap(missing);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shelf-filter-apply')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result?.isActive, isTrue);
      expect(result?.values.values.every((values) => values.isEmpty), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pinning zero-count tag survives cancellation without selecting it',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      const original = ShelfFacetSelection(
        values: {
          'author': {'X'},
        },
      );
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        initial: original,
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('shelf-option-tags-B')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-star-B')));
      await tester.pumpAndSettle();
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 1)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(original.values, {
        'author': {'X'},
      });
      expect(await ShelfFacetPreferences.load('comic'), {'B'});
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('shelf-star-B'))).top,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('shelf-star-A'))).top,
        ),
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('shelf-option-tags-B')),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'author stars stay separate from tag stars and survive reset and cancel',
    (tester) async {
      await ShelfFacetPreferences.save('comic', {'B'});
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        initial: const ShelfFacetSelection(
          values: {
            'tags': {'A'},
          },
        ),
        onResult: (value) => result = value,
      );
      final authors = find.byKey(const ValueKey('shelf-facet-author'));
      final authorOption = find.byKey(const ValueKey('shelf-option-author-Y'));
      final authorStar = find.byKey(const ValueKey('shelf-star-author-Y'));
      await tester.tap(authors);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(authorOption).onPressed, isNull);
      await tester.tap(authorStar);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(authorOption).onPressed, isNull);
      expect(
        tester.getTopLeft(authorOption).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('shelf-option-author-X')))
              .dy,
        ),
      );
      expect(await ShelfFacetPreferences.load('comic|facet:author'), {'Y'});
      expect(await ShelfFacetPreferences.load('comic'), {'B'});
      await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(authorOption).onPressed, isNotNull);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      await tester.tap(authors);
      await tester.pumpAndSettle();
      await tester.tap(authorStar);
      await tester.pumpAndSettle();
      expect(await ShelfFacetPreferences.load('comic|facet:author'), isEmpty);
      expect(await ShelfFacetPreferences.load('comic'), {'B'});
    },
  );
  testWidgets(
    'flat video root has one all-collection scope without redundant choices',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      ShelfFacetSelection? result;
      await _mount(
        tester,
        style: style,
        hierarchical: false,
        onResult: (value) => result = value,
      );
      expect(
        find.byKey(const ValueKey('shelf-scope-all-label')),
        findsOneWidget,
      );
      expect(find.text(t.bookshelf.facets.allRecords), findsOneWidget);
      for (final scope in ShelfFacetScope.values) {
        expect(find.byKey(ValueKey('shelf-scope-${scope.name}')), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result, const ShelfFacetSelection(applied: true));
      expect(result?.isActive, isTrue);
    },
  );
  testWidgets(
    'open sheet reloads restored stars and star action preserves restored tags and filter draft',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      ShelfFacetSelection? result;
      await _mount(tester, style: style, onResult: (value) => result = value);
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-option-tags-A')));
      await tester.pumpAndSettle();
      // The portable restore writes its validated snapshot, then publishes this
      // event. Full snapshot merge behavior is covered by sync tests.
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'breeze.bookshelf.facet-tags.v1.comic',
        '["B"]',
      );
      PortablePreferences.changes.value++;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shelf-star-B')),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 1)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-star-A')));
      await tester.pumpAndSettle();
      expect(await ShelfFacetPreferences.load('comic'), {'A', 'B'});
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result?.values['tags'], {'A'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'star action reads latest persisted tags before the restore event arrives',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await _mount(tester, style: style, onResult: (_) {});
      await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'breeze.bookshelf.facet-tags.v1.comic',
        '["B"]',
      );
      // A local tap may arrive before the restore's UI notification. It must
      // mutate the persisted set, rather than replace it with the sheet snapshot.
      await tester.tap(find.byKey(const ValueKey('shelf-star-A')));
      await tester.pumpAndSettle();
      expect(await ShelfFacetPreferences.load('comic'), {'A', 'B'});
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
