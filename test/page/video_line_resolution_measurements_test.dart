import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_line_resolution_measurements.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resolver measurements are bounded and isolate route and episode',
    () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime.utc(2026, 11, 25);
      final cache = VideoLineResolutionMeasurements(now: () => now);
      String key({
        String route = 'system',
        String episode = 'episode-1',
        String line = 'line-b',
      }) => VideoLineResolutionMeasurements.key(
        source: 'source-id',
        work: 'https://example.test/watch?signed=private',
        episode: episode,
        line: line,
        route: route,
      );
      const success = (
        elapsed: Duration(milliseconds: 240),
        outcome: VideoLineResolutionOutcome.resolved,
      );
      const failure = (
        elapsed: Duration(seconds: 2),
        outcome: VideoLineResolutionOutcome.failed,
      );
      const timeout = (
        elapsed: Duration(seconds: 8),
        outcome: VideoLineResolutionOutcome.timedOut,
      );
      await cache.record(key(), success);
      await cache.record(key(line: 'line-c'), failure);
      await cache.record(key(line: 'line-d'), timeout);
      expect(cache.read(key(route: 'proxy')), isNull);
      expect(cache.read(key(episode: 'episode-2')), isNull);
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(VideoLineResolutionMeasurements.storageKey)!;
      expect(data, isNot(contains('private')));
      expect(data, isNot(contains('example.test')));
      expect(data, isNot(contains('line-b')));

      final reopened = VideoLineResolutionMeasurements(now: () => now);
      await reopened.load();
      expect(reopened.read(key()), success);
      expect(reopened.read(key(line: 'line-c')), failure);
      expect(reopened.read(key(line: 'line-d')), timeout);
      now = now.add(const Duration(minutes: 2));
      expect(reopened.read(key()), success);
      expect(reopened.read(key(line: 'line-c')), isNull);
      expect(reopened.read(key(line: 'line-d')), isNull);
      now = now.add(const Duration(minutes: 8));
      expect(reopened.read(key()), isNull);

      for (var number = 0; number < 100; number++) {
        now = now.add(const Duration(milliseconds: 1));
        await reopened.record(key(episode: '$number'), success);
      }
      expect(reopened.read(key(episode: '0')), isNull);
      expect(reopened.read(key(episode: '99')), success);
      expect(
        jsonDecode(prefs.getString(VideoLineResolutionMeasurements.storageKey)!)
            as Map,
        hasLength(96),
      );
      cache.dispose();
      reopened.dispose();
    },
  );
}
