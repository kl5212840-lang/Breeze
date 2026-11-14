import '../../test_helper.dart';
import 'sync_installed_fixture.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';

class _Remote implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  bool reject = false;
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
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    if (reject) throw StateError('offline');
    files[path] = List.of(bytes);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    throw StateError('Must not delete cloud data');
  }
}

Future<List<int>> identity(List<int> bytes) async => bytes;
const codec = VideoLibrarySyncCodec(encode: identity, decode: identity);
ApiVideoItem film(String id) => ApiVideoItem(
  id: id,
  title: '作品$id',
  detailUrl: Uri.parse('https://www.ikunzy.com/voddetail/$id.html'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late VideoLibraryStore a, b;
  late _Remote remote;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins(['ikun']);
    a = VideoLibraryStore(deviceId: 'device-A', storageKey: 'sync.A');
    b = VideoLibraryStore(deviceId: 'device-B', storageKey: 'sync.B');
    remote = _Remote();
  });
  tearDown(() {
    a.dispose();
    b.dispose();
  });
  test(
    'the library command waits for a local backup and reads settings at execution',
    () async {
      await a.setFavorite('ikun', film('7'), true);
      final started = Completer<void>(), release = Completer<void>();
      final backup = runExclusiveStorageOperation(() async {
        started.complete();
        await release.future;
      });
      await started.future;
      var settings = const GlobalSettingState(dynamicColor: false);
      GlobalSettingState? adapterSettings;
      final sync = syncVideoLibrary(
        readState: () => settings,
        store: a,
        codec: codec,
        createAdapter: (state) {
          adapterSettings = state;
          return remote;
        },
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(adapterSettings, isNull);
        expect(remote.files, isEmpty);
        settings = settings.copyWith(dynamicColor: true);
      } finally {
        release.complete();
        await backup;
      }
      expect(await sync, isTrue);
      expect(adapterSettings?.dynamicColor, isTrue);
      expect(remote.files.keys.single, contains('video_library_'));
    },
  );
  test(
    'portable video metadata keeps CMS click and rating evidence without local artists',
    () async {
      final item = ApiVideoItem.fromJson({
        'id': '77',
        'title': 'CMS work',
        'detailUrl': 'https://www.ikunzy.com/voddetail/77.html',
        'sourceViews': 0,
        'sourceViewsKind': 'clicks',
        'sourceRating': 8.5,
        'sourceRatingCount': 2,
        'sourceRatingCountConsistent': false,
      }, home: Uri.parse('https://www.ikunzy.com/'));
      await a.setFavorite('ikun', item, true);
      const localDownloadKey = 'breeze.local.video.download-details.v2';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(localDownloadKey, 'offline artist marker');
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      final cloud = utf8.decode(remote.files.values.single);
      expect(cloud, isNot(contains('offline artist marker')));
      expect(cloud, isNot(contains(localDownloadKey)));
      await VideoLibrarySync.run(remote, store: b, codec: codec, upload: false);
      final snapshot = await b.read();
      final stored = snapshot.favorites[VideoLibraryStore.itemKey('ikun', '77')]!
          .data['item'] as Map;
      expect(stored, containsPair('sourceViews', 0));
      expect(stored, containsPair('sourceViewsKind', 'clicks'));
      expect(stored, containsPair('sourceRating', 8.5));
      expect(stored, containsPair('sourceRatingCount', 2));
      expect(stored, containsPair('sourceRatingCountConsistent', false));
      expect(prefs.getString(localDownloadKey), 'offline artist marker');
    },
  );

  test(
    'existing adapter transfers favorites, folder IDs and memberships',
    () async {
      final folder = await a.createFolder('ikun', '剧情');
      await a.setFavorite('ikun', film('7'), true, folderIds: {folder});
      remote.files['${ComicSyncCore.syncRemoteRootName}/comic_1.bin'] = [
        1,
        2,
        3,
      ];
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      await VideoLibrarySync.run(remote, store: b, codec: codec, upload: false);
      final result = await b.read();
      expect(result.contains('ikun', '7'), isTrue);
      expect(result.foldersOf(VideoLibraryStore.itemKey('ikun', '7')), {
        folder,
      });
      expect(remote.files.values.where((x) => x.length == 3), hasLength(1));
      expect(
        remote.files.keys.where((x) => x.contains('video_library')),
        hasLength(1),
      );
    },
  );
  test(
    'concurrent device snapshots converge without shared-manifest overwrite',
    () async {
      await a.setFavorite('ikun', film('7'), true);
      await b.setFavorite('ikun', film('8'), true);
      await Future.wait([
        VideoLibrarySync.run(remote, store: a, codec: codec),
        VideoLibrarySync.run(remote, store: b, codec: codec),
      ]);
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      await VideoLibrarySync.run(remote, store: b, codec: codec);
      expect((await a.read()).itemsFor('ikun'), hasLength(2));
      expect((await b.read()).itemsFor('ikun'), hasLength(2));
      expect(remote.files.length, 2);
    },
  );
  test(
    'delete and rename survive another offline device uploading stale content',
    () async {
      final folder = await a.createFolder('ikun', '旧名');
      await a.setFavorite('ikun', film('7'), true, folderIds: {folder});
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      await VideoLibrarySync.run(remote, store: b, codec: codec, upload: false);
      await a.renameFolder(folder, '新名');
      await a.setFavorite('ikun', film('7'), false);
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      await VideoLibrarySync.run(remote, store: b, codec: codec);
      expect((await b.read()).contains('ikun', '7'), isFalse);
      expect((await b.read()).folders[folder]!.data['name'], '新名');
    },
  );
  test('failed upload preserves local favorites and is retryable', () async {
    await a.setFavorite('ikun', film('7'), true);
    remote.reject = true;
    await expectLater(
      VideoLibrarySync.run(remote, store: a, codec: codec),
      throwsStateError,
    );
    expect((await a.read()).contains('ikun', '7'), isTrue);
    remote.reject = false;
    await VideoLibrarySync.run(remote, store: a, codec: codec);
    expect(remote.files, isNotEmpty);
  });
  test(
    'corrupt and future cloud records cannot replace valid local data',
    () async {
      await a.setFavorite('ikun', film('7'), true);
      await VideoLibrarySync.run(remote, store: a, codec: codec);
      final path = remote.files.keys.single;
      final payload =
          jsonDecode(utf8.decode(remote.files[path]!)) as Map<String, dynamic>;
      payload['version'] = 99;
      remote.files[path] = utf8.encode(jsonEncode(payload));
      await expectLater(
        VideoLibrarySync.run(remote, store: a, codec: codec),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect((await a.read()).contains('ikun', '7'), isTrue);
    },
  );
}
