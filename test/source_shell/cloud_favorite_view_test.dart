import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';

void main() {
  testWidgets('cloud favorite entry point defaults to detailed view', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComicListPage(
          title: '云端收藏',
          sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('cloud-favorite-view-toggle')),
      findsOneWidget,
    );
    expect(find.byTooltip('切换网格'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cloud-favorite-view-toggle')));
    await tester.pump();
    expect(find.byTooltip('切换列表'), findsOneWidget);
  });
}
