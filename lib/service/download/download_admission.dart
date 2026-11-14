import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';

enum DownloadNetworkWait {
  offline('waitingNetwork'),
  wifi('waitingWifi');

  const DownloadNetworkWait(this.code);
  final String code;

  static DownloadNetworkWait? fromCode(Object? code) =>
      values.where((wait) => wait.code == code).firstOrNull;

  String get label => switch (this) {
    offline => t.download.waitingForNetwork,
    wifi => t.download.waitingForWifi,
  };
}

/// Shared admission for download jobs only. A transport being available does
/// not establish that a source is reachable, logged in, or authorized.
class DownloadAdmission extends ChangeNotifier with WidgetsBindingObserver {
  DownloadAdmission({
    Future<List<ConnectivityResult>> Function()? readNetwork,
    Stream<List<ConnectivityResult>>? networkEvents,
    Future<int?> Function()? readFreeBytes,
  }) : _readNetwork = readNetwork ?? Connectivity().checkConnectivity,
       _networkEvents = networkEvents ?? Connectivity().onConnectivityChanged,
       _readFreeBytes = readFreeBytes ?? _readPlatformFreeBytes;

  static final instance = DownloadAdmission();
  static const minimumFreeBytes = 32 * 1024 * 1024;
  static const _capacity = MethodChannel('breeze.download.capacity');
  static const queuePauseKey = 'breeze.local.download.queue-paused.v1';

  static bool get supportsMobileControls =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  final Future<List<ConnectivityResult>> Function() _readNetwork;
  final Stream<List<ConnectivityResult>> _networkEvents;
  final Future<int?> Function() _readFreeBytes;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<void>? _started;
  Future<void>? _queueStateRead;
  Set<ConnectivityResult>? _transports;
  int _revision = 0;
  bool _wifiOnly = false;
  bool _disposed = false;
  bool _queuePaused = false;
  bool _writingQueuePause = false;
  bool? _lastForegroundAllowed;

  bool get wifiOnly => _wifiOnly;
  bool get queuePaused => _queuePaused;
  bool get foregroundAllowed {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  DownloadNetworkWait? get networkWait {
    final transports = _transports;
    if (transports != null && transports.isEmpty)
      return DownloadNetworkWait.offline;
    if (_wifiOnly && !_hasWifi(transports)) {
      return DownloadNetworkWait.wifi;
    }
    return null;
  }

  bool _hasWifi(Set<ConnectivityResult>? transports) {
    if (transports == null || !transports.contains(ConnectivityResult.wifi)) {
      return false;
    }
    // Android VPNs can report several underlying transports at once. The OS
    // may choose cellular, so wait for a route the native writers can confirm.
    return defaultTargetPlatform != TargetPlatform.android ||
        !transports.any(
          (transport) =>
              transport == ConnectivityResult.mobile ||
              transport == ConnectivityResult.ethernet ||
              transport == ConnectivityResult.vpn,
        );
  }

  void setWifiOnly(bool enabled) {
    if (enabled == _wifiOnly) return;
    _wifiOnly = enabled;
    notifyListeners();
  }

  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    WidgetsBinding.instance.addObserver(this);
    _lastForegroundAllowed = foregroundAllowed;
    _subscription = _networkEvents.listen(_update, onError: (Object _) {});
    await Future.wait([initializeQueueState(), _refresh()]);
  }

  Future<void> initializeQueueState() =>
      _queueStateRead ??= _restoreQueuePause();

  Future<void> _restoreQueuePause() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_disposed && prefs.getBool(queuePauseKey) == true) {
        _queuePaused = true;
        notifyListeners();
      }
    } catch (_) {
      // An unreadable device preference leaves the queue at its default.
    }
  }

  /// This device's queue command, independent of synced settings.
  Future<void> setQueuePaused(bool paused) async {
    if (_writingQueuePause) return;
    _writingQueuePause = true;
    try {
      await initializeQueueState();
      if (_disposed || _queuePaused == paused) return;
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(queuePauseKey, paused)) {
        throw StateError('Could not save the download queue state');
      }
      if (_disposed) return;
      _queuePaused = paused;
      notifyListeners();
    } finally {
      _writingQueuePause = false;
    }
  }

  void _update(List<ConnectivityResult> results) {
    if (_disposed) return;
    _revision++;
    final transports = results
        .where((v) => v != ConnectivityResult.none)
        .toSet();
    if (setEquals(transports, _transports)) return;
    _transports = transports;
    notifyListeners();
  }

  Future<void> _refresh() async {
    final revision = _revision;
    try {
      final current = await _readNetwork().timeout(const Duration(seconds: 2));
      if (!_disposed && revision == _revision) _update(current);
    } catch (_) {
      // An unavailable monitor does not block unrestricted downloads. The
      // Wi-Fi setting still requires a positively identified Wi-Fi transport.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final allowed = foregroundAllowed;
    if (_lastForegroundAllowed != allowed) {
      _lastForegroundAllowed = allowed;
      notifyListeners();
    }
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<bool> waitForNetwork(Future<void> cancelled) async {
    await start();
    if (networkWait == null) return true;
    final ready = Completer<bool>();
    void changed() {
      if (networkWait == null && !ready.isCompleted) ready.complete(true);
    }

    addListener(changed);
    try {
      return await Future.any([ready.future, cancelled.then((_) => false)]);
    } finally {
      removeListener(changed);
    }
  }

  Future<bool> hasSpace() async {
    final free = await availableBytes();
    return free == null || free >= minimumFreeBytes;
  }

  Future<int?> availableBytes() async {
    try {
      final free = await _readFreeBytes().timeout(const Duration(seconds: 3));
      return free != null && free >= 0 ? free : null;
    } catch (_) {
      // Unavailable disk measurements never invent a zero-byte volume.
      return null;
    }
  }

  static Future<int?> _readPlatformFreeBytes() =>
      _capacity.invokeMethod<int>('availableBytes');

  @override
  void dispose() {
    _disposed = true;
    if (_started != null) WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
