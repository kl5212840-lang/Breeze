import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

import '../test_helper.dart';

const _a = 'native-return-a', _b = 'native-return-b';
Map<String, dynamic> _info(String uuid, String version) => {
  'uuid': uuid, 'name': uuid == _a ? 'Fixture A' : 'Fixture B',
  'version': version, 'iconUrl': '', 'functions': [],
};
Uint8List _bytes(Object value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

class _Api extends RustLibApi {
  final runtimes = <String, QjsRuntimeBuildRequest>{};
  final calls = <String>[];
  Completer<void>? dropGate, dropStarted, freshRequested;
  Completer<Uint8List>? freshInfo;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({required String name}) async => runtimes.containsKey(name);
  @override
  Future<void> crateApiQjsBuildQjsRuntime({required QjsRuntimeBuildRequest request}) async { runtimes[request.runtimeName] = request; }
  @override
  Future<String> crateApiQjsQjsCurrentBundle({required String runtimeName}) async => jsonEncode(runtimes[runtimeName]?.bundle?.bundleName);
  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async {
    if (!runtimeName.startsWith('global') && dropGate != null) {
      if (dropStarted?.isCompleted == false) dropStarted!.complete();
      await dropGate!.future;
    }
    return runtimes.remove(runtimeName) != null;
  }
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({required String runtimeName, required String taskGroupKey,
    required bool isOnce, String? bundleJs, String? bundleUrl, required String fnPath, required String argsJson}) async {
    calls.add('$runtimeName:$fnPath:${bundleJs?.contains('new') == true}');
    if (fnPath == 'getInfo') {
      if (runtimeName == 'global') return _bytes(_info(_a, '1.1.0'));
      final uuid = runtimeName.contains(_b) || bundleJs?.contains(_b) == true ? _b : _a;
      final fresh = uuid == _a && bundleJs?.contains('new') == true;
      if (fresh && freshInfo != null) {
        if (freshRequested?.isCompleted == false) freshRequested!.complete();
        return freshInfo!.future;
      }
      return _bytes(_info(uuid, fresh ? '1.1.0' : '1.0.0'));
    }
    if (fnPath == 'getSettingsBundle') {
      return _bytes({'ok': true,
      'scheme': {'sections': []}, 'data': {'canLogin': false, 'canShowUserInfo': false, 'values': {}}});
    }
    if (fnPath == 'getCapabilitiesBundle') return _bytes({'ok': true, 'scheme': {'actions': []}, 'data': {}});
    if (fnPath == 'init') return _bytes({'ok': true});
    throw StateError('Unexpected offline function $fnPath');
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected native fixture API ${invocation.memberName}');
}

Set<int> _sceneIds(WidgetTester tester) {
  final ids = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) ids.add(layer.viewId);
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) { visit(child); child = child.nextSibling; }
    }
  }
  visit(tester.binding.renderViews.single.debugLayer!);
  return ids;
}
Finder _entry(String uuid, String layout) => layout == 'list'
    ? find.byWidgetPredicate((w) => w is PluginCard && w.pluginUuid == uuid, skipOffstage: false)
    : find.byWidgetPredicate((w) => w is PluginGridTile && w.pluginState.uuid == uuid, skipOffstage: false);
