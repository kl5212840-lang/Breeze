import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/sync_task_progress.dart';

void main() {
  test('unknown totals stay indeterminate and only a known item batch has a fraction', () async {
    final tasks = SyncTaskProgress();
    await tasks.run(direction: SyncDirection.upload, action: () async {
      expect(tasks.value!.phase, SyncTaskPhase.preparing);
      expect(tasks.value!.fraction, isNull);
      tasks.phase(SyncTaskPhase.artwork, completed: 0, total: 2);
      expect(tasks.value!.fraction, 0);
      tasks.phase(SyncTaskPhase.artwork, completed: 1, total: 2);
      expect(tasks.value!.fraction, .5);
      tasks.phase(SyncTaskPhase.settings);
      expect(tasks.value!.fraction, isNull);
      expect(() => tasks.phase(SyncTaskPhase.artwork, completed: 3, total: 2), throwsArgumentError);
    });
    expect(tasks.value!.status, SyncTaskStatus.completed);
    expect(tasks.value!.fraction, isNull, reason: 'there is no invented whole-round percentage');
  });

  test('nested operation shares one task and a competing start cannot duplicate it', () async {
    final tasks = SyncTaskProgress(), release = Completer<void>();
    var calls = 0;
    final running = tasks.run(direction: SyncDirection.restore, action: () async {
      final id = tasks.value!.id;
      await tasks.run(direction: SyncDirection.restore, action: () async {
        expect(tasks.value!.id, id);
        calls++;
        tasks.phase(SyncTaskPhase.videos);
        await release.future;
      });
    });
    await expectLater(tasks.run(direction: SyncDirection.upload, action: () async { calls++; }),
        throwsA(isA<SyncTaskAlreadyRunning>()));
    expect(tasks.running, isTrue);
    expect(calls, 1);
    release.complete();
    await running;
    expect(tasks.running, isFalse);
    expect(tasks.value!.direction, SyncDirection.restore);
  });

  test('failure and cancellation remain readable without exposing raw errors', () async {
    final tasks = SyncTaskProgress();
    await expectLater(tasks.run(direction: SyncDirection.upload, action: () async {
      tasks.phase(SyncTaskPhase.artwork, completed: 1, total: 2);
      throw TimeoutException('synthetic private transport contents');
    }), throwsA(isA<TimeoutException>()));
    expect(tasks.value!.status, SyncTaskStatus.failed);
    expect(tasks.value!.failure, SyncFailureKind.timeout);
    expect(tasks.value!.completedItems, isNull);
    final failed = tasks.value!.id;
    tasks.markCancelled(failed - 1);
    expect(tasks.value!.status, SyncTaskStatus.failed);
    tasks.markCancelled(failed);
    expect(tasks.value!.status, SyncTaskStatus.cancelled);
    await expectLater(tasks.run(direction: SyncDirection.restore,
        cancelled: (error) => error is _Cancelled,
        action: () async { throw const _Cancelled(); }), throwsA(isA<_Cancelled>()));
    expect(tasks.value!.status, SyncTaskStatus.cancelled);
    expect(tasks.running, isFalse);
  });

  test('a late callback from a finished round cannot overwrite the next task', () async {
    final tasks = SyncTaskProgress();
    late void Function() lateCallback;
    await tasks.run(direction: SyncDirection.upload, action: () async {
      final zone = Zone.current;
      lateCallback = () => zone.run(() => tasks.phase(SyncTaskPhase.artwork, completed: 9, total: 9));
    });
    final first = tasks.value!.id;
    final release = Completer<void>();
    final next = tasks.run(direction: SyncDirection.restore, action: () async {
      tasks.phase(SyncTaskPhase.comics);
      await release.future;
    });
    lateCallback();
    expect(tasks.value!.id, isNot(first));
    expect(tasks.value!.phase, SyncTaskPhase.comics);
    expect(tasks.value!.fraction, isNull);
    release.complete();
    await next;
  });
}

class _Cancelled { const _Cancelled(); }
