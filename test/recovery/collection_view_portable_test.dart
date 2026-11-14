import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/service/collection_view_preferences.dart';

class _PausedViewStore extends InMemorySharedPreferencesStore {
  _PausedViewStore(this.pausedKey) : super.empty();
  final String pausedKey;
  final started = Completer<void>(), release = Completer<void>();
  bool _paused = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    // The legacy Dart API adds its default prefix at the platform boundary.
    if (key == 'flutter.$pausedKey' && !_paused) {
      _paused = true;
      started.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

Map<String, dynamic> _views(PortablePreferencesSnapshot snapshot) => {
  for (final row in snapshot.entries.values)
    if ((row['key'] as String).startsWith(CollectionViewPreferences.prefix) &&
        row['deleted'] != true)
      row['key'] as String: row['value'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await CollectionViewPreferences.flush();
    await SourceListPreferences.flush();
  });

  test(
    'actual backup and restore preserve all collection scopes and notify once',
    () async {
      final expected = <String, String>{
        for (final medium in ['comic', 'video'])
          for (final mode in ['favorite', 'history', 'download'])
            'public|$medium|$mode': mode == 'history' ? 'list' : 'grid',
        'plugin|future/源%plugin|movie namespace|library': 'list',
        'plugin|future/源%plugin|animate namespace|library': 'grid',
        'plugin|future/源%plugin|movie namespace|favorite': 'grid',
        'plugin|future/源%plugin|movie namespace|history': 'list',
      };
      for (final entry in expected.entries) {
        await CollectionViewPreferences.write(entry.key, entry.value);
      }
      final captured = await PortablePreferences.capture();
      final replay = PortablePreferencesSnapshot.fromJson(
        jsonDecode(jsonEncode(captured.toJson())),
      );
      expect(_views(replay), {
        for (final entry in expected.entries)
          CollectionViewPreferences.keyFor(entry.key): entry.value,
      });
      SharedPreferences.setMockInitialValues({
        'auth.userInfo': 'synthetic device-b account',
        'auth.jwt': 'synthetic device-b token',
      });
      var notified = 0;
      void changed() => notified++;
      CollectionViewPreferences.changes.addListener(changed);
      addTearDown(
        () => CollectionViewPreferences.changes.removeListener(changed),
      );
      await PortablePreferences.restore(replay, replace: true);
      expect(notified, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      for (final entry in expected.entries) {
        expect(await CollectionViewPreferences.read(entry.key), entry.value);
      }
      expect(prefs.getString('auth.userInfo'), 'synthetic device-b account');
      expect(prefs.getString('auth.jwt'), 'synthetic device-b token');
      expect(
        await CollectionViewPreferences.read('public|comic|unknown'),
        isNull,
      );
    },
  );

  test(
    'excluding settings omits view preferences but retains playback progress',
    () async {
      await CollectionViewPreferences.write('public|video|favorite', 'list');
      await SourceListPreferences.write('future-plugin', true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('breeze.video.progress.synthetic-record', 12345);
      final captured = await PortablePreferences.capture();
      expect(_views(captured), hasLength(1));
      final withoutSettings = PortablePreferences.forSync(
        captured,
        includeSettings: false,
      );
      expect(_views(withoutSettings), isEmpty);
      expect(
        withoutSettings.entries.values.any(
          (row) =>
              (row['key'] as String).startsWith(SourceListPreferences.prefix),
        ),
        isFalse,
      );
      expect(
        withoutSettings.entries.values.single['key'],
        'breeze.video.progress.synthetic-record',
      );
      expect(withoutSettings.entries.values.single['value'], 12345);
      expect(_views(PortablePreferences.forSync(captured)), _views(captured));
    },
  );

  test(
    'invalid local views are omitted without blocking valid backup scopes',
    () async {
      final invalidKey = CollectionViewPreferences.keyFor(
        'public|comic|favorite',
      );
      final validKey = CollectionViewPreferences.keyFor('public|video|history');
      SharedPreferences.setMockInitialValues({
        invalidKey: 'compact',
        validKey: 'list',
      });
      final captured = await PortablePreferences.capture();
      expect(_views(captured), {validKey: 'list'});
      expect(
        await CollectionViewPreferences.read('public|comic|favorite'),
        isNull,
      );
      expect(
        PortablePreferencesSnapshot.fromJson(captured.toJson()).toJson(),
        captured.toJson(),
      );
    },
  );

  test(
    'invalid incoming views fail validation before any restoration or notification',
    () async {
      const scope = 'public|comic|favorite';
      await CollectionViewPreferences.write(scope, 'grid');
      final captured = await PortablePreferences.capture();
      final entry = captured.entries.entries.singleWhere(
        (entry) =>
            entry.value['key'] == CollectionViewPreferences.keyFor(scope),
      );
      final invalid = PortablePreferencesSnapshot({
        entry.key: {...entry.value, 'value': 'columns'},
      });
      final before = CollectionViewPreferences.changes.value;
      await expectLater(
        PortablePreferences.restore(invalid, replace: true),
        throwsFormatException,
      );
      expect(await CollectionViewPreferences.read(scope), 'grid');
      expect(CollectionViewPreferences.changes.value, before);
    },
  );

  test(
    'an invalid local layout retains its previous valid journal entry',
    () async {
      const scope = 'public|comic|favorite';
      await CollectionViewPreferences.write(scope, 'list');
      final valid = await PortablePreferences.capture();
      final key = CollectionViewPreferences.keyFor(scope);
      final previous = valid.entries.entries.singleWhere(
        (entry) => entry.value['key'] == key,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, 'compact');
      final captured = await PortablePreferences.capture();
      expect(captured.entries[previous.key], previous.value);
      expect(captured.entries[previous.key]?['deleted'], isFalse);
      expect(_views(captured), {key: 'list'});
      final replay = PortablePreferencesSnapshot.fromJson(
        jsonDecode(jsonEncode(captured.toJson())),
      );
      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(replay, replace: true);
      expect(await CollectionViewPreferences.read(scope), 'list');
    },
  );

  for (final legacy in [false, true]) {
    test(
      'backup waits for an in-flight ${legacy ? 'source' : 'collection'} view write',
      () async {
        const scope = 'public|video|download';
        final key = legacy
            ? '${SourceListPreferences.prefix}future-plugin'
            : CollectionViewPreferences.keyFor(scope);
        final paused = _PausedViewStore(key);
        SharedPreferencesStorePlatform.instance = paused;
        final writing = legacy
            ? SourceListPreferences.write('future-plugin', true)
            : CollectionViewPreferences.write(scope, 'list');
        try {
          await paused.started.future.timeout(const Duration(seconds: 5));
          var finished = false;
          final capture = PortablePreferences.capture().then((snapshot) {
            finished = true;
            return snapshot;
          });
          await Future<void>.delayed(Duration.zero);
          expect(finished, isFalse);
          paused.release.complete();
          await writing;
          final captured = await capture.timeout(const Duration(seconds: 5));
          expect(
            captured.entries.values.singleWhere(
              (row) => row['key'] == key,
            )['value'],
            legacy ? true : 'list',
          );
        } finally {
          if (!paused.release.isCompleted) paused.release.complete();
          await writing;
        }
      },
    );
  }

  test(
    'restore waits for old writes and retains incoming scope boundaries',
    () async {
      const favorite = 'public|video|favorite',
          history = 'public|video|history';
      await CollectionViewPreferences.write(favorite, 'grid');
      await CollectionViewPreferences.write(history, 'list');
      final incoming = PortablePreferencesSnapshot.fromJson(
        (await PortablePreferences.capture()).toJson(),
      );
      SharedPreferences.setMockInitialValues({});
      final paused = _PausedViewStore(
        CollectionViewPreferences.keyFor(favorite),
      );
      SharedPreferencesStorePlatform.instance = paused;
      final writing = CollectionViewPreferences.write(favorite, 'list');
      try {
        await paused.started.future.timeout(const Duration(seconds: 5));
        var finished = false;
        final restore = PortablePreferences.restore(
          incoming,
          replace: true,
        ).then((_) => finished = true);
        await Future<void>.delayed(Duration.zero);
        expect(finished, isFalse);
        paused.release.complete();
        await writing;
        await restore.timeout(const Duration(seconds: 5));
        expect(await CollectionViewPreferences.read(favorite), 'grid');
        expect(await CollectionViewPreferences.read(history), 'list');
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(await CollectionViewPreferences.read(favorite), 'grid');
        expect(await CollectionViewPreferences.read(history), 'list');
      } finally {
        if (!paused.release.isCompleted) paused.release.complete();
        await writing;
      }
    },
  );
}
