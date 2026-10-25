import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';

/// Site navigation follows the platform independently of player control style.
/// UIKit owns tab semantics and iOS 26 material; other platforms retain the
/// existing Material navigation. No glass is added to the video content layer.
class VideoNativeNavigation extends StatefulWidget {
  const VideoNativeNavigation({
    super.key,
    required this.items,
    required this.symbols,
    required this.currentIndex,
    required this.onTap,
  });
  final List<BottomNavigationBarItem> items;
  final List<String> symbols;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  @override
  State<VideoNativeNavigation> createState() => _VideoNativeNavigationState();
}

class _VideoNativeNavigationState extends State<VideoNativeNavigation> {
  MethodChannel? _channel;
  Map<String, dynamic>? _sent;
  double? _nativeHeight;
  Map<String, dynamic> _arguments(BuildContext context) => {
    'selected': widget.currentIndex,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'enabled': widget.onTap != null,
    'items': [
      for (var i = 0; i < widget.items.length; i++)
        {
          'title': widget.items[i].label ?? '',
          'symbol': widget.symbols.elementAtOrNull(i) ?? 'circle',
        },
    ],
  };
  Future<void> _update(Map<String, dynamic> args) async {
    if (_channel == null ||
        const DeepCollectionEquality().equals(_sent, args)) {
      return;
    }
    _sent = args;
    try {
      await _channel!.invokeMethod<void>('update', args);
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: widget.items,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
      );
    }
    final args = _arguments(context);
    unawaited(_update(args));
    // UIKit's fitting height includes its own bottom accommodation. Wrapping
    // a short native bar in Flutter SafeArea compressed the glass platter and
    // left symbols outside it. Allocate the native height only once.
    return SizedBox(
      height: _nativeHeight ?? 49 + MediaQuery.viewPaddingOf(context).bottom,
      child: UiKitView(
        viewType: 'breeze.video.navigation',
        creationParams: args,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (!mounted) return;
          _channel?.setMethodCallHandler(null);
          _channel = MethodChannel('breeze.video.navigation.$id')
            ..setMethodCallHandler((call) async {
              if (!mounted) return;
              if (call.method == 'height' && call.arguments is num) {
                final height = (call.arguments as num).toDouble();
                if (height.isFinite &&
                    height >= 49 &&
                    height <= 160 &&
                    height != _nativeHeight) {
                  setState(() => _nativeHeight = height);
                }
                return;
              }
              if (call.method != 'select' || call.arguments is! int) {
                return;
              }
              final index = call.arguments as int;
              if (index >= 0 && index < widget.items.length) {
                widget.onTap?.call(index);
              }
            });
          _sent = null;
          unawaited(_update(_arguments(context)));
        },
      ),
    );
  }
}
