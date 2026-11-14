import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import '../test_helper.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_bar.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('category browse has its title and no all-source search field', (
    tester,
  ) async {
    final cubit = SearchCubit(
      const SearchStates(
        pluginExtern: {
          'categories': ['短篇'],
        },
      ),
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(appBar: SearchResultBar(searchEvent: SearchEvent())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SearchQueryField), findsNothing);
    expect(find.text('短篇'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
  for (final existingSearch in [false, true]) {
    testWidgets(
      'search editing preserves the source list return chain ($existingSearch)',
      (tester) async {
        final cubit = SearchCubit(
          const SearchStates(searchKeyword: 'kept query'),
        );
        final router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: 'Home',
              path: '/',
              initial: true,
              builder: (_, __) => const Scaffold(body: Text('Home page')),
            ),
            NamedRouteDef(
              name: SearchRoute.name,
              path: '/search',
              builder: (_, __) => const Scaffold(body: Text('Search entry')),
            ),
            NamedRouteDef(
              name: 'SourceResults',
              path: '/results',
              builder: (_, __) => BlocProvider.value(
                value: cubit,
                child: const Scaffold(
                  appBar: SearchResultBar(searchEvent: SearchEvent()),
                  body: Text('Retained results'),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.config()),
        );
        await tester.pumpAndSettle();
        if (existingSearch) {
          router.pushPath('/search');
          await tester.pumpAndSettle();
        }
        router.pushPath('/results');
        await tester.pumpAndSettle();
        tester.widget<SearchQueryField>(find.byType(SearchQueryField)).onTap!();
        await tester.pumpAndSettle();
        expect(router.stack.last.name, SearchRoute.name);
        expect(
          router.stack.map((r) => r.name).toList(),
          existingSearch
              ? ['Home', SearchRoute.name]
              : ['Home', 'SourceResults', SearchRoute.name],
        );
        if (!existingSearch) {
          await router.maybePop();
          await tester.pumpAndSettle();
          expect(find.text('Retained results'), findsOneWidget);
          expect(cubit.state.searchKeyword, 'kept query');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await cubit.close();
      },
    );
  }
}
