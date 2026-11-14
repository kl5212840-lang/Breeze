import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_read/controller/reader_system_ui_controller.dart';

void main() {
  testWidgets(
    'retiring a reader does not restore bars or cancel its successor sync',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode' ||
            call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
          calls.add(call);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final old = ReaderSystemUiController();
      await old.applyVisibility(false);
      final next = ReaderSystemUiController();
      next.scheduleSync(() => unawaited(next.applyVisibility(false)));

      await old.close();
      await tester.pump(const Duration(milliseconds: 30));
      expect(calls.map((call) => call.method), [
        'SystemChrome.setEnabledSystemUIMode',
        'SystemChrome.setEnabledSystemUIMode',
      ]);
      await next.close();
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIOverlays');
    },
  );
}
