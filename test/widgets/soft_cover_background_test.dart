import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';

Future<Uint8List> _greenImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xff00ff00), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'narrow custom artwork conceals red original at every frame edge',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('cover-privacy-pixels-'),
      ))!;
      final file = File('${directory.path}/narrow.png');
      final controller = CollectionCoverPrivacyController.instance;
      final previous = controller.state.value;
      final previousPath = controller.localImagePath.value;
      try {
        await tester.runAsync(() async {
          await file.writeAsBytes(await _greenImage(8, 120));
        });
        // Resolve IO before the image enters the test's fake-async widget zone.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.runAsync(
          () => precacheImage(
            FileImage(file),
            tester.element(find.byType(SizedBox).first),
          ).timeout(const Duration(seconds: 3)),
        );
        controller.state.value = const CollectionCoverPrivacySettings(
          enabled: true,
          ready: true,
          style: CollectionCoverStyle.custom,
        );
        controller.localImagePath.value = file.path;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: const ValueKey('privacy-frame'),
                child: const SizedBox(
                  width: 80,
                  height: 120,
                  child: CollectionCoverPrivacyScope(
                    child: CollectionCoverPrivacy(
                      fit: BoxFit.contain,
                      child: ColoredBox(color: Color(0xffff0000)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('privacy-frame')),
        );
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes!.buffer.asUint8List();
        });
        for (final point in [
          (1, 1),
          (78, 1),
          (1, 60),
          (78, 60),
          (1, 118),
          (78, 118),
        ]) {
          final offset = (point.$2 * 80 + point.$1) * 4;
          expect(
            pixels![offset],
            lessThan(10),
            reason: 'original red must never leak at $point',
          );
          expect(pixels[offset + 1], greaterThan(240));
          expect(pixels[offset + 3], 255);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.state.value = previous;
        controller.localImagePath.value = previousPath;
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    },
  );

  for (final dimensions in [(160, 60), (60, 160)]) {
    testWidgets('contain uses one provider and fixed frame for $dimensions', (
      tester,
    ) async {
      final bytes = await tester.runAsync(
        () => _greenImage(dimensions.$1, dimensions.$2),
      );
      final provider = MemoryImage(bytes!);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              key: const ValueKey('fixed-frame'),
              width: 80,
              height: 120,
              child: SoftCoverBackground(
                image: provider,
                child: Image(image: provider, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('fixed-frame'))),
        const Size(80, 120),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(images.every((image) => identical(image.image, provider)), isTrue);
      expect(
        images.map((image) => image.fit),
        containsAll([BoxFit.cover, BoxFit.contain]),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
