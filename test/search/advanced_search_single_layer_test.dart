import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';

void main() {
  testWidgets('the inline JM year wheel clears and disables its month', (
    tester,
  ) async {
    Map<String, dynamic>? filters;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                filters = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const PluginAdvancedSearchDialog(
                    initialSort: 1,
                    scheme: PluginAdvancedSearchScheme(
                      source: PluginAccountAuthenticationService.jm,
                      values: {'y': 2025, 'm': 5},
                      fields: [
                        {
                          'key': 'y',
                          'kind': 'choice',
                          'label': 'Year',
                          'optionLayout': 'menu',
                          'options': [
                            {'label': 'All years', 'value': ''},
                            {'label': '2025', 'value': 2025},
                          ],
                        },
                        {
                          'key': 'm',
                          'kind': 'choice',
                          'label': 'Month',
                          'optionLayout': 'menu',
                          'requiresOption': 'y',
                          'options': [
                            {'label': 'All months', 'value': ''},
                            {'label': 'May', 'value': 5},
                          ],
                        },
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final year = find.byKey(const ValueKey('advanced-search.y.wheel'));
    final month = find.byKey(const ValueKey('advanced-search.m'));
    expect(tester.widget<YearFilterPicker>(month).enabled, isTrue);
    await tester.drag(year, const Offset(0, 65));
    await tester.pumpAndSettle();
    expect(tester.widget<YearFilterPicker>(month).enabled, isFalse);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(NativeMaterialSurface), findsOneWidget);
    await tester.tap(find.text(t.common.apply));
    await tester.pumpAndSettle();
    expect(filters, {'y': '', 'm': ''});
  });

  testWidgets(
    'advanced filters use the task surface across styles and contrast',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 520);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      const fields = [
        {
          'key': 'sortBy',
          'kind': 'choice',
          'label': 'Sort',
          'options': [
            {'label': 'Latest', 'value': 1},
            {'label': 'Earliest', 'value': 2},
          ],
        },
      ];
      final applied = <Map<String, dynamic>?>[];
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      for (final (interfaceStyle, highContrast, source, apply) in [
        ('system', false, PluginAccountAuthenticationService.jm, false),
        ('system', false, 'otherSource', true),
        ('system', true, 'otherSource', true),
        ('breeze', false, 'otherSource', true),
      ]) {
        style.value = interfaceStyle;
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  highContrast: highContrast,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      applied.add(
                        await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => PluginAdvancedSearchDialog(
                            initialSort: 1,
                            scheme: PluginAdvancedSearchScheme(
                              source: source,
                              fields: fields,
                              values: {},
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, t.common.apply);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        expect(button.hitTestable(), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        final material = find.byType(UiKitView);
        if (highContrast || interfaceStyle == 'breeze') {
          expect(material, findsNothing);
        } else {
          final view = tester.widget<UiKitView>(material);
          expect(view.viewType, 'breeze.search.surface');
          expect((view.creationParams! as Map)['readableContent'], isTrue);
        }
        await tester.tap(
          find.widgetWithText(ChoiceChip, 'Earliest').hitTestable(),
        );
        await tester.pumpAndSettle();
        await tester.tap(apply ? button : find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(applied, [
        null,
        {'sortBy': 2},
        {'sortBy': 2},
        {'sortBy': 2},
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('favorite eligibility follows dimension identity rather than size', () {
    PluginChoiceField field(String key, {String? semantic}) =>
        PluginChoiceField(
          key: key,
          label: 'Label',
          kind: 'choice',
          options: const [],
          semantic: semantic,
        );
    for (final key in [
      'order',
      'sortBy',
      'category',
      'language',
      'week',
      'year',
    ]) {
      expect(field(key).supportsFavorites, isFalse);
    }
    for (final key in ['tags', 'author', 'theme']) {
      expect(field(key).supportsFavorites, isTrue);
    }
    expect(field('custom', semantic: 'tags').supportsFavorites, isTrue);
    expect(field('tags', semantic: 'language').supportsFavorites, isFalse);
  });

  testWidgets('multi selection has one draft and cancel leaves inputs intact', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.enUs);
    final original = <String, dynamic>{
      'categories': ['A'],
    };
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => PluginAdvancedSearchDialog(
                    initialSort: 1,
                    scheme: PluginAdvancedSearchScheme(
                      fields: const [
                        {
                          'key': 'categories',
                          'kind': 'multiChoice',
                          'label': 'Categories',
                          'options': [
                            {'label': 'A', 'value': 'A'},
                            {'label': 'B', 'value': 'B'},
                          ],
                        },
                      ],
                      values: original,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
    expect(original['categories'], ['A']);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(original['categories'], ['A']);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.tap(find.text(t.common.apply));
    await tester.pumpAndSettle();
    expect(result?['categories'], ['A', 'B']);
    expect(original['categories'], ['A']);
  });
}
