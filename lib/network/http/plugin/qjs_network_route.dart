import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';

import 'package:zephyr/network/source_network_policy.dart';

/// Source identity stays stable while only the transport runtime is versioned.
String canonicalQjsSource(String value) {
  value = value.trim();
  while (value.length >= 2 && value.startsWith('(') && value.endsWith(')')) {
    value = value.substring(1, value.length - 1).trim();
  }
  return SourceNetworkPolicies.canonicalSource(pluginSessionBaseRuntime(value));
}

class _QjsTaskNetworkScope {
  const _QjsTaskNetworkScope(this.snapshot, this.taskGroupKey);
  final SourceNetworkSnapshot snapshot;
  final String taskGroupKey;
}

/// Pins a whole download, including metadata calls without an explicit group,
/// to one snapshot. Concurrent downloads and foreground visits stay separate.
class QjsNetworkRouteStore {
  QjsNetworkRouteStore({
    Future<SourceNetworkSnapshot> Function(String)? resolve,
  }) : _resolve = resolve ?? SourceNetworkPolicies.resolve;

  final Future<SourceNetworkSnapshot> Function(String) _resolve;
  final _known = <String, SourceNetworkSnapshot>{};
  final _groups = <String, Future<SourceNetworkSnapshot>>{};
  final _scopeKey = Object();

  String _groupKey(String source, String group) => '$source::$group';

  Future<SourceNetworkSnapshot> resolve(
    String source, {
    String? runtimeName,
    String? taskGroupKey,
  }) async {
    source = canonicalQjsSource(source);
    final scope = Zone.current[_scopeKey] as _QjsTaskNetworkScope?;
    if (scope?.snapshot.source == source) return scope!.snapshot;
    if (taskGroupKey != null && taskGroupKey.isNotEmpty) {
      final key = _groupKey(source, taskGroupKey);
      final existing = _groups[key];
      if (existing != null) return existing;
      final pending = _resolveRuntime(source, runtimeName);
      _groups[key] = pending;
      try {
        return await pending;
      } catch (_) {
        if (identical(_groups[key], pending)) _groups.remove(key);
        rethrow;
      }
    }
    return _resolveRuntime(source, runtimeName);
  }

  Future<SourceNetworkSnapshot> _resolveRuntime(
    String source,
    String? runtimeName,
  ) async {
    final requested = runtimeName?.trim() ?? '';
    if (requested.isNotEmpty && canonicalQjsSource(requested) != source) {
      throw StateError('Runtime belongs to a different source');
    }
    final snapshot = await _resolve(source);
    // Callers historically pass source or the registry's current runtime name.
    // Both resolve the current visit. Only an explicit task-group scope pins an
    // older generation; otherwise a stale registry name must not pin forever.
    _known[snapshot.runtimeName] = snapshot;
    return snapshot;
  }

  Future<T> runTaskGroup<T>({
    required String source,
    required String taskGroupKey,
    required Future<T> Function() action,
  }) async {
    final snapshot = await resolve(source, taskGroupKey: taskGroupKey);
    try {
      return await runZoned(
        action,
        zoneValues: {_scopeKey: _QjsTaskNetworkScope(snapshot, taskGroupKey)},
      );
    } finally {
      releaseGroup(source, taskGroupKey);
    }
  }

  String? currentTaskGroup(String source) {
    final scope = Zone.current[_scopeKey] as _QjsTaskNetworkScope?;
    return scope?.snapshot.source == canonicalQjsSource(source)
        ? scope!.taskGroupKey
        : null;
  }

  SourceNetworkSnapshot? known(String runtimeName) => _known[runtimeName];

  Iterable<String> runtimeNames(String source) => _known.entries
      .where((entry) => entry.value.source == canonicalQjsSource(source))
      .map((entry) => entry.key);

  void releaseGroup(String source, String taskGroupKey) {
    _groups.remove(_groupKey(canonicalQjsSource(source), taskGroupKey));
  }
}

/// A set loses the second reference when overlapping requests share a runtime.
class QjsTaskRuntimeReferences {
  final _groups = <String, Map<String, int>>{};

  void retain(String group, String runtime) {
    final refs = _groups.putIfAbsent(group, () => {});
    refs[runtime] = (refs[runtime] ?? 0) + 1;
  }

  void release(String group, String runtime) {
    final refs = _groups[group];
    if (refs == null) return;
    final remaining = (refs[runtime] ?? 0) - 1;
    if (remaining > 0) {
      refs[runtime] = remaining;
    } else {
      refs.remove(runtime);
    }
    if (refs.isEmpty) _groups.remove(group);
  }

  List<String> take(String group) => _groups.remove(group)?.keys.toList() ?? [];
}
