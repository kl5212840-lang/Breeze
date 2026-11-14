import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/s3_sync_service.dart';
import 'package:zephyr/network/sync/webdav_sync_service.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_cloud_purge.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

import '../../test_helper.dart';

const source = '99999999-1111-4222-8333-444444444444';
const other = '88888888-1111-4222-8333-444444444444';
Future<List<int>> identity(List<int> value) async => value;
const comicCodec = ComicSyncCodec(encode: identity, decode: identity);
const settingsCodec = SettingsSyncCodec(encode: identity, decode: identity);
const videoCodec = VideoLibrarySyncCodec(encode: identity, decode: identity);

class Remote implements ComicSyncRemoteAdapter, LegacyPluginPurgeTransport {
  Remote({this.legacy = false});
  final bool legacy;
  String get root => legacy ? SyncArchiveContext.legacyRoot : ComicSyncCore.syncRemoteRootName;
  final files = <String, List<int>>{};
  int writes = 0;
  int? failAt;
  String path(String name) => name.contains('/') ? name : '$root/$name';
  void seed(String name, Object value) => files[path(name)] = utf8.encode(jsonEncode(value));
  void commit(String kind) => files[path('$kind.md5')] = utf8.encode(ComicSyncCore.calculateMd5(files[path('${kind}_1.bin')]!));
  @override Future<void> testConnection() async {}
  @override Future<void> ensureRemoteReady() async {}
  @override Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override Future<List<int>> downloadRemoteFile(String name) async => files[path(name)] ?? (throw StateError('404'));
  @override Future<String> downloadRemoteMd5() async => utf8.decode(files[path('comic.md5')] ?? []);
  @override Future<void> uploadRemoteMd5(String value) async => uploadRemoteFile('comic.md5', utf8.encode(value));
  @override Future<void> uploadRemoteFile(String name, List<int> bytes, {String contentType = 'application/octet-stream'}) async {
    if (legacy) throw const LegacyArchiveReadOnly();
    await _write(name, bytes);
  }
  Future<void> _write(String name, List<int> bytes) async {
    writes++;
    if (writes == failAt) throw StateError('offline');
    files[path(name)] = List.of(bytes);
  }
  @override Future<void> rewriteLegacySnapshotForPluginPurge(String physicalPath, List<int> data) async {
    validateLegacyPluginPurgePath(legacy ? SyncArchiveContext.legacyReadOnly : SyncArchiveContext.current, physicalPath);
    await _write(physicalPath, data);
  }
  @override Future<void> deleteRemoteFiles(List<String> paths) async {
    if (legacy) throw const LegacyArchiveReadOnly();
    for (final p in paths) {
      if (!appearanceManifestName.hasMatch(p.split('/').last) && !appearanceResourceName.hasMatch(p.split('/').last)) throw StateError('Do not delete shared snapshots');
      files.remove(path(p));
    }
  }
}

