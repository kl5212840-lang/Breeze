import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

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
