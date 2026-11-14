import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final surfaceChannels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        surfaceChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in surfaceChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    surfaceChannels.clear();
  });
  test(
    'duration and status orders are semantic and never selection-dependent',
    () {
      expect(
        downloadFilterOrderedValues('duration', [
          'hour',
          'short',
          'long',
          'medium',
        ]),
        ['short', 'medium', 'long', 'hour'],
      );
      expect(downloadFilterOrderedValues('tags', ['Z', 'B', 'A']), [
        'A',
        'B',
        'Z',
      ]);
      expect(
        downloadFilterOrderedValues('status', [
          'saved',
          'downloading',
          'queued',
          'failed',
        ]),
        ['queued', 'downloading', 'failed', 'saved'],
      );
    },
  );
  testWidgets(
    'duration is a real stable choice without presenting missing metadata as a category',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadFilterSheet(
              entries: [
                for (final value in ['hour', 'long', 'short', 'medium'])
                  ShelfFacetEntry(
                    key: value,
                    source: 'video',
                    searchText: '',
                    fields: {
                      'duration': {value},
                    },
                  ),
                const ShelfFacetEntry(
                  key: 'old',
                  source: 'video',
                  searchText: '',
                ),
              ],
              initial: const ShelfFacetSelection(
                values: {
                  'duration': {'hour'},
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final short = find.byKey(
        const ValueKey('download-filter-option-duration-short'),
      );
      final hour = find.byKey(
        const ValueKey('download-filter-option-duration-hour'),
      );
      final before = tester.getRect(short);
      expect(before.top, lessThan(tester.getRect(hour).top));
      expect(find.text(t.download.durationShort), findsOneWidget);
      expect(
        find.byKey(const ValueKey('download-filter-unknown')),
        findsNothing,
      );
      await tester.tap(short);
      await tester.pumpAndSettle();
      expect(tester.getRect(short), before);
      expect(tester.getRect(short).top, lessThan(tester.getRect(hour).top));
      expect(
        find.text(t.bookshelf.facets.resultTitle(count: 2)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('all actual dimensions stay on one horizontal navigation row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
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
        home: Scaffold(
          body: DownloadFilterSheet(
            entries: [
              ShelfFacetEntry(
                key: 'a',
                source: 's',
                searchText: '',
                fields: {
                  for (final group in downloadFilterGroups)
                    group: {'Actual value'},
                },
              ),
            ],
            initial: const ShelfFacetSelection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = tester
        .getRect(
          find.byKey(
            ValueKey('download-filter-group-${downloadFilterGroups.first}'),
          ),
        )
        .center
        .dy;
    for (final group in downloadFilterGroups) {
      expect(
        tester
            .getRect(find.byKey(ValueKey('download-filter-group-$group')))
            .center
            .dy,
        closeTo(top, .01),
      );
    }
    expect(tester.takeException(), isNull);
  });
  final platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });
  final entries = List.generate(
    1000,
    (index) => ShelfFacetEntry(
      key: '$index',
      source: index.isEven ? 'comic' : 'video',
      searchText: '',
      fields: {
        'tags': {'Tag ${index.toString().padLeft(4, '0')}'},
        'category': {index.isEven ? 'A' : 'B'},
      },
    ),
  );
  test(
    'raw facets preserve group OR, between-group AND and missing old metadata',
    () {
      const item = ShelfFacetEntry(
        key: '1',
        source: 'video',
        searchText: '',
        fields: {
          'category': {'A'},
          'tags': {'X', shelfFacetUnknown},
        },
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'tags': {'X', 'Y'},
              'category': {'A'},
            },
          ),
        ),
        isTrue,
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'tags': {'X'},
              'category': {'B'},
            },
          ),
        ),
        isFalse,
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'tags': {shelfFacetUnknown},
            },
          ),
        ),
        isTrue,
      );
      expect(
        downloadFacetMatches(
          const ShelfFacetEntry(key: 'old', source: 'video', searchText: ''),
          const ShelfFacetSelection(
            values: {
              'tags': {'X'},
            },
          ),
        ),
        isFalse,
      );
    },
  );
  test(
    'author, version, status and duration combine without fabricating missing data',
    () {
      const item = ShelfFacetEntry(
        key: 'v',
        source: 's',
        searchText: '',
        fields: {
          'author': {'Creator'},
          'quality': {'1080p'},
          'status': {'saved'},
          'duration': {'hour'},
          'tags': {'Drama'},
        },
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'author': {'Creator', 'Other'},
              'quality': {'1080p'},
              'status': {'saved'},
              'duration': {'hour'},
            },
          ),
        ),
        isTrue,
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'author': {'Creator'},
              'status': {'failed'},
            },
          ),
        ),
        isFalse,
      );
      expect(
        downloadFacetMatches(
          item,
          const ShelfFacetSelection(
            values: {
              'language': {'Japanese'},
            },
          ),
        ),
        isFalse,
      );
    },
  );
  for (final size in [
    const Size(320, 800),
    const Size(390, 800),
    const Size(440, 800),
    const Size(700, 320),
  ]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets('lazy searchable draft ${size.width}x${size.height}/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ShelfFacetSelection? result;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    result = await showDownloadFilterSheet(
                      context,
                      entries: entries,
                      initial: const ShelfFacetSelection(),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // The builder must not create a thousand offscreen checkbox widgets.
        expect(
          find.byKey(const ValueKey('download-filter-option-tags-Tag 0999')),
          findsNothing,
        );
        final search = find.byKey(const ValueKey('download-filter-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, '0999');
        await tester.pumpAndSettle();
        final target = find.byKey(
          const ValueKey('download-filter-option-tags-Tag 0999'),
        );
        final viewport = find.byKey(const ValueKey('download-filter-options'));
        final scrollable = find
            .descendant(of: viewport, matching: find.byType(Scrollable))
            .first;
        // Searching leaves one result after the compact scrollable controls.
        // Move the actual vertical viewport, rather than dragging its center
        // (which can be the focused TextField in a short landscape panel).
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        await tester.tap(target);
        await tester.pump();
        expect(result, isNull);
        final apply = find.byKey(const ValueKey('download-filter-apply'));
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        expect(apply.hitTestable(), findsOneWidget);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(result!.values['tags'], {'Tag 0999'});
        expect(tester.takeException(), isNull);
      }, variant: platforms);
    }
  }
  for (final group in downloadFilterGroups) {
    testWidgets('only actual $group group is directly available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadFilterSheet(
              entries: [
                ShelfFacetEntry(
                  key: '1',
                  source: 'source',
                  searchText: '',
                  fields: {
                    group: {'Actual value'},
                  },
                ),
              ],
              initial: const ShelfFacetSelection(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byKey(ValueKey('download-filter-option-$group-Actual value')),
        findsOneWidget,
      );
      expect(find.byType(ShelfTagPinButton).hitTestable(), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('download-filter-option-$group-Actual value')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, variant: platforms);
  }
  testWidgets('tag and author stars persist independently of filter drafts', (
    tester,
  ) async {
    const scope = 'download|all|*';
    SharedPreferences.setMockInitialValues({
      'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(scope)}': '["Zed"]',
    });
    ShelfFacetSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showDownloadFilterSheet(
                  context,
                  entries: [
                    for (final value in ['Alpha', 'Zed'])
                      ShelfFacetEntry(
                        key: value,
                        source: 'fixture',
                        searchText: '',
                        fields: {
                          'tags': {value},
                          'author': {value},
                        },
                      ),
                  ],
                  initial: const ShelfFacetSelection(),
                  preferenceKey: scope,
                );
              },
            ),
          ),
        ),
      ),
    );
    final author = find.byKey(const ValueKey('download-filter-group-author'));
    final tagStar = find.byKey(const ValueKey('download-star-Zed'));
    final authorStar = find.byKey(const ValueKey('download-star-author-Zed'));
    final alpha = find.byKey(
      const ValueKey('download-filter-option-author-Alpha'),
    );
    bool pinned(Finder finder) =>
        tester.widget<ShelfTagPinButton>(finder).pinned;
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(find.text('Open'));
    expect(pinned(tagStar), isTrue);
    await tap(author);
    expect(pinned(authorStar), isFalse);
    expect(
      tester.getTopLeft(alpha).dy,
      lessThan(tester.getTopLeft(authorStar).dy),
    );
    await tap(authorStar);
    expect(pinned(authorStar), isTrue);
    expect(
      tester.getTopLeft(authorStar).dy,
      lessThan(tester.getTopLeft(alpha).dy),
    );
    await tap(find.byKey(const ValueKey('download-filter-cancel')));
    expect(result, isNull);
    await tap(find.text('Open'));
    expect(pinned(tagStar), isTrue);
    await tap(author);
    expect(pinned(authorStar), isTrue);
    await tap(find.byKey(const ValueKey('download-filter-reset')));
    expect(pinned(authorStar), isTrue);
    await tap(find.byKey(const ValueKey('download-filter-apply')));
    expect(result!.applied, isTrue);
    expect(result!.values, isEmpty);
    await tap(find.text('Open'));
    await tap(author);
    await tap(authorStar);
    expect(pinned(authorStar), isFalse);
    expect(
      tester.getTopLeft(alpha).dy,
      lessThan(tester.getTopLeft(authorStar).dy),
    );
    await tap(find.byKey(const ValueKey('download-filter-group-tags')));
    expect(pinned(tagStar), isTrue);
  }, variant: platforms);
  testWidgets(
    'long tags remain reachable with narrow screen, large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      const label =
          '很长的真实标签 Long tag without truncating metadata repeated repeated';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDownloadFilterSheet(
                  context,
                  entries: const [
                    ShelfFacetEntry(
                      key: '1',
                      source: 'video',
                      searchText: '',
                      fields: {
                        'tags': {label},
                      },
                    ),
                  ],
                  initial: const ShelfFacetSelection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('download-filter-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Long tag');
      await tester.pumpAndSettle();
      final option = find.byKey(
        const ValueKey('download-filter-option-tags-$label'),
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      // At 2x a full, untruncated label may be taller than the keyboard's
      // remaining viewport. Select its genuinely visible 44pt region.
      final options = find.byKey(const ValueKey('download-filter-options'));
      final visibleOption = tester
          .getRect(option)
          .intersect(tester.getRect(options));
      expect(visibleOption.width, greaterThanOrEqualTo(44));
      expect(visibleOption.height, greaterThanOrEqualTo(44));
      await tester.tapAt(visibleOption.center);
      await tester.pump();
      expect(
        find.descendant(
          of: option,
          matching: find.byIcon(Icons.check_box_outlined),
        ),
        findsOneWidget,
      );
      // In the short-height fallback the footer is below this full label.
      // Include the unpainted sliver to reveal it, then require a real hit.
      final apply = find.byKey(
        const ValueKey('download-filter-apply'),
        skipOffstage: false,
      );
      await tester.ensureVisible(apply);
      await tester.pumpAndSettle();
      expect(apply.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );
  testWidgets(
    'cancel and reset remain draft; vanished selected value is removable at zero',
    (tester) async {
      const initial = ShelfFacetSelection(
        values: {
          'tags': {'Vanished long tag 很长的已选标签'},
        },
      );
      ShelfFacetSelection? result;
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showDownloadFilterSheet(
                    context,
                    entries: const [],
                    initial: initial,
                  );
                  returned = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final option = find.byKey(
        const ValueKey('download-filter-option-tags-Vanished long tag 很长的已选标签'),
      );
      expect(tester.widget<TextButton>(option).onPressed, isNotNull);
      await tester.tap(option);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('download-filter-reset')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('download-filter-cancel')));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
      expect(initial.values['tags'], {'Vanished long tag 很长的已选标签'});
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );
}
