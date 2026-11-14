import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets('Breeze commands and menus reserve the outline for focus', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    final filterSelected = ValueNotifier(false);
    addTearDown(style.dispose);
    addTearDown(filterSelected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppInterfaceStyleScope(
          style: style,
          child: Scaffold(
            body: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: filterSelected,
                  builder: (context, selected, _) => SourceFilterIconButton(
                    tooltip: 'Filter',
                    active: selected,
                    bare: false,
                    onPressed: () => filterSelected.value = !selected,
                  ),
                ),
                NativeVideoMenu(
                  label: '',
                  tooltip: 'More',
                  selected: '',
                  width: VideoControlMetrics.touchExtent,
                  icon: Icons.more_horiz,
                  symbol: 'ellipsis',
                  hostPresentation: true,
                  options: const {'manage': 'Manage'},
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Finder command(String tooltip) => find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    );
    final filter = command('Filter');
    final more = command('More');
    Finder plate(Finder button) => find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.all(Radius.circular(10)),
      ),
    );
    BoxDecoration decoration(Finder button) =>
        tester.widget<DecoratedBox>(plate(button)).decoration as BoxDecoration;

    final filterRect = tester.getRect(filter);
    final moreRect = tester.getRect(more);
    void expectStableGeometry() {
      for (final (button, rect) in [(filter, filterRect), (more, moreRect)]) {
        expect(rect.size, const Size.square(44));
        expect(tester.getRect(button), rect);
        expect(tester.getSize(plate(button)), const Size.square(36));
        expect(tester.getCenter(plate(button)), rect.center);
      }
    }

    expectStableGeometry();
    final resting = decoration(filter);
    expect(resting.border, isNull);
    expect(decoration(more), resting);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect((decoration(filter).border! as Border).top.width, 2);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 200));
    await mouse.moveTo(filterRect.center);
    await tester.pumpAndSettle();
    expect(decoration(filter).color, isNot(resting.color));
    await mouse.removePointer();
    await tester.pumpAndSettle();

    final press = await tester.startGesture(filterRect.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    final intermediate = decoration(filter).color;
    expect(intermediate, isNot(resting.color));
    await tester.pump(const Duration(milliseconds: 40));
    expect(decoration(filter).color, isNot(intermediate));
    expectStableGeometry();
    await press.cancel();
    await tester.pumpAndSettle();
    expect(decoration(filter), resting);
    expect(filterSelected.value, isFalse);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(filterSelected.value, isTrue);
    expect(decoration(filter).color, isNot(resting.color));
    expect(decoration(filter).border, isNull);
    expectStableGeometry();

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Manage'), findsOneWidget);
    expect(decoration(more).color, isNot(resting.color));
    expectStableGeometry();
    await tester.tapAt(const Offset(1, 200));
    await tester.pumpAndSettle();
    expect(find.text('Manage'), findsNothing);
    expect(tester.widget<IconButton>(more).isSelected, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
