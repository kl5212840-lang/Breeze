import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_removal_flow.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('removal scope dependencies and independent confirmation $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PluginRemovalScope? selected;
      bool? confirmed;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(builder: (context) => Scaffold(body: TextButton(
          child: const Text('open'),
          onPressed: () async {
            selected = await showPluginRemovalScope(context, pluginName: 'Fixture');
            if (selected != null && context.mounted) {
              confirmed = await confirmPluginRemoval(context, pluginName: 'Fixture', scope: selected!);
            }
          },
        ))),
      ));
      await tester.tap(find.text('open')); await tester.pumpAndSettle();
      CheckboxListTile local() => tester.widget(find.byKey(const ValueKey('plugin-remove-local')));
      CheckboxListTile cloud() => tester.widget(find.byKey(const ValueKey('plugin-remove-cloud')));
      expect(local().value, isFalse); expect(cloud().value, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('plugin-remove-cloud')));
      await tester.tap(find.byKey(const ValueKey('plugin-remove-cloud'))); await tester.pump();
      expect(local().value, isTrue); expect(cloud().value, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('plugin-remove-local')));
      await tester.tap(find.byKey(const ValueKey('plugin-remove-local'))); await tester.pump();
      expect(local().value, isFalse); expect(cloud().value, isFalse);
      await tester.tap(find.byKey(const ValueKey('plugin-remove-next'))); await tester.pumpAndSettle();
      expect(selected!.local, isFalse); expect(selected!.cloud, isFalse);
      expect(confirmed, isNull);
      expect(find.byKey(const ValueKey('plugin-remove-confirm')), findsOneWidget);
      await tester.tap(find.text(t.common.cancel)); await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
