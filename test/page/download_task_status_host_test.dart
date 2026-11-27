import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'dart:async';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:auto_route/auto_route.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:flutter/services.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/view/download_card_details.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/page/donwload_task/view/download_task_entry.dart';
import 'package:zephyr/page/donwload_task/view/download_work_sections.dart';
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_completion_notice.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/work_list_divider.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/type/enum.dart';

import '../test_helper.dart';
import '../download_fixture.dart';
import '../ui_preview_helper.dart';

Finder _chapterList(DownloadWorkPane pane) =>
    find.byKey(PageStorageKey(('download-chapters-list', pane)));

Finder _workPane(DownloadWorkPane pane) => find.descendant(
  of: find.byKey(const ValueKey('download-work-pane')),
  matching: find.text(pane == DownloadWorkPane.saved ? 'Downloaded' : 'Tasks'),
);

Future<void> _enterDownloadManagement(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('download-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(t.bookshelf.manage).hitTestable());
  await tester.pumpAndSettle();
}

class _DownloadRouteHost extends AppRouter {
  _DownloadRouteHost(this.home);

  final Widget home;

  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: 'NavigationBar',
      path: '/',
      initial: true,
      builder: (_, _) => home,
    ),
  ];
}

class _DownloadRouteObserver extends NavigatorObserver {
  final pushes = <PageRoute<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) pushes.add(route);
  }
}

class _DelayedDownloadNoticeStore extends InMemorySharedPreferencesStore {
  _DelayedDownloadNoticeStore(this.previous) : super.empty();

  final SharedPreferencesStorePlatform previous;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${DownloadCompletionNotice.storageKey}') {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    return previous.setValue(valueType, key, value);
  }
}

DownloadTask _task(String name, String state) => DownloadTask()
  ..comicId = name
  ..comicName = name
  ..isDownloading = state == 'downloading'
  ..isCompleted = state == 'completed'
  ..taskInfo = DownloadTaskJson(
    from: 'offline-download-fixture',
    comicId: name,
    comicName: name,
    stateCode: state,
    completedImages: state == 'completed' ? 10 : 3,
    totalImages: 10,
    lastErrorMessage: state == 'failed' ? '测试下载失败' : '',
    chapterRef: const DownloadChapterTaskRef(
      chapterId: 'chapter-1',
      title: '第一话',
      order: 1,
    ),
  );