Future<void> purge(Remote remote) => purgeCloudPluginAccountData(remote, source, comicCodec: comicCodec, settingsCodec: settingsCodec, videoCodec: videoCodec);
Map<String, dynamic> comics() => {
  'version': 'v1',
  'favorites': [
    (createTestFavorite('$source:a')..source = source).toJson()..remove('id'),
    (createTestFavorite('$other:b')..source = other).toJson()..remove('id'),
  ],
  'histories': [], 'follows': [], 'readPreferences': [], 'folders': [], 'links': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
  });
  test('explicit purge removes source chapters from each device snapshot', () async {
    final remote = Remote();
    const own = (source, 'work', 'one');
    const retained = (other, 'work', 'one');
    final archive = ChapterProgressArchive({
      own: (at: 10, progress: (pageIndex: 5, pageCount: 5, completed: true)),
      retained: (at: 11, progress: (pageIndex: 2, pageCount: 5, completed: false)),
    });
    for (final suffix in ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb']) {
      remote.files[remote.path('chapter_progress_v1_$suffix.bin')] = archive.encode();
    }
    await purge(remote);
    for (final bytes in remote.files.values) {
      expect(ChapterProgressArchive.decode(bytes).rows, {retained: archive.rows[retained]});
    }
  });
  test('all comic versions are cleaned immediately while other source is exact', () async {
    final original = comics();
    final remote = Remote()..seed('comic_1.bin', original)..commit('comic');
    remote.seed('comic_2.bin', original);
    final otherRow = (original['favorites'] as List).last;
    await purge(remote);
    for (final path in remote.files.keys.where((p) => p.endsWith('.bin'))) {
      final data = jsonDecode(utf8.decode(remote.files[path]!)) as Map;
      expect(data['favorites'], [otherRow]);
    }
    final writes = remote.writes;
    await purge(remote);
    expect(remote.writes, writes, reason: 'already purged is idempotent');
  });
  test('settings drop package/config aliases but preserve global and other config', () {
    final input = {
      'version': 'v1', 'schemaVersion': 'v2', 'globalSetting': {'dynamicColor': true},
      'pluginInfos': [{'uuid': source}, {'uuid': other}],
      'pluginConfigs': [{'name': source, 'config': 'secret'}, {'name': other, 'config': 'unchanged'}],
      'blocks': {'plugins': {'updatedAt': 100, 'data': {
        'pluginInfos': [{'uuid': source}, {'uuid': other}],
        'pluginConfigs': [{'name': source, 'config': 'secret'}, {'name': other, 'config': 'unchanged'}],
      }}},
    };
    final result = removePluginFromCloudPayload('settings', input, source);
    expect(result['globalSetting'], input['globalSetting']);
    expect(result['pluginInfos'], [{'uuid': other}]);
    expect((result['blocks'] as Map)['plugins']['data']['pluginConfigs'], [{'name': other, 'config': 'unchanged'}]);
    expect((input['pluginInfos'] as List).length, 2);
  });
  test('video all device files remove source and keep other favorites', () async {
    final store = VideoLibraryStore(deviceId: 'fixture', storageKey: 'cloud-purge');
    addTearDown(store.dispose);
    final item = ApiVideoItem(id: 'one', title: 'Fixture', detailUrl: Uri.https('example.invalid', '/one'));
    await store.setFavorite(source, item, true);
    await store.setFavorite(other, item, true);
    final raw = (await store.read()).toJson();
    final remote = Remote();
    for (final id in ['a', 'b']) {
      remote.seed('video_library_${List.filled(32, id).join()}.bin', {
        'format': 'BreezeVideoLibrary', 'version': 1, 'snapshot': raw,
        'sha256': sha256.convert(utf8.encode(jsonEncode(raw))).toString(),
      });
    }
    await purge(remote);
    final result = await VideoLibrarySync.readArchive(remote, codec: videoCodec);
    expect(result.snapshot.contains(source, 'one'), isFalse);
    expect(result.snapshot.contains(other, 'one'), isTrue);
  });
  test('settings active and historical copies are actually rewritten, not deferred', () async {
    final data = {
      'version': 'v1', 'schemaVersion': 'v2', 'syncTime': 100,
      'pluginInfos': [], 'pluginConfigs': [
        {'name': source, 'config': '{"account":"fixture"}'},
        {'name': other, 'config': '{"keep":true}'},
      ],
      'blocks': {'plugins': {'updatedAt': 100, 'data': {
        'pluginInfos': [], 'pluginConfigs': [
          {'name': source, 'config': '{"account":"fixture"}'},
          {'name': other, 'config': '{"keep":true}'},
        ],
      }}},
    };
    final remote = Remote()..seed('settings_1.bin', data)..commit('settings');
    remote.seed('settings_2.bin', data);
    await purge(remote);
    final active = await readSettingsArchiveData(remote, codec: settingsCodec);
    expect(active!.pluginConfigsForSource(source), isEmpty);
    expect(active.pluginConfigsForSource(other).single.config, '{"keep":true}');
    for (final path in remote.files.keys.where((p) => p.endsWith('.bin'))) {
      final payload = jsonDecode(utf8.decode(remote.files[path]!)) as Map;
      expect(payload['pluginConfigs'], [{'name': other, 'config': '{"keep":true}'}]);
    }
  });
  test('future historical candidate blocks every write', () async {
    final remote = Remote()..seed('comic_1.bin', comics())..commit('comic');
    remote.seed('comic_2.bin', {...comics(), 'version': 'v99'});
    await expectLater(purge(remote), throwsA(isA<CloudPluginPurgeFailure>().having((e) => e.cause, 'cause', isA<SyncCompatibilityException>()).having((e) => e.mayHaveChanged, 'changed', false)));
    expect(remote.writes, 0);
  });
  test('failure after head commit reports partial cloud and retry finishes', () async {
    final remote = Remote()..seed('comic_1.bin', comics())..commit('comic')..failAt = 3;
    await expectLater(purge(remote), throwsA(isA<CloudPluginPurgeFailure>().having((e) => e.mayHaveChanged, 'changed', true)));
    expect(await readComicArchiveData(remote, codec: comicCodec), isNotNull);
    remote.failAt = null;
    await purge(remote);
    for (final path in remote.files.keys.where((p) => p.endsWith('.bin'))) {
      expect((jsonDecode(utf8.decode(remote.files[path]!))['favorites'] as List).length, 1);
    }
  });
  ScopedSyncArchiveAdapter archives(Remote current, Remote legacy) => ScopedSyncArchiveAdapter(
    current, SyncArchiveContext.current,
    legacyReader: ScopedSyncArchiveAdapter(legacy, SyncArchiveContext.legacyReadOnly),
  );
  Future<void> purgeBoth(Remote current, Remote legacy) => purgeCloudPluginAccountData(
    archives(current, legacy), source, comicCodec: comicCodec,
    settingsCodec: settingsCodec, videoCodec: videoCodec,
  );
  void expectPurged(Remote remote) {
    for (final path in remote.files.keys.where((p) => p.split('/').last.startsWith('comic_'))) {
      final payload = jsonDecode(utf8.decode(remote.files[path]!)) as Map;
      expect((payload['favorites'] as List).map((row) => row['source']), [other]);
    }
  }
  test('explicit purge cleans both archives; ordinary legacy writes remain read-only', () async {
    final current = Remote()..seed('comic_1.bin', comics())..commit('comic');
    final legacy = Remote(legacy: true)..seed('comic_1.bin', comics())..commit('comic');
    legacy.seed('comic_2.bin', comics());
    final scoped = archives(current, legacy);
    await expectLater(Future<void>.sync(() => scoped.legacyReader!.uploadRemoteFile('comic_1.bin', [])), throwsA(isA<LegacyArchiveReadOnly>()));
    await expectLater(Future<void>.sync(() => scoped.legacyReader!.uploadRemoteMd5('x')), throwsA(isA<LegacyArchiveReadOnly>()));
    await expectLater(Future<void>.sync(() => scoped.legacyReader!.deleteRemoteFiles(['comic_1.bin'])), throwsA(isA<LegacyArchiveReadOnly>()));
    await purgeBoth(current, legacy);
    expectPurged(current); expectPurged(legacy);
    expect(current.writes, greaterThan(0)); expect(legacy.writes, greaterThan(0));
    final count = current.writes + legacy.writes;
    await purgeBoth(current, legacy);
    expect(current.writes + legacy.writes, count);
    await expectLater(Future<void>.sync(() => legacy.uploadRemoteFile('comic_1.bin', [])), throwsA(isA<LegacyArchiveReadOnly>()));
  });
  test('a future legacy historical candidate blocks writes to BOTH archives', () async {
    final current = Remote()..seed('comic_1.bin', comics())..commit('comic');
    final legacy = Remote(legacy: true)..seed('comic_1.bin', comics())..commit('comic');
    legacy.seed('comic_2.bin', {...comics(), 'version': 'v99'});
    await expectLater(purgeBoth(current, legacy), throwsA(isA<CloudPluginPurgeFailure>()
      .having((e) => e.cause, 'cause', isA<SyncCompatibilityException>())
      .having((e) => e.mayHaveChanged, 'changed', false)));
    expect(current.writes, 0); expect(legacy.writes, 0);
  });
  test('legacy write failure reports current completion and is retryable', () async {
    final current = Remote()..seed('comic_1.bin', comics())..commit('comic');
    final legacy = Remote(legacy: true)..seed('comic_1.bin', comics())..commit('comic')..failAt = 1;
    await expectLater(purgeBoth(current, legacy), throwsA(isA<CloudPluginPurgeFailure>()
      .having((e) => e.currentArchiveCompleted, 'current complete', true)
      .having((e) => e.legacyArchiveCompleted, 'legacy complete', false)
      .having((e) => e.mayHaveChanged, 'changed', true)));
    expectPurged(current);
    expect((jsonDecode(utf8.decode(legacy.files[legacy.path('comic_1.bin')]!))['favorites'] as List).length, 2);
    legacy.failAt = null;
    await purgeBoth(current, legacy);
    expectPurged(current); expectPurged(legacy);
  });
  test('legacy rewrite rejects traversal, other roots and unknown file families', () async {
    final legacy = Remote(legacy: true);
    final scoped = ScopedSyncArchiveAdapter(legacy, SyncArchiveContext.legacyReadOnly);
    for (final path in ['../comic_1.bin', '${SyncArchiveContext.legacyRoot}/comic_1.bin',
      'comic_1.bin/child', 'unknown.bin', 'settings_1.bin/../../comic_1.bin']) {
      await expectLater(Future<void>.sync(() => scoped.rewriteLegacySnapshotForPluginPurge(path, [])), throwsStateError);
    }
    expect(legacy.writes, 0);
  });
  test('plugin image purge strips all refs, removes owned blobs and preserves shared content', () async {
    final shared=[1,2,3], unique=[4,5,6];
    final sharedDigest=sha256.convert(shared).toString(), uniqueDigest=sha256.convert(unique).toString();
    final manifest=AppearanceSyncManifest({
      'plugin-icon:$source':LocalAppearanceSyncRecord(key:'plugin-icon:$source',digest:uniqueDigest,size:3,modifiedAt:2,deleted:false),
      'profile:$source':LocalAppearanceSyncRecord(key:'profile:$source',digest:sharedDigest,size:3,modifiedAt:2,deleted:false),
      'profile:$other':LocalAppearanceSyncRecord(key:'profile:$other',digest:sharedDigest,size:3,modifiedAt:2,deleted:false),
    });
    final bytes=utf8.encode(jsonEncode(manifest.toJson()));final remote=Remote();
    remote.files[remote.path('appearance_${List.filled(32,'c').join()}_${sha256.convert(bytes)}.bin')]=bytes;
    remote.files[remote.path('appearance_resource_$sharedDigest.bin')]=shared;
    remote.files[remote.path('appearance_resource_$uniqueDigest.bin')]=unique;
    await purge(remote);
    final refs=remote.files.entries.where((e)=>appearanceManifestName.hasMatch(e.key.split('/').last));
    expect(refs,hasLength(1));
    expect(AppearanceSyncManifest.fromBytes(refs.single.value).records.keys,['profile:$other']);
    expect(remote.files[remote.path('appearance_resource_$sharedDigest.bin')],shared);
    expect(remote.files.containsKey(remote.path('appearance_resource_$uniqueDigest.bin')),isFalse);
  });

  test('concrete transports reject ordinary legacy writes and invalid explicit paths before I/O', () async {
    const state = GlobalSettingState(syncSetting: SyncSettingState(
      webdavSetting: WebDavSettingState(host: 'https://example.invalid', username: 'fixture', password: 'fixture'),
      s3Setting: S3SettingState(endpoint: 'example.invalid', bucket: 'fixture', accessKey: 'fixture', secretKey: 'fixture'),
    ));
    final transports = <ComicSyncRemoteAdapter>[
      S3SyncService(state, archive: SyncArchiveContext.legacyReadOnly),
      WebDavSyncService(state, archive: SyncArchiveContext.legacyReadOnly),
    ];
    for (final transport in transports) {
      await expectLater(Future<void>.sync(() => transport.uploadRemoteFile('comic_1.bin', [])), throwsA(isA<LegacyArchiveReadOnly>()));
      await expectLater(Future<void>.sync(() => transport.uploadRemoteMd5('x')), throwsA(isA<LegacyArchiveReadOnly>()));
      await expectLater(Future<void>.sync(() => transport.deleteRemoteFiles(['comic_1.bin'])), throwsA(isA<LegacyArchiveReadOnly>()));
      final purge = transport as LegacyPluginPurgeTransport;
      for (final path in ['comic_1.bin', '${SyncArchiveContext.currentRoot}/comic_1.bin',
        '${SyncArchiveContext.legacyRoot}/../comic_1.bin', '${SyncArchiveContext.legacyRoot}/comic_1.bin/extra',
        '${SyncArchiveContext.legacyRoot}/unknown.bin', '${SyncArchiveContext.legacyRoot}/comic_1.bin?x']) {
        await expectLater(Future<void>.sync(() => purge.rewriteLegacySnapshotForPluginPurge(path, [])), throwsStateError);
      }
    }
  });
}
