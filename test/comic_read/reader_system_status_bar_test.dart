import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/reader/reader_system_ui_service.dart';

void main() {
  testWidgets(
    'status bar mode is independent of the reader menu and restores on exit',
    (tester) async {
      final android = defaultTargetPlatform == TargetPlatform.android;
      const nativeChannel = MethodChannel('system_ui_control');
      final channel = android ? nativeChannel : SystemChannels.platform;
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final service = ReaderSystemUiService.instance;
      final owner = service.acquire();
      await service.applyVisibility(owner, false);
      await service.applyVisibility(owner, false, showStatusBar: true);
      await service.applyVisibility(owner, false, showStatusBar: true);
      await service.applyVisibility(owner, true, showStatusBar: true);
      await service.applyVisibility(owner, false, showStatusBar: true);
      await service.release(owner);

      if (android) {
        expect(calls.map((call) => call.method), [
          'hideSystemBars',
          'hideSystemBars',
          'showSystemBars',
          'hideSystemBars',
          'showSystemBars',
        ]);
        expect(calls[0].arguments, {'showStatusBar': false});
        expect(calls[1].arguments, {'showStatusBar': true});
        expect(calls[3].arguments, {'showStatusBar': true});
      } else {
        expect(calls.map((call) => call.arguments), [
          'SystemUiMode.immersive',
          ['SystemUiOverlay.top'],
          ['SystemUiOverlay.top', 'SystemUiOverlay.bottom'],
          ['SystemUiOverlay.top'],
          ['SystemUiOverlay.top', 'SystemUiOverlay.bottom'],
        ]);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
