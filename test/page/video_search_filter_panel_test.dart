import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:zephyr/widgets/year_filter_picker.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filter_panel.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

const schema = VideoFilterSchema(
  options: {
    'genre': [
      VideoFilterChoice(value: '', label: 'All'),
      VideoFilterChoice(value: '3DCG', label: '3DCG'),
    ],
    'sort': [
      VideoFilterChoice(value: '', label: 'Default'),
      VideoFilterChoice(value: 'views', label: 'Views'),
    ],
    'date': [
      VideoFilterChoice(value: '', label: 'All dates'),
      VideoFilterChoice(value: 'past', label: 'Past day'),
    ],
    'duration': [
      VideoFilterChoice(value: '', label: 'All lengths'),
      VideoFilterChoice(value: 'short', label: 'Short'),
    ],
  },
  tagGroups: {
    'Attributes': [
      VideoFilterChoice(value: '1080p', label: 'HD'),
      VideoFilterChoice(value: '60FPS', label: 'Smooth'),
    ],
  },
  customDate: true,
);
Future<VideoSiteResult<VideoFilterSchema>> read() async =>
    (status: VideoSiteStatus.ok, value: schema, writeUnconfirmed: false);
void main() {
  testWidgets(
    'fixed controls omit stars while tag favorites survive draft cancel',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final results = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const source = 'hanime-fixture';
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () async => results.add(
                        await showVideoTaskSheet<Object>(
                          context: context,
                          builder: (_) => const VideoQuickFilterPanel(
                            source: source,
                            section: VideoFilterSection.genre,
                            initial: VideoSearchFilters(),
                            schema: schema,
                          ),
                        ),
                      ),
                      child: const Text('Quick'),
                    ),
                    TextButton(
                      onPressed: () async => results.add(
                        await showVideoTaskSheet<Object>(
                          context: context,
                          builder: (_) => const VideoSearchFilterPanel(
                            source: source,
                            initial: VideoSearchFilters(),
                            schema: schema,
                            readSchema: read,
                          ),
                        ),
                      ),
                      child: const Text('Detailed'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      final fixedStar = find.byKey(
        const ValueKey('filter-favorite-genre-3DCG'),
      );
      await tap(find.text('Quick'));
      expect(fixedStar, findsNothing);
      expect(results, isEmpty);
      await tap(find.byTooltip(t.common.close));
      await tap(find.text('Detailed'));
      expect(fixedStar, findsNothing);
      await tap(find.widgetWithText(Tab, t.videoFilters.tags));
      final star = find.byKey(const ValueKey('filter-favorite-tags-1080p'));
      await tester.ensureVisible(star);
      await tap(star);
      expect(
        find.descendant(of: star, matching: find.byIcon(Icons.star_rounded)),
        findsOneWidget,
      );
      expect(results, [null]);
      await tap(find.byTooltip(t.common.cancel));
      expect(results, [null, null]);
      expect(
        await ShelfFacetPreferences.load(
          'source-filter|hanime-fixture|hanime-video|facet:tags',
        ),
        contains('1080p'),
      );
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final section in [
        VideoFilterSection.genre,
        VideoFilterSection.tags,
        VideoFilterSection.query,
        VideoFilterSection.date,
      ]) {
        testWidgets(
          'iOS actual sheet $style $brightness opens $section without provider errors',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              (_) async => null,
            );
            addTearDown(
              () => messenger.setMockMethodCallHandler(
                SystemChannels.platform_views,
                null,
              ),
            );
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        child: const Text('Open real sheet'),
                        onPressed: () => showVideoTaskSheet<VideoSearchFilters>(
                          context: context,
                          builder: (_) => VideoSearchFilterPanel(
                            initial: const VideoSearchFilters(),
                            schema: schema,
                            readSchema: read,
                            initialSection: section,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open real sheet'));
            await tester.pumpAndSettle();
            final contentMaterial = tester.widget<NativeMaterialSurface>(
              find.byKey(const ValueKey('video-filter.readable-content')),
            );
            expect(contentMaterial.readableContent, isTrue);
            expect(contentMaterial.radius, 0);

            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('video-filter.panel')),
              findsOneWidget,
            );
            if (section == VideoFilterSection.genre) {
              final option = find.byKey(
                const ValueKey('video-filter.genre.3DCG'),
              );
              final frame = tester.getRect(option);
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: option, matching: find.text('3DCG')),
              );
              final boxes = paragraph.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 4),
              );
              final glyphs = boxes
                  .map(
                    (box) => Rect.fromPoints(
                      paragraph.localToGlobal(Offset(box.left, box.top)),
                      paragraph.localToGlobal(Offset(box.right, box.bottom)),
                    ),
                  )
                  .reduce((a, b) => a.expandToInclude(b));
              expect(
                (glyphs.center.dx - frame.center.dx).abs(),
                lessThanOrEqualTo(1),
              );
            }
            if (section == VideoFilterSection.date) {
              expect(find.widgetWithText(ChoiceChip, 'Past day'), findsNothing);
              expect(
                find.byKey(const ValueKey('video-filter.date.options')),
                findsNothing,
              );
              await _compactPick(tester, 'video-filter.date', 'past');
              expect(
                find.byKey(const ValueKey('video-filter.date.options')),
                findsNothing,
              );
              expect(
                find.descendant(
                  of: find.byKey(const ValueKey('video-filter.date.trigger')),
                  matching: find.text('Past day'),
                ),
                findsOneWidget,
              );
            }
            await tester.tap(find.byTooltip(t.common.cancel));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('video-filter.panel')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Hanime declared year wheel applies actual date $style ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            (_) async => null,
          );
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            ),
          );
          final actual = schema.copyWith(years: ['2026', '2025', '2024']);
          VideoSearchFilters? applied;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.7)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Open year sheet'),
                      onPressed: () async {
                        applied = await showVideoTaskSheet<VideoSearchFilters>(
                          context: context,
                          builder: (_) => VideoSearchFilterPanel(
                            initial: const VideoSearchFilters(date: '2026 年'),
                            schema: actual,
                            readSchema: read,
                            initialSection: VideoFilterSection.date,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open year sheet'));
          await tester.pumpAndSettle();
          final wheel = find.byKey(const ValueKey('video-filter.year.wheel'));
          await tester.ensureVisible(wheel);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('video-filter.custom-year')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('video-filter.year.item.2025')),
          );
          await tester.pumpAndSettle();
          expect(applied, isNull);
          expect(
            tester
                .widget<YearFilterPicker>(find.byType(YearFilterPicker))
                .selected,
            '2025',
          );
          final selected = tester.widget<CupertinoPicker>(
            find.descendant(of: wheel, matching: find.byType(CupertinoPicker)),
          );
          expect(selected.scrollController!.selectedItem, 2);
          await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
          await tester.pumpAndSettle();
          expect(applied?.date, '2025 年');
          expect(
            applied
                ?.toUri(Uri.parse('https://hanime1.me/'))
                .queryParameters['date'],
            '2025 年',
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets('short tag groups use compact rows and a content-sized sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.bottomCenter,
          child: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(),
            schema: VideoFilterSchema(
              tagGroups: {
                'Group': [
                  for (var i = 0; i < 9; i++)
                    VideoFilterChoice(value: '$i', label: 'HD $i'),
                ],
              },
            ),
            readSchema: read,
            initialSection: VideoFilterSection.tags,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('video-filter.panel'))).height,
      lessThan(600),
    );
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent)
          .mainAxisExtent,
      lessThanOrEqualTo(48),
    );
    expect(find.widgetWithText(FilterChip, 'HD 8'), findsOneWidget);
    final lastTag = tester.getRect(find.widgetWithText(FilterChip, 'HD 8'));
    final gridBounds = tester.getRect(find.byType(GridView));
    expect(lastTag.bottom, lessThanOrEqualTo(gridBounds.bottom));
    expect(
      gridBounds.bottom - lastTag.bottom,
      lessThan(48),
      reason: 'Small tag groups should not leave a large empty grid area',
    );
    await tester.tap(find.widgetWithText(FilterChip, 'HD 8'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<void> mount(
    WidgetTester tester, {
    required ValueChanged<VideoSearchFilters?> result,
    VideoSearchFilters initial = const VideoSearchFilters(),
    VideoFilterSection section = VideoFilterSection.tags,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result(
                  await Navigator.of(context).push<VideoSearchFilters>(
                    MaterialPageRoute(
                      builder: (_) => VideoSearchFilterPanel(
                        initial: initial,
                        schema: schema,
                        readSchema: read,
                        initialSection: section,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'draft tag and sort changes apply together while preserving all other conditions',
    (tester) async {
      const initial = VideoSearchFilters(
        query: 'Series',
        genre: '3DCG',
        date: 'past',
        duration: 'short',
        tags: ['1080p'],
        page: 4,
      );
      VideoSearchFilters? result;
      await mount(tester, initial: initial, result: (value) => result = value);
      await tester.tap(find.widgetWithText(FilterChip, 'Smooth'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ChoiceChip, t.videoFilters.anyMatch),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-filter.sort.views')));
      await tester.pump();
      expect(result, isNull);
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await tester.pumpAndSettle();
      expect(
        result,
        initial.copyWith(
          sort: 'views',
          tags: ['1080p', '60FPS'],
          anyTag: true,
          page: 1,
        ),
      );
      expect(initial.tags, ['1080p']);
    },
  );
  testWidgets(
    'cancel discards the draft; clearing filters preserves query and author mode',
    (tester) async {
      const initial = VideoSearchFilters(
        query: 'Series',
        genre: '3DCG',
        tags: ['1080p'],
        anyTag: true,
        author: true,
        page: 3,
      );
      VideoSearchFilters? result = initial;
      await mount(tester, initial: initial, result: (value) => result = value);
      await tester.tap(find.widgetWithText(FilterChip, 'Smooth'));
      await tester.pump();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-filter.reset')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await tester.pumpAndSettle();
      expect(result, const VideoSearchFilters(query: 'Series', author: true));
    },
  );
  testWidgets(
    'custom dates validate the year and encode the site year/month value',
    (tester) async {
      VideoSearchFilters? result;
      await mount(
        tester,
        section: VideoFilterSection.date,
        result: (value) => result = value,
      );
      await _compactPick(tester, 'video-filter.date', '__breeze_custom_date__');
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.custom-year')),
        '20',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.custom-year')),
        '2026',
      );
      await tester.pump();
      await _compactPick(tester, 'video-filter.month', '10');
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await tester.pumpAndSettle();
      expect(result!.date, '2026 年 10 月');
    },
  );
  testWidgets(
    'compact date and month stay inside a narrow large-text sheet and cancel draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      VideoSearchFilters? result;
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.7)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showVideoTaskSheet<VideoSearchFilters>(
                        context: context,
                        builder: (_) => VideoSearchFilterPanel(
                          initial: const VideoSearchFilters(date: 'past'),
                          schema: schema,
                          readSchema: read,
                          initialSection: VideoFilterSection.date,
                        ),
                      ),
                  child: const Text('Open date sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open date sheet'));
      await tester.pumpAndSettle();
      await _compactPick(tester, 'video-filter.date', '__breeze_custom_date__');
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.custom-year')),
        '2026',
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ChoiceChip, t.videoFilters.month(value: 1)),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('video-filter.month.trigger')),
      );
      await tester.tap(
        find.byKey(const ValueKey('video-filter.month.trigger')),
      );
      await tester.pumpAndSettle();
      final options = find.byKey(const ValueKey('video-filter.month.options'));
      expect(tester.getRect(options).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(options).right, lessThanOrEqualTo(320));
      expect(tester.getSize(options).height, lessThanOrEqualTo(280));
      _expectDateChoiceGeometry(
        tester,
        find.byKey(const ValueKey('video-filter.month.trigger')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.month.search')),
        '10',
      );
      await tester.pumpAndSettle();
      _expectDateChoiceGeometry(
        tester,
        find.byKey(const ValueKey('video-filter.month.10')),
      );
      expect(tester.takeException(), isNull);
      await _compactPick(tester, 'video-filter.month', '10');
      expect(result, isNull);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open date sheet'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('video-filter.custom-year')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('video-filter.date.trigger')),
          matching: find.text('Past day'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date choice does not invent custom year support', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(date: '2026 年'),
            schema: VideoFilterSchema(
              options: {'date': schema.options['date']!},
            ),
            readSchema: read,
            initialSection: VideoFilterSection.date,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('video-filter.custom-year')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('video-filter.month.trigger')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('video-filter.date.trigger')),
        matching: find.text('2026 年'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('video-filter.date.trigger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('video-filter.date.__breeze_custom_date__')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing a focused tag draft hides the keyboard and applies only explicitly',
    (tester) async {
      VideoSearchFilters? result;
      await mount(
        tester,
        initial: const VideoSearchFilters(tags: ['1080p']),
        result: (value) => result = value,
      );
      final search = find.byKey(const ValueKey('video-filter.tag-search'));
      await tester.enterText(search, 'Smooth');
      await tester.tap(find.widgetWithText(FilterChip, 'Smooth'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Smooth'))
            .selected,
        isFalse,
      );
      await tester.enterText(search, 'Smooth');
      await tester.tap(find.widgetWithText(FilterChip, 'Smooth'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await tester.pumpAndSettle();
      expect(result!.tags, ['1080p', '60FPS']);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );
  testWidgets(
    'small screen and large text preserve clear/apply and selected tags',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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
          home: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(tags: ['1080p']),
            schema: schema,
            readSchema: read,
            initialSection: VideoFilterSection.tags,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('video-filter.apply')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('video-filter.reset')).hitTestable(),
        findsOneWidget,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('video-filter.apply')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('video-filter.reset')).hitTestable(),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'task sheet keeps input, close and apply above a small-screen keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open sheet'),
                onPressed: () => showVideoTaskSheet(
                  context: context,
                  builder: (_) => VideoSearchFilterPanel(
                    initial: const VideoSearchFilters(tags: ['1080p']),
                    schema: schema,
                    readSchema: read,
                    initialSection: VideoFilterSection.tags,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.tag-search')),
        'HD',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final apply = find.byKey(const ValueKey('video-filter.apply'));
      expect(apply.hitTestable(), findsOneWidget);
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(228 + 1e-6));
      expect(
        find.byTooltip(t.videoFilters.closeKeyboard).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byTooltip(t.videoFilters.allFilters).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large tag sets build visible choices and search across groups without losing selections',
    (tester) async {
      final large = VideoFilterSchema(
        tagGroups: {
          for (var group = 0; group < 8; group++)
            'Group $group': [
              for (var i = 0; i < 400; i++)
                VideoFilterChoice(value: '$group-$i', label: 'Tag $group-$i'),
            ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(tags: ['0-0', '7-399']),
            schema: large,
            readSchema: read,
            initialSection: VideoFilterSection.tags,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip).evaluate().length, lessThan(70));
      await tester.enterText(
        find.byKey(const ValueKey('video-filter.tag-search')),
        'Tag 7-399',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Tag 7-399'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tag 7-399'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip(t.common.clear).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-filter.selected')));
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNWidgets(2));
      await tester.tap(find.widgetWithText(FilterChip, 'Tag 7-399'));
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsOneWidget);
    },
  );

  testWidgets(
    'full reset stays explicit and reduce-motion choices do not animate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(query: 'Series', tags: ['1080p']),
            schema: schema,
            readSchema: read,
            initialSection: VideoFilterSection.tags,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);
      expect(chip.chipAnimationStyle!.selectAnimation!.duration, Duration.zero);
      await tester.tap(find.byTooltip(t.videoFilters.clearAll));
      await tester.pump();
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip).first).selected,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reduce-motion tab changes finish immediately and retain the filter draft',
    (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: reduced,
          builder: (_, value, _) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: child!,
            ),
            home: VideoSearchFilterPanel(
              initial: const VideoSearchFilters(tags: ['1080p']),
              schema: schema,
              readSchema: read,
              initialSection: VideoFilterSection.tags,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Smooth'));
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.sort));
      await tester.pump(const Duration(milliseconds: 20));
      reduced.value = true;
      await tester.pump();
      var tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabs.animationDuration, Duration.zero);
      expect(tabs.index, VideoFilterSection.sort.index);
      expect(tabs.indexIsChanging, isFalse);
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.tags));
      await tester.pump();
      expect(tabs.animation!.value, VideoFilterSection.tags.index);
      expect(tabs.indexIsChanging, isFalse);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Smooth'))
            .selected,
        isTrue,
      );
      reduced.value = false;
      await tester.pump();
      tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabs.animationDuration, const Duration(milliseconds: 160));
      expect(tabs.index, VideoFilterSection.tags.index);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'replacing the tab controller keeps one tag reader and ignores its closed result',
    (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      final pending = Completer<VideoSiteResult<VideoFilterSchema>>();
      var reads = 0, cancelled = 0, published = 0;
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: reduced,
          builder: (_, value, _) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => VideoSearchFilterPanel(
                        initial: const VideoSearchFilters(),
                        schema: const VideoFilterSchema(),
                        readSchema: () {
                          reads++;
                          return pending.future;
                        },
                        onCancelRead: () => cancelled++,
                        onSchema: (_) => published++,
                      ),
                    ),
                  ),
                  child: const Text('Open lazy filters'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open lazy filters'));
      await tester.pumpAndSettle();
      reduced.value = true;
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.tags));
      await tester.pump();
      expect(reads, 1);
      reduced.value = false;
      await tester.pump();
      expect(reads, 1);
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
      pending.complete((
        status: VideoSiteStatus.ok,
        value: schema,
        writeUnconfirmed: false,
      ));
      await tester.pump();
      expect(published, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'selected wrapped tag labels keep their final characters inside the chip',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: VideoSearchFilterPanel(
            initial: const VideoSearchFilters(tags: ['one']),
            schema: const VideoFilterSchema(
              tagGroups: {
                'Group': [VideoFilterChoice(value: 'one', label: 'Word 20')],
              },
            ),
            readSchema: read,
            initialSection: VideoFilterSection.tags,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = tester.renderObject<RenderParagraph>(find.text('Word 20'));
      final boxes = label.getBoxesForSelection(
        const TextSelection(baseOffset: 6, extentOffset: 7),
      );
      expect(boxes, isNotEmpty);
      expect(boxes.last.bottom, lessThanOrEqualTo(label.size.height + 1));
    },
  );
}

