import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('visibility is local, keyed by ID and reloadable', () async {
    final preferences = DiscoverPluginVisibility();
    addTearDown(preferences.dispose);
    await preferences.load();
    expect(preferences.isVisible('plugin-a'), isTrue);
    await preferences.saveHiddenIds({'plugin-a'});
    expect(preferences.isVisible('plugin-a'), isFalse);
    expect(preferences.isVisible('plugin-b'), isTrue);
    final persisted = await SharedPreferences.getInstance();
    expect(persisted.getKeys(), {DiscoverPluginVisibility.preferenceKey});
    final next = DiscoverPluginVisibility();
    addTearDown(next.dispose);
    await next.load();
    expect(next.hiddenIds, {'plugin-a'});
  });

  test(
    'all-hidden state is reversible without removing uninstalled IDs',
    () async {
      final preferences = DiscoverPluginVisibility();
      addTearDown(preferences.dispose);
      await preferences.load();
      await preferences.saveHiddenIds({
        'installed-a',
        'installed-b',
        'uninstalled-c',
      });
      final visible = [
        'installed-a',
        'installed-b',
      ].where(preferences.isVisible);
      expect(visible, isEmpty);
      await preferences.saveHiddenIds(
        {...preferences.hiddenIds}..removeAll(['installed-a', 'installed-b']),
      );
      expect(preferences.hiddenIds, {'uninstalled-c'});
      expect(preferences.isVisible('installed-a'), isTrue);
      expect(
        preferences.isVisible('uninstalled-c'),
        isFalse,
        reason: 'reinstalling the same ID preserves its prior choice',
      );
    },
  );

  test(
    'a failed write leaves the current choice intact and can retry',
    () async {
      var attempts = 0;
      final preferences = DiscoverPluginVisibility(
        read: () async => ['old-hidden'],
        write: (_) async => ++attempts > 1,
      );
      addTearDown(preferences.dispose);
      await preferences.load();
      await expectLater(
        preferences.saveHiddenIds({'new-hidden'}),
        throwsStateError,
      );
      expect(preferences.hiddenIds, {'old-hidden'});
      await preferences.saveHiddenIds({'new-hidden'});
      expect(preferences.hiddenIds, {'new-hidden'});
      expect(attempts, 2);
    },
  );

  test(
    'writes are serialized so a slower old save cannot overwrite a newer one',
    () async {
      final first = Completer<bool>();
      final written = <List<String>>[];
      final preferences = DiscoverPluginVisibility(
        read: () async => [],
        write: (ids) async {
          written.add(ids);
          return written.length == 1 ? first.future : true;
        },
      );
      addTearDown(preferences.dispose);
      await preferences.load();
      final old = preferences.saveHiddenIds({'old'});
      final newest = preferences.saveHiddenIds({'new'});
      await Future<void>.delayed(Duration.zero);
      expect(written, [
        ['old'],
      ]);
      first.complete(true);
      await Future.wait([old, newest]);
      expect(written, [
        ['old'],
        ['new'],
      ]);
      expect(preferences.hiddenIds, {'new'});
    },
  );

  test(
    'a synchronous read failure clears inflight state and retries safely',
    () async {
      var attempts = 0;
      final preferences = DiscoverPluginVisibility(
        read: () {
          if (++attempts == 1) throw StateError('local preference read failed');
          return Future.value(['hidden']);
        },
      );
      addTearDown(preferences.dispose);
      await expectLater(preferences.load(), throwsStateError);
      expect(preferences.loaded, isFalse);
      expect(preferences.loadError, isNotNull);
      await preferences.load();
      expect(preferences.loaded, isTrue);
      expect(preferences.loadError, isNull);
      expect(preferences.hiddenIds, {'hidden'});
    },
  );

  test(
    'concurrent initial reads coalesce and invalid stored IDs are ignored',
    () async {
      final pending = Completer<List<String>>();
      var reads = 0;
      final preferences = DiscoverPluginVisibility(
        read: () {
          reads++;
          return pending.future;
        },
      );
      addTearDown(preferences.dispose);
      final first = preferences.load(), second = preferences.load();
      expect(second, same(first));
      expect(reads, 1);
      pending.complete(['good-id', 'good-id', '', ' whitespace ', 'x' * 201]);
      await first;
      expect(preferences.hiddenIds, {'good-id'});
    },
  );
}
