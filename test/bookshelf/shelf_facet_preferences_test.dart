import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the legacy API's cache-before-persistence failure contract.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';

class _RejectedFacetWrite extends InMemorySharedPreferencesStore {
  _RejectedFacetWrite() : super.empty();
  final started = Completer<void>();
  final release = Completer<void>();
  bool rejectNext = false;
  bool throwFailure = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (rejectNext) {
      rejectNext = false;
      started.complete();
      await release.future;
      if (throwFailure) throw StateError('fixture write failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'stars persist independently for comics and videos without changing caller sets',
    () async {
      final tags = {'A', 'B'};
      await ShelfFacetPreferences.save('comic', tags);
      await ShelfFacetPreferences.save('video', {'C'});
      expect(await ShelfFacetPreferences.load('comic'), tags);
      expect(await ShelfFacetPreferences.load('video'), {'C'});
      expect(tags, {'A', 'B'});
      await ShelfFacetPreferences.save('comic', {'B'});
      expect(await ShelfFacetPreferences.load('comic'), {'B'});
      expect(await ShelfFacetPreferences.load('video'), {'C'});
    },
  );
  test('malformed preferences cannot become selected tags', () async {
    SharedPreferences.setMockInitialValues({
      'breeze.bookshelf.facet-tags.v1.comic': '{broken',
    });
    await expectLater(ShelfFacetPreferences.load('comic'), throwsFormatException);
    await expectLater(ShelfFacetPreferences.toggle('comic', 'new'), throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString('breeze.bookshelf.facet-tags.v1.comic'), '{broken');
  });
  test('missing-metadata markers cannot be starred and source scopes remain separate', () async {
    await expectLater(ShelfFacetPreferences.toggle('comic', shelfFacetUnknown), throwsArgumentError);
    await ShelfFacetPreferences.toggle('source-results|one', 'same label');
    expect(await ShelfFacetPreferences.load('source-results|two'), isEmpty);
    expect(await ShelfFacetPreferences.load('source-results|one'), {'same label'});
  });
  test(
    'concurrent star toggles compose per scope and load waits for queued writes',
    () async {
      await ShelfFacetPreferences.save('comic', {'restored'});
      final actions = [
        ShelfFacetPreferences.toggle('comic', 'A'),
        ShelfFacetPreferences.toggle('comic', 'B'),
        ShelfFacetPreferences.toggle('comic', 'A'),
        ShelfFacetPreferences.toggle('video', 'V'),
      ];
      expect(await ShelfFacetPreferences.load('comic'), {'restored', 'B'});
      await Future.wait(actions);
      await ShelfFacetPreferences.flush();
      expect(await ShelfFacetPreferences.load('video'), {'V'});
    },
  );

  test(
    'toggle reads external restored set and returns an independent result',
    () async {
      await ShelfFacetPreferences.save('comic', {'old'});
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'breeze.bookshelf.facet-tags.v1.comic',
        '["restored"]',
      );
      final first = await ShelfFacetPreferences.toggle('comic', 'A');
      await ShelfFacetPreferences.toggle('comic', 'B');
      expect(first, {'restored', 'A'});
      expect(await ShelfFacetPreferences.load('comic'), {'restored', 'A', 'B'});
    },
  );
  for (final throws in [false, true]) {
    test(
      'failed star write keeps previous cache and allows retry; throws=$throws',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _RejectedFacetWrite()..throwFailure = throws;
        SharedPreferencesStorePlatform.instance = store;
        try {
          await ShelfFacetPreferences.save('comic', {'old'});
          final revision = ShelfFacetPreferences.changes.value;
          store.rejectNext = true;
          final writing = ShelfFacetPreferences.toggle('comic', 'failed');
          final failure = expectLater(writing, throwsStateError);
          await store.started.future;
          store.release.complete();
          await failure;
          expect(await ShelfFacetPreferences.load('comic'), {'old'});
          expect(ShelfFacetPreferences.changes.value, revision);
          await ShelfFacetPreferences.toggle('comic', 'retry');
          expect(await ShelfFacetPreferences.load('comic'), {'old', 'retry'});
          final preferences = await SharedPreferences.getInstance();
          await preferences.reload();
          expect(await ShelfFacetPreferences.load('comic'), {'old', 'retry'});
        } finally {
          if (!store.release.isCompleted) store.release.complete();
          await ShelfFacetPreferences.flush();
          SharedPreferencesStorePlatform.instance = previous;
        }
      },
    );
  }

  test('failed star write cannot roll back a newer restored value', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _RejectedFacetWrite();
    SharedPreferencesStorePlatform.instance = store;
    try {
      await ShelfFacetPreferences.save('comic', {'old'});
      store.rejectNext = true;
      final writing = ShelfFacetPreferences.toggle('comic', 'failed');
      final failure = expectLater(writing, throwsStateError);
      await store.started.future;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'breeze.bookshelf.facet-tags.v1.comic',
        '["restored"]',
      );
      store.release.complete();
      await failure;
      expect(await ShelfFacetPreferences.load('comic'), {'restored'});
      await preferences.reload();
      expect(await ShelfFacetPreferences.load('comic'), {'restored'});
    } finally {
      if (!store.release.isCompleted) store.release.complete();
      await ShelfFacetPreferences.flush();
      SharedPreferencesStorePlatform.instance = previous;
    }
  });
}