Map<int, State> _entryViews(WidgetTester tester, String uuid, String layout) {
  final result = <int, State>{};
  for (final element in find.descendant(of: _entry(uuid, layout),
      matching: find.byType(UiKitView, skipOffstage: false), skipOffstage: false).evaluate()) {
    void visit(RenderObject render) {
      if (render is RenderUiKitView) result[render.viewController.id] = (element as StatefulElement).state;
      render.visitChildren(visit);
    }
    visit(element.findRenderObject()!);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = PluginRegistryService.I;
  late _Api api;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final arguments = <int, Map<dynamic, dynamic>>{};
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _Api(); RustLib.initMock(api: api);
    await service.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => TestObjectBoxHelper.tempPath);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final id = args['id'] as int;
        final params = args['params'];
        if (params is Uint8List) arguments[id] = const StandardMessageCodec().decodeMessage(ByteData.sublistView(params)) as Map;
        final channel = MethodChannel('${args['viewType']}.$id'); channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (event) async {
          if (event.method == 'update' && event.arguments is Map) arguments[id] = event.arguments as Map;
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    if (api.dropGate?.isCompleted == false) api.dropGate!.complete();
    if (api.freshInfo?.isCompleted == false) api.freshInfo!.complete(_bytes(_info(_a, '1.1.0')));
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    for (final channel in channels) { messenger.setMockMethodCallHandler(channel, null); }
    channels.clear(); arguments.clear();
  });
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
  }
  Future<void> until(WidgetTester tester, bool Function() condition, String label) async {
    for (var i = 0; i < 60 && !condition(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue, reason: '$label; offline calls=${api.calls}');
  }

  for (final (layout, styleName, brightness, phase) in [
    ('list', 'system', Brightness.light, 'settled'),
    ('grid', 'system', Brightness.light, 'settled'),
    ('list', 'system', Brightness.dark, 'settled'),
    ('list', 'system', Brightness.light, 'exit-before-update'),
    ('list', 'system', Brightness.light, 'reverse-push'),
    ('list', 'system', Brightness.light, 'cancel-pop'),
    ('list', 'breeze', Brightness.light, 'settled'),
    ('grid', 'breeze', Brightness.dark, 'settled'),
  ]) {
    testWidgets('actual main Discover $layout $styleName $brightness restores native composition after update $phase', (tester) async {
      tester.view.physicalSize = const Size(430, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'discover_plugin_layout_v1': layout});
        api.runtimes.clear(); api.calls.clear(); api.dropGate = null; api.dropStarted = null; api.freshInfo = null; api.freshRequested = null;
        objectbox.pluginInfoBox.removeAll(); await service.refreshFromDb();
        for (final uuid in [_a, _b]) {
          await service.upsert(PluginInfo(uuid: uuid, version: '1.0.0', originScript: '$uuid old',
            insertedAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026), isEnabled: true,
            isDeleted: false, lastLoadSuccess: true, debug: false, sortOrder: uuid == _a ? 0 : 1,
            getInfoJson: jsonEncode(_info(uuid, '1.0.0'))));
        }
      });
      final style = ValueNotifier(styleName);
      final tabs = PersistentTabController();
      final global = GlobalSettingCubit();
      final registry = PluginRegistryCubit();
      addTearDown(style.dispose); addTearDown(tabs.dispose); addTearDown(global.close); addTearDown(registry.close);
      final observer = NativeCompositionObserver(candidateRoutes: const {'NavigationBar': {'PluginSettingsRoute', 'SearchRoute'}});
      final router = RootStackRouter.build(defaultRouteType: const RouteType.material(enablePredictiveBackGesture: false), routes: [
        NamedRouteDef(name: 'NavigationBar', path: '/', initial: true, builder: (_, _) => app.MainNativeTabHost(
          controller: tabs, screens: const [DiscoverPage(), SizedBox.shrink(), SizedBox.shrink()], navBarHeight: 84,
          navigation: VideoNativeNavigation(items: const [
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Shelf'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
          ], symbols: const ['safari', 'books.vertical', 'ellipsis.circle'], currentIndex: 0, onTap: tabs.jumpToTab))),
        NamedRouteDef(name: PluginSettingsRoute.name, path: '/plugin-settings', builder: (_, data) {
          final args = data.argsAs<PluginSettingsRouteArgs>();
          return PluginSettingsPage(from: args.from, pluginUuid: args.pluginUuid,
            pluginRuntimeName: args.pluginRuntimeName, pluginDisplayName: args.pluginDisplayName);
        }),
        NamedRouteDef(name: SearchRoute.name, path: '/plugin-search', builder: (_, data) {
          final args = data.argsAs<SearchRouteArgs>();
          expect(args.searchState.from, _a);
          expect(args.aggregateMode, isFalse);
          return const Scaffold(body: Text('Plugin search destination'));
        }),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MultiBlocProvider(providers: [BlocProvider.value(value: global), BlocProvider.value(value: registry)],
        child: AppInterfaceStyleScope(style: style, child: MaterialApp.router(
          theme: ThemeData(brightness: brightness, platform: TargetPlatform.iOS),
          routerConfig: router.config(navigatorObservers: () => [observer]),
          // ignore: deprecated_member_use
          builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
        ))));
      await frames(tester);
      final discover = tester.element(find.byType(CustomScrollView).first).read<DiscoverCubit>();
      await until(tester, () => discover.state.infoStates[_a]?.loading == false && discover.state.infoStates[_b]?.loading == false, 'initial real metadata');
      expect(find.byType(app.MainNativeTabHost), findsOneWidget);
      final unchangedViews = _entryViews(tester, _b, layout);
      if (styleName == 'system') expect(unchangedViews, hasLength(1));
      Future<void> nativeEvent(int id, MethodCall call) async {
        final completer = Completer<void>();
        tester.binding.channelBuffers.push('breeze.video.control.$id',
          const StandardMethodCodec().encodeMethodCall(call),
          (_) => completer.complete());
        await completer.future;
      }
      int cardGroupId() => _entryViews(tester, _a, layout).keys.singleWhere(
        (id) => arguments[id]?['kind'] == 'iconGroup',
      );
      if (layout == 'list' && styleName == 'system' &&
          brightness == Brightness.light && phase == 'settled') {
        await nativeEvent(cardGroupId(), const MethodCall('select', 'search'));
        await frames(tester);
        expect(router.current.name, SearchRoute.name);
        expect(find.text('Plugin search destination'), findsOneWidget);
        unawaited(router.maybePop());
        await frames(tester);
        expect(router.current.name, 'NavigationBar');
      }
      Future<void> settings() async {
        if (layout == 'list') {
          if (styleName == 'system') {
            await nativeEvent(cardGroupId(), const MethodCall('select', 'settings'));
          } else {
            await tester.tap(find.descendant(of: _entry(_a, layout), matching: find.byTooltip(t.discover.settings)));
          }
        } else {
          if (styleName == 'system') {
            final id = arguments.keys.singleWhere(
              (id) => arguments[id]?['tooltip'] == t.common.more,
            );
            await nativeEvent(id, const MethodCall('select', 'manage'));
          } else {
            await tester.tap(find.byTooltip(t.common.more));
            await tester.pumpAndSettle();
            await tester.tap(find.text(t.discover.pluginManagement));
          }
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('plugin-manager.actions.$_a')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('plugin-manager.settings.$_a')));
        }
        await tester.pump();
      }
      await settings();
      if (phase != 'reverse-push') {
        await frames(tester);
      } else {
        await tester.pump(const Duration(milliseconds: 110));
      }
      expect(router.current.name, PluginSettingsRoute.name);
      await tester.runAsync(() async {
        api.dropGate = Completer<void>(); api.dropStarted = Completer<void>();
        api.freshInfo = Completer<Uint8List>(); api.freshRequested = Completer<void>();
      });
      late Future<String> updating;
      await tester.runAsync(() async {
        updating = PluginInstallService.I.savePluginByScript('$_a new', sourceLabel: 'offline host fixture',
          expectedUuid: _a, allowReplaceExisting: true, initialize: false);
        await api.dropStarted!.future.timeout(const Duration(seconds: 5));
      });
      expect(service.snapshot[_a]!.version, '1.0.0', reason: 'registry publication hold is real');
      if (phase == 'exit-before-update' || phase == 'reverse-push') {
        unawaited(router.maybePop()); await frames(tester);
      }
      await tester.runAsync(() async { api.dropGate!.complete(); await updating.timeout(const Duration(seconds: 5)); });
      await until(tester, () => api.freshRequested!.isCompleted, 'new bundle getInfo starts in Discover');
      await tester.runAsync(() async { api.freshInfo!.complete(_bytes(_info(_a, '1.1.0'))); });
      await until(tester, () => discover.state.infoStates[_a]?.data?['version'] == '1.1.0' && discover.state.infoStates[_a]?.loading == false, 'fresh bundle metadata publishes');
      expect(service.getCachedPluginInfo(_a)?['version'], '1.1.0');
      if (phase == 'cancel-pop') {
        final gesture = await tester.startGesture(const Offset(5, 450));
        await gesture.moveBy(const Offset(130, 0), timeStamp: const Duration(milliseconds: 100)); await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(-120, 0), timeStamp: const Duration(milliseconds: 200)); await gesture.up(); await frames(tester);
        expect(router.current.name, PluginSettingsRoute.name, reason: 'cancelled gesture retains the settings page');
      }
      if (router.current.name == PluginSettingsRoute.name) { unawaited(router.maybePop()); await frames(tester); }
      await frames(tester);
      expect(router.current.name, 'NavigationBar');
      if (layout == 'grid') {
        await tester.tap(find.byKey(const ValueKey('plugin-manager.close')));
        await frames(tester);
      }
      expect(discover.state.plugins[_a]?.isEnabled, isTrue);
      expect(discover.state.plugins[_b]?.isEnabled, isTrue);
      expect(discover.state.infoStates[_a]?.error, isNull);
      expect(discover.state.infoStates[_b]?.error, isNull);
      expect(discover.state.infoStates[_a]?.data?['name'], 'Fixture A');
      expect(discover.state.infoStates[_b]?.data?['name'], 'Fixture B');
      expect(_entry(_a, layout), findsOneWidget); expect(_entry(_b, layout), findsOneWidget);
      final returnedA = _entryViews(tester, _a, layout), returnedB = _entryViews(tester, _b, layout);
      expect(returnedB.keys, unorderedEquals(unchangedViews.keys), reason: 'the unrelated plugin must retain its UIKit instances');
      for (final id in returnedB.keys) {
        expect(returnedB[id], same(unchangedViews[id]));
      }
      if (styleName == 'system') {
        expect(returnedA, hasLength(1));
        for (final uuid in [_a, _b]) {
          for (final element in find.descendant(of: _entry(uuid, layout), matching: find.byType(UiKitView)).evaluate()) {
            final box = element.findRenderObject() as RenderBox;
            expect(box.size.width, greaterThanOrEqualTo(44));
            expect(box.size.height, greaterThanOrEqualTo(44));
          }
        }
        final expected = {...returnedA.keys, ...returnedB.keys};
        expect(_sceneIds(tester).containsAll(expected), isTrue,
          reason: 'all actual native card controls must re-enter the scene without a plugin toggle; expected=$expected scene=${_sceneIds(tester)}');
      } else {
        expect(returnedA, isEmpty); expect(returnedB, isEmpty);
        final controls = find.descendant(
          of: _entry(_a, layout),
          matching: layout == 'list'
              ? find.byType(SourceChromeIconButton)
              : find.byKey(const ValueKey('plugin-grid.$_a.manage')),
        );
        expect(controls, findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
