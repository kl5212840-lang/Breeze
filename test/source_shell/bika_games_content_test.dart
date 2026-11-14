import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/widgets/bika_games_content.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

import '../test_helper.dart';

Map<String, dynamic> _game(int i) => {
  'id': 'game-$i', 'title': '离线游戏样本$i',
  'cover': <String, dynamic>{},
  'publisher': '发布者', 'version': '样本版本',
  'adult': i == 0, 'ios': true, 'android': null,
};

Map<String, dynamic> _list({String source = bikaPlusSourceId,
  int page = 1, int count = 1, bool more = false}) => {
  'source': source,
  'data': {'items': [for (var i = 0; i < count; i++) _game(i)],
    'page': page, 'pages': more ? page + 1 : page, 'hasMore': more},
};

Widget _host(Widget body, {double scale = 1, Brightness brightness = Brightness.light}) =>
    AppInterfaceStyleScope(
      style: ValueNotifier('breeze'),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: MediaQuery(
          data: MediaQueryData(size: const Size(320, 600), textScaler: TextScaler.linear(scale)),
          child: TouchHoverIntentScope(child: body),
        )),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('a nonempty game cover passes the resolved image URL to the shared image loader', (tester) async {
    const source = 'offline-cover-fixture';
    await tester.pumpWidget(_host(BikaGamesContent(source: source, load: (_, _, _) async => {
      'source': source, 'data': {'items': [{..._game(0), 'cover': {
        'url': 'https://img.picacomic.com/games/fixture.jpg', 'path': 'games/fixture.jpg',
      }}], 'page': 1, 'pages': 1, 'hasMore': false},
    })));
    await tester.pumpAndSettle();
    final cover = tester.widget<CoverWidget>(find.byType(CoverWidget));
    expect(cover.fileServer, 'https://img.picacomic.com/games/fixture.jpg');
    expect(cover.path, 'games/fixture.jpg');
    expect(cover.from, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('games use a dedicated request and detail returns to the same retained list', (tester) async {
    final calls = <(String, Map<String, dynamic>)>[];
    Future<Map<String, dynamic>> load(String source, String fn, Map<String, dynamic> core) async {
      calls.add((fn, core));
      if (fn == 'getGameListBundle') return _list();
      expect(fn, 'getGameDetailsBundle'); expect(core, {'id': 'game-0'});
      return {'source': source, 'data': {'game': {..._game(0), 'description': '<p>真实字段的离线详情</p>'}}};
    }
    await tester.pumpWidget(_host(BikaGamesContent(source: bikaPlusSourceId, load: load)));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'getGameListBundle');
    expect(calls.single.$2, {'page': 1});
    expect(find.text('iOS'), findsOneWidget); expect(find.text('Android'), findsNothing);
    expect(find.text('18+'), findsOneWidget);
    await tester.tap(find.text('离线游戏样本0')); await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('真实字段的离线详情'), findsOneWidget);
    expect(find.text(t.sourceShell.bikaDownloadLinksEmpty), findsOneWidget);
    Navigator.of(tester.element(find.byType(AppBar))).pop(); await tester.pumpAndSettle();
    expect(find.byKey(const PageStorageKey('bika-games-scroll')), findsOneWidget);
    expect(calls, hasLength(2)); expect(find.text('离线游戏样本0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authentication failure offers the existing login action and no fake empty list', (tester) async {
    await tester.pumpWidget(_host(BikaGamesContent(
      source: bikaPlusSourceId,
      load: (_, _, _) async => throw StateError('请先登录哔咔账号'),
    )));
    await tester.pumpAndSettle();
    expect(find.text(t.navigation.needLoginTitle), findsOneWidget);
    expect(find.text(t.navigation.goLogin), findsOneWidget);
    expect(find.text('暂无游戏'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure keeps existing games and scroll offset with a local retry', (tester) async {
    var calls = 0;
    final held = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_host(BikaGamesContent(
      source: bikaPlusSourceId,
      load: (_, _, _) async => ++calls == 1 ? _list(count: 12) : held.future,
    )));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(find.byKey(const PageStorageKey('bika-games-scroll')));
    list.controller!.jumpTo(160); await tester.pump();
    final position = list.controller!.offset;
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final pending = refresh.onRefresh(); await tester.pump();
    expect(list.controller!.offset, position);
    held.completeError(StateError('离线请求失败'));
    await pending; await tester.pump();
    expect(list.controller!.offset, position);
    expect(find.text(t.common.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late data after changing sources cannot replace the new source list', (tester) async {
    final old = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> load(String source, String fn, Map<String, dynamic> core) =>
        source == bikaPlusSourceId ? old.future : Future.value(_list(source: source, count: 0));
    await tester.pumpWidget(_host(BikaGamesContent(key: const ValueKey('games'), source: bikaPlusSourceId, load: load)));
    await tester.pump();
    await tester.pumpWidget(_host(BikaGamesContent(key: const ValueKey('games'), source: 'fixture-new-source', load: load)));
    await tester.pumpAndSettle();
    old.complete(_list()); await tester.pumpAndSettle();
    expect(find.text('暂无游戏'), findsOneWidget);
    expect(find.text('离线游戏样本0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('game cards reflow at 320px and large text in ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(320, 600); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(BikaGamesContent(
        source: bikaPlusSourceId, load: (_, _, _) async => _list(),
      ), scale: 1.8, brightness: brightness));
      await tester.pumpAndSettle();
      expect(find.text('离线游戏样本0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
