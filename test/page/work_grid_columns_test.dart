import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_grid.dart';

void main() {
  test('bookshelf and legacy comic work grids use three columns without changing format ratios', () {
    for (final width in [320.0, 440.0, 800.0, 1200.0]) {
      expect(BookshelfContentLayout.columns(width), 3);
    }
    final delegate = buildComicSimplifyEntryGridDelegate(childAspectRatio: .68)
        as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.childAspectRatio, .68);
  });
  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('video work grid stays three columns including its loading host $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget host({int? explicit}) => MaterialApp(home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: ApiVideoCollection(items: const [], loading: true,
            storageKey: 'grid-columns-fixture', mode: ApiVideoView.grid, gridColumns: explicit, onOpen: (_) {}))));
        await tester.pumpWidget(host());
        await tester.pump();
        var grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(host(explicit: 4));
        await tester.pump();
        grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 4,
          reason: 'An explicit host choice remains authoritative.');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
