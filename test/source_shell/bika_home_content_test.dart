import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/widgets/bika_home_content.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

Map<String, dynamic> _data({bool failed = false, int count = 3}) => {
  'categories': [
    for (var i = 0; i < count; i++)
      {
        'title': '分类 $i',
        'cover': <String, dynamic>{},
        'action': {
          'type': 'openSearch',
          'payload': {
            'source': bikaPlusSourceId,
            'extern': {
              'categories': ['分类 $i'],
            },
          },
        },
      },
  ],
  'keywords': [
    {
      'label': '热词',
      'action': {
        'type': 'openSearch',
        'payload': {'source': bikaPlusSourceId, 'keyword': '热词'},
      },
    },
  ],
  'shortcuts': [
    {
      'label': '排行榜',
      'action': {'type': 'openComicList', 'payload': <String, dynamic>{}},
    },
  ],
  'notices': [
    if (failed)
      {
        'label': '热词加载失败 · 重试',
        'action': {
          'type': 'openPluginFunction',
          'payload': {'source': bikaPlusSourceId, 'id': 'home'},
        },
      },
  ],
};

Widget _host(
  Widget home, {
  String style = 'breeze',
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => AppInterfaceStyleScope(
  style: ValueNotifier(style),
  child: MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 600),
          textScaler: TextScaler.linear(scale),
        ),
        child: TouchHoverIntentScope(child: home),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Display conversion reads the real UserSetting row via globalSetting. The
  // shared helper creates that row in a temporary, isolated ObjectBox store.
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('hot words start compact and expand locally without replacing the categories', (tester) async {
    final data = _data();
    data['keywords'] = [for (var i = 0; i < 12; i++) {'label': '热词$i', 'action': {'type': 'openSearch', 'payload': {'keyword': '热词$i'}}}];
    var reloads = 0;
    await tester.pumpWidget(_host(BikaHomeContent(source: bikaPlusSourceId, data: data,
      loading: false, error: '', onReload: () async { reloads++; }, onAction: (_) async {})));
    expect(find.text('热词0'), findsOneWidget); expect(find.text('热词4'), findsNothing);
    final scroll = tester.widget<ListView>(find.byKey(const ValueKey('bika-home-scroll'))).controller;
    await tester.tap(find.byKey(const ValueKey('bika-home-keywords-toggle'))); await tester.pump();
    expect(find.text('热词11'), findsOneWidget);
    expect(tester.widget<ListView>(find.byKey(const ValueKey('bika-home-scroll'))).controller, same(scroll));
    expect(reloads, 0); expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home category and hot-word actions preserve their real payloads',
    (tester) async {
      final actions = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        _host(
          BikaHomeContent(
            source: bikaPlusSourceId,
            data: _data(),
            loading: false,
            error: '',
            onReload: () async {},
            onAction: (action) async {
              actions.add(action);
            },
          ),
        ),
      );
      // Empty covers must use the production semantic fallback. Do not create
      // an empty-path provider whose asynchronous error could escape assertions.
      expect(find.byType(CoverWidget), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.auto_stories_outlined), findsNWidgets(3));
      expect(
        tester.getTopLeft(find.text('热词')).dy,
        lessThan(tester.getTopLeft(find.text('分类 0')).dy),
        reason: 'Hot words belong directly below the shell search, before categories',
      );
      expect(
        tester.getTopLeft(find.text('排行榜')).dy,
        lessThan(tester.getTopLeft(find.text('分类 0')).dy),
      );
      await tester.tap(find.text('分类 0'));
      await tester.tap(find.text('热词'));
      expect(actions.map((a) => a['type']), ['openSearch', 'openSearch']);
      expect((actions.first['payload'] as Map)['extern'], {
        'categories': ['分类 0'],
      });
      expect((actions.last['payload'] as Map)['keyword'], '热词');
      expect(find.byType(TouchHoverIntent), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed section retries in place once while keeping successful content',
    (tester) async {
      final held = Completer<void>();
      var calls = 0, navigations = 0;
      await tester.pumpWidget(
        _host(
          BikaHomeContent(
            source: bikaPlusSourceId,
            data: _data(failed: true),
            loading: false,
            error: '',
            onReload: () {
              calls++;
              return held.future;
            },
            onAction: (_) async {
              navigations++;
            },
          ),
        ),
      );
      await tester.tap(find.text('热词加载失败 · 重试'));
      await tester.pump();
      await tester.tap(find.text('热词加载失败 · 重试'));
      await tester.pump();
      expect(calls, 1);
      expect(navigations, 0);
      expect(find.text('分类 0'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      held.complete();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reload and theme changes retain the existing scroller and offset',
    (tester) async {
      var loading = false;
      var dark = false;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return _host(
              BikaHomeContent(
                source: bikaPlusSourceId,
                data: loading ? {} : _data(count: 60),
                loading: loading,
                error: '',
                onReload: () async {},
                onAction: (_) async {},
              ),
              brightness: dark ? Brightness.dark : Brightness.light,
            );
          },
        ),
      );
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('bika-home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final initial = tester.state<ScrollableState>(scrollable);
      await tester.drag(
        find.byKey(const ValueKey('bika-home-scroll')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      final offset = initial.position.pixels;
      expect(offset, greaterThan(0));
      update(() {
        loading = true;
        dark = true;
      });
      await tester.pump();
      expect(
        identical(tester.state<ScrollableState>(scrollable), initial),
        isTrue,
      );
      expect(initial.position.pixels, offset);
      update(() {
        loading = false;
      });
      await tester.pump();
      expect(initial.position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fatal failure removes stale content and retry is still available',
    (tester) async {
      var error = '';
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return _host(
              BikaHomeContent(
                source: bikaPlusSourceId,
                data: error.isEmpty ? _data() : {},
                loading: false,
                error: error,
                onReload: () async {},
                onAction: (_) async {},
              ),
            );
          },
        ),
      );
      expect(find.text('分类 0'), findsOneWidget);
      update(() {
        error = '浏览条件已变化，请重试';
      });
      await tester.pump();
      expect(find.text('分类 0'), findsNothing);
      expect(find.text(error), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    },
  );

  for (final sample in [
    (width: 320.0, scale: 1.0, columns: 3),
    (width: 390.0, scale: 1.0, columns: 4),
    (width: 440.0, scale: 1.0, columns: 5),
    (width: 320.0, scale: 2.0, columns: 2),
  ]) {
    testWidgets('category density ${sample.width} at ${sample.scale}x adapts without losing actions', (tester) async {
      tester.view.physicalSize = Size(sample.width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = <Map<String, dynamic>>[];
      await tester.pumpWidget(_host(BikaHomeContent(
        source: bikaPlusSourceId, data: _data(count: 8), loading: false, error: '',
        onReload: () async {}, onAction: (action) async { actions.add(action); },
      ), scale: sample.scale));
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount,
        sample.columns);
      await tester.tap(find.text('分类 0'));
      expect(actions.single['type'], 'openSearch');
      expect(tester.takeException(), isNull);
    });
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('$style $brightness narrow large text remains actionable', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = _data();
        (data['categories'] as List).first['title'] = 'とても長い日本語の分類タイトル・全編';
        await tester.pumpWidget(
          _host(
            BikaHomeContent(
              source: bikaPlusSourceId,
              data: data,
              loading: false,
              error: '',
              onReload: () async {},
              onAction: (_) async {},
            ),
            style: style,
            brightness: brightness,
            scale: 2,
          ),
        );
        expect(find.byType(InkWell), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
