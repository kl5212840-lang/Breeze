import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets(
    'completion feedback clears itself and does not queue stale successes',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const Text('Content');
              },
            ),
          ),
        ),
      );
      showActionFeedback(context, 'Saved');
      await tester.pump();
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      showActionFeedback(context, 'Moved');
      await tester.pump();
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Moved'), findsNothing);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(milliseconds: 100));
      toastification.managers.clear();
    },
  );
}
