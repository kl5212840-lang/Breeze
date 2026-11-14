import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_interaction.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'inline $brightness $size keeps themed bottom and safe controls',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = ThemeData(brightness: brightness);
          final boundaryKey = GlobalKey();
          const insets = EdgeInsets.only(top: 24, bottom: 34);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: RepaintBoundary(
                key: boundaryKey,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    padding: insets,
                    viewPadding: insets,
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: const VideoPageSafeArea(
                    child: ColoredBox(
                      key: ValueKey('safe-content'),
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final content = tester.getRect(
            find.byKey(const ValueKey('safe-content')),
          );
          expect(content.top, 24);
          expect(content.bottom, size.height - 34);
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            Color pixel(int y) {
              final offset = (y * image.width + image.width ~/ 2) * 4;
              return Color.fromARGB(
                pixels.getUint8(offset + 3),
                pixels.getUint8(offset),
                pixels.getUint8(offset + 1),
                pixels.getUint8(offset + 2),
              );
            }

            expect(pixel(0), Colors.black);
            expect(pixel(image.height - 1), theme.colorScheme.surface);
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'fullscreen remains black without reserving top or bottom inset',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: const VideoPageSafeArea(
              fullscreen: true,
              child: SizedBox.expand(key: ValueKey('fullscreen-content')),
            ),
          ),
        ),
      );
      final background = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('video-page.inset-background')),
      );
      expect(background.color, Colors.black);
      expect(
        tester.getRect(find.byKey(const ValueKey('fullscreen-content'))).top,
        0,
      );
      expect(
        find.byKey(const ValueKey('video-page.status-background')),
        findsNothing,
      );
    },
  );
}
