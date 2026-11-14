import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/widgets/toast.dart';

void main() {
  test('source field search becomes All when submitting a global search', () {
    for (final scope in ['author', 'tags', 'team']) {
      final source = SearchStates(
        from: copyComicSourceId,
        pluginExtern: {
          keywordSearchScopeKey: scope,
          copySearchTopicKey: 'jingji',
          'copySearchVariants': ['競技'],
          'q_type': 'author',
          'main_tag': 2,
          'bikaSearchField': 'author',
          'blockedCategories': ['hidden'],
        },
      );
      expect(searchSubmissionExtern(source, aggregateMode: true), {
        keywordSearchScopeKey: 'all',
        'blockedCategories': ['hidden'],
      });
      expect(
        searchSubmissionExtern(
          source,
          aggregateMode: false,
        )[keywordSearchScopeKey],
        scope,
      );
    }

    const legacy = SearchStates(
      from: copyComicSourceId,
      pluginExtern: {'q_type': 'author'},
    );
    expect(searchSubmissionExtern(legacy, aggregateMode: true), {
      keywordSearchScopeKey: 'all',
    });
    expect(
      searchSubmissionExtern(
        const SearchStates(
          from: copyComicSourceId,
          pluginExtern: {'q_type': ''},
        ),
        aggregateMode: true,
      ),
      {keywordSearchScopeKey: 'all', 'q_type': ''},
    );
    for (final aggregate in [false, true]) {
      expect(
        searchSubmissionExtern(const SearchStates(), aggregateMode: aggregate),
        {keywordSearchScopeKey: 'all'},
      );
      expect(
        searchSubmissionExtern(
          const SearchStates(pluginExtern: {keywordSearchScopeKey: 'title'}),
          aggregateMode: aggregate,
        ),
        {keywordSearchScopeKey: 'title'},
      );
    }
    const explicit = {keywordSearchScopeKey: 'title', 'q_type': 'author'};
    expect(
      searchSubmissionExtern(
        legacy,
        aggregateMode: true,
        pluginExtern: explicit,
      ),
      explicit,
    );
  });

  testWidgets('blank search stays on the search page', (tester) async {
    BuildContext? searchContext;
    final warnings = <ToastEvent>[];
    final subscription = eventBus.on<ToastEvent>().listen(warnings.add);
    addTearDown(subscription.cancel);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            searchContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    onSearch(searchContext!, ' \t ', aggregateMode: false);
    await tester.pump();

    expect(warnings, hasLength(1));
    expect(warnings.single.message, t.search.enterKeyword);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
