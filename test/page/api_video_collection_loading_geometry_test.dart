import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';

void main() {
  for (final shelf in [true, false]) {
    for (final width in [320.0, 440.0]) {
      for (final scale in [1.0, 1.35, 2.0]) {
        testWidgets('loading geometry shelf=$shelf width=$width scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final base = ThemeData();
          final textTheme = TextTheme.lerp(
            base.textTheme,
            base.textTheme.copyWith(
              titleSmall: base.textTheme.titleSmall!.copyWith(fontSize: 15.7),
              bodySmall: base.textTheme.bodySmall!.copyWith(fontSize: 13.1),
            ),
            .37,
          );
          final item = ApiVideoItem(
            id: 'sample',
            title: 'Sample title',
            year: '2026',
            detailUrl: Uri.parse('https://example.com/sample'),
          );
          Widget host(bool loading) => MaterialApp(
            theme: base.copyWith(textTheme: textTheme),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Builder(
                  builder: (context) => ApiVideoCollection(
                    key: const ValueKey('same-collection'),
                    items: loading ? [] : [item],
                    mode: ApiVideoView.grid,
                    onOpen: (_) {},
                    loading: loading,
                    storageKey: 'geometry',
                    gridColumns: shelf ? 3 : null,
                    gridItemExtent: shelf
                        ? BookshelfContentLayout.itemExtent(context, width)
                        : null,
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    gridMainAxisSpacing: shelf
                        ? BookshelfContentLayout.spacing
                        : 0,
                    gridCaptionBuilder: shelf
                        ? (_, item) => BookshelfCardCaption(
                            title: item.title,
                            subtitle: 'Source',
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(host(true));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'loading');
          final skeleton = tester.getRect(
            find.byKey(const ValueKey('api-skeleton.poster.0')),
          );
          expect(skeleton.width / skeleton.height, closeTo(2 / 3, .0001));
          await tester.pumpWidget(host(false));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'loaded');
          final loaded = tester.getRect(find.byType(ApiVideoPoster).first);
          expect(loaded, skeleton);
        });
      }
    }
  }
}
