import 'sync_installed_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_record_data_clear.dart';

import '../../test_helper.dart';

const source = '99999999-1111-4222-8333-444444444444';
const other = '88888888-1111-4222-8333-444444444444';
Future<List<int>> identity(List<int> bytes) async => bytes;
const videoCodec = VideoLibrarySyncCodec(encode: identity, decode: identity);
Map<String, dynamic> comics(List<Map<String, dynamic>> favorites) => {
  'version': 'v1',
  'favorites': favorites,
  'histories': [],
  'follows': [],
  'readPreferences': [],
  'folders': [],
  'links': [],
};
ApiVideoItem film(String id) => ApiVideoItem(
  id: id,
  title: 'synthetic $id',
  detailUrl: Uri.parse('https://fixture.invalid/voddetail/$id.html'),
);

class Remote extends ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String path) async => files[path]!;
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    files[path] = List.of(data);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    throw StateError('Never delete other device snapshots');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.comicReadPreferenceBox.removeAll();
    objectbox.downloadTaskBox.removeAll();
    await installSyncPlugins([source, other]);
  });
  Future<int> mask() => LocalPluginInstallationState.instance.setDataExclusions(
    source,
    {PluginDataScope.records},
    beforeWrite: (_) async {},
  );

  test(
    'comic mask filters only local application and keeps complete merged cloud projection',
    () async {
      final fresh = createTestFavorite('$source:local')..source = source;
      objectbox.unifiedFavoriteBox.put(fresh);
      final remoteOwned = createTestFavorite('$source:remote')..source = source;
      final remoteOther = createTestFavorite('$other:remote')..source = other;
      await mask();
      final projection = <String, dynamic>{};
      objectbox.store.runInTransaction<void>(TxMode.write, () {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          comics([remoteOwned.toJson(), remoteOther.toJson()]),
          cloudProjection: projection,
        );
      });
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((row) => row.uniqueKey),
        unorderedEquals([fresh.uniqueKey, remoteOther.uniqueKey]),
      );
      expect(
        (projection['favorites'] as List).map((row) => row['uniqueKey']),
        unorderedEquals([
          fresh.uniqueKey,
          remoteOwned.uniqueKey,
          remoteOther.uniqueKey,
        ]),
      );
    },
  );

  test(
    'removed plugin is not refilled and upload retains its remote favorites',
    () async {
      final a = VideoLibraryStore(
        deviceId: 'A',
        storageKey: 'fixture.library.a',
      );
      final b = VideoLibraryStore(
        deviceId: 'B',
        storageKey: 'fixture.library.b',
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final remote = Remote();
      await a.setFavorite(source, film('7'), true);
      await a.setFavorite(other, film('8'), true);
      await VideoLibrarySync.run(remote, store: a, codec: videoCodec);
      await mask();
      await LocalPluginInstallationState.instance.markRemoved(source);
      await VideoLibrarySync.run(remote, store: b, codec: videoCodec);
      expect((await b.read()).contains(source, '7'), isFalse);
      expect((await b.read()).contains(other, '8'), isTrue);
      final full = await VideoLibrarySync.readArchive(
        remote,
        codec: videoCodec,
      );
      expect(full.snapshot.contains(source, '7'), isTrue);
      expect(full.snapshot.contains(other, '8'), isTrue);
      await LocalPluginInstallationState.instance.completeExplicitInstallation(
        source,
      );
      expect(
        LocalPluginInstallationState.instance.isDataExcluded(
          source,
          PluginDataScope.records,
        ),
        isTrue,
      );
      await VideoLibrarySync.run(
        remote,
        store: b,
        codec: videoCodec,
        upload: false,
      );
      expect((await b.read()).contains(source, '7'), isTrue);
    },
  );

  test(
    'scoped record clear preserves download entrypoints unless downloads are selected',
    () async {
      final favorite = createTestFavorite('$source:1')..source = source;
      final download = createTestDownload('$source:1')..source = source;
      objectbox.unifiedFavoriteBox.put(favorite);
      objectbox.unifiedDownloadBox.put(download);
      final epoch = await mask();
      final store = VideoLibraryStore(
        deviceId: 'local',
        storageKey: 'fixture.records',
      );
      addTearDown(store.dispose);
      await store.setFavorite(source, film('7'), true);
      final plan = await preparePluginRecordDataClear(
        source,
        cloudDelete: false,
        expectedEpoch: epoch,
        store: store,
      );
      await plan.applyPreferences(beforeWrite: (_) async {});
      objectbox.store.runInTransaction<void>(
        TxMode.write,
        plan.persistDatabase,
      );
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
      expect(objectbox.unifiedDownloadBox.getAll().single.id, download.id);
      expect((await store.read()).contains(source, '7'), isFalse);
    },
  );

  test(
    'explicit cloud record clear writes current tombstones including remote-only rows',
    () async {
      final remoteFavorite = createTestFavorite('$source:remote')
        ..source = source;
      final store = VideoLibraryStore(
        deviceId: 'local',
        storageKey: 'fixture.records',
      );
      final remoteStore = VideoLibraryStore(
        deviceId: 'remote',
        storageKey: 'fixture.remote',
      );
      addTearDown(store.dispose);
      addTearDown(remoteStore.dispose);
      await remoteStore.setFavorite(source, film('9'), true);
      final epoch = await mask();
      final plan = await preparePluginRecordDataClear(
        source,
        cloudDelete: true,
        expectedEpoch: epoch,
        store: store,
        knownCloudComics: comics([remoteFavorite.toJson()]),
        knownCloudVideo: await remoteStore.read(),
      );
      await plan.applyPreferences(beforeWrite: (_) async {});
      objectbox.store.runInTransaction<void>(
        TxMode.write,
        plan.persistDatabase,
      );
      expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isTrue);
      expect(
        (await store.read())
            .favorites[VideoLibraryStore.itemKey(source, '9')]!
            .deleted,
        isTrue,
      );
      await LocalPluginInstallationState.instance.completeExplicitInstallation(
        source,
      );
      expect(
        objectbox.unifiedFavoriteBox.getAll().single.deleted,
        isTrue,
        reason:
            'reinstall changes installation state, not explicit personal deletion',
      );
      expect(
        (await store.read())
            .favorites[VideoLibraryStore.itemKey(source, '9')]!
            .deleted,
        isTrue,
      );
      expect(
        objectbox.pluginInfoBox.getAll().any((row) => row.isDeleted),
        isFalse,
      );
    },
  );

  test(
    'local removal during video encoding blocks stale publication',
    () async {
      final store = VideoLibraryStore(
        deviceId: 'local',
        storageKey: 'fixture.guarded',
      );
      addTearDown(store.dispose);
      await store.setFavorite(source, film('7'), true);
      final remote = Remote();
      final guarded = VideoLibrarySyncCodec(
        decode: identity,
        encode: (bytes) async {
          await LocalPluginInstallationState.instance.markRemoved(source);
          return bytes;
        },
      );
      await expectLater(
        VideoLibrarySync.run(remote, store: store, codec: guarded),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(remote.files, isEmpty);
    },
  );
}
