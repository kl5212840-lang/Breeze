import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_icon_veil.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  final now = DateTime(2026, 1, 1);
  final enabledPlugin = PluginRuntimeState(
    uuid: 'copy-source',
    version: '0.0.15',
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

  Widget card({
    required bool enabled,
    required VoidCallback? onOpen,
    bool showSearch = true,
    double scale = 1,
    bool reduceMotion = false,
    bool? pendingEnabled,
    ValueNotifier<String>? interfaceStyle,
    Brightness brightness = Brightness.light,
    TextDirection direction = TextDirection.ltr,
    ValueChanged<bool>? onToggle,
    ValueChanged<String>? onSettings,
    VoidCallback? onSearch,
    Future<void> Function(Map<String, dynamic>)? onAction,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) {
        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: Directionality(textDirection: direction, child: child!),
        );
        return interfaceStyle == null
            ? content
            : AppInterfaceStyleScope(style: interfaceStyle, child: content);
      },
      home: Scaffold(
        body: SingleChildScrollView(
          child: PluginCard(
            pluginUuid: 'copy-source',
            pluginState: enabledPlugin.copyWith(isEnabled: enabled),
            infoState: const DiscoverPluginInfoState(
              loading: false,
              data: {
                'name': '测试图源',
                'iconUrl': '',
                'function': [
                  {
                    'id': 'recommend',
                    'title': '推荐栏目',
                    'action': {'type': 'openComicList'},
                  },
                  {
                    'id': 'tool',
                    'title': '独立工具',
                    'action': {'type': 'openSearch'},
                  },
                ],
              },
            ),
            pendingEnabled: pendingEnabled,
            onSearch: onSearch ?? () {},
            showSearch: showSearch,
            onOpen: onOpen,
            onSettings: onSettings ?? (_) {},
            onToggleEnabled: onToggle ?? (_) {},
            onRetry: () {},
            onAction: onAction ?? (_) async {},
          ),
        ),
      ),
    );
  }

  final openTarget = find.byKey(const ValueKey('plugin-card.copy-source.open'));

  testWidgets(
    'Discover power plate shares the action row geometry in both styles',
    (tester) async {
      final cubit = GlobalSettingCubit()
        ..updateState(
          (state) => state.copyWith(switchStyle: BreezeSwitchStyle.power),
        );
      final style = ValueNotifier('system');
      addTearDown(cubit.close);
      addTearDown(style.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final toggle = find.byKey(
        const ValueKey('plugin-card.copy-source.toggle'),
      );
      final paint = find.byKey(const ValueKey('breeze.switch.paint'));
      Finder action(String symbol) => find.byWidgetPredicate(
        (widget) => widget is SourceChromeIconButton && widget.symbol == symbol,
      );

      for (final mode in ['system', 'breeze']) {
        style.value = mode;
        for (final narrow in [false, true]) {
          await tester.binding.setSurfaceSize(Size(narrow ? 320 : 420, 760));
          final changes = <bool>[];
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: card(
                enabled: true,
                onOpen: () {},
                onToggle: changes.add,
                interfaceStyle: style,
                scale: narrow ? 2 : 1,
                brightness: narrow ? Brightness.dark : Brightness.light,
                direction: narrow ? TextDirection.rtl : TextDirection.ltr,
                reduceMotion: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final switchBox = tester.getRect(toggle);
          final switchPlate = tester.getRect(paint);
          const diameter = 36.0;
          late final Rect settingsBox;
          late final Rect searchBox;
          if (mode == 'system') {
            final native = find.byType(UiKitView);
            expect(native, findsOneWidget);
            final args = tester.widget<UiKitView>(native).creationParams as Map;
            expect(args['kind'], 'iconGroup');
            final rtl = args['rtl'] as bool;
            expect(rtl, narrow);
            final buttons = (args['buttons'] as List).cast<Map>();
            expect(buttons.map((button) => button['id']), [
              'search',
              'settings',
            ]);
            expect(buttons.map((button) => button['symbol']), [
              'magnifyingglass',
              'gearshape',
            ]);
            const extent = VideoControlMetrics.touchExtent;
            final group = tester.getRect(native);
            expect(group.size, const Size(2 * extent, extent));
            Rect buttonBox(int index) => Rect.fromLTWH(
              rtl
                  ? group.right - (index + 1) * extent
                  : group.left + index * extent,
              group.top,
              extent,
              extent,
            );

            searchBox = buttonBox(0);
            settingsBox = buttonBox(1);
            for (final button in buttons) {
              expect(
                extent - 2 * (button['backgroundInset'] as double),
                diameter,
              );
            }
          } else {
            final settings = action('gearshape');
            settingsBox = tester.getRect(settings);
            searchBox = tester.getRect(action('magnifyingglass'));
            final plate = find.descendant(
              of: settings,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is SizedBox &&
                    widget.width == diameter &&
                    widget.height == diameter,
              ),
            );
            expect(plate, findsOneWidget);
          }
          expect(switchPlate.size, const Size.square(diameter));
          expect(
            paint,
            paints..rrect(
              rrect: RRect.fromRectAndRadius(
                const Rect.fromLTWH(0, 0, diameter, diameter),
                const Radius.circular(diameter / 2),
              ),
            ),
          );
          expect(switchBox.width, settingsBox.width);
          expect(switchBox.height, greaterThanOrEqualTo(44));
          expect(switchPlate.center.dy, settingsBox.center.dy);
          expect(
            switchPlate.center.dx - settingsBox.center.dx,
            settingsBox.center.dx - searchBox.center.dx,
          );
          await tester.tap(toggle);
          expect(changes, [false]);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('enabled source has a single-tap entry', (tester) async {
    var opened = 0;
    await tester.pumpWidget(card(enabled: true, onOpen: () => opened++));

    expect(find.text(t.sourceShell.enter), findsNothing);
    expect(find.text('推荐栏目'), findsNothing);
    expect(find.text('独立工具'), findsNothing);
    await tester.tapAt(tester.getTopLeft(openTarget) + const Offset(3, 3));
    expect(opened, 1);
  });

  testWidgets('disabled source does not expose the entry', (tester) async {
    var opened = 0;
    await tester.pumpWidget(card(enabled: false, onOpen: () => opened++));

    expect(find.text(t.discover.disabled), findsOneWidget);
    await tester.tap(openTarget);
    expect(opened, 0);
  });

  testWidgets('web-only list entry omits unsupported comic search', (
    tester,
  ) async {
    await tester.pumpWidget(
      card(enabled: true, onOpen: () {}, showSearch: false),
    );
    expect(find.byTooltip(t.sourceShell.search), findsNothing);
    expect(find.text(t.sourceShell.enter), findsNothing);
  });

  testWidgets(
    'unknown video source card search follows explicit capabilities and preserves legacy defaults',
    (tester) async {
      for (final search in <String?>[
        null,
        'none',
        'full',
        'suggestions',
        'website',
      ]) {
        final action = <String, dynamic>{
          'type': 'openVideoLibrary',
          'payload': {
            'nativeSearch': true,
            if (search != null) 'capabilities': {'search': search},
          },
        };
        final searchAction = DiscoverRouter.videoSearchAction(action);
        var opened = 0;
        await tester.pumpWidget(
          card(
            enabled: true,
            onOpen: () {},
            // Same helper-to-card contract used by DiscoverPage for a single
            // declared video entry; no maintained UUID is involved.
            showSearch: searchAction != null,
            onSearch: () => opened++,
          ),
        );
        await tester.pump();
        final searchButton = find.byTooltip(t.sourceShell.search);
        if (search == 'none') {
          expect(searchAction, isNull);
          expect(searchButton, findsNothing);
          expect(opened, 0);
        } else {
          expect(searchAction?['payload']['openSearch'], isTrue);
          expect(searchButton, findsOneWidget);
          await tester.tap(searchButton);
          expect(opened, 1);
        }
        expect(find.text(t.sourceShell.enter), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'catalog search opt-in stays independent of API capability declarations',
    () {
      final action = {
        'type': 'openVideoCatalog',
        'payload': {
          'nativeSearch': true,
          'capabilities': {'search': 'none'},
        },
      };
      expect(
        DiscoverRouter.videoSearchAction(action)?['payload']['openSearch'],
        isTrue,
      );
      expect(
        DiscoverRouter.videoSearchAction({
          'type': 'openVideoLibrary',
          'payload': {'nativeSearch': false},
        }),
        isNull,
      );
    },
  );

  testWidgets('legacy shortcuts remain actionable without a source shell', (
    tester,
  ) async {
    final actions = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      card(
        enabled: true,
        onOpen: null,
        onAction: (action) async {
          actions.add(action);
        },
      ),
    );

    expect(find.text('推荐栏目'), findsOneWidget);
    expect(find.text('独立工具'), findsOneWidget);
    await tester.tap(find.text('独立工具'));
    expect(actions.single['type'], 'openSearch');
  });

  testWidgets('list actions fit a narrow phone without crowding the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(card(enabled: true, onOpen: () {}));

    expect(find.text('测试图源').hitTestable(), findsOneWidget);
    expect(find.text(t.sourceShell.enter), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('toggling keeps the complete source card height stable', (
    tester,
  ) async {
    await tester.pumpWidget(card(enabled: true, onOpen: () {}));
    final enabledSize = tester.getSize(find.byType(PluginCard));
    await tester.pumpWidget(card(enabled: false, onOpen: () {}));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PluginCard)), enabledSize);
    await tester.pumpWidget(card(enabled: true, onOpen: () {}));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PluginCard)), enabledSize);
  });

  testWidgets(
    'legacy shortcut area and management targets retain their positions when disabled',
    (tester) async {
      await tester.pumpWidget(card(enabled: true, onOpen: null));
      final enabledSize = tester.getSize(find.byType(PluginCard));
      final toggle = find.byKey(
        const ValueKey('plugin-card.copy-source.toggle'),
      );
      final enabledToggleBounds = tester.getRect(toggle);
      await tester.pumpWidget(card(enabled: false, onOpen: null));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PluginCard)), enabledSize);
      expect(tester.getRect(toggle), enabledToggleBounds);
    },
  );
  testWidgets(
    '320pt Breeze card animates the same switch through a pending toggle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final toggled = <bool>[];
      await tester.pumpWidget(
        card(
          enabled: true,
          onOpen: () {},
          scale: 2,
          reduceMotion: true,
          interfaceStyle: style,
          onToggle: toggled.add,
        ),
      );
      final size = tester.getSize(find.byType(PluginCard));
      final settings = find.byTooltip(t.discover.settings);
      final toggle = find.byKey(
        const ValueKey('plugin-card.copy-source.toggle'),
      );
      final settingsBounds = tester.getRect(settings);
      final toggleBounds = tester.getRect(toggle);
      final control = find.byType(Switch);
      final switchElement = tester.element(control);
      expect(tester.widget<Switch>(control).value, isTrue);
      expect(tester.widget<Switch>(control).thumbIcon, isNotNull);
      expect(settingsBounds.height, greaterThanOrEqualTo(44));
      expect(toggleBounds.height, greaterThanOrEqualTo(44));
      expect(tester.getSize(openTarget).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSize(find.byTooltip(t.sourceShell.search)).height,
        greaterThanOrEqualTo(44),
      );
      for (final busy in [true, false]) {
        await tester.pumpWidget(
          card(
            enabled: busy,
            onOpen: () {},
            scale: 2,
            reduceMotion: true,
            pendingEnabled: busy ? false : null,
            interfaceStyle: style,
            onToggle: toggled.add,
          ),
        );
        await tester.pump();
        expect(tester.getSize(find.byType(PluginCard)), size);
        expect(tester.getRect(settings), settingsBounds);
        expect(tester.getRect(toggle), toggleBounds);
        expect(tester.element(control), same(switchElement));
        expect(tester.widget<Switch>(control).value, isFalse);
        await tester.tap(toggle);
        expect(toggled, busy ? isEmpty : [true]);
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is SourceChromeIconButton &&
              widget.tooltip == t.sourceShell.search,
        );
        expect(tester.widget<SourceChromeIconButton>(search).onPressed, isNull);
        expect(tester.getSize(search).height, 44);
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: find.byType(PluginIconVeil),
                  matching: find.byType(AnimatedScale),
                ),
              )
              .duration,
          Duration.zero,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('search and card taps dispatch independently', (tester) async {
    var opened = 0, searches = 0;
    final toggled = <bool>[];
    final settings = <String>[];
    await tester.pumpWidget(
      card(
        enabled: true,
        onOpen: () => opened++,
        onSearch: () => searches++,
        onToggle: toggled.add,
        onSettings: settings.add,
      ),
    );
    await tester.tap(find.byTooltip(t.sourceShell.search));
    expect(searches, 1);
    expect(opened, 0);
    await tester.tap(openTarget);
    expect(searches, 1);
    expect(opened, 1);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byTooltip(t.discover.settings));
    expect(toggled, [false]);
    expect(settings, ['测试图源']);
    expect(opened, 1);
  });

  testWidgets(
    'closed legacy actions leave the accessibility tree and preserve full card extent',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(card(enabled: true, onOpen: null));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ActionChip).first).height,
          greaterThanOrEqualTo(44),
        );
        await tester.pumpWidget(card(enabled: false, onOpen: null));
        await tester.pumpAndSettle();
        final labels = <String>[];
        void collect(SemanticsNode node) {
          labels.add(node.label);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        expect(labels, isNot(contains('推荐栏目')));
        expect(labels, isNot(contains('独立工具')));
        expect(find.text('推荐栏目').hitTestable(), findsNothing);
        expect(labels.join(' '), contains(t.discover.disabled));
      } finally {
        semantics.dispose();
      }
    },
  );
}
