import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/picture_bloc/picture_bloc.dart';

/// 发现页和插件商店共用的图标，按 URL 缓存，不依赖插件是否已安装。
class PluginIcon extends StatefulWidget {
  const PluginIcon({super.key, required this.url, required this.placeholder});

  final String url;
  final Widget placeholder;

  @override
  State<PluginIcon> createState() => _PluginIconState();
}

class _PluginIconState extends State<PluginIcon> {
  Uint8List? _embedded;

  void _readEmbedded() {
    _embedded = null;
    final url = widget.url.trim();
    // Single-file plugins can carry a small icon without an external image host.
    if (!url.startsWith('data:image/png;base64,') || url.length > 350000) {
      return;
    }
    try {
      final bytes = base64Decode(url.substring(22));
      if (bytes.length < 33 || bytes.length > 262144) return;
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i] != signature[i]) return;
      }
      final header = ByteData.sublistView(bytes);
      final width = header.getUint32(16), height = header.getUint32(20);
      if (width < 1 || height < 1 || width > 1024 || height > 1024) return;
      _embedded = bytes;
    } on FormatException {
      // Invalid metadata keeps the existing placeholder; never request a data URL.
    }
  }

  @override
  void initState() {
    super.initState();
    _readEmbedded();
  }

  @override
  void didUpdateWidget(covariant PluginIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _readEmbedded();
  }

  @override
  Widget build(BuildContext context) {
    final iconUrl = widget.url.trim();
    if (_embedded case final bytes?) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }
    if (iconUrl.isEmpty || iconUrl.startsWith('data:')) {
      return widget.placeholder;
    }

    final pictureInfo = PictureInfo(
      from: 'plugin_icons',
      url: iconUrl,
      path: sha256.convert(utf8.encode(iconUrl)).toString(),
      pictureType: PictureType.avatar,
    );

    return BlocProvider(
      key: ValueKey(iconUrl),
      create: (_) =>
          PictureBloc()..add(GetPicture(pictureInfo, usePlugin: false)),
      child: BlocBuilder<PictureBloc, PictureLoadState>(
        builder: (context, state) {
          switch (state.status) {
            case PictureLoadStatus.initial:
            case PictureLoadStatus.failure:
              return widget.placeholder;
            case PictureLoadStatus.success:
              return Image.file(
                File(state.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => widget.placeholder,
              );
          }
        },
      ),
    );
  }
}
