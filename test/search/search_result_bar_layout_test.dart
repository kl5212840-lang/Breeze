import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_bar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

void main() {
  testWidgets('no advanced capability leaves no blank toolbar slot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SearchCubit(const SearchStates(searchKeyword: '关键词'));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(appBar: SearchResultBar(searchEvent: SearchEvent())),
        ),
      ),
    );

    final query = find.byType(SearchResultQueryTitle);
    final more = find.byType(SourceMoreButton);
    final initialQuery = tester.getRect(query);
    final initialMore = tester.getRect(more);
    expect(initialMore.left - initialQuery.right, greaterThanOrEqualTo(0));
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);

    await tester.pumpAndSettle();
    expect(tester.getRect(query), initialQuery);
    expect(tester.getRect(more), initialMore);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the result title and controls share a center in both styles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SearchCubit(const SearchStates(searchKeyword: 'keyword'));
    final style = ValueNotifier('breeze');
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(cubit.close);
    addTearDown(style.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(left: 9, right: 14),
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: SearchResultBar(
                  searchEvent: const SearchEvent(),
                  toolbarHeight: SearchResultQueryTitle.toolbarHeight(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final value in ['breeze', 'system']) {
      style.value = value;
      await tester.pumpAndSettle();
      final title = tester.getRect(find.byType(SearchResultQueryTitle));
      expect(find.byType(TextField), findsNothing);
      for (final icon in [Icons.arrow_back_ios_new_rounded, Icons.more_horiz]) {
        final target = tester.getRect(find.widgetWithIcon(IconButton, icon));
        expect(target.center.dy, closeTo(title.center.dy, .01));
        expect(target.width, greaterThanOrEqualTo(44));
        expect(target.height, greaterThanOrEqualTo(44));
        expect(
          target.left,
          greaterThanOrEqualTo(9 + CollectionToolbarMetrics.sourceContentInset),
        );
        expect(
          target.right,
          lessThanOrEqualTo(
            320 - 14 - CollectionToolbarMetrics.sourceContentInset,
          ),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
