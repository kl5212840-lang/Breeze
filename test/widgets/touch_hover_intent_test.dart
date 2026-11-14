import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/more/view/more.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

Finder _ink(Finder control) =>
    find.descendant(of: control, matching: find.byType(InkWell)).first;

// Inspect the features actually registered for Material's ink painting, not
// just the widget's configured color (which can still fall back to a theme).
List<InkHighlight> _highlights(WidgetTester tester, Finder control) {
  final dynamic material = Material.of(tester.element(_ink(control)));
  final features = material.debugInkFeatures as List<InkFeature>?;
  return (features ?? <InkFeature>[])
      .whereType<InkHighlight>()
      .where((feature) => feature.active)
      .toList();
}

void _expectIdleInk(WidgetTester tester, Finder control) {
  final highlights = _highlights(tester, control);
  expect(
    highlights,
    isNotEmpty,
    reason: 'The stationary pointer really hovers',
  );
  expect(highlights.every((feature) => feature.color.a == 0), isTrue);
}

void _expectVisibleInk(WidgetTester tester, Finder control) => expect(
  _highlights(tester, control).any((feature) => feature.color.a > 0),
  isTrue,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  testWidgets(
    'Breeze setting value only highlights after deliberate pointer movement',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: TouchHoverIntentScope(
              child: Scaffold(
                body: Column(
                  children: [
                    SettingChoiceTile<int>(
                      title: '自动隐藏',
                      value: 5,
                      items: const {3: '3 秒', 5: '5 秒'},
                      onChanged: (_) {},
                    ),
                    const SizedBox(
                      key: ValueKey('outside-setting'),
                      height: 100,
                      width: 200,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final value = find.byType(SourceChoiceMenu<int>);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final center = tester.getCenter(value);
      await mouse.addPointer(location: center);
      await tester.pumpAndSettle();
      _expectIdleInk(tester, value);
      await mouse.moveTo(center + const Offset(2, 0));
      await tester.pumpAndSettle();
      _expectVisibleInk(tester, value);
      final elsewhere = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('outside-setting'))),
      );
      await elsewhere.cancel();
      await tester.pumpAndSettle();
      _expectIdleInk(tester, value);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final settings in [true, false]) {
        testWidgets(
          '${settings ? 'Settings storage' : 'More changelog'} paints no passive hover on arrival or return, $style $brightness',
          (tester) async {
            tester.view.physicalSize = const Size(430, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            final router = RootStackRouter.build(
              routes: [
                NamedRouteDef(
                  name: 'Home',
                  path: '/',
                  initial: true,
                  builder: (_, _) => const Scaffold(body: SizedBox.expand()),
                ),
                NamedRouteDef(
                  name: 'GlobalSettingRoute',
                  path: '/settings',
                  builder: (_, _) => const GlobalSettingPage(),
                ),
                NamedRouteDef(
                  name: 'MoreRoute',
                  path: '/more',
                  builder: (_, _) => const MorePage(),
                ),
                for (final name in ['StorageSettingRoute', 'ChangelogRoute'])
                  NamedRouteDef(
                    name: name,
                    path: '/$name',
                    builder: (_, _) =>
                        const Scaffold(body: Text('destination fixture')),
                  ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => GlobalSettingCubit()),
                  BlocProvider(create: (_) => ComicFollowCubit()),
                ],
                child: AppInterfaceStyleScope(
                  style: preference,
                  child: MaterialApp.router(
                    theme: ThemeData(brightness: brightness),
                    routerConfig: router.config(),
                    builder: (_, child) => TouchHoverIntentScope(child: child!),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            void open() => unawaited(
              router.push<void>(
                PageRouteInfo<void>(
                  settings ? 'GlobalSettingRoute' : 'MoreRoute',
                ),
              ),
            );
            final target = find.widgetWithText(
              ListTile,
              settings ? t.settings.storage : t.more.changelog,
            );
            open();
            await tester.pumpAndSettle();
            expect(target.hitTestable(), findsOneWidget);
            final position = tester.getCenter(target);
            router.pop();
            await tester.pumpAndSettle();
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            addTearDown(mouse.removePointer);
            await mouse.addPointer(location: position);
            open();
            await tester.pumpAndSettle();
            _expectIdleInk(tester, target);
            await mouse.moveTo(position + const Offset(2, 0));
            await tester.pumpAndSettle();
            _expectVisibleInk(tester, target);
            // The real row callback opens its existing navigation destination.
            // No action is invoked by merely entering under the pointer.
            expect(find.text('destination fixture'), findsNothing);
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(find.text('destination fixture'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            _expectIdleInk(tester, target);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  testWidgets(
    'touch elsewhere and a new control identity clear hover; press, cancel, keyboard focus and mouse remain visible',
    (tester) async {
      final identity = ValueNotifier('one');
      final focus = FocusNode();
      addTearDown(identity.dispose);
      addTearDown(focus.dispose);
      var clicks = 0;
      var parentDowns = 0;
      const key = ValueKey('intent-button');
      final target = find.byKey(key);
      final style = TextButton.styleFrom(foregroundColor: Colors.blue);
      await tester.pumpWidget(
        MaterialApp(
          home: Listener(
            onPointerDown: (_) => parentDowns++,
            child: TouchHoverIntentScope(
              child: Scaffold(
                body: Column(
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: identity,
                      builder: (_, id, _) => TouchHoverIntent(
                        identity: id,
                        builder: (_, hover) => TextButton(
                          key: key,
                          focusNode: focus,
                          style: style.copyWith(
                            overlayColor: hover.overlayColor(
                              style.overlayColor,
                            ),
                          ),
                          onPressed: () => clicks++,
                          child: Text(id),
                        ),
                      ),
                    ),
                    const SizedBox(
                      key: ValueKey('outside'),
                      height: 100,
                      width: 200,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final position = tester.getCenter(target);
      await mouse.addPointer(location: position);
      await tester.pumpAndSettle();
      _expectIdleInk(tester, target);
      await mouse.moveTo(position + const Offset(2, 0));
      await tester.pumpAndSettle();
      _expectVisibleInk(tester, target);
      identity.value = 'two';
      await tester.pumpAndSettle();
      _expectIdleInk(tester, target);
      await mouse.moveTo(position + const Offset(3, 0));
      await tester.pumpAndSettle();
      _expectVisibleInk(tester, target);
      final elsewhere = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('outside'))),
      );
      await elsewhere.cancel();
      await tester.pumpAndSettle();
      _expectIdleInk(tester, target);
      expect(parentDowns, 1, reason: 'The app observer must not consume input');
      final press = await tester.startGesture(position);
      await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
      final ink = tester.widget<InkWell>(_ink(target));
      expect(ink.statesController!.value, contains(WidgetState.pressed));
      final dynamic material = Material.of(tester.element(_ink(target)));
      expect(
        (material.debugInkFeatures as List<InkFeature>)
            .whereType<InteractiveInkFeature>()
            .any((feature) => feature.color.a > 0),
        isTrue,
      );
      await press.cancel();
      await tester.pumpAndSettle();
      expect(clicks, 0);
      _expectIdleInk(tester, target);
      final strategy = FocusManager.instance.highlightStrategy;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      focus.requestFocus();
      await tester.pumpAndSettle();
      _expectVisibleInk(tester, target);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(clicks, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'desktop preserves stationary hover even with an iOS-themed control',
    (tester) async {
      final target = find.text('desktop row');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: TouchHoverIntentScope(
              child: TouchHoverIntent(
                builder: (_, hover) => ListTile(
                  hoverColor: hover.hoverColor(),
                  title: const Text('desktop row'),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(target));
      await tester.pumpAndSettle();
      _expectVisibleInk(tester, find.byType(ListTile));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
