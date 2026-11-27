import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

typedef ComicLikeResult = ({bool liked, int? totalLikes});
typedef ComicLikeWork = ({String source, String id});

ComicLikeWork comicLikeWork(String source, String id) =>
    (source: canonicalQjsSource(source), id: id);

/// Recent votes shared by details and any already-loaded list rows.
/// List responses are snapshots and never replace a vote written after loading.
class ComicLikeUpdates extends ChangeNotifier {
  ComicLikeUpdates._([this._elapsed]) {
    _sessionChanges = pluginSessionWriteFence.changes.listen((boundary) {
      final size = _updates.length;
      _updates.removeWhere((work, _) => work.source == boundary.source);
      final writes = _writes.length;
      _writes.removeWhere((work, _) => work.source == boundary.source);
      final unconfirmed = _unconfirmed.length;
      _unconfirmed.removeWhere((work, _) => work.source == boundary.source);
      if (_updates.length != size ||
          _writes.length != writes ||
          _unconfirmed.length != unconfirmed) {
        notifyListeners();
      }
    });
  }

  @visibleForTesting
  ComicLikeUpdates.withClock(Duration Function() elapsed) : this._(elapsed);

  static final instance = ComicLikeUpdates._();
  static const _maxWorks = 256;
  static const _settleWindow = Duration(seconds: 15);
  final _clock = Stopwatch()..start();
  final Duration Function()? _elapsed;
  late final StreamSubscription<PluginSessionBoundary> _sessionChanges;
  final _updates = <ComicLikeWork, _LikeUpdate>{};
  final _writes = <ComicLikeWork, Object>{};
  final _unconfirmed = <ComicLikeWork, _UnconfirmedLike>{};
  Duration get _now => _elapsed?.call() ?? _clock.elapsed;

  ComicLikeResult? valueFor(ComicLikeWork work) => _updates[work]?.value;

  Object? markRead(ComicLikeWork work) => _unconfirmed[work] ?? _updates[work];

  bool isWriting(ComicLikeWork work) => _writes.containsKey(work);
  bool needsCheck(ComicLikeWork work) => _unconfirmed.containsKey(work);
  bool ownsWrite(ComicLikeWork work, Object owner) =>
      identical(_writes[work], owner);

  Object? beginWrite(ComicLikeWork work) {
    if (isWriting(work) || pluginSessionWriteFence.isChanging(work.source)) {
      return null;
    }
    final owner = _writes[work] = Object();
    if (_updates[work] case final previous?) {
      // An earlier read must not publish while a new intent is being sent.
      _updates[work] = _LikeUpdate(
        value: previous.value,
        before: previous.before,
        acceptedAt: previous.acceptedAt,
        awaitingTotal: previous.awaitingTotal,
      );
    }
    notifyListeners();
    return owner;
  }

  void finishWrite(
    ComicLikeWork work,
    Object owner, {
    ComicLikeResult? unconfirmedBefore,
    Future<ComicLikeResult> Function()? readUnconfirmed,
    Duration readTimeout = const Duration(seconds: 4),
  }) {
    if (!ownsWrite(work, owner)) return;
    _writes.remove(work);
    _unconfirmed.remove(work);
    if (unconfirmedBefore != null) {
      final check = _unconfirmed[work] = _UnconfirmedLike(unconfirmedBefore);
      if (_unconfirmed.length > _maxWorks) {
        _unconfirmed.remove(_unconfirmed.keys.first);
      }
      if (readUnconfirmed != null) {
        unawaited(
          _verifyUnconfirmed(work, check, readUnconfirmed, readTimeout),
        );
      }
    }
    notifyListeners();
  }

  void observeDetail(
    ComicLikeWork work,
    Object? startedWith,
    ComicLikeResult value,
  ) {
    if (isWriting(work)) return;
    if (_unconfirmed[work] case final check?) {
      if (identical(check, startedWith) && value.liked != check.before.liked) {
        _unconfirmed.remove(work);
        _remember(work, check.before, value, canReconcile: true);
      }
      return;
    }
    final update = _updates[work];
    if (update == null || !identical(update, startedWith)) return;
    final recent = _now - update.acceptedAt < _settleWindow;
    // A confirmed selection can persist while every aggregate read still
    // returns the exact pre-write number. Elapsed time cannot make it newer.
    if (recent && value.liked != update.value.liked) return;
    if (value.liked == update.value.liked &&
        (value.totalLikes == null ||
            (update.awaitingTotal || recent) && _hasOldTotal(update, value))) {
      return;
    }
    _replace(work, update, value);
  }

