import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

/// Native package list/delete are isolated channel fixtures. The actual page,
/// Flutter menu/confirmation, MP4 bytes, index and task records remain real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = 'hls-removal-host';
  const quality = '720p';
  final page = Uri.parse(
    'https://site-fixture.test/voddetail/42.html?line=a&episode=one',
  );
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'an old failed row cannot bind removal to a newer failed attempt',
    () async {
      SharedPreferences.setMockInitialValues({});
      const taskSource = 'replacement-attempt';
      final key = await VideoExportRecords.beginTransfer(
        source: taskSource,
        video: page,
        title: 'Replacement attempt',
        quality: quality,
      );
      Future<void> fail() => VideoExportRecords.updateTransfer(
        key,
        received: 0,
        total: 0,
        status: 'failed',
        terminal: true,
      );
      await fail();
      final original = (await VideoExportRecords.readTaskSnapshot())
          .singleWhere((row) => row['key'] == key);
      final restarted = await VideoExportRecords.restartTransfer(original);
      expect(restarted?['attempt'], 2);
      await fail();
      await expectLater(
        bindVideoDownloadRemoval(
          source: taskSource,
          page: page,
          quality: quality,
          displayedTask: original,
        ),
        throwsStateError,
      );
      final currentRow = (await VideoExportRecords.readTaskSnapshot())
          .singleWhere((row) => row['key'] == key);
      final current = await bindVideoDownloadRemoval(
        source: taskSource,
        page: page,
        quality: quality,
        displayedTask: currentRow,
      );
      await removeVideoDownload(
        source: taskSource,
        page: page,
        quality: quality,
        expected: current,
      );
    },
  );

  test('deleting an external receipt preserves the same local MP4', () async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    final canonicalPage = Uri.https(page.authority, page.path);
    final id = VideoLocalResources.identity(source, canonicalPage, quality);
    final bytes = Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
    final original = await VideoLocalResources.file(id);
    await original.parent.create(recursive: true);
    await original.writeAsBytes(bytes);
    await VideoLocalResources.saved(
      resourceId: id,
      bytes: bytes.length,
      source: source,
      video: canonicalPage,
      title: 'Original local MP4',
      quality: quality,
      taskKey: 'receipt-fixture-managed-task',
    );
    await VideoExportRecords.add(
      source: source,
      video: canonicalPage,
      title: 'Earlier Files receipt',
      quality: quality,
    );
    final receipt = (await VideoExportRecords.read()).single;
    final receiptPage = Uri.parse(receipt['url'] as String);
    expect(VideoLocalResources.identity(source, receiptPage, quality), id);
    final bound = await bindVideoDownloadRemoval(
      source: source,
      page: receiptPage,
      quality: quality,
      displayedTask: {
        ...receipt,
        'key': 'external|${receipt['key']}',
        'externalKey': receipt['key'],
        'status': 'saved',
      },
    );
    await removeVideoDownload(
      source: source,
      page: receiptPage,
      quality: quality,
      expected: bound,
    );
    expect(await VideoExportRecords.read(), isEmpty);
    expect(await original.readAsBytes(), orderedEquals(bytes));
  });

  testWidgets(
    'Files receipt explains export and deletes only the bound record',
    (tester) async {
      final style = ValueNotifier('breeze');
      final notices = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(notices.add);
      addTearDown(subscription.cancel);
      final canonicalPage = Uri.https(page.authority, page.path);
      final id = VideoLocalResources.identity(source, canonicalPage, quality);
      final bytes = Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
      late File managed, exported;
      late String replacement;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await useIsolatedDownloadFixture();
        VideoLocalResources.invalidate();
        managed = await VideoLocalResources.file(id);
        exported = File('${managed.parent.parent.path}/external-fixture.mp4');
        await exported.writeAsBytes(bytes);
        await VideoExportRecords.add(
          source: source,
          video: canonicalPage,
          title: 'Earlier Files receipt',
          quality: quality,
        );
      });

      Future<void> until(Finder target, String stage) async {
        final elapsed = Stopwatch()..start();
        while (target.evaluate().isEmpty &&
            elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(target, findsOneWidget, reason: stage);
      }

      Future<T> finish<T>(Future<T> future, String stage) async {
        late T value;
        Object? failure;
        StackTrace? stack;
        var completed = false;
        future.then<void>(
          (result) {
            value = result;
            completed = true;
          },
          onError: (Object error, StackTrace trace) {
            failure = error;
            stack = trace;
            completed = true;
          },
        );
        final elapsed = Stopwatch()..start();
        while (!completed && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(completed, isTrue, reason: stage);
        if (failure != null) Error.throwWithStackTrace(failure!, stack!);
        return value;
      }

      try {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        final card = find.byKey(ValueKey('download-card.video:$id'));
        await until(
          card,
          'the real downloads page displays the export receipt',
        );
        expect(find.text(t.bookshelf.exportedVideo), findsOneWidget);
        expect(find.text(t.download.videoExternalFiles), findsNothing);
        expect(
          find.descendant(
            of: card,
            matching: find.byIcon(Icons.play_arrow_rounded),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(ValueKey('download-open.video:$id')));
        await tester.pump();
        expect(
          notices
              .where(
                (notice) => notice.message == t.download.videoExternalFiles,
              )
              .map((notice) => notice.type),
          [ToastType.info],
        );

        await tester.drag(card, const Offset(-160, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 260));
        final delete = find.byKey(ValueKey('download-swipe.video:$id.delete'));
        expect(delete.hitTestable(), findsOneWidget);
        expect(
          find.byKey(ValueKey('download-swipe.video:$id.export')),
          findsNothing,
        );
        await tester.tap(delete);
        // Advance the close animation in the test clock before waiting for
        // real storage I/O. Wall-clock polling alone may produce too few
        // frames when this host runs alongside other widget-test isolates.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 260));
        final dialog = find.byType(AlertDialog);
        await until(dialog, 'the receipt opens a removal confirmation');
        await tester.pump(const Duration(milliseconds: 350));

        // A new managed download for the same identity arrives after binding.
        await tester.runAsync(() async {
          replacement = await VideoExportRecords.beginTransfer(
            source: source,
            video: canonicalPage,
            title: 'New managed download',
            quality: quality,
            resourceId: id,
          );
          await managed.parent.create(recursive: true);
          await managed.writeAsBytes(bytes);
          await VideoLocalResources.saved(
            resourceId: id,
            bytes: bytes.length,
            source: source,
            video: canonicalPage,
            title: 'New managed download',
            quality: quality,
            taskKey: replacement,
          );
          await VideoExportRecords.updateTransfer(
            replacement,
            received: bytes.length,
            total: bytes.length,
            status: 'saved',
            terminal: true,
            resourceId: id,
          );
        });
        await tester.tap(find.widgetWithText(TextButton, t.common.delete));
        await until(
          find.text('New managed download'),
          'the managed replacement remains visible after receipt removal',
        );
        // Wait for the actual persisted receipt deletion, independent of the
        // replacement card becoming visible while the confirmation closes.
        final elapsed = Stopwatch()..start();
        var receipts = await finish(VideoExportRecords.read(), 'read receipts');
        while (receipts.isNotEmpty &&
            elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.pump(const Duration(milliseconds: 16));
          receipts = await finish(
            VideoExportRecords.read(),
            'wait for receipt removal',
          );
        }
        expect(receipts, isEmpty);
        await tester.runAsync(() async {
          expect(await managed.readAsBytes(), orderedEquals(bytes));
          expect(await exported.readAsBytes(), orderedEquals(bytes));
        });
        final tasks = await finish(
          VideoExportRecords.readTasks(),
          'read the managed replacement',
        );
        expect(tasks.map((row) => row['key']), contains(replacement));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await finish(VideoExportRecords.flush(), 'drain receipt writes');
        await finish(
          DownloadCenterResources.readVideos(waitForStorage: true),
          'drain the unmounted download center inventory',
        );
        style.dispose();
      }
    },
  );

  testWidgets(
    'exporting the MP4 copy and removing the same-work HLS preserve the original MP4',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final style = ValueNotifier('breeze');
      final nativeViews = <int>{};
      final viewChannels = <MethodChannel>[];
      final nativeDeletes = <Map<String, dynamic>>[];
      final nativeRows = <Map<String, dynamic>>[];
      const exportChannel = MethodChannel('breeze.video.download');
      late File exported;
      var exports = 0;
      late String mp4Task, hlsTask, mp4ID, hlsID, originalTaskJSON;
      late File mp4, index;
      late Uint8List originalIndex, originalMP4;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          nativeViews.add(arguments['id'] as int);
          final channel = MethodChannel(
            '${arguments['viewType']}.${arguments['id']}',
          );
          viewChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        } else if (call.method == 'dispose') {
          nativeViews.remove(call.arguments as int);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
        switch (call.method) {
          case 'list':
            return [
              for (final row in nativeRows) {...row},
            ];
          case 'delete':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            nativeDeletes.add(args);
            final matches = nativeRows
                .where(
                  (row) =>
                      row['resourceId'] == args['resourceId'] &&
                      row['assetId'] == args['assetId'] &&
                      row['generation'] == args['generation'],
                )
                .toList();
            if (matches.length != 1) return false;
            nativeRows.remove(matches.single);
            return true;
          default:
            throw MissingPluginException(
              'Unexpected HLS host fixture operation',
            );
        }
      });
      Future<void> until(bool Function() ready, String stage) async {
        final elapsed = Stopwatch()..start();
        while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), isTrue, reason: stage);
      }

      Future<T> finish<T>(Future<T> future, String stage) async {
        T? value;
        Object? failure;
        StackTrace? stack;
        var completed = false;
        future.then<void>(
          (result) {
            value = result;
            completed = true;
          },
          onError: (Object error, StackTrace trace) {
            failure = error;
            stack = trace;
            completed = true;
          },
        );
        await until(() => completed, stage);
        if (failure != null) Error.throwWithStackTrace(failure!, stack!);
        return value as T;
      }

      try {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          await useIsolatedDownloadFixture();
          VideoLocalResources.invalidate();
          mp4ID = VideoLocalResources.identity(source, page, quality);
          hlsID = VideoHlsAssets.identity(source, page, quality);
          expect(hlsID, isNot(mp4ID));
          mp4Task = await VideoExportRecords.beginTransfer(
            source: source,
            video: page,
            title: '同一作品 MP4',
            quality: quality,
            resourceId: mp4ID,
          );
          mp4 = await VideoLocalResources.file(mp4ID);
          await mp4.parent.create(recursive: true);
          await mp4.writeAsBytes(
            Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
          );
          await VideoLocalResources.saved(
            resourceId: mp4ID,
            bytes: 24,
            source: source,
            video: page,
            title: '同一作品 MP4',
            quality: quality,
            taskKey: mp4Task,
          );
          await VideoExportRecords.updateTransfer(
            mp4Task,
            received: 24,
            total: 24,
            status: 'saved',
            terminal: true,
            resourceId: mp4ID,
          );
          hlsTask = await VideoExportRecords.beginTransfer(
            source: source,
            video: page,
            title: '同一作品 HLS',
            quality: quality,
            resourceId: hlsID,
            format: 'hls',
          );
          nativeRows.add({
            'resourceId': hlsID,
            'assetId': 'hls-asset-bound',
            'generation': 'hls-generation-bound',
            'source': source,
            'url': page.toString(),
            'title': '同一作品 HLS',
            'quality': quality,
            'bytes': 4096,
            'taskKey': hlsTask,
            'showTask': true,
            'at': DateTime.now().toUtc().millisecondsSinceEpoch,
            'format': 'hls',
            'available': true,
            'filePresent': true,
          });
          await VideoExportRecords.updateTransfer(
            hlsTask,
            received: 4096,
            total: 4096,
            status: 'saved',
            terminal: true,
            resourceId: hlsID,
          );
          index = File('${mp4.parent.path}/index.json');
          exported = File('${mp4.parent.parent.path}/exported-copy.mp4');
          originalIndex = await index.readAsBytes();
          originalMP4 = await mp4.readAsBytes();
          originalTaskJSON = (await SharedPreferences.getInstance()).getString(
            VideoExportRecords.taskStorageKey,
          )!;
          await DownloadWorkPins.setPinnedItems([
            for (final id in [mp4ID, hlsID])
              DownloadCenterItem(
                key: 'video:$id',
                source: source,
                title: '同一作品',
                priority: 3,
                at: 0,
                video: const {
                  'publicWorkIdentity': 'work-42',
                  'publicWorkTitle': '同一作品',
                },
              ),
          ], true);
        });
        messenger.setMockMethodCallHandler(exportChannel, (call) async {
          expect(call.method, 'export');
          expect(call.arguments['resourceId'], mp4ID);
          exports++;
          mp4.copySync(exported.path);
          return 'saved';
        });
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        final hlsCard = find.byKey(ValueKey('download-card.video:$hlsID'));
        final mp4Card = find.byKey(ValueKey('download-card.video:$mp4ID'));
        await until(
          () => hlsCard.evaluate().isNotEmpty && mp4Card.evaluate().isNotEmpty,
          'the actual unified page shows two distinct format-bound cards',
        );
        expect(
          find.byKey(ValueKey('download-menu.video:$mp4ID')),
          findsNothing,
        );
        await tester.ensureVisible(mp4Card);
        await tester.pump();
        // A short, ordinary swipe still opens the tray with three commands.
        await tester.drag(mp4Card, const Offset(-90, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 260));
        final export = find.byKey(
          ValueKey('download-swipe.video:$mp4ID.export'),
        );
        expect(export.hitTestable(), findsOneWidget);
        await tester.tap(export);
        await until(
          () => exports == 1,
          'the real card invokes the Files export',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await finish(VideoExportRecords.flush(), 'export action settles');
        final afterExport = await finish(
          DownloadCenterResources.readVideos(),
          'refresh resource rows after export',
        );
        expect(
          afterExport.map((row) => row['resourceId']),
          unorderedEquals([mp4ID, hlsID]),
        );
        expect(
          await finish(VideoExportRecords.read(), 'export receipts'),
          isEmpty,
        );
        await tester.runAsync(() async {
          expect(await exported.readAsBytes(), orderedEquals(originalMP4));
          expect(await mp4.readAsBytes(), orderedEquals(originalMP4));
          expect(await index.readAsBytes(), orderedEquals(originalIndex));
        });
        final playback = await finish(
          VideoLocalResources.playback(mp4ID),
          'the original can be opened by the offline player after export',
        );
        expect(playback.sources.single.url, mp4.uri);

        const failedTitle = 'Failed replacement of the existing MP4';
        final failedTask = await finish(
          VideoExportRecords.beginTransfer(
            source: source,
            video: page,
            title: failedTitle,
            quality: quality,
          ),
          'queue an independent attempt for the same MP4 identity',
        );
        await finish(
          VideoExportRecords.updateTransfer(
            failedTask,
            received: 0,
            total: 0,
            status: 'failed',
            terminal: true,
          ),
          'the replacement fails',
        );
        final failure = find.text(failedTitle);
        await until(
          () => failure.evaluate().isNotEmpty,
          'the replacement failure is visible',
        );
        await tester.ensureVisible(failure);
        await tester.drag(failure, const Offset(-165, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final failedDelete = find.byKey(
          ValueKey('download-swipe.video:$mp4ID.delete'),
        );
        expect(failedDelete.hitTestable(), findsOneWidget);
        expect(
          find.byKey(ValueKey('download-swipe.video:$mp4ID.export')),
          findsNothing,
        );
        await tester.tap(failedDelete);
        await until(
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          'the failed attempt has its own confirmation',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.widgetWithText(TextButton, t.common.delete));
        await until(
          () => failure.evaluate().isEmpty && mp4Card.evaluate().isNotEmpty,
          'the failed log is removed and the original card returns',
        );
        expect(nativeDeletes, isEmpty);
        await tester.runAsync(() async {
          expect(await mp4.readAsBytes(), orderedEquals(originalMP4));
          expect(await exported.readAsBytes(), orderedEquals(originalMP4));
        });

        Future<void> openHlsDeleteConfirmation() async {
          final open = find.byKey(ValueKey('download-open.video:$hlsID'));
          await until(
            () =>
                open.evaluate().isNotEmpty &&
                tester.widget<InkWell>(open).onTap != null,
            'the HLS card is interactive after the previous action',
          );
          expect(
            find.byKey(ValueKey('download-menu.video:$hlsID')),
            findsNothing,
          );
          await tester.ensureVisible(hlsCard);
          await tester.pump();
          await tester.drag(hlsCard, const Offset(-160, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            find.byKey(ValueKey('download-swipe.video:$hlsID.export')),
            findsNothing,
          );
          final delete = find.byKey(
            ValueKey('download-swipe.video:$hlsID.delete'),
          );
          expect(delete.hitTestable(), findsOneWidget);
          await tester.tap(delete);
          await until(
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
            'format-bound deletion reaches a real confirmation',
          );
          await tester.pump(const Duration(milliseconds: 350));
        }

        await openHlsDeleteConfirmation();
        expect(nativeDeletes, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await until(
          () => find.byType(AlertDialog).evaluate().isEmpty,
          'cancel leaves confirmation',
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(nativeDeletes, isEmpty);
        expect(hlsCard, findsOneWidget);
        expect(mp4Card, findsOneWidget);
        await tester.runAsync(() async {
          expect(await mp4.readAsBytes(), orderedEquals(originalMP4));
          expect(await index.readAsBytes(), orderedEquals(originalIndex));
          expect(
            (await SharedPreferences.getInstance()).getString(
              VideoExportRecords.taskStorageKey,
            ),
            originalTaskJSON,
          );
        });
        await openHlsDeleteConfirmation();
        await tester.tap(find.widgetWithText(TextButton, t.common.delete));
        await until(
          () => nativeDeletes.isNotEmpty && hlsCard.evaluate().isEmpty,
          'native HLS asset and its real task/card disappear after confirmation',
        );
        expect(nativeDeletes, [
          {
            'resourceId': hlsID,
            'assetId': 'hls-asset-bound',
            'generation': 'hls-generation-bound',
          },
        ]);
        expect(nativeRows, isEmpty);
        expect(mp4Card, findsOneWidget);
        final tasks = await finish(
          VideoExportRecords.readTasks(),
          'final format-scoped task records',
        );
        expect(tasks.map((row) => row['key']), [mp4Task]);
        expect(tasks.single['resourceId'], mp4ID);
        await tester.runAsync(() async {
          expect(await mp4.readAsBytes(), orderedEquals(originalMP4));
          expect(await index.readAsBytes(), orderedEquals(originalIndex));
        });
        final pins = await finish(DownloadWorkPins.read(), 'remaining MP4 pin');
        expect(pins['video:$mp4ID'], isNotNull);
        expect(pins['video:$hlsID'], pins['video:$mp4ID']);
        // Exercise the committed service path with no mounted download center.
        await tester.pumpWidget(const SizedBox.shrink());
        await finish(
          removeVideoDownload(source: source, page: page, quality: quality),
          'remove the last remaining format',
        );
        expect(
          await finish(DownloadWorkPins.read(), 'last member pin cleanup'),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await until(
          () => nativeViews.isEmpty,
          'native views dispose before mock channels close',
        );
        await finish(VideoExportRecords.flush(), 'terminal task write drain');
        await finish(VideoLocalResources.read(), 'managed resource read drain');
        messenger.setMockMethodCallHandler(VideoHlsAssets.channel, null);
        messenger.setMockMethodCallHandler(exportChannel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in viewChannels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        debugDefaultTargetPlatformOverride = previousPlatform;
        style.dispose();
      }
    },
  );
}
