import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/source_quick_category_bar.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import '../test_helper.dart';

class _ReadySearch extends SearchBloc {
  final requests = <SearchEvent>[];
  @override
  SearchState get state => SearchState(status: SearchStatus.success);
  @override
  void add(SearchEvent event) => requests.add(event);
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
  });
  testWidgets(
    'existing category controls on another source retain remote refresh',
    (tester) async {
      final search = SearchCubit(
        const SearchStates(
          from: 'existing-category-source',
          searchKeyword: 'query',
        ),
      );
      final results = _ReadySearch();
      addTearDown(results.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: search),
            BlocProvider<SearchBloc>.value(value: results),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SourceQuickCategoryBar(
                categories: const ['分类甲'],
                detailedView: true,
                onViewChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-分类甲')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(results.requests, hasLength(1));
      expect(
        results.requests.single.searchStates.pluginExtern['blockedCategories'],
        ['分类甲'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await search.close();
      await SourceListBlockPreferences.flush();
    },
  );

  testWidgets(
    'settings blocks stay visible, locked and survive clearing page-only blocks',
    (tester) async {
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: bikaPlusSourceId,
          config: jsonEncode({
            'search.blockedCategories': ['短篇'],
          }),
        ),
      );
      await SourceListBlockPreferences.write('$bikaPlusSourceId|search', {
        '全彩',
      });
      final search = SearchCubit(
        const SearchStates(from: bikaPlusSourceId, searchKeyword: 'query'),
      );
      final results = _ReadySearch();
      addTearDown(results.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: search),
            BlocProvider<SearchBloc>.value(value: results),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SourceQuickCategoryBar(
                categories: const ['短篇', '全彩'],
                detailedView: true,
                onViewChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      ActionChip chip(String name) =>
          tester.widget<ActionChip>(find.byKey(ValueKey('category-$name')));
      expect(chip('短篇').onPressed, isNull);
      expect(chip('全彩').onPressed, isNotNull);
      expect(find.text('短篇'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-短篇')));
      await tester.pump();
      expect(find.text('已在插件设置中屏蔽，请到屏蔽设置中修改'), findsOneWidget);
      expect(
        loadPluginConfigValue<List>(
          bikaPlusSourceId,
          'search.blockedCategories',
          fallback: const [],
        ),
        ['短篇'],
      );
      await tester.tap(find.byKey(const ValueKey('source-list.clear-blocked')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        await SourceListBlockPreferences.read('$bikaPlusSourceId|search'),
        isEmpty,
      );
      expect(search.state.pluginExtern['blockedCategories'], isEmpty);
      expect(search.state.pluginExtern['settingsBlockedCategories'], ['短篇']);
      expect(chip('短篇').onPressed, isNull);
      await tester.runAsync(() async {
        await savePluginConfigValue(
          bikaPlusSourceId,
          'search.blockedCategories',
          [],
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      expect(chip('短篇').onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await search.close();
      await SourceListBlockPreferences.flush();
    },
  );
}
