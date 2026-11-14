import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

void main() {
  testWidgets(
    'segmented fallback measures finite height in an unbounded column',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 440.0]) {
        for (final scale in [1.0, 1.4, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          final brightness = width == 390 ? Brightness.dark : Brightness.light;
          final colors = BreezeThemeColors.fromSeed(
            const Color(0xff009688),
            brightness,
          );
          final highContrast = scale == 2;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: colors,
                scaffoldBackgroundColor: colors.surface,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  highContrast: highContrast,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: VideoControlAppearance(
                  systemControls: false,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          NativeVideoSegmentedControl(
                            options: const {'all': '全部追更', 'unread': '未读更新'},
                            selected: 'all',
                            onSelected: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final size = tester.getSize(find.byType(NativeVideoSegmentedControl));
          expect(size.height.isFinite, isTrue);
          expect(size.height, greaterThanOrEqualTo(44));
          expect(find.text('全部追更').hitTestable(), findsOneWidget);
          expect(find.text('未读更新').hitTestable(), findsOneWidget);
          final fallback = tester.widget<SegmentedButton<String>>(
            find.byType(SegmentedButton<String>),
          );
          const selected = {WidgetState.selected};
          final fill = fallback.style!.backgroundColor!.resolve(selected)!;
          final label = fallback.style!.foregroundColor!.resolve(selected)!;
          final track = fallback.style!.backgroundColor!.resolve({})!;
          final selection = BreezeControlColors.systemSegmentSelection(
            colors,
            highContrast: highContrast,
          );
          expect(
            (track, fill, label),
            (selection.track, selection.fill, selection.foreground),
          );
          expect(
            BreezeThemeColors.contrast(label, fill),
            greaterThanOrEqualTo(4.5),
          );
          if (highContrast) {
            expect(
              BreezeThemeColors.contrast(fill, track),
              greaterThanOrEqualTo(3),
            );
          } else {
            expect(fill, isNot(Colors.white));
            expect(
              fill.computeLuminance(),
              greaterThan(track.computeLuminance()),
            );
          }
          expect(tester.takeException(), isNull, reason: '$width / $scale');
        }
      }
    },
  );

  testWidgets(
    'catalog back and more keep equal UIKit hit areas and visible plate metrics',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'breeze.video.control.${(call.arguments as Map)['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: Center(
                child: NativeVideoIconButton(
                  light: false,
                  tooltip: 'Back',
                  icon: Icons.arrow_back_rounded,
                  symbol: 'chevron.left',
                  onPressed: () {},
                ),
              ),
              actions: [
                NativeVideoMenu(
                  hostPresentation: true,
                  label: '',
                  tooltip: 'More',
                  width: 44,
                  icon: Icons.more_horiz_rounded,
                  symbol: 'ellipsis',
                  selected: '',
                  options: const {
                    'website': '打开官网',
                    'settings': '设置',
                    'exit': '退出插件',
                  },
                  groups: const [
                    ['website'],
                    ['settings'],
                    ['exit'],
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final views = find.byType(UiKitView);
      expect(views, findsNWidgets(2));
      final more = tester.widget<UiKitView>(views.last);
      expect((more.creationParams! as Map)['compactPopup'], isTrue);
      expect((more.creationParams! as Map)['groups'], [
        ['website'],
        ['settings'],
        ['exit'],
      ], reason: 'Grouping must retain the real iOS menu presentation');
      for (var index = 0; index < 2; index++) {
        final view = tester.widget<UiKitView>(views.at(index));
        final arguments = view.creationParams! as Map;
        expect(tester.getSize(views.at(index)), const Size(44, 44));
        expect(arguments['backgroundInset'], 4);
        expect(arguments['iconSize'], 22);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a bare host menu keeps its 44-point hit area and opens', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoControlAppearance(
            systemControls: false,
            child: NativeVideoMenu(
              label: '',
              tooltip: 'More',
              selected: '',
              options: const {'manage': 'Manage'},
              onSelected: (value) => selected = value,
              icon: Icons.more_horiz_rounded,
              width: 44,
              bare: true,
              hostPresentation: true,
            ),
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);
    expect(tester.getSize(button), const Size(44, 44));
    final plate = tester.widget<DecoratedBox>(
      find.descendant(of: button, matching: find.byType(DecoratedBox)),
    );
    expect((plate.decoration as BoxDecoration).color, Colors.transparent);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(selected, 'manage');
  });

  testWidgets(
    'catalog fallback back and more share a 36pt plate without shrinking touch targets',
    (tester) async {
      var backs = 0;
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: VideoControlAppearance(
            systemControls: false,
            child: Scaffold(
              appBar: AppBar(
                leading: Center(
                  child: NativeVideoIconButton(
                    light: false,
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    symbol: 'chevron.left',
                    onPressed: () => backs++,
                  ),
                ),
                actions: [
                  NativeVideoMenu(
                    hostPresentation: true,
                    label: '',
                    tooltip: 'More',
                    width: 44,
                    icon: Icons.more_horiz_rounded,
                    symbol: 'ellipsis',
                    selected: '',
                    options: const {'exit': 'Exit'},
                    onSelected: (value) => selected = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(UiKitView), findsNothing);
      for (final label in ['Back', 'More']) {
        final touch = find.byTooltip(label);
        final plate = find.descendant(
          of: touch,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == 36 && widget.height == 36,
          ),
        );
        expect(tester.getSize(touch), const Size(44, 44));
        expect(plate, findsOneWidget);
        expect(tester.getRect(plate).center, tester.getRect(touch).center);
      }
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Exit'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byTooltip('Back')));
      await tester.pumpAndSettle();
      expect(find.text('Exit'), findsNothing);
      expect(backs, 0, reason: 'Dismissal must not reach the back control');
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(selected, 'exit');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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
      final navigator = GlobalKey<NavigatorState>();
      final controller = NativeVideoMenuController();
      Widget menu(String selected) => MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Center(
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
      await native('menuOpened', 4);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        closed,
        2,
        reason:
            'A route transition must not destroy native chrome or synthesize a close',
      );
      await native('menuClosed', 4);
      expect(closed, 3);
      await tester.pumpAndSettle();
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
