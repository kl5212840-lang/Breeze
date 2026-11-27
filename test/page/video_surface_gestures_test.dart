import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:zephyr/page/video/video_surface_gestures.dart';

const _device = MethodChannel('zephyr/video_screen_brightness');
final _surface = find.byType(VideoSurfaceGestures);
final _feedback = find.byKey(const ValueKey('video-landscape-adjustment'));
final _track = find.byKey(const ValueKey('video-adjustment-track'));

Widget _player({
  bool controlsVisible = true,
  bool reduceMotion = false,
  bool fullscreen = true,
  EdgeInsets systemInsets = EdgeInsets.zero,
  VoidCallback? onSeek,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      systemGestureInsets: systemInsets,
    ),
    child: child!,
  ),
  home: Center(
    child: SizedBox(
      width: 600,
      height: fullscreen ? 360 : 220,
      child: VideoSurfaceGestures(
        sessionActive: true,
        enabled: true,
        reversed: false,
        seekEnabled: true,
        fullscreen: fullscreen,
        controlsVisible: controlsVisible,
        onSeekStart: onSeek ?? () => fail('Vertical adjustment became a seek'),
        onSeekUpdate: (_) {},
        onSeekEnd: () {},
        onSeekCancel: () {},
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  ),
);

void _mockDevice(
  WidgetTester tester,
  Future<Object?> Function(MethodCall) handle,
) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_device, handle);
  addTearDown(() => messenger.setMockMethodCallHandler(_device, null));
}

