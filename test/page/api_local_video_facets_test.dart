import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets(
    'local favorites applies, cancels and clears actual metadata facets without fetching details',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'facets-test',
        storageKey: 'facets-test',
      );
      addTearDown(store.dispose);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await store.importFavorites('unknown-plugin', [
          for (var i = 0; i < 2; i++)
            ApiVideoItem(
              id: '$i',
              title: 'Work $i',
              detailUrl: Uri.parse(
                'https://video.test/voddetail/${i + 1}.html',
              ),
              genres: i == 0 ? 'Action' : 'Drama',
              year: i == 0 ? '2024' : '2025',
            ),
        ]);
      });
      var requests = 0;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: ApiVideoFavorites(
                source: 'unknown-plugin',
                store: store,
                mode: ApiVideoView.grid,
                onOpen: (_) async {},
                loadDetail: (item) async {
                  requests++;
                  return item;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> choose() async {
        await tester.tap(find.byKey(const ValueKey('local-favorites.filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-facet-tags')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('shelf-option-tags-Action')),
        );
        await tester.pumpAndSettle();
      }

      await choose();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items,
        hasLength(2),
      );
      await choose();
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items
            .single
            .id,
        '0',
      );
      await tester.tap(
        find.byKey(const ValueKey('local-favorites.clear-filter')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items,
        hasLength(2),
      );
      expect(requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape cards size to actual caption rather than reserving portrait-height whitespace',
    (tester) async {
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoCollection(
              mode: ApiVideoView.grid,
              posterAspectRatio: 16 / 9,
              storageKey: 'landscape-caption',
              onOpen: (_) {},
              items: [
                for (var i = 0; i < 4; i++)
                  ApiVideoItem(
                    id: '$i',
                    title: 'Work $i',
                    detailUrl: Uri.parse(
                      'https://video.test/voddetail/${i + 1}.html',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey('api-video.0')));
      final next = tester.getRect(find.byKey(const ValueKey('api-video.2')));
      expect(
        next.top - first.top - first.width / (16 / 9),
        lessThan(80),
        reason:
            'Only two title lines and the normal row gap are needed without public summary/remarks',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
