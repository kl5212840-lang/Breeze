import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/gesture_lock.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';

import '../test_helper.dart';

class _DesktopPreferenceStore extends InMemorySharedPreferencesStore {
  _DesktopPreferenceStore()
    : super.withData({'flutter.desktop_close_behavior': 'hide'});
  bool reject = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      reject && key == 'flutter.desktop_close_behavior'
      ? Future.value(false)
      : super.setValue(valueType, key, value);
}

Future<void> _draw(WidgetTester tester, List<int> pattern) async {
  final rect = tester.getRect(find.byType(AppGesturePatternBoard));
  Offset point(int index) =>
      rect.topLeft +
      Offset(
        (index % 3 + .5) * rect.width / 3,
        (index ~/ 3 + .5) * rect.height / 3,
      );
  final gesture = await tester.startGesture(point(pattern.first));
  await gesture.moveTo(point(pattern.first) + const Offset(20, 0));
  for (final index in pattern.skip(1)) {
    await gesture.moveTo(point(index));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState();
    objectbox.userSettingBox.put(user);
  });

  Future<GlobalSettingCubit> mount(WidgetTester tester, String style) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = GlobalSettingCubit();
    final preference = ValueNotifier(style);
    addTearDown(settings.close);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: AppInterfaceStyleScope(
          style: preference,
          child: const MaterialApp(home: GlobalSettingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> open(WidgetTester tester, String title) async {
    final entry = find.text(title);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'original app and bookshelf settings survive returning and a fresh cubit $style',
      (tester) async {
        final settings = await mount(tester, style);
        await open(tester, t.settings.appBehavior);
        expect(find.text(t.settings.appBehavior),findsOneWidget);
        expect(find.text(t.settings.oldPageRollback), findsNothing);
        final startup = tester.widget<SettingChoiceTile<String>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SettingChoiceTile<String> &&
                widget.title == t.settings.splashPage,
          ),
        );
        expect(
          startup.items.keys,
          containsAll([
            t.navigation.discover,
            t.navigation.bookshelf,
            t.common.download,
            t.navigation.more,
          ]),
        );
        expect(startup.items, hasLength(4));
        for (final title in [
          t.settings.cloudFavoritePreferred,
          t.settings.autoFollowOnCollect,
          t.settings.leftHandMode,
          t.settings.clickCoverToStartReading,
        ]) {
          final field = find.widgetWithText(SwitchListTile, title);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          tester.widget<SwitchListTile>(field).onChanged!(true);
          await tester.pumpAndSettle();
        }
        await back(tester);
        await open(tester, t.settings.appBehavior);
        for (final title in [
          t.settings.cloudFavoritePreferred,
          t.settings.autoFollowOnCollect,
          t.settings.leftHandMode,
          t.settings.clickCoverToStartReading,
        ]) {
          final field = find.widgetWithText(SwitchListTile, title);
          await tester.ensureVisible(field);
          expect(tester.widget<SwitchListTile>(field).value, isTrue);
        }
        final home = find.byWidgetPredicate(
          (widget) =>
              widget is SettingChoiceTile<int> &&
              widget.title == t.settings.bookshelfHomePage,
        );
        await tester.ensureVisible(home);
        tester.widget<SettingChoiceTile<int>>(home).onChanged(1);
        expect(find.text(t.settings.bookshelfRememberFavoriteSort), findsNothing);
        expect(find.text(t.settings.bookshelfRememberHistorySort), findsNothing);
        await tester.pumpAndSettle();
        await back(tester);
        final cold = GlobalSettingCubit();
        addTearDown(cold.close);
        await cold.initBox();
        expect(cold.state.cloudFavoritePreferred, isTrue);
        expect(cold.state.autoFollowOnCollect, isTrue);
        expect(cold.state.leftHandModeEnabled, isTrue);
        expect(cold.state.clickCoverToStartReading, isTrue);
        expect(cold.state.bookshelfSetting.homePageIndex, 1);
        expect(settings.state.oldPageRollbackEnabled, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'original app-lock setup cancellation, gesture validation and PIN recovery keep durable credentials',
    (tester) async {
      final settings = await mount(tester, 'breeze');
      await open(tester, t.settings.appBehavior);
      final lock = find.widgetWithText(SwitchListTile, t.settings.appLock);
      tester.widget<SwitchListTile>(lock).onChanged!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(settings.state.appLockSetting, const AppLockSettingState());
      tester.widget<SwitchListTile>(lock).onChanged!(true);
      await tester.pumpAndSettle();
      await _draw(tester, [0, 1, 2]);
      expect(find.text(t.gestureLock.setupErrorMinPoints), findsOneWidget);
      await _draw(tester, [0, 1, 2, 5]);
      await _draw(tester, [0, 1, 2, 5]);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.tap(find.text(t.common.ok));
      await tester.pumpAndSettle();
      final credentials = settings.state.appLockSetting;
      expect(credentials.enabled, isTrue);
      expect(credentials.isReady, isTrue);
      expect(credentials.gesturePasswordHash, hashGesturePattern([0, 1, 2, 5]));
      final cold = GlobalSettingCubit();
      addTearDown(cold.close);
      await cold.initBox();
      expect(cold.state.appLockSetting, credentials);

      GestureUnlockResult? result;
      unawaited(
        showGestureUnlockDialog(
          tester.element(lock),
          expectedHash: cold.state.appLockSetting.gesturePasswordHash,
          showForgotPassword: true,
        ).then((value) => result = value),
      );
      await tester.pumpAndSettle();
      await _draw(tester, [0, 1, 2, 4]);
      expect(result, isNull);
      expect(find.text(t.gestureLock.incorrectPassword), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AppGesturePatternBoard), findsOneWidget);
      await _draw(tester, [0, 1, 2, 5]);
      expect(result, GestureUnlockResult.success);
      expect(settings.state.appLockSetting, credentials);

      result = null;
      unawaited(
        showGestureUnlockDialog(
          tester.element(lock),
          expectedHash: credentials.gesturePasswordHash,
          showForgotPassword: true,
        ).then((value) => result = value),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.gestureLock.forgotPassword));
      await tester.pumpAndSettle();
      expect(result, GestureUnlockResult.forgotPassword);

      bool? pin;
      unawaited(
        showPinVerifyDialog(
          tester.element(lock),
          expectedHash: credentials.resetPinHash,
        ).then((value) => pin = value),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text(t.common.ok));
      await tester.pumpAndSettle();
      expect(pin, isNull);
      expect(find.text(t.gestureLock.pinIncorrect), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text(t.common.ok));
      await tester.pumpAndSettle();
      expect(pin, isTrue);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.appLockSetting,
        credentials,
      );
      tester.widget<SwitchListTile>(lock).onChanged!(false);
      await tester.pumpAndSettle();
      expect(settings.state.appLockSetting.enabled, isFalse);
      expect(settings.state.appLockSetting.isReady, isTrue);
      final remove = find.widgetWithText(ListTile, t.common.delete);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(settings.state.appLockSetting.isReady, isTrue);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      await tester.pumpAndSettle();
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.appLockSetting,
        const AppLockSettingState(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop close preference rejects failed persistence without changing the displayed action',
    (tester) async {
      final backend = _DesktopPreferenceStore();
      SharedPreferencesStorePlatform.instance = backend;
      await mount(tester, 'breeze');
      await open(tester, t.settings.appBehavior);
      final field = find.byWidgetPredicate(
        (widget) => widget is SettingChoiceTile<DesktopCloseBehavior>,
      );
      SettingChoiceTile<DesktopCloseBehavior> choice() => tester.widget(field);
      expect(choice().value, DesktopCloseBehavior.hide);
      choice().onChanged(DesktopCloseBehavior.close);
      await tester.pumpAndSettle();
      expect(choice().value, DesktopCloseBehavior.hide);
      expect(choice().enabled, isTrue);
      expect(choice().error, t.error.saveFailed);
      expect(await WindowLogic.loadCloseBehavior(), DesktopCloseBehavior.hide);
      backend.reject = false;
      choice().onChanged(DesktopCloseBehavior.close);
      await tester.pumpAndSettle();
      expect(choice().value, DesktopCloseBehavior.close);
      expect(choice().error, isNull);
      expect(await WindowLogic.loadCloseBehavior(), DesktopCloseBehavior.close);
      expect(tester.takeException(), isNull);
    },
    skip: !(Platform.isMacOS || Platform.isWindows || Platform.isLinux),
  );
}
