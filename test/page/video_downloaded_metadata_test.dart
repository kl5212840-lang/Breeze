import 'dart:async';
import 'package:flutter/painting.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_creator_reference.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

import '../download_fixture.dart';

Uri _watch(String path, [int episode = 1]) =>
    Uri.parse('https://metadata.example/$path?line=a&episode=$episode');
Map<String, dynamic> _row(
  String source,
  Uri watch, {
  String quality = '720p',
}) => {
  'resourceId': VideoLocalResources.identity(source, watch, quality),
  'source': source,
  'url': '$watch',
  'title': 'Actual file title',
  'quality': quality,
  'at': DateTime.utc(2026, 11, 5).millisecondsSinceEpoch,
  'durationMs': 120000,
};
ApiVideoItem _item(
  String id,
  String path, {
  String description = 'Public basic description',
  Uri? cover,
}) => ApiVideoItem(
  id: id,
  title: 'Public work $id',
  detailUrl: Uri.parse('https://metadata.example/$path'),
  coverUrl: cover,
  description: description,
  genres: 'Drama, Adventure',
  year: '2025',
  area: 'JP',
  releaseDate: '2025-02-03',
  sourceViews: 999,
  lines: [
    ApiVideoLine(
      id: 'a',
      label: 'Line A',
      episodes: [
        for (final episode in [1, 2])
          ApiVideoEpisode(
            id: '$episode',
            title: '第$episode集',
            url: null,
            watchUrl: _watch(path, episode),
          ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
  });

  test(
    'Hanime downloads keep the exact artist without borrowing the uploader',
    () async {
      const source = '1e600cff-8ebe-4517-8aa4-6678aec46424';
      final legacy = Uri.parse('https://hanime1.me/watch?v=42');
      final fresh = Uri.parse('https://hanime1.me/watch?v=43');
      final unrelated = Uri.parse('https://hanime1.me/watch?v=44');
      NativePlaybackSession session(Uri watch, {String artist = ''}) =>
          NativePlaybackSession(
            title: '[Title label] Work ${watch.queryParameters['v']}',
            watchUrl: watch,
            sources: const [],
            description: 'Description without author metadata',
            tags: const ['Tag (1)', 'Tag (2)', 'Plain tag', 'Literal (3)'],
            tagTargets: {
              'Literal (3)': Uri.https('hanime1.me', '/search', {
                'tags[]': 'Literal (3)',
              }),
            },
            creator: artist.isEmpty
                ? null
                : VideoCreatorReference(
                    name: artist,
                    role: 'artist',
                    entityKey: '',
                  ),
            uploader: const VideoCreatorReference(
              name: 'Different uploader',
              role: 'uploader',
              entityKey: '',
            ),
          );
      final resources = [
        for (final page in [legacy, fresh])
          {..._row(source, page), 'available': true, 'filePresent': true},
      ];
      final rows = DownloadCenterResources.mergeVideos([], resources);
      final legacyRow = rows.singleWhere((row) => row['url'] == '$legacy');
      final freshRow = rows.singleWhere((row) => row['url'] == '$fresh');
      await VideoDownloadedDetails.saveSession(source, session(legacy));
      await VideoDownloadedDetails.retainForResource(
        legacyRow,
        frameFallback: false,
      );
      expect(
        (await VideoDownloadedDetails.readForResource(legacyRow))!.creatorName,
        isEmpty,
      );
      await VideoDownloadedDetails.retainObservedCreator(
        source,
        session(unrelated, artist: 'Other artist'),
      );
      expect(
        (await VideoDownloadedDetails.readForResource(legacyRow))!.creatorName,
        isEmpty,
      );
      await VideoDownloadedDetails.retainObservedCreator(
        source,
        session(legacy, artist: 'Observed artist'),
      );

      await VideoDownloadedDetails.saveSession(
        source,
        session(fresh, artist: 'Fresh artist'),
      );
      await VideoDownloadedDetails.retainForResource(
        freshRow,
        frameFallback: false,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(VideoDownloadedDetails.storageKey);
      final metadata = await VideoDownloadedDetails.readForResources([
        legacyRow,
        freshRow,
      ]);
      expect(metadata.map((value) => value!.creatorName), [
        'Observed artist',
        'Fresh artist',
      ]);
      expect(metadata.first!.tags, ['Tag', 'Plain tag', 'Literal (3)']);
      expect(metadata.every((value) => value!.canonicalWorkId == null), isTrue);

      await DownloadCenterResources.enrichVideoRows(rows);
      final projected = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: rows,
      );
      final matches = projected.where(
        (item) => item.matches(
          facetValues: {
            'author': {'Observed artist'},
          },
        ),
      );
      expect(matches.single.video!['url'], '$legacy');
      expect(
        projected.expand((item) => item.fields['author'] ?? const <String>{}),
        unorderedEquals(['Observed artist', 'Fresh artist']),
      );
    },
  );

  test(
    'more than 32 committed downloads retain durable basics without the old browsing cache or a source repository',
    () async {
      final rows = <Map<String, dynamic>>[];
      for (var index = 1; index <= 40; index++) {
        final watch = Uri.parse('https://metadata.example/watch?v=$index');
        await VideoDownloadedDetails.saveSession(
          'removed-source',
          NativePlaybackSession(
            title: 'Title $index',
            watchUrl: watch,
            sources: const [],
            description: 'Description $index',
            tags: ['Tag $index'],
          ),
        );
        final row = _row('removed-source', watch);
        rows.add(row);
        await VideoDownloadedDetails.retainForResource(
          row,
          waitForPoster: true,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(VideoDownloadedDetails.storageKey);
      final metadata = await VideoDownloadedDetails.readForResources(rows);
      expect(metadata, hasLength(40));
      expect(metadata.first!.title, 'Title 1');
      expect(metadata.first!.description, 'Description 1');
      expect(metadata.last!.description, 'Description 40');
      expect(
        metadata.every((value) => value!.canonicalWorkId == null),
        isTrue,
        reason:
            'separate single-item playlists are never inferred to be one series',
      );
      expect(metadata.first!.source, 'removed-source');
      expect(metadata.first!.localCoverPath, isNull);
    },
  );

  test(
    'real module namespace and source isolate equal raw work IDs; episode attributes remain independent',
    () async {
      final movie = _item('7', 'videos/movie_7', description: 'Movie basics');
      final anime = _item('7', 'videos/anime_7', description: 'Anime basics');
      await VideoDownloadedDetails.captureItem(
        'source-a',
        movie,
        movie.episodeCards('a'),
        namespace: 'movie',
      );
      await VideoDownloadedDetails.captureItem(
        'source-a',
        anime,
        anime.episodeCards('a'),
        namespace: 'anime',
      );
      await VideoDownloadedDetails.captureItem(
        'source-b',
        movie,
        movie.episodeCards('a'),
        namespace: 'movie',
      );
      final rows = [
        _row('source-a', _watch('videos/movie_7')),
        _row('source-a', _watch('videos/anime_7')),
        _row('source-b', _watch('videos/movie_7')),
        _row('source-a', _watch('videos/movie_7', 2), quality: '1080p'),
      ];
      for (final row in rows) {
        await VideoDownloadedDetails.retainForResource(
          row,
          waitForPoster: true,
        );
      }
      final values = await VideoDownloadedDetails.readForResources(rows);
      expect(values[0]!.canonicalWorkId, isNot(values[1]!.canonicalWorkId));
      expect(values[0]!.canonicalWorkId, isNot(values[2]!.canonicalWorkId));
      expect(values[0]!.description, 'Movie basics');
      expect(values[1]!.description, 'Anime basics');
      expect(values[0]!.canonicalWorkId, values[3]!.canonicalWorkId);
      expect(values[0]!.episodeOrder, 0);
      expect(values[3]!.episodeOrder, 1);
      expect(values[3]!.quality, '1080p');
      expect(values[0]!.releaseDate, '2025-02-03');
      expect(values[0]!.downloadedAt!.year, 2026);
      final encoded = (await SharedPreferences.getInstance()).getString(
        VideoDownloadedDetails.durableStorageKey,
      )!;
      expect(encoded, isNot(contains('sourceViews')));
      expect(encoded, isNot(contains('discussionUrl')));
    },
  );

  test(
    'decoded resized provider retains a signed official poster with no live page or cover URL',
    () async {
      final watch = Uri.parse('https://metadata.example/watch?v=73');
      final bytes = Uint8List.fromList(
        img.encodePng(
          img.Image(width: 120, height: 240)..clear(img.ColorRgb8(25, 160, 65)),
        ),
      );
      final provider = ResizeImage(MemoryImage(bytes), width: 96);
      final ready = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (_, _) {
          if (!ready.isCompleted) ready.complete();
        },
        onError: (Object error, StackTrace? stack) =>
            ready.completeError(error, stack),
      );
      stream.addListener(listener);
      await ready.future;
      VideoDownloadedDetails.rememberDecodedPoster(
        source: 'cached-source',
        page: watch,
        url: 'https://covers.example/poster.png?token=TRANSIENT_ONLY',
        provider: provider,
      );
      final row = _row('cached-source', watch);
      final before = VideoDownloadedDetails.posterChanges.value;
      try {
        await VideoDownloadedDetails.retainForResource(
          row,
          waitForPoster: true,
        );
        final metadata = await VideoDownloadedDetails.readForResource(row);
        final path = await VideoDownloadedDetails.localPosterForResource(row);
        expect(path, isNotNull);
        expect(metadata!.localCoverPath, path);
        final image = img.decodePng(await File(path!).readAsBytes())!;
        expect(image.width / image.height, closeTo(.5, .01));
        expect(
          image.getPixel(image.width ~/ 2, image.height ~/ 2).g,
          greaterThan(140),
        );
        expect(VideoDownloadedDetails.posterChanges.value, before + 1);
        await VideoDownloadedDetails.retainForResource(
          row,
          waitForPoster: true,
        );
        expect(
          VideoDownloadedDetails.posterChanges.value,
          before + 1,
          reason: 'existing local PNG is reused',
        );
        final other = _row('other-source', watch);
        await VideoDownloadedDetails.retainForResource(other);
        expect(
          await VideoDownloadedDetails.localPosterForResource(other),
          isNull,
          reason:
              'same page from another source cannot borrow a decoded private provider',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(VideoDownloadedDetails.durableStorageKey),
          isNot(contains('TRANSIENT_ONLY')),
        );
      } finally {
        stream.removeListener(listener);
      }
    },
  );

  test(
    'new cover is a bounded managed local PNG and survives until the last downloaded resource is removed',
    () async {
      final pixels = img.Image(width: 500, height: 1000)
        ..clear(img.ColorRgb8(20, 140, 80));
      final png = Uint8List.fromList(img.encodePng(pixels));
      const channel = MethodChannel('breeze.video.network');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var read = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start')
          return {
            'status': 200,
            'url': 'https://covers.example/cover.png',
            'headers': {
              'content-type': 'image/png',
              'content-length': '${png.length}',
            },
          };
        if (call.method == 'read' && !read) {
          read = true;
          return png;
        }
        return null;
      });
      final network = OmoNetworkContext(
        'local-cover-fixture',
        source: 'source-a',
      );
      try {
        final item = _item(
          '7',
          'voddetail/7.html',
          cover: Uri.parse('https://covers.example/cover.png'),
        );
        await VideoDownloadedDetails.captureItem(
          'source-a',
          item,
          item.episodeCards('a'),
          network: network,
        );
        final rows = [
          _row('source-a', _watch('voddetail/7.html')),
          _row('source-a', _watch('voddetail/7.html', 2)),
        ];
        for (final row in rows) {
          await VideoDownloadedDetails.retainForResource(
            row,
            waitForPoster: true,
          );
        }
        final values = await VideoDownloadedDetails.readForResources(rows);
        final file = File(values.first!.localCoverPath!);
        final image = img.decodePng(await file.readAsBytes())!;
        expect(image.width, lessThanOrEqualTo(320));
        expect(image.height, lessThanOrEqualTo(480));
        expect(image.width / image.height, closeTo(.5, .01));
        await VideoDownloadedDetails.removeResource(
          rows.first['resourceId'] as String,
        );
        expect(await file.exists(), isTrue);
        await VideoDownloadedDetails.removeResource(
          rows.last['resourceId'] as String,
        );
        expect(await file.exists(), isFalse);
      } finally {
        await network.close();
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  test(
    'blocked optional poster never holds committed metadata or the managed-resource read queue',
    () async {
      const channel = MethodChannel('breeze.video.network');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final entered = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          entered.complete();
          return response.future;
        }
        return null;
      });
      final network = OmoNetworkContext(
        'blocked-cover-fixture',
        source: 'source-a',
      );
      final item = _item(
        '7',
        'voddetail/7.html',
        cover: Uri.parse('https://covers.example/blocked.png'),
      );
      final watch = _watch('voddetail/7.html');
      final row = _row('source-a', watch);
      var captured = false;
      final capture =
          VideoDownloadedDetails.captureItem(
            'source-a',
            item,
            item.episodeCards('a'),
            network: network,
          ).then((_) {
            captured = true;
          });
      try {
        await entered.future;
        await Future<void>.delayed(Duration.zero);
        expect(
          captured,
          isTrue,
          reason: 'queue admission must not wait for a poster response',
        );
        final id = row['resourceId'] as String;
        final file = await VideoLocalResources.file(id);
        await file.parent.create(recursive: true);
        await file.writeAsBytes([
          0,
          0,
          0,
          24,
          ...ascii.encode('ftyp'),
          ...List.filled(16, 0),
        ]);
        await VideoLocalResources.saved(
          resourceId: id,
          bytes: 24,
          source: 'source-a',
          video: watch,
          title: 'Saved during blocked cover',
          quality: '720p',
          taskKey: 'blocked-cover-task',
          cover: '${item.coverUrl}',
        );
        expect(response.isCompleted, isFalse);
        final actual = (await VideoLocalResources.read(fresh: true)).single;
        expect(actual['taskKey'], 'blocked-cover-task');
        final details = await VideoDownloadedDetails.readForResource(actual);
        expect(details!.tags, ['Drama', 'Adventure']);
        expect(details.localCoverPath, isNull);
        expect(
          response.isCompleted,
          isFalse,
          reason:
              'reads use committed data while optional image IO remains pending',
        );
      } finally {
        if (!response.isCompleted)
          response.complete({
            'status': 404,
            'url': 'https://covers.example/blocked.png',
            'headers': <String, String>{},
          });
        await capture;
        // Drain optional work before tearing down its source visit/fixture.
        await VideoDownloadedDetails.retainForResource(
          row,
          waitForPoster: true,
        );
        await network.close();
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  test(
    'corrupt metadata and invalid individual rows cannot delete files or prevent a valid local fallback',
    () async {
      final row = _row('removed-source', _watch('voddetail/7.html'));
      final unrelatedMedia = File(
        '${Directory.systemTemp.path}/breeze-preserved-${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      await unrelatedMedia.writeAsBytes([1, 2, 3]);
      try {
        await (await SharedPreferences.getInstance()).setString(
          VideoDownloadedDetails.durableStorageKey,
          '{broken',
        );
        final values = await VideoDownloadedDetails.readForResources([{}, row]);
        expect(values.first, isNull);
        expect(values.last!.title, 'Actual file title');
        expect(values.last!.localCoverPath, isNull);
        expect(await unrelatedMedia.readAsBytes(), [1, 2, 3]);
      } finally {
        await unrelatedMedia.delete();
      }
    },
  );
  test(
    'declared module, planned episode count and language survive local metadata snapshots',
    () async {
      final base = _item('7', 'videos/movie_7');
      final item = ApiVideoItem(
        id: base.id,
        title: base.title,
        detailUrl: base.detailUrl,
        lines: base.lines,
        plannedEpisodes: 12,
        language: 'ja',
        typeId: '20',
        typeName: '动画',
        genres: '冒险,奇幻',
      );
      await VideoDownloadedDetails.captureItem(
        'group-source',
        item,
        item.episodeCards('a'),
        namespace: 'movie',
      );
      final value = (await VideoDownloadedDetails.readForResources([
        _row('group-source', _watch('videos/movie_7')),
      ])).single!;
      expect(value.moduleNamespace, 'movie');
      expect(value.plannedEpisodes, 12);
      expect(value.language, 'ja');
      expect(value.typeName, '动画');
      expect(value.tags, ['冒险', '奇幻']);
      final public = VideoDownloadedDetails.publicItem(item);
      expect(public['typeId'], '20');
      expect(public['typeName'], '动画');
      expect(public['language'], 'ja');
      expect(
        value.canonicalWorkId,
        'group-source|movie|7|https://metadata.example/videos/movie_7',
      );
    },
  );

  test(
    'legacy public item fields remain durable after its browsing snapshot is removed',
    () async {
      final base = _item('8', 'videos/movie_8');
      final item = ApiVideoItem(
        id: base.id,
        title: base.title,
        detailUrl: base.detailUrl,
        lines: base.lines,
        typeName: '动画',
        language: 'ja',
        genres: '冒险',
        writers: '原作者',
      );
      await VideoDownloadedDetails.saveItem('removed-source', item);
      final row = _row('removed-source', _watch('videos/movie_8'));
      await VideoDownloadedDetails.retainForResource(row, waitForPoster: true);
      await (await SharedPreferences.getInstance()).remove(
        VideoDownloadedDetails.storageKey,
      );
      final metadata = (await VideoDownloadedDetails.readForResource(row))!;
      expect(metadata.typeName, '动画');
      expect(metadata.language, 'ja');
      expect(metadata.tags, ['冒险']);
      expect(metadata.writers, '原作者');
      expect(metadata.canonicalWorkId, isNull);
    },
  );
}
