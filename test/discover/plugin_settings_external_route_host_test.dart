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
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import '../test_helper.dart';

const _a = bikaPlusSourceId, _b = 'external-generic-source';
Map<String,dynamic> _info(String uuid, String version) => {
  'uuid':uuid, 'name':uuid == _a ? 'Declared Bika' : 'Generic source', 'version':version, 'iconUrl':'',
  'function':[{'id':'home','title':'首页'}],
  if(uuid == _a) 'breezeExperience':{
    'bikaExperience':{'version':1,'appearanceKey':bikaExperienceAppearanceKey,'loadingArtwork':bikaExperienceArtwork},
  },
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

Finder _entry(String uuid, String layout) => layout == 'list'
    ? find.byWidgetPredicate((w) => w is PluginCard && w.pluginUuid == uuid, skipOffstage: false)
    : find.byWidgetPredicate((w) => w is PluginGridTile && w.pluginState.uuid == uuid, skipOffstage: false);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service=PluginRegistryService.I;
  late _Api api;
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels=<MethodChannel>[];
  final arguments=<int,Map<dynamic,dynamic>>{};
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  setUpAll(()async{
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
    api=_Api();RustLib.initMock(api:api);await service.init();
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  setUp((){
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),(_)async=>TestObjectBoxHelper.tempPath);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async{
      if(call.method=='create'){
        final args=call.arguments as Map,id=args['id'] as int,params=args['params'];
        if(params is Uint8List)arguments[id]=const StandardMessageCodec().decodeMessage(ByteData.sublistView(params)) as Map;
        final channel=MethodChannel('${args['viewType']}.$id');channels.add(channel);
        messenger.setMockMethodCallHandler(channel,(event)async{
          if(event.method=='update' && event.arguments is Map)arguments[id]=event.arguments as Map;
          return null;
        });
      }return null;
    });
  });
  tearDown((){
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),null);
    for(final channel in channels){messenger.setMockMethodCallHandler(channel,null);}
    channels.clear();arguments.clear();
  });
  Future<void> frames(WidgetTester tester)async{
    for(var i=0;i<8;i++){await tester.runAsync(()=>Future<void>.delayed(Duration.zero));await tester.pump(const Duration(milliseconds:100));}
  }
  Future<void> event(WidgetTester tester,int id,String method,[Object? value])async{
    final done=Completer<void>();
    tester.binding.channelBuffers.push('breeze.video.control.$id',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method,value)),(_)=>done.complete());
    await done.future;await tester.pump();
  }
  for(final layout in ['list','grid']) {
    for(final styleName in ['system','breeze']) {
      testWidgets('real Discover $layout/$styleName keeps external settings complete for declared Bika and generic sources', (tester)async{
        tester.view.physicalSize=const Size(430,1000);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(()async{
          SharedPreferences.setMockInitialValues({'discover_plugin_layout_v1':layout});
          api.runtimes.clear();api.calls.clear();objectbox.pluginInfoBox.removeAll();
          await service.refreshFromDb();
          for(final uuid in [_a,_b]){
            await service.upsert(PluginInfo(uuid:uuid,version:'1.0.0',originScript:'$uuid old',
              insertedAt:DateTime.utc(2026),updatedAt:DateTime.utc(2026),isEnabled:true,
              isDeleted:false,lastLoadSuccess:true,debug:false,sortOrder:uuid==_a?0:1,
              getInfoJson:jsonEncode(_info(uuid,'1.0.0'))));
          }
        });
        expect(supportsBikaExperienceDeclaration(_a,_info(_a,'1.0.0')),isTrue);
        expect(supportsBikaExperienceDeclaration(_b,_info(_b,'1.0.0')),isFalse);
        final style=ValueNotifier(styleName),tabs=PersistentTabController();
        final global=GlobalSettingCubit(),registry=PluginRegistryCubit();
        addTearDown(style.dispose);addTearDown(tabs.dispose);addTearDown(global.close);addTearDown(registry.close);
        final received=<String,PluginSettingsRouteArgs>{};
        final router=RootStackRouter.build(defaultRouteType:const RouteType.material(enablePredictiveBackGesture:false),routes:[
          NamedRouteDef(name:'NavigationBar',path:'/',initial:true,builder:(_,_)=>app.MainNativeTabHost(
            controller:tabs,screens:const [DiscoverPage(),SizedBox.shrink(),SizedBox.shrink()],navBarHeight:84,
            navigation:VideoNativeNavigation(items:const [
              BottomNavigationBarItem(icon:Icon(Icons.explore),label:'Discover'),
              BottomNavigationBarItem(icon:Icon(Icons.book),label:'Shelf'),
              BottomNavigationBarItem(icon:Icon(Icons.more_horiz),label:'More')],
              symbols:const ['safari','books.vertical','ellipsis.circle'],currentIndex:0,onTap:tabs.jumpToTab))),
          NamedRouteDef(name:PluginSettingsRoute.name,path:'/plugin-settings',builder:(_,data){
            final args=data.argsAs<PluginSettingsRouteArgs>();received[args.pluginUuid]=args;
            return PluginSettingsPage(from:args.from,pluginUuid:args.pluginUuid,
              pluginRuntimeName:args.pluginRuntimeName,pluginDisplayName:args.pluginDisplayName,
              insideSource:args.insideSource,scope:args.scope);
          }),
          // A real production source menu exercises the unchanged internal
          // canonical helper in the same router; this is not a factory-only test.
          NamedRouteDef(name:'InternalFixture',path:'/inside/:source',builder:(_,data){
            final source=data.params.getString('source');
            return SourceExperienceBoundary(source:source,builder:(_)=>Scaffold(
              appBar:AppBar(actions:[SourceMoreButton(source:source)]),body:const Text('Source content')));
          }),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MultiBlocProvider(providers:[BlocProvider.value(value:global),BlocProvider.value(value:registry)],
          child:AppInterfaceStyleScope(style:style,child:MaterialApp.router(theme:ThemeData(platform:TargetPlatform.iOS),
            routerConfig:router.config(),
            // ignore: deprecated_member_use
            builder:(_,child)=>MaterialUiCompatibilityBridge(child:child!)))));
        await frames(tester);
        final discover=tester.element(find.byType(CustomScrollView).first).read<DiscoverCubit>();
        for(var i=0;i<60 && (discover.state.infoStates[_a]?.loading!=false || discover.state.infoStates[_b]?.loading!=false);i++){
          await frames(tester);
        }
        expect(discover.state.infoStates[_a]?.loading,isFalse);
        expect(discover.state.infoStates[_b]?.loading,isFalse);
        for(final uuid in [_a,_b]){
          final entry=_entry(uuid,layout);
          expect(entry,findsOneWidget);
          if(styleName=='system'){
            final id=arguments.keys.singleWhere(
              (id) => arguments[id]?['tooltip'] == t.common.more,
            );
            await event(tester,id,'select','manage');
          }else{
            await tester.tap(find.byTooltip(t.common.more));
            await tester.pumpAndSettle();
            await tester.tap(find.text(t.discover.pluginManagement));
          }
          await frames(tester);
          final visibility = find.byKey(ValueKey('plugin-manager.visible.$uuid'));
          final actions = find.byKey(ValueKey('plugin-manager.actions.$uuid'));
          if (layout == 'list') {
            expect(visibility, findsOneWidget);
            expect(actions, findsNothing);
            await tester.tap(find.byKey(const ValueKey('plugin-manager.cancel')));
            await frames(tester);
            if (styleName == 'system') {
              final view = find.descendant(
                of: entry,
                matching: find.byType(UiKitView),
              );
              expect(view, findsOneWidget);
              final ids = <int>[];
              void collectViewIds(RenderObject render) {
                if (render is RenderUiKitView) {
                  ids.add(render.viewController.id);
                }
                render.visitChildren(collectViewIds);
              }

              collectViewIds(tester.renderObject(view));
              final id = ids.single;
              expect(arguments[id]?['kind'], 'iconGroup');
              await event(tester, id, 'select', 'settings');
            } else {
              final settings = find.descendant(
                of: entry,
                matching: find.byWidgetPredicate(
                  (widget) => widget is SourceChromeIconButton &&
                      widget.tooltip == t.discover.settings,
                ),
              );
              tester.widget<SourceChromeIconButton>(settings).onPressed!();
            }
          } else {
            await tester.tap(visibility);
            await tester.tap(actions);
            await frames(tester);
            await tester.tap(find.byKey(ValueKey('plugin-manager.settings.$uuid')));
          }
          await frames(tester);
          expect(router.current.name,PluginSettingsRoute.name);
          final args=received[uuid]!;
          expect(args.from,uuid);expect(args.pluginUuid,uuid);expect(args.pluginRuntimeName,uuid);
          expect(args.pluginDisplayName,uuid==_a?'Declared Bika':'Generic source');
          expect(args.insideSource,isFalse);expect(args.scope,PluginSettingsScope.all);
          final page=tester.widget<PluginSettingsPage>(find.byType(PluginSettingsPage));
          expect(page.insideSource,isFalse);expect(page.scope,PluginSettingsScope.all);
          expect(find.byType(SourceShellPage),findsNothing);
          await router.maybePop();await frames(tester);
          if (layout == 'grid') {
            expect(tester.widget<Switch>(visibility).value,isFalse);
            await tester.tap(find.byKey(const ValueKey('plugin-manager.cancel')));
            await frames(tester);
            final tileMenu = find.byKey(ValueKey('plugin-grid.$uuid.manage'));
            final menu = tester.widget<NativeVideoMenu>(tileMenu);
            expect(menu.options['settings'], t.discover.settings);
            expect(menu.selectAfterDismissal, contains('settings'));
            received.remove(uuid);
            if (styleName == 'system') {
              final id = arguments.keys.singleWhere(
                (id) => arguments[id]?['tooltip'] == menu.tooltip,
              );
              await event(tester, id, 'select', 'settings');
            } else {
              await tester.tap(tileMenu);
              await tester.pumpAndSettle();
              await tester.tap(find.text(t.discover.settings));
            }
            await frames(tester);
            expect(router.current.name, PluginSettingsRoute.name);
            expect(received[uuid]!.pluginUuid, uuid);
            expect(received[uuid]!.scope, PluginSettingsScope.all);
            await router.maybePop();
            await frames(tester);
          }
          expect(entry,findsOneWidget);
          unawaited(router.pushPath('/inside/$uuid'));await frames(tester);
          final sourceMenu=find.descendant(of:find.byType(SourceMoreButton),matching:find.byType(NativeVideoMenu));
          expect(sourceMenu,findsOneWidget);
          tester.widget<NativeVideoMenu>(sourceMenu).onSelected('__source_settings');
          await frames(tester);
          if(uuid==_a){
            final internal=tester.widget<SourceShellPage>(find.byType(SourceShellPage));
            expect(internal.source,uuid);expect(internal.initialSectionId,'bikaSettings');
            expect(find.byType(PluginSettingsPage),findsNothing);
          }else{
            final internal=tester.widget<PluginSettingsPage>(find.byType(PluginSettingsPage));
            expect(internal.insideSource,isTrue);expect(internal.scope,PluginSettingsScope.all);
          }
          await tester.binding.handlePopRoute();await frames(tester);
          await router.maybePop();await frames(tester);
          expect(router.current.name,'NavigationBar');
        }
        expect(received,hasLength(2));expect(tester.takeException(),isNull);
        await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
      },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
