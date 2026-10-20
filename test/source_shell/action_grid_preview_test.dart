import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('source categories keep their preview images and actions', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const DiscoverSchemeRenderer().buildPage(
              context,
              from: 'personal-source',
              scheme: {
                'body': {'type': 'action-grid', 'key': 'items'},
              },
              data: {
                'items': [
                  {
                    'title': '短篇',
                    'cover': {
                      'url': 'https://img.example/category.jpg',
                      'path': 'category.jpg',
                    },
                    'action': {
                      'type': 'openSearch',
                      'payload': {'source': 'personal-source'},
                    },
                  },
                ],
              },
              onReachBottom: () async {},
              onAction: (action) async => selected = action,
              isLoadingMore: false,
              showLoadMoreRetry: false,
              onRetryLoadMore: () {},
            ),
          ),
        ),
      ),
    );

    final preview = tester.widget<CoverWidget>(find.byType(CoverWidget));
    expect(preview.fileServer, 'https://img.example/category.jpg');
    expect(preview.path, 'category.jpg');
    expect(find.text('短篇'), findsOneWidget);
    await tester.tap(find.text('短篇'));
    expect(selected?['type'], 'openSearch');
    await tester.pump(const Duration(milliseconds: 150));
  });
}
