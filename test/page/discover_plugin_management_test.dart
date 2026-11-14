import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/page/discover/service/discover_plugin_management.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';
import 'package:zephyr/page/discover/view/plugin_management_island.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

const options = [
  DiscoverPluginManagementOption(id: 'b', title: '同名插件'),
  DiscoverPluginManagementOption(id: 'a', title: '同名插件'),
];
Finder control(String id) => find.byKey(ValueKey('plugin-manager.$id'));
Finder visible(String id) => control('visible.$id');

void main() {
  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(DiscoverPluginManagementDraft) save,
    Set<String> hidden = const {'absent'},
    double scale = 1,
    double keyboard = 0,
    ValueNotifier<List<DiscoverPluginManagementOption>>? plugins,
    Future<void> Function(DiscoverPluginManagementOption)? onSettings,
    Future<void> Function(String, bool)? onToggleEnabled,
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
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookshelfManagementIsland<void>(
                context: context,
                builder: (_) => plugins == null
                    ? PluginManagementIsland(
                        plugins: options,
                        defaultOrder: const ['a', 'b'],
                        hiddenIds: hidden,
                        onSave: save,
                        onSettings: onSettings,
                        onToggleEnabled: onToggleEnabled,
                      )
                    : ValueListenableBuilder<
                        List<DiscoverPluginManagementOption>
                      >(
                        valueListenable: plugins,
                        builder: (_, values, _) => PluginManagementIsland(
                          plugins: values,
                          defaultOrder: const ['a', 'b', 'c'],
                          hiddenIds: hidden,
                          onSave: save,
                          onSettings: onSettings,
                          onToggleEnabled: onToggleEnabled,
                        ),
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

  void reorder(WidgetTester tester, int from, int to) => tester
      .widget<SliverReorderableList>(find.byType(SliverReorderableList))
      .onReorderItem!(from, to);

  testWidgets(
    'combined draft includes icons and duplicate IDs; reset and cancel never persist',
    (tester) async {
      var saves = 0;
      await open(
        tester,
        save: (_) async {
          saves++;
        },
        hidden: {'a', 'absent'},
      );
      expect(find.byType(PluginIcon), findsNWidgets(2));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      await tester.tap(visible('b'));
      reorder(tester, 1, 0);
      await tester.pump();
      await tester.tap(control('reset'));
      await tester.pump();
      expect(tester.widget<Switch>(visible('a')).value, isTrue);
      expect(tester.widget<Switch>(visible('b')).value, isTrue);
      expect(saves, 0);
      await tester.tap(control('cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.byType(PluginManagementIsland), findsNothing);
    },
  );

  testWidgets(
    'one save commits hidden and reordered IDs together while preserving absent IDs',
    (tester) async {
      DiscoverPluginManagementDraft? saved;
      await open(
        tester,
        save: (draft) async {
          saved = draft;
        },
      );
      await tester.tap(visible('a'));
      await tester.tap(visible('b'));
      reorder(tester, 1, 0);
      await tester.pump();
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(saved!.order, ['a', 'b']);
      expect(saved!.hiddenIds, {'a', 'b', 'absent'});
      expect(saved!.restoreDefaultOrder, isFalse);
      expect(find.byType(PluginManagementIsland), findsNothing);
    },
  );

  testWidgets(
    'default order reset stays a draft and only Done commits its reset intent',
    (tester) async {
      DiscoverPluginManagementDraft? saved;
      await open(
        tester,
        hidden: {'a', 'absent'},
        save: (draft) async {
          saved = draft;
        },
      );
      await tester.tap(control('reset'));
      await tester.pump();
      expect(saved, isNull);
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(saved!.restoreDefaultOrder, isTrue);
      expect(saved!.order, ['a', 'b']);
      expect(saved!.hiddenIds, {'absent'});
    },
  );

  testWidgets(
    'runtime actions target hidden sources without committing the visibility draft',
    (tester) async {
      final settings = <String>[];
      final toggles = <(String, bool)>[];
      var saves = 0;
      final plugins = ValueNotifier<List<DiscoverPluginManagementOption>>([
        const DiscoverPluginManagementOption(
          id: 'a',
          title: '待启用的来源',
          enabled: false,
        ),
      ]);
      addTearDown(plugins.dispose);
      await open(
        tester,
        plugins: plugins,
        hidden: {'a'},
        scale: 2,
        onSettings: (plugin) async => settings.add(plugin.id),
        onToggleEnabled: (id, enabled) async => toggles.add((id, enabled)),
        save: (_) async => saves++,
      );
      await tester.tap(control('actions.a'));
      await tester.pumpAndSettle();
      final setting = control('settings.a');
      final toggle = control('enabled.a');
      await tester.ensureVisible(setting);
      await tester.pumpAndSettle();
      await tester.tap(setting);
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings, ['a']);
      expect(toggles, [('a', true)]);
      expect(tester.widget<Switch>(visible('a')).value, isFalse);
      plugins.value = const [
        DiscoverPluginManagementOption(id: 'a', title: '待启用的来源'),
      ];
      await tester.pumpAndSettle();
      expect(find.text(t.discover.disablePlugin), findsOneWidget);
      expect(tester.widget<Switch>(visible('a')).value, isFalse);
      expect(tester.takeException(), isNull);
      await tester.tap(control('cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    },
  );

  testWidgets(
    'busy prevents close/back/duplicate saves and failure keeps the draft for retry',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      final drafts = <DiscoverPluginManagementDraft>[];
      await open(
        tester,
        save: (draft) {
          drafts.add(draft);
          return ++calls == 1 ? pending.future : Future.value();
        },
      );
      await tester.tap(visible('a'));
      await tester.tap(control('save'));
      await tester.pump();
      expect(tester.widget<Switch>(visible('a')).onChanged, isNull);
      expect(
        tester.widget<ReorderableDragStartListener>(control('drag.a')).enabled,
        isFalse,
      );
      await tester.tapAt(const Offset(3, 3));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PluginManagementIsland), findsOneWidget);
      expect(calls, 1);
      pending.completeError(StateError('local write failed'));
      await tester.pumpAndSettle();
      expect(find.text(t.error.saveFailed), findsOneWidget);
      expect(tester.widget<Switch>(visible('a')).value, isFalse);
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(drafts.last.hiddenIds, drafts.first.hiddenIds);
      expect(find.byType(PluginManagementIsland), findsNothing);
    },
  );

  testWidgets(
    '320 double text keyboard remains readable with complete 44pt footer and internal scrolling',
    (tester) async {
      final plugins = ValueNotifier<List<DiscoverPluginManagementOption>>([
        for (var i = 0; i < 8; i++)
          DiscoverPluginManagementOption(id: 'p$i', title: '较长的插件名称 第 $i 个'),
      ]);
      addTearDown(plugins.dispose);
      await open(
        tester,
        scale: 2,
        keyboard: 280,
        plugins: plugins,
        save: (_) async {},
      );
      expect(find.byType(BottomSheet), findsNothing);
      for (final id in ['cancel', 'save', 'close']) {
        expect(tester.getSize(control(id)).height, greaterThanOrEqualTo(44));
        expect(tester.getRect(control(id)).bottom, lessThanOrEqualTo(460));
      }
      expect(tester.getSize(visible('p0')).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      await tester.tap(control('cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'renames and uninstall changes preserve per-ID choices without restoring removed rows',
    (tester) async {
      final plugins = ValueNotifier<List<DiscoverPluginManagementOption>>(
        options,
      );
      addTearDown(plugins.dispose);
      DiscoverPluginManagementDraft? saved;
      await open(
        tester,
        plugins: plugins,
        save: (draft) async {
          saved = draft;
        },
      );
      await tester.tap(visible('a'));
      plugins.value = const [
        DiscoverPluginManagementOption(id: 'a', title: '新版名称'),
        DiscoverPluginManagementOption(id: 'c', title: '新增插件'),
      ];
      await tester.pumpAndSettle();
      expect(find.text('新版名称'), findsOneWidget);
      expect(visible('b'), findsNothing);
      expect(tester.widget<Switch>(visible('a')).value, isFalse);
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(saved!.order, ['a', 'c']);
      expect(saved!.hiddenIds, {'a', 'absent'});
    },
  );

  test(
    'visibility failure restores prior effective order and retry applies the full draft',
    () async {
      var actualOrder = ['b', 'a'], writes = 0;
      final prefs = DiscoverPluginVisibility(
        read: () async => ['absent'],
        write: (_) async => ++writes > 1,
      );
      addTearDown(prefs.dispose);
      await prefs.load();
      final draft = DiscoverPluginManagementDraft(
        order: ['a', 'b'],
        hiddenIds: {'a', 'absent'},
      );
      Future<void> save() => saveDiscoverPluginManagement(
        draft: draft,
        visibility: prefs,
        previousOrder: ['b', 'a'],
        writeOrder: (ids) async {
          actualOrder = [...ids];
        },
        resetOrder: () async {
          actualOrder = ['a', 'b'];
        },
      );
      await expectLater(save(), throwsStateError);
      expect(actualOrder, ['b', 'a']);
      expect(prefs.hiddenIds, {'absent'});
      await save();
      expect(actualOrder, ['a', 'b']);
      expect(prefs.hiddenIds, {'a', 'absent'});
    },
  );

  test(
    'failed order never writes visibility and reset uses the existing registry reset callback',
    () async {
      var visibilityWrites = 0, orderWrites = 0, resets = 0;
      final prefs = DiscoverPluginVisibility(
        read: () async => [],
        write: (_) async {
          visibilityWrites++;
          return true;
        },
      );
      addTearDown(prefs.dispose);
      await prefs.load();
      await expectLater(
        saveDiscoverPluginManagement(
          draft: DiscoverPluginManagementDraft(
            order: ['a', 'b'],
            hiddenIds: {'a'},
          ),
          visibility: prefs,
          previousOrder: ['b', 'a'],
          writeOrder: (ids) async {
            if (++orderWrites == 1) throw StateError('partial order write');
          },
          resetOrder: () async {},
        ),
        throwsStateError,
      );
      expect(visibilityWrites, 0);
      expect(orderWrites, 2);
      expect(prefs.hiddenIds, isEmpty);
      await saveDiscoverPluginManagement(
        draft: DiscoverPluginManagementDraft(
          order: ['a', 'b'],
          hiddenIds: {'absent'},
          restoreDefaultOrder: true,
        ),
        visibility: prefs,
        previousOrder: ['b', 'a'],
        writeOrder: (_) async {},
        resetOrder: () async {
          resets++;
        },
      );
      expect(resets, 1);
      expect(prefs.hiddenIds, {'absent'});
    },
  );
}
