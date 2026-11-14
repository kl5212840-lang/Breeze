import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/type/enum.dart';

import '../test_helper.dart';
import '../download_fixture.dart';

class _HeldRuntime extends RustLibApi {
  final entered = Completer<void>();
  final release = Completer<void>();
  final runtimeChecks = <String>[];
  bool holdDetail = false;
  DownloadTaskJson? heldImageTask;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async {
    runtimeChecks.add(name);
    if (holdDetail || heldImageTask != null) return true;
    if (!entered.isCompleted) entered.complete();
    await release.future;
    throw StateError('fixture runtime failure');
  }

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('fixture bundle');

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async {
    if (!release.isCompleted) release.complete();
    return true;
  }

  @override
  Future<QjsCancelTasksByGroupResult> crateApiQjsQjsCancelTasksByGroup({
    required String runtimeName,
    required String taskGroupKey,
  }) async {
    if (!release.isCompleted) release.complete();
    return const QjsCancelTasksByGroupResult(
      cancelled: 1,
      notFound: 0,
      failedRuntimeGroups: [],
    );
  }

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    if (fnPath == 'init') return Uint8List.fromList(utf8.encode('{}'));
    if (heldImageTask case final task?) {
      final response = switch (fnPath) {
        'getComicDetail' => {
          'normal': {
            'comicInfo': {
              'id': task.comicId,
              'title': task.comicName,
              'titleMeta': [],
              'description': '',
              'cover': {'id': '', 'url': '', 'name': ''},
              'metadata': [],
            },
            'eps': [],
            'recommend': [],
          },
        },
        'getChapter' => {
          'chapter': {
            'epId': task.chapterKey,
            'docs': [
              for (final path in ['shared.png', 'held.png'])
                {'path': path, 'url': 'https://fixture.invalid/$path'},
            ],
          },
        },
        'getDownloadConcurrency' => {'concurrency': 1},
        _ => throw StateError('Unexpected plugin function $fnPath'),
      };
      return Uint8List.fromList(utf8.encode(jsonEncode(response)));
    }
    expect(fnPath, 'getComicDetail');
    if (!entered.isCompleted) entered.complete();
    await release.future;
    throw StateError('__QJS_RUNTIME_CANCELLED__');
  }

  @override
  Future<Uint8List> crateApiQjsQjsFetchImage({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    expect(jsonDecode(argsJson)['url'], 'https://fixture.invalid/held.png');
    if (!entered.isCompleted) entered.complete();
    await release.future;
    throw const DownloadTaskCancelledException();
  }

  @override
  String crateApiSimpleEncodePath({required String path}) =>
      'fixture-${path.codeUnits.join('-')}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDownAll(connectivity.close);

  final queue = DownloadQueueManager.instance;
  late _HeldRuntime runtime;
  setUp(() {
    connectivity.set(ConnectivityResult.wifi);
    runtime = _HeldRuntime();
    RustLib.initMock(api: runtime);
  });
  tearDown(() async {
    queue.stopWatchingTasks();
    objectbox.downloadTaskBox.removeAll();
    objectbox.unifiedDownloadBox.removeAll();
    if (!runtime.release.isCompleted) runtime.release.complete();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (queue.isProcessing && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(queue.isProcessing, isFalse);
    RustLib.dispose();
  });

  DownloadTaskJson payload(String chapter) => DownloadTaskJson(
    from: 'startup-resume-fixture',
    comicId: 'work',
    comicName: 'Work',
    chapterRef: DownloadChapterTaskRef(chapterId: chapter, title: chapter),
  );

  int seed(DownloadTaskJson payload, {bool running = false}) {
    return objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = payload.comicId
        ..comicName = payload.comicName
        ..isDownloading = running
        ..taskInfo = payload,
    );
  }

  const delay = Duration(minutes: 1);
  const deadline = Duration(seconds: 5);

  test(
    'backup holds new comic transfers and refuses file backup or restore during a live worker',
    () async {
      const capacity = MethodChannel('breeze.download.capacity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final checking = Completer<void>(), available = Completer<int>();
      messenger.setMockMethodCallHandler(capacity, (_) async {
        if (!checking.isCompleted) checking.complete();
        return available.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(capacity, null));
      final root = await Directory.systemTemp.createTemp(
        'breeze-backup-download-',
      );
      addTearDown(() => root.delete(recursive: true));
      final id = seed(payload('backup-admission'));
      queue.watchTasks();
      await checking.future.timeout(deadline);
      final paused = DownloadAdmission.instance.queuePaused;
      await queue.withStableDownloadTree(() async {
        available.complete(1 << 30);
        await Future<void>.delayed(Duration.zero);
        expect(objectbox.downloadTaskBox.get(id)!.isDownloading, isFalse);
        expect(runtime.runtimeChecks, isEmpty);
        expect(DownloadAdmission.instance.queuePaused, paused);
      });
      await runtime.entered.future.timeout(deadline);

      final zip = File('${root.path}/backup.zip');
      await expectLater(
        exportBreezeBackup(zipPath: zip.path, includeDownloads: true),
        throwsA(isA<ComicDownloadTreeBusy>()),
      );
      expect(await zip.exists(), isFalse);
      await File(
        '${root.path}/config.json',
      ).writeAsString('{"includeDownloads":true}');
      await expectLater(
        importExtractedBreezeData(root.path, restoreDownloadFiles: true),
        throwsA(isA<ComicDownloadTreeBusy>()),
      );
      expect(objectbox.downloadTaskBox.get(id)!.isDownloading, isTrue);
    },
  );

  test('paused comic queue resumes with the selected queued chapter', () async {
    final admission = DownloadAdmission.instance;
    await admission.setQueuePaused(true);
    try {
      final first = seed(payload('first'));
      final next = seed(payload('next'));
      queue.watchTasks();
      final snapshot = objectbox.downloadTaskBox.get(next)!;
      expect(queue.prioritize(snapshot), isTrue);
      expect(runtime.entered.isCompleted, isFalse);
      await admission.setQueuePaused(false);
      await runtime.entered.future.timeout(deadline);
      expect(objectbox.downloadTaskBox.get(next)!.isDownloading, isTrue);
      expect(objectbox.downloadTaskBox.get(first)!.isDownloading, isFalse);
      expect(queue.prioritize(snapshot), isFalse);
    } finally {
      await admission.setQueuePaused(false);
    }
  });

  test(
    'explicit queue resume bypasses startup delay and preserves admission',
    () async {
      final admission = DownloadAdmission.instance;
      await admission.setQueuePaused(true);
      try {
        connectivity.set(ConnectivityResult.none);
        final interrupted = seed(
          payload('recover').copyWith(
            phaseCode: 'resume',
            attempt: 3,
            imagePaths: ['saved.png'],
          ),
        );
        final manuallyPaused = seed(
          payload('paused').copyWith(
            stateCode: 'paused',
            phaseCode: 'userPaused',
            attempt: 4,
            imagePaths: ['paused.png'],
          ),
        );
        final paused = objectbox.downloadTaskBox.get(manuallyPaused)!;
        queue.watchTasks(startupResumeDelay: delay);
        expect(runtime.entered.isCompleted, isFalse);

        await queue.resumeQueueFromUser();
        expect(admission.queuePaused, isFalse);
        final waitingBy = DateTime.now().add(deadline);
        while (objectbox.downloadTaskBox
                    .get(interrupted)
                    ?.taskInfo
                    ?.phaseCode !=
                'waitingNetwork' &&
            DateTime.now().isBefore(waitingBy)) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        final waiting = objectbox.downloadTaskBox.get(interrupted)!;
        expect(waiting.taskInfo!.phaseCode, 'waitingNetwork');
        expect(waiting.taskInfo!.attempt, 3);
        expect(runtime.runtimeChecks, isEmpty);

        connectivity.set(ConnectivityResult.wifi);
        await runtime.entered.future.timeout(deadline);
        final active = objectbox.downloadTaskBox.get(interrupted)!;
        expect(active.isDownloading, isTrue);
        expect(active.taskInfo!.attempt, 4);
        expect(active.taskInfo!.imagePaths, ['saved.png']);
        expect(
          objectbox.downloadTaskBox.get(manuallyPaused)!.dbTaskInfoStr,
          paused.dbTaskInfoStr,
        );
      } finally {
        await admission.setQueuePaused(false);
      }
    },
  );

  test(
    'known low storage preserves a queued comic for a later retry',
    () async {
      const channel = MethodChannel('breeze.download.capacity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var available = 1024;
      messenger.setMockMethodCallHandler(channel, (_) async => available);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final id = seed(
        payload('low-storage').copyWith(imagePaths: ['checkpoint.png']),
      );
      queue.watchTasks();
      final failedBy = DateTime.now().add(deadline);
      while (objectbox.downloadTaskBox.get(id)?.taskInfo?.lastErrorCode !=
              'outOfSpace' &&
          DateTime.now().isBefore(failedBy)) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final waiting = objectbox.downloadTaskBox.get(id)!.taskInfo!;
      expect(waiting.lastErrorCode, 'outOfSpace');
      expect(waiting.imagePaths, ['checkpoint.png']);
      expect(runtime.runtimeChecks, isEmpty);
      available = 1024 * 1024 * 1024;
      await queue.retryTask(id);
      await runtime.entered.future.timeout(deadline);
      expect(runtime.runtimeChecks, [waiting.from]);
    },
  );

  test(
    'an offline comic stays queued and starts once on reconnection',
    () async {
      connectivity.set(ConnectivityResult.none);
      final id = seed(
        payload('offline').copyWith(imagePaths: ['checkpoint.png']),
      );
      queue.watchTasks();
      final waitingBy = DateTime.now().add(deadline);
      while (objectbox.downloadTaskBox.get(id)?.taskInfo?.phaseCode !=
              'waitingNetwork' &&
          DateTime.now().isBefore(waitingBy)) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final waiting = objectbox.downloadTaskBox.get(id)!.taskInfo!;
      expect(waiting.phaseCode, 'waitingNetwork');
      expect(waiting.imagePaths, ['checkpoint.png']);
      expect(runtime.runtimeChecks, isEmpty);
      connectivity.set(ConnectivityResult.wifi);
      await runtime.entered.future.timeout(deadline);
      expect(runtime.runtimeChecks, [waiting.from]);
      expect(
        objectbox.downloadTaskBox.get(id)!.taskInfo!.attempt,
        waiting.attempt + 1,
      );
    },
  );

  Future<void> seedPlugin(String source, {required bool enabled}) async {
    final now = DateTime.utc(2026);
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: source,
        version: '1.0.0',
        originScript: 'fixture bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: enabled,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
      ),
    );
  }

  test('cold recovery removes explicit legacy deletion markers only', () {
    final removedId = seed(
      payload(
        'removed',
      ).copyWith(stateCode: 'completed', phaseCode: 'fileRemoved'),
    );
    final retryId = seed(
      payload(
        'retry',
      ).copyWith(stateCode: 'failed', lastErrorMessage: 'fileRemoved'),
    );
    final savedId = seed(payload('saved').copyWith(stateCode: 'completed'));

    queue.resetStuckTasks();
    queue.resetStuckTasks();

    expect(objectbox.downloadTaskBox.get(removedId), isNull);
    expect(
      objectbox.downloadTaskBox.get(retryId)?.taskInfo?.stateCode,
      'failed',
    );
    expect(
      objectbox.downloadTaskBox.get(savedId)?.taskInfo?.stateCode,
      'completed',
    );
  });

  test(
    'cold recovery pauses a disabled source and runs the next source',
    () async {
      const disabledSource = 'disabled-resume-fixture';
      await seedPlugin(disabledSource, enabled: false);
      final disabledId = seed(
        payload('interrupted').copyWith(
          from: disabledSource,
          stateCode: 'running',
          attempt: 3,
          completedImages: 1,
          imagePaths: ['checkpoint.png'],
        ),
        running: true,
      );
      final healthy = payload('healthy');
      final healthyId = seed(healthy);

      queue.resetStuckTasks();
      queue.watchTasks();
      await runtime.entered.future.timeout(deadline);

      final disabled = objectbox.downloadTaskBox.get(disabledId)!;
      expect(disabled.isCompleted, isFalse);
      expect(disabled.isDownloading, isFalse);
      expect(disabled.taskInfo!.stateCode, 'paused');
      expect(disabled.taskInfo!.phaseCode, 'pluginDisabled');
      expect(disabled.taskInfo!.attempt, 3);
      expect(disabled.taskInfo!.imagePaths, ['checkpoint.png']);
      expect(runtime.runtimeChecks, [healthy.from]);
      expect(objectbox.downloadTaskBox.get(healthyId)!.isDownloading, isTrue);
      await expectLater(
        queue.retryTask(disabledId),
        throwsA(isA<DownloadSourceDisabled>()),
      );
    },
  );

  test(
    'disabling an in-flight source retains files and waits for retry',
    () async {
      const source = 'disable-in-flight-fixture';
      await seedPlugin(source, enabled: true);
      runtime.holdDetail = true;
      final running = payload(
        'in-flight',
      ).copyWith(from: source, imagePaths: ['checkpoint.png']);
      final runningId = seed(running);
      final queuedId = seed(payload('queued').copyWith(from: source));
      final completedId = seed(
        payload('completed').copyWith(from: source, stateCode: 'completed'),
      );
      final completed = objectbox.downloadTaskBox.get(completedId)!;
      completed.isCompleted = true;
      objectbox.downloadTaskBox.put(completed);
      final checkpoint = File(
        await DownloadAssetStore(
          from: source,
          path: 'checkpoint.png',
          cartoonId: running.comicId,
          chapterId: running.chapterKey,
          pictureType: PictureType.page,
        ).canonicalDownloadPath(),
      );
      await checkpoint.parent.create(recursive: true);
      await checkpoint.writeAsString('partial image');

      queue.watchTasks();
      await runtime.entered.future.timeout(deadline);
      expect(objectbox.downloadTaskBox.get(runningId)!.isDownloading, isTrue);
      final disabling = PluginRegistryService.I.setEnabled(source, false);
      queue.cancelCurrentTask();
      await disabling.timeout(deadline);
      queue.stopWatchingTasks();

      final paused = objectbox.downloadTaskBox.get(runningId)!;
      expect(paused.isCompleted, isFalse);
      expect(paused.isDownloading, isFalse);
      expect(paused.taskInfo!.stateCode, 'paused');
      expect(paused.taskInfo!.imagePaths, ['checkpoint.png']);
      expect(await checkpoint.readAsString(), 'partial image');
      expect(
        objectbox.downloadTaskBox.get(queuedId)!.taskInfo!.stateCode,
        'paused',
      );
      expect(
        objectbox.downloadTaskBox.get(completedId)!.dbTaskInfoStr,
        completed.dbTaskInfoStr,
      );
      expect(objectbox.unifiedDownloadBox.count(), 0);

      await PluginRegistryService.I.setEnabled(source, true, initialize: false);
      expect(
        objectbox.downloadTaskBox.get(runningId)!.taskInfo!.stateCode,
        'paused',
      );
      await queue.retryTask(runningId);
      expect(
        objectbox.downloadTaskBox.get(runningId)!.taskInfo!.stateCode,
        'queued',
      );
      expect(objectbox.downloadTaskBox.get(runningId)!.taskInfo!.imagePaths, [
        'checkpoint.png',
      ]);
    },
  );

  test('a newly queued chapter starts before an interrupted chapter', () async {
    final oldId = seed(
      payload('interrupted').copyWith(
        stateCode: 'running',
        phaseCode: 'downloadingImages',
        attempt: 3,
        completedImages: 1,
        imagePaths: ['checkpoint.png'],
      ),
      running: true,
    );
    queue.resetStuckTasks();
    queue.watchTasks(startupResumeDelay: delay);

    queue.addTask(payload('new'));
    await runtime.entered.future.timeout(deadline);

    final old = objectbox.downloadTaskBox.get(oldId)!;
    expect(old.isDownloading, isFalse);
    expect(old.taskInfo!.phaseCode, 'resume');
    expect(old.taskInfo!.attempt, 3);
    expect(old.taskInfo!.imagePaths, ['checkpoint.png']);
    final next = objectbox.downloadTaskBox.getAll().singleWhere(
      (task) => task.id != oldId,
    );
    expect(next.isDownloading, isTrue);
    expect(next.taskInfo!.chapterKey, 'new');

    // Recreating the navigation shell repeats these startup calls in-process.
    queue.resetStuckTasks();
    queue.watchTasks(startupResumeDelay: delay);
    final live = objectbox.downloadTaskBox.get(next.id)!;
    expect(live.isDownloading, isTrue);
    expect(live.taskInfo!.stateCode, 'running');
    expect(live.taskInfo!.attempt, 1);
  });

  test(
    'cancelling a queued sibling preserves a running uncheckpointed page',
    () async {
      const source = 'active-shared-page-fixture';
      const bucket = 'shared-storage';
      await seedPlugin(source, enabled: true);
      DownloadTaskJson inBucket(String chapter) => payload(chapter).copyWith(
        from: source,
        chapterRef: DownloadChapterTaskRef(
          chapterId: chapter,
          storageChapterId: bucket,
        ),
      );
      final running = inBucket('running');
      runtime.heldImageTask = running;
      Future<File> writePage(String path) async {
        final file = File(
          await DownloadAssetStore(
            from: source,
            cartoonId: running.comicId,
            chapterId: running.chapterKey,
            storageChapterId: bucket,
            path: path,
            pictureType: PictureType.page,
          ).canonicalDownloadPath(),
        );
        await file.parent.create(recursive: true);
        return file.writeAsString(path);
      }

      final shared = await writePage('shared.png');
      final exclusive = await writePage('exclusive.png');
      final runningId = seed(running);
      final queued = inBucket('queued');
      final queuedId = seed(
        queued.copyWith(imagePaths: ['shared.png', 'exclusive.png']),
      );
      Future<void> cancel(DownloadTaskJson task) => queue
          .cancelChapterTask(
            from: source,
            comicId: task.comicId,
            chapterKey: task.chapterKey,
          )
          .timeout(deadline);

      queue.watchTasks();
      await runtime.entered.future.timeout(deadline);
      expect(
        objectbox.downloadTaskBox.get(runningId)!.taskInfo!.imagePaths,
        isEmpty,
      );
      await cancel(queued);

      expect(await shared.readAsString(), 'shared.png');
      expect(await exclusive.exists(), isFalse);
      expect(
        objectbox.downloadTaskBox.get(queuedId)!.taskInfo!.stateCode,
        'cancelled',
      );

      final deletingOnly = await writePage('deleting-only.png');
      final selectedId = seed(
        inBucket(
          'delete-this',
        ).copyWith(imagePaths: ['shared.png', 'deleting-only.png']),
      );
      final deletion = await queue
          .stopAndDeleteTasks([objectbox.downloadTaskBox.get(selectedId)!])
          .timeout(deadline);
      expect(deletion.removed, {selectedId});
      expect(deletion.skipped, isEmpty);
      expect(deletion.failures, isEmpty);
      expect(objectbox.downloadTaskBox.get(selectedId), isNull);
      expect(await deletingOnly.exists(), isFalse);
      expect(await shared.readAsString(), 'shared.png');
      expect(objectbox.downloadTaskBox.get(runningId)!.isDownloading, isTrue);
      expect(runtime.release.isCompleted, isFalse);

      objectbox.unifiedDownloadBox.put(
        createTestDownload('$source:${running.comicId}')
          ..source = source
          ..comicId = running.comicId
          ..chapters = jsonEncode([
            {
              'id': 'finished',
              'storageChapterId': bucket,
              'images': [
                {'path': 'shared.png'},
              ],
            },
          ]),
      );
      await cancel(running);

      expect(await shared.readAsString(), 'shared.png');
      expect(
        objectbox.downloadTaskBox.get(runningId)!.taskInfo!.stateCode,
        'cancelled',
      );
    },
  );

  for (final state in ['failed', 'paused']) {
    test('an explicit $state retry starts during startup delay', () async {
      final id = seed(
        payload(state).copyWith(
          stateCode: state,
          attempt: 3,
          imagePaths: ['checkpoint.png'],
        ),
      );
      queue.watchTasks(startupResumeDelay: delay);

      await queue.retryTask(id);
      await runtime.entered.future.timeout(deadline);

      final task = objectbox.downloadTaskBox.get(id)!;
      expect(task.isDownloading, isTrue);
      expect(task.taskInfo!.attempt, 4);
      expect(task.taskInfo!.imagePaths, ['checkpoint.png']);
      expect(objectbox.downloadTaskBox.count(), 1);
    });
  }

  test(
    'Wi-Fi loss stops the active comic and retains its checkpoint',
    () async {
      final admission = DownloadAdmission.instance..setWifiOnly(true);
      final id = seed(
        payload('active-wifi').copyWith(imagePaths: ['checkpoint.png']),
      );
      runtime.holdDetail = true;
      queue.watchTasks();
      try {
        await runtime.entered.future.timeout(deadline);
        connectivity.set(ConnectivityResult.mobile);
        await runtime.release.future.timeout(deadline);

        final stoppedBy = DateTime.now().add(deadline);
        while (queue.isProcessing && DateTime.now().isBefore(stoppedBy)) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(queue.isProcessing, isFalse);
        final waiting = objectbox.downloadTaskBox.get(id)!;
        expect(waiting.isCompleted, isFalse);
        expect(waiting.isDownloading, isFalse);
        expect(waiting.taskInfo!.stateCode, 'queued');
        expect(waiting.taskInfo!.phaseCode, 'waitingWifi');
        expect(waiting.taskInfo!.imagePaths, ['checkpoint.png']);
      } finally {
        queue.stopWatchingTasks();
        admission.setWifiOnly(false);
      }
    },
  );

  test(
    'explicit comic cancellation wins over a simultaneous Wi-Fi loss',
    () async {
      final admission = DownloadAdmission.instance..setWifiOnly(true);
      final task = payload('cancel-as-wifi-drops');
      final id = seed(task);
      runtime.holdDetail = true;
      queue.watchTasks();
      try {
        await runtime.entered.future.timeout(deadline);
        final cancelling = queue.cancelChapterTask(
          from: task.from,
          comicId: task.comicId,
          chapterKey: task.chapterKey,
        );
        connectivity.set(ConnectivityResult.mobile);
        await cancelling.timeout(deadline);

        final cancelled = objectbox.downloadTaskBox.get(id)!;
        expect(cancelled.isCompleted, isTrue);
        expect(cancelled.taskInfo!.stateCode, 'cancelled');
        expect(cancelled.taskInfo!.phaseCode, 'cancelled');
      } finally {
        queue.stopWatchingTasks();
        admission.setWifiOnly(false);
      }
    },
  );

  test('a malformed saved task cannot block the next comic download', () async {
    final brokenId = objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicName = 'Broken download'
        ..dbTaskInfoStr = '{',
    );
    final healthyId = seed(payload('healthy-after-malformed'));
    queue.watchTasks();

    await runtime.entered.future.timeout(deadline);
    expect(objectbox.downloadTaskBox.get(brokenId)!.isCompleted, isTrue);
    expect(objectbox.downloadTaskBox.get(healthyId)!.isDownloading, isTrue);
  });
}
