import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

/// A non-interactive system symbol for Flutter-owned settings and record rows.
/// UIKit draws the glyph once; no native view is inserted in a clipping list.
class InterfaceSymbol extends StatelessWidget {
  const InterfaceSymbol({
    super.key,
    required this.symbol,
    required this.fallback,
    this.size,
    this.color,
  });
  final String symbol;
  final IconData fallback;
  final double? size;
  final Color? color;
  static const _channel = MethodChannel('breeze.interface.symbols');
  static final _images = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> _read(String symbol) async {
    try {
      return await _channel.invokeMethod<Uint8List>('image', symbol);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final extent = size ?? iconTheme.size ?? 24;
    final tint =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    Widget icon() => Icon(fallback, size: extent, color: color);
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !AppInterfaceStyleScope.usesSystem(context)) {
      return icon();
    }
    return SizedBox.square(
      dimension: extent,
      child: FutureBuilder<Uint8List?>(
        key: ValueKey(symbol),
        future: _images.putIfAbsent(symbol, () => _read(symbol)),
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.expand();
          }
          final bytes = snapshot.data;
          if (bytes == null) return icon();
          return Image.memory(
            bytes,
            color: tint,
            colorBlendMode: BlendMode.srcIn,
            excludeFromSemantics: true,
            fit: BoxFit.contain,
          );
        },
      ),
    );
  }
}
