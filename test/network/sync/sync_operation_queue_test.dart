import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';

void main() {
  test(
    'manual and automatic operations run in order without overlapping',
    () async {
      final queue = SyncOperationQueue(), gate = Completer<void>();
      final events = <String>[];
      final upload = queue.run(() async {
        events.add('upload');
        await gate.future;
        events.add('upload complete');
      });
      final download = queue.run(() async => events.add('download'));
      expect(queue.busy.value, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['upload']);
      gate.complete();
      await Future.wait([upload, download]);
      expect(events, ['upload', 'upload complete', 'download']);
      expect(queue.busy.value, isFalse);
    },
  );
  test('a failed operation releases the next request', () async {
    final queue = SyncOperationQueue();
    var ran = false;
    final first = queue.run(() async => throw StateError('offline'));
    final checked = expectLater(first, throwsStateError);
    final next = queue.run(() async {
      ran = true;
    });
    await checked;
    await next;
    expect(ran, isTrue);
    expect(queue.busy.value, isFalse);
  });
}
