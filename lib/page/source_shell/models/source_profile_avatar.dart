import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The Bika avatar API expects a compact square JPEG, not the original photo.
Uint8List prepareSourceAvatar(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
    throw const FormatException('图片不能超过 12 MB');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('请选择 JPG、PNG 或 WebP 图片');
  }
  final square = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: 200,
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: 85));
}
