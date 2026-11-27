import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';
const _legacySource = '017d270a-bc47-4c10-9e8d-e9b8a1125e2a';

class _LoginApi extends RustLibApi {
  String accountField = 'account';
  Object? failure;
  Object? schemeFailure;
  Map<String, dynamic>? schemeResponse;
  Map<String, dynamic>? response;
  Map<String, String> savedValues = const {};
  Completer<void>? pending;
  String? copyMember;
  bool legacyAccount = false;
  bool legacyOffline = false;
  bool legacySessionValid = false;
  int submissions = 0;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('login-error-fixture');
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
    Map<String, dynamic> result;
    if (fnPath == 'init') {
      result = {'ok': true};
    } else if (fnPath == 'getLoginBundle') {
      if (schemeFailure != null) throw schemeFailure!;
      if (schemeResponse != null) {
        return Uint8List.fromList(utf8.encode(jsonEncode(schemeResponse)));
      }
      result = {
        'scheme': {
          'title': 'Synthetic login',
          'fields': [
            {
              'key': accountField,
              'kind': 'text',
              'label': 'Account',
              'required': true,
            },
            {
              'key': 'password',
              'kind': 'password',
              'label': 'Password',
              'required': true,
            },
          ],
          'submitFnPath': 'loginWithPassword',
          'submitText': 'Synthetic sign in',
        },
        'data': {'values': savedValues},
      };
    } else if (fnPath == 'loginWithPassword') {
      submissions++;
      final args = jsonDecode(argsJson) as Map;
      expect(args[accountField], 'fixture-user');
      expect(args['password'], 'fixture-password');
      expect((args['values'] as Map)[accountField], 'fixture-user');
      await pending?.future;
      if (failure != null) throw failure!;
      if (copyMember != null) {
        replaceActivePluginAccount(PluginAccountAuthenticationService.copy, {
          'auth.username': 'fixture-user',
          'auth.token': 'new-fixture-token',
        });
      }
      if (legacyAccount) {
        replaceActivePluginAccount(_legacySource, {
          'auth.username': 'fixture-user',
          'auth.token': 'legacy-fixture-new-session',
        });
        legacySessionValid = true;
        result = {
          'data': {'ok': true},
        };
      } else {
        result = response ?? {'ok': false};
      }
    } else if (fnPath == 'getUserInfoBundle' && copyMember != null) {
      result = {
        'data': {
          'extern': {'userId': copyMember, 'username': 'Verified fixture user'},
        },
      };
    } else if (fnPath == 'getUserInfoBundle' && legacyAccount) {
      result = {
        'scheme': {'type': 'userInfo'},
        'data': {
          'title': legacySessionValid ? 'Fixture nickname' : '登录已失效',
          'avatar': {'id': 'avatar'},
          'lines': [
            if (legacyOffline)
              'Network request timed out'
            else if (!legacySessionValid)
              '{"type":"unauthorized","source":"$_legacySource","message":"private fixture"}',
          ],
        },
      };
    } else {
      throw StateError('Unexpected plugin function $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected bridge ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _LoginApi();
  final channels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
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
    SharedPreferences.setMockInitialValues({});
    api.failure = null;
    api.schemeFailure = null;
    api.schemeResponse = null;
    api.response = null;
    api.pending = null;
    api.copyMember = null;
    api.legacyAccount = false;
    api.legacyOffline = false;
    api.legacySessionValid = false;
    api.submissions = 0;
    api.accountField = 'account';
    api.savedValues = const {};
  });
  testWidgets(
    'legacy native recovery uses the selected record and a fresh bound login',
    (tester) async {
      api.legacyAccount = true;
      api.accountField = 'username';
      api.savedValues = {
        'username': 'other-fixture-user',
        'password': 'other-fixture-password',
      };
      replaceActivePluginAccount(_legacySource, {
        'auth.username': 'fixture-user',
        'auth.token': 'legacy-expired-session',
      });
      await PluginAccountProfiles.rememberCurrent(_legacySource);
      final target = PluginAccountProfiles.read(
        _legacySource,
      ).profiles.values.single;
      const previous = {
        'auth.username': 'other-fixture-user',
        'auth.token': 'other-fixture-session',
        'auth.password': 'other-fixture-password',
      };
      replaceActivePluginAccount(_legacySource, previous);
      await tester.pumpWidget(
        MaterialApp(
          home: PluginSavedAccountsPage(
            source: _legacySource,
            nativeLoginSupported: true,
            onAddAccount: () async => fail('Expected selected-account login'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey('saved-account-${target.id}'));
      final retry = find.byKey(const ValueKey('saved-account-retry'));
      final recover = find.text(t.accountProfiles.continueLogin);
      api.legacyOffline = true;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(t.login.networkUnavailable), findsOneWidget);
      expect(recover, findsNothing);
      expect(api.submissions, 0);
      expect(
        readHostPluginConfiguration(_legacySource)['auth.token'],
        previous['auth.token'],
      );

      api.legacyOffline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text(t.accountProfiles.savedSignInRequired), findsOneWidget);
      expect(retry, findsNothing);
      expect(find.textContaining('private fixture'), findsNothing);

      await tester.tap(recover);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      TextField field(int index) => tester.widget<TextField>(fields.at(index));
      expect(field(0).controller!.text, 'fixture-user');
      expect(field(0).readOnly, isTrue);
      expect(field(1).controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('login.remember')));
      await tester.enterText(fields.last, 'fixture-password');
      await tester.tap(find.byKey(const ValueKey('login.submit')));
      await tester.pumpAndSettle();
      expect(api.submissions, 1);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text(t.accountProfiles.current), findsOneWidget);
      expect(await PluginAccountProfiles.selected(_legacySource), target.id);
      final restored = PluginAccountIdentities.current(_legacySource)!;
      expect(restored.serverIdentity, isEmpty);
      expect(restored.loginIdentity, 'fixture-user');
      expect(
        onLoadPluginConfig(_legacySource, hostRememberedPluginLoginKey, 'null'),
        '{"ok":true,"value":null}',
      );
      expect(
        onLoadPluginConfig(_legacySource, '', 'null'),
        isNot(contains('fixture-password')),
      );
      expect(
        PluginAccountProfiles.savedNativePassword(
          PluginAccountProfiles.read(_legacySource).profiles[target.id]!,
        ),
        'fixture-password',
      );

      replaceActivePluginAccount(_legacySource, previous);
      api.legacySessionValid = false;
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(recover);
      await tester.pumpAndSettle();
      expect(field(0).controller!.text, 'fixture-user');
      expect(field(1).controller!.text, 'fixture-password');
      expect(field(1).obscureText, isTrue);
      Navigator.of(tester.element(find.byType(LoginPage))).pop();
      await tester.pumpAndSettle();
      expect(recover, findsOneWidget);
      expect(api.submissions, 1);
      expect(
        readHostPluginConfiguration(_legacySource)['auth.token'],
        previous['auth.token'],
      );
    },
  );
  testWidgets(
    'saved-account form verifies the requested profile before replacing the current login',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      replaceActivePluginAccount(source, {
        'auth.username': 'fixture-user',
        'auth.token': 'old-fixture-token',
      });
      await PluginAccountProfiles.rememberCurrent(
        source,
        serverIdentity: 'expected-member',
      );
      final target = PluginAccountProfiles.read(source).profiles.values.single;
      replaceActivePluginAccount(source, {
        'auth.username': 'current-user',
        'auth.token': 'current-fixture-token',
      });
      api.accountField = 'username';
      api.savedValues = {
        'username': 'current-user',
        'password': 'other-fixture-password',
      };
      api.response = {'ok': true};
      api.copyMember = 'different-member';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => openPluginAccountLoginForm(
                  context,
                  source: source,
                  username: target.identity,
                  savedAccount: (id: target.id, revision: target.revision),
                ),
                child: const Text('Open saved login'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open saved login'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'fixture-user',
      );
      expect(tester.widget<TextField>(fields.last).controller!.text, isEmpty);
      await tester.enterText(fields.last, 'fixture-password');
      final submit = find.byKey(const ValueKey('login.submit'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submissions, 1);
      expect(find.byKey(const ValueKey('login.submit-error')), findsOneWidget);
      expect(
        readHostPluginConfiguration(source)['auth.token'],
        'current-fixture-token',
      );
      expect(await PluginAccountProfiles.selected(source), isNull);

      api.copyMember = 'expected-member';
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submissions, 2);
      expect(find.byType(LoginPage), findsNothing);
      expect(await PluginAccountProfiles.selected(source), target.id);
      expect(
        readHostPluginConfiguration(source)['auth.token'],
        'new-fixture-token',
      );
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'expected-member',
      );
    },
  );
  for (final accountField in ['username', 'account']) {
    testWidgets(
      'relogin uses only matching saved credentials for $accountField',
      (tester) async {
        api.accountField = accountField;
        api.savedValues = {
          accountField: 'current-user',
          'password': 'fixture-saved',
        };
        Future<void> open({String? username, int? recoveryGeneration}) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => openPluginAccountLoginForm(
                      context,
                      source: _source,
                      username: username,
                      recoveryGeneration: recoveryGeneration,
                    ),
                    child: const Text('Open login'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open login'));
          await tester.pumpAndSettle();
        }

        TextField field(int index) =>
            tester.widget<TextField>(find.byType(TextField).at(index));
        Future<void> close() async {
          Navigator.of(tester.element(find.byType(LoginPage))).pop();
          await tester.pumpAndSettle();
        }

        await open(username: 'current-user', recoveryGeneration: 0);
        expect(field(0).controller!.text, 'current-user');
        expect(field(1).controller!.text, 'fixture-saved');
        expect(field(1).obscureText, isTrue);
        await tester.enterText(find.byType(TextField).first, 'different-user');
        expect(field(1).controller!.text, isEmpty);
        await close();

        await open(username: 'different-user', recoveryGeneration: 0);
        expect(field(1).controller!.text, isEmpty);
        await close();

        await open(username: 'current-user', recoveryGeneration: 1);
        expect(field(1).controller!.text, isEmpty);
        await close();

        api.savedValues = {accountField: 'current-user'};
        await open(username: 'current-user', recoveryGeneration: 0);
        expect(field(0).controller!.text, 'current-user');
        expect(field(1).controller!.text, isEmpty);
        await close();

        api.savedValues = {
          accountField: 'current-user',
          'password': 'fixture-saved',
        };
        await open();
        expect(field(0).controller!.text, isEmpty);
        expect(field(1).controller!.text, isEmpty);
        await close();
        expect(api.submissions, 0);
      },
    );
  }
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  Future<void> mount(
    WidgetTester tester,
    String style, {
    Brightness brightness = Brightness.light,
  }) async {
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              fontFamily: uiPreviewDirectory == null ? null : 'AccountPreview',
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('login-preview'),
              child: child!,
            ),
            home: const LoginPage(from: _source),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'fixture-user');
    await tester.enterText(find.byType(TextField).at(1), 'fixture-password');
  }

  final submit = find.byKey(const ValueKey('login.submit'));
  for (final kind in ['network', 'missingFunction', 'rateLimitedEnvelope']) {
    testWidgets('login schema failures retain the actual cause: $kind', (
      tester,
    ) async {
      final missingFunction = kind == 'missingFunction';
      if (kind == 'rateLimitedEnvelope') {
        api.schemeResponse = {
          'data': {'code': 429},
        };
      } else {
        api.schemeFailure = AnyhowException(
          '[bundle:fixture fn:getLoginBundle source:fixture.cjs] '
          '${missingFunction ? 'function path not found' : 'connection reset'}',
        );
      }
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: BlocProvider(
            create: (_) => GlobalSettingCubit(),
            child: const MaterialApp(home: LoginPage(from: _source)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          missingFunction
              ? t.login.loginNotSupported
              : t.login.loadConfigFailed(
                  error: kind == 'rateLimitedEnvelope'
                      ? t.login.rateLimited
                      : t.login.networkUnavailable,
                ),
        ),
        findsOneWidget,
      );
      expect(find.text(t.login.retry), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(api.submissions, 0);
    });
  }
  if (uiPreviewDirectory != null) {
    for (final style in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets('login error render $style ${brightness.name}', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          api.failure = const FormatException('Too many login attempts');
          await mount(tester, style, brightness: brightness);
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(find.text(t.login.rateLimited), findsOneWidget);
          await writeUiPreview(
            tester,
            const ValueKey('login-preview'),
            'login-$style-${brightness.name}',
          );
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
      }
    }
  }
  for (final style in ['system', 'breeze']) {
    for (final schema in ['Bika', 'JM', 'Copy', 'Unknown third party']) {
      testWidgets(
        '$style $schema real login adapter retains safe rejection inline and allows manual retry',
        (tester) async {
          api.accountField = schema == 'Copy' || schema == 'Unknown third party'
              ? 'username'
              : 'account';
          api.failure = AnyhowException(
            '[bundle:fixture fn:login source:fixture.cjs] Invalid username or password\n[stack-hook] args:{"password":"fixture-password"}',
          );
          api.pending = Completer<void>();
          var succeeded = 0;
          final sub = eventBus.on<PluginLoginSucceeded>().listen(
            (_) => succeeded++,
          );
          addTearDown(sub.cancel);
          await mount(tester, style);
          await tester.tap(submit);
          await tester.pump();
          expect(api.submissions, 1);
          expect(tester.widget<TextButton>(submit).onPressed, isNull);
          await tester.tap(submit);
          await tester.pump();
          expect(api.submissions, 1);
          api.pending!.complete();
          await tester.pumpAndSettle();
          expect(find.text(t.login.invalidCredentials), findsOneWidget);
          expect(
            find.byKey(const ValueKey('login.submit-error')),
            findsOneWidget,
          );
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            tester
                .widget<TextField>(find.byType(TextField).at(0))
                .controller!
                .text,
            'fixture-user',
          );
          expect(
            tester
                .widget<TextField>(find.byType(TextField).at(1))
                .controller!
                .text,
            'fixture-password',
          );
          expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
          expect(succeeded, 0);
          expect(find.textContaining('stack-hook'), findsNothing);
          api.pending = null;
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(api.submissions, 2);
          expect(succeeded, 0);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  for (final (reason, kind) in [
    ('HTTP 401', LoginFailureKind.rejected),
    ('Captcha verification failed', LoginFailureKind.verification),
    ('Too many login attempts', LoginFailureKind.rateLimited),
    ('Connection reset', LoginFailureKind.network),
    ('Client access restricted', LoginFailureKind.clientRestricted),
    ('Account suspended', LoginFailureKind.accountRestricted),
    (
      'private diagnostic password=fixture-password https://private.test/raw',
      LoginFailureKind.unknown,
    ),
  ]) {
    testWidgets(
      'explicit failed envelope passes through the real adapter without a success event: ${kind.name}',
      (tester) async {
        api.response = {
          'data': {'success': false, 'message': reason},
        };
        var succeeded = 0;
        final sub = eventBus.on<PluginLoginSucceeded>().listen(
          (_) => succeeded++,
        );
        addTearDown(sub.cancel);
        await mount(tester, 'breeze');
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text(userFacingLoginFailureMessage(kind)), findsOneWidget);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(succeeded, 0);
        expect(find.textContaining('private.test'), findsNothing);
        expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  for (final (label, response, kind) in [
    (
      'top status without flag',
      <String, dynamic>{'status': 429},
      LoginFailureKind.rateLimited,
    ),
    (
      'nested code with empty failure reason',
      <String, dynamic>{
        'data': {'success': false, 'code': 429, 'message': ''},
      },
      LoginFailureKind.rateLimited,
    ),
    (
      'legacy code without flag',
      <String, dynamic>{'code': 401},
      LoginFailureKind.rejected,
    ),
    (
      'nested HTTP failure without flag',
      <String, dynamic>{
        'data': {'status': 503},
      },
      LoginFailureKind.rejected,
    ),
    (
      'explicit credential reason with status',
      <String, dynamic>{
        'data': {'code': 401, 'message': 'Invalid email or password'},
      },
      LoginFailureKind.credentials,
    ),
    (
      'confirmed limit survives private diagnostics',
      <String, dynamic>{
        'ok': false,
        'status': 429,
        'message': 'unknown failure args:password=fixture-password',
      },
      LoginFailureKind.rateLimited,
    ),
  ]) {
    testWidgets(
      'HTTP failed envelope keeps the real login host open without success: $label',
      (tester) async {
        api.response = response;
        var succeeded = 0;
        final sub = eventBus.on<PluginLoginSucceeded>().listen(
          (_) => succeeded++,
        );
        addTearDown(sub.cancel);
        await mount(tester, 'breeze');
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text(userFacingLoginFailureMessage(kind)), findsOneWidget);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(succeeded, 0);
        expect(api.submissions, 1);
        expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          'fixture-password',
        );
        expect(find.textContaining('args:'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
