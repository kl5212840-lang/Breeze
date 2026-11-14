import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/models/plugin_runtime_state.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';

import '../test_helper.dart';

// Flutter 3.47's iOS slicer propagates a platform view's nonrectangular clips
// to later Flutter overlay content. Test actual hosts, not just naked controls.
void expectRectangularNativeAncestry(WidgetTester tester) {
  final views = find.byType(UiKitView, skipOffstage: false);
  expect(views, findsWidgets, reason: 'The test must actually exercise UIKit');
  for (final element in views.evaluate()) {
    RenderObject? node = element.findRenderObject();
    while (node != null) {
      final clips = switch (node) {
        RenderClipRRect(:final clipBehavior) => clipBehavior != Clip.none,
        RenderClipPath(:final clipBehavior) => clipBehavior != Clip.none,
        RenderClipOval(:final clipBehavior) => clipBehavior != Clip.none,
        RenderPhysicalShape(:final clipBehavior) => clipBehavior != Clip.none,
        RenderPhysicalModel(:final clipBehavior, :final borderRadius) =>
          clipBehavior != Clip.none && borderRadius != BorderRadius.zero,
        _ => false,
      };
      expect(clips, isFalse, reason: 'Native view inherits $node');
      node = node.parent;
    }
  }
}

Finder _iconGroups(Finder row) => find.descendant(
  of: row,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is UiKitView &&
        widget.creationParams is Map &&
        (widget.creationParams as Map)['kind'] == 'iconGroup',
  ),
);

int _platformId(Finder view) {
  RenderUiKitView? result;
  void visit(RenderObject object) {
    if (object is RenderUiKitView) result = object;
    object.visitChildren(visit);
  }

  visit(view.evaluate().single.findRenderObject()!);
  return result!.viewController.id;
}

