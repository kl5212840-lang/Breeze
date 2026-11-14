import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/donwload_task/view/download_video_work_page.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';
import '../download_fixture.dart';

Future<Object?> emptyHlsIndex(MethodCall call) async {
  if (call.method == 'list') return <Object?>[];
  throw MissingPluginException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await DownloadAdmission.instance.initializeQueueState();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VideoHlsAssets.channel, emptyHlsIndex);
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    expect(await DownloadCenterResources.readVideos(), isEmpty);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(VideoHlsAssets.channel, null);
  });

  Future<void> settleHost(WidgetTester tester) async {
    // Probe the same full aggregation as the mounted page: readTasks alone
    // finishes before DownloadCenterResources' second managed-resource read.
    var completed = false;
    Object? failure;
    DownloadCenterResources.readVideos().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        completed = true;
      },
    );
    // The storage queue may already contain a future created in FakeAsync.
    // Never await it while withholding that clock's microtask pump.
    final elapsed = Stopwatch()..start();
    while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(completed, isTrue, reason: 'Actual managed-index read must finish.');
    expect(failure, isNull);
    // Queued transfers intentionally keep their status indicator animated.
    // Settle navigation after real I/O without waiting for that animation to end.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> runHost(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      // Dispose watches/listeners while this test still pumps their own zone.
      // Drain the complete resource read after unmount so the next test cannot
      // inherit a filesystem/queue continuation owned by a dead FakeAsync zone.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await settleHost(tester);
    }
  }

  Future<T> finishOperation<T>(
    WidgetTester tester,
    Future<T> Function() operation, {
    required String stage,
  }) async {
    var completed = false;
    late T value;
    Object? failure;
    StackTrace? failureStack;
    // Start in the test zone, then drive BOTH its continuations and actual IO.
    // runAsync(() => operation()) can wait forever when operation joins a
    // storage/resource future which the mounted page created in FakeAsync.
    Future<T>.sync(operation).then<void>(
      (result) {
        value = result;
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    );
    final elapsed = Stopwatch()..start();
    while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(completed, isTrue, reason: 'Real operation must finish: $stage');
    if (failure case final error?) {
      Error.throwWithStackTrace(error, failureStack!);
    }
    return value;
  }

  for (final styleName in ['system', 'breeze']) {
    testWidgets(
      'episode body is inert until playable and recovery actions are explicit $styleName',
      (tester) => runHost(tester, () async {
        const source = 'offline-video-fixture';
        final detail = Uri.parse('https://fixture.test/voddetail/2316.html');
        final watch = detail.replace(
          queryParameters: {'line': 'main', 'episode': '1'},
        );
        late String task;
        await finishOperation(tester, () async {
          await VideoDownloadedDetails.captureItem(
            source,
            ApiVideoItem(
              id: '2316',
              title: 'Actual queued series',
              detailUrl: detail,
              plannedEpisodes: 12,
              lines: [
                ApiVideoLine(
                  id: 'main',
                  label: 'Main',
                  episodes: [
                    ApiVideoEpisode(
                      id: '1',
                      title: 'Episode 1',
                      url: null,
                      watchUrl: watch,
                    ),
                  ],
                ),
              ],
            ),
            [
              NativeVideoCard(
                title: 'Episode 1',
                episodeLabel: 'Episode 1',
                watchUrl: watch,
                coverUrl: null,
              ),
            ],
          );
          task = await VideoExportRecords.beginTransfer(
            source: source,
            video: watch,
            title: 'Episode 1',
            quality: '720p',
            format: 'hls',
            queued: true,
          );
        }, stage: 'capture public work and persist queued episode');
        final notices = <ToastEvent>[];
        final subscription = eventBus.on<ToastEvent>().listen(notices.add);
        final style = ValueNotifier(styleName);
        addTearDown(style.dispose);
        try {
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: const MaterialApp(home: DownloadTaskPage()),
            ),
          );
          await settleHost(tester);
          expect(find.byType(DownloadVideoWorkCard), findsOneWidget);
          final workCard = find.byType(DownloadVideoWorkCard);
          await tester.drag(workCard, const Offset(-115, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          expect(find.text(t.common.detail).hitTestable(), findsOneWidget);
          // Close the revealed actions before opening the downloaded group.
          await tester.tap(workCard);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          await tester.tap(workCard);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 450));
          expect(
            find.byType(DownloadVideoWorkPage),
            findsOneWidget,
            reason:
                'An unfinished work may still open its local episode management page',
          );
          final identity = VideoLocalResources.identity(
            source,
            watch,
            'hls|720p',
          );
          final episodeBody = find.byKey(
            ValueKey('download-title.video:$identity'),
          );
          final card = find.byKey(ValueKey('download-card.video:$identity'));
          final cardHeight = tester.getSize(card).height;
          for (final status in ['preparing', 'downloading', 'saving']) {
            await finishOperation(
              tester,
              () => VideoExportRecords.updateTransfer(
                task,
                received: null,
                status: status,
              ),
              stage: 'persist $status',
            );
            await settleHost(tester);
            expect(episodeBody, findsOneWidget);
            expect(tester.getSize(card).height, cardHeight);
            await tester.tap(episodeBody);
            await tester.pump();
            expect(notices, isEmpty);
            expect(find.byType(DownloadVideoWorkPage), findsOneWidget);
            expect(find.byType(NativeVideoPage), findsNothing);
            final rows = await finishOperation(
              tester,
              VideoExportRecords.readTaskSnapshot,
              stage: 'read durable $status',
            );
            expect(rows.single['status'], status);
          }
          expect(notices, isEmpty);
          for (final status in [
            'failed',
            'interrupted',
            'unavailable',
            'unsupported',
            'routeUnavailable',
            'busy',
          ]) {
            await finishOperation(
              tester,
              () => VideoExportRecords.updateTransfer(
                task,
                received: null,
                status: status,
                failureReason: 'network',
              ),
              stage: 'persist failure $status',
            );
            await settleHost(tester);
            final finder = find.byKey(
              ValueKey('download-status.video:$identity'),
            );
            expect(finder, findsOneWidget);
            final text = tester.widget<Text>(finder);
            expect(
              text.style?.color,
              Theme.of(tester.element(finder)).colorScheme.error,
            );
            expect(text.data, isNot(t.common.unknown));
            if (status == 'failed') {
              expect(text.data, contains('网络'));
            }
          }
          expect(tester.getSize(card).height, cardHeight);
          expect(find.text(t.download.retryEpisodeDownload), findsOneWidget);
          await tester.tap(episodeBody);
          await tester.pump();
          expect(
            (await finishOperation(
              tester,
              VideoExportRecords.readTaskSnapshot,
              stage: 'a tap on a failed row leaves its attempt intact',
            )).single['status'],
            'busy',
          );
          final titleStart = tester.getTopLeft(episodeBody).dx;
          await finishOperation(
            tester,
            () => VideoExportRecords.updateTransfer(
              task,
              received: null,
              status: 'failed',
              failureReason: 'qualityUnavailable',
            ),
            stage: 'a missing download option requires source details',
          );
          await settleHost(tester);
          expect(tester.getSize(card).height, greaterThanOrEqualTo(cardHeight));
          expect(tester.getTopLeft(episodeBody).dx, titleStart);
          expect(find.text(t.download.retryEpisodeDownload), findsNothing);
          expect(find.text(t.common.detail).hitTestable(), findsNothing);
          expect(
            find.byKey(ValueKey('download-source.$identity')),
            findsNothing,
          );
          final swipeHint = find.text(t.download.swipeForWorkDetails);
          expect(swipeHint, findsOneWidget);
          expect(
            tester.getRect(card).contains(tester.getRect(swipeHint).center),
            isTrue,
          );
          expect(find.byType(NativeVideoPage), findsNothing);

          final episodeMenu = find.byKey(
            ValueKey('download-menu.video:$identity'),
          );
          expect(episodeMenu, findsNothing);
          await tester.longPress(episodeBody);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          expect(
            find.byKey(const ValueKey('download-episodes-delete')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey('download-swipe.video:$identity.delete')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('download-episodes-manage')),
          );
          await tester.pump();
          await tester.drag(episodeBody, const Offset(-160, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          expect(
            find
                .byKey(ValueKey('download-swipe.video:$identity.details'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(
            find
                .byKey(ValueKey('download-swipe.video:$identity.delete'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          try {
            await finishOperation(
              tester,
              subscription.cancel,
              stage: 'detach this test\'s toast subscription',
            );
          } finally {
            await finishOperation(
              tester,
              () => VideoExportRecords.updateTransfer(
                task,
                received: null,
                status: 'cancelled',
                terminal: true,
              ),
              stage: 'retire this test\'s queued attempt',
            );
          }
        }
      }),
    );
  }

  testWidgets(
    'cold download host shows confirmed rows before the complete inventory',
    (tester) => runHost(tester, () async {
      tester.view.physicalSize = const Size(520, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const source = 'offline-video-fixture';
      const otherSource = 'other-offline-video-fixture';
      const comicTitle = 'Checked comic ready on first mount';
      const queuedTitle = 'Durable queued video on first mount';
      final comicId = objectbox.unifiedDownloadBox.put(
        createTestDownload('comic-source|cold-fixture')
          ..source = 'comic-source'
          ..comicId = 'cold-fixture'
          ..title = comicTitle,
      );
      addTearDown(() => objectbox.unifiedDownloadBox.remove(comicId));
      final otherWatch = Uri.parse('https://fixture.test/watch?v=2320');
      final failedWork = Uri.parse('https://fixture.test/voddetail/2318.html');
      final failedWatch = failedWork.replace(
        queryParameters: {'line': 'main', 'episode': '1'},
      );
      final savedEpisode = failedWork.replace(
        queryParameters: {'line': 'main', 'episode': '2'},
      );
      Map<String, Object> hlsRow(String id, String source, Uri watch) => {
        'resourceId': VideoHlsAssets.identity(source, watch, '720p'),
        'source': source,
        'url': watch.toString(),
        'title': 'Verified HLS $id',
        'quality': '720p',
        'bytes': 2048,
        'taskKey': 'fixture-$id',
        'showTask': false,
        'at': 1700000000000,
        'assetId': id,
        'generation': 'generation-1',
        'format': 'hls',
        'available': true,
        'filePresent': true,
      };
      final watch = Uri.parse('https://fixture.test/watch?v=2316');
      final resource = VideoLocalResources.identity(source, watch, '720p');
      final removedWatch = Uri.parse('https://fixture.test/watch?v=2317');
      final removed = VideoLocalResources.identity(
        source,
        removedWatch,
        '720p',
      );
      late Map<String, dynamic> managed;
      await tester.runAsync(() async {
        final key = await VideoExportRecords.beginTransfer(
          source: source,
          video: watch,
          title: 'Delayed managed video',
          quality: '720p',
          resourceId: resource,
        );
        final file = await VideoLocalResources.file(resource);
        await file.parent.create(recursive: true);
        await file.writeAsBytes([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]);
        await VideoLocalResources.saved(
          resourceId: resource,
          bytes: 24,
          source: source,
          video: watch,
          title: 'Delayed managed video',
          quality: '720p',
          taskKey: key,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: 24,
          total: 24,
          status: 'saved',
          resourceId: resource,
          terminal: true,
        );
        managed = (await VideoLocalResources.read()).single;
        await VideoDownloadedDetails.ensureLocalPoster(managed);
        final removedKey = await VideoExportRecords.beginTransfer(
          source: source,
          video: removedWatch,
          title: 'Previously deleted video',
          quality: '720p',
          resourceId: removed,
        );
        await VideoExportRecords.updateTransfer(
          removedKey,
          received: 24,
          status: 'saved',
          resourceId: removed,
          terminal: true,
        );
        await VideoDownloadedDetails.captureItem(
          source,
          ApiVideoItem(
            id: '2318',
            title: 'Retryable transfer',
            detailUrl: failedWork,
            plannedEpisodes: 4,
            lines: [
              ApiVideoLine(
                id: 'main',
                label: 'Main',
                episodes: [
                  ApiVideoEpisode(
                    id: '1',
                    title: 'Episode 1',
                    url: null,
                    watchUrl: failedWatch,
                  ),
                  ApiVideoEpisode(
                    id: '2',
                    title: 'Episode 2',
                    url: null,
                    watchUrl: savedEpisode,
                  ),
                ],
              ),
            ],
          ),
          [
            NativeVideoCard(
              title: 'Episode 1',
              episodeLabel: 'Episode 1',
              watchUrl: failedWatch,
              coverUrl: null,
            ),
            NativeVideoCard(
              title: 'Episode 2',
              episodeLabel: 'Episode 2',
              watchUrl: savedEpisode,
              coverUrl: null,
            ),
          ],
        );
        final failedKey = await VideoExportRecords.beginTransfer(
          source: source,
          video: failedWatch,
          title: 'Retryable transfer · Episode 1',
          quality: '720p',
        );
        await VideoExportRecords.updateTransfer(
          failedKey,
          received: null,
          status: 'failed',
          terminal: true,
        );
        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString(VideoExportRecords.taskStorageKey)!)
                as List<dynamic>;
        await prefs.setString(
          VideoExportRecords.taskStorageKey,
          jsonEncode([
            ...stored,
            {
              'kind': 'transfer',
              'key': 'restored-cold-queue',
              'source': source,
              'url': 'https://fixture.test/watch?v=2321',
              'title': queuedTitle,
              'quality': '720p',
              'format': 'mp4',
              'at': 1700000000000,
              'attempt': 1,
              'status': 'queued',
            },
          ]),
        );
        VideoLocalResources.invalidate();
      });
      final gate = Completer<List<Object?>>();
      final nativeMethods = <String>[];
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        VideoHlsAssets.channel,
        (call) async {
          nativeMethods.add(call.method);
          if (call.method != 'list') return null;
          reads++;
          return gate.future;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          VideoHlsAssets.channel,
          null,
        ),
      );
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final libraryGate = Completer<void>();
      final libraryEntered = Completer<void>();
      final libraryWrite = VideoLibraryStore.shared.updateSnapshot(
        (_) => VideoLibrarySnapshot(),
        beforeWrite: (_, _) {
          libraryEntered.complete();
          return libraryGate.future;
        },
      );
      try {
        await libraryEntered.future;
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        final title = find.byKey(ValueKey('download-title.video:$resource'));
        final deletedTitle = find.byKey(
          ValueKey('download-title.video:$removed'),
        );
        final failedTitle = find.text('Retryable transfer · Episode 1');
        final queued = find.text(queuedTitle);
        final comic = find.text(comicTitle);
        final count = find.byKey(const ValueKey('download-count'));
        final loading = find.byKey(
          const ValueKey('download-inventory-loading'),
        );
        final firstSource = find.byKey(ValueKey('bookshelf.source.$source'));
        final lateSource = find.byKey(
          ValueKey('bookshelf.source.$otherSource'),
        );
        final group = find.byType(DownloadVideoWorkCard);
        final more = find.byKey(const ValueKey('download-more'));
        final filter = find.byKey(const ValueKey('download-filter'));
        void selectMedia(String media) => tester
            .widget<NativeVideoSegmentedControl>(
              find.byType(NativeVideoSegmentedControl),
            )
            .onSelected!(media);
        final elapsed = Stopwatch()..start();
        while ((reads == 0 ||
                title.evaluate().isEmpty ||
                failedTitle.evaluate().isEmpty ||
                queued.evaluate().isEmpty ||
                comic.evaluate().isEmpty ||
                firstSource.evaluate().isEmpty) &&
            elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(failedTitle, findsOneWidget);
        expect(queued, findsOneWidget);
        expect(comic, findsOneWidget);
        expect(title, findsOneWidget);
        expect(group, findsNothing);
        expect(count, findsNothing);
        expect(firstSource, findsOneWidget);
        expect(lateSource, findsNothing);
        expect(loading, findsNothing);
        expect(find.text(t.download.noTasks), findsNothing);
        expect(deletedTitle, findsNothing);
        expect(
          tester.widget<NativeVideoMenu>(more).options,
          isNot(contains('manage')),
        );
        expect(tester.widget<SourceFilterIconButton>(filter).onPressed, isNull);
        expect(
          reads,
          greaterThan(0),
          reason:
              'the managed resource projection is genuinely waiting on the native index',
        );
        expect(nativeMethods, everyElement('list'));
        selectMedia('comic');
        await tester.pump();
        expect(comic, findsOneWidget);
        expect(failedTitle, findsNothing);
        expect(queued, findsNothing);
        expect(title, findsNothing);
        selectMedia('video');
        await tester.pump();
        expect(comic, findsNothing);
        expect(failedTitle, findsOneWidget);
        expect(queued, findsOneWidget);
        expect(title, findsOneWidget);
        selectMedia('all');
        await tester.pump();
        expect(reads, 1, reason: 'Media changes only filter confirmed rows.');
        final status = find.byKey(
          ValueKey('download-state-row.video:$resource'),
        );
        expect(find.text(t.download.videoExternalFiles), findsNothing);
        await tester.pump(const Duration(milliseconds: 8500));
        expect(failedTitle, findsOneWidget);
        expect(queued, findsOneWidget);
        expect(comic, findsOneWidget);
        expect(count, findsNothing);
        expect(firstSource, findsOneWidget);
        expect(lateSource, findsNothing);
        expect(title, findsOneWidget);
        expect(deletedTitle, findsNothing);
        expect(
          find.text('${t.common.loadingFailed} · ${t.common.retry}'),
          findsNothing,
        );
        expect(reads, 1);
        gate.complete([
          hlsRow('saved-episode', source, savedEpisode),
          hlsRow('other-source', otherSource, otherWatch),
        ]);
        final verifiedElapsed = Stopwatch()..start();
        while (count.evaluate().isEmpty &&
            verifiedElapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          title,
          findsOneWidget,
          reason: 'verified files appear while optional library fallback waits',
        );
        expect(group, findsOneWidget);
        final verifiedWork = tester.widget<DownloadVideoWorkCard>(group).work;
        expect(verifiedWork.completed, 1);
        expect(verifiedWork.totalEpisodes, 2);
        expect(verifiedWork.failed, 1);
        expect(tester.widget<Text>(count).data, t.common.itemsCount(count: 6));
        expect(
          tester.widget<NativeVideoMenu>(more).options,
          contains('manage'),
        );
        expect(
          tester.widget<SourceFilterIconButton>(filter).onPressed,
          isNotNull,
        );
        expect(comic, findsOneWidget);
        expect(firstSource, findsOneWidget);
        expect(lateSource, findsOneWidget);
        expect(loading, findsNothing);
        expect(deletedTitle, findsNothing);
        await finishOperation(tester, () async {
          final next = await VideoExportRecords.beginTransfer(
            source: source,
            video: Uri.parse('https://fixture.test/watch?v=2319'),
            title: 'New terminal transfer during metadata read',
            quality: '720p',
          );
          await VideoExportRecords.updateTransfer(
            next,
            received: null,
            status: 'failed',
            terminal: true,
          );
        }, stage: 'a new task can commit while display metadata waits');
        final nextTitle = find.text(
          'New terminal transfer during metadata read',
        );
        final refreshElapsed = Stopwatch()..start();
        while (nextTitle.evaluate().isEmpty &&
            refreshElapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(nextTitle, findsOneWidget);
        libraryGate.complete();
        await libraryWrite;
        await settleHost(tester);
        expect(nextTitle, findsOneWidget);
        expect(title, findsOneWidget);
        expect(find.byKey(ValueKey(verifiedWork.key)), findsOneWidget);
        expect(tester.widget<Text>(count).data, t.common.itemsCount(count: 7));
        expect(deletedTitle, findsNothing);
        expect(find.text('24 B'), findsOneWidget);
        expect(
          find.descendant(of: status, matching: find.text(t.common.loading)),
          findsNothing,
        );
        expect(find.text(t.download.videoExternalFiles), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete([]);
        if (!libraryGate.isCompleted) libraryGate.complete();
        await libraryWrite;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          VideoHlsAssets.channel,
          emptyHlsIndex,
        );
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          var posterFinished = false;
          VideoDownloadedDetails.ensureLocalPoster(
            managed,
          ).then((_) => posterFinished = true);
          final elapsed = Stopwatch()..start();
          while (!posterFinished &&
              elapsed.elapsed < const Duration(seconds: 5)) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            posterFinished,
            isTrue,
            reason:
                'the actual managed-cover job retires before this fixture leaves its FakeAsync zone',
          );
          await settleHost(tester);
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            VideoHlsAssets.channel,
            emptyHlsIndex,
          );
        }
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'inventory failure exposes only checked files and recovery retains the last good view',
    (tester) => runHost(tester, () async {
      tester.view.physicalSize = const Size(520, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const source = 'checked-mp4-fixture';
      const mp4Title = 'Checked MP4';
      const failedTitle = 'Durable failed transfer';
      const unverifiedTitle = 'HLS log without verification';
      final watch = Uri.parse('https://fixture.test/watch?v=2301');
      final mp4Id = VideoLocalResources.identity(source, watch, '720p');
      final missingWatch = Uri.parse('https://fixture.test/watch?v=2302');
      final missingId = VideoHlsAssets.identity(source, missingWatch, '720p');
      await tester.runAsync(() async {
        final file = await VideoLocalResources.file(mp4Id);
        await file.parent.create(recursive: true);
        await file.writeAsBytes([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]);
        await VideoLocalResources.saved(
          resourceId: mp4Id,
          bytes: 24,
          source: source,
          video: watch,
          title: mp4Title,
          quality: '720p',
          taskKey: 'checked-mp4-without-task',
        );
        final failed = await VideoExportRecords.beginTransfer(
          source: source,
          video: Uri.parse('https://fixture.test/watch?v=2303'),
          title: failedTitle,
          quality: '720p',
        );
        await VideoExportRecords.updateTransfer(
          failed,
          received: null,
          status: 'failed',
          terminal: true,
        );
        final missing = await VideoExportRecords.beginTransfer(
          source: source,
          video: missingWatch,
          title: unverifiedTitle,
          quality: '720p',
          format: 'hls',
          resourceId: missingId,
        );
        await VideoExportRecords.updateTransfer(
          missing,
          received: 20,
          status: 'saved',
          resourceId: missingId,
          terminal: true,
        );
      });

      final gates = List.generate(3, (_) => Completer<List<Object?>>());
      var reads = 0;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) {
        if (call.method != 'list' || reads >= gates.length) {
          return emptyHlsIndex(call);
        }
        return gates[reads++].future;
      });
      Future<void> waitFor(
        bool Function() condition, {
        required String stage,
      }) async {
        final elapsed = Stopwatch()..start();
        while (!condition() && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          condition(),
          isTrue,
          reason:
              '$stage, reads=$reads, text=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}',
        );
      }

      try {
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        final mp4 = find.byKey(ValueKey('download-title.video:$mp4Id'));
        final failed = find.text(failedTitle);
        final count = find.byKey(const ValueKey('download-count'));
        final loading = find.byKey(
          const ValueKey('download-inventory-loading'),
        );
        final sourceTab = find.byKey(ValueKey('bookshelf.source.$source'));
        final retry = find.widgetWithText(
          TextButton,
          '${t.common.refreshRetained} · ${t.common.retry}',
        );
        await waitFor(
          () =>
              reads == 1 &&
              mp4.evaluate().isNotEmpty &&
              failed.evaluate().isNotEmpty &&
              sourceTab.evaluate().isNotEmpty,
          stage: 'confirmed rows before the first native reply',
        );
        expect(count, findsNothing);
        expect(retry, findsNothing);
        expect(find.text(unverifiedTitle), findsNothing);
        gates[0].completeError(
          PlatformException(code: 'inventory-unavailable'),
        );
        await waitFor(
          () => retry.evaluate().isNotEmpty,
          stage: 'checked cold fallback',
        );
        expect(mp4, findsOneWidget);
        expect(failed, findsOneWidget);
        expect(retry, findsOneWidget);
        expect(loading, findsNothing);
        expect(count, findsNothing);
        expect(sourceTab, findsOneWidget);
        expect(find.text(unverifiedTitle), findsNothing);

        await tester.tap(retry);
        await tester.pump();
        await waitFor(() => reads == 2, stage: 'manual retry');
        expect(tester.widget<TextButton>(retry).onPressed, isNull);
        expect(mp4, findsOneWidget);
        expect(count, findsNothing);
        gates[1].complete([]);
        await waitFor(
          () => count.evaluate().isNotEmpty,
          stage: 'complete retry snapshot',
        );
        expect(tester.widget<Text>(count).data, t.common.itemsCount(count: 2));
        expect(sourceTab, findsOneWidget);
        expect(retry, findsNothing);

        VideoLocalResources.invalidate();
        await waitFor(() => reads == 3, stage: 'automatic warm refresh');
        expect(mp4, findsOneWidget);
        expect(failed, findsOneWidget);
        expect(tester.widget<Text>(count).data, t.common.itemsCount(count: 2));
        expect(sourceTab, findsOneWidget);
        expect(loading, findsNothing);
        gates[2].completeError(
          PlatformException(code: 'inventory-unavailable'),
        );
        await waitFor(() => retry.evaluate().isNotEmpty, stage: 'warm failure');
        expect(mp4, findsOneWidget);
        expect(failed, findsOneWidget);
        expect(tester.widget<Text>(count).data, t.common.itemsCount(count: 2));
        expect(sourceTab, findsOneWidget);
        expect(find.text(unverifiedTitle), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        for (final gate in gates) {
          if (!gate.isCompleted) gate.complete([]);
        }
        messenger.setMockMethodCallHandler(
          VideoHlsAssets.channel,
          emptyHlsIndex,
        );
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
