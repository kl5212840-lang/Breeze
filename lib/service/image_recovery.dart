import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/service/http_retry_after.dart';
import 'package:zephyr/util/error_filter.dart';

abstract interface class ImageFailureEvidence {
  bool get retryable;
}

class ImageRecoverySuperseded implements Exception {
  const ImageRecoverySuperseded();
}

int? imageFailureHttpStatus(Object error) => error is NetworkImageLoadException
    ? error.statusCode
    : reportedHttpStatus(error);

/// Only transient failures are eligible for automatic recovery. Unknown plugin
/// transport failures receive the same small budget; permanent HTTP failures do not.
bool imageFailureIsTransient(Object error) {
  if (error is ImageFailureEvidence) return error.retryable;
  if (error is ImageRecoverySuperseded ||
      error is FormatException ||
      error is ArgumentError ||
      error is StateError ||
      error is FileSystemException)
    return false;
  if (error is TimeoutException ||
      error is SocketException ||
      error is HandshakeException) {
    return true;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('unsupported') ||
      text.contains('cancel') ||
      text.contains('superseded') ||
      text.contains('decode') ||
      text.contains('image codec') ||
      text.contains('invalid image') ||
      text.contains('unauthorized') ||
      text.contains('emptydata') ||
      text.contains('notfound') ||
      text.contains('sessionchanged') ||
      text.contains('账号状态已变化') ||
      text.contains('missing plugin'))
    return false;
  final code = imageFailureHttpStatus(error);
  return code == null || isTransientHttpStatus(code);
}

/// Shared bounded admission. Jobs with the same identity share one running
/// request, and a visible consumer promotes an existing pending prefetch.
class ImageRequestQueue {
  ImageRequestQueue({this.concurrency = 4, this.maxCoverRequests});
  final int concurrency;
  final int? maxCoverRequests;
  int _running = 0;
  int _runningCovers = 0;
  final _jobs = <String, _ImageJob>{};
  Future<T> run<T>(
    String key,
    Future<T> Function() action, {
    int priority = 0,
    bool Function()? current,
    bool cover = false,
  }) {
    final existing = _jobs[key];
    if (existing != null) {
      if (priority > existing.priority) existing.priority = priority;
      existing.currents.add(current);
      return existing.result.future.then((v) => v as T);
    }
    final job = _ImageJob(key, priority, () async => action(), current, cover);
    _jobs[key] = job;
    _drain();
    return job.result.future.then((v) => v as T);
  }

  void _drain() {
    while (_running < concurrency) {
      final pending =
          _jobs.values
              .where(
                (job) =>
                    !job.started &&
                    (!job.cover ||
                        _runningCovers < (maxCoverRequests ?? concurrency)),
              )
              .toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));
      if (pending.isEmpty) return;
      final job = pending.first;
      job.started = true;
      if (!job.currents.any((current) => current?.call() != false)) {
        _jobs.remove(job.key);
        job.result.completeError(const ImageRecoverySuperseded());
        continue;
      }
      _running++;
      if (job.cover) _runningCovers++;
      Future<Object?>.sync(job.action)
          .then(job.result.complete, onError: job.result.completeError)
          .whenComplete(() {
            _running--;
            if (job.cover) _runningCovers--;
            if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
            _drain();
          });
    }
  }
}

class _ImageJob {
  _ImageJob(
    this.key,
    this.priority,
    this.action,
    bool Function()? current,
    this.cover,
  ) {
    currents.add(current);
  }
  final String key;
  int priority;
  final Future<Object?> Function() action;
  final bool cover;
  final currents = <bool Function()?>[];
  bool started = false;
  final result = Completer<Object?>();
}

