import 'dart:async';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/ios_download_continuation.dart';

typedef VideoDownloadAttempt = ({String key, int attempt});

/// Aggregates explicitly started attempts using fixed units per transfer.
abstract final class VideoDownloadContinuation {
  static const _units = 1000;
  static final _activity = IosDownloadContinuation('video', _expire);
  static final _attempts = <VideoDownloadAttempt, _Attempt>{};
  static int _finishedUnits = 0, _finishedCount = 0;
  static bool _allSaved = true;

  static void add(Map<VideoDownloadAttempt, Future<void> Function()> owners) {
    if (owners.isEmpty || !IosDownloadContinuation.canBegin) return;
    for (final entry in owners.entries) {
      _attempts.putIfAbsent(entry.key, () => _Attempt(entry.value));
    }
    if (_activity.active) {
      _update();
    } else {
      final report = _report();
      unawaited(
        _activity.beginFromUser(
          title: t.download.videoTasks,
          subtitle: t.download.downloading,
          completed: report.completed,
          total: report.total,
        ),
      );
    }
  }

  static void progress(VideoDownloadAttempt attempt, double? fraction) {
    final item = _attempts[attempt];
    if (item == null ||
        fraction == null ||
        !fraction.isFinite ||
        fraction < 0 ||
        fraction > 1)
      return;
    final value = (fraction * _units).floor().clamp(0, _units - 1);
    if (value == item.units) return;
    item.units = value;
    _update();
  }

  static void finish(VideoDownloadAttempt attempt, {required bool saved}) {
    final item = _attempts.remove(attempt);
    if (item == null) return;
    _finishedCount++;
    _finishedUnits += saved ? _units : item.units;
    _allSaved = _allSaved && saved;
    _update();
    if (_attempts.isEmpty) {
      unawaited(_activity.finish(success: _allSaved));
      _reset();
    }
  }

  static ({int completed, int total}) _report() => (
    completed:
        _finishedUnits +
        _attempts.values.fold(0, (sum, item) => sum + item.units),
    total: (_finishedCount + _attempts.length) * _units,
  );

  static void _update() {
    final report = _report();
    _activity.update(
      title: t.download.videoTasks,
      subtitle: t.download.downloading,
      completed: report.completed,
      total: report.total,
    );
  }

  static void _reset() {
    _attempts.clear();
    _finishedCount = _finishedUnits = 0;
    _allSaved = true;
  }

  static Future<void> _expire() async {
    final owners = _attempts.values.map((item) => item.stop).toList();
    _reset();
    await Future.wait(owners.map((stop) => stop()));
  }
}

final class _Attempt {
  _Attempt(this.stop);
  final Future<void> Function() stop;
  int units = 0;
}
