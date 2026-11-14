import '../../test_helper.dart';
import 'sync_installed_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:zephyr/network/sync/sync_direction.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_personal_preferences.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

class _Remote implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  bool fail = false;
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<void> testConnection() async {}
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
    if (fail) throw StateError('offline');
    files[path] = List.of(bytes);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    for (final path in paths) {
      files.remove(path);
    }
  }
}

Future<List<int>> _identity(List<int> bytes) async => bytes;
const _codec = VideoLibrarySyncCodec(encode: _identity, decode: _identity);
const _sources = [
  'hanime-fixture',
  'omo-fixture',
  'ikun-fixture',
  'modu-fixture',
  'oscar-fixture',
];
VideoWatchRecord _record(String source, String id) => VideoWatchRecord(
  watchUrl: Uri.parse(
    'https://$source.test/watch?v=${{'one': '1', 'two': '2', 'three': '3'}[id]}',
  ),
  title: 'Fixture $source $id',
  position: const Duration(seconds: 40),
  duration: const Duration(minutes: 3),
  updatedAt: DateTime.utc(2025, 1, 1),
  completed: false,
  metadata: const {
    'genres': 'Action',
    'year': '2024',
    'area': 'Japan',
    'auth.jwt': 'must-not-be-exported',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins(_sources);
  });
  for (final failPreparation in [false, true]) {
    test(
      'portable merge retains video progress written during recovery preparation '
      '(fails=$failPreparation)',
      () async {
        final source = _sources.first;
        final old = _record(source, 'one');
        final other = _record(source, 'two');
        await VideoWatchHistory.record(source, other);
        final incoming = await PortablePreferences.capture(persist: false);
        await VideoWatchHistory.remove(source, other.watchUrl);
        await VideoWatchHistory.record(source, old);

        final entered = Completer<void>();
        final release = Completer<void>();
        final restore = PortablePreferences.restore(
          incoming,
          beforeWrite: (updates) async {
            entered.complete();
            await release.future;
            expect(
              updates,
              contains('${PortablePreferences.historyPrefix}$source'),
            );
            if (failPreparation) throw StateError('Preparation failed');
          },
        );
        final checkedRestore = failPreparation
            ? expectLater(restore, throwsStateError)
            : restore;
        await entered.future;
        final checkpoint = VideoWatchRecord.fromJson({
          ...old.toJson(),
          'position': const Duration(seconds: 56).inMilliseconds,
          'updatedAt': DateTime.utc(2026, 11, 10).millisecondsSinceEpoch,
        })!;
        final write = VideoWatchHistory.record(source, checkpoint);
        await Future<void>.delayed(Duration.zero);
        release.complete();
        await Future.wait([checkedRestore, write]);

        final records = await VideoWatchHistory.read(source);
        expect(records.map((record) => record.watchUrl), [
          old.watchUrl,
          if (!failPreparation) other.watchUrl,
        ]);
        expect(records.first.position, checkpoint.position);
        final captured = await PortablePreferences.capture(persist: false);
        final archived = captured.entries.values
            .where(
              (row) => row['key'] == '${PortablePreferences.historyPrefix}$source',
            )
            .map((row) => VideoWatchRecord.fromJson(row['value'])!)
            .toList();
        expect(archived, hasLength(records.length));
        expect(
          archived
              .singleWhere((record) => record.watchUrl == checkpoint.watchUrl)
              .position,
          checkpoint.position,
        );
      },
    );
  }
  test(
    'five video sources restore favorites, history, searches and settings into a fresh device',
    () async {
      final remote = _Remote(),
          source = VideoLibraryStore(deviceId: 'device-a');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'breeze.bookshelf.facet-tags.v1.comic',
        jsonEncode(['tag-a', '标签B']),
      );
      await prefs.setString(
        'breeze.bookshelf.facet-tags.v1.video',
        jsonEncode(['genre-a']),
      );
      await prefs.setString('sync.device_id', 'device-a');
      await prefs.setString(
        'breeze.omo.network.v1',
        'device-only-loopback-secret',
      );
      await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
      await prefs.setString(
        'breeze.bookshelf.source-tabs.video.v1',
        jsonEncode({
          'version': 1,
          'order': _sources,
          'hidden': [_sources.last],
        }),
      );
      for (final id in _sources) {
        await source.setFavorite(
          id,
          ApiVideoItem(
            id: 'one',
            title: 'Fixture',
            detailUrl: Uri.parse('https://$id.test/video/one'),
          ),
          true,
        );
        await VideoWatchHistory.record(id, _record(id, 'one'));
        await VideoSearchHistory.add(id, 'search-$id');
        await VideoExportRecords.add(
          source: id,
          video: _record(id, 'one').watchUrl,
          title: 'Export fixture',
          quality: 'original',
        );
        await SourceListPreferences.write(id, true);
      }
      await VideoLibrarySync.run(remote, store: source, codec: _codec);
      expect(remote.files, hasLength(1));
      expect(
        utf8.decode(remote.files.values.single),
        isNot(contains('device-only-loopback-secret')),
      );
      expect(
        utf8.decode(remote.files.values.single),
        isNot(contains('must-not-be-exported')),
      );
      SharedPreferences.setMockInitialValues({'sync.device_id': 'device-b'});
      final target = VideoLibraryStore(deviceId: 'device-b');
      await VideoLibrarySync.run(
        remote,
        store: target,
        codec: _codec,
        upload: false,
      );
      expect(
        (await target.read()).favorites.values.where((r) => !r.deleted),
        hasLength(5),
      );
      for (final id in _sources) {
        expect(
          (await VideoWatchHistory.read(id)).single.position,
          const Duration(seconds: 40),
        );
        expect(await VideoSearchHistory.read(id), ['search-$id']);
        expect((await VideoWatchHistory.read(id)).single.metadata, {
          'genres': 'Action',
          'year': '2024',
          'area': 'Japan',
        });
        expect(await SourceListPreferences.read(id), isTrue);
      }
      expect(await VideoExportRecords.read(), hasLength(5));
      expect((await VideoPlaybackPreferences.read()).controlsStyle, 'breeze');
      final imported = await SharedPreferences.getInstance();
      expect(
        jsonDecode(imported.getString('breeze.bookshelf.facet-tags.v1.comic')!),
        ['tag-a', '标签B'],
      );
      expect(
        jsonDecode(imported.getString('breeze.bookshelf.facet-tags.v1.video')!),
        ['genre-a'],
      );
      expect(imported.getString('sync.device_id'), 'device-b');
      expect(imported.containsKey('breeze.omo.network.v1'), isFalse);
      expect(
        jsonDecode(
          imported.getString('breeze.bookshelf.source-tabs.video.v1')!,
        )['hidden'],
        [_sources.last],
      );
      expect(
        remote.files,
        hasLength(1),
        reason: 'download never publishes an empty new-device snapshot',
      );
    },
  );

  test(
    'record-level merge keeps concurrent additions and deletion tombstones beat stale devices',
    () async {
      await VideoWatchHistory.record('source', _record('source', 'one'));
      await VideoSearchHistory.add('source', 'deleted-word');
      final stale = await PortablePreferences.capture();
      await VideoWatchHistory.remove(
        'source',
        _record('source', 'one').watchUrl,
      );
      await VideoSearchHistory.remove('source', 'deleted-word');
      await VideoWatchHistory.record('source', _record('source', 'two'));
      final edited = await PortablePreferences.capture();
      SharedPreferences.setMockInitialValues({});
      await PortablePreferences.restore(edited.merged(stale));
      expect((await VideoWatchHistory.read('source')).map((r) => r.title), [
        'Fixture source two',
      ]);
      expect(await VideoSearchHistory.read('source'), isEmpty);
      await VideoWatchHistory.record('source', _record('source', 'three'));
      final other = await PortablePreferences.capture();
      await PortablePreferences.restore(other.merged(stale));
      expect(
        (await VideoWatchHistory.read('source')).map((r) => r.title).toSet(),
        {'Fixture source two', 'Fixture source three'},
      );
    },
  );

  test(
    'data sync can exclude settings and corrupt remote snapshots do not alter local data',
    () async {
      await installSyncPlugins([..._sources, 'source']);
      final remote = _Remote(), source = VideoLibraryStore(deviceId: 'a');
      await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
      await VideoSearchHistory.add('source', 'portable-word');
      await VideoLibrarySync.run(
        remote,
        store: source,
        codec: _codec,
        includeSettings: false,
      );
      expect(
        utf8.decode(remote.files.values.single),
        isNot(contains(VideoPlaybackPreferences.snapshotKey)),
      );
      SharedPreferences.setMockInitialValues({});
      await VideoPlaybackPreferences.save('controlsStyle', 'system');
      final target = VideoLibraryStore(deviceId: 'b');
      await VideoLibrarySync.run(
        remote,
        store: target,
        codec: _codec,
        includeSettings: false,
        upload: false,
      );
      expect((await VideoPlaybackPreferences.read()).controlsStyle, 'system');
      expect(await VideoSearchHistory.read('source'), ['portable-word']);
      final before = (await PortablePreferences.capture()).toJson();
      final path = remote.files.keys.single;
      final data =
          jsonDecode(utf8.decode(remote.files[path]!)) as Map<String, dynamic>;
      data['portableSha256'] = 'invalid';
      remote.files[path] = utf8.encode(jsonEncode(data));
      await expectLater(
        VideoLibrarySync.run(remote, store: target, codec: _codec),
        throwsFormatException,
      );
      expect((await PortablePreferences.capture()).toJson(), before);
    },
  );

  test(
    'unowned device keys and wrong value types are rejected before restoring',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('breeze.video.progress.fixture', 12000);
      final valid = await PortablePreferences.capture();
      final data =
          jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
      final entry = (data['entries'] as Map).values.single as Map;
      entry['value'] = 'wrong-type';
      expect(
        () => PortablePreferencesSnapshot.fromJson(data),
        throwsFormatException,
      );
      entry['key'] = 'sync.device_id';
      entry['value'] = 'attacker-device';
      expect(
        () => PortablePreferencesSnapshot.fromJson(data),
        throwsFormatException,
      );
      expect(prefs.getInt('breeze.video.progress.fixture'), 12000);
    },
  );
  test(
    'personal search scope survives selected cloud sync and file backup',
    () async {
      final source = _sources.first;
      final scope =
          'plugin|$source|https://site.test/user/1|https://site.test/likes';
      final key =
          '${VideoPersonalPreferences.prefix}${Uri.encodeComponent(scope)}';
      final cacheKey =
          '${VideoPersonalSnapshotStore.prefix}${Uri.encodeComponent(scope)}';
      const legacy = {'query': 'one', 'sort': 'source', 'facets': {}};
      final settings = {...legacy, 'keywordScope': 'all'};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, 'device-only');
      await VideoPersonalPreferences.write(scope, legacy);
      final oldFile = await PortablePreferences.capture();
      await VideoPersonalPreferences.write(scope, settings);
      final newFile = await PortablePreferences.capture();
      final row = newFile.entries.values.single;
      expect(row['key'], key);
      expect(jsonDecode(row['value'] as String), settings);
      expect(
        const BackupImportOptions(importSettings: false).includesPortable(row),
        isTrue,
      );
      expect(
        const BackupImportOptions(importPlugins: false).includesPortable(row),
        isFalse,
      );

      final remote = _Remote();
      await VideoLibrarySync.run(
        remote,
        store: VideoLibraryStore(deviceId: 'personal-sender'),
        codec: _codec,
      );
      final archive = await VideoLibrarySync.readArchive(remote, codec: _codec);
      expect(archive.preferences.entries.values.single['key'], key);
      SharedPreferences.setMockInitialValues({cacheKey: 'receiver-cache'});
      final receiver = VideoLibraryStore(deviceId: 'personal-receiver');
      await VideoLibrarySync.run(
        remote,
        store: receiver,
        codec: _codec,
        upload: false,
        direction: SyncDirection.recordsOnly,
        includeSettings: false,
      );
      expect(await VideoPersonalPreferences.read(scope), isEmpty);
      await VideoLibrarySync.run(
        remote,
        store: receiver,
        codec: _codec,
        upload: false,
        direction: SyncDirection.restore,
        includeSettings: false,
        includePluginSettings: true,
      );
      expect(await VideoPersonalPreferences.read(scope), settings);

      Future<void> restoreFile(PortablePreferencesSnapshot snapshot) =>
          PortablePreferences.restore(
            PortablePreferencesSnapshot.fromJson(
              jsonDecode(jsonEncode(snapshot.toJson())),
            ),
            replace: true,
          );
      await restoreFile(oldFile);
      expect(await VideoPersonalPreferences.read(scope), legacy);
      await restoreFile(newFile);
      expect(await VideoPersonalPreferences.read(scope), settings);
      expect(
        (await SharedPreferences.getInstance()).getString(cacheKey),
        'receiver-cache',
      );
    },
  );

  test(
    'a malformed optional personal preference keeps its last valid archive value',
    () async {
      final scope =
          'plugin|${_sources.first}|https://site.test/user/1|https://site.test/likes';
      await VideoPersonalPreferences.write(scope, {'keywordScope': 'title'});
      final before = await PortablePreferences.capture();
      await VideoPersonalPreferences.write(scope, {'keywordScope': 'unknown'});
      expect((await PortablePreferences.capture()).toJson(), before.toJson());
    },
  );

  test(
    'portable preferences follow selected global and plugin directions while search records merge',
    () async {
      const source = 'hanime-fixture';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('breeze.collection-cover.style.v1', 'glass');
      await prefs.setBool('breeze.source.list-details.v1.$source', false);
      await prefs.setStringList('${PortablePreferences.searchPrefix}$source', [
        'local',
      ]);
      final local = await PortablePreferences.capture();
      SharedPreferences.setMockInitialValues({
        'breeze.collection-cover.style.v1': 'mosaic',
        'breeze.source.list-details.v1.$source': true,
        '${PortablePreferences.searchPrefix}$source': ['cloud'],
      });
      final remote = await PortablePreferences.capture();
      final uploaded = PortablePreferences.directed(
        local,
        remote,
        direction: SyncDirection.upload,
        forCloud: true,
        includeSettings: false,
        includePluginSettings: true,
      );
      expect(
        uploaded.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.collection-cover.style.v1',
        )['value'],
        'mosaic',
      );
      expect(
        uploaded.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.source.list-details.v1.$source',
        )['value'],
        isFalse,
      );
      expect(
        uploaded.entries.values
            .where((r) => r['kind'] == 'search' && r['deleted'] != true)
            .map((r) => r['value'])
            .toSet(),
        {'local', 'cloud'},
      );
      final restored = PortablePreferences.directed(
        local,
        remote,
        direction: SyncDirection.restore,
        includeSettings: true,
        includePluginSettings: false,
      );
      expect(
        restored.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.collection-cover.style.v1',
        )['value'],
        'mosaic',
      );
      expect(
        restored.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.source.list-details.v1.$source',
        )['value'],
        isFalse,
      );
      final auto = PortablePreferences.directed(
        local,
        remote,
        direction: SyncDirection.recordsOnly,
      );
      expect(
        auto.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.collection-cover.style.v1',
        )['value'],
        'glass',
      );
      expect(
        auto.entries.values
            .where((r) => r['kind'] == 'search' && r['deleted'] != true)
            .map((r) => r['value'])
            .toSet(),
        {'local', 'cloud'},
      );
    },
  );
  test('explicit uploaded custom cover style survives other-device archives, repeated upload and restore capture', () async {
    const key = CollectionCoverPrivacyController.styleKey;
    Map<String, dynamic> style(PortablePreferencesSnapshot s) => s.entries.values.singleWhere((r) => r['key'] == key);
    final remote = _Remote();
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, 'blur');
    final oldCloud = await PortablePreferences.capture();
    final cloudEntries = {for (final e in oldCloud.entries.entries)
      e.key: {...e.value, if (e.value['key'] == key) 'updatedAt': 500}};
    await prefs.setString(PortablePreferences.journalKey,
      jsonEncode(PortablePreferencesSnapshot(cloudEntries).toJson()));
    await VideoLibrarySync.run(remote, store: VideoLibraryStore(deviceId: 'old-blur-device'),
      codec: _codec, direction: SyncDirection.upload);

    SharedPreferences.setMockInitialValues({key: 'custom', CollectionCoverPrivacyController.enabledKey: true});
    final own = await PortablePreferences.capture();
    expect(style(own)['updatedAt'], 1);
    final sender = VideoLibraryStore(deviceId: 'custom-device');
    await VideoLibrarySync.run(remote, store: sender, codec: _codec, direction: SyncDirection.upload);
    expect(remote.files, hasLength(2));
    var archive = await VideoLibrarySync.readArchive(remote, codec: _codec);
    expect(style(archive.preferences)['value'], 'custom');
    expect(style(archive.preferences)['updatedAt'], 501);
    // A second upload must not lower its own file back to local clock 1. Nor
    // should equal content keep incrementing the cloud clock on every round.
    await VideoLibrarySync.run(remote, store: sender, codec: _codec, direction: SyncDirection.upload);
    archive = await VideoLibrarySync.readArchive(remote, codec: _codec);
    expect(style(archive.preferences)['value'], 'custom');
    expect(style(archive.preferences)['updatedAt'], 501);

    SharedPreferences.setMockInitialValues({key: 'glass', CollectionCoverPrivacyController.enabledKey: true});
    final controller = CollectionCoverPrivacyController.instance;
    controller.state.value = const CollectionCoverPrivacySettings();
    await controller.ensureLoaded();
    controller.localImagePath.value = '/fixture/retained-selected-cover.jpg';
    addTearDown(() => controller.localImagePath.value = null);
    await VideoLibrarySync.run(remote, store: VideoLibraryStore(deviceId: 'restored-device'),
      codec: _codec, upload: false, direction: SyncDirection.restore);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), 'custom');
    expect(controller.state.value.style, CollectionCoverStyle.custom);
    expect(controller.state.value.enabled, isTrue);
    expect(prefs.getBool(CollectionCoverPrivacyController.enabledKey), isTrue);
    expect(controller.localImagePath.value, '/fixture/retained-selected-cover.jpg');
    final captured = await PortablePreferences.capture();
    expect(style(captured)['value'], 'custom');
    expect(style(captured)['updatedAt'], 501, reason: 'restore reload/capture must not resurrect or timestamp the old local glass value');
    final capturedAgain = await PortablePreferences.capture();
    expect(style(capturedAgain), style(captured));
  });

  test('upload revision promotion respects settings scope, deletion intent and record union without mutating snapshots', () async {
    const key = CollectionCoverPrivacyController.styleKey;
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, 'custom');
    await VideoSearchHistory.add('hanime-fixture', 'local-search');
    final local = await PortablePreferences.capture();
    SharedPreferences.setMockInitialValues({key: 'blur'});
    await VideoSearchHistory.add('hanime-fixture', 'cloud-search');
    final captured = await PortablePreferences.capture();
    final remote = PortablePreferencesSnapshot({for (final e in captured.entries.entries)
      e.key: {...e.value, if (e.value['key'] == key) 'updatedAt': 100}});
    final beforeLocal = jsonEncode(local.toJson()), beforeRemote = jsonEncode(remote.toJson());
    Map<String, dynamic> style(PortablePreferencesSnapshot s) => s.entries.values.singleWhere((r) => r['key'] == key);
    final uploaded = PortablePreferences.directed(local, remote,
      direction: SyncDirection.upload, forCloud: true);
    expect(style(uploaded)['value'], 'custom'); expect(style(uploaded)['updatedAt'], 101);
    expect(uploaded.entries.values.where((r) => r['kind'] == 'search').map((r) => r['value']).toSet(),
      {'local-search', 'cloud-search'});
    final settingsOff = PortablePreferences.directed(local, remote,
      direction: SyncDirection.upload, forCloud: true, includeSettings: false);
    expect(style(settingsOff)['value'], 'blur'); expect(style(settingsOff)['updatedAt'], 100);
    final automatic = PortablePreferences.directed(local, remote,
      direction: SyncDirection.recordsOnly, forCloud: true);
    expect(style(automatic), style(remote));
    final merge = PortablePreferences.directed(local, remote, direction: SyncDirection.merge);
    expect(style(merge), style(remote));

    final deleted = PortablePreferencesSnapshot({for (final e in local.entries.entries)
      e.key: e.value['key'] == key ? ({...e.value, 'deleted': true}..remove('value')) : {...e.value}});
    final deletion = PortablePreferences.directed(deleted, remote,
      direction: SyncDirection.upload, forCloud: true);
    expect(style(deletion)['deleted'], isTrue); expect(style(deletion)['updatedAt'], 101);
    expect(style(remote.merged(deletion))['deleted'], isTrue);
    expect(jsonEncode(local.toJson()), beforeLocal); expect(jsonEncode(remote.toJson()), beforeRemote);
  });

}