class ImageRecoveryHub with WidgetsBindingObserver {
  ImageRecoveryHub({bool listenToPlatform = true}) {
    if (listenToPlatform) {
      try {
        WidgetsBinding.instance.addObserver(this);
        foreground =
            WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        final connectivity = _platformConnectivity = Connectivity();
        _connectivity = connectivity.onConnectivityChanged.listen(
          updateConnectivity,
          onError: (Object _) {},
        );
        unawaited(_refreshConnectivity());
      } catch (_) {}
    }
  }
  static final instance = ImageRecoveryHub();
  // Leave room for reader pages when several cover CDNs stall together.
  static final requests = ImageRequestQueue(maxCoverRequests: 3);
  final retries = ImageRequestQueue(concurrency: 2);
  final _recovered = StreamController<void>.broadcast(sync: true);
  final _activity = StreamController<void>.broadcast(sync: true);
  Stream<void> get recovered => _recovered.stream;
  Stream<void> get activity => _activity.stream;
  Connectivity? _platformConnectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  int _connectivityRevision = 0;
  bool _disposed = false;
  bool foreground = true, online = true;
  Set<ConnectivityResult>? _transports;
  DateTime? _lastPathRecovery;
  final _lastImageSuccess = <String, DateTime>{};
  String recoveryReason = '';
  String recoveredImageHost = '';
  void _recover(String reason, {String imageHost = ''}) {
    recoveryReason = reason;
    recoveredImageHost = imageHost;
    _recovered.add(null);
  }

  void updateConnectivity(List<ConnectivityResult> values) {
    if (_disposed) return;
    _connectivityRevision++;
    final previous = online;
    final transports = values
        .where((v) => v != ConnectivityResult.none)
        .toSet();
    final changed =
        _transports != null &&
        (_transports!.length != transports.length ||
            !_transports!.containsAll(transports));
    _transports = transports;
    online = transports.isNotEmpty;
    _activity.add(null);
    if (!online) return;
    final now = DateTime.now();
    if (!previous) {
      // A real outage cancels waiting retries. Restore their demand even when
      // a weaker transport or foreground hint was emitted recently.
      _lastPathRecovery = now;
      _recover('reconnect');
    } else if (changed &&
        (_lastPathRecovery == null ||
            now.difference(_lastPathRecovery!) >=
                const Duration(seconds: 10))) {
      _lastPathRecovery = now;
      _recover('connectivity');
    }
  }

  Future<void> _refreshConnectivity() async {
    final platform = _platformConnectivity;
    if (platform == null || _disposed) return;
    final revision = ++_connectivityRevision;
    final elapsed = Stopwatch()..start();
    try {
      final values = await platform.checkConnectivity();
      if (revision == _connectivityRevision &&
          elapsed.elapsed <= const Duration(seconds: 2)) {
        updateConnectivity(values);
      }
    } catch (_) {
      // A failed snapshot leaves the last observed transport in effect.
    }
  }

  /// A real successful image transport can prove same-Wi-Fi service recovered.
  /// Each failed consumer accepts this hint only once, never as a polling loop.
  void noteSuccessfulRequest({required String imageHost}) {
    final now = DateTime.now();
    if (!foreground || !online || imageHost.isEmpty) return;
    _lastImageSuccess.removeWhere(
      (_, when) => now.difference(when) >= const Duration(seconds: 10),
    );
    if (_lastImageSuccess.containsKey(imageHost)) return;
    _lastImageSuccess[imageHost] = now;
    _recover('success', imageHost: imageHost);
  }

  /// Call from a user's existing page refresh action, never from widget build.
  void userRefresh() => _recover('manual');
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = foreground;
    foreground = state == AppLifecycleState.resumed;
    _activity.add(null);
    if (foreground && !previous) {
      _recover('resume');
      // Platform callbacks can omit a path change while the app is suspended.
      unawaited(_refreshConnectivity());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivity?.cancel();
    await _recovered.close();
    await _activity.close();
  }
}

