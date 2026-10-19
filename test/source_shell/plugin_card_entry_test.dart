import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  final now = DateTime(2026, 1, 1);
  final enabledPlugin = PluginRuntimeState(
    uuid: 'copy-source',
    version: '0.0.15',
    originScript: '',
    isEnabled: true,
    isDeleted: false,
    debug: false,
    debugUrl: null,
    lastLoadSuccess: true,
    lastLoadError: null,
    sortOrder: 0,
    insertedAt: now,
    updatedAt: now,
    deletedAt: null,
  );

  Widget card({required bool enabled, required VoidCallback? onOpen}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PluginCard(
            pluginUuid: 'copy-source',
            pluginState: enabledPlugin.copyWith(isEnabled: enabled),
            infoState: const DiscoverPluginInfoState(
              loading: false,
              data: {
                'name': '测试图源',
                'iconUrl': '',
                'function': [
                  {
                    'id': 'recommend',
                    'title': '推荐栏目',
                    'action': {'type': 'openComicList'},
                  },
                  {
                    'id': 'tool',
                    'title': '独立工具',
                    'action': {'type': 'openSearch'},
                  },
                ],
              },
            ),
            isToggling: false,
            onSearch: () {},
            onOpen: onOpen,
            onSettings: (_) {},
            onToggleEnabled: (_) {},
            onRetry: () {},
            onAction: (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets('enabled source has a single-tap entry', (tester) async {
    var opened = 0;
    await tester.pumpWidget(card(enabled: true, onOpen: () => opened++));

    expect(find.text(t.sourceShell.enter), findsOneWidget);
    expect(find.text('推荐栏目'), findsNothing);
    expect(find.text('独立工具'), findsOneWidget);
    await tester.tap(find.text(t.sourceShell.enter));
    expect(opened, 1);
  });

  testWidgets('disabled source does not expose the entry', (tester) async {
    await tester.pumpWidget(card(enabled: false, onOpen: () {}));

    expect(find.text(t.sourceShell.enter), findsNothing);
  });

  testWidgets('legacy shortcuts remain when no source shell is available', (
    tester,
  ) async {
    await tester.pumpWidget(card(enabled: true, onOpen: null));

    expect(find.text('推荐栏目'), findsOneWidget);
    expect(find.text('独立工具'), findsOneWidget);
  });
}
