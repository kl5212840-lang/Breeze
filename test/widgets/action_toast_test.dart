import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

void main() {
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('in-app notice stays non-modal and opens once $style $brightness', (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        addTearDown(() async {
          toastification.dismissAll(delayForAnimation: false);
          await tester.pump(const Duration(milliseconds: 100));
          toastification.managers.clear();
        });
        var opened = 0;
        var underlying = 0;
        await tester.pumpWidget(AppInterfaceStyleScope(style: preference,
          child: MaterialApp(theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
            home: Builder(builder: (context) => Scaffold(body: Column(children: [
              TextButton(onPressed: () => showActionToast(context, ToastEvent(
                type: ToastType.info, title: 'Following updates',
                message: 'Several followed works have new chapters available. Open the list to see what changed.',
                duration: const Duration(seconds: 4), actionLabel: 'View updates',
                onTap: () async { opened++; },
              )), child: const Text('Show notice')),
              const Spacer(),
              TextButton(onPressed: () => underlying++, child: const Text('Page action')),
            ]))),
          ),
        ));
        await tester.pumpAndSettle();
        final existingBarriers = find.byType(ModalBarrier).evaluate().length;
        await tester.tap(find.text('Show notice'));
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ModalBarrier).evaluate().length, existingBarriers);
        expect(find.text('View updates'), findsOneWidget);
        await tester.tap(find.text('Page action'));
        await tester.pump();
        expect(underlying, 1);
        expect(opened, 0);
        await tester.tap(find.text('View updates'));
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(opened, 1);
        expect(find.text('View updates'), findsNothing);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
