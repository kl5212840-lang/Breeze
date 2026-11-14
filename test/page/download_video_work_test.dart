import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/view/download_video_work_page.dart';
import 'package:zephyr/page/donwload_task/view/download_work_sections.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/source_downloaded_video_groups.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../ui_preview_helper.dart';

DownloadCenterItem _episode(
  String key, {
  String source = 'omo',
  String? canonical = 'work-42',
  String namespace = 'anime',
  int planned = 0,
  String quality = '720p',
  String status = 'saved',
  int? bytes = 24,
  int attempt = 1,
  int at = 100,
  String? phaseCode,
}) => DownloadCenterItem(
  key: 'video:$key',
  source: source,
  title: 'Original task $key',
  priority: status == 'saved' ? 3 : 0,
  at: at,
  video: {
    'key': key,
    'source': source,
    'title': 'Original task $key',
    'url': 'https://fixture.test/voddetail/42.html?line=A&episode=$key',
    'quality': quality,
    'resourceId': key,
    'status': status,
    'phaseCode': ?phaseCode,
    'attempt': attempt,
    'local': status == 'saved',
    'fileRemoved': false,
    'fileInvalid': false,
    if (bytes != null) 'bytes': bytes,
    if (status != 'saved') 'received': 0,
    if (canonical != null) 'publicWorkIdentity': canonical,
    'publicModuleNamespace': namespace,
    'publicPlannedEpisodes': planned,
    'publicWorkTitle': 'Actual source work title',
    'publicEpisodeLabel': 'Episode $key',
  },
);

DownloadCenterItem _verifiedEpisode(DownloadCenterItem item) {
  final row = item.video!;
  return DownloadCenterItem(
    key: item.key,
    source: item.source,
    title: item.title,
    priority: item.priority,
    at: item.at,
    video: {
      ...row,
      'resourceId': VideoLocalResources.identity(
        item.source,
        Uri.parse(row['url'] as String),
        row['quality'] as String,
      ),
      'available': true,
      'filePresent': true,
    },
  );
}

