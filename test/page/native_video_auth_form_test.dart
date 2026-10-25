import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/page/video/video_creator_strip.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

Widget auth({
  required Future<String> Function(String, String, String, bool) submit,
  int revision = 0,
  bool rejected = false,
  bool registration = false,
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
      registration: registration,
      hasRemember: true,
      revision: revision,
      siteRejected: rejected,
      submit: submit,
      onChangeMode: () {},
      onWebsite: () {},
    ),
  ),
);

void main() {
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
        auth(submit: submit, revision: 1, rejected: true),
      );
      pending.complete('submitted');
      await tester.pump();
      await tester.pump(const Duration(seconds: 26));
      expect(find.text(t.videoCommunity.authUnconfirmed), findsNothing);
      expect(find.text(t.videoCommunity.authFailed), findsOneWidget);
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
    'a returned validation form re-enables native fields without losing input',
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
        auth(submit: submit, revision: 1, rejected: true),
      );
      expect(find.text(t.videoCommunity.authFailed), findsOneWidget);
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
}
