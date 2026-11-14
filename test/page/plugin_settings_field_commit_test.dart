import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';
const _field = <String, dynamic>{
  'key': 'quality',
  'kind': 'select',
  'label': 'Third-party quality',
  'fnPath': 'vendor.validateQuality',
  'options': [
    {'label': 'Original', 'value': 'old'},
    {'label': 'Next', 'value': 'next'},
    {'label': 'Latest', 'value': 'latest'},
  ],
};

class _FieldApi extends RustLibApi {
  final calls = <String>[];
  Completer<Map<String, dynamic>>? pending;
  final actionCalls = <String>[];
  bool legacyMaintenance = false;
  bool transientCommand = false;
  Map<String, dynamic>? commandPayload;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('field-fixture');
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
    final Object result;
    if (fnPath == 'vendor.inputCommand') {
      commandPayload = jsonDecode(argsJson) as Map<String, dynamic>;
      actionCalls.add(fnPath);
      result = {'ok': true};
    } else if (fnPath == 'vendor.validateQuality') {
      calls.add(jsonDecode(argsJson)['value'].toString());
      result = await pending!.future;
    } else if (fnPath == 'clearPluginSession') {
      actionCalls.add(fnPath);
      result = {'ok': true};
    } else if (fnPath == 'getCapabilitiesBundle' && legacyMaintenance) {
      result = {
        'scheme': {
          'actions': [
            {'title': '清理插件会话', 'fnPath': 'clearPluginSession'},
          ],
        },
      };
    } else if (fnPath == 'getSettingsBundle') {
      result = {
        'scheme': {
          'sections': [
            {
              'title': 'Vendor settings',
              'fields': [
                _field,
                if (transientCommand)
                  {
                    'key': 'command.password',
                    'kind': 'password',
                    'label': '更新密码',
                    'description': '更新密码。',
                    'fnPath': 'vendor.inputCommand',
                    'persist': false,
                  },
              ],
            },
          ],
        },
        'data': {
          'values': {'quality': 'old'},
          'canLogin': false,
        },
      };
    } else {
      result = {'data': <String, dynamic>{}};
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

PluginSettingsContent _content(WidgetTester tester) =>
    tester.widget<PluginSettingsContent>(find.byType(PluginSettingsContent));
SettingChoiceTile<dynamic> _choice(WidgetTester tester) =>
    tester.widget<SettingChoiceTile<dynamic>>(
      find.byType(SettingChoiceTile<dynamic>),
    );

Future<void> _mount(WidgetTester tester, String style) async {
  final registry = PluginRegistryCubit();
  final preference = ValueNotifier(style);
  addTearDown(registry.close);
  addTearDown(preference.dispose);
  await savePluginConfigValue(_source, 'quality', 'old');
  await tester.pumpWidget(
    BlocProvider.value(
      value: registry,
      child: AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          home: PluginSettingsPage(
            from: _source,
            pluginUuid: _source,
            pluginRuntimeName: _source,
            pluginDisplayName: 'Unknown vendor',
            scope: PluginSettingsScope.preferences,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(_choice(tester).value, 'old');
}

// Flutter checks foundation variables before package:test tearDown runs.
// Restore the override inside the test callback, including assertion failures.
void _iosHostTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      toastification.dismissAll(delayForAnimation: false);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      toastification.managers.clear();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _FieldApi();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.pending = null;
    api.actionCalls.clear();
    api.legacyMaintenance = false;
    api.transientCommand = false;
    api.commandPayload = null;
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
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  for (final style in ['system', 'breeze']) {
    _iosHostTest(
      '$style one-time input has no fake value and does not retain or replay its submission',
      (tester) async {
        api.transientCommand = true;
        await _mount(tester, style);
        final field = find.byKey(
          const ValueKey('plugin-field-key:command.password'),
        );
        await tester.scrollUntilVisible(field, 160, maxScrolls: 10);
        await tester.pumpAndSettle();
        final row = find.descendant(
          of: field,
          matching: find.byType(PluginSettingsFieldRow),
        );
        expect(tester.widget<PluginSettingsFieldRow>(row).currentValue, isNull);
        expect(find.text('更新密码。'), findsNothing);
        final tap = find.descendant(of: field, matching: find.byType(ListTile));
        await tester.tap(tap);
        await tester.pumpAndSettle();
        final editor = find.byType(TextFormField);
        expect(tester.widget<TextFormField>(editor).initialValue, isEmpty);
        await tester.enterText(editor, 'fixture-once-secret');
        await tester.tap(find.text(t.common.save));
        await tester.pumpAndSettle();
        expect(api.commandPayload!['key'], 'command.password');
        expect(api.commandPayload!['value'], 'fixture-once-secret');
        expect(api.actionCalls, ['vendor.inputCommand']);
        expect(
          _content(tester).state.values.containsKey('command.password'),
          isFalse,
        );
        expect(
          loadPluginConfigValue(_source, 'command.password', fallback: ''),
          '',
        );
        await tester.ensureVisible(tap);
        await tester.pumpAndSettle();
        await tester.tap(tap);
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(editor).initialValue, isEmpty);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(api.actionCalls, ['vendor.inputCommand']);
        expect(_choice(tester).value, 'old');
      },
    );
    _iosHostTest(
      '$style legacy maintenance is hidden and retained callbacks cannot clear account data',
      (tester) async {
        api.legacyMaintenance = true;
        await savePluginConfigValue(
          _source,
          'auth.account',
          'synthetic-kept-account',
        );
        await _mount(tester, style);
        expect(find.text('清理插件会话'), findsNothing);
        final content = _content(tester);
        await content.onRunAction({
          'title': 'legacy',
          'fnPath': 'clearPluginSession',
        });
        await content.onCommitField({
          'key': 'auth.account',
          'kind': 'text',
          'fnPath': 'clearPluginSession',
        }, '');
        await tester.pump();
        expect(api.actionCalls, isEmpty);
        expect(
          loadPluginConfigValue(_source, 'auth.account', fallback: ''),
          'synthetic-kept-account',
        );
        expect(api.calls, isEmpty);
      },
    );
    for (final rejection in ['throw', 'explicit']) {
      _iosHostTest(
        '$style $rejection rejection retains persisted value and allows retry',
        (tester) async {
          // Create error futures inside this testWidgets error zone.
          api.pending = Completer<Map<String, dynamic>>();
          await _mount(tester, style);
          final commit = _content(tester).onCommitField(_field, 'next');
          await tester.pump();
          expect(_choice(tester).enabled, isFalse);
          expect(_choice(tester).value, 'old');
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          if (rejection == 'throw') {
            api.pending!.completeError(StateError('Connection refused'));
          } else {
            api.pending!.complete({
              'data': {'ok': false, 'message': 'Unsupported quality'},
            });
          }
          await commit;
          await tester.pumpAndSettle();
          expect(_choice(tester).enabled, isTrue);
          expect(_choice(tester).value, 'old');
          expect(
            loadPluginConfigValue(_source, 'quality', fallback: ''),
            'old',
          );
          expect(
            _content(tester).fieldErrors.values.single,
            contains(t.error.saveFailed),
          );
          expect(
            find.text(_content(tester).fieldErrors.values.single),
            findsOneWidget,
          );
          api.pending = Completer<Map<String, dynamic>>();
          final retry = _content(tester).onCommitField(_field, 'latest');
          await tester.pump();
          expect(_content(tester).fieldErrors, isEmpty);
          api.pending!.complete({'ok': true});
          await retry;
          await tester.pump();
          for (var frame = 0; frame < 7; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.text(t.common.saved), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(_choice(tester).value, 'latest');
          expect(
            loadPluginConfigValue(_source, 'quality', fallback: ''),
            'latest',
          );
          expect(_content(tester).fieldErrors, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    _iosHostTest('$style fast same-field callbacks share in-flight guard', (
      tester,
    ) async {
      api.pending = Completer<Map<String, dynamic>>();
      await _mount(tester, style);
      final callback = _content(tester).onCommitField;
      final first = callback(_field, 'next');
      final second = callback(_field, 'latest');
      await tester.pump();
      expect(api.calls, ['next']);
      expect(_choice(tester).enabled, isFalse);
      api.pending!.complete({'data': <String, dynamic>{}});
      await Future.wait([first, second]);
      await tester.pumpAndSettle();
      expect(_choice(tester).value, 'next');
      expect(loadPluginConfigValue(_source, 'quality', fallback: ''), 'next');
      expect(_choice(tester).enabled, isTrue);
    });

    _iosHostTest('$style credential failure does not expose submitted value', (
      tester,
    ) async {
      api.pending = Completer<Map<String, dynamic>>();
      await _mount(tester, style);
      const secret = 'private-fixture-value';
      final commit = _content(
        tester,
      ).onCommitField({..._field, 'kind': 'password'}, secret);
      await tester.pump();
      api.pending!.completeError(StateError(secret));
      await commit;
      await tester.pumpAndSettle();
      expect(_content(tester).fieldErrors.values.single, t.error.saveFailed);
      expect(find.textContaining(secret), findsNothing);
      expect(loadPluginConfigValue(_source, 'quality', fallback: ''), 'old');
      expect(tester.takeException(), isNull);
    });

    _iosHostTest(
      '$style local encode failure does not change UI or stored value',
      (tester) async {
        api.pending = Completer<Map<String, dynamic>>();
        await _mount(tester, style);
        await _content(
          tester,
        ).onCommitField({..._field, 'fnPath': ''}, double.nan);
        await tester.pumpAndSettle();
        expect(_choice(tester).value, 'old');
        expect(loadPluginConfigValue(_source, 'quality', fallback: ''), 'old');
        expect(_content(tester).fieldErrors, isNotEmpty);
        expect(_choice(tester).enabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    _iosHostTest('$style disposed page ignores late remote success', (
      tester,
    ) async {
      api.pending = Completer<Map<String, dynamic>>();
      await _mount(tester, style);
      final commit = _content(tester).onCommitField(_field, 'next');
      await tester.pumpWidget(const SizedBox.shrink());
      api.pending!.complete({'ok': true});
      await commit;
      await tester.pumpAndSettle();
      expect(loadPluginConfigValue(_source, 'quality', fallback: ''), 'old');
      expect(
        toastification.managers.values.expand(
          (manager) => manager.notifications,
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
