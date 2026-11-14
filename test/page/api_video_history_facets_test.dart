import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets(
    'history facets use saved public metadata, keep query and never classify watch date as release year',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        for (var i = 0; i < 3; i++) {
          await VideoWatchHistory.record(
            'hybrid',
            VideoWatchRecord(
              watchUrl: Uri.parse(
                'https://module.test/videos/Hid$i?line=main&episode=1',
              ),
              title: 'Work $i',
              position: const Duration(seconds: 30),
              duration: const Duration(minutes: 10),
              updatedAt: DateTime.utc(2026, 10, i + 1),
              completed: false,
              metadata: i == 2
                  ? const {}
                  : {
                      'genres': i == 0 ? 'Action' : 'Drama',
                      'year': i == 0 ? '2024' : '2025',
                    },
            ),
          );
        }
      });
      var requests = 0;
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: Text(t.videoLibrary.history)),
              body: ApiVideoHistory(
                source: 'hybrid',
                home: Uri.parse('https://module.test'),
                itemNamespace: 'movie',
                posterAspectRatio: 16 / 9,
                mode: ApiVideoView.grid,
                onOpen: (_, _) async {},
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
      expect(
        find.text(t.videoLibrary.history),
        findsOneWidget,
        reason: 'The route already supplies the record title',
      );
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'Work');
      await tester.pumpAndSettle();
      Future<void> choose() async {
        await tester.tap(find.byKey(const ValueKey('api-history.filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-facet-year')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('shelf-option-year-2026-10-01')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('shelf-option-year-2024')));
        await tester.pumpAndSettle();
      }

      await choose();
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items,
        hasLength(3),
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
        'movie:Hid0',
      );
      expect(tester.widget<TextField>(search).controller!.text, 'Work');
      var collection = tester.widget<ApiVideoCollection>(
        find.byType(ApiVideoCollection),
      );
      collection.onLongPress!(collection.items.single);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .selecting,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .selecting,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('api-history.clear-filter')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
            .items,
        hasLength(3),
      );
      expect(requests, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
