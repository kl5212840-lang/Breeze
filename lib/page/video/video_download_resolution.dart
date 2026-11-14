import 'dart:async';

class VideoResolutionCancelled implements Exception {
  const VideoResolutionCancelled();
}

/// One parsing attempt. A source gate can retire early only after the exact
/// browser/runtime owner acknowledges cancellation, never from a UI flag.
class VideoDownloadResolutionOwner {
  VideoDownloadResolutionOwner(this.source, {this.cooperative = false})
    : token =
          'video-resolve-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
  static int _sequence = 0;
  static final _zoneKey = Object();
  static VideoDownloadResolutionOwner? get current =>
      Zone.current[_zoneKey] as VideoDownloadResolutionOwner?;
  final String source, token;
  final bool cooperative;
  final _callbacks = <Object, Future<void> Function()>{};
  final _cleanups = <void Function()>[];
  final _stopped = Completer<void>();
  Future<void>? _stopping;
  bool _cancelled = false, _closed = false;
  Future<void> get stopped => _stopped.future;
  bool get cancelled => _cancelled;
  bool get closed => _closed;
  void check() {
    if (_cancelled || _closed) throw const VideoResolutionCancelled();
  }

  Future<T> run<T>(Future<T> Function() action) {
    check();
    return runZoned(action, zoneValues: {_zoneKey: this});
  }

  void Function() onCancel(Future<void> Function() callback) {
    check();
    final key = Object();
    _callbacks[key] = callback;
    return () => _callbacks.remove(key);
  }

  void onClose(void Function() callback) => _cleanups.add(callback);
  Future<void> stop() => _stopping ??= () async {
    if (_closed) return;
    _cancelled = true;
    final callbacks = _callbacks.values.toList();
    await Future.wait(callbacks.map((callback) => callback()));
    if ((cooperative || callbacks.isNotEmpty) && !_stopped.isCompleted)
      _stopped.complete();
  }();
  void close() {
    if (_closed) return;
    _closed = true;
    _callbacks.clear();
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
  }
}
