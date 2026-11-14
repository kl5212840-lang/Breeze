import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

enum VideoPanelPurpose { controls, speed, sources, episodes, download }

/// A sidebar is sized for its task, rather than a fixed share of the movie.
double videoSidePanelWidth(
  BuildContext context,
  BoxConstraints bounds, {
  VideoPanelPurpose purpose = VideoPanelPurpose.controls,
  Iterable<String> labels = const [],
}) {
  final media = MediaQuery.of(context);
  final scale = math.max(1.0, media.textScaler.scale(17) / 17);
  final base = switch (purpose) {
    VideoPanelPurpose.speed => 160.0,
    VideoPanelPurpose.sources => 250.0,
    VideoPanelPurpose.episodes => 300.0,
    VideoPanelPurpose.controls => 330.0,
    VideoPanelPurpose.download => 350.0,
  };
  var contentWidth = base * scale;
  for (final label in labels) {
    final text = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 17)),
      textDirection: Directionality.of(context),
      textScaler: media.textScaler,
    )..layout();
    contentWidth = math.max(
      contentWidth,
      math.min(text.width + 88, 400 * scale),
    );
    text.dispose();
  }
  // Content avoids the notch. The fade and the modal itself reach the edge.
  final preferred = contentWidth + math.max(12, media.padding.right) + 12;
  return preferred.clamp(
    0.0,
    math.min(bounds.maxWidth, math.max(280, bounds.maxWidth * .56)),
  );
}

ThemeData videoSidePanelTheme(ThemeData base) {
  final dark =
      ColorScheme.fromSeed(
        seedColor: base.colorScheme.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF242428),
        surfaceContainer: const Color(0xFF2B2B30),
        onSurface: const Color(0xFFF5F5F7),
        onSurfaceVariant: const Color(0xFFCECED4),
      );
  return videoReadableTaskTheme(
    base.copyWith(
      brightness: Brightness.dark,
      colorScheme: dark,
      textTheme: base.textTheme.apply(
        bodyColor: dark.onSurface,
        displayColor: dark.onSurface,
      ),
      dividerColor: dark.outlineVariant.withValues(alpha: .35),
    ),
  );
}

/// The movie remains visible between independent control groups. There is no
/// opaque full-height panel behind them; depth comes from this fading layer.
class VideoSidePanelDepth extends StatelessWidget {
  const VideoSidePanelDepth({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final fade = (width * .6).clamp(144.0, 240.0);
    final glass =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        VideoControlAppearance.usesSystem(context) &&
        !MediaQuery.highContrastOf(context) &&
        !context.select<GlobalSettingCubit?, bool>(
          (cubit) => cubit?.state.eInkSetting.enabled ?? false,
        );
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: width + fade,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: DecoratedBox(
            key: const ValueKey('video-panel.side-depth'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                stops: [0, fade / (width + fade), 1],
                colors: [
                  Colors.transparent,
                  glass ? const Color(0x3D000000) : const Color(0xD9000000),
                  glass ? const Color(0x70000000) : const Color(0xE6000000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Each functional block owns its material and keeps the movie visible in
/// the spaces between groups.
class VideoPanelBlock extends StatelessWidget {
  const VideoPanelBlock({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => NativeMaterialSurface(
    systemStyle: VideoControlAppearance.usesSystem(context),
    readableContent: true,
    androidGlass: true,
    radius: 14,
    child: child,
  );
}
