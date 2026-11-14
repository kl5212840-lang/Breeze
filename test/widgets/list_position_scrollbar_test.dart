import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/list_position_scrollbar.dart';

void main() {
  for (final (brightness, highContrast, reduceMotion) in [
    (Brightness.light, false, false),
    (Brightness.dark, true, true),
  ]) {
    testWidgets('list position fades after scrolling, $brightness', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ListPositionScrollbar(
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemExtent: 60,
                itemBuilder: (_, i) => Text('Item $i'),
              ),
            ),
          ),
        ),
      );
      final scrollbar = find.byType(RawScrollbar);
      final widget = tester.widget<RawScrollbar>(scrollbar);
      expect(widget.interactive, isFalse);
      expect(
        widget.thumbColor,
        scheme.onSurface.withValues(alpha: highContrast ? .68 : .52),
      );
      final paint = find.descendant(
        of: scrollbar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is ScrollbarPainter,
        ),
      );
      double opacity() =>
          (tester.widget<CustomPaint>(paint).foregroundPainter
                  as ScrollbarPainter)
              .fadeoutOpacityAnimation
              .value;

      expect(opacity(), 0);
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 50));
      if (!reduceMotion) {
        await tester.pump(const Duration(milliseconds: 75));
        expect(opacity(), inExclusiveRange(0, 1));
        await tester.pump(const Duration(milliseconds: 75));
      }
      expect(opacity(), 0);
    });
  }
}
