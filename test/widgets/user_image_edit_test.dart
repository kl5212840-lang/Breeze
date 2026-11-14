import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zephyr/widgets/user_image_edit.dart';

void main() {
  test('crop cannot uncover an edge at any zoom, pan, or aspect ratio', () {
    for (final ratio in [1.0, 2 / 3, 16 / 9]) {
      for (final zoom in [1.0, 2.5, 6.0]) {
        for (final center in [-10.0, 0.0, .5, 1.0, 10.0]) {
          final crop = UserImageCrop(zoom: zoom, centerX: center, centerY: center)
              .bounds(600, 400, ratio);
          expect(crop.x, greaterThanOrEqualTo(0));
          expect(crop.y, greaterThanOrEqualTo(0));
          expect(crop.x + crop.width, lessThanOrEqualTo(600));
          expect(crop.y + crop.height, lessThanOrEqualTo(400));
          expect(crop.width / crop.height, closeTo(ratio, .00001));
        }
      }
    }
  });

  test('crop exports the selected edge rather than a fresh central crop', () {
    final source = img.Image(width: 120, height: 60);
    img.fillRect(source, x1: 0, y1: 0, x2: 59, y2: 59,
      color: img.ColorRgb8(240, 20, 20));
    img.fillRect(source, x1: 60, y1: 0, x2: 119, y2: 59,
      color: img.ColorRgb8(20, 20, 240));
    final bytes = Uint8List.fromList(img.encodePng(source));
    img.Image render(double centerX, {int turns = 0, double ratio = 1}) =>
      img.decodeJpg(exportUserImageCrop({
        'bytes': bytes, 'zoom': 1.0, 'centerX': centerX, 'centerY': .5,
        'quarterTurns': turns, 'aspectRatio': ratio,
      }))!;
    final left = render(0), right = render(1);
    expect(left.width, 60);
    expect(left.height, 60);
    expect(left.getPixel(30, 30).r, greaterThan(200));
    expect(right.getPixel(30, 30).b, greaterThan(200));
    final rotated = render(.5, turns: 1, ratio: .5);
    expect(rotated.width, 60);
    expect(rotated.height, 120);
    expect(rotated.getPixel(30, 15).r, greaterThan(200));
    expect(rotated.getPixel(30, 105).b, greaterThan(200));
    final restored = render(0, turns: 4);
    expect(restored.getPixel(30, 30).r, greaterThan(200));
  });

  test('zoom limits and invalid crop input are bounded', () {
    final zoomed = const UserImageCrop(zoom: 1000).bounds(600, 400, 1);
    expect(zoomed.width, closeTo(400 / 6, .00001));
    final zoomedOut = const UserImageCrop(zoom: .01).bounds(600, 400, 1);
    expect(zoomedOut.width, 400);
    expect(() => const UserImageCrop(zoom: double.nan).bounds(600, 400, 1),
      throwsFormatException);
    expect(() => const UserImageCrop().bounds(600, 400, 0), throwsFormatException);
    expect(() => exportUserImageCrop({
      'bytes': Uint8List(0), 'zoom': 1.0, 'centerX': .5, 'centerY': .5,
      'quarterTurns': 0, 'aspectRatio': 1.0,
    }), throwsFormatException);
  });
}
