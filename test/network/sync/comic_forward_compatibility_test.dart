import 'sync_installed_fixture.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';

import '../../test_helper.dart';
import 'sync_compatibility_guard_test.dart'
    show CompatibilityRemote, compatibilityIdentity;

const _codec = ComicSyncCodec(
  encode: compatibilityIdentity,
  decode: compatibilityIdentity,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.unifiedFavoriteBox.removeAll();
    await installSyncPlugins(['test']);
  });

  for (final change in ['version', 'collection', 'field', 'schema']) {
    test(
      'manual comic upload refuses future $change and preserves local/cloud records',
      () async {
        final local = createTestFavorite('source:local')..deleted = true;
        objectbox.unifiedFavoriteBox.put(local);
        final row = createTestFavorite('source:remote').toJson()..remove('id');
        final data = <String, dynamic>{
          'version': 'v1',
          'favorites': [row],
        };
        if (change == 'version') data['version'] = 'v99';
        if (change == 'collection') data['future-records'] = [];
        if (change == 'field') row['future-field'] = 'not understood';
        if (change == 'schema') row['schemaVersion'] = 99;
        final remote = CompatibilityRemote()..payload('comic', data);
        await expectLater(
          uploadComicData(remote, codec: _codec),
          throwsA(isA<SyncCompatibilityException>()),
        );
        expect(remote.uploads, 0);
        expect(remote.deletions, 0);
        expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isTrue);
        expect(
          objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
          'source:local',
        );
      },
    );
  }

  test(
    'public comic download preserves unknown metadata entries as an opaque string',
    () async {
      const metadata =
          '[{"type":"future-plugin-field","value":{"nested":[1,"opaque"]}}]';
      final row = createTestFavorite('source:remote')..metadata = metadata;
      final raw = row.toJson()..remove('id');
      final remote = CompatibilityRemote()
        ..payload('comic', {
          'version': 'v1',
          'favorites': [raw],
        });
      expect(await downloadComicData(remote, codec: _codec), isTrue);
      expect(objectbox.unifiedFavoriteBox.getAll().single.metadata, metadata);
      expect(remote.uploads, 0);
      expect(remote.deletions, 0);
    },
  );

  test(
    'orphaned newer comic candidates cannot evict the active MD5 snapshot',
    () async {
      objectbox.unifiedFavoriteBox.put(createTestFavorite('source:kept'));
      final bytes = await ComicSyncCore.buildCompressedPayload(codec: _codec);
      final remote = CompatibilityRemote();
      final active = remote.path('comic_1.bin');
      remote.files[active] = bytes;
      remote.files[remote.path('comic.md5')] = utf8.encode(
        ComicSyncCore.calculateMd5(bytes),
      );
      for (var i = 2; i <= 5; i++) {
        remote.files[remote.path('comic_$i.bin')] = [i];
      }
      await runComicSync(remote, codec: _codec);
      expect(remote.files[active], bytes);
      expect(
        await remote.downloadRemoteMd5(),
        ComicSyncCore.calculateMd5(bytes),
      );
      expect(remote.uploads, 0);
    },
  );
  test(
    'current shipped schema2 local records roundtrip through public upload and download',
    () async {
      objectbox.unifiedFavoriteBox.removeAll();
      objectbox.unifiedHistoryBox.removeAll();
      objectbox.comicReadPreferenceBox.removeAll();
      const metadata =
          '[{"type":"future-plugin-field","value":{"opaque":[1,2]}}]';
      objectbox.unifiedFavoriteBox.put(
        createTestFavorite('shipped:local-favorite')
          ..schemaVersion = 2
          ..metadata = metadata,
      );
      objectbox.unifiedHistoryBox.put(
        createTestHistory('shipped:local-history')
          ..schemaVersion = 2
          ..metadata = metadata,
      );
      final remote = CompatibilityRemote();
      await uploadComicData(remote, codec: _codec);
      final before = remote.files.map(
        (key, value) => MapEntry(key, base64Encode(value)),
      );
      final writes = remote.uploads;
      objectbox.unifiedFavoriteBox.removeAll();
      objectbox.unifiedHistoryBox.removeAll();
      expect(await downloadComicData(remote, codec: _codec), isTrue);
      expect(objectbox.unifiedFavoriteBox.getAll().single.schemaVersion, 2);
      expect(objectbox.unifiedHistoryBox.getAll().single.schemaVersion, 2);
      expect(objectbox.unifiedFavoriteBox.getAll().single.metadata, metadata);
      expect(objectbox.unifiedHistoryBox.getAll().single.metadata, metadata);
      expect(
        remote.files.map((key, value) => MapEntry(key, base64Encode(value))),
        before,
      );
      expect(remote.uploads, writes);
      expect(remote.deletions, 0);
    },
  );
}
