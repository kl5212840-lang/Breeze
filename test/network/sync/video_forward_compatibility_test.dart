import '../../test_helper.dart';
import 'sync_installed_fixture.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';

import 'sync_compatibility_guard_test.dart'
    show CompatibilityRemote, compatibilityIdentity;

const _codec = VideoLibrarySyncCodec(
  encode: compatibilityIdentity,
  decode: compatibilityIdentity,
);
String _digest(Object? data) =>
    sha256.convert(utf8.encode(jsonEncode(data))).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins(['future-plugin']);
  });
  final item = ApiVideoItem(
    id: 'fixture',
    title: 'Saved',
    detailUrl: Uri.https('example.test', '/vod/fixture'),
  );

  for (final change in [
    'version',
    'collection',
    'revision',
    'metadata',
    'portable',
  ]) {
    test(
      'video public sync rejects future $change before merging or uploading',
      () async {
        final store = VideoLibraryStore(
          deviceId: 'fixture-device',
          storageKey: 'fixture.library',
        );
        await store.setFavorite('future-plugin', item, true);
        final before = (await store.read()).toJson();
        final raw = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
        if (change == 'version') raw['version'] = 99;
        if (change == 'collection') raw['future-collection'] = {};
        final favorite = (raw['favorites'] as Map).values.single as Map;
        if (change == 'revision') favorite['future-clock'] = 1;
        if (change == 'metadata') {
          ((favorite['data'] as Map)['item'] as Map)['future-metadata'] =
              'opaque';
        }
        final envelope = <String, dynamic>{
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'snapshot': raw,
          'sha256': _digest(raw),
        };
        if (change == 'portable') {
          final portable = {'version': 99, 'entries': {}};
          envelope['portable'] = portable;
          envelope['portableSha256'] = _digest(portable);
        }
        final remote = CompatibilityRemote();
        remote.files[remote.path(
          'video_library_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bin',
        )] = utf8.encode(
          jsonEncode(envelope),
        );
        await expectLater(
          VideoLibrarySync.run(remote, store: store, codec: _codec),
          throwsA(
            change == 'portable'
                ? isA<FormatException>()
                : isA<SyncCompatibilityException>(),
          ),
        );
        expect((await store.read()).toJson(), before);
        expect(remote.uploads, 0);
        expect(remote.deletions, 0);
      },
    );
  }

  test(
    'known legacy device file without portable preserves current local preferences',
    () async {
      final store = VideoLibraryStore(
        deviceId: 'fixture-device',
        storageKey: 'fixture.legacy',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('breeze.video.library.view.future-plugin', 'list');
      final snapshot = VideoLibrarySnapshot().toJson();
      final remote = CompatibilityRemote();
      remote.files[remote.path(
        'video_library_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.bin',
      )] = utf8.encode(
        jsonEncode({
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'snapshot': snapshot,
          'sha256': _digest(snapshot),
        }),
      );
      await VideoLibrarySync.run(
        remote,
        store: store,
        codec: _codec,
        upload: false,
      );
      expect(
        prefs.getString('breeze.video.library.view.future-plugin'),
        'list',
      );
      expect(remote.uploads, 0);
      expect(remote.deletions, 0);
      expect((await PortablePreferences.capture()).entries, isNotEmpty);
    },
  );
}
