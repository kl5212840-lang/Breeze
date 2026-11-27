import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/view/plugin_comic_grid_sliver.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/search_result/widgets/filtered_result_pages.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/source_page_divider.dart';

import '../test_helper.dart';

UnifiedComicListItem _comic(int index) => UnifiedComicListItem.fromJson({
  'source': 'source-page-fixture',
  'id': 'entry-$index',
  'title': 'Work $index',
  'cover': {'id': 'entry-$index', 'url': '', 'path': '', 'extern': {}},
  'metadata': [],
  'raw': {},
  'extern': {},
});

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('dividers require adjacent known pages in source order', () {
    expect(sourcePageBreaks([1, 1, 3, 4], (page) => page), {2, 3});
    expect(sourcePageBreaks([1, null, 3, 4], (page) => page), {3});
    expect(sourcePageBreaks([1, 3, null, 2, 4], (page) => page), isEmpty);
  });

  testWidgets(
    'an empty filtered list continues on an upward drag after its budget',
    (tester) async {
      final controller = ScrollController();
      final page = ValueNotifier(1);
      final requests = <int>[];
      addTearDown(controller.dispose);
      addTearDown(page.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: page,
              builder: (context, current, _) => FilteredResultPages(
                controller: controller,
                matches: const [],
                page: current,
                ready: true,
                complete: current == 12,
                failed: false,
                paused: false,
                batchSize: 5,
                loadMore: () {
                  requests.add(current + 1);
                  return true;
                },
                builder: (_, progress) => CustomScrollView(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          progress.emptyMessage ??
                              t.searchResult.noMatchingWorks,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (var accepted = 2; accepted <= 10; accepted++) {
        expect(requests.last, accepted);
        page.value = accepted;
        await tester.pump();
      }
      final view = find.byType(CustomScrollView);
      expect(requests.length, 9);
      expect(find.text(t.searchResult.noMatchesYet), findsOneWidget);
      await tester.drag(view, const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(requests.length, 9);
      await tester.drag(view, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(requests.length, 10);
      expect(requests.last, 11);
      page.value = 11;
      await tester.pump();
      expect(requests.last, 12);
      page.value = 12;
      await tester.pumpAndSettle();
      expect(requests.length, 11);
      expect(find.text(t.searchResult.noMatchingWorks), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('list places one decorative divider at each source boundary', (
    tester,
  ) async {
    final comics = [for (var i = 0; i < 3; i++) _comic(i)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceSearchDetailList(
            entries: comics,
            pageBreaks: const {0, 1, 2},
            hasReachedMax: true,
            isLoadingMore: false,
            loadMoreFailed: false,
            onRetryLoadMore: () {},
            onLoadMore: () {},
            entryBuilder: (entry, _) =>
                SizedBox(height: 56, child: Text(entry.title)),
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey(('result-page-divider', 1)));
    final second = find.byKey(const ValueKey(('result-page-divider', 2)));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(
      find.byKey(const ValueKey(('result-page-divider', 0))),
      findsNothing,
    );
    expect(tester.getSize(first).height, 18);
    expect(
      tester
          .widget<Image>(
            find.descendant(of: first, matching: find.byType(Image)),
          )
          .excludeFromSemantics,
      isTrue,
    );
    expect(find.text(t.searchResult.pageOnly(page: 2)), findsNothing);
    expect(
      tester.getBottomLeft(find.text('Work 0')).dy,
      lessThanOrEqualTo(tester.getTopLeft(first).dy),
    );
    expect(
      tester.getBottomLeft(first).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Work 1')).dy),
    );
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiet grid paging preserves density and tappable cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final entries = [
      for (var i = 0; i < 4; i++)
        ComicSimplifyEntryInfo(
          title: 'Work $i',
          id: 'entry-$i',
          fileServer: '',
          path: '',
          pictureType: PictureType.cover,
          from: 'source-page-fixture',
        ),
    ];
    String? opened;
    var retries = 0;
    Future<void> mount({bool quiet = false, bool failed = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: PluginComicGridSliver(
              entries: entries,
              hasReachedMax: false,
              quietPaging: quiet,
              isLoadingMore: false,
              loadMoreFailed: failed,
              onRetryLoadMore: () => retries++,
              onLoadMore: () {},
              onEntryTap: (entry) => opened = entry.id,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await mount();
    expect(find.text(t.oldHome.loadMore), findsOneWidget);
    final cards = find.byType(ComicSimplifyEntry);
    expect(cards, findsNWidgets(4));
    final geometry = [for (var i = 0; i < 4; i++) tester.getRect(cards.at(i))];
    await mount(quiet: true);
    expect(find.text(t.oldHome.loadMore), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(tester.getRect(cards.at(i)), geometry[i]);
    }
    await tester.tap(cards.at(1));
    expect(opened, 'entry-1');
    await mount(quiet: true, failed: true);
    expect(find.text(t.oldHome.loadMore), findsNothing);
    await tester.tap(find.text(t.oldHome.loadMoreFailed));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
