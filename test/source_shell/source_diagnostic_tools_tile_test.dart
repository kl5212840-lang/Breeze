import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Hold the existing shared_preferences backing store while testing saving UI.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_tools_tile.dart';

class _SlowStore extends InMemorySharedPreferencesStore {
  _SlowStore() : super.empty();

  final save = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    await save.future;
    return super.setValue(type, key, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'opt-in switch persists and responds immediately to external changes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SourceDiagnosticToolsTile(source: 'hanime')),
        ),
      );
      final finder = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(finder).onChanged, isNull);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, isFalse);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      expect(find.text(t.sourceShell.diagnosticTools), findsOneWidget);

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, isTrue);
      expect(await SourceDiagnosticPreferences.enabled('hanime'), isTrue);

      await SourceDiagnosticPreferences.setEnabled('hanime', false);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, isFalse);
    },
  );

  testWidgets('reused settings row reloads the new source preference', (
    tester,
  ) async {
    await SourceDiagnosticPreferences.setEnabled('source-a', true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SourceDiagnosticToolsTile(source: 'source-a')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SourceDiagnosticToolsTile(source: 'source-b')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('saving disables repeated taps until persistence completes', (
    tester,
  ) async {
    final store = _SlowStore();
    SharedPreferencesStorePlatform.instance = store;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SourceDiagnosticToolsTile(source: 'saving-source'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final finder = find.byType(SwitchListTile);
    await tester.tap(finder);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(finder).onChanged, isNull);
    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
    store.save.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(finder).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(finder).value, isTrue);
  });
}
