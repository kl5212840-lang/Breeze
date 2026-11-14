import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

void main() {
  for (final size in [(400, 100), (100, 400)]) {
    testWidgets('actual cover decoder preserves source ratio $size', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'cover-decode-ratio-',
        );
        ui.Image? decoded;
        try {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.green, BlendMode.src);
          final picture = recorder.endRecording();
          final source = await picture.toImage(size.$1, size.$2);
          final bytes = await source.toByteData(format: ui.ImageByteFormat.png);
          source.dispose();
          picture.dispose();
          final file = await File(
            '${directory.path}/source.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          final provider = createCoverImageProvider(
            file.path,
            width: 96,
            height: 144,
          );
          final stream = provider.resolve(ImageConfiguration.empty);
          final completed = Completer<ui.Image>();
          final listener = ImageStreamListener(
            (info, _) => completed.complete(info.image.clone()),
            onError: (Object error, StackTrace? trace) =>
                completed.completeError(error, trace),
          );
          stream.addListener(listener);
          try {
            decoded = await completed.future;
          } finally {
            stream.removeListener(listener);
          }
          expect(
            decoded.width / decoded.height,
            closeTo(size.$1 / size.$2, .05),
          );
          expect(decoded.width, lessThanOrEqualTo(96));
          expect(decoded.height, lessThanOrEqualTo(144));
          await provider.evict();
        } finally {
          decoded?.dispose();
          await directory.delete(recursive: true);
        }
      });
    });
  }
}
