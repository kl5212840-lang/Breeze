import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

Future<void> chooseMore(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('omo-favorites.more')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'import waits for folder confirmation and never mutates official follows',
    (tester) async {
      final operations = <String>[];
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (op, _) async {
          operations.add(op);
          if (op == 'account') {
            return {
              'kind': 'account',
              'account': {'id': '1', 'name': '测试'},
            };
          }
          return {
            'kind': 'favorites',
            'rawCount': 1,
            'hasMore': false,
            'items': [
              {
                'recordId': '20',
                'vodId': '18454',
                'item': {
                  'id': '2f9e3891a901bcb267a7fa5c',
                  'title': '导入流程样本',
                  'detailUrl':
                      'https://www.omofuna.com/anime/2f9e3891a901bcb267a7fa5c.html',
                },
              },
            ],
          };
        },
      );
      final store = VideoLibraryStore(
        deviceId: 'test',
        storageKey: 'import-flow',
      );
      addTearDown(client.dispose);
      addTearDown(store.dispose);
      final folder = await store.createFolder('omo', '想看');
      var importing = true, completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) => OmoSiteFavoritesPage(
                client: client,
                source: 'omo',
                store: store,
                active: true,
                importing: importing,
                onOpen: (_) async {},
                onImportMode: (value) => set(() => importing = value),
                onImported: () => set(() {
                  completed++;
                  importing = false;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入流程样本'));
      await tester.pump();
      await tester.tap(find.text(t.videoSource.chooseImportFolder));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 30));
      await tester.pumpAndSettle();
      expect((await store.read()).itemsFor('omo'), isEmpty);
      expect(completed, 0);
      await tester.tap(find.text(t.videoSource.chooseImportFolder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('想看'));
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(OmoSiteFavoritesPage)),
      );
      for (final message in ['旧反馈一', '旧反馈二']) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(label: '操作', onPressed: () {}),
          ),
        );
      }
      await tester.tap(find.widgetWithText(FilledButton, t.common.save));
      await tester.pumpAndSettle();
      final snapshot = await store.read();
      expect(snapshot.itemsFor('omo').length, 1);
      expect(snapshot.foldersOf(snapshot.itemsFor('omo').single.key), {folder});
      expect(completed, 1);
      expect(operations, ['account', 'favorites']);
      expect(find.text('旧反馈一'), findsOneWidget);
      expect(find.byType(VideoActionNotice), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(VideoActionNotice), findsNothing);
      expect(find.text('旧反馈一'), findsOneWidget);
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('旧反馈二'), findsOneWidget);
      messenger.clearSnackBars();
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in ['loading', 'error', 'signedOut', 'empty']) {
    testWidgets('import can be cancelled in $state state', (tester) async {
      final pendingAccount = Completer<Map<String, dynamic>>();
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (operation, _) async {
          if (operation == 'account') {
            if (state == 'loading') return pendingAccount.future;
            if (state == 'signedOut') return {'kind': 'signedOut'};
            return {
              'kind': 'account',
              'account': {'id': '1', 'name': '测试'},
            };
          }
          if (state == 'error') throw const OmoSiteException('unavailable');
          return {
            'kind': 'favorites',
            'rawCount': 0,
            'hasMore': false,
            'items': [],
          };
        },
      );
      addTearDown(client.dispose);
      var importing = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) => OmoSiteFavoritesPage(
                client: client,
                source: 'omo',
                active: true,
                importing: importing,
                onOpen: (_) async {},
                onImportMode: (value) => set(() => importing = value),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      if (state != 'loading') await tester.pumpAndSettle();
      expect(find.text(t.common.cancel), findsOneWidget);
      await tester.tap(find.text(t.common.cancel));
      await tester.pump();
      expect(importing, isFalse);
      expect(find.text(t.common.cancel), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      if (state == 'loading') {
        pendingAccount.complete({'kind': 'signedOut'});
        await tester.pumpAndSettle();
        expect(
          importing,
          isFalse,
          reason: 'A late read must not reopen import',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search and failed pagination keep selections and allow cancel', (
    tester,
  ) async {
    var nextPageAttempts = 0;
    final client = OmoSiteClient(
      home: Uri.parse('https://www.omofuna.com/'),
      request: (operation, parameters) async {
        if (operation == 'account') {
          return {
            'kind': 'account',
            'account': {'id': '1', 'name': '测试'},
          };
        }
        if (parameters['offset'] != 0) {
          nextPageAttempts++;
          throw const OmoSiteException('unavailable');
        }
        return {
          'kind': 'favorites',
          'rawCount': 2,
          'hasMore': true,
          'items': [
            for (final (id, title) in [
              ('aaaaaaaaaaaaaaaa', '星空物语'),
              ('bbbbbbbbbbbbbbbb', '海边故事'),
            ])
              {
                'recordId': id == 'aaaaaaaaaaaaaaaa' ? '20' : '21',
                'vodId': id == 'aaaaaaaaaaaaaaaa' ? '1' : '2',
                'item': {
                  'id': id,
                  'title': title,
                  'detailUrl': 'https://www.omofuna.com/anime/$id.html',
                },
              },
          ],
        };
      },
    );
    addTearDown(client.dispose);
    var importing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) => OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              importing: importing,
              onOpen: (_) async {},
              onImportMode: (value) => set(() => importing = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('星空物语'));
    await tester.tap(find.byKey(const ValueKey('omo-favorites.search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '海边');
    await tester.pumpAndSettle();
    expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
    await tester.tap(find.text(t.common.selectAll));
    await tester.pump();
    expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
    final editorRect = tester.getRect(find.byType(TextField).first);
    final privacy = find.byType(CollectionCoverPrivacyButton);
    final privacyRect = tester.getRect(privacy);
    final collectionScroll = find
        .descendant(
          of: find.byType(ApiVideoCollection),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(t.common.nextPage),
      150,
      scrollable: collectionScroll,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(TextField).first), editorRect);
    expect(tester.getRect(privacy), privacyRect);
    await tester.tap(find.text(t.common.nextPage));
    await tester.pumpAndSettle();
    expect(
      nextPageAttempts,
      1,
      reason: 'The next page must actually be requested and fail.',
    );
    await tester.scrollUntilVisible(
      find.text(t.bookshelf.selectedCount(count: 2)),
      -150,
      scrollable: collectionScroll,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
    expect(find.text(t.videoSource.readFailed), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(t.common.cancel),
      -150,
      scrollable: collectionScroll,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(importing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back cancels import before leaving its page', (
    tester,
  ) async {
    final client = OmoSiteClient(
      home: Uri.parse('https://www.omofuna.com/'),
      request: (_, _) async => {'kind': 'signedOut'},
    );
    addTearDown(client.dispose);
    var importing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: StatefulBuilder(
                      builder: (_, set) => OmoSiteFavoritesPage(
                        client: client,
                        source: 'omo',
                        active: true,
                        importing: importing,
                        onOpen: (_) async {},
                        onImportMode: (value) => set(() => importing = value),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('打开站点追番'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开站点追番'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(importing, isFalse);
    expect(find.byType(OmoSiteFavoritesPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('打开站点追番'), findsOneWidget);
  });

  testWidgets(
    'import result survives local-tab switch and closes on collection exit',
    (tester) async {
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (operation, _) async => operation == 'account'
            ? {
                'kind': 'account',
                'account': {'id': '1', 'name': '测试'},
              }
            : {
                'kind': 'favorites',
                'rawCount': 1,
                'hasMore': false,
                'items': [
                  {
                    'recordId': '20',
                    'vodId': '1',
                    'item': {
                      'id': 'aaaaaaaaaaaaaaaa',
                      'title': '反馈样本',
                      'detailUrl':
                          'https://www.omofuna.com/anime/aaaaaaaaaaaaaaaa.html',
                    },
                  },
                ],
              },
      );
      final store = VideoLibraryStore(
        deviceId: 'test',
        storageKey: 'import-feedback',
      );
      addTearDown(client.dispose);
      addTearDown(store.dispose);
      await store.createFolder('omo', '目标文件夹');
      var importing = true, active = true, collection = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return OmoSiteFavoritesPage(
                  client: client,
                  source: 'omo',
                  store: store,
                  active: active,
                  collectionActive: collection,
                  importing: importing,
                  onOpen: (_) async {},
                  onImportMode: (value) => set(() => importing = value),
                  onImported: () => set(() {
                    importing = false;
                    active = false;
                  }),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('反馈样本'));
      await tester.pump();
      await tester.tap(find.text(t.videoSource.chooseImportFolder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('目标文件夹'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, t.common.save));
      await tester.pumpAndSettle();
      expect(active, isFalse);
      expect(
        find.text(t.videoSource.importResult(added: 1, existing: 0)),
        findsOneWidget,
      );
      update(() => collection = false);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('site follows share view mode and keep posters when importing', (
    tester,
  ) async {
    final client = fixtureClient();
    addTearDown(client.dispose);
    var mode = ApiVideoView.grid, importing = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return OmoSiteFavoritesPage(
                client: client,
                source: 'omo',
                active: true,
                mode: mode,
                importing: importing,
                onOpen: (_) async {},
                onImportMode: (value) => set(() => importing = value),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection)).mode,
      ApiVideoView.grid,
    );
    update(() => mode = ApiVideoView.list);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ApiVideoCollection>(find.byType(ApiVideoCollection)).mode,
      ApiVideoView.list,
    );
    await chooseMore(tester, t.videoSource.importLocal);
    expect(importing, isTrue);
    expect(find.byType(ApiVideoPoster), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('api-video.aaaaaaaaaaaaaaaa')));
    await tester.pump();
    final collection = tester.widget<ApiVideoCollection>(
      find.byType(ApiVideoCollection),
    );
    expect(collection.selecting, isTrue);
    expect(collection.selected, {'aaaaaaaaaaaaaaaa'});
    expect(find.byType(ApiVideoPoster), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manage selects works with effective batch actions and normal taps still play',
    (tester) async {
      final client = fixtureClient();
      addTearDown(client.dispose);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              onOpen: (_) async => opened++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await chooseMore(tester, t.videoSource.manage);
      expect(find.text(t.bookshelf.selectedCount(count: 0)), findsOneWidget);
      final managingCollection = tester.widget<ApiVideoCollection>(
        find.byType(ApiVideoCollection),
      );
      expect(managingCollection.selecting, isTrue);
      expect(managingCollection.selected, isEmpty);
      final card = find.byKey(const ValueKey('api-video.aaaaaaaaaaaaaaaa'));
      final mark = find.descendant(
        of: card,
        matching: find.byType(CollectionSelectionMark),
      );
      expect(tester.widget<CollectionSelectionMark>(mark).visible, isTrue);
      expect(tester.widget<CollectionSelectionMark>(mark).selected, isFalse);
      await tester.tap(
        find.byKey(const ValueKey('api-video.aaaaaaaaaaaaaaaa')),
      );
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .selected,
        {'aaaaaaaaaaaaaaaa'},
      );
      expect(tester.widget<CollectionSelectionMark>(mark).selected, isTrue);
      expect(find.text(t.videoSource.chooseImportFolder), findsOneWidget);
      expect(find.text(t.videoSource.unfollowSite), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('omo-favorites.selection.cancel')),
      );
      await tester.pumpAndSettle();
      final restoredCollection = tester.widget<ApiVideoCollection>(
        find.byType(ApiVideoCollection),
      );
      expect(restoredCollection.selecting, isFalse);
      expect(restoredCollection.selected, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('api-video.aaaaaaaaaaaaaaaa')),
      );
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown account error offers retry without a false login state',
    (tester) async {
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (_, _) async => {'kind': 'unavailable'},
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.common.retry), findsOneWidget);
      expect(find.text(t.videoSource.login), findsNothing);
      expect(find.text(t.videoSource.noSiteFavorites), findsNothing);
      expect(find.text(t.videoLibrary.results(count: 0)), findsNothing);
    },
  );

  testWidgets('failed same-account refresh retains the visible library', (
    tester,
  ) async {
    var failed = false, attempts = 0;
    final client = fixtureClient(
      before: () {
        attempts++;
        if (failed) throw const OmoSiteException('unavailable');
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmoSiteFavoritesPage(
            client: client,
            source: 'omo',
            active: true,
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final more = tester.widget<NativeVideoMenu>(
      find.byKey(const ValueKey('omo-favorites.more')),
    );
    expect(more.options.keys, ['manage']);
    expect(find.byKey(const ValueKey('omo-favorites.sort')), findsOneWidget);
    expect(find.byKey(const ValueKey('omo-favorites.view')), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);

    final scrollable = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    final before = attempts;
    failed = true;
    await tester.drag(scrollable, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(attempts, before + 1);
    final item = find.byKey(const ValueKey('api-video.aaaaaaaaaaaaaaaa'));
    expect(item, findsOneWidget);
    final error = find.byKey(const ValueKey('omo-favorites.retained-error'));
    final retry = find.descendant(
      of: error,
      matching: find.text(t.common.retry),
    );
    expect(retry, findsOneWidget);
    expect(find.text(t.videoSource.login), findsNothing);

    failed = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    expect(item, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'batch unfollow confirms and reads back each real selected site work',
    (tester) async {
      final removed = <String>{}, writes = <String>[];
      final client = OmoSiteClient(
        home: Uri.parse('https://www.omofuna.com/'),
        request: (operation, args) async {
          if (operation == 'account')
            return {
              'kind': 'account',
              'account': {'id': 'fixture', 'name': 'Fixture'},
            };
          if (operation == 'favoriteRemove') {
            final id = '${args['vodId']}';
            writes.add(id);
            removed.add(id);
            return {'kind': 'mutation', 'accepted': true};
          }
          if (operation == 'favoriteState')
            return {
              'kind': 'favoriteState',
              'favorite': !removed.contains('${args['vodId']}'),
            };
          expect(operation, 'favorites');
          return {
            'kind': 'favorites',
            'rawCount': 2 - removed.length,
            'hasMore': false,
            'items': [
              for (final id in ['1', '2'])
                if (!removed.contains(id))
                  {
                    'recordId': id,
                    'vodId': id,
                    'item': {
                      'id': id == '1' ? 'aaaaaaaaaaaaaaaa' : 'bbbbbbbbbbbbbbbb',
                      'title': 'Work $id',
                      'detailUrl':
                          'https://www.omofuna.com/anime/${id == '1' ? 'aaaaaaaaaaaaaaaa' : 'bbbbbbbbbbbbbbbb'}.html',
                    },
                  },
            ],
          };
        },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await chooseMore(tester, t.videoSource.manage);
      await tester.tap(find.text(t.common.selectAll));
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
      await tester.tap(find.text(t.videoSource.unfollowSite));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, t.common.confirm));
      await tester.pumpAndSettle();
      expect(writes, ['1', '2']);
      expect(removed, {'1', '2'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('site toolbar and selection remain usable on narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = fixtureClient();
    addTearDown(client.dispose);
    var importing = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) => OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              importing: importing,
              onOpen: (_) async {},
              onImportMode: (value) => set(() => importing = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await chooseMore(tester, t.videoSource.importLocal);
    final cancel = find.byTooltip(t.common.cancel).hitTestable();
    expect(cancel, findsOneWidget);
    expect(find.byType(ApiVideoPoster), findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(importing, isFalse);
    expect(tester.takeException(), isNull);
  });
}

OmoSiteClient fixtureClient({void Function()? before}) => OmoSiteClient(
  home: Uri.parse('https://www.omofuna.com/'),
  request: (operation, _) async {
    before?.call();
    if (operation == 'account') {
      return {
        'kind': 'account',
        'account': {'id': '1', 'name': '测试'},
      };
    }
    return {
      'kind': 'favorites',
      'rawCount': 1,
      'hasMore': false,
      'items': [
        {
          'recordId': '20',
          'vodId': '1',
          'item': {
            'id': 'aaaaaaaaaaaaaaaa',
            'title': '流程测试作品',
            'remarks': '12集',
            'detailUrl': 'https://www.omofuna.com/anime/aaaaaaaaaaaaaaaa.html',
          },
        },
      ],
    };
  },
);
