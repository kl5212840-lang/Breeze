import '../../test_helper.dart';
import 'sync_installed_fixture.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_library_store.dart';

import 'sync_compatibility_guard_test.dart'
    show CompatibilityRemote, compatibilityIdentity;

String _hash(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
const _codec = VideoLibrarySyncCodec(
  encode: compatibilityIdentity,
  decode: compatibilityIdentity,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins(['synthetic']);
  });
  Future<PortablePreferencesSnapshot> externalAck() async {
    await VideoExportRecords.add(
      source: 'synthetic',
      video: Uri.parse('https://video.example/watch?v=1'),
      title: 'Public export',
      quality: '',
      cover: 'https://image.example/poster.jpg',
    );
    return PortablePreferences.capture();
  }

  test(
    'real external export acknowledgment restores with a public image transform and no resource availability claim',
    () async {
      final raw = (await externalAck()).toJson();
      final row =
          ((raw['entries'] as Map).values.singleWhere(
                    (e) => (e as Map)['kind'] == 'export',
                  )
                  as Map)['value']
              as Map;
      row['cover'] = 'https://image.example/poster.jpg?w=200&format=webp';
      final snapshot = PortablePreferencesSnapshot.fromJson(raw);
      expect(row.keys.toSet(), {
        'key',
        'source',
        'url',
        'title',
        'quality',
        'cover',
        'at',
      });
      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(snapshot);
      final restored = (await VideoExportRecords.read()).single;
      expect(restored, row);
      expect(restored.keys, isNot(contains('resourceId')));
      expect(restored.keys, isNot(contains('available')));
      expect(
        PortablePreferences.owns(VideoExportRecords.taskStorageKey),
        isFalse,
      );
    },
  );

  test(
    'capture excludes polluted transfer rows and the independent local task store',
    () async {
      await externalAck();
      final prefs = await SharedPreferences.getInstance();
      final valid =
          (jsonDecode(prefs.getString(VideoExportRecords.storageKey)!) as List)
                  .single
              as Map;
      final transfer = {
        ...valid,
        'kind': 'transfer',
        'resourceId': 'LOCAL_ID_MARKER',
        'fileURL': 'file:///LOCAL_PATH_MARKER.mp4',
        'status': 'saved',
      };
      await prefs.setString(
        VideoExportRecords.storageKey,
        jsonEncode([valid, transfer]),
      );
      await prefs.setString(
        VideoExportRecords.taskStorageKey,
        jsonEncode([transfer]),
      );
      final captured = await PortablePreferences.capture();
      expect(
        captured.entries.values.where(
          (e) => e['kind'] == 'export' && e['deleted'] != true,
        ),
        hasLength(1),
      );
      expect(jsonEncode(captured.toJson()), isNot(contains('LOCAL_ID_MARKER')));
      expect(
        jsonEncode(captured.toJson()),
        isNot(contains('LOCAL_PATH_MARKER')),
      );
      expect(
        prefs.getString(VideoExportRecords.taskStorageKey),
        contains('LOCAL_ID_MARKER'),
      );
    },
  );

  for (final field in [
    'kind',
    'resourceId',
    'fileRemoved',
    'fileURL',
    'status',
    'headers',
  ]) {
    test(
      'restore rejects export $field before modifying local preferences',
      () async {
        final snapshot = await externalAck();
        final raw =
            jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
        final entry =
            (raw['entries'] as Map).values.singleWhere(
                  (e) => (e as Map)['kind'] == 'export',
                )
                as Map;
        (entry['value'] as Map)[field] = field == 'fileRemoved'
            ? false
            : 'LOCAL_ONLY_MARKER';
        final prefs = await SharedPreferences.getInstance();
        final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
        await expectLater(
          PortablePreferences.restore(
            PortablePreferencesSnapshot(
              (raw['entries'] as Map).map(
                (key, value) => MapEntry(
                  key as String,
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            ),
          ),
          throwsFormatException,
        );
        expect({
          for (final key in prefs.getKeys()) key: prefs.get(key),
        }, before);
      },
    );
  }

  test(
    'public video sync rejects a polluted export envelope before library merge or upload',
    () async {
      final snapshot = await externalAck();
      final portable =
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
      final entry =
          (portable['entries'] as Map).values.singleWhere(
                (e) => (e as Map)['kind'] == 'export',
              )
              as Map;
      (entry['value'] as Map)['resourceId'] = 'LOCAL_ONLY_MARKER';
      final library = VideoLibrarySnapshot().toJson();
      final remote = CompatibilityRemote();
      remote.files[remote.path(
        'video_library_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bin',
      )] = utf8.encode(
        jsonEncode({
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'snapshot': library,
          'sha256': _hash(library),
          'portable': portable,
          'portableSha256': _hash(portable),
        }),
      );
      final store = VideoLibraryStore(
        deviceId: 'synthetic',
        storageKey: 'boundary.library',
      );
      await store.setFavorite(
        'synthetic',
        ApiVideoItem(
          id: 'local',
          title: 'Local',
          detailUrl: Uri.parse('https://video.example/watch?v=2'),
        ),
        true,
      );
      final before = (await store.read()).toJson();
      await expectLater(
        VideoLibrarySync.run(remote, store: store, codec: _codec),
        throwsFormatException,
      );
      expect((await store.read()).toJson(), before);
      expect(remote.uploads, 0);
      expect(remote.deletions, 0);
    },
  );

  for (final cover in [
    'file:///local/poster.jpg',
    'https://image.example/poster.jpg?token=PRIVATE_MARKER',
  ]) {
    test('capture does not export a local or signed cover reference', () async {
      await VideoExportRecords.add(
        source: 'synthetic',
        video: Uri.parse('https://video.example/watch?v=1'),
        title: 'Public export',
        quality: 'HD',
      );
      final prefs = await SharedPreferences.getInstance();
      final rows =
          jsonDecode(prefs.getString(VideoExportRecords.storageKey)!) as List;
      (rows.single as Map)['cover'] = cover;
      await prefs.setString(VideoExportRecords.storageKey, jsonEncode(rows));
      final captured = await PortablePreferences.capture();
      expect(
        captured.entries.values.where(
          (e) => e['kind'] == 'export' && e['deleted'] != true,
        ),
        isEmpty,
      );
      expect(jsonEncode(captured.toJson()), isNot(contains(cover)));
    });
  }
}
