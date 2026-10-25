import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';

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
}
