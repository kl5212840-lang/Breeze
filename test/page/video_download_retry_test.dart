import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_episode_download_queue.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import '../download_fixture.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel=MethodChannel('breeze.video.download');
  const source='download-retry-fixture';
  final watch=Uri.parse('https://hanime1.me/watch?v=93');
  final oldChoice=(label:'720p',url:Uri.parse('https://old-cdn.test/video.mp4?signature=old'),format:'mp4');
  Future<Map<String,dynamic>> failed()async{
    final status=await VideoSystemDownload().save(source:source,video:watch,title:'Work',choice:oldChoice,onProgress:(_){});
    expect(status,VideoDownloadStatus.failed);
    return (await VideoExportRecords.readTasks()).single;
  }
  setUp(()async{
    SharedPreferences.setMockInitialValues({});await useIsolatedDownloadFixture();VideoLocalResources.invalidate();
    final previous=debugDefaultTargetPlatformOverride;debugDefaultTargetPlatformOverride=TargetPlatform.iOS;
    addTearDown(()=>debugDefaultTargetPlatformOverride=previous);
    messenger.setMockMethodCallHandler(channel,(call)async=>call.method=='start'?{'status':'failed','reason':'httpForbidden','httpStatus':403}:null);
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel,(_)async=>[]);
    addTearDown(()async{await VideoEpisodeDownloadQueue.flush();messenger.setMockMethodCallHandler(channel,null);messenger.setMockMethodCallHandler(VideoHlsAssets.channel,null);});
  });
  test('failed native transfer retries the same row with a fresh signed URL and commits an actual staged file',()async{
    final row=await failed();final key=row['key'];
    expect(row['failureReason'],'httpForbidden');expect(row['httpStatus'],403);
    final starts=<Map>[], owner=VideoDownloadRetry.register(source,(task)async{
      expect(task['url'],'$watch');expect(task['quality'],'720p');
      expect(task.values.any((value)=>'$value'.contains('signature=')),isFalse);
      return VideoDownloadRetryResolution(choices:[(label:'720p',format:'mp4',url:Uri.parse('https://fresh-cdn.test/video.mp4?signature=new'))]);
    },current:()=>true);addTearDown(()=>VideoDownloadRetry.unregister(source,owner));
    messenger.setMockMethodCallHandler(channel,(call)async{
      if(call.method!='start')return null;
      final args=call.arguments as Map;starts.add(args);
      final stage=await VideoLocalResources.stagedFile('a'*32);await stage.parent.create(recursive:true);
      await stage.writeAsBytes(Uint8List(4096)..setAll(0,[0,0,0,24,102,116,121,112]));
      return {'status':'staged','resourceId':args['managedId'],'stageId':'a'*32,'bytes':4096};
    });
    expect(await VideoDownloadRetry.retry(row),isTrue);
    expect(await VideoDownloadRetry.retry(row),isFalse,reason:'Repeated taps cannot queue the same row twice');
    await VideoEpisodeDownloadQueue.flush();
    final after=(await VideoExportRecords.readTasks()).single;
    expect(after['key'],key);expect(after['status'],'saved');expect(after['attempt'],2);
    expect(starts.single['url'],'https://fresh-cdn.test/video.mp4?signature=new');
    final resource=(await VideoLocalResources.read(fresh:true)).single;
    expect(await (await VideoLocalResources.file(resource['resourceId'] as String)).exists(),isTrue);
    final stored=(await SharedPreferences.getInstance()).getString(VideoExportRecords.taskStorageKey)!;
    for(final secret in ['old-cdn','fresh-cdn','signature=','headers']){expect(stored, isNot(contains(secret)));}
  });
  test('expired quality does not silently select a different quality or start native',()async{
    final row=await failed();var starts=0;
    final owner=VideoDownloadRetry.register(source,(_)async=>VideoDownloadRetryResolution(choices:[
      (label:'480p',format:'mp4',url:Uri.parse('https://cdn.test/video.mp4'))]),current:()=>true);
    addTearDown(()=>VideoDownloadRetry.unregister(source,owner));
    messenger.setMockMethodCallHandler(channel,(call)async{if(call.method=='start')starts++;return null;});
    expect(await VideoDownloadRetry.retry(row),isTrue);await VideoEpisodeDownloadQueue.flush();
    final result=(await VideoExportRecords.readTasks()).single;
    expect(starts,0);expect(result['key'],row['key']);expect(result['failureReason'],'qualityUnavailable');
  });
  test('retry records a safe resolution stage for unexpected parser errors', () async {
    final row = await failed();
    final owner = VideoDownloadRetry.register(source, (_) async {
      throw StateError('private-parser-secret');
    }, current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await VideoEpisodeDownloadQueue.flush();
    final result = (await VideoExportRecords.readTaskSnapshot()).single;
    expect(result['failureReason'], 'downloadFailed');
    expect(result['failureStage'], 'resolution');
    expect(result.toString(), isNot(contains('private-parser-secret')));
  });
  test('retry records a safe stage when transfer setup throws', () async {
    final row = await failed();
    final owner = VideoDownloadRetry.register(source, (_) async => VideoDownloadRetryResolution(
      choices: [oldChoice], headersForChoice: (_) => throw StateError('private-header-secret')),
      current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await VideoEpisodeDownloadQueue.flush();
    final result = (await VideoExportRecords.readTaskSnapshot()).single;
    expect(result['failureStage'], 'retryTransfer');
    expect(result.toString(), isNot(contains('private-header-secret')));
  });
  test('retry preserves the native HLS failure stage', () async {
    final page = Uri.parse('https://site.example/voddetail/42.html?line=2&episode=2');
    final key = await VideoExportRecords.beginTransfer(source: source, video: page,
      title: 'Episode', quality: '720p', format: 'hls',
      resourceId: VideoHlsAssets.identity(source, page, '720p'));
    await VideoExportRecords.updateTransfer(key, received: null, status: 'failed', terminal: true);
    final row = (await VideoExportRecords.readTaskSnapshot()).single;
    final owner = VideoDownloadRetry.register(source, (_) async => VideoDownloadRetryResolution(
      choices: [(label: '720p', format: 'hls', url: Uri.parse('https://cdn.test/video.m3u8'))]),
      current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async => call.method == 'start'
      ? {'status': 'failed', 'reason': 'network', 'failureStage': 'nativeTransfer',
         'failureDomain': 'NSURLErrorDomain', 'failureCode': -1001} : []);
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await VideoEpisodeDownloadQueue.flush();
    final result = (await VideoExportRecords.readTaskSnapshot()).single;
    expect(result['failureStage'], 'nativeTransfer');
    expect(result['failureCode'], -1001);
  });
  test('retry uses the engine media format rather than an uppercase display format', () async {
    final row = await failed();
    var starts = 0;
    final owner = VideoDownloadRetry.register(source, (_) async => VideoDownloadRetryResolution(
      choices: [(label: '720p', format: 'MP4', url: Uri.parse('https://fresh-cdn.test/video.mp4'))]), current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') starts++;
      return {'status': 'failed', 'reason': 'network'};
    });
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await VideoEpisodeDownloadQueue.flush();
    expect(starts, 1);
    expect((await VideoExportRecords.readTaskSnapshot()).single['failureReason'], 'network');
  });
  for (final committed in [false, true]) {
    test(
      'HLS retry cancellation waits for native settlement (committed: $committed)',
      () async {
        const quality = '720p';
        final resourceId = VideoHlsAssets.identity(source, watch, quality);
        final key = await VideoExportRecords.beginTransfer(
          source: source,
          video: watch,
          title: 'Work',
          quality: quality,
          format: 'hls',
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: null,
          status: 'failed',
          terminal: true,
        );
        final row = (await VideoExportRecords.readTaskSnapshot()).single;
        final owner = VideoDownloadRetry.register(
          source,
          (_) async => VideoDownloadRetryResolution(
            choices: [
              (
                label: quality,
                format: 'hls',
                url: Uri.parse('https://cdn.test/video.m3u8'),
              ),
            ],
          ),
          current: () => true,
        );
        addTearDown(() => VideoDownloadRetry.unregister(source, owner));
        final nativeEntered = Completer<void>(),
            nativeReply = Completer<void>();
        var cancelCalls = 0;
        final resource = <String, dynamic>{
          'source': source,
          'url': '$watch',
          'quality': quality,
          'title': 'Work',
          'resourceId': resourceId,
          'assetId': 'retry-asset',
          'generation': 'retry-generation',
          'format': 'hls',
          'bytes': 4096,
          'taskKey': key,
          'showTask': true,
          'at': 1,
          'available': true,
          'filePresent': true,
        };
        var published = false;
        messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (
          call,
        ) async {
          switch (call.method) {
            case 'list':
              return [if (published) resource];
            case 'start':
              if (committed) return {...resource, 'status': 'staged'};
              nativeEntered.complete();
              await nativeReply.future;
              return 'cancelled';
            case 'commit':
              published = true;
              nativeEntered.complete();
              await nativeReply.future;
              return resource;
            case 'cancel':
              cancelCalls++;
              return null;
            default:
              return null;
          }
        });

        late bool wasQueued, wasLive;
        try {
          expect(await VideoDownloadRetry.retry(row), isTrue);
          await nativeEntered.future.timeout(const Duration(seconds: 3));
          await VideoSystemDownload.cancelTask(key);
          wasQueued = VideoSystemDownload.isQueuedTask(key);
          wasLive = VideoExportRecords.isAttemptCurrent(key, 2);
        } finally {
          nativeReply.complete();
          await VideoEpisodeDownloadQueue.flush();
        }

        final saved = (await VideoExportRecords.readTaskSnapshot()).single;
        expect(saved['status'], committed ? 'saved' : 'cancelled');
        expect(wasQueued, isTrue);
        expect(wasLive, isTrue);
        expect(VideoSystemDownload.isQueuedTask(key), isFalse);
        expect(cancelCalls, 1);
        if (committed) {
          expect(saved['resourceId'], resourceId);
          expect(
            (await VideoHlsAssets.read()).single['resourceId'],
            resourceId,
          );
        }
      },
    );
  }
  test('legacy HLS resource binding preserves the same line without inventing a missing quality', () async {
    final page = Uri.parse('https://site.example/voddetail/42.html?line=2&episode=2');
    final key = await VideoExportRecords.beginTransfer(source: source, video: page,
      title: 'Series episode 2', quality: 'Line two', resourceId: VideoHlsAssets.identity(source, page, 'Line two'));
    await VideoExportRecords.updateTransfer(key, received: null, status: 'failed', terminal: true);
    final row = (await VideoExportRecords.readTaskSnapshot()).single;
    expect(row.containsKey('format'), isFalse);
    var starts = 0;
    final owner = VideoDownloadRetry.register(source, (_) async => VideoDownloadRetryResolution(
      choices: [(label: 'Line two', format: 'HLS', url: Uri.parse('https://fresh-cdn.test/episode.m3u8'))]), current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    messenger.setMockMethodCallHandler(VideoHlsAssets.channel, (call) async {
      if (call.method == 'start') { starts++; return {'status': 'failed', 'reason': 'network'}; }
      return [];
    });
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await VideoEpisodeDownloadQueue.flush();
    expect(starts, 1);
    expect((await VideoExportRecords.readTaskSnapshot()).single['failureReason'], 'network');
  });
  test('a pending retry parser does not reject admission for another work and cancellation releases its slot', () async {
    final row = await failed();
    final pending = Completer<VideoDownloadRetryResolution>(), invoked = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(VideoDownloadRetryResolution(choices: const []));
    });
    var releases = 0, starts = 0;
    final owner = VideoDownloadRetry.register(source, (_) {
      invoked.complete(); return pending.future;
    }, current: () => true);
    addTearDown(() => VideoDownloadRetry.unregister(source, owner));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') starts++;
      return {'status': 'failed', 'reason': 'network'};
    });
    expect(await VideoDownloadRetry.retry(row), isTrue);
    await invoked.future;
    final other = VideoSystemDownload();
    final transfer = other.save(source: source, video: Uri.parse('https://hanime1.me/watch?v=94'),
      title: 'Other work', choice: oldChoice, onProgress: (_) {});
    addTearDown(() async {
      if (!pending.isCompleted) pending.complete(VideoDownloadRetryResolution(choices: const []));
      await transfer;
    });
    for (var i = 0; i < 100 && other.lastTaskKey == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(other.lastTaskKey, isNotNull);
    final queued = (await VideoExportRecords.readTaskSnapshot()).singleWhere((value) => value['key'] == other.lastTaskKey);
    expect(queued['status'], 'preparing'); expect(queued['received'], isNull); expect(starts, 0);
    await VideoSystemDownload.cancelTask(row['key'] as String);
    await VideoEpisodeDownloadQueue.flush();
    expect(await transfer, VideoDownloadStatus.failed);
    expect(starts, 1);
    pending.complete(VideoDownloadRetryResolution(choices: const [], release: () async { releases++; }));
    await Future<void>.delayed(Duration.zero);
    expect(releases, 1);
  });
  test('same-source B resolves only after A acknowledges its owned stop; a late A cannot start or cancel B', () async {
    final a = await failed();
    final otherWatch = Uri.parse('https://hanime1.me/watch?v=94');
    await VideoSystemDownload().save(source: source, video: otherWatch, title: 'B', choice: oldChoice, onProgress: (_) {});
    final b = (await VideoExportRecords.readTaskSnapshot()).singleWhere((row) => row['url'] == '$otherWatch');
    final aResult = Completer<VideoDownloadRetryResolution>(), bResult = Completer<VideoDownloadRetryResolution>();
    final aStarted = Completer<void>(), bStarted = Completer<void>(), stopRequested = Completer<void>(), stopAcknowledged = Completer<void>();
    var aReleased = 0;
    final starts = <String>[];
    VideoSystemDownload.concurrencyLimitForTesting = () => 2;
    final lease = VideoDownloadRetry.register(source, (row) {
      if (row['url'] == a['url']) { aStarted.complete(); return aResult.future; }
      bStarted.complete(); return bResult.future;
    }, current: () => true, cancel: (row) async {
      expect(row['url'], a['url'], reason: 'the cancellation callback is bound to this exact attempt');
      stopRequested.complete(); await stopAcknowledged.future;
    });
    addTearDown(() async {
      if (!stopAcknowledged.isCompleted) stopAcknowledged.complete();
      if (!aResult.isCompleted) aResult.complete(VideoDownloadRetryResolution(choices: const []));
      if (!bResult.isCompleted) bResult.complete(VideoDownloadRetryResolution(choices: const []));
      await VideoEpisodeDownloadQueue.flush();
      VideoDownloadRetry.unregister(source, lease);
      VideoSystemDownload.concurrencyLimitForTesting = null;
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') starts.add((call.arguments as Map)['url'] as String);
      return {'status': 'failed', 'reason': 'network'};
    });
    expect(await VideoDownloadRetry.retry(a), isTrue); await aStarted.future;
    expect(await VideoDownloadRetry.retry(b), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(bStarted.isCompleted, isFalse);
    final cancellation = VideoSystemDownload.cancelTask(a['key'] as String);
    await stopRequested.future;
    expect(bStarted.isCompleted, isFalse, reason: 'a UI cancelled flag cannot release a live source parser');
    stopAcknowledged.complete(); await cancellation;
    await bStarted.future.timeout(const Duration(seconds: 2));
    expect(aResult.isCompleted, isFalse);
    bResult.complete(VideoDownloadRetryResolution(choices: [(label: '720p', format: 'mp4', url: Uri.parse('https://fresh-b.test/video.mp4'))]));
    aResult.complete(VideoDownloadRetryResolution(choices: [(label: '720p', format: 'mp4', url: Uri.parse('https://stale-a.test/video.mp4'))], release: () async { aReleased++; }));
    await VideoEpisodeDownloadQueue.flush(); await Future<void>.delayed(Duration.zero);
    expect(starts, ['https://fresh-b.test/video.mp4']);
    expect(aReleased, 1);
    final rows = await VideoExportRecords.readTaskSnapshot();
    expect(rows.singleWhere((row) => row['key'] == a['key'])['status'], 'cancelled');
    expect(rows.singleWhere((row) => row['key'] == b['key'])['failureReason'], 'network');
  });
  test('incomplete cancelled intents require the source instead of exposing an unusable retry', () {
    final row = {'key': 'intent', 'source': source, 'url': '$watch', 'quality': '', 'status': 'cancelled'};
    expect(VideoDownloadRetry.canRecover(row), isFalse);
    expect(VideoDownloadRetry.canRetry(row), isFalse);
    expect(VideoDownloadRetry.needsSource(row), isTrue);
  });
  test('old terminal callback cannot overwrite a new queued attempt',()async{
    final row=await failed();
    final first=await VideoExportRecords.restartTransfer(row);expect(first,isNotNull);
    await VideoExportRecords.updateTransfer(row['key'] as String,received:null,status:'cancelled',terminal:true,expectedAttempt:first!['attempt'] as int);
    final cancelled=(await VideoExportRecords.readTasks()).single;
    final second=await VideoExportRecords.restartTransfer(cancelled);expect(second,isNotNull);
    await VideoExportRecords.updateTransfer(row['key'] as String,received:0,status:'failed',terminal:true,expectedAttempt:first['attempt'] as int,failureReason:'network');
    final current=(await VideoExportRecords.readTasks()).single;
    expect(current['attempt'],second!['attempt']);expect(current['status'],'preparing');
    await VideoExportRecords.updateTransfer(row['key'] as String,received:null,status:'cancelled',terminal:true,expectedAttempt:second['attempt'] as int);
  });
  test('cancelling an unresolved owned background visit releases it immediately',()async{
    final row=await failed(), pending=Completer<VideoDownloadRetryResolution>(), invoked=Completer<void>();
    var closed=0,released=0;
    expect(await VideoDownloadRetry.retry(row,fallback:(_)async{invoked.complete();return pending.future;},cancelResolution:()async{closed++;}),isTrue);
    await invoked.future;
    await VideoSystemDownload.cancelTask(row['key'] as String);
    expect(closed,1,reason:'No document timeout or idle timer is needed to close the owned WK visit');
    expect(pending.isCompleted,isFalse);
    pending.complete(VideoDownloadRetryResolution(choices:const [],release:()async{released++;}));
    await VideoEpisodeDownloadQueue.flush();await Future<void>.delayed(Duration.zero);
    expect(released,1);expect((await VideoExportRecords.readTasks()).single['status'],'cancelled');
  });
  for(final action in ['cancel','remove','account']){
    test('a late resolver after $action cannot start or resurrect the row',()async{
      final row=await failed(), pending=Completer<VideoDownloadRetryResolution>(), invoked=Completer<void>();
      var starts=0,releases=0;
      final owner=VideoDownloadRetry.register(source,(_)async{invoked.complete();return pending.future;},current:()=>true);
      addTearDown(()=>VideoDownloadRetry.unregister(source,owner));
      messenger.setMockMethodCallHandler(channel,(call)async{if(call.method=='start')starts++;return null;});
      expect(await VideoDownloadRetry.retry(row),isTrue);await invoked.future;
      final current=(await VideoExportRecords.readTasks()).single;
      if(action=='account')pluginSessionWriteFence.advance(source);else await VideoSystemDownload.cancelTask(row['key'] as String);
      if(action=='remove'){
        final bound=await VideoExportRecords.bindDownloadRemoval(VideoLocalResources.identity(source,watch,'720p'));
        await VideoExportRecords.removeBoundDownloadRecords(bound);
      }
      pending.complete(VideoDownloadRetryResolution(choices:[(label:'720p',format:'mp4',url:Uri.parse('https://late.test/video.mp4?signature=late'))],release:()async{releases++;}));
      await VideoEpisodeDownloadQueue.flush();await Future<void>.delayed(Duration.zero);
      expect(starts,0);expect(releases,1);
      final rows=await VideoExportRecords.readTasks();
      if(action=='remove'){expect(rows,isEmpty);}else{expect(rows.single['attempt'],current['attempt']);expect(rows.single['status'],'cancelled');}
    });
  }
}
