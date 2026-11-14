import 'package:zephyr/i18n/strings.g.dart';

class CacheWorkspaceBusy implements Exception {
  const CacheWorkspaceBusy();
  @override
  String toString() => t.cache.backupBusy;
}

class CacheCleanupFailed implements Exception {
  const CacheCleanupFailed();
  @override
  String toString() => t.cache.clearFailed;
}

class CacheWorkspaceLease {
  CacheWorkspaceLease._();
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    CacheWorkspaceGuard._workspaces--;
  }
}

/// Acquisition is synchronous, so cleanup cannot slip between a check and the
/// first asynchronous staging operation. Leases may span an import confirmation.
abstract final class CacheWorkspaceGuard {
  static int _workspaces = 0;
  static bool _clearing = false;

  static CacheWorkspaceLease acquire() {
    if (_clearing) throw const CacheWorkspaceBusy();
    _workspaces++;
    return CacheWorkspaceLease._();
  }

  static Future<T> withWorkspace<T>(Future<T> Function() action) async {
    final lease = acquire();
    try {
      return await action();
    } finally {
      lease.release();
    }
  }

  static Future<T> clear<T>(Future<T> Function() action) async {
    if (_clearing || _workspaces > 0) throw const CacheWorkspaceBusy();
    _clearing = true;
    try {
      return await action();
    } finally {
      _clearing = false;
    }
  }
}
