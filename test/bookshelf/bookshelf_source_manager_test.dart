import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_source_manager.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';

import '../test_helper.dart';

void main() {
  const sources = {'a': '插件甲', 'b': '插件乙', 'c': '插件丙'};
  Future<void> open(
    WidgetTester tester, {
    BookshelfSourcePreferences? initial,
    Map<String, String> names = sources,
    double scale = 1,
    bool useDisplayNames = false,
    required Future<void> Function(BookshelfSourcePreferences) save,
  }) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookshelfSourceManager(
                context: context,
                sources: names,
                useDisplayNames: useDisplayNames,
                initial: initial ?? BookshelfSourcePreferences(),
                onSave: save,
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

  group('Discover names', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
    tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

    testWidgets('shelf alias keeps the source ID and download uses its title', (
      tester,
    ) async {
      await savePluginDisplayName('a', '发现别名', expectedName: '');
      BookshelfSourcePreferences? saved;
      await open(
        tester,
        useDisplayNames: true,
        save: (value) async => saved = value,
      );
      final row = find.byKey(const ValueKey('source-manager.row.a'));
      expect(
        find.descendant(of: row, matching: find.text('发现别名')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('source-manager.visible.a')));
      await tester.tap(find.byKey(const ValueKey('source-manager.done')));
      await tester.pumpAndSettle();
      expect(saved?.hidden, {'a'});

      await open(tester, save: (_) async {});
      expect(
        find.descendant(of: row, matching: find.text('插件甲')),
        findsOneWidget,
      );
      expect(find.text('发现别名'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('source-manager.cancel')));
      await tester.pumpAndSettle();
    });
  });

  testWidgets(
    'visibility and reorder are a draft until Done, cancel discards all',
    (tester) async {
      var writes = 0;
      await open(tester, save: (_) async => writes++);
      await tester.tap(find.byKey(const ValueKey('source-manager.visible.a')));
      tester
          .widget<SliverReorderableList>(find.byType(SliverReorderableList))
          .onReorderItem!(2, 0);
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.byKey(const ValueKey('source-manager.cancel')));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.byType(BookshelfSourceManager), findsNothing);
    },
  );

  testWidgets('drag reorders stable IDs and Done persists hidden state', (
    tester,
  ) async {
    BookshelfSourcePreferences? saved;
    await open(tester, save: (v) async => saved = v);
    final drag = find.byKey(const ValueKey('source-manager.drag.c'));
    final first = find.byKey(const ValueKey('source-manager.row.a'));
    final beforeFirst = Offset(
      tester.getCenter(drag).dx,
      tester.getTopLeft(first).dy - 30,
    );
    final gesture = await tester.startGesture(tester.getCenter(drag));
    await tester.pump();
    await gesture.moveTo(beforeFirst);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-manager.visible.b')));
    await tester.tap(find.byKey(const ValueKey('source-manager.done')));
    await tester.pumpAndSettle();
    expect(saved?.order, ['c', 'a', 'b']);
    expect(saved?.hidden, {'b'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset restores visible default order as a cancelable draft', (
    tester,
  ) async {
    BookshelfSourcePreferences? saved;
    await open(
      tester,
      initial: BookshelfSourcePreferences(
        order: ['c', 'a', 'b'],
        hidden: ['a', 'b', 'c', 'missing'],
      ),
      save: (v) async => saved = v,
    );
    await tester.tap(find.byKey(const ValueKey('source-manager.reset')));
    await tester.pump();
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('source-manager.visible.a')),
          )
          .value,
      true,
    );
    await tester.tap(find.byKey(const ValueKey('source-manager.done')));
    await tester.pumpAndSettle();
    expect(saved?.order, isEmpty);
    expect(saved?.hidden, isEmpty);
  });

  testWidgets(
    '320 double text scrolls long names with a fixed full 44 point Done',
    (tester) async {
      await open(
        tester,
        scale: 2,
        names: {for (var i = 0; i < 15; i++) '$i': '较长的插件名称 $i'},
        save: (_) async {},
      );
      final done = find.byKey(const ValueKey('source-manager.done'));
      expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(done).bottom, lessThanOrEqualTo(740));
      await tester.drag(
        find.byKey(const ValueKey('source-manager.scroll')),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(const ValueKey('source-manager.cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save busy blocks duplicate writes and failure stays actionable',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(
        tester,
        save: (_) {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.byKey(const ValueKey('source-manager.done')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('source-manager.done')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('source-manager.cancel')),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BookshelfSourceManager), findsOneWidget);
      pending.completeError(StateError('failure'));
      await tester.pumpAndSettle();
      expect(find.text(t.error.saveFailed), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('source-manager.done')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('source-manager.cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
