import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/native_video_catalog_page.dart';

void main() {
  final action = <String, dynamic>{
    'type': 'openVideoCatalog',
    'payload': {
      'source': 'test-video-source',
      'url': 'https://video.example/',
      'nativeSearch': true,
      'catalogFnPath': 'catalog',
      'detailFnPath': 'detail',
      'playbackFnPath': 'playback',
      'selectors': {
        for (final name in [
          'row',
          'rowTitle',
          'rowCards',
          'cards',
          'cardLink',
          'cardTitle',
          'cardImage',
          'cardSubtitle',
          'cardDuration',
          'detailTitle',
          'detailCover',
          'detailDescription',
          'detailTags',
          'episodes',
          'related',
          'video',
        ])
          name: '.fixture',
      },
    },
  };
  test(
    'video search requires explicit capability and keeps launch action intact',
    () {
      final search = DiscoverRouter.videoSearchAction(action)!;
      expect((search['payload'] as Map)['openSearch'], true);
      expect((action['payload'] as Map).containsKey('openSearch'), false);
      expect(
        DiscoverRouter.videoSearchAction({
          'type': 'openVideoCatalog',
          'payload': {},
        }),
        isNull,
      );
      expect(
        DiscoverRouter.videoSearchAction({
          'type': 'openWeb',
          'payload': {'nativeSearch': true},
        }),
        isNull,
      );
    },
  );
  testWidgets(
    'shortcut opens video search first; cancelling never opens a catalog or browser',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => DiscoverRouter.route(
                  context,
                  action: DiscoverRouter.videoSearchAction(action)!,
                  currentFrom: 'test',
                ),
                child: const Text('search'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('search'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoSearchPage), findsOneWidget);
      expect(find.byType(NativeVideoCatalogPage), findsNothing);
      await tester.tap(find.byTooltip(t.videoSearch.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(VideoSearchPage), findsNothing);
      expect(find.byType(NativeVideoCatalogPage), findsNothing);
    },
  );
}
