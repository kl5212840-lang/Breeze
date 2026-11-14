import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/page/comic_info/models/unified_plugin_detail.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/jm_cover_like_loader.dart';
import 'package:zephyr/widgets/comic_simplify_entry/jm_cover_like_badge.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('detail likes require explicit availability and both matching IDs', () {
    const source = JmListLikeCounts.source;
    int? read(Object? count, Object? available, {String comicInfoId = '7'}) =>
        UnifiedPluginDetailResponse.fromMap({
          'source': source,
          'comicId': '7',
          'data': {
            'normal': {
              'comicInfo': {'id': comicInfoId},
              'totalLikes': count,
              'extern': {
                'metricAvailability': {'totalLikes': available},
              },
            },
          },
        }).confirmedLikes(source: source, comicId: '7');
    expect(read(0, true), 0);
    expect(read(0, null), isNull);
    expect(read(1, false), isNull);
    expect(read(null, true), isNull);
    expect(read(10, true, comicInfoId: '8'), isNull);
  });

  test(
    'two physical slots, no offscreen queue or retired cache write',
    () async {
      final fence = PluginSessionWriteFence();
      final priority = ValueNotifier<int>(0);
      final counts = JmListLikeCounts(sessionFence: fence);
      final calls = <String, Completer<int?>>{};
      final loader = JmCoverLikeLoader(
        counts: counts,
        fence: fence,
        foregroundReads: priority,
        canRead: () => true,
        read: (id) => (calls[id] = Completer<int?>()).future,
      );
      addTearDown(() {
        loader.dispose();
        counts.dispose();
        priority.dispose();
      });

      loader.setDemand('list', {'1', '2', 'offscreen'});
      loader.setDemand('other', {'1'});
      await _settle();
      expect(calls.keys, ['1', '2']);
      loader.setDemand('list', {});
      loader.setDemand('other', {});
      fence.advance(JmListLikeCounts.source);
      loader.setDemand('new', {'3'});
      await _settle();
      expect(calls.keys, ['1', '2']);
      calls['1']!.complete(100);
      await _settle();
      expect(counts.countFor('1'), isNull);
      expect(calls.keys, ['1', '2', '3']);
      calls['2']!.complete(200);
      calls['3']!.complete(0);
      await _settle();
      expect(counts.countFor('2'), isNull);
      expect(counts.countFor('3'), 0);
      expect(calls, isNot(contains('offscreen')));
    },
  );

  test('priority reads delay misses and 429 pauses the queue', () async {
    final fence = PluginSessionWriteFence();
    final priority = ValueNotifier<int>(1);
    final counts = JmListLikeCounts(sessionFence: fence);
    final calls = <String>[];
    var elapsed = Duration.zero;
    final first = Completer<int?>();
    final second = Completer<int?>();
    final loader = JmCoverLikeLoader(
      counts: counts,
      fence: fence,
      foregroundReads: priority,
      canRead: () => true,
      elapsed: () => elapsed,
      read: (id) {
        calls.add(id);
        return switch (id) {
          '1' => first.future,
          '2' => second.future,
          _ => Future<int?>.value(3),
        };
      },
    );
    addTearDown(() {
      loader.dispose();
      counts.dispose();
      priority.dispose();
    });

    loader.setDemand('list', {'1', '2', '3'});
    expect(calls, isEmpty);
    priority.value = 0;
    await _settle();
    expect(calls, ['1', '2']);
    first.completeError(Exception('HTTP 429 Too Many Requests'));
    second.complete(2);
    await _settle();
    expect(calls, ['1', '2']);
    expect(counts.countFor('2'), 2);
    elapsed += const Duration(minutes: 2);
    loader.setDemand('list', {'2', '3'});
    await _settle();
    expect(calls, ['1', '2', '3']);
  });

  testWidgets('cache extent builds offscreen cards without requesting likes', (
    tester,
  ) async {
    final detector = VisibilityDetectorController.instance;
    final oldInterval = detector.updateInterval;
    detector.updateInterval = Duration.zero;
    addTearDown(() => detector.updateInterval = oldInterval);
    final fence = PluginSessionWriteFence();
    final counts = JmListLikeCounts(sessionFence: fence);
    final priority = ValueNotifier<int>(0);
    final scroll = ScrollController();
    final calls = <String>[];
    final built = <int>{};
    final loader = JmCoverLikeLoader(
      counts: counts,
      fence: fence,
      foregroundReads: priority,
      canRead: () => true,
      read: (id) async {
        calls.add(id);
        return null;
      },
    );
    addTearDown(() {
      loader.dispose();
      counts.dispose();
      priority.dispose();
      scroll.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JmCoverLikeScope(
            counts: counts,
            loader: loader,
            child: Center(
              child: SizedBox(
                height: 100,
                width: 90,
                child: ListView.builder(
                  controller: scroll,
                  itemExtent: 100,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(400),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    built.add(index);
                    return JmCoverLikeVisibility(
                      comicId: '$index',
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(built, containsAll([0, 1, 2]));
    await tester.pump(const Duration(milliseconds: 249));
    expect(calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, ['0']);

    scroll.jumpTo(300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 249));
    expect(calls, ['0']);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, ['0', '3']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
