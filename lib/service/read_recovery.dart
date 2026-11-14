import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'dart:async';
import 'dart:io';

import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/util/error_filter.dart';

const _automaticReadKey = #breezeAutomaticReadRecovery;
bool get isAutomaticReadRecovery => Zone.current[_automaticReadKey] == true;

Duration readRetryAfterDelay(
  Object error, {
  Duration fallback = const Duration(seconds: 45),
  DateTime? now,
}) {
  final value = RegExp(
    r'retry-after[ :=]+([^\r\n]+)',
    caseSensitive: false,
  ).firstMatch(error.toString())?.group(1)?.trim();
  if (value == null) return fallback;
  final seconds = int.tryParse(value);
  if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
  try {
    final delay = HttpDate.parse(value).difference(now ?? DateTime.now());
    return delay.isNegative ? Duration.zero : delay;
  } on FormatException {
    return fallback;
  } on HttpException {
    return fallback;
  }
}

/// Page reads need positive transient evidence. Login, verification and malformed
/// plugin responses require user/source changes, never a periodic retry.
abstract interface class ReadFailureEvidence {
  bool get retryable;
}

bool readFailureIsTransient(Object error) {
  if (error is PluginLoginRequiredException) return false;
  if (error is ReadFailureEvidence) return error.retryable;
  if (error is FormatException || error is ArgumentError) return false;
  final text = normalizeSearchErrorMessage(error).toLowerCase();
  if (RegExp(
    r'需要登录|请.{0,3}登录|登录.{0,3}(过期|失效)|未登录|验证码|验证后|人机验证|权限|unauthorized|forbidden|captcha|login required|not logged in|please (?:log|sign) in|sessionchanged|账号状态已变化|cancel|superseded|invalid response|malformed|解析失败|格式错误|不兼容',
  ).hasMatch(text))
    return false;
  final status = RegExp(
    r'(?:http(?:\s+error)?|status(?:code)?[ :=]*)\s*([1-5]\d\d)|\b(401|403|404|408|425|429|5\d\d)\b',
  ).firstMatch(text);
  final code = status == null ? null : int.tryParse(status[1] ?? status[2]!);
  if (code != null)
    return code == 408 || code == 425 || code == 429 || code >= 500;
  return error is SocketException ||
      error is TimeoutException ||
      isTransientNetworkError(error) ||
      RegExp(
        r'网络|连接.{0,4}(中断|失败|超时)|服务.{0,3}(暂时|繁忙)|temporarily unavailable',
      ).hasMatch(text);
}

/// Demand-driven recovery for idempotent reads only. There is no healthy-page
/// timer, and image transport success does not prove this source is reachable.
class ReadRecoveryController {
  ReadRecoveryController({
    required this.source,
    required this.retry,
    ImageRecoveryHub? hub,
    bool active = false,
    this.shortDelays = const [
      Duration(milliseconds: 800),
      Duration(milliseconds: 2400),
    ],
    this.slowDelay = const Duration(seconds: 45),
    this.notBefore,
  }) : hub = hub ?? ImageRecoveryHub.instance,
       _active = active {
    _signals = this.hub.recovered.listen((_) {
      final reason = this.hub.recoveryReason;
      if (reason == 'success') return;
      if (reason == 'reconnect' || reason == 'connectivity') _attempt = 0;
      if (_eligible) trigger();
    });
    _activity = this.hub.activity.listen((_) => _schedule());
    _networkChanges = SourceNetworkPolicies.changes.listen(
      _networkPolicyChanged,
    );
  }

  // Shared page-only admission bounds concurrency independently from images.
  static final _requests = _ReadRecoveryAdmission();
  static final _sourceRetryAfter = <String, DateTime>{};
  final String source;
  final Future<void> Function() retry;
  final ImageRecoveryHub hub;
  final List<Duration> shortDelays;
  final Duration slowDelay;
  final DateTime? Function()? notBefore;
  late final StreamSubscription<void> _signals, _activity;
  late final StreamSubscription<String> _networkChanges;
  Timer? _timer;
  Object? _error;
  bool _active, _disposed = false, _running = false, _invalidated = false;
  bool _followUp = false;
  int _attempt = 0, _epoch = 0;
  bool get _eligible =>
      _invalidated || _error != null && readFailureIsTransient(_error!);
  // Each failure burst has its short retries and one last delayed attempt.
  // An unchanged upstream failure must not turn a foreground page into a poller.
  bool get _hasBudget => _attempt <= shortDelays.length;
  bool get _canRun => !_disposed && _active && hub.foreground && hub.online;

  void _networkPolicyChanged(String changedSource) {
    // Explicit route changes reopen failed demand once, without periodically
    // refreshing healthy pages or modifying the user's selected route.
    if (source == changedSource && _error != null) invalidate();
  }

