import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';
import 'package:zephyr/page/search_aggregate/view/search_aggregate_result_page.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'aggregate selection and queries stay in the same search session',
    (tester) async {
      final registry = _TestPluginRegistry();
      final settings = GlobalSettingCubit();
      final slow = Completer<List<dynamic>>();
      final calls = <(String, String)>[];
      final submissions = <SearchAggregateResultRouteArgs>[];
      final searches = <AggregateSearchCubit>[];
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'Home',
            path: '/',
            initial: true,
            builder: (_, _) => const Scaffold(),
          ),
          AutoRoute(page: SearchRoute.page),
          NamedRouteDef(
            name: SearchAggregateResultRoute.name,
            path: '/aggregate-results',
            builder: (_, data) {
              final args = data.argsAs<SearchAggregateResultRouteArgs>();
              submissions.add(args);
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: args.searchCubit!),
                  BlocProvider(
                    create: (_) {
                      final search = AggregateSearchCubit(
                        args.searchEvent,
                        initialSelectedSources: args.selectedSources,
                        sourceSearch: (id, event) {
                          final keyword = event.searchStates.searchKeyword;
                          calls.add((id, keyword));
                          if (id == 'slow' && keyword == '水原') {
                            return slow.future;
                          }
                          return Future.value([]);
                        },
                      )..search();
                      searches.add(search);
                      return search;
                    },
                  ),
                ],
                child: SearchAggregateResultPage(searchEvent: args.searchEvent),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(registry.close);
      addTearDown(settings.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PluginRegistryCubit>.value(value: registry),
            BlocProvider.value(value: settings),
          ],
          child: MaterialApp.router(routerConfig: router.config()),
        ),
      );
      router.push(SearchRoute(searchState: const SearchStates()));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, '水原');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final firstSearch = searches.single;
      expect(firstSearch.state.pendingSources, {'slow'});
      expect(calls, containsAll([('slow', '水原'), ('fast', '水原')]));

      final select = find.descendant(
        of: find.byType(SearchAggregateResultPage),
        matching: find.byTooltip(t.search.selectSourceTooltip),
      );
      await tester.tap(select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(firstSearch.state.pendingSources, {'slow'});
      await tester.tap(find.text(t.common.cancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(firstSearch.state.pendingSources, {'slow'});
      expect(calls, hasLength(2));

      await tester.tap(select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('search-source.fast')));
      await tester.tap(find.text(t.common.apply));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(firstSearch.state.pendingSources, {'slow'});
      expect(firstSearch.state.selectedSources, {'fast': false, 'slow': true});
      expect(calls, hasLength(2));
      slow.complete([]);
      await tester.pumpAndSettle();

      tester.widget<SearchQueryField>(find.byType(SearchQueryField)).onTap!();
      await tester.pumpAndSettle();
      await tester.showKeyboard(field);
      const composition = TextEditingValue(
        text: 'pin',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      tester.testTextInput.updateEditingValue(composition);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<TextField>(field).controller!.value, composition);
      expect(submissions.single.searchCubit!.state.searchKeyword, '水原');
      await tester.tap(
        find.descendant(
          of: find.byType(HistoryWidget),
          matching: find.text('水原'),
        ),
      );
      await tester.pumpAndSettle();
      expect(submissions.last.selectedSources['fast'], isFalse);
      tester.widget<SearchQueryField>(find.byType(SearchQueryField)).onTap!();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '水原');

      await tester.enterText(field, '新查询');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submissions.last.searchEvent.searchStates.searchKeyword, '新查询');
      expect(calls.where((call) => call.$2 == '新查询'), [('slow', '新查询')]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _TestPluginRegistry extends PluginRegistryCubit {
  _TestPluginRegistry() {
    emit({
      for (final id in ['fast', 'slow'])
        id: PluginRuntimeState(
          uuid: id,
          version: '1',
          originScript: '',
          isEnabled: true,
          isDeleted: false,
          debug: false,
          debugUrl: null,
          lastLoadSuccess: true,
          lastLoadError: null,
          sortOrder: null,
          insertedAt: DateTime(2026),
          updatedAt: DateTime(2026),
          deletedAt: null,
        ),
    });
  }
}
