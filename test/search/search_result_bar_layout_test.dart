import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
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

    final query = find.byType(SearchQueryField);
    final more = find.byType(SourceMoreButton);
    final initialQuery = tester.getRect(query);
    final initialMore = tester.getRect(more);
    expect(initialMore.left - initialQuery.right, 0);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);

    await tester.pumpAndSettle();
    expect(tester.getRect(query), initialQuery);
    expect(tester.getRect(more), initialMore);
    expect(find.byTooltip(t.search.advancedSearchOptions), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Breeze result actions center on the field with compact plates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SearchCubit(const SearchStates(searchKeyword: 'keyword'));
    final style = ValueNotifier('breeze');
    addTearDown(cubit.close);
    addTearDown(style.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                appBar: SearchToolbarScope.appBar(
                  context,
                  (height) => SearchResultBar(
                    searchEvent: const SearchEvent(),
                    toolbarHeight: height,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(SearchQueryField));
    for (final icon in [Icons.arrow_back, Icons.more_horiz]) {
      final button = find.widgetWithIcon(IconButton, icon);
      final plate = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox && widget.decoration is BoxDecoration,
        ),
      );
      expect(plate, findsOneWidget);
      final rect = tester.getRect(plate);
      final target = tester.getRect(button);
      expect(rect.center.dy, closeTo(field.center.dy, .01));
      expect(rect.width, closeTo(36, .01));
      expect(rect.height, lessThan(field.height));
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
    }
  });
}
