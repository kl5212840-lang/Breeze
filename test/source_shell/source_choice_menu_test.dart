import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

void main() {
  testWidgets('short choices size to their labels and keep a selection slot', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: Scaffold(
            body: SourceChoiceMenu<int>(
              label: '名称',
              tooltip: '范围',
              value: 1,
              options: const {1: '名称', 2: '作者'},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('范围'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(const ValueKey('video-host-menu')));
    expect(panel.width, lessThan(140));
    final selected = find.text('名称').last;
    expect(tester.getTopLeft(selected).dx, panel.left + 16);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('choice in a Navigator settings route, $brightness', (
      tester,
    ) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      var underlyingTaps = 0;
      final changes = <int>[];
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Settings'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: Column(
                          children: [
                            SourceChoiceMenu<int>(
                              label: 'Current',
                              tooltip: 'Choose',
                              value: 1,
                              options: const {1: 'Current', 2: 'Second'},
                              onChanged: changes.add,
                            ),
                            TextButton(
                              onPressed: () => underlyingTaps++,
                              child: const Text('Underlying action'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Underlying action')));
      await tester.pumpAndSettle();
      expect(underlyingTaps, 0);
      expect(changes, isEmpty);
      await tester.tap(find.byTooltip('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(changes, [
        2,
      ], reason: 'Commit without waiting for the exit animation');
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SourceChoiceMenu<int>))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'bottom choice scrolls inside the keyboard safe area at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 200),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SourceChoiceMenu<String>(
                label: 'Current',
                tooltip: 'Choose',
                value: '0',
                options: {for (var i = 0; i < 25; i++) '$i': 'Option $i'},
                onChanged: (value) => picked = value,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose'));
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find.byKey(const ValueKey('video-host-menu')),
      );
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(320));
      expect(panel.bottom, lessThanOrEqualTo(440));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2500),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Option 24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 24'));
      await tester.pumpAndSettle();
      expect(picked, '24');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system choice forwards its selection to the existing native menu',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 200)),
            child: child!,
          ),
          home: Scaffold(
            body: SourceChoiceMenu<int>(
              label: 'Current',
              tooltip: 'Choose',
              value: 20,
              options: const {10: 'First', 20: 'Current'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final params =
          tester.widget<UiKitView>(find.byType(UiKitView)).creationParams!
              as Map;
      expect(params['bare'], true);
      expect(params['compactPopup'], true);
      expect(params['selected'], '1');
      expect(params['menuBottomInset'], 200);
      expect(find.byType(NativeVideoMenu), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'open Breeze choice follows its trigger when the keyboard moves it, $brightness',
      (tester) async {
        final style = ValueNotifier('breeze');
        final keyboard = ValueNotifier(0.0);
        addTearDown(style.dispose);
        addTearDown(keyboard.dispose);
        await tester.binding.setSurfaceSize(const Size(400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => ValueListenableBuilder(
                valueListenable: keyboard,
                builder: (_, inset, _) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: SourceChoiceMenu<int>(
                    label: 'Current',
                    tooltip: 'Choose',
                    value: 1,
                    options: const {1: 'Current', 2: 'Second'},
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Choose'));
        await tester.pumpAndSettle();
        final panelFinder = find.byKey(const ValueKey('video-host-menu'));
        final before = tester.getRect(panelFinder);
        keyboard.value = 200;
        await tester.pumpAndSettle();
        final anchor = tester.getRect(find.byTooltip('Choose'));
        final panel = tester.getRect(panelFinder);
        expect(
          panel.bottom,
          lessThanOrEqualTo(anchor.top - 6),
          reason: 'menu follows the moved trigger rather than overlapping it',
        );
        expect(panel.width, before.width);
        expect(panel.size.height, before.size.height);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'open system choice receives new text size without recreation, $brightness',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final scale = ValueNotifier(1.0);
        addTearDown(scale.dispose);
        MethodChannel? channel;
        var creates = 0;
        final updates = <Map>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            creates++;
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
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          if (channel != null) {
            messenger.setMockMethodCallHandler(channel!, null);
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => ValueListenableBuilder(
              valueListenable: scale,
              builder: (_, value, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(value)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: SourceChoiceMenu<int>(
                label: 'Current',
                tooltip: 'Choose',
                value: 1,
                options: const {1: 'Current', 2: 'Another choice'},
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state(find.byType(UiKitView));
        // Exercise the same bridge while a native menu is open, rather than
        // creating another trigger after the accessibility change.
        await messenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('menuOpened', {'generation': 1}),
          ),
          (_) {},
        );
        await tester.pump();
        updates.clear();
        scale.value = 2;
        await tester.pumpAndSettle();
        expect(creates, 1);
        expect(tester.state(find.byType(UiKitView)), same(state));
        expect(updates, hasLength(1));
        expect(updates.single['menuFontSize'], 34);
        expect(updates.single['selected'], '0');
        expect(updates.single['options'], [
          {'value': '0', 'title': 'Current'},
          {'value': '1', 'title': 'Another choice'},
        ]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
