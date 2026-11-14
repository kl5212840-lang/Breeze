import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/controller/reader_auto_read_controller.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('restarting smooth auto-read replaces its pending frame', (
    tester,
  ) async {
    final controller = ReaderAutoReadController();
    addTearDown(controller.dispose);
    controller.setVisible(true);
    void sync(bool enabled) => controller.sync(
      readSetting: ReadSettingState(
        autoScroll: enabled,
        autoScrollSmooth: true,
      ),
      readMode: 0,
      canTick: () => true,
      onTick: ({double? deltaMs}) {},
    );
    final scheduler = SchedulerBinding.instance;
    final otherCallbacks = scheduler.transientCallbackCount;
    sync(true);
    sync(false);
    sync(true);
    expect(scheduler.transientCallbackCount, otherCallbacks + 1);
    await tester.pump();
    controller.dispose();
    expect(scheduler.transientCallbackCount, otherCallbacks);
  });

  for (final smooth in [false, true]) {
    testWidgets('hidden auto-read suspends its clock (smooth: $smooth)', (
      tester,
    ) async {
      final controller = ReaderAutoReadController();
      addTearDown(controller.dispose);
      final setting = ReadSettingState(
        autoScroll: true,
        autoScrollSmooth: smooth,
        autoScrollColumnIntervalMs: 300,
      );
      final deltas = <double?>[];
      void tick({double? deltaMs}) => deltas.add(deltaMs);
      controller.sync(
        readSetting: setting,
        readMode: 0,
        canTick: () => true,
        onTick: tick,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(deltas, isEmpty);

      final interval = Duration(milliseconds: smooth ? 16 : 300);
      controller.setVisible(true);
      await tester.pump();
      await tester.pump(interval);
      expect(deltas, [smooth ? 16.0 : null]);

      controller.setVisible(false);
      final pending = SchedulerBinding.instance.transientCallbackCount;
      await tester.pump(const Duration(seconds: 2));
      expect(deltas, hasLength(1));
      expect(SchedulerBinding.instance.transientCallbackCount, pending);

      controller.setVisible(true);
      await tester.pump();
      await tester.pump(interval);
      expect(deltas, [smooth ? 16.0 : null, smooth ? 16.0 : null]);
      controller.togglePaused(
        readSetting: setting,
        readMode: 0,
        canTick: () => true,
        onTick: tick,
      );
      controller.setVisible(false);
      controller.setVisible(true);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isPaused, isTrue);
      expect(deltas, hasLength(2));
    });
  }

  test(
    'consecutive per-comic edits use the latest values and keep other overrides',
    () async {
      final cubit = ComicReadPreferenceCubit();
      addTearDown(cubit.close);
      const global = ReadSettingState();
      cubit.bind('reader-audit', 'consecutive');
      final unrelated = cubit.updateField(
        global,
        (current) => current.copyWith(readMode: 2),
      );
      final zoom = cubit.updateField(
        global,
        (current) => current.copyWith(doubleTapZoom: true),
      );
      final menu = cubit.updateField(
        global,
        (current) =>
            current.copyWith(doubleTapOpenMenu: true, doubleTapZoom: false),
      );
      expect(await unrelated, {'readMode'});
      expect(await zoom, {'doubleTapZoom'});
      expect(await menu, {'doubleTapOpenMenu', 'doubleTapZoom'});

      cubit.unbind();
      cubit.bind('reader-audit', 'consecutive');
      final override = cubit.state.override!;
      expect(override.setting.readMode, 2);
      expect(override.setting.doubleTapOpenMenu, isTrue);
      expect(override.setting.doubleTapZoom, isFalse);
    },
  );

  test('a pending edit or clear stays with its comic after a rebind', () async {
    final cubit = ComicReadPreferenceCubit();
    addTearDown(cubit.close);
    const global = ReadSettingState();
    cubit.bind('reader-audit', 'other-book');
    await cubit.updateField(
      global,
      (current) => current.copyWith(doubleTapZoom: true),
    );

    cubit.bind('reader-audit', 'edited-book');
    final edit = cubit.updateField(
      global,
      (current) => current.copyWith(readMode: 2),
    );
    cubit.bind('reader-audit', 'other-book');
    await edit;
    expect(cubit.state.override!.keys, {'doubleTapZoom'});

    cubit.bind('reader-audit', 'edited-book');
    expect(cubit.state.override!.keys, {'readMode'});
    final clear = cubit.clearOverride();
    cubit.bind('reader-audit', 'other-book');
    await clear;
    expect(cubit.state.override!.keys, {'doubleTapZoom'});

    cubit.bind('reader-audit', 'edited-book');
    expect(cubit.state.hasOverride, isFalse);
  });

  test(
    'a persisted explicit default keeps only its own override across global changes and book switches',
    () async {
      final cubit = ComicReadPreferenceCubit();
      addTearDown(cubit.close);
      const global = ReadSettingState(readMode: 2, autoScroll: true);
      cubit.bind('reader-audit', 'first');
      await cubit.updateField(
        global,
        (current) => current.copyWith(readMode: 0),
      );
      cubit.bind('reader-audit', 'second');
      expect(cubit.state.hasOverride, isFalse);
      cubit.bind('reader-audit', 'first');
      expect(cubit.state.override!.keys, {'readMode'});
      final changedGlobal = global.copyWith(
        autoScroll: false,
        autoScrollColumnIntervalMs: 900,
        readerBackgroundMode: ReaderBackgroundMode.grey,
      );
      final effective = ComicReadPreferenceService.resolveEffective(
        changedGlobal,
        cubit.state.override,
      );
      expect(effective.readMode, 0);
      expect(effective.autoScroll, isFalse);
      expect(effective.autoScrollColumnIntervalMs, 900);
      expect(effective.readerBackgroundMode, ReaderBackgroundMode.grey);
      await cubit.clearOverride();
      cubit.bind('reader-audit', 'second');
      cubit.bind('reader-audit', 'first');
      expect(cubit.state.hasOverride, isFalse);
      expect(
        ComicReadPreferenceService.resolveEffective(
          changedGlobal,
          cubit.state.override,
        ),
        changedGlobal,
      );
      cubit.unbind();
      expect(cubit.state.uniqueKey, isEmpty);
    },
  );

  testWidgets(
    'actual auto-reader changes cadence by mode and stops while blocked or disabled',
    (tester) async {
      final controller = ReaderAutoReadController();
      addTearDown(controller.dispose);
      controller.setVisible(true);
      var ticks = 0;
      var active = true;
      var setting = const ReadSettingState(
        autoScroll: true,
        autoScrollColumnIntervalMs: 300,
        autoScrollPageIntervalMs: 800,
      );
      void sync(int mode) => controller.sync(
        readSetting: setting,
        readMode: mode,
        canTick: () => active,
        onTick: ({double? deltaMs}) => ticks++,
      );
      sync(0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ticks, 1);
      sync(1);
      await tester.pump(const Duration(milliseconds: 799));
      expect(ticks, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ticks, 2);
      active = false;
      await tester.pump(const Duration(milliseconds: 1600));
      expect(ticks, 2);
      active = true;
      await tester.pump(const Duration(milliseconds: 800));
      expect(ticks, 3);
      setting = setting.copyWith(autoScroll: false);
      sync(1);
      await tester.pump(const Duration(seconds: 2));
      expect(ticks, 3);
    },
  );
}
