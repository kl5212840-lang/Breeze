import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_local_appearance_section.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

class _ClassicSwitchTrack extends Adaptation<SwitchThemeData> {
  const _ClassicSwitchTrack();

  static const color = Color(0xffa03d76);

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) =>
      defaultValue.copyWith(trackColor: const WidgetStatePropertyAll(color));
}

const _source = '78617c71-313f-42fe-9317-460d691890b2';
const _captureKey = ValueKey('compact-plugin-settings-preview');
const _sectionTitle = '第三方阅读偏好';
const _qualityLabel = '较长的第三方画质选项标题';
const _qualityDescription = '线路无法连接时可以切换画质，此处保留第三方插件提供的完整说明。';
const _textDescription = '此值仅改变本站阅读偏好，不会改变账号或删除记录。';
const _actionWarning = '这是插件提供的操作说明，执行前请确认适用范围。';

class _CompactApi extends RustLibApi {
  final calls = <String>[];
  bool emptySchema = false;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('compact-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    calls.add(fnPath);
    final Object result = switch (fnPath) {
      'init' => {'ok': true},
      'getSettingsBundle' => {
        'scheme': {
          'sections': emptySchema
              ? []
              : [
                  {
                    'title': _sectionTitle,
                    'fields': [
                      {
                        'key': 'enabled',
                        'kind': 'switch',
                        'label': '连续阅读',
                        'description': '读完当前章节后继续下一章。',
                      },
                      {
                        'key': 'quality',
                        'kind': 'select',
                        'label': _qualityLabel,
                        'description': _qualityDescription,
                        'options': [
                          {'value': 'auto', 'label': '自动'},
                          {'value': 'original', 'label': '原图'},
                        ],
                      },
                      {
                        'key': 'labels',
                        'kind': 'multiChoice',
                        'label': '分类',
                        'description': '可以选择多个实际分类。',
                        'options': [
                          {'value': 'a', 'label': '分类A'},
                          {'value': 'b', 'label': '分类B'},
                        ],
                      },
                      {
                        'key': 'nickname',
                        'kind': 'vendorText',
                        'label': '阅读标记',
                        'description': _textDescription,
                      },
                      {
                        'key': 'password',
                        'kind': 'password',
                        'label': '插件密钥',
                        'description': '此值由插件保存，请谨慎修改。',
                      },
                    ],
                  },
                ],
        },
        'data': {
          'canLogin': false,
          'canShowUserInfo': true,
          'canShowDetail': true,
          'values': {
            'enabled': true,
            'quality': 'auto',
            'labels': ['a'],
            'nickname': '本机标记',
            'password': 'synthetic-secret',
          },
        },
      },
      'getUserInfoBundle' => {
        'data': {
          'title': '已保存账号资料',
          'lines': ['保留的官方昵称', '等级4'],
          'avatar': {'url': '', 'path': ''},
        },
      },
      'getCapabilitiesBundle' => {
        'scheme': {
          'actions': [
            {
              'title': '插件操作',
              'fnPath': 'vendor.action',
              'description': _actionWarning,
            },
            {'title': '内部维护', 'fnPath': 'clearPluginSession'},
          ],
        },
      },
      'vendor.action' => {'ok': true},
      _ => throw StateError('Unexpected fixture function $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _CompactApi();
  final channels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
    await PluginRegistryService.I.init();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.emptySchema = false;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => TestObjectBoxHelper.tempPath,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'empty plugin schema keeps host groups in the same order: $style',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final registry = PluginRegistryCubit();
        final preference = ValueNotifier(style);
        try {
          api.emptySchema = true;
          await tester.pumpWidget(
            BlocProvider.value(
              value: registry,
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  home: const PluginSettingsPage(
                    from: _source,
                    pluginUuid: _source,
                    pluginRuntimeName: _source,
                    pluginDisplayName: '第三方插件',
                    scope: PluginSettingsScope.preferences,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );
          _expectAppearanceGroupOrder(tester, management: false);
          await tester.scrollUntilVisible(
            find.byType(PluginLocalAppearanceSection),
            200,
            maxScrolls: 12,
          );
          expect(find.byType(PluginLocalAppearanceSection), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          try {
            var closed = false;
            Object? closeError;
            unawaited(
              registry.close().then<void>(
                (_) => closed = true,
                onError: (Object error) {
                  closeError = error;
                  closed = true;
                },
              ),
            );
            final elapsed = Stopwatch()..start();
            while (!closed && elapsed.elapsed < const Duration(seconds: 5)) {
              await tester.pump(const Duration(milliseconds: 16));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
            }
            expect(closed, isTrue, reason: 'registry subscription closes');
            if (closeError != null) throw closeError!;
          } finally {
            preference.dispose();
            debugDefaultTargetPlatformOverride = null;
          }
        }
      },
    );
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'actual plugin settings compact $style ${brightness.name} ${scale}x retains schema and actions',
          (tester) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
            try {
              tester.view.physicalSize = Size(scale == 1 ? 430 : 320, 932);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final registry = PluginRegistryCubit();
              final stylePreference = ValueNotifier(style);
              addTearDown(registry.close);
              addTearDown(stylePreference.dispose);
              await tester.pumpWidget(
                BlocProvider.value(
                  value: registry,
                  child: AppInterfaceStyleScope(
                    style: stylePreference,
                    child: MaterialApp(
                      theme: ThemeData(
                        brightness: brightness,
                        adaptations: const [_ClassicSwitchTrack()],
                        fontFamily: uiPreviewDirectory == null
                            ? null
                            : 'AccountPreview',
                      ),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: RepaintBoundary(key: _captureKey, child: child!),
                      ),
                      home: const PluginSettingsPage(
                        from: _source,
                        pluginUuid: _source,
                        pluginRuntimeName: _source,
                        pluginDisplayName: '第三方插件',
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle(
                const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 5),
              );
              expect(find.text('保留的官方昵称'), findsOneWidget);
              _expectAppearanceGroupOrder(tester, management: true);
              final choice = tester.widget<SettingChoiceTile<dynamic>>(
                find.byType(SettingChoiceTile<dynamic>),
              );
              expect(choice.description, isNull);
              final section = tester
                  .widgetList<SettingSection>(find.byType(SettingSection))
                  .singleWhere((s) => s.title == _sectionTitle);
              expect(section.details[_qualityLabel], _qualityDescription);
              expect(section.details['阅读标记'], _textDescription);
              final switchRow = find.widgetWithText(ListTile, '连续阅读');
              await tester.scrollUntilVisible(switchRow, 180, maxScrolls: 12);
              expect(tester.widget<ListTile>(switchRow).subtitle, isNull);
              final classic = find.descendant(
                of: switchRow,
                matching: find.byType(Switch),
              );
              expect(tester.widget<Switch>(classic).value, isTrue);
              final switchTheme = Theme.of(tester.element(classic));
              final track = switchTheme
                  .getAdaptation<SwitchThemeData>()!
                  .adapt(switchTheme, const SwitchThemeData())
                  .trackColor!
                  .resolve({WidgetState.selected});
              expect(classic, paints..rrect(color: track));
              expect(
                tester.getSize(switchRow).height,
                greaterThanOrEqualTo(44),
              );
              await writeUiPreview(
                tester,
                _captureKey,
                'plugin-compact-$style-${brightness.name}-$scale',
              );
              final nickname = find.byKey(
                const ValueKey('plugin-field-key:nickname'),
              );
              await tester.scrollUntilVisible(nickname, 180, maxScrolls: 12);
              final nicknameRow = find.descendant(
                of: nickname,
                matching: find.byType(ListTile),
              );
              expect(tester.widget<ListTile>(nicknameRow).subtitle, isNull);
              final value = find.descendant(
                of: nicknameRow,
                matching: find.text('本机标记'),
              );
              expect(
                tester.getRect(value).right,
                lessThanOrEqualTo(tester.getRect(nicknameRow).right - 16),
              );
              expect(
                tester.getSize(nicknameRow).height,
                greaterThanOrEqualTo(44),
              );
              expect(find.text('synthetic-secret'), findsNothing);

              // Optional field help is grouped and collapsed in the real
              // plugin host. Executable warnings remain at their own controls.
              final disclosure = find.byKey(
                const ValueKey('settings-details-$_sectionTitle'),
              );
              await tester.scrollUntilVisible(disclosure, 180, maxScrolls: 12);
              await tester.pumpAndSettle();
              expect(find.text(_qualityDescription), findsNothing);
              await tester.tap(disclosure);
              await tester.pumpAndSettle();
              expect(find.text(_qualityDescription), findsOneWidget);
              await tester.scrollUntilVisible(
                find.text(_textDescription),
                180,
                maxScrolls: 12,
              );
              expect(find.text(_textDescription), findsOneWidget);
              await writeUiPreview(
                tester,
                _captureKey,
                'plugin-details-$style-${brightness.name}-$scale',
              );

              // Third-party executable actions keep their unclassified warning visible.
              final action = find.widgetWithText(ListTile, '插件操作');
              await tester.scrollUntilVisible(action, 220, maxScrolls: 14);
              expect(tester.widget<ListTile>(action).subtitle, isA<Text>());
              expect(find.text(_actionWarning), findsOneWidget);
              expect(find.text('内部维护'), findsNothing);
              if (brightness == Brightness.light && scale == 1) {
                await tester.tap(action);
                await tester.pumpAndSettle();
                expect(
                  api.calls.where((fn) => fn == 'vendor.action'),
                  hasLength(1),
                );
                expect(api.calls, isNot(contains('clearPluginSession')));
                await tester.scrollUntilVisible(nickname, -220, maxScrolls: 14);
                // ensureVisible jumps the scroll position; lay out that jump
                // before tap computes the retained row's screen coordinates.
                await tester.pump();
                expect(nicknameRow.hitTestable(), findsOneWidget);
                await tester.tap(nicknameRow);
                await tester.pumpAndSettle();
                final editor = find.byType(TextFormField);
                expect(editor, findsOneWidget);
                await tester.enterText(editor, '修改后的标记');
                await tester.tap(find.text(t.common.save));
                await tester.pumpAndSettle();
                expect(
                  tester
                      .widget<PluginSettingsContent>(
                        find.byType(PluginSettingsContent),
                      )
                      .state
                      .values['nickname'],
                  '修改后的标记',
                );
                expect(find.text('修改后的标记'), findsOneWidget);
              }
              final deletion = find.widgetWithText(
                ListTile,
                t.pluginLifecycle.deleteEntry,
              );
              await tester.scrollUntilVisible(deletion, 240, maxScrolls: 18);
              await tester.pumpAndSettle();
              expect(deletion.hitTestable(), findsOneWidget);
              expect(tester.widget<ListTile>(deletion).onTap, isNotNull);
              await tester.tap(deletion);
              await tester.pumpAndSettle();
              expect(
                find.text(t.pluginLifecycle.deleteLocalData),
                findsOneWidget,
              );
              expect(
                find.text(t.pluginLifecycle.deleteCloudData),
                findsOneWidget,
              );
              // Scope selection is not deletion; cancelling preserves the plugin.
              await tester.tap(find.text(t.common.cancel));
              await tester.pumpAndSettle();
              expect(find.byType(PluginSettingsContent), findsOneWidget);
              expect(tester.takeException(), isNull);
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          },
        );
      }
    }
  }
}

void _expectAppearanceGroupOrder(
  WidgetTester tester, {
  required bool management,
}) {
  final list = tester.widget<ListView>(
    find.byKey(const ValueKey('plugin-settings-sections')),
  );
  final children = (list.childrenDelegate as SliverChildListDelegate).children;
  final access = children.indexWhere(
    (w) => w is PluginSettingsSectionCard && w.title == t.plugin.accessAndTools,
  );
  final appearance = children.indexWhere(
    (w) => w is PluginLocalAppearanceSection,
  );
  expect(access, greaterThanOrEqualTo(0));
  expect(
    appearance,
    access + 1,
    reason: 'all plugin-authored sections precede the fixed host group block',
  );
  if (management) {
    final manager = children.indexWhere(
      (w) => w is PluginSettingsSectionCard && w.title == t.plugin.management,
    );
    expect(manager, appearance + 1);
  } else {
    expect(appearance, children.length - 1);
  }
}
