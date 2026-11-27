import 'package:zephyr/i18n/strings.g.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/source_quick_category_bar.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_category_settings_scope.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import '../test_helper.dart';

class _ReadySearch extends SearchBloc {
  final requests = <SearchEvent>[];
  @override
  SearchState get state => SearchState(status: SearchStatus.success);
  @override
  void add(SearchEvent event) => requests.add(event);
}

Future<void> _openCategoryFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('search-result.filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(t.searchResult.blockCategories));
  await tester.pumpAndSettle();
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
      await _openCategoryFilter(tester);
      await tester.tap(find.byKey(const ValueKey('分类甲')));
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
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

  test(
    'legacy page rules merge into settings once and remain removable',
    () async {
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: bikaPlusSourceId,
          config: jsonEncode({
            bikaSearchBlockedCategoriesKey: ['短篇'],
            'home.blockedCategories': ['首頁入口'],
          }),
        ),
      );
      final legacy = '$bikaPlusSourceId|search';
      await SourceListBlockPreferences.write(legacy, {'全彩'});
      await Future.wait([
        migrateBikaSearchBlocks(bikaPlusSourceId),
        migrateBikaSearchBlocks(bikaPlusSourceId),
      ]);
      List read(String key) => loadPluginConfigValue<List>(
        bikaPlusSourceId,
        key,
        fallback: const [],
      );
      expect(read(bikaSearchBlockedCategoriesKey), ['短篇', '全彩']);
      expect(read('home.blockedCategories'), ['首頁入口']);
      final beforeRemoval = objectbox.pluginConfigBox.getAll().single.config;

      await savePluginConfigValue(
        bikaPlusSourceId,
        bikaSearchBlockedCategoriesKey,
        ['短篇'],
      );
      await migrateBikaSearchBlocks(bikaPlusSourceId);
      expect(read(bikaSearchBlockedCategoriesKey), ['短篇']);
      expect(await SourceListBlockPreferences.read(legacy), {'全彩'});
      final afterRemoval = objectbox.pluginConfigBox.getAll().single.config;
      final merged =
          jsonDecode(
                mergePluginConfigData(
                  afterRemoval,
                  beforeRemoval,
                  localUpdatedAt: 0,
                  remoteUpdatedAt: 0,
                  preferRemoteOnConflict: true,
                ),
              )
              as Map;
      expect(merged[bikaSearchBlockedCategoriesKey], ['短篇']);

      // An old backup can still contain the legacy and the saved rules.
      await SourceListBlockPreferences.write(legacy, {'全彩', '同人'});
      await migrateBikaSearchBlocks(bikaPlusSourceId);
      expect(read(bikaSearchBlockedCategoriesKey), ['短篇', '同人']);
    },
  );
}
