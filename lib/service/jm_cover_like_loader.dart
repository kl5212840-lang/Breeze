import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/comic_info/models/unified_plugin_detail.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

/// One queue for all visible JM covers, including simultaneously mounted tabs.
/// Retired calls keep their slots until the underlying plugin call has settled.
class JmCoverLikeLoader {
  JmCoverLikeLoader({
    required this.counts,
    required PluginSessionWriteFence fence,
    required ValueListenable<int> foregroundReads,
    required Future<int?> Function(String comicId) read,
    required bool Function() canRead,
    Duration Function()? elapsed,
  }) : _fence = fence,
       _foregroundReads = foregroundReads,
       _read = read,
       _canRead = canRead,
       _elapsed = elapsed {
    _foregroundReads.addListener(_foregroundChanged);
    _boundary = _fence.changes.listen((event) {
      if (event.source != JmListLikeCounts.source) return;
      _failed.clear();
      _cooldown = Duration.zero;
      _pending.clear();
      for (final attempt in _running.values) {
        attempt.owners.clear();
      }
    });
  }

  static final instance = JmCoverLikeLoader(
    counts: JmListLikeCounts.instance,
    fence: pluginSessionWriteFence,
    foregroundReads: jmForegroundComicReads,
    canRead: _installedDetailContract,
    read: _readDetailLikes,
  );

  static bool _installedDetailContract() {
    const source = JmListLikeCounts.source;
    final registry = PluginRegistryService.I;
    final info = registry.getCachedPluginInfo(source);
    final experience = asJsonMap(
      info?['breezeExperience'] ?? asJsonMap(info?['data'])['breezeExperience'],
    );
    // This marker identifies the maintained JM bundle with a known detail
    // metric schema. The background request still uses ordinary comic detail.
    return registry.getByUuid(source)?.isActive == true &&
        experience['comicFollow'] == 1;
  }

  static Future<int?> _readDetailLikes(String comicId) async {
    const source = JmListLikeCounts.source;
    // No cancel race: the slot is owned until the physical plugin call returns.
    // This uses the current source route/session and publishes no detail writes.
    final response = await callUnifiedComicPlugin(
      from: source,
      fnPath: 'getComicDetail',
      core: {'comicId': comicId},
      notifyUnauthorized: false,
      jmCoverLikeRead: true,
    );
    return UnifiedPluginDetailResponse.fromMap(
      response,
    ).confirmedLikes(source: source, comicId: comicId);
  }

  final JmListLikeCounts counts;
  final PluginSessionWriteFence _fence;
  final ValueListenable<int> _foregroundReads;
  final Future<int?> Function(String comicId) _read;
  final bool Function() _canRead;
  final Duration Function()? _elapsed;
  final _clock = Stopwatch()..start();
  final _pending = <Object, Set<String>>{};
  final _running = <String, _LikeRead>{};
  final _failed = <String, Duration>{};
  late final StreamSubscription<PluginSessionBoundary> _boundary;
  Duration _cooldown = Duration.zero;
  bool _disposed = false;
  bool _drainScheduled = false;

  Duration get _now => _elapsed?.call() ?? _clock.elapsed;

  void _foregroundChanged() => _scheduleDrain();

  void _scheduleDrain() {
    // Priority traffic can finish while a widget tree is being replaced.
    if (_disposed || _drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      _drain();
    });
  }

  void setDemand(Object owner, Set<String> visible) {
    if (_disposed) return;
    if (visible.isEmpty) {
      _pending.remove(owner);
    } else {
      _pending[owner] = visible;
    }
    for (final attempt in _running.values) {
      // Once all owners have retired, a late response cannot reattach.
      if (attempt.owners.isEmpty || !visible.contains(attempt.id)) {
        attempt.owners.remove(owner);
      } else {
        attempt.owners.add(owner);
      }
    }
    _scheduleDrain();
  }

  void retainDemand(Object owner, Set<String> visible) {
    final previous = _pending[owner];
    if (previous != null) setDemand(owner, previous.intersection(visible));
  }

  void _drain() {
    const source = JmListLikeCounts.source;
    if (_disposed ||
        _pending.isEmpty ||
        _running.length >= 2 ||
        _foregroundReads.value > 0 ||
        _fence.isChanging(source) ||
        _now < _cooldown ||
        !_canRead()) {
      return;
    }
    final now = _now;
    _failed.removeWhere((_, until) => until <= now);
    for (final id in _pending.values.expand((ids) => ids).toSet()) {
      if (_running.length >= 2) break;
      if (counts.countFor(id) != null ||
          _running.containsKey(id) ||
          _failed.containsKey(id)) {
        continue;
      }
      final attempt = _LikeRead(id, _fence.generation(source), {
        for (final entry in _pending.entries)
          if (entry.value.contains(id)) entry.key,
      });
      _running[id] = attempt;
      unawaited(_load(attempt));
    }
  }

  Future<void> _load(_LikeRead attempt) async {
    try {
      final count = await _read(attempt.id);
      if (!_owns(attempt)) return;
      if (count == null) {
        _defer(attempt.id, const Duration(minutes: 15));
      } else if (counts.countFor(attempt.id) == null) {
        counts.remember({attempt.id: count}, generation: attempt.generation);
      }
    } catch (error) {
      if (!_owns(attempt)) return;
      final failure = classifyComicFollowCheckFailure(
        error,
        additionalEnvelopeType: 'comic_detail_error',
      );
      final rateLimited =
          failure.httpStatus == 429 ||
          RegExp(
            r'(?:服务器响应异常\s*\(429\)|\b429 Too Many Requests\b)',
          ).hasMatch(quickJsErrorMessage(error) ?? '');
      final delay = switch (failure) {
        ComicFollowCheckException(httpStatus: 429) => const Duration(
          minutes: 2,
        ),
        ComicFollowCheckException(reason: ComicFollowCheckFailure.network) =>
          const Duration(seconds: 30),
        _ => const Duration(minutes: 2),
      };
      if (rateLimited ||
          failure.reason == ComicFollowCheckFailure.sourceUnavailable ||
          failure.reason == ComicFollowCheckFailure.network ||
          failure.reason == ComicFollowCheckFailure.unknown ||
          failure.reason == ComicFollowCheckFailure.signInRequired) {
        // Some legacy JM bundles omit HTTP status from the error. Cool down
        // ambiguous transport failures too, without a timer to resume reads.
        _cooldown = _now + delay;
      }
      _defer(attempt.id, delay);
    } finally {
      _running.remove(attempt.id);
      _drain();
    }
  }

  bool _owns(_LikeRead attempt) =>
      !_disposed &&
      attempt.owners.isNotEmpty &&
      !_fence.isChanging(JmListLikeCounts.source) &&
      _fence.generation(JmListLikeCounts.source) == attempt.generation;

  void _defer(String id, Duration delay) {
    _failed.remove(id);
    _failed[id] = _now + delay;
    if (_failed.length > 256) _failed.remove(_failed.keys.first);
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    _foregroundReads.removeListener(_foregroundChanged);
    unawaited(_boundary.cancel());
  }
}

class _LikeRead {
  _LikeRead(this.id, this.generation, this.owners);

  final String id;
  final int generation;
  final Set<Object> owners;
}
