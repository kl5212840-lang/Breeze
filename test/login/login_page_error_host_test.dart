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
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';

class _LoginApi extends RustLibApi {
  String accountField = 'account';
  Object? failure;
  Object? schemeFailure;
  Map<String, dynamic>? schemeResponse;
  Map<String, dynamic>? response;
  Map<String, String> savedValues = const {};
  Completer<void>? pending;
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
      result = response ?? {'ok': false};
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
    api.submissions = 0;
    api.accountField = 'account';
    api.savedValues = const {};
  });
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
