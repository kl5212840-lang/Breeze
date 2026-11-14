import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show DebugCreator;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

List<Layer> paintLeaves(Layer layer){
  if(layer is ContainerLayer){
    final result=<Layer>[];
    var child=layer.firstChild;
    while(child!=null){result.addAll(paintLeaves(child));child=child.nextSibling;}
    return result;
  }
  return layer is PictureLayer || layer is PlatformViewLayer ? [layer] : [];
}

String layerOwners(Layer leaf){
  final owners=<String>[];
  Layer? layer=leaf;
  while(layer!=null && owners.length<12){
    final creator=layer.debugCreator;
    owners.add('${layer.runtimeType}#${identityHashCode(layer)}:${creator is DebugCreator ? creator.element.widget.runtimeType : creator?.runtimeType}');
    layer=layer.parent;
  }
  return owners.join(' <- ');
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real preparation route paints all Flutter body before its 44pt native back and preserves safe-area geometry, visibility and return',(tester)async{
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize=const Size(440,956);tester.view.devicePixelRatio=1;
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channels=<int,MethodChannel>{},live=<int>{};
    final style=ValueNotifier('system');
    final navigator=GlobalKey<NavigatorState>();
    final media=Completer<Map<String,dynamic>>();
    final home=Uri.parse('https://composition-fixture.test/');
    final raw=<String,dynamic>{'id':'42','title':'真实准备页正文','detailUrl':'https://composition-fixture.test/voddetail/42.html',
      'description':'准备期间应保持完整绘制的作品简介。','lines':[{'id':'main','label':'线路一','episodes':[
        {'id':'one','title':'第01集','resolveOnPlayback':true,'watchUrl':'https://composition-fixture.test/voddetail/42.html?line=main&episode=one'}]}]};
    final item=ApiVideoItem.fromJson(raw,home:home);
    final repository=ApiVideoRepository(source:'composition-foreground-fixture',home:home,catalogFn:'list',detailFn:'detail',playbackFn:'play',
      pluginCall:(path,_)async=>path=='play'?media.future:{'data':raw});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async{
      if(call.method=='create'){
        final args=call.arguments as Map,id=args['id'] as int;live.add(id);
        final channel=MethodChannel('${args['viewType']}.$id');channels[id]=channel;
        messenger.setMockMethodCallHandler(channel,(_)async=>null);
      }else if(call.method=='dispose')live.remove(call.arguments as int);
      return null;
    });
    Future<void> replies()async{
      await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));
      await tester.pump();
    }
    try{
      await tester.pumpWidget(AppInterfaceStyleScope(style:style,child:MaterialApp(
        navigatorKey:navigator,
        navigatorObservers:[NativeCompositionObserver(candidateOpaqueDestinations:const {omoVideoDetailRouteName})],
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(padding:const EdgeInsets.only(top:60,bottom:34)),child:child!),
        onGenerateRoute:(_)=>videoPageRoute<void>(settings:const RouteSettings(name:apiVideoLibraryRouteName),builder:(context)=>Scaffold(
          appBar:AppBar(title:const SearchFieldSurface(child:Text('source search'))),
          body:Center(child:TextButton(key:const ValueKey('open-preparation'),onPressed:()=>Navigator.of(context).push(videoPageRoute<void>(
            settings:const RouteSettings(name:omoVideoDetailRouteName),builder:(_)=>ApiVideoDetailPage(repository:repository,initialItem:item))),child:const Text('Open'))),
          bottomNavigationBar:VideoNativeNavigation(currentIndex:0,onTap:(_){},symbols:const ['house','person'],items:const [
            BottomNavigationBarItem(icon:Icon(Icons.home),label:'Library'),BottomNavigationBarItem(icon:Icon(Icons.person),label:'Account')]),
        )),
      )));
      await replies();await replies();
      final sourceIds=Set<int>.of(live);
      await tester.tap(find.byKey(const ValueKey('open-preparation')));await tester.pump();
      await tester.pump(const Duration(milliseconds:250));await replies();
      final back=find.byKey(const ValueKey('api-initial.back'));
      final nativeBack=find.descendant(of:back,matching:find.byType(UiKitView));
      expect(nativeBack,findsOneWidget);expect(find.byType(NativeVideoPage),findsNothing);
      final state=tester.state(nativeBack);
      final platformRenders=<RenderUiKitView>[];
      void visitNativeRender(RenderObject render){
        if(render is RenderUiKitView)platformRenders.add(render);
        render.visitChildren(visitNativeRender);
      }
      // UiKitView's root is a semantics wrapper in this SDK. Find the actual
      // platform render descendant and retain the real native controller ID.
      visitNativeRender(tester.renderObject(nativeBack));
      expect(platformRenders,hasLength(1));
      final backId=platformRenders.single.viewController.id;
      expect(tester.getSize(back),const Size(44,44));
      expect(tester.getTopLeft(back)-tester.getTopLeft(find.byType(ApiVideoDetailPage)),const Offset(8,68),
        reason:'The 44pt back keeps its safe-area offset while the actual route is sliding');
      void expectPagePaintOrder(String phase){
        // ModalRoute already isolates buildPage with this RepaintBoundary;
        // use its actual retained layer, without inserting a test boundary.
        // The separate outer route boundary includes transitions/Overlay.
        final route=ModalRoute.of(tester.element(find.byType(ApiVideoDetailPage)))!;
        final render=route.subtreeContext!.findRenderObject();
        expect(render,isA<RenderRepaintBoundary>());
        final pageLayer=(render! as RenderRepaintBoundary).debugLayer!;
        final pageLeaves=paintLeaves(pageLayer);
        final sceneLeaves=paintLeaves(tester.binding.renderViews.single.debugLayer!);
        final nativeIndex=sceneLeaves.indexWhere((layer)=>layer is PlatformViewLayer && layer.viewId==backId);
        expect(nativeIndex,greaterThanOrEqualTo(0));
        final trailing=sceneLeaves.skip(nativeIndex+1).toList();
        // Attribute every trailing picture before asserting, so a failed
        // candidate reports whether its owner is page or route decoration.
        for(final layer in trailing.whereType<PictureLayer>()){
          debugPrint('COMPOSITION_PICTURE $phase inPage=${pageLeaves.contains(layer)} ${layerOwners(layer)}');
        }
        expect(pageLeaves.whereType<PictureLayer>(),isNotEmpty);
        expect(pageLeaves.last,isA<PlatformViewLayer>(),
          reason:'No PictureLayer anywhere inside the real incoming buildPage may paint after its native back ($phase)');
        expect((pageLeaves.last as PlatformViewLayer).viewId,backId);
        expect(sceneLeaves,containsAllInOrder(pageLeaves));
        for(final layer in trailing){
          expect(pageLeaves, isNot(contains(layer)),
            reason:'Every scene layer after native back must be outside incoming buildPage, never ignored body paint ($phase)');
        }
      }
      expectPagePaintOrder('enter-250ms');
      await tester.pump(const Duration(milliseconds:350));await replies();
      expect(tester.getTopLeft(back),const Offset(8,68));
      expectPagePaintOrder('settled');
      final surface=find.byKey(const ValueKey('api-initial.gesture-surface'));
      await tester.tapAt(tester.getTopLeft(surface)+const Offset(130,20));await tester.pump(const Duration(milliseconds:180));
      expect(back.hitTestable(),findsNothing);
      await tester.tapAt(tester.getTopLeft(surface)+const Offset(130,20));await tester.pump(const Duration(milliseconds:180));
      expect(back.hitTestable(),findsOneWidget);expect(tester.state(nativeBack),same(state));
      expect(tester.getRect(back),const Rect.fromLTWH(8,68,44,44));
      // Invoke the actual native-control bridge rather than a Flutter-only back substitute.
      await messenger.handlePlatformMessage(channels[backId]!.name,const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),(_){});
      await tester.pump();await tester.pump(const Duration(milliseconds:600));await replies();
      expect(find.byType(ApiVideoDetailPage),findsNothing);
      expect(find.byKey(const ValueKey('open-preparation')),findsOneWidget);
      expect(live.containsAll(sourceIds),isTrue,reason:'Source platform views survive ordinary return');
      media.complete({'data':{'item':raw,'lineId':'main','episodeId':'one',
        'watchUrl':'https://composition-fixture.test/voddetail/42.html?line=main&episode=one',
        'sources':[{'url':'https://media-fixture.test/video.mp4','quality':'720p'}]}});
      await replies();await replies();
      expect(find.byType(NativeVideoPage),findsNothing,reason:'A late resolver cannot revive a popped route');
      expect(tester.takeException(),isNull);
    }finally{
      if(!media.isCompleted)media.complete({'data':raw});
      await tester.pumpWidget(const SizedBox.shrink());await tester.pump(const Duration(milliseconds:600));await replies();
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
      for(final channel in channels.values)messenger.setMockMethodCallHandler(channel,null);
      style.dispose();tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    }
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
}
