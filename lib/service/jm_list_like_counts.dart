import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/util/json/json_value.dart';

/// Short-lived public counts already read by the JM list or detail. No IO.
class JmListLikeCounts extends ChangeNotifier {
  JmListLikeCounts({
    PluginSessionWriteFence? sessionFence,
    Duration Function()? elapsed,
    Duration lifetime = const Duration(minutes: 15),
    int capacity = 256,
  }) : assert(capacity > 0),
       assert(lifetime > Duration.zero),
       _fence = sessionFence ?? pluginSessionWriteFence,
       _elapsed = elapsed,
       _lifetime = lifetime,
       _capacity = capacity {
    _subscription = _fence.changes.listen((boundary) {
      if (boundary.source != source || _values.isEmpty) return;
      _values.clear();
      _expiry?.cancel();
      notifyListeners();
    });
  }

  static const source = PluginAccountAuthenticationService.jm;
  static final instance = JmListLikeCounts();
  final PluginSessionWriteFence _fence;
  final Duration Function()? _elapsed;
  final _clock = Stopwatch()..start();
  final Duration _lifetime;
  final int _capacity;
  final _values = <String, ({int count, Duration expires})>{};
  late final StreamSubscription<PluginSessionBoundary> _subscription;
  Timer? _expiry;
  Duration get _now => _elapsed?.call() ?? _clock.elapsed;

  int? countFor(String comicId) {
    if (_fence.isChanging(source)) return null;
    final value = _values[comicId];
    return value != null && value.expires > _now ? value.count : null;
  }

  void remember(Map<String, int> counts, {required int generation}) {
    if (counts.isEmpty ||
        _fence.isChanging(source) ||
        _fence.generation(source) != generation) {
      return;
    }
    final now = _now;
    var changed = _removeExpired(now);
    for (final entry in counts.entries) {
      if (entry.key.isEmpty || parsePublicComicCount(entry.value) == null) {
        continue;
      }
      final previous = _values.remove(entry.key);
      _values[entry.key] = (count: entry.value, expires: now + _lifetime);
      changed = changed || previous?.count != entry.value;
    }
    while (_values.length > _capacity) {
      _values.remove(_values.keys.first);
      changed = true;
    }
    _scheduleExpiry(now);
    if (changed) notifyListeners();
  }

  bool _removeExpired(Duration now) {
    final length = _values.length;
    _values.removeWhere((_, value) => value.expires <= now);
    return length != _values.length;
  }

  void _scheduleExpiry(Duration now) {
    _expiry?.cancel();
    if (_values.isEmpty) return;
    _expiry = Timer(_values.values.first.expires - now, () {
      final now = _now;
      final changed = _removeExpired(now);
      _scheduleExpiry(now);
      if (changed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// The legacy JM adapter puts a default zero into both normalized fields.
/// Read the original list row and match by work ID to establish availability.
Map<String, int> readJmListLikeCounts(Object? raw, Set<String> visibleIds) {
  final envelope = asJsonMap(raw);
  final rows = asJsonList(
    raw is List ? raw : envelope['list'] ?? envelope['content'],
  );
  final counts = <String, int>{};
  final seen = <String>{};
  for (final row in rows.whereType<Map>()) {
    final id = row['id']?.toString() ?? '';
    if (!visibleIds.contains(id)) continue;
    if (!seen.add(id)) {
      // An ambiguous original row should never supply a count.
      counts.remove(id);
    } else if (parsePublicComicCount(row['likes']) case final count?) {
      counts[id] = count;
    }
  }
  return counts;
}
