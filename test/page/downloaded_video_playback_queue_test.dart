import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/downloaded_video_playback_queue.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

import '../download_fixture.dart';

const _source = 'download-queue-fixture';
final _home = Uri.parse('https://offline.source.tv/');
Uri _watch(int episode, {String work = '7', String line = 'a'}) =>
    _home.resolve('voddetail/$work.html?line=$line&episode=$episode');

Map<String, dynamic> _row(
  int episode, {
  String work = '7',
  String line = 'a',
  String quality = '720p',
  String source = _source,
  bool hls = false,
  bool available = true,
}) {
  final watch = _watch(episode, work: work, line: line);
  return {
    'resourceId': hls
        ? VideoHlsAssets.identity(source, watch, quality)
        : VideoLocalResources.identity(source, watch, quality),
    'source': source,
    'url': '$watch',
    'title': 'Work $work',
    'quality': quality,
    'at': 1700000000000 + episode,
    'bytes': 24,
    'taskKey': 'task-$episode',
    'available': available,
    'showTask': true,
    if (hls) ...{
      'format': 'hls',
      'assetId': 'asset-$episode',
      'generation': 'generation-$episode',
    },
  };
}

NativePlaybackSession _playback(Map<String, dynamic> row) =>
    NativePlaybackSession(
      title: row['title'] as String,
      watchUrl: Uri.parse(row['url'] as String),
      description: 'Untrusted cached presentation is not copied',
      tags: const [],
      coverUrl: Uri.parse('https://remote.source.tv/cover.jpg'),
      sources: [
        NativePlaybackSource(
          url: row['format'] == 'hls'
              ? VideoHlsAssets.playbackUri(row)
              : Uri.file('/fixture/${row['resourceId']}.mp4'),
          label: row['quality'] as String,
          headers: const {},
          localResourceId: row['resourceId'] as String,
        ),
      ],
    );

