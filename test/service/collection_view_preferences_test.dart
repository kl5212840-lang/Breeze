import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Verify the legacy cache, which is changed before a platform write completes.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/service/collection_view_preferences.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  Completer<void>? readGate, writeGate;
  bool rejectNext = false, throwNext = false;
  int writes = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    await readGate?.future;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    final gate = writeGate;
    writeGate = null;
    final reject = rejectNext, throwing = throwNext;
    rejectNext = throwNext = false;
    await gate?.future;
    if (throwing) throw StateError('synthetic storage failure');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(CollectionViewPreferences.flush);

  test(
    'six public partitions and plugin modules/sections persist independently',
    () async {
      final scopes = [
        for (final media in ['comic', 'video'])
          for (final mode in ['favorite', 'history', 'download'])
            'public|$media|$mode',
        'plugin|bika|movie|favorite',
        'plugin|bika|animate|favorite',
        'plugin|bika|movie|history',
      ];
      for (var i = 0; i < scopes.length; i++) {
        await CollectionViewPreferences.write(
          scopes[i],
          i.isEven ? 'list' : 'grid',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      for (var i = 0; i < scopes.length; i++) {
        expect(
          await CollectionViewPreferences.read(scopes[i]),
          i.isEven ? 'list' : 'grid',
        );
      }
    },
  );

  test(
    'only valid legacy values are defaults and are never rewritten',
    () async {
      SharedPreferences.setMockInitialValues({
        'old-video': 'list',
        'old-comic': true,
        'bad-video': 'details',
        CollectionViewPreferences.keyFor('invalid'): 42,
      });
      expect(
        await CollectionViewPreferences.read('video', legacyKey: 'old-video'),
        'list',
      );
      expect(
        await CollectionViewPreferences.read(
          'comic',
          legacyDetailedKey: 'old-comic',
        ),
        'list',
      );
      expect(
        await CollectionViewPreferences.read('invalid', legacyKey: 'old-video'),
        'list',
      );
      expect(
        await CollectionViewPreferences.read('missing', legacyKey: 'bad-video'),
        isNull,
      );
      await CollectionViewPreferences.write('video', 'grid');
      expect(
        await CollectionViewPreferences.read('video', legacyKey: 'old-video'),
        'grid',
      );
      expect(
        (await SharedPreferences.getInstance()).getString('old-video'),
        'list',
      );
      expect(
        () => CollectionViewPreferences.write('video', 'details'),
        throwsArgumentError,
      );
    },
  );

  test(
    'read follows queued writes and rapid choices finish in user order',
    () async {
      final store = _Store()..writeGate = Completer<void>();
      final gate = store.writeGate!;
      SharedPreferencesStorePlatform.instance = store;
      final first = CollectionViewPreferences.write('rapid', 'list');
      final second = CollectionViewPreferences.write('rapid', 'grid');
      var readDone = false;
      final read = CollectionViewPreferences.read('rapid').then((value) {
        readDone = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 1);
      expect(readDone, isFalse);
      gate.complete();
      await Future.wait([first, second]);
      expect(await read, 'grid');
      expect(store.writes, 2);
    },
  );

  test(
    'a slow initial read cannot return a value from before a newer write',
    () async {
      final store = _Store()..readGate = Completer<void>();
      SharedPreferencesStorePlatform.instance = store;
      final read = CollectionViewPreferences.read('initial');
      final save = CollectionViewPreferences.write('initial', 'list');
      store.readGate!.complete();
      await save;
      expect(await read, 'list');
    },
  );

  for (final throwing in [false, true]) {
    test(
      'failed ${throwing ? 'throw' : 'false'} save restores cache and allows retry',
      () async {
        final store = _Store();
        SharedPreferencesStorePlatform.instance = store;
        await CollectionViewPreferences.write('failure', 'grid');
        final before = CollectionViewPreferences.changes.value;
        store.throwNext = throwing;
        store.rejectNext = !throwing;
        await expectLater(
          CollectionViewPreferences.write('failure', 'list'),
          throwsStateError,
        );
        expect(await CollectionViewPreferences.read('failure'), 'grid');
        expect(CollectionViewPreferences.changes.value, before);
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(await CollectionViewPreferences.read('failure'), 'grid');
        await CollectionViewPreferences.write('failure', 'list');
        expect(await CollectionViewPreferences.read('failure'), 'list');
      },
    );
  }

  test(
    'a failed pending write preserves a newer same-key restore and other scopes',
    () async {
      final store = _Store();
      SharedPreferencesStorePlatform.instance = store;
      await CollectionViewPreferences.write('restored', 'grid');
      store.writeGate = Completer<void>();
      final gate = store.writeGate!;
      store.rejectNext = true;
      final pending = CollectionViewPreferences.write('restored', 'list');
      final failed = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CollectionViewPreferences.keyFor('restored'),
        'grid',
      );
      await prefs.setString(CollectionViewPreferences.keyFor('other'), 'list');
      gate.complete();
      await failed;
      expect(await CollectionViewPreferences.read('restored'), 'grid');
      expect(await CollectionViewPreferences.read('other'), 'list');
      await prefs.reload();
      expect(await CollectionViewPreferences.read('restored'), 'grid');
      expect(await CollectionViewPreferences.read('other'), 'list');
    },
  );
}
