import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';

void main() {
  test('only original JM likes for a matching work are evidence', () {
    expect(
      readJmListLikeCounts(
        {
          'list': [
            {'id': 1, 'favorite': false, 'liked': false, 'total_views': 98},
            {'id': 2, 'likes': '0'},
            {'id': '3', 'likes': 1234},
            {'id': '4', 'likes': false},
            {'id': '5', 'likes': 1.5},
            {'id': '6', 'likes': 92},
            {'id': '6', 'likes': 95},
            {'id': 'outside', 'likes': 100},
            {'id': '7', 'likes': null},
          ],
        },
        {'1', '2', '3', '4', '5', '6', '7'},
      ),
      {'2': 0, '3': 1234},
    );
  });

  test('bounded storage keeps zero and discards expired counts', () {
    var now = Duration.zero;
    final counts = JmListLikeCounts(
      sessionFence: PluginSessionWriteFence(),
      elapsed: () => now,
      lifetime: const Duration(minutes: 5),
      capacity: 2,
    );
    addTearDown(counts.dispose);
    var updates = 0;
    counts.addListener(() => updates++);

    counts.remember({'first': 12, 'zero': 0}, generation: 0);
    expect(counts.countFor('zero'), 0);
    expect(counts.countFor('unknown'), isNull);
    counts.remember({'third': 123}, generation: 0);
    expect(counts.countFor('first'), isNull);
    expect(counts.countFor('third'), 123);
    expect(updates, 2);

    now += const Duration(minutes: 5);
    expect(counts.countFor('zero'), isNull);
    expect(counts.countFor('third'), isNull);
  });

  test('session and reload boundaries reject retired readings', () {
    final fence = PluginSessionWriteFence();
    final counts = JmListLikeCounts(sessionFence: fence);
    addTearDown(counts.dispose);
    const source = JmListLikeCounts.source;
    counts.remember({'work': 24}, generation: 0);
    expect(counts.countFor('work'), 24);

    fence.advance('another-source');
    expect(counts.countFor('work'), 24);

    final owner = fence.beginSessionChange(source);
    counts.remember({'work': 123}, generation: owner);
    expect(counts.countFor('work'), isNull);
    fence.seal(source, owner);
    counts.remember({'work': 42}, generation: owner);
    expect(counts.countFor('work'), isNull);

    counts.remember({'work': 23}, generation: fence.generation(source));
    expect(counts.countFor('work'), 23);
    fence.advance(source);
    expect(counts.countFor('work'), isNull);
  });
}
