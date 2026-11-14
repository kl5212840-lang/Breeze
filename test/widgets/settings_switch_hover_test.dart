import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

List<InteractiveInkFeature> _features(WidgetTester tester, Finder row) {
  final ink = find.descendant(of: row, matching: find.byType(InkWell)).first;
  final dynamic material = Material.of(tester.element(ink));
  return (material.debugInkFeatures as List<InkFeature>? ?? [])
      .whereType<InteractiveInkFeature>()
      .toList();
}

List<InkHighlight> _hoverInk(WidgetTester tester, Finder row) => _features(
  tester,
  row,
).whereType<InkHighlight>().where((feature) => feature.active).toList();

void _expectIdle(WidgetTester tester, Finder row) {
  final highlights = _hoverInk(tester, row);
  expect(
    highlights,
    isNotEmpty,
    reason: 'The row really receives passive hover',
  );
  expect(highlights.every((feature) => feature.color.a == 0), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  const capacity = MethodChannel('breeze.download.capacity');
  const hls = MethodChannel('breeze.video.hls');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(capacity, (_) async => 1000000000);
    messenger.setMockMethodCallHandler(hls, (_) async => const []);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final channel = MethodChannel(
          'breeze.video.control.${(call.arguments as Map)['id']}',
        );
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(capacity, null);
    messenger.setMockMethodCallHandler(hls, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'actual download setting switch keeps its true value and feedback without passive row hover, $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(390, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final cubit = GlobalSettingCubit();
          final preference = ValueNotifier(style);
          addTearDown(cubit.close);
          addTearDown(preference.dispose);
          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  navigatorKey: navigator,
                  theme: ThemeData(brightness: brightness),
                  builder: (_, child) => TouchHoverIntentScope(child: child!),
                  home: const Scaffold(body: SizedBox.expand()),
                ),
              ),
            ),
          );
          void open() => unawaited(
            navigator.currentState!.push<void>(
              videoPageRoute(
                settings: const RouteSettings(name: 'hover.download-settings'),
                builder: (_) => const DownloadSettingsPage(),
              ),
            ),
          );
          final row = find.widgetWithText(
            SwitchListTile,
            t.settings.retryDownloadUntilSuccess,
          );
          open();
          await tester.pumpAndSettle();
          expect(row.hitTestable(), findsOneWidget);
          final position = tester.getCenter(row);
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: position);
          open();
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(row).value, isTrue);
          expect(cubit.state.retryDownloadUntilSuccess, isTrue);
          final control = find.descendant(
            of: row,
            matching: find.byType(Switch),
          );
          final element = tester.element(control);
          expect(tester.widget<Switch>(control).value, isTrue);
          _expectIdle(tester, row);
          await mouse.moveTo(position + const Offset(2, 0));
          await tester.pumpAndSettle();
          expect(
            _hoverInk(tester, row).any((feature) => feature.color.a > 0),
            isTrue,
          );
          final press = await tester.startGesture(position);
          await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
          expect(
            _features(tester, row).any((feature) => feature.color.a > 0),
            isTrue,
          );
          await press.cancel();
          await tester.pumpAndSettle();
          expect(cubit.state.retryDownloadUntilSuccess, isTrue);
          _expectIdle(tester, row);
          // Use the real row's tap handler, not the fixture's callback.
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(cubit.state.retryDownloadUntilSuccess, isFalse);
          expect(tester.widget<SwitchListTile>(row).value, isFalse);
          expect(tester.widget<Switch>(control).value, isFalse);
          expect(tester.element(control), same(element));
          _expectIdle(tester, row);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
