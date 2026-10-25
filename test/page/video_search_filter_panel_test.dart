import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filter_panel.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_interaction.dart';

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
      await tester.tap(find.widgetWithText(ChoiceChip, 'Views'));
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
      await tester.tap(find.text(t.videoFilters.yearMonth));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '20');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '2026');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, t.videoFilters.month(value: 10)),
      );
      await tester.tap(
        find.widgetWithText(ChoiceChip, t.videoFilters.month(value: 10)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await tester.pumpAndSettle();
      expect(result!.date, '2026 年 10 月');
    },
  );
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
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(228));
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
