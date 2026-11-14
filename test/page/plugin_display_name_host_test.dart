import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/discover/widgets/plugin_icon_veil.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_display_name_tile.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 50 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: 'alias-source',
        version: 'fixture',
        originScript: '',
        insertedAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        isEnabled: true,
        isDeleted: false,
        debug: false,
        lastLoadSuccess: true,
        getInfoJson: jsonEncode({'name': 'Original plugin', 'iconUrl': ''}),
      ),
    );
  });

  testWidgets('plugin icon veil fades inside fixed artwork bounds', (
    tester,
  ) async {
    final icon = find.byKey(const ValueKey('source-icon'));
    Future<void> mount(bool enabled, {bool reduceMotion = false}) =>
        tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Center(
              child: SizedBox.square(
                dimension: 56,
                child: PluginIconVeil(
                  key: const ValueKey('source-icon'),
                  radius: 12,
                  enabled: enabled,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );
    double opacity() {
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: icon,
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is DecoratedBox &&
                            widget.position == DecorationPosition.foreground,
                      ),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      return decoration.color!.a;
    }

    double scale() => tester
        .widget<AnimatedScale>(
          find.descendant(of: icon, matching: find.byType(AnimatedScale)),
        )
        .scale;

    await mount(true);
    expect(scale(), 1);
    final bounds = tester.getRect(icon);
    expect(opacity(), 0);
    await mount(false);
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(), inExclusiveRange(0, .32));
    await tester.pumpAndSettle();
    expect(opacity(), closeTo(.32, .001));
    expect(scale(), lessThan(1));
    expect(tester.getRect(icon), bounds);
    await mount(true, reduceMotion: true);
    await tester.pump();
    expect(opacity(), 0);
    expect(tester.getRect(icon), bounds);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'discovery labels update while settings identity stays original: $style $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(400, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final plugin = PluginRegistryService.I.getByUuid('alias-source')!;
          const info = DiscoverPluginInfoState(
            loading: false,
            data: {'name': 'Original plugin', 'iconUrl': ''},
          );
          String? settingsName;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        const PluginDisplayNameTile(source: 'alias-source'),
                        PluginCard(
                          pluginUuid: 'alias-source',
                          pluginState: plugin,
                          infoState: info,
                          onOpen: () {},
                          onSettings: (name) => settingsName = name,
                          onToggleEnabled: (_) {},
                          onSearch: () {},
                          showSearch: false,
                          onRetry: () {},
                          onAction: (_) async {},
                        ),
                        SizedBox(
                          width: 160,
                          height: 300,
                          child: PluginGridTile(
                            pluginState: plugin,
                            infoState: info,
                            isToggling: false,
                            onOpen: () {},
                            onSearch: () {},
                            showSearch: false,
                            onSettings: (name) => settingsName = name,
                            onToggleEnabled: (_) {},
                            onRetry: () {},
                            onAction: (_) async {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text(t.pluginAppearance.displayNameHint), findsNothing);
          for (final layout in [PluginCard, PluginGridTile]) {
            expect(
              find.descendant(
                of: find.byType(layout),
                matching: find.byType(PluginIconVeil),
              ),
              findsOneWidget,
            );
          }
          Future<void> edit() async {
            await tester.tap(
              find.byKey(const ValueKey('plugin-display-name-edit')),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(t.pluginAppearance.displayNameHint),
              findsOneWidget,
            );
          }

          await edit();
          await tester.enterText(
            find.byKey(const ValueKey('plugin-display-name-input')),
            'Cancelled draft',
          );
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          expect(readPluginDisplayName('alias-source'), '');
          await edit();
          await tester.enterText(
            find.byKey(const ValueKey('plugin-display-name-input')),
            'My source',
          );
          await tester.tap(
            find.byKey(const ValueKey('plugin-display-name-save')),
          );
          await _until(
            tester,
            () => find.text('My source').evaluate().length >= 2,
          );
          expect(readPluginDisplayName('alias-source'), 'My source');
          await tester.tap(find.byTooltip(t.discover.settings));
          expect(settingsName, 'Original plugin');
          expect(
            find.descendant(
              of: find.byType(PluginCard),
              matching: find.text('My source').hitTestable(),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(PluginGridTile),
              matching: find.text('My source').hitTestable(),
            ),
            findsOneWidget,
          );
          expect(
            PluginRegistryService.I.getCachedPluginInfo(
              'alias-source',
            )?['name'],
            'Original plugin',
          );
          expect(plugin.uuid, 'alias-source');
          await edit();
          await tester.tap(find.text(t.pluginAppearance.displayNameOriginal));
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          expect(readPluginDisplayName('alias-source'), 'My source');
          await edit();
          await tester.enterText(
            find.byKey(const ValueKey('plugin-display-name-input')),
            'x' * 81,
          );
          await tester.tap(
            find.byKey(const ValueKey('plugin-display-name-save')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(t.pluginAppearance.displayNameTooLong),
            findsOneWidget,
          );
          expect(readPluginDisplayName('alias-source'), 'My source');
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          await edit();
          await tester.tap(find.text(t.pluginAppearance.displayNameOriginal));
          await tester.tap(
            find.byKey(const ValueKey('plugin-display-name-save')),
          );
          await _until(tester, () => find.text('My source').evaluate().isEmpty);
          expect(readPluginDisplayName('alias-source'), '');
          expect(find.text('Original plugin'), findsWidgets);
          final row = find.descendant(
            of: find.byType(PluginDisplayNameTile),
            matching: find.byType(ListTile),
          );
          expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
