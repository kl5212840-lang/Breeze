import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../ui_preview_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_account_details_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

const source = 'b2f8f370-81b8-437e-a432-b9af8d577312';
OmoSiteClient client({OmoSiteRequest? request}) => OmoSiteClient(
  home: Uri.parse('https://www.omofuna.com/'),
  request:
      request ??
      (operation, _) async => switch (operation) {
        'history' || 'historyPreview' => {
          'kind': 'history',
          'items': [],
          'rawCount': 0,
          'hasMore': false,
        },
        'account' => {
          'kind': 'account',
          'account': {
            'id': '1',
            'name': '测试账号',
            'group': '游客',
            'canComment': true,
          },
        },
        _ => throw StateError(
          'Unexpected account fixture operation: $operation',
        ),
      },
);

Future<void> settleLocalPreviews(WidgetTester tester) async {
  List<SourceProfileVideoPreview> previews() => tester
      .widgetList<SourceProfileVideoPreview>(
        find.byType(SourceProfileVideoPreview),
      )
      .where((preview) => preview.identity.startsWith('local-'))
      .toList();
  final elapsed = Stopwatch()..start();
  // The mounted My page reads the real isolated managed-file index. Its I/O
  // finishes on the real event loop, while continuations remain in FakeAsync.
  // Do not await a second storage-queue read from runAsync: pump both clocks.
  while (previews().any((preview) => preview.loading) &&
      elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(previews(), hasLength(2));
  expect(
    previews().every((preview) => !preview.loading && !preview.failed),
    isTrue,
    reason:
        'Both real local record reads finish successfully before navigation',
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    const events = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(connectivity, null);
      messenger.setMockMethodCallHandler(events, null);
    });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'avatar opens native account before any explicit website action: $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final site = client();
          addTearDown(site.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: RepaintBoundary(
                key: const ValueKey('omo-native-preview'),
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    fontFamily: uiPreviewDirectory == null
                        ? null
                        : 'AccountPreview',
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.7)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: OmoAccountPage(
                      client: site,
                      source: source,
                      active: true,
                      onLocalHistory: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await settleLocalPreviews(tester);
          await writeUiPreview(
            tester,
            const ValueKey('omo-native-preview'),
            'omo-my-$style-${brightness.name}-large',
          );
          await tester.tap(find.byKey(const ValueKey('omo-my.avatar')));
          await tester.pumpAndSettle();
          expect(find.byType(OmoAccountDetailsPage), findsOneWidget);
          expect(find.byType(OmoSiteWebPage), findsNothing);
          expect(find.text(t.omoAccount.identity), findsOneWidget);
          expect(find.text(t.omoAccount.chooseBackground), findsOneWidget);
          expect(tester.takeException(), isNull);
          await writeUiPreview(
            tester,
            const ValueKey('omo-native-preview'),
            'omo-account-$style-${brightness.name}-large',
          );
        },
        variant: TargetPlatformVariant({TargetPlatform.iOS}),
      );
    }
  }

  testWidgets(
    'native account has one deliberate website boundary, never opens it while reading',
    (tester) async {
      final site = client();
      addTearDown(site.dispose);
      await site.readAccount();
      var opened = 0;
      String? target;
      await tester.pumpWidget(
        MaterialApp(
          home: OmoAccountDetailsPage(
            client: site,
            source: source,
            onWebsite: (_, path, _) async {
              opened++;
              target = path;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, 0);
      final link = find.byKey(const ValueKey('omo-account.explicit-website'));
      await tester.scrollUntilVisible(link, 300);
      await tester.pumpAndSettle();
      expect(find.text(t.omoAccount.editOnWebsite), findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(target, '/user/info.html');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'logout requires authoritative signed-out readback, no optimistic identity deletion',
    () async {
      var signedOut = false;
      final operations = <String>[];
      final site = client(
        request: (operation, _) async {
          operations.add(operation);
          if (operation == 'logout') return {'kind': 'logoutSent'};
          return signedOut
              ? {'kind': 'signedOut'}
              : {
                  'kind': 'account',
                  'account': {'id': '1', 'name': '测试账号'},
                };
        },
      );
      addTearDown(site.dispose);
      await site.readAccount();
      await expectLater(site.signOut(), throwsA(isA<OmoSiteException>()));
      expect(site.account?.id, '1');
      signedOut = true;
      await site.signOut();
      expect(site.account, isNull);
      expect(operations, ['account', 'logout', 'account', 'logout', 'account']);
    },
  );
}
