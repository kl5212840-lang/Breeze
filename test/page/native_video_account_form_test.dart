import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_account_form.dart';

const fixture = <String, dynamic>{
  'supported': true,
  'signedIn': true,
  'profileReady': true,
  'passwordReady': true,
  'avatarReady': false,
  'logoutReady': true,
  'otpReady': false,
  'name': 'Fixture',
  'email': 'fixture@example.test',
};

Widget account({
  required Future<Map<String, dynamic>> Function() read,
  required VideoAccountFormSubmit submit,
  GlobalKey<NativeVideoAccountFormState>? formKey,
  int revision = 0,
  bool readback = false,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: NativeVideoAccountForm(
      key: formKey,
      page: Uri.parse('https://hanime1.me/user/7/edit'),
      read: read,
      submit: submit,
      onRefresh: () {},
      onWebsite: () {},
      revision: revision,
      readback: readback,
    ),
  ),
);

void main() {
  testWidgets(
    'profile submits once and confirms only an independent matching read',
    (tester) async {
      var state = {...fixture};
      var calls = 0;
      Future<Map<String, dynamic>> read() async => state;
      Future<String> submit(
        String operation,
        Map<String, String> values,
      ) async {
        calls++;
        expect(operation, 'profile');
        expect(values, {
          'name': 'Changed fixture',
          'email': 'fixture@example.test',
        });
        return 'submitted';
      }

      await tester.pumpWidget(account(read: read, submit: submit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Changed fixture',
      );
      await tester.pump();
      final save = find.widgetWithText(
        FilledButton,
        t.videoSiteAccount.saveProfile,
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      state = {...fixture, 'name': 'Changed fixture'};
      await tester.pumpWidget(account(read: read, submit: submit, revision: 1));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text(t.videoSiteAccount.readbackMatched), findsNothing);
      expect(find.text(t.videoSiteAccount.unconfirmed), findsOneWidget);
      await tester.pumpWidget(
        account(read: read, submit: submit, revision: 2, readback: true),
      );
      await tester.pump();
      expect(find.text(t.videoSiteAccount.readbackMatched), findsOneWidget);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stale reads never overwrite a newer account document', (
    tester,
  ) async {
    final old = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      account(read: () => old.future, submit: (a, b) async => 'changed'),
    );
    await tester.pumpWidget(
      account(
        read: () async => {...fixture, 'name': 'Current fixture'},
        submit: (a, b) async => 'changed',
        revision: 1,
      ),
    );
    await tester.pump();
    old.complete({...fixture, 'name': 'Old fixture'});
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Current fixture',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'password validation, clearing and uncertain-state guard do not repeat a write',
    (tester) async {
      var calls = 0;
      Future<String> submit(
        String operation,
        Map<String, String> values,
      ) async {
        calls++;
        expect(operation, 'password');
        expect(values['password_old'], 'synthetic-old');
        expect(values['password_new_confirm'], 'synthetic-new');
        return 'submitted';
      }

      await tester.pumpWidget(
        account(read: () async => fixture, submit: submit),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        (2, 'synthetic-old'),
        (3, 'synthetic-new'),
        (4, 'mismatch'),
      ]) {
        await tester.ensureVisible(find.byType(TextFormField).at(entry.$1));
        await tester.enterText(
          find.byType(TextFormField).at(entry.$1),
          entry.$2,
        );
      }
      final change = find.widgetWithText(
        OutlinedButton,
        t.videoSiteAccount.changePassword,
      );
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pump();
      expect(calls, 0);
      expect(find.text(t.videoSiteAccount.passwordMismatch), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(4), 'synthetic-new');
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pump();
      expect(calls, 1);
      for (var i = 2; i < 5; i++) {
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(i))
              .controller!
              .text,
          isEmpty,
        );
      }
      await tester.pump(const Duration(seconds: 26));
      expect(tester.widget<OutlinedButton>(change).onPressed, isNull);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'the host close guard preserves unsaved profile changes on cancel',
    (tester) async {
      final key = GlobalKey<NativeVideoAccountFormState>();
      await tester.pumpWidget(
        account(
          formKey: key,
          read: () async => fixture,
          submit: (a, b) async => 'changed',
        ),
      );
      await tester.pumpAndSettle();
      expect(await key.currentState!.requestClose(), isTrue);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved fixture',
      );
      final close = key.currentState!.requestClose();
      await tester.pumpAndSettle();
      expect(find.text(t.videoSiteAccount.discardTitle), findsOneWidget);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(await close, isFalse);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Unsaved fixture',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a password reply after navigation never touches disposed controllers',
    (tester) async {
      final reply = Completer<String>();
      await tester.pumpWidget(
        account(read: () async => fixture, submit: (a, b) => reply.future),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        (2, 'synthetic-old'),
        (3, 'synthetic-new'),
        (4, 'synthetic-new'),
      ]) {
        await tester.ensureVisible(find.byType(TextFormField).at(entry.$1));
        await tester.enterText(
          find.byType(TextFormField).at(entry.$1),
          entry.$2,
        );
      }
      final change = find.widgetWithText(
        OutlinedButton,
        t.videoSiteAccount.changePassword,
      );
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      reply.complete('submitted');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backgrounding clears secrets without clearing a pending write lock',
    (tester) async {
      var calls = 0;
      final reply = Completer<String>();
      await tester.pumpWidget(
        account(
          read: () async => fixture,
          submit: (a, b) {
            calls++;
            return reply.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        (2, 'synthetic-old'),
        (3, 'synthetic-new'),
        (4, 'synthetic-new'),
      ]) {
        await tester.ensureVisible(find.byType(TextFormField).at(entry.$1));
        await tester.enterText(
          find.byType(TextFormField).at(entry.$1),
          entry.$2,
        );
      }
      final change = find.widgetWithText(
        OutlinedButton,
        t.videoSiteAccount.changePassword,
      );
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      for (var i = 2; i < 5; i++) {
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(i))
              .controller!
              .text,
          isEmpty,
        );
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(change).onPressed, isNull);
      expect(calls, 1);
      reply.complete('submitted');
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'account form remains scrollable at 320px and 2x text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          account(
            read: () async => fixture,
            submit: (a, b) async => 'changed',
            scale: 2,
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(TextButton, t.videoSiteAccount.refresh),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        final button = tester.getSize(
          find.widgetWithText(TextButton, t.videoSiteAccount.refresh),
        );
        expect(button.height, greaterThanOrEqualTo(44));
        expect(find.text(t.videoSiteAccount.requestCode), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('recovery click is not an email success flash', (tester) async {
    var state = <String, dynamic>{'supported': true};
    var calls = 0;
    Widget recovery(int revision) => MaterialApp(
      home: Scaffold(
        body: NativeVideoPasswordRecoveryForm(
          read: () async => state,
          submit: (email) async {
            calls++;
            return 'submitted';
          },
          onLogin: () {},
          onWebsite: () {},
          revision: revision,
        ),
      ),
    );
    await tester.pumpWidget(recovery(0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'fixture@example.test');
    await tester.tap(
      find.widgetWithText(FilledButton, t.videoSiteAccount.sendRecovery),
    );
    await tester.pump();
    expect(calls, 1);
    expect(find.text(t.videoSiteAccount.recoverySent), findsNothing);
    state = {'supported': true, 'sent': true};
    await tester.pumpWidget(recovery(1));
    await tester.pump();
    expect(find.text(t.videoSiteAccount.recoverySent), findsOneWidget);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
