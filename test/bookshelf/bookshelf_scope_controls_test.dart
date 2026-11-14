import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('source selection preserves query, sort and the other medium', (
    tester,
  ) async {
    final comics = BookshelfSearchCubit(), videos = BookshelfSearchCubit();
    addTearDown(comics.close);
    addTearDown(videos.close);
    comics.setKeyword(ShelfPageMode.favorite, '想看的漫画');
    comics.setSort(ShelfPageMode.favorite, 'va');
    videos.setSources(ShelfPageMode.favorite, ['omo']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamBuilder(
            stream: comics.stream,
            builder: (context, _) => BookshelfSourceNavigation(
              sources: const {'a': '插件甲', 'b': '插件乙'},
              selected: comics.state.favorite.sources,
              onChanged: (v) => comics.setSources(ShelfPageMode.favorite, v),
            ),
          ),
        ),
      ),
    );
    final all = find.byKey(const ValueKey('bookshelf.source.'));
    final plugin = find.byKey(const ValueKey('bookshelf.source.a'));
    final pluginRect = tester.getRect(plugin);
    await tester.tap(plugin);
    await tester.pumpAndSettle();
    expect(tester.getRect(plugin), pluginRect);
    expect(tester.getSize(all).height, greaterThanOrEqualTo(44));
    expect(comics.state.favorite.sources, ['a']);
    expect(comics.state.favorite.keyword, '想看的漫画');
    expect(comics.state.favorite.sort, 'va');
    expect(videos.state.favorite.sources, ['omo']);
    await tester.tap(find.byKey(const ValueKey('bookshelf.source.')));
    await tester.pump();
    expect(comics.state.favorite.sources, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('$mode $brightness slides one plate without moving labels', (
        tester,
      ) async {
        final theme = ThemeData(brightness: brightness);
        final preference = ValueNotifier(mode);
        final selected = ValueNotifier<List<String>>([]);
        addTearDown(preference.dispose);
        addTearDown(selected.dispose);
        bool reduceMotion = false;
        Future<void> mount() => tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: child!,
              ),
              home: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (context, value, _) => BookshelfSourceNavigation(
                    sources: const {'a': '哔咔漫画+', 'b': '拷贝漫画'},
                    selected: value,
                    onChanged: (value) => selected.value = value,
                  ),
                ),
              ),
            ),
          ),
        );
        await mount();
        final plate = find.byKey(const ValueKey('bookshelf.sources.thumb'));
        final label = find.byKey(const ValueKey('bookshelf.source.a'));
        final before = tester.getCenter(plate);
        final target = tester.getCenter(label);
        expect(before.dx, lessThan(target.dx));
        expect(
          tester
              .widget<DecoratedBox>(
                find.descendant(of: plate, matching: find.byType(DecoratedBox)),
              )
              .decoration,
          isA<BoxDecoration>()
              .having(
                (value) => value.color,
                'theme color',
                mode == 'breeze'
                    ? BreezeControlColors.sectionSelection(theme).fill
                    : theme.colorScheme.surfaceContainerHigh,
              )
              .having((value) => value.border, 'no resting outline', isNull),
        );
        await tester.tap(label);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        final during = tester.getCenter(plate);
        expect(during.dx, inExclusiveRange(before.dx, target.dx));
        expect(tester.getCenter(label), target);
        expect(find.text('哔咔漫画+'), findsOneWidget);
        expect(plate, findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.getCenter(plate), target);
        reduceMotion = true;
        await mount();
        final all = find.byKey(const ValueKey('bookshelf.source.'));
        await tester.tap(all);
        await tester.pump();
        expect(tester.getCenter(plate), tester.getCenter(all));
      });
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'classic Breeze selection follows actual buttons in $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final colors = ColorScheme.fromSeed(
          seedColor: direction == TextDirection.ltr
              ? const Color(0xff935492)
              : const Color(0xff1257ba),
          brightness: direction == TextDirection.ltr
              ? Brightness.light
              : Brightness.dark,
        );
        final style = ValueNotifier('breeze');
        final selection = ValueNotifier<List<String>>([]);
        addTearDown(style.dispose);
        addTearDown(selection.dispose);
        const lastId = 'classic-breeze-source';
        var reduceMotion = false;
        var hideLast = false;
        Future<void> mount() => tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(colorScheme: colors),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Directionality(
                    textDirection: direction,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: const TextScaler.linear(2),
                        disableAnimations: reduceMotion,
                        highContrast: true,
                      ),
                      child: ValueListenableBuilder(
                        valueListenable: selection,
                        builder: (context, value, _) =>
                            BookshelfSourceNavigation(
                              showManage: false,
                              classicChips: true,
                              sources: const {
                                'a': 'One',
                                lastId: 'A much longer source name',
                              },
                              hidden: hideLast ? {lastId} : const {},
                              selected: value,
                              onChanged: (value) => selection.value = value,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final track = find.byKey(
          const ValueKey('bookshelf.sources.selection-track'),
        );
        List<Rect> paintedPlates() {
          final bounds = <Rect>[];
          final origin = tester.getTopLeft(track);
          final fill = BreezeControlColors.sectionSelection(
            Theme.of(tester.element(track)),
            highContrast: true,
          ).fill;
          expect(
            tester.renderObject(track),
            paints..everything((name, arguments) {
              if (name == #drawRRect &&
                  (arguments[1] as Paint).color.toARGB32() == fill.toARGB32()) {
                bounds.add((arguments[0] as RRect).outerRect.shift(origin));
              }
              return true;
            }),
          );
          return bounds;
        }

        await mount();
        final source = find.byKey(const ValueKey('bookshelf.source.a'));
        final all = find.byKey(const ValueKey('bookshelf.source.'));
        final last = find.byKey(const ValueKey('bookshelf.source.$lastId'));
        final before = tester.getRect(source);
        final initialPlate = paintedPlates().single;
        expect(initialPlate, tester.getRect(all));
        expect(before.width, greaterThanOrEqualTo(44));
        expect(before.height, greaterThanOrEqualTo(44));
        final pressPlate = find
            .descendant(of: source, matching: find.byType(AnimatedContainer))
            .last;
        double pressAlpha() {
          final box = find
              .descendant(of: pressPlate, matching: find.byType(DecoratedBox))
              .first;
          return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration)
              .color!
              .a;
        }

        final gesture = await tester.startGesture(before.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        expect(pressAlpha(), greaterThan(0));
        expect(selection.value, isEmpty);
        expect(paintedPlates().first, initialPlate);
        expect(tester.getRect(source), before);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(pressAlpha(), 0);
        expect(selection.value, isEmpty);

        Color labelColor(Finder button) => tester
            .widget<Text>(
              find.descendant(of: button, matching: find.byType(Text)).first,
            )
            .style!
            .color!;
        final inactiveColor = labelColor(source);
        final activeColor = labelColor(all);
        expect(activeColor, isNot(inactiveColor));
        await tester.tap(source);
        await tester.pump();
        expect(selection.value, ['a']);
        expect(paintedPlates().single, initialPlate);
        expect(labelColor(source), inactiveColor);
        await tester.pump(const Duration(milliseconds: 64));
        final forward = paintedPlates().single;
        expect(
          forward.center.dx,
          inExclusiveRange(
            direction == TextDirection.ltr
                ? initialPlate.center.dx
                : before.center.dx,
            direction == TextDirection.ltr
                ? before.center.dx
                : initialPlate.center.dx,
          ),
        );
        expect(labelColor(source), isNot(inactiveColor));
        expect(labelColor(source), isNot(activeColor));
        final forwardColor = labelColor(source);
        expect(tester.getRect(source), before);

        await tester.tap(all);
        await tester.pump();
        expect(selection.value, isEmpty);
        expect(paintedPlates().single, forward);
        expect(labelColor(source), forwardColor);
        await tester.pump(const Duration(milliseconds: 32));
        expect(
          (paintedPlates().single.center.dx - initialPlate.center.dx).abs(),
          lessThan((forward.center.dx - initialPlate.center.dx).abs()),
        );
        await tester.pumpAndSettle();
        expect(paintedPlates().single, initialPlate);
        expect(tester.getRect(source), before);

        reduceMotion = true;
        await mount();
        await tester.tap(source);
        await tester.pump();
        expect(paintedPlates().single, before);
        expect(labelColor(source), activeColor);
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        await tester.drag(
          find.byKey(const ValueKey('bookshelf.sources.scroll')),
          Offset(direction == TextDirection.ltr ? -200 : 200, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
        expect(selection.value, ['a']);
        await tester.tap(last);
        await tester.pump();
        expect(selection.value, [lastId]);
        final originalLast = tester.getRect(last);
        expect(paintedPlates().single, originalLast);

        await savePluginDisplayName(lastId, 'Alias', expectedName: '');
        for (var i = 0; i < 50 && find.text('Alias').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.text('Alias'), findsOneWidget);
        expect(tester.getSize(last).width, lessThan(originalLast.width));
        expect(paintedPlates().single, tester.getRect(last));
        await savePluginDisplayName(lastId, '', expectedName: 'Alias');

        selection.value = ['a', lastId];
        await tester.pump();
        expect(
          paintedPlates(),
          unorderedEquals([tester.getRect(source), tester.getRect(last)]),
        );
        selection.value = [lastId];
        await tester.pump();
        hideLast = true;
        await mount();
        expect(last, findsNothing);
        expect(paintedPlates(), isEmpty);

        final focus = FocusManager.instance;
        final originalHighlight = focus.highlightStrategy;
        addTearDown(() => focus.highlightStrategy = originalHighlight);
        focus.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        focus.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final allPressPlate = find
            .descendant(of: all, matching: find.byType(AnimatedContainer))
            .last;
        expect(
          tester.widget<AnimatedContainer>(allPressPlate).foregroundDecoration,
          isA<BoxDecoration>().having(
            (value) => value.border,
            'focus ring',
            isNotNull,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selection.value, isEmpty);
        expect(paintedPlates().single, tester.getRect(all));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'classic iOS glass chips scroll independently and update alias in place',
    (tester) async {
      tester.view.physicalSize = const Size(220, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      final updatedLabels = <String, Object?>{};
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'breeze.video.control.${(call.arguments as Map)['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'update') {
              updatedLabels[channel.name] = (call.arguments as Map)['label'];
            }
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final style = ValueNotifier('system');
      final selection = ValueNotifier<List<String>>([]);
      addTearDown(style.dispose);
      addTearDown(selection.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: selection,
                builder: (context, value, _) => BookshelfSourceNavigation(
                  showManage: false,
                  classicChips: true,
                  sources: const {'a': '哔咔漫画+', 'b': '名称较长的插件来源'},
                  selected: value,
                  onChanged: (value) => selection.value = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('bookshelf.sources.scroll'));
      final views = find.descendant(of: rail, matching: find.byType(UiKitView));
      expect(views, findsNWidgets(3));
      for (final widget in tester.widgetList<UiKitView>(views)) {
        final args = widget.creationParams! as Map;
        expect(args['bare'], isFalse);
        expect(args['label'], isA<String>());
      }
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: rail, matching: find.byType(Scrollable)),
      );
      final viewport = tester.getRect(rail);
      await tester.dragFrom(
        Offset(viewport.right - 24, viewport.center.dy),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(selection.value, isEmpty);
      final last = find.byKey(const ValueKey('bookshelf.source.b'));
      expect(tester.getCenter(last).dx, lessThan(viewport.right));
      expect(tester.widget<NativeVideoTextButton>(last).bare, isFalse);
      await messenger.handlePlatformMessage(
        channels.last.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(selection.value, ['b']);
      final sourceChannel = channels.last.name;
      Future<void> rename(String value, String expectedName) async {
        await savePluginDisplayName('b', value, expectedName: expectedName);
        final visibleName = value.isEmpty ? '名称较长的插件来源' : value;
        for (
          var i = 0;
          i < 50 && updatedLabels[sourceChannel] != visibleName;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(updatedLabels[sourceChannel], visibleName);
        expect(tester.widget<NativeVideoTextButton>(last).tooltip, visibleName);
        expect(selection.value, ['b']);
      }

      await rename('图源别名', '');
      await rename('', '图源别名');
      expect(channels, hasLength(3));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final direction in TextDirection.values) {
    testWidgets('classic rail uses a tighter divider gap in $direction', (
      tester,
    ) async {
      Future<(double, Rect)> mount(bool classicChips) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: SizedBox(
                  width: 220,
                  child: BookshelfSourceNavigation(
                    key: ValueKey(classicChips),
                    classicChips: classicChips,
                    sources: const {'a': 'Alpha', 'b': 'A wider source name'},
                    selected: const [],
                    onChanged: (_) {},
                    onManage: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = tester.getRect(
          find.byKey(const ValueKey('bookshelf.source.b')),
        );
        final divider = tester.getCenter(
          find.byKey(const ValueKey('bookshelf.sources.divider')),
        );
        final manage = tester.getRect(
          find.byKey(const ValueKey('bookshelf.sources.manage')),
        );
        final gap = direction == TextDirection.ltr
            ? divider.dx - last.right
            : last.left - divider.dx;
        return (gap, manage);
      }

      final (standardGap, standardManage) = await mount(false);
      final (classicGap, classicManage) = await mount(true);
      expect(classicGap, greaterThan(0));
      expect(classicGap, lessThan(standardGap));
      expect(classicManage.width, greaterThanOrEqualTo(44));
      expect(classicManage.height, greaterThanOrEqualTo(44));
      if (direction == TextDirection.ltr) {
        expect(classicManage.right, standardManage.right);
      } else {
        expect(classicManage.left, standardManage.left);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '320 point double text keeps source targets and a retained missing plugin',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: BookshelfSourceNavigation(
              sources: const {'a': '较长的插件名称'},
              selected: const ['legacy'],
              onChanged: (_) => calls++,
            ),
          ),
        ),
      );
      final scroll = find.byKey(const ValueKey('bookshelf.sources.scroll'));
      await tester.drag(scroll, const Offset(-1000, 0));
      await tester.pumpAndSettle();
      final legacy = find.byKey(const ValueKey('bookshelf.source.legacy'));
      expect(legacy, findsOneWidget);
      expect(tester.getSize(legacy).height, greaterThanOrEqualTo(44));
      await tester.tap(legacy);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'batch selection disables source changes without clearing scope',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookshelfSourceNavigation(
              sources: {'a': '插件甲'},
              selected: ['a'],
              onChanged: null,
            ),
          ),
        ),
      );
      final button = find.widgetWithText(TextButton, '插件甲');
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All and management remain available when every source tab is hidden',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookshelfSourceNavigation(
              sources: const {'a': '插件甲'},
              selected: const [],
              hidden: const {'a'},
              onChanged: (_) {},
              onManage: () => opened++,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('bookshelf.source.a')), findsNothing);
      expect(find.byKey(const ValueKey('bookshelf.source.')), findsOneWidget);
      final manage = find.byKey(const ValueKey('bookshelf.sources.manage'));
      expect(tester.getSize(manage).height, greaterThanOrEqualTo(44));
      await tester.tap(manage);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
