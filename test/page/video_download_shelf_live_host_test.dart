import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('export committed while a shelf-open action is pending becomes visible on return', (tester) async {
    final opening = Completer<void>();
    var opened = false, reads = 0;
    final store = VideoLibraryStore(deviceId: 'download-shelf-live');
    addTearDown(store.dispose);
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    Future<void> exported(int id, String title) => VideoExportRecords.add(
      source: 'shelf-live', video: Uri.parse('https://hanime1.me/watch?v=$id'),
      title: title, quality: '720p');
    await tester.runAsync(() => exported(11, '已有导出'));
    final data = VideoBookshelfPaneDataSource(
      changes: VideoExportRecords.exportsChanged, store: store,
      sourceNames: () async => {'shelf-live': '本机测试源'},
      open: (_, _) { opened = true; return opening.future; },
      remove: (_, _) async {}, enrich: (row) async => row.item,
      load: (_, _) async {
        reads++;
        return [for (final row in await VideoExportRecords.read()) VideoBookshelfRow(
          key: row['key'] as String, source: 'shelf-live', recordKey: row['key'] as String,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row['at'] as int),
          item: ApiVideoItem(id: row['key'] as String, title: row['title'] as String,
            detailUrl: Uri.parse(row['url'] as String)),
        )];
      },
    );
    await tester.pumpWidget(AppInterfaceStyleScope(style: style,
      child: MaterialApp(home: Scaffold(body: VideoBookshelfPane(
        mode: ShelfPageMode.download, search: const SearchStatusState(), dataSource: data,
      )))));
    Future<void> until(bool Function() ready) async {
      for (var frame = 0; frame < 80 && !ready(); frame++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(ready(), isTrue);
    }
    await until(() => find.text('已有导出').evaluate().isNotEmpty);
    await tester.tap(find.text('已有导出'));
    await until(() => opened);
    final before = reads;
    await tester.runAsync(() => exported(12, '下载完成新导出'));
    await tester.pump();
    expect(reads, before, reason: 'Do not reload the underlying collection while its action is held.');
    expect(find.text('下载完成新导出'), findsNothing);
    opening.complete();
    await until(() => find.text('下载完成新导出').evaluate().isNotEmpty);
    expect(reads, greaterThan(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