Future<File> _saveComicResource(
  DownloadTask task, {
  int bytes = 2048,
  DateTime? downloadedAt,
}) async {
  final payload = task.taskInfo!;
  final chapter = payload.chapterRef;
  const path = 'completed-page.jpg';
  final store = DownloadAssetStore(
    from: payload.from,
    cartoonId: payload.comicId,
    chapterId: chapter.chapterId,
    storageChapterId: chapter.chapterId,
    path: path,
    pictureType: PictureType.page,
  );
  final file = File((await store.canonicalDownloadCandidate()).path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List.filled(bytes, 7));
  final record =
      createTestDownload(buildDownloadTaskKey(payload.from, payload.comicId))
        ..source = payload.from
        ..comicId = payload.comicId
        ..title = task.comicName
        ..chapters = jsonEncode([
          {
            'id': chapter.chapterId,
            'logicalKey': chapter.chapterId,
            'storageChapterId': chapter.chapterId,
            'name': chapter.title,
            'order': chapter.order,
            'images': [
              {'path': path},
            ],
          },
        ]);
  if (downloadedAt != null) record.downloadedAt = downloadedAt;
  objectbox.unifiedDownloadBox.put(record);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // The singleton caches this future. Initialize it outside any test's
    // FakeAsync clock so a later widget can use the same admission state.
    await DownloadAdmission.instance.initializeQueueState();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    // Initialize the real, empty device index before any fake widget clock
    // owns filesystem futures or the shared storage operation queue.
    expect(await DownloadCenterResources.readVideos(), isEmpty);
  });
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  test(
    'completion history does not auto-disappear and explicit clearing leaves media intact',
    () async {
      final tasks = [for (var i = 0; i < 250; i++) _task('完成$i', 'completed')];
      objectbox.downloadTaskBox.putMany(tasks);
      final media = createTestDownload('offline-download-fixture|完成0');
      objectbox.unifiedDownloadBox.put(media);
      expect(const DownloadTaskRepository().getAll(), hasLength(250));
      await const DownloadTaskRepository().removeRecords([tasks.first.id]);
      expect(objectbox.downloadTaskBox.count(), 249);
      expect(objectbox.unifiedDownloadBox.get(media.id), isNotNull);
    },
  );

  test(
    'retained completed/cancelled identity never shadows a newer chapter task',
    () {
      const repository = DownloadTaskRepository();
      final old = _task('同一作品', 'completed');
      objectbox.downloadTaskBox.put(old);
      final key = old.taskInfo!.taskKey;
      expect(repository.findByTaskKey(key)!.id, old.id);
      final current = _task('同一作品', 'queued');
      objectbox.downloadTaskBox.put(current);
      expect(repository.findByTaskKey(key)!.id, current.id);
      expect(
        repository.findByTaskKey(key, incompleteOnly: true)!.id,
        current.id,
      );
      expect(
        objectbox.downloadTaskBox.get(old.id)!.taskInfo!.stateCode,
        'completed',
      );
    },
  );

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
    // Start an exit requested by a modal completion before advancing its
    // animation; the first frame alone can establish its start timestamp.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> openRowActions(WidgetTester tester, String key) async {
    final more = find.byKey(ValueKey('download-row-more.$key'));
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await settleHost(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  Future<void> settleRowMenuSelection(WidgetTester tester) async {
    // The menu releases its input barrier before invoking a row command.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await settleHost(tester);
  }

  Future<void> waitForRemovalDialog(WidgetTester tester) async {
    final dialog = find.byType(AlertDialog).hitTestable();
    final elapsed = Stopwatch()..start();
    while (dialog.evaluate().isEmpty &&
        elapsed.elapsed < const Duration(seconds: 5)) {
      await settleHost(tester);
    }
    expect(dialog, findsOneWidget);
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
      // File measurements and follow-up storage reads can outlive the page.
      // Drain both while their FakeAsync callbacks can still run.
      final metrics = DownloadResourceMetrics.instance;
      final elapsed = Stopwatch()..start();
      while ((metrics.measuring || syncStorageOperations.busy.value) &&
          elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        metrics.measuring,
        isFalse,
        reason: 'File measurements must drain.',
      );
      expect(
        syncStorageOperations.busy.value,
        isFalse,
        reason: 'Pending storage reads must finish before the next host.',
      );
    }
  }

  testWidgets(
    'long mixed download work manages exact chapters and keeps partial pages in both styles',
    (tester) async {
      // Completion acknowledgments share an async write queue. Run both
      // real work-page visits under the same widget-test clock.
      for (final style in ['breeze', 'system']) {
        await runHost(tester, () async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          int? nativeBackId;
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              if (args['viewType'] != 'breeze.video.control') return null;
              if (args['params'] case final Uint8List params) {
                final config =
                    const StandardMessageCodec().decodeMessage(
                          ByteData.sublistView(params),
                        )
                        as Map;
                if (config['symbol'] == 'chevron.left') {
                  nativeBackId = args['id'] as int;
                }
              }
            }
            return null;
          });
          Future<void> pressBack() async {
            if (style == 'breeze') {
              await tester.tap(find.byType(BackButton).hitTestable());
              return;
            }
            expect(nativeBackId, isNotNull);
            await messenger.handlePlatformMessage(
              'breeze.video.control.$nativeBackId',
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall('press'),
              ),
              (_) {},
            );
          }

          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
          });
          const source = 'offline-download-fixture';
          final title = '205 chapter work $style';
          final workKey = '$source:$title';
          const partialPath = 'partial-page.jpg';
          const completedPath = 'offline-page.jpg';
          DownloadTask task(int chapter, String state, {String? partial}) =>
              DownloadTask()
                ..comicId = title
                ..comicName = title
                ..isDownloading = state == 'running'
                ..status = state == 'running'
                    ? t.download.downloading
                    : t.download.statusWaiting
                ..taskInfo = DownloadTaskJson(
                  from: source,
                  comicId: title,
                  comicName: title,
                  stateCode: state,
                  phaseCode: state == 'running' ? 'downloadingChapter' : '',
                  attempt: state == 'running' ? 1 : 0,
                  completedImages: partial == null ? 0 : 1,
                  totalImages: 5,
                  imagePaths: [?partial],
                  chapterRef: DownloadChapterTaskRef(
                    chapterId: 'request-$chapter',
                    storageChapterId: 'stored-$chapter',
                    logicalKey: 'chapter-$chapter',
                    title: 'Chapter $chapter',
                    order: chapter,
                  ),
                );
          final active = task(1, 'running', partial: partialPath);
          final second = task(2, 'queued');
          final untouched = task(3, 'queued');
          objectbox.downloadTaskBox.putMany([active, second, untouched]);
          final resource = createTestDownload(workKey)
            ..source = source
            ..comicId = title
            ..title = title
            ..chapters = jsonEncode([
              for (var chapter = 4; chapter <= 205; chapter++)
                {
                  'id': 'chapter-$chapter',
                  'logicalKey': 'chapter-$chapter',
                  'name': 'Offline chapter $chapter',
                  'order': chapter,
                  'images': [
                    if (chapter == 201) {'path': completedPath},
                  ],
                },
            ]);
          objectbox.unifiedDownloadBox.put(resource);
          final favorite = createTestFavorite(workKey);
          final history = createTestHistory(workKey);
          objectbox.unifiedFavoriteBox.put(favorite);
          objectbox.unifiedHistoryBox.put(history);
          Future<File> savePage(
            String chapter,
            String storageChapter,
            String path,
            List<int> bytes,
          ) async {
            final store = DownloadAssetStore(
              from: source,
              cartoonId: title,
              chapterId: chapter,
              storageChapterId: storageChapter,
              path: path,
              pictureType: PictureType.page,
            );
            final page = File((await store.canonicalDownloadCandidate()).path);
            await page.parent.create(recursive: true);
            await page.writeAsBytes(bytes);
            return page;
          }

          final files = (await tester.runAsync(() async {
            return (
              partial: await savePage('chapter-1', 'stored-1', partialPath, [
                1,
                2,
                3,
                4,
              ]),
              offline: await savePage(
                'chapter-201',
                'chapter-201',
                completedPath,
                [7, 8, 9],
              ),
            );
          }))!;

          tester.view.physicalSize = const Size(340, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: style == 'breeze'
                      ? Brightness.dark
                      : Brightness.light,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.35)),
                  child: child!,
                ),
                home: const DownloadTaskPage(),
              ),
            ),
          );
          await settleHost(tester);

          final work = find.byKey(ValueKey('download-open.comic:$workKey'));
          final list = _chapterList(DownloadWorkPane.active);
          final manage = find.byKey(const ValueKey('download-episodes-manage'));
          final pause = find.byKey(const ValueKey('download-episodes-pause'));
          final resume = find.byKey(const ValueKey('download-episodes-resume'));
          final delete = find.byKey(const ValueKey('download-episodes-delete'));
          final chapterPause = find.byKey(
            ValueKey('download-chapter-pause.task:${active.id}'),
          );
          final chapterResume = find.byKey(
            ValueKey('download-chapter-resume.task:${active.id}'),
          );
          Finder chapter(int index) {
            final attempt = {1: active, 2: second, 3: untouched}[index];
            final key = attempt == null
                ? 'chapter-$index'
                : 'task:${attempt.id}';
            return find.byKey(ValueKey('download-chapter-open.$key'));
          }

          Finder status(int index, String label) => find.descendant(
            of: chapter(index),
            matching: find.textContaining(label),
          );
          DownloadTaskJson stored(DownloadTask task) =>
              objectbox.downloadTaskBox.get(task.id)!.taskInfo!;
          void expectPartial() {
            expect(stored(active).completedImages, 1);
            expect(stored(active).imagePaths, [partialPath]);
            expect(files.partial.readAsBytesSync(), [1, 2, 3, 4]);
          }

          Future<void> tap(Finder finder) async {
            expect(finder.hitTestable(), findsOneWidget);
            await tester.tap(finder.hitTestable());
            await settleHost(tester);
          }

          Future<void> revealChapter(int index) async {
            final row = chapter(index);
            if (row.evaluate().isEmpty) {
              final scrollable = find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first;
              final position = tester
                  .state<ScrollableState>(scrollable)
                  .position;
              if (position.pixels > 0) {
                await tester.drag(list, Offset(0, position.pixels + 80));
                await settleHost(tester);
              }
              if (row.evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  row,
                  90,
                  scrollable: scrollable,
                  maxScrolls: 6,
                );
              }
            }
            await tester.ensureVisible(row);
            await settleHost(tester);
          }

          Future<void> selectChapter(int index) async {
            await revealChapter(index);
            await tap(chapter(index));
          }

          Future<void> expectVisibleStatus(int index, String label) async {
            await revealChapter(index);
            final rendered = status(index, label);
            for (
              var attempt = 0;
              attempt < 10 && rendered.evaluate().isEmpty;
              attempt++
            ) {
              await settleHost(tester);
            }
            expect(rendered, findsOneWidget);
          }

          Future<void> expectState(DownloadTask task, String state) async {
            for (
              var attempt = 0;
              attempt < 20 && stored(task).stateCode != state;
              attempt++
            ) {
              await settleHost(tester);
            }
            expect(stored(task).stateCode, state);
          }

          await tap(work);
          expect(_chapterList(DownloadWorkPane.saved), findsOneWidget);
          expect(chapter(201), findsOneWidget);
          expect(chapter(1), findsNothing);
          await tap(_workPane(DownloadWorkPane.active));
          expect(list, findsOneWidget);
          expect(chapter(201), findsNothing);
          await revealChapter(1);
          expect(
            find.descendant(
              of: chapter(1),
              matching: find.textContaining('20%'),
            ),
            findsOneWidget,
          );
          await expectVisibleStatus(2, t.download.statusWaiting);
          await revealChapter(1);
          expect(chapterPause.hitTestable(), findsOneWidget);
          final otherBefore = stored(untouched);
          final secondBefore = stored(second);

          await tap(manage);
          await selectChapter(1);
          expect(
            find.text(t.bookshelf.selectedCount(count: 1)),
            findsOneWidget,
          );
          expect(chapterPause.hitTestable(), findsNothing);
          expect(tester.widget<TextButton>(delete).onPressed, isNotNull);
          await tap(pause);
          await expectState(active, 'paused');
          expect(stored(active).phaseCode, 'userPaused');
          expect(stored(second), secondBefore);
          expect(stored(untouched), otherBefore);
          expectPartial();
          expect(
            find.text(t.bookshelf.selectedCount(count: 0)),
            findsOneWidget,
          );
          await selectChapter(1);
          await selectChapter(2);
          expect(
            find.text(t.bookshelf.selectedCount(count: 2)),
            findsOneWidget,
          );
          expect(pause.hitTestable(), findsOneWidget);
          expect(resume.hitTestable(), findsOneWidget);

          await tap(_workPane(DownloadWorkPane.saved));
          expect(chapter(1), findsNothing);
          expect(find.text(t.bookshelf.selectedCount(count: 2)), findsNothing);
          await tap(manage);
          expect(
            find.text(t.bookshelf.selectedCount(count: 0)),
            findsOneWidget,
          );
          expect(tester.widget<InkWell>(chapter(201)).onTap, isNull);
          await tap(_workPane(DownloadWorkPane.active));
          expect(chapter(201), findsNothing);
          expect(
            find.text(t.bookshelf.selectedCount(count: 2)),
            findsOneWidget,
          );
          await tap(_workPane(DownloadWorkPane.saved));
          expect(
            find.text(t.bookshelf.selectedCount(count: 0)),
            findsOneWidget,
          );
          await tap(manage);
          await tap(_workPane(DownloadWorkPane.active));

          // Exit management and the work page using Back. Returning to the
          // same work reads the paused state and the partial data again.
          await pressBack();
          await settleHost(tester);
          expect(list, findsOneWidget);
          await expectVisibleStatus(1, t.download.paused);
          final previous = SharedPreferencesStorePlatform.instance;
          final delayedNotice = _DelayedDownloadNoticeStore(previous);
          SharedPreferencesStorePlatform.instance = delayedNotice;
          try {
            await pressBack();
            await settleHost(tester);
            expect(delayedNotice.started.isCompleted, isTrue);
            await tap(work);
            await tap(_workPane(DownloadWorkPane.active));
            expect(
              list,
              findsOneWidget,
              reason:
                  'A pending completion acknowledgment cannot block reopening.',
            );
          } finally {
            delayedNotice.release.complete();
            SharedPreferencesStorePlatform.instance = previous;
            await settleHost(tester);
          }
          await expectVisibleStatus(1, t.download.paused);
          await tap(chapterResume);
          await expectState(active, 'queued');
          await expectVisibleStatus(1, t.download.statusWaiting);
          expect(stored(second), secondBefore);
          expect(stored(untouched), otherBefore);
          expectPartial();

          // Do a batch in the same work and continue the selected chapters.
          expect(list, findsOneWidget);
          await tap(manage);
          await selectChapter(1);
          await selectChapter(2);
          expect(
            find.text(t.bookshelf.selectedCount(count: 2)),
            findsOneWidget,
          );
          await tap(pause);
          await expectState(active, 'paused');
          await expectState(second, 'paused');
          expect(stored(untouched), otherBefore);
          expectPartial();
          await selectChapter(1);
          await selectChapter(2);
          await tap(resume);
          await expectState(active, 'queued');
          await expectState(second, 'queued');
          expect(stored(untouched), otherBefore);
          expectPartial();

          // The selected task can be removed without pausing the others.
          // Dismissing its confirmation preserves files and queued states.
          final othersBeforeDelete = [stored(second), stored(untouched)];
          await selectChapter(1);
          await tap(delete);
          final dialog = find.byType(AlertDialog);
          expect(
            find.descendant(
              of: dialog,
              matching: find.textContaining('Chapter 1'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: dialog,
              matching: find.textContaining('Chapter 2'),
            ),
            findsNothing,
          );
          Finder dialogButton(String label) => find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, label),
          );
          await tap(dialogButton(t.common.cancel));
          expectPartial();
          expect(list, findsOneWidget);
          await tap(delete);
          await tap(dialogButton(t.common.delete));
          for (
            var attempt = 0;
            attempt < 20 && objectbox.downloadTaskBox.get(active.id) != null;
            attempt++
          ) {
            await settleHost(tester);
          }
          expect(objectbox.downloadTaskBox.get(active.id), isNull);
          expect(files.partial.existsSync(), isFalse);
          expect(files.offline.readAsBytesSync(), [7, 8, 9]);
          expect([stored(second), stored(untouched)], othersBeforeDelete);
          expect(
            objectbox.unifiedDownloadBox.get(resource.id)!.chapters,
            resource.chapters,
          );
          expect(objectbox.unifiedFavoriteBox.get(favorite.id), isNotNull);
          expect(objectbox.unifiedHistoryBox.get(history.id), isNotNull);
          expect(list, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a previously paused queue offers only in-place recovery when jobs are waiting',
    (tester) => runHost(tester, () async {
      final admission = DownloadAdmission.instance;
      await tester.runAsync(
        () =>
            admission.setQueuePaused(true).timeout(const Duration(seconds: 3)),
      );
      addTearDown(() => admission.setQueuePaused(false));
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      final stopped = _task('Stopped download', 'paused');
      objectbox.downloadTaskBox.put(stopped);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: const MaterialApp(home: DownloadTaskPage()),
        ),
      );
      await settleHost(tester);

      final resumeQueue = find.byKey(const ValueKey('download-queue-resume'));
      expect(resumeQueue, findsNothing);
      await tester.tap(find.byKey(const ValueKey('download-more')));
      await settleHost(tester);
      expect(find.text(t.download.settings).hitTestable(), findsOneWidget);
      expect(find.text(t.download.pauseQueue), findsNothing);
      expect(find.text(t.download.resumeQueue), findsNothing);
      await tester.binding.handlePopRoute();
      await settleHost(tester);
      expect(find.text(t.download.settings).hitTestable(), findsNothing);

      final waiting = _task('Waiting download', 'queued');
      objectbox.downloadTaskBox.put(waiting);
      for (
        var attempt = 0;
        attempt < 20 && resumeQueue.evaluate().isEmpty;
        attempt++
      ) {
        await settleHost(tester);
      }
      expect(resumeQueue.hitTestable(), findsOneWidget);
      expect(find.text(waiting.comicName), findsOneWidget);
      await tester.tap(find.text(waiting.comicName));
      await settleHost(tester);
      final chapters = _chapterList(DownloadWorkPane.active);
      expect(chapters, findsOneWidget);
      final chapterResume = find.descendant(
        of: chapters,
        matching: resumeQueue,
      );
      expect(chapterResume.hitTestable(), findsOneWidget);
      expect(find.text(t.download.queuePaused).hitTestable(), findsOneWidget);
      preference.value = 'system';
      await settleHost(tester);
      expect(chapterResume.hitTestable(), findsOneWidget);
      await tester.tap(chapterResume);
      await settleHost(tester);
      expect(admission.queuePaused, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          DownloadAdmission.queuePauseKey,
        ),
        isNot(true),
      );
      expect(resumeQueue, findsNothing);
      expect(chapters, findsOneWidget);
      expect(
        objectbox.downloadTaskBox.get(waiting.id)!.taskInfo!.stateCode,
        'queued',
      );
      expect(
        objectbox.downloadTaskBox.get(stopped.id)!.taskInfo!.stateCode,
        'paused',
      );
      expect(tester.takeException(), isNull);
    }),
  );

  for (final style in ['breeze', 'system']) {
    testWidgets(
      'long offline work keeps comic management across chapter ranges: $style',
      (tester) => runHost(tester, () async {
        const source = 'offline-download-fixture', title = '长篇离线章节测试';
        final chapters = [
          for (var index = 1; index <= 65; index++)
            {
              'id': 'chapter-$index',
              'logicalKey': 'chapter-$index',
              'name': 'Chapter $index',
              'order': index,
              'groupTitle': index <= 60 ? 'First volume' : 'Final volume',
              'images': [
                {'path': index == 61 ? 'tail-page.jpg' : 'page.jpg'},
              ],
            },
        ];
        final record = createTestDownload(buildDownloadTaskKey(source, title))
          ..source = source
          ..comicId = title
          ..title = title
          ..chapters = jsonEncode(chapters);
        objectbox.unifiedDownloadBox.put(record);
        await tester.runAsync(() async {
          final store = DownloadAssetStore(
            from: source,
            cartoonId: title,
            chapterId: 'chapter-61',
            storageChapterId: 'chapter-61',
            path: 'tail-page.jpg',
            pictureType: PictureType.page,
          );
          final file = File((await store.canonicalDownloadCandidate()).path);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(List.filled(2048, 7));
        });
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: ThemeData(
                brightness: style == 'breeze'
                    ? Brightness.dark
                    : Brightness.light,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.55)),
                child: child!,
              ),
              home: const DownloadTaskPage(),
            ),
          ),
        );
        await settleHost(tester);
        await tester.tap(find.text(title));
        await settleHost(tester);
        Finder chapter(int index) =>
            find.byKey(ValueKey('download-chapter-open.chapter-$index'));
        final list = _chapterList(DownloadWorkPane.saved);
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        Future<void> revealRanges() async {
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await settleHost(tester);
        }

        Future<void> revealRow(Finder target) async {
          if (target.evaluate().isEmpty) {
            await revealRanges();
            await tester.scrollUntilVisible(
              target,
              200,
              scrollable: scrollable,
            );
          }
          await tester.ensureVisible(target);
          await tester.pump();
        }

        Future<void> range(String label) async {
          final target = find.text(label);
          await revealRow(target);
          await tester.tap(target.hitTestable());
          await settleHost(tester);
        }

        expect(
          find.byKey(const ValueKey('download-chapters-summary')),
          findsOneWidget,
        );
        expect(chapter(61), findsNothing);
        const tailRange = 'Chapter 61–Chapter 65 · Final volume';
        final tailTitle = find.text(tailRange);
        await revealRow(tailTitle);
        final tailCount = find.text('5 downloaded chapters');
        expect(tailCount, findsOneWidget);
        expect(
          tester.getRect(tailCount).top,
          greaterThan(tester.getRect(tailTitle).top),
        );
        expect(
          tester.widget<Text>(tailCount).style?.color,
          Theme.of(tester.element(tailCount)).colorScheme.onSurfaceVariant,
        );
        await range(tailRange);
        expect(chapter(1), findsNothing);
        expect(chapter(61), findsOneWidget);
        expect(tester.widget<InkWell>(chapter(61)).onTap, isNotNull);
        final chapterTitle = find.descendant(
          of: chapter(61),
          matching: find.text('Chapter 61'),
        );
        Finder rowDivider(Finder item) => find.descendant(
          of: find.ancestor(of: item, matching: find.byType(WorkListRow)),
          matching: find.byType(Divider),
        );
        final groupAxis = tester.getTopLeft(tailTitle).dx;
        final chapterAxis = tester.getTopLeft(chapterTitle).dx;
        expect(chapterAxis - groupAxis, closeTo(16, .01));
        expect(rowDivider(tailTitle), findsNothing);
        expect(
          tester.getRect(rowDivider(chapterTitle)).left,
          closeTo(chapterAxis, .01),
        );
        final theme = Theme.of(tester.element(chapterTitle));
        expect(
          tester.widget<Text>(tailTitle).style?.color,
          theme.colorScheme.onSurface,
        );
        expect(
          tester.widget<Text>(chapterTitle).style?.color,
          theme.colorScheme.onSurface,
        );
        expect(
          tester.widget<Text>(tailTitle).style?.fontWeight,
          FontWeight.w600,
        );
        final disclosure = find
            .ancestor(of: tailTitle, matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(disclosure).height, greaterThanOrEqualTo(44));
        expect(
          tester
              .getCenter(
                find.descendant(
                  of: disclosure,
                  matching: find.byIcon(Icons.expand_more),
                ),
              )
              .dx,
          closeTo(
            tester
                .getCenter(
                  find.byKey(const ValueKey('download-row-more.chapter-61')),
                )
                .dx,
            .01,
          ),
        );
        final manage = find.byKey(const ValueKey('download-episodes-manage'));
        await tester.tap(manage);
        await settleHost(tester);
        await revealRow(chapter(61));
        expect(tester.getTopLeft(chapterTitle).dx, closeTo(chapterAxis, .01));
        await tester.tap(chapter(61));
        await settleHost(tester);
        expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
        await range('Chapter 31–Chapter 60 · First volume');
        await revealRow(chapter(31));
        await tester.tap(chapter(31));
        await settleHost(tester);
        expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
        await range(tailRange);
        await tester.tap(
          find.byKey(const ValueKey('download-episodes-select-all')),
        );
        await settleHost(tester);
        expect(find.text(t.bookshelf.selectedCount(count: 65)), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('download-episodes-select-all')),
        );
        await settleHost(tester);
        for (var index = 61; index <= 65; index++) {
          await revealRow(chapter(index));
          await tester.tap(chapter(index));
          await settleHost(tester);
        }
        expect(find.text(t.bookshelf.selectedCount(count: 5)), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('download-episodes-delete')),
        );
        await settleHost(tester);
        expect(find.textContaining('5 selected chapters'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, t.common.delete),
          ),
        );
        final elapsed = Stopwatch()..start();
        while ((jsonDecode(
                          objectbox.unifiedDownloadBox.get(record.id)!.chapters,
                        )
                        as List)
                    .length ==
                65 &&
            elapsed.elapsed < const Duration(seconds: 10)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 1));
        }
        await settleHost(tester);
        final remaining = objectbox.unifiedDownloadBox.get(record.id)!;
        expect(
          (jsonDecode(remaining.chapters) as List<dynamic>).map(
            (chapter) => chapter['id'],
          ),
          [for (var index = 1; index <= 60; index++) 'chapter-$index'],
        );
        await revealRanges();
        expect(find.text(tailRange), findsNothing);
        final firstRange = find.text('Chapter 1–Chapter 30 · First volume');
        expect(firstRange, findsOneWidget);
        final firstHeading = find
            .ancestor(
              of: firstRange,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.header == true,
              ),
            )
            .first;
        expect(
          tester.widget<Semantics>(firstHeading).properties.expanded,
          isTrue,
        );
        await revealRow(chapter(1));
        expect(chapter(1).hitTestable(), findsOneWidget);
        expect(find.text(t.bookshelf.selectedCount(count: 0)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'download center pull keeps its spinner through a queued native file check',
    (tester) => runHost(tester, () async {
      const channel = MethodChannel('breeze.video.hls');
      final reads = <Completer<List<Object?>>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'list' || reads.length >= 2) return <Object?>[];
        final gate = Completer<List<Object?>>();
        reads.add(gate);
        return gate.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      Future<void> waitForReads(int count) async {
        final watch = Stopwatch()..start();
        while (reads.length < count &&
            watch.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(reads, hasLength(count));
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
        await waitForReads(1);
        var finished = false;
        final refresh = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show()
            .then((_) => finished = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(finished, isFalse);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        reads.first.complete([]);
        await waitForReads(2);
        expect(finished, isFalse);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);

        reads.last.complete([]);
        await settleHost(tester);
        await refresh;
        expect(find.text(t.common.refreshChecked), findsOneWidget);
      } finally {
        for (final read in reads) {
          if (!read.isCompleted) read.complete([]);
        }
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'download media changes keep one stationary viewport and current rows',
    (tester) => runHost(tester, () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      tester.view.physicalSize = const Size(430, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      const comicTitle = 'Motion comic';
      const videoTitle = 'Motion video';
      objectbox.downloadTaskBox.put(_task(comicTitle, 'failed'));
      await tester.runAsync(() async {
        final key = await VideoExportRecords.beginTransfer(
          source: 'b28da416-f2d4-4208-a85e-8b4c7c648e48',
          video: Uri.parse('https://fixture.test/voddetail/42.html'),
          title: videoTitle,
          quality: '',
          queued: true,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'failed',
          terminal: true,
        );
      });
      final media = find.byType(NativeVideoSegmentedControl);
      final viewport = find.byKey(
        const PageStorageKey('download-center.unified'),
      );
      NativeVideoSegmentedControl mediaControl() =>
          tester.widget<NativeVideoSegmentedControl>(media);
      for (final rtl in [false, true]) {
        style.value = rtl ? 'system' : 'breeze';
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            key: ValueKey(rtl),
            style: style,
            child: MaterialApp(
              builder: (_, child) => Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
              home: rtl
                  ? const Scaffold(body: DownloadTaskPage(embedded: true))
                  : const DownloadTaskPage(),
            ),
          ),
        );
        await settleHost(tester);
        final viewportRect = tester.getRect(viewport);
        final viewportElement = tester.element(viewport);
        final scroll = find
            .descendant(of: viewport, matching: find.byType(Scrollable))
            .first;
        ScrollPosition position() =>
            tester.state<ScrollableState>(scroll).position;
        final originalPosition = position();
        final scopeRect = tester.getRect(media);
        final plate = find.descendant(
          of: media,
          matching: find.byKey(const ValueKey('breeze.selection.plate')),
        );
        Finder segment(String value) =>
            find.descendant(of: media, matching: find.byKey(ValueKey(value)));
        final horizontal =
            rtl ||
            tester.getCenter(segment('all')).dx !=
                tester.getCenter(segment('video')).dx;
        double offsetOf(Finder finder) {
          final center = tester.getCenter(finder);
          return horizontal ? center.dx : center.dy;
        }

        Future<void> select(String value) async {
          if (rtl) {
            mediaControl().onSelected!(value);
          } else {
            await tester.tap(segment(value));
          }
        }

        void expectStationary() {
          expect(tester.getRect(viewport), viewportRect);
          expect(tester.getRect(media), scopeRect);
          expect(tester.element(viewport), same(viewportElement));
          expect(position(), same(originalPosition));
        }

        Color? segmentColor(String value) => tester
            .widget<Text>(
              find.descendant(
                of: segment(value),
                matching: find.text(mediaControl().options[value]!),
              ),
            )
            .style
            ?.color;
        final untouchedComicColor = rtl ? null : segmentColor('comic');
        final initialPlate = rtl ? null : offsetOf(plate);
        await select('video');
        await tester.pump();
        expect(mediaControl().selected, 'video');
        expect(find.text(videoTitle), findsOneWidget);
        expect(find.text(comicTitle, skipOffstage: false), findsNothing);
        expectStationary();
        await tester.pump(const Duration(milliseconds: 45));
        expectStationary();
        if (initialPlate != null) {
          final target = offsetOf(segment('video'));
          expect(offsetOf(plate), inExclusiveRange(initialPlate, target));
          for (var frame = 0; frame < 3; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(segmentColor('comic'), untouchedComicColor);
            expectStationary();
          }
        }

        final beforeReverse = rtl ? null : offsetOf(plate);
        await select('all');
        await tester.pump();
        expectStationary();
        expect(find.text(comicTitle), findsOneWidget);
        expect(find.text(videoTitle), findsOneWidget);
        if (beforeReverse != null) {
          expect(offsetOf(plate), closeTo(beforeReverse, .01));
        }
        await select('comic');
        await tester.pump();
        expect(mediaControl().selected, 'comic');
        expect(find.text(comicTitle), findsOneWidget);
        expect(find.text(videoTitle, skipOffstage: false), findsNothing);
        expectStationary();
        await tester.pump(const Duration(milliseconds: 400));
        expectStationary();
        if (!rtl) {
          expect(offsetOf(plate), closeTo(offsetOf(segment('comic')), .01));
          bool isSemanticallySelected(String value) => tester
              .widgetList<Semantics>(
                find.descendant(
                  of: segment(value),
                  matching: find.byType(Semantics),
                ),
              )
              .any((widget) => widget.properties.selected == true);
          expect(isSemanticallySelected('comic'), isTrue);
          expect(isSemanticallySelected('video'), isFalse);
        }
        expect(tester.takeException(), isNull);
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Breeze download media and source taps keep visible results current at 320 RTL',
    (tester) => runHost(tester, () async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      const videoSource = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
      const comicTitle = '漫画任务', videoTitle = '视频任务';
      objectbox.downloadTaskBox.put(_task(comicTitle, 'failed'));
      await tester.runAsync(() async {
        final key = await VideoExportRecords.beginTransfer(
          source: videoSource,
          video: Uri.parse('https://fixture.test/voddetail/42.html'),
          title: videoTitle,
          quality: '',
          queued: true,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'failed',
          terminal: true,
        );
      });
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff1257ba),
                brightness: Brightness.dark,
              ),
            ),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
            ),
            home: const DownloadTaskPage(),
          ),
        ),
      );
      await settleHost(tester);
      final rail = find.byType(BookshelfSourceNavigation);
      final source = find.byKey(
        const ValueKey('bookshelf.source.$videoSource'),
      );
      final media = find.byWidgetPredicate(
        (widget) =>
            widget is NativeVideoSegmentedControl &&
            widget.options.containsKey('comic'),
      );
      NativeVideoSegmentedControl mediaControl() =>
          tester.widget<NativeVideoSegmentedControl>(media);
      Finder mediaLabel(String value) => find.descendant(
        of: media,
        matching: find.text(mediaControl().options[value]!),
      );
      List<String> activeSources() =>
          tester.widget<BookshelfSourceNavigation>(rail).selected;
      final railRect = tester.getRect(rail);
      final mediaRect = tester.getRect(media);
      final viewport = find.byKey(
        const PageStorageKey('download-center.unified'),
      );
      final viewportX = tester.getTopLeft(viewport).dx;

      expect(find.text(comicTitle), findsOneWidget);
      expect(find.text(videoTitle), findsOneWidget);
      await tester.ensureVisible(source);
      await tester.pumpAndSettle();
      expect(source.hitTestable(), findsOneWidget);
      expect(tester.getSize(source).height, greaterThanOrEqualTo(44));
      await tester.tap(source);
      await tester.pump();
      expect(activeSources(), [videoSource]);
      expect(find.text(comicTitle), findsNothing);
      expect(find.text(videoTitle), findsOneWidget);

      await tester.tap(mediaLabel('comic'));
      await tester.pump();
      expect(mediaControl().selected, 'comic');
      expect(activeSources(), isEmpty);
      expect(find.text(comicTitle), findsOneWidget);
      expect(find.text(videoTitle), findsNothing);
      expect(tester.getTopLeft(viewport).dx, viewportX);
      await tester.tap(mediaLabel('video'));
      await tester.pump();
      expect(mediaControl().selected, 'video');
      expect(find.text(comicTitle), findsNothing);
      expect(find.text(videoTitle), findsOneWidget);
      await tester.tap(mediaLabel('all'));
      await tester.pump();
      expect(mediaControl().selected, 'all');
      expect(find.text(comicTitle), findsOneWidget);
      expect(find.text(videoTitle), findsOneWidget);
      expect(tester.getRect(rail), railRect);
      expect(tester.getRect(media), mediaRect);
      expect(tester.takeException(), isNull);
    }),
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'download chapters use the root AutoRoute secondary animation: $style',
      (tester) => runHost(tester, () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
        });
        const title = 'Download route fixture';
        // A task without a stored chapter opens the work's chapter list.
        objectbox.downloadTaskBox.put(_task(title, 'paused'));
        final tabs = PersistentTabController();
        final preference = ValueNotifier(style);
        final observer = _DownloadRouteObserver();
        final router = _DownloadRouteHost(
          app.MainNativeTabHost(
            controller: tabs,
            screens: const [
              DownloadTaskPage(embedded: true),
              SizedBox.shrink(),
            ],
            navBarHeight: 72,
            navigation: const SizedBox.shrink(),
          ),
        );
        addTearDown(tabs.dispose);
        addTearDown(preference.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp.router(
              routerConfig: router.config(
                navigatorObservers: () => [
                  observer,
                  NativeCompositionObserver(geometryBasedOcclusion: true),
                ],
              ),
            ),
          ),
        );
        await settleHost(tester);
        final mainRoute = observer.pushes.single;
        expect(mainRoute.secondaryAnimation!.value, 0);

        final opener = tester.widget<InkWell>(
          find.byKey(
            const ValueKey(
              'download-open.comic:offline-download-fixture:Download route fixture',
            ),
          ),
        );
        opener.onTap!();
        opener.onTap!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(observer.pushes, hasLength(2));
        final chapters = observer.pushes.last;
        expect(chapters.settings.name, 'breeze.download.comic-chapters');
        expect(chapters.animation!.value, inExclusiveRange(0, 1));
        expect(mainRoute.secondaryAnimation!.value, chapters.animation!.value);

        await tester.pumpAndSettle();
        router.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(mainRoute.secondaryAnimation!.value, 0);
        expect(find.text(title), findsOneWidget);
      }),
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final width in [320.0, 390.0, 440.0]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets(
        'comic and video download geometry width=$width scale=$scale',
        (tester) => runHost(tester, () async {
          const source = 'offline-download-fixture';
          final keys = <String>[];
          for (final title in [
            '短漫画',
            '很长的漫画作品标题用于验证两行标题与章节状态以及完整下载时间都保持紧凑对齐',
          ]) {
            final task = _task(title, 'completed');
            objectbox.downloadTaskBox.put(task);
            final record =
                createTestDownload(buildDownloadTaskKey(source, title))
                  ..source = source
                  ..comicId = title
                  ..title = title
                  ..downloadedAt = DateTime.utc(2026, 11, 5, 12, 34)
                  ..chapters = jsonEncode([
                    {
                      'id': 'chapter-1',
                      'logicalKey': 'chapter-1',
                      'storageChapterId': 'chapter-1',
                      'name': '第一话',
                      'order': 1,
                      'images': [
                        {'path': 'layout-page.jpg'},
                      ],
                    },
                  ]);
            await tester.runAsync(() async {
              final store = DownloadAssetStore(
                from: source,
                cartoonId: title,
                chapterId: 'chapter-1',
                storageChapterId: 'chapter-1',
                path: 'layout-page.jpg',
                pictureType: PictureType.page,
              );
              final file = File(
                (await store.canonicalDownloadCandidate()).path,
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(List.filled(2048, 7));
              objectbox.unifiedDownloadBox.put(record);
              final stored = objectbox.unifiedDownloadBox.get(record.id)!;
              final measured = await DownloadResourceMetrics.instance.readComic(
                DownloadComicResource(stored),
              );
              expect(
                measured.sizeBytes,
                2048,
                reason:
                    'measure the real persisted version before mounting the known-size host',
              );
            });
            keys.add('comic:$source:$title');
          }
          await tester.runAsync(() async {
            for (var i = 0; i < 2; i++) {
              const videoSource = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
              final watch = Uri.parse(
                'https://layout.example/voddetail/${i + 1}.html?line=main&episode=1',
              );
              final title = i == 0
                  ? '很长的视频作品名称用于验证双行标题和已下载大小及时间保持在统一封面边界以内'
                  : '短视频';
              if (i == 0) {
                await VideoDownloadedDetails.saveSession(
                  videoSource,
                  NativePlaybackSession(
                    title: title,
                    description: '',
                    watchUrl: watch,
                    sources: const [],
                    tags: const ['真实标签', '另一标签'],
                  ),
                );
              }
              final resource = VideoLocalResources.identity(
                videoSource,
                watch,
                '1080p',
              );
              final key = await VideoExportRecords.beginTransfer(
                source: videoSource,
                video: watch,
                title: title,
                quality: '1080p',
                resourceId: resource,
                sourceDuration: i == 0 ? '2:42:25' : null,
              );
              // Complete the same managed-file path as an actual MP4 download.
              // A saved external transfer acknowledgment has no local finish
              // date and must not be used to test downloaded-date geometry.
              final file = await VideoLocalResources.file(resource);
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
                resourceId: resource,
                bytes: 24,
                source: videoSource,
                video: watch,
                title: title,
                quality: '1080p',
                taskKey: key,
                sourceDuration: i == 0 ? '2:42:25' : null,
                durationMs: i == 0 ? 9745000 : null,
              );
              await VideoExportRecords.updateTransfer(
                key,
                received: 24,
                total: 24,
                status: 'saved',
                terminal: true,
                resourceId: resource,
                durationMs: i == 0 ? 9745000 : null,
              );
              keys.add('video:$resource');
            }
            final projected = projectDownloadCenter(
              tasks: const DownloadTaskRepository().getAll(),
              comics: DownloadCenterResources.readComics(),
              videos: await DownloadCenterResources.readVideos(),
            ).where((item) => keys.contains(item.key)).toList();
            expect(
              projected.map((item) => item.key).toSet(),
              keys.toSet(),
              reason:
                  'all four real rows must project before mounting the host',
            );
            expect(
              projected.every((item) => item.completedAt != null),
              isTrue,
              reason:
                  'every geometry fixture is a completed local download with an actual finish time',
            );
            final videoRows = projected.where((item) => item.isVideo).toList();
            expect(videoRows, hasLength(2));
            expect(
              videoRows.every(
                (item) =>
                    item.source == 'ccc2fe17-c0a8-4fd8-a596-835772686404' &&
                    item.video?['local'] == true &&
                    item.video?['status'] == 'saved' &&
                    item.sizeBytes == 24,
              ),
              isTrue,
            );
            expect(
              videoRows.where((item) => item.video?['durationMs'] == 9745000),
              hasLength(1),
            );
            expect(
              videoRows.where((item) => item.video?['durationMs'] == null),
              hasLength(1),
            );
          });
          await tester.binding.setSurfaceSize(Size(width, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final preference = ValueNotifier('breeze');
          addTearDown(preference.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const DownloadTaskPage(),
              ),
            ),
          );
          await settleHost(tester);
          expect(find.text('真实标签 · 另一标签'), findsOneWidget);
          final comicSizes = keys
              .take(2)
              .map((key) => find.byKey(ValueKey('download-size.$key')));
          // A completed comic's byte count is optional asynchronous metadata.
          // Compare the same metadata set across view and management modes.
          for (
            var i = 0;
            i < 100 && comicSizes.any((size) => size.evaluate().isEmpty);
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          for (final size in comicSizes) {
            expect(size, findsOneWidget);
          }
          final before = <String, (Rect, Rect)>{};
          void verify(String key) {
            final cover = tester.getRect(
              find.byKey(ValueKey('download-cover.$key')),
            );
            final details = tester.getRect(
              find.byKey(ValueKey('download-details.$key')),
            );
            final title = tester.getRect(
              find.byKey(ValueKey('download-title.$key')),
            );
            final footerRect = tester.getRect(
              find.byKey(ValueKey('download-info.$key')),
            );
            final calendar = tester.widget<Text>(
              find.byKey(ValueKey('download-date.$key')),
            );
            final clock = tester.widget<Text>(
              find.byKey(ValueKey('download-time.$key')),
            );
            expect(calendar.data, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
            expect(clock.data, matches(RegExp(r'^\d{2}:\d{2}$')));
            expect(cover.size, const Size(94, 141));
            final row = tester.getRect(
              find.byKey(ValueKey('download-open.$key')),
            );
            expect(cover.top - row.top, greaterThanOrEqualTo(9));
            expect(row.bottom - cover.bottom, greaterThanOrEqualTo(9));
            expect(cover.width / cover.height, closeTo(2 / 3, .0001));
            final sourceRect = tester.getRect(
              find.byKey(ValueKey('download-source.$key')),
            );
            expect(sourceRect.top - title.bottom, closeTo(4, .1));
            final tags = find.byKey(ValueKey('download-tags.$key'));
            if (tags.evaluate().isNotEmpty) {
              final tagRect = tester.getRect(tags);
              expect(tagRect.top - sourceRect.bottom, closeTo(4, .1));
              expect(tagRect.bottom, lessThan(footerRect.top));
            }
            expect(footerRect.left, closeTo(title.left, .1));
            expect(
              find.byKey(ValueKey('download-status.$key')),
              findsNothing,
              reason:
                  'completed local resources do not repeat a saved/completed status line',
            );
            expect(footerRect.bottom, closeTo(details.bottom, .1));
            if (scale == 1) {
              expect(
                details.height,
                closeTo(141, .1),
                reason: 'normal two-line titles fit the actual host: $key',
              );
              expect(
                footerRect.height,
                lessThanOrEqualTo(31),
                reason:
                    'calendar, clock and bytes occupy at most two footer lines',
              );
              expect(title.top, closeTo(cover.top, .1));
              expect(footerRect.bottom, closeTo(cover.bottom, .1));
            } else {
              // Accessibility preserves the poster's ratio and all metadata.
              // If text grows, this is explicitly a centered-poster fallback.
              expect(cover.center.dy, closeTo(details.center.dy, .1));
              expect(details.height, greaterThanOrEqualTo(141));
            }
          }

          for (final key in keys) {
            verify(key);
            before[key] = (
              tester.getRect(find.byKey(ValueKey('download-cover.$key'))),
              tester.getRect(find.byKey(ValueKey('download-details.$key'))),
            );
          }
          for (final key in keys.where((key) => key.startsWith('video:'))) {
            final bytes = tester.widget<Text>(
              find.byKey(ValueKey('download-size.$key')),
            );
            expect(
              bytes.data,
              '24 B',
              reason: 'small real files keep their actual byte count',
            );
          }
          final knownPoster = find.byKey(ValueKey('download-cover.${keys[2]}'));
          final duration = find.descendant(
            of: knownPoster,
            matching: find.text('2:42:25'),
          );
          expect(duration, findsOneWidget);
          final posterRect = tester.getRect(knownPoster),
              durationRect = tester.getRect(duration);
          expect(posterRect.contains(durationRect.topLeft), isTrue);
          expect(
            posterRect.contains(
              durationRect.bottomRight - const Offset(.1, .1),
            ),
            isTrue,
          );
          for (final key in keys) {
            expect(find.byKey(ValueKey('download-menu.$key')), findsNothing);
          }
          final pageMenu = tester.widget<NativeVideoMenu>(
            find.byKey(const ValueKey('download-more')),
          );
          expect(pageMenu.options.keys.last, 'help');
          expect(pageMenu.groups.last, ['help']);
          expect(
            pageMenu.selectAfterDismissal,
            unorderedEquals(
              pageMenu.options.keys.where((key) => key != 'queue'),
            ),
          );
          expect(pageMenu.optionIcons['help']?.symbol, 'questionmark.circle');
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            pageMenu.onSelected('help');
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.textContaining(t.download.helpHls), findsOneWidget);
            expect(
              find.textContaining(t.download.helpContinue),
              findsOneWidget,
            );
            await tester.tap(find.text(t.common.gotIt));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('download-filter')));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('download-filter-option-tags-真实标签')),
            );
            await tester.tap(
              find.byKey(const ValueKey('download-filter-apply')),
            );
            await settleHost(tester);
            expect(
              find.byKey(ValueKey('download-cover.${keys[2]}')),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('download-cover.${keys[3]}')),
              findsNothing,
            );
            expect(
              find.byKey(ValueKey('download-cover.${keys.first}')),
              findsNothing,
            );
            final filter = find.byKey(const ValueKey('download-filter'));
            final quickClear = find.byKey(
              const ValueKey('download-clear-filters'),
            );
            final scope = find.byType(NativeVideoSegmentedControl);
            expect(
              tester.widget<SourceFilterIconButton>(filter).selected,
              isTrue,
            );
            expect(
              tester.widget<SourceFilterIconButton>(filter).tooltip,
              'Filter and sort · ${t.comicList.activeFilters} · 1',
            );
            expect(find.byType(InputChip), findsNothing);
            expect(quickClear, findsNothing);
            tester.widget<NativeVideoSegmentedControl>(scope).onSelected!(
              'comic',
            );
            await settleHost(tester);
            expect(find.text(t.bookshelf.facets.noResults), findsOneWidget);
            await tester.tap(filter);
            await tester.pumpAndSettle();
            await tester.tap(find.text(t.common.reset));
            await tester.tap(
              find.byKey(const ValueKey('download-filter-apply')),
            );
            await settleHost(tester);
            expect(
              tester.widget<SourceFilterIconButton>(filter).selected,
              isFalse,
            );
            expect(
              tester.widget<NativeVideoSegmentedControl>(scope).selected,
              'comic',
            );
            tester.widget<NativeVideoSegmentedControl>(scope).onSelected!(
              'all',
            );
            await settleHost(tester);
            await tester.tap(filter);
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('download-filter-option-tags-真实标签')),
            );
            await tester.tap(
              find.byKey(const ValueKey('download-filter-apply')),
            );
            await settleHost(tester);
            await tester.tap(filter);
            await tester.pumpAndSettle();
            await tester.tap(find.text(t.common.reset));
            await tester.tap(
              find.byKey(const ValueKey('download-filter-apply')),
            );
            await settleHost(tester);
            expect(
              tester.widget<SourceFilterIconButton>(filter).selected,
              isFalse,
            );
            for (final key in keys) {
              expect(
                find.byKey(ValueKey('download-cover.$key')),
                findsOneWidget,
              );
            }
          }
          await tester.longPress(
            find.byKey(ValueKey('download-open.${keys.first}')),
          );
          await settleHost(tester);
          for (final key in keys) {
            verify(key);
            expect(
              tester.getSize(find.byKey(ValueKey('download-cover.$key'))),
              before[key]!.$1.size,
            );
            expect(
              tester.getSize(find.byKey(ValueKey('download-details.$key'))),
              before[key]!.$2.size,
              reason: 'Entering management preserves the details size for $key',
            );
          }
          expect(tester.takeException(), isNull);
        }),
      );
    }
  }

  testWidgets(
    'one comic export reports its local scope before any picker and cancel preserves downloads',
    (tester) => runHost(tester, () async {
      const source = 'offline-download-fixture',
          id = 'archive-ui',
          key = 'comic:$source:$id';
      final record = createTestDownload(buildDownloadTaskKey(source, id))
        ..source = source
        ..comicId = id
        ..title = 'Local archive'
        ..chapters = jsonEncode([
          {
            'id': 'a',
            'logicalKey': 'a',
            'storageChapterId': 'a',
            'name': 'Chapter A',
            'order': 1,
            'images': [
              {'path': 'saved.png'},
              {'path': 'missing.png'},
            ],
          },
        ]);
      objectbox.unifiedDownloadBox.put(record);
      late File original;
      await tester.runAsync(() async {
        final asset = DownloadAssetStore(
          from: source,
          cartoonId: id,
          chapterId: 'a',
          storageChapterId: 'a',
          path: 'saved.png',
          pictureType: PictureType.page,
        );
        original = File((await asset.canonicalDownloadCandidate()).path);
        await original.parent.create(recursive: true);
        await original.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      });
      const channel = MethodChannel('breeze.video.download');
      var presented = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        presented++;
        return 'saved';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: const MaterialApp(home: DownloadTaskPage()),
        ),
      );
      await settleHost(tester);
      final export = find.byKey(const ValueKey('download-swipe.$key.export'));
      expect(export, findsNothing);
      await openRowActions(tester, key);
      expect(export.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: export, matching: find.text('Export copy')),
        findsOneWidget,
      );
      await tester.tap(export);
      for (
        var i = 0;
        i < 100 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(t.download.exportComicScope(chapters: 1, pages: 1)),
        findsOneWidget,
      );
      expect(
        find.text(t.download.exportComicMissingPages(pages: 1)),
        findsOneWidget,
      );
      expect(
        find.text(t.download.exportComicUnavailableChapters(chapters: 0)),
        findsNothing,
      );
      expect(presented, 0);
      await tester.tap(find.text(t.common.cancel));
      for (
        var i = 0;
        i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(presented, 0);
      expect(await tester.runAsync(original.exists), isTrue);
      expect(objectbox.unifiedDownloadBox.count(), 1);
      expect(tester.takeException(), isNull);
    }),
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'header actions and reversible search share tab, navigator and router hosts',
    (tester) => runHost(tester, () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final nativeChannels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final channel = MethodChannel('${args['viewType']}.${args['id']}');
          nativeChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in nativeChannels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      objectbox.downloadTaskBox.put(_task('Header fixture', 'paused'));
      for (final style in ['system', 'breeze']) {
        for (final host in ['tab', 'navigator', 'router']) {
          final preference = ValueNotifier(style);
          final reduced = host == 'router';
          Widget media(BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: reduced,
            ),
            child: child!,
          );
          final router = host != 'router'
              ? null
              : RootStackRouter.build(
                  routes: [
                    NamedRouteDef(
                      name: 'HeaderDownloadHost',
                      path: '/',
                      initial: true,
                      builder: (_, _) => const DownloadTaskPage(),
                    ),
                  ],
                );
          final tabs = PersistentTabController(initialIndex: 0);
          final Widget app;
          if (router != null) {
            app = MaterialApp.router(
              builder: media,
              routerConfig: router.config(),
            );
          } else {
            app = MaterialApp(
              builder: media,
              home: Builder(
                builder: (context) => host == 'tab'
                    ? PersistentTabView(
                        context,
                        controller: tabs,
                        screens: const [
                          DownloadTaskPage(embedded: true),
                          SizedBox.shrink(),
                        ],
                        items: [
                          PersistentBottomNavBarItem(
                            icon: const Icon(Icons.download_outlined),
                            title: t.common.download,
                          ),
                          PersistentBottomNavBarItem(
                            icon: const Icon(Icons.more_horiz),
                            title: t.common.more,
                          ),
                        ],
                      )
                    : Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DownloadTaskPage(),
                            ),
                          ),
                          child: const Text('Open downloads'),
                        ),
                      ),
              ),
            );
          }
          await tester.pumpWidget(
            AppInterfaceStyleScope(style: preference, child: app),
          );
          if (host == 'navigator') {
            await tester.tap(find.text('Open downloads'));
          }
          await settleHost(tester);
          // Measure the settled route, not the tail of its iOS entrance.
          await tester.pumpAndSettle();
          final searchAction = find.byKey(
            const ValueKey('download-search-action'),
          );
          final manage = find.byKey(
            const ValueKey('download-selection.cancel'),
          );
          final eye = find.byType(CollectionCoverPrivacyButton);
          final more = find.byKey(const ValueKey('download-more'));
          expect(manage, findsNothing);
          final controls = [searchAction, eye, more];
          final frames = controls.map(tester.getRect).toList();
          for (var index = 0; index < frames.length; index++) {
            expect(frames[index].width, closeTo(44, .0001));
            expect(frames[index].height, closeTo(44, .0001));
            expect(
              frames[index].center.dy,
              closeTo(frames.first.center.dy, .1),
            );
            if (index > 0)
              expect(
                frames[index - 1].right,
                lessThanOrEqualTo(frames[index].left),
              );
          }
          final header = tester.getRect(
            find.byKey(const ValueKey('download-header')),
          );
          expect(frames.last.right, closeTo(header.right, .1));
          final filter = find.byKey(const ValueKey('download-filter'));
          final sources = find.byKey(
            const ValueKey('bookshelf.sources.manage'),
          );
          expect(
            tester.getCenter(filter).dx,
            closeTo(frames.last.center.dx, .1),
          );
          expect(
            tester.getCenter(sources).dx,
            closeTo(frames.last.center.dx, .1),
          );
          expect(find.text(t.common.itemsCount(count: 1)), findsOneWidget);
          final before = tester.getRect(find.text('Header fixture'));
          if (style == 'breeze') {
            await tester.tap(more);
            await tester.pump(const Duration(milliseconds: 200));
            final panel = find.byKey(const ValueKey('video-host-menu'));
            expect(panel, findsOneWidget);
            expect(
              tester.getRect(panel).top,
              greaterThanOrEqualTo(frames.last.bottom),
            );
            await tester.binding.handlePopRoute();
            await tester.pump(const Duration(milliseconds: 200));
          }
          tester.widget<SourceChromeIconButton>(searchAction).onPressed!();
          await tester.pump();
          final editor = find.byKey(const ValueKey('download-search-field'));
          final cancel = find.byKey(const ValueKey('download-search-close'));
          final expanded = tester.getRect(editor);
          expect(more, findsNothing);
          expect(expanded.left, closeTo(header.left, .1));
          expect(expanded.right, closeTo(header.right, .1));
          expect(expanded.contains(tester.getCenter(cancel)), isTrue);
          expect(manage, findsNothing);
          expect(eye, findsNothing);
          expect(searchAction, findsNothing);
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.getRect(editor), expanded);
          final after = tester.getRect(find.text('Header fixture'));
          expect(after.width, closeTo(before.width, .0001));
          expect(after.height, closeTo(before.height, .0001));
          for (final edges in [
            (after.left, before.left),
            (after.top, before.top),
            (after.right, before.right),
            (after.bottom, before.bottom),
          ]) {
            expect(edges.$1, closeTo(edges.$2, .15));
          }
          tester.widget<IconButton>(cancel).onPressed!();
          await tester.pump();
          expect(editor, findsNothing);
          expect(cancel, findsNothing);
          expect(manage, findsNothing);
          // Reopen immediately; departed actions must not remain interactive.
          tester.widget<SourceChromeIconButton>(searchAction).onPressed!();
          await tester.pump();
          expect(manage, findsNothing);
          await tester.binding.handlePopRoute();
          await settleHost(tester);
          expect(editor, findsNothing);
          expect(find.text('Header fixture'), findsOneWidget);
          final restoredHeader = tester.getRect(
            find.byKey(const ValueKey('download-header')),
          );
          expect(restoredHeader.width, closeTo(header.width, .0001));
          expect(restoredHeader.height, closeTo(header.height, .0001));
          for (final edges in [
            (restoredHeader.left, header.left),
            (restoredHeader.top, header.top),
            (restoredHeader.right, header.right),
            (restoredHeader.bottom, header.bottom),
          ]) {
            expect(edges.$1, closeTo(edges.$2, .15));
          }
          final restored = tester.getRect(find.text('Header fixture'));
          expect(restored.width, closeTo(before.width, .0001));
          expect(restored.height, closeTo(before.height, .0001));
          for (final edges in [
            (restored.left, before.left),
            (restored.top, before.top),
            (restored.right, before.right),
            (restored.bottom, before.bottom),
          ]) {
            expect(edges.$1, closeTo(edges.$2, .15));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await settleHost(tester);
          router?.dispose();
          tabs.dispose();
          preference.dispose();
        }
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'download management keeps cover/title geometry and separates metadata: $style $brightness',
        (tester) => runHost(tester, () async {
          const title = '很长的下载作品标题用于验证小屏大字模式与管理模式原位切换';
          const source = 'offline-download-fixture';
          const key = 'comic:$source:$title';
          objectbox.downloadTaskBox.put(_task(title, 'completed'));
          final record = createTestDownload(buildDownloadTaskKey(source, title))
            ..source = source
            ..comicId = title
            ..title = title
            ..downloadedAt = DateTime.utc(2026, 10, 1, 12, 34)
            ..chapters = jsonEncode([
              {
                'id': 'chapter-1',
                'logicalKey': 'chapter-1',
                'storageChapterId': 'chapter-1',
                'name': '第一话',
                'order': 1,
                'images': [
                  {'path': 'fixture-page.jpg'},
                ],
              },
            ]);
          await tester.runAsync(() async {
            final store = DownloadAssetStore(
              from: source,
              cartoonId: title,
              chapterId: 'chapter-1',
              storageChapterId: 'chapter-1',
              path: 'fixture-page.jpg',
              pictureType: PictureType.page,
            );
            final file = File((await store.canonicalDownloadCandidate()).path);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(List.filled(2048, 7));
            objectbox.unifiedDownloadBox.put(record);
            final stored = objectbox.unifiedDownloadBox.get(record.id)!;
            final measured = await DownloadResourceMetrics.instance.readComic(
              DownloadComicResource(stored),
            );
            expect(
              measured.sizeBytes,
              2048,
              reason:
                  'ObjectBox time precision must not invalidate the premeasured fixture',
            );
          });
          await tester.binding.setSurfaceSize(const Size(320, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: const DownloadTaskPage(embedded: true),
              ),
            ),
          );
          await settleHost(tester);
          final cover = find.byKey(const ValueKey('download-cover.$key'));
          final text = find.byKey(const ValueKey('download-title.$key'));
          final open = find.byKey(const ValueKey('download-open.$key'));
          expect(
            find.byKey(const ValueKey('download-menu.$key')),
            findsNothing,
          );
          final bytes = find.byKey(const ValueKey('download-size.$key'));
          final date = find.byKey(const ValueKey('download-time.$key'));
          final byteText = find.text('2.0 KB');
          final metricWait = Stopwatch()..start();
          while (byteText.evaluate().isEmpty &&
              metricWait.elapsed < const Duration(seconds: 3)) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(byteText, findsOneWidget);
          final coverBefore = tester.getRect(cover),
              titleBefore = tester.getRect(text);
          expect(tester.getRect(open).contains(titleBefore.center), isTrue);
          final card = find.byKey(const ValueKey('download-card.$key'));
          BorderSide border() =>
              (tester.widget<Material>(card).shape! as RoundedRectangleBorder)
                  .side;
          expect(border(), BorderSide.none);
          expect(
            tester.widget<Material>(card).color,
            Theme.of(tester.element(card)).scaffoldBackgroundColor,
          );
          expect(tester.getRect(bytes).overlaps(tester.getRect(date)), isFalse);
          expect(
            tester.getRect(bytes).left,
            greaterThanOrEqualTo(titleBefore.left),
          );
          expect(
            tester.getRect(date).left,
            greaterThanOrEqualTo(titleBefore.left),
          );
          expect(
            tester.getRect(find.byKey(const ValueKey('download-count'))).top,
            lessThan(tester.getRect(cover).top),
          );
          await tester.tap(find.byTooltip(t.common.search));
          await settleHost(tester);
          final search = find.byKey(const ValueKey('download-search-field'));
          final closeSearch = find.byKey(
            const ValueKey('download-search-close'),
          );
          expect(search, findsOneWidget);
          expect(tester.widget<SearchQueryField>(search).inline, isTrue);
          // The editor contains its close control and uses the full header width.
          expect(
            find.byKey(const ValueKey('download-selection.cancel')),
            findsNothing,
          );
          expect(find.byType(CollectionCoverPrivacyButton), findsNothing);
          expect(find.byKey(const ValueKey('download-more')), findsNothing);
          expect(
            tester.getRect(search).contains(tester.getCenter(closeSearch)),
            isTrue,
          );
          expect(
            tester.getRect(search).center.dy,
            closeTo(tester.getRect(closeSearch).center.dy, 1),
          );
          expect(
            tester.getRect(search).bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const ValueKey('download-filter'))).top,
            ),
          );
          await tester.enterText(
            find.descendant(of: search, matching: find.byType(TextField)),
            '无匹配内容',
          );
          await settleHost(tester);
          expect(text, findsNothing);
          await tester.tap(closeSearch);
          await settleHost(tester);
          expect(search, findsNothing);
          expect(closeSearch, findsNothing);
          expect(tester.getRect(cover), coverBefore);
          expect(tester.getRect(text), titleBefore);
          expect(find.byType(TextField), findsNothing);
          await _enterDownloadManagement(tester);
          await settleHost(tester);
          expect(tester.getRect(cover), coverBefore);
          expect(tester.getRect(text), titleBefore);
          final selection = find.byKey(const ValueKey('download-select.$key'));
          final selectionRect = tester.getRect(selection);
          expect(selection.hitTestable(), findsOneWidget);
          expect(coverBefore.contains(selectionRect.topLeft), isTrue);
          expect(
            coverBefore.contains(
              selectionRect.bottomRight - const Offset(.1, .1),
            ),
            isTrue,
          );
          await tester.tap(selection);
          await settleHost(tester);
          expect(
            tester.widget<DownloadCardSelection>(selection).selected,
            isTrue,
          );
          expect(border(), BorderSide.none);
          final selectionTheme = Theme.of(tester.element(card));
          expect(
            tester.widget<Material>(card).color,
            Color.alphaBlend(
              selectionTheme.colorScheme.primary.withValues(alpha: .06),
              selectionTheme.scaffoldBackgroundColor,
            ),
          );
          await tester.tap(text);
          await settleHost(tester);
          expect(
            tester.widget<DownloadCardSelection>(selection).selected,
            isFalse,
          );
          expect(find.byType(DownloadTaskPage), findsOneWidget);
          await tester.tap(find.byTooltip(t.common.cancel));
          await settleHost(tester);
          expect(tester.getRect(cover), coverBefore);
          expect(tester.getRect(text), titleBefore);
          expect(objectbox.downloadTaskBox.count(), 1);
          expect(objectbox.unifiedDownloadBox.count(), 1);
          expect(tester.takeException(), isNull);
        }),
      );
    }
  }

  testWidgets(
    'storage shows saved bytes and sorts pinned downloads within their group',
    (tester) => runHost(tester, () async {
      final small = _task('最近保存的下载', 'completed');
      final large = _task('占用最大的下载', 'completed');
      late File smallPage;
      await tester.runAsync(() async {
        smallPage = await _saveComicResource(
          small,
          bytes: 1024,
          downloadedAt: DateTime.utc(2026, 11, 10),
        );
        await _saveComicResource(
          large,
          bytes: 8192,
          downloadedAt: DateTime.utc(2026, 11, 9),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          DownloadWorkPins.storageKey,
          jsonEncode({
            'version': 1,
            'pins': {
              'comic:offline-download-fixture:${large.comicId}': 1,
              'comic:offline-download-fixture:${small.comicId}': 2,
            },
          }),
        );
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const capacity = MethodChannel('breeze.download.capacity');
      var spaceReads = 0;
      messenger.setMockMethodCallHandler(capacity, (_) async {
        spaceReads++;
        return 1 << 30;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(capacity, null));
      final cubit = GlobalSettingCubit()..updateALl(const GlobalSettingState());
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: DownloadTaskPage()),
        ),
      );
      await settleHost(tester);
      double position(String title) => tester.getTopLeft(find.text(title)).dy;
      Future<void> until(bool Function() ready) async {
        final elapsed = Stopwatch()..start();
        while (!ready() && elapsed.elapsed < const Duration(seconds: 3)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), isTrue);
      }

      expect(position(small.comicName), lessThan(position(large.comicName)));
      expect(find.byType(DownloadCardPin), findsNWidgets(2));
      final footer = find.byKey(const ValueKey('download-storage-footer'));
      await until(
        () =>
            footer.hitTestable().evaluate().isNotEmpty &&
            tester.widget<Text>(footer).data!.contains('9.2 KB'),
      );
      expect(tester.widget<Text>(footer).data, contains('1.1 GB'));

      await tester.tap(find.byKey(const ValueKey('download-more')));
      await settleHost(tester);
      expect(find.text(t.download.storageSpace).hitTestable(), findsNothing);
      await tester.tap(find.text(t.download.settings).hitTestable());
      await until(
        () => find.byType(DownloadSettingsPage).evaluate().isNotEmpty,
      );
      await settleHost(tester);
      expect(find.byType(DownloadSettingsPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(t.download.savedDownloadSpace), findsOneWidget);
      await until(() => find.text('9.2 KB').evaluate().isNotEmpty);
      expect(find.text('1.1 GB'), findsOneWidget);
      expect(spaceReads, greaterThanOrEqualTo(2));
      Navigator.of(tester.element(find.byType(DownloadSettingsPage))).pop();
      await settleHost(tester);

      Future<void> chooseOrder(String label) async {
        await tester.tap(find.byKey(const ValueKey('download-filter')));
        await settleHost(tester);
        expect(find.byKey(const ValueKey('download-order')), findsOneWidget);
        await tester.tap(find.text(label).hitTestable());
        await tester.tap(find.byKey(const ValueKey('download-filter-apply')));
        await settleHost(tester);
      }

      await chooseOrder(t.download.largestDownloadsFirst);
      await until(() => position(large.comicName) < position(small.comicName));
      await chooseOrder(t.download.defaultDownloadOrder);
      expect(position(small.comicName), lessThan(position(large.comicName)));
      expect(objectbox.unifiedDownloadBox.count(), 2);

      await tester.runAsync(() => smallPage.writeAsBytes(List.filled(2048, 7)));
      var refreshed = false;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh()
          .then((_) => refreshed = true);
      await until(() => refreshed);
      await refresh;
      await until(() => tester.widget<Text>(footer).data!.contains('10.2 KB'));
    }),
  );

  testWidgets(
    'download work pins survive search and clear after deleting the work',
    (tester) => runHost(tester, () async {
      final first = _task('Pinned comic fixture', 'paused');
      final second = _task('Other comic fixture', 'paused');
      objectbox.downloadTaskBox.putMany([first, second]);
      List<(int, String?, bool)> queue() => [
        for (final task in const DownloadTaskRepository().getAll())
          (task.id, task.taskInfo?.stateCode, task.isDownloading),
      ];
      final initialQueue = queue();
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);

      final firstTitle = find.byKey(
        ValueKey(
          'download-title.comic:offline-download-fixture:${first.comicName}',
        ),
      );
      final secondTitle = find.byKey(
        ValueKey(
          'download-title.comic:offline-download-fixture:${second.comicName}',
        ),
      );
      const firstKey = 'comic:offline-download-fixture:Pinned comic fixture';
      Finder action(String id) =>
          find.byKey(ValueKey('download-swipe.$firstKey.$id'));
      Future<void> revealCommand(String id) async {
        final card = find.byKey(const ValueKey('download-card.$firstKey'));
        final swipe = find.ancestor(
          of: card,
          matching: find.byType(DownloadSwipeActions),
        );
        bool hasCommand() =>
            swipe.evaluate().isNotEmpty &&
            tester
                .widget<DownloadSwipeActions>(swipe)
                .actions
                .any((command) => command.id == id);
        final elapsed = Stopwatch()..start();
        while (!hasCommand() && elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(hasCommand(), isTrue, reason: 'The $id command is available');
        await tester.ensureVisible(card);
        await tester.pump();
        await openRowActions(tester, firstKey);
        expect(action(id).hitTestable(), findsOneWidget);
      }

      Future<void> chooseAction(String id) async {
        await revealCommand(id);
        await tester.tap(action(id));
        await settleRowMenuSelection(tester);
      }

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      expect(top(secondTitle), lessThan(top(firstTitle)));
      await chooseAction('pin');
      expect(top(firstTitle), lessThan(top(secondTitle)));
      final poster = tester.getRect(
        find.byKey(const ValueKey('download-cover.$firstKey')),
      );
      final pin = tester.getRect(find.byType(DownloadCardPin));
      expect(pin.center.dx, lessThan(poster.center.dx));
      expect(pin.center.dy, lessThan(poster.center.dy));
      expect(pin.left, lessThan(poster.left));
      expect(pin.top, lessThan(poster.top));
      expect(
        pin.top -
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('download-open.$firstKey')),
                )
                .dy,
        greaterThanOrEqualTo(3),
      );
      expect(pin.contains(poster.topLeft), isTrue);
      expect(poster.contains(pin.bottomRight), isTrue);
      expect(queue(), initialQueue);

      await tester.tap(find.byKey(const ValueKey('download-search-action')));
      await settleHost(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('download-search-field')),
          matching: find.byType(TextField),
        ),
        second.comicName,
      );
      await settleHost(tester);
      expect(firstTitle, findsNothing);
      expect(secondTitle, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('download-search-close')));
      await settleHost(tester);
      expect(top(firstTitle), lessThan(top(secondTitle)));

      await chooseAction('unpin');
      expect(top(secondTitle), lessThan(top(firstTitle)));
      expect(find.byType(DownloadCardPin), findsNothing);
      expect(queue(), initialQueue);

      await chooseAction('pin');
      await chooseAction('delete');
      await waitForRemovalDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      for (var attempt = 0; attempt < 20; attempt++) {
        await settleHost(tester);
        final pins = await DownloadWorkPins.read();
        if (objectbox.downloadTaskBox.get(first.id) == null &&
            !pins.containsKey(firstKey)) {
          break;
        }
      }
      expect(firstTitle, findsNothing);
      expect(objectbox.downloadTaskBox.get(first.id), isNull);
      expect((await DownloadWorkPins.read()).containsKey(firstKey), isFalse);
      expect(queue(), initialQueue.where((row) => row.$1 == second.id));

      objectbox.downloadTaskBox.put(_task(first.comicName, 'paused'));
      for (
        var attempt = 0;
        attempt < 20 && firstTitle.evaluate().isEmpty;
        attempt++
      ) {
        await settleHost(tester);
      }
      expect(firstTitle, findsOneWidget);
      await revealCommand('pin');
      expect(action('unpin'), findsNothing);
      expect(queue().map((row) => row.$2), everyElement('paused'));
    }),
  );

  testWidgets(
    'standalone downloads returns on the first tap with row actions revealed',
    (tester) => runHost(tester, () async {
      final task = _task('可返回的下载', 'failed');
      objectbox.downloadTaskBox.put(task);
      const entry = 'Open downloads';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadTaskPage(),
                  ),
                ),
                child: const Text(entry),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(entry));
      await settleHost(tester);
      final row = find.text(task.comicName);
      await tester.ensureVisible(row);
      await tester.drag(row, const Offset(-160, 0));
      await settleHost(tester);
      final tray = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'download-swipe-tray.',
            ),
      );
      expect(tray, findsOneWidget);
      await tester.tap(find.byType(SourceBackButton));
      await settleHost(tester);
      expect(find.byType(DownloadTaskPage), findsNothing);
      expect(find.text(entry), findsOneWidget);
      expect(objectbox.downloadTaskBox.count(), 1);
    }),
  );

  for (final shell in ['wide', 'breeze', 'native', 'android']) {
    testWidgets(
      'downloads $shell navigation leaves on the first tap and reopens closed',
      (tester) => runHost(tester, () async {
        tester.view.physicalSize = shell == 'wide'
            ? const Size(1024, 740)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final task = _task('主导航下载', 'failed');
        objectbox.downloadTaskBox.put(task);
        final controller = PersistentTabController();
        final openSwipe = ValueNotifier<String?>(null);
        final style = ValueNotifier(shell == 'breeze' ? 'breeze' : 'system');
        addTearDown(controller.dispose);
        addTearDown(openSwipe.dispose);
        addTearDown(style.dispose);

        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        int? nativeNavigationId;
        MethodChannel? nativeNavigationChannel;
        final nativeDecisions = <String>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.arguments is! Map) return null;
          final arguments = call.arguments as Map;
          if (call.method == 'create' &&
              arguments['viewType'] == 'breeze.video.navigation') {
            nativeNavigationId = arguments['id'] as int;
            nativeNavigationChannel = MethodChannel(
              'breeze.video.navigation.$nativeNavigationId',
            );
            messenger.setMockMethodCallHandler(
              nativeNavigationChannel!,
              (_) async => null,
            );
          }
          if (arguments['id'] == nativeNavigationId &&
              call.method.endsWith('Gesture')) {
            nativeDecisions.add(call.method);
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          if (nativeNavigationChannel case final channel?) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });

        const otherPage = 'Outside downloads';
        final screens = [
          DownloadTaskPage(embedded: true, openSwipe: openSwipe),
          const Scaffold(body: Text(otherPage)),
        ];
        const tabIcons = [Icons.download, Icons.home];
        final tabs = [
          BottomNavigationBarItem(icon: Icon(tabIcons[0]), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(tabIcons[1]), label: 'Home'),
        ];
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  final index = controller.index;
                  final navigationGroup = index == 0 ? openSwipe : null;
                  void select(int next) {
                    openSwipe.value = null;
                    if (next != controller.index) {
                      setState(() => controller.jumpToTab(next));
                    }
                  }

                  if (shell == 'wide') {
                    return app.MainWideTabHost(
                      screens: screens,
                      destinations: [
                        for (final tab in tabs)
                          NavigationRailDestination(
                            icon: tab.icon,
                            label: Text(tab.label!),
                          ),
                      ],
                      selectedIndex: index,
                      onSelected: select,
                      onSearch: () {},
                      navigationTapRegionGroup: navigationGroup,
                    );
                  }
                  return app.MainNativeTabHost(
                    controller: controller,
                    screens: screens,
                    floatingNavigation: shell == 'native',
                    navBarHeight: 64,
                    navigationTapRegionGroup: navigationGroup,
                    navigation: VideoNativeNavigation(
                      items: tabs,
                      symbols: const ['arrow.down', 'house'],
                      currentIndex: index,
                      onTap: select,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await settleHost(tester);
        await tester.drag(find.text(task.comicName), const Offset(-160, 0));
        await settleHost(tester);
        expect(openSwipe.value, isNotNull);

        Future<void> tapTab(int index) async {
          if (shell == 'native') {
            nativeDecisions.clear();
            final nav = find.byWidgetPredicate(
              (widget) =>
                  widget is UiKitView &&
                  widget.viewType == 'breeze.video.navigation',
            );
            await tester.tap(nav);
            await tester.pump();
            expect(nativeDecisions, ['acceptGesture']);
            await messenger.handlePlatformMessage(
              nativeNavigationChannel!.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('select', index),
              ),
              (_) {},
            );
          } else {
            await tester.tap(find.byIcon(tabIcons[index]));
          }
          await settleHost(tester);
        }

        await tapTab(1);
        expect(find.text(otherPage), findsOneWidget);
        expect(openSwipe.value, isNull);
        await tapTab(0);
        expect(find.text(task.comicName), findsOneWidget);
        expect(openSwipe.value, isNull);
        expect(tester.takeException(), isNull);
      }),
      variant: TargetPlatformVariant.only(
        shell == 'android' ? TargetPlatform.android : TargetPlatform.iOS,
      ),
    );
  }

  testWidgets(
    'stopped rows offer details and deletion while retry stays at the failure',
    (tester) => runHost(tester, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = _task('可侧拉的下载', 'completed');
      final second = _task('另一个已下载项', 'completed');
      final failed = _task('重试留在原位', 'failed');
      await tester.runAsync(() async {
        await _saveComicResource(first);
        await _saveComicResource(second);
      });
      objectbox.downloadTaskBox.putMany([first, second, failed]);
      final colors = BreezeThemeColors.fromSeed(
        const Color(0xff009688),
        Brightness.dark,
      ).copyWith(error: const Color(0xffffb4ab));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: colors,
            scaffoldBackgroundColor: colors.surface,
          ),
          home: const DownloadTaskPage(),
        ),
      );
      await settleHost(tester);
      const prefix = 'comic:offline-download-fixture:';
      Finder action(String title, String id) =>
          find.byKey(ValueKey('download-swipe.$prefix$title.$id'));

      final firstKey = '$prefix${first.comicName}';
      final card = find.byKey(ValueKey('download-card.$firstKey'));
      await tester.ensureVisible(card);
      final rest = tester.getRect(card);
      await tester.drag(card, const Offset(-160, 0));
      await settleHost(tester);
      expect(action(first.comicName, 'export'), findsNothing);
      final tray = find.byKey(ValueKey('download-swipe-tray.$firstKey'));
      final cardRect = tester.getRect(card);
      final trayRect = tester.getRect(tray);
      expect(trayRect.center.dy, closeTo(cardRect.center.dy, .01));
      expect(trayRect.height, closeTo(cardRect.height, .01));
      expect(trayRect.right, closeTo(rest.right, .01));
      expect(cardRect.right, closeTo(trayRect.left, .01));
      expect(
        find.byKey(ValueKey('download-row-more.$firstKey')).hitTestable(),
        findsOneWidget,
      );
      expect(action(first.comicName, 'more'), findsNothing);
      expect(action(first.comicName, 'pin'), findsNothing);
      final shortcutDelete = action(first.comicName, 'delete');
      expect(shortcutDelete.hitTestable(), findsOneWidget);
      expect(tester.getSize(shortcutDelete).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(shortcutDelete).height, greaterThanOrEqualTo(44));
      expect(action(first.comicName, 'retry'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(objectbox.downloadTaskBox.count(), 3);

      await tester.tapAt(tester.getCenter(card));
      await settleHost(tester);
      expect(tray, findsNothing);
      await openRowActions(tester, '$prefix${second.comicName}');
      final delete = action(second.comicName, 'delete');
      expect(delete.hitTestable(), findsOneWidget);
      final icon = find.descendant(of: delete, matching: find.byType(Icon));
      final label = find.descendant(of: delete, matching: find.byType(Text));
      final deleteColor = tester.widget<Text>(label).style!.color!;
      expect(deleteColor.r, greaterThan(deleteColor.g));
      expect(deleteColor.r, greaterThan(deleteColor.b));
      expect(tester.widget<Icon>(icon).color, deleteColor);
      expect(
        BreezeThemeColors.contrast(
          deleteColor,
          Theme.of(tester.element(delete)).colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(delete);
      await waitForRemovalDialog(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(second.comicName),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await settleHost(tester);
      expect(objectbox.downloadTaskBox.count(), 3);

      final deleteFailed = action(failed.comicName, 'delete');
      await openRowActions(tester, '$prefix${failed.comicName}');
      expect(deleteFailed.hitTestable(), findsOneWidget);
      expect(action(failed.comicName, 'retry'), findsNothing);
      expect(action(failed.comicName, 'export'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(deleteFailed);
      await waitForRemovalDialog(tester);
      expect(find.textContaining(failed.comicName), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await settleHost(tester);
      expect(
        find.widgetWithText(TextButton, t.common.retry).hitTestable(),
        findsOneWidget,
      );

      await openRowActions(tester, '$prefix${failed.comicName}');
      await tester.tap(
        find.byKey(
          ValueKey('download-action-sheet-close.$prefix${failed.comicName}'),
        ),
      );
      await settleHost(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(objectbox.downloadTaskBox.count(), 3);
      expect(find.byKey(const ValueKey('download-search-close')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('download-search-action')));
      await settleHost(tester);
      await tester.tap(find.byKey(const ValueKey('download-search-close')));
      await settleHost(tester);

      await _enterDownloadManagement(tester);
      await settleHost(tester);
      await tester.drag(find.text(first.comicName), const Offset(-220, 0));
      await settleHost(tester);
      expect(action(first.comicName, 'delete'), findsNothing);
      expect(objectbox.downloadTaskBox.count(), 3);
    }),
  );

  testWidgets(
    'swipe shortcut order and touch targets adapt to text and direction',
    (tester) async {
      final open = ValueNotifier<String?>(null);
      addTearDown(open.dispose);
      final actions = <DownloadSwipeAction>[
        (
          id: 'details',
          label: 'Work details',
          icon: Icons.info_outline,
          run: () {},
        ),
        (id: 'export', label: 'Export', icon: Icons.ios_share, run: () {}),
        (id: 'delete', label: 'Delete', icon: Icons.delete_outline, run: () {}),
        (
          id: 'next',
          label: 'Prioritize this download',
          icon: Icons.vertical_align_top_rounded,
          run: () {},
        ),
      ];
      final row = find.byKey(const ValueKey('density-row'));
      final title = find.text('Offline item');
      for (final (width, scale, direction, secondary) in [
        (430.0, 1.0, TextDirection.ltr, 'delete'),
        (320.0, 2.4, TextDirection.ltr, 'delete'),
        (320.0, 1.0, TextDirection.rtl, 'next'),
      ]) {
        final rtl = direction == TextDirection.rtl;
        final shortcuts = ['details', secondary];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: rtl ? TargetPlatform.android : TargetPlatform.iOS,
            ),
            builder: (context, child) => Directionality(
              textDirection: direction,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: scale > 2,
                ),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: DownloadSwipeActions(
                    key: ValueKey((width, scale, direction)),
                    rowKey: 'density',
                    openRow: open,
                    actions: actions,
                    swipeActionIds: shortcuts,
                    child: const SizedBox(
                      key: ValueKey('density-row'),
                      height: 78,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Offline item',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DownloadRowMoreButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rest = tester.getRect(row);
        final titleAtRest = tester.getRect(title);
        final gesture = await tester.startGesture(rest.center);
        final step = Offset(rtl ? 28 : -28, 0);
        await gesture.moveBy(step);
        await gesture.moveBy(step);
        await tester.pump();
        final moving = tester.getRect(row);
        expect(moving.height, rest.height);
        expect(moving.top, rest.top);
        expect(
          rtl ? moving.left - rest.left : rest.right - moving.right,
          greaterThan(10),
        );
        final movedTitle = tester.getRect(title);
        expect(
          movedTitle,
          rectMoreOrLessEquals(
            titleAtRest.shift(moving.topLeft - rest.topLeft),
          ),
        );
        expect(moving.size, rest.size);
        await gesture.moveBy(step * 4);
        await gesture.up();
        await tester.pumpAndSettle();
        Finder button(String id) =>
            find.byKey(ValueKey('download-swipe.density.$id'));
        final minimum = rtl ? 48.0 : 44.0;
        final tray = find.byKey(const ValueKey('download-swipe-tray.density'));
        expect(tester.getSize(tray).height, rest.height);
        for (final id in shortcuts) {
          final target = button(id);
          expect(target.hitTestable(), findsOneWidget);
          expect(tester.getSize(target).width, greaterThanOrEqualTo(minimum));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(minimum));
          final label = find.descendant(
            of: target,
            matching: find.byType(Text),
          );
          if (label.evaluate().isEmpty) {
            final icon = tester.widget<Icon>(
              find.descendant(of: target, matching: find.byType(Icon)),
            );
            expect(
              icon.semanticLabel,
              actions.firstWhere((a) => a.id == id).label,
            );
          } else {
            expect(tester.widget<Text>(label).maxLines, 1);
            expect(
              tester
                  .renderObject<RenderParagraph>(
                    find.descendant(of: label, matching: find.byType(RichText)),
                  )
                  .didExceedMaxLines,
              isFalse,
            );
          }
        }
        expect(
          tester.getCenter(button('details')).dx,
          rtl
              ? greaterThan(tester.getCenter(button(secondary)).dx)
              : lessThan(tester.getCenter(button(secondary)).dx),
        );
        for (final action in actions.where((a) => !shortcuts.contains(a.id))) {
          expect(button(action.id), findsNothing);
        }
        expect(button('more'), findsNothing);
        await tester.tapAt(Offset(rest.center.dx, rest.bottom + 10));
        await tester.pumpAndSettle();
        expect(tray, findsNothing);
        expect(tester.getRect(row), rest);
        expect(tester.getRect(title), titleAtRest);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'same chapter attempts own separate swipe and selection actions',
    (tester) => runHost(tester, () async {
      const source = 'offline-download-fixture';
      const title = 'Duplicate chapter attempts';
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DownloadTask attempt(
        String state,
        int revision, {
        int chapter = 25,
        int? queuedAt,
        String? phase,
      }) => DownloadTask()
        ..comicId = title
        ..comicName = title
        ..isCompleted = state == 'cancelled'
        ..isDownloading = state == 'running'
        ..status = state == 'cancelled'
            ? t.download.cancelled
            : t.download.statusWaiting
        ..taskInfo = DownloadTaskJson(
          from: source,
          comicId: title,
          comicName: title,
          stateCode: state,
          phaseCode: phase ?? (state == 'cancelled' ? 'cancelled' : ''),
          attempt: revision,
          queuedAt: queuedAt,
          chapterRef: DownloadChapterTaskRef(
            chapterId: '$chapter',
            logicalKey: '$chapter',
            title: 'Chapter $chapter',
            order: chapter,
          ),
        );
      final old = attempt('cancelled', 1);
      final waiting = attempt('queued', 2, queuedAt: 100);
      final recent = attempt('queued', 1, chapter: 26, queuedAt: 200);
      final failure = attempt('failed', 1, chapter: 27);
      final retry = attempt('queued', 1, chapter: 28, phase: 'waitingRetry');
      final paused = attempt('paused', 1, chapter: 29);
      final running = attempt('running', 1, chapter: 30);
      objectbox.downloadTaskBox.putMany([
        old,
        waiting,
        recent,
        failure,
        retry,
        paused,
        running,
      ]);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      await tester.tap(
        find.byKey(const ValueKey('download-open.comic:$source:$title')),
      );
      await settleHost(tester);
      Finder row(DownloadTask task) =>
          find.byKey(ValueKey('download-chapter-open.task:${task.id}'));
      Finder tray(DownloadTask task) =>
          find.byKey(ValueKey('download-swipe-tray.task:${task.id}'));
      expect(row(waiting), findsOneWidget);
      expect(row(old), findsOneWidget);
      final order = [running, waiting, recent, retry, failure, paused, old];
      final positions = [
        for (final task in order) tester.getTopLeft(row(task)).dy,
      ];
      expect(positions, orderedEquals([...positions]..sort()));
      expect(positions.toSet(), hasLength(order.length));
      expect(
        find.descendant(
          of: row(retry),
          matching: find.text(t.download.statusWaitingRetry),
        ),
        findsOneWidget,
      );
      final retryButton = find.byKey(
        ValueKey('download-chapter-resume.task:${retry.id}'),
      );
      expect(retryButton.hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: retryButton,
          matching: find.text(t.download.retryNow),
        ),
        findsOneWidget,
      );
      await tester.drag(row(retry), const Offset(-160, 0));
      await settleHost(tester);
      expect(tray(retry), findsOneWidget);
      expect(retryButton.hitTestable(), findsNothing);
      expect(
        find
            .byKey(ValueKey('download-swipe.task:${retry.id}.info'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('download-swipe.task:${retry.id}.delete')),
        findsNothing,
      );
      await tester.tapAt(tester.getCenter(row(retry)));
      await settleHost(tester);
      expect(retryButton.hitTestable(), findsOneWidget);
      await openRowActions(tester, 'task:${retry.id}');
      expect(
        find.byKey(ValueKey('download-swipe.task:${retry.id}.pause')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await settleHost(tester);
      final waitingBefore = tester.getRect(row(waiting));
      await tester.drag(row(old), const Offset(-160, 0));
      await settleHost(tester);
      expect(tray(old), findsOneWidget);
      expect(tray(waiting), findsNothing);
      expect(tester.getRect(row(waiting)), waitingBefore);
      await tester.drag(row(waiting), const Offset(-160, 0));
      await settleHost(tester);
      expect(tray(waiting), findsOneWidget);
      expect(tray(old), findsNothing);
      final manage = find.byKey(const ValueKey('download-episodes-manage'));
      await tester.tap(manage);
      await settleHost(tester);
      expect(tray(waiting), findsNothing);
      await tester.tap(manage);
      await settleHost(tester);
      expect(
        find.descendant(of: manage, matching: find.text(t.common.done)),
        findsOneWidget,
      );
      await tester.ensureVisible(row(old));
      await tester.tap(row(old).hitTestable());
      await settleHost(tester);
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('download-episodes-delete')));
      await settleHost(tester);
      expect(
        find.textContaining('Remove 1 selected cancelled download records'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, t.common.delete),
        ),
      );
      await settleHost(tester);
      expect(objectbox.downloadTaskBox.get(old.id), isNull);
      expect(
        objectbox.downloadTaskBox.get(waiting.id)?.taskInfo?.stateCode,
        'queued',
      );
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    '250 variable-height downloads only offer return to top and retain selection geometry',
    (tester) => runHost(tester, () async {
      objectbox.downloadTaskBox.putMany([
        for (var index = 0; index < 250; index++)
          _task(
            index.isEven ? '下载作品 $index' : '需要恢复的下载作品 $index — ${'很长的名称' * 12}',
            index.isEven ? 'failed' : 'paused',
          ),
      ]);
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const DownloadTaskPage(),
        ),
      );
      await settleHost(tester);
      final list = find.byKey(const PageStorageKey('download-center.unified'));
      final scroll = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      final bottom = find.byKey(const ValueKey('download-list-bottom'));
      final top = find.byKey(const ValueKey('download-list-top'));
      expect(bottom, findsNothing);
      expect(top, findsNothing);
      expect(
        find.byType(CollectionPressFeedback).evaluate().length,
        lessThan(20),
      );
      position.jumpTo(position.viewportDimension * 2.5);
      await tester.pump();
      expect(top, findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      final entering = tester.getRect(top);
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: top, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(top.hitTestable(), findsOneWidget);
      final shown = tester.getRect(top);
      expect(entering.left, greaterThan(shown.left));
      expect(entering.bottom, shown.bottom);
      expect(shown.height, greaterThanOrEqualTo(44));
      expect(find.text(t.download.jumpToTop), findsNothing);
      expect(find.byTooltip(t.download.jumpToTop), findsOneWidget);
      expect(shown.right, closeTo(tester.getRect(list).right - 18, 1));
      expect(bottom, findsNothing);
      await tester.tap(top);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      position.jumpTo(100);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(list);
      final extent = position.maxScrollExtent;
      await _enterDownloadManagement(tester);
      await tester.pumpAndSettle();
      expect(tester.getRect(list), viewport);
      expect(position.pixels, 100);
      expect(position.maxScrollExtent, extent);

      await tester.tap(find.byType(DownloadCardSelection).hitTestable().first);
      await tester.pumpAndSettle();
      expect(tester.getRect(list), viewport);
      expect(position.pixels, 100);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      // The first jump materializes the lazily estimated final children.
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final endPosition = position.pixels;
      final last = find.byType(DownloadCardSelection).last;
      final delete = find.widgetWithText(TextButton, t.common.delete);
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getTopLeft(delete).dy),
      );
      await tester.tap(find.byTooltip(t.common.cancel));
      await tester.pumpAndSettle();
      expect(tester.getRect(list), viewport);
      expect(position.pixels, endPosition);
    }),
  );

  testWidgets(
    'comic work resume prefers an exact chapter over a legacy alias',
    (tester) => runHost(tester, () async {
      const source = 'offline-download-fixture';
      const title = 'Conflicting chapter identities';
      final key = buildDownloadTaskKey(source, title);
      objectbox.unifiedDownloadBox.put(
        createTestDownload(key)
          ..source = source
          ..comicId = title
          ..title = title
          ..chapters = jsonEncode([
            for (final (id, logicalKey, name, order) in [
              ('chapter-b', 'chapter-a', 'First chapter', 1),
              ('storage-b', 'chapter-b', 'Second chapter', 2),
            ])
              {
                'id': id,
                'logicalKey': logicalKey,
                'taskChapterId': 'shared-request',
                'name': name,
                'order': order,
                if (order == 2) 'completedAt': '2026-11-12T08:13:00Z',
                'images': [
                  {'path': 'page.jpg'},
                ],
              },
          ]),
      );
      final history = createTestHistory(key)
        ..source = source
        ..comicId = title
        ..chapterId = 'chapter-b'
        ..chapterTitle = 'Second chapter'
        ..pageIndex = 2;
      objectbox.unifiedHistoryBox.put(history);
      await ComicChapterReadingProgress.instance.record(
        source: source,
        comicId: title,
        chapterId: 'chapter-b',
        pageIndex: 1,
        lastVisiblePage: 1,
        pageCount: 1,
      );
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      await tester.tap(find.text(title));
      await settleHost(tester);

      final resume = find.byKey(const ValueKey('download-resume-entry'));
      expect(tester.widget<InkWell>(resume).onTap, isNotNull);
      expect(
        find.descendant(
          of: resume,
          matching: find.textContaining('Second chapter'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('download-chapter-reading.chapter-b')),
        findsOneWidget,
      );
      expect(find.text('Read'), findsOneWidget);
      final chapter = find.byKey(
        const ValueKey('download-chapter-open.chapter-b'),
      );
      expect(
        find.descendant(
          of: chapter,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
      final titleFinder = find.text('Second chapter');
      final titleBefore = tester.getRect(titleFinder);
      final chapterBefore = tester.getRect(chapter);
      final gesture = await tester.startGesture(tester.getCenter(chapter));
      await gesture.moveBy(const Offset(-27, 0));
      await gesture.moveBy(const Offset(-36, 0));
      await tester.pump();
      expect(tester.getRect(titleFinder).left, lessThan(titleBefore.left));
      expect(tester.getRect(chapter).right, lessThan(chapterBefore.right));
      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await settleHost(tester);
      final tray = find.byKey(const ValueKey('download-swipe-tray.chapter-b'));
      final time = find.byKey(
        const ValueKey('download-action-sheet-time.chapter-b'),
      );
      final well = find.byKey(const ValueKey('download-swipe-well.chapter-b'));
      final wellColor =
          (tester.widget<DecoratedBox>(well).decoration as BoxDecoration).color;
      expect(wellColor?.a, 1);
      expect(tester.widget<Material>(tray).type, MaterialType.transparency);
      expect(tester.getRect(titleFinder).left, lessThan(titleBefore.left));
      final rowRect = tester.getRect(chapter);
      final trayRect = tester.getRect(tray);
      expect(trayRect.right, closeTo(chapterBefore.right, .01));
      expect(trayRect.left, closeTo(rowRect.right, .01));
      expect(trayRect.center.dy, closeTo(rowRect.center.dy, .01));
      expect(rowRect.height, chapterBefore.height);
      expect(
        tester.getRect(titleFinder),
        rectMoreOrLessEquals(
          titleBefore.shift(rowRect.topLeft - chapterBefore.topLeft),
        ),
      );
      expect(time, findsNothing);
      expect(
        find.byKey(const ValueKey('download-row-more.chapter-b')).hitTestable(),
        findsOneWidget,
      );
      final information = find.byKey(
        const ValueKey('download-swipe.chapter-b.info'),
      );
      expect(information.hitTestable(), findsOneWidget);
      final delete = find.byKey(
        const ValueKey('download-swipe.chapter-b.delete'),
      );
      expect(delete.hitTestable(), findsOneWidget);
      expect(tester.getSize(delete).height, greaterThanOrEqualTo(44));
      await tester.tap(information);
      await settleHost(tester);
      expect(time, findsOneWidget);
      expect(tester.widget<Text>(time).data, startsWith('Downloaded '));
      expect(delete, findsNothing);
      await tester.binding.handlePopRoute();
      await settleHost(tester);
      expect(tester.getRect(titleFinder), titleBefore);
      await tester.drag(chapter, const Offset(-190, 0));
      await settleHost(tester);
      await tester.tap(delete);
      await waitForRemovalDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await settleHost(tester);
      expect(tester.getRect(titleFinder), titleBefore);
      await openRowActions(tester, 'chapter-b');
      await tester.tap(information);
      await settleRowMenuSelection(tester);
      expect(time, findsOneWidget);
      expect(tester.widget<Text>(time).data, startsWith('Downloaded '));
      await tester.binding.handlePopRoute();
      await settleHost(tester);

      final inFlight = _task(title, 'running')..isDownloading = true;
      objectbox.downloadTaskBox.put(inFlight);
      await settleHost(tester);
      await openRowActions(tester, 'chapter-b');
      expect(delete, findsNothing);
      await tester.tap(information);
      await settleRowMenuSelection(tester);
      expect(time, findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleHost(tester);
      objectbox.downloadTaskBox.remove(inFlight.id);
      await settleHost(tester);

      history.chapterId = 'shared-request';
      objectbox.unifiedHistoryBox.put(history);
      await settleHost(tester);
      expect(tester.widget<InkWell>(resume).onTap, isNull);
      await tester.drag(chapter, const Offset(-190, 0));
      await settleHost(tester);
      expect(tray.hitTestable(), findsOneWidget);
      final back = find.byType(SourceBackButton).hitTestable();
      expect(back, findsOneWidget);
      await tester.tap(back);
      await settleHost(tester);
      expect(chapter, findsNothing);
      await tester.tap(find.text(title));
      await settleHost(tester);
      expect(chapter, findsOneWidget);
      expect(tray, findsNothing);
    }),
  );

  testWidgets(
    'download management selects only visible removable items',
    (tester) => runHost(tester, () async {
      final active = _task('仍在下载', 'running')..isDownloading = true;
      final first = _task('来源甲的可删除作品', 'failed');
      final second = _task('来源乙的可删除作品', 'failed');
      second.taskInfo = second.taskInfo!.copyWith(
        from: 'another-offline-source',
      );
      objectbox.downloadTaskBox.putMany([active, first, second]);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);

      const activeKey = 'comic:offline-download-fixture:仍在下载';
      expect(
        find.byKey(const ValueKey('download-menu.$activeKey')),
        findsNothing,
      );
      expect(
        find.widgetWithText(TextButton, 'Pause downloads'),
        findsOneWidget,
      );
      await _enterDownloadManagement(tester);
      await settleHost(tester);
      final activeSelection = tester.widget<DownloadCardSelection>(
        find.byKey(const ValueKey('download-select.$activeKey')),
      );
      expect(activeSelection.onTap, isNull);
      final cancel = find.byKey(const ValueKey('download-selection.cancel'));
      final selectAll = find.byKey(
        const ValueKey('download-selection.select-all'),
      );
      final count = find.text(t.bookshelf.selectedCount(count: 0));
      expect(count, findsOneWidget);
      expect(
        find.descendant(of: cancel, matching: find.text(t.common.cancel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: selectAll, matching: find.text(t.common.selectAll)),
        findsOneWidget,
      );
      expect(tester.getCenter(cancel).dx, lessThan(tester.getCenter(count).dx));
      expect(
        tester.getCenter(selectAll).dx,
        greaterThan(tester.getCenter(count).dx),
      );
      await tester.tap(find.byTooltip(t.common.selectAll));
      await settleHost(tester);
      expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
      expect(find.byTooltip(t.bookshelf.deselectAll), findsOneWidget);
      await tester.tap(find.byTooltip(t.bookshelf.deselectAll));
      await settleHost(tester);
      expect(count, findsOneWidget);

      tester
          .widget<BookshelfSourceNavigation>(
            find.byType(BookshelfSourceNavigation),
          )
          .onChanged!(['another-offline-source']);
      await settleHost(tester);
      expect(count, findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, t.common.delete),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip(t.common.selectAll));
      await settleHost(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      await settleHost(tester);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(second.comicName),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(first.comicName),
        ),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, t.common.cancel),
        ),
      );
      await settleHost(tester);
      expect(objectbox.downloadTaskBox.count(), 3);
    }),
  );

  testWidgets(
    'source navigation is outside facets and selection immediately scopes the download list',
    (tester) => runHost(tester, () async {
      final first = _task('来源甲的作品', 'failed');
      final second = _task('来源乙的作品', 'failed');
      second.taskInfo = second.taskInfo!.copyWith(
        from: 'another-offline-source',
      );
      objectbox.downloadTaskBox.putMany([first, second]);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      final bar = tester.widget<BookshelfSourceNavigation>(
        find.byType(BookshelfSourceNavigation),
      );
      expect(
        bar.sources.keys,
        containsAll(['offline-download-fixture', 'another-offline-source']),
      );
      bar.onChanged!(['another-offline-source']);
      await settleHost(tester);
      expect(find.text('来源甲的作品'), findsNothing);
      expect(find.text('来源乙的作品'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('download-filter')));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadFilterSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DownloadFilterSheet),
          matching: find.byType(BookshelfSourceNavigation),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('download-filter-cancel')));
      await settleHost(tester);
      expect(
        tester
            .widget<BookshelfSourceNavigation>(
              find.byType(BookshelfSourceNavigation),
            )
            .selected,
        ['another-offline-source'],
      );
      tester
          .widget<BookshelfSourceNavigation>(
            find.byType(BookshelfSourceNavigation),
          )
          .onChanged!([]);
      await settleHost(tester);
      expect(find.text('来源甲的作品'), findsOneWidget);
      expect(find.text('来源乙的作品'), findsOneWidget);
      expect(objectbox.downloadTaskBox.count(), 2);
      expect(tester.takeException(), isNull);
    }),
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'chapter deletion updates task and legacy rows after cancel and failure: $style',
      (tester) => runHost(tester, () async {
        const source = 'offline-download-fixture', title = '单章删除测试';
        final task = _task(title, 'completed');
        task.taskInfo = task.taskInfo!.copyWith(
          chapterRef: const DownloadChapterTaskRef(
            chapterId: 'a',
            logicalKey: 'a',
            title: '有任务章节',
          ),
        );
        objectbox.downloadTaskBox.put(task);
        final record = createTestDownload(buildDownloadTaskKey(source, title))
          ..source = source
          ..comicId = title
          ..title = title
          ..chapters = jsonEncode([
            {
              'id': 'a',
              'logicalKey': 'a',
              'name': '有任务章节',
              'groupTitle': '默認',
              'order': 1,
              'storageChapterId': 'a',
              'images': [
                for (var index = 1; index <= 6; index++)
                  {'path': 'chapter-a-$index.jpg'},
              ],
            },
            {
              'id': 'b',
              'logicalKey': 'b',
              'name': '旧下载章节',
              'order': 2,
              'images': [],
            },
          ]);
        objectbox.unifiedDownloadBox.put(record);
        objectbox.unifiedFavoriteBox.put(
          createTestFavorite(buildDownloadTaskKey(source, title)),
        );
        objectbox.unifiedHistoryBox.put(
          createTestHistory(buildDownloadTaskKey(source, title))
            ..source = source
            ..comicId = title
            ..chapterId = 'a'
            ..chapterTitle = '有任务章节'
            ..chapterOrder = 2
            ..pageIndex = 6,
        );
        await tester.runAsync(() async {
          await createDownloadFixture(source, title);
          for (var index = 1; index <= 6; index++) {
            final store = DownloadAssetStore(
              from: source,
              cartoonId: title,
              chapterId: 'a',
              storageChapterId: 'a',
              path: 'chapter-a-$index.jpg',
              pictureType: PictureType.page,
            );
            final file = File((await store.canonicalDownloadCandidate()).path);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(List.filled(index == 6 ? 343 : 341, 7));
          }
          final actual = objectbox.unifiedDownloadBox.get(record.id)!;
          final size = await DownloadResourceMetrics.instance.readComic(
            DownloadComicResource(actual),
          );
          expect(size.status, DownloadResourceSizeStatus.partial);
          expect(size.knownBytes, 2048);
          expect(size.chapters['a']!.sizeBytes, 2048);
        });
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        await settleHost(tester);
        await tester.tap(find.text(title));
        await settleHost(tester);
        Finder chapter(String key) =>
            find.byKey(ValueKey('download-chapter-open.$key'));
        Finder remove(String key) =>
            find.byKey(ValueKey('download-swipe.$key.delete'));
        Future<void> reveal(String key) async {
          final row = chapter(key);
          await tester.ensureVisible(row);
          await tester.drag(row, const Offset(-150, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          final action = find
              .byKey(ValueKey('download-swipe.$key.delete'))
              .hitTestable();
          expect(action, findsOneWidget);
          expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        }

        expect(find.textContaining('默認'), findsNothing);
        expect(remove('a'), findsNothing);
        expect(remove('b'), findsNothing);
        expect(tester.widget<InkWell>(chapter('a')).onTap, isNotNull);
        expect(tester.widget<InkWell>(chapter('b')).onTap, isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('download-chapters-cover'))),
          const Size(60, 90),
        );
        expect(find.text(source), findsWidgets);
        expect(find.text('1 downloaded chapters'), findsOneWidget);
        expect(find.text('Continue reading'), findsOneWidget);
        expect(find.text('有任务章节'), findsWidgets);
        expect(
          find.text(t.comicInfo.readProgressPage(page: '5')),
          findsOneWidget,
        );
        expect(find.text('读到第2话 · 第5页'), findsNothing);
        final lastReadMark = find.byKey(
          const ValueKey('download-chapter-reading.a'),
        );
        expect(lastReadMark, findsOneWidget);
        expect(
          find.byKey(const ValueKey('download-resume-position')),
          findsOneWidget,
        );
        final heights = {
          for (final key in ['a', 'b'])
            key: tester.getSize(chapter(key)).height,
        };
        final history = objectbox.unifiedHistoryBox.getAll().single;
        history.pageIndex = 1000;
        objectbox.unifiedHistoryBox.put(history);
        await settleHost(tester);
        expect(
          find.text(t.comicInfo.readProgressPage(page: '6')),
          findsOneWidget,
        );
        for (final key in ['a', 'b']) {
          expect(tester.getSize(chapter(key)).height, heights[key]);
        }
        history.deleted = true;
        objectbox.unifiedHistoryBox.put(history);
        await settleHost(tester);
        expect(lastReadMark, findsNothing);
        expect(
          find.byKey(const ValueKey('download-resume-entry')),
          findsNothing,
        );
        for (final key in ['a', 'b']) {
          expect(tester.getSize(chapter(key)).height, heights[key]);
        }
        history.deleted = false;
        history.pageIndex = 6;
        objectbox.unifiedHistoryBox.put(history);
        await settleHost(tester);
        expect(lastReadMark, findsOneWidget);
        expect(
          tester
              .widget<InkWell>(
                find.byKey(const ValueKey('download-resume-entry')),
              )
              .onTap,
          isNotNull,
        );
        expect(_workPane(DownloadWorkPane.saved), findsOneWidget);
        expect(_chapterList(DownloadWorkPane.saved), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('download-chapters-total-size')),
              )
              .data,
          t.download.comicSavedBytes(amount: '2.0 KB'),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('download-chapter-size.a')),
              )
              .data,
          '2.0 KB',
        );
        expect(
          find.byKey(const ValueKey('download-chapter-size.b')),
          findsNothing,
        );
        Future<void> confirm() async {
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextButton, t.common.delete),
            ),
          );
          await settleHost(tester);
        }

        final manage = find.byKey(const ValueKey('download-episodes-manage'));
        final batchDelete = find.byKey(
          const ValueKey('download-episodes-delete'),
        );
        await reveal('a');
        await tester.tap(manage);
        await settleHost(tester);
        expect(remove('a'), findsNothing);
        expect(
          batchDelete,
          findsNothing,
          reason: 'First outside tap only closes the tray.',
        );
        await tester.longPress(chapter('a'));
        await settleHost(tester);
        expect(remove('a'), findsNothing);
        expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
        expect(tester.getSize(chapter('a')).height, heights['a']);
        await tester.tap(
          find.byKey(const ValueKey('download-episodes-select-all')),
        );
        await settleHost(tester);
        expect(find.text(t.bookshelf.selectedCount(count: 2)), findsOneWidget);
        await tester.tap(batchDelete);
        await settleHost(tester);
        expect(find.textContaining('2 selected chapters'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await settleHost(tester);
        expect(objectbox.unifiedDownloadBox.count(), 1);
        await tester.binding.handlePopRoute();
        await settleHost(tester);
        expect(batchDelete, findsNothing);
        expect(chapter('a'), findsOneWidget);

        await tester.ensureVisible(chapter('a'));
        await openRowActions(tester, 'a');
        await tester.tap(remove('a'));
        await waitForRemovalDialog(tester);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await settleHost(tester);
        expect(objectbox.downloadTaskBox.count(), 1);
        expect(
          (jsonDecode(objectbox.unifiedDownloadBox.getAll().single.chapters)
                  as List)
              .length,
          2,
        );
        record.detailJson = '{invalid';
        objectbox.unifiedDownloadBox.put(record);
        await settleHost(tester);
        await tester.ensureVisible(chapter('a'));
        await openRowActions(tester, 'a');
        await tester.tap(remove('a'));
        await waitForRemovalDialog(tester);
        await confirm();
        expect(chapter('a'), findsOneWidget);
        expect(chapter('b'), findsOneWidget);
        expect(objectbox.downloadTaskBox.count(), 1);
        expect(
          find.byKey(const ValueKey('download-chapter-error.a')),
          findsOneWidget,
        );
        record.detailJson = '';
        objectbox.unifiedDownloadBox.put(record);
        await settleHost(tester);
        await tester.ensureVisible(chapter('a'));
        await openRowActions(tester, 'a');
        await tester.tap(remove('a'));
        await waitForRemovalDialog(tester);
        await confirm();
        expect(chapter('a'), findsNothing);
        expect(chapter('b'), findsOneWidget);
        expect(find.text('Last-read chapter is unavailable'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('download-chapter-reading.a')),
          findsNothing,
        );
        expect(objectbox.downloadTaskBox.count(), 0);
        await tester.ensureVisible(chapter('b'));
        await openRowActions(tester, 'b');
        await tester.tap(remove('b'));
        await waitForRemovalDialog(tester);
        await confirm();
        expect(objectbox.unifiedDownloadBox.count(), 0);
        expect(objectbox.downloadTaskBox.count(), 0);
        expect(objectbox.unifiedFavoriteBox.count(), 1);
        expect(objectbox.unifiedHistoryBox.count(), 1);
        await tester.binding.handlePopRoute();
        await settleHost(tester);
        expect(find.text(title), findsNothing);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'real bottom-tab download host renders all states and survives style changes',
    (tester) => runHost(tester, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadUiPreviewFonts();
      const previewKey = ValueKey('download.selection.preview');
      final completed = _task('已完成的作品', 'completed');
      await tester.runAsync(() => _saveComicResource(completed));
      objectbox.downloadTaskBox.putMany([
        _task('进行中的作品', 'downloading'),
        completed,
        _task('未完成的作品', 'failed'),
      ]);
      final preference = ValueNotifier('breeze');
      final controller = PersistentTabController();
      addTearDown(preference.dispose);
      addTearDown(controller.dispose);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final channel = MethodChannel('${args['viewType']}.${args['id']}');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      for (final brightness in Brightness.values) {
        final colors = BreezeThemeColors.fromSeed(
          const Color(0xff009688),
          brightness,
        );
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: colors,
                scaffoldBackgroundColor: colors.surface,
                fontFamily: uiPreviewDirectory == null
                    ? null
                    : 'AccountPreview',
              ),
              home: RepaintBoundary(
                key: previewKey,
                child: app.MainNativeTabHost(
                  controller: controller,
                  screens: const [DownloadTaskPage(embedded: true)],
                  navBarHeight: 84,
                  navigation: const SizedBox(height: 84),
                ),
              ),
            ),
          ),
        );
        await settleHost(tester);
        for (final style in ['breeze', 'system', 'breeze']) {
          preference.value = style;
          await settleHost(tester);
          // One media selector, never separate download-status destinations.
          expect(find.byType(NativeVideoSegmentedControl), findsOneWidget);
          for (final title in ['进行中的作品', '未完成的作品', '已完成的作品']) {
            expect(find.text(title), findsOneWidget);
          }
          for (final menu in tester.widgetList<NativeVideoMenu>(
            find.byType(NativeVideoMenu),
          )) {
            if (menu.icon != null && menu.label.isEmpty) {
              expect(
                menu.symbol,
                isNotEmpty,
                reason:
                    'UIKit requires its own glyph, independently of the Flutter icon.',
              );
            }
          }
          expect(
            find.ancestor(
              of: find.byType(NativeVideoMenu),
              matching: find.byType(CollectionPressFeedback),
            ),
            findsNothing,
            reason: 'A row press must not scale the UIKit menu frame.',
          );
          expect(
            find.byKey(const ValueKey('download-clear-records')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }

        final segment = find.byType(NativeVideoSegmentedControl);
        await tester.tap(
          find.descendant(
            of: segment,
            matching: find.byKey(const ValueKey('comic')),
          ),
        );
        await settleHost(tester);
        final sectionPlate = tester.getRect(
          find.descendant(
            of: segment,
            matching: find.byKey(const ValueKey('breeze.selection.plate')),
          ),
        );
        final sourceTarget = tester.getRect(
          find.byKey(const ValueKey('bookshelf.source.')),
        );
        const sourceInset = CollectionToolbarMetrics.actionPlateInset;
        final sourcePlate = Rect.fromLTRB(
          sourceTarget.left,
          sourceTarget.top + sourceInset,
          sourceTarget.right,
          sourceTarget.bottom - sourceInset,
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(previewKey),
        );
        final contrasts = await tester.runAsync(() async {
          const scale = 2.0;
          final image = await boundary.toImage(pixelRatio: scale);
          try {
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            Color pixel(Offset global) {
              final local = boundary.globalToLocal(global) * scale;
              final index =
                  4 * (local.dy.floor() * image.width + local.dx.floor());
              return Color.fromARGB(
                255,
                rgba.getUint8(index),
                rgba.getUint8(index + 1),
                rgba.getUint8(index + 2),
              );
            }

            return [
              for (final (name, plate, background) in [
                (
                  'segment',
                  sectionPlate,
                  Offset(sectionPlate.center.dx, sectionPlate.top - 1),
                ),
                (
                  'source',
                  sourcePlate,
                  Offset(sourcePlate.left - 8, sourcePlate.center.dy),
                ),
              ])
                (
                  name: name,
                  backdropContrast: BreezeThemeColors.contrast(
                    pixel(Offset(plate.center.dx, plate.top + 6)),
                    pixel(background),
                  ),
                  edge: pixel(Offset(plate.center.dx, plate.top + .65)),
                  fill: pixel(Offset(plate.center.dx, plate.top + 6)),
                  upperInset: pixel(Offset(plate.center.dx, plate.top + 2.25)),
                  lowerInset: pixel(
                    Offset(plate.center.dx, plate.bottom - 2.25),
                  ),
                  backdrop: pixel(background),
                  upperOutside: pixel(
                    Offset(plate.center.dx, plate.top - 1.25),
                  ),
                  lowerOutside: pixel(
                    Offset(plate.center.dx, plate.bottom + 1.25),
                  ),
                ),
            ];
          } finally {
            image.dispose();
          }
        });
        await writeUiPreview(
          tester,
          previewKey,
          'download-teal-${brightness.name}',
        );
        for (final sample in contrasts!) {
          final reason = '${brightness.name} ${sample.name}';
          if (sample.name == 'source') {
            expect(
              sample.upperInset.computeLuminance(),
              lessThan(sample.fill.computeLuminance()),
              reason: '$reason upper edge is inset',
            );
            expect(
              sample.lowerInset.computeLuminance(),
              greaterThan(sample.fill.computeLuminance()),
              reason: '$reason lower edge catches light',
            );
            expect(
              sample.edge,
              isNot(sample.upperInset),
              reason: '$reason rim is distinct',
            );
            expect(
              sample.upperOutside.computeLuminance(),
              greaterThan(sample.backdrop.computeLuminance()),
              reason: '$reason reflects light above the rim',
            );
            expect(
              sample.lowerOutside.computeLuminance(),
              lessThan(sample.backdrop.computeLuminance()),
              reason: '$reason casts a shadow below the rim',
            );
          } else {
            expect(sample.edge, sample.fill, reason: '$reason has no border');
          }
          expect(
            sample.backdropContrast,
            inInclusiveRange(
              sample.name == 'segment' ? 1.10 : 1.03,
              sample.name == 'source' && brightness == Brightness.light
                  ? 1.13
                  : 1.6,
            ),
            reason: '$reason fill separates from its painted backdrop',
          );
        }
      }
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final compact in [false, true]) {
    testWidgets(
      'persistent nearby entry preserves plain host when main owner is absent, compact=$compact',
      (tester) => runHost(tester, () async {
        expect(DownloadCenterNavigation.available, isFalse);
        objectbox.downloadTaskBox.put(_task('入口任务', 'queued'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => DownloadTaskEntry(
                  compact: compact,
                  onOpen: () => openDownloadTasks(context),
                ),
              ),
            ),
          ),
        );
        await settleHost(tester);
        final entry = find.byKey(const ValueKey('download-task-entry'));
        expect(entry, findsOneWidget);
        expect(tester.getSize(entry).height, greaterThanOrEqualTo(44));
        if (!compact) {
          expect(find.text(t.download.pending(count: 1)), findsOneWidget);
        }
        await tester.tap(entry);
        await settleHost(tester);
        expect(
          find.byType(DownloadTaskPage),
          findsNothing,
          reason:
              'an absent main owner must never create an independent download route',
        );
        expect(objectbox.downloadTaskBox.getAll().single.comicName, '入口任务');
        expect(
          find.byKey(const ValueKey('download-task-entry')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'real task host follows progress to persistent completion',
    (tester) => runHost(tester, () async {
      final task = _task('可见任务', 'downloading');
      objectbox.downloadTaskBox.put(task);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      expect(find.text('可见任务'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, .3);

      await tester.runAsync(() => _saveComicResource(task));
      task
        ..isDownloading = false
        ..isCompleted = true
        ..taskInfo = task.taskInfo!.copyWith(
          stateCode: 'completed',
          completedImages: 10,
        );
      objectbox.downloadTaskBox.put(task);
      expect(
        objectbox.downloadTaskBox.get(task.id)!.taskInfo!.stateCode,
        'completed',
      );
      for (
        var i = 0;
        i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('可见任务'), findsOneWidget);
      expect(find.text(t.download.completed), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      expect(
        find.text('可见任务'),
        findsOneWidget,
        reason:
            'Reopening the actual page must read the completion from the DB.',
      );
      expect(
        find.byKey(
          const ValueKey('download-open.comic:offline-download-fixture:可见任务'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'short lists refresh and long press enters then leaves management without deleting',
    (tester) => runHost(tester, () async {
      final task = _task('保留的下载', 'completed');
      await tester.runAsync(() => _saveComicResource(task));
      objectbox.downloadTaskBox.put(task);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      final list = find.byKey(const PageStorageKey('download-center.unified'));
      expect(
        tester.widget<CustomScrollView>(list).physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );
      expect(
        find.ancestor(
          of: find.text('保留的下载'),
          matching: find.byType(CollectionPressFeedback),
        ),
        findsOneWidget,
      );
      await tester.longPress(find.text('保留的下载'));
      await settleHost(tester);
      expect(find.byTooltip(t.common.cancel), findsOneWidget);
      final selection = find.byType(DownloadCardSelection);
      expect(selection, findsOneWidget);
      expect(tester.widget<DownloadCardSelection>(selection).selected, isTrue);
      await tester.tap(find.byTooltip(t.common.cancel));
      await settleHost(tester);
      expect(selection, findsNothing);

      await tester.tap(find.byTooltip(t.common.search));
      await settleHost(tester);
      await tester.enterText(find.byType(TextField), '保留');
      await settleHost(tester);
      await tester.longPress(find.text('保留的下载'));
      await settleHost(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(t.bookshelf.selectedCount(count: 1)), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleHost(tester);
      final editor = tester.widget<TextField>(find.byType(TextField));
      expect(editor.controller?.text, '保留');
      expect(editor.focusNode?.hasFocus, isFalse);
      expect(selection, findsNothing);
      expect(objectbox.downloadTaskBox.get(task.id), isNotNull);
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'failed legacy video tap never attempts to open a nonexistent local file',
    (tester) => runHost(tester, () async {
      const source = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
      late String key, itemKey;
      await tester.runAsync(() async {
        key = await VideoExportRecords.beginTransfer(
          source: source,
          // A shared /videos ID without its declared module is genuinely not
          // enough to navigate. A /voddetail/42 ID is now recoverable.
          video: Uri.parse(
            'https://fixture.test/videos/legacy42?line=main&episode=one',
          ),
          title: 'Failed legacy video',
          quality: '',
          queued: true,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'failed',
          failureReason: 'missingIdentity',
          terminal: true,
        );
        final rows = await DownloadCenterResources.readVideos();
        expect(VideoDownloadRetry.needsSource(rows.single), isTrue);
        expect(videoDownloadSourceTarget(rows.single), isNull);
        itemKey = projectDownloadCenter(
          tasks: [],
          comics: [],
          videos: rows,
        ).single.key;
      });
      final events = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(events.add);
      addTearDown(subscription.cancel);
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      final row = find.byKey(ValueKey('download-open.$itemKey'));
      expect(row.hitTestable(), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(
        events.map((event) => event.message),
        contains(t.download.sourceUnavailableHint),
      );
      expect(
        events.map((event) => event.message),
        isNot(contains(t.download.fileUnavailable)),
      );
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'failed task is labelled failed rather than waiting',
    (tester) => runHost(tester, () async {
      objectbox.downloadTaskBox.put(_task('失败任务', 'failed'));
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      expect(find.text(t.download.notificationFailedTitle), findsOneWidget);
      expect(find.text('测试下载失败'), findsOneWidget);
      expect(find.widgetWithText(TextButton, t.common.retry), findsOneWidget);
      expect(find.text(t.download.pending(count: 1)), findsNothing);
      expect(tester.takeException(), isNull);
    }),
  );
  testWidgets(
    'download source labels hide tabs only, reset defaults and preserve all tasks',
    (tester) => runHost(tester, () async {
      const firstSource = 'offline-download-fixture',
          secondSource = 'another-offline-source';
      final first = _task('隐藏来源的作品', 'failed'),
          second = _task('可见来源的作品', 'failed');
      second.taskInfo = second.taskInfo!.copyWith(from: secondSource);
      objectbox.downloadTaskBox.putMany([first, second]);
      final store = BookshelfSourcePreferenceStore();
      await store.save(
        BookshelfSourceMedium.download,
        BookshelfSourcePreferences(
          order: [secondSource, firstSource],
          hidden: [firstSource],
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
      await settleHost(tester);
      expect(
        find.byKey(const ValueKey('bookshelf.source.offline-download-fixture')),
        findsNothing,
      );
      expect(find.text('隐藏来源的作品'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('bookshelf.source.another-offline-source')),
      );
      await settleHost(tester);
      expect(find.text('隐藏来源的作品'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bookshelf.sources.manage')));
      await settleHost(tester);
      await tester.tap(
        find.byKey(
          const ValueKey('source-manager.visible.another-offline-source'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('source-manager.done')));
      await settleHost(tester);
      expect(
        tester
            .widget<BookshelfSourceNavigation>(
              find.byType(BookshelfSourceNavigation),
            )
            .selected,
        isEmpty,
      );
      expect(find.text('隐藏来源的作品'), findsOneWidget);
      expect(find.text('可见来源的作品'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bookshelf.source.another-offline-source')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('bookshelf.sources.manage')));
      await settleHost(tester);
      await tester.tap(find.byKey(const ValueKey('source-manager.reset')));
      await tester.tap(find.byKey(const ValueKey('source-manager.done')));
      await settleHost(tester);
      expect(
        (await store.read(BookshelfSourceMedium.download)).hidden,
        isEmpty,
      );
      expect(
        tester
            .widget<BookshelfSourceNavigation>(
              find.byType(BookshelfSourceNavigation),
            )
            .sources
            .keys,
        containsAll([firstSource, secondSource]),
      );
      expect(objectbox.downloadTaskBox.count(), 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settleHost(tester);
    }),
  );
}
