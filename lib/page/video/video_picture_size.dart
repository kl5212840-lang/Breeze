import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';

Map<VideoPictureSize, String> videoPictureSizeLabels() => {
  VideoPictureSize.fit: t.videoPlayback.pictureFit,
  VideoPictureSize.stretch: t.videoPlayback.pictureStretch,
  VideoPictureSize.fill: t.videoPlayback.pictureFill,
  VideoPictureSize.wide: '16:9',
  VideoPictureSize.standard: '4:3',
};

/// Fits only the media surface within the player's unchanged viewport.
class VideoPictureFrame extends StatelessWidget {
  const VideoPictureFrame({
    super.key,
    required this.size,
    required this.mediaSize,
    required this.child,
  });

  final VideoPictureSize size;
  final Size mediaSize;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = switch (size) {
        VideoPictureSize.wide => 16 / 9,
        VideoPictureSize.standard => 4 / 3,
        _ => null,
      };
      final viewport = constraints.biggest;
      final width = ratio == null
          ? viewport.width
          : math.min(viewport.width, viewport.height * ratio);
      return Center(
        child: SizedBox(
          width: width,
          height: ratio == null ? viewport.height : width / ratio,
          child: FittedBox(
            fit: switch (size) {
              VideoPictureSize.fit => BoxFit.contain,
              VideoPictureSize.fill => BoxFit.cover,
              _ => BoxFit.fill,
            },
            clipBehavior: Clip.hardEdge,
            child: SizedBox.fromSize(size: mediaSize, child: child),
          ),
        ),
      );
    },
  );
}
