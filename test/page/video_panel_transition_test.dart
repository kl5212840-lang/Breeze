import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_panel_transition.dart';

void main() {
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
