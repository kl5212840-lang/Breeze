import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';
import 'package:zephyr/page/discover/view/plugin_visibility_sheet.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/setting/global/switch_style_setting_page.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _paintKey = ValueKey('breeze.switch.paint');
const _particleKey = ValueKey('breeze.switch.spark.particles');
const _trialKey = ValueKey('settings.switch-style.trial');
const _ordinaryKey = ValueKey('switch-host.ordinary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await LocalAppearanceImages.instance.load();
    await CollectionCoverPrivacyController.instance.ensureLoaded();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('old or unknown saved switch styles use classic', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'switchStyle': 'futureStyle'},
    ]) {
      expect(
        GlobalSettingState.fromJson(json).switchStyle,
        BreezeSwitchStyle.classic,
      );
    }
  });

  testWidgets('Android keeps the same appearance options across styles', (
    tester,
  ) async {
    final cubit = GlobalSettingCubit();
    final style = ValueNotifier('system');
    addTearDown(cubit.close);
    addTearDown(style.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: const AppearanceSettingPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('settings.switch-style'));
    final font = find.text(t.settings.fontSettings);
    final displaySection = find.ancestor(
      of: font,
      matching: find.byType(SettingSection),
    );
    final amoled = find.ancestor(
      of: find.text(t.settings.amoled),
      matching: find.byType(ListTile),
    );
    final paint = find.descendant(of: amoled, matching: find.byKey(_paintKey));
    final groups = find.byType(SettingSection);
    List<String> headings() => tester
        .widgetList<SettingSection>(groups)
        .map((section) => section.title)
        .toList();

    expect(entry, findsOneWidget);
    expect(paint, findsNothing);
    final systemHeadings = headings();
    expect(
      tester.widget<SettingSection>(displaySection).title,
      t.settings.appearanceOptions,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final picker = find.byType(SwitchStyleSettingPage);
    expect(picker, findsOneWidget);
    expect(
      find.byType(ListTile).evaluate().where((element) {
        final key = element.widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('settings.switch-style.') &&
            key != _trialKey;
      }).length,
      BreezeSwitchStyle.values.length,
    );
    await tester.tap(find.byKey(const ValueKey('settings.switch-style.ring')));
    await tester.pumpAndSettle();
    expect(cubit.state.switchStyle, BreezeSwitchStyle.ring);
    Navigator.of(tester.element(picker)).pop();
    await tester.pumpAndSettle();
    expect(paint, findsOneWidget);

    style.value = 'breeze';
    await tester.pumpAndSettle();
    expect(headings(), systemHeadings);
    expect(entry, findsOneWidget);
    expect(
      tester.widget<SettingSection>(displaySection).title,
      t.settings.appearanceOptions,
    );
    expect(paint, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('appearance entry, preview, real switch and platform boundary', (
    tester,
  ) async {
    final cubit = GlobalSettingCubit()
      ..applySyncedState(const GlobalSettingState());
    final style = ValueNotifier('breeze');
    addTearDown(cubit.close);
    addTearDown(style.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Widget host({
      Widget home = const AppearanceSettingPage(),
      Brightness brightness = Brightness.light,
      Color seed = const Color(0xffcddc39),
      TextDirection direction = TextDirection.ltr,
      double scale = 1,
      bool reduceMotion = false,
    }) => BlocProvider.value(
      value: cubit,
      child: AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            colorScheme: BreezeThemeColors.fromSeed(seed, brightness),
            fontFamily: uiPreviewDirectory == null ? null : 'AccountPreview',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: Directionality(
              textDirection: direction,
              child: BreezeControlTheme(
                // ignore: deprecated_member_use
                child: MaterialUiCompatibilityBridge(
                  child: RepaintBoundary(
                    key: const ValueKey('switch-host.preview'),
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
          home: Directionality(textDirection: direction, child: home),
        ),
      ),
    );

    final trial = find.byKey(_trialKey);
    final trialSwitch = find.descendant(
      of: trial,
      matching: find.byType(Switch),
    );
    final paint = find.descendant(of: trial, matching: find.byKey(_paintKey));
    final switchRow = find.byKey(const ValueKey('settings.switch-style'));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(reduceMotion: true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(switchRow);
      await tester.tap(switchRow);
      await tester.pumpAndSettle();
      final page = find.byType(SwitchStyleSettingPage);
      expect(page, findsOneWidget);
      // Flutter's test clock does not advance the image codec. Wait for
      // both bundled sprites before recording the actual settings preview.
      final previewContext = tester.element(page);
      await tester.runAsync(() async {
        for (final state in ['off', 'on']) {
          await precacheImage(
            AssetImage('asset/image/switch_style/lamp-$state.jpg'),
            previewContext,
          );
        }
      });
      expect(tester.widget<Switch>(trialSwitch).value, isFalse);

      for (final choice in BreezeSwitchStyle.values) {
        final row = find.byKey(
          ValueKey('settings.switch-style.${choice.name}'),
        );
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(cubit.state.switchStyle, choice);
        expect(globalSetting.switchStyle, choice);
        final afterSelection = cubit.state;
        expect(tester.widget<Switch>(trialSwitch).value, isFalse);
        await tester.ensureVisible(trial);
        // Touching the row and touching the switch itself must each toggle once.
        await tester.tapAt(tester.getTopLeft(trial) + const Offset(28, 24));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(trialSwitch).value, isTrue);
        if (choice != BreezeSwitchStyle.classic) {
          expect(paint, findsOneWidget);
          expect(
            tester.getSemantics(trial).flagsCollection.isToggled,
            Tristate.isTrue,
          );
          switch (choice) {
            case BreezeSwitchStyle.symbols:
              expect(
                paint,
                paints
                  ..path()
                  ..path()
                  ..circle(x: 39),
              );
            case BreezeSwitchStyle.ring:
              expect(
                paint,
                paints
                  ..circle(radius: 15 * 52 / 70)
                  ..circle(radius: 7.5 * 52 / 70),
              );
            case BreezeSwitchStyle.relief:
              expect(
                paint,
                paints
                  ..clipRRect()
                  ..drrect()
                  ..circle(hasMaskFilter: true)
                  ..circle(),
              );
            case BreezeSwitchStyle.pixel:
              final sprites = find.descendant(
                of: paint,
                matching: find.byType(RawImage),
              );
              expect(sprites, findsNWidgets(2));
              for (final sprite in tester.widgetList<RawImage>(sprites)) {
                expect(sprite.image?.width, 16);
                expect(sprite.image?.height, 16);
                expect(sprite.fit, BoxFit.fill);
              }
            case BreezeSwitchStyle.thumb:
              expect(
                paint,
                paints
                  ..rrect()
                  ..rrect(style: PaintingStyle.stroke)
                  ..circle()
                  ..path(),
              );
            case BreezeSwitchStyle.power:
              expect(
                paint,
                paints
                  ..circle(hasMaskFilter: true)
                  ..rrect()
                  ..path(),
              );
            case BreezeSwitchStyle.spark:
              expect(
                paint,
                paints
                  ..rrect()
                  ..circle()
                  ..path(),
              );
              expect(
                find.descendant(of: trial, matching: find.byKey(_particleKey)),
                paints
                  ..clipRRect()
                  ..rrect(),
              );
            case BreezeSwitchStyle.classic:
              break;
          }
        }
        await writeUiPreview(
          tester,
          const ValueKey('switch-host.preview'),
          'switch-style-${choice.name}-light',
        );
        await tester.tap(trialSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(trialSwitch).value, isFalse);
        expect(cubit.state, same(afterSelection));
      }
      await tester.tap(trialSwitch);
      await tester.pumpAndSettle();
      for (final name in ['ring', 'pixel']) {
        final row = find.byKey(ValueKey('settings.switch-style.$name'));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(trialSwitch).value, isTrue);
      }
      final persisted = GlobalSettingCubit();
      addTearDown(persisted.close);
      await persisted.initBox();
      expect(persisted.state.switchStyle, BreezeSwitchStyle.pixel);

      Navigator.of(tester.element(trial)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(SwitchStyleSettingPage), findsNothing);
      expect(
        find.descendant(
          of: switchRow,
          matching: find.text(switchStyleLabel(BreezeSwitchStyle.pixel)),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Theme/style changes and a narrow translated route must preserve the
      // selected style and keep the interactive preview independent.
      tester.view.physicalSize = const Size(320, 800);
      for (final brightness in Brightness.values) {
        final rtl = brightness == Brightness.dark;
        final options = host(
          home: const SwitchStyleSettingPage(),
          brightness: brightness,
          seed: rtl ? const Color(0xff482d86) : const Color(0xff00ffed),
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
          scale: 2,
          reduceMotion: rtl,
        );
        await tester.pumpWidget(options);
        await tester.pumpAndSettle();
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(trial, 80, scrollable: scroll);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final initial = tester.widget<Switch>(trialSwitch).value;
        // PhyoTP's rail is 0.3em of a 4em track. The two 2em sprites
        // move together and only the lit layer fades in.
        final lamp = find.descendant(
          of: paint,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName.endsWith('/lamp-on.jpg'),
          ),
        );
        expect(
          paint,
          paints..rect(rect: const Rect.fromLTWH(0, 13.05, 52, 3.9)),
        );
        void expectThumb(bool on) {
          final sprite = tester.getRect(lamp);
          expect(sprite.size, const Size(26, 26));
          expect(
            sprite.left - tester.getTopLeft(paint).dx,
            closeTo(on != rtl ? 26 : 0, .01),
          );
          final fade = find.ancestor(of: lamp, matching: find.byType(Opacity));
          expect(tester.widget<Opacity>(fade.first).opacity, on ? 1 : 0);
        }

        expectThumb(initial);
        await tester.tap(trialSwitch);
        await tester.pump();
        if (rtl) {
          expectThumb(!initial);
        } else {
          await tester.pump(const Duration(milliseconds: 200));
          final moved =
              tester.getTopLeft(lamp).dx - tester.getTopLeft(paint).dx;
          expect(moved, inExclusiveRange(0, 26));
          await tester.pump(const Duration(milliseconds: 200));
          expectThumb(!initial);
        }
        await tester.pumpAndSettle();
        expectThumb(!initial);
        await tester.tap(trialSwitch);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(trialSwitch);
        await tester.pumpAndSettle();
        expectThumb(!initial);
        expect(cubit.state.switchStyle, BreezeSwitchStyle.pixel);
        await writeUiPreview(
          tester,
          const ValueKey('switch-host.preview'),
          'switch-style-${brightness.name}-narrow',
        );
      }

      style.value = 'system';
      for (final choice in [
        BreezeSwitchStyle.symbols,
        BreezeSwitchStyle.ring,
        BreezeSwitchStyle.relief,
        BreezeSwitchStyle.thumb,
        BreezeSwitchStyle.power,
        BreezeSwitchStyle.spark,
      ]) {
        cubit.updateState((state) => state.copyWith(switchStyle: choice));
        await tester.pumpWidget(
          host(
            home: const SwitchStyleSettingPage(),
            brightness: Brightness.dark,
            seed: const Color(0xff21b3db),
            direction: TextDirection.rtl,
            scale: 2,
            reduceMotion: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await writeUiPreview(
          tester,
          const ValueKey('switch-host.preview'),
          'switch-style-${choice.name}-dark-system-rtl',
        );
      }
      cubit.updateState(
        (state) => state.copyWith(switchStyle: BreezeSwitchStyle.pixel),
      );

      style.value = 'breeze';
      var changes = 0;
      final original = Switch.adaptive(
        value: true,
        onChanged: (_) => changes++,
      );
      final ordinary = host(
        home: Scaffold(
          body: Center(child: BreezeSwitch(key: _ordinaryKey, original)),
        ),
      );
      await tester.pumpWidget(ordinary);
      await tester.pumpAndSettle();
      expect(find.byKey(_paintKey), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_ordinaryKey)),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(changes, 0);
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(find.byKey(_paintKey), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)), same(original));
      await tester.tap(find.byKey(_ordinaryKey));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(cubit.state.switchStyle, BreezeSwitchStyle.pixel);

      final preferences = DiscoverPluginVisibility(
        read: () async => [],
        write: (_) async => true,
      );
      addTearDown(preferences.dispose);
      await preferences.load();
      await tester.pumpWidget(
        host(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => PluginVisibilitySheet(
                    plugins: const [
                      DiscoverPluginVisibilityOption(id: 'a', title: 'Plugin'),
                    ],
                    preferences: preferences,
                  ),
                ),
                child: const Text('Open plugins'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open plugins'));
      await tester.pumpAndSettle();
      final pluginRow = find.byKey(const ValueKey('discover.visibility.a'));
      final pluginPaint = find.descendant(
        of: pluginRow,
        matching: find.byKey(_paintKey),
      );
      expect(pluginPaint, findsOneWidget);
      await tester.tap(pluginRow);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(pluginRow).flagsCollection.isToggled,
        Tristate.isFalse,
      );
      expect(preferences.hiddenIds, isEmpty);
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
      expect(preferences.hiddenIds, {'a'});
      expect(style.value, 'system');
      expect(cubit.state.switchStyle, BreezeSwitchStyle.pixel);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('spark drifts and warps in the live settings preview', (
    tester,
  ) async {
    final cubit = GlobalSettingCubit()
      ..updateState(
        (state) => state.copyWith(switchStyle: BreezeSwitchStyle.spark),
      );
    addTearDown(cubit.close);
    final visibility = VisibilityDetectorController.instance;
    final previousInterval = visibility.updateInterval;
    visibility.updateInterval = Duration.zero;
    addTearDown(() => visibility.updateInterval = previousInterval);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Widget host({bool reduceMotion = false}) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const SwitchStyleSettingPage(),
      ),
    );
    final trial = find.byKey(_trialKey);
    final layer = find.descendant(
      of: trial,
      matching: find.byKey(_particleKey),
    );
    final control = find.descendant(of: trial, matching: find.byType(Switch));
    List<RRect> particles() {
      final shapes = <RRect>[];
      expect(
        layer,
        paints..everything((symbol, args) {
          if (symbol == #drawRRect) shapes.add(args.first as RRect);
          return true;
        }),
      );
      return shapes;
    }

    await tester.pumpWidget(host());
    await tester.ensureVisible(trial);
    await tester.pump();
    visibility.notifyNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    expect(tester.widget<Switch>(control).value, isFalse);
    final dots = particles();
    expect(dots, hasLength(4));
    for (final dot in dots) {
      expect(dot.width, closeTo(dot.height, .001));
    }

    final boundary =
        tester.renderObject(layer).parent! as RenderRepaintBoundary;
    boundary.debugResetMetrics();
    await tester.pump(const Duration(milliseconds: 150));
    expect(particles(), isNot(dots));
    expect(boundary.debugAsymmetricPaintCount, greaterThan(0));
    expect(boundary.debugSymmetricPaintCount, 0);

    await tester.tap(control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 470));
    expect(tester.widget<Switch>(control).value, isTrue);
    final streaks = particles();
    expect(streaks, hasLength(4));
    expect(
      streaks.every((streak) => streak.width > 10 * streak.height),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(particles(), isNot(streaks));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final paused = particles();
    await tester.pump(const Duration(milliseconds: 400));
    expect(particles(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(particles(), isNot(paused));

    // The preview contains two samples plus the trial control. Scroll the
    // whole section away while keeping it inside the list's cache extent.
    expect(find.byKey(_particleKey), findsNWidgets(3));
    tester.view.physicalSize = const Size(390, 390);
    await tester.pump();
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(0);
    await tester.pump();
    visibility.notifyNow();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, 0);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.ensureVisible(trial);
    await tester.pump();

    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pumpAndSettle();
    final staticStreaks = particles();
    await tester.pump(const Duration(seconds: 1));
    expect(particles(), staticStreaks);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
