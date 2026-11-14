import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';

VideoWatchRecord _record(int id, {int second = 20}) => VideoWatchRecord(
  watchUrl: Uri.parse('https://hanime1.me/watch?v=$id&temporary=not-persisted'),
  title: 'Video $id',
  position: Duration(seconds: second),
  duration: const Duration(minutes: 2),
  updatedAt: DateTime.utc(2026, 10, 22).add(Duration(seconds: id)),
  completed: false,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'records and concurrent writes stay source-scoped and bounded',
    () async {
      await Future.wait([
        for (var id = 0; id <= VideoWatchHistory.limit; id++)
          VideoWatchHistory.record('one', _record(id)),
        VideoWatchHistory.record('two', _record(1)),
      ]);
      final first = await VideoWatchHistory.read('one');
      expect(first, hasLength(VideoWatchHistory.limit));
      expect(first.first.title, 'Video 200');
      expect(first.last.title, 'Video 1');
      expect(await VideoWatchHistory.read('two'), hasLength(1));
      expect(first.first.watchUrl.queryParameters.keys, ['v']);
    },
  );

  test(
    'updating one video keeps a single record and its latest position',
    () async {
      await VideoWatchHistory.record('one', _record(1));
      await VideoWatchHistory.record('one', _record(1, second: 42));
      final records = await VideoWatchHistory.read('one');
      expect(records, hasLength(1));
      expect(records.single.position, const Duration(seconds: 42));
    },
  );

  test(
    'deleting records also removes legacy resume positions, not comic data',
    () async {
      final store = await SharedPreferences.getInstance();
      await store.setInt('reader.page', 9);
      await VideoWatchHistory.record('one', _record(1));
      await VideoWatchHistory.record('one', _record(2));
      await VideoWatchHistory.record('two', _record(3));
      await store.setInt('breeze.video.progress.hanime1.me.1', 20000);
      await store.setInt('breeze.video.progress.hanime1.me.2', 20000);
      await VideoWatchHistory.remove('one', _record(1).watchUrl);
      expect(await VideoWatchHistory.read('one'), hasLength(1));
      expect(store.containsKey('breeze.video.progress.hanime1.me.1'), isFalse);
      expect(store.getInt('breeze.video.progress.hanime1.me.2'), 20000);
      await VideoWatchHistory.remove('one', null);
      expect(await VideoWatchHistory.read('one'), isEmpty);
      expect(await VideoWatchHistory.read('two'), hasLength(1));
      expect(store.getInt('reader.page'), 9);
      expect(store.containsKey('breeze.video.progress.hanime1.me.2'), isFalse);
    },
  );

  test('corrupt and unsafe records do not become playback actions', () async {
    final store = await SharedPreferences.getInstance();
    await store.setString('breeze.video.history.v1.one', 'broken');
    expect(await VideoWatchHistory.read('one'), isEmpty);
    await store.setString(
      'breeze.video.history.v1.one',
      jsonEncode([
        {..._record(1).toJson(), 'watchUrl': 'http://hanime1.me/watch?v=1'},
        {
          ..._record(1).toJson(),
          'watchUrl': 'https://user:pass@hanime1.me/watch?v=1',
        },
        {..._record(1).toJson(), 'duration': -1},
        {..._record(1).toJson(), 'updatedAt': -1},
        {..._record(1).toJson(), 'position': 9999999},
      ]),
    );
    final records = await VideoWatchHistory.read('one');
    expect(records, hasLength(1));
    expect(records.single.position, records.single.duration);
  });
  test(
    'public metadata roundtrips without private payload and legacy replay keeps known fields',
    () async {
      final watch = Uri.parse(
        'https://module.test/videos/Hid-1?line=main&episode=1&token=omit',
      );
      expect(VideoWatchRecord.canonicalUrl(watch), isNotNull);
      final item = ApiVideoItem(
        id: 'movie:Hid-1',
        title: 'Work',
        detailUrl: watch,
        genres: 'Action/Drama',
        typeName: 'Movie',
        year: '2024',
        area: 'Japan',
        language: 'Japanese',
        writers: '作者甲 / 作者乙',
      );
      final row = VideoWatchRecord(
        watchUrl: watch,
        title: item.title,
        position: const Duration(seconds: 20),
        duration: const Duration(minutes: 10),
        updatedAt: DateTime.utc(2026),
        completed: false,
        metadata: {
          ...VideoWatchRecord.metadataFromItem(item),
          'token': 'private',
          'mediaUrl': 'https://secret.test/media',
        },
      );
      await VideoWatchHistory.record('hybrid', row);
      var restored = (await VideoWatchHistory.read('hybrid')).single;
      expect(
        restored.metadata.keys,
        unorderedEquals(['genres', 'typeName', 'year', 'area', 'language', 'writers']),
      );
      final replay = apiVideoHistoryItem(restored, itemNamespace: 'movie');
      expect(replay.year, '2024');
      expect(replay.genres, 'Action/Drama');
      expect(replay.writers, '作者甲 / 作者乙');
      final facets = shelfFacetEntryFromVideo(VideoBookshelfRow(
        key: 'history', source: 'hybrid', item: replay, updatedAt: restored.updatedAt,
      ));
      expect(facets.fields['author'], {'作者甲', '作者乙'});
      expect(replay.detailUrl.hasQuery, isFalse);
      expect(jsonEncode(restored.toJson()), isNot(contains('private')));
      await VideoWatchHistory.record(
        'hybrid',
        VideoWatchRecord(
          watchUrl: watch.replace(query: 'line=main&episode=2'),
          title: 'Work',
          position: const Duration(seconds: 30),
          duration: row.duration,
          updatedAt: DateTime.utc(2026, 2),
          completed: false,
        ),
      );
      restored = (await VideoWatchHistory.read('hybrid')).first;
      expect(restored.metadata['year'], '2024');
      expect(restored.metadata['writers'], '作者甲 / 作者乙');
      expect(restored.position.inSeconds, 30);
      // History's existing sparse contract treats empty fields as unknown:
      // a replay without public basics must not retract an observed author.
      await VideoWatchHistory.record('hybrid', VideoWatchRecord(
        watchUrl: restored.watchUrl, title: restored.title,
        position: restored.position, duration: restored.duration,
        updatedAt: DateTime.utc(2026, 3), completed: false,
        metadata: const {'writers': ''},
      ));
      expect((await VideoWatchHistory.read('hybrid')).first.metadata['writers'],
        '作者甲 / 作者乙');
      expect((await VideoWatchHistory.read('another-source')), isEmpty);

    },
  );
}