  void failed(Object error) {
    _error = error;
    final text = error.toString().toLowerCase();
    if (RegExp(r'\b429\b').hasMatch(text)) {
      final now = DateTime.now();
      final retryAt = now.add(
        readRetryAfterDelay(error, fallback: slowDelay, now: now),
      );
      _sourceRetryAfter.removeWhere((_, deadline) => !deadline.isAfter(now));
      final previous = _sourceRetryAfter[source];
      if (retryAt.isAfter(previous ?? now)) _sourceRetryAfter[source] = retryAt;
    }
    _invalidated = false;
    if (!_eligible) {
      _timer?.cancel();
      _timer = null;
    }
    _schedule();
  }

  void succeeded() {
    _error = null;
    _invalidated = false;
    _attempt = 0;
    _followUp = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Explicit account/line/query invalidation can reopen a permanent failure.
  void invalidate() {
    _invalidated = true;
    _attempt = 0;
    trigger();
  }

  /// Coalesces restoration/visibility signals, including one arriving in-flight.
  void trigger() {
    if (!_eligible || _disposed) return;
    if (_running) {
      _followUp = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    _schedule(immediate: true);
  }

  void setActive(bool active) {
    final becameVisible = active && !_active;
    _active = active;
    if (becameVisible && _eligible) {
      trigger();
    } else {
      _schedule();
    }
  }

  void _schedule({bool immediate = false}) {
    if (!_canRun || !_eligible || !_hasBudget) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_running || _timer != null) return;
    var delay = immediate
        ? Duration.zero
        : _attempt < shortDelays.length
        ? shortDelays[_attempt]
        : slowDelay + Duration(milliseconds: identityHashCode(this) % 5000);
    final retryAfter = _sourceRetryAfter[source];
    if (retryAfter != null) {
      final remaining = retryAfter.difference(DateTime.now());
      if (remaining > delay) delay = remaining;
      if (remaining <= Duration.zero) _sourceRetryAfter.remove(source);
    }
    final deferred = notBefore?.call()?.difference(DateTime.now());
    if (deferred != null && deferred > delay) delay = deferred;
    final epoch = _epoch;
    _timer = Timer(delay, () async {
      _timer = null;
      if (epoch != _epoch || !_canRun || !_eligible || !_hasBudget) return;
      _running = true;
      try {
        await _requests.run(
          source,
          () async {
            final limitedUntil = _sourceRetryAfter[source];
            if (limitedUntil != null && limitedUntil.isAfter(DateTime.now()))
              return;
            _attempt++;
            await runZoned(retry, zoneValues: {_automaticReadKey: true});
          },
          current: () => epoch == _epoch && _canRun && _eligible && _hasBudget,
        );
      } catch (error) {
        if (epoch == _epoch && error is! ImageRecoverySuperseded) failed(error);
      } finally {
        _running = false;
        if (epoch == _epoch) {
          final followUp = _followUp;
          _followUp = false;
          _schedule(immediate: followUp);
        } else {
          _schedule();
        }
      }
    });
  }

  void reset() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _error = null;
    _invalidated = false;
    _attempt = 0;
    _followUp = false;
  }

  void dispose() {
    if (_disposed) return;
    reset();
    _disposed = true;
    unawaited(_networkChanges.cancel());
    unawaited(_signals.cancel());
    unawaited(_activity.cancel());
  }
}

/// At most two sources recover concurrently and one read per source runs at a
/// time. Different queries keep their own result ownership; they never share an
/// unrelated response merely because their source is the same.
class _ReadRecoveryAdmission {
  final _pending = <_ReadRecoveryJob>[];
  final _sources = <String>{};
  Future<void> run(
    String source,
    Future<void> Function() action, {
    required bool Function() current,
  }) {
    final job = _ReadRecoveryJob(source, action, current);
    _pending.add(job);
    _drain();
    return job.result.future;
  }

  void _drain() {
    while (_sources.length < 2) {
      final index = _pending.indexWhere(
        (job) => !_sources.contains(job.source),
      );
      if (index < 0) return;
      final job = _pending.removeAt(index);
      if (!job.current()) {
        job.result.complete();
        continue;
      }
      _sources.add(job.source);
      Future<void>.sync(job.action)
          .then(job.result.complete, onError: job.result.completeError)
          .whenComplete(() {
            _sources.remove(job.source);
            _drain();
          });
    }
  }
}

class _ReadRecoveryJob {
  _ReadRecoveryJob(this.source, this.action, this.current);
  final String source;
  final Future<void> Function() action;
  final bool Function() current;
  final result = Completer<void>();
}
