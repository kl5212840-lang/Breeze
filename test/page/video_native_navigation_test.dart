import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

void main() {
  const items = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
  ];
  testWidgets(
    'native navigation preserves current selection and validates platform callbacks',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodChannel? channel;
      var creations = 0;
      final updates = <Map>[];
      final selections = <int>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          creations++;
          channel = MethodChannel(
            'breeze.video.navigation.${(call.arguments as Map)['id']}',
          );
          messenger.setMockMethodCallHandler(channel!, (call) async {
            if (call.method == 'update') updates.add(call.arguments as Map);
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (channel != null) messenger.setMockMethodCallHandler(channel!, null);
      });
      Widget view(
        int current, {
        bool enabled = true,
        List<String?> badgeValues = const [],
        List<String?> selectedSymbols = const [],
      }) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: VideoNativeNavigation(
            items: items,
            symbols: const ['book.closed', 'bell'],
            selectedSymbols: selectedSymbols,
            badgeValues: badgeValues,
            currentIndex: current,
            onTap: enabled ? selections.add : null,
          ),
        ),
      );
      await tester.pumpWidget(view(0));
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(updates.last['selected'], 0);
      expect(updates.last['items'], [
        {'title': 'Home', 'symbol': 'book.closed'},
        {'title': 'Me', 'symbol': 'bell'},
      ]);
      const mainSelectedSymbols = ['book.fill', 'breeze.follow.selected'];
      await tester.pumpWidget(view(0, selectedSymbols: mainSelectedSymbols));
      await tester.pump();
      expect(updates.last['items'], [
        {
          'title': 'Home',
          'symbol': 'book.closed',
          'selectedSymbol': 'book.fill',
        },
        {
          'title': 'Me',
          'symbol': 'bell',
          'selectedSymbol': 'breeze.follow.selected',
        },
      ]);
      expect(creations, 1);
      Future<void> select(int index) async {
        await messenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('select', index),
          ),
          (_) {},
        );
        await tester.pump();
      }

      Future<void> height(num value) async {
        await messenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('height', value),
          ),
          (_) {},
        );
        await tester.pump();
      }

      await height(83);
      expect(tester.getSize(find.byType(UiKitView)).height, 83);
      for (final invalid in [0, 37, 1000, double.nan, double.infinity]) {
        await height(invalid);
        expect(tester.getSize(find.byType(UiKitView)).height, 83);
      }

      await select(-1);
      await select(2);
      expect(selections, isEmpty);
      await select(1);
      expect(selections, [1]);
      await tester.pumpWidget(view(1));
      await tester.pump();
      expect(updates.last['selected'], 1);
      final definitions = updates.last['items'];
      await tester.pumpWidget(view(1, badgeValues: const [null, '3']));
      await tester.pump();
      expect(updates.last['badges'], [null, '3']);
      expect(updates.last['items'], definitions);
      expect(updates.last['selected'], 1);
      await tester.pumpWidget(view(1));
      await tester.pump();
      expect(updates.last.containsKey('badges'), isFalse);
      expect(creations, 1, reason: 'badge updates keep the same UIKit view');
      await tester.pumpWidget(view(1, enabled: false));
      await tester.pump();
      await select(0);
      expect(selections, [1]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android system navigation follows theme changes and Breeze keeps its bar',
    (tester) async {
      int selected = 0;
      final appearance = ValueNotifier('system');
      addTearDown(appearance.dispose);
      Widget view(Color seed, Brightness brightness) {
        final scheme = BreezeThemeColors.fromSeed(seed, brightness);
        return MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(
            bottomNavigationBar: AppInterfaceStyleScope(
              style: appearance,
              child: MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.only(top: 48, bottom: 24),
                ),
                child: VideoNativeNavigation(
                  items: items,
                  symbols: const ['house', 'person'],
                  currentIndex: selected,
                  onTap: (i) => selected = i,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(view(Colors.pink, Brightness.light));
      final bar = find.byType(NavigationBar);
      expect(tester.getSize(bar).height, 92);
      expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);
      final pink = tester.widget<NavigationBar>(bar).indicatorColor;
      expect(find.byType(UiKitView), findsNothing);
      await tester.tap(find.text('Me'));
      expect(selected, 1);
      await tester.pumpWidget(view(Colors.teal, Brightness.dark));
      await tester.pumpAndSettle();
      final teal = tester.widget<NavigationBar>(bar);
      expect(teal.selectedIndex, 1);
      expect(teal.indicatorColor, isNot(pink));
      final theme = NavigationBarTheme.of(tester.element(bar));
      final icon = theme.iconTheme!.resolve({WidgetState.selected})!.color!;
      expect(
        BreezeThemeColors.contrast(icon, teal.indicatorColor!),
        greaterThan(4.5),
      );
      appearance.value = 'breeze';
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(find.byType(BreezeNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
