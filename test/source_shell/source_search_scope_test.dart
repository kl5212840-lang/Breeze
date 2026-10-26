import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';

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
    expect(sourceSearchScopeOptions(fields), _options);
    expect(
      uniqueAdvancedFields('copy-scope-test', fields).map((f) => f['key']),
      ['custom'],
    );
    expect(
      sourceSearchScopeOptions([
        {'key': 'q_type', 'kind': 'text'},
      ]),
      isEmpty,
    );
  });

  testWidgets(
    'changing scope retains the query and supports returning to All',
    (tester) async {
      final cubit = SearchCubit(
        const SearchStates(
          from: 'copy-scope-test',
          searchKeyword: '查询关键词',
          pluginExtern: {'q_type': '', 'unrelated': 'preserved'},
        ),
      );
      addTearDown(cubit.close);
      var searches = 0;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: SourceSearchScopeControl(
                options: _options,
                onChanged: () => searches++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('作者'));
      await tester.pumpAndSettle();
      expect(cubit.state.searchKeyword, '查询关键词');
      expect(cubit.state.pluginExtern, {
        'q_type': 'author',
        'unrelated': 'preserved',
      });
      expect(searches, 1);
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('作者'));
      await tester.pumpAndSettle();
      expect(
        searches,
        1,
        reason: 'Re-selecting the current scope must not reload',
      );
      await tester.tap(find.byTooltip(t.comicList.scope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      expect(cubit.state.pluginExtern['q_type'], '');
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
              leading: const SourceSearchScopeControl(options: _options),
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
