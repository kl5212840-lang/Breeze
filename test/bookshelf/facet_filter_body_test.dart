import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/facet_filter_body.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

final _entries = [
  for (var i = 0; i < 150; i++)
    ShelfFacetEntry(
      key: '$i',
      source: 'one',
      searchText: '',
      fields: {
        'tags': {'Tag $i'},
        'category': {'Only category'},
        'author': {'Only author'},
      },
    ),
  const ShelfFacetEntry(key: 'missing', source: 'one', searchText: ''),
];

class _ObservedEntries extends ListBase<ShelfFacetEntry> {
  int reads = 0;

  @override
  int get length => _entries.length;

  @override
  set length(int _) => throw UnsupportedError('read-only test snapshot');

  @override
  ShelfFacetEntry operator [](int index) {
    reads++;
    return _entries[index];
  }

  @override
  void operator []=(int index, ShelfFacetEntry value) =>
      throw UnsupportedError('read-only test snapshot');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final styleName in ['system', 'breeze']) {
    for (final branch in ['shelf', 'download']) {
      testWidgets(
        '$styleName $branch facet thumb paints on entry, during scroll and at rest',
        (tester) async {
          tester.view.physicalSize = const Size(390, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final style = ValueNotifier(styleName);
          addTearDown(style.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('open'),
                      onPressed: () {
                        if (branch == 'download') {
                          showDownloadFilterSheet(
                            context,
                            entries: _entries,
                            initial: const ShelfFacetSelection(),
                          );
                        } else {
                          showShelfFilterSheet(
                            context,
                            entries: _entries,
                            initial: const ShelfFacetSelection(),
                            preferenceKey: 'one',
                            scopeLabel: '',
                            currentFolder: null,
                            focusedLayout: false,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          if (branch == 'download') {
            await tester.tap(
              find.byKey(const ValueKey('download-filter-group-tags')),
            );
          } else {
            await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
          }
          await tester.pumpAndSettle();

          final viewport = find.byKey(
            ValueKey(
              branch == 'download'
                  ? 'download-filter-options'
                  : 'shelf-focused-options',
            ),
          );
          final thumb = find.descendant(
            of: viewport,
            matching: find.byKey(const ValueKey('facet-position-thumb')),
          );
          expect(thumb, findsOneWidget);
          final initialThumb = tester.getRect(thumb);
          final thumbColor =
              (tester.widget<Container>(thumb).decoration as BoxDecoration)
                  .color;
          expect(initialThumb.width, 3);
          expect(initialThumb.right, tester.getRect(viewport).right - 12);
          expect(thumb, paints..rrect(color: thumbColor));
          final list = find
              .descendant(of: viewport, matching: find.byType(Scrollable))
              .first;
          final before = tester.state<ScrollableState>(list).position.pixels;
          await tester.drag(list, const Offset(0, -180));
          await tester.pump();
          final after = tester.state<ScrollableState>(list).position.pixels;
          expect(after, greaterThan(before));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 3));
          expect(tester.getRect(thumb).top, greaterThan(initialThumb.top));
          expect(thumb, paints..rrect(color: thumbColor));
          final category = find.byKey(
            ValueKey(
              branch == 'download'
                  ? 'download-filter-group-category'
                  : 'shelf-facet-category',
            ),
          );
          await tester.tap(category);
          await tester.pumpAndSettle();
          expect(
            tester.state<ScrollableState>(list).position.maxScrollExtent,
            0,
          );
          expect(thumb, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(
              ValueKey(
                branch == 'download'
                    ? 'download-filter-cancel'
                    : 'shelf-focused-cancel',
              ),
            ),
          );
          await tester.pumpAndSettle();
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
        }),
      );
    }
  }
  for (final branch in ['ordinary', 'focused', 'download']) {
    testWidgets(
      '$branch keeps panel/search/footer bounds across dimensions and keyboard changes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        ShelfFacetSelection? result;
        final entries = _ObservedEntries();
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('open'),
                    onPressed: () async {
                      result = branch == 'download'
                          ? await showDownloadFilterSheet(
                              context,
                              entries: entries,
                              initial: const ShelfFacetSelection(),
                            )
                          : await showShelfFilterSheet(
                              context,
                              entries: entries,
                              initial: const ShelfFacetSelection(),
                              preferenceKey: 'one',
                              scopeLabel: '',
                              currentFolder: null,
                              focusedLayout: branch == 'focused',
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final body = find.byType(FacetFilterBody);
        final search = find.byKey(
          ValueKey(
            branch == 'download'
                ? 'download-filter-search'
                : 'shelf-facet-search',
          ),
        );
        final apply = find.byKey(
          ValueKey(
            branch == 'download'
                ? 'download-filter-apply'
                : 'shelf-filter-apply',
          ),
        );
        final groups = branch == 'download'
            ? 'download-filter-group-'
            : 'shelf-facet-';
        final rect = tester.getRect(body),
            searchRect = tester.getRect(search),
            applyRect = tester.getRect(apply);
        for (final dimension in ['category', 'author', 'tags']) {
          final choice = find.byKey(ValueKey('$groups$dimension'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(tester.getRect(body), rect);
          expect(tester.getRect(search), searchRect);
          expect(tester.getRect(apply), applyRect);
          expect(search.hitTestable(), findsOneWidget);
          expect(apply.hitTestable(), findsOneWidget);
        }
        expect(
          find.byKey(const ValueKey('shelf-option-tags-__breeze_unknown__')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('download-filter-unknown')),
          findsNothing,
        );
        expect(
          find.byKey(
            ValueKey(
              '${branch == 'download' ? 'download-filter-option-' : 'shelf-option-'}tags-Tag 149',
            ),
          ),
          findsNothing,
          reason: 'The shared options remain lazy.',
        );
        final preview = find.descendant(of: apply, matching: find.byType(Text));
        final beforeSearch = tester.widget<Text>(preview).data;
        entries.reads = 0;
        await tester.enterText(search, 'Tag 1');
        await tester.pumpAndSettle();
        expect(
          entries.reads,
          0,
          reason: 'Option search must not rescan works.',
        );
        expect(tester.widget<Text>(preview).data, beforeSearch);
        final editable = tester.widget<EditableText>(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        final focus = editable.focusNode;
        expect(focus.hasFocus, isTrue);
        // Enter the short-height fallback and back without creating a new field.
        tester.view.viewInsets = const FakeViewPadding(bottom: 480);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: search,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode,
          same(focus),
        );
        expect(focus.hasFocus, isTrue);
        expect(editable.controller.text, 'Tag 1');
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        expect(tester.getRect(search).bottom, lessThanOrEqualTo(370.01));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.getRect(body), rect);
        expect(tester.takeException(), isNull);
        final cancel = find.byKey(
          ValueKey(
            branch == 'download'
                ? 'download-filter-cancel'
                : 'shelf-focused-cancel',
          ),
        );
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'legacy synthetic unknown is removed only from the sheet draft, real same-name tag survives',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final actualValue = shelfFacetEncodeValue(shelfFacetUnknown);
      final original = ShelfFacetSelection(
        values: {
          'tags': {shelfFacetUnknown, actualValue},
        },
      );
      ShelfFacetSelection? result;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    result = await showShelfFilterSheet(
                      context,
                      entries: const [
                        ShelfFacetEntry(
                          key: 'real',
                          source: 'one',
                          searchText: '',
                          fields: {
                            'tags': {shelfFacetUnknown},
                          },
                        ),
                        ShelfFacetEntry(
                          key: 'missing',
                          source: 'one',
                          searchText: '',
                        ),
                      ],
                      initial: original,
                      preferenceKey: 'one',
                      scopeLabel: '',
                      currentFolder: null,
                      focusedLayout: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shelf-option-tags-__breeze_unknown__')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('shelf-option-tags-$actualValue')),
        findsOneWidget,
      );
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 1)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(result?.values['tags'], {actualValue});
      expect(original.values['tags'], {shelfFacetUnknown, actualValue});
      // The legacy matcher stays compatible outside the sheet presentation.
      expect(
        shelfFacetMatches(
          const ShelfFacetEntry(key: 'missing', source: 'one', searchText: ''),
          const ShelfFacetSelection(
            values: {
              'tags': {shelfFacetUnknown},
            },
          ),
          currentFolder: null,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
