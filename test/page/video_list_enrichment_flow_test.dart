import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

void main() {
  testWidgets(
    'catalog detailed mode supplements a fresh summary without opening it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'breeze.video.library.view.list-enrichment': 'list',
      });
      var detailReads = 0;
      final summary = {
        'id': '1234567890abcdef',
        'title': '只提供摘要的作品',
        'year': '2026',
        'remarks': '4集',
        'detailUrl': 'https://example.com/anime/1234567890abcdef.html',
      };
      final repository = ApiVideoRepository(
        source: 'list-enrichment',
        home: Uri.parse('https://example.com/'),
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(presentation: 'anime'),
        pluginCall: (path, args) async {
          if (path == 'item') {
            detailReads++;
            expect(args['id'], summary['id']);
            return {
              'data': {...summary, 'description': '无需先打开详情即可看到完整简介。'},
            };
          }
          expect(path, 'list');
          return {
            'data': {
              'items': [summary],
              'page': 1,
              'pageCount': 1,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repository, title: 'OmoFun'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('无需先打开详情即可看到完整简介。'), findsOneWidget);
      expect(detailReads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