Future<void> _compactPick(
  WidgetTester tester,
  String prefix,
  String value,
) async {
  Finder key(String suffix) => find.byKey(ValueKey('$prefix.$suffix'));
  if (key('options').evaluate().isEmpty) {
    await tester.ensureVisible(key('trigger'));
    await tester.tap(key('trigger'));
    await tester.pumpAndSettle();
  }
  // Search makes even an option outside the lazy list viewport reachable.
  final query = value == '__breeze_custom_date__'
      ? t.videoFilters.yearMonth
      : value == 'past'
      ? 'Past day'
      : value;
  await tester.enterText(key('search'), query);
  await tester.pumpAndSettle();
  await tester.ensureVisible(key(value.isEmpty ? 'all' : value));
  await tester.tap(key(value.isEmpty ? 'all' : value));
  await tester.pumpAndSettle();
}

void _expectDateChoiceGeometry(WidgetTester tester, Finder button) {
  final bounds = tester.getRect(button);
  expect(bounds.height, greaterThanOrEqualTo(44));
  for (final content in [
    find.descendant(of: button, matching: find.byType(Row)),
    find.descendant(of: button, matching: find.byType(Text)),
  ]) {
    for (final element in content.evaluate()) {
      final rect = tester.getRect(
        find.byElementPredicate((candidate) => candidate == element),
      );
      expect(rect.left, greaterThanOrEqualTo(bounds.left + 10));
      expect(rect.right, lessThanOrEqualTo(bounds.right - 10));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
    }
  }
}
