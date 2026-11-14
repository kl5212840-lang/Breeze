import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPressTimeout;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_page_route.dart';

final _home = Uri.parse('https://www.omofuna.com/');
final _favorite = find.byKey(const ValueKey('api-detail.favorite'));

Map<String, dynamic> _account(String id) => {
  'kind': 'account',
  'account': {'id': id, 'name': '测试用户'},
};

Future<void> _mount(WidgetTester tester, OmoSiteClient client) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = VideoLibraryStore(
    deviceId: 'follow-qa',
    storageKey: 'follow-action-fixture',
  );
  addTearDown(store.dispose);
  addTearDown(client.dispose);
  final data = <String, dynamic>{
    'id': '1234567890abcdef',
    'vodId': '42',
    'title': '追番测试',
    'detailUrl': '${_home}anime/1234567890abcdef.html',
    'lines': <dynamic>[],
  };
  final repo = ApiVideoRepository(
    source: 'follow-action-fixture',
    home: _home,
    catalogFn: 'list',
    detailFn: 'item',
    playbackFn: 'play',
    pluginCall: (_, _) async => {'data': data},
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ApiVideoDetailPage(
        repository: repo,
        initialItem: ApiVideoItem.fromJson(data, home: _home),
        store: store,
        siteClient: client,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'touch-oriented route arrival under a stationary pointer is idle while real hover, focus and press retain feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = OmoSiteClient(
        home: _home,
        request: (operation, _) async => operation == 'account'
            ? _account('fixture')
            : {'kind': 'favoriteState', 'favorite': false},
      );
      final store = VideoLibraryStore(
        deviceId: 'hover-fixture',
        storageKey: 'hover-route-fixture',
      );
      addTearDown(client.dispose);
      addTearDown(store.dispose);
      final data = {
        'id': '1234567890abcdef',
        'vodId': '42',
        'title': '触控追番状态',
        'detailUrl': '${_home}anime/1234567890abcdef.html',
        'lines': <Object>[],
      };
      final repository = ApiVideoRepository(
        source: 'hover-route-fixture',
        home: _home,
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        pluginCall: (_, _) async => {'data': data},
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      void open() => unawaited(
        navigator.currentState!.push<void>(
          videoPageRoute(
            builder: (_) => ApiVideoDetailPage(
              repository: repository,
              initialItem: ApiVideoItem.fromJson(data, home: _home),
              store: store,
              siteClient: client,
            ),
          ),
        ),
      );
      InkWell ink() => tester.widget<InkWell>(
        find.descendant(of: _favorite, matching: find.byType(InkWell)).first,
      );
      Color? overlay() => tester
          .widget<TextButton>(_favorite)
          .style
          ?.overlayColor
          ?.resolve(ink().statesController!.value);
      open();
      await tester.pumpAndSettle();
      final position = tester.getCenter(_favorite);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(pointer.removePointer);
      await pointer.addPointer(location: position);
      await pointer.moveTo(position);
      open();
      await tester.pumpAndSettle();
      expect(_favorite, findsOneWidget);
      expect(ink().statesController!.value, contains(WidgetState.hovered));
      expect(
        ink().statesController!.value,
        isNot(contains(WidgetState.pressed)),
      );
      expect(
        overlay()?.a ?? 0,
        0,
        reason:
            'A new touch page under an unmoved pointer must not arrive looking pressed',
      );
      await pointer.moveTo(position + const Offset(2, 0));
      await tester.pump();
      expect(
        overlay()?.a ?? 0,
        greaterThan(0),
        reason: 'An actual mouse move still gets normal hover feedback',
      );
      final touch = await tester.startGesture(position);
      // TapDown is deferred while the surrounding scroll/drag arena is open.
      await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
      expect(ink().statesController!.value, contains(WidgetState.pressed));
      expect(overlay()?.a ?? 0, greaterThan(0));
      await touch.cancel();
      await tester.pumpAndSettle();
      expect(
        ink().statesController!.value,
        isNot(contains(WidgetState.pressed)),
      );
      expect(overlay()?.a ?? 0, 0);
      final strategy = FocusManager.instance.highlightStrategy;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      for (
        var index = 0;
        index < 20 &&
            !ink().statesController!.value.contains(WidgetState.focused);
        index++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(ink().statesController!.value, contains(WidgetState.focused));
      expect(
        overlay()?.a ?? 0,
        greaterThan(0),
        reason: 'Keyboard focus remains visible',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      for (final id in ['favorite', 'share']) {
        final action = find.byKey(ValueKey('api-detail.$id'));
        final center = tester.getCenter(action);
        await pointer.moveTo(center);
        await tester.pump();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        open();
        await tester.pumpAndSettle();
        final actionInk = tester.widget<InkWell>(
          find.descendant(of: action, matching: find.byType(InkWell)).first,
        );
        final states = actionInk.statesController!.value;
        expect(states, contains(WidgetState.hovered));
        expect(states, isNot(contains(WidgetState.pressed)));
        final color = tester
            .widget<TextButton>(action)
            .style
            ?.overlayColor
            ?.resolve(states);
        expect(
          color?.a ?? 0,
          0,
          reason: 'The same passive-hover rule applies to $id',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Omo detail retains local favorites without site follow requests',
    (tester) async {
      final calls = <String>[];
      final client = OmoSiteClient(
        home: _home,
        request: (operation, _) async {
          calls.add(operation);
          throw StateError('Unexpected site request');
        },
      );
      await _mount(tester, client);
      await tester.pumpAndSettle();
      expect(_favorite, findsOneWidget);
      expect(
        find.byKey(const ValueKey('api-detail.site-follow')),
        findsNothing,
      );
      await tester.tap(_favorite);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _favorite,
          matching: find.text(t.videoLibrary.saved),
        ),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'a pending favorite state cannot cross an account identity change',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var accountId = '1';
      final client = OmoSiteClient(
        home: _home,
        request: (op, _) async =>
            op == 'account' ? _account(accountId) : pending.future,
      );
      addTearDown(client.dispose);
      await client.readAccount();
      final read = client.favoriteState('42');
      final failure = expectLater(
        read,
        throwsA(
          isA<OmoSiteException>().having(
            (e) => e.kind,
            'kind',
            'accountChanged',
          ),
        ),
      );
      accountId = '2';
      await client.readAccount();
      pending.complete({'kind': 'favoriteState', 'favorite': false});
      await failure;
      expect(client.account?.id, '2');
    },
  );

  test(
    'an old signed-out favorite read cannot describe the newer account',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var accountId = '1';
      final client = OmoSiteClient(
        home: _home,
        request: (op, _) async =>
            op == 'account' ? _account(accountId) : pending.future,
      );
      addTearDown(client.dispose);
      await client.readAccount();
      final failure = expectLater(
        client.favoriteState('42'),
        throwsA(
          isA<OmoSiteException>().having(
            (e) => e.kind,
            'kind',
            'accountChanged',
          ),
        ),
      );
      accountId = '2';
      await client.readAccount();
      pending.complete({'kind': 'signedOut'});
      await failure;
      expect(client.account?.id, '2');
    },
  );

  for (final malformed in [null, 'false', 0]) {
    test(
      'malformed favorite state $malformed is unknown, not unfollowed',
      () async {
        final client = OmoSiteClient(
          home: _home,
          request: (op, _) async => op == 'account'
              ? _account('1')
              : {'kind': 'favoriteState', 'favorite': malformed},
        );
        addTearDown(client.dispose);
        await client.readAccount();
        await expectLater(
          client.favoriteState('42'),
          throwsA(
            isA<OmoSiteException>().having(
              (e) => e.kind,
              'kind',
              'unavailable',
            ),
          ),
        );
      },
    );
  }
}
