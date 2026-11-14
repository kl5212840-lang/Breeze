import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String? get uiPreviewDirectory => Platform.environment['BREEZE_UI_PREVIEW_DIR'];

/// Opt-in local render evidence. Ordinary tests stay independent of macOS fonts.
Future<void> loadUiPreviewFonts() async {
  if (uiPreviewDirectory == null) return;
  // A TTC contains regional variants. Loading the collection as one custom
  // font selected HK punctuation, even for these Simplified Chinese previews.
  final loader = FontLoader('AccountPreview');
  for (final face in ['Regular', 'Medium', 'Semibold']) {
    final font = File('build/ui-preview-fonts/PingFangSC-$face.ttf');
    if (!font.existsSync()) {
      throw StateError(
        'Prepare preview faces with script/test/prepare_ui_preview_fonts.py',
      );
    }
    loader.addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  }
  await loader.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw StateError('Set FLUTTER_ROOT to the Flutter SDK for UI previews');
  }
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      ))
      .load();
}

Future<void> writeUiPreview(WidgetTester tester, Key key, String name) async {
  final directory = uiPreviewDirectory;
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = Directory(directory)..createSync(recursive: true);
    File(
      '${output.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
