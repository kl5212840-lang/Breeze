import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';

import '../test_helper.dart';

const _options = {'': '全部', 'name': '标题', 'author': '作者', 'local': '汉化组'};

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('scope is owned by the source and no longer duplicated in advanced', () {
    final fields = <Map<String, dynamic>>[
      {
        'key': 'q_type',
        'kind': 'choice',
        'options': [
          for (final e in _options.entries) {'value': e.key, 'label': e.value},
        ],
      },
      {'key': 'custom', 'kind': 'choice', 'options': []},
    ];
    expect(sourceSearchScope(fields)?.options, _options);
    expect(
      uniqueAdvancedFields('copy-scope-test', fields).map((f) => f['key']),
      ['custom'],
    );
    expect(
      sourceSearchScope([
        {'key': 'q_type', 'kind': 'text'},
      ]),
      isNull,
    );
  });

  test('manual scopes map only verified native parameters', () {
    const copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
    const jm = '6886291b-f524-441c-844b-c2efae9899a9';
    final title = {keywordSearchScopeKey: 'title', 'sortBy': 4};
    expect(keywordSearchRequestExtern(copy, title), {
      'sortBy': 4,
      'q_type': 'name',
    });
    expect(keywordSearchRequestExtern(copy, {keywordSearchScopeKey: 'all'}), {
      'q_type': '',
    });
    expect(keywordSearchRequestExtern(jm, title), {'sortBy': 4, 'main_tag': 0});
    expect(keywordSearchRequestExtern(jm, {'main_tag': 3}), {'main_tag': 3});
    expect(keywordSearchRequestExtern('opaque', title), {'sortBy': 4});
    expect(needsLoadedTitleMatch(copy, title), isFalse);
    expect(needsLoadedTitleMatch(jm, title), isTrue);
    expect(keywordTitleMatcher('天空 之城')(['天空之城']), isTrue);
    expect(keywordTitleMatcher('天空 之城')(['天空', '之城']), isFalse);
  });

  test(
    'remote field scopes keep source parameters and leave video parsing intact',
    () {
      const jm = '6886291b-f524-441c-844b-c2efae9899a9';
      final author = {keywordSearchScopeKey: 'author'};
      final tags = {keywordSearchScopeKey: 'tags'};
      final team = {keywordSearchScopeKey: 'team'};
      expect(
        keywordSearchRequestExtern(copyComicSourceId, author)['q_type'],
        'author',
      );
      expect(
        keywordSearchRequestExtern(copyComicSourceId, team)['q_type'],
        'local',
      );
      expect(
        keywordSearchRequestExtern(copyComicSourceId, tags)[copySearchTopicKey],
        true,
      );
      expect(keywordSearchRequestExtern(jm, author), {'main_tag': 2});
      expect(keywordSearchRequestExtern(jm, tags), {'main_tag': 3});
      expect(keywordSearchRequestExtern(bikaPlusSourceId, author), {
        'bikaSearchField': 'author',
      });
      expect(keywordSearchRequestExtern(bikaPlusSourceId, tags), {
        'bikaSearchField': 'tag',
      });
      expect(keywordSearchRequestExtern(bikaPlusSourceId, team), {
        'bikaSearchField': 'team',
      });
      expect(
        keywordSearchRequestExtern(bikaPlusSourceId, {
          'bikaSearchField': 'tag',
        }),
        {'bikaSearchField': 'tag'},
      );
      expect(
        sourceKeywordSearchScope(jm, {'main_tag': 3}),
        KeywordSearchScope.tags,
      );
      expect(parseKeywordSearchScope('tags'), isNull);
      expect(parseSourceKeywordSearchScope('tags'), KeywordSearchScope.tags);
    },
  );

  testWidgets(
    'changing scope retains the query and supports returning to All',
    (tester) async {
      final cubit = SearchCubit(
        const SearchStates(
          from: 'copy-scope-test',
          searchKeyword: '查询关键词',
          pluginExtern: {
            keywordSearchScopeKey: 'title',
            'unrelated': 'preserved',
          },
        ),
      );
      addTearDown(cubit.close);
      var searches = 0;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: SourceSearchScopeControl(onChanged: (_) => searches++),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      expect(find.text('作者'), findsNothing);
      expect(find.text('汉化组'), findsNothing);
      await tester.tap(find.text(t.common.all).last);
      await tester.pumpAndSettle();
      expect(cubit.state.searchKeyword, '查询关键词');
      expect(cubit.state.pluginExtern, {
        keywordSearchScopeKey: 'all',
        'unrelated': 'preserved',
      });
      expect(searches, 1);
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      expect(find.text('作者'), findsNothing);
      expect(find.text('汉化组'), findsNothing);
      await tester.tap(find.text(t.common.all).last);
      await tester.pumpAndSettle();
      expect(
        searches,
        1,
        reason: 'Re-selecting the current scope must not reload',
      );
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.searchScopeTitle).last);
      await tester.pumpAndSettle();
      expect(cubit.state.pluginExtern[keywordSearchScopeKey], 'title');
      expect(cubit.state.searchKeyword, '查询关键词');
      expect(searches, 2);
    },
  );

  testWidgets('scope, paging, sort and view fit narrow large-text layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = SearchCubit(const SearchStates(from: 'copy-scope-layout'));
    addTearDown(cubit.close);
    var modeChanges = 0;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SourceListFilterBar(
              categories: const [],
              blockedCategories: const {},
              onCategoryTap: (_) {},
              sortValue: '1',
              sortOptions: const {'1': '按更新时间排序'},
              onSortChanged: (_) {},
              detailedView: false,
              onViewChanged: (_) => modeChanges++,
              leading: const SourceSearchScopeControl(),
              pageLabel: '第100 / 200页',
              onPageTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(t.comicList.switchToList));
    expect(modeChanges, 1);
  });
}
