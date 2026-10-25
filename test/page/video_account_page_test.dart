import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_account_page.dart';

class _Cookies implements VideoAccountCookies {
  int writes = 0;
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async => [];
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
  }
}

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'account backup requires consent, serializes actions and fits large phone text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      var writes = 0;
      final service = VideoAccountService(
        origin: Uri.parse('https://hanime1.me/'),
        cookies: _Cookies(),
        call: (_, _) async => {
          'data': {'backup': null},
        },
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: VideoAccountPage(
            service: service,
            backupCurrent: () {
              writes++;
              return pending.future;
            },
            onLogin: () {},
            onCloudSettings: () async {},
          ),
        ),
      );
      await _pump(tester);
      await tester.scrollUntilVisible(find.text(t.videoAccount.backup), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoAccount.backup));
      await _pump(tester);
      expect(writes, 0);
      expect(find.text(t.videoAccount.backupPrompt), findsOneWidget);
      await tester.tap(find.text(t.common.confirm));
      await _pump(tester);
      expect(writes, 1);
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, t.videoAccount.backup),
            )
            .onTap,
        isNull,
      );
      pending.complete();
      await _pump(tester);
      expect(find.text(t.videoAccount.backupDone), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expired or missing backups can be removed without changing browser cookies',
    (tester) async {
      final cookies = _Cookies();
      var forgotten = 0;
      final service = VideoAccountService(
        origin: Uri.parse('https://hanime1.me/'),
        cookies: cookies,
        call: (fn, _) async {
          if (fn == 'forget') {
            forgotten++;
            return {
              'data': {'saved': true},
            };
          }
          return {
            'data': {'backup': null},
          };
        },
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoAccountPage(
            service: service,
            backupCurrent: () async {},
            onLogin: () {},
            onCloudSettings: () async {},
          ),
        ),
      );
      await _pump(tester);
      await tester.scrollUntilVisible(find.text(t.videoAccount.forget), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoAccount.forget));
      await _pump(tester);
      expect(forgotten, 0);
      await tester.tap(find.text(t.common.confirm));
      await _pump(tester);
      expect(forgotten, 1);
      expect(cookies.writes, 0);
      expect(find.text(t.videoAccount.forgotten), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
