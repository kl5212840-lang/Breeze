import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

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
