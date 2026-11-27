import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'recent words are bounded, deduplicated, source-local and serialized',
    () async {
      await Future.wait([
        for (var i = 0; i < 20; i++) VideoSearchHistory.add('one', 'Word $i'),
      ]);
      await VideoSearchHistory.add('two', 'Separate');
      await VideoSearchHistory.add('one', 'Word 12');
      var words = await VideoSearchHistory.read('one');
      expect(words.length, VideoSearchHistory.limit);
      expect(words.first, 'Word 12');
      expect(words.toSet().length, words.length);
      await VideoSearchHistory.remove('one', 'Word 12');
      expect(await VideoSearchHistory.read('one'), isNot(contains('Word 12')));
      await VideoSearchHistory.clear('one');
      expect(await VideoSearchHistory.read('one'), isEmpty);
      expect(await VideoSearchHistory.read('two'), ['Separate']);
      expect(VideoSearchHistory.clean('\n  a\u0000b  '), 'ab');
    },
  );

  Future<void> mount(
    WidgetTester tester,
    ValueChanged<VideoSearchFilters?> done, {
    VideoSearchPage? page,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async => done(
                await Navigator.of(context).push<VideoSearchFilters>(
                  MaterialPageRoute(
                    builder: (_) =>
                        page ??
                        const VideoSearchPage(
                          source: 'one',
                          initial: VideoSearchFilters(
                            query: 'Old',
                            sort: 'views',
                            tags: ['HD'],
                            page: 5,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a known recent word keeps its explicit video scope', (
    tester,
  ) async {
    await VideoSearchHistory.add(
      'one',
      'Known word',
      scope: KeywordSearchScope.title,
    );
    KeywordSearchScope? scope;
    VideoSearchFilters? result;
    await mount(
      tester,
      (value) => result = value,
      page: VideoSearchPage(
        source: 'one',
        initial: const VideoSearchFilters(),
        authorEnabled: false,
        showScopeSelection: false,
        onSubmitScope: (value) => scope = value,
      ),
    );
    expect(find.byType(KeywordScopeMenu), findsNothing);
    await tester.tap(find.text('Known word'));
    await tester.pumpAndSettle();
    expect(result?.query, 'Known word');
    expect(scope, KeywordSearchScope.title);
  });

  testWidgets(
    'search is focused once, clears inline and submits author mode with existing filters',
    (tester) async {
      VideoSearchFilters? result;
      await mount(tester, (value) => result = value);
      final input = find.byKey(const ValueKey('video-search.input'));
      final submit = find.byType(SearchFieldSubmitButton);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(
        find.descendant(of: input, matching: find.byIcon(Icons.search_rounded)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(t.videoSearch.clearQuery));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      final submitButton = find.descendant(
        of: submit,
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(submitButton).onPressed, isNull);
      await tester.enterText(input, 'Creator');
      await tester.tap(find.widgetWithText(ChoiceChip, t.videoFilters.authors));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        result,
        const VideoSearchFilters(
          query: 'Creator',
          author: true,
          sort: 'views',
          tags: ['HD'],
        ),
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        await tester.runAsync(() => VideoSearchHistory.read('one')),
        isEmpty,
        reason: 'only the catalog confirms a submitted search for history',
      );
    },
  );

  testWidgets(
    'dedicated search keeps stable back, input and submit slots with the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: VideoSearchPage(
            source: 'one',
            initial: const VideoSearchFilters(query: 'Series'),
            filterBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      final field = find.byType(SearchFieldSurface);
      final filterRow = find.byKey(const ValueKey('video-search.filters-row'));
      final filter = find.byKey(const ValueKey('video-search.filters'));
      final initialBar = tester.getRect(appBar);
      final initialField = tester.getRect(field);
      final initialRow = tester.getRect(filterRow);
      final back = tester.getRect(find.byTooltip(t.videoSearch.cancel));
      final submit = tester.getRect(find.byType(SearchFieldSubmitButton));
      expect(back.left, closeTo(initialBar.left + 16, .5));
      expect(initialField.left - back.right, greaterThanOrEqualTo(8));
      expect(submit.left, closeTo(initialField.left, .5));
      expect(submit.right, lessThan(initialField.right));
      expect(submit.width, greaterThanOrEqualTo(44));
      expect(initialBar.right - initialField.right, closeTo(16, .5));
      expect(initialField.width, greaterThan(150));
      expect(back.center.dy, closeTo(initialField.center.dy, .5));
      expect(submit.center.dy, closeTo(initialField.center.dy, .5));
      expect(tester.getRect(filter).right, closeTo(initialBar.right - 16, .5));
      expect(tester.getSize(filter).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
      expect(find.byTooltip(t.videoSearch.clearQuery), findsOneWidget);
      expect(find.byTooltip(t.videoSearch.cancel), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(tester.getRect(appBar), initialBar);
      expect(tester.getRect(field), initialField);
      expect(tester.getRect(filterRow), initialRow);

      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
      expect(tester.getRect(appBar), initialBar);
      expect(tester.getRect(field), initialField);
      expect(tester.getRect(filterRow), initialRow);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'recent search can be removed or reused; cancel preserves the original request',
    (tester) async {
      await tester.runAsync(() async {
        await VideoSearchHistory.add('one', 'Recent');
        await VideoSearchHistory.add('one', 'Remove me');
      });
      VideoSearchFilters? result;
      await mount(tester, (value) => result = value);
      final historyRow = find.byKey(
        const ValueKey('search-history.word.Remove me'),
      );
      final historyStart = tester.getTopLeft(historyRow);
      expect(find.byTooltip(t.videoSearch.removeRecent), findsNothing);
      expect(find.byTooltip(t.search.clearHistory), findsNothing);
      await tester.tap(find.byKey(const ValueKey('search-history.manage')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(historyRow), historyStart);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(historyRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.bookshelf.deleteSelected));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => VideoSearchHistory.read('one')), [
        'Remove me',
        'Recent',
      ]);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.bookshelf.deleteSelected));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, t.common.delete));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => VideoSearchHistory.read('one')), [
        'Recent',
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('video-search.input')),
        'Unsubmitted draft',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, t.videoFilters.authors));
      await tester.tap(find.byTooltip(t.videoSearch.cancel));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('video-search.input')))
            .controller!
            .text,
        'Old',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, t.videoFilters.videos),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(result!.query, 'Recent');
      expect(result!.sort, 'views');
      expect(result!.tags, ['HD']);
    },
  );
}
