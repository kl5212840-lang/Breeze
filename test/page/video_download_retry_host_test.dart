import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets('failed download card retries in place, refreshes its signed address and saves without a second task', (tester) async {
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel=MethodChannel('breeze.video.download');
    const connectivity=MethodChannel('dev.fluttercommunity.plus/connectivity');
    const connectivityStatus=MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    const source='retry-card-source';
    final style=ValueNotifier('breeze');
    final previous=debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride=TargetPlatform.iOS;
    final channels=<MethodChannel>[];
    Object? resolver;
    var starts=0;
    String? originalKey;
    Future<void> until(bool Function() ready,String stage) async {
      for(var i=0;i<250 && !ready();i++) {
        await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));
        await tester.pump(const Duration(milliseconds:16));
      }
      expect(ready(),isTrue,reason:stage);
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
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async {
      if(call.method=='create') {
        final args=call.arguments as Map;
        final view=MethodChannel('${args['viewType']}.${args['id']}');channels.add(view);
        messenger.setMockMethodCallHandler(view,(_)async=>null);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel,(_)async=>[]);
    messenger.setMockMethodCallHandler(connectivity,(_)async=>['wifi']);
    messenger.setMockMethodCallHandler(connectivityStatus,(_)async=>null);
    try {
      await tester.runAsync(()async {
        SharedPreferences.setMockInitialValues({});await useIsolatedDownloadFixture();VideoLocalResources.invalidate();
        originalKey=await VideoExportRecords.beginTransfer(source:source,video:Uri.parse('https://source.test/watch?v=95'),title:'Retry work',quality:'720p');
        await VideoExportRecords.updateTransfer(originalKey!,received:null,status:'failed',terminal:true,failureReason:'httpForbidden');
      });
      resolver=VideoDownloadRetry.register(source,(row)async {
        expect(row['key'],originalKey);expect(row['quality'],'720p');
        return VideoDownloadRetryResolution(choices:[(label:'720p',format:'mp4',url:Uri.parse('https://fresh.test/download.mp4?signature=new'))]);
      },current:()=>true);
      messenger.setMockMethodCallHandler(channel,(call)async {
        if(call.method!='start')return null;
        starts++;
        final args=call.arguments as Map;expect(args['url'],'https://fresh.test/download.mp4?signature=new');
        final stage=await VideoLocalResources.stagedFile('b'*32);await stage.parent.create(recursive:true);
        await stage.writeAsBytes(Uint8List(4096)..setAll(0,[0,0,0,24,102,116,121,112]));
        return {'status':'staged','resourceId':args['managedId'],'stageId':'b'*32,'bytes':4096};
      });
      await tester.pumpWidget(AppInterfaceStyleScope(style:style,child:const MaterialApp(home:DownloadTaskPage())));
      final retry=find.byKey(ValueKey('download-retry.$originalKey'));
      await until(()=>retry.evaluate().isNotEmpty,'a real terminal failed card exposes Retry');
      await tester.ensureVisible(retry);await tester.pump();await tester.tap(retry);
      await until(()=>starts==1,'Retry actually prepares the new attempt and reaches the native engine');
      await finish(VideoEpisodeDownloadQueue.flush(),'fresh resolution and actual managed file commit complete');
      final rows=await finish(VideoExportRecords.readTasks(),'the committed task projection finishes with real filesystem replies');
      expect(rows,hasLength(1));expect(rows.single['key'],originalKey);expect(rows.single['attempt'],2);expect(rows.single['status'],'saved');expect(starts,1);
      expect(find.text('Retry work'),findsWidgets);
      expect(find.byType(DownloadTaskPage),findsOneWidget,reason:'Retry stays in Downloads and never opens a source route');
      final resources=await finish(VideoLocalResources.read(fresh:true),'the real managed index is readable');expect(resources,hasLength(1));
      final exists=await finish(VideoLocalResources.file(resources.single['resourceId'] as String).then((file)=>file.exists()),'the committed MP4 bytes exist');expect(exists,isTrue);
    } finally {
      if(originalKey!=null && VideoExportRecords.isLive(originalKey!))await finish(VideoSystemDownload.cancelTask(originalKey!),'cancel the owned test attempt');
      await finish(VideoEpisodeDownloadQueue.flush(),'retire retry work before disposing its host');
      await tester.pumpWidget(const SizedBox.shrink());
      if(resolver!=null)VideoDownloadRetry.unregister(source,resolver);
      messenger.setMockMethodCallHandler(channel,null);messenger.setMockMethodCallHandler(VideoHlsAssets.channel,null);
      messenger.setMockMethodCallHandler(connectivity,null);
      messenger.setMockMethodCallHandler(connectivityStatus,null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
      for(final channel in channels)messenger.setMockMethodCallHandler(channel,null);
      style.dispose();debugDefaultTargetPlatformOverride=previous;
    }
  });
}
