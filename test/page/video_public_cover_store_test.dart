import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/page/video/video_public_cover_store.dart';
import 'package:zephyr/service/temporary_data_cache.dart';

final _home = Uri.parse('https://video.example/');
Map<String, dynamic> _row(String id, {String? cover}) => {
  'id': id,
  'title': '更新作品$id',
  'detailUrl': '${_home}voddetail/$id.html',
  'coverUrl': ?cover,
  'remarks': '更新时间',
};
Map<String, dynamic> _page({String? cover}) => {
  'items': [_row('1', cover: cover)],
};
String? _cover(Map<String, dynamic> page) =>
    (page['items'] as List).first['coverUrl'] as String?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'restores public poster, isolates source/home, and respects source refresh',
    () async {
      final store = VideoPublicCoverStore(source: 'cover-restore', home: _home);
      await store.remember([
        ApiVideoItem.fromJson(
          _row('1', cover: 'https://images.example/one.jpg'),
          home: _home,
        ),
      ]);
      final restored = VideoPublicCoverStore(
        source: 'cover-restore',
        home: _home,
      );
      expect(
        _cover(await restored.supplement(_page(), refresh: false)),
        'https://images.example/one.jpg',
      );
      expect(_cover(await restored.supplement(_page(), refresh: true)), isNull);
      final otherSource = VideoPublicCoverStore(
        source: 'other-source',
        home: _home,
      );
      final otherHome = VideoPublicCoverStore(
        source: 'cover-restore',
        home: Uri.parse('https://other.example/'),
      );
      expect(
        _cover(await otherSource.supplement(_page(), refresh: false)),
        isNull,
      );
      expect(
        _cover(await otherHome.supplement(_page(), refresh: false)),
        isNull,
      );
      expect(
        _cover(
          await restored.supplement(
            _page(cover: 'https://images.example/new.jpg'),
            refresh: false,
          ),
        ),
        'https://images.example/new.jpg',
      );
      expect(
        _cover(await restored.supplement(_page(), refresh: false)),
        'https://images.example/new.jpg',
      );
    },
  );

  test(
    'bounded public-only pairs are device cache and source cleanup fences queued writes',
    () async {
      const source = 'cover-clear';
      final store = VideoPublicCoverStore(source: source, home: _home);
      await store.remember([
        for (var i = 0; i < 140; i++)
          ApiVideoItem.fromJson(
            _row('$i', cover: 'https://images.example/$i.jpg'),
            home: _home,
          ),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where(
            (key) =>
                key.startsWith(VideoPersonalSnapshotStore.prefix) &&
                !key.contains('invalidated.'),
          )
          .toList();
      expect(keys, hasLength(1));
      expect(PortablePreferences.owns(keys.single), false);
      final rows =
          (jsonDecode(prefs.getString(keys.single)!) as Map)['videos'] as List;
      expect(rows, hasLength(VideoPublicCoverStore.capacity));
      expect((rows.first as Map).keys.toSet(), {'pageUrl', 'coverUrl'});
      final pending = store.remember([
        ApiVideoItem.fromJson(
          _row('999', cover: 'https://images.example/late.jpg'),
          home: _home,
        ),
      ]);
      TemporaryDataCaches.clear(source: source);
      await pending;
      expect(_cover(await store.supplement(_page(), refresh: false)), isNull);
      await VideoPersonalSnapshotStore.clearDisk(source: source);
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith(VideoPersonalSnapshotStore.prefix),
        ),
        isEmpty,
      );
    },
  );

  test(
    'repository detail observations fill a recreated repository feed without overwriting labels',
    () async {
      const source = 'cover-repository';
      var detailCalls = 0;
      ApiVideoRepository repository() => ApiVideoRepository(
        source: source,
        home: _home,
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        pluginCall: (fn, args) async {
          if (fn == 'list') return {'data': _page()};
          detailCalls++;
          return {
            'data': _row('1', cover: 'https://images.example/repository.jpg'),
          };
        },
      );
      final first = repository();
      expect((await first.page()).items.single.coverUrl, isNull);
      await first.enrich(ApiVideoItem.fromJson(_row('1'), home: _home));
      // The repository queues the observation before resolving the detail. Page
      // reads await that queue, including after a new repository is constructed.
      await first.page();
      final recovered = (await repository().page()).items.single;
      expect(
        recovered.coverUrl.toString(),
        'https://images.example/repository.jpg',
      );
      expect(recovered.title, '更新作品1');
      expect(recovered.remarks, '更新时间');
      expect(detailCalls, 1);
      expect((await first.page(refresh: true)).items.single.coverUrl, isNull);
    },
  );
}
