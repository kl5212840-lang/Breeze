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
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';
import 'package:zephyr/page/search_aggregate/view/search_aggregate_result_page.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'aggregate history and new queries use the current enabled plugins',
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
                        initialSelectedSources: {
                          for (final plugin in registry.state.values)
                            if (plugin.isActive) plugin.uuid: true,
                        },
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
      router.push(
        SearchRoute(
          searchState: SearchStates.fromJson({
            'aggregateSources': {'fast': false, 'new': true, 'removed': true},
          }),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(
        find.byKey(const ValueKey('comic-search.options-row')),
        findsNothing,
      );
      await tester.enterText(field, '水原');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final firstSearch = searches.single;
      expect(firstSearch.state.pendingSources, {'slow'});
      expect(calls, containsAll([('slow', '水原'), ('fast', '水原')]));

      expect(find.byTooltip(t.search.selectSourceTooltip), findsNothing);
      expect(firstSearch.state.selectedSources, {'fast': true, 'slow': true});
      final resultFilter = find.widgetWithText(FilterChip, t.search.hasResults);
      final resultScaffold = find.ancestor(
        of: resultFilter,
        matching: find.byType(Scaffold),
      );
      double filterLeadingInset() =>
          tester.getTopLeft(resultFilter).dx -
          tester.getTopLeft(resultScaffold).dx;
      final filterLeftWhileLoading = filterLeadingInset();
      slow.complete([]);
      await tester.pumpAndSettle();
      expect(filterLeadingInset(), closeTo(filterLeftWhileLoading, .01));

      final resultTitle = find.byKey(const ValueKey('aggregate.query-title'));
      expect(find.byType(TextField), findsNothing);
      await tester.tap(
        find.descendant(of: resultTitle, matching: find.text('水原')),
      );
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
      registry.setEnabled('fast', false);
      registry.setEnabled('new', true);
      calls.clear();
      await tester.tap(
        find.descendant(
          of: find.byType(HistoryWidget),
          matching: find.text('水原'),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, unorderedEquals([('slow', '水原'), ('new', '水原')]));
      await tester.tap(
        find.descendant(of: resultTitle, matching: find.text('水原')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '水原');

      await tester.enterText(field, '新查询');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submissions.last.searchEvent.searchStates.searchKeyword, '新查询');
      expect(
        calls.where((call) => call.$2 == '新查询'),
        unorderedEquals([('slow', '新查询'), ('new', '新查询')]),
      );

      router.popUntilRoot();
      await tester.pumpAndSettle();
      const directState = SearchStates(searchKeyword: '直接结果');
      final directSession = SearchCubit(directState);
      addTearDown(directSession.close);
      router.push(
        SearchAggregateResultRoute(
          searchEvent: const SearchEvent(searchStates: directState),
          searchCubit: directSession,
        ),
      );
      await tester.pumpAndSettle();
      final directResults = searches.last;
      final submittedCount = submissions.length;
      await tester.tap(
        find.descendant(of: resultTitle, matching: find.text('直接结果')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '直接结果');
      await tester.enterText(field, '取消编辑');
      await tester.tap(find.byKey(const ValueKey('comic-search.back')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: resultTitle, matching: find.text('直接结果')),
        findsOneWidget,
      );
      expect(searches.last, same(directResults));
      expect(submissions, hasLength(submittedCount));
      expect(directResults.state.selectedSources, {'slow': true, 'new': true});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _TestPluginRegistry extends PluginRegistryCubit {
  _TestPluginRegistry() {
    emit({
      for (final id in ['fast', 'slow', 'new', 'removed'])
        id: PluginRuntimeState(
          uuid: id,
          version: '1',
          originScript: '',
          isEnabled: id != 'new',
          isDeleted: id == 'removed',
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

  void setEnabled(String id, bool enabled) {
    emit({...state, id: state[id]!.copyWith(isEnabled: enabled)});
  }
}
