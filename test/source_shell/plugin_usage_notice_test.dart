import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/plugin_usage_notice.dart';

void main() {
  testWidgets(
    'notice is on demand, scrolls at large text and closes without a gate',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var backgroundTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showPluginUsageNotice(context),
                    child: const Text('Open notice'),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => backgroundTaps++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PluginUsageNoticeDialog), findsNothing);
      await tester.tap(find.text('Open notice'));
      await tester.pumpAndSettle();
      expect(find.text(t.about.disclaimerItem1Title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text(t.about.disclaimerItem8Title),
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('plugin-usage-notice-content')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(find.byType(PluginUsageNoticeDialog), findsNothing);
      expect(backgroundTaps, 0);
    },
  );
}
