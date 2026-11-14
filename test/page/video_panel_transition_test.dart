import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_panel_transition.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_side_panel.dart';

void main() {
  testWidgets('landscape tasks fit their content and share a strong fading edge', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var purpose = VideoPanelPurpose.speed;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, change) {
      update = change;
      return MediaQuery(data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(right: 44)),
        child: VideoBottomPanelLayout(purpose: purpose, reservedTop: 0,
          child: const SizedBox(key: ValueKey('task-width'))));
    })));
    final speed = tester.getSize(find.byKey(const ValueKey('task-width'))).width;
    update(() => purpose = VideoPanelPurpose.sources);
    await tester.pump();
    final sources = tester.getSize(find.byKey(const ValueKey('task-width'))).width;
    update(() => purpose = VideoPanelPurpose.controls);
    await tester.pump();
    final controls = tester.getSize(find.byKey(const ValueKey('task-width'))).width;
    expect(speed, lessThan(sources));
    expect(sources, lessThan(controls));
    expect(controls, lessThan(844 / 2));
    final depth = find.byKey(const ValueKey('video-panel.side-depth'));
    expect(tester.getRect(depth).right, 844);
    expect(tester.getRect(depth).left, lessThan(tester.getRect(find.byKey(const ValueKey('task-width'))).left));
    final gradient = (tester.widget<DecoratedBox>(depth).decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first.a, 0);
    expect(gradient.colors[1].a, greaterThan(.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing panel consumes touches until its exit animation is dismissed', (tester) async {
    var open = true, taps = 0;
    late StateSetter change;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      change = setState;
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque,
          onTap: () => taps++, child: const ColoredBox(color: Colors.white))),
        VideoPanelTransition(open: open, side: true,
          onDismiss: () => change(() => open = false),
          child: const Align(alignment: Alignment.centerRight,
            child: SizedBox(width: 200, child: Text('Closing panel')))),
      ]);
    })));
    await tester.pumpAndSettle();
    change(() => open = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tapAt(const Offset(20, 200));
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(20, 200));
    expect(taps, 1);
  });

  testWidgets('landscape scrim preserves the main video brightness', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SizedBox.expand(
      child: VideoPanelTransition(open: true, side: true, onDismiss: () {},
        child: const Align(alignment: Alignment.centerRight,
          child: SizedBox(width: 200, child: Text('Sidebar')))),
    )));
    await tester.pumpAndSettle();
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color!.a, 0);
    final scrim = tester.widget<DecoratedBox>(find.byKey(const ValueKey('video-panel.scrim')));
    expect((scrim.decoration as BoxDecoration).gradient, isNull);
    expect((scrim.decoration as BoxDecoration).color, isNull);
    expect(barrier.dismissible, isTrue);
  });

  for (final reduced in [false, true]) {
    testWidgets('panel reverses without losing content, reduced=$reduced', (
      tester,
    ) async {
      var open = false;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: Stack(
                  children: [
                    VideoPanelTransition(
                      open: open,
                      side: true,
                      onDismiss: () => change(() => open = false),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 300,
                          child: Text('Panel content'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      change(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Panel content'), findsOneWidget);
      final before = tester.getTopLeft(find.text('Panel content')).dx;
      change(() => open = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      change(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Panel content'), findsOneWidget);
      final settled = tester.getTopLeft(find.text('Panel content')).dx;
      expect(reduced ? before == settled : before > settled, true);
      await tester.tapAt(const Offset(20, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Panel content'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
