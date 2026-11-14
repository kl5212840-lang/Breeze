import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

import '../video_local_fixture.dart';

ApiVideoItem _item(
  String id, {
  String duration = '',
  String remarks = '',
  String description = '',
  int count = 0,
  int planned = 0,
  bool finished = false,
  String host = 'duration.test',
}) {
  final page = Uri.parse('https://$host/voddetail/$id.html');
  return ApiVideoItem(
    id: id,
    title: 'Work $id',
    detailUrl: page,
    sourceDuration: duration,
    remarks: remarks,
    description: description,
    plannedEpisodes: planned,
    finished: finished,
    lines: [
      if (count > 0)
        ApiVideoLine(
          id: 'a',
          label: 'Line',
          episodes: [
            for (var n = 1; n <= count; n++)
              ApiVideoEpisode(
                id: '$n',
                title: 'Episode $n',
                url: null,
                watchUrl: page.replace(
                  queryParameters: {'line': 'a', 'episode': '$n'},
                ),
              ),
          ],
        ),
    ],
  );
}

Future<void> _history(String source, Uri watch, {int seconds = 125}) =>
    VideoWatchHistory.record(
      source,
      VideoWatchRecord(
        watchUrl: watch,
        title: 'Viewed episode',
        position: const Duration(seconds: 8),
        duration: Duration(seconds: seconds),
        updatedAt: DateTime.utc(2026, 11, 6),
        completed: false,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedVideoResources();
  });

  test(
    'all favorite writes retain only an observed same-work duration while other empty metadata still clears',
    () async {
      final store = VideoLibraryStore(
        deviceId: 'duration',
        storageKey: 'duration.store',
      );
      addTearDown(store.dispose);
      await store.setFavorite(
        'source',
        _item('1', remarks: '1:30', description: 'Old synopsis'),
        true,
      );
      await store.observeDetails('source', [_item('1')]);
      var saved = (await store.read()).itemsFor('source').single.item;
      expect(saved.sourceDuration, '1:30');
      expect(saved.remarks, isEmpty);
      expect(saved.description, isEmpty);
      await store.setFavorite('source', _item('1'), true);
      await store.setFollow('source', _item('1', count: 2), true);
      await store.observeItems('source', [_item('1', count: 2)]);
      expect(
        (await store.read()).itemsFor('source').single.item.sourceDuration,
        '1:30',
      );
      await store.observeDetails('source', [_item('1', duration: '2:42:25')]);
      expect(
        (await store.read()).itemsFor('source').single.item.sourceDuration,
        '2:42:25',
      );
      await store.setFavorite('other-source', _item('1'), true);
      expect(
        (await store.read())
            .itemsFor('other-source')
            .single
            .item
            .sourceDuration,
        isEmpty,
      );
      await store.observeDetails('source', [
        _item('1', host: 'different-work.test'),
      ]);
      expect(
        (await store.read()).itemsFor('source').single.item.sourceDuration,
        isEmpty,
        reason:
            'Equal source-local ID cannot transfer duration across work origins',
      );
      await store.setFavorite('source', _item('1', duration: '1:30'), true);
      await store.observeDetails('source', [
        ApiVideoItem(
          id: '1',
          title: 'Different path',
          detailUrl: _item('2').detailUrl,
        ),
      ]);
      expect(
        (await store.read()).itemsFor('source').single.item.sourceDuration,
        isEmpty,
        reason:
            'Equal IDs in one origin still cannot transfer duration between distinct works',
      );
    },
  );

  test(
    'favorites read local declared or proven single-video totals, never arbitrary series episode duration or another source',
    () async {
      final known = _item('1', remarks: '02:42:25');
      final single = _item('2', count: 1, planned: 1);
      final series = _item('3', count: 2, planned: 12);
      final uncertain = _item('4', count: 1);
      for (final item in [known, single, series, uncertain]) {
        await VideoDownloadedDetails.saveItem('source', item);
        await VideoBookshelfIndex.store.setFavorite(
          'source',
          _item(item.id),
          true,
        );
        if (item.lines.isNotEmpty)
          await _history('source', item.lines.single.episodes.first.watchUrl);
      }
      await VideoBookshelfIndex.store.setFavorite(
        'other-source',
        _item('2'),
        true,
      );
      final before = videoLibrarySnapshotEncoding(
        await VideoBookshelfIndex.store.read(),
      );
      final rows = await VideoBookshelfIndex.load(
        ShelfPageMode.favorite,
        const SearchStatusState(),
      );
      ApiVideoItem saved(String source, String id) => rows
          .singleWhere((row) => row.source == source && row.item.id == id)
          .item;
      expect(saved('source', '1').sourceDuration, '2:42:25');
      expect(
        saved('source', '2').sourceDuration,
        '2:05',
        reason: 'Observed total, not the eight-second position',
      );
      expect(saved('source', '3').sourceDuration, isEmpty);
      expect(
        saved('source', '4').sourceDuration,
        isEmpty,
        reason:
            'One currently listed episode is not proof that an ongoing work has one episode',
      );
      expect(saved('other-source', '2').sourceDuration, isEmpty);
      expect(
        videoLibrarySnapshotEncoding(await VideoBookshelfIndex.store.read()),
        before,
        reason:
            'Local projection does not rewrite favorites or create synchronization changes',
      );
    },
  );

  test(
    'download projection retains real resource totals and falls back only to exact source/watch history',
    () async {
      for (var n = 1; n <= 2; n++) {
        final watch = Uri.parse('https://duration.test/watch?v=$n');
        final id = VideoLocalResources.identity(
          'download-source',
          watch,
          '720p',
        );
        final file = await VideoLocalResources.file(id);
        await file.parent.create(recursive: true);
        await file.writeAsBytes([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          ...List.filled(16, 0),
        ]);
        await VideoLocalResources.saved(
          resourceId: id,
          bytes: 24,
          source: 'download-source',
          video: watch,
          title: 'Download $n',
          quality: '720p',
          taskKey: 'task-$n',
          durationMs: n == 1 ? 125000 : null,
          sourceDuration: n == 1 ? '9:59' : null,
        );
        await _history('download-source', watch, seconds: n == 1 ? 500 : 180);
      }
      final rows = await VideoBookshelfIndex.load(
        ShelfPageMode.download,
        const SearchStatusState(sources: ['download-source']),
      );
      expect(
        rows
            .singleWhere((row) => row.item.title == 'Download 1')
            .item
            .sourceDuration,
        '2:05',
      );
      expect(
        rows
            .singleWhere((row) => row.item.title == 'Download 2')
            .item
            .sourceDuration,
        '3:00',
      );
    },
  );

  test(
    'cached item and session saves preserve known duration only under their exact work or episode identity',
    () async {
      await VideoDownloadedDetails.saveItem(
        'source',
        _item('1', remarks: '1:30', description: 'Old synopsis'),
      );
      await VideoDownloadedDetails.saveItem('source', _item('1'));
      final cached = await VideoDownloadedDetails.readItem(
        'source',
        _item('1').detailUrl,
      );
      expect(cached!.sourceDuration, '1:30');
      expect(cached.description, isEmpty);
      await VideoDownloadedDetails.saveItem(
        'source',
        ApiVideoItem(
          id: 'other-module',
          title: 'Different identity',
          detailUrl: _item('1').detailUrl,
        ),
      );
      expect(
        (await VideoDownloadedDetails.readItem(
          'source',
          _item('1').detailUrl,
        ))!.sourceDuration,
        isEmpty,
      );
      final work = _item('2', duration: '40:00', count: 2, planned: 2);
      await VideoDownloadedDetails.captureItem(
        'durable',
        work,
        work.episodeCards('a'),
      );
      final empty = _item('2', count: 2, planned: 2);
      await VideoDownloadedDetails.captureItem(
        'durable',
        empty,
        empty.episodeCards('a'),
      );
      final watch = work.lines.single.episodes.first.watchUrl;
      final metadata = await VideoDownloadedDetails.readForResource({
        'resourceId': VideoLocalResources.identity('durable', watch, '720p'),
        'source': 'durable',
        'url': '$watch',
        'title': 'Episode',
        'quality': '720p',
        'at': 1,
      });
      expect(metadata!.sourceDuration, '40:00');
      NativePlaybackSession session(Uri target, String? duration) =>
          NativePlaybackSession(
            title: 'Episode',
            watchUrl: target,
            sources: const [],
            description: '',
            tags: const [],
            metadata: VideoPublicMetadata(duration: duration),
          );
      await VideoDownloadedDetails.saveSession(
        'session',
        session(watch, '4:00'),
      );
      await VideoDownloadedDetails.saveSession('session', session(watch, null));
      Future<Map> readSession() async =>
          (jsonDecode(
                        (await SharedPreferences.getInstance()).getString(
                          VideoDownloadedDetails.storageKey,
                        )!,
                      )
                      as List)
                  .cast<Map>()
                  .singleWhere((row) => row['source'] == 'session')['session']
              as Map;
      expect((await readSession())['sourceDuration'], '4:00');
      await VideoDownloadedDetails.saveSession(
        'session',
        session(work.lines.single.episodes.last.watchUrl, null),
      );
      expect(
        (await readSession())['sourceDuration'],
        isNull,
        reason:
            'Session cache is keyed by work but its episode total cannot leak into another episode',
      );
    },
  );
}
