import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/plugin_installation_guard.dart';

import '../test_helper.dart';

const _source = 'guard-dynamic-source';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginInfoBox.removeAll();
    final now = DateTime.utc(2026);
    objectbox.pluginInfoBox.put(
      PluginInfo(
        uuid: _source,
        version: '1',
        originScript: 'retained fixture',
        insertedAt: now,
        updatedAt: now,
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: false,
        debug: false,
      ),
    );
    await PluginRegistryService.I.init();
    await LocalPluginInstallationState.instance.markRemoved(_source);
    await PluginRegistryService.I.refreshFromDb();
  });

  testWidgets(
    'repeated taps share one confirmation and cancel writes nothing',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(LocalPluginInstallationState.storageKey);
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  ensurePluginInstalled(context, _source).then(results.add);
                  ensurePluginInstalled(context, _source).then(results.add);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(results, [false, false]);
      expect(prefs.getString(LocalPluginInstallationState.storageKey), before);
      expect(
        objectbox.pluginInfoBox.getAll().single.originScript,
        'retained fixture',
      );
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel from a pushed record page preserves its parent and page route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Builder(
                      builder: (recordContext) => Scaffold(
                        body: TextButton(
                          onPressed: () =>
                              ensurePluginInstalled(recordContext, _source),
                          child: const Text('record'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('parent'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(find.text('record'), findsOneWidget);
      expect(find.text('parent'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.text('parent'), findsOneWidget);
    },
  );
}
