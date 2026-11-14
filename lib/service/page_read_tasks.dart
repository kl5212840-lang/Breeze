import 'dart:async';

import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';

/// Owns only this page's idempotent plugin reads. A unique group per physical
/// read prevents close/supersession from cancelling downloads or other pages.
class PageReadTasks {
  static int _sequence = 0;
  final _groups = <String, String>{};

  Future<T> run<T>(
    String source,
    Future<T> Function(String group) action,
  ) async {
    final group =
        'page-read-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    _groups[group] = source;
    try {
      return await action(group);
    } finally {
      _groups.remove(group);
      releaseQjsTaskGroupNetwork(source, group);
      clearDownloadCancelSignal(group);
    }
  }

  Future<void> cancel() async {
    final groups = Map<String, String>.from(_groups);
    // Signal every captured read before awaiting native cancellation; reads
    // admitted after this snapshot belong to the new query and are untouched.
    for (final group in groups.keys) {
      triggerDownloadCancelSignal(group);
    }
    await Future.wait([
      for (final entry in groups.entries)
        cancelTrackedQjsTasks(
          pluginId: entry.value,
          taskGroupKey: entry.key,
        ).catchError((Object _) {}),
    ]);
  }
}
