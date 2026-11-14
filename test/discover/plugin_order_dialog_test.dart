import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/page/discover/view/plugin_order_dialog.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

void main() {
  PluginRuntimeState plugin(String id) => PluginRuntimeState(
    uuid: id,
    version: '1',
    originScript: '',
    isEnabled: true,
    isDeleted: false,
    debug: false,
    debugUrl: null,
    lastLoadSuccess: true,
    lastLoadError: null,
    sortOrder: null,
    insertedAt: DateTime(2026),
    updatedAt: DateTime(2026),
    deletedAt: null,
  );
  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(List<String>) save,
    required Future<void> Function() reset,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookshelfManagementIsland<void>(
                context: context,
                builder: (_) => PluginOrderDialog(
                  initialPlugins: [plugin('插件甲'), plugin('插件乙')],
                  onSave: save,
                  onReset: reset,
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'plugin order uses a shrinking island and cancel leaves registry untouched',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        save: (_) async {
          calls++;
        },
        reset: () async {
          calls++;
        },
      );
      tester
          .widget<SliverReorderableList>(find.byType(SliverReorderableList))
          .onReorderItem!(1, 0);
      await tester.pump();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('bookshelf.island.surface')))
            .height,
        lessThan(350),
      );
      await tester.tap(find.byKey(const ValueKey('plugin-order.cancel')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final reset in [false, true]) {
    testWidgets(
      '${reset ? 'reset' : 'save'} failure stays in place and busy blocks outside/back',
      (tester) async {
        final pending = Completer<void>();
        var calls = 0;
        Future<void> write() {
          calls++;
          return calls == 1 ? pending.future : Future<void>.value();
        }

        await open(tester, save: (_) => write(), reset: write);
        final action = find.byKey(
          ValueKey(reset ? 'plugin-order.reset' : 'plugin-order.save'),
        );
        await tester.tap(action);
        await tester.pump();
        await tester.tapAt(const Offset(4, 4));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(PluginOrderDialog), findsOneWidget);
        expect(calls, 1);
        pending.completeError(StateError('failed'));
        await tester.pumpAndSettle();
        expect(find.text(t.error.saveFailed), findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.byType(PluginOrderDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
