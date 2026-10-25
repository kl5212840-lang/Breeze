import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final plugin = PluginRuntimeState(
    uuid: 'source-1',
    version: '1.0',
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

  Widget tile({
    bool enabled = true,
    VoidCallback? onOpen,
    ValueChanged<bool>? onToggle,
    bool showSearch = true,
    TextScaler textScaler = TextScaler.noScaling,
  }) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Center(
          child: SizedBox(
            width: 128,
            height: textScaler.scale(178),
            child: PluginGridTile(
              pluginState: plugin.copyWith(isEnabled: enabled),
              infoState: const DiscoverPluginInfoState(
                loading: false,
                data: {'name': '测试图源', 'iconUrl': ''},
              ),
              isToggling: false,
              onOpen: onOpen,
              onSearch: () {},
              showSearch: showSearch,
              onSettings: (_) {},
              onToggleEnabled: onToggle ?? (_) {},
              onRetry: () {},
              onAction: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('grid tile opens a source without clipping its title', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(tile(onOpen: () => opens++));
    await tester.tap(find.text('测试图源'));
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web-only tile omits unsupported comic search', (tester) async {
    await tester.pumpWidget(tile(onOpen: () {}, showSearch: false));
    await tester.tap(find.byTooltip(t.discover.moreActions(title: '测试图源')));
    await tester.pumpAndSettle();
    expect(find.text(t.sourceShell.search), findsNothing);
    expect(find.text(t.discover.settings), findsOneWidget);
  });

  testWidgets('disabled tile keeps an enable action in its menu', (
    tester,
  ) async {
    bool? requestedState;
    await tester.pumpWidget(
      tile(enabled: false, onToggle: (value) => requestedState = value),
    );
    await tester.tap(find.byTooltip(t.discover.moreActions(title: '测试图源')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.discover.enablePlugin));
    await tester.pumpAndSettle();
    expect(requestedState, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid tile grows with larger text', (tester) async {
    await tester.pumpWidget(
      tile(textScaler: const TextScaler.linear(1.7), onOpen: () {}),
    );
    expect(find.text('测试图源'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
