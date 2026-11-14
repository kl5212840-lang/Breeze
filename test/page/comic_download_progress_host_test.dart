import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';
import '../download_fixture.dart';

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    DownloadResourceMetrics.instance.invalidateAll();
    expect(await DownloadCenterResources.readVideos(), isEmpty);
  });
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });
  for (final style in ['system', 'breeze']) {
    testWidgets(
      'comic work progress, written bytes and root chapter navigation stay real: $style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style),
            tabs = PersistentTabController(initialIndex: 1);
        addTearDown(preference.dispose);
        addTearDown(tabs.dispose);
        final source = 'comic-progress-$style';
        const work = 'work';
        final payload = DownloadTaskJson(
          from: source,
          comicId: work,
          comicName: 'Selected work',
          stateCode: 'running',
          completedImages: 2,
          totalImages: 4,
          imagePaths: ['written.jpg'],
          chapterRef: const DownloadChapterTaskRef(
            logicalKey: 'logical-one',
            chapterId: 'request-one',
            storageChapterId: 'storage-one',
            title: 'First chapter',
          ),
        );
        final first = DownloadTask()
          ..comicId = work
          ..comicName = 'Selected work'
          ..isDownloading = true
          ..taskInfo = payload;
        final second = DownloadTask()
          ..comicId = work
          ..comicName = 'Selected work'
          ..taskInfo = payload.copyWith(
            stateCode: 'queued',
            completedImages: 0,
            totalImages: 0,
            imagePaths: [],
            chapterRef: const DownloadChapterTaskRef(
              logicalKey: 'logical-two',
              title: 'Second chapter',
            ),
          );
        await tester.runAsync(() async {
          objectbox.downloadTaskBox.putMany([first, second]);
          final store = DownloadAssetStore(
            from: source,
            cartoonId: work,
            chapterId: 'logical-one',
            storageChapterId: 'storage-one',
            path: 'written.jpg',
            pictureType: PictureType.page,
          );
          final file = File((await store.canonicalDownloadCandidate()).path);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(List.filled(4096, 7));
        });
        try {
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.7)),
                  child: child!,
                ),
                home: MainNativeTabHost(
                  controller: tabs,
                  screens: const [
                    SizedBox.shrink(),
                    DownloadTaskPage(embedded: true),
                  ],
                  navBarHeight: 84,
                  navigation: const SizedBox(
                    key: ValueKey('main-download-nav'),
                    height: 84,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('Main navigation')),
                    ),
                  ),
                ),
              ),
            ),
          );
          final workProgress = find.byKey(
            ValueKey('download-work-progress.comic:$source:$work'),
          );
          await _until(
            tester,
            () => workProgress.evaluate().isNotEmpty,
            'The real main Downloads projects the queued and running chapter before any commit',
          );
          expect(
            tester.widget<LinearProgressIndicator>(workProgress).value,
            .25,
          );
          expect(find.text('0 of 2 chapters completed'), findsOneWidget);
          await _until(
            tester,
            () => find.text('≥ 4.0 KB').evaluate().isNotEmpty,
            'The real written file is measurable before a UnifiedComicDownload row exists',
          );
          expect(objectbox.unifiedDownloadBox.count(), 0);
          expect(
            find.byKey(const ValueKey('main-download-nav')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.text('Selected work'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final summary = find.byKey(
            const ValueKey('download-chapters-summary'),
          );
          await _until(
            tester,
            () => summary.evaluate().isNotEmpty,
            'The work opens its root chapter page',
          );
          expect(
            find.byKey(const ValueKey('main-download-nav')).hitTestable(),
            findsNothing,
            reason: 'The work interior covers the main bottom navigation',
          );
          final chapterProgress = find.byKey(
            ValueKey('download-chapter-progress.task:${first.id}'),
          );
          await tester.ensureVisible(chapterProgress);
          await tester.pump();
          expect(
            tester.widget<LinearProgressIndicator>(chapterProgress).value,
            .5,
          );
          await _until(
            tester,
            () => tester
                .widget<Text>(
                  find.byKey(
                    ValueKey('download-chapter-size.task:${first.id}'),
                  ),
                )
                .data!
                .contains('4.0 KB'),
            'The chapter uses the exact logical/request alias and actual disk bytes',
          );
          first.taskInfo = payload.copyWith(completedImages: 3);
          objectbox.downloadTaskBox.put(first);
          await _until(
            tester,
            () =>
                tester.widget<LinearProgressIndicator>(chapterProgress).value ==
                .75,
            'The active chapter advances from two to three of its four pages',
          );
          Navigator.of(tester.element(summary)).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            tester.widget<LinearProgressIndicator>(workProgress).value,
            .375,
            reason: 'The outer work summary includes its queued sibling.',
          );
          expect(
            find.text('0 of 2 chapters completed'),
            findsOneWidget,
            reason: 'Partial image progress does not complete a chapter.',
          );
          first.taskInfo = payload.copyWith(
            stateCode: 'completed',
            completedImages: 4,
          );
          first.isDownloading = false;
          first.isCompleted = true;
          objectbox.unifiedDownloadBox.put(
            createTestDownload('$source:$work')
              ..source = source
              ..comicId = work
              ..title = 'Selected work'
              ..chapters = jsonEncode([
                {
                  'id': 'logical-one',
                  'logicalKey': 'logical-one',
                  'requestId': 'request-one',
                  'storageChapterId': 'storage-one',
                  'name': 'First chapter',
                  'order': 1,
                  'images': [
                    {'path': 'written.jpg'},
                  ],
                },
              ]),
          );
          objectbox.downloadTaskBox.put(first);
          await _until(
            tester,
            () =>
                tester.widget<LinearProgressIndicator>(workProgress).value ==
                .5,
            'Completing one chapter advances the work to one of two chapters',
          );
          expect(find.text('1 of 2 chapters completed'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('main-download-nav')).hitTestable(),
            findsOneWidget,
          );
          expect(objectbox.downloadTaskBox.count(), 2);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
          final resource = DownloadCenterResources.readComics().firstOrNull;
          if (resource != null) {
            // Drain the final reads after unmounting. Their continuations need
            // this test's fake clock before the other style can use the queue.
            final metrics = DownloadResourceMetrics.instance;
            metrics.invalidate(resource.key);
            var finished = false;
            Future.wait([
              metrics.readComicProgress(
                source: source,
                comicId: work,
                resource: resource,
                tasks: [first.taskInfo!, second.taskInfo!],
              ),
              metrics.readComic(resource),
            ]).then((_) => finished = true);
            await _until(tester, () => finished, 'Final disk reads finish');
          }
          await tester.runAsync(() async {
            await DownloadCenterResources.readVideos();
          });
        }
      },
    );
  }
}
