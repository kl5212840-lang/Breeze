import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_tools_tile.dart';

void main() {
  testWidgets('development mode cannot be enabled without a development URL', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <(bool, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: PluginSettingsContent(
              from: 'test',
              pluginRuntimeName: 'test',
              state: const PluginSettingsState(loading: false),
              debugEnabled: false,
              debugUrl: '',
              deleted: false,
              pluginVersion: '1',
              colorScheme: Theme.of(context).colorScheme,
              onUpdateDebugConfig: ({required enabled, required url}) async {
                calls.add((enabled, url));
              },
              onConfirmDeletePlugin: () async {},
              onUpdatePlugin: () async {},
              onOpenLoginPage: () async {},
              onOpenDetailPage: () async {},
              onCommitField: (_, _) async {},
              onRunAction: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SourceDiagnosticToolsTile),
      findsOneWidget,
      reason: 'Comic plugin settings must expose the same opt-in switch',
    );
    await tester.ensureVisible(find.text(t.plugin.debugMode));
    await tester.tap(find.text(t.plugin.debugMode));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(t.plugin.debugAddress), findsWidgets);
    expect(calls, isEmpty);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
