import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _source = 'capability-fixture';
const _other = 'other-capability-fixture';

Finder _accountControl() => find.byWidgetPredicate(
  (widget) =>
      widget is SourceChromeIconButton &&
      widget.tooltip == t.sourceShell.account,
);

class _CapabilityApi extends RustLibApi {
  final calls = <(String, String)>[];
  final settings = <String, FutureOr<Map<String, dynamic>> Function()>{};
  final login = <String, FutureOr<Map<String, dynamic>> Function()>{};
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('login-capability-fixture');
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
    calls.add((runtimeName, fnPath));
    final Map<String, dynamic> result;
    if (fnPath == 'getSettingsBundle') {
      result = await settings[runtimeName]!();
    } else if (fnPath == 'getLoginBundle') {
      result =
          await (login[runtimeName]?.call() ??
              (throw StateError('No login capability')));
    } else if (fnPath == 'getInfo') {
      result = {'name': 'Capability fixture'};
    } else {
      result = {'data': <String, dynamic>{}};
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

final _pluginIds = <String, int>{};
Future<void> _version(String source, String version) async {
  final info = PluginInfo(
    id: _pluginIds[source] ?? 0,
    uuid: source,
    version: version,
    originScript: 'fixture-$version',
    insertedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isEnabled: true,
    isDeleted: false,
    lastLoadSuccess: true,
    debug: false,
    getInfoJson: jsonEncode({'name': 'Capability fixture'}),
  );
  await PluginRegistryService.I.upsert(info);
  _pluginIds[source] = info.id;
}

Future<void> _mount(
  WidgetTester tester,
  String source,
  ValueNotifier<String> style, {
  List<SourceShellSection> sections = const [],
}) => tester.pumpWidget(
  AppInterfaceStyleScope(
    style: style,
    child: MaterialApp(
      home: SourceShellPage(
        key: const ValueKey('same-shell'),
        source: source,
        sourceName: 'Capability fixture',
        sections: sections,
      ),
    ),
  ),
);

void _iosTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _CapabilityApi();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.settings.clear();
    api.login.clear();
    api.settings[_source] = () => {'data': <String, dynamic>{}};
    api.settings[_other] = () => {
      'data': {'canLogin': false},
    };
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
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  for (final styleName in ['system', 'breeze']) {
    for (final declared in [false, true]) {
      _iosTest(
        '$styleName explicit canLogin=$declared wins without probing login',
        (tester) async {
          final style = ValueNotifier(styleName);
          addTearDown(style.dispose);
          api.settings[_source] = () => {
            'data': {'canLogin': declared},
          };
          await _mount(tester, _source, style);
          await tester.pumpAndSettle();
          expect(_accountControl(), declared ? findsOneWidget : findsNothing);
          expect(
            api.calls.where((call) => call.$2 == 'getLoginBundle'),
            isEmpty,
          );
          await _mount(tester, _source, style);
          await tester.pumpAndSettle();
          expect(
            api.calls.where((call) => call.$2 == 'getSettingsBundle').length,
            1,
          );
          final cubit = PluginSettingsCubit();
          addTearDown(cubit.close);
          await cubit.load(_source);
          expect(cubit.state.loginSupported, declared);
          expect(
            api.calls.where((call) => call.$2 == 'getLoginBundle'),
            isEmpty,
          );
        },
      );
    }

    _iosTest(
      '$styleName legacy source retains successful login and settings failure fallback',
      (tester) async {
        final style = ValueNotifier(styleName);
        addTearDown(style.dispose);
        api.settings[_source] = () => throw StateError('No settings function');
        api.login[_source] = () => {
          'data': {'fields': []},
        };
        await _mount(tester, _source, style);
        await tester.pumpAndSettle();
        expect(_accountControl(), findsOneWidget);
        expect(
          api.calls.where((call) => call.$2 == 'getLoginBundle').length,
          1,
        );
      },
    );

    _iosTest(
      '$styleName anonymous failed probe keeps content and task NeedLogin semantics',
      (tester) async {
        final style = ValueNotifier(styleName);
        addTearDown(style.dispose);
        api.login[_source] = () => throw StateError(
          jsonEncode({
            'type': 'unauthorized',
            'source': _source,
            'message': 'Login required',
          }),
        );
        await _mount(tester, _source, style);
        await tester.pumpAndSettle();
        expect(_accountControl(), findsNothing);
        expect(find.text(t.sourceShell.noSections), findsOneWidget);
        expect(find.text(t.navigation.needLoginTitle), findsNothing);
        eventBus.fire(NeedLogin(from: _source));
        await tester.pumpAndSettle();
        expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
        eventBus.fire(const PluginLoginSucceeded(_source));
        await tester.pumpAndSettle();
        expect(find.text(t.sourceShell.noSections), findsOneWidget);
        expect(
          api.calls.where((call) => call.$2 == 'getSettingsBundle').length,
          1,
        );
      },
    );
  }

  _iosTest(
    'profile tab remains account destination with no extra capability probes',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await _mount(
        tester,
        _source,
        style,
        sections: const [
          SourceShellSection.more(title: 'More', actions: []),
          SourceShellSection.profile(),
        ],
      );
      await tester.pumpAndSettle();
      expect(_accountControl(), findsNothing);
      expect(find.widgetWithText(NavigationDestination, '我的'), findsOneWidget);
      expect(
        api.calls.where(
          (call) => ['getSettingsBundle', 'getLoginBundle'].contains(call.$2),
        ),
        isEmpty,
      );
    },
  );

  _iosTest(
    'unknown probe leaves content interactive and ignores old-source completion',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final old = Completer<Map<String, dynamic>>();
      api.settings[_source] = () => old.future;
      await _mount(tester, _source, style);
      await tester.pump();
      expect(_accountControl(), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await _mount(tester, _other, style);
      await tester.pumpAndSettle();
      old.complete({
        'data': {'canLogin': true},
      });
      await tester.pumpAndSettle();
      expect(_accountControl(), findsNothing);
      expect(
        api.calls.where((call) => call.$2 == 'getSettingsBundle').length,
        2,
      );
    },
  );

  _iosTest('plugin update probes once and ignores older version completion', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await _version(_source, '1');
    final old = Completer<Map<String, dynamic>>();
    api.settings[_source] = () => old.future;
    await _mount(tester, _source, style);
    await tester.pump();
    api.settings[_source] = () => {
      'data': {'canLogin': false},
    };
    await _version(_source, '2');
    await tester.pumpAndSettle();
    old.complete({
      'data': {'canLogin': true},
    });
    await tester.pumpAndSettle();
    expect(_accountControl(), findsNothing);
    expect(api.calls.where((call) => call.$2 == 'getSettingsBundle').length, 2);
    await _version(_source, '2');
    await tester.pumpAndSettle();
    expect(api.calls.where((call) => call.$2 == 'getSettingsBundle').length, 2);
    api.settings[_source] = () => {
      'data': {'canLogin': true},
    };
    await _version(_source, '3');
    await tester.pumpAndSettle();
    expect(_accountControl(), findsOneWidget);
  });

  _iosTest('disposed shell ignores a late successful capability result', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    final pending = Completer<Map<String, dynamic>>();
    api.settings[_source] = () => pending.future;
    await _mount(tester, _source, style);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete({
      'data': {'canLogin': true},
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