Future<void> _saveWork(String id) async {
  final item = ApiVideoItem.fromJson({
    'id': id,
    'title': 'Work $id',
    'detailUrl': '${_home}voddetail/$id.html',
    'description': 'Public description $id',
    'genres': ['Drama'],
    'lines': [
      for (final line in ['a', 'b'])
        {
          'id': line,
          'label': line,
          'episodes': [
            for (final episode in [1, 2, 3, 4])
              {
                'id': '$episode',
                'title': '第${episode}集',
                'watchUrl': '${_watch(episode, work: id, line: line)}',
                'resolveOnPlayback': true,
              },
          ],
        },
    ],
  }, home: _home);
  await VideoDownloadedDetails.captureItem(_source, item, [
    for (final line in item.lines) ...item.episodeCards(line.id),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeCalls = <MethodCall>[];
  const channel = MethodChannel('breeze.video.hls');
  setUp(() async {
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'list') return <Object>[];
          throw StateError('The queue must not acquire native playback');
        });
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    await _saveWork('7');
    await _saveWork('8');
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'durable explicit work metadata selects exact clicked resource and stable downloaded gaps',
    () async {
      final clicked = _row(2, hls: true);
      final rows = [
        _row(2),
        _row(4),
        _row(1),
        clicked,
        _row(4, quality: '1080p'),
        _row(3, available: false),
        _row(3, line: 'b'),
        _row(3, work: '8'),
        _row(3, source: 'another-source'),
      ];
      final reads = <String>[];
      final queue = DownloadedVideoPlaybackQueue(
        readRows: () async => rows,
        readPlayback: (id) async {
          reads.add(id);
          return _playback(rows.singleWhere((row) => row['resourceId'] == id));
        },
      );
      addTearDown(queue.dispose);
      final plan = await queue.build(clicked['resourceId'] as String);
      expect(plan.entries.map((entry) => entry.watchUrl), [
        _watch(1),
        _watch(2),
        _watch(4),
      ]);
      expect(plan.currentResourceId, clicked['resourceId']);
      expect(
        plan.session.sources.single.localResourceId,
        clicked['resourceId'],
      );
      expect(plan.sequence.adjacent(_watch(2), 1)!.watchUrl, _watch(4));
      expect(plan.sequence.adjacent(_watch(4), 1), isNull);
      expect(plan.session.coverUrl, isNull);
      expect(plan.session.related, isEmpty);
      expect(plan.session.creator, isNull);
      expect(
        plan.session.episodes.every((card) => card.coverUrl == null),
        isTrue,
      );
      expect(() => plan.entries.clear(), throwsUnsupportedError);
      expect(
        () => plan.currentRow['quality'] = '1080p',
        throwsUnsupportedError,
      );
      final next = await plan.loadEpisode(_watch(4));
      expect(next.sources.single.localResourceId, _row(4)['resourceId']);
      expect(reads, [clicked['resourceId'], _row(4)['resourceId']]);
      await expectLater(plan.loadEpisode(_watch(3)), throwsStateError);
      expect(reads, hasLength(2));
      final reorderedRows = rows.reversed.toList();
      rows
        ..clear()
        ..addAll(reorderedRows);
      final rebuilt = await queue.build(clicked['resourceId'] as String);
      expect(
        rebuilt.entries.map((entry) => entry.resourceId),
        plan.entries.map((entry) => entry.resourceId),
      );
      await expectLater(plan.loadEpisode(_watch(1)), throwsStateError);
    },
  );

  test(
    'module work namespaces isolate equal raw item IDs and quality remains exact',
    () async {
      final current = _row(1),
          otherModule = _row(2),
          highQuality = _row(3, quality: '1080p');
      final rows = [current, otherModule, highQuality];
      final queue = DownloadedVideoPlaybackQueue(
        readRows: () async => rows,
        readPlayback: (id) async =>
            _playback(rows.singleWhere((row) => row['resourceId'] == id)),
        readMetadata: (input) async => [
          for (final row in input)
            DownloadedVideoMetadata(
              source: _source,
              resourceId: row['resourceId'] as String,
              watchUrl: Uri.parse(row['url'] as String),
              title: 'Same raw ID',
              quality: row['quality'] as String,
              canonicalWorkId: 'raw-id-7',
              moduleNamespace: row['resourceId'] == otherModule['resourceId']
                  ? 'anime'
                  : 'movie',
              episodeOrder: 0,
            ),
        ],
      );
      addTearDown(queue.dispose);
      final plan = await queue.build(current['resourceId'] as String);
      expect(plan.entries.single.resourceId, current['resourceId']);
      await expectLater(plan.loadEpisode(_watch(2)), throwsStateError);
      await expectLater(plan.loadEpisode(_watch(3)), throwsStateError);
    },
  );

  test(
    'old records and Hanime playlists without explicit work identity stay singletons',
    () async {
      final first = _row(1), second = _row(2);
      final rows = [first, second];
      final queue = DownloadedVideoPlaybackQueue(
        readRows: () async => rows,
        readMetadata: (rows) async => [for (final _ in rows) null],
        readPlayback: (id) async =>
            _playback(rows.singleWhere((row) => row['resourceId'] == id)),
      );
      addTearDown(queue.dispose);
      final plan = await queue.build(second['resourceId'] as String);
      expect(plan.entries.single.resourceId, second['resourceId']);
      await expectLater(plan.loadEpisode(_watch(1)), throwsStateError);
      final hanimeRows = [
        for (final n in [1, 2])
          {
            ..._row(n),
            'url': 'https://hanime1.me/watch?v=$n',
            'resourceId': VideoLocalResources.identity(
              _source,
              Uri.parse('https://hanime1.me/watch?v=$n'),
              '720p',
            ),
          },
      ];
      final hanime = DownloadedVideoPlaybackQueue(
        readRows: () async => hanimeRows,
        readPlayback: (id) async =>
            _playback(hanimeRows.singleWhere((row) => row['resourceId'] == id)),
      );
      addTearDown(hanime.dispose);
      final one = await hanime.build(hanimeRows.last['resourceId'] as String);
      expect(one.entries, hasLength(1));
    },
  );

  test(
    'queue target removal and replacement fail before returning a new playback descriptor',
    () async {
      final clicked = _row(1), next = _row(2, hls: true);
      final rows = [clicked, next];
      var playbackReads = 0;
      final queue = DownloadedVideoPlaybackQueue(
        readRows: () async => rows,
        readPlayback: (id) async {
          playbackReads++;
          return _playback(rows.singleWhere((row) => row['resourceId'] == id));
        },
      );
      addTearDown(queue.dispose);
      final plan = await queue.build(clicked['resourceId'] as String);
      next['generation'] = 'replacement-generation';
      await expectLater(plan.loadEpisode(_watch(2)), throwsStateError);
      expect(playbackReads, 1);
      rows.remove(next);
      await expectLater(plan.loadEpisode(_watch(2)), throwsStateError);
      expect(playbackReads, 1);
    },
  );

  test(
    'late build and switch are fenced on dispose and cancellation without taking any leases',
    () async {
      final first = _row(1),
          second = _row(2, hls: true),
          rows = [_row(1), _row(2, hls: true)];
      final pending = Completer<NativePlaybackSession>();
      final queue = DownloadedVideoPlaybackQueue(
        readRows: () async => rows,
        readPlayback: (id) => id == second['resourceId']
            ? pending.future
            : Future.value(_playback(first)),
      );
      final plan = await queue.build(first['resourceId'] as String);
      final switching = plan.loadEpisode(_watch(2));
      final rejected = expectLater(switching, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      queue.cancelPending();
      pending.complete(_playback(second));
      await rejected;
      // A descriptor isn't an acquired HLS capability; only a real player owns it.
      expect(
        nativeCalls.where((call) => call.method == 'acquirePlayback'),
        isEmpty,
      );
      queue.dispose();
      await expectLater(plan.loadEpisode(_watch(1)), throwsStateError);
      final building = Completer<NativePlaybackSession>();
      final began = Completer<void>();
      final late = DownloadedVideoPlaybackQueue(
        readRows: () async => [first],
        readPlayback: (_) {
          began.complete();
          return building.future;
        },
      );
      final result = late.build(first['resourceId'] as String);
      final closed = expectLater(result, throwsStateError);
      await began.future;
      late.dispose();
      building.complete(_playback(first));
      await closed;
    },
  );

  test(
    'default local storage chain checks the actual managed file again before a switch',
    () async {
      final row = _row(1), id = row['resourceId'] as String;
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]),
      );
      await VideoLocalResources.saved(
        resourceId: id,
        bytes: 24,
        source: _source,
        video: _watch(1),
        title: 'Work 7',
        quality: '720p',
        taskKey: 'physical-fixture',
      );
      final queue = DownloadedVideoPlaybackQueue();
      addTearDown(queue.dispose);
      final plan = await queue.build(id);
      expect(File.fromUri(plan.session.sources.single.url).path, file.path);
      await file.delete();
      VideoLocalResources.invalidate();
      await expectLater(plan.loadEpisode(_watch(1)), throwsStateError);
    },
  );
}
