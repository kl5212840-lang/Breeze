import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/action_feedback.dart';

void main() {
  testWidgets(
    'top notices stay readable, coalesce duplicates and keep independent lifetimes',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const Text('Page');
              },
            ),
          ),
        ),
      );
      try {
        final first = ToastEvent(
          type: ToastType.success,
          message: 'Check-in confirmed',
          duration: const Duration(seconds: 1),
        );
        expect(context.mounted, isTrue);
        expect(
          Overlay.maybeOf(context, rootOverlay: true),
          isNotNull,
          reason: 'notice context has a root overlay',
        );
        showToastEvent(context, first);
        showToastEvent(context, first);
        await tester.pump();
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Check-in confirmed'), findsOneWidget);
        expect(readableToastDuration(first), const Duration(seconds: 3));
        expect(
          tester.getCenter(find.text('Check-in confirmed')).dy,
          lessThan(300),
        );
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('Check-in confirmed'), findsOneWidget);
        showActionFeedback(context, 'Preference saved');
        showToastEvent(
          context,
          ToastEvent(
            type: ToastType.success,
            message: 'Check-in confirmed',
            duration: const Duration(seconds: 1),
          ),
        );
        await tester.pump();
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Preference saved'), findsOneWidget);
        expect(find.text('Check-in confirmed'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        for (var frame = 0; frame < 18; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Check-in confirmed'), findsNothing);
        expect(find.text('Preference saved'), findsOneWidget);
        final longError = ToastEvent(
          type: ToastType.error,
          message: List.filled(
            5,
            'A readable error with useful details.',
          ).join(' '),
          duration: const Duration(seconds: 1),
        );
        showToastEvent(context, longError);
        await tester.pump();
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          readableToastDuration(longError),
          greaterThanOrEqualTo(const Duration(seconds: 5)),
        );
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('New page'))),
        );
        showActionFeedback(context, 'Late stale success');
        await tester.pump();
        expect(find.text('Late stale success'), findsNothing);
      } finally {
        toastification.dismissAll(delayForAnimation: false);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        toastification.managers.clear();
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(tester.takeException(), isNull);
    },
  );
}
