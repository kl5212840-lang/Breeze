import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

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
    VoidCallback? onSearch,
    ValueChanged<String>? onSettings,
    ValueChanged<bool>? onToggleEnabled,
    bool showSearch = true,
    TextScaler textScaler = TextScaler.noScaling,
    String name = '测试图源',
    double width = 128,
  }) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Center(
          child: SizedBox(
            width: width,
            height: 114 + 2 * textScaler.scale(16),
            child: PluginGridTile(
              pluginState: plugin.copyWith(isEnabled: enabled),
              infoState: DiscoverPluginInfoState(
                loading: false,
                data: {'name': name, 'iconUrl': ''},
              ),
              isToggling: false,
              onOpen: onOpen,
              onSearch: onSearch ?? () {},
              onSettings: onSettings ?? (_) {},
              onToggleEnabled: onToggleEnabled ?? (_) {},
              showSearch: showSearch,
              onRetry: () {},
              onAction: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );

  final management = find.byType(NativeVideoMenu);
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(management);
    await tester.pumpAndSettle();
  }

  testWidgets('grid tile opens a source without clipping its title', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(tile(onOpen: () => opens++));
    await tester.tap(find.text('测试图源'));
    expect(opens, 1);
    expect(tester.getSize(find.byType(PluginIcon)).width, greaterThan(68));
    expect(tester.getSize(management), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('web-only tile omits unsupported comic search', (tester) async {
    await tester.pumpWidget(tile(onOpen: () {}, showSearch: false));
    await openMenu(tester);
    expect(find.text(t.sourceShell.search), findsNothing);
    expect(find.text(t.discover.settings), findsOneWidget);
  });

  testWidgets('grid management has three independent actions', (tester) async {
    var opened = 0, searched = 0;
    final settings = <String>[];
    final toggles = <bool>[];
    await tester.pumpWidget(
      tile(
        onOpen: () => opened++,
        onSearch: () => searched++,
        onSettings: settings.add,
        onToggleEnabled: toggles.add,
      ),
    );
    expect(find.byTooltip(t.sourceShell.search), findsNothing);
    await openMenu(tester);
    expect(find.text(t.discover.settings), findsOneWidget);
    expect(find.text(t.discover.disablePlugin), findsOneWidget);
    await tester.tap(find.text(t.sourceShell.search));
    await tester.pumpAndSettle();
    expect(searched, 1);
    expect(opened, 0);
    await openMenu(tester);
    await tester.tap(find.text(t.discover.settings));
    await tester.pumpAndSettle();
    expect(settings, ['测试图源']);
    await openMenu(tester);
    await tester.tap(find.text(t.discover.disablePlugin));
    await tester.pumpAndSettle();
    expect(toggles, [false]);
    await tester.tap(find.text('测试图源'));
    expect(opened, 1);
    expect(searched, 1);
  });

  testWidgets('disabled tile keeps its status and can be re-enabled', (
    tester,
  ) async {
    var opened = 0;
    final toggles = <bool>[];
    await tester.pumpWidget(
      tile(
        enabled: false,
        onOpen: () => opened++,
        onToggleEnabled: toggles.add,
      ),
    );
    await tester.tap(find.text('测试图源'));
    expect(opened, 0);
    expect(find.byTooltip(t.discover.disabled), findsOneWidget);
    await openMenu(tester);
    expect(find.text(t.sourceShell.search), findsNothing);
    expect(find.text(t.discover.settings), findsOneWidget);
    await tester.tap(find.text(t.discover.enablePlugin));
    await tester.pumpAndSettle();
    expect(toggles, [true]);
  });

  testWidgets('narrow grid tile fits a long title at larger text sizes', (
    tester,
  ) async {
    const name = '名称较长的测试图源';
    await tester.pumpWidget(
      tile(
        width: 90,
        name: name,
        textScaler: const TextScaler.linear(2),
        onOpen: () {},
      ),
    );
    final title = find.text(name);
    expect(
      tester.getBottomLeft(title).dy,
      lessThanOrEqualTo(tester.getTopLeft(management).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
