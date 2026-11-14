import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/search_history_entries.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/page/search/widget/search_history_section.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';

import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'history wraps to three rows and expands without changing actions',
    (tester) async {
      final words = List.generate(18, (index) => 'query $index');
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 340,
                child: SearchHistorySection(
                  compact: true,
                  words: words,
                  scopeLabel: 'source',
                  onSubmit: submitted.add,
                  onRemove: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      Finder chip(String word) =>
          find.byKey(ValueKey('search-history.word.$word'));
      final visible = words
          .where((word) => chip(word).evaluate().isNotEmpty)
          .toList();
      final rows = visible
          .map((word) => tester.getTopLeft(chip(word)).dy)
          .toSet();
      expect(rows.length, 3);
      expect(visible.length, lessThan(words.length));
      expect(
        tester.getTopLeft(chip(visible[0])).dy,
        tester.getTopLeft(chip(visible[1])).dy,
      );
      expect(
        tester.getTopLeft(chip(visible[1])).dx -
            tester.getTopRight(chip(visible[0])).dx,
        8,
      );
      await tester.tap(chip(words.first));
      await tester.pump();
      expect(submitted, [words.first]);
      await tester.tap(find.byKey(const ValueKey('search-history.expand')));
      await tester.pumpAndSettle();
      expect(chip(words.last), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('search-history.expand')),
      );
      await tester.tap(find.byKey(const ValueKey('search-history.expand')));
      await tester.pumpAndSettle();
      expect(chip(words.last), findsNothing);
      expect(submitted, [words.first]);
    },
  );

  test(
    'source history never guesses legacy scope and deletes only exact scope',
    () {
      var history = ['旧的无来源搜索'];
      history = SearchHistoryEntries.add(history, '同名搜索', scope: 'a');
      history = SearchHistoryEntries.add(history, '同名搜索', scope: 'b');
      history = SearchHistoryEntries.add(history, '综合搜索', scope: '');
      expect(SearchHistoryEntries.words(history, scope: 'a'), ['同名搜索']);
      expect(SearchHistoryEntries.words(history, scope: 'b'), ['同名搜索']);
      expect(SearchHistoryEntries.words(history, scope: ''), [
        '综合搜索',
        '旧的无来源搜索',
      ]);
      history = SearchHistoryEntries.remove(history, {'同名搜索'}, scope: 'a');
      expect(SearchHistoryEntries.words(history, scope: 'a'), isEmpty);
      expect(SearchHistoryEntries.words(history, scope: 'b'), ['同名搜索']);
      expect(SearchHistoryEntries.words(history, scope: ''), [
        '综合搜索',
        '旧的无来源搜索',
      ]);
    },
  );

  testWidgets('short history words stay compact with full touch targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: SearchHistorySection(
                words: const ['one', 'two', 'six'],
                scopeLabel: 'scope',
                onSubmit: (_) {},
                onRemove: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    Rect chip(String word) =>
        tester.getRect(find.byKey(ValueKey('search-history.word.$word')));
    expect(chip('one').top, chip('six').top);
    expect(chip('one').height, greaterThanOrEqualTo(44));
    expect(chip('one').width, greaterThanOrEqualTo(44));
    expect(find.byTooltip(t.videoSearch.removeRecent), findsNothing);
  });

  testWidgets(
    'management keeps history row positions and text alignment stable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchHistorySection(
              words: const ['first', 'second'],
              scopeLabel: 'scope',
              onSubmit: (_) {},
              onRemove: (_) async {},
            ),
          ),
        ),
      );
      final initial = tester.getTopLeft(find.text('first'));
      await tester.tap(find.byKey(const ValueKey('search-history.manage')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('first')), initial);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.byKey(const ValueKey('search-history.word.first')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('first')), initial);
    },
  );

  testWidgets('cancelling history deletion does not restore the input focus', (
    tester,
  ) async {
    final inputFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: inputFocus, autofocus: true),
              SearchHistorySection(
                words: const ['entry'],
                scopeLabel: 'scope',
                onSubmit: (_) {},
                onRemove: (_) async {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.manage')));
    await tester.pumpAndSettle();
    expect(inputFocus.hasFocus, isFalse);
    await tester.tap(find.byKey(const ValueKey('search-history.word.entry')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('search-history.delete-selected')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
    await tester.pumpAndSettle();
    expect(inputFocus.hasFocus, isFalse);
  });

  testWidgets(
    'manage selects words without searching; delete cancellation is safe',
    (tester) async {
      var words = ['甲搜索', '乙搜索', '丙搜索'];
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) => SingleChildScrollView(
                child: SearchHistorySection(
                  words: words,
                  scopeLabel: '当前来源',
                  onSubmit: (_) => submissions++,
                  onRemove: (selected) async => update(
                    () => words = words
                        .where((word) => !selected.contains(word))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('search-history.manage')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('search-history.word.甲搜索')));
      await tester.tap(find.byKey(const ValueKey('search-history.word.乙搜索')));
      await tester.pump();
      expect(submissions, 0);
      await tester.tap(
        find.byKey(const ValueKey('search-history.delete-selected')),
      );
      await tester.pumpAndSettle();
      expect(words.length, 3);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await tester.pumpAndSettle();
      expect(words.length, 3);
      await tester.tap(
        find.byKey(const ValueKey('search-history.delete-selected')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, t.common.delete));
      await tester.pumpAndSettle();
      expect(words, ['丙搜索']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comic source clear retains legacy and other source histories', (
    tester,
  ) async {
    final settings = GlobalSettingCubit();
    addTearDown(settings.close);
    final initial = SearchHistoryEntries.add(
      SearchHistoryEntries.add(['旧综合词'], '甲源词', scope: 'a'),
      '乙源词',
      scope: 'b',
    );
    settings.updateState((value) => value.copyWith(searchHistory: initial));
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: const MaterialApp(
          home: Scaffold(
            body: HistoryWidget(aggregateMode: false, source: 'a'),
          ),
        ),
      ),
    );
    expect(find.text('甲源词'), findsOneWidget);
    expect(find.text('乙源词'), findsNothing);
    expect(find.text('旧综合词'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('search-history.manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.clear')));
    await tester.pumpAndSettle();
    settings.updateState(
      (current) => current.copyWith(
        searchHistory: SearchHistoryEntries.add(
          current.searchHistory,
          '确认期间新加入',
          scope: 'a',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.search.clearHistory));
    await tester.pumpAndSettle();
    expect(
      SearchHistoryEntries.words(settings.state.searchHistory, scope: 'a'),
      ['确认期间新加入'],
    );
    expect(
      SearchHistoryEntries.words(settings.state.searchHistory, scope: 'b'),
      ['乙源词'],
    );
    expect(
      SearchHistoryEntries.words(settings.state.searchHistory, scope: ''),
      ['旧综合词'],
    );
  });

  testWidgets('video clear confirmation affects only current source', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await VideoSearchHistory.add('a', '甲视频');
      await VideoSearchHistory.add('b', '乙视频');
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoSearchPage(
          source: 'a',
          initial: VideoSearchFilters(),
          authorEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-history.clear')));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => VideoSearchHistory.read('a')), ['甲视频']);
    await tester.tap(find.widgetWithText(FilledButton, t.search.clearHistory));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => VideoSearchHistory.read('a')), isEmpty);
    expect(await tester.runAsync(() => VideoSearchHistory.read('b')), ['乙视频']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded comic input defeats inherited dark fill and underline',
    (tester) async {
      var submitted = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.black,
              enabledBorder: UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(),
            ),
          ),
          home: Scaffold(
            body: SearchQueryField(
              query: '关键词',
              autoExpand: true,
              onSubmitted: (query) => submitted = query,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final colors = Theme.of(
        tester.element(find.byType(TextField)),
      ).colorScheme;
      // The outer SearchFieldSurface owns the only background.
      expect(field.decoration?.filled, isFalse);
      expect(field.decoration?.enabledBorder, isA<OutlineInputBorder>());
      expect(field.decoration?.focusedBorder, isA<OutlineInputBorder>());
      expect(field.decoration?.focusedBorder?.borderSide.color, colors.primary);
      await tester.tap(find.byTooltip(t.search.title));
      await tester.pumpAndSettle();
      expect(submitted, '关键词');
      expect(tester.takeException(), isNull);
    },
  );
}
