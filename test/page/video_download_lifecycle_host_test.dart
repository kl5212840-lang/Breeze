import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  const channel = MethodChannel('breeze.video.download');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  final nativeViews = <int>{};
  final video = Uri.parse('https://hanime1.me/watch?v=93&private=omit');
  final choice = (
    label: '720p',
    format: 'MP4',
    url: Uri.parse(
      'https://media-fixture.test/file.mp4?credential=never-persist',
    ),
  );
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await DownloadAdmission.instance.start();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        nativeViews.add(args['id'] as int);
        final viewChannel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(viewChannel);
        messenger.setMockMethodCallHandler(viewChannel, (_) async => null);
      } else if (call.method == 'dispose') {
        nativeViews.remove(call.arguments as int);
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    final directory = await VideoLocalResources.root();
    if (await directory.exists()) await directory.delete(recursive: true);
    VideoLocalResources.invalidate();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final nativeChannel in nativeChannels) {
      messenger.setMockMethodCallHandler(nativeChannel, null);
    }
    nativeChannels.clear();
    expect(nativeViews, isEmpty);
  });

  Future<void> until(
    WidgetTester tester,
    bool Function() ready, {
    String stage = 'the requested host state',
  }) async {
    final elapsed = Stopwatch()..start();
    while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      ready(),
      isTrue,
      reason: 'Timed out after real 5s waiting for $stage',
    );
  }

  Future<T> finish<T>(
    WidgetTester tester,
    Future<T> future,
    String stage,
  ) async {
    var completed = false;
    late T result;
    Object? failure;
    StackTrace? trace;
    future.then<void>(
      (value) {
        result = value;
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        completed = true;
      },
    );
    // Queue futures can belong to this fake clock: pump it between real I/O
    // turns instead of blocking runAsync on the queue's prior microtasks.
    await until(tester, () => completed, stage: stage);
    if (failure != null) Error.throwWithStackTrace(failure!, trace!);
    return result;
  }

  Future<void> drainHost(
    WidgetTester tester,
    Completer<Object?> pending,
    String resourceId,
  ) async {
    if (!pending.isCompleted) pending.complete('cancelled');
    await tester.pumpWidget(const SizedBox.shrink());
    await until(
      tester,
      () => nativeViews.isEmpty,
      stage: 'all native controls disposed before host channels close',
    );
    await finish(
      tester,
      VideoExportRecords.flush(),
      'terminal task write cleanup',
    );
    await finish(
      tester,
      VideoLocalResources.read(),
      'managed index queue cleanup',
    );
    await until(tester, () {
      if (!VideoLocalResources.tryHold(resourceId)) return false;
      VideoLocalResources.release(resourceId);
      return true;
    }, stage: 'the native transfer finalizer releasing its resource');
    // Unmount before the last probe: disposed hosts must not enqueue another
    // read after this test's FakeAsync zone has stopped being pumped.
    await finish(
      tester,
      VideoExportRecords.readTasks(),
      'final disposed-host read drain',
    );
    await finish(
      tester,
      DownloadCenterResources.readVideos(waitForStorage: true),
      'full download-center projection drain',
    );
    await tester.pump();
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'sheet exit keeps real transfer; task host progress and confirmed saved result, $style',
      (tester) async {
        final styleValue = ValueNotifier(style);
        addTearDown(styleValue.dispose);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<Object?>();
        var cancels = 0;
        String? job, managedId;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'start') {
            job = call.arguments['id'] as String;
            managedId = call.arguments['managedId'] as String;
            return pending.future;
          }
          if (call.method == 'cancel') {
            cancels++;
          }
          return null;
        });
        try {
          Widget host(Widget child) => AppInterfaceStyleScope(
            style: styleValue,
            child: MaterialApp(
              theme: ThemeData(
                brightness: style == 'system'
                    ? Brightness.light
                    : Brightness.dark,
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2),
                ),
                child: child,
              ),
            ),
          );
          await tester.pumpWidget(
            host(
              Scaffold(
                body: VideoDownloadSheet(
                  source: 'persistent-$style',
                  video: video,
                  title: '持续下载 $style',
                  onClose: () {},
                  readChoices: () async => (
                    status: VideoSiteStatus.ok,
                    value: [choice],
                    writeUnconfirmed: false,
                  ),
                ),
              ),
            ),
          );
          await until(
            tester,
            () => find
                .byKey(const ValueKey('video-download-choice-0'))
                .evaluate()
                .isNotEmpty,
            stage: 'download choices and local availability',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('video-download-choice-0')),
          );
          await tester.tap(
            find.byKey(const ValueKey('video-download-choice-0')),
          );
          await tester.pump();
          expect(
            job,
            isNull,
            reason: 'Selecting a quality alone must not start a transfer',
          );
          final start = find.byKey(const ValueKey('video-download.start'));
          await tester.ensureVisible(start);
          await tester.pump();
          await until(
            tester,
            () => tester.widget<FilledButton>(start).onPressed != null,
            stage: 'local download availability before enabling Start',
          );
          expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
          expect(start.hitTestable(), findsOneWidget);
          await tester.tap(start);
          await until(
            tester,
            () => job != null,
            stage: 'explicit Start reaches the native download engine',
          );
          // Dispose the actual sheet, not just its close callback.
          await tester.pumpWidget(
            host(const Scaffold(body: DownloadTaskPage(embedded: true))),
          );
          await until(
            tester,
            () => find.text('持续下载 $style').evaluate().isNotEmpty,
          );
          expect(cancels, 0);
          expect(find.byType(AppBar), findsNothing);
          await messenger.handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('progress', {
                'id': job,
                'received': 10240,
                'total': 20480,
              }),
            ),
            (_) {},
          );
          await until(
            tester,
            () => find.text('10.2 KB / 20.5 KB').evaluate().isNotEmpty,
          );
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator),
                )
                .value,
            .5,
          );
          final stored = (await SharedPreferences.getInstance()).getString(
            VideoExportRecords.taskStorageKey,
          )!;
          expect(stored, isNot(contains('credential')));
          expect(stored, isNot(contains('private')));
          expect(stored, isNot(contains('media-fixture')));
          expect(
            await finish(
              tester,
              VideoExportRecords.read(),
              'external export records',
            ),
            isEmpty,
            reason: 'Bytes received do not prove a committed managed video.',
          );
          final stageId = List.filled(32, style == 'system' ? 'a' : 'b').join();
          final media = (await tester.runAsync(
            () => VideoLocalResources.stagedFile(stageId),
          ))!;
          await tester.runAsync(() async {
            await media.parent.create(recursive: true);
            final bytes = Uint8List(20480)
              ..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
            await media.writeAsBytes(bytes);
          });
          pending.complete({
            'status': 'staged',
            'resourceId': managedId,
            'stageId': stageId,
            'bytes': 20480,
          });
          await finish(tester, VideoExportRecords.flush(), 'task log commit');
          // A valid local MP4 exposes export only after native staging and
          // the managed index are committed. Completion has no duplicate badge.
          final savedId = VideoLocalResources.identity(
            'persistent-$style',
            video,
            choice.label,
          );
          final savedCard = find.byKey(
            ValueKey('download-card.video:$savedId'),
          );
          final swipe = find.byWidgetPredicate(
            (widget) =>
                widget is DownloadSwipeActions &&
                widget.rowKey == 'video:$savedId' &&
                widget.actions.any((action) => action.id == 'export'),
          );
          await until(
            tester,
            () => swipe.evaluate().isNotEmpty,
            stage: 'the real committed MP4 exposes its managed file action',
          );
          expect(
            find.byKey(ValueKey('download-menu.video:$savedId')),
            findsNothing,
          );
          expect(savedCard, findsOneWidget);
          expect(find.text(t.common.saved), findsNothing);
          final quality = find.byKey(
            ValueKey(
              'download-source.video:${VideoLocalResources.identity('persistent-$style', video, choice.label)}',
            ),
          );
          expect(quality, findsOneWidget);
          expect(
            tester.widget<Text>(quality).data,
            contains('persistent-$style'),
          );
          expect(tester.widget<Text>(quality).data, contains('720p'));
          await finish(tester, VideoExportRecords.flush(), 'task log commit');
          expect(
            await finish(
              tester,
              VideoExportRecords.read(),
              'external export records',
            ),
            isEmpty,
          );
          expect(
            (await finish(
              tester,
              VideoLocalResources.read(),
              'verified local resource',
            )).single['source'],
            'persistent-$style',
          );
          expect(find.byTooltip(t.download.cancelTask), findsNothing);
          expect(cancels, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await drainHost(
            tester,
            pending,
            VideoLocalResources.identity(
              'persistent-$style',
              video,
              choice.label,
            ),
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'task page cancel is explicit and stays disabled until native confirmation',
    (tester) async {
      final pending = Completer<Object?>();
      final cancelReceived = Completer<void>();
      var cancels = 0;
      String? job;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          job = call.arguments['id'] as String;
          return pending.future;
        }
        if (call.method == 'cancel') {
          cancels++;
          cancelReceived.complete();
        }
        return null;
      });
      final result = VideoSystemDownload().save(
        choice: choice,
        source: 'explicit-cancel',
        video: video,
        title: '手动取消任务',
        onProgress: (_) {},
      );
      final styleValue = ValueNotifier('breeze');
      addTearDown(styleValue.dispose);
      try {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: styleValue,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        await until(
          tester,
          () => job != null && find.text('手动取消任务').evaluate().isNotEmpty,
          stage: 'the new explicit-cancel transfer and visible task',
        );
        expect(cancels, 0);
        final cancel = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == t.download.cancelTask,
        );
        await tester.tap(cancel);
        await until(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          stage: 'explicit cancellation confirmation',
        );
        expect(cancels, 0);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.widgetWithText(TextButton, t.common.ok));
        // Native mock receipt can complete before the setState frame that
        // disables the card. Wait for both real receipt and rendered state.
        await until(
          tester,
          () =>
              cancelReceived.isCompleted &&
              tester.widget<IconButton>(cancel).onPressed == null,
          stage: 'native cancellation request and rebuilt disabled task action',
        );
        expect(tester.widget<IconButton>(cancel).onPressed, isNull);
        expect(find.text(t.download.videoCancelled), findsNothing);
        expect(cancels, 1);
        pending.complete('cancelled');
        await until(
          tester,
          () => find.text(t.download.videoCancelled).evaluate().isNotEmpty,
        );
        final quality = find.byKey(
          ValueKey(
            'download-source.video:${VideoLocalResources.identity('explicit-cancel', video, choice.label)}',
          ),
        );
        expect(quality, findsOneWidget);
        expect(tester.widget<Text>(quality).data, contains('explicit-cancel'));
        expect(tester.widget<Text>(quality).data, contains('720p'));
        expect(
          await finish(tester, result, 'native cancellation finalization'),
          VideoDownloadStatus.cancelled,
        );
        expect(find.byTooltip(t.download.cancelTask), findsNothing);
        expect(
          await finish(
            tester,
            VideoExportRecords.read(),
            'external export records',
          ),
          isEmpty,
        );
      } finally {
        await drainHost(
          tester,
          pending,
          VideoLocalResources.identity('explicit-cancel', video, choice.label),
        );
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test(
    'old-process in-flight record is interrupted, never resumable or saved',
    () async {
      SharedPreferences.setMockInitialValues({
        VideoExportRecords.taskStorageKey: jsonEncode([
          {
            'kind': 'transfer',
            'key': 'old-process',
            'source': 'fixture',
            'url': 'https://hanime1.me/watch?v=7',
            'title': '旧任务',
            'quality': '720p',
            'at': 1,
            'status': 'downloading',
            'received': 10,
            'total': 100,
          },
        ]),
      });
      final row = (await VideoExportRecords.readTasks()).singleWhere(
        (row) => row['key'] == 'old-process',
      );
      expect(row['status'], 'interrupted');
      expect(VideoExportRecords.isLive('old-process'), isFalse);
      expect(await VideoExportRecords.read(), isEmpty);
    },
  );
}
