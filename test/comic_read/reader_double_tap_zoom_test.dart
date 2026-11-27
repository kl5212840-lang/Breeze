import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/controller/reader_action_controller.dart';
import 'package:zephyr/page/comic_read/controller/reader_input_controller.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/page/comic_read/widgets/navigation/vertical_pull_navigator.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';

class _SettingsCubit extends GlobalSettingCubit {
  _SettingsCubit(ReadSettingState setting) {
    emit(state.copyWith(readSetting: setting));
  }

  @override
  void updateReadSetting(
    ReadSettingState Function(ReadSettingState current) updates,
  ) {
    emit(state.copyWith(readSetting: updates(state.readSetting)));
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.scrollPages, this.onPullNext});

  final bool scrollPages;
  final Future<void> Function()? onPullNext;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  final _page = PageController();
  final _scroll = ScrollController();
  late final ReaderInputController _input;
  bool locked = false;
  int menuToggles = 0;

  @override
  void initState() {
    super.initState();
    _input = ReaderInputController(
      context: context,
      readerCubit: context.read<ReaderCubit>(),
      pageController: _page,
      transformationController: transform,
      vsync: this,
      onToggleMenu: () => menuToggles++,
      onToggleDesktopFullscreen: () async {},
      onRefreshState: () => setState(() {}),
      isScrollLockedByMultiTouch: () => locked,
      onUpdateScrollLock: (value) => setState(() => locked = value),
      buildColumnMode: (_) => _buildColumnMode(),
      buildRowMode: () => widget.scrollPages
          ? PageView.builder(
              controller: _page,
              physics: locked ? const NeverScrollableScrollPhysics() : null,
              reverse: isReverseRowReadMode(context.readEffectiveReadMode()),
              itemCount: 5,
              itemBuilder: (_, _) => const ColoredBox(color: Colors.white),
            )
          : const ColoredBox(color: Colors.white),
    );
    _input.setActionController(
      ReaderActionController(
        context: context,
        scrollController: _scroll,
        pageController: _page,
        onBeforeTurnPage: _input.restoreScaleBeforeTurnPage,
      ),
    );
    _input.init();
  }

  @override
  Widget build(BuildContext context) => _input.buildInteractiveViewer();

  Widget _buildColumnMode() {
    if (!widget.scrollPages) return const ColoredBox(color: Colors.white);
    Widget buildList(ScrollPhysics physics) => ListView.builder(
      controller: _scroll,
      physics: locked ? NeverScrollableScrollPhysics(parent: physics) : physics,
      itemCount: 5,
      itemExtent: 300,
      itemBuilder: (_, _) => const ColoredBox(color: Colors.white),
    );
    final onPullNext = widget.onPullNext;
    if (onPullNext == null) return buildList(const ClampingScrollPhysics());
    return VerticalPullNavigator(
      havePrev: false,
      haveNext: true,
      onPrev: () async {},
      onNext: onPullNext,
      builder: (_, physics) => buildList(physics),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _page.dispose();
    transform.dispose();
    super.dispose();
  }
}

