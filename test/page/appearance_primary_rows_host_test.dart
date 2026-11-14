import 'package:flutter/cupertino.dart' show CupertinoListSection;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/theme_color/view/theme_color_page.dart';
import 'package:zephyr/page/theme_color/widgets/color_box.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/setting/global/switch_style_setting_page.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/system_accent_availability.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import '../test_helper.dart';
import '../ui_preview_helper.dart';

Future<void> _drainImageReads(WidgetTester tester) async {
  var done = false;
  Object? failure;
  // Start on the widget clock, then give real disk I/O bounded event-loop turns.
  LocalAppearanceImages.instance.load().then(
    (_) => done = true,
    onError: (Object error) {
      failure = error;
      done = true;
    },
  );
  final clock = Stopwatch()..start();
  while (!done && clock.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    done,
    isTrue,
    reason: 'Appearance image reads finish within five seconds',
  );
  expect(failure, isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    // Load actual local services against the isolated path in a real async zone.
    // No disk future from one FakeAsync host may leak into the next host.
    await LocalAppearanceImages.instance.load().timeout(
      const Duration(seconds: 5),
    );
    await CollectionCoverPrivacyController.instance.ensureLoaded();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
  });
  // The real page deliberately owns a process-wide image service. Keep this
  // matrix in one FakeAsync lifetime: otherwise its completed serial futures can
  // retain a prior test clock when the next page registers another disk read.
  testWidgets(
    'appearance primary rows and progressive help: four style/theme hosts',
    (tester) async {
      for (final style in ['system', 'breeze']) {
        for (final brightness in Brightness.values) {
          debugPrint('appearance host: $style ${brightness.name}');
          SharedPreferences.setMockInitialValues({
            '${VideoPlaybackPreferences.prefix}controlsStyle': style,
          });
          final cubit = GlobalSettingCubit();
          const initialSeed = Color(0xffcddc39);
          cubit.updateALl(
            const GlobalSettingState(
              dynamicColor: true,
              seedColor: initialSeed,
              isAMOLED: false,
            ),
          );
          final preference = ValueNotifier(style);
          addTearDown(cubit.close);
          addTearDown(preference.dispose);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget host(double scale, {bool systemAccent = false}) =>
              BlocProvider.value(
                value: cubit,
                child: AppInterfaceStyleScope(
                  style: preference,
                  child: BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
                    builder: (_, state) {
                      final colors = BreezeThemeColors.fromSeed(
                        state.seedColor,
                        brightness,
                      );
                      return MaterialApp(
                        theme: ThemeData(
                          colorScheme: colors,
                          scaffoldBackgroundColor:
                              brightness == Brightness.dark && state.isAMOLED
                              ? Colors.black
                              : colors.surface,
                          fontFamily: uiPreviewDirectory == null
                              ? null
                              : 'AccountPreview',
                        ),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: BreezeControlTheme(
                            // ignore: deprecated_member_use
                            child: MaterialUiCompatibilityBridge(
                              child: RepaintBoundary(
                                key: const ValueKey('appearance.preview'),
                                child: child!,
                              ),
                            ),
                          ),
                        ),
                        home: SystemAccentAvailability(
                          available: systemAccent,
                          child: const AppearanceSettingPage(),
                        ),
                      );
                    },
                  ),
                ),
              );
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpWidget(host(1));
          await tester.pumpAndSettle();
          await _drainImageReads(tester);
          expect(find.text(t.settings.dynamicColor), findsNothing);
          expect(find.text(t.settings.themeColor), findsOneWidget);
          final initialColors = Theme.of(
            tester.element(find.byType(SettingSection).first),
          ).colorScheme;
          void expectContentPalette(ColorScheme colors, {bool amoled = false}) {
            final page = amoled ? Colors.black : colors.surface;
            expect(
              tester
                  .widget<Scaffold>(find.byType(Scaffold).first)
                  .backgroundColor,
              page,
            );
            if (style == 'system') {
              final group = tester.widget<CupertinoListSection>(
                find.byType(CupertinoListSection).first,
              );
              expect(group.backgroundColor, page);
              expect(group.decoration?.color, colors.surfaceContainerLow);
            } else {
              expect(
                tester.widget<Card>(find.byType(Card).first).color,
                colors.surfaceContainerLow,
              );
            }
          }

          expectContentPalette(initialColors);
          final toggle = find.byType(Switch).first;
          final switchTheme = Theme.of(tester.element(toggle));
          final symbols = tester.widget<Switch>(toggle).thumbIcon!;
          for (final states in <Set<WidgetState>>[
            {},
            {WidgetState.selected},
          ]) {
            expect(
              BreezeThemeColors.contrast(
                symbols.resolve(states)!.color!,
                Colors.white,
              ),
              greaterThanOrEqualTo(4.5),
            );
          }
          final adaptation = switchTheme.getAdaptation<SwitchThemeData>();
          if (style == 'system') {
            expect(adaptation, isNull);
          } else {
            final fill = adaptation!
                .adapt(switchTheme, const SwitchThemeData())
                .trackColor!
                .resolve({WidgetState.selected});
            expect(fill, isNotNull);
            expect(
              BreezeThemeColors.contrast(fill!, Colors.white),
              greaterThanOrEqualTo(4.5),
            );
          }
          await writeUiPreview(
            tester,
            const ValueKey('appearance.preview'),
            'settings-appearance-lime-$style-${brightness.name}',
          );
          if (brightness == Brightness.dark) {
            cubit.updateState((state) => state.copyWith(isAMOLED: true));
            await tester.pumpAndSettle();
            expectContentPalette(initialColors, amoled: true);
            cubit.updateState((state) => state.copyWith(isAMOLED: false));
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(host(1, systemAccent: true));
          await tester.pumpAndSettle();
          expect(find.text(t.settings.dynamicColor), findsOneWidget);
          expect(find.text(t.settings.dynamicColorSubtitle), findsOneWidget);
          expect(find.text(t.settings.themeColor), findsNothing);
          await tester.pumpWidget(host(1));
          await tester.pumpAndSettle();
          for (final description in [
            t.settings.languageSubtitle,
            t.settings.themeSubtitle,
            t.settings.fontSettingsSubtitle,
            t.settings.themeColorSubtitle,
          ]) {
            expect(find.text(description), findsNothing);
          }
          final primary = tester.widget<SettingSection>(
            find.byType(SettingSection).first,
          );
          expect(primary.title, isEmpty);
          expect(primary.footer, isNull);
          expect(primary.details, isEmpty);
          expect(find.byType(SettingDetailsNotes), findsNothing);
          expect(find.text(t.settings.interfaceStyleHint), findsNothing);
          final display = tester
              .widgetList<SettingSection>(find.byType(SettingSection))
              .singleWhere(
                (section) => section.title == t.settings.appearanceOptions,
              );
          expect(display.details, isEmpty);
          expect(display.footer, t.settings.amoledSubtitle);
          expect(primary.children.length, 6);
          final styleEntry = find.byKey(
            const ValueKey('settings.switch-style'),
          );
          expect(styleEntry, findsOneWidget);
          await tester.ensureVisible(styleEntry);
          await tester.tap(styleEntry);
          await tester.pumpAndSettle();
          final stylePage = find.byType(SwitchStyleSettingPage);
          expect(stylePage, findsOneWidget);
          final pixel = find.byKey(
            const ValueKey('settings.switch-style.pixel'),
          );
          await tester.ensureVisible(pixel);
          await tester.tap(pixel);
          await tester.pumpAndSettle();
          expect(cubit.state.switchStyle, BreezeSwitchStyle.pixel);
          Navigator.of(tester.element(stylePage)).pop();
          await tester.pumpAndSettle();
          expect(stylePage, findsNothing);

          Finder settingRow(String title) => find.ancestor(
            of: find.text(title),
            matching: find.byType(ListTile),
          );
          for (final title in [t.settings.amoled, t.coverPrivacy.enable]) {
            final row = settingRow(title);
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: row,
                matching: find.byKey(const ValueKey('breeze.switch.paint')),
              ),
              findsOneWidget,
            );
          }
          expect(preference.value, style);
          expectContentPalette(initialColors);
          if (uiPreviewDirectory != null) {
            final imageContext = tester.element(settingRow(t.settings.amoled));
            await tester.runAsync(() async {
              for (final state in ['off', 'on']) {
                await precacheImage(
                  AssetImage('asset/image/switch_style/lamp-$state.jpg'),
                  imageContext,
                );
              }
            });
            await tester.ensureVisible(styleEntry);
            await tester.pumpAndSettle();
            await writeUiPreview(
              tester,
              const ValueKey('appearance.preview'),
              'global-pixel-$style-${brightness.name}',
            );
          }
          await tester.ensureVisible(settingRow(t.settings.amoled));
          await tester.tap(settingRow(t.settings.amoled));
          await tester.pumpAndSettle();
          expect(cubit.state.isAMOLED, isTrue);
          cubit.updateState(
            (state) => state.copyWith(
              isAMOLED: false,
              switchStyle: BreezeSwitchStyle.classic,
            ),
          );
          await tester.pumpAndSettle();
          if (styleEntry.evaluate().isEmpty) {
            await tester.scrollUntilVisible(styleEntry, -200);
          } else {
            await tester.ensureVisible(styleEntry);
          }
          await tester.pumpAndSettle();
          final choices = tester.widgetList<SettingChoiceTile>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SettingChoiceTile &&
                  [
                    t.settings.language,
                    t.settings.theme,
                    t.settings.interfaceStyle,
                  ].contains(widget.title),
            ),
          );
          expect(choices.length, 3);
          for (final choice in choices) {
            expect(choice.description, isNull);
          }
          final colorEntry = find.text(t.settings.themeColor);
          await tester.ensureVisible(colorEntry);
          await tester.pumpAndSettle();
          await tester.tap(colorEntry);
          await tester.pumpAndSettle();
          expect(find.byType(ThemeColorPage), findsOneWidget);
          final swatch = tester
              .widgetList<ColorThemeItem>(find.byType(ColorThemeItem))
              .firstWhere(
                (item) =>
                    item.colorInfo.color.toARGB32() !=
                    cubit.state.seedColor.toARGB32(),
              );
          swatch.onColorSelected(swatch.colorInfo.color);
          await tester.pumpAndSettle();
          expect(
            objectbox.userSettingBox.get(1)!.globalSetting.seedColor.toARGB32(),
            swatch.colorInfo.color.toARGB32(),
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(AppearanceSettingPage), findsOneWidget);
          final preview = find.byKey(
            const ValueKey('appearance.theme-color-preview'),
          );
          final decoration =
              tester.widget<DecoratedBox>(preview).decoration as BoxDecoration;
          expect(
            decoration.color?.toARGB32(),
            swatch.colorInfo.color.toARGB32(),
          );
          final updatedColors = Theme.of(tester.element(preview)).colorScheme;
          expect(updatedColors.surface, isNot(initialColors.surface));
          expectContentPalette(updatedColors);
          expect(tester.getSize(preview), const Size.square(22));
          final languageEntry = find.text(t.settings.language);
          if (languageEntry.evaluate().isEmpty) {
            await tester.scrollUntilVisible(languageEntry, -200);
          } else {
            await tester.ensureVisible(languageEntry);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await writeUiPreview(
            tester,
            const ValueKey('appearance.preview'),
            'settings-appearance-normal-$style-${brightness.name}',
          );

          tester.view.physicalSize = const Size(320, 760);
          await tester.pumpWidget(host(2));
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('appearance.preview'),
            'settings-appearance-large-$style-${brightness.name}',
          );
          expect(find.byType(SettingDetailsNotes), findsNothing);
          expect(find.text(t.settings.dynamicColorSubtitle), findsNothing);
          expect(find.text(t.settings.notchAdaptationSubtitle), findsNothing);
          await tester.scrollUntilVisible(
            find.text(t.coverPrivacy.localOnly),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text(t.coverPrivacy.customEmpty), findsNothing);
          expect(tester.takeException(), isNull);
          await _drainImageReads(tester);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
