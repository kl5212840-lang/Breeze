import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/migration/migration_v9_to_v10.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const source = 'download-center-upgrade';
const comicId = 'old-work';
const title = '升级前已保存的本地漫画';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  testWidgets(
    'resume and chapter taps work again after a reader replaces its route',
    (tester) async {
      await tester.runAsync(useIsolatedDownloadFixture);
      final saved = createTestDownload('$source:$comicId')
        ..source = source
        ..comicId = comicId
        ..title = title
        ..chapters = jsonEncode([
          for (final order in [11, 12])
            {
              'id': 'chapter-$order',
              'logicalKey': 'chapter-$order',
              'name': 'Chapter $order',
              'order': order,
              'images': [
                {'path': 'page.jpg'},
              ],
            },
        ]);
      objectbox.unifiedDownloadBox.put(saved);
      objectbox.unifiedHistoryBox.put(
        createTestHistory('$source:$comicId')
          ..source = source
          ..comicId = comicId
          ..chapterId = 'chapter-12'
          ..chapterTitle = 'Chapter 12'
          ..pageIndex = 2,
      );
      final opened = <ComicReadRouteArgs>[];
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'DownloadsHost',
            path: '/',
            initial: true,
            builder: (_, _) => const DownloadTaskPage(),
          ),
          NamedRouteDef(
            name: ComicReadRoute.name,
            path: '/comic',
            builder: (_, data) {
              final args = data.argsAs<ComicReadRouteArgs>();
              opened.add(args);
              return Scaffold(body: Text('reader ${args.chapterId}'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      Future<void> tapAndWait(Finder finder, Finder result) async {
        await waitFor(tester, () => finder.hitTestable().evaluate().isNotEmpty);
        await tester.tap(finder.hitTestable().first);
        await waitFor(tester, () => result.hitTestable().evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 400));
      }

      final resume = find.byKey(const ValueKey('download-resume-entry'));
      await tapAndWait(find.text(title), resume);
      final chapter = find.byKey(
        const ValueKey('download-chapter-open.chapter-11'),
      );
      await tapAndWait(chapter, find.text('reader chapter-11'));
      final first = opened.last;
      unawaited(
        router.replace(
          ComicReadRoute(
            comicId: comicId,
            from: source,
            comicInfo: first.comicInfo,
            type: ComicEntryType.download,
            order: 12,
            chapterId: 'chapter-12',
            epsNumber: 2,
            stringSelectCubit: first.stringSelectCubit,
          ),
        ),
      );
      await waitFor(
        tester,
        () => find.text('reader chapter-12').evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 400));
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tapAndWait(resume, find.text('reader chapter-12'));
      expect(opened.last.logicalKey, 'chapter-12');
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tapAndWait(chapter, find.text('reader chapter-11'));
      expect(opened.last.logicalKey, 'chapter-11');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test(
    'early transfers are independent of the storage verification queue',
    () async {
      await useIsolatedDownloadFixture();
      final prefs = await SharedPreferences.getInstance();
      const taskKey = VideoExportRecords.taskStorageKey;
      final before = prefs.getString(taskKey);
      addTearDown(() async {
        await VideoExportRecords.flush();
        final restored = before == null
            ? await prefs.remove(taskKey)
            : await prefs.setString(taskKey, before);
        expect(restored, isTrue);
      });
      const source = 'early-transfer-inventory';
      final keys = <String, String>{};
      for (final (index, status) in ['failed', 'saved', 'cancelled'].indexed) {
        final key = await VideoExportRecords.beginTransfer(
          source: source,
          video: Uri.parse('https://fixture.invalid/watch?v=${index + 1}'),
          title: status,
          quality: '720p',
        );
        keys[status] = key;
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: status,
          terminal: true,
        );
      }
      final entered = Completer<void>();
      final release = Completer<void>();
      final hold = runExclusiveStorageOperation(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final read = DownloadCenterResources.readVideoPhases(fresh: true);
      try {
        final early = read.readTransfers();
        expect(read.readTransfers(), same(early));
        final rows = await early.timeout(const Duration(seconds: 2));
        expect(
          rows.where((row) => row['source'] == source).map((row) => row['key']),
          [keys['failed']],
        );
      } finally {
        release.complete();
        await hold;
        await read.enriched;
      }
    },
  );

  test('manual verification bypasses the managed MP4 index snapshot', () async {
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    const source = 'manual-download-verification';
    final url = Uri.parse('https://hanime1.me/watch?v=1234');
    final id = VideoLocalResources.identity(source, url, '720p');
    final taskKey = await VideoExportRecords.beginTransfer(
      source: source,
      video: url,
      title: 'Checked download',
      quality: '720p',
      resourceId: id,
    );
    final file = await VideoLocalResources.file(id);
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
      resourceId: id,
      bytes: 24,
      source: source,
      video: url,
      title: 'Checked download',
      quality: '720p',
      taskKey: taskKey,
    );
    await VideoExportRecords.updateTransfer(
      taskKey,
      received: 24,
      status: 'saved',
      terminal: true,
      resourceId: id,
    );
    expect(
      (await DownloadCenterResources.readVideos()).single['available'],
      isTrue,
    );

    // Simulate an external file loss without an in-app change notification.
    await file.delete();
    expect(
      (await DownloadCenterResources.readVideos()).single['available'],
      isTrue,
    );
    final fresh = await DownloadCenterResources.readVideos(fresh: true);
    expect(
      fresh.any((row) => row['resourceId'] == id && row['available'] == true),
      isFalse,
    );
  });

  test(
    'actual task migration leaves resources discoverable without rewriting source records',
    () async {
      await useIsolatedDownloadFixture();
      final directory = await createDownloadFixture(source, comicId);
      final page = await File(
        '${directory.path}/page.png',
      ).writeAsString('original bytes');
      final record = createTestDownload('$source:$comicId')
        ..source = source
        ..comicId = comicId
        ..title = title;
      objectbox.unifiedDownloadBox.put(record);
      objectbox.downloadTaskBox.put(DownloadTask()..comicId = comicId);
      await migrateV9ToV10();
      expect(objectbox.downloadTaskBox.count(), 0);
      expect(DownloadCenterResources.readComics().single.title, title);
      expect(await page.readAsString(), 'original bytes');
      expect(
        objectbox.unifiedDownloadBox
            .get(record.id)!
            .updatedAt
            .millisecondsSinceEpoch,
        record.updatedAt.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'managed resources survive task clearing; missing files stay outside the center',
    () async {
      SharedPreferences.setMockInitialValues({});
      await useIsolatedDownloadFixture();
      VideoLocalResources.invalidate();
      final url = Uri.parse('https://hanime1.me/watch?v=51');
      final id = VideoLocalResources.identity(source, url, '720p');
      final key = await VideoExportRecords.beginTransfer(
        source: source,
        video: url,
        title: title,
        quality: '720p',
        resourceId: id,
      );
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]),
      );
      await VideoLocalResources.saved(
        resourceId: id,
        bytes: 24,
        source: source,
        video: url,
        title: title,
        quality: '720p',
        taskKey: key,
      );
      await VideoExportRecords.updateTransfer(
        key,
        received: 24,
        status: 'saved',
        terminal: true,
        resourceId: id,
      );
      expect(
        (await DownloadCenterResources.readVideos()).where(
          (row) => row['resourceId'] == id,
        ),
        hasLength(1),
      );
      await VideoLocalResources.remove(id);
      var rows = await DownloadCenterResources.readVideos();
      expect(rows, isEmpty);
      expect(
        (await VideoExportRecords.readTasks()).single['fileRemoved'],
        isTrue,
      );
      // Recreate the device-owned file, then clear only its transfer log.
      await file.writeAsBytes(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]),
      );
      await VideoLocalResources.saved(
        resourceId: id,
        bytes: 24,
        source: source,
        video: url,
        title: title,
        quality: '720p',
        taskKey: key,
      );
      await VideoExportRecords.clearTaskRecords({key});
      rows = await DownloadCenterResources.readVideos();
      expect(rows, hasLength(1));
      expect(rows.single['resourceOnly'], isTrue);
      expect(await file.exists(), isTrue);
      expect((await VideoLocalResources.read()).single['available'], isTrue);
      await file.writeAsString('damaged');
      VideoLocalResources.invalidate();
      rows = await DownloadCenterResources.readVideos();
      expect(rows.single['resourceOnly'], isTrue);
      expect(rows.single['fileInvalid'], isTrue);
      expect(await file.exists(), isTrue);
    },
  );

  test(
    'repeated successful managed transfers merge their clearable keys without hiding removed or external evidence',
    () {
      final tasks = <Map<String, dynamic>>[
        {
          'key': 'new',
          'resourceId': 'managed-id',
          'local': true,
          'status': 'saved',
          'at': 3,
        },
        {
          'key': 'old',
          'resourceId': 'managed-id',
          'local': true,
          'status': 'saved',
          'at': 2,
        },
        {
          'key': 'removed',
          'resourceId': 'removed-id',
          'local': true,
          'status': 'saved',
          'fileRemoved': true,
          'at': 1,
        },
        {'key': 'export', 'status': 'saved', 'at': 0},
      ];
      final rows = DownloadCenterResources.mergeVideos(tasks, [
        {'resourceId': 'managed-id', 'available': true, 'at': 3, 'bytes': 24},
        {'resourceId': 'missing-id', 'available': false, 'at': 1, 'bytes': 24},
      ]);
      expect(rows, hasLength(3));
      expect(rows.first['recordKeys'], ['new', 'old']);
      expect(rows[1]['fileRemoved'], isTrue);
      expect(
        rows.last.containsKey('local'),
        isFalse,
        reason: 'an external export is not a managed file',
      );
      expect(
        tasks.first.containsKey('recordKeys'),
        isFalse,
        reason: 'aggregation never mutates stored input',
      );
    },
  );

  test(
    'resource snapshot excludes tombstones and separates source identities',
    () {
      for (final src in [source, 'another-source']) {
        objectbox.unifiedDownloadBox.put(
          createTestDownload('$src:$comicId')
            ..source = src
            ..comicId = comicId,
        );
      }
      objectbox.unifiedDownloadBox.put(
        createTestDownload('deleted:$comicId')
          ..source = 'deleted'
          ..comicId = comicId
          ..deleted = true,
      );
      expect(
        DownloadCenterResources.readComics().map((row) => row.key).toSet(),
        {'$source:$comicId', 'another-source:$comicId'},
      );
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'upgrade resource without task remains visible: $style $brightness',
        (tester) async {
          late Directory resourceDirectory;
          await tester.runAsync(() async {
            await useIsolatedDownloadFixture();
            resourceDirectory = await createDownloadFixture(source, comicId);
            await File(
              '${resourceDirectory.path}/page.png',
            ).writeAsString('saved image');
            objectbox.unifiedDownloadBox.put(
              createTestDownload('$source:$comicId')
                ..source = source
                ..comicId = comicId
                ..title = title
                ..chapters = jsonEncode([
                  {
                    'id': '1',
                    'logicalKey': '1',
                    'name': '保存章节',
                    'order': 1,
                    'images': [
                      {'id': 'page', 'path': 'page.png', 'url': ''},
                    ],
                  },
                ]),
            );
            ComicLinkService.addComic(
              '$source:$comicId',
              null,
              ComicFolderType.download,
            );
            objectbox.unifiedFavoriteBox.put(
              createTestFavorite('$source:$comicId'),
            );
            objectbox.unifiedHistoryBox.put(
              createTestHistory('$source:$comicId'),
            );
          });
          final notifier = ValueNotifier(style);
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            notifier.dispose();
          });
          final previousPlatform = debugDefaultTargetPlatformOverride;
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          try {
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            final channels = <MethodChannel>[];
            final nativeViews = <int>{};
            messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
              call,
            ) async {
              if (call.method == 'create') {
                final args = call.arguments as Map;
                nativeViews.add(args['id'] as int);
                final channel = MethodChannel(
                  '${args['viewType']}.${args['id']}',
                );
                channels.add(channel);
                messenger.setMockMethodCallHandler(channel, (_) async => null);
              } else if (call.method == 'dispose') {
                nativeViews.remove(call.arguments as int);
              }
              return null;
            });
            addTearDown(() {
              debugDefaultTargetPlatformOverride = previousPlatform;
              messenger.setMockMethodCallHandler(
                SystemChannels.platform_views,
                null,
              );
              for (final channel in channels)
                messenger.setMockMethodCallHandler(channel, null);
            });
            ComicReadRouteArgs? opened;
            final router = RootStackRouter.build(
              routes: [
                NamedRouteDef(
                  name: 'DownloadsHost',
                  path: '/',
                  initial: true,
                  builder: (_, _) => const DownloadTaskPage(),
                ),
                NamedRouteDef(
                  name: ComicReadRoute.name,
                  path: '/comic',
                  builder: (_, data) {
                    opened = data.argsAs<ComicReadRouteArgs>();
                    return const Scaffold(body: Text('offline-detail'));
                  },
                ),
              ],
            );
            addTearDown(router.dispose);
            // Unmount even when an assertion fails, while the native host and
            // per-view channels still exist. Framework cleanup runs later.
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await waitFor(tester, () => nativeViews.isEmpty);
            });
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: notifier,
                child: MaterialApp.router(
                  routerConfig: router.config(),
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.7)),
                    child: child!,
                  ),
                ),
              ),
            );
            await waitFor(tester, () => find.text(title).evaluate().isNotEmpty);
            expect(
              find.byType(NativeVideoSegmentedControl),
              findsOneWidget,
              reason:
                  'media scope is shared; download statuses stay in one list',
            );
            expect(
              find.byKey(const ValueKey('download-clear-records')),
              findsNothing,
            );
            expect(find.text(title), findsOneWidget);
            await tester.tap(find.text(title));
            await waitFor(
              tester,
              () => find.text('offline-detail').evaluate().isNotEmpty,
            );
            expect(find.text('offline-detail'), findsOneWidget);
            expect(opened?.comicId, comicId);
            expect(opened?.from, source);
            expect(opened?.type, ComicEntryType.download);
            await router.maybePop();
            await waitFor(tester, () => find.text(title).evaluate().isNotEmpty);
            await tester.pump(const Duration(milliseconds: 350));
            expect(
              objectbox.downloadTaskBox.count(),
              0,
              reason: 'resources never fabricate completed tasks',
            );
            await tester.runAsync(() async {
              objectbox.downloadTaskBox.put(
                DownloadTask()
                  ..comicId = comicId
                  ..comicName = title
                  ..isCompleted = true
                  ..taskInfo = const DownloadTaskJson(
                    from: source,
                    comicId: comicId,
                    comicName: title,
                    stateCode: 'completed',
                    chapterRef: DownloadChapterTaskRef(
                      chapterId: '1',
                      title: '保存章节',
                    ),
                  ),
              );
            });
            await waitFor(tester, () => objectbox.downloadTaskBox.count() == 1);
            expect(
              find.text(title),
              findsOneWidget,
              reason:
                  'existing task and persistent resource share one work row',
            );
            final deleteResource = find.byKey(
              const ValueKey('download-swipe.comic:$source:$comicId.delete'),
            );
            Future<void> openDeleteConfirmation() async {
              await tester.drag(find.text(title), const Offset(-220, 0));
              await waitFor(
                tester,
                () => deleteResource.hitTestable().evaluate().isNotEmpty,
              );
              expect(find.byType(AlertDialog), findsNothing);
              await tester.tap(deleteResource.hitTestable());
              await waitFor(
                tester,
                () => find.byType(AlertDialog).evaluate().isNotEmpty,
              );
              await tester.pump(const Duration(milliseconds: 350));
            }

            await openDeleteConfirmation();
            await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
            await waitFor(
              tester,
              () => find.byType(AlertDialog).evaluate().isEmpty,
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(objectbox.unifiedDownloadBox.count(), 1);
            expect(objectbox.downloadTaskBox.count(), 1);
            expect(await tester.runAsync(resourceDirectory.exists), isTrue);
            await openDeleteConfirmation();
            await tester.tap(find.widgetWithText(TextButton, t.common.delete));
            await waitFor(
              tester,
              () =>
                  objectbox.unifiedDownloadBox.count() == 0 &&
                  objectbox.downloadTaskBox.count() == 0 &&
                  find.text(title).evaluate().isEmpty,
            );
            expect(await tester.runAsync(resourceDirectory.exists), isFalse);
            expect(
              ComicLinkService.linksOfComic(
                '$source:$comicId',
                ComicFolderType.download,
              ),
              isEmpty,
            );
            expect(objectbox.unifiedFavoriteBox.count(), 1);
            expect(objectbox.unifiedHistoryBox.count(), 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            var drained = false;
            DownloadCenterResources.readVideos().then((_) => drained = true);
            await waitFor(tester, () => drained);
          } finally {
            debugDefaultTargetPlatformOverride = previousPlatform;
          }
        },
      );
    }
  }
}
