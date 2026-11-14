import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_catalog_cache.dart';
import 'package:zephyr/service/temporary_data_cache.dart';

void main() {
  test(
    'plugin cleanup clears its real browser snapshots and keeps other sources',
    () {
      final a = VideoCatalogCache(cacheSource: 'cache-a');
      final b = VideoCatalogCache(cacheSource: 'cache-b');
      a['catalog'] = {
        'items': ['one'],
      };
      b['catalog'] = {
        'items': ['two'],
      };
      final generation = a.generation;
      TemporaryDataCaches.clear(source: 'cache-a');
      expect(a, isEmpty);
      expect(a.generation, generation + 1);
      expect(a.isFresh('catalog'), isFalse);
      expect(b['catalog'], {
        'items': ['two'],
      });
      expect(TemporaryDataCaches.count(source: 'cache-b'), 1);
      TemporaryDataCaches.clear();
      expect(b, isEmpty);
    },
  );

  test(
    'clearing during a detail request keeps the result without restoring its cache',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final home = Uri.parse('https://cache.example/');
      Map<String, dynamic> detail() => {
        'data': {
          'id': '1',
          'title': '作品',
          'detailUrl': home.resolve('voddetail/1.html').toString(),
        },
      };
      final repo = ApiVideoRepository(
        source: 'cache-pending',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, _) async => ++calls == 1 ? pending.future : detail(),
      );
      final result = repo.item('1');
      await Future<void>.delayed(Duration.zero);
      TemporaryDataCaches.clear(source: 'cache-pending');
      pending.complete(detail());
      expect((await result).title, '作品');
      expect(repo.cacheEntryCount, 0);
      expect((await repo.item('1')).title, '作品');
      expect(calls, 2);
      expect(repo.cacheEntryCount, 1);
    },
  );

  test(
    'clearing also invalidates detail reads queued before cleanup',
    () async {
      final pending = <String, Completer<Map<String, dynamic>>>{};
      final home = Uri.parse('https://queued-cache.example/');
      Map<String, dynamic> detail(String id) => {
        'data': {
          'id': id,
          'title': '作品$id',
          'detailUrl': home.resolve('voddetail/$id.html').toString(),
        },
      };
      final repo = ApiVideoRepository(
        source: 'cache-queued',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, args) {
          final id = args['id'] as String;
          final request = Completer<Map<String, dynamic>>();
          pending[id] = request;
          return request.future;
        },
      );
      final first = repo.item('1');
      final second = repo.item('2');
      final queued = repo.item('3');
      await Future<void>.delayed(Duration.zero);
      expect(pending.keys, unorderedEquals(['1', '2']));
      TemporaryDataCaches.clear(source: 'cache-queued');
      pending['1']!.complete(detail('1'));
      pending['2']!.complete(detail('2'));
      await Future.wait([first, second]);
      expect(pending, contains('3'));
      pending['3']!.complete(detail('3'));
      expect((await queued).title, '作品3');
      expect(repo.cacheEntryCount, 0);
    },
  );
}
