import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_account_page.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _Cookies implements VideoAccountCookies {
  int writes = 0;
  final values = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async => [...values];
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
    values.add({...cookie});
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
    values.removeWhere((value) => value['name'] == cookie['name']);
  }
}

Map<String, dynamic> _snapshot() => {
  'version': 1,
  'origin': 'https://hanime1.me',
  'name': 'Backup account',
  'cookies': [
    {
      'name': 'session',
      'value': 'private fixture token',
      'domain': 'hanime1.me',
      'path': '/',
      'httpOnly': true,
      'secure': true,
    },
  ],
};

Future<void> _open(
  WidgetTester tester, {
  required String style,
  Brightness brightness = Brightness.dark,
  required VideoAccountService service,
  bool Function()? hasSavedCredentials,
  Future<void> Function()? backupCurrent,
  VoidCallback? onLogin,
  Future<void> Function()? onCloudSettings,
}) async {
  // Keep the actual iOS route and native chrome boundary; mock only its channel.
  final nativeChannels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
    call,
  ) async {
    if (call.method == 'create') {
      final args = call.arguments as Map;
      final channel = MethodChannel('${args['viewType']}.${args['id']}');
      nativeChannels.add(channel);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
  final preference = ValueNotifier(style);
  addTearDown(preference.dispose);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppInterfaceStyleScope(
      style: preference,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                videoPageRoute(
                  networkSource: 'hanime-recovery-fixture',
                  builder: (_) => VideoAccountPage(
                    service: service,
                    hasSavedCredentials: hasSavedCredentials,
                    backupCurrent: backupCurrent ?? () async {},
                    onLogin: onLogin ?? () {},
                    onCloudSettings: onCloudSettings ?? () async {},
                  ),
                ),
              ),
              child: const Text('open recovery'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open recovery'));
  await tester.pumpAndSettle();
  expect(find.byType(SettingPageShell), findsOneWidget);
  final page = tester.element(find.byType(VideoAccountPage));
  expect(VideoNetworkScope.maybeOf(page)?.source, 'hanime-recovery-fixture');
}

Future<void> _tap(
  WidgetTester tester,
  String text, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(find.text(text), delta);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  // Confirmation intentionally keeps the operation busy; its progress
  // indicator is indeterminate until the user chooses an action.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$style ${brightness.name} account route separates saved details from an empty session and opens login',
        (tester) async {
          var login = 0;
          final cookies = _Cookies();
          final service = VideoAccountService(
            origin: Uri.parse('https://hanime1.me/'),
            cookies: cookies,
            call: (_, _) async => {
              'data': {'backup': null},
            },
            readFn: 'read',
            saveFn: 'save',
            forgetFn: 'forget',
          );
          await _open(
            tester,
            style: style,
            brightness: brightness,
            service: service,
            hasSavedCredentials: () => true,
            onLogin: () => login++,
          );
          expect(
            find.text(t.videoAccount.recoveryDetailsSaved),
            findsOneWidget,
          );
          await _tap(tester, t.videoAccount.login);
          expect(login, 1);
          await tester.scrollUntilVisible(
            find.text(t.videoAccount.restore),
            250,
          );
          expect(
            tester
                .widget<ListTile>(
                  find.widgetWithText(ListTile, t.videoAccount.restore),
                )
                .onTap,
            isNull,
          );
          expect(cookies.writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        '$style ${brightness.name} restoring an existing backup needs consent and does not claim login',
        (tester) async {
          final feedback = <ToastEvent>[];
          final subscription = eventBus.on<ToastEvent>().listen(feedback.add);
          addTearDown(subscription.cancel);
          var login = 0;
          final cookies = _Cookies();
          final service = VideoAccountService(
            origin: Uri.parse('https://hanime1.me/'),
            cookies: cookies,
            call: (_, _) async => {
              'data': {'backup': _snapshot()},
            },
            readFn: 'read',
            saveFn: 'save',
            forgetFn: 'forget',
          );
          await _open(
            tester,
            style: style,
            brightness: brightness,
            service: service,
            onLogin: () => login++,
          );
          expect(
            find.text(t.videoAccount.recoveryDetailsEmpty),
            findsOneWidget,
          );
          await _tap(tester, t.videoAccount.restore);
          expect(find.text(t.videoAccount.restorePrompt), findsOneWidget);
          expect(cookies.writes, 0);
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          expect(cookies.writes, 0);
          expect(
            feedback,
            isEmpty,
            reason: 'Cancel does not report completion',
          );
          await _tap(tester, t.videoAccount.restore);
          await tester.tap(find.text(t.common.confirm));
          await tester.pumpAndSettle();
          expect(cookies.writes, 1);
          expect(login, 0);
          expect(feedback, hasLength(1));
          expect(feedback.single.type, ToastType.success);
          expect(feedback.single.message, t.videoAccount.restored);
          await tester.scrollUntilVisible(
            find.text(t.videoAccount.restored),
            -250,
          );
          expect(find.text(t.videoAccount.restored), findsOneWidget);
          expect(
            find.text('Backup account'),
            findsOneWidget,
            reason: 'The restore target must remain identifiable',
          );
          expect(find.text('private fixture token'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'cloud return refresh failure blocks stale restore; retry keeps login reachable',
    (tester) async {
      final feedback = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(feedback.add);
      addTearDown(subscription.cancel);
      var failRead = false;
      Completer<Map<String, dynamic>>? pendingRead;
      var login = 0;
      final cookies = _Cookies();
      final service = VideoAccountService(
        origin: Uri.parse('https://hanime1.me/'),
        cookies: cookies,
        call: (_, _) async {
          if (failRead) throw StateError('fixture read failure');
          if (pendingRead != null) return pendingRead.future;
          return {
            'data': {'backup': _snapshot()},
          };
        },
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      await _open(
        tester,
        style: 'system',
        service: service,
        onLogin: () => login++,
        onCloudSettings: () async => failRead = true,
        backupCurrent: () async => throw StateError('fixture backup failure'),
      );
      await _tap(tester, t.videoAccount.cloud);
      await tester.scrollUntilVisible(find.text(t.videoAccount.restore), -250);
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, t.videoAccount.restore),
            )
            .onTap,
        isNull,
      );
      expect(find.text(t.videoAccount.empty), findsNothing);
      await _tap(tester, t.videoAccount.backup);
      await tester.tap(find.text(t.common.confirm));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(t.videoAccount.failed), -250);
      expect(find.text(t.videoAccount.failed), findsOneWidget);
      expect(feedback, hasLength(1));
      expect(feedback.single.type, ToastType.error);
      expect(feedback.single.message, t.videoAccount.failed);
      failRead = false;
      pendingRead = Completer<Map<String, dynamic>>();
      await _tap(tester, t.common.retry);
      for (final title in [t.videoAccount.backup, t.videoAccount.forget]) {
        expect(
          tester.widget<ListTile>(find.widgetWithText(ListTile, title)).onTap,
          isNull,
          reason: 'Reading must not overlap a write action',
        );
      }
      expect(feedback, hasLength(1));
      pendingRead.complete({
        'data': {'backup': _snapshot()},
      });
      await tester.pumpAndSettle();
      expect(find.text(t.videoAccount.recoveryReadFailed), findsNothing);
      await _tap(tester, t.videoAccount.login, delta: -250);
      expect(login, 1);
      expect(cookies.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
