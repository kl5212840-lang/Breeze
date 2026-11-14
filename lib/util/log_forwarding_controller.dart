import 'dart:async';

/// Reconfigures the two forwarding sinks together without replacing local log
/// outputs. Injected callbacks make save/clear/failure behavior testable offline.
class LogForwardingController {
  LogForwardingController({
    required this.configureRust,
    required this.configureDart,
  });

  final FutureOr<void> Function(String) configureRust;
  final void Function(String) configureDart;
  String _current = '';
  Future<void>? _pending;
  String get current => _current;

  Future<void> _serialize(Future<void> Function() action) async {
    final work = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => action());
    _pending = work;
    try {
      await work;
    } finally {
      if (identical(_pending, work)) _pending = null;
    }
  }

  Future<void> _apply(String address) async {
    final previous = _current;
    try {
      await configureRust(address);
      configureDart(address);
      _current = address;
    } catch (_) {
      await configureRust(previous);
      configureDart(previous);
      rethrow;
    }
  }

  Future<void> apply(String address) =>
      _serialize(() => _apply(address.trim()));

  Future<void> save(
    String address, {
    required FutureOr<void> Function(String) persist,
  }) => _serialize(() async {
    final previous = _current;
    await _apply(address.trim());
    try {
      await persist(_current);
    } catch (_) {
      await _apply(previous);
      rethrow;
    }
  });
}
