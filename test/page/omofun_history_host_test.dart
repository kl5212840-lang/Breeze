import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  final watch = home.resolve('/anime/1234567890abcdef/play/1/2.html');
  Map<String, dynamic> account(String id) => {
    'kind': 'account',
    'account': {'id': id, 'name': 'Fixture'},
  };
  Map<String, dynamic> page({
    int count = 1,
    bool more = false,
    bool mapped = true,
  }) => {
    'kind': 'history',
    'rawCount': count,
    'hasMore': more,
    'items': [
      if (mapped)
        {
          'url': '$watch',
          'title': '真实结构作品',
          'episodeLabel': '第2集',
          'watchedAt': '2026-11-06',
        },
    ],
  };

  test(
    'history canonical work URI has no empty separators and exact playback keeps line and episode',
    () {
      final original = home.resolve(
        '/anime/1234567890abcdef/play/2/7.html?visit=sample#position',
      );
      final entry = OmoHistoryEntry(url: original, title: 'Work');
      expect(
        entry.detailUrl.toString(),
        'https://www.omofuna.com/anime/1234567890abcdef.html',
      );
      expect(entry.detailUrl.hasQuery, isFalse);
      expect(entry.detailUrl.hasFragment, isFalse);
      expect(entry.item.id, '1234567890abcdef');
      expect(
        entry.resume.toString(),
        'https://www.omofuna.com/anime/1234567890abcdef.html?line=2&episode=7',
      );
      expect(entry.resume!.hasFragment, isFalse);
      expect(entry.url, original);
      expect(entry.url.queryParameters, {'visit': 'sample'});
    },
  );

  test(
    'unexpected history envelopes cannot become an empty successful list',
    () async {
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => {'kind': 'account', 'rawCount': 0},
      );
      addTearDown(client.dispose);
      await expectLater(
        client.privateIndex('history'),
        throwsA(isA<OmoSiteException>()),
      );
    },
  );

  testWidgets(
    'site history renders native cards, pages by raw count and opens the precise native entry',
    (tester) async {
      final offsets = <int>[];
      final opened = <Uri>[];
      final native = <OmoHistoryEntry>[];
      final client = OmoSiteClient(
        home: home,
        request: (operation, args) async {
          if (operation == 'account') return account('1');
          offsets.add(args['offset'] as int);
          return args['offset'] == 0
              ? page(count: 2, more: true)
              : page(mapped: false);
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: OmoPrivateIndexPage(
            client: client,
            kind: 'history',
            onOpenRecord: (entry) async => native.add(entry),
            onOpenWebsite: (url) async => opened.add(url),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('真实结构作品'), findsOneWidget);
      expect(find.text('第2集 · 2026-11-06'), findsOneWidget);
      expect(find.text(t.videoSource.emptySiteList), findsNothing);
      expect(find.text(t.videoSource.siteListFallback), findsOneWidget);
      final scopeMenu = find.byType(KeywordScopeMenu);
      final input = find.byType(TextField);
      expect(
        tester.widget<KeywordScopeMenu>(scopeMenu).scope,
        KeywordSearchScope.all,
      );
      await tester.enterText(input, '第2集');
      await tester.pumpAndSettle();
      expect(find.text('真实结构作品'), findsOneWidget);
      tester
          .widget<KeywordScopeMenu>(scopeMenu)
          .onChanged(KeywordSearchScope.title);
      await tester.pumpAndSettle();
      expect(find.text('真实结构作品'), findsNothing);
      await tester.enterText(input, '');
      await tester.pumpAndSettle();
      expect(find.text('真实结构作品'), findsOneWidget);
      expect(offsets, [0]);
      await tester.ensureVisible(find.text(t.comments.loadMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.comments.loadMore));
      await tester.pumpAndSettle();
      expect(offsets, [0, 2]);
      expect(find.text('真实结构作品'), findsOneWidget);
      await tester.tap(find.text('真实结构作品'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(native.single.item.id, '1234567890abcdef');
      expect(
        native.single.item.detailUrl,
        home.resolve('/anime/1234567890abcdef.html'),
      );
      expect(native.single.resume?.queryParameters, {
        'line': '1',
        'episode': '2',
      });
      await tester.ensureVisible(find.text(t.videoLibrary.openWebsite));
      await tester.pumpAndSettle();
      expect(
        find.text(t.videoLibrary.openWebsite).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text(t.videoLibrary.openWebsite));
      await tester.pumpAndSettle();
      expect(opened.last, home.resolve('/user/history.html'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in ['empty', 'unmapped', 'failure']) {
    testWidgets(
      'site history distinguishes $state without a fake empty result',
      (tester) async {
        final client = OmoSiteClient(
          home: home,
          request: (operation, _) async {
            if (operation == 'account') return account('1');
            return state == 'failure'
                ? {'kind': 'unavailable'}
                : page(count: state == 'empty' ? 0 : 2, mapped: false);
          },
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: OmoPrivateIndexPage(
              client: client,
              kind: 'history',
              onOpenWebsite: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(t.videoSource.emptySiteList),
          state == 'empty' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(t.videoSource.readFailed),
          state == 'failure' ? findsOneWidget : findsNothing,
        );
        if (state == 'unmapped') {
          expect(
            find.text('Records loaded. Open the website to view them.'),
            findsOneWidget,
          );
        }
        expect(
          find.text(t.videoLibrary.openWebsite).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'account change clears old records and a disposed page cannot navigate from a late history reply',
    (tester) async {
      var current = '1';
      final pending = Completer<Map<String, dynamic>>();
      var historyCalls = 0, opens = 0;
      final client = OmoSiteClient(
        home: home,
        request: (operation, _) async {
          if (operation == 'account') return account(current);
          return ++historyCalls == 1 ? page() : pending.future;
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: OmoPrivateIndexPage(
            client: client,
            kind: 'history',
            onOpenWebsite: (_) async => opens++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('真实结构作品'), findsOneWidget);
      current = '2';
      await client.readAccount();
      await tester.pump();
      expect(find.text('真实结构作品'), findsNothing);
      await tester.tap(find.text(t.common.retry));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(page());
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
