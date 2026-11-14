import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

import '../ui_preview_helper.dart';

// Flutter checks foundation variables before package:test tearDown runs.
// Restore the override inside the test callback, including assertion failures.
void _iosHostTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

// Engine codecs, file I/O and isolate replies need the real event loop. Fake
// pumpAndSettle advances virtual frames and can starve these completions while
// an intentional loading indicator is animating.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  expect(ready(), isTrue, reason: reason);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  final nativeByTooltip = <String, MethodChannel>{};
  const captureKey = ValueKey('image-editor-preview');
  setUpAll(loadUiPreviewFonts);
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (update) async {
          if (update.method == 'update' && update.arguments is Map) {
            final tooltip = (update.arguments as Map)['tooltip'];
            if (tooltip is String) nativeByTooltip[tooltip] = channel;
          }
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
    nativeByTooltip.clear();
  });
  Future<void> pressAction(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    final action = tester.widget<NativeVideoIconButton>(finder);
    expect(action.onPressed, isNotNull);
    if (find
        .descendant(of: finder, matching: find.byType(UiKitView))
        .evaluate()
        .isEmpty) {
      await tester.tap(finder);
    } else {
      final channel = nativeByTooltip[action.tooltip];
      expect(channel, isNotNull, reason: 'ready native navigation action');
      await messenger.handlePlatformMessage(
        channel!.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
    }
    await tester.pump();
  }

  final pattern = img.Image(width: 80, height: 120);
  img.fillRect(
    pattern,
    x1: 0,
    y1: 0,
    x2: 39,
    y2: 119,
    color: img.ColorRgb8(60, 100, 180),
  );
  img.fillRect(
    pattern,
    x1: 40,
    y1: 0,
    x2: 79,
    y2: 119,
    color: img.ColorRgb8(220, 160, 60),
  );
  final prepared = Uint8List.fromList(img.encodePng(pattern));
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'preview cancel writes nothing: $style $brightness large text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final notifier = ValueNotifier(style);
          final textScale = ValueNotifier(2.0);
          addTearDown(notifier.dispose);
          addTearDown(textScale.dispose);
          var writes = 0;
          var prepares = 0;
          String? result = 'pending';
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: notifier,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  builder: (context, scale, _) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(key: captureKey, child: child!),
                  ),
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await pickLocalAppearanceImage(
                          context,
                          imageKey: 'collection-cover',
                          title: t.coverPrivacy.customImage,
                          pickBytes: () async => Uint8List.fromList([1, 2, 3]),
                          prepare: (_) async {
                            prepares++;
                            return prepared;
                          },
                          save: (_, _) async {
                            writes++;
                            return 'saved';
                          },
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await _pumpUntil(
            tester,
            () =>
                find
                    .byKey(const ValueKey('image-editor-confirm'))
                    .evaluate()
                    .isNotEmpty &&
                tester
                        .widget<NativeVideoIconButton>(
                          find.byKey(const ValueKey('image-editor-confirm')),
                        )
                        .onPressed !=
                    null,
            'editor codec becomes ready',
          );
          expect(prepares, 1);
          expect(writes, 0);
          expect(find.byType(Image), findsOneWidget);
          final image = tester.widget<Image>(find.byType(Image));
          expect((image.image as MemoryImage).bytes, same(prepared));
          expect(image.fit, BoxFit.fill);
          expect(find.byType(Slider), findsNothing);
          final viewport = find.byKey(
            const ValueKey('user-image-crop-viewport'),
          );
          final size = tester.getSize(viewport);
          expect(size.width / size.height, closeTo(2 / 3, .001));
          final cancel = find.byKey(const ValueKey('image-editor-cancel'));
          final cancelRect = tester.getRect(cancel);
          final confirm = find.byKey(const ValueKey('image-editor-confirm'));
          expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(confirm).height, greaterThanOrEqualTo(44));
          expect(tester.getRect(confirm).right, lessThanOrEqualTo(320));
          final beforeZoom = tester.getRect(find.byType(Image));
          final center = tester.getCenter(viewport);
          final firstFinger = await tester.startGesture(
            center - const Offset(20, 0),
            pointer: 7,
          );
          final secondFinger = await tester.startGesture(
            center + const Offset(20, 0),
            pointer: 8,
          );
          await tester.pump(const Duration(milliseconds: 16));
          await firstFinger.moveTo(center - const Offset(45, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await secondFinger.moveTo(center + const Offset(45, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await firstFinger.moveTo(center - const Offset(65, 0));
          await secondFinger.moveTo(center + const Offset(65, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await secondFinger.up();
          await firstFinger.up();
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byType(Image)).width,
            greaterThan(beforeZoom.width),
            reason: 'two-finger pinch zooms the image',
          );
          final beforePan = tester.getRect(find.byType(Image));
          // Scale recognizers accept a one-finger pan after 36pt. The short
          // tester.drag helper only sent two moves, with its last move starting
          // the gesture; include subsequent frames that actually move the crop.
          final pan = await tester.startGesture(tester.getCenter(viewport));
          await pan.moveBy(const Offset(40, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await pan.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await pan.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await pan.up();
          await tester.pumpAndSettle();
          final afterPan = tester.getRect(find.byType(Image));
          final frame = tester.getRect(viewport);
          expect(
            afterPan.left,
            greaterThan(beforePan.left),
            reason: 'dragging still changes the selected image region',
          );
          expect(afterPan.left, lessThanOrEqualTo(frame.left));
          expect(afterPan.right, greaterThanOrEqualTo(frame.right));
          expect(afterPan.top, lessThanOrEqualTo(frame.top));
          expect(afterPan.bottom, greaterThanOrEqualTo(frame.bottom));
          await tester.ensureVisible(find.text(t.imageEditor.rotate));
          await tester.tap(find.text(t.imageEditor.rotate));
          await tester.pumpAndSettle();
          expect(
            tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
            1,
          );
          await tester.tap(find.text(t.imageEditor.reset));
          await tester.pumpAndSettle();
          expect(
            tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
            0,
          );
          expect(writes, 0);
          expect(
            tester.getRect(cancel),
            cancelRect,
            reason: 'navigation stays available while the tools scroll',
          );
          await tester.ensureVisible(viewport);
          await tester.pumpAndSettle();
          await tester.drag(viewport, const Offset(400, 400));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(viewport).width / tester.getSize(viewport).height,
            closeTo(2 / 3, .001),
          );
          await writeUiPreview(
            tester,
            captureKey,
            'image-editor-$style-${brightness.name}-large-text',
          );
          tester.view.physicalSize = const Size(430, 932);
          textScale.value = 1;
          await tester.pumpAndSettle();
          expect(
            tester.getSize(viewport).width / tester.getSize(viewport).height,
            closeTo(2 / 3, .001),
            reason: 'resizing keeps the role-specific crop',
          );
          await writeUiPreview(
            tester,
            captureKey,
            'image-editor-$style-${brightness.name}-standard',
          );
          expect(tester.takeException(), isNull);
          await pressAction(tester, 'image-editor-cancel');
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(writes, 0);
        },
      );
    }
  }

  for (final stale in [false, true]) {
    _iosHostTest('confirmation commits only current host, stale=$stale', (
      tester,
    ) async {
      var valid = true;
      var writes = 0;
      String? result;
      final completed = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await pickLocalAppearanceImage(
                    context,
                    imageKey: 'profile:e9f18928-3ba8-4d86-a12e-b53a62f47933',
                    title: t.coverPrivacy.wallpaper,
                    aspectRatio: 16 / 9,
                    canCommit: () => valid,
                    pickBytes: () async => prepared,
                    prepare: (bytes) async => bytes,
                    save: (key, bytes) async {
                      expect(key, startsWith('profile:'));
                      final result = img.decodeJpg(bytes)!;
                      expect(
                        result.width / result.height,
                        closeTo(16 / 9, .05),
                      );
                      writes++;
                      return 'saved';
                    },
                  );
                  completed.complete();
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(const ValueKey('image-editor-confirm'))
                .evaluate()
                .isNotEmpty &&
            tester
                    .widget<NativeVideoIconButton>(
                      find.byKey(const ValueKey('image-editor-confirm')),
                    )
                    .onPressed !=
                null,
        'editor codec becomes ready',
      );
      expect(writes, 0);
      valid = !stale;
      await pressAction(tester, 'image-editor-confirm');
      await _pumpUntil(
        tester,
        () => completed.isCompleted,
        'crop export and current-host commit complete',
      );
      expect(writes, stale ? 0 : 1);
      expect(result, stale ? isNull : 'saved');
    });
  }

  _iosHostTest('OS picker cancellation never prepares or writes', (
    tester,
  ) async {
    var prepares = 0;
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => pickLocalAppearanceImage(
                context,
                imageKey: 'collection-cover',
                title: 'Cover',
                pickBytes: () async => null,
                prepare: (bytes) async {
                  prepares++;
                  return bytes;
                },
                save: (_, _) async {
                  writes++;
                  return 'saved';
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(prepares, 0);
    expect(writes, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
