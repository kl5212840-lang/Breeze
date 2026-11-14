import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets(
    'wide main rail emphasizes the current destination and keeps tab state',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xff37724b),
        brightness: Brightness.dark,
      );
      const destinations = [
        NavigationRailDestination(
          icon: Icon(Icons.explore_outlined),
          label: Text('Explore'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: Text('Shelf'),
        ),
      ];
      final field = GlobalKey();
      var selected = 0;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            theme: ThemeData(colorScheme: colors),
            home: StatefulBuilder(
              builder: (context, setState) => app.MainWideTabHost(
                destinations: destinations,
                screens: [
                  TextField(key: field),
                  const Text('Shelf content'),
                ],
                selectedIndex: selected,
                onSelected: (index) => setState(() => selected = index),
                onSearch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(field), 'kept draft');
      final rail = find.byType(NavigationRail);
      final bounds = tester.getRect(rail);
      final initial = tester.widget<NavigationRail>(rail);
      final oldIndicator = Color.alphaBlend(
        colors.primary.withValues(alpha: .14),
        initial.backgroundColor!,
      );
      expect(
        initial.indicatorColor!.computeLuminance(),
        greaterThan(oldIndicator.computeLuminance()),
      );
      expect(
        initial.selectedLabelTextStyle!.color,
        initial.selectedIconTheme!.color,
      );
      expect(
        initial.selectedLabelTextStyle!.color,
        isNot(initial.unselectedLabelTextStyle!.color),
      );

      await tester.tap(find.text('Shelf'));
      await tester.pump();
      expect(find.text('Shelf content').hitTestable(), findsOneWidget);
      expect(tester.widget<NavigationRail>(rail).selectedIndex, 1);
      expect(tester.getRect(rail), bounds);
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.text('kept draft'), findsOneWidget);
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationRail>(rail).indicatorColor, isNull);
      expect(find.text('kept draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real Discover swaps list and grid promptly and keeps its keyboard target on reversal',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'discover_plugin_layout_v1': 'list',
      });
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: BlocProvider(
            create: (_) => GlobalSettingCubit(),
            child: const MaterialApp(home: DiscoverPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final now = DateTime(2026, 1, 1);
      final cubit = tester.element(find.byType(Scaffold)).read<DiscoverCubit>();
      cubit.emit(
        DiscoverState(
          plugins: {
            'example': PluginRuntimeState(
              uuid: 'example',
              version: '1',
              originScript: '',
              isEnabled: true,
              isDeleted: false,
              debug: false,
              debugUrl: null,
              lastLoadSuccess: true,
              lastLoadError: null,
              sortOrder: 0,
              insertedAt: now,
              updatedAt: now,
              deletedAt: null,
            ),
          },
          infoStates: const {
            'example': DiscoverPluginInfoState(
              loading: false,
              data: {'name': 'Example', 'iconUrl': ''},
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      final selector = find.byType(BreezeSectionSelector<String>);
      final plate = find.descendant(
        of: selector,
        matching: find.byKey(const ValueKey('breeze.selection.plate')),
      );
      final grid = find.widgetWithText(TextButton, t.discover.gridLayout);
      final list = find.widgetWithText(TextButton, t.discover.listLayout);
      final gridRect = tester.getRect(grid);
      final listRect = tester.getRect(list);
      final start = tester.getCenter(plate).dx;
      expect(find.byType(PluginCard), findsOneWidget);

      await tester.tap(grid);
      await tester.pump();
      expect(find.byType(PluginGridTile), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 45));
      final moving = tester.getCenter(plate).dx;
      expect(moving, inExclusiveRange(start, gridRect.center.dx));

      // Focus the adjacent list button while the grid indicator is in flight.
      final label = find.descendant(
        of: list,
        matching: find.text(t.discover.listLayout),
      );
      final focus = Focus.of(tester.element(label))..requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(PluginCard), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(tester.getCenter(plate).dx, moving);
      await tester.pumpAndSettle();
      expect(tester.getCenter(plate).dx, start);
      expect(tester.getRect(grid), gridRect);
      expect(tester.getRect(list), listRect);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
