import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets(
    'history detail notes keep local watch time and progress through public metadata refresh',
    (tester) async {
      final watchedAt = DateTime(2026, 11, 1, 21, 37);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await VideoWatchHistory.record(
          'timestamps',
          VideoWatchRecord(
            watchUrl: Uri.parse(
              'https://module.test/videos/Hid1?line=1&episode=1',
            ),
            title: 'Record',
            position: const Duration(seconds: 30),
            duration: const Duration(minutes: 10),
            updatedAt: watchedAt,
            completed: false,
            metadata: const {'year': '2024'},
          ),
        );
      });
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final detail = Completer<ApiVideoItem>();
      ApiVideoItem? requested;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: ApiVideoHistory(
                source: 'timestamps',
                home: Uri.parse('https://module.test'),
                itemNamespace: 'movie',
                mode: ApiVideoView.list,
                onOpen: (_, _) async {},
                loadDetail: (item) {
                  requested = item;
                  return detail.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final note = t.videoLibrary.lastWatchedAt(time: '2026-11-01 21:37');
      final progress = t.bookshelf.watchTo(position: '0:30');
      expect(find.textContaining('$progress\n$note'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(requested, isNotNull);
      detail.complete(
        ApiVideoItem.fromJson({
          ...requested!.toLibraryJson(),
          'updatedAt': '2040-01-02 01:02',
          'remarks': 'source refresh',
          'description': 'Public synopsis',
        }, home: requested!.detailUrl),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('$progress\n$note'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      final collection = tester.widget<ApiVideoCollection>(
        find.byType(ApiVideoCollection),
      );
      expect(collection.items.single.year, '2024');
      final rows = (await tester.runAsync(
        () => VideoWatchHistory.read('timestamps'),
      ))!;
      expect(rows.single.updatedAt.toUtc(), watchedAt.toUtc());
      expect(tester.takeException(), isNull);
    },
  );
}