void main() {
  testWidgets('long offline work pages video episodes with stable selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final items = [
      for (var index = 1; index <= 205; index++)
        _episode(index.toString().padLeft(3, '0')),
    ];
    var snapshot = items;
    final work = groupVideoDownloadItems(items, universe: items).single.work!;
    final style = ValueNotifier('system');
    addTearDown(style.dispose);
    String? played;
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: () async => snapshot,
            matches: (_) => true,
            onRemoveEpisodes: (_, selected) async {
              expect(selected.map((item) => item.key), ['video:201']);
              snapshot = items.take(200).toList();
              VideoLocalResources.changes.value++;
            },
            rowBuilder: (context, item, _, resumeAt) {
              final scope = DownloadEpisodeRowScope.of(context)!;
              return DownloadEpisodePlayRow(
                title: item.title,
                variant: '720p',
                bytes: item.sizeBytes,
                resumeAt: resumeAt,
                selecting: scope.selecting,
                selected: scope.selected,
                onPlay: scope.selecting
                    ? scope.onSelect
                    : () => played = item.key,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final resumeCard = find.byKey(
      const ValueKey('video-work-continue-watching'),
    );
    expect(resumeCard, findsNothing);
    Finder row(int index) =>
        find.text('Original task ${index.toString().padLeft(3, '0')}');
    final lastRange = find.widgetWithText(ChoiceChip, '201-205');
    expect(lastRange, findsOneWidget);
    expect(row(201), findsNothing);
    await tester.ensureVisible(lastRange);
    await tester.pump();
    await tester.tap(lastRange);
    await tester.pumpAndSettle();
    expect(row(1), findsNothing);
    await tester.ensureVisible(row(201));
    await tester.pump();
    await tester.tap(row(201));
    expect(played, 'video:201');
    await tester.tap(find.byKey(const ValueKey('download-episodes-manage')));
    await tester.pumpAndSettle();
    expect(resumeCard, findsNothing);
    await tester.tap(row(201));
    await tester.pumpAndSettle();
    expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);

    snapshot = items.skip(1).toList();
    VideoLocalResources.changes.value++;
    await tester.pumpAndSettle();
    final savedList = find.byKey(
      PageStorageKey('video-download-work.${work.key}.saved'),
    );
    final vertical = tester.state<ScrollableState>(
      find.descendant(
        of: savedList,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    vertical.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '176-200'))
          .selected,
      isTrue,
    );
    expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
    snapshot = items;
    VideoLocalResources.changes.value++;
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(lastRange).selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('download-episodes-delete')));
    await tester.pumpAndSettle();
    expect(lastRange, findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '176-200'))
          .selected,
      isTrue,
    );
    expect(row(176), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved ranges and active tasks keep independent scroll positions',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final admission = DownloadAdmission.instance;
      await tester.runAsync(
        () =>
            admission.setQueuePaused(true).timeout(const Duration(seconds: 3)),
      );
      addTearDown(() => admission.setQueuePaused(false));
      var items = [
        for (var index = 1; index <= 50; index++)
          _episode(
            index.toString().padLeft(3, '0'),
            status: switch (index) {
              50 => 'downloading',
              49 => 'queued',
              48 => 'paused',
              47 => 'failed',
              46 || 45 => 'queued',
              44 => 'cancelled',
              _ => 'saved',
            },
            at: index == 46 ? 200 : 100,
            phaseCode: index == 45 ? 'waitingRetry' : null,
          ),
      ];
      final work = groupVideoDownloadItems(items, universe: items).single.work!;
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: () async => items,
            matches: (_) => true,
            rowBuilder: (_, item, _, _) =>
                SizedBox(height: 36, child: Text(item.title)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '1-25'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '26-43'), findsOneWidget);
      final active = find.text('Original task 050');
      final queued = find.text('Original task 049');
      final paused = find.text('Original task 048');
      final saved = find.text('Original task 001');
      expect(saved, findsOneWidget);
      expect(active, findsNothing);
      final scrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.drag(scrollable, const Offset(0, -280));
      await tester.pumpAndSettle();
      final savedOffset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(savedOffset, greaterThan(0));
      await tester.tap(find.text('Downloading'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '1-25'), findsNothing);
      expect(saved, findsNothing);
      expect(
        tester.getTopLeft(active).dy,
        lessThan(tester.getTopLeft(queued).dy),
      );
      expect(
        tester.getTopLeft(queued).dy,
        lessThan(tester.getTopLeft(paused).dy),
      );
      final activeOrder = ['050', '047', '046', '049', '045', '048', '044'];
      final offsets = [
        for (final key in activeOrder)
          tester.getTopLeft(find.text('Original task $key')).dy,
      ];
      expect(offsets, orderedEquals([...offsets]..sort()));
      expect(offsets.toSet(), hasLength(activeOrder.length));
      final queuePaused = find.byKey(const ValueKey('download-queue-paused'));
      expect(queuePaused, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('download-queue-resume')));
      for (var i = 0; i < 50 && admission.queuePaused; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(queuePaused, findsNothing);
      expect(admission.queuePaused, isFalse);
      await tester.tap(find.text('Downloaded'));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        savedOffset,
      );
      await tester.tap(find.text('Downloading'));
      await tester.pumpAndSettle();
      items = [
        ...items.take(43),
        for (var index = 44; index <= 50; index++) _episode('0$index'),
      ];
      VideoLocalResources.changes.value++;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DownloadWorkSectionControl>(
              find.byType(DownloadWorkSectionControl),
            )
            .selected,
        DownloadWorkPane.active,
      );
      expect(active, findsNothing);
      final viewSaved = find.byKey(const ValueKey('video-work-view-saved'));
      expect(viewSaved, findsOneWidget);
      await tester.tap(viewSaved);
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '26-50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'only declared canonical relationships group; source/module isolate equal IDs',
    () {
      final rows = [
        _episode('1'),
        _episode('2'),
        _episode('3', source: 'other'),
        _episode('4', namespace: 'movie'),
        _episode('5', canonical: null),
        _episode('6', canonical: null),
      ];
      final display = groupVideoDownloadItems(rows, universe: rows);
      expect(display, hasLength(5));
      expect(display.first.work!.episodes.map((item) => item.key), [
        'video:1',
        'video:2',
      ]);
      expect(display.first.work!.title, 'Actual source work title');
      expect(display.where((item) => item.work != null), hasLength(1));
      expect(
        display.last.item.key,
        'video:6',
        reason:
            'Hanime/title/author similarities never group unknown identities',
      );
    },
  );
  test(
    'explicit series groups one episode; quality copies cannot invent a series',
    () {
      final series = [_episode('1', planned: 12)];
      expect(
        groupVideoDownloadItems(series, universe: series).single.work,
        isNotNull,
      );
      final a = _episode('1'),
          b = DownloadCenterItem(
            key: 'video:copy',
            source: a.source,
            title: a.title,
            priority: 3,
            at: 100,
            video: {...a.video!, 'key': 'copy', 'quality': '1080p'},
          );
      expect(
        groupVideoDownloadItems(
          [a, b],
          universe: [a, b],
        ).where((item) => item.work != null),
        isEmpty,
      );
    },
  );
  test(
    'filter leaves first and show only matching episode identities inside their known work',
    () {
      final all = [_episode('1'), _episode('2')];
      final filtered = groupVideoDownloadItems([
        all.last,
      ], universe: all).single.work!;
      expect(filtered.totalEpisodes, 2);
      expect(filtered.episodes.single.key, 'video:2');
      expect(
        filtered.identity.contains(_episode('3', namespace: 'movie')),
        isFalse,
      );
      expect(filtered.episodes.single.video!['attempt'], 1);
    },
  );
  test(
    'aggregate progress and bytes use actual files and never invent unknown totals',
    () {
      final complete = _episode('1'),
          pending = _episode('2', status: 'preparing', bytes: null);
      final work = DownloadVideoWork(
        identity: downloadVideoWorkIdentity(complete)!,
        episodes: [complete, pending],
        totalEpisodes: 2,
      );
      expect(work.completed, 1);
      expect(work.knownBytes, 24);
      expect(work.progress, isNull);
      final removed = DownloadCenterItem(
        key: 'video:removed',
        source: complete.source,
        title: complete.title,
        priority: 3,
        at: 100,
        video: {...complete.video!, 'fileRemoved': true, 'received': 24},
      );
      final missing = DownloadVideoWork(
        identity: work.identity,
        episodes: [removed],
        totalEpisodes: 1,
      );
      expect(missing.completed, 0);
      expect(missing.knownBytes, isNull);
      expect(missing.progress, isNull);
    },
  );
  testWidgets(
    'a live HLS work card shows actual cached bytes and its media percentage without a byte total',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final episode = _episode(
        '1',
        planned: 12,
        status: 'downloading',
        bytes: null,
      );
      final work = groupVideoDownloadItems(
        [episode],
        universe: [episode],
      ).single.work!;
      final progress = ValueNotifier<Map<String, dynamic>>({
        ...episode.video!,
        'format': 'hls',
        'received': 2048,
        'receivedSource': 'package',
        'mediaProgress': .02,
      });
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  DownloadVideoWorkCard(
                    work: work,
                    sourceTitle: 'Omo',
                    progress: {'1': progress},
                    onOpen: () {},
                    onManage: () {},
                    onRemove: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2%'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((widget) => widget.data?.contains('KB') == true)
            .map((widget) => widget.data)
            .toList(),
        ['2.0 KB'],
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .02,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      progress.value = {
        ...progress.value,
        'received': 4096,
        'mediaProgress': .25,
      };
      await tester.pump();
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('4.1 KB'), findsOneWidget);
      expect(progress.value['total'], isNull);
      progress.value = {
        ...progress.value,
        'networkBytes': 1024,
        'networkTotal': 8192,
      };
      await tester.pump();
      expect(find.text('1.0 KB / 8.2 KB'), findsOneWidget);
      expect(find.text('/ 8.2 KB'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .125,
      );
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((widget) => widget.data?.contains('KB') == true)
            .map((widget) => widget.data)
            .toList(),
        ['1.0 KB / 8.2 KB'],
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mixed finished and failed work offers recovery without a false 50 percent transfer',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final rows = [
        _episode('1'),
        _episode('2', status: 'failed', bytes: null),
      ];
      final work = DownloadVideoWork(
        identity: downloadVideoWorkIdentity(rows.first)!,
        episodes: rows,
        totalEpisodes: 2,
      );
      expect(work.completed, 1);
      expect(work.failed, 1);
      expect(work.transferring, isFalse);
      expect(work.progress, isNull);
      DownloadVideoWork? retried;
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  DownloadVideoWorkCard(
                    work: work,
                    sourceTitle: 'Omo',
                    onOpen: () {},
                    onManage: () {},
                    onRemove: (_) {},
                    onRetryFailed: (value) => retried = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final summary = find.byKey(ValueKey('download-work-summary.${work.key}'));
      expect(summary, findsOneWidget);
      expect(
        find.descendant(
          of: summary,
          matching: find.text('1 of 2 downloads complete'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.byIcon(Icons.video_library_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text(t.download.workEpisodeCount(count: 2)), findsNothing);
      expect(
        find.byKey(ValueKey('download-work-menu.${work.key}')),
        findsNothing,
      );
      expect(find.text('${t.download.failed} 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('50%'), findsNothing);
      await tester.tap(find.byKey(ValueKey('download-work-retry.${work.key}')));
      expect(retried!.failedEpisodes.map((item) => item.video!['key']), ['2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed work keeps its geometry throughout selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    final rows = [
      _episode('1', status: 'failed', bytes: null),
      _episode('2', status: 'failed', bytes: null),
    ];
    final work = DownloadVideoWork(
      identity: downloadVideoWorkIdentity(rows.first)!,
      episodes: rows,
      totalEpisodes: 2,
    );
    Future<void> mount({required bool managing, bool selected = false}) =>
        tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: Scaffold(
                body: DownloadVideoWorkCard(
                  work: work,
                  sourceTitle: 'Omo',
                  onOpen: () {},
                  onManage: () {},
                  onRemove: (_) {},
                  onRetryFailed: (_) {},
                  managing: managing,
                  selected: selected,
                ),
              ),
            ),
          ),
        );
    final card = find.byKey(ValueKey('download-work.${work.key}'));
    final title = find.text(work.title);
    final retry = find.byKey(ValueKey('download-work-retry.${work.key}'));
    await mount(managing: false);
    final cardBefore = tester.getRect(card);
    final titleBefore = tester.getRect(title);
    expect(retry.hitTestable(), findsOneWidget);
    for (final selected in [false, true, false]) {
      await mount(managing: true, selected: selected);
      expect(tester.getRect(card), cardBefore);
      expect(tester.getRect(title), titleBefore);
      expect(retry.hitTestable(), findsNothing);
    }
  });

  testWidgets('work actions follow current attempts and the filtered scope', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final episode = _episode('1', status: 'failed', attempt: 2);
    final work = DownloadVideoWork(
      identity: downloadVideoWorkIdentity(episode)!,
      episodes: [episode],
      totalEpisodes: 3,
    );
    final openRow = ValueNotifier<String?>(null);
    final progress = ValueNotifier<Map<String, dynamic>>({
      'attempt': 1,
      'status': 'downloading',
    });
    addTearDown(openRow.dispose);
    addTearDown(progress.dispose);
    var removals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DownloadVideoWorkCard(
                work: work,
                sourceTitle: 'Omo',
                onOpen: () {},
                onManage: () {},
                onRemove: (_) => removals++,
                onRetryFailed: (_) {},
                openSwipe: openRow,
                progress: {'1': progress},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final delete = find.byKey(ValueKey('download-swipe.${work.key}.delete'));
    expect(find.text('0 of 1 downloads complete'), findsOneWidget);
    expect(find.text('1 of 3 downloads match'), findsOneWidget);
    await tester.drag(find.text(work.title), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(delete.hitTestable(), findsOneWidget);
    final caption = find.descendant(
      of: delete,
      matching: find.text(t.common.delete),
    );
    expect(caption, findsOneWidget);
    expect(tester.widget<Text>(caption).semanticsLabel, 'Delete this download');
    expect(removals, 0);

    await tester.tap(delete);
    await tester.pump(const Duration(milliseconds: 24));
    progress.value = {'attempt': 3, 'status': 'preparing'};
    await tester.pumpAndSettle();
    expect(delete, findsNothing);
    expect(openRow.value, isNull);
    expect(removals, 0);
  });

  for (final interface in ['breeze', 'system']) {
    testWidgets(
      'single resume card and episode rows fit large text in $interface',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await loadUiPreviewFonts();
        const previewKey = ValueKey('download.video.work.preview');
        final style = ValueNotifier(interface);
        addTearDown(style.dispose);
        final first = _verifiedEpisode(_episode('1', bytes: 280 * 1024 * 1024));
        final second = _verifiedEpisode(
          _episode('2', bytes: 308 * 1024 * 1024),
        );
        final unknown = _episode('3', bytes: null);
        final items = [first, second, unknown];
        final work = DownloadVideoWork(
          identity: downloadVideoWorkIdentity(first)!,
          episodes: items,
          totalEpisodes: items.length,
        );
        for (final (source, item, completed) in [
          ('omo', first, false),
          ('other', second, false),
          ('omo', second, true),
        ]) {
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: Uri.parse(item.video!['url'] as String),
              title: item.title,
              position: const Duration(minutes: 7, seconds: 29),
              duration: const Duration(minutes: 20),
              updatedAt: DateTime.utc(2026, 11, 10, completed ? 11 : 12),
              completed: completed,
            ),
          );
        }
        String? played;
        final colors = BreezeThemeColors.fromSeed(
          const Color(0xff009688),
          interface == 'breeze' ? Brightness.dark : Brightness.light,
        );
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: colors,
                scaffoldBackgroundColor: colors.surface,
                fontFamily: uiPreviewDirectory == null
                    ? null
                    : 'AccountPreview',
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: previewKey,
                child: DownloadVideoWorkPage(
                  initial: work,
                  readItems: () async => items,
                  matches: (_) => true,
                  onContinueWatching: (_, item) async => played = item.key,
                  onRemoveEpisodes: (_, _) async {},
                  rowBuilder: (_, item, _, resumeAt) => DownloadEpisodePlayRow(
                    title: item.title,
                    variant: '720p',
                    bytes: item.sizeBytes,
                    resumeAt: resumeAt,
                    onPlay: () => played = item.key,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(work.title), findsOneWidget);
        final card = find.byKey(const ValueKey('video-work-continue-watching'));
        expect(card, findsOneWidget);
        expect(tester.getSize(card).height, greaterThanOrEqualTo(44));
        expect(find.text(t.videoLibrary.continueWatching), findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.textContaining('7:29')),
          findsOneWidget,
        );
        await writeUiPreview(
          tester,
          previewKey,
          'video-resume-$interface-large',
        );
        final firstRow = find.ancestor(
          of: find.text(first.title),
          matching: find.byType(DownloadEpisodePlayRow),
        );
        final manage = find.byKey(const ValueKey('download-episodes-manage'));
        final cardRect = tester.getRect(card);
        final firstRowRect = tester.getRect(firstRow);
        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, t.common.done), findsOneWidget);
        expect(tester.getRect(card), cardRect);
        expect(tester.getRect(firstRow), firstRowRect);
        expect(tester.widget<InkWell>(card).onTap, isNull);
        await tester.tapAt(cardRect.center);
        await tester.pump();
        expect(played, isNull);

        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(tester.getRect(card), cardRect);
        expect(tester.getRect(firstRow), firstRowRect);
        await tester.tap(card);
        await tester.pump();
        expect(played, first.key);
        expect(find.text(t.download.openEpisodePlayback), findsNothing);
        final firstSize = find.descendant(
          of: firstRow,
          matching: find.text(downloadByteAmount(first.sizeBytes!)),
        );
        expect(firstSize, findsOneWidget);
        final trailingEdge = tester.getRect(firstSize).right;
        final secondSize = find.text(downloadByteAmount(second.sizeBytes!));
        final scrollable = find.descendant(
          of: find.byKey(
            PageStorageKey('video-download-work.${work.key}.saved'),
          ),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          secondSize,
          100,
          scrollable: scrollable,
        );
        expect(trailingEdge, tester.getRect(secondSize).right);
        await tester.ensureVisible(firstSize);
        await tester.pump();
        await tester.tap(firstSize);
        expect(played, first.key);
        await tester.scrollUntilVisible(
          find.text(second.title),
          100,
          scrollable: scrollable,
        );
        await tester.pump();
        expect(find.text('Watched'), findsOneWidget);
        await tester.tap(find.text(second.title));
        expect(played, second.key);
        final unknownTitle = find.text(unknown.title);
        await tester.scrollUntilVisible(
          unknownTitle,
          120,
          scrollable: scrollable,
        );
        final unknownRow = find.ancestor(
          of: unknownTitle,
          matching: find.byType(DownloadEpisodePlayRow),
        );
        expect(unknownRow, findsOneWidget);
        expect(
          find.descendant(of: unknownRow, matching: find.byType(Text)),
          findsNWidgets(2), // Only the title and the variant are known.
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'source work tray consumes an outside tap and long press manages the exact version',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final first = _episode('1');
      final next = _episode('2');
      final queued = _episode('3', status: 'preparing');
      var items = [first, next, queued];
      final work = DownloadVideoWork(
        identity: downloadVideoWorkIdentity(first)!,
        episodes: items,
        totalEpisodes: items.length,
      );
      final removed = <DownloadCenterItem>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: () async => items,
            matches: (_) => true,
            onRemoveEpisodes: (_, chosen) async => removed.addAll(chosen),
            rowBuilder: (_, item, showFormat, resume) =>
                SourceDownloadedEpisodeRow(
                  item: item,
                  episodeContext: true,
                  showFileFormat: showFormat,
                  resumeAt: resume,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('source-download.1'));
      final manage = find.byKey(const ValueKey('download-episodes-manage'));
      final delete = find.byKey(const ValueKey('download-episodes-delete'));
      final tray = find.byKey(const ValueKey('download-swipe.video:1.delete'));
      final normalHeight = tester.getSize(row).height;
      await tester.drag(row, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(tray.hitTestable(), findsOneWidget);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(tray, findsNothing);
      expect(delete, findsNothing);
      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(tray, findsNothing);
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      expect(tester.getSize(row).height, normalHeight);
      await tester.tap(find.text('Downloading'));
      await tester.pumpAndSettle();
      expect(delete, findsNothing);
      expect(tester.widget<TextButton>(manage).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('source-download-cancel.3')),
        findsOneWidget,
      );
      await tester.tap(find.text('Downloaded'));
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      items = [_episode('1', attempt: 2), next, queued];
      VideoLocalResources.changes.value++;
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.selectedCount(count: 0)), findsOneWidget);
      expect(tester.widget<TextButton>(delete).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey('download-episodes-select-all')),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(removed.map((item) => item.key), ['video:1', 'video:2']);
      expect(removed.first.video!['attempt'], 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a source episode tray at zero releases the first outside tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final items = [_episode('1'), _episode('2')];
      final work = groupVideoDownloadItems(items, universe: items).single.work!;
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: () async => items,
            matches: (_) => true,
            onRemoveEpisodes: (_, _) async {},
            rowBuilder: (_, item, showFormat, resume) =>
                SourceDownloadedEpisodeRow(
                  item: item,
                  episodeContext: true,
                  showFileFormat: showFormat,
                  resumeAt: resume,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('source-download.1'));
      final tray = find.byKey(const ValueKey('download-swipe.video:1.delete'));
      final manage = find.byKey(const ValueKey('download-episodes-manage'));
      await tester.drag(row, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(tray.hitTestable(), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      expect(tray, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(find.text(t.common.done), findsOneWidget);
    },
  );

  testWidgets(
    'plugin episode bytes and resume stay clear of the actions menu',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final item = _episode('1', bytes: 280 * 1024 * 1024);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SourceDownloadedEpisodeRow(
                  item: item,
                  episodeContext: true,
                  resumeAt: const Duration(minutes: 7, seconds: 29),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final play = find.byType(DownloadEpisodePlayRow);
      final size = find.text(downloadByteAmount(item.sizeBytes!));
      final menu = find.byTooltip(t.common.more);
      expect(find.textContaining('7:29'), findsOneWidget);
      expect(size, findsOneWidget);
      expect(menu, findsOneWidget);
      expect(tester.getRect(size).overlaps(tester.getRect(menu)), isFalse);
      expect(tester.getRect(play).overlaps(tester.getRect(menu)), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('work resume uses the complete entry inventory before refresh', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final first = _verifiedEpisode(_episode('1'));
    final second = _verifiedEpisode(_episode('2'));
    final otherVersion = _verifiedEpisode(_episode('2', quality: '1080p'));
    final visible = [first, second];
    final inventory = [...visible, otherVersion];
    final work = groupVideoDownloadItems(
      visible,
      universe: inventory,
    ).single.work!;
    final refresh = Completer<List<DownloadCenterItem>>();
    Future<void> write(DownloadCenterItem item, DateTime at) =>
        VideoWatchHistory.record(
          item.source,
          VideoWatchRecord(
            watchUrl: Uri.parse(item.video!['url'] as String),
            title: item.title,
            position: const Duration(seconds: 23),
            duration: const Duration(minutes: 2),
            updatedAt: at,
            completed: false,
          ),
        );
    await write(first, DateTime.utc(2026, 1));
    final initialHistory = readDownloadVideoWorkHistory(first.source);
    final readyHistory = await initialHistory;
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadVideoWorkPage(
          initial: work,
          initialHistory: initialHistory,
          readyHistory: readyHistory,
          readItems: () => refresh.future,
          matches: (item) => item.video!['quality'] == '720p',
          onContinueWatching: (_, _) async {},
          rowBuilder: (_, item, _, _) => Text(item.title),
        ),
      ),
    );
    final card = find.byKey(const ValueKey('video-work-continue-watching'));
    expect(refresh.isCompleted, isFalse);
    expect(card, findsOneWidget);
    expect(find.textContaining('0:23'), findsOneWidget);

    await write(second, DateTime.utc(2026, 2));
    await tester.pumpAndSettle();
    expect(refresh.isCompleted, isFalse);
    expect(card, findsNothing);
    refresh.complete(inventory);
    await tester.pumpAndSettle();
    expect(card, findsNothing);
  });

  testWidgets(
    'work pull awaits the queued file verification and reports its result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final episode = _episode('1');
      final initial = Completer<List<DownloadCenterItem>>();
      final verified = Completer<List<DownloadCenterItem>>();
      final latest = Completer<List<DownloadCenterItem>>();
      var checks = 0, regularReads = 0;
      final work = DownloadVideoWork(
        identity: downloadVideoWorkIdentity(episode)!,
        episodes: [episode],
        totalEpisodes: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadVideoWorkPage(
            initial: work,
            readItems: () =>
                ++regularReads == 1 ? initial.future : latest.future,
            refreshItems: () {
              checks++;
              return verified.future;
            },
            matches: (_) => true,
            rowBuilder: (_, item, _, _) => Text(item.title),
          ),
        ),
      );
      final indicator = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      var finished = false;
      final refresh = indicator.show().then((_) => finished = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, isFalse);
      expect(checks, 0);
      expect(find.text(episode.title), findsOneWidget);

      initial.complete([episode]);
      await tester.pump();
      expect(checks, 1);
      expect(finished, isFalse);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.text(t.common.refreshUnchanged), findsNothing);

      // A storage notification invalidates the first verification before
      // its rows can commit. The user still waits for the queued projection.
      VideoLocalResources.invalidate();
      verified.complete([episode]);
      await tester.pump();
      expect(regularReads, 2);
      expect(finished, isFalse);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      latest.complete([episode]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text(t.common.refreshUnchanged), findsOneWidget);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('waiting, paused and cancelled work never claim an active transfer', () {
    for (final status in ['preparing', 'cancelled', 'paused']) {
      final item = _episode('2', status: status, bytes: null);
      final work = DownloadVideoWork(
        identity: downloadVideoWorkIdentity(item)!,
        episodes: [item],
        totalEpisodes: 1,
      );
      expect(work.transferring, isFalse);
      expect(work.progress, isNull);
      expect(downloadVideoWorkStateLabels(work), isNotEmpty);
    }
  });

  for (final width in [320.0, 440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'work entry and filtered episode route preserve identity $width/$scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier('breeze');
          addTearDown(preference.dispose);
          final privacy = CollectionCoverPrivacyController.instance,
              before = CollectionCoverPrivacyController.instance.state.value;
          privacy.state.value = const CollectionCoverPrivacySettings(
            enabled: false,
            ready: true,
          );
          addTearDown(() => privacy.state.value = before);
          var rows = [_episode('1'), _episode('2')];
          final work = groupVideoDownloadItems(
            rows,
            universe: rows,
          ).single.work!;
          String? pressed;
          int? attempt;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  bottomNavigationBar: const SizedBox(
                    height: 64,
                    child: Text('MAIN NAV'),
                  ),
                  body: Builder(
                    builder: (context) => ListView(
                      children: [
                        DownloadVideoWorkCard(
                          work: work,
                          sourceTitle: 'Actual source',
                          onManage: () {},
                          onRemove: (_) {},
                          onOpen: () =>
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => DownloadVideoWorkPage(
                                    initial: work,
                                    sourceTitle: scale == 1
                                        ? 'Actual source'
                                        : null,
                                    readItems: () async => rows,
                                    matches: (item) => item.key == 'video:2',
                                    rowBuilder: (context, item, _, _) =>
                                        TextButton(
                                          key: ValueKey(
                                            'episode-action.${item.key}',
                                          ),
                                          child: Text(item.title),
                                          onPressed: () {
                                            pressed = item.key;
                                            attempt =
                                                item.video!['attempt'] as int;
                                          },
                                        ),
                                  ),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('video-cover-marker')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(ValueKey('download-work.${work.key}')));
          await tester.pumpAndSettle();
          expect(find.text('MAIN NAV').hitTestable(), findsNothing);
          expect(find.text(work.identity.source), findsNothing);
          expect(
            find.text('Actual source'),
            scale == 1 ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('episode-action.video:1')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('episode-action.video:2')),
          );
          expect(pressed, 'video:2');
          expect(attempt, 1);
          rows = [
            _episode('2', attempt: 2),
            _episode('foreign', namespace: 'movie'),
          ];
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('episode-action.video:2')),
          );
          expect(
            attempt,
            2,
            reason:
                'episode operations receive the new attempt, never a representative group row',
          );
          await tester.tap(find.byType(SourceBackButton));
          await tester.pumpAndSettle();
          expect(find.text('MAIN NAV').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
        }),
      );
    }
  }

  testWidgets(
    'UIKit work back exits management before returning to downloads',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodChannel? backChannel;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final bytes = args['params'] as Uint8List?;
          final params = const StandardMessageCodec().decodeMessage(
            bytes == null ? null : ByteData.sublistView(bytes),
          );
          if (args['viewType'] == 'breeze.video.control' &&
              params is Map &&
              params['tooltip'] == t.common.back) {
            backChannel = MethodChannel('breeze.video.control.${args['id']}');
            messenger.setMockMethodCallHandler(backChannel!, (_) async => null);
          }
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (backChannel != null) {
          messenger.setMockMethodCallHandler(backChannel!, null);
        }
      });
      final rows = [_episode('1'), _episode('2')];
      final work = groupVideoDownloadItems(rows, universe: rows).single.work!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
                      videoPageRoute<void>(
                        settings: const RouteSettings(
                          name: 'breeze.download.video-work',
                        ),
                        matchAutoRouteTransition: true,
                        builder: (_) => DownloadVideoWorkPage(
                          initial: work,
                          readItems: () async => rows,
                          matches: (_) => true,
                          onRemoveEpisodes: (_, _) async {},
                          rowBuilder: (_, item, _, _) => Text(item.title),
                        ),
                      ),
                    ),
                child: const Text('Download list'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Download list'));
      await tester.pumpAndSettle();
      expect(backChannel, isNotNull);
      final manage = find.byKey(const ValueKey('download-episodes-manage'));
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: manage, matching: find.text(t.common.done)),
        findsOneWidget,
      );

      Future<void> back() async {
        await messenger.handlePlatformMessage(
          backChannel!.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('press'),
          ),
          null,
        );
        await tester.pumpAndSettle();
      }

      await back();
      expect(find.byType(DownloadVideoWorkPage), findsOneWidget);
      expect(
        find.descendant(of: manage, matching: find.text(t.bookshelf.manage)),
        findsOneWidget,
      );
      await back();
      expect(find.byType(DownloadVideoWorkPage), findsNothing);
      expect(find.text('Download list'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
