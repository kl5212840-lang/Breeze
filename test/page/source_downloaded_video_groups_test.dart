import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/source_downloaded_videos_page.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../download_fixture.dart';
import '../test_helper.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';

Map<String, dynamic> episode(
  String id, {
  String source = 'omo',
  String module = 'anime',
  String? work = 'work42',
  bool available = true,
}) => {
  'key': id,
  'resourceId': 'resource$id',
  'source': source,
  'title': 'Episode $id',
  'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$id',
  'quality': '720p',
  'format': 'hls',
  'at': 1,
  'status': available ? 'saved' : 'failed',
  'local': available,
  'available': available,
  'filePresent': available,
  if (work != null) 'publicWorkIdentity': work,
  'publicModuleNamespace': module,
  'publicWorkTitle': 'Actual work',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'source preview uses canonical groups while module, source and unknown identities stay separate',
    () {
      final rows = [
        episode('1'),
        episode('2'),
        episode('3', module: 'movie'),
        episode('4', source: 'other'),
        episode('5', work: null),
        episode('6', work: null),
      ];
      final groups = sourceVideoDownloadGroups(rows, 'omo');
      expect(groups, hasLength(4));
      final series = groups.where((item) => item.work != null).single.work!;
      expect(series.title, 'Actual work');
      expect(
        series.episodes.map((item) => item.video!['key']),
        containsAll(['1', '2']),
      );
      expect(
        groups
            .expand((item) => item.work?.episodes ?? [item.item])
            .every((item) => item.source == 'omo'),
        isTrue,
      );
      expect(groups.where((item) => item.work == null), hasLength(3));
    },
  );
  test(
    'preview starts from real playable files but retains failed siblings in the work universe',
    () {
      final groups = sourceVideoDownloadGroups([
        episode('1'),
        episode('2', available: false),
      ], 'omo');
      expect(groups, hasLength(1));
      expect(groups.single.work!.episodes.single.video!['key'], '1');
      expect(groups.single.work!.totalEpisodes, 2);
      expect(
        sourceVideoDownloadItems([
          episode('1'),
          episode('2', available: false),
        ], 'omo'),
        hasLength(2),
      );
    },
  );
  test(
    'real task-backed merge preserves validated availability before source grouping',
    () {
      final tasks = [
        for (var i = 1; i <= 5; i++)
          {
            'key': 'task$i',
            'resourceId': 'resource$i',
            'source': 'omo',
            'title': 'Episode $i',
            'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$i',
            'quality': '720p',
            'format': 'hls',
            'at': i,
            'status': 'saved',
            'local': true,
            'fileRemoved': false,
            'fileInvalid': false,
          },
      ];
      final resources = [
        for (var i = 1; i <= 5; i++)
          {
            'resourceId': 'resource$i',
            'source': 'omo',
            'title': 'Episode $i',
            'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$i',
            'quality': '720p',
            'format': 'hls',
            'at': i,
            'bytes': 1024,
            'available': true,
            'filePresent': true,
          },
      ];
      expect(
        tasks.every(
          (row) =>
              !row.containsKey('available') && !row.containsKey('filePresent'),
        ),
        isTrue,
      );
      final merged = DownloadCenterResources.mergeVideos(tasks, resources);
      expect(merged, hasLength(5));
      expect(
        merged.every(
          (row) => row['available'] == true && row['filePresent'] == true,
        ),
        isTrue,
      );
      expect(sourceVideoDownloadGroups(merged, 'omo'), hasLength(5));
      final missing = DownloadCenterResources.mergeVideos(tasks, []);
      expect(sourceVideoDownloadGroups(missing, 'omo'), isEmpty);
    },
  );
  testWidgets(
    'source work and standalone cards share geometry and keep the work title above the episode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final entries = sourceVideoDownloadGroups([
        episode('1'),
        episode('2'),
        episode('3', work: null),
      ], 'omo');
      final work = entries.singleWhere((entry) => entry.work != null).work!;
      final single = entries.singleWhere((entry) => entry.work == null).item;
      var opens = 0, manages = 0, removals = 0;
      final openSwipe = ValueNotifier<String?>(null);
      addTearDown(openSwipe.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  SourceDownloadedWorkCard(
                    key: const ValueKey('work-card'),
                    work: work,
                    onOpen: () => opens++,
                    onManage: () => manages++,
                    onRemove: () => removals++,
                    openSwipe: openSwipe,
                  ),
                  SourceDownloadedEpisodeRow(
                    key: const ValueKey('single-card'),
                    item: single,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final key in ['work-card', 'single-card']) {
        final card = find.byKey(ValueKey(key));
        final cover = find.descendant(
          of: card,
          matching: find.byType(DownloadVideoTaskCover),
        );
        expect(tester.getSize(cover), const Size(88, 132));
        final title = find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('source-download-card.title')),
        );
        expect(tester.widget<Text>(title).data, 'Actual work');
      }
      await tester.tap(find.byKey(const ValueKey('work-card')));
      expect(opens, 1);
      await tester.longPress(find.byKey(const ValueKey('work-card')));
      expect(manages, 1);

      await tester.drag(
        find.byKey(const ValueKey('work-card')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('download-swipe.${work.key}.more')),
        findsNothing,
      );
      final details = find.byKey(
        ValueKey('download-swipe.${work.key}.details'),
      );
      expect(details.hitTestable(), findsOneWidget);
      expect(opens, 1);
      expect(removals, 0);

      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('work-card'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('download-row-more.${work.key}')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(ValueKey('download-action-sheet.${work.key}'));
      expect(
        find.descendant(of: sheet, matching: find.text(work.title)),
        findsOneWidget,
      );
      expect(find.descendant(of: sheet, matching: details), findsOneWidget);
      final manage = find.byKey(ValueKey('download-swipe.${work.key}.manage'));
      final remove = find.byKey(ValueKey('download-swipe.${work.key}.delete'));
      expect(find.descendant(of: sheet, matching: remove), findsOneWidget);
      expect(find.descendant(of: sheet, matching: manage), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('download-action-sheet-close.${work.key}')),
      );
      await tester.pumpAndSettle();
      expect(manages, 1);
      expect(removals, 0);

      await tester.tap(find.byKey(ValueKey('download-row-more.${single.key}')));
      await tester.pumpAndSettle();
      final singleSheet = find.byKey(
        ValueKey('download-action-sheet.${single.key}'),
      );
      expect(
        find.descendant(
          of: singleSheet,
          matching: find.byKey(ValueKey('download-swipe.${single.key}.info')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: singleSheet, matching: find.text(t.common.delete)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey('download-action-sheet-close.${single.key}')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final styleName in ['system', 'breeze']) {
    testWidgets('source downloads keep a separate More target in $styleName', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier(styleName);
      addTearDown(style.dispose);
      const source = 'source-download-actions';
      const title = 'A downloaded work at a narrow width';
      const quality = '720p';
      final page = Uri.parse('https://fixture.test/watch?v=42');
      final resourceId = VideoLocalResources.identity(source, page, quality);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await useIsolatedDownloadFixture();
        VideoLocalResources.invalidate();
        final file = await VideoLocalResources.file(resourceId);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
        );
        await VideoLocalResources.saved(
          resourceId: resourceId,
          bytes: 24,
          source: source,
          video: page,
          title: title,
          quality: quality,
          taskKey: 'source-download-actions-fixture',
        );
      });
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            theme: ThemeData(
              platform: styleName == 'system'
                  ? TargetPlatform.iOS
                  : TargetPlatform.android,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.45)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      unawaited(openSourceDownloadedVideos(context, source)),
                  child: const Text('Open downloads fixture'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open downloads fixture'));
      await tester.pump();

      final key = 'video:$resourceId';
      final row = find.byKey(ValueKey('source-download.$resourceId'));
      final more = find.byKey(ValueKey('download-row-more.$key'));
      final elapsed = Stopwatch()..start();
      while (more.evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(find.byType(SourceDownloadedVideosPage), findsOneWidget);
      expect(more.hitTestable(), findsOneWidget);
      final rowHeight = tester.getSize(row).height;
      final extent = CollectionToolbarMetrics.actionExtentOf(
        tester.element(more),
      );
      expect(tester.getSize(more), Size.square(extent));
      expect(tester.getRect(more).right, tester.getRect(row).right - 12);
      final label = find.descendant(of: row, matching: find.text(title));
      expect(tester.getRect(label).top, tester.getRect(more).top);
      expect(
        tester.getRect(label).right,
        lessThanOrEqualTo(tester.getRect(more).left),
      );

      await tester.drag(row, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('download-swipe.$key.more')), findsNothing);
      expect(
        find.byKey(ValueKey('download-swipe.$key.delete')).hitTestable(),
        findsOneWidget,
      );
      expect(more.hitTestable(), findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      final sheet = find.byKey(ValueKey('download-action-sheet.$key'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(t.download.exportVideo)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(t.common.delete)),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: sheet, matching: find.text(t.common.delete)),
      );
      await tester.pumpAndSettle();
      elapsed.reset();
      final confirmation = find.byType(AlertDialog);
      while (confirmation.evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(confirmation, findsOneWidget);
      await tester.tap(
        find.descendant(of: confirmation, matching: find.text(t.common.cancel)),
      );
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () async => (await VideoLocalResources.file(resourceId)).exists(),
        ),
        isTrue,
      );

      await tester.longPress(label);
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      expect(more, findsNothing);
      expect(tester.getSize(row).height, rowHeight);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final grouping = ValueVariant<bool>({true, false});
  testWidgets('source downloads close search before leaving the route', (
    tester,
  ) async {
    final grouped = grouping.currentValue!;
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
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: SourceDownloadedVideosPage(
            source: 'omo',
            groupDownloads: grouped,
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    final search = find.byKey(const ValueKey('source-downloads.search-toggle'));
    final elapsed = Stopwatch()..start();
    final ready = grouped
        ? find.byKey(const ValueKey('source-downloads.count'))
        : search;
    while (ready.evaluate().isEmpty &&
        elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ready, findsOneWidget);
    Future<void> pumpToolbar() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    await tester.tap(search);
    await pumpToolbar();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'Stored query');
    await pumpToolbar();
    await tester.tap(search);
    await pumpToolbar();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Stored query'), findsNothing);
    expect(find.text(t.bookshelf.download), findsOneWidget);
    expect(find.byKey(const ValueKey('source-downloads.more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('source-downloads.sort')),
      grouped ? findsOneWidget : findsNothing,
    );
    await tester.tap(search);
    await pumpToolbar();
    await tester.enterText(find.byType(TextField), 'No match');
    await tester.binding.handlePopRoute();
    await pumpToolbar();
    expect(find.byType(TextField), findsNothing);
    expect(find.text(t.bookshelf.download), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the download store's bounded read finish after the route is disposed.
    await tester.pump(const Duration(seconds: 8));
  }, variant: grouping);
}
