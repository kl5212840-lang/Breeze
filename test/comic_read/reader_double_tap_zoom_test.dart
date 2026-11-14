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
  const _Viewer();

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
      buildColumnMode: (_) => const ColoredBox(color: Colors.white),
      buildRowMode: () => const ColoredBox(color: Colors.white),
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
                : const SizedBox(width: 400, height: 500, child: _Viewer()),
          ),
        ),
      ),
    ),
  );
  return settings;
}

Future<void> _doubleTap(WidgetTester tester) async {
  final origin = tester.getTopLeft(find.byType(InteractiveViewer));
  final point = origin + const Offset(60, 140);
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
    expect(viewer.transform.value.storage[12], closeTo(50, .01));
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
