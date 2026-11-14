import 'dart:io';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/service/local_appearance_images.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  );
  Widget icon(String url) => MaterialApp(
    home: PluginIcon(url: url, placeholder: const Text('placeholder')),
  );
  testWidgets(
    'embedded plugin icon renders offline and invalid replacement falls back',
    (tester) async {
      await tester.pumpWidget(
        icon('data:image/png;base64,${base64Encode(bytes)}'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      await tester.pumpWidget(icon('data:image/png;base64,invalid'));
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
  testWidgets('oversized image dimensions are rejected before decoding', (
    tester,
  ) async {
    final altered = Uint8List.fromList(bytes);
    ByteData.sublistView(altered).setUint32(16, 65535);
    await tester.pumpWidget(
      icon('data:image/png;base64,${base64Encode(altered)}'),
    );
    expect(find.text('placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('local image updates only its UUID and does not replace store/author artwork', (tester) async {
    const a = '89f5990d-4ce1-44f1-80f2-6da72f765234', b = '2c24bf10-d5e9-4f80-a2a9-a3e3fdd95bbb';
    final directory = Directory.systemTemp.createTempSync('breeze_plugin_icon_');
    final local = File('${directory.path}/icon.png')..writeAsBytesSync(bytes);
    final images = LocalAppearanceImages(rootDirectory: directory);
    images.paths.value = {LocalAppearanceImages.pluginIconKey(a)!: local.path};
    try {
      final published = 'data:image/png;base64,${base64Encode(bytes)}';
      await tester.pumpWidget(MaterialApp(home: Row(children: [
        SizedBox.square(dimension: 48, child: PluginIcon(url: published, pluginUuid: a.toUpperCase(), imageStore: images, placeholder: const Text('A'))),
        SizedBox.square(dimension: 48, child: PluginIcon(url: published, pluginUuid: b, imageStore: images, placeholder: const Text('B'))),
        SizedBox.square(dimension: 48, child: PluginIcon(url: published, imageStore: images, placeholder: const Text('Published'))),
      ])));
      final rendered = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(rendered, hasLength(3));
      final resized = rendered.first.image as ResizeImage;
      expect((resized.imageProvider as FileImage).file.path, local.path);
      expect(resized.policy, ResizeImagePolicy.fit);
      expect(resized.width, 384);
      expect(rendered[1].image, isA<MemoryImage>());
      expect(rendered[2].image, isA<MemoryImage>());
      images.paths.value = {};
      await tester.pump();
      expect(tester.widgetList<Image>(find.byType(Image)).every((image) => image.image is MemoryImage), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      images.paths.dispose();
      directory.deleteSync(recursive: true);
    }
  });

}
