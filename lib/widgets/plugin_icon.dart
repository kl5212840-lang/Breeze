import 'dart:async';
import 'package:zephyr/widgets/picture_bloc/picture_recovery_region.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/picture_bloc/picture_bloc.dart';

/// 发现页和插件商店共用的图标，按 URL 缓存，不依赖插件是否已安装。
class PluginIcon extends StatefulWidget {
  const PluginIcon({
    super.key,
    required this.url,
    required this.placeholder,
    this.pluginUuid,
    this.imageStore,
  });

  final String? pluginUuid;
  final LocalAppearanceImages? imageStore;
  final String url;
  final Widget placeholder;

  @override
  State<PluginIcon> createState() => _PluginIconState();
}

class _PluginIconState extends State<PluginIcon> {
  Uint8List? _embedded;
  int _embeddedWidth = 0, _embeddedHeight = 0;

  void _readEmbedded() {
    _embedded = null;
    _embeddedWidth = 0;
    _embeddedHeight = 0;
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
      _embeddedWidth = width;
      _embeddedHeight = height;
    } on FormatException {
      // Invalid metadata keeps the existing placeholder; never request a data URL.
    }
  }

  int? _embeddedCacheWidth(
    BoxConstraints constraints,
    double devicePixelRatio,
  ) {
    if (!constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return null;
    }
    // Cover needs enough pixels on both axes. Constrain only the decode width
    // so non-square artwork keeps its aspect ratio instead of being stretched.
    // At DPR < 1 retain at least logical size under loose image constraints.
    final ratio = devicePixelRatio.isFinite
        ? math.max(1.0, devicePixelRatio)
        : 1.0;
    final scale =
        math.max(
          constraints.maxWidth / _embeddedWidth,
          constraints.maxHeight / _embeddedHeight,
        ) *
        ratio;
    if (scale >= 1) return null;
    return (_embeddedWidth * scale).ceil().clamp(1, _embeddedWidth).toInt();
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
    final store = widget.imageStore ?? LocalAppearanceImages.instance;
    final key = LocalAppearanceImages.pluginIconKey(widget.pluginUuid ?? '');
    if (key == null) return _buildDefault(context);
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: store.paths,
      builder: (context, paths, _) {
        final path = paths[key];
        if (path == null || path.isEmpty) return _buildDefault(context);
        return Image(
          image: ResizeImage(
            FileImage(File(path)),
            width: 384,
            height: 384,
            policy: ResizeImagePolicy.fit,
          ),
          key: ValueKey('plugin-icon.local:$key:$path'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefault(context),
        );
      },
    );
  }

  Widget _buildDefault(BuildContext context) {
    final iconUrl = widget.url.trim();
    if (_embedded case final bytes?) {
      return LayoutBuilder(
        builder: (context, constraints) => Image.memory(
          bytes,
          cacheWidth: _embeddedCacheWidth(
            constraints,
            MediaQuery.devicePixelRatioOf(context),
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => widget.placeholder,
        ),
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
          PictureBloc(initiallyActive: false)
            ..add(GetPicture(pictureInfo, usePlugin: false)),
      child: BlocBuilder<PictureBloc, PictureLoadState>(
        builder: (context, state) {
          return PictureRecoveryRegion(
            bloc: context.read<PictureBloc>(),
            child: Builder(
              builder: (context) {
                switch (state.status) {
                  case PictureLoadStatus.initial:
                  case PictureLoadStatus.failure:
                    return widget.placeholder;
                  case PictureLoadStatus.success:
                    return Image.file(
                      File(state.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, _) {
                        unawaited(
                          context.read<PictureBloc>().reportDecodeFailure(
                            error,
                            imagePath: state.imagePath,
                          ),
                        );
                        return widget.placeholder;
                      },
                    );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
