import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/source_downloaded_videos_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../download_fixture.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';

Map<String, dynamic> episode(String id, {String source = 'omo', String module = 'anime', String? work = 'work42', bool available = true}) => {
  'key': id, 'resourceId': 'resource$id', 'source': source, 'title': 'Episode $id',
  'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$id',
  'quality': '720p', 'format': 'hls', 'at': 1,
  'status': available ? 'saved' : 'failed', 'local': available,
  'available': available, 'filePresent': available,
  if (work != null) 'publicWorkIdentity': work,
  'publicModuleNamespace': module, 'publicWorkTitle': 'Actual work',
};
void main() {
  test('source preview uses canonical groups while module, source and unknown identities stay separate', () {
    final rows = [episode('1'), episode('2'), episode('3', module: 'movie'),
      episode('4', source: 'other'), episode('5', work: null), episode('6', work: null)];
    final groups = sourceVideoDownloadGroups(rows, 'omo');
    expect(groups, hasLength(4));
    final series = groups.where((item) => item.work != null).single.work!;
    expect(series.title, 'Actual work');
    expect(series.episodes.map((item) => item.video!['key']), containsAll(['1', '2']));
    expect(groups.expand((item) => item.work?.episodes ?? [item.item]).every((item) => item.source == 'omo'), isTrue);
    expect(groups.where((item) => item.work == null), hasLength(3));
  });
  test('preview starts from real playable files but retains failed siblings in the work universe', () {
    final groups = sourceVideoDownloadGroups([episode('1'), episode('2', available: false)], 'omo');
    expect(groups, hasLength(1));
    expect(groups.single.work!.episodes.single.video!['key'], '1');
    expect(groups.single.work!.totalEpisodes, 2);
    expect(sourceVideoDownloadItems([episode('1'), episode('2', available: false)], 'omo'), hasLength(2));
  });
  test('real task-backed merge preserves validated availability before source grouping', () {
    final tasks = [for (var i = 1; i <= 5; i++) {
      'key': 'task$i', 'resourceId': 'resource$i', 'source': 'omo', 'title': 'Episode $i',
      'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$i',
      'quality': '720p', 'format': 'hls', 'at': i,
      'status': 'saved', 'local': true, 'fileRemoved': false, 'fileInvalid': false,
    }];
    final resources = [for (var i = 1; i <= 5; i++) {
      'resourceId': 'resource$i', 'source': 'omo', 'title': 'Episode $i',
      'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$i',
      'quality': '720p', 'format': 'hls', 'at': i, 'bytes': 1024,
      'available': true, 'filePresent': true,
    }];
    expect(tasks.every((row) => !row.containsKey('available') && !row.containsKey('filePresent')), isTrue);
    final merged = DownloadCenterResources.mergeVideos(tasks, resources);
    expect(merged, hasLength(5));
    expect(merged.every((row) => row['available'] == true && row['filePresent'] == true), isTrue);
    expect(sourceVideoDownloadGroups(merged, 'omo'), hasLength(5));
    final missing = DownloadCenterResources.mergeVideos(tasks, []);
    expect(sourceVideoDownloadGroups(missing, 'omo'), isEmpty);
  });
  testWidgets('source work and standalone cards share geometry and keep the work title above the episode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    final entries = sourceVideoDownloadGroups([episode('1'), episode('2'), episode('3', work: null)], 'omo');
    final work = entries.singleWhere((entry) => entry.work != null).work!;
    final single = entries.singleWhere((entry) => entry.work == null).item;
    var opens = 0, manages = 0;
    await tester.pumpWidget(AppInterfaceStyleScope(style: style,
      child: MaterialApp(home: Scaffold(body: ListView(children: [
        SourceDownloadedWorkCard(key: const ValueKey('work-card'), work: work,
          onOpen: () => opens++, onManage: () => manages++, onRemove: () {}),
        SourceDownloadedEpisodeRow(key: const ValueKey('single-card'),
          item: single),
      ])))));
    await tester.pump();
    for (final key in ['work-card', 'single-card']) {
      final card = find.byKey(ValueKey(key));
      final cover = find.descendant(of: card, matching: find.byType(DownloadVideoTaskCover));
      expect(tester.getSize(cover), const Size(88, 132));
      final title = find.descendant(of: card, matching: find.byKey(const ValueKey('source-download-card.title')));
      expect(tester.widget<Text>(title).data, 'Actual work');
    }
    await tester.tap(find.byKey(const ValueKey('work-card')));
    expect(opens, 1);
    await tester.longPress(find.byKey(const ValueKey('work-card')));
    expect(manages, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Omo source downloads use compact search and retain its query when closed', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await useIsolatedDownloadFixture();
    });
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(AppInterfaceStyleScope(style: style, child: const MaterialApp(
      home: SourceDownloadedVideosPage(source: 'omo', groupDownloads: true))));
    expect(find.byType(TextField), findsNothing);
    final elapsed = Stopwatch()..start();
    final count = find.byKey(const ValueKey('source-downloads.count'));
    while (count.evaluate().isEmpty && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(count, findsOneWidget);
    final search = find.byKey(const ValueKey('source-downloads.search-toggle'));
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'Stored query');
    await tester.pumpAndSettle();
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Stored query'), findsOneWidget);
    expect(find.byKey(const ValueKey('source-downloads.more')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
