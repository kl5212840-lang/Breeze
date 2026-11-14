import 'dart:async';

class PluginSessionBoundary {
  const PluginSessionBoundary(this.source, this.generation, this.changing);
  final String source;
  final int generation;
  final bool changing;
}

/// A host-owned runtime suffix. It is never stored as a plugin/config identity.
final _sessionSuffix = RegExp(r'\.breeze-session\.([1-9][0-9]*)$');

String pluginSessionBaseRuntime(String runtime) =>
    runtime.replaceFirst(_sessionSuffix, '');

/// Source-wide write ownership, independent of a JS VM's local revision.
///
/// Only an explicit host session/lifecycle boundary advances this clock. Empty
/// strings, nulls, arbitrary field names and network changes carry no intent.
class PluginSessionWriteFence {
  final _generations = <String, int>{};
  final _changing = <String, int>{};
  final _changes = StreamController<PluginSessionBoundary>.broadcast(
    sync: true,
  );

  Stream<PluginSessionBoundary> get changes => _changes.stream;
  bool isChanging(String source) => _changing[source] == generation(source);

  int generation(String source) => _generations[source] ?? 0;

  int advance(String source) {
    final next = _generations[source] = generation(source) + 1;
    _changes.add(PluginSessionBoundary(source, next, isChanging(source)));
    return next;
  }

  int beginSessionChange(String source) {
    _changing[source] = generation(source) + 1;
    return advance(source);
  }

  void seal(String source, int owner) {
    if (_changing[source] == owner) _changing.remove(source);
    if (generation(source) == owner) advance(source);
  }

  String runtime(String source, String baseRuntime) {
    final base = pluginSessionBaseRuntime(baseRuntime);
    final current = generation(source);
    return current == 0 ? base : '$base.breeze-session.$current';
  }

  bool permits(String source, String runtime) {
    runtime = runtime.trim();
    while (runtime.length >= 2 &&
        runtime.startsWith('(') &&
        runtime.endsWith(')')) {
      runtime = runtime.substring(1, runtime.length - 1).trim();
    }
    final match = _sessionSuffix.firstMatch(runtime);
    final owner = match == null ? 0 : int.tryParse(match.group(1)!) ?? -1;
    return owner == generation(source);
  }
}

final pluginSessionWriteFence = PluginSessionWriteFence();

/// Carries no source name, field, credentials or plugin-returned error text.
class PluginSessionChanged implements Exception {
  const PluginSessionChanged();
  @override
  String toString() => '账号状态已变化，请重新操作';
}

bool isStandardPluginSessionChange(String function) => const {
  'clearPluginSession',
  'loginWithPassword',
  'updatePassword',
}.contains(function.trim());
