import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

class _CountingReaderSettings extends GlobalSettingCubit {
  int writes = 0;

  @override
  void updateReadSetting(
    ReadSettingState Function(ReadSettingState current) updates,
  ) {
    writes++;
    super.updateReadSetting(updates);
  }
}

Future<GlobalSettingCubit> _open(
  WidgetTester tester, {
  String style = 'breeze',
  Brightness brightness = Brightness.light,
  ReadSettingState? read,
  GlobalSettingCubit? settingsCubit,
  bool perComic = false,
  String comicId = 'comic-a',
  double textScale = 2,
}) async {
  final settings = settingsCubit ?? GlobalSettingCubit();
  if (read != null) settings.emit(settings.state.copyWith(readSetting: read));
  final preferences = ComicReadPreferenceCubit();
  if (perComic) preferences.bind('density-fixture', comicId);
  final interface = ValueNotifier(style);
  addTearDown(settings.close);
  addTearDown(preferences.close);
  addTearDown(interface.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: preferences),
      ],
      child: AppInterfaceStyleScope(
        style: interface,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReaderSettingsSheet(
                  context,
                  source: perComic ? 'density-fixture' : '',
                  comicId: perComic ? comicId : '',
                ),
                child: const Text('open-settings'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-settings'));
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _tab(WidgetTester tester, String title) async {
  final tab = find.widgetWithText(Tab, title);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Material _rowMaterial(WidgetTester tester, Finder tile) {
  Material? material;
  tester.element(tile).visitAncestorElements((element) {
    if (element.widget is Material) {
      material = element.widget as Material;
      return false;
    }
    return true;
  });
  expect(material, isNotNull);
  return material!;
}

void _expectAlignedGroup(WidgetTester tester, List<String> titles) {
  final labels = titles.map(find.text).toList();
  final rows = labels
      .map((label) => find.ancestor(of: label, matching: find.byType(ListTile)))
      .toList();
  final material = _rowMaterial(tester, rows.first);
  expect(material.borderRadius, BorderRadius.circular(14));
  expect(material.clipBehavior, Clip.none);
  final groupRect = tester.getRect(find.byWidget(material));
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    expect(_rowMaterial(tester, row), same(material));
    final rowRect = tester.getRect(row);
    expect(rowRect.height, greaterThanOrEqualTo(44));
    expect(rowRect.left, groupRect.left);
    expect(rowRect.right, groupRect.right);
    expect(tester.getTopLeft(labels[i]).dx, closeTo(groupRect.left + 16, .1));
  }
}

void _expectRectangularNativeAncestry(WidgetTester tester, Finder view) {
  expect(view, findsOneWidget);
  RenderObject? node = tester.renderObject(view);
  while (node != null) {
    final hasRoundedClip = switch (node) {
      RenderClipRRect(:final clipBehavior) => clipBehavior != Clip.none,
      RenderClipPath(:final clipBehavior) => clipBehavior != Clip.none,
      RenderClipOval(:final clipBehavior) => clipBehavior != Clip.none,
      RenderPhysicalShape(:final clipBehavior) => clipBehavior != Clip.none,
      RenderPhysicalModel(:final clipBehavior, :final borderRadius) =>
        clipBehavior != Clip.none && borderRadius != BorderRadius.zero,
      _ => false,
    };
    expect(hasRoundedClip, isFalse, reason: 'Native choice inherits $node');
    node = node.parent;
  }
}

void main() {
  testWidgets(
    'the mobile reading settings persist the system status bar choice',
    (tester) async {
      final settings = await _open(tester, textScale: 1);
      final option = find.text(t.reader.showSystemStatusBar);
      await _show(tester, option);
      expect(settings.state.readSetting.showSystemStatusBar, isFalse);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.showSystemStatusBar, isTrue);
      expect(
        ReadSettingState.fromJson(
          settings.state.readSetting.toJson(),
        ).showSystemStatusBar,
        isTrue,
      );
      expect(ReadSettingState.fromJson({}).showSystemStatusBar, isFalse);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets(
    'global reading settings expose phone landscape and only show top padding for webtoons',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = await _open(
        tester,
        textScale: 1,
        read: const ReadSettingState(readMode: 0),
      );
      expect(find.text(t.reader.themeMode), findsNothing);
      final topPadding = find.text(t.settings.notchAdaptation);
      final landscape = find.text(t.reader.landscapeReader);
      expect(topPadding, findsOneWidget);
      expect(landscape, findsOneWidget);
      await _show(tester, topPadding);
      await tester.tap(topPadding);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.comicReadTopContainer, isFalse);
      final paged = find.text(t.reader.singlePageLtr);
      await _show(tester, paged);
      await tester.tap(paged);
      await tester.pumpAndSettle();
      expect(topPadding, findsNothing);
      expect(settings.state.readSetting.comicReadTopContainer, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'custom menu area previews width and remembers it when disabled',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _CountingReaderSettings();
      await _open(
        tester,
        read: const ReadSettingState(),
        settingsCubit: settings,
      );
      await _tab(tester, t.reader.gesture);
      final toggle = find.text(t.reader.customToolbarTapArea);
      final slider = find.byKey(
        const ValueKey('reader.toolbar-tap-area.width'),
      );
      final preview = find.byKey(
        const ValueKey('reader.toolbar-tap-area.preview'),
      );
      expect(slider, findsNothing);
      await _show(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.customToolbarTapArea, isTrue);
      expect(tester.widget<Slider>(slider).value, 50);
      expect(tester.widget<FractionallySizedBox>(preview).widthFactor, .5);

      await _show(tester, slider);
      final control = tester.widget<Slider>(slider);
      expect(control.semanticFormatterCallback!(64), '64%');
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        final labelledSlider = find.descendant(
          of: slider,
          matching: find.bySemanticsLabel(t.reader.toolbarTapAreaWidth),
        );
        expect(labelledSlider, findsOneWidget);
        expect(tester.getSemantics(labelledSlider).value, '50%');
      } finally {
        semantics.dispose();
      }
      final highlightedBand = find.descendant(
        of: preview,
        matching: find.byType(ColoredBox),
      );
      final originalBand = tester.getRect(highlightedBand);
      control.onChanged!(64);
      await tester.pump();
      expect(tester.widget<FractionallySizedBox>(preview).widthFactor, .64);
      expect(
        tester.getRect(highlightedBand).width,
        closeTo(originalBand.width * .64 / .50, .1),
      );
      expect(tester.getRect(highlightedBand).center.dx, originalBand.center.dx);
      expect(tester.getRect(highlightedBand).height, originalBand.height);
      expect(settings.state.readSetting.toolbarTapAreaPercent, 50);
      control.onChangeEnd!(64);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, 64);

      await _show(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(slider, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, 64);
      await _show(tester, slider);
      final inputSemantics = tester.ensureSemantics();
      final writes = settings.writes;
      try {
        await tester.pump();
        final node = tester.getSemantics(
          find.descendant(
            of: slider,
            matching: find.bySemanticsLabel(t.reader.toolbarTapAreaWidth),
          ),
        );
        node.owner!.performAction(node.id, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(settings.state.readSetting.toolbarTapAreaPercent, 66);
        expect(settings.writes, writes + 1);

        node.owner!.performAction(node.id, SemanticsAction.focus);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(settings.state.readSetting.toolbarTapAreaPercent, 68);
        expect(settings.writes, writes + 2);
      } finally {
        inputSemantics.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'setting sliders preview a drag and ignore vertical cancellation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _CountingReaderSettings();
      await _open(
        tester,
        settingsCubit: settings,
        read: const ReadSettingState(customToolbarTapArea: true),
      );
      await _tab(tester, t.reader.gesture);
      final slider = find.byKey(
        const ValueKey('reader.toolbar-tap-area.width'),
      );
      await _show(tester, slider);
      final origin = tester.getCenter(slider);
      final initialWrites = settings.writes;

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final haptics = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments.toString());
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final scroll = await tester.startGesture(origin + const Offset(38, 0));
      await scroll.moveBy(const Offset(0, -45));
      await scroll.up();
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, 50);
      expect(settings.writes, initialWrites);
      expect(haptics, isEmpty);

      await _show(tester, slider);
      final cancelled = await tester.startGesture(tester.getCenter(slider));
      await cancelled.moveBy(const Offset(63, 0));
      await tester.pump();
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, 50);
      expect(settings.writes, initialWrites);

      final valid = await tester.startGesture(tester.getCenter(slider));
      await valid.moveBy(const Offset(27, 0));
      await tester.pump();
      await valid.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, greaterThan(50));
      expect(settings.writes, initialWrites);
      await valid.up();
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, greaterThan(50));
      expect(settings.writes, initialWrites + 1);
      expect(haptics, everyElement('HapticFeedbackType.selectionClick'));

      await _show(tester, slider);
      await tester.tapAt(tester.getCenter(slider) - const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, lessThan(50));
      expect(settings.writes, initialWrites + 2);
      expect(haptics.length, inInclusiveRange(2, 4));
    },
  );

  testWidgets('info sliders align their values and mark only stepped units', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(
      tester,
      brightness: Brightness.dark,
      read: const ReadSettingState(
        pageInfoEdgePadding: 24,
        pageInfoFontSize: 16,
        pageInfoOpacityPercent: 75,
      ),
    );
    await _tab(tester, t.reader.infoBar);

    Future<int> checkSlider(String title, String value) async {
      final slider = find.byWidgetPredicate(
        (widget) => widget is Slider && widget.label == title,
      );
      await _show(tester, slider);
      final bounds = tester.getRect(slider);
      expect(bounds.height, 44);
      expect(tester.getRect(find.text(value)).right, closeTo(bounds.right, .1));
      var marks = 0;
      expect(
        slider,
        paints..everything((symbol, arguments) {
          if (symbol == #drawCircle && arguments[1] == 1.0) marks++;
          return true;
        }),
      );
      return marks;
    }

    expect(
      await checkSlider(t.reader.edgePadding, '24 ${t.reader.pixels}'),
      inExclusiveRange(2, 49),
    );
    expect(await checkSlider(t.reader.fontSize, '16 ${t.reader.pixels}'), 11);
    expect(await checkSlider(t.reader.backgroundOpacity, '75%'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'percent input previews exact values and commits only on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      const bottomSafeArea = FakeViewPadding(bottom: 34);
      tester.view.viewPadding = bottomSafeArea;
      tester.view.padding = bottomSafeArea;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final settings = _CountingReaderSettings();
      await _open(
        tester,
        brightness: Brightness.dark,
        settingsCubit: settings,
        read: const ReadSettingState(customToolbarTapArea: true),
      );
      await _tab(tester, t.reader.gesture);
      final field = find.byKey(const ValueKey('reader.slider-percent.input'));
      final slider = find.byKey(
        const ValueKey('reader.toolbar-tap-area.width'),
      );
      final dialog = find.byKey(const ValueKey('reader.slider-percent.dialog'));
      final band = find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('reader.toolbar-tap-area.preview')),
      );
      Rect? sliderFrame;
      double? scrollOffset;
      double offset() => Scrollable.of(tester.element(slider)).position.pixels;
      final cancel = find.text(t.common.cancel);
      final confirm = find.text(t.common.confirm);
      final error = find.text(t.reader.sliderPercentageRange(min: 30, max: 70));

      Future<void> open(String label) async {
        final value = find.text(label);
        await _show(tester, value);
        sliderFrame = tester.getRect(slider);
        scrollOffset = offset();
        await tester.tap(value);
        await tester.pumpAndSettle();
        expect(field, findsOneWidget);
        expect(tester.getRect(slider), sliderFrame);
        expect(offset(), scrollOffset);
      }

      await open('50%');
      tester.view.padding = const FakeViewPadding();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _show(tester, confirm);
      expect(confirm.hitTestable(), findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.getRect(confirm).bottom, lessThan(380));
      expect(tester.getRect(slider), sliderFrame);
      expect(offset(), scrollOffset);
      tester.view.padding = bottomSafeArea;
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(field);
      expect(input.keyboardType, TextInputType.number);
      expect(
        input.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      await tester.enterText(field, '５７％');
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, 57);
      expect(tester.widget<FractionallySizedBox>(band).widthFactor, .57);
      expect(tester.getRect(slider), sliderFrame);
      expect(offset(), scrollOffset);
      expect(settings.writes, 0);

      for (final invalid in ['', '57.5', '71%', '-40']) {
        await tester.enterText(field, invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(settings.writes, 0);
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      }
      await tester.enterText(field, '57%');
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      await _show(tester, cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(tester.widget<Slider>(slider).value, 50);
      expect(settings.writes, 0);

      await open('50%');
      await tester.enterText(field, '57%');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(settings.state.readSetting.toolbarTapAreaPercent, 57);
      expect(settings.writes, 1);

      await open('57%');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(settings.writes, 1);

      await open('57%');
      await tester.enterText(field, '70');
      await _show(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.toolbarTapAreaPercent, 70);
      expect(settings.writes, 2);

      await open('70%');
      await tester.enterText(field, '30');
      tester.view.physicalSize = const Size(640, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 138);
      await tester.pumpAndSettle();
      await _show(tester, cancel);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.getRect(cancel).bottom, lessThan(182));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(settings.writes, 2);
      expect(settings.state.readSetting.toolbarTapAreaPercent, 70);
      expect(field, findsNothing);
    },
  );

  testWidgets('auto-read sliders keep exact steps and the per-comic owner', (
    tester,
  ) async {
    final settings = await _open(
      tester,
      perComic: true,
      comicId: 'slider-fixture',
      read: const ReadSettingState(autoScroll: true),
    );
    await _tab(tester, t.reader.perComicThisComic);
    Finder slider(String title) => find.byWidgetPredicate(
      (widget) => widget is Slider && widget.label == title,
    );
    final interval = slider(t.reader.webtoonScrollInterval);
    final row = tester.widget<Slider>(interval);
    expect((row.min, row.max, row.divisions), (300.0, 5000.0, 47));
    final page = tester.widget<Slider>(
      slider(t.reader.singlePageScrollInterval),
    );
    expect((page.min, page.max, page.divisions), (800.0, 10000.0, 92));
    final distance = tester.widget<Slider>(
      slider(t.reader.webtoonScrollDistance),
    );
    expect((distance.min, distance.max, distance.divisions), (10.0, 100.0, 90));
    final comic = tester.element(interval).read<ComicReadPreferenceCubit>();
    row.onChanged!(2300);
    await tester.pump();
    expect(comic.state.override, isNull);
    row.onChangeEnd!(2300);
    await tester.pumpAndSettle();
    expect(comic.state.override!.keys, {'autoScrollColumnIntervalMs'});
    expect(comic.state.override!.setting.autoScrollColumnIntervalMs, 2300);
    expect(settings.state.readSetting.autoScrollColumnIntervalMs, 1600);
  });

  testWidgets('tap zones follow reading direction and the webtoon switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = await _open(tester, textScale: 1);
    await _tab(tester, t.reader.gesture);
    Finder option(String title) => find.widgetWithText(ChoiceChip, title);
    final enable = find.text(t.reader.enableWebtoonTapPageTurn);
    final custom = find.text(t.reader.customToolbarTapArea);
    final needsCustom = find.text(t.reader.tapPageTurnNeedsCustomArea);
    expect(option(t.reader.tapPageTurnWebtoonAll), findsNothing);
    expect(enable, findsNothing);
    expect(needsCustom, findsOneWidget);
    await _show(tester, custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(find.text(t.reader.tapPageTurnWebtoonDisabled), findsOneWidget);
    await _show(tester, enable);
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(option(t.reader.tapPageTurnWebtoonAll), findsOneWidget);
    expect(option(t.reader.bottomHalfNext), findsOneWidget);
    expect(find.text(t.reader.tapPageTurnWebtoonSplitHelp), findsOneWidget);
    await _show(tester, option(t.reader.topHalfNext));
    await tester.tap(option(t.reader.topHalfNext));
    await tester.pumpAndSettle();
    expect(
      settings.state.readSetting.tapPageTurnMode,
      ReaderTapPageTurnMode.leftHand,
    );
    await _show(tester, enable);
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(option(t.reader.topHalfNext), findsNothing);
    expect(
      settings.state.readSetting.tapPageTurnMode,
      ReaderTapPageTurnMode.leftHand,
    );

    settings.updateReadSetting((value) => value.copyWith(readMode: 2));
    await tester.pumpAndSettle();
    expect(option(t.reader.fullscreen), findsOneWidget);
    expect(option(t.reader.leftHandMode), findsOneWidget);
    expect(option(t.reader.rightHandMode), findsOneWidget);
    expect(option(t.reader.topHalfNext), findsNothing);
    expect(
      tester.widget<ChoiceChip>(option(t.reader.leftHandMode)).selected,
      isTrue,
    );
    expect(find.text(t.reader.tapPageTurnSplitHelp), findsOneWidget);
    await _show(tester, option(t.reader.fullscreen));
    await tester.tap(option(t.reader.fullscreen));
    await tester.pumpAndSettle();
    expect(
      settings.state.readSetting.tapPageTurnMode,
      ReaderTapPageTurnMode.fullScreen,
    );
    expect(find.text(t.reader.tapPageTurnAllHelp), findsOneWidget);
    expect(enable, findsOneWidget);
    await _show(tester, custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(option(t.reader.fullscreen), findsNothing);
    expect(enable, findsNothing);
    expect(needsCustom, findsOneWidget);
    expect(
      settings.state.readSetting.tapPageTurnMode,
      ReaderTapPageTurnMode.fullScreen,
    );
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(option(t.reader.fullscreen)).selected,
      isTrue,
    );
  });

  testWidgets('per-comic tap zones keep the global webtoon switch separate', (
    tester,
  ) async {
    final settings = await _open(tester, perComic: true, textScale: 1);
    await _tab(tester, t.reader.perComicThisComic);
    final customDisabled = find.text(t.reader.tapPageTurnNeedsCustomArea);
    expect(customDisabled, findsOneWidget);
    settings.updateReadSetting(
      (value) => value.copyWith(customToolbarTapArea: true),
    );
    await tester.pumpAndSettle();
    final hint = find.text(t.reader.tapPageTurnWebtoonPerComicDisabled);
    await _show(tester, hint);
    expect(hint, findsOneWidget);
    expect(find.text(t.reader.enableWebtoonTapPageTurn), findsNothing);
    settings.updateReadSetting(
      (value) => value.copyWith(tapPageTurnInWebtoon: true),
    );
    await tester.pumpAndSettle();
    final full = find.widgetWithText(
      ChoiceChip,
      t.reader.tapPageTurnWebtoonAll,
    );
    await _show(tester, full);
    final preferences = tester.element(full).read<ComicReadPreferenceCubit>();
    await tester.tap(full);
    await tester.pumpAndSettle();
    expect(find.text(t.reader.tapPageTurnWebtoonAllHelp), findsOneWidget);
    expect(preferences.state.override!.keys, {'tapPageTurnMode'});
    expect(
      preferences.state.override!.setting.tapPageTurnMode,
      ReaderTapPageTurnMode.fullScreen,
    );
    expect(
      settings.state.readSetting.tapPageTurnMode,
      ReaderTapPageTurnMode.rightHand,
    );
    settings.updateReadSetting(
      (value) => value.copyWith(customToolbarTapArea: false),
    );
    await tester.pumpAndSettle();
    expect(customDisabled, findsOneWidget);
    expect(full, findsNothing);
    expect(preferences.state.override!.keys, {'tapPageTurnMode'});
    settings.updateReadSetting(
      (value) => value.copyWith(customToolbarTapArea: true),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(full).selected, isTrue);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$style $brightness reader uses grouped help on a narrow large-text host',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _open(tester, style: style, brightness: brightness);
          await _tab(tester, t.reader.gesture);
          expect(
            find.text(t.reader.reverseHorizontalPageTurnSubtitle),
            findsNothing,
          );
          final details = find.byKey(
            ValueKey('settings-details-${t.reader.pageMode}'),
          );
          await _show(tester, details);
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(
            find.text(t.reader.reverseHorizontalPageTurnSubtitle),
            findsOneWidget,
          );
          expect(tester.getSize(details).height, greaterThanOrEqualTo(44));
          // Kept-alive TabBarView pages must reset their help when paging away.
          await _tab(tester, t.reader.infoBar);
          await _tab(tester, t.reader.gesture);
          expect(
            find.text(t.reader.reverseHorizontalPageTurnSubtitle),
            findsNothing,
          );
          await _tab(tester, t.reader.infoBar);
          expect(find.text(t.reader.pageNumberSubtitle), findsNothing);
          expect(find.text(t.reader.batterySubtitle), findsNothing);
          expect(find.text(t.reader.timeSubtitle), findsNothing);
          final pageTile = find.ancestor(
            of: find.text(t.reader.pageNumber),
            matching: find.byType(ListTile),
          );
          await _show(tester, pageTile);
          expect(tester.getSize(pageTile).height, greaterThanOrEqualTo(44));
          _expectAlignedGroup(tester, [
            t.reader.pageNumber,
            t.reader.networkStatus,
            t.reader.battery,
            t.reader.time,
          ]);
          if (style == 'breeze') {
            final top = find.widgetWithText(
              ChoiceChip,
              t.reader.verticalPositionTop,
            );
            final bottom = find.widgetWithText(
              ChoiceChip,
              t.reader.verticalPositionBottom,
            );
            await _show(tester, top);
            final colors = Theme.of(tester.element(top)).colorScheme;
            expect(tester.widget<ChoiceChip>(top).side, BorderSide.none);
            expect(
              tester.widget<ChoiceChip>(bottom).side?.color,
              colors.primary,
            );
            expect(tester.getSize(top).height, greaterThanOrEqualTo(44));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style reader tabs retain the full longest label when the labels have unequal widths',
      (tester) async {
        final locale = LocaleSettings.currentLocale;
        LocaleSettings.setLocaleSync(AppLocale.zhCn);
        addTearDown(() => LocaleSettings.setLocaleSync(locale));
        tester.view.physicalSize = const Size(720, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester, style: style, perComic: true, textScale: 1.4);
        final bar = find.byType(TabBar);
        Finder label(String text) =>
            find.descendant(of: bar, matching: find.text(text));
        final labels = [
          t.reader.settings,
          t.reader.gesture,
          t.reader.infoBar,
          t.reader.perComicThisComic,
        ];
        final widths = labels
            .map(
              (text) =>
                  tester
                      .renderObject<RenderParagraph>(label(text))
                      .getMaxIntrinsicWidth(double.infinity) +
                  32,
            )
            .toList();
        final total = widths.reduce((a, b) => a + b);
        final fixed = widths.reduce((a, b) => a > b ? a : b) * labels.length;
        final sheetWidth = ((total + fixed) / 2).ceilToDouble();
        // All labels fit by total width, while the longest cannot fit an equal slot.
        tester.view.physicalSize = Size(sheetWidth + 56, 780);
        await tester.pumpAndSettle();
        for (final title in labels) {
          await _tab(tester, title);
          final paragraph = tester.renderObject<RenderParagraph>(label(title));
          expect(
            paragraph.size.width + .5,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicWidth(double.infinity),
            ),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disabled placement reason and all-hidden state remain visible outside disclosures',
    (tester) async {
      final settings = await _open(
        tester,
        read: const ReadSettingState().copyWith(
          pageInfoShowPage: false,
          pageInfoShowNetwork: false,
          pageInfoShowBattery: false,
          pageInfoShowTime: false,
          pageInfoHorizontalPosition: ReaderInfoHorizontalPosition.center,
        ),
      );
      await _tab(tester, t.reader.infoBar);
      await _show(tester, find.text(t.reader.allHiddenNotice));
      expect(find.text(t.reader.allHiddenNotice), findsOneWidget);
      await _show(tester, find.text(t.reader.edgePaddingDisabled));
      expect(find.text(t.reader.edgePaddingDisabled), findsOneWidget);
      expect(find.byType(SettingDetailsNotes).hitTestable(), findsNothing);
      expect(
        settings.state.readSetting.pageInfoHorizontalPosition,
        ReaderInfoHorizontalPosition.center,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mutual exclusion and running-with-hidden-controls consequence stay directly visible',
    (tester) async {
      final settings = await _open(
        tester,
        read: const ReadSettingState().copyWith(autoScroll: true),
      );
      await _show(tester, find.text(t.reader.autoReadHidePauseButtonSubtitle));
      expect(
        find.text(t.reader.autoReadHidePauseButtonSubtitle),
        findsOneWidget,
      );
      await _tab(tester, t.reader.gesture);
      await _show(tester, find.text(t.reader.doubleTapOpenMenuSubtitle));
      expect(find.text(t.reader.doubleTapOpenMenuSubtitle), findsOneWidget);
      final tile = find.ancestor(
        of: find.text(t.reader.doubleTapOpenMenu),
        matching: find.byType(ListTile),
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(settings.state.readSetting.doubleTapOpenMenu, isTrue);
      expect(settings.state.readSetting.doubleTapZoom, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing the settings resets expanded help without writing preferences',
    (tester) async {
      final settings = await _open(tester);
      final before = settings.state;
      await _tab(tester, t.reader.gesture);
      final details = find.byKey(
        ValueKey('settings-details-${t.reader.pageMode}'),
      );
      await _show(tester, details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.text(t.reader.reverseHorizontalPageTurnSubtitle),
        findsOneWidget,
      );
      final context = tester.element(find.byType(TabBar));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-settings'));
      await tester.pumpAndSettle();
      await _tab(tester, t.reader.gesture);
      expect(
        find.text(t.reader.reverseHorizontalPageTurnSubtitle),
        findsNothing,
      );
      expect(settings.state, before);
    },
  );

  testWidgets(
    'large current values and per-comic tab use the same disclosure geometry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(
        tester,
        perComic: true,
        read: const ReadSettingState().copyWith(
          autoScroll: true,
          autoScrollColumnIntervalMs: 5000,
          autoScrollPageIntervalMs: 10000,
        ),
      );
      await _tab(tester, t.reader.perComicThisComic);
      // Bring the per-comic help into view without confusing the adjacent global tab.
      final view = tester.widget<TabBarView>(find.byType(TabBarView));
      final target = find.descendant(
        of: find.byWidget(view.children[3]),
        matching: find.byKey(ValueKey('settings-details-${t.reader.autoRead}')),
      );
      await _show(tester, target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        find.text(t.reader.autoReadSmoothSubtitle).hitTestable(),
        findsOneWidget,
      );
      await _tab(tester, t.reader.settings);
      await _tab(tester, t.reader.perComicThisComic);
      expect(
        find.text(t.reader.autoReadSmoothSubtitle).hitTestable(),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preload choices share group ink, title alignment and one disclosure',
    (tester) async {
      await _open(tester);
      final choice = find.widgetWithText(
        SettingChoiceTile<int>,
        t.reader.preloadImageCount,
      );
      await _show(tester, choice);
      _expectAlignedGroup(tester, [
        t.reader.preloadImageCount,
        t.reader.preloadChapterCount,
      ]);
      final details = find.byKey(
        ValueKey('settings-details-${t.reader.preload}'),
      );
      await _show(tester, details);
      expect(details, findsOneWidget);
      expect(find.text(t.reader.preloadImageCountSubtitle), findsNothing);
      expect(find.text(t.reader.preloadChapterCountSubtitle), findsNothing);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text(t.reader.preloadImageCountSubtitle), findsOneWidget);
      expect(find.text(t.reader.preloadChapterCountSubtitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iOS reader preload choice has no rounded clip ancestor', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    await _open(tester, style: 'system', textScale: 1);
    final choice = find.widgetWithText(
      SettingChoiceTile<int>,
      t.reader.preloadImageCount,
    );
    await _show(tester, choice);
    _expectRectangularNativeAncestry(
      tester,
      find.descendant(of: choice, matching: find.byType(UiKitView)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
