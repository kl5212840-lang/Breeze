import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final calls = <MethodCall>[];
  final nativeChoice = find.byWidgetPredicate(
    (widget) =>
        widget is UiKitView &&
        (widget.creationParams as Map)['selectionIndicator'] == true,
  );
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final channel = MethodChannel(
          'breeze.video.control.${(call.arguments as Map)['id']}',
        );
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  Future<void> open(
    WidgetTester tester,
    String style, {
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: SettingPageShell(
            title: '应用行为',
            grouped: true,
            child: SettingListView(
              children: [
                SettingChoiceTile<String>(
                  leading: const Icon(Icons.rocket_launch_outlined),
                  title: '启动页面',
                  description: '打开应用时显示的页面',
                  value: '发现',
                  items: const {'发现': '发现', '书架': '书架'},
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    calls.clear();
  }

  testWidgets(
    'short native setting uses the available value column without shrinking its label',
    (tester) async {
      await open(tester, 'system');
      final value = tester.getRect(nativeChoice);
      final title = tester.getRect(find.text('启动页面'));
      // The old glyph-width estimate allocated only about 72pt. UIKit also
      // needs its own title/image layout; use the available stable column.
      expect(value.left - title.right, closeTo(16, .5));
      expect(value.width, greaterThan(150));
      expect(value.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSize(find.text('打开应用时显示的页面')).height,
        lessThanOrEqualTo(42),
        reason:
            'A normal-width short description has room for at most two lines',
      );
      final row = tester.getRect(find.byType(ListTile));
      expect(
        value.center.dy,
        closeTo(row.center.dy, .5),
        reason:
            'The current value centers beside the title and description as a single row',
      );
      final leading = tester.getRect(find.byIcon(Icons.rocket_launch_outlined));
      expect(leading.center.dy, closeTo(row.center.dy, .5));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native setting receives immediate down feedback and clears on cancel or scrolling',
    (tester) async {
      await open(tester, 'system');
      final view = nativeChoice;
      final bounds = tester.getRect(view);
      final held = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        calls
            .where((call) => call.method == 'setPressed')
            .map((c) => c.arguments),
        [true],
      );
      await held.cancel();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        calls
            .where((call) => call.method == 'setPressed')
            .map((c) => c.arguments),
        [true, false],
      );
      expect(tester.getRect(view), bounds);
      calls.clear();
      final scrolling = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 20));
      await scrolling.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(
        calls
            .where((call) => call.method == 'setPressed')
            .map((c) => c.arguments),
        [true, false],
      );
      await scrolling.cancel();
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'openMenu'), isEmpty);
      expect(tester.getRect(view), bounds);
      calls.clear();
      final leaving = await tester.startGesture(
        Offset(bounds.right - 2, bounds.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await leaving.moveBy(const Offset(4, 0));
      await tester.pump();
      expect(
        calls
            .where((call) => call.method == 'setPressed')
            .map((c) => c.arguments),
        [true, false],
        reason: 'Leaving the value cancels feedback even within drag slop',
      );
      await leaving.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'Breeze value has cancellable press feedback without moving the row reduced=$reduced',
      (tester) async {
        await open(tester, 'breeze', reduced: reduced);
        final label = find.text('发现');
        final before = tester.getRect(label);
        final rowBefore = tester.getRect(
          find.byType(SettingChoiceTile<String>),
        );
        final held = await tester.startGesture(before.center);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester.getRect(label).top - before.top,
          closeTo(reduced ? 0 : 1, .1),
        );
        expect(
          tester.getRect(find.byType(SettingChoiceTile<String>)),
          rowBefore,
        );
        await held.cancel();
        await tester.pumpAndSettle();
        expect(tester.getRect(label), before);
        expect(find.text('书架'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'direct bare text menus retain their native menu and share down/cancel feedback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NativeVideoMenu(
                bare: true,
                label: '最近收藏',
                tooltip: '排序',
                selected: 'recent',
                options: const {'recent': '最近收藏', 'name': '名称'},
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = find.byType(UiKitView);
      final args = tester.widget<UiKitView>(view).creationParams as Map;
      expect(args['compactPopup'], isNull);
      expect(args['pressFeedback'], isTrue);
      calls.clear();
      final gesture = await tester.startGesture(tester.getCenter(view));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(
        calls
            .where((call) => call.method == 'setPressed')
            .map((c) => c.arguments),
        [true, false],
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  Future<void> openIconMenu(
    WidgetTester tester,
    String style, {
    bool reduced = false,
    bool bare = false,
    ValueChanged<String>? selected,
  }) async {
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                ListTile(
                  title: const Text('下载作品'),
                  trailing: NativeVideoMenu(
                    key: const ValueKey('feedback-icon-menu'),
                    hostPresentation: true,
                    label: '',
                    tooltip: '更多',
                    selected: '',
                    width: 44,
                    bare: bare,
                    icon: Icons.more_horiz_rounded,
                    symbol: 'ellipsis',
                    options: const {'delete': '删除下载'},
                    onSelected: selected ?? (_) {},
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    calls.clear();
  }

  for (final bare in [false, true]) {
    testWidgets(
      'native icon menu keeps its plate/frame and forwards down/cancel/drag bare=$bare',
      (tester) async {
        await openIconMenu(tester, 'system', bare: bare);
        final view = find.byType(UiKitView);
        final args = tester.widget<UiKitView>(view).creationParams as Map;
        expect(args['pressFeedback'], isTrue);
        expect(args['iconPressFeedback'], isTrue);
        expect(args['bare'], bare);
        expect(args['backgroundInset'], VideoControlMetrics.backgroundInset);
        expect(args['compactPopup'], isTrue);
        expect(
          find.ancestor(
            of: view,
            matching: find.byType(CollectionPressFeedback),
          ),
          findsNothing,
        );
        final before = tester.getRect(view);
        expect(before.size, const Size(44, 44));
        final held = await tester.startGesture(before.center);
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          calls
              .where((call) => call.method == 'setPressed')
              .map((call) => call.arguments),
          [true],
        );
        await held.cancel();
        await tester.pumpAndSettle();
        expect(
          calls
              .where((call) => call.method == 'setPressed')
              .map((call) => call.arguments),
          [true, false],
        );
        expect(tester.getRect(view), before);
        calls.clear();
        final dragging = await tester.startGesture(before.center);
        await tester.pump(const Duration(milliseconds: 20));
        await dragging.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          calls
              .where((call) => call.method == 'setPressed')
              .map((call) => call.arguments),
          [true, false],
        );
        expect(calls.where((call) => call.method == 'openMenu'), isEmpty);
        await dragging.cancel();
        await tester.pumpAndSettle();
        calls.clear();
        final leaving = await tester.startGesture(tester.getCenter(view));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await leaving.cancel();
        expect(
          calls
              .where((call) => call.method == 'setPressed')
              .map((call) => call.arguments),
          [true, false],
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'Breeze icon menu has reversible press feedback and a stable host reduced=$reduced',
      (tester) async {
        final selected = <String>[];
        await openIconMenu(
          tester,
          'breeze',
          reduced: reduced,
          selected: selected.add,
        );
        final trigger = find.byKey(const ValueKey('feedback-icon-menu'));
        final icon = find.byIcon(Icons.more_horiz_rounded);
        final before = tester.getCenter(icon);
        final iconWidth = tester.getSize(icon).width;
        final frame = tester.getRect(trigger);
        final row = tester.getRect(find.byType(ListTile));
        final held = await tester.startGesture(frame.center);
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          tester.getCenter(icon).dy - before.dy,
          closeTo(reduced ? 0 : .6, .1),
        );
        expect(
          tester.getRect(icon).width,
          closeTo(iconWidth * (reduced ? 1 : .96), .1),
        );
        expect(tester.getRect(trigger), frame);
        expect(tester.getRect(find.byType(ListTile)), row);
        await held.cancel();
        await tester.pumpAndSettle();
        expect(tester.getCenter(icon), before);
        expect(selected, isEmpty);
        expect(find.text('删除下载'), findsNothing);
        final scrolling = await tester.startGesture(frame.center);
        await tester.pump(const Duration(milliseconds: 180));
        await scrolling.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 180));
        await scrolling.cancel();
        await tester.pumpAndSettle();
        // Scroll can change position, but the glyph has no residual displacement
        // relative to its own fixed 44pt trigger.
        expect(
          tester.getCenter(icon).dy,
          closeTo(tester.getRect(trigger).center.dy, .1),
        );
        expect(find.text('删除下载'), findsNothing);
        expect(selected, isEmpty);
        await tester.ensureVisible(trigger);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除下载'));
        await tester.pumpAndSettle();
        expect(selected, ['delete']);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
