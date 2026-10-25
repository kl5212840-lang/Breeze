import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';

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
    ValueChanged<VideoSearchFilters?> done,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async => done(
                await Navigator.of(context).push<VideoSearchFilters>(
                  MaterialPageRoute(
                    builder: (_) => const VideoSearchPage(
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

  testWidgets(
    'search is focused once, clears inline and submits author mode with existing filters',
    (tester) async {
      VideoSearchFilters? result;
      await mount(tester, (value) => result = value);
      final input = find.byKey(const ValueKey('video-search.input'));
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byTooltip(t.videoSearch.clearQuery));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == t.videoSearch.submit,
              ),
            )
            .onPressed,
        isNull,
      );
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
    'recent search can be removed or reused; cancel preserves the original request',
    (tester) async {
      await tester.runAsync(() async {
        await VideoSearchHistory.add('one', 'Recent');
        await VideoSearchHistory.add('one', 'Remove me');
      });
      VideoSearchFilters? result;
      await mount(tester, (value) => result = value);
      await tester.tap(find.byTooltip(t.videoSearch.removeRecent).first);
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
