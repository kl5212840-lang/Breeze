import 'dart:async';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/setting/common/plugin_user_info_card.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';

class _SummaryApi extends RustLibApi {
  final calls = <String>[];
  bool canShowUserInfo = false;
  String loginTitle = '', loginSubtitle = '';
  String loginNameField = 'account';
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> actions = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>>? measuredSections;
  Map<String, dynamic> settingsValues = {};
  int? measuredMs;
  Object? summaryError;
  Completer<Map<String, dynamic>>? summaryGate;
  Future<Map<String, dynamic>> Function()? jmProfile;
  Future<void> Function(String, String, Object?)? jmNetworkChange;
  Future<void> Function()? jmMeasurement;
  bool? jmEffectiveRouteChanged;
  Map<String, dynamic>? jmMeasurementData;
  Future<Map<String, dynamic>> Function(String, String, Map<String, dynamic>)?
  copyNetwork;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('summary-fixture');
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
    if (copyNetwork != null &&
        (fnPath == 'saveSettings' || fnPath == 'testLineSpeeds')) {
      final args = jsonDecode(argsJson) as Map<String, dynamic>;
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({'data': await copyNetwork!(runtimeName, fnPath, args)}),
        ),
      );
    }
    if (fnPath == 'getUserProfileDetails' && jmProfile != null) {
      return Uint8List.fromList(
        utf8.encode(jsonEncode({'data': await jmProfile!()})),
      );
    }
    if (fnPath == 'onNetworkChanged' && jmNetworkChange != null) {
      final args = jsonDecode(argsJson) as Map;
      await jmNetworkChange!(runtimeName, args['key'] as String, args['value']);
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'data': {
              'ok': true,
              if (jmEffectiveRouteChanged != null)
                'effectiveRouteChanged': jmEffectiveRouteChanged,
            },
          }),
        ),
      );
    }
    if ((fnPath == 'getSettingsUserInfoBundle' ||
            fnPath == 'getUserInfoBundle') &&
        summaryGate != null) {
      final response = await summaryGate!.future;
      return Uint8List.fromList(utf8.encode(jsonEncode({'data': response})));
    }
    if ((fnPath == 'getSettingsUserInfoBundle' ||
            fnPath == 'getUserInfoBundle') &&
        summaryError != null) {
      throw summaryError!;
    }
    if (fnPath == 'testLineSpeeds' || fnPath == 'measureEndpointSpeeds') {
      if (fnPath == 'measureEndpointSpeeds') await jmMeasurement?.call();
      measuredMs = 20;
      sections = measuredSections ?? sections;
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'ok': true,
            'message': 'Measured',
            'data': {
              'ok': true,
              'anyAvailable': true,
              if (fnPath == 'measureEndpointSpeeds') ...?jmMeasurementData,
              if (fnPath == 'measureEndpointSpeeds' &&
                  jmEffectiveRouteChanged != null)
                'effectiveRouteChanged': jmEffectiveRouteChanged,
            },
          }),
        ),
      );
    }
    final result = switch (fnPath) {
      'init' => {'ok': true},
      'saveSettings' => {'ok': true},
      'getSettingsBundle' => {
        'scheme': {'sections': sections},
        'data': {
          'canShowUserInfo': canShowUserInfo,
          'canLogin': true,
          'loginTitle': loginTitle,
          'loginSubtitle': loginSubtitle,
          'values': {
            if (measuredMs != null) 'probeMs': measuredMs,
            if (sections.isNotEmpty) 'api.domain': '大陆专线3',
            ...settingsValues,
          },
        },
      },
      'getSettingsUserInfoBundle' || 'getUserInfoBundle' => {'data': summary},
      'getCapabilitiesBundle' => {
        'scheme': {'actions': actions},
      },
      'getLoginBundle' => {
        'scheme': {
          'title': 'Fixture login',
          'fields': [
            {'key': loginNameField, 'kind': 'text', 'label': 'Account'},
            {'key': 'password', 'kind': 'password', 'label': 'Password'},
          ],
          'submitFnPath': 'loginWithPassword',
        },
        'data': {
          'values': {
            loginNameField: 'fixture-account',
            'password': 'fixture-secret',
          },
        },
      },
      _ => throw StateError('Unexpected settings call $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _SummaryApi();
  var version = 0;
  var pluginId = 0;
  final channels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.calls.clear();
    api.canShowUserInfo = false;
    api.summaryError = null;
    api.summaryGate = null;
    api.jmProfile = null;
    api.jmNetworkChange = null;
    api.jmMeasurement = null;
    api.jmEffectiveRouteChanged = null;
    api.copyNetwork = null;
    api.actions = [];
    api.sections = [];
    api.measuredSections = null;
    api.settingsValues = {};
    api.measuredMs = null;
    api.loginTitle = '';
    api.loginSubtitle = '';
    api.loginNameField = 'account';
    api.summary = {
      'available': true,
      'title': '账号',
      'avatar': {'url': '', 'path': ''},
      'lines': ['官方昵称 · 硬币20', 'Lv.4', '经验100/200'],
      'extern': {
        'profileDataSource': 'storedSession',
        'accountId': 'fixture-account',
        'uid': 'fixture-account',
        'checkedInDate': '2026-11-01',
        'checkinProof': {
          'source': 'savedReceipt',
          'date': '2026-11-01',
          'verifiedThisRequest': false,
        },
      },
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
  Future<void> mount(
    WidgetTester tester, {
    required String style,
    String source = _source,
    bool profile = true,
    bool declared = true,
    PluginSettingsScope scope = PluginSettingsScope.preferences,
    double textScale = 1,
  }) async {
    late PluginInfo info;
    await tester.runAsync(
      () => PluginRegistryService.I.upsert(
        info = PluginInfo(
          id: pluginId,
          uuid: source,
          version: 'summary-${++version}',
          originScript: 'fixture',
          insertedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isEnabled: true,
          isDeleted: false,
          lastLoadSuccess: true,
          debug: false,
          getInfoJson: jsonEncode({
            'name': 'Synthetic vendor',
            'breezeExperience': {
              'profileTab': profile,
              if (declared && source == PluginAccountAuthenticationService.jm)
                'profileDetailsFunction': 'getUserProfileDetails',
              if (declared)
                'settingsUserInfoFunction': 'getSettingsUserInfoBundle',
            },
          }),
        ),
      ),
    );
    pluginId = info.id;
    final registry = PluginRegistryCubit();
    final preference = ValueNotifier(style);
    addTearDown(registry.close);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: registry,
        child: AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: PluginSettingsPage(
              from: source,
              pluginUuid: source,
              pluginRuntimeName: source,
              pluginDisplayName: 'Synthetic vendor',
              scope: scope,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final style in ['system', 'breeze']) {
    for (final width in [320.0, 390.0, 440.0]) {
      testWidgets(
        '$style compact verified account summary at $width with large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          api.summary = {
            'available': true,
            'hostVerified': true,
            'title': '账号',
            'avatar': {'url': '', 'path': ''},
            'lines': [
              'Actual returned member with a long public display name',
              'ID: actual-42',
              'Lv.4',
              'Experience 100/200',
              'Checked in',
            ],
            'extern': {'accountId': 'actual-42', 'username': 'actual.login'},
          };
          await mount(tester, style: style, textScale: 1.6);
          final card = find.byType(PluginUserInfoCard);
          expect(tester.widget<PluginUserInfoCard>(card).verified, isTrue);
          expect(
            find.text('Actual returned member with a long public display name'),
            findsOneWidget,
          );
          expect(find.text('ID: actual-42'), findsNothing);
          expect(find.text('actual.login'), findsOneWidget);
          final status = find.byKey(
            const ValueKey('plugin-account-authenticated'),
          );
          expect(status, findsOneWidget);
          expect(
            tester.getRect(card).contains(tester.getCenter(status)),
            isTrue,
          );
          final facts = find.ancestor(of: status, matching: find.byType(Wrap));
          expect(facts, findsOneWidget);
          for (final value in ['Lv.4', 'Experience 100/200', 'Checked in']) {
            final fact = find.descendant(of: facts, matching: find.text(value));
            expect(fact, findsOneWidget);
            expect(
              tester.getRect(card).contains(tester.getCenter(fact)),
              isTrue,
            );
          }
          final avatar = find.descendant(
            of: card,
            matching: find.byType(CircleAvatar),
          );
          expect(tester.getSize(avatar), const Size(64, 64));
          expect(find.text(t.plugin.switchAccount), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style distinguishes expired auth from unavailable profile without a global login gate',
      (tester) async {
        await mount(tester, style: style);
        final context = tester.element(find.byType(PluginSettingsContent));
        final cubit = context.read<PluginSettingsCubit>();
        final loginEvents = <NeedLogin>[];
        final subscription = eventBus.on<NeedLogin>().listen(loginEvents.add);
        addTearDown(subscription.cancel);
        expect(find.byType(PluginUserInfoCard), findsOneWidget);

        api.summaryError = StateError('fixture network unavailable');
        await tester.runAsync(() => cubit.loadUserInfo(_source));
        await tester.pumpAndSettle();
        expect(cubit.state.userInfoLoginRequired, isFalse);
        expect(cubit.state.userInfo, isNotEmpty);
        expect(find.byType(PluginUserInfoCard), findsOneWidget);
        expect(find.text(t.plugin.userInfoLoadFailed), findsOneWidget);
        expect(find.text(t.common.retry), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plugin-settings-direct-login')),
          findsNothing,
        );

        api.summaryError = AnyhowException(
          jsonEncode({
            'type': 'unauthorized',
            'source': _source,
            'message': 'fixture expired session with private contents',
          }),
        );
        await tester.runAsync(() => cubit.loadUserInfo(_source));
        await tester.pumpAndSettle();
        expect(cubit.state.userInfoLoginRequired, isTrue);
        expect(cubit.state.userInfo, isEmpty);
        expect(find.byType(PluginUserInfoCard), findsNothing);
        expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
        expect(find.text(t.plugin.switchAccount), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plugin-settings-direct-login')),
          findsOneWidget,
        );
        expect(find.text(t.common.retry), findsNothing);
        expect(
          find.byKey(const ValueKey('plugin-account-authenticated')),
          findsNothing,
        );
        expect(find.text(t.plugin.accountLogin), findsNothing);
        expect(find.textContaining('private contents'), findsNothing);
        expect(loginEvents, isEmpty);

        api.summaryError = null;
        api.summary = {'available': false};
        await tester.runAsync(() => cubit.loadUserInfo(_source));
        await tester.pumpAndSettle();
        expect(cubit.state.userInfoLoginRequired, isFalse);
        expect(find.text(t.plugin.noUserInfo), findsOneWidget);
        expect(loginEvents, isEmpty);
      },
    );
  }

  for (final (style, select) in [('system', true), ('breeze', false)]) {
    testWidgets(
      'expired Copy opens the login form directly with only the matching local username: $style',
      (tester) async {
        const source = PluginAccountAuthenticationService.copy;
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          pluginSessionWriteFence.advance(source);
          replaceActivePluginAccount(source, {
            'auth.username': 'fixture-first',
            'auth.token': 'fixture-first-token',
          });
          await PluginAccountProfiles.rememberCurrent(
            source,
            serverIdentity: 'fixture-first-id',
          );
          replaceActivePluginAccount(source, {
            'auth.username': 'fixture-selected',
            'auth.token': 'fixture-selected-token',
          });
          await PluginAccountProfiles.rememberCurrent(
            source,
            serverIdentity: 'fixture-selected-id',
            select: select,
          );
          if (!select) replaceActivePluginAccount(source, {});
        });
        api.canShowUserInfo = true;
        api.loginNameField = 'username';
        api.summaryError = AnyhowException('{"type":"unauthorized"}');
        await mount(
          tester,
          style: style,
          source: source,
          scope: PluginSettingsScope.all,
          textScale: 2,
        );
        final signIn = find.byKey(
          const ValueKey('plugin-settings-direct-login'),
        );
        expect(signIn, findsOneWidget);
        expect(tester.getSize(signIn).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(signIn).width, greaterThanOrEqualTo(44));
        expect(find.text(t.plugin.switchAccount), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        expect(api.calls, isNot(contains('loginWithPassword')));
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(PluginSavedAccountsPage), findsNothing);
        final fields = tester.widgetList<EditableText>(
          find.byType(EditableText),
        );
        expect(fields.map((field) => field.controller.text), [
          select ? 'fixture-selected' : '',
          '',
        ]);
        expect(api.calls, isNot(contains('loginWithPassword')));
        Navigator.of(tester.element(find.byType(LoginPage))).pop();
        await tester.pumpAndSettle();
        expect(signIn, findsOneWidget);
        expect(find.text(t.plugin.switchAccount), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style profile account summary reads only declared cache function and renders real receipt',
      (tester) async {
        await mount(tester, style: style);
        expect(
          api.calls.where((call) => call == 'getSettingsUserInfoBundle'),
          hasLength(1),
        );
        expect(api.calls, isNot(contains('getUserInfoBundle')));
        expect(api.calls, isNot(contains('getLoginBundle')));
        final content = tester.widget<PluginSettingsContent>(
          find.byType(PluginSettingsContent),
        );
        expect(content.showAccount, isTrue);
        expect(content.readOnlyAccount, isTrue);
        final card = tester.widget<PluginUserInfoCard>(
          find.byType(PluginUserInfoCard),
        );
        expect(card.lines, ['官方昵称 · 硬币20', 'Lv.4', '经验100/200']);
        expect(find.byType(CircleAvatar), findsOneWidget);
        expect(
          find.text(
            t.plugin.checkinReceipt(
              date: '2026-11-01',
              source: t.plugin.checkinSavedReceipt,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(t.plugin.accountSummaryHint), findsOneWidget);
        expect(content.state.loginSupported, isTrue);
        expect(find.text(t.plugin.switchAccount), findsOneWidget);
        expect(find.text(t.plugin.accountLogin), findsNothing);
        expect(find.text(t.plugin.accountLoginSubtitle), findsNothing);
        await savePluginConfigValue(
          _source,
          'auth.account',
          'fixture-kept-account',
        );
        await tester.tap(find.text(t.plugin.switchAccount));
        await tester.pumpAndSettle();
        expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        expect(api.calls, isNot(contains('getLoginBundle')));
        expect(
          find.text(t.accountProfiles.current),
          findsNothing,
          reason: 'a stored summary does not verify the current session',
        );
        await tester.tap(find.byKey(const ValueKey('saved-account-add')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields, isNotEmpty);
        expect(
          fields.every((field) => field.controller!.text.isEmpty),
          isTrue,
          reason: 'adding an account must not reuse another saved login',
        );
        expect(
          api.calls.where((call) => call == 'getLoginBundle'),
          hasLength(1),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
        expect(find.text(t.accountProfiles.current), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(t.plugin.switchAccount), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plugin-account-authenticated')),
          findsNothing,
        );
        expect(
          loadPluginConfigValue(_source, 'auth.account', fallback: ''),
          'fixture-kept-account',
        );
        expect(api.calls, isNot(contains('clearPluginSession')));
        expect(api.calls, isNot(contains('loginWithPassword')));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      '$style profile without explicit summary never probes user info or login',
      (tester) async {
        await mount(tester, style: style, declared: false);
        expect(
          api.calls.where(
            (call) => call.contains('UserInfo') || call.contains('Login'),
          ),
          isEmpty,
        );
        expect(find.byType(PluginUserInfoCard), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  testWidgets(
    'missing cached summary is unavailable and never claims unsigned or level zero',
    (tester) async {
      api.summary = {
        'available': false,
        'lines': [],
        'extern': {'profileDataSource': 'storedSession'},
      };
      await mount(tester, style: 'breeze');
      expect(find.text(t.plugin.noUserInfo), findsOneWidget);
      expect(find.byType(PluginUserInfoCard), findsNothing);
      expect(find.text(t.plugin.switchAccount), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plugin-account-authenticated')),
        findsNothing,
      );
      expect(find.text(t.plugin.accountLogin), findsNothing);
      expect(find.text(t.plugin.accountLoginSubtitle), findsNothing);
      expect(find.textContaining('Lv.0'), findsNothing);
      expect(api.calls, isNot(contains('getUserInfoBundle')));
      expect(api.calls, isNot(contains('getLoginBundle')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('summary rejects a receipt associated with a different account', (
    tester,
  ) async {
    (api.summary['extern'] as Map)['accountId'] = 'different-account';
    await mount(tester, style: 'breeze');
    expect(find.text(t.plugin.noCheckinReceipt), findsOneWidget);
    expect(find.textContaining('2026-11-01'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy third party keeps default account and login behavior', (
    tester,
  ) async {
    api.canShowUserInfo = true;
    await mount(tester, style: 'breeze', profile: false, declared: false);
    expect(api.calls, contains('getUserInfoBundle'));
    expect(api.calls, isNot(contains('getSettingsUserInfoBundle')));
    final content = tester.widget<PluginSettingsContent>(
      find.byType(PluginSettingsContent),
    );
    expect(content.readOnlyAccount, isFalse);
    expect(content.state.loginSupported, isTrue);
    expect(find.byType(PluginUserInfoCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'technical ID is removed only when it exactly repeats a confirmed identity',
    () {
      const id = 'abcdef0123456789';
      const lines = [
        'Nickname',
        'ID: $id',
        '会员编号：123',
        'Lv.4',
        '经验100/200',
        'ID: 456',
      ];
      expect(sanitizePluginAccountSummaryLines(lines, {'userId': id}), [
        'Nickname',
        '会员编号：123',
        'Lv.4',
        '经验100/200',
        'ID: 456',
      ]);
      expect(sanitizePluginAccountSummaryLines(lines, {}), lines);
      expect(
        sanitizePluginAccountSummaryLines(lines, {'userId': 'another-account'}),
        lines,
      );
    },
  );
  testWidgets(
    'generic summary hides a proven duplicate ID without parsing hexadecimal',
    (tester) async {
      api.summary['lines'] = [
        'Nickname',
        'ID: abcdef0123456789',
        '会员编号：123',
        'Lv.4',
      ];
      api.summary['extern'] = {'userId': 'abcdef0123456789'};
      await mount(tester, style: 'breeze');
      final card = tester.widget<PluginUserInfoCard>(
        find.byType(PluginUserInfoCard),
      );
      expect(card.lines, ['Nickname', '会员编号：123', 'Lv.4']);
      expect(find.text('ID: abcdef0123456789'), findsNothing);
      expect(card.accountIdentity, isEmpty);
      expect(card.verified, isFalse);
      expect(
        find.byKey(const ValueKey('plugin-account-authenticated')),
        findsNothing,
      );
      expect(find.text('会员编号：123'), findsOneWidget);
    },
  );
  test(
    'account display uses explicit public labels and never guesses UID usefulness',
    () {
      expect(
        pluginAccountDisplayIdentity(
          {'accountId': 'opaque-identity', 'uid': '42'},
          ['Nickname'],
        ),
        isEmpty,
      );
      expect(
        pluginAccountDisplayIdentity(
          {'username': 'Nickname', 'userId': 'hash-value'},
          ['Nickname'],
        ),
        isEmpty,
      );
      expect(
        pluginAccountDisplayIdentity(
          {'username': 'actual.account'},
          ['Nickname'],
        ),
        'actual.account',
      );
      expect(
        pluginAccountDisplayIdentity(
          {'email': 'member@example.test'},
          ['Nickname'],
        ),
        'member@example.test',
      );
      expect(
        sanitizePluginAccountSummaryLines(
          ['Nickname', '会员编号：123', 'Lv.4'],
          {'uid': '123'},
        ),
        ['Nickname', '会员编号：123', 'Lv.4'],
      );
    },
  );
  testWidgets('management scope never reads declared account summary', (
    tester,
  ) async {
    await mount(tester, style: 'breeze', scope: PluginSettingsScope.management);
    expect(
      api.calls.where(
        (call) => call.contains('UserInfo') || call.contains('Login'),
      ),
      isEmpty,
    );
    expect(find.byType(PluginUserInfoCard), findsNothing);
    expect(find.byType(SettingChoice<dynamic>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'settings pull refresh reads the server summary without a toolbar refresh',
    (tester) async {
      await mount(tester, style: 'breeze', scope: PluginSettingsScope.all);
      final before = api.calls
          .where((fn) => fn == 'getSettingsUserInfoBundle')
          .length;
      api.summary = {
        'lines': ['Fresh server member'],
        'avatar': {},
        'extern': {},
      };
      expect(find.byTooltip(t.common.refresh), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('plugin-settings-sections')),
        const Offset(0, 350),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh server member'), findsOneWidget);
      expect(
        api.calls.where((fn) => fn == 'getSettingsUserInfoBundle').length,
        before + 1,
      );
      final contentContext = tester.element(find.byType(PluginSettingsContent));
      expect(
        contentContext.read<PluginSettingsCubit>().state.avatarRevision,
        1,
      );
      api.summary = {
        'lines': ['Second server member'],
        'avatar': {},
        'extern': {},
      };
      await tester.drag(
        find.byKey(const ValueKey('plugin-settings-sections')),
        const Offset(0, 350),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second server member'), findsOneWidget);
      expect(
        api.calls.where((fn) => fn == 'getSettingsUserInfoBundle').length,
        before + 2,
      );
      expect(
        contentContext.read<PluginSettingsCubit>().state.avatarRevision,
        2,
      );
      final update = find.text(t.about.checkUpdate);
      await tester.scrollUntilVisible(
        update,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('plugin-settings-sections')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        update,
        findsOneWidget,
        reason: 'binary update checking is an explicit management action',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verified API refresh keeps good identity on failure and fences late old account',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      pluginSessionWriteFence.advance(source);
      api.summary = {
        'lines': ['Original member'],
        'avatar': {'id': 'copy-A', 'path': 'member/avatar.jpg'},
        'extern': {'userId': 'copy-A', 'username': 'Original member'},
      };
      await mount(tester, style: 'breeze', source: source);
      expect(
        tester
            .widget<PluginUserInfoCard>(find.byType(PluginUserInfoCard))
            .avatarPath,
        'member/avatar.jpg',
      );
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'copy-A');
      final cubit = tester
          .element(find.byType(PluginSettingsContent))
          .read<PluginSettingsCubit>();
      final before = api.calls.where((fn) => fn == 'getUserInfoBundle').length;
      api.summaryError = StateError('transport unavailable');
      await tester.drag(
        find.byKey(const ValueKey('plugin-settings-sections')),
        const Offset(0, 350),
      );
      await tester.pumpAndSettle();
      expect(
        api.calls.where((fn) => fn == 'getUserInfoBundle').length,
        before + 1,
        reason: 'an existing verified receipt must not bypass server refresh',
      );
      expect(find.text('Original member'), findsOneWidget);
      expect(find.text(t.plugin.userInfoLoadFailed), findsOneWidget);
      expect(cubit.state.userInfoLoginRequired, isFalse);
      api.summaryError = null;
      final gate = api.summaryGate = Completer<Map<String, dynamic>>();
      final pending = cubit.loadUserInfo(source);
      await tester.pump();
      expect(
        find.text('Original member'),
        findsOneWidget,
        reason: 'refresh keeps useful content',
      );
      pluginSessionWriteFence.advance(source);
      PluginAccountIdentities.confirm(
        source,
        const PluginAccountAuthentication(
          serverIdentity: 'copy-B',
          label: 'Current member',
        ),
        generation: pluginSessionWriteFence.generation(source),
      );
      gate.complete({
        'extern': {'userId': 'copy-A', 'username': 'Stale member'},
      });
      await tester.runAsync(() => pending);
      await tester.pumpAndSettle();
      expect(find.text('Current member'), findsOneWidget);
      expect(find.text('Stale member'), findsNothing);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'copy-B');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Copy Auto applies only the completed route and refreshes its account once',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      const speed = {'fnPath': 'testLineSpeeds', 'title': '测速'};
      const field = <String, dynamic>{
        'key': 'api.domain',
        'kind': 'select',
        'label': '访问线路',
        'fnPath': 'saveSettings',
        'persist': false,
        'options': [
          {'value': 'line-a', 'label': 'Line A'},
          {'value': 'auto', 'label': '自动（选最快）'},
        ],
      };
      await savePluginConfigValue(source, 'api.domain', 'line-a');
      await savePluginConfigValue(source, 'network.autoRoute.v1', 'line-a');
      api.settingsValues = {'api.domain': 'line-a'};
      api.sections = [
        {
          'id': 'network',
          'title': '网络',
          'headerAction': speed,
          'fields': [field],
        },
      ];
      api.summary = {
        'extern': {'userId': 'member-a', 'username': 'Member A'},
      };
      await mount(
        tester,
        style: 'breeze',
        source: source,
        scope: PluginSettingsScope.all,
      );
      final page = find.byType(PluginSettingsContent);
      final cubit = tester.element(page).read<PluginSettingsCubit>();
      int reads() => api.calls.where((fn) => fn == 'getUserInfoBundle').length;
      final initialReads = reads();
      final started = Completer<void>();
      final finish = Completer<void>();
      api.copyNetwork = (runtime, fn, args) async {
        if (fn == 'saveSettings') {
          expect(args['key'], 'api.domain');
          expect(args['value'], 'auto');
          onSavePluginConfig(runtime, 'api.domain', '"auto"');
          api.settingsValues = {'api.domain': 'auto'};
          return {'ok': true, 'effectiveRouteChanged': false};
        }
        onSavePluginConfig(runtime, 'network.autoRoute.v1', '"line-b"');
        started.complete();
        await finish.future;
        api.summary = {
          'extern': {'userId': 'member-b', 'username': 'Member B'},
        };
        return {'ok': true, 'effectiveRouteChanged': true};
      };
      await tester
          .widget<PluginSettingsContent>(page)
          .onCommitField(field, 'auto');
      await tester.pumpAndSettle();
      expect(cubit.state.values['api.domain'], 'auto');
      expect(reads(), initialReads);
      final measurement = tester
          .widget<PluginSettingsContent>(page)
          .onRunAction(speed);
      await started.future;
      await tester.pump();
      expect(reads(), initialReads);
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'member-a',
      );
      finish.complete();
      await measurement;
      await tester.pumpAndSettle();
      expect(reads(), initialReads + 1);
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'member-b',
      );
      expect(cubit.state.values['api.domain'], 'auto');
      expect(
        loadPluginConfigValue(source, 'network.autoRoute.v1', fallback: ''),
        'line-b',
      );
    },
  );

  testWidgets(
    'Copy route commit refreshes settings account and rejects an old line error',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      const field = <String, dynamic>{
        'key': 'api.domain',
        'kind': 'select',
        'label': '访问线路',
        'fnPath': 'saveSettings',
        'options': [
          {'value': 'old settings line', 'label': 'Old line'},
          {'value': 'working settings line', 'label': 'Working line'},
        ],
      };
      await savePluginConfigValue(source, 'api.domain', 'old settings line');
      api.settingsValues = {'api.domain': 'old settings line'};
      api.sections = [
        {
          'id': 'network',
          'title': '网络',
          'fields': [field],
        },
      ];
      api.summary = {
        'extern': {
          'userId': 'copy-old-line',
          'username': 'Previous line member',
        },
      };
      await mount(
        tester,
        style: 'breeze',
        source: source,
        scope: PluginSettingsScope.all,
      );
      final page = find.byType(PluginSettingsContent);
      final cubit = tester.element(page).read<PluginSettingsCubit>();
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'copy-old-line',
      );
      final oldGate = api.summaryGate = Completer<Map<String, dynamic>>();
      final oldRead = cubit.loadUserInfo(source);
      await tester.pump();
      final before = api.calls.where((fn) => fn == 'getUserInfoBundle').length;
      api.summaryGate = null;
      api.summary = {
        'extern': {
          'userId': 'copy-current-line',
          'username': 'Current line member',
        },
      };
      await tester
          .widget<PluginSettingsContent>(page)
          .onCommitField(field, 'working settings line');
      await tester.pump();
      expect(
        loadPluginConfigValue(source, 'api.domain', fallback: ''),
        'working settings line',
      );
      expect(
        api.calls.where((fn) => fn == 'getUserInfoBundle').length,
        before + 1,
      );
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'copy-current-line',
      );
      oldGate.completeError(
        AnyhowException('{"type":"unauthorized","message":"old line denied"}'),
      );
      await oldRead;
      await tester.pumpAndSettle();
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'copy-current-line',
      );
      expect(cubit.state.userInfoLoginRequired, isFalse);
      expect(cubit.state.userInfo['hostVerified'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (scenario, unauthorized, callbackFails) in [
    ('stale success', false, false),
    ('stale unauthorized', true, false),
    ('failed callback', true, true),
  ]) {
    testWidgets(
      'JM API line waits for runtime and fences stale account: $scenario',
      (tester) async {
        const source = PluginAccountAuthenticationService.jm;
        const key = 'network.apiBase';
        const oldLine = 'https://old-line.invalid';
        const newLine = 'https://new-line.invalid';
        const field = <String, dynamic>{
          'key': key,
          'kind': 'choice',
          'label': '接口线路',
          'fnPath': 'onNetworkChanged',
          'options': [
            {'value': oldLine, 'label': 'Old JM line'},
            {'value': newLine, 'label': 'New JM line'},
          ],
        };
        Map<String, dynamic> proof(String name) => {
          'accountId': 'jm-route-account',
          'nickname': name,
          'profileDataSource': 'serverUserEdit',
        };
        pluginSessionWriteFence.advance(source);
        await savePluginConfigValue(source, key, oldLine);
        api.canShowUserInfo = true;
        api.settingsValues = {key: oldLine};
        api.sections = [
          {
            'id': 'network',
            'title': '网络',
            'fields': [field],
          },
        ];
        var runtimeLine = oldLine;
        final readLines = <String>[];
        final oldGate = Completer<Map<String, dynamic>>();
        api.jmProfile = () async {
          readLines.add(runtimeLine);
          if (readLines.length == 1) return proof('Previous JM member');
          if (readLines.length == 2) return oldGate.future;
          return proof(
            runtimeLine == oldLine ? 'Retried JM member' : 'Current JM member',
          );
        };
        final persisted = Completer<void>();
        final runtimeReady = Completer<void>();
        final routeWrites = <(String, Object?)>[];
        api.jmNetworkChange = (runtime, changedKey, value) async {
          routeWrites.add((changedKey, value));
          onSavePluginConfig(runtime, changedKey, jsonEncode(value));
          persisted.complete();
          await runtimeReady.future;
          if (callbackFails) throw StateError('Line callback failed');
          runtimeLine = newLine;
          api.settingsValues = {key: newLine};
        };
        await mount(
          tester,
          style: 'breeze',
          source: source,
          scope: PluginSettingsScope.all,
        );
        final page = find.byType(PluginSettingsContent);
        final cubit = tester.element(page).read<PluginSettingsCubit>();
        expect(find.text('Previous JM member'), findsOneWidget);
        final oldRead = cubit.loadUserInfo(source);
        await tester.pump();
        expect(readLines, [oldLine, oldLine]);
        final change = tester
            .widget<PluginSettingsContent>(page)
            .onCommitField(field, newLine);
        await tester.pump();
        expect(routeWrites, [(key, newLine)]);
        expect(persisted.isCompleted, isTrue);
        expect(loadPluginConfigValue(source, key, fallback: ''), newLine);
        var manualReadCompleted = false;
        unawaited(
          cubit.loadUserInfo(source).then((_) {
            manualReadCompleted = true;
          }),
        );
        await tester.pump();
        expect(manualReadCompleted, isTrue);
        expect(readLines, [oldLine, oldLine]);
        if (!unauthorized) {
          oldGate.complete(proof('Stale JM member'));
          await oldRead;
          await tester.pump();
          expect(find.text('Previous JM member'), findsOneWidget);
          expect(find.text('Stale JM member'), findsNothing);
        }
        runtimeReady.complete();
        await change;
        await tester.pumpAndSettle();
        if (callbackFails) {
          expect(readLines, [oldLine, oldLine]);
          expect(find.text('Previous JM member'), findsOneWidget);
          expect(cubit.state.loadingUserInfo, isFalse);
          expect(cubit.state.values[key], oldLine);
          await cubit.loadUserInfo(source);
          await tester.pumpAndSettle();
        }
        final currentName = callbackFails
            ? 'Retried JM member'
            : 'Current JM member';
        expect(readLines, [
          oldLine,
          oldLine,
          callbackFails ? oldLine : newLine,
        ]);
        expect(find.text(currentName), findsOneWidget);
        if (unauthorized) {
          oldGate.completeError(
            AnyhowException(
              '{"type":"unauthorized","message":"old JM line denied"}',
            ),
          );
          await oldRead;
          await tester.pumpAndSettle();
        }
        expect(PluginAccountIdentities.current(source)?.label, currentName);
        expect(cubit.state.values[key], callbackFails ? oldLine : newLine);
        expect(cubit.state.userInfoLoginRequired, isFalse);
        expect(find.text(currentName), findsOneWidget);
      },
    );
  }

  for (final (mode, changed) in [
    ('measure', true),
    ('measure', false),
    ('images-auto', true),
    ('images-auto', false),
  ]) {
    testWidgets(
      'JM $mode checks the saved session after an effective API change: $changed',
      (tester) async {
        const source = PluginAccountAuthenticationService.jm;
        const oldApi = 'https://old-api.invalid';
        const newApi = 'https://new-api.invalid';
        const imageKey = 'network.imageBase';
        const action = <String, dynamic>{
          'key': 'speedtest',
          'title': '测速',
          'fnPath': 'measureEndpointSpeeds',
        };
        const field = <String, dynamic>{
          'key': imageKey,
          'kind': 'choice',
          'label': '图片线路',
          'fnPath': 'onNetworkChanged',
          'options': [
            {'value': '', 'label': '自动'},
            {'value': 'https://fixed-image.invalid', 'label': '固定图片'},
          ],
        };
        pluginSessionWriteFence.advance(source);
        api.canShowUserInfo = true;
        api.jmEffectiveRouteChanged = changed;
        api.settingsValues = {
          'network.apiBase': '',
          imageKey: 'https://fixed-image.invalid',
        };
        api.sections = [
          {
            'id': 'network',
            'title': '网络',
            'headerAction': action,
            'fields': [field],
          },
        ];
        api.actions = [action];
        var runtimeLine = oldApi;
        final reads = <String>[];
        final oldRequest = Completer<Map<String, dynamic>>();
        api.jmProfile = () async {
          reads.add(runtimeLine);
          if (changed && reads.length == 2) return oldRequest.future;
          return {
            'accountId': 'jm-effective-account',
            'nickname': runtimeLine == newApi
                ? 'New API member'
                : 'Old API member',
            'profileDataSource': 'serverUserEdit',
          };
        };
        final release = Completer<void>();
        final commits = <(String, Object?)>[];
        Future<void> applyRoute() async {
          await release.future;
          if (changed) runtimeLine = newApi;
        }

        api.jmMeasurement = applyRoute;
        api.jmNetworkChange = (runtime, key, value) async {
          commits.add((key, value));
          await applyRoute();
          api.settingsValues[imageKey] = value;
        };
        await mount(
          tester,
          style: mode == 'measure' ? 'breeze' : 'system',
          source: source,
          scope: PluginSettingsScope.all,
        );
        final page = find.byType(PluginSettingsContent);
        final cubit = tester.element(page).read<PluginSettingsCubit>();
        expect(reads, [oldApi]);
        final staleRead = changed
            ? cubit.loadUserInfo(source)
            : Future<void>.value();
        await tester.pump();
        final content = tester.widget<PluginSettingsContent>(page);
        final work = mode == 'measure'
            ? content.onRunAction(action)
            : content.onCommitField(field, '');
        await tester.pump();
        if (mode == 'images-auto') expect(commits, [(imageKey, '')]);
        expect(isPluginEndpointUpdating(source), isTrue);
        expect(
          tester.widget<PluginSettingsContent>(page).jmEndpointBusy,
          isTrue,
        );
        await cubit.loadUserInfo(source);
        expect(reads, changed ? [oldApi, oldApi] : [oldApi]);
        release.complete();
        await work;
        await tester.pumpAndSettle();
        expect(isPluginEndpointUpdating(source), isFalse);
        expect(reads, changed ? [oldApi, oldApi, newApi] : [oldApi]);
        if (changed) {
          oldRequest.completeError(
            AnyhowException(
              '{"type":"unauthorized","message":"old API denied"}',
            ),
          );
          await staleRead;
          await tester.pumpAndSettle();
        }
        expect(cubit.state.userInfoLoginRequired, isFalse);
        expect(
          PluginAccountIdentities.current(source)?.label,
          changed ? 'New API member' : 'Old API member',
        );
        expect(api.calls, isNot(contains('loginWithPassword')));
        expect(api.calls, isNot(contains('getUserInfoBundle')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy Copy member 401 shows the settings login entry', (
    tester,
  ) async {
    const source = PluginAccountAuthenticationService.copy;
    const url =
        'https://fixture.invalid/api/v3/member/info?fixture=private-value';
    api.summary = {
      'extern': {'userId': 'copy-legacy', 'username': 'Legacy member'},
    };
    await mount(tester, style: 'breeze', source: source);
    final cubit = tester
        .element(find.byType(PluginSettingsContent))
        .read<PluginSettingsCubit>();
    expect(
      PluginAccountIdentities.current(source)?.serverIdentity,
      'copy-legacy',
    );
    final prompts = <NeedLogin>[];
    final subscription = eventBus.on<NeedLogin>().listen(prompts.add);
    addTearDown(subscription.cancel);

    api.summaryError = AnyhowException('Network request timed out: GET $url');
    await tester.runAsync(() => cubit.loadUserInfo(source));
    await tester.pumpAndSettle();
    expect(cubit.state.userInfoLoginRequired, isFalse);
    expect(find.text(t.login.networkUnavailable), findsOneWidget);
    expect(find.textContaining('private-value'), findsNothing);
    expect(
      PluginAccountIdentities.current(source)?.serverIdentity,
      'copy-legacy',
    );

    api.summaryError = AnyhowException(
      'HTTPError: Request failed with status code 403 Forbidden: GET $url',
    );
    await tester.runAsync(() => cubit.loadUserInfo(source));
    await tester.pumpAndSettle();
    expect(cubit.state.userInfoLoginRequired, isFalse);
    expect(find.text(t.plugin.userInfoLoadFailed), findsOneWidget);
    expect(
      PluginAccountIdentities.current(source)?.serverIdentity,
      'copy-legacy',
    );

    api.summaryError = AnyhowException(
      'HTTPError: Request failed with status code 401 Unauthorized: GET $url',
    );
    await tester.runAsync(() => cubit.loadUserInfo(source));
    await tester.pumpAndSettle();
    expect(cubit.state.userInfoLoginRequired, isTrue);
    expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
    expect(find.textContaining('private-value'), findsNothing);
    expect(PluginAccountIdentities.current(source), isNull);
    expect(prompts, isEmpty);
  });

  for (final (source, key, automatic, pinned, supported) in [
    (
      PluginAccountAuthenticationService.copy,
      'api.domain',
      'auto',
      false,
      true,
    ),
    (PluginAccountAuthenticationService.jm, 'network.apiBase', '', false, true),
    (
      PluginAccountAuthenticationService.jm,
      'network.imageBase',
      '',
      true,
      true,
    ),
    (_source, 'api.domain', 'auto', false, false),
    (
      PluginAccountAuthenticationService.copy,
      'api.platform',
      'auto',
      false,
      false,
    ),
  ]) {
    testWidgets(
      'route menu metadata stays scoped and selection separate: $source/$key',
      (tester) async {
        const target = 'https://route-full-name.fixture.invalid';
        const domain = 'route-full-name.fixture.invalid';
        api.settingsValues = {key: pinned ? target : automatic};
        api.sections = [
          {
            'id': 'network',
            'title': 'Network',
            'fields': [
              {
                'key': key,
                'kind': 'select',
                'label': 'Fixture route options',
                'options': [
                  {'value': automatic, 'label': 'Automatic'},
                  {
                    'value': target,
                    'label': 'Legacy route with full domain',
                    'routeOption': {
                      'title': 'Compact · 42 ms',
                      'domain': domain,
                      'inUse': true,
                    },
                  },
                  {'value': 'legacy', 'label': 'Legacy option'},
                ],
              },
            ],
          },
        ];
        await mount(tester, style: 'breeze', source: source, profile: false);
        final field = find.byKey(ValueKey('plugin-field-key:$key'));
        expect(field, findsOneWidget);
        final menu = tester.widget<NativeVideoMenu>(
          find.descendant(of: field, matching: find.byType(NativeVideoMenu)),
        );
        expect(menu.selected, pinned ? '1' : '0');
        expect(menu.label, pinned ? 'Compact' : 'Automatic');
        expect(
          menu.options['1'],
          supported ? 'Compact' : 'Legacy route with full domain',
        );
        expect(menu.options['2'], 'Legacy option');
        expect(menu.optionDetails, supported ? {'1': '42 ms'} : isEmpty);
        expect(menu.optionCopyText, supported ? {'1': domain} : isEmpty);
        expect(
          menu.optionBadges,
          supported && !pinned ? {'1': t.plugin.routeOptionInUse} : isEmpty,
        );
      },
    );
  }

  for (final style in ['breeze', 'system']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Copy network header speed action refreshes public labels and preserves portrait: $style/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const source = PluginAccountAuthenticationService.copy;
          pluginSessionWriteFence.advance(source);
          api.summary = {
            'lines': ['Copy member'],
            'avatar': {'id': 'copy-speed', 'path': 'profile.jpg'},
            'extern': {'userId': 'copy-speed', 'username': 'Copy member'},
          };
          api.actions = [
            {
              'key': 'line-speed',
              'fnPath': 'testLineSpeeds',
              'title': 'Measure source lines',
            },
          ];
          List<Map<String, dynamic>> network(String measuredLabel) => [
            {
              'id': 'network',
              'title': '网络',
              'headerAction': {
                'key': 'line-speed',
                'fnPath': 'testLineSpeeds',
                'title': '测速',
              },
              'fields': [
                {
                  'key': 'api.domain',
                  'kind': 'select',
                  'label': '访问线路',
                  'fnPath': 'saveSettings',
                  'options': [
                    {'value': '大陆专线3', 'label': measuredLabel},
                  ],
                },
                {
                  'key': 'api.platform',
                  'kind': 'select',
                  'label': '请求标识',
                  'fnPath': 'saveSettings',
                  'options': [
                    {'value': 'iphone', 'label': 'iPhone'},
                  ],
                },
              ],
            },
          ];
          api.settingsValues = {'api.platform': 'iphone'};
          api.sections = network('大陆3');
          const longLabel = '大陆3 · 1141ms · 旧 · mapi.copy2000.site';
          api.measuredSections = network(longLabel);
          await mount(
            tester,
            style: style,
            textScale: scale,
            source: source,
            scope: PluginSettingsScope.all,
          );
          final cubit = tester
              .element(find.byType(PluginSettingsContent))
              .read<PluginSettingsCubit>();
          final before = api.calls.length,
              portraitRevision = cubit.state.avatarRevision;
          final action = find.byKey(
            const ValueKey('plugin-section-action.testLineSpeeds'),
          );
          expect(action, findsOneWidget);
          expect(find.text('Measure source lines'), findsNothing);
          expect(find.text(t.plugin.operations), findsNothing);
          await tester.scrollUntilVisible(
            action,
            300,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('plugin-settings-sections')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
          Finder menu(String key) => find.descendant(
            of: find.byKey(ValueKey('plugin-field-key:$key')),
            matching: find.byType(NativeVideoMenu),
          );
          final route = menu('api.domain');
          final request = menu('api.platform');
          final routeBefore = tester.getRect(route);
          final requestBefore = tester.getRect(request);
          if (scale == 1) {
            expect(
              routeBefore.center.dy,
              closeTo(tester.getCenter(find.text('访问线路')).dy, 1),
            );
            expect(
              requestBefore.center.dy,
              closeTo(tester.getCenter(find.text('请求标识')).dy, 1),
            );
          }
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(tester.getRect(route), routeBefore);
          expect(tester.getRect(request), requestBefore);
          expect(tester.widget<NativeVideoMenu>(route).label, longLabel);
          expect(api.calls.skip(before).where((fn) => fn != 'init'), [
            'testLineSpeeds',
            'getSettingsBundle',
            'getCapabilitiesBundle',
          ]);
          expect(cubit.state.values['probeMs'], 20);
          expect(cubit.state.values['api.domain'], '大陆专线3');
          expect(cubit.state.userInfo['hostVerified'], isTrue);
          expect(cubit.state.avatarRevision, portraitRevision);
          expect(
            PluginAccountIdentities.current(source)?.serverIdentity,
            'copy-speed',
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
        }),
      );
    }
  }

  for (final style in ['breeze', 'system']) {
    for (final outcome in ['success', 'partial', 'failure', 'missing']) {
    testWidgets('legacy JM network uses the section speed action: $style/$outcome', (
      tester,
    ) async {
      const source = PluginAccountAuthenticationService.jm;
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<Map<String, dynamic>> network(String heading) => [
        {
          'id': 'network',
          'title': heading,
          'fields': [
            for (final (key, title) in [
              ('network.imageBase', '图片线路'),
              ('network.apiBase', '接口线路'),
            ])
              {
                'key': key,
                'label': title,
                'kind': 'choice',
                'fnPath': 'onNetworkChanged',
                'options': [
                  {'value': '', 'label': '默认'},
                ],
              },
          ],
        },
      ];
      api.jmMeasurementData = outcome == 'missing' ? {} : {
        'api': [{'ok': outcome != 'failure'}],
        'image': outcome == 'failure' ? [] : [{'ok': outcome == 'success'}],
      };
      final notices = <ToastEvent>[];
      final listener = eventBus.on<ToastEvent>().listen(notices.add);
      addTearDown(listener.cancel);
      api.sections = network('网络线路（未测速，可在下方操作区测试）');
      api.measuredSections = network('网络线路（测于 14:30）');
      api.actions = [
        {
          'key': 'speedtest',
          'title': '测试所有线路速度',
          'fnPath': 'measureEndpointSpeeds',
        },
      ];
      api.settingsValues = {'network.imageBase': '', 'network.apiBase': ''};
      await mount(
        tester,
        style: style,
        source: source,
        scope: PluginSettingsScope.all,
        textScale: 2,
      );
      final header = find.text('网络线路');
      final button = find.byKey(
        const ValueKey('plugin-section-action.measureEndpointSpeeds'),
      );
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('plugin-settings-sections')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(button, 250, scrollable: scroll);
      expect(find.text('测试所有线路速度'), findsNothing);
      expect(find.text('测速'), findsOneWidget);
      expect(
        tester.getCenter(header).dy,
        closeTo(tester.getCenter(button).dy, 1),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      expect(find.text('图片线路'), findsOneWidget);
      expect(find.text('接口线路'), findsOneWidget);
      final before = api.calls.length;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.calls.skip(before).where((fn) => fn != 'init'), [
        'measureEndpointSpeeds',
        'getSettingsBundle',
        'getCapabilitiesBundle',
      ]);
      expect(find.text('上次测速 14:30'), findsOneWidget);
      final notice = notices.last;
      expect(notice.type, switch (outcome) {
        'success' => ToastType.success,
        'partial' => ToastType.warning,
        _ => ToastType.error,
      });
      expect(notice.message, switch (outcome) {
        'success' => t.plugin.lineTestSuccess,
        'partial' => t.plugin.lineTestPartial,
        _ => t.plugin.lineTestFailure,
      });
      expect(find.text('图片线路'), findsOneWidget);
      expect(find.text('接口线路'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
