import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  for (final styleName in ['system', 'breeze']) {
    testWidgets(
      'refresh shows progress without replacing its button: $styleName',
      (tester) async {
        final busy = ValueNotifier(false), style = ValueNotifier(styleName);
        addTearDown(busy.dispose);
        addTearDown(style.dispose);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final channels = <MethodChannel>[], updates = <Map>[];
        var creates = 0;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            creates++;
            final args = call.arguments as Map;
            final channel = MethodChannel('breeze.video.control.${args['id']}');
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'update') updates.add(call.arguments as Map);
              return null;
            });
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    ValueListenableBuilder<bool>(
                      valueListenable: busy,
                      builder: (_, loading, _) => SourceChromeIconButton(
                        icon: Icons.refresh,
                        symbol: 'arrow.clockwise',
                        tooltip: 'Refresh',
                        busy: loading,
                        onPressed: loading ? null : () => busy.value = true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(SourceChromeIconButton);
        final native = find.byType(UiKitView);
        final initialCreates = creates;
        final nativeState = native.evaluate().isEmpty
            ? null
            : tester.state(native);
        final original = tester.getRect(button);
        busy.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.widget<SourceChromeIconButton>(button).onPressed, isNull);
        expect(tester.getRect(button), original);
        if (styleName == 'system') {
          expect(creates, initialCreates);
          expect(tester.state(native), same(nativeState));
          expect(updates.last['busy'], isTrue);
          expect(updates.last['enabled'], isFalse);
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
        busy.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        if (styleName == 'system') {
          expect(updates.last['busy'], isFalse);
          expect(tester.state(native), same(nativeState));
        } else {
          expect(find.byType(CircularProgressIndicator), findsNothing);
        }
        expect(
          tester.widget<SourceChromeIconButton>(button).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
