import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise shared_preferences' actual backing-store failure contract.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/type/enum.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _BlockedPreferences extends InMemorySharedPreferencesStore {
  _BlockedPreferences() : super.empty();
  final firstWrite = Completer<void>();
  bool _first = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_first) {
      _first = false;
      await firstWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

class _Texture extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < size.height; y++) {
      for (var x = 0; x < size.width; x++) {
        paint.color = Color.fromARGB(
          255,
          (x * 73 + y * 19) % 256,
          (x * 31 + y * 37) % 256,
          (x * 11 + y * 53) % 256,
        );
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Texture oldDelegate) => false;
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('cover-pixels')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

int _difference(Uint8List data, int a, int b) =>
    (data[a] - data[b]).abs() +
    (data[a + 1] - data[b + 1]).abs() +
    (data[a + 2] - data[b + 2]).abs();

void main() {
  final controller = CollectionCoverPrivacyController.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller.state.value = const CollectionCoverPrivacySettings();
    controller.localImagePath.value = null;
  });
  tearDown(() {
    controller.state.value = const CollectionCoverPrivacySettings();
    controller.localImagePath.value = null;
  });

  test(
    'local switch and synced style persist separately without an image path',
    () async {
      await controller.ensureLoaded();
      expect(
        controller.state.value,
        const CollectionCoverPrivacySettings(ready: true),
      );
      await controller.setEnabled(true);
      await controller.setStyle(CollectionCoverStyle.glass);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(CollectionCoverPrivacyController.enabledKey),
        isTrue,
      );
      expect(
        preferences.getString(CollectionCoverPrivacyController.styleKey),
        'glass',
      );
      expect(preferences.getKeys(), {
        CollectionCoverPrivacyController.enabledKey,
        CollectionCoverPrivacyController.styleKey,
      });
      await preferences.setString(
        CollectionCoverPrivacyController.styleKey,
        'mosaic',
      );
      await controller.reloadStyle();
      expect(controller.state.value.enabled, isTrue);
      expect(controller.state.value.style, CollectionCoverStyle.mosaic);
    },
  );

  test('failed preference writes keep original covers protected', () async {
    await controller.ensureLoaded();
    final previous = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _FailingPreferences();
    try {
      await expectLater(controller.setEnabled(true), throwsStateError);
      expect(controller.state.value.enabled, isTrue);
      await expectLater(controller.setEnabled(false), throwsStateError);
      expect(controller.state.value.enabled, isTrue);
    } finally {
      SharedPreferencesStorePlatform.instance = previous;
    }
  });

  test(
    'a later enable prevents an earlier pending disable from exposing covers',
    () async {
      await controller.ensureLoaded();
      controller.state.value = const CollectionCoverPrivacySettings(
        enabled: true,
        ready: true,
      );
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _BlockedPreferences();
      SharedPreferencesStorePlatform.instance = store;
      final values = <bool>[];
      void changed() => values.add(controller.state.value.enabled);
      controller.state.addListener(changed);
      try {
        final disable = controller.setEnabled(false);
        final enable = controller.setEnabled(true);
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.value.enabled, isTrue);
        store.firstWrite.complete();
        await Future.wait([disable, enable]);
        expect(values, isNot(contains(false)));
        expect(controller.state.value.enabled, isTrue);
      } finally {
        controller.state.removeListener(changed);
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );

  testWidgets(
    'one button exposes a 44pt toggle and persists the requested switch',
    (tester) async {
      controller.state.value = const CollectionCoverPrivacySettings(
        enabled: true,
        ready: true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: CollectionCoverPrivacyButton())),
        ),
      );
      expect(
        tester.getSize(find.byType(CollectionCoverPrivacyButton)),
        const Size(44, 44),
      );
      await tester.tap(find.byType(CollectionCoverPrivacyButton));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(controller.state.value.enabled, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          CollectionCoverPrivacyController.enabledKey,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'only collection scope opts in and unready never paints the original directly',
    (tester) async {
      Future<void> mount(bool? scope) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: scope == null
                ? const CollectionCoverPrivacy(
                    child: SizedBox(width: 96, height: 144),
                  )
                : CollectionCoverPrivacyScope(
                    enabled: scope,
                    child: const CollectionCoverPrivacy(
                      child: SizedBox(width: 96, height: 144),
                    ),
                  ),
          ),
        ),
      );
      await mount(null);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsNothing,
      );
      await mount(false);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsNothing,
      );
      await mount(true);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(CollectionCoverPrivacy)),
        const Size(96, 144),
      );
      controller.state.value = const CollectionCoverPrivacySettings(
        ready: true,
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'opaque replacement skips painting the original without unmounting it',
    (tester) async {
      controller.state.value = const CollectionCoverPrivacySettings(
        ready: true,
        enabled: true,
        style: CollectionCoverStyle.custom,
      );
      controller.localImagePath.value = '/missing-replacement.png';
      var paints = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: CollectionCoverPrivacyScope(
              child: CollectionCoverPrivacy(
                child: CustomPaint(
                  size: const Size(88, 132),
                  painter: _PaintCounter(() => paints++),
                ),
              ),
            ),
          ),
        ),
      );
      final original = tester.renderObject(find.byType(CustomPaint).last);
      expect(paints, 0);
      expect(
        tester.getSize(find.byType(CollectionCoverPrivacy)),
        const Size(88, 132),
      );

      controller.state.value = const CollectionCoverPrivacySettings(
        ready: true,
      );
      await tester.pump();
      expect(
        tester.renderObject(find.byType(CustomPaint).last),
        same(original),
      );
      expect(paints, greaterThan(0));
    },
  );

  testWidgets(
    'a warm replacement is painted on the first frame after remounting a comic cover',
    (tester) async {
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(connectivity, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(connectivity, null));
      final dir = Directory.systemTemp.createTempSync('protected-cover-');
      final file = File('${dir.path}/replacement.png');
      final visibility = VisibilityDetectorController.instance;
      final interval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      addTearDown(() async {
        visibility.updateInterval = interval;
        await dir.delete(recursive: true);
      });
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(6, 9);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = ResizeImage(
        FileImage(file),
        width: 256,
        height: 256,
        policy: ResizeImagePolicy.fit,
      );
      addTearDown(provider.evict);
      final theme = ThemeData.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const SizedBox.expand(key: ValueKey('precache')),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          provider,
          tester.element(find.byKey(const ValueKey('precache'))),
        ),
      );
      controller.state.value = const CollectionCoverPrivacySettings(
        enabled: true,
        ready: true,
        style: CollectionCoverStyle.custom,
      );
      controller.localImagePath.value = file.path;
      Future<void> mount(bool grid) async {
        const cover = CoverWidget(
          fileServer: 'https://example.test',
          path: '/pending.png',
          id: 'work',
          pictureType: PictureType.comic,
          from: 'test',
          width: 80,
          height: 120,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: TickerMode(
              enabled: false,
              child: Center(
                child: RepaintBoundary(
                  key: const ValueKey('cover-pixels'),
                  child: CollectionCoverPrivacyScope(
                    child: grid
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [cover],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [cover],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // The original remains unresolved in both layouts.
      await mount(false);
      final firstState = tester.state(find.byType(CoverWidget));
      await mount(true);
      expect(tester.state(find.byType(CoverWidget)), isNot(same(firstState)));
      final bytes = await _pixels(tester);
      final center = (60 * 80 + 40) * 4;
      expect(bytes.sublist(center, center + 4), [255, 0, 0, 255]);

      controller.state.value = const CollectionCoverPrivacySettings(
        ready: true,
      );
      await tester.pump();
      final placeholder = await _pixels(tester);
      final surface = theme.colorScheme.surfaceContainerHigh.toARGB32();
      final sample = (12 * 80 + 12) * 4;
      expect(placeholder.sublist(sample, sample + 4), [
        (surface >> 16) & 255,
        (surface >> 8) & 255,
        surface & 255,
        255,
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final styleName in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(96, 144), const Size(64, 64)]) {
        testWidgets(
          'effects preserve $styleName ${brightness.name} cover $size and labels/taps',
          (tester) async {
            final style = ValueNotifier(styleName);
            addTearDown(style.dispose);
            var taps = 0;
            final cover = SizedBox.fromSize(
              size: size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const CollectionCoverPrivacyScope(
                        child: CollectionCoverPrivacy(
                          child: ColoredBox(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(top: 4, left: 4, child: Text('Title')),
                ],
              ),
            );
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: style,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: Center(
                      child: GestureDetector(onTap: () => taps++, child: cover),
                    ),
                  ),
                ),
              ),
            );
            for (final effect in CollectionCoverStyle.values) {
              controller.state.value = CollectionCoverPrivacySettings(
                enabled: true,
                style: effect,
                ready: true,
              );
              await tester.pump();
              expect(tester.getSize(find.byType(CollectionCoverPrivacy)), size);
              final label = find.text('Title').evaluate().single;
              var filteredAncestor = false;
              label.visitAncestorElements((element) {
                if (element.widget is ImageFiltered) filteredAncestor = true;
                return true;
              });
              expect(filteredAncestor, isFalse);
              await tester.tap(find.byType(CollectionCoverPrivacy));
            }
            expect(taps, 4);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'mosaic rasterizes coarse sampled pixel blocks rather than drawing a grid',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      controller.state.value = const CollectionCoverPrivacySettings(
        enabled: true,
        style: CollectionCoverStyle.mosaic,
        ready: true,
      );
      final cover = CollectionCoverPrivacyScope(
        child: CollectionCoverPrivacy(
          child: SizedBox.square(
            dimension: 96,
            child: CustomPaint(painter: _Texture()),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: const ValueKey('cover-pixels'),
              child: cover,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = await _pixels(tester);
      expect(data.length, 96 * 96 * 4);
      final blockColors = <String>{};
      for (var by = 0; by < 4; by++) {
        for (var bx = 0; bx < 4; bx++) {
          final base = ((by * 24 + 10) * 96 + bx * 24 + 10) * 4;
          blockColors.add('${data[base]},${data[base + 1]},${data[base + 2]}');
          for (final dy in [5, 10, 16]) {
            for (final dx in [5, 10, 16]) {
              final sample = ((by * 24 + dy) * 96 + bx * 24 + dx) * 4;
              expect(
                _difference(data, base, sample),
                lessThanOrEqualTo(3),
                reason: 'each sampled block must have a uniform interior',
              );
            }
          }
        }
      }
      expect(
        blockColors.length,
        greaterThan(1),
        reason:
            'the sampled image must remain distinct from a flat placeholder',
      );
    },
  );
}
