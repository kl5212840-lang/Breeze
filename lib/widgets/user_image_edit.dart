import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The same geometry drives the viewport and export. Coordinates are relative
/// to the oriented image, so a resized viewport does not change the crop.
class UserImageCrop {
  const UserImageCrop({
    this.zoom = 1,
    this.centerX = .5,
    this.centerY = .5,
    this.quarterTurns = 0,
  });
  final double zoom, centerX, centerY;
  final int quarterTurns;

  ({double x, double y, double width, double height}) bounds(
    double width,
    double height,
    double aspectRatio,
  ) {
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        !zoom.isFinite ||
        !centerX.isFinite ||
        !centerY.isFinite) {
      throw const FormatException('Invalid crop');
    }
    final scale = zoom.clamp(1.0, 6.0).toDouble();
    final cropWidth = math.min(width, height * aspectRatio) / scale;
    final cropHeight = cropWidth / aspectRatio;
    final x = (centerX * width - cropWidth / 2)
        .clamp(0.0, width - cropWidth)
        .toDouble();
    final y = (centerY * height - cropHeight / 2)
        .clamp(0.0, height - cropHeight)
        .toDouble();
    return (x: x, y: y, width: cropWidth, height: cropHeight);
  }
}

/// Input has already passed the bounded decoder and metadata stripping stage.
/// This isolate never decodes original, unbounded photo-library data.
Uint8List exportUserImageCrop(Map<String, Object> request) {
  final bytes = request['bytes'] as Uint8List;
  if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
    throw const FormatException('Invalid prepared image');
  }
  final img.Decoder decoder = bytes[0] == 255
      ? img.JpegDecoder()
      : img.PngDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > 1600 ||
      info.height > 1600) {
    throw const FormatException('Invalid prepared image');
  }
  final image = decoder.decodeFrame(0);
  if (image == null) {
    throw const FormatException('Invalid prepared image');
  }
  final crop = UserImageCrop(
    zoom: request['zoom'] as double,
    centerX: request['centerX'] as double,
    centerY: request['centerY'] as double,
    quarterTurns: request['quarterTurns'] as int,
  );
  final rotated = crop.quarterTurns % 4 == 0
      ? image
      : img.copyRotate(image, angle: (crop.quarterTurns % 4) * 90);
  final bounds = crop.bounds(
    rotated.width.toDouble(),
    rotated.height.toDouble(),
    request['aspectRatio'] as double,
  );
  final x = bounds.x.round().clamp(0, rotated.width - 1).toInt();
  final y = bounds.y.round().clamp(0, rotated.height - 1).toInt();
  final cropped = img.copyCrop(
    rotated,
    x: x,
    y: y,
    width: bounds.width.round().clamp(1, rotated.width - x).toInt(),
    height: bounds.height.round().clamp(1, rotated.height - y).toInt(),
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 88));
}
