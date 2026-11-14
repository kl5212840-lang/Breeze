import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';

/// One mounted main navigation owns application-wide foreground checks. This
/// has no OS/background worker and does not depend on the currently shown page.
class ComicFollowForegroundScheduler with WidgetsBindingObserver {
  ComicFollowForegroundScheduler({
    required this.cubit,
    Timer Function(Duration, void Function())? timerFactory,
    AppLifecycleState? Function()? lifecycleState,
    this.observeLifecycle = true,
  }) : _timerFactory =
           timerFactory ?? ((delay, callback) => Timer(delay, callback)),
       _lifecycleState =
           lifecycleState ?? (() => WidgetsBinding.instance.lifecycleState);

  static const foregroundResumeDelay = Duration(minutes: 1);
  final ComicFollowCubit cubit;
  final Timer Function(Duration, void Function()) _timerFactory;
  final AppLifecycleState? Function() _lifecycleState;
  final bool observeLifecycle;
  final Stopwatch _timerAge = Stopwatch();
  StreamSubscription<ComicFollowState>? _followSubscription;
  Timer? _timer;
  Duration _scheduledDelay = Duration.zero;
  int? _followRevision;
  bool _started = false, _disposed = false, _foreground = false;
  int _generation = 0;

  bool get hasScheduledCheck => _timer?.isActive == true;
  bool get _ownsForeground =>
      !_disposed &&
      _started &&
      _foreground &&
      cubit.isApplicationCheckingOwner(this);

  void start() {
    if (_disposed) throw StateError('Follow scheduler already disposed');
    if (_started) return;
    _started = true;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    final state = _lifecycleState();
    _foreground = state == null || state == AppLifecycleState.resumed;
    cubit.attachApplicationCheckingOwner(this, foreground: _foreground);
    _followRevision = cubit.state.revision;
    _followSubscription = cubit.stream.listen(_onFollowChanged);
    if (_foreground) _schedule(foregroundResumeDelay);
  }

  void _onFollowChanged(ComicFollowState state) {
    // A manual batch emits a revision for each row. Recalculate its deadline
    // once when the batch settles.
    if (state.isCheckingUpdates || state.revision == _followRevision) return;
    _followRevision = state.revision;
    if (!_ownsForeground || !hasScheduledCheck) return;
    // An imported record or a recent failure can be due sooner than the timer
    // calculated for the previous list. Keep any already earlier deadline.
    final delay = cubit.nextAutomaticCheckDelay;
    if (delay < _scheduledDelay - _timerAge.elapsed) _schedule(delay);
  }

  void _schedule(Duration delay) {
    if (!_ownsForeground) return;
    _timer?.cancel();
    _scheduledDelay = delay;
    _timerAge
      ..reset()
      ..start();
    final generation = _generation;
    _timer = _timerFactory(delay, () {
      unawaited(_tick(generation));
    });
  }

  Future<void> _tick(int generation) async {
    if (!_ownsForeground || generation != _generation) return;
    _timer = null;
    _timerAge.stop();
    try {
      await cubit.checkDueUpdates();
    } catch (error, stackTrace) {
      logger.w('应用前台追更检查暂未完成', error: error, stackTrace: stackTrace);
    } finally {
      if (_ownsForeground && generation == _generation) {
        _schedule(cubit.nextAutomaticCheckDelay);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !_started) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _timerAge.stop();
    cubit.setApplicationCheckingForeground(this, foreground);
    if (foreground) _schedule(foregroundResumeDelay);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _timerAge.stop();
    unawaited(_followSubscription?.cancel());
    if (_started && observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    cubit.detachApplicationCheckingOwner(this);
  }
}
