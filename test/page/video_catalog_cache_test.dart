import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_catalog_cache.dart';

void main() {
  test('freshness expires without discarding fallback content', () {
    var now = DateTime.utc(2026);
    final cache = VideoCatalogCache(now: () => now);
    cache['/'] = {'videos': []};
    expect(cache.isFresh('/'), isTrue);
    now = now.add(VideoCatalogCache.freshFor);
    expect(cache.isFresh('/'), isFalse);
    expect(cache['/'], isNotNull);
    cache['/'] = {
      'videos': ['updated'],
    };
    expect(cache.isFresh('/'), isTrue);
    now = now.subtract(const Duration(hours: 1));
    expect(cache.isFresh('/'), isFalse);
  });

  test(
    'bounded cache replaces oldest snapshot and clears all account state',
    () {
      final cache = VideoCatalogCache();
      for (var i = 0; i < 9; i++) {
        cache['$i'] = {'id': i};
      }
      expect(cache.length, 8);
      expect(cache['0'], isNull);
      cache['1'] = {'id': 'updated'};
      cache['9'] = {};
      expect(cache['1'], {'id': 'updated'});
      expect(cache['2'], isNull);
      cache.clear();
      expect(cache.isFresh('1'), isFalse);
      expect(cache['1'], isNull);
    },
  );
}