  void accept(
    ComicLikeWork work, {
    required Object owner,
    required ComicLikeResult before,
    required ComicLikeResult receipt,
    Future<ComicLikeResult> Function()? read,
    Duration readTimeout = const Duration(seconds: 4),
  }) {
    if (!ownsWrite(work, owner)) return;
    final update = _remember(work, before, receipt, canReconcile: read != null);
    if (update.awaitingTotal && read != null) {
      unawaited(_reconcile(work, update, read, readTimeout));
    }
  }

  Future<void> _verifyUnconfirmed(
    ComicLikeWork work,
    _UnconfirmedLike check,
    Future<ComicLikeResult> Function() read,
    Duration readTimeout,
  ) async {
    bool isCurrent() =>
        !isWriting(work) && identical(_unconfirmed[work], check);
    for (final delay in [Duration.zero, const Duration(milliseconds: 350)]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!isCurrent()) return;
      try {
        final value = await read().timeout(readTimeout);
        if (!isCurrent()) return;
        if (value.liked == check.before.liked) continue;
        _unconfirmed.remove(work);
        final update = _remember(work, check.before, value, canReconcile: true);
        if (update.awaitingTotal) {
          unawaited(_reconcile(work, update, read, readTimeout));
        }
        return;
      } on PluginLoginRequiredException {
        return;
      } on PluginSessionChanged {
        return;
      } on TimeoutException {
        return;
      } catch (_) {
        // Keep the receipt unknown when a follow-up read fails.
      }
    }
  }

  _LikeUpdate _remember(
    ComicLikeWork work,
    ComicLikeResult before,
    ComicLikeResult receipt, {
    required bool canReconcile,
  }) {
    final pending =
        canReconcile &&
        receipt.liked != before.liked &&
        (receipt.totalLikes == null || receipt.totalLikes == before.totalLikes);
    final previous = before.totalLikes;
    final projected = pending && previous != null
        ? previous + (receipt.liked ? 1 : (previous == 0 ? 0 : -1))
        : null;
    final count =
        parsePublicComicCount(projected) ?? receipt.totalLikes ?? previous;
    final update = _LikeUpdate(
      value: (liked: receipt.liked, totalLikes: count),
      before: before,
      acceptedAt: _now,
      awaitingTotal: pending,
    );
    _put(work, update);
    return update;
  }

  bool _hasOldTotal(_LikeUpdate update, ComicLikeResult observed) =>
      update.before.liked != update.value.liked &&
      update.value.totalLikes != update.before.totalLikes &&
      observed.totalLikes == update.before.totalLikes;

  Future<void> _reconcile(
    ComicLikeWork work,
    _LikeUpdate update,
    Future<ComicLikeResult> Function() read,
    Duration readTimeout,
  ) async {
    ComicLikeResult? observed;
    var mismatches = 0;
    for (final delay in [Duration.zero, const Duration(milliseconds: 350)]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!identical(_updates[work], update)) return;
      try {
        final value = await read().timeout(readTimeout);
        if (!identical(_updates[work], update)) return;
        observed = value;
        if (value.liked != update.value.liked) mismatches++;
        if (value.liked == update.value.liked &&
            value.totalLikes != null &&
            !_hasOldTotal(update, value)) {
          _replace(work, update, value);
          return;
        }
      } on PluginSessionChanged {
        return;
      } on TimeoutException {
        break;
      } catch (_) {
        // Receipt and aggregate reads can succeed independently.
      }
    }
    if (mismatches == 2 &&
        observed != null &&
        observed.liked != update.value.liked &&
        identical(_updates[work], update)) {
      _replace(work, update, (
        liked: observed.liked,
        totalLikes: observed.totalLikes ?? update.before.totalLikes,
      ));
    }
  }

  void _replace(
    ComicLikeWork work,
    _LikeUpdate update,
    ComicLikeResult result,
  ) {
    _put(
      work,
      _LikeUpdate(
        value: (
          liked: result.liked,
          totalLikes: result.totalLikes ?? update.value.totalLikes,
        ),
        before: update.before,
        acceptedAt: update.acceptedAt,
        awaitingTotal: false,
      ),
    );
  }

  void _put(ComicLikeWork work, _LikeUpdate update) {
    final previous = _updates.remove(work);
    _updates[work] = update;
    final evicted = _updates.length > _maxWorks;
    if (evicted) _updates.remove(_updates.keys.first);
    if (evicted || previous?.value != update.value) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sessionChanges.cancel());
    _updates.clear();
    _writes.clear();
    _unconfirmed.clear();
    super.dispose();
  }
}

class _UnconfirmedLike {
  _UnconfirmedLike(this.before);

  final ComicLikeResult before;
}

class _LikeUpdate {
  const _LikeUpdate({
    required this.value,
    required this.before,
    required this.acceptedAt,
    required this.awaitingTotal,
  });

  final ComicLikeResult value;
  final ComicLikeResult before;
  final Duration acceptedAt;
  final bool awaitingTotal;
}
