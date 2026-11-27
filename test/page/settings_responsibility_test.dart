import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/bika_content_block_rules.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

import '../test_helper.dart';

const _state = PluginSettingsState(
  loading: false,
  hasLoadedSettings: true,
  canShowUserInfo: true,
  loginSupported: true,
  loginTitle: 'Fixture site login',
  sections: [
    {
      'title': '网络',
      'fields': [
        {
          'key': 'apiDomain',
          'kind': 'select',
          'label': '访问线路',
          'description': '无法访问时可尝试更换线路',
          'options': [
            {'value': 'one', 'label': '大陆专线1'},
            {'value': 'two', 'label': '国际服'},
          ],
        },
      ],
    },
  ],
  values: {'apiDomain': 'one'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  group('Bika content rules', () {
    setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
    tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

    Future<void> pumpBikaSettings(
      WidgetTester tester, {
      double textScale = 1,
      Future<void> Function(Map<String, dynamic>, dynamic)? onCommitField,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => SettingPageShell(
              grouped: true,
              title: 'Bika settings',
              child: PluginSettingsContent(
                from: bikaPlusSourceId,
                pluginRuntimeName: bikaPlusSourceId,
                state: const PluginSettingsState(
                  loading: false,
                  hasLoadedSettings: true,
                ),
                scope: PluginSettingsScope.preferences,
                showAccount: false,
                debugEnabled: false,
                debugUrl: '',
                deleted: false,
                pluginVersion: '1.0',
                colorScheme: Theme.of(context).colorScheme,
                onUpdateDebugConfig:
                    ({required enabled, required url}) async {},
                onConfirmDeletePlugin: () async {},
                onUpdatePlugin: () async {},
                onOpenLoginPage: null,
                onOpenDetailPage: () async {},
                onCommitField: onCommitField ?? (_, _) async {},
                onRunAction: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('edits individual phrases through plugin settings', (
      tester,
    ) async {
      final key = BikaContentBlockField.title.configKey;
      await savePluginConfigValue(bikaPlusSourceId, key, ['Existing rule']);
      final commits = <Object?>[];

      await pumpBikaSettings(
        tester,
        onCommitField: (field, value) async {
          expect(field['key'], key);
          commits.add(value);
          await savePluginConfigValue(bikaPlusSourceId, key, value);
        },
      );

      final row = find.text(t.searchResult.bikaBlockedTitles);
      final input = find.byKey(const ValueKey('bika-block-rule-input'));
      final add = find.byKey(const ValueKey('bika-block-rule-add'));
      Finder remove(String rule) =>
          find.byKey(ValueKey(('bika-block-rule-remove', rule)));

      Future<void> openEditor() async {
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(
          find.text(t.searchResult.bikaBlockedTitles),
          findsAtLeastNWidgets(2),
        );
        expect(remove('Existing rule'), findsOneWidget);
        expect(tester.widget<TextField>(input).maxLines, 1);
      }

      await openEditor();
      await tester.enterText(input, 'Two word phrase');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(remove('Two word phrase'), findsOneWidget);
      expect(remove('Two'), findsNothing);
      expect(remove('word'), findsNothing);

      await tester.enterText(input, 'Second entry');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(remove('Second entry'), findsOneWidget);
      await tester.tap(remove('Second entry'));
      await tester.pumpAndSettle();
      expect(remove('Second entry'), findsNothing);
      expect(remove('Two word phrase'), findsOneWidget);

      await tester.enterText(input, '  two WORD phrase  ');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(add).onPressed, isNull);
      expect(remove('Two word phrase'), findsOneWidget);
      expect(remove('two WORD phrase'), findsNothing);

      await tester.tap(remove('Existing rule'));
      await tester.pumpAndSettle();
      expect(remove('Existing rule'), findsNothing);
      expect(readHostPluginConfiguration(bikaPlusSourceId)[key], [
        'Existing rule',
      ]);

      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      expect(tester.testTextInput.isVisible, isFalse);

      await openEditor();
      expect(remove('Two word phrase'), findsNothing);
      await tester.enterText(input, 'Two word phrase');
      await tester.pump();
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(commits, [
        ['Existing rule', 'Two word phrase'],
      ]);
      expect(readHostPluginConfiguration(bikaPlusSourceId)[key], [
        'Existing rule',
        'Two word phrase',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final (viewport, textScale, keyboard) in [
      (const Size(440, 956), 1.0, 0.0),
      (const Size(320, 640), 2.0, 230.0),
    ]) {
      testWidgets(
        'long Bika rules scroll within the editor at ${viewport.width}',
        (tester) async {
          tester.view
            ..physicalSize = viewport
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final rules = List.generate(24, (i) => 'Rule ${i + 1}');
          await savePluginConfigValue(
            bikaPlusSourceId,
            BikaContentBlockField.title.configKey,
            rules,
          );
          await pumpBikaSettings(tester, textScale: textScale);
          await tester.tap(find.text(t.searchResult.bikaBlockedTitles));
          await tester.pumpAndSettle();

          final list = find.byKey(const ValueKey('bika-block-rule-list'));
          final input = find.byKey(const ValueKey('bika-block-rule-input'));
          final save = find.text(t.common.save);
          final cancel = find.text(t.common.cancel);
          final scrollable = find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          );
          final last = find.byKey(
            ValueKey(('bika-block-rule-remove', rules.last)),
          );
          final initial = find.byKey(
            ValueKey(('bika-block-rule-remove', rules.first)),
          );
          if (keyboard > 0) {
            await tester.tap(input);
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
            await tester.pumpAndSettle();
          }

          final listRect = tester.getRect(list);
          final inputBefore = tester.getRect(input);
          final saveBefore = tester.getRect(save);
          final cancelBefore = tester.getRect(cancel);
          if (keyboard == 0) {
            expect(listRect.height, greaterThanOrEqualTo(230));
            final dialog = tester.getRect(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.byType(NativeMaterialSurface),
              ),
            );
            expect(dialog.height, lessThanOrEqualTo(525));
            expect(initial.hitTestable(), findsOneWidget);
          } else {
            expect(listRect.height, greaterThan(44));
            expect(saveBefore.bottom, lessThan(viewport.height - keyboard));
            expect(cancelBefore.bottom, lessThan(viewport.height - keyboard));
            expect(inputBefore.top, greaterThan(0));
          }
          expect(last.hitTestable(), findsNothing);
          await tester.scrollUntilVisible(last, 150, scrollable: scrollable);
          await tester.pumpAndSettle();

          expect(last.hitTestable(), findsOneWidget);
          expect(tester.getRect(input), inputBefore);
          expect(tester.getRect(save), saveBefore);
          expect(tester.getRect(cancel), cancelBefore);
          expect(tester.getSize(last).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(last).width, greaterThanOrEqualTo(44));
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(last, findsNothing);
          expect(
            find
                .byKey(ValueKey(('bika-block-rule-remove', rules[22])))
                .hitTestable(),
            findsOneWidget,
          );
          expect(tester.getRect(input), inputBefore);
          expect(tester.getRect(save), saveBefore);
          if (keyboard > 0) {
            final editable = find.descendant(
              of: input,
              matching: find.byType(EditableText),
            );
            expect(
              tester.widget<EditableText>(editable).focusNode.hasFocus,
              isTrue,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scope in [
        PluginSettingsScope.preferences,
        PluginSettingsScope.management,
      ]) {
        testWidgets(
          'settings responsibility $style ${brightness.name} ${scope.name}',
          (tester) async {
            tester.view.physicalSize = const Size(430, 932);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Builder(
                    builder: (context) => SettingPageShell(
                      grouped: true,
                      title: 'Fixture settings',
                      child: PluginSettingsContent(
                        from: 'settings-scope-fixture',
                        pluginRuntimeName: 'settings-scope-fixture',
                        state: _state,
                        scope: scope,
                        showAccount: false,
                        debugEnabled: false,
                        debugUrl: '',
                        deleted: false,
                        pluginVersion: '1.0',
                        colorScheme: Theme.of(context).colorScheme,
                        onUpdateDebugConfig:
                            ({required enabled, required url}) async {},
                        onConfirmDeletePlugin: () async {},
                        onUpdatePlugin: () async {},
                        onOpenLoginPage: () async => fail(
                          'Account must be reached from the personal page',
                        ),
                        onOpenDetailPage: () async {},
                        onCommitField: (_, _) async {},
                        onRunAction: (_) async {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Fixture site login'), findsNothing);
            if (scope == PluginSettingsScope.preferences) {
              expect(find.text(t.plugin.management), findsNothing);
              expect(find.text(t.plugin.developerOptions), findsNothing);
              expect(find.text(t.plugin.deletePlugin), findsNothing);
              expect(find.text('无法访问时可尝试更换线路'), findsNothing);
              await tester.tap(
                find.byKey(const ValueKey('settings-details-网络')),
              );
              await tester.pumpAndSettle();
              expect(find.text('无法访问时可尝试更换线路'), findsOneWidget);
              final choice = find.descendant(
                of: find.byType(SettingChoiceTile<dynamic>),
                matching: find.byType(NativeVideoMenu),
              );
              final title = tester.getRect(
                find.descendant(
                  of: find.byType(SettingChoiceTile<dynamic>),
                  matching: find.text('访问线路'),
                ),
              );
              final value = tester.getRect(choice);
              expect(title.center.dy, closeTo(value.center.dy, .5));
              final titleGap = style == 'breeze' ? 12.0 : 16.0;
              expect(
                value.left - title.right,
                greaterThanOrEqualTo(titleGap - .5),
              );
              expect(
                tester.getRect(find.text('无法访问时可尝试更换线路')).top,
                greaterThanOrEqualTo(value.bottom),
              );
              expect(value.height, greaterThanOrEqualTo(44));
            } else {
              expect(find.text('访问线路'), findsNothing);
              expect(find.text(t.plugin.management), findsOneWidget);
              expect(find.text(t.plugin.developerOptions), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
