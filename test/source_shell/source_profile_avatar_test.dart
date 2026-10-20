import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zephyr/page/source_shell/models/source_profile_avatar.dart';

void main() {
  test('prepares a square JPEG avatar from a rectangular image', () {
    final source = img.Image(width: 400, height: 200);
    img.fill(source, color: img.ColorRgb8(236, 135, 177));
    final jpeg = prepareSourceAvatar(Uint8List.fromList(img.encodePng(source)));
    final result = img.decodeImage(jpeg);

    expect(jpeg[0], 0xff);
    expect(jpeg[1], 0xd8);
    expect(result?.width, 200);
    expect(result?.height, 200);
  });

  test('rejects missing or unrecognized image data', () {
    expect(() => prepareSourceAvatar(Uint8List(0)), throwsFormatException);
    expect(
      () => prepareSourceAvatar(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
