import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/page/video/video_creator_strip.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

Widget auth({
  required Future<String> Function(String, String, String, bool) submit,
  int revision = 0,
  bool rejected = false,
  String errorKind = '',
  bool registration = false,
  VideoAccountCredentials? credentials,
  Future<void> Function(String, String)? saveCredentials,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: NativeVideoAuthForm(
      credentials: credentials,
      saveCredentials: saveCredentials,
      registration: registration,
      hasRemember: true,
      revision: revision,
      siteRejected: rejected,
      siteErrorKind: errorKind,
      submit: submit,
      onChangeMode: () {},
      onWebsite: () {},
    ),
  ),
);

void main() {
  for (final width in [320.0, 390.0, 440.0]) {
    testWidgets('Omo native username and human verification fit $width with large text and require explicit submit', (tester) async {
      tester.view.physicalSize = Size(width, 800); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final code = TextEditingController(); addTearDown(code.dispose);
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.7)), child: child!),
        home: Scaffold(body: NativeVideoAuthForm(registration: false, hasRemember: false,
          accountIsEmail: false, allowRegistration: false,
          verification: TextFormField(controller: code, decoration: InputDecoration(labelText: t.videoCommunity.captcha),
            validator: (value) => value?.trim().isNotEmpty == true ? null : t.videoCommunity.required),
          submit: (account, password, _, __) async { calls++; expect(account, 'ordinary-user'); expect(code.text, 'human-code'); return 'unsupported'; },
          onChangeMode: () {}, onWebsite: () {}))));
      await tester.enterText(find.byType(TextFormField).at(0), 'ordinary-user');
      await tester.enterText(find.byType(TextFormField).at(1), 'synthetic-password');
      final login = find.widgetWithText(FilledButton, t.videoCommunity.login);
      await tester.ensureVisible(login); await tester.tap(login); await tester.pump();
      expect(calls, 0, reason: 'a missing human verification field cannot submit');
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.enterText(find.byType(TextFormField).at(2), 'human-code');
      await tester.ensureVisible(login); await tester.tap(login); await tester.pump();
      expect(calls, 1);
      expect(find.text(t.videoCommunity.createAccount), findsNothing);
      expect(find.text(t.videoCommunity.invalidEmail), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'saved details prefill without submitting and save only on user action',
    (tester) async {
      var calls = 0, saves = 0;
      await tester.pumpWidget(
        auth(
          credentials: VideoAccountCredentials(
            'fixture@example.test',
            'secret',
            Uri.parse('https://example.test'),
          ),
          saveCredentials: (account, password) async {
            saves++;
          },
          submit: (a, b, c, d) async {
            calls++;
            return 'submitted';
          },
        ),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'fixture@example.test',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'secret',
      );
      expect(calls, 0);
      expect(saves, 0);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, t.videoCommunity.login),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoCommunity.login),
      );
      await tester.pump();
      expect(calls, 1);
      expect(saves, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'failed credential save does not submit or claim a submitted request',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        auth(
          credentials: VideoAccountCredentials(
            'fixture@example.test',
            'secret',
            Uri.parse('https://example.test'),
          ),
          saveCredentials: (a, b) async => throw StateError('save failed'),
          submit: (a, b, c, d) async {
            calls++;
            return 'submitted';
          },
        ),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, t.videoCommunity.login),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoCommunity.login),
      );
      await tester.pump();
      expect(calls, 0);
      expect(find.text(t.error.saveFailed), findsOneWidget);
      expect(find.text(t.videoCommunity.authUnconfirmed), findsNothing);
    },
  );

  testWidgets(
    'a returned form ignores the previous submission result and deadline',
    (tester) async {
      final pending = Completer<String>();
      Future<String> submit(String a, String b, String c, bool d) =>
          pending.future;
      await tester.pumpWidget(auth(submit: submit));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpWidget(
        auth(
          submit: submit,
          revision: 1,
          rejected: true,
          errorKind: 'credentials',
        ),
      );
      pending.complete('submitted');
      await tester.pump();
      await tester.pump(const Duration(seconds: 26));
      expect(find.text(t.videoCommunity.authUnconfirmed), findsNothing);
      expect(find.text(t.login.invalidCredentials), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native login validates and never double-submits while awaiting the site',
    (tester) async {
      var calls = 0;
      Future<String> submit(
        String email,
        String password,
        String name,
        bool remember,
      ) async {
        calls++;
        expect(email, 'fixture@example.test');
        expect(password, 'synthetic-password');
        return 'submitted';
      }

      await tester.pumpWidget(auth(submit: submit));
      await tester.tap(
        find.widgetWithText(FilledButton, t.videoCommunity.login),
      );
      await tester.pump();
      expect(find.text(t.videoCommunity.invalidEmail), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 26));
      expect(find.text(t.videoCommunity.authUnconfirmed), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a returned explicit credential rejection re-enables native fields without losing input',
    (tester) async {
      Future<String> submit(String a, String b, String c, bool d) async =>
          'submitted';
      await tester.pumpWidget(auth(submit: submit));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pumpWidget(
        auth(
          submit: submit,
          revision: 1,
          rejected: true,
          errorKind: 'credentials',
        ),
      );
      expect(find.text(t.login.invalidCredentials), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'fixture@example.test',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'native registration fits 320px and large text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          auth(
            submit: (a, b, c, d) async => 'changed',
            registration: true,
            scale: 2,
            brightness: brightness,
          ),
        );
        await tester.scrollUntilVisible(
          find.byType(FilledButton),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TextFormField), findsNWidgets(3));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'subscription creators use compact avatars and preserve destinations',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: VideoCreatorStrip(
              page: Uri.parse('https://hanime1.me/subscriptions'),
              creators: const [
                {
                  'title': 'A long creator name 作者',
                  'pageUrl': 'https://hanime1.me/search?query=Example',
                },
              ],
              onOpen: (uri) => opened = uri,
            ),
          ),
        ),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      await tester.tap(find.text('A long creator name 作者'));
      expect(opened?.queryParameters['query'], 'Example');
      expect(tester.takeException(), isNull);
    },
  );

  test('uncertain mutations cannot be repeated automatically', () async {
    var evaluations = 0;
    final operations = VideoSiteOperations(
      page: Uri.parse('https://hanime1.me/watch?v=1'),
      evaluate: (script) async {
        if (script.contains('if (true)')) return {'status': 'cancelled'};
        evaluations++;
        return {'status': 'unconfirmed'};
      },
    );
    expect(
      (await operations.run('comment', {'text': 'Fixture'}))['status'],
      'unconfirmed',
    );
    expect(
      (await operations.run('comment', {'text': 'Fixture'}))['status'],
      'unconfirmed',
    );
    expect(evaluations, 1);
    operations.dispose();
  });

  test(
    'confirmation failure keeps its recovery status and blocks the same write',
    () async {
      var starts = 0, mutations = 0;
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        onMutation: () => mutations++,
        evaluate: (script) async {
          if (script.contains('if (true)')) return {'status': 'cancelled'};
          starts++;
          return {'status': 'verification', 'writeUnconfirmed': true};
        },
      );
      expect((await operations.run('like'))['status'], 'verification');
      expect((await operations.run('like'))['status'], 'unconfirmed');
      expect(starts, 1);
      expect(mutations, 0);
      operations.dispose();
    },
  );

  test(
    'concurrent operations are serialized and disposed results ignored',
    () async {
      final pending = Completer<dynamic>();
      final operations = VideoSiteOperations(
        page: Uri.parse('https://hanime1.me/watch?v=1'),
        evaluate: (_) => pending.future,
      );
      final first = operations.run('comments');
      expect((await operations.run('comments'))['status'], 'busy');
      operations.dispose();
      pending.complete({'status': 'ok', 'items': []});
      expect((await first)['status'], 'changed');
    },
  );
  testWidgets(
    'explicit credential rejection retains inputs and permits only manual retry',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        auth(
          submit: (a, b, c, d) async {
            calls++;
            throw StateError('Invalid email or password');
          },
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text(t.login.invalidCredentials), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'synthetic-password',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(calls, 1);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'uncertain network failure gives a safe reason and retains website verification before resubmitting',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        auth(
          submit: (a, b, c, d) async {
            calls++;
            throw StateError(
              'Connection reset password=synthetic-password https://private.test',
            );
          },
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text(t.login.networkUnavailable), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      expect(find.textContaining('private.test'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'synthetic-password',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an unknown returned validation reason keeps native resubmission locked and website reachable',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        auth(
          rejected: true,
          errorKind: 'unknown',
          submit: (a, b, c, d) async {
            calls++;
            return 'submitted';
          },
        ),
      );
      await tester.pump();
      expect(find.text(t.videoCommunity.authFailed), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
            )
            .onPressed,
        isNotNull,
      );
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
