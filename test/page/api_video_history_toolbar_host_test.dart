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
    'narrow history toolbar keeps filter and More usable; clear has one confirmation and only removes local source records',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        for (final source in ['history-toolbar', 'other-source']) {
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/1.html?line=1&episode=1',
              ),
              title: 'Work',
              position: const Duration(seconds: 20),
              duration: const Duration(minutes: 10),
              updatedAt: DateTime.utc(2026, 11, 6),
              completed: false,
            ),
          );
        }
      });
      var remoteReads = 0;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 850),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: ApiVideoHistory(
                  source: 'history-toolbar',
                  home: Uri.parse('https://fixture.test'),
                  mode: ApiVideoView.grid,
                  onOpen: (_, _) async {},
                  loadDetail: (item) async {
                    remoteReads++;
                    return item;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialPosterReads = remoteReads;
      final scroll = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scroll, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text(t.common.refreshUnchanged), findsOneWidget);
      expect(remoteReads, initialPosterReads);
      await tester.pump(const Duration(seconds: 3));
      final filter = find.byKey(const ValueKey('api-history.filter'));
      final more = find.byKey(const ValueKey('api-history.manage'));
      expect(filter.hitTestable(), findsOneWidget);
      expect(more.hitTestable(), findsOneWidget);
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(more).height, greaterThanOrEqualTo(44));
      expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.clearHistory));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await tester.pumpAndSettle();
      expect((await VideoWatchHistory.read('history-toolbar')).length, 1);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoLibrary.clearHistory));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      await tester.pumpAndSettle();
      expect(await VideoWatchHistory.read('history-toolbar'), isEmpty);
      expect((await VideoWatchHistory.read('other-source')).length, 1);
      expect(remoteReads, initialPosterReads);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 850), const Size(700, 320)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Omo compact history uses one command row and one results row $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          await VideoWatchHistory.record(
            'omo-compact',
            VideoWatchRecord(
              watchUrl: Uri.parse(
                'https://fixture.test/voddetail/1.html?line=A&episode=1',
              ),
              title: 'Work',
              position: const Duration(seconds: 20),
              duration: const Duration(minutes: 10),
              updatedAt: DateTime.utc(2026, 11, 6),
              completed: false,
            ),
          );
          final style = ValueNotifier('breeze');
          addTearDown(style.dispose);
          var toggles = 0;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ApiVideoHistory(
                    source: 'omo-compact',
                    compactHeader: true,
                    onToggleView: () => toggles++,
                    home: Uri.parse('https://fixture.test'),
                    mode: ApiVideoView.grid,
                    onOpen: (_, _) async {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          final command = find.byKey(
            const ValueKey('api-history.compact-header'),
          );
          final results = find.byKey(
            const ValueKey('api-history.compact-results'),
          );
          expect(command, findsOneWidget);
          expect(results, findsOneWidget);
          final sort = find.byKey(const ValueKey('api-history.sort'));
          final view = find.byKey(const ValueKey('api-history.view'));
          final filter = find.byKey(const ValueKey('api-history.filter'));
          final count = find.byKey(const ValueKey('api-history.count'));
          final more = find.byKey(const ValueKey('api-history.manage'));
          for (final action in [sort, view, filter]) {
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
          }
          expect(tester.getTopLeft(count).dx, 16);
          expect(tester.getCenter(filter).dx, tester.getCenter(more).dx);
          expect(tester.getCenter(sort).dy, tester.getCenter(filter).dy);
          expect(tester.getCenter(view).dy, tester.getCenter(filter).dy);
          expect(
            tester.getRect(results).top,
            greaterThanOrEqualTo(tester.getRect(command).bottom),
          );
          final search = find.byKey(
            const ValueKey('api-history.search-toggle'),
          );
          await tester.tap(search);
          await tester.pumpAndSettle();
          expect(tester.getCenter(filter).dx, tester.getCenter(search).dx);
          expect(find.byType(TextField), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byType(TextField))
                .focusNode!
                .hasFocus,
            isTrue,
          );
          await tester.enterText(find.byType(TextField), 'Work');
          await tester.pumpAndSettle();
          await tester.tap(search);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          await tester.tap(view);
          await tester.pumpAndSettle();
          expect(toggles, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
