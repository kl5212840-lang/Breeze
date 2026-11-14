import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 阅读器系统 UI（状态栏/导航栏）服务。
///
/// 封装 `SystemChrome` 与 Android 原生 `MethodChannel('system_ui_control')`，
/// 使 controller 层不再直接操作平台 UI。
class ReaderSystemUiService {
  static final ReaderSystemUiService instance = ReaderSystemUiService._();
  ReaderSystemUiService._();

  static const _systemUiChannel = MethodChannel('system_ui_control');

  Timer? _syncTimer;
  bool? _lastMenuVisible;
  int _owner = 0;
  Future<void> _pending = Future<void>.value();

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  int acquire() {
    _syncTimer?.cancel();
    _lastMenuVisible = null;
    return ++_owner;
  }

  /// Delayed callbacks belong to the reader that requested them.
  void scheduleSync(
    int owner,
    void Function() syncFn, {
    Duration delay = const Duration(milliseconds: 24),
  }) {
    if (owner != _owner) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(delay, () {
      if (owner == _owner) syncFn();
    });
  }

  Future<void> applyVisibility(
    int owner,
    bool isMenuVisible, {
    bool force = false,
  }) async {
    if (owner != _owner || (!force && _lastMenuVisible == isMenuVisible))
      return;
    _lastMenuVisible = isMenuVisible;
    try {
      await _enqueue(owner, visible: isMenuVisible);
    } catch (_) {
      if (owner == _owner && _lastMenuVisible == isMenuVisible) {
        _lastMenuVisible = null;
      }
      rethrow;
    }
  }

  /// Release the bars only if this is still the most recent reader.
  Future<void> release(int owner) {
    if (owner != _owner) return Future<void>.value();
    _syncTimer?.cancel();
    _lastMenuVisible = null;
    return _enqueue(++_owner, visible: true);
  }

  Future<void> _enqueue(int owner, {required bool visible}) {
    final request = _pending.then((_) async {
      if (owner != _owner) return;
      await (visible ? _showSystemBars() : _hideSystemBars());
    });
    _pending = request.then<void>((_) {}, onError: (Object _) {});
    return request;
  }

  Future<void> _showSystemBars() async {
    if (_isAndroid) {
      await _systemUiChannel.invokeMethod('showSystemBars');
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  Future<void> _hideSystemBars() async {
    if (_isAndroid) {
      await _systemUiChannel.invokeMethod('hideSystemBars');
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }
}
