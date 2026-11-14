import '../test_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

Future<void> _settleLocalPreviews(WidgetTester tester) async {
  await tester.pump();
  bool loading() => tester
      .widgetList<SourceProfileVideoPreview>(
        find.byType(SourceProfileVideoPreview),
      )
      .any((preview) => preview.loading);
  final elapsed = Stopwatch()..start();
  while (loading() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    loading(),
    isFalse,
    reason: 'Real local metadata reads must settle before animation settlement',
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    const changes = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(connectivity, null);
      messenger.setMockMethodCallHandler(changes, null);
    });
  });
  testWidgets(
    'My shows the real site following preview without duplicating its library',
    (tester) async {
      final operations = <String>[];
      var historyOpened = 0;
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (operation, _) async {
          operations.add(operation);
          if (operation == 'favorites')
            return {
              'kind': 'favorites',
              'rawCount': 1,
              'hasMore': false,
              'items': [
                {
                  'recordId': '7',
                  'vodId': '42',
                  'item': {
                    'id': '1234567890abcdef',
                    'title': 'Actual followed work',
                    'detailUrl':
                        'https://www.omofuna.com/anime/1234567890abcdef.html',
                  },
                },
              ],
            };
          return {
            'kind': 'account',
            'account': {
              'id': '1',
              'name': '测试昵称',
              'group': '游客',
              'canComment': true,
            },
          };
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoAccountPage(
              client: client,
              active: true,
              onLocalHistory: () => historyOpened++,
            ),
          ),
        ),
      );
      await _settleLocalPreviews(tester);
      expect(operations, ['account', 'favorites']);
      expect(find.text('测试昵称'), findsOneWidget);
      expect(find.text(t.videoSource.siteFavorites), findsOneWidget);
      final following = tester.widget<SourceProfileVideoPreview>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SourceProfileVideoPreview &&
              widget.identity.startsWith('site-following.'),
        ),
      );
      expect(following.items, hasLength(1));
      expect(find.text('Actual followed work'), findsOneWidget);
      expect(find.byKey(const ValueKey('omo-my.follows-fold')), findsNothing);
      expect(find.text(t.videoSource.permissions), findsNothing);
      expect(find.text(t.videoSource.accountDetails), findsOneWidget);
      expect(find.text(t.videoSource.commentAllowed), findsNothing);
      // The heading expands/collapses its rail; View All opens local history.
      final historyRail = find.byWidgetPredicate(
        (widget) =>
            widget is SourceProfileVideoPreview &&
            widget.identity.startsWith('local-history.'),
      );
      final historyAction = find.descendant(
        of: historyRail,
        matching: find.widgetWithText(TextButton, '查看全部'),
      );
      await tester.ensureVisible(historyAction);
      await tester.pumpAndSettle();
      await tester.tap(historyAction);
      expect(historyOpened, 1);
      expect(operations, ['account', 'favorites']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final signedOut in [false, true]) {
    testWidgets(
      signedOut
          ? 'confirmed signed-out account offers login'
          : 'unavailable account does not pretend to be signed out',
      (tester) async {
        final client = OmoSiteClient(
          home: Uri.parse('https://www.omofuna.com/'),
          request: (_, _) async => {
            'kind': signedOut ? 'signedOut' : 'unavailable',
          },
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OmoAccountPage(
                client: client,
                active: true,
                onLocalHistory: () {},
              ),
            ),
          ),
        );
        await _settleLocalPreviews(tester);
        expect(
          find.text(t.videoSource.login),
          signedOut ? findsOneWidget : findsNothing,
        );
        final accountFailure = find.widgetWithText(
          ListTile,
          omoSiteError(const OmoSiteException('unavailable')),
        );
        final accountRetry = find.descendant(
          of: accountFailure,
          matching: find.text(t.common.retry),
        );
        expect(accountFailure, signedOut ? findsNothing : findsOneWidget);
        expect(accountRetry, signedOut ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
