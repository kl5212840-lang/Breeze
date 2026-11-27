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

import '../test_helper.dart';

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
    final initialQuery = tester.getRect(query);
    expect(find.byType(SourceMoreButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);

    await tester.pumpAndSettle();
    expect(tester.getRect(query), initialQuery);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('category browsing keeps the source menu', (tester) async {
    await tester.runAsync(TestObjectBoxHelper.setUpTestObjectBox);
    addTearDown(TestObjectBoxHelper.tearDownTestObjectBox);
    SharedPreferences.setMockInitialValues({});
    final cubit = SearchCubit(
      const SearchStates(
        from: 'fixture',
        pluginExtern: {
          'categories': ['冒险'],
        },
      ),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(appBar: SearchResultBar(searchEvent: SearchEvent())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('冒险'), findsOneWidget);
    expect(find.byType(SourceMoreButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
      expect(find.byType(SourceMoreButton), findsNothing);
      final back = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new_rounded),
      );
      expect(back.center.dy, closeTo(title.center.dy, .01));
      expect(back.width, greaterThanOrEqualTo(44));
      expect(back.height, greaterThanOrEqualTo(44));
      expect(
        back.left,
        greaterThanOrEqualTo(9 + CollectionToolbarMetrics.sourceContentInset),
      );
      expect(back.right, lessThanOrEqualTo(title.left));
      expect(tester.takeException(), isNull);
    }
  });
}
