import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Device-local launcher preference, read from the native host.
class AppIconController extends ChangeNotifier with WidgetsBindingObserver {
  AppIconController({
    MethodChannel channel = const MethodChannel('breeze.appearance.app_icon'),
    bool? isIOS,
    bool? isAndroid,
  }) : _channel = channel,
       isIOS =
           isIOS ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
       isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static final instance = AppIconController();
  static const classicName = 'AppIconClassic';
  final MethodChannel _channel;
  final bool isIOS;
  final bool isAndroid;
  bool get _hasNativeIcon => isIOS || isAndroid;
  bool supported = false, ready = false, changing = false, failed = false;
  String iconName = '';
  // System interface appearance; not a claim about Home Screen tint/clear.
  String previewAppearance = 'light';
  Uint8List? preview;
  Future<void>? _initialRead, _refreshInFlight;
  Timer? _appearanceRefresh;
  bool _refreshPending = false;
  bool _observing = false, _disposed = false;
  int _revision = 0;

  Future<void> ensureLoaded() {
    if (!_hasNativeIcon || _disposed) return Future.value();
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    return _initialRead ??= refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestAppearanceRefresh();
  }

  @override
  void didChangePlatformBrightness() => _requestAppearanceRefresh();

  void _requestAppearanceRefresh() {
    if (_disposed || !_hasNativeIcon) return;
    // Resume and platform-brightness notifications can arrive together.
    _appearanceRefresh ??= Timer(Duration.zero, () {
      _appearanceRefresh = null;
      if (changing || _refreshInFlight != null) {
        _refreshPending = true;
      } else {
        unawaited(refresh());
      }
    });
  }

  void _accept(Map<Object?, Object?> status) {
    supported = status['supported'] == true;
    iconName = status['iconName'] as String? ?? '';
    previewAppearance = status['previewAppearance'] == 'dark'
        ? 'dark'
        : 'light';
    preview = status['preview'] as Uint8List?;
    ready = true;
  }

  Future<void> refresh() {
    if (!_hasNativeIcon || _disposed || changing) return Future.value();
    return _refreshInFlight ??= _readStatus().whenComplete(() {
      _refreshInFlight = null;
      if (_refreshPending && !_disposed && !changing) {
        _refreshPending = false;
        _requestAppearanceRefresh();
      }
    });
  }

  Future<void> _readStatus() async {
    final revision = ++_revision;
    try {
      final status = await _channel.invokeMapMethod<Object?, Object?>('status');
      if (_disposed || changing || revision != _revision || status == null)
        return;
      _accept(status);
      failed = false;
      notifyListeners();
    } on PlatformException {
      // Preserve the last confirmed system state.
    } on MissingPluginException {
      // The native host can be older than the Flutter interface.
    }
  }

  Future<bool> select(String name) async {
    if (_disposed ||
        !supported ||
        changing ||
        (name.isNotEmpty && name != classicName))
      return false;
    if (name == iconName) return true;
    ++_revision; // A status read started before this write cannot overwrite it.
    changing = true;
    failed = false;
    notifyListeners();
    try {
      final status = await _channel.invokeMapMethod<Object?, Object?>(
        'select',
        name,
      );
      if (_disposed) return false;
      final success =
          status != null &&
          status['failed'] == false &&
          (status['iconName'] as String? ?? '') == name;
      if (status != null && success) _accept(status);
      failed = !success;
      return success;
    } on PlatformException {
      if (!_disposed) failed = true;
      return false;
    } on MissingPluginException {
      if (!_disposed) failed = true;
      return false;
    } finally {
      if (!_disposed) {
        changing = false;
        notifyListeners();
        if (_refreshPending) {
          _refreshPending = false;
          _requestAppearanceRefresh();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _appearanceRefresh?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
