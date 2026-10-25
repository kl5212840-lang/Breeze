import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

void main() {
  testWidgets(
    'UIKit action enabled state follows pending writes and ignores a disabled press',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodChannel? channel;
      final updates = <Map>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          channel = MethodChannel(
            'breeze.video.control.${(call.arguments as Map)['id']}',
          );
          messenger.setMockMethodCallHandler(channel!, (call) async {
            if (call.method == 'update') updates.add(call.arguments as Map);
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (channel != null) messenger.setMockMethodCallHandler(channel!, null);
      });
      var presses = 0;
      Widget view(bool enabled) => MaterialApp(
        home: Center(
          child: NativeVideoIconButton(
            tooltip: 'Like',
            icon: Icons.thumb_up_outlined,
            symbol: 'hand.thumbsup',
            onPressed: enabled ? () => presses++ : null,
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(updates.last['enabled'], false);
      expect(updates.last['backgroundInset'], 4);
      expect(tester.getSize(find.byType(UiKitView)), const Size(44, 44));
      Future<void> press() => messenger.handlePlatformMessage(
        channel!.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
      await press();
      expect(presses, 0);
      await tester.pumpWidget(view(true));
      await tester.pump();
      expect(updates.last['enabled'], true);
      await press();
      expect(presses, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('timeline keeps its touch band separate from the button row', (
    tester,
  ) async {
    double? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        trackShape: const VideoTimelineTrackShape(),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(value: .4, onChanged: (v) => selected = v),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Play'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    final button = find.byType(TextButton);
    final touch = tester.getRect(slider);
    final nextTouch = tester.getRect(button);
    expect(touch.height, 44);
    expect(touch.bottom, lessThanOrEqualTo(nextTouch.top));
    final track = const VideoTimelineTrackShape().getPreferredRect(
      parentBox: tester.renderObject<RenderBox>(slider),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
      ),
    );
    expect(track.center.dy, 32);
    expect(track.center.dy + 12, lessThanOrEqualTo(touch.height));
    final centerDistance = nextTouch.center.dy - (touch.top + track.center.dy);
    expect(centerDistance, 34);
    // The upper portion of the original touch band still seeks; the visible
    // track moved inside that band rather than shrinking the hit target.
    await tester.tapAt(Offset(touch.left + touch.width * .75, touch.top + 4));
    expect(selected, greaterThan(.5));
  });

  testWidgets('Breeze controls use Flutter buttons and menus on iOS', (
    tester,
  ) async {
    var presses = 0;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoControlAppearance(
            systemControls: false,
            child: Column(
              children: [
                NativeVideoIconButton(
                  tooltip: 'Play',
                  icon: Icons.play_arrow,
                  symbol: 'play.fill',
                  onPressed: () => presses++,
                ),
                NativeVideoMenu(
                  label: '1×',
                  tooltip: 'Speed',
                  selected: '1',
                  options: const {'1': '1×', '2': '2×'},
                  onSelected: (value) => selected = value,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    await tester.tap(find.byTooltip('Play'));
    expect(presses, 1);
    expect(
      tester.getSize(find.byTooltip('Play')).shortestSide,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byTooltip('Speed'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem<String> && w.value == '2',
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, '2');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'UIKit menus survive identical player rebuilds and report dismissal',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final updates = <MethodCall>[];
      late MethodChannel channel;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          channel = MethodChannel('breeze.video.control.$id');
          messenger.setMockMethodCallHandler(channel, (call) async {
            updates.add(call);
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(channel, null);
      });
      var opened = 0;
      var closed = 0;
      final controller = NativeVideoMenuController();
      Widget menu(String selected) => MaterialApp(
        home: Center(
          child: NativeVideoMenu(
            controller: controller,
            label: '$selected×',
            tooltip: 'Speed',
            selected: selected,
            options: const {'1': '1×', '2': '2×'},
            onSelected: (_) {},
            onOpened: () => opened++,
            onClosed: () => closed++,
          ),
        ),
      );
      await tester.pumpWidget(menu('1'));
      await tester.pumpAndSettle();
      final touchArea = tester.getSize(find.byType(UiKitView));
      expect(touchArea.height, greaterThanOrEqualTo(44));
      expect(touchArea.width, greaterThanOrEqualTo(44));
      expect(updates.last.method, 'update');
      updates.clear();
      Future<void> native(String event, [int? generation]) async {
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              event,
              generation == null ? null : {'generation': generation},
            ),
          ),
          (_) {},
        );
        await tester.pump();
      }

      expect(
        controller.ownsBarrier,
        true,
        reason:
            'UIKit must own outside dismissal without a competing Flutter barrier',
      );
      await native('menuOpened');
      expect(opened, 1);
      await tester.pumpWidget(menu('1'));
      expect(
        updates,
        isEmpty,
        reason: 'position-only frames must not rebuild UIMenu',
      );
      await controller.dismiss();
      expect(updates.single.method, 'dismissMenu');
      updates.clear();
      await native('menuClosed');
      expect(closed, 1);
      await native('menuOpened', 2);
      await native('menuOpened', 3);
      await native('menuClosed', 2);
      expect(closed, 1, reason: 'an older exit must not clear a reopened menu');
      await native('menuClosed', 3);
      expect(closed, 2);
      await tester.pumpWidget(menu('2'));
      expect(updates.single.method, 'update');
      expect((updates.single.arguments as Map)['selected'], '2');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.attached, false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'UIKit receives the latest state after delayed creation and ignores disposed callbacks',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final creation = Completer<void>();
      final updates = <MethodCall>[];
      late MethodChannel channel;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          channel = MethodChannel(
            'breeze.video.control.${(call.arguments as Map)['id']}',
          );
          messenger.setMockMethodCallHandler(channel, (call) async {
            updates.add(call);
            return null;
          });
          await creation.future;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(channel, null);
      });
      Widget menu(String speed) => MaterialApp(
        home: NativeVideoMenu(
          label: '$speed×',
          tooltip: 'Speed',
          selected: speed,
          options: const {'1': '1×', '2': '2×'},
          onSelected: (_) {},
        ),
      );
      await tester.pumpWidget(menu('1'));
      await tester.pump();
      await tester.pumpWidget(menu('2'));
      creation.complete();
      await tester.pumpAndSettle();
      expect((updates.last.arguments as Map)['selected'], '2');
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      await tester.pumpWidget(const SizedBox.shrink());
      updates.clear();
      view.onPlatformViewCreated!(999);
      await tester.pump();
      expect(updates, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
