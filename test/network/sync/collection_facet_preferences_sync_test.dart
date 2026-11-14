import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';

class _PausedFacetWrites extends InMemorySharedPreferencesStore {
  _PausedFacetWrites() : super.empty();
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('breeze.bookshelf.facet-tags.v1.')) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a pin changed during restore is applied to the restored set', () async {
    await ShelfFacetPreferences.save('comic', {'remote-tag'});
    final incoming = await PortablePreferences.capture();
    SharedPreferences.setMockInitialValues({});
    await ShelfFacetPreferences.save('comic', {'old-tag'});
    final planned = Completer<void>();
    final commit = Completer<void>();
    final restoring = PortablePreferences.restore(
      incoming,
      replace: true,
      beforeWrite: (_) {
        planned.complete();
        return commit.future;
      },
    );
    await planned.future;
    final toggling = ShelfFacetPreferences.toggle('comic', 'new-tag');
    await Future<void>.delayed(Duration.zero);
    commit.complete();
    await restoring;
    await toggling;

    expect(await ShelfFacetPreferences.load('comic'), {
      'remote-tag',
      'new-tag',
    });
  });

  test('backup waits for an in-flight starred-tag write', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final paused = _PausedFacetWrites();
    SharedPreferencesStorePlatform.instance = paused;
    final writing = ShelfFacetPreferences.toggle('comic', 'new-tag');
    try {
      await paused.started.future;
      var finished = false;
      final capture = PortablePreferences.capture().then((value) {
        finished = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(finished, isFalse);
      paused.release.complete();
      await writing;
      final snapshot = await capture;
      expect(jsonEncode(snapshot.toJson()), contains('new-tag'));
    } finally {
      if (!paused.release.isCompleted) paused.release.complete();
      await writing;
      SharedPreferencesStorePlatform.instance = previous;
    }
  });

  test(
    'unknown encoded source scopes restore separately from account keys',
    () async {
      const source = 'future-plugin/源%auth.userInfo';
      await ShelfFacetPreferences.save('comic', {'comic-tag'});
      await ShelfFacetPreferences.save('video', {'video-tag'});
      await ShelfFacetPreferences.save(source, {'未知源标签', 'tag-a'});
      final snapshot = await PortablePreferences.capture();
      final encoded = jsonEncode(snapshot.toJson());
      expect(encoded, contains(Uri.encodeComponent(source)));

      SharedPreferences.setMockInitialValues({
        'auth.userInfo': 'device-b-account-fixture',
        'auth.jwt': 'device-b-session-fixture',
      });
      var notifications = 0;
      void restored() => notifications++;
      PortablePreferences.changes.addListener(restored);
      addTearDown(() => PortablePreferences.changes.removeListener(restored));
      await PortablePreferences.restore(
        PortablePreferencesSnapshot.fromJson(jsonDecode(encoded)),
        replace: true,
      );
      expect(await ShelfFacetPreferences.load('comic'), {'comic-tag'});
      expect(await ShelfFacetPreferences.load('video'), {'video-tag'});
      expect(await ShelfFacetPreferences.load(source), {'未知源标签', 'tag-a'});
      expect(await ShelfFacetPreferences.load('other-plugin'), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth.userInfo'), 'device-b-account-fixture');
      expect(prefs.getString('auth.jwt'), 'device-b-session-fixture');
      expect(notifications, 1);

      final excluded = PortablePreferences.forSync(
        snapshot,
        includeSettings: false,
      );
      expect(
        excluded.entries.values.where(
          (row) => (row['key'] as String).startsWith(
            'breeze.bookshelf.facet-tags.v1.',
          ),
        ),
        isEmpty,
      );
    },
  );

  test(
    'filter favorites restore with the correct settings ownership',
    () async {
      const global = 'download|all|*|facet:status';
      const source = 'download|video|test-source|facet:quality';
      const sourceVideo = 'source-downloads.test-source|facet:author';
      const comicPanel = 'source-filter|test-source|comic-list|facet:category';
      const omoSite = 'omo.site-favorites.test-source|facet:author';
      await ShelfFacetPreferences.save(global, {'paused'});
      await ShelfFacetPreferences.save(source, {'720p'});
      await ShelfFacetPreferences.save(sourceVideo, {'Example author'});
      await ShelfFacetPreferences.save(comicPanel, {'comics'});
      await ShelfFacetPreferences.save(omoSite, {'Site author'});
      final snapshot = await PortablePreferences.capture();
      final app = PortablePreferences.forSync(
        snapshot,
        includeSettings: true,
        includePluginSettings: false,
      );
      final plugin = PortablePreferences.forSync(
        snapshot,
        includeSettings: false,
        includePluginSettings: true,
      );
      bool has(PortablePreferencesSnapshot settings, String scope) =>
          settings.entries.values.any(
            (row) =>
                row['key'] ==
                'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(scope)}',
          );
      expect(has(app, global), isTrue);
      expect(has(app, source), isFalse);
      expect(has(app, sourceVideo), isFalse);
      expect(has(app, comicPanel), isFalse);
      expect(has(app, omoSite), isFalse);
      expect(has(plugin, global), isFalse);
      expect(has(plugin, source), isTrue);
      expect(has(plugin, sourceVideo), isTrue);
      expect(has(plugin, comicPanel), isTrue);
      expect(has(plugin, omoSite), isTrue);

      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(snapshot, replace: true);
      expect(await ShelfFacetPreferences.load(global), {'paused'});
      expect(await ShelfFacetPreferences.load(source), {'720p'});
      expect(await ShelfFacetPreferences.load(sourceVideo), {'Example author'});
      expect(await ShelfFacetPreferences.load(comicPanel), {'comics'});
      expect(await ShelfFacetPreferences.load(omoSite), {'Site author'});
    },
  );

  test(
    'temporarily unavailable source tabs retain order and visibility after restore',
    () async {
      final store = BookshelfSourcePreferenceStore();
      await store.save(
        BookshelfSourceMedium.comic,
        BookshelfSourcePreferences(
          order: ['known-a', 'future-plugin', 'known-b'],
          hidden: ['future-plugin'],
        ),
      );
      final snapshot = await PortablePreferences.capture();
      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(snapshot, replace: true);
      final restored = await store.read(BookshelfSourceMedium.comic);
      expect(restored.order, ['known-a', 'future-plugin', 'known-b']);
      expect(restored.hidden, {'future-plugin'});
      final reordered = restored.withKnownOrder(['known-b', 'known-a']);
      expect(reordered.order, ['known-b', 'future-plugin', 'known-a']);
      expect(reordered.hidden, {'future-plugin'});
      expect(reordered.arrange({'known-a': 'A', 'known-b': 'B'}).keys, [
        'known-b',
        'known-a',
      ]);
      expect(
        reordered.arrange({
          'known-a': 'A',
          'known-b': 'B',
          'future-plugin': 'F',
        }).keys,
        ['known-b', 'known-a'],
      );
    },
  );

  test(
    'a deleted starred-tag preference stays deleted against a stale snapshot',
    () async {
      const key = 'breeze.bookshelf.facet-tags.v1.comic';
      await ShelfFacetPreferences.save('comic', {'stale-tag'});
      final stale = await PortablePreferences.capture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      final deleted = await PortablePreferences.capture();
      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(deleted.merged(stale), replace: true);
      expect(await ShelfFacetPreferences.load('comic'), isEmpty);
      expect((await SharedPreferences.getInstance()).containsKey(key), isFalse);
    },
  );
}
