import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

const _source = 'cloud-view-fixture';

class _CloudViewApi extends RustLibApi {
  @override
  String crateApiQjsOpenccConvert({
    required String text,
    required String config,
  }) => text;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final data = switch (fnPath) {
      'init' => {'ok': true},
      'getCloudFavoriteSceneBundle' => {
        'source': _source,
        'title': '云端收藏',
        'list': {
          'fnPath': 'getCloudFavoriteData',
          'extern': {'source': 'cloudFavorite'},
        },
      },
      'getCloudFavoriteData' => {
        'items': [
          {
            'source': _source,
            'id': 'first',
            'title': 'Cloud work',
            'cover': {'id': 'first', 'url': '', 'path': '', 'extern': {}},
            'metadata': [],
          },
        ],
        'hasReachedMax': true,
      },
      _ => throw StateError('Unexpected fixture call $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode({'data': data})));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _CloudViewApi());
  });
  tearDownAll(() async {
    RustLib.dispose();
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cloud favorite entry point defaults to detailed view', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComicListPage(
          title: '云端收藏',
          sceneSource: _source,
          sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('jm-cloud-view'));
    final grid = find.descendant(
      of: toggle,
      matching: find.byTooltip(t.comicList.switchToGrid),
    );
    expect(tester.widget<SourceListViewToggle>(toggle).detailed, isTrue);
    expect(grid.hitTestable(), findsOneWidget);
    final records = find.byType(PluginPagedComicListView);
    expect(
      tester.widget<PluginPagedComicListView>(records).detailedView,
      isTrue,
    );
    expect(find.text('Cloud work'), findsOneWidget);

    await tester.tap(grid);
    await tester.pump();
    expect(tester.widget<SourceListViewToggle>(toggle).detailed, isFalse);
    expect(
      tester.widget<PluginPagedComicListView>(records).detailedView,
      isFalse,
    );
    expect(
      find.byTooltip(t.comicList.switchToList).hitTestable(),
      findsOneWidget,
    );
  });
}