void main() {
  testWidgets(
    'Android leaves media volume applied and restores the player brightness',
    (tester) async {
      final calls = <String>[];
      _mockDevice(tester, (call) async {
        calls.add(call.method);
        if (call.method == 'restore') return null;
        return call.arguments ?? .5;
      });
      await tester.pumpWidget(_player(fullscreen: false));
      final bounds = tester.getRect(_surface);
      final brightness = await tester.startGesture(
        Offset(bounds.left + 150, bounds.center.dy),
      );
      await brightness.moveBy(const Offset(0, -55));
      await tester.pump();
      await brightness.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, containsAllInOrder(['get', 'set']));
      expect(calls, isNot(contains('restore')));

      final volume = await tester.startGesture(
        Offset(bounds.right - 150, bounds.center.dy),
      );
      await volume.moveBy(const Offset(0, -55));
      await tester.pump();
      await volume.up();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls, containsAllInOrder(['getVolume', 'setVolume', 'restore']));
      expect(calls.where((method) => method == 'restore'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a transient brightness write failure keeps the same finger in control',
    (tester) async {
      const device = MethodChannel('zephyr/video_screen_brightness');
      final writes = <double>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(device, (call) async {
        if (call.method == 'get') return .5;
        if (call.method != 'set') fail('Unexpected device call ${call.method}');
        final level = call.arguments as double;
        writes.add(level);
        if (writes.length == 2) throw PlatformException(code: 'unavailable');
        return level;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(device, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 600,
              height: 360,
              child: VideoSurfaceGestures(
                sessionActive: true,
                enabled: true,
                reversed: false,
                seekEnabled: true,
                fullscreen: true,
                controlsVisible: true,
                onSeekStart: () => fail('Vertical adjustment became a seek'),
                onSeekUpdate: (_) {},
                onSeekEnd: () {},
                onSeekCancel: () {},
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      );
      final surface = find.byType(VideoSurfaceGestures);
      final finger = await tester.startGesture(
        tester.getTopLeft(surface) + const Offset(160, 180),
      );
      await finger.moveBy(const Offset(0, -35));
      await tester.pump();
      await finger.moveBy(const Offset(0, -25));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final feedback = find.byKey(const ValueKey('video-landscape-adjustment'));
      expect(
        feedback,
        findsOneWidget,
        reason: 'One missed readback should not hide the HUD',
      );
      await finger.moveBy(const Offset(0, -25));
      await tester.pump();
      expect(writes, orderedEquals([.64, .74, .84]));
      await finger.up();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a slow curved swipe can recover the initial read and ignore a second finger',
    (tester) async {
      final calls = <MethodCall>[];
      _mockDevice(tester, (call) async {
        calls.add(call);
        if (calls.length == 1) throw PlatformException(code: 'unavailable');
        return call.arguments ?? .45;
      });
      await tester.pumpWidget(_player(fullscreen: false));
      final origin = tester.getTopLeft(_surface);
      final finger = await tester.startGesture(origin + const Offset(100, 56));
      await finger.moveBy(const Offset(7, 14));
      await tester.pump();
      expect(calls, isEmpty);
      await finger.moveBy(const Offset(3, 9));
      await tester.pump();
      expect(calls.map((call) => call.method), ['get', 'get', 'set']);
      expect(calls.last.arguments, .31);
      final other = await tester.startGesture(origin + const Offset(440, 70));
      await other.moveBy(const Offset(0, 64));
      await other.up();
      await tester.pump(const Duration(milliseconds: 850));
      expect(calls, hasLength(3));
      expect(_feedback, findsOneWidget);
      await finger.moveBy(const Offset(0, -16));
      await tester.pump();
      expect(calls.last.arguments, .41);
      await finger.up();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'crossing the center and control rows keeps the original side and coalesces writes',
    (tester) async {
      final firstWrite = Completer<double>();
      final writes = <double>[];
      _mockDevice(tester, (call) async {
        if (call.method == 'get') return .5;
        expect(call.method, 'set');
        final level = call.arguments as double;
        writes.add(level);
        return writes.length == 1 ? firstWrite.future : level;
      });
      await tester.pumpWidget(_player());
      final start = tester.getTopLeft(_surface) + const Offset(180, 180);
      final finger = await tester.startGesture(start);
      await finger.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(writes, [.7]);
      await tester.pumpWidget(_player(controlsVisible: false));
      await finger.moveBy(const Offset(240, -124));
      await finger.moveBy(const Offset(0, 38));
      await finger.moveBy(const Offset(8, 22));
      await finger.up();
      expect(writes, [.7]);
      firstWrite.complete(.7);
      await tester.pump();
      // The finger passes the top limit, then reverses from it immediately.
      expect(writes, [.7, .76]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'an interrupted gesture cannot paint or send its queued level after a new touch',
    (tester) async {
      final write = Completer<double>();
      final calls = <String>[];
      _mockDevice(tester, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'get' => .5,
          'set' => write.future,
          'getVolume' => .35,
          _ => call.arguments,
        };
      });
      await tester.pumpWidget(_player());
      final origin = tester.getTopLeft(_surface);
      final left = await tester.startGesture(origin + const Offset(150, 190));
      await left.moveBy(const Offset(0, -40));
      await tester.pump();
      await left.moveBy(const Offset(0, -45));
      await left.cancel();
      final right = await tester.startGesture(origin + const Offset(450, 190));
      await right.moveBy(const Offset(0, 44));
      await tester.pump();
      expect(calls, ['get', 'set']);
      write.complete(.66);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['get', 'set', 'getVolume', 'setVolume']);
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      await right.up();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'system edges, control rows and the middle reserve their hit areas',
    (tester) async {
      final calls = <String>[];
      var seeks = 0;
      _mockDevice(tester, (call) async {
        calls.add(call.method);
        return call.arguments ?? .5;
      });
      await tester.pumpWidget(
        _player(
          fullscreen: false,
          systemInsets: const EdgeInsets.only(left: 28, right: 28),
          onSeek: () => seeks++,
        ),
      );
      final origin = tester.getTopLeft(_surface);
      for (final start in [
        const Offset(20, 70),
        const Offset(581, 70),
        const Offset(90, 35),
        const Offset(90, 173),
        const Offset(302, 85),
      ]) {
        await tester.dragFrom(origin + start, const Offset(0, 44));
        await tester.pump();
      }
      expect(calls, isEmpty);
      expect(seeks, 0);
      final finger = await tester.startGesture(origin + const Offset(34, 56));
      await finger.moveBy(const Offset(0, 44));
      await tester.pump();
      expect(calls, ['get', 'set']);
      await finger.up();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'unsupported device adjustment keeps its axis without showing a fake level',
    (tester) async {
      final calls = <String>[];
      _mockDevice(tester, (call) async {
        calls.add(call.method);
        throw PlatformException(code: 'unsupported');
      });
      await tester.pumpWidget(_player());
      final origin = tester.getTopLeft(_surface);
      final finger = await tester.startGesture(origin + const Offset(160, 120));
      await finger.moveBy(const Offset(0, 45));
      await tester.pump();
      await finger.moveBy(const Offset(230, 25));
      await finger.moveBy(const Offset(0, 30));
      await finger.up();
      await tester.pumpAndSettle();
      expect(calls, ['get']);
      expect(_feedback, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'the bar stretches at the limit and relaxes on release (reduce motion: $reduceMotion)',
      (tester) async {
        _mockDevice(tester, (call) async => call.arguments ?? .7);
        await tester.pumpWidget(_player(reduceMotion: reduceMotion));
        final origin = tester.getTopLeft(_surface);
        final finger = await tester.startGesture(
          origin + const Offset(175, 180),
        );
        await finger.moveBy(const Offset(0, -35));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        expect(tester.getSize(_track).height, reduceMotion ? 4 : 5.5);
        await finger.moveBy(const Offset(0, -80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        final stretch = tester.getSize(_track).height;
        expect(stretch, reduceMotion ? 4 : inExclusiveRange(5.5, 7));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getSize(_track).height, reduceMotion ? 4 : 7);
        await finger.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));
        expect(tester.getSize(_track).height, 4);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        expect(_feedback, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final seekEnabled in [false, true]) {
    testWidgets(
      seekEnabled
          ? 'a disabled adjustment cannot claim a horizontal seek'
          : 'a disabled seek cannot claim a vertical adjustment',
      (tester) async {
        const brightnessChannel = MethodChannel(
          'zephyr/video_screen_brightness',
        );
        final actions = <String>{};
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(brightnessChannel, (call) async {
          if (call.method == 'get') return .5;
          if (call.method == 'set') {
            actions.add('brightness');
            return call.arguments;
          }
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(brightnessChannel, null),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 600,
                height: 360,
                child: VideoSurfaceGestures(
                  sessionActive: !seekEnabled,
                  enabled: !seekEnabled,
                  reversed: false,
                  seekEnabled: seekEnabled,
                  fullscreen: true,
                  controlsVisible: true,
                  onSeekStart: () => actions.add('seek'),
                  onSeekUpdate: (_) {},
                  onSeekEnd: () {},
                  onSeekCancel: () {},
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        );
        final surface = find.byType(VideoSurfaceGestures);
        final gesture = await tester.startGesture(
          tester.getTopLeft(surface) + const Offset(170, 170),
        );
        await gesture.moveBy(
          seekEnabled ? const Offset(4, -32) : const Offset(32, -4),
        );
        await gesture.moveBy(
          seekEnabled ? const Offset(110, 0) : const Offset(0, -110),
        );
        await gesture.up();
        await tester.pump();

        expect(actions, {seekEnabled ? 'seek' : 'brightness'});
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final direction in [-1.0, 1.0]) {
    testWidgets(
      'system volume stops at the limit and reverses promptly ($direction)',
      (tester) async {
        const device = MethodChannel('zephyr/video_screen_brightness');
        final nativeReads = Completer<double>();
        final writes = <double>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(device, (call) async {
          if (call.method == 'getVolume') return nativeReads.future;
          if (call.method != 'setVolume') return null;
          final requested = call.arguments as double;
          writes.add(requested);
          return (requested * 10).round() / 10;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(device, null));
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 600,
                height: 360,
                child: VideoSurfaceGestures(
                  sessionActive: true,
                  enabled: true,
                  reversed: false,
                  seekEnabled: true,
                  fullscreen: true,
                  controlsVisible: true,
                  onSeekStart: () => fail('A vertical drag must not seek'),
                  onSeekUpdate: (_) {},
                  onSeekEnd: () {},
                  onSeekCancel: () {},
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        );
        final start =
            tester.getTopLeft(find.byType(VideoSurfaceGestures)) +
            const Offset(420, 160);
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(Offset(0, direction * 100));
        await gesture.moveBy(Offset(0, direction * 100));
        // Reverse before the first native read is back. A cumulative delta
        // would leave the adjustment pinned even while reversing.
        await gesture.moveBy(Offset(0, -direction * 35));
        nativeReads.complete(direction < 0 ? .85 : .15);
        await tester.pump();
        expect(writes.single, direction < 0 ? .86 : .14);
        await tester.pump();
        final hud = find.byKey(const ValueKey('video-landscape-adjustment'));
        final track = find.descendant(
          of: hud,
          matching: find.byType(material_ui.LinearProgressIndicator),
        );
        expect(
          tester.widget<material_ui.LinearProgressIndicator>(track).value,
          direction < 0 ? .9 : .1,
        );
        expect(
          tester.getCenter(hud),
          tester.getCenter(find.byType(VideoSurfaceGestures)),
        );
        await gesture.moveBy(Offset(0, direction * 50));
        await tester.pump();
        expect(writes.last, direction < 0 ? 1 : 0);
        final writesAtLimit = writes.length;
        await gesture.moveBy(Offset(0, direction * 50));
        await tester.pump();
        expect(writes, hasLength(writesAtLimit));
        await gesture.moveBy(Offset(0, -direction * 30));
        await tester.pump();
        expect(writes.last, direction < 0 ? .88 : .12);
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 140));
        expect(hud, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
