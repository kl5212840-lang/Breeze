import 'package:flutter/foundation.dart';

/// Temporary debug-only timings. Never include titles, URLs or task identities.
class DownloadInteractionTrace {
  DownloadInteractionTrace(String scope) : _scope = scope {
    assert(() {
      _clock = Stopwatch()..start();
      _id = ++_nextId;
      mark('start');
      return true;
    }());
  }

  static int _nextId = 0;
  final String _scope;
  Stopwatch? _clock;
  int _id = 0;
  int _previous = 0;

  void mark(String stage) {
    assert(() {
      final elapsed = _clock!.elapsedMicroseconds;
      debugPrint(
        '[download-timing $_id $_scope] $stage '
        'total=${(elapsed / 1000).toStringAsFixed(1)}ms '
        'step=${((elapsed - _previous) / 1000).toStringAsFixed(1)}ms',
      );
      _previous = elapsed;
      return true;
    }());
  }
}
