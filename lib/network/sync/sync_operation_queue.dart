import 'package:flutter/foundation.dart';

/// Shared by daily sync, local backup operations and cloud protection changes.
final syncStorageOperations = SyncOperationQueue();

/// Keeps manual upload, import and automatic sync from racing each other.
class SyncOperationQueue {
  Future<void>? _pending;
  int _jobs = 0;
  final _busy = ValueNotifier(false);
  ValueListenable<bool> get busy => _busy;

  Future<void> run(Future<void> Function() action) {
    _jobs++;
    _busy.value = true;
    final job = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => action());
    _pending = job;
    void release() {
      if (identical(_pending, job)) _pending = null;
      _jobs--;
      _busy.value = _jobs != 0;
    }

    job.then((_) => release(), onError: (Object _, StackTrace _) => release());
    return job;
  }
}
