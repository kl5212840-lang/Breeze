import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';

import '../video_local_fixture.dart';

NativePlaybackSession _session(Uri page, List<NativePlaybackSource> sources) =>
    NativePlaybackSession(
      title: 'Episode',
      watchUrl: page,
      sources: sources,
      description: '',
      tags: const [],
    );
final _first = Uri.parse(
  'https://site-fixture.test/voddetail/42.html?line=line-a&episode=one',
);
final _second = Uri.parse(
  'https://site-fixture.test/voddetail/42.html?line=line-a&episode=two',
);
NativePlaybackSource _media(
  String suffix, {
  Map<String, String> headers = const {},
}) => NativePlaybackSource(
  url: Uri.parse('https://cdn-fixture.test/media.$suffix?signature=ephemeral'),
  label: '720p',
  headers: headers,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'native HLS and MP4 are offered on mobile with their original formats',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final adapter = VideoPlaybackDownloadAdapter(
        _session(_first, [_media('mp4'), _media('m3u8'), _media('mpd')]),
      );
      final result = await adapter.readChoices();
      expect(result.value, [
        (label: '720p', url: _media('mp4').url, format: 'mp4'),
        (label: '720p · 2', url: _media('m3u8').url, format: 'hls'),
      ]);
      expect(
        VideoPlaybackDownloadAdapter(
          _session(Uri.parse('https://site-fixture.test/voddetail/42.html'), [
            _media('mp4'),
          ]),
        ).choices,
        isEmpty,
        reason:
            'a work page alone cannot bind this download to a verified episode',
      );
    },
  );

  test(
    'transport headers stay ephemeral and must be public first-party playback headers',
    () {
      final adapter = VideoPlaybackDownloadAdapter(
        _session(_first, [
          _media(
            'mp4',
            headers: {
              'Referer': 'https://site-fixture.test/',
              'Origin': 'https://site-fixture.test',
              'User-Agent': 'fixture-agent',
            },
          ),
        ]),
      );
      expect(adapter.headersForChoice(adapter.choices.single), {
        'Referer': 'https://site-fixture.test/',
        'Origin': 'https://site-fixture.test',
        'User-Agent': 'fixture-agent',
      });
      for (final headers in [
        {'Cookie': 'private'},
        {'Authorization': 'private'},
        {'Referer': 'https://other.test/'},
        {'Referer': 'https://site-fixture.test/?token=private'},
        {'User-Agent': 'agent\r\nCookie: private'},
      ]) {
        expect(
          VideoPlaybackDownloadAdapter(
            _session(_first, [_media('mp4', headers: headers)]),
          ).choices,
          isEmpty,
        );
      }
    },
  );

  test(
    'resolved media preserves a website workflow and exposes HLS on mobile only',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final mp4 = _session(_first, [_media('mp4')]);
      expect(VideoPlaybackDownloadAdapter.resolve(mp4)!.choices, hasLength(1));
      expect(
        VideoPlaybackDownloadAdapter.resolve(mp4, hasWebsiteDownload: true),
        isNull,
      );
      final hls = _session(_first, [_media('m3u8')]);
      expect(
        VideoPlaybackDownloadAdapter.resolve(hls)!.choices.single.format,
        'hls',
      );
      expect(
        VideoPlaybackDownloadAdapter.resolve(hls, hasWebsiteDownload: true),
        isNull,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(VideoPlaybackDownloadAdapter.resolve(hls), isNull);
      final explicit = VideoPlaybackDownloadAdapter(mp4);
      expect(
        VideoPlaybackDownloadAdapter.resolve(
          mp4,
          declared: (_) => explicit,
          hasWebsiteDownload: true,
        ),
        same(explicit),
      );
    },
  );

  test(
    'new episode and line resources are distinct while original Hanime and legacy API identities stay unchanged',
    () {
      final hanime = Uri.parse('https://hanime1.me/watch?v=42&private=discard');
      final old = sha256
          .convert(utf8.encode('fixture|https://hanime1.me/watch?v=42|720p'))
          .toString();
      expect(VideoLocalResources.identity('fixture', hanime, '720p'), old);
      expect(
        VideoLocalResources.identity('fixture', _first, '720p'),
        isNot(VideoLocalResources.identity('fixture', _second, '720p')),
      );
      expect(
        VideoLocalResources.identity('fixture', _first, '720p'),
        isNot(
          VideoLocalResources.identity(
            'fixture',
            _first.replace(
              queryParameters: {'line': 'line-b', 'episode': 'one'},
            ),
            '720p',
          ),
        ),
      );
      expect(
        VideoLocalResources.identity('other-source', _first, '720p'),
        isNot(VideoLocalResources.identity('fixture', _first, '720p')),
      );
      final legacy = Uri.parse('https://site-fixture.test/voddetail/42.html');
      expect(
        VideoLocalResources.identity('fixture', legacy, '720p'),
        sha256.convert(utf8.encode('fixture|$legacy|720p')).toString(),
      );
      expect(
        VideoLocalResources.resourcePage(
          _first.replace(
            queryParameters: {
              ..._first.queryParameters,
              'signature': 'private',
            },
          ),
        ),
        _first,
      );
      expect(
        VideoLocalResources.resourcePage(
          Uri.parse('https://site-fixture.test/voddetail/42.html?line=one'),
        ),
        isNull,
      );
    },
  );

  test(
    'two real stored episodes survive fresh index read, offline open and exact physical removal without merging into the work',
    () async {
      await useIsolatedVideoResources();
      final bytes = Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
      final ids = <String>[];
      for (final page in [_first, _second]) {
        final id = VideoLocalResources.identity('fixture', page, '720p');
        ids.add(id);
        final file = await VideoLocalResources.file(id);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        final key = await VideoExportRecords.beginTransfer(
          source: 'fixture',
          video: page,
          title: page.queryParameters['episode']!,
          quality: '720p',
          resourceId: id,
        );
        await VideoLocalResources.saved(
          resourceId: id,
          bytes: bytes.length,
          source: 'fixture',
          video: page,
          title: page.queryParameters['episode']!,
          quality: '720p',
          taskKey: key,
        );
        await VideoExportRecords.updateTransfer(
          key,
          received: bytes.length,
          total: bytes.length,
          status: 'saved',
          terminal: true,
          resourceId: id,
        );
      }
      VideoLocalResources.invalidate();
      final rows = await VideoLocalResources.read(fresh: true);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r['url']).toSet(), {
        _first.toString(),
        _second.toString(),
      });
      expect((await VideoLocalResources.playback(ids[1])).watchUrl, _second);
      expect(
        (await VideoExportRecords.readTasks()).map((r) => r['url']).toSet(),
        {_first.toString(), _second.toString()},
      );
      final legacy = Uri.parse('https://site-fixture.test/voddetail/42.html');
      final legacyId = VideoLocalResources.identity('fixture', legacy, '720p');
      final legacyFile = await VideoLocalResources.file(legacyId);
      await legacyFile.writeAsBytes(bytes);
      await VideoLocalResources.saved(
        resourceId: legacyId,
        bytes: bytes.length,
        source: 'fixture',
        video: legacy,
        title: 'Legacy work resource',
        quality: '720p',
        taskKey: 'legacy-record',
      );
      VideoLocalResources.invalidate();
      expect(await VideoLocalResources.read(fresh: true), hasLength(3));
      expect((await VideoLocalResources.playback(legacyId)).watchUrl, legacy);
      await VideoLocalResources.remove(legacyId);
      final afterLegacyRemoval = await VideoLocalResources.read(fresh: true);
      // Physical removal preserves task metadata; only the exact file becomes
      // unavailable. The legacy work is never reassigned to either episode.
      expect(afterLegacyRemoval, hasLength(3));
      expect(
        afterLegacyRemoval
            .where((r) => r['available'] == true)
            .map((r) => r['resourceId'])
            .toSet(),
        ids.toSet(),
      );
      expect(
        afterLegacyRemoval.singleWhere(
          (r) => r['resourceId'] == legacyId,
        )['filePresent'],
        isFalse,
      );
      expect(await legacyFile.exists(), isFalse);
      await VideoLocalResources.remove(ids[0]);
      final afterEpisodeRemoval = await VideoLocalResources.read(fresh: true);
      expect(afterEpisodeRemoval, hasLength(3));
      expect(
        afterEpisodeRemoval
            .where((r) => r['available'] == true)
            .single['resourceId'],
        ids[1],
      );
      expect(
        afterEpisodeRemoval.singleWhere(
          (r) => r['resourceId'] == ids[0],
        )['filePresent'],
        isFalse,
      );
      expect(await (await VideoLocalResources.file(ids[0])).exists(), isFalse);
      expect(await (await VideoLocalResources.file(ids[1])).exists(), isTrue);
      expect((await VideoLocalResources.playback(ids[1])).watchUrl, _second);
      final index = File(
        '${(await VideoLocalResources.root()).path}/index.json',
      );
      expect(await index.readAsString(), isNot(contains('signature')));
      expect(
        (await SharedPreferences.getInstance()).getString(
          VideoExportRecords.taskStorageKey,
        ),
        isNot(contains('ephemeral')),
      );
    },
  );
  test(
    'resolved API media uses the existing staged transfer and saves only canonical episode metadata',
    () async {
      await useIsolatedVideoResources();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('breeze.video.download');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final adapter = VideoPlaybackDownloadAdapter(
        _session(_first, [
          _media(
            'mp4',
            headers: {
              'Referer': 'https://site-fixture.test/',
              'Origin': 'https://site-fixture.test',
              'User-Agent': 'fixture-agent',
            },
          ),
        ]),
      );
      Map<dynamic, dynamic>? sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'start');
        sent = call.arguments as Map;
        final stage = await VideoLocalResources.stagedFile('a' * 32);
        await stage.parent.create(recursive: true);
        await stage.writeAsBytes(
          Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
        );
        return {
          'status': 'staged',
          'resourceId': sent!['managedId'],
          'stageId': 'a' * 32,
          'bytes': 24,
        };
      });
      final result = await VideoSystemDownload().save(
        choice: adapter.choices.single,
        headers: adapter.headersForChoice(adapter.choices.single),
        source: 'api-download-fixture',
        video: _first,
        title: 'Episode one',
        onProgress: (_) {},
      );
      expect(result, VideoDownloadStatus.saved);
      expect(sent!['referer'], 'https://site-fixture.test/voddetail/42.html');
      expect(
        sent!['headers'],
        adapter.headersForChoice(adapter.choices.single),
      );
      expect(
        (await VideoLocalResources.read(fresh: true)).single['url'],
        _first.toString(),
      );
      final task = (await VideoExportRecords.readTasks()).single;
      expect(task['status'], 'saved');
      expect((await VideoLocalResources.read(fresh: true)).single['bytes'], 24);
      expect(task['url'], _first.toString());
      // Neither the media token nor transport headers belong to the task store.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(VideoExportRecords.taskStorageKey),
        isNot(contains('signature')),
      );
      expect(
        prefs.getString(VideoExportRecords.taskStorageKey),
        isNot(contains('fixture-agent')),
      );
    },
  );

  test(
    'Android uses the selected HTTP proxy for both native transfer channels',
    () async {
      await useIsolatedVideoResources();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const source = '12345678-1234-1234-1234-123456789012';
      const inherited = 'http://proxy-inherited.test:8000';
      const sourceProxy = 'http://proxy-source.test:8001';
      SourceNetworkPolicies.initialize(
        () => const ProxySettingState(enabled: true, address: inherited),
      );
      addTearDown(
        () => SourceNetworkPolicies.initialize(() => const ProxySettingState()),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const mp4Channel = MethodChannel('breeze.video.download');
      const hlsChannel = VideoHlsAssets.channel;
      final requests = <Map>[];
      for (final channel in [mp4Channel, hlsChannel]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'list') return const [];
          expect(call.method, 'start');
          final wire = call.arguments as Map;
          requests.add(wire);
          expect(
            wire['androidProxy'],
            channel == mp4Channel ? inherited : sourceProxy,
          );
          expect(wire.containsKey('recoveryScope'), isFalse);
          return {'status': 'failed', 'reason': 'network'};
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      expect(await VideoSystemDownload.supportsRoute(source, null), isTrue);
      for (final path in ['mp4', 'm3u8']) {
        if (path == 'm3u8') {
          await SourceNetworkPolicies.save(
            source,
            const SourceNetworkPreference(
              mode: SourceNetworkMode.proxy,
              address: sourceProxy,
            ),
          );
        }
        expect(
          await VideoSystemDownload().save(
            choice: (
              label: '720p',
              url: _media(path).url,
              format: path == 'mp4' ? 'mp4' : 'hls',
            ),
            source: source,
            video: _first,
            title: 'Episode one',
            onProgress: (_) {},
          ),
          VideoDownloadStatus.failed,
        );
      }
      expect(requests, hasLength(2));
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getString(VideoExportRecords.taskStorageKey);
      expect(queue, isNotNull);
      expect(queue, isNot(contains('proxy-inherited.test')));
      expect(queue, isNot(contains('proxy-source.test')));
      expect(queue, isNot(contains('signature')));
    },
  );

  test(
    'Unsupported Android SOCKS and TLS proxy routes cannot fall back to direct downloads',
    () async {
      await useIsolatedVideoResources();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var settings = const ProxySettingState(
        enabled: true,
        type: ProxyType.socks5,
        address: '127.0.0.1:1080',
      );
      SourceNetworkPolicies.initialize(() => settings);
      addTearDown(
        () => SourceNetworkPolicies.initialize(() => const ProxySettingState()),
      );
      const source = '12345678-1234-1234-1234-123456789012';
      const channel = MethodChannel('breeze.video.download');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls++;
        return 'saved';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      for (final unsupported in [
        settings,
        const ProxySettingState(
          enabled: true,
          address: 'https://proxy.example.test:8443',
        ),
      ]) {
        settings = unsupported;
        expect(await VideoSystemDownload.supportsRoute(source, null), isFalse);
        final result = await VideoSystemDownload().save(
          choice: (label: '720p', url: _media('mp4').url, format: 'mp4'),
          source: source,
          video: _first,
          title: 'Episode one',
          onProgress: (_) {},
        );
        expect(result, VideoDownloadStatus.routeUnavailable);
      }
      expect(nativeCalls, 0);
      final tasks = await VideoExportRecords.readTaskSnapshot();
      expect(tasks.single['status'], 'routeUnavailable');
      expect(tasks.single['failureReason'], 'routeUnavailable');
      expect(jsonEncode(tasks), isNot(contains('proxy.example.test')));
    },
  );
}
