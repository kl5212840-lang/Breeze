import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/ios_download_continuation.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(() => objectbox.downloadTaskBox.removeAll());

  const repository = DownloadTaskRepository();
  const payload = DownloadTaskJson(
    from: 'source',
    comicId: 'work',
    comicName: 'Work',
    chapterRef: DownloadChapterTaskRef(logicalKey: 'chapter'),
    attempt: 1,
    stateCode: 'running',
    phaseCode: 'downloadingChapter',
  );

  DownloadTask runningTask() {
    final id = repository.putPayload(
      DownloadTask(),
      payload,
      isDownloading: true,
    );
    return objectbox.downloadTaskBox.get(id)!;
  }

  test('pause clears deferred retry without clearing chapter files', () {
    final deferred = payload.copyWith(
      stateCode: 'queued',
      phaseCode: 'waitingRetry',
      retryRounds: 2,
      nextRetryAt: 4102444800000,
      imagePaths: ['kept.png'],
    );
    final id = repository.putPayload(DownloadTask(), deferred);
    final queue = DownloadQueueManager.instance;
    expect(queue.pauseTasks([objectbox.downloadTaskBox.get(id)!]), 1);
    final result = objectbox.downloadTaskBox.get(id)!.taskInfo!;
    expect(result.stateCode, 'paused');
    expect(result.nextRetryAt, isNull);
    expect(result.imagePaths, ['kept.png']);
  });

  test(
    'manual retry clears a saved backoff and retains chapter pages',
    () async {
      final deferred = payload.copyWith(
        stateCode: 'queued',
        phaseCode: 'waitingRetry',
        retryRounds: 3,
        nextRetryAt: 4102444800000,
        completedImages: 1,
        totalImages: 2,
        imagePaths: ['page.png'],
      );
      final id = repository.putPayload(DownloadTask(), deferred);
      final queue = DownloadQueueManager.instance;
      expect(queue.canPauseTask(objectbox.downloadTaskBox.get(id)!), isTrue);
      expect(queue.canResumeTask(objectbox.downloadTaskBox.get(id)!), isTrue);
      await queue.retryTask(id);
      final result = objectbox.downloadTaskBox.get(id)!.taskInfo!;
      expect(result.phaseCode, 'retry');
      expect(result.nextRetryAt, isNull);
      expect(result.retryRounds, 0);
      expect(result.imagePaths, ['page.png']);
      expect(result.completedImages, 1);
    },
  );

  testWidgets(
    'explicit enqueues share one iOS continuation and count queued chapters',
    (tester) async {
      final queue = DownloadQueueManager.instance;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, (
        call,
      ) async {
        calls.add(call);
        return <String, Object>{
          'accepted': (call.arguments as Map)['scope'] == 'comics',
        };
      });
      try {
        queue.addTask(payload.copyWith(stateCode: 'queued'));
        queue.addTask(
          payload.copyWith(
            stateCode: 'queued',
            chapterRef: const DownloadChapterTaskRef(logicalKey: 'chapter-2'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls.where((call) => call.method == 'begin'), hasLength(1));
        expect((calls.first.arguments as Map)['scope'], 'comics');
        expect(calls.last.method, 'update');
        expect((calls.last.arguments as Map)['total'], 2000);
        expect((calls.last.arguments as Map)['completed'], 0);
      } finally {
        queue.stopWatchingTasks();
        await tester.pump();
        messenger.setMockMethodCallHandler(
          IosDownloadContinuation.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('native rejection leaves the comic task queued', (tester) async {
    final queue = DownloadQueueManager.instance;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final methods = <String>[];
    messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, (
      call,
    ) async {
      expect((call.arguments as Map)['scope'], 'comics');
      methods.add(call.method);
      return <String, Object>{'accepted': false};
    });
    try {
      queue.addTask(payload.copyWith(stateCode: 'queued'));
      await tester.pump();
      expect(methods, ['begin']);
      expect(repository.getAll().single.taskInfo?.stateCode, 'queued');
    } finally {
      queue.stopWatchingTasks();
      messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'an old running checkpoint cannot overwrite a requeued cancellation',
    () async {
      final cancelled = payload.copyWith(
        stateCode: 'cancelled',
        phaseCode: 'cancelled',
      );
      final id = repository.putPayload(
        DownloadTask(),
        cancelled,
        isCompleted: true,
      );
      await DownloadQueueManager.instance.retryTask(id);
      await repository.putTaskWriteBackground(
        taskKey: payload.taskKey,
        taskId: id,
        expectedAttempt: payload.attempt,
        requireRunning: true,
        payloadJson: downloadTaskJsonToJson(
          payload.copyWith(stateCode: 'failed'),
        ),
      );
      expect(objectbox.downloadTaskBox.get(id)!.taskInfo!.stateCode, 'queued');
    },
  );

  test(
    're-enqueue after cancellation reuses one row even on repeated requests',
    () async {
      final cancelled = payload.copyWith(
        stateCode: 'cancelled',
        phaseCode: 'cancelled',
      );
      final id = repository.putPayload(
        DownloadTask(),
        cancelled,
        isCompleted: true,
      );
      final queue = DownloadQueueManager.instance;
      queue.addTask(payload);
      queue.addTask(payload);
      await Future<void>.delayed(Duration.zero);
      final row = repository.getAll().single;
      expect(row.id, id);
      expect(row.taskInfo!.stateCode, 'queued');
      expect(row.isCompleted, isFalse);
    },
  );

  test(
    'startup drops only older settled cancellation for the same identity',
    () {
      final cancelled = payload.copyWith(
        stateCode: 'cancelled',
        phaseCode: 'cancelled',
      );
      final duplicate = repository.putPayload(
        DownloadTask(),
        cancelled,
        isCompleted: true,
      );
      final cancelling = repository.putPayload(
        DownloadTask(),
        cancelled.copyWith(phaseCode: 'cancelling'),
        isCompleted: true,
      );
      final sibling = repository.putPayload(
        DownloadTask(),
        cancelled.copyWith(
          chapterRef: const DownloadChapterTaskRef(logicalKey: 'sibling'),
        ),
        isCompleted: true,
      );
      final queued = repository.putPayload(
        DownloadTask(),
        payload.copyWith(stateCode: 'queued'),
      );
      repository.removeSupersededCancelledRecords();
      expect(
        repository.getAll().map((row) => row.id),
        unorderedEquals([cancelling, sibling, queued]),
      );
      expect(objectbox.downloadTaskBox.get(duplicate), isNull);
    },
  );

  test('a cancelled row confirmation cannot delete a newer attempt', () async {
    final cancelled = payload.copyWith(
      stateCode: 'cancelled',
      phaseCode: 'cancelled',
    );
    final id = repository.putPayload(
      DownloadTask(),
      cancelled,
      isCompleted: true,
    );
    final selected = objectbox.downloadTaskBox.get(id)!;
    repository.putPayload(
      objectbox.downloadTaskBox.get(id)!,
      payload.copyWith(attempt: 2),
      isDownloading: true,
      isCompleted: false,
    );
    expect(await repository.removeCancelledRecord(selected), isFalse);
    expect(objectbox.downloadTaskBox.get(id)!.taskInfo!.attempt, 2);
  });

  test(
    'a failed checkpoint does not poison the queue or escape its waiter',
    () async {
      final id = runningTask().id;
      final uncaught = <Object>[];
      final finished = Completer<List<Object?>>();

      runZonedGuarded(() {
        Future<Object?> outcome(Future<void> job) =>
            job.then<Object?>((_) => null, onError: (Object error) => error);
        Future<void> write(String json) => repository.putTaskWriteBackground(
          taskKey: payload.taskKey,
          taskId: id,
          expectedAttempt: payload.attempt,
          requireRunning: true,
          payloadJson: json,
        );

        finished.complete(
          Future.wait([
            outcome(write('{')),
            outcome(
              write(
                downloadTaskJsonToJson(payload.copyWith(completedImages: 1)),
              ),
            ),
            outcome(repository.flushTaskWrites(payload.taskKey)),
          ]),
        );
      }, (error, _) => uncaught.add(error));

      final [failure, followingWrite, drain] = await finished.future;
      expect(failure, isA<FormatException>());
      expect(followingWrite, isNull);
      expect(drain, isNull);
      expect(uncaught, isEmpty);
      expect(objectbox.downloadTaskBox.get(id)!.taskInfo!.completedImages, 1);
    },
  );

  test(
    'Wi-Fi wait retains a newer checkpoint from the same running attempt',
    () async {
      final snapshot = runningTask();
      final checkpoint = payload.copyWith(
        completedImages: 1,
        imagePaths: ['page.png'],
      );
      await repository.putTaskWriteBackground(
        taskKey: payload.taskKey,
        taskId: snapshot.id,
        expectedAttempt: payload.attempt,
        requireRunning: true,
        payloadJson: downloadTaskJsonToJson(checkpoint),
      );

      expect(
        repository.markNetworkWaiting(snapshot, DownloadNetworkWait.wifi),
        isTrue,
      );
      final waiting = objectbox.downloadTaskBox.get(snapshot.id)!;
      expect(waiting.isDownloading, isFalse);
      expect(
        waiting.taskInfo,
        checkpoint.copyWith(stateCode: 'queued', phaseCode: 'waitingWifi'),
      );
    },
  );

  test(
    'Wi-Fi wait respects a replaced, paused, retried or terminal attempt',
    () {
      for (final (state, phase, attempt, downloading, completed) in [
        ('running', 'downloadingChapter', 2, true, false),
        ('paused', 'pluginDisabled', 1, false, false),
        ('queued', 'retry', 1, false, false),
        ('running', 'cancelling', 1, false, true),
        ('completed', 'completed', 1, false, true),
      ]) {
        final snapshot = runningTask();
        final current = payload.copyWith(
          stateCode: state,
          phaseCode: phase,
          attempt: attempt,
        );
        repository.putPayload(
          objectbox.downloadTaskBox.get(snapshot.id)!,
          current,
          isDownloading: downloading,
          isCompleted: completed,
        );
        expect(
          repository.markNetworkWaiting(snapshot, DownloadNetworkWait.wifi),
          isFalse,
          reason: phase,
        );
        final stored = objectbox.downloadTaskBox.get(snapshot.id)!;
        expect(stored.taskInfo, current);
        expect(stored.isDownloading, downloading);
        expect(stored.isCompleted, completed);
      }
    },
  );
}