class ImageRecoveryController {
  ImageRecoveryController({
    required this.retry,
    this.maxAutomaticAttempts = 2,
    this.retryIntervalAfterAttempts,
    bool active = true,
    ImageRecoveryHub? hub,
    this.imageHost,
    this.onChanged,
  }) : hub = hub ?? ImageRecoveryHub.instance,
       _active = active {
    _signal = this.hub.recovered.listen((_) {
      final reason = this.hub.recoveryReason;
      if (reason == 'reconnect' && _eligible) {
        // Hidden consumers keep this renewed budget until visible again.
        _lastRecovery = DateTime.now();
        _attempts = 0;
        _timer?.cancel();
        _timer = null;
        _schedule();
        return;
      }
      if (_error == null || !_active) return;
      if (reason == 'success' &&
          (_successWakeUsed ||
              imageHost?.call() != this.hub.recoveredImageHost)) {
        return;
      }
      if (reason == 'manual') {
        _attempts = 0;
        _schedule();
        return;
      }
      if (!_eligible) return;
      final now = DateTime.now();
      if (_lastRecovery != null &&
          now.difference(_lastRecovery!) < const Duration(seconds: 10))
        return;
      if (reason == 'success') _successWakeUsed = true;
      _lastRecovery = now;
      _attempts = 0;
      _schedule();
    });
    _activity = this.hub.activity.listen((_) {
      if (!_canRun) {
        _timer?.cancel();
        _timer = null;
      } else {
        _schedule();
      }
      onChanged?.call();
    });
  }
  final Future<void> Function() retry;
  final String? Function()? imageHost;
  final VoidCallback? onChanged;
  final int maxAutomaticAttempts;
  // Visible reader pages may continue after the initial, short retry burst.
  final Duration? retryIntervalAfterAttempts;
  final ImageRecoveryHub hub;
  late final StreamSubscription<void> _signal, _activity;
  Timer? _timer;
  Object? _error;
  int _attempts = 0, _epoch = 0;
  bool _successWakeUsed = false;
  bool _active, _disposed = false, _running = false;
  DateTime? _lastRecovery;
  DateTime? _retryNotBefore;
  bool get _eligible => _error != null && imageFailureIsTransient(_error!);
  bool get _canRun => !_disposed && _active && hub.foreground && hub.online;
  bool get _hasRetryBudget =>
      _attempts < maxAutomaticAttempts || retryIntervalAfterAttempts != null;
  bool get hasPendingRecovery =>
      !_disposed &&
      _eligible &&
      (_running || _timer != null || _hasRetryBudget);
  bool get recovering =>
      hasPendingRecovery && (_running || _timer != null || _canRun);
  void failed(Object error) {
    if (identical(_error, error)) {
      _schedule();
      return;
    }
    _recordFailure(error);
    _schedule();
    onChanged?.call();
  }

  void _recordFailure(Object error) {
    _error = error;
    final status = imageFailureHttpStatus(error);
    if (status == null || !isTransientHttpStatus(status)) return;
    final now = DateTime.now();
    final delay =
        httpRetryAfterDelay(error.toString(), now: now) ??
        (status == 429 ? const Duration(seconds: 45) : Duration.zero);
    final retryAt = now.add(delay);
    if (retryAt.isAfter(_retryNotBefore ?? now)) {
      _retryNotBefore = retryAt;
      _timer?.cancel();
      _timer = null;
    }
  }

  void succeeded() {
    if (_error == null && _attempts == 0 && _timer == null) return;
    _error = null;
    _retryNotBefore = null;
    _attempts = 0;
    _timer?.cancel();
    _timer = null;
    onChanged?.call();
  }

  void reset() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _error = null;
    _retryNotBefore = null;
    _attempts = 0;
    _lastRecovery = null;
    _successWakeUsed = false;
  }

  void setActive(bool value) {
    _active = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
    } else {
      _schedule();
    }
  }

  void _schedule() {
    if (!_canRun ||
        !_eligible ||
        _running ||
        _timer != null ||
        !_hasRetryBudget)
      return;
    final backoff = _attempts < maxAutomaticAttempts
        ? Duration(milliseconds: _attempts == 0 ? 800 : 2400)
        : retryIntervalAfterAttempts!;
    final remaining = _retryNotBefore?.difference(DateTime.now());
    _timer = Timer(
      remaining != null && remaining > backoff ? remaining : backoff,
      () async {
        _timer = null;
        if (!_canRun || !_eligible) return;
        final epoch = _epoch;
        _running = true;
        onChanged?.call();
        try {
          await hub.retries.run<void>('recovery:${identityHashCode(this)}', () {
            _attempts++;
            return retry();
          }, current: () => epoch == _epoch && _canRun && _eligible);
        } catch (error) {
          if (!_disposed &&
              epoch == _epoch &&
              error is! ImageRecoverySuperseded)
            _recordFailure(error);
        } finally {
          _running = false;
          if (!_disposed) {
            _schedule();
            onChanged?.call();
          }
        }
      },
    );
  }

  void dispose() {
    _epoch++;
    _disposed = true;
    _timer?.cancel();
    unawaited(_signal.cancel());
    unawaited(_activity.cancel());
  }
}
