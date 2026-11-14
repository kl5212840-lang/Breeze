import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/api_video_episode_download.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_download_panel.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../download_fixture.dart';
import '../test_helper.dart';

class _Tabs extends StatefulWidget {
  const _Tabs(this.keys);
  final Set<String> keys;
  @override State<_Tabs> createState()=>_TabsState();
}
class _TabsState extends State<_Tabs>{
  final tabs=PersistentTabController();
  @override void initState(){
    super.initState();
    DownloadCenterNavigation.attach(this,()async{
      if(!mounted)return false;
      tabs.jumpToTab(1);
      return true;
    });
  }
  @override void dispose(){DownloadCenterNavigation.detach(this);tabs.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>MainNativeTabHost(
    controller:tabs,navBarHeight:50,floatingNavigation:false,
    navigation:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
      TextButton(key:const ValueKey('main-source'),onPressed:()=>tabs.jumpToTab(0),child:const Text('Source')),
      TextButton(key:const ValueKey('main-downloads'),onPressed:()=>tabs.jumpToTab(1),child:const Text('Main Downloads')),
    ]),screens:[
      Scaffold(body:SafeArea(child:VideoDownloadPanel(title:'Selected episodes',onClose:(){},
        child:SingleChildScrollView(child:VideoDownloadCurrentTasks(taskKeys:widget.keys))))),
      const DownloadTaskPage(embedded:true),
    ]);
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets('Omo public episode enqueue is durable and visible in the sole main Downloads tab before media completes, even when HLS index never replies',(tester)async{
    final connectivity = DownloadConnectivityFixture();
    addTearDown(connectivity.close);
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const download=MethodChannel('breeze.video.download');
    final channels=<MethodChannel>[];
    final nativeResult=Completer<Object?>(), started=Completer<void>(),index=Completer<Object?>();
    var holdPageInventory = false;
    var preflightIndexReads = 0, heldIndexReads = 0;
    final old=debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride=TargetPlatform.iOS;
    final style=ValueNotifier('breeze');
    const source='omo-enqueue-visibility-host';
    final home=Uri.parse('https://www.omofuna.com/'),detail=Uri.parse('https://www.omofuna.com/anime/1234567890abcdef.html');
    final raw=<String,dynamic>{'id':'1234567890abcdef','title':'Omo persisted work','detailUrl':'$detail',
      'lines':[{'id':'1','label':'线路1','episodes':[
        for(var i=1;i<=2;i++){'id':'$i','title':'第0$i集','resolveOnPlayback':true,'watchUrl':'$detail?line=1&episode=$i'}]}]};
    final item=ApiVideoItem.fromJson(raw,home:home);
    final cards=[for(final episode in item.lines.single.episodes)
      NativeVideoCard(title:item.title,watchUrl:episode.watchUrl,coverUrl:null,episodeLabel:episode.title)];
    final calls=<String>[];
    final repository=ApiVideoRepository(source:source,home:home,catalogFn:'list',detailFn:'detail',playbackFn:'play',
      pluginCall:(fn,args)async{
        calls.add(fn);
        if(fn!='play')return {'data':raw};
        return {'data':{'item':raw,'lineId':args['lineId'],'episodeId':args['episodeId'],
          'watchUrl':'$detail?line=${args['lineId']}&episode=${args['episodeId']}',
          'sources':[{'url':'https://media-fixture.test/video.mp4?signature=ephemeral','quality':'720p'}]}};
      });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async{
      if(call.method=='create'){
        final args=call.arguments as Map;final channel=MethodChannel('${args['viewType']}.${args['id']}');channels.add(channel);
        messenger.setMockMethodCallHandler(channel,(_)async=>null);
      }return null;
    });
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
      if (call.method != 'list') return null;
      if (!holdPageInventory) {
        preflightIndexReads++;
        return <Object?>[];
      }
      heldIndexReads++;
      return index.future;
    });
    messenger.setMockMethodCallHandler(download,(call)async{
      if(call.method=='start'){if(!started.isCompleted)started.complete();return nativeResult.future;}
      if(call.method=='cancel' && !nativeResult.isCompleted)nativeResult.complete('cancelled');
      return null;
    });
    Future<void> until(bool Function() condition,String stage)async{
      for(var i=0;i<250 && !condition();i++){
        await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));
        await tester.pump(const Duration(milliseconds:16));
      }expect(condition(),isTrue,reason:stage);
    }
    Future<T> finish<T>(Future<T> future,String stage)async{
      T? value;Object? failure;StackTrace? trace;var completed=false;
      future.then<void>((result){value=result;completed=true;},onError:(Object error,StackTrace stack){failure=error;trace=stack;completed=true;});
      // The future was created by the live widget/FakeAsync zone. Keep
      // pumping that zone while real file/native replies are delivered.
      await until(()=>completed,stage);
      if(failure!=null)Error.throwWithStackTrace(failure!,trace!);
      return value as T;
    }
    List<String> keys=const [];
    try{
      await tester.runAsync(()async{
        SharedPreferences.setMockInitialValues({});await useIsolatedDownloadFixture();VideoLocalResources.invalidate();
        objectbox.unifiedDownloadBox.removeAll();objectbox.downloadTaskBox.removeAll();
        objectbox.unifiedDownloadBox.put(createTestDownload('visible-comic'));
        keys=await ApiVideoEpisodeDownloads.enqueue(repository,item,cards);
      });
      expect(keys,hasLength(2));
      final persisted=(await tester.runAsync(()=>SharedPreferences.getInstance()))!.getString(VideoExportRecords.taskStorageKey)!;
      for(final key in keys)expect(persisted,contains(key));
      expect(persisted,isNot(contains('signature=')));
      await until(() => started.isCompleted,
        'the first queued transfer starts after checking for an existing local file');
      expect(preflightIndexReads, greaterThan(0));
      // Only the download page's first inventory is withheld. The engine's
      // existing-file check belongs to admission, before native transfer.
      holdPageInventory = true;
      await tester.pumpWidget(AppInterfaceStyleScope(style:style,child:MaterialApp(home:_Tabs(keys.toSet()))));
      await until(()=>find.textContaining('Omo persisted work').evaluate().length>=2,'the actual task panel reads queued membership without media/index enumeration');
      expect(index.isCompleted,isFalse);expect(nativeResult.isCompleted,isFalse);
      await tester.tap(find.byKey(const ValueKey('video-download-tasks')));
      await until(()=>find.byWidgetPredicate((widget)=>widget is DownloadTaskPage && widget.embedded).evaluate().isNotEmpty,'the real panel link switches to the existing main Downloads tab');
      await until(()=>find.textContaining('Omo persisted work').evaluate().length>=2 && find.textContaining('Test Comic visible-comic').evaluate().isNotEmpty,'queued/running videos and existing comics are visible before resource enrichment');
      await until(() => heldIndexReads > 0, 'the first page inventory really waits for native HLS');
      expect(index.isCompleted, isFalse);
      expect(find.byWidgetPredicate((widget)=>widget is DownloadTaskPage && !widget.embedded),findsNothing,reason:'The task link never creates an independent download route');
      expect(find.byType(DownloadTaskPage),findsOneWidget);
      final mountedDownloads=tester.element(find.byType(DownloadTaskPage));
      expect(find.byType(CircularProgressIndicator),findsNothing);
      expect(nativeResult.isCompleted,isFalse,reason:'Visibility must not depend on completing video bytes');
      await tester.tap(find.byKey(const ValueKey('main-source')));await tester.pump();
      await tester.tap(find.byKey(const ValueKey('main-downloads')));await tester.pump();
      await until(()=>find.textContaining('Omo persisted work').evaluate().length>=2,'manually returning to main Downloads retains the same queue');
      expect(tester.element(find.byType(DownloadTaskPage)),same(mountedDownloads),reason:'The same mounted main tab is reused');
      expect(find.byType(CircularProgressIndicator),findsNothing);
      await tester.pump(const Duration(seconds: 11));
      final retry = find.text('${t.common.refreshRetained} · ${t.common.retry}');
      await until(() => retry.evaluate().isNotEmpty,
        'A never-reply read ends in an explicit retryable error, while cards remain');
      expect(retry, findsOneWidget);
      expect(find.textContaining('Omo persisted work'),findsWidgets);expect(find.textContaining('Test Comic visible-comic'),findsWidgets);
      expect(nativeResult.isCompleted,isFalse);expect(index.isCompleted,isFalse);
      expect(calls.where((fn)=>fn=='play'),hasLength(1),reason:'The second public episode remains queued, never resolved early');
    }finally{
      if(!index.isCompleted)index.complete([]);
      if(!nativeResult.isCompleted)nativeResult.complete('cancelled');
      await finish(VideoEpisodeDownloadQueue.flush(),'retire the real serial batch while delivering native and storage replies');
      await tester.pumpWidget(const SizedBox.shrink());await tester.pump(const Duration(seconds:11));
      messenger.setMockMethodCallHandler(download,null);messenger.setMockMethodCallHandler(VideoHlsAssets.channel,null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
      for(final channel in channels)messenger.setMockMethodCallHandler(channel,null);
      objectbox.unifiedDownloadBox.removeAll();objectbox.downloadTaskBox.removeAll();
      style.dispose();debugDefaultTargetPlatformOverride=old;
    }
  });
}
