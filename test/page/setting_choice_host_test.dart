import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/navigation/main_navigation_layout.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/app_behavior_setting_page.dart';
import 'package:zephyr/page/setting/global/eink_setting_page.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
  for (final style in ['system', 'breeze']) {
    testWidgets(
      'App Behavior toggles both main navigation items at 320pt 2x $style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        final cubit = GlobalSettingCubit();
        addTearDown(cubit.close);
        cubit.updateState(
          (current) => current.copyWith(mainNavigationSlots: ''),
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const AppBehaviorSettingPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Finder row(MainNavigationShortcut shortcut) =>
            find.byKey(ValueKey('settings.main-navigation.${shortcut.name}'));
        Future<void> toggle(MainNavigationShortcut shortcut, bool value) async {
          await tester.ensureVisible(row(shortcut));
          await tester.pumpAndSettle();
          final control = tester.widget<BreezeSwitchListTile>(row(shortcut));
          expect(control.tile.value, !value);
          final rect = tester.getRect(row(shortcut));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.height, greaterThanOrEqualTo(44));
          await tester.tap(
            find.descendant(
              of: row(shortcut),
              matching: find.text(
                shortcut == MainNavigationShortcut.follow
                    ? t.comicFollow.title
                    : t.common.download,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<BreezeSwitchListTile>(row(shortcut)).tile.value,
            value,
          );
          expect(tester.takeException(), isNull);
        }

        const follow = MainNavigationShortcut.follow;
        const downloads = MainNavigationShortcut.downloads;
        const left = MainNavigationPosition.left;
        const right = MainNavigationPosition.right;
        const more = MainNavigationPosition.more;
        void expectLayout(
          MainNavigationPosition followPosition,
          MainNavigationPosition downloadsPosition,
        ) {
          final layout = MainNavigationLayout.decode(
            cubit.state.mainNavigationSlots,
          );
          expect(layout.positionOf(follow), followPosition);
          expect(layout.positionOf(downloads), downloadsPosition);
        }

        expect(find.text(t.settings.mainNavigation.title), findsOneWidget);
        expect(find.text(t.settings.mainNavigation.hiddenHint), findsOneWidget);
        expectLayout(right, right);
        cubit.updateState(
          (current) => current.copyWith(mainNavigationSlots: 'left,right'),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<BreezeSwitchListTile>(row(follow)).tile.value,
          isTrue,
        );
        await toggle(downloads, false);
        expectLayout(left, more);
        await toggle(follow, false);
        expectLayout(more, more);
        await toggle(follow, true);
        expectLayout(right, more);
        await toggle(downloads, true);
        expectLayout(right, right);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    for (final brightness in Brightness.values) {
      testWidgets(
        'appearance page keeps its setting usable at 320pt 2x $style ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final cubit = GlobalSettingCubit();
          addTearDown(cubit.close);
          cubit.updateState(
            (current) => current.copyWith(themeMode: ThemeMode.system),
          );
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const AppearanceSettingPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final choice = find.byType(SettingChoice<ThemeMode>);
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          final rect = tester.getRect(choice);
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.height, greaterThanOrEqualTo(44));
          tester
              .widget<NativeVideoMenu>(
                find.descendant(
                  of: choice,
                  matching: find.byType(NativeVideoMenu),
                ),
              )
              .onSelected('2');
          await tester.pumpAndSettle();
          expect(cubit.state.themeMode, ThemeMode.dark);
          expect(tester.getRect(choice), rect);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
      testWidgets(
        'iOS setting choice uses shared host contract $style ${brightness.name}',
        (tester) async {
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final changes = <ThemeMode>[];
          var value = ThemeMode.system;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, update) => ListTile(
                      title: const Text('主题'),
                      trailing: SettingChoice<ThemeMode>(
                        value: value,
                        items: const {
                          ThemeMode.system: '系统',
                          ThemeMode.light: 'Light appearance',
                          ThemeMode.dark: 'Dark',
                        },
                        onChanged: (next) => update(() {
                          value = next;
                          changes.add(next);
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SourceChoiceMenu<ThemeMode>), findsOneWidget);
          final before = tester.getRect(find.byType(SettingChoice<ThemeMode>));
          final menu = tester.widget<NativeVideoMenu>(
            find.byType(NativeVideoMenu),
          );
          expect(menu.hostPresentation, isTrue);
          expect(menu.bare, isTrue);
          menu.onSelected('0');
          await tester.pumpAndSettle();
          expect(
            changes,
            isEmpty,
            reason: 'Selecting the same setting must not save it twice',
          );
          menu.onSelected('1');
          await tester.pumpAndSettle();
          expect(changes, [ThemeMode.light]);
          expect(tester.getRect(find.byType(SettingChoice<ThemeMode>)), before);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  testWidgets('follow-system nullable locale remains a real choice', (
    tester,
  ) async {
    final choices = <Locale?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingChoice<Locale?>(
            value: const Locale('zh'),
            items: {
              null: '跟随系统',
              const Locale('zh'): '中文',
              const Locale('en'): 'English',
            },
            onChanged: choices.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<NativeVideoMenu>(find.byType(NativeVideoMenu))
        .onSelected('0');
    expect(choices, [null]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'selecting a displayed fallback commits the actual eInk setting',
    (tester) async {
      final cubit = GlobalSettingCubit();
      addTearDown(cubit.close);
      cubit.updateEInkSetting(
        (current) =>
            current.copyWith(enabled: true, autoRefreshEveryNTurns: 17),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: EInkSettingPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(t.settings.einkAutoRefreshTurns),
        300,
      );
      await tester.pumpAndSettle();
      final setting = find.byType(SettingChoice<int>);
      expect(tester.widget<SettingChoice<int>>(setting).value, 0);
      expect(cubit.state.eInkSetting.autoRefreshEveryNTurns, 17);
      final menu = tester.widget<NativeVideoMenu>(
        find.descendant(of: setting, matching: find.byType(NativeVideoMenu)),
      );
      menu.onSelected('0');
      await tester.pumpAndSettle();
      expect(cubit.state.eInkSetting.autoRefreshEveryNTurns, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
