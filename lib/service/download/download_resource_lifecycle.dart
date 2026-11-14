import 'dart:async';

/// Only the execution phase of destructive download removal owns this lease.
/// Queue requests for the same work wait for its release; other works proceed.
class DownloadResourceRemovalLease {
  DownloadResourceRemovalLease._(this.key);
  final String key;
  final _released = Completer<void>();
  Future<void> get released => _released.future;
  bool get isReleased => _released.isCompleted;
  void release() {
    if (isReleased) return;
    if (identical(DownloadResourceLifecycle._removals[key], this)) {
      DownloadResourceLifecycle._removals.remove(key);
    }
    _released.complete();
  }
}

abstract final class DownloadResourceLifecycle {
  static final _removals = <String, DownloadResourceRemovalLease>{};
  static String comic(String uniqueKey) => 'comic:$uniqueKey';
  static String video(String resourceId) => 'video:$resourceId';
  static DownloadResourceRemovalLease? removing(String key) => _removals[key];
  static void requireAvailable(String key) {
    if (_removals.containsKey(key))
      throw StateError('Download removal is in progress');
  }

  static DownloadResourceRemovalLease acquireRemoval(String key) {
    requireAvailable(key);
    final lease = DownloadResourceRemovalLease._(key);
    _removals[key] = lease;
    return lease;
  }
}