Set<int> _platformLayers(WidgetTester tester) {
  final ids = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) ids.add(layer.viewId);
    if (layer is ContainerLayer) {
      for (
        var child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        visit(child);
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return ids;
}

PluginRuntimeState _plugin(String id, {int index = 0}) {
  final now = DateTime(2026, 1, 1);
  return PluginRuntimeState(
    uuid: id,
    version: '1',
    originScript: '',
    isEnabled: true,
    isDeleted: false,
    debug: false,
    debugUrl: null,
    lastLoadSuccess: true,
    lastLoadError: null,
    sortOrder: index,
    insertedAt: now,
    updatedAt: now,
    deletedAt: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final arguments = <int, Map<dynamic, dynamic>>{};
  final updates = <int, int>{};
  final gestures = <(String, int)>[];
  final presses = <(int, String, bool)>[];
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final id = args['id'] as int;
        if (args['params'] case final Uint8List params) {
          final decoded = const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(params),
          );
          if (decoded is Map) arguments[id] = decoded;
        }
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (event) async {
          if (event.method == 'update' && event.arguments is Map) {
            arguments[id] = event.arguments as Map;
            updates.update(id, (count) => count + 1, ifAbsent: () => 1);
          }
          if (event.method == 'setPressed' && event.arguments is Map) {
            final press = event.arguments as Map;
            presses.add((id, press['id'] as String, press['pressed'] as bool));
          }
          return null;
        });
      }
      if (call.method == 'acceptGesture' || call.method == 'rejectGesture') {
        gestures.add((call.method, (call.arguments as Map)['id'] as int));
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
    arguments.clear();
    updates.clear();
    gestures.clear();
    presses.clear();
  });

  for (final layout in ['list', 'grid']) {
    testWidgets(
      'real Discover $layout keeps rounded paint outside native clipping',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'discover_plugin_layout_v1': layout,
        });
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          BlocProvider(
            create: (_) => GlobalSettingCubit(),
            child: MaterialApp(
              navigatorKey: navigator,
              home: const DiscoverPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final plugin = _plugin('example');
        final cubit = tester
            .element(find.byType(Scaffold))
            .read<DiscoverCubit>();
        cubit.emit(
          DiscoverState(
            plugins: {'example': plugin},
            infoStates: const {
              'example': DiscoverPluginInfoState(
                loading: false,
                data: {'name': 'Example', 'iconUrl': ''},
              ),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(layout == 'list' ? PluginCard : PluginGridTile),
          findsOneWidget,
        );
        expectRectangularNativeAncestry(tester);
        final originals = tester.stateList(find.byType(UiKitView)).toList();
        final initial = cubit.state;
        final entry = find.byType(
          layout == 'list' ? PluginCard : PluginGridTile,
        );
        final entryBounds = tester.getRect(entry);
        final group = layout == 'list' ? _platformId(_iconGroups(entry)) : null;
        final topSearch = arguments.values.singleWhere(
          (control) =>
              control['symbol'] == 'magnifyingglass' &&
              control['tooltip'] != null,
        );
        expect(topSearch['flatSurface'], isNot(true));
        if (layout == 'grid') {
          final gridMenu = arguments.values.singleWhere(
            (control) =>
                control['symbol'] == 'ellipsis' &&
                (control['tooltip'] as String?)?.startsWith('Example') == true,
          );
          expect(gridMenu['flatSurface'], isNot(true));
        }
        Iterable<Map> rowButtons() =>
            (arguments[group]!['buttons'] as List).cast<Map>();
        Map<Object?, Object?> enabledButtons() => {
          for (final button in rowButtons()) button['id']: button['enabled'],
        };
        if (group != null) {
          expect(enabledButtons(), {'search': true, 'settings': true});
          expect(rowButtons(), everyElement(containsPair('flatSurface', true)));
          expect(
            rowButtons(),
            everyElement(containsPair('iconPressFeedback', true)),
          );
          expect(tester.getSize(_iconGroups(entry)), const Size(88, 44));
          final row = tester.widget<Row>(
            find
                .ancestor(of: _iconGroups(entry), matching: find.byType(Row))
                .first,
          );
          expect(
            row.children.last,
            isA<VideoControlAppearance>(),
            reason:
                'The UIKit group must composite above the adjacent Flutter switch.',
          );
          expect(
            tester.getRect(_iconGroups(entry)).right,
            tester
                .getRect(
                  find.byKey(const ValueKey('plugin-card.example.toggle')),
                )
                .left,
          );
          expect(updates[group] ?? 0, 0);
        }
        cubit.emit(initial.copyWith(pendingEnabled: const {'example': false}));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(tester.getRect(entry), entryBounds);
        if (group != null) {
          expect(enabledButtons(), {'search': false, 'settings': true});
          expect(updates[group], 1);
        }
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(originals),
        );
        cubit.emit(
          initial.copyWith(
            plugins: {'example': plugin.copyWith(isEnabled: false)},
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(entry), entryBounds);
        if (group != null) {
          expect(enabledButtons(), {'search': false, 'settings': true});
          expect(updates[group], 1);
        }
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(originals),
        );
        cubit.emit(initial);
        await tester.pumpAndSettle();
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(originals),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: SearchQueryField(query: '', inline: true)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expectRectangularNativeAncestry(tester);
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(originals),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final styleName in ['system', 'breeze']) {
    testWidgets(
      'Discover RTL $styleName list restores row controls after scrolling',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final style = ValueNotifier(styleName);
        addTearDown(style.dispose);
        await tester.pumpWidget(
          BlocProvider(
            create: (_) => GlobalSettingCubit(),
            child: AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                builder: (_, child) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
                home: const DiscoverPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cubit = tester
            .element(find.byType(Scaffold))
            .read<DiscoverCubit>();
        cubit.emit(
          DiscoverState(
            plugins: {
              for (var index = 0; index < 16; index++)
                'example-$index': _plugin('example-$index', index: index),
            },
            infoStates: {
              for (var index = 0; index < 16; index++)
                'example-$index': DiscoverPluginInfoState(
                  loading: false,
                  data: {
                    'name': 'Example $index',
                    'iconUrl': '',
                    if (index == 15)
                      'functions': [
                        {
                          'action': {'type': 'openWeb'},
                        },
                      ],
                  },
                ),
            },
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byWidgetPredicate(
          (widget) => widget is PluginCard && widget.pluginUuid == 'example-0',
        );
        final groups = _iconGroups(first);
        expect(first, findsOneWidget);
        int? firstId;
        if (styleName == 'system') {
          expect(groups, findsOneWidget);
          firstId = _platformId(groups);
          expect(arguments[firstId]?['rtl'], isTrue);
          expect(tester.getSize(groups).width, 88);
          expect(_platformLayers(tester), contains(firstId));
          final groupCenter = tester.getCenter(groups);
          final searchPress = await tester.startGesture(
            groupCenter + const Offset(22, 0),
          );
          await tester.pump();
          expect(presses, [(firstId, 'search', true)]);
          await searchPress.moveBy(const Offset(0, 28));
          await searchPress.cancel();
          await tester.pumpAndSettle();
          expect(presses.last, (firstId, 'search', false));
          final settingsPress = await tester.startGesture(
            groupCenter - const Offset(22, 0),
          );
          await tester.pump();
          expect(presses.last, (firstId, 'settings', true));
          await settingsPress.up();
          await tester.pumpAndSettle();
          expect(presses.last, (firstId, 'settings', false));
          final selector = find.byWidgetPredicate(
            (widget) =>
                widget is UiKitView &&
                (widget.creationParams as Map?)?['kind'] == 'segmented',
          );
          final selectorId = _platformId(selector);
          final center = tester.getCenter(selector);
          final drag = await tester.startGesture(center + const Offset(42, 0));
          await drag.moveBy(const Offset(-34, 0));
          await drag.moveBy(const Offset(-50, 0));
          await tester.pumpAndSettle();
          expect(arguments[selectorId]?['selected'], 'grid');
          expect(find.byType(PluginGridTile), findsNothing);
          await drag.cancel();
          await tester.pumpAndSettle();
          expect(arguments[selectorId]?['selected'], 'list');
          gestures.clear();
          await tester.dragFrom(center, const Offset(0, -100));
          expect(gestures, contains(('rejectGesture', selectorId)));
        } else {
          expect(find.byType(UiKitView), findsNothing);
        }
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(first, findsNothing);
        if (firstId != null) {
          expect(_platformLayers(tester), isNot(contains(firstId)));
          final last = find.byWidgetPredicate(
            (widget) =>
                widget is PluginCard && widget.pluginUuid == 'example-15',
          );
          final lastGroup = _iconGroups(last);
          expect(lastGroup, findsOneWidget);
          expect(tester.getSize(lastGroup).width, 44);
          final buttons = arguments[_platformId(lastGroup)]!['buttons'] as List;
          expect(buttons.map((button) => (button as Map)['id']), ['settings']);
        }
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(first, findsOneWidget);
        if (styleName == 'system') {
          expect(groups, findsOneWidget);
          final restoredId = _platformId(groups);
          expect(arguments[restoredId]?['rtl'], isTrue);
          expect(_platformLayers(tester), contains(restoredId));
          final selector = find.byWidgetPredicate(
            (widget) =>
                widget is UiKitView &&
                (widget.creationParams as Map?)?['kind'] == 'segmented',
          );
          final center = tester.getCenter(selector);
          await tester.dragFrom(
            center + const Offset(42, 0),
            const Offset(-84, 0),
          );
          await tester.pumpAndSettle();
          expect(find.byType(PluginGridTile), findsWidgets);
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString('discover_plugin_layout_v1'), 'grid');
          await tester.dragFrom(
            tester.getCenter(selector) - const Offset(42, 0),
            const Offset(84, 0),
          );
          await tester.pumpAndSettle();
          expect(first, findsOneWidget);
          expect(preferences.getString('discover_plugin_layout_v1'), 'list');
        } else {
          expect(find.byType(UiKitView), findsNothing);
          final selector = find.byType(BreezeSectionSelector<String>);
          final listSlot = tester.getCenter(selector) + const Offset(42, 0);
          final cancelled = await tester.startGesture(listSlot);
          await cancelled.moveBy(const Offset(-34, 0));
          await cancelled.moveBy(const Offset(-50, 0));
          await tester.pump();
          expect(find.byType(PluginGridTile), findsNothing);
          await cancelled.cancel();
          await tester.pumpAndSettle();
          expect(first, findsOneWidget);
          await tester.dragFrom(listSlot, const Offset(-84, 0));
          await tester.pumpAndSettle();
          expect(find.byType(PluginGridTile), findsWidgets);
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString('discover_plugin_layout_v1'), 'grid');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'system search lets UIKit own its capsule without a Flutter rounded clip',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SearchQueryField(query: 'text', inline: true)),
        ),
      );
      await tester.pumpAndSettle();
      expectRectangularNativeAncestry(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
