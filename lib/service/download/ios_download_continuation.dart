import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

typedef _Progress = ({String title, String subtitle, int completed, int total});

/// Owns a system continued activity for one user-initiated download scope.
/// Legacy transfers remain independent of platform acceptance.
final class IosDownloadContinuation {
  IosDownloadContinuation(this.scope, this.onExpired);

  final String scope;
  final Future<void> Function() onExpired;
  static const channel = MethodChannel('breeze.download.continued');
  static final _owners = <String, IosDownloadContinuation>{};
  static bool _installed = false;

  String? _token;
  _Progress? _latest;
  Timer? _timer;
  bool _accepted = false;

  bool get active => _token != null;

  static bool get canBegin =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static void _install() {
    if (_installed) return;
    _installed = true;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method != 'expired' || args is! Map) return false;
      final owner = _owners[args['scope']];
      final token = owner?._token;
      if (owner == null || token == null || token != args['token'])
        return false;
      owner._clear();
      try {
        await owner.onExpired();
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  Map<String, Object> _args(String token, _Progress progress) => {
    'scope': scope,
    'token': token,
    'title': progress.title,
    'subtitle': progress.subtitle,
    'completed': progress.completed,
    'total': progress.total,
  };

  Future<bool> beginFromUser({
    required String title,
    required String subtitle,
    required int completed,
    required int total,
  }) async {
    if (!canBegin || !_valid(completed, total)) return false;
    if (active) {
      update(
        title: title,
        subtitle: subtitle,
        completed: completed,
        total: total,
      );
      return _accepted;
    }
    final previous = _owners[scope];
    if (previous != null && !identical(previous, this)) {
      unawaited(previous.finish(success: false));
    }
    _install();
    final token = _token = const Uuid().v4();
    final progress = _latest = (
      title: title,
      subtitle: subtitle,
      completed: completed,
      total: total,
    );
    _owners[scope] = this;
    try {
      final result = await channel.invokeMapMethod<String, Object>(
        'begin',
        _args(token, progress),
      );
      if (_token != token) return false;
      if (result?['accepted'] == true) {
        _accepted = true;
        if (_latest != progress) _schedule();
        return true;
      }
    } catch (_) {
      // Older iOS builds and denied scheduling keep their original transport.
    }
    if (_token == token) _clear();
    return false;
  }

  static bool _valid(int completed, int total) =>
      completed >= 0 && total > 0 && completed <= total;

  void update({
    required String title,
    required String subtitle,
    required int completed,
    required int total,
  }) {
    if (!active || !_valid(completed, total)) return;
    final progress = (
      title: title,
      subtitle: subtitle,
      completed: completed,
      total: total,
    );
    if (_latest == progress) return;
    _latest = progress;
    if (_accepted) _schedule();
  }

  void _schedule() {
    _timer ??= Timer(const Duration(milliseconds: 250), () {
      _timer = null;
      final token = _token, progress = _latest;
      if (token != null && progress != null) {
        unawaited(_send('update', _args(token, progress)));
      }
    });
  }

  void _clear() {
    _token = null;
    _accepted = false;
    _latest = null;
    _timer?.cancel();
    _timer = null;
    if (identical(_owners[scope], this)) _owners.remove(scope);
  }

  static Future<void> _send(String method, Map<String, Object> args) async {
    try {
      await channel.invokeMethod<Object?>(method, args);
    } catch (_) {
      // Activity bookkeeping cannot stop a legacy transfer.
    }
  }

  Future<void> finish({required bool success}) async {
    final token = _token, progress = _latest, accepted = _accepted;
    if (token == null) return;
    _clear();
    // Preserve the last measured units before a successful terminal update.
    if (success && accepted && progress != null) {
      await _send('update', _args(token, progress));
    }
    await _send('end', {'scope': scope, 'token': token, 'success': success});
  }
}
