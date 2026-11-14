import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';
import 'package:zephyr/page/discover/view/plugin_visibility_sheet.dart';

const _plugins = [
  DiscoverPluginVisibilityOption(id: 'a', title: '同名插件'),
  DiscoverPluginVisibilityOption(id: 'b', title: '同名插件'),
];

Finder _switch(String id) => find.byKey(ValueKey('discover.visibility.$id'));

Future<void> _open(
  WidgetTester tester,
  DiscoverPluginVisibility preferences, {
  double scale = 1,
  ValueNotifier<List<DiscoverPluginVisibilityOption>>? plugins,
}) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(preferences.dispose);
  await preferences.load();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-visibility'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => plugins == null
                  ? PluginVisibilitySheet(
                      plugins: _plugins,
                      preferences: preferences,
                    )
                  : ValueListenableBuilder<
                      List<DiscoverPluginVisibilityOption>
                    >(
                      valueListenable: plugins,
                      builder: (_, values, _) => PluginVisibilitySheet(
                        plugins: values,
                        preferences: preferences,
                      ),
                    ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-visibility')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('duplicate names use IDs and cancelling discards the draft', (
    tester,
  ) async {
    final writes = <List<String>>[];
    final preferences = DiscoverPluginVisibility(
      read: () async => [],
      write: (ids) async {
        writes.add(ids);
        return true;
      },
    );
    await _open(tester, preferences);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    await tester.tap(_switch('a'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(_switch('a')).value, isFalse);
    expect(tester.widget<SwitchListTile>(_switch('b')).value, isTrue);
    expect(preferences.hiddenIds, isEmpty);
    await tester.tap(find.byTooltip(t.common.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(PluginVisibilitySheet), findsNothing);
    expect(preferences.hiddenIds, isEmpty);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all installed plugins can be hidden without deleting absent IDs',
    (tester) async {
      final preferences = DiscoverPluginVisibility(
        read: () async => ['uninstalled'],
        write: (_) async => true,
      );
      await _open(tester, preferences);
      await tester.tap(_switch('a'));
      await tester.tap(_switch('b'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
      expect(preferences.hiddenIds, {'a', 'b', 'uninstalled'});
      expect(find.byType(PluginVisibilitySheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Show all restores installed plugins and keeps uninstall choices',
    (tester) async {
      final preferences = DiscoverPluginVisibility(
        read: () async => ['a', 'b', 'uninstalled'],
        write: (_) async => true,
      );
      await _open(tester, preferences);
      await tester.tap(find.text(t.discover.showAllPlugins));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(_switch('a')).value, isTrue);
      expect(tester.widget<SwitchListTile>(_switch('b')).value, isTrue);
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
      expect(preferences.hiddenIds, {'uninstalled'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save stays open with a retry and no committed change', (
    tester,
  ) async {
    var writes = 0;
    final preferences = DiscoverPluginVisibility(
      read: () async => [],
      write: (_) async => ++writes > 1,
    );
    await _open(tester, preferences);
    await tester.tap(_switch('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();
    expect(find.text(t.error.saveFailed), findsOneWidget);
    expect(find.byType(PluginVisibilitySheet), findsOneWidget);
    expect(preferences.hiddenIds, isEmpty);
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();
    expect(preferences.hiddenIds, {'a'});
    expect(writes, 2);
    expect(find.byType(PluginVisibilitySheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving disables duplicate commits and selection until it completes',
    (tester) async {
      final pending = Completer<bool>();
      var writes = 0;
      final preferences = DiscoverPluginVisibility(
        read: () async => [],
        write: (_) {
          writes++;
          return pending.future;
        },
      );
      await _open(tester, preferences);
      await tester.tap(_switch('a'));
      await tester.tap(find.text(t.common.done));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(_switch('a')).onChanged, isNull);
      await tester.tap(find.text(t.common.done));
      await tester.pump();
      expect(writes, 1);
      expect(find.byType(PluginVisibilitySheet), findsOneWidget);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(PluginVisibilitySheet), findsNothing);
      expect(preferences.hiddenIds, {'a'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('plugin renames and uninstall updates keep the same ID draft', (
    tester,
  ) async {
    final plugins = ValueNotifier<List<DiscoverPluginVisibilityOption>>(
      _plugins,
    );
    addTearDown(plugins.dispose);
    final preferences = DiscoverPluginVisibility(
      read: () async => [],
      write: (_) async => true,
    );
    await _open(tester, preferences, plugins: plugins);
    await tester.tap(_switch('a'));
    await tester.pumpAndSettle();
    plugins.value = const [
      DiscoverPluginVisibilityOption(id: 'a', title: '新版名称'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('新版名称'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_switch('a')).value, isFalse);
    expect(_switch('b'), findsNothing);
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();
    expect(preferences.hiddenIds, {'a'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('management remains readable with large text on a narrow phone', (
    tester,
  ) async {
    final preferences = DiscoverPluginVisibility(
      read: () async => [],
      write: (_) async => true,
    );
    await _open(tester, preferences, scale: 1.8);
    expect(find.text(t.discover.visiblePlugins), findsOneWidget);
    expect(find.text(t.discover.visiblePluginsHint), findsOneWidget);
    expect(tester.getSize(_switch('a')).height, greaterThanOrEqualTo(44));
    await tester.tap(find.text(t.common.done));
    await tester.pumpAndSettle();
    expect(find.byType(PluginVisibilitySheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
