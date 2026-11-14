import '../test_helper.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_site_history_preview.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';

Future<void> _settleMyReads(WidgetTester tester) async {
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
    reason: 'Actual source local reads must finish within the host I/O budget',
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final home = Uri.parse('https://www.omofuna.com/');
  Map<String, dynamic> account() => {
    'kind': 'account',
    'account': {'id': '1', 'name': 'Fixture'},
  };
  Map<String, dynamic> favorites() => {
    'kind': 'favorites',
    'rawCount': 1,
    'hasMore': false,
    'unmappedCount': 0,
    'items': [
      {
        'recordId': '7',
        'vodId': '42',
        'item': {
          'id': '1234567890abcdef',
          'title': 'Actual site following',
          'detailUrl': '${home}anime/1234567890abcdef.html',
        },
      },
    ],
  };
  testWidgets(
    'following preview uses the real favorites model and native open callback',
    (tester) async {
      final reads = <String>[];
      final opened = <OmoFavorite>[];
      var all = 0;
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async {
          reads.add(operation);
          return operation == 'account' ? account() : favorites();
        },
      );
      addTearDown(client.dispose);
      await client.readAccount();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoSiteFollowingPreview(
              client: client,
              source: 'omo',
              onViewAll: () => all++,
              onOpen: (row) async => opened.add(row),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, ['account', 'favorites']);
      expect(find.text(t.videoSource.siteFavorites), findsOneWidget);
      expect(find.text(t.omoAccount.siteHistory), findsNothing);
      expect(find.byType(ApiVideoPoster), findsOneWidget);
      await tester.tap(find.text('Actual site following'));
      await tester.pump();
      expect(opened.single.recordId, '7');
      expect(
        opened.single.item.detailUrl,
        home.resolve('/anime/1234567890abcdef.html'),
      );
      final preview = tester.widget<SourceProfileVideoPreview>(
        find.byType(SourceProfileVideoPreview),
      );
      preview.onViewAll();
      expect(all, 1);
      client.invalidateAccount();
      await tester.pump();
      expect(find.text('Actual site following'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'same-account round trip cannot publish an older favorites response',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async =>
            operation == 'account' ? account() : gate.future,
      );
      addTearDown(client.dispose);
      await client.readAccount();
      final reading = client.favorites();
      client.invalidateAccount();
      await client.readAccount();
      gate.complete(favorites());
      await expectLater(reading, throwsA(isA<OmoSiteException>()));
    },
  );
  testWidgets(
    'My orders local history, site following, downloads and uses measured bottom inset',
    (tester) async {
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async => operation == 'account'
            ? account()
            : {'kind': 'favorites', 'items': [], 'rawCount': 0},
      );
      addTearDown(client.dispose);
      await client.readAccount();
      await tester.pumpWidget(
        MaterialApp(
          home: NativeNavigationInset(
            bottom: 96,
            child: Scaffold(
              body: OmoAccountPage(
                client: client,
                source: 'omo',
                active: true,
                onLocalHistory: () {},
              ),
            ),
          ),
        ),
      );
      await _settleMyReads(tester);
      final rails = tester
          .widgetList<SourceProfileVideoPreview>(
            find.byType(SourceProfileVideoPreview),
          )
          .toList();
      expect(rails.map((rail) => rail.title), [
        t.omoAccount.localHistory,
        t.videoSource.siteFavorites,
        t.bookshelf.download,
      ]);
      final list = tester.widget<ListView>(
        find
            .descendant(
              of: find.byType(OmoAccountPage),
              matching: find.byType(ListView),
            )
            .first,
      );
      expect((list.padding! as EdgeInsets).bottom, 28 + 96);
      rails[1].onViewAll();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OmoSiteFavoritesPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(OmoSiteFavoritesPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _settleMyReads(tester);
      expect(find.byType(OmoAccountPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
