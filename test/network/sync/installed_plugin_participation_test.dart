import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

import '../../test_helper.dart';

const _installed = '99999999-1111-4222-8333-444444444444';
const _removed = '88888888-1111-4222-8333-444444444444';
const _absent = '77777777-1111-4222-8333-444444444444';
const _state = GlobalSettingState(
  syncSetting: SyncSettingState(syncPlugins: true),
);
Future<List<int>> _identity(List<int> bytes) async => bytes;
const _settingsCodec = SettingsSyncCodec(encode: _identity, decode: _identity);
const _videoCodec = VideoLibrarySyncCodec(encode: _identity, decode: _identity);

PluginInfo _info(String source, {bool enabled = false, bool deleted = false}) =>
    PluginInfo(
      uuid: source,
      version: 'fixture',
      originScript: deleted ? '' : 'fixture-script',
      insertedAt: DateTime.fromMillisecondsSinceEpoch(100, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(200, isUtc: true),
      isEnabled: enabled,
      isDeleted: deleted,
      deletedAt: deleted
          ? DateTime.fromMillisecondsSinceEpoch(200, isUtc: true)
          : null,
      lastLoadSuccess: false,
      debug: false,
    );

Map<String, dynamic> _comics(List<Map<String, dynamic>> rows) => {
  'version': 'v1',
  'favorites': rows,
  'histories': [],
  'follows': [],
  'readPreferences': [],
  'folders': [],
  'links': [],
};
Map<String, dynamic> _settings(
  List<PluginInfo> infos, {
  String schema = 'v2',
}) => {
  'version': 'v1',
  'schemaVersion': schema,
  'syncTime': 10000,
  'blocks': {
    'plugins': {
      'updatedAt': 10000,
      'data': {
        'pluginInfos': infos.map((row) => row.toJson()).toList(),
        'pluginConfigs': [
          for (final row in infos)
            PluginConfig(
              name: row.uuid,
              config: '{"value":"cloud-${row.uuid}"}',
            ).toJson(),
        ],
      },
    },
  },
};

class _Remote extends ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  int uploads = 0;
  String path(String input) => input.contains('/')
      ? input
      : '${ComicSyncCore.syncRemoteRootName}/$input';
  void seedSettings(Map<String, dynamic> data) {
    final bytes = utf8.encode(jsonEncode(data));
    files[path('settings_10000.bin')] = bytes;
    files[path('settings.md5')] = utf8.encode(
      ComicSyncCore.calculateMd5(bytes),
    );
  }

  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String input) async {
    final bytes = files[path(input)];
    if (bytes == null) throw StateError('404');
    return List.of(bytes);
  }

  @override
  Future<String> downloadRemoteMd5() async =>
      utf8.decode(files[path('comic.md5')] ?? []);
  @override
  Future<void> uploadRemoteMd5(String digest) async =>
      uploadRemoteFile('comic.md5', utf8.encode(digest));
  @override
  Future<void> uploadRemoteFile(
    String input,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    uploads++;
    files[path(input)] = List.of(bytes);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    for (final input in paths) {
      files.remove(path(input));
    }
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
    objectbox.comicFollowBox.removeAll();
    objectbox.comicReadPreferenceBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.userSettingBox.put(UserSetting(id: 1)..globalSetting = _state);
    objectbox.pluginInfoBox.putMany([_info(_installed), _info(_removed)]);
    await LocalPluginInstallationState.instance.markRemoved(_removed);
  });

  test(
    'disabled stays installed, removal blocks participation, explicit reinstall invalidates old capture',
    () async {
      final local = LocalPluginInstallationState.instance;
      final scope = await SyncPluginParticipation.capture();
      expect(scope.sources, {_installed});
      scope.check();
      final row = objectbox.pluginInfoBox.getAll().firstWhere(
        (row) => row.uuid == _installed,
      );
      row.isEnabled = true;
      objectbox.pluginInfoBox.put(row);
      scope.check();
      await local.completeExplicitInstallation(_removed);
      expect(scope.check, throwsA(isA<PluginLifecycleChanged>()));
      expect((await SyncPluginParticipation.capture()).sources, {
        _installed,
        _removed,
      });
    },
  );

  test(
    'comic apply keeps removed local rows while cloud projection preserves their exact remote rows',
    () async {
      final localActive = createTestFavorite('active')
        ..source = _installed
        ..title = 'local active';
      final localRetained = createTestFavorite('retained')
        ..source = _removed
        ..title = 'local retained';
      objectbox.unifiedFavoriteBox.putMany([localActive, localRetained]);
      final remoteRetained = createTestFavorite('retained')
        ..source = _removed
        ..title = 'cloud retained';
      final remoteAbsent = createTestFavorite('absent')
        ..source = _absent
        ..title = 'cloud absent';
      final remote = _comics([remoteRetained.toJson(), remoteAbsent.toJson()]);
      final projection = <String, dynamic>{};
      final scope = await SyncPluginParticipation.capture();
      objectbox.store.runInTransaction(TxMode.write, () {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          remote,
          participatingSources: scope.sources,
          cloudProjection: projection,
        );
      });
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((row) => row.title),
        unorderedEquals(['local active', 'local retained']),
      );
      final cloudRows = projection['favorites'] as List;
      expect(
        cloudRows.where((row) => row['source'] == _removed).single,
        remoteRetained.toJson(),
      );
      expect(
        cloudRows.where((row) => row['source'] == _absent).single,
        remoteAbsent.toJson(),
      );
      expect(
        cloudRows.where((row) => row['source'] == _installed),
        hasLength(1),
      );
      expect(
        projectPluginComicData(
          ComicSyncCore.captureData(),
          const {},
          scope.sources,
        )['favorites'],
        hasLength(1),
      );
    },
  );

  test('new comic archive dates preserve their instants in UTC', () {
    final createdAt = DateTime.utc(2026, 11, 1, 3);
    final updatedAt = DateTime.utc(2026, 11, 2, 4);
    final lastReadAt = DateTime.utc(2026, 11, 2, 1);
    final updateTime = DateTime.utc(2026, 11, 2, 2);
    const key = '$_installed:work';
    objectbox.unifiedFavoriteBox.put(
      createTestFavorite(key, updatedAt: updatedAt, deleted: true)
        ..source = _installed
        ..createdAt = createdAt,
    );
    objectbox.unifiedHistoryBox.put(
      createTestHistory(key, updatedAt: updatedAt)
        ..source = _installed
        ..createdAt = createdAt
        ..lastReadAt = lastReadAt,
    );
    objectbox.comicFollowBox.put(
      ComicFollow(
        uniqueKey: key,
        source: _installed,
        comicId: 'work',
        title: 'Work',
        description: '',
        cover: '{}',
        creator: '{}',
        titleMeta: '[]',
        metadata: '[]',
        lastChapterCount: 1,
        detectedChapterCount: 2,
        hasUpdate: true,
        updateTime: updateTime,
        deleted: false,
        createdAt: createdAt,
        updatedAt: updatedAt,
        schemaVersion: 1,
      ),
    );
    objectbox.comicReadPreferenceBox.put(
      ComicReadPreference(
        uniqueKey: key,
        source: _installed,
        comicId: 'work',
        updatedAt: updatedAt,
      ),
    );
    final capture = ComicSyncCore.captureData();
    final projection = <String, dynamic>{};
    objectbox.store.runInTransaction(TxMode.write, () {
      ComicSyncCore.mergeUnifiedData(
        objectbox.store,
        _comics([]),
        participatingSources: {_installed},
        cloudProjection: projection,
      );
    });
    for (final payload in [capture, projection]) {
      final dates = {
        'favorites': {'createdAt': createdAt, 'updatedAt': updatedAt},
        'histories': {
          'createdAt': createdAt,
          'lastReadAt': lastReadAt,
          'updatedAt': updatedAt,
        },
        'follows': {
          'createdAt': createdAt,
          'updateTime': updateTime,
          'updatedAt': updatedAt,
        },
        'readPreferences': {'updatedAt': updatedAt},
      };
      for (final table in dates.entries) {
        final row = (payload[table.key] as List).single as Map;
        for (final field in table.value.entries) {
          expect(row[field.key], field.value.toIso8601String());
        }
      }
    }
  });

  test('comic archive leaves unchanged legacy cloud dates in place', () {
    const key = '$_installed:work';
    final legacyTime = DateTime(2026, 11, 2, 4);
    final favorite = createTestFavorite(key, updatedAt: legacyTime)
      ..source = _installed;
    final preference = ComicReadPreference(
      uniqueKey: key,
      source: _installed,
      comicId: 'work',
      updatedAt: legacyTime,
    );
    final remote = _comics([favorite.toJson()])
      ..['readPreferences'] = [preference.toJson()];
    for (final direction in [SyncDirection.recordsOnly, SyncDirection.merge]) {
      final projection = <String, dynamic>{};
      objectbox.store.runInTransaction(TxMode.write, () {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          remote,
          participatingSources: {_installed},
          preferenceDirection: direction,
          cloudProjection: projection,
        );
      });
      for (final table in ['favorites', 'readPreferences']) {
        final row = (projection[table] as List).single as Map;
        expect(row['updatedAt'], legacyTime.toIso8601String());
      }
    }
  });

  test(
    'normal settings preserve uninstalled remote rows without importing their package or overwriting local retained config',
    () async {
      objectbox.pluginConfigBox.putMany([
        PluginConfig(name: _removed, config: '{"value":"local-retained"}'),
        PluginConfig(name: _installed, config: '{"value":"local-active"}'),
      ]);
      final remote = _Remote();
      final incoming = _settings([_info(_removed), _info(_absent)]);
      final path = remote.path('settings_10000.bin');
      remote.files[path] = utf8.encode(jsonEncode(incoming));
      remote.files[remote.path('settings.md5')] = utf8.encode(
        ComicSyncCore.calculateMd5(remote.files[path]!),
      );
      await runSettingsSync(
        remote,
        currentGlobalSetting: _state,
        codec: _settingsCodec,
      );
      expect(
        objectbox.pluginInfoBox.getAll().any((row) => row.uuid == _absent),
        isFalse,
      );
      expect(
        objectbox.pluginConfigBox
            .getAll()
            .firstWhere((row) => row.name == _removed)
            .config,
        '{"value":"local-retained"}',
      );
      final result = await readSettingsArchiveData(
        remote,
        codec: _settingsCodec,
      );
      expect(
        result!.pluginConfigsForSource(_removed).single.config,
        '{"value":"cloud-$_removed"}',
      );
      expect(
        result.pluginConfigsForSource(_absent).single.config,
        '{"value":"cloud-$_absent"}',
      );
      final before = remote.uploads;
      await runSettingsSync(
        remote,
        currentGlobalSetting: _state,
        codec: _settingsCodec,
      );
      expect(
        remote.uploads,
        before,
        reason:
            'Skipped foreign rows must not cause clock/hash churn each round',
      );
    },
  );

  test(
    'ordinary incoming installation tombstone cannot uninstall this device; explicit file plan remains unrestricted',
    () async {
      final remote = _Remote();
      remote.seedSettings(_settings([_info(_installed, deleted: true)]));
      final archive = await readSettingsArchiveData(
        remote,
        codec: _settingsCodec,
      );
      final scope = await SyncPluginParticipation.capture();
      final normal = await prepareSettingsArchiveImport(
        archive,
        state: _state,
        participation: scope,
      );
      objectbox.store.runInTransaction(TxMode.write, normal.persistDatabase);
      expect(
        objectbox.pluginInfoBox
            .getAll()
            .firstWhere((row) => row.uuid == _installed)
            .isDeleted,
        isFalse,
      );
      remote.seedSettings(_settings([_info(_absent)]));
      final filePlan = await prepareSettingsArchiveImport(
        await readSettingsArchiveData(remote, codec: _settingsCodec),
        state: _state,
      );
      objectbox.store.runInTransaction(TxMode.write, filePlan.persistDatabase);
      expect(
        objectbox.pluginInfoBox.getAll().any((row) => row.uuid == _absent),
        isTrue,
      );
    },
  );

  test(
    'video ordinary sync keeps removed local favorite and keeps foreign cloud favorite without importing it',
    () async {
      final local = VideoLibraryStore(
        deviceId: 'local',
        storageKey: 'fixture.installed.local',
      );
      final other = VideoLibraryStore(
        deviceId: 'cloud',
        storageKey: 'fixture.installed.cloud',
      );
      addTearDown(local.dispose);
      addTearDown(other.dispose);
      ApiVideoItem item(String id) => ApiVideoItem(
        id: id,
        title: id,
        detailUrl: Uri.parse('https://fixture.invalid/$id'),
      );
      await local.setFavorite(_installed, item('active'), true);
      await local.setFavorite(_removed, item('local-retained'), true);
      await other.setFavorite(_removed, item('cloud-retained'), true);
      await other.setFavorite(_absent, item('cloud-absent'), true);
      final snapshot = (await other.read()).toJson();
      final remote = _Remote();
      remote.files[remote.path(
        'video_library_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bin',
      )] = utf8.encode(
        jsonEncode({
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'snapshot': snapshot,
          'sha256': sha256
              .convert(utf8.encode(jsonEncode(snapshot)))
              .toString(),
        }),
      );
      await VideoLibrarySync.run(remote, store: local, codec: _videoCodec);
      final actual = await local.read();
      expect(actual.contains(_removed, 'local-retained'), isTrue);
      expect(actual.contains(_removed, 'cloud-retained'), isFalse);
      expect(actual.contains(_absent, 'cloud-absent'), isFalse);
      final archive = await VideoLibrarySync.readArchive(
        remote,
        codec: _videoCodec,
      );
      expect(archive.snapshot.contains(_installed, 'active'), isTrue);
      expect(archive.snapshot.contains(_removed, 'cloud-retained'), isTrue);
      expect(archive.snapshot.contains(_removed, 'local-retained'), isFalse);
      expect(archive.snapshot.contains(_absent, 'cloud-absent'), isTrue);
    },
  );

  test(
    'portable ordinary projection preserves global values and removed local values separately from cloud values',
    () async {
      Map<String, dynamic> row(String source, bool value, int clock) => {
        'key': 'breeze.source.list-details.v1.$source',
        'kind': 'preference',
        'value': value,
        'deleted': false,
        'updatedAt': clock,
      };
      final incoming = PortablePreferencesSnapshot({
        'active': row(_installed, true, 200),
        'removed': row(_removed, true, 200),
        'global': {
          'key': 'breeze.bookshelf.source-tabs.comic',
          'kind': 'preference',
          'value': '{"order":[],"hidden":[]}',
          'deleted': false,
          'updatedAt': 200,
        },
      });
      final retained = PortablePreferencesSnapshot({
        'removed': row(_removed, false, 100),
      });
      final applied = projectPluginPortableData(incoming, retained, {
        _installed,
      });
      expect(applied.entries['global'], incoming.entries['global']);
      expect(applied.entries['active']!['value'], isTrue);
      expect(applied.entries['removed']!['value'], isFalse);
      final uploaded = projectPluginPortableData(retained, incoming, {
        _installed,
      });
      expect(uploaded.entries['removed']!['value'], isTrue);
    },
  );

  test(
    'old masks do not create a hidden sync opt-out after explicit reinstall',
    () async {
      final localState = LocalPluginInstallationState.instance;
      await localState.setDataExclusions(
        _removed,
        PluginDataScope.values.toSet(),
        beforeWrite: (_) async {},
      );
      final before = await SyncPluginParticipation.capture();
      final remoteFavorite = createTestFavorite('reinstall-remote')
        ..source = _removed;
      final comicData = _comics([remoteFavorite.toJson()]);
      objectbox.store.runInTransaction(TxMode.write, () {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          comicData,
          participatingSources: before.sources,
        );
      });
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
      final prefKey = 'breeze.source.list-details.v1.$_removed';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, false);
      final portable = PortablePreferencesSnapshot({
        '$prefKey#${sha256.convert(utf8.encode(''))}': {
          'key': prefKey,
          'kind': 'preference',
          'value': true,
          'deleted': false,
          'updatedAt': DateTime.now().millisecondsSinceEpoch + 10000,
        },
      });
      await PortablePreferences.restore(
        portable,
        participatingSources: before.sources,
      );
      expect(prefs.getBool(prefKey), isFalse);
      final library = VideoLibraryStore(
        deviceId: 'reinstall',
        storageKey: 'fixture.reinstall.library',
      );
      final cloudLibrary = VideoLibraryStore(
        deviceId: 'remote',
        storageKey: 'fixture.reinstall.remote',
      );
      addTearDown(library.dispose);
      addTearDown(cloudLibrary.dispose);
      await cloudLibrary.setFavorite(
        _removed,
        ApiVideoItem(
          id: '7',
          title: 'Fixture',
          detailUrl: Uri.parse('https://fixture.invalid/7'),
        ),
        true,
      );
      final raw = (await cloudLibrary.read()).toJson();
      final videoRemote = _Remote();
      videoRemote.files[videoRemote.path(
        'video_library_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.bin',
      )] = utf8.encode(
        jsonEncode({
          'format': 'BreezeVideoLibrary',
          'version': 1,
          'snapshot': raw,
          'sha256': sha256.convert(utf8.encode(jsonEncode(raw))).toString(),
        }),
      );
      await VideoLibrarySync.run(
        videoRemote,
        store: library,
        codec: _videoCodec,
        participation: before,
      );
      expect((await library.read()).contains(_removed, '7'), isFalse);

      await localState.completeExplicitInstallation(_removed);
      expect(
        localState.isDataExcluded(_removed, PluginDataScope.records),
        isTrue,
        reason: 'Ordinary participation must not delete old persistent fields',
      );
      final after = await SyncPluginParticipation.capture();
      objectbox.store.runInTransaction(TxMode.write, () {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          comicData,
          participatingSources: after.sources,
        );
      });
      expect(
        objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
        remoteFavorite.uniqueKey,
      );
      await PortablePreferences.restore(
        portable,
        participatingSources: after.sources,
      );
      expect(prefs.getBool(prefKey), isTrue);
      await VideoLibrarySync.run(
        videoRemote,
        store: library,
        codec: _videoCodec,
        participation: after,
      );
      expect((await library.read()).contains(_removed, '7'), isTrue);
      final settingsRemote = _Remote();
      settingsRemote.seedSettings(_settings([_info(_removed)]));
      final plan = await prepareSettingsArchiveImport(
        await readSettingsArchiveData(settingsRemote, codec: _settingsCodec),
        state: _state,
        participation: after,
      );
      objectbox.store.runInTransaction(TxMode.write, plan.persistDatabase);
      final restored = objectbox.pluginConfigBox.getAll().firstWhere(
        (row) => row.name == _removed,
      );
      expect(jsonDecode(restored.config)['value'], 'cloud-$_removed');
    },
  );

  test(
    'future remote schema is rejected before installed filtering or any upload',
    () async {
      final remote = _Remote();
      remote.files[remote.path('settings_10000.bin')] = utf8.encode(
        jsonEncode(_settings([_info(_absent)], schema: 'v99')),
      );
      await expectLater(
        runSettingsSync(
          remote,
          currentGlobalSetting: _state,
          codec: _settingsCodec,
        ),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(remote.uploads, 0);
      expect(
        objectbox.pluginInfoBox.getAll().any((row) => row.uuid == _absent),
        isFalse,
      );
    },
  );
}
