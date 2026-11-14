import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_local_poster.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('breeze.video.download');
  const hls = MethodChannel('breeze.video.hls');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final page = Uri.parse('https://offline.example/watch?v=1');
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 160, height: 90)
    ..clear(img.ColorRgb8(30, 170, 80))));
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    messenger.setMockMethodCallHandler(hls, (call) async => call.method == 'list' ? [] : null);
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(hls, null);
      await VideoLocalResources.flush();
      VideoLocalResources.invalidate();
    });
  });
  Future<Map<String, dynamic>> seed() async {
    final id = VideoLocalResources.identity('removed-source', page, '720p');
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112, ...List.filled(16, 0)]);
    await VideoLocalResources.saved(resourceId: id, bytes: 24, source: 'removed-source',
      video: page, title: 'Offline', quality: '720p', taskKey: 'poster-fixture');
    return (await VideoLocalResources.read(fresh: true)).single;
  }
  test('one bound MP4 frame is persisted and reused without a URL/path bridge argument', () async {
    final row = await seed();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    var hlsReads = 0;
    messenger.setMockMethodCallHandler(hls, (_) async {
      hlsReads++;
      throw PlatformException(code: 'HLS index unavailable');
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'poster');
      expect(call.arguments, {'resourceId': row['resourceId']});
      calls++;
      return png;
    });
    final paths = await Future.wait([
      VideoDownloadedDetails.ensureLocalPoster(row), VideoDownloadedDetails.ensureLocalPoster(row),
    ]);
    expect(paths[0], isNotNull);
    expect(paths[1], paths[0]);
    final image = img.decodePng(await File(paths[0]!).readAsBytes())!;
    expect(image.width / image.height, closeTo(160 / 90, .001));
    expect(image.getPixel(0, 0).g, 170);
    expect(await VideoDownloadedDetails.ensureLocalPoster(row), paths[0]);
    expect(calls, 1);
    expect(hlsReads, 0);
  });
  test('unreadable frame is attempted once per committed binding', () async {
    final row = await seed();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async { calls++; return null; });
    expect(await VideoDownloadedDetails.ensureLocalPoster(row), isNull);
    expect(await VideoDownloadedDetails.ensureLocalPoster(row), isNull);
    expect(calls, 1);
    expect(await (await VideoLocalResources.file(row['resourceId'])).exists(), isTrue);
  });
  test('removing metadata during native decode rejects its late frame without touching media', () async {
    final row = await seed();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final entered = Completer<void>(), result = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (_) { entered.complete(); return result.future; });
    final pending = VideoDownloadedDetails.ensureLocalPoster(row);
    await entered.future;
    await expectLater(VideoLocalResources.remove(row['resourceId']),
      throwsA(isA<ManagedVideoResourceBusy>()));
    await VideoDownloadedDetails.removeResource(row['resourceId']);
    result.complete(png);
    expect(await pending, isNull);
    expect(await VideoDownloadedDetails.localPosterForResource(row), isNull);
    expect(await (await VideoLocalResources.file(row['resourceId'])).exists(), isTrue);
  });
  test('HLS poster request carries only its validated generation binding', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final id = VideoHlsAssets.identity('hls-source', page, '720p');
    final row = <String, dynamic>{
      'resourceId': id, 'source': 'hls-source', 'url': '$page', 'title': 'Local HLS',
      'quality': '720p', 'bytes': 0, 'taskKey': 'hls-task', 'showTask': true,
      'at': 123, 'assetId': 'local-asset', 'generation': 'generation-1',
      'format': 'hls', 'available': true, 'filePresent': true,
    };
    var calls = 0;
    messenger.setMockMethodCallHandler(hls, (call) async {
      if (call.method == 'list') return [row];
      expect(call.method, 'poster');
      expect(call.arguments, {'resourceId': id, 'assetId': 'local-asset', 'generation': 'generation-1'});
      calls++;
      return png;
    });
    Uint8List? received;
    expect(await VideoLocalPoster.capture(row, begin: () async => true,
      consume: (bytes) async { received = bytes; }), isTrue);
    expect(received, png);
    expect(await VideoLocalPoster.capture({...row, 'generation': 'old-generation'},
      begin: () async => true, consume: (_) async => fail('stale HLS')), isFalse);
    expect(calls, 1);
  });
  test('Android and arbitrary or stale resource identities never invoke frame extraction', () async {
    final row = await seed();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async { calls++; return png; });
    expect(await VideoDownloadedDetails.ensureLocalPoster(row), isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await VideoLocalPoster.capture({...row, 'source': 'other'},
      begin: () async => true, consume: (_) async => fail('stale frame')), isFalse);
    expect(await VideoLocalPoster.capture({...row, 'resourceId': '../../outside'},
      begin: () async => true, consume: (_) async => fail('arbitrary path')), isFalse);
    expect(calls, 0);
  });
}
