import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/app_icon_controller.dart';
import 'package:zephyr/widgets/current_app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.appearance.app_icon.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppIconController controller;
  final pixel = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aJ1kAAAAASUVORK5CYII=',
    ),
  );
  Map<String, Object?> status(String name, {bool failed = false}) => {
    'supported': true,
    'iconName': name,
    'failed': failed,
    'preview': pixel,
  };

  setUp(() => controller = AppIconController(channel: channel, isIOS: true));
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'system selection is authoritative and failed change retains confirmed icon',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'status'
            ? status(AppIconController.classicName)
            : status('', failed: true),
      );
      await controller.ensureLoaded();
      expect(controller.iconName, AppIconController.classicName);
      expect(await controller.select(''), isFalse);
      expect(controller.iconName, AppIconController.classicName);
      expect(controller.failed, isTrue);
      expect(controller.changing, isFalse);
    },
  );

  test(
    'late status read cannot overwrite successful switch and concurrent switch is rejected',
    () async {
      final oldRead = Completer<Map<String, Object?>>();
      final switchResult = Completer<Map<String, Object?>>();
      var reads = 0, writes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'status')
          return ++reads == 1 ? status('') : oldRead.future;
        writes++;
        return switchResult.future;
      });
      await controller.ensureLoaded();
      final refresh = controller.refresh();
      final select = controller.select(AppIconController.classicName);
      expect(controller.iconName, '');
      expect(await controller.select(AppIconController.classicName), isFalse);
      switchResult.complete(status(AppIconController.classicName));
      expect(await select, isTrue);
      oldRead.complete(status(''));
      await refresh;
      expect(controller.iconName, AppIconController.classicName);
      expect(writes, 1);
    },
  );

  test(
    'exception preserves current image and successful primary reset follows actual name',
    () async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'status')
          return status(AppIconController.classicName);
        if (fail) throw PlatformException(code: 'denied');
        return status('');
      });
      await controller.ensureLoaded();
      final before = controller.preview;
      expect(await controller.select(''), isFalse);
      expect(controller.preview, same(before));
      fail = false;
      expect(await controller.select(''), isTrue);
      expect(controller.iconName, '');
      expect(controller.failed, isFalse);
    },
  );

  testWidgets(
    'shared preview keeps project 88pt size and uses device pixel ratio',
    (tester) async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            status(call.method == 'select' ? call.arguments as String : ''),
      );
      await controller.ensureLoaded();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Column(
              children: [
                CurrentAppIcon(controller: controller),
                CurrentAppIcon(size: 28, controller: controller),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CurrentAppIcon).first),
        const Size(88, 88),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect((images.first.image as ResizeImage).width, 264);
      expect((images.last.image as ResizeImage).width, 84);
      expect(await controller.select(AppIconController.classicName), isTrue);
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
    },
  );
  testWidgets(
    'system appearance refresh is independent of the Flutter light theme and coalesces notifications',
    (tester) async {
      var dark = false;
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        reads++;
        return {...status(''), 'previewAppearance': dark ? 'dark' : 'light'};
      });
      await controller.ensureLoaded();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: CurrentAppIcon(controller: controller),
        ),
      );
      expect(controller.previewAppearance, 'light');
      dark = true;
      controller.didChangePlatformBrightness();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      controller.didChangePlatformBrightness();
      await tester.pumpAndSettle();
      expect(controller.previewAppearance, 'dark');
      expect(reads, 2);
      expect(
        Theme.of(tester.element(find.byType(CurrentAppIcon))).brightness,
        Brightness.light,
      );
    },
  );

  testWidgets(
    'notifications during a read schedule at most one follow-up read',
    (tester) async {
      final inFlight = Completer<Map<String, Object?>>();
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        reads++;
        if (reads == 2) return inFlight.future;
        return {
          ...status(''),
          'previewAppearance': reads > 1 ? 'dark' : 'light',
        };
      });
      await controller.ensureLoaded();
      controller.didChangePlatformBrightness();
      // pump() only flushes microtasks; advance fake time to run Timer.zero.
      await tester.pump(const Duration(milliseconds: 1));
      expect(reads, 2);
      for (var i = 0; i < 4; i++) {
        controller.didChangePlatformBrightness();
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }
      // pump() only flushes microtasks; advance fake time to run Timer.zero.
      await tester.pump(const Duration(milliseconds: 1));
      expect(reads, 2);
      inFlight.complete({...status(''), 'previewAppearance': 'dark'});
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(controller.previewAppearance, 'dark');
    },
  );
}
