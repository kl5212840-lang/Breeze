import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => objectbox.pluginConfigBox.removeAll());

  test(
    'rename and clearing preserve source identity, account and other plugin preferences',
    () async {
      savePluginConfigValueSync(
        'alpha',
        'auth.authorization',
        'synthetic-token',
      );
      savePluginConfigValueSync(
        'alpha',
        'network.apiBase',
        'https://example.invalid/',
      );
      savePluginConfigValueSync('beta', pluginDisplayNameKey, 'Other source');
      await savePluginDisplayName('alpha', '  My   comics  ', expectedName: '');
      expect(readPluginDisplayName('alpha'), 'My comics');
      expect(readPluginDisplayName('beta'), 'Other source');
      await savePluginDisplayName('alpha', '', expectedName: 'My comics');
      expect(readPluginDisplayName('alpha'), '');
      final config = objectbox.pluginConfigBox.getAll().singleWhere(
        (row) => row.name == 'alpha',
      );
      final data = jsonDecode(config.config) as Map;
      expect(data[pluginDisplayNameKey], '');
      expect(data['auth.authorization'], 'synthetic-token');
      expect(data['network.apiBase'], 'https://example.invalid/');
      expect(objectbox.pluginInfoBox.getAll(), isEmpty);
    },
  );

  test(
    'stale confirmation and overlong input leave persisted preferences unchanged',
    () async {
      savePluginConfigValueSync('alpha', pluginDisplayNameKey, 'Newer name');
      final before = objectbox.pluginConfigBox.getAll().single.config;
      await expectLater(
        savePluginDisplayName('alpha', 'Old draft', expectedName: ''),
        throwsStateError,
      );
      await expectLater(
        savePluginDisplayName('alpha', 'x' * 81, expectedName: 'Newer name'),
        throwsFormatException,
      );
      expect(objectbox.pluginConfigBox.getAll().single.config, before);
      for (final invalid in [null, true, 123, <String, dynamic>{}, 'x' * 81]) {
        expect(normalizePluginDisplayName(invalid), '');
      }
    },
  );

  testWidgets(
    'shared titles observe source-specific updates, clear and a retained consumer switching source',
    (tester) async {
      savePluginConfigValueSync('alpha', pluginDisplayNameKey, 'Alpha alias');
      savePluginConfigValueSync('beta', pluginDisplayNameKey, 'Beta alias');
      final source = ValueNotifier('alpha');
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: source,
            builder: (_, value, _) => PluginDisplayNameBuilder(
              source: value,
              fallback: 'Original name',
              builder: (_, name) => Text(name),
            ),
          ),
        ),
      );
      expect(find.text('Alpha alias'), findsOneWidget);
      source.value = 'beta';
      await tester.pump();
      expect(find.text('Beta alias'), findsOneWidget);
      savePluginConfigValueSync('alpha', pluginDisplayNameKey, 'Changed alpha');
      savePluginConfigValueSync('beta', pluginDisplayNameKey, '');
      for (
        var i = 0;
        i < 50 && find.text('Original name').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('Original name'), findsOneWidget);
      expect(find.text('Changed alpha'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