Future<_SettingsCubit> _mount(
  WidgetTester tester, {
  required ReadSettingState setting,
  bool reduceMotion = false,
  bool openSettings = false,
  bool scrollPages = false,
  Future<void> Function()? onPullNext,
}) async {
  final settings = _SettingsCubit(setting);
  final preferences = ComicReadPreferenceCubit();
  final reader = ReaderCubit();
  addTearDown(settings.close);
  addTearDown(preferences.close);
  addTearDown(reader.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GlobalSettingCubit>.value(value: settings),
        BlocProvider.value(value: preferences),
        BlocProvider.value(value: reader),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: openSettings
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showReaderSettingsSheet(context),
                      child: const Text('Open'),
                    ),
                  )
                : SizedBox(
                    width: 400,
                    height: 500,
                    child: _Viewer(
                      scrollPages: scrollPages,
                      onPullNext: onPullNext,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
  return settings;
}

Future<void> _doubleTap(WidgetTester tester, {Offset? localPosition}) async {
  final origin = tester.getTopLeft(find.byType(InteractiveViewer));
  final point = origin + (localPosition ?? const Offset(60, 140));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(point);
  await tester.pump();
}

void main() {
  test('the new setting defaults off and keeps sparse inheritance', () {
    final old = ReadSettingState.fromJson({'doubleTapZoom': true});
    expect(old.doubleTapZoomAnimation, isFalse);
    final global = old.copyWith(doubleTapZoomAnimation: true);
    expect(ReadSettingState.fromJson(global.toJson()), global);
    final inherited = ComicReadPreferenceService.resolveEffective(global, (
      setting: old,
      keys: {'doubleTapZoom'},
    ));
    final explicit = ComicReadPreferenceService.resolveEffective(global, (
      setting: old,
      keys: {'doubleTapZoomAnimation'},
    ));
    expect(inherited.doubleTapZoomAnimation, isTrue);
    expect(explicit.doubleTapZoomAnimation, isFalse);
  });

  testWidgets('zoom animation is only offered while double-tap zoom is on', (
    tester,
  ) async {
    final settings = await _mount(
      tester,
      setting: const ReadSettingState(),
      openSettings: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, t.reader.gesture));
    await tester.pumpAndSettle();

    final zoom = find.text(t.reader.doubleTapZoom);
    final animation = find.text(t.reader.doubleTapZoomAnimation);
    expect(animation, findsNothing);
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    expect(animation, findsOneWidget);
    expect(settings.state.readSetting.doubleTapZoomAnimation, isFalse);
    await tester.ensureVisible(animation);
    await tester.tap(animation);
    await tester.pumpAndSettle();
    expect(settings.state.readSetting.doubleTapZoomAnimation, isTrue);
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    expect(animation, findsNothing);
    expect(settings.state.readSetting.doubleTapZoomAnimation, isTrue);
  });

  testWidgets('double tap animates both ways and stops at a new page', (
    tester,
  ) async {
    await _mount(
      tester,
      setting: const ReadSettingState(
        doubleTapZoom: true,
        doubleTapZoomAnimation: true,
      ),
    );
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    double scale() => viewer.transform.value.getMaxScaleOnAxis();

    await _doubleTap(tester);
    expect(scale(), 1);
    expect(viewer.locked, isTrue);
    await tester.pump(const Duration(milliseconds: 70));
    expect(scale(), inExclusiveRange(1, kDoubleTapZoomScale));
    await tester.pump(const Duration(milliseconds: 110));
    expect(scale(), kDoubleTapZoomScale);
    expect(viewer.transform.value.storage[12], closeTo(0, .01));
    expect(viewer.transform.value.storage[13], closeTo(-100, .01));
    expect(viewer.menuToggles, 0);

    await _doubleTap(tester);
    expect(scale(), kDoubleTapZoomScale);
    await tester.pump(const Duration(milliseconds: 70));
    expect(scale(), inExclusiveRange(1, kDoubleTapZoomScale));
    await tester.pump(const Duration(milliseconds: 110));
    expect(scale(), 1);
    expect(viewer.locked, isFalse);

    await _doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 50));
    viewer.context.read<ReaderCubit>().updateCurrentSlot(2);
    await tester.pump(const Duration(milliseconds: 16));
    expect(scale(), 1);
    expect(viewer.locked, isFalse);
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), 1);

    await _doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 24));
    expect(scale(), inExclusiveRange(1, kDoubleTapZoomScale));
    await _doubleTap(tester);
    expect(scale(), inExclusiveRange(1, kDoubleTapZoomScale));
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), 1);
    expect(viewer.menuToggles, 0);
  });

  for (final animate in [false, true]) {
    testWidgets(
      'a zoomed vertical drag crosses the viewport boundary (animate $animate)',
      (tester) async {
        await _mount(
          tester,
          setting: ReadSettingState(
            doubleTapZoom: true,
            doubleTapZoomAnimation: animate,
          ),
          scrollPages: true,
        );
        final frame = tester.getRect(find.byType(InteractiveViewer));
        final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
        viewer._scroll.jumpTo(300);
        await tester.pump();
        await _doubleTap(tester, localPosition: const Offset(200, 350));
        await tester.pumpAndSettle();
        double y() => viewer.transform.value.storage[13];
        double scale() => viewer.transform.value.getMaxScaleOnAxis();
        expect(scale(), kDoubleTapZoomScale);
        expect(y(), closeTo(-625, .001));

        final finger = await tester.startGesture(frame.center);
        await tester.pump(const Duration(milliseconds: 60));
        await finger.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 60));
        final beforeCrossing = y();
        expect(viewer._scroll.offset, 300);
        await finger.moveBy(const Offset(0, -150));
        await tester.pump();
        expect(y(), closeTo(-750, .001));
        final afterCrossing = 300 + (150 - (beforeCrossing + 750)) / scale();
        expect(viewer._scroll.offset, closeTo(afterCrossing, .001));

        await finger.moveBy(const Offset(70, -50));
        await tester.pump();
        expect(viewer._scroll.offset, closeTo(afterCrossing + 20, .001));
        await finger.moveBy(const Offset(0, 45));
        await tester.pump();
        expect(y(), closeTo(-705, .001));
        expect(viewer._scroll.offset, closeTo(afterCrossing + 20, .001));
        await finger.cancel();
        await tester.pumpAndSettle();
        expect(viewer._scroll.offset, closeTo(afterCrossing + 20, .001));
        expect(scale(), kDoubleTapZoomScale);
        expect(viewer.menuToggles, 0);

        await _doubleTap(tester);
        await tester.pumpAndSettle();
        expect(scale(), 1);
        expect(viewer.locked, isFalse);
        await tester.dragFrom(frame.center, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(viewer._scroll.offset, greaterThan(afterCrossing + 20));
      },
    );
  }

  testWidgets('a pinched viewport passes a continuous drag to the list', (
    tester,
  ) async {
    await _mount(tester, setting: const ReadSettingState(), scrollPages: true);
    final frame = tester.getRect(find.byType(InteractiveViewer));
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    viewer._scroll.jumpTo(300);
    await tester.pump();

    final left = await tester.startGesture(
      frame.topLeft + const Offset(155, 380),
    );
    final right = await tester.startGesture(
      frame.topLeft + const Offset(245, 380),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await left.moveBy(const Offset(-55, 0));
    await right.moveBy(const Offset(70, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await right.up();
    await left.up();
    await tester.pumpAndSettle();
    final scale = viewer.transform.value.getMaxScaleOnAxis();
    expect(scale, greaterThan(1.4));
    expect(viewer._scroll.offset, 300);

    final finger = await tester.startGesture(frame.center);
    await tester.pump(const Duration(milliseconds: 60));
    await finger.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 60));
    final before = viewer.transform.value.storage[13];
    await finger.moveBy(const Offset(0, -200));
    await tester.pump();
    final lowerEdge = frame.height * (1 - scale);
    expect(viewer.transform.value.storage[13], closeTo(lowerEdge, .001));
    expect(
      viewer._scroll.offset,
      closeTo(300 + (200 - (before - lowerEdge)) / scale, .001),
    );
    await finger.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('zoomed scrolling can pull at the real chapter boundary', (
    tester,
  ) async {
    var nextChapterPulls = 0;
    await _mount(
      tester,
      setting: const ReadSettingState(doubleTapZoom: true),
      scrollPages: true,
      onPullNext: () async => nextChapterPulls++,
    );
    final frame = tester.getRect(find.byType(InteractiveViewer));
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    final end = viewer._scroll.position.maxScrollExtent;
    viewer._scroll.jumpTo(end - 180);
    await tester.pump();
    await _doubleTap(tester, localPosition: const Offset(200, 455));
    expect(viewer.transform.value.storage[13], closeTo(-750, .001));
    await tester.dragFrom(
      frame.bottomCenter - const Offset(0, 10),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(viewer._scroll.offset, greaterThan(end - 180));
    expect(nextChapterPulls, 0);

    viewer._scroll.jumpTo(end);
    await tester.pump();
    final finger = await tester.startGesture(
      frame.bottomCenter - const Offset(0, 10),
    );
    await finger.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 60));
    await finger.moveBy(const Offset(0, -390));
    await tester.pump(const Duration(milliseconds: 60));
    expect(nextChapterPulls, 0);
    await finger.up();
    await tester.pumpAndSettle();
    expect(nextChapterPulls, 1);
  });

  for (final (name, readMode, delta, viewport) in [
    (
      'continuous vertical',
      kReadModeColumn,
      const Offset(0, -12),
      const Size(400, 700),
    ),
    (
      'left-to-right pages',
      kReadModeRowLtr,
      const Offset(-12, 0),
      const Size(700, 400),
    ),
    (
      'right-to-left pages',
      kReadModeRowRtl,
      const Offset(12, 0),
      const Size(400, 700),
    ),
  ]) {
    testWidgets('a short $name swipe does not toggle menu', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _mount(
        tester,
        setting: ReadSettingState(
          readMode: readMode,
          customToolbarTapArea: true,
        ),
        scrollPages: true,
      );

      final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.moveBy(delta);
      await gesture.moveBy(-delta);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(viewer.menuToggles, 0);

      final deliberateTap = await tester.startGesture(center);
      await deliberateTap.moveBy(delta / 3);
      await deliberateTap.up();
      await tester.pumpAndSettle();
      expect(viewer.menuToggles, 1);

      await tester.dragFrom(center, delta * 22);
      await tester.pumpAndSettle();
      expect(viewer.menuToggles, 1);
      if (isColumnReadMode(readMode)) {
        expect(viewer._scroll.offset, greaterThan(0));
      } else {
        expect(viewer._page.page, 1);
        await tester.tapAt(center + const Offset(140, 0));
        await tester.pumpAndSettle();
        expect(viewer._page.page, 2);
        expect(viewer.menuToggles, 1);
      }
    });
  }

  testWidgets('narrow webtoon uses a full-height custom toolbar zone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final settings = await _mount(
      tester,
      setting: const ReadSettingState(
        readMode: 0,
        customToolbarTapArea: true,
        toolbarTapAreaPercent: 40,
      ),
      scrollPages: true,
    );

    final frame = tester.getRect(find.byType(InteractiveViewer));
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    final left = Offset(frame.left + frame.width * .29, frame.center.dy);
    final right = Offset(frame.right - frame.width * .29, frame.center.dy);
    final inside = Offset(frame.left + frame.width * .31, frame.top + 20);

    for (final side in [left, right]) {
      await tester.tapAt(side);
      await tester.pumpAndSettle();
      expect(viewer.menuToggles, 0);
      expect(viewer._scroll.offset, 0);
    }
    await tester.tapAt(inside);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 1);

    final scroll = await tester.startGesture(left);
    await tester.pump(const Duration(milliseconds: 100));
    await scroll.moveBy(const Offset(0, -45));
    await scroll.moveBy(Offset(frame.width * .4, -90));
    await scroll.up();
    await tester.pumpAndSettle();
    expect(viewer._scroll.offset, greaterThan(0));
    expect(viewer.menuToggles, 1);

    final cancelled = await tester.startGesture(frame.center);
    await tester.pump(const Duration(milliseconds: 100));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 1);

    settings.updateReadSetting(
      (value) => value.copyWith(
        tapPageTurnInWebtoon: true,
        tapPageTurnMode: ReaderTapPageTurnMode.fullScreen,
      ),
    );
    await tester.pumpAndSettle();
    final beforeTurn = viewer._scroll.offset;
    await tester.tapAt(right);
    await tester.pumpAndSettle();
    expect(viewer._scroll.offset, greaterThan(beforeTurn));
    expect(viewer.menuToggles, 1);
  });

  test('toolbar area defaults off and bounds restored settings', () {
    final previous = ReadSettingState.fromJson({});
    expect(previous.customToolbarTapArea, isFalse);
    expect(previous.toolbarTapAreaPercent, 50);
    final custom = previous.copyWith(
      customToolbarTapArea: true,
      toolbarTapAreaPercent: 64,
    );
    expect(ReadSettingState.fromJson(custom.toJson()), custom);
    expect(
      ReadSettingState.fromJson({
        'toolbarTapAreaPercent': 95,
      }).toolbarTapAreaPercent,
      70,
    );
  });

  testWidgets('default toolbar area accepts a side tap, but not a stop tap', (
    tester,
  ) async {
    await _mount(tester, setting: const ReadSettingState(), scrollPages: true);
    final frame = tester.getRect(find.byType(InteractiveViewer));
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    final side = Offset(frame.left + 40, frame.center.dy);

    await tester.flingFrom(side, const Offset(0, -130), 1000);
    await tester.pump(const Duration(milliseconds: 16));
    expect(viewer._scroll.position.isScrollingNotifier.value, isTrue);
    await tester.tapAt(side);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 0);

    await tester.tapAt(side);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 1);
  });

  testWidgets('both taps respect the custom area for an opted-in menu', (
    tester,
  ) async {
    await _mount(
      tester,
      setting: const ReadSettingState(
        customToolbarTapArea: true,
        doubleTapOpenMenu: true,
      ),
    );
    final frame = tester.getRect(find.byType(InteractiveViewer));
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    viewer.context.read<ReaderCubit>().updateMenuVisible(visible: false);
    final outside = Offset(frame.left + frame.width * .24, frame.center.dy);
    final inside = Offset(frame.left + frame.width * .26, frame.center.dy);

    await tester.tapAt(outside);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(inside);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 0);

    await tester.tapAt(inside);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(inside);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 1);
  });

  testWidgets('a swipe in either tap cannot open the double-tap menu', (
    tester,
  ) async {
    await _mount(
      tester,
      setting: const ReadSettingState(doubleTapOpenMenu: true),
      scrollPages: true,
    );
    final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
    viewer.context.read<ReaderCubit>().updateMenuVisible(visible: false);
    final center = tester.getCenter(find.byType(InteractiveViewer));

    Future<void> shortSwipe() async {
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, -12));
      await gesture.up();
    }

    await shortSwipe();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 0);

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await shortSwipe();
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 0);

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 1);

    viewer.context.read<ReaderCubit>().updateMenuVisible(visible: true);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(viewer.menuToggles, 2);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('zoom is immediate with reduced motion $reduceMotion', (
      tester,
    ) async {
      await _mount(
        tester,
        setting: ReadSettingState(
          doubleTapZoom: true,
          doubleTapZoomAnimation: reduceMotion,
        ),
        reduceMotion: reduceMotion,
      );
      final viewer = tester.state<_ViewerState>(find.byType(_Viewer));
      await _doubleTap(tester);
      expect(viewer.transform.value.getMaxScaleOnAxis(), kDoubleTapZoomScale);
      await _doubleTap(tester);
      expect(viewer.transform.value.getMaxScaleOnAxis(), 1);
      expect(viewer.menuToggles, 0);
      await tester.pump(const Duration(milliseconds: 60));
    });
  }
}
