import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_library_store.dart';

void main() {
  final home = Uri.parse('https://example.org/');

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool reduced = false,
    bool directors = true,
    Brightness brightness = Brightness.light,
    String firstName = '声优一',
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = <String, dynamic>{
      'id': 'metadata',
      'title': '资料排版示例',
      'detailUrl': 'https://example.org/anime/metadata.html',
      'genres': '动画 · 奇幻',
      'credits': [
        if (directors)
          for (var i = 0; i < 8; i++)
            {
              'name': '导演${i + 1}',
              'role': 'director',
              'url': 'https://example.org/search/director-$i.html',
            },
        for (var i = 0; i < 8; i++)
          {
            'name': i == 0 ? firstName : '声优${i + 1}',
            'role': 'voice',
            'url': 'https://example.org/search/voice-$i.html',
          },
      ],
    };
    final repository = ApiVideoRepository(
      source: 'metadata-$width-$scale-$brightness',
      home: home,
      catalogFn: 'list',
      detailFn: 'detail',
      playbackFn: 'play',
      pluginCall: (path, args) async => {
        'data': path == 'detail' ? data : {'items': []},
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: ApiVideoDetailPage(
          repository: repository,
          initialItem: ApiVideoItem.fromJson(data, home: home),
          store: VideoLibraryStore(
            deviceId: 'metadata-test',
            storageKey: 'metadata-$width-$scale-$brightness',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'initial metadata layout');
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('api-detail.metadata')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('metadata labels align with plain values and first credit line', (
    tester,
  ) async {
    await mount(tester, directors: false);
    await reveal(tester, find.text('声优一'));
    expect(
      tester.getTopLeft(find.text(t.videoLibrary.genres)).dy,
      closeTo(tester.getTopLeft(find.text('动画 · 奇幻')).dy, .5),
    );
    expect(
      tester.getTopLeft(find.text(t.videoLibrary.voiceCast)).dy,
      closeTo(tester.getTopLeft(find.text('声优一')).dy, .5),
    );
    expect(
      tester.getTopLeft(find.text('声优一')).dx,
      closeTo(tester.getTopLeft(find.text('动画 · 奇幻')).dx, .5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('each role expands independently on a separate control row', (
    tester,
  ) async {
    await mount(tester);
    final director = find.byKey(
      const ValueKey('api-detail.credits.director.toggle'),
    );
    await reveal(tester, director);
    final names = find.byKey(
      const ValueKey('api-detail.credits.director.names'),
    );
    expect(
      tester.getTopLeft(director).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(names).dy),
    );
    expect(tester.getSize(director).height, greaterThanOrEqualTo(44));
    await tester.tap(director);
    await tester.pumpAndSettle();
    expect(find.text('导演8'), findsOneWidget);
    expect(find.text('声优8'), findsNothing);
    await reveal(tester, director);
    await tester.tap(director);
    await tester.pumpAndSettle();
    expect(find.text('导演8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('credit links retain a 44 point target and open their person', (
    tester,
  ) async {
    await mount(tester, directors: false);
    final name = find.widgetWithText(TextButton, '声优一');
    await reveal(tester, name);
    expect(tester.getSize(name).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(name).width, greaterThanOrEqualTo(44));
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(find.byType(ApiVideoLibraryPage), findsOneWidget);
    expect(find.text('声优一'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long first names align and an interrupted expansion reverses', (
    tester,
  ) async {
    await mount(tester, directors: false, firstName: '很长的跨行声优姓名需要保留完整可读');
    final toggle = find.byKey(
      const ValueKey('api-detail.credits.voice.toggle'),
    );
    await reveal(tester, toggle);
    final first = find.text('很长的跨行声优姓名需要保留完整可读');
    expect(
      tester.getTopLeft(find.text(t.videoLibrary.voiceCast)).dy,
      closeTo(tester.getTopLeft(first).dy, .5),
    );
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isTrue,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('声优8'), findsNothing);
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '320 point double text credits stay reversible in $brightness',
      (tester) async {
        await mount(
          tester,
          width: 320,
          scale: 2,
          reduced: true,
          directors: false,
          brightness: brightness,
          firstName: '很长的跨行声优姓名测试',
        );
        final toggle = find.byKey(
          const ValueKey('api-detail.credits.voice.toggle'),
        );
        await reveal(tester, toggle);
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
        expect(tester.getRect(toggle).right, lessThanOrEqualTo(304));
        await tester.tap(toggle);
        await tester.pump();
        expect(find.text('声优8'), findsOneWidget);
        await reveal(tester, toggle);
        await tester.tap(toggle);
        await tester.pump();
        expect(find.text('声优8'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
