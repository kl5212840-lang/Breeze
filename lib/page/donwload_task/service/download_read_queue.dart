/// A read requested during a snapshot read joins the next read. Its caller
/// waits for that snapshot, while repeated task notifications share the slot.
class DownloadReadQueue {
  DownloadReadQueue(this._read, {required this.isActive});

  final Future<void> Function() _read;
  final bool Function() isActive;
  Future<void>? _running, _next;

  Future<void>? get pending => _next ?? _running;

  Future<void> request() {
    if (!isActive()) return Future.value();
    if (_next case final next?) return next;
    if (_running case final running?) {
      Future<void> startNext() {
        _next = null;
        return _start();
      }

      return _next = running.then(
        (_) => startNext(),
        onError: (Object _, StackTrace _) => startNext(),
      );
    }
    return _start();
  }

  Future<void> _start() {
    if (!isActive()) return Future.value();
    return _running = _read().whenComplete(() => _running = null);
  }
}
