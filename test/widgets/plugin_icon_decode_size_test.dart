import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

void main() {
  final bytes = img.encodePng(img.Image(width: 1024, height: 512));
  final published = 'data:image/png;base64,${base64Encode(bytes)}';
  const uuid = '89f5990d-4ce1-44f1-80f2-6da72f765234';

  Future<void> pumpIcon(
    WidgetTester tester, {
    required Size size,
    required double dpr,
    String? url,
    LocalAppearanceImages? images,
    bool unboundedWidth = false,
  }) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(400 * dpr, 400 * dpr);
    final icon = PluginIcon(
      key: const ValueKey('retained-plugin-icon'),
      url: url ?? published,
      pluginUuid: uuid,
      imageStore: images,
      placeholder: const Text('placeholder'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: unboundedWidth
                ? SizedBox(
                    height: size.height,
                    child: UnconstrainedBox(
                      constrainedAxis: Axis.vertical,
                      child: icon,
                    ),
                  )
                : SizedBox.fromSize(size: size, child: icon),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<Size?> decodedSize(WidgetTester tester, ImageProvider provider) =>
      tester.runAsync(() async {
        final result = Completer<Size>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (info, _) => result.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          ),
          onError: (Object error, StackTrace? stack) =>
              result.completeError(error, stack),
        );
        stream.addListener(listener);
        try {
          return await result.future;
        } finally {
          stream.removeListener(listener);
        }
      });

  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'embedded decode follows icon size and real DPR without distortion',
    (tester) async {
      resetView(tester);
      for (final sample in [
        (size: const Size.square(36), dpr: 1.0, width: 72),
        (size: const Size.square(48), dpr: 3.0, width: 288),
        (size: const Size.square(64), dpr: 2.6, width: 333),
        (size: const Size.square(88), dpr: 3.0, width: 528),
        (size: const Size(80, 40), dpr: 3.0, width: 240),
        (size: const Size(40, 80), dpr: 3.0, width: 480),
        (size: const Size.square(48), dpr: 0.75, width: 96),
      ]) {
        await pumpIcon(tester, size: sample.size, dpr: sample.dpr);
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image as ResizeImage;
        expect(provider.width, sample.width);
        expect(
          provider.height,
          isNull,
          reason: 'one axis preserves source aspect',
        );
        expect(provider.allowUpscaling, isFalse);
        expect(provider.imageProvider, isA<MemoryImage>());
        final decoded = (await decodedSize(tester, provider))!;
        expect(decoded.width, sample.width.toDouble());
        expect(decoded.height, closeTo(sample.width / 2, 1));
        expect(image.fit, BoxFit.cover);
        expect(tester.getSize(find.byType(PluginIcon)), sample.size);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('small sources and unbounded hosts keep the original provider', (
    tester,
  ) async {
    resetView(tester);
    final tiny = img.encodePng(img.Image(width: 16, height: 8));
    await pumpIcon(
      tester,
      size: const Size.square(88),
      dpr: 3,
      url: 'data:image/png;base64,${base64Encode(tiny)}',
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    await pumpIcon(
      tester,
      size: const Size(160, 80),
      dpr: 3,
      unboundedWidth: true,
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('decode keys track size, DPR and custom replacement paths', (
    tester,
  ) async {
    resetView(tester);
    final temporary = Directory.systemTemp.createTempSync(
      'plugin-icon-decode-',
    );
    final images = LocalAppearanceImages(rootDirectory: temporary);
    final key = LocalAppearanceImages.pluginIconKey(uuid)!;
    final a = File('${temporary.path}/a.png')..writeAsBytesSync(bytes);
    final b = File('${temporary.path}/b.png')..writeAsBytesSync(bytes);
    Future<Object> imageKey() => tester
        .widget<Image>(find.byType(Image))
        .image
        .obtainKey(ImageConfiguration.empty);
    try {
      await pumpIcon(
        tester,
        size: const Size.square(48),
        dpr: 2,
        images: images,
      );
      final first = await imageKey();
      await pumpIcon(
        tester,
        size: const Size.square(48),
        dpr: 2,
        images: images,
      );
      expect(
        await imageKey(),
        first,
        reason: 'unrelated rebuild reuses decode key',
      );
      await pumpIcon(
        tester,
        size: const Size.square(48),
        dpr: 3,
        images: images,
      );
      final density = await imageKey();
      expect(density, isNot(first));
      await pumpIcon(
        tester,
        size: const Size.square(88),
        dpr: 3,
        images: images,
      );
      expect(await imageKey(), isNot(density));
      final previousPublishedKey = await imageKey();
      final changed = img.Image(width: 1024, height: 512)
        ..setPixelRgba(0, 0, 255, 0, 0, 255);
      await pumpIcon(
        tester,
        size: const Size.square(88),
        dpr: 3,
        url: 'data:image/png;base64,${base64Encode(img.encodePng(changed))}',
        images: images,
      );
      final publishedKey = await imageKey();
      expect(publishedKey, isNot(previousPublishedKey));

      images.paths.value = {key: a.path};
      await tester.pump();
      final localA =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect((localA.imageProvider as FileImage).file.path, a.path);
      expect(localA.width, 384, reason: 'custom branch is outside this change');
      final localKey = await imageKey();
      images.paths.value = {key: b.path};
      await tester.pump();
      expect(await imageKey(), isNot(localKey));
      images.paths.value = {};
      await tester.pump();
      expect(await imageKey(), publishedKey);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      images.paths.dispose();
      temporary.deleteSync(recursive: true);
    }
  });
}
