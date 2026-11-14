import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/full_cloud_replace.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../../test_helper.dart';
import 'full_cloud_replace_fixture.dart';

Map<String, dynamic> _comic(String key) => {
  'version': 'v1',
  'favorites': [
    createTestFavorite(key, updatedAt: DateTime.utc(2025)).toJson()
      ..remove('id'),
  ],
};

FullCloudLocalSnapshot _artworkSnapshot() {
  final base = emptyFullReplaceSnapshot();
  final bytes = img.encodePng(img.Image(width: 8, height: 8));
  final digest = sha256.convert(bytes).toString();
  final key = FolderCoverIdentity.comic('retry-folder');
  return FullCloudLocalSnapshot(
    comic: base.comic,
    settings: base.settings,
    video: base.video,
    appearance: AppearanceSyncManifest({
      key: LocalAppearanceSyncRecord(
        key: key,
        digest: digest,
        size: bytes.length,
        modifiedAt: 1,
        deleted: false,
      ),
    }),
    resources: {digest: bytes},
  );
}

class _Profiles implements BackupProtectionProfileStore {
  BackupProtectionProfile? value;
  int writes = 0;
  @override
  Future<BackupProtectionProfile?> read() async => value;
  @override
  Future<void> write(BackupProtectionProfile? profile) async {
    value = profile;
    writes++;
  }
}

class _NoKeys implements BackupDeviceKeyStore {
  @override
  Future<Uint8List?> readKey(String id) async => null;
  @override
  Future<void> writeKey(String id, Uint8List bytes) async =>
      throw StateError('No device trust in fixture');
  @override
  Future<void> deleteKey(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.comicFollowBox.removeAll();
    objectbox.comicReadPreferenceBox.removeAll();
    await LocalPluginInstallationState.instance.reload();
  });

  test(
    'preview is read-only and cancellation leaves both archives and all preferences intact',
    () async {
      final cloud = FullReplaceMemoryServer()
        ..comic(_comic('new-only'))
        ..comic(_comic('old-only'), legacy: true);
      final local = emptyFullReplaceSnapshot(comic: _comic('local'));
      final before = cloud.saved;
      final prefs = await SharedPreferences.getInstance();
      final beforePrefs = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      final plan = await cloud.service(() => local).preview();
      expect(plan.currentFiles, 2);
      expect(plan.legacyFiles, 2);
      expect(plan.counts['comic']!.removed, 2);
      expect(plan.counts['comic']!.local, 1);
      // Returning without commit models cancellation at either UI step.
      expect(cloud.saved, before);
      expect(cloud.writes, isEmpty);
      expect(cloud.ensureCalls, 0);
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, beforePrefs);
    },
  );

  test(
    'full replacement previews and replaces chapter history objects',
    () async {
      final cloud = FullReplaceMemoryServer();
      final oldPath = cloud.path(
        'chapter_progress_v1_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.bin',
      );
      const old = ('fixture', 'old-work', 'one');
      const current = ('fixture', 'current-work', 'one');
      const progress = (
        at: 10,
        progress: (pageIndex: 5, pageCount: 5, completed: true),
      );
      cloud.files[oldPath] = ChapterProgressArchive({old: progress}).encode();
      final base = emptyFullReplaceSnapshot();
      final local = FullCloudLocalSnapshot(
        comic: base.comic,
        settings: base.settings,
        video: base.video,
        appearance: base.appearance,
        chapters: ChapterProgressArchive({current: progress}),
      );
      final service = cloud.service(() => local);
      final plan = await service.preview();
      expect(plan.counts['comic']!.removed, 1);
      expect(plan.counts['comic']!.local, 1);
      expect(cloud.writes, isEmpty);
      await service.commit(plan);
      expect(cloud.files, isNot(contains(oldPath)));
      final sidecar = cloud.files.entries.singleWhere(
        (row) => row.key.contains('/chapter_progress_v1_'),
      );
      expect(ChapterProgressArchive.decode(sidecar.value).rows, {
        current: progress,
      });
    },
  );

  test(
    'full replacement removes all historical/device archives in both roots and preserves unrelated/control files',
    () async {
      final cloud = FullReplaceMemoryServer()
        ..comic(_comic('remote-new'), stamp: 1)
        ..comic(_comic('remote-history'), stamp: 2)
        ..comic(_comic('remote-old'), legacy: true);
      cloud.files['unrelated/keep.bin'] = [1, 2, 3];
      cloud.files[cloud.path('unmanaged-note.txt')] = utf8.encode('keep');
      cloud.files[cloud.path('protection.json')] = utf8.encode(
        'synthetic control fixture',
      );
      final local = emptyFullReplaceSnapshot(comic: _comic('local-retained'));
      final service = cloud.service(() => local);
      final plan = await service.preview();
      expect(plan.counts['comic']!.removed, 3);
      await service.commit(plan);
      expect(
        cloud.files.keys.where(
          (p) => p.startsWith('${SyncArchiveContext.legacyRoot}/'),
        ),
        isEmpty,
      );
      expect(cloud.files['unrelated/keep.bin'], [1, 2, 3]);
      expect(
        utf8.decode(cloud.files[cloud.path('unmanaged-note.txt')]!),
        'keep',
      );
      expect(
        utf8.decode(cloud.files[cloud.path('protection.json')]!),
        'synthetic control fixture',
      );
      final result = await readComicArchiveData(
        cloud.adapters(),
        codec: const ComicSyncCodec(
          encode: identityFullReplaceCodec,
          decode: identityFullReplaceCodec,
        ),
      );
      expect(
        (result!['favorites'] as List).single['uniqueKey'],
        'local-retained',
      );
      expect(cloud.files.keys.where((p) => p.contains('/comic_')).length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (k) => k.startsWith('sync.full-replace.pending.'),
        ),
        isEmpty,
      );
      await expectLater(
        service.commit(plan),
        throwsA(isA<FullCloudReplaceStale>()),
      );
    },
  );

  for (final legacy in [false, true]) {
    test(
      'changed remote content or late snapshot rejects before first write, legacy=$legacy',
      () async {
        final cloud = FullReplaceMemoryServer()
          ..comic(_comic('remote'), legacy: legacy);
        final local = emptyFullReplaceSnapshot();
        final service = cloud.service(() => local);
        final plan = await service.preview();
        cloud.comic(_comic('late'), legacy: legacy, stamp: 2);
        final before = cloud.saved;
        await expectLater(
          service.commit(plan),
          throwsA(isA<FullCloudReplaceStale>()),
        );
        expect(cloud.saved, before);
        expect(cloud.writes, isEmpty);
        expect(cloud.ensureCalls, 0);
      },
    );
  }

  test(
    'same-list content changes are detected by digest, not merely directory names',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('before'));
      final local = emptyFullReplaceSnapshot();
      final service = cloud.service(() => local);
      final plan = await service.preview();
      cloud.comic(_comic('after'));
      await expectLater(
        service.commit(plan),
        throwsA(isA<FullCloudReplaceStale>()),
      );
      expect(cloud.writes, isEmpty);
    },
  );

  test(
    'local edits after preview require another preview and do not upload stale intent',
    () async {
      final cloud = FullReplaceMemoryServer();
      var local = emptyFullReplaceSnapshot(comic: _comic('before'));
      final service = cloud.service(() => local);
      final plan = await service.preview();
      local = emptyFullReplaceSnapshot(comic: _comic('after'));
      await expectLater(
        service.commit(plan),
        throwsA(isA<FullCloudReplaceStale>()),
      );
      expect(cloud.writes, isEmpty);
    },
  );

  test(
    'a future format in an inactive historical archive blocks the whole operation',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('valid'), stamp: 2);
      cloud.files[cloud.path('comic_1.bin')] = utf8.encode(
        jsonEncode({'version': 'future', 'favorites': []}),
      );
      await expectLater(
        cloud.service(emptyFullReplaceSnapshot).preview(),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(cloud.writes, isEmpty);
    },
  );

  test(
    'interrupted PUT is reported as partial and a new service can preview and retry its certified residue',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('remote'));
      final local = emptyFullReplaceSnapshot(comic: _comic('local'));
      final service = cloud.service(() => local);
      final plan = await service.preview();
      cloud.failPut = (p) => p.contains('/comic_');
      cloud.truncateFailedPut = true;
      await expectLater(
        service.commit(plan),
        throwsA(
          isA<FullCloudReplaceFailure>().having(
            (e) => e.mayHaveChanged,
            'partial',
            true,
          ),
        ),
      );
      cloud.failPut = null;
      final retry = cloud.service(() => local);
      final before = cloud.saved;
      final next = await retry.preview();
      expect(
        cloud.saved,
        before,
      ); // retry preview itself also never repairs cloud
      await retry.commit(next);
      expect(cloud.files.keys.where((p) => p.contains('/comic_')).length, 1);
    },
  );

  test(
    'journalled staging names do not bypass a decodable future-format gate',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('remote'));
      final service = cloud.service(emptyFullReplaceSnapshot);
      final plan = await service.preview();
      cloud.truncateFailedPut = true;
      cloud.failPut = (p) => p.contains('/comic_');
      await expectLater(
        service.commit(plan),
        throwsA(isA<FullCloudReplaceFailure>()),
      );
      final staged = cloud.files.keys.singleWhere(
        (p) => p.contains('/comic_') && !p.endsWith('/comic_1.bin'),
      );
      cloud.files[staged] = utf8.encode(
        jsonEncode({'version': 'future', 'favorites': []}),
      );
      final writes = cloud.writes.length;
      await expectLater(
        cloud.service(emptyFullReplaceSnapshot).preview(),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(cloud.writes.length, writes);
    },
  );

  test(
    'a content-addressed image interrupted PUT can be retried at its certified name',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('remote'));
      final local = _artworkSnapshot();
      final service = cloud.service(() => local);
      final plan = await service.preview();
      cloud.failPut = (p) => p.contains('/appearance_resource_');
      cloud.truncateFailedPut = true;
      await expectLater(
        service.commit(plan),
        throwsA(isA<FullCloudReplaceFailure>()),
      );
      expect(cloud.writes.where((p) => p.startsWith('delete:')), isEmpty);
      cloud.failPut = null;
      final retry = cloud.service(() => local);
      await retry.commit(await retry.preview());
      expect(
        cloud.files.keys.where((p) => p.contains('/appearance_resource_')),
        hasLength(1),
      );
      expect(cloud.files.values.any((bytes) => bytes.length == 3), false);
    },
  );

  test(
    'the explicit legacy capability rejects current roots, unowned files and nested paths',
    () {
      for (final path in [
        '${SyncArchiveContext.currentRoot}/comic_1.bin',
        '${SyncArchiveContext.legacyRoot}/protection.json',
        '${SyncArchiveContext.legacyRoot}/nested/comic_1.bin',
        '${SyncArchiveContext.legacyRoot}/../comic_1.bin',
      ]) {
        expect(
          () => validateFullReplaceLegacyPath(
            SyncArchiveContext.legacyReadOnly,
            path,
          ),
          throwsStateError,
        );
      }
      expect(
        validateFullReplaceLegacyPath(
          SyncArchiveContext.legacyReadOnly,
          '${SyncArchiveContext.legacyRoot}/comic_1.bin',
        ),
        '${SyncArchiveContext.legacyRoot}/comic_1.bin',
      );
    },
  );

  test(
    'partial old-root cleanup remains previewable and retryable without a legacy compatibility copy',
    () async {
      final cloud = FullReplaceMemoryServer()
        ..comic(_comic('legacy-only'), legacy: true);
      final local = emptyFullReplaceSnapshot();
      final service = cloud.service(() => local);
      final plan = await service.preview();
      cloud.failDelete = (p) => p.endsWith('comic_1.bin');
      await expectLater(
        service.commit(plan),
        throwsA(
          isA<FullCloudReplaceFailure>().having(
            (e) => e.mayHaveChanged,
            'partial',
            true,
          ),
        ),
      );
      // The old MD5 may already be gone; independently validated known snapshots
      // remain a valid destructive preview, without weakening ordinary sync.
      cloud.failDelete = null;
      final retry = cloud.service(() => local);
      await retry.commit(await retry.preview());
      expect(
        cloud.files.keys.where(
          (p) => p.startsWith('${SyncArchiveContext.legacyRoot}/'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'late device file during publication is kept and prevents old snapshot cleanup',
    () async {
      final cloud = FullReplaceMemoryServer()..comic(_comic('old'));
      final local = emptyFullReplaceSnapshot();
      final service = cloud.service(() => local);
      final plan = await service.preview();
      cloud.beforePut = (p) {
        cloud.beforePut = null;
        cloud.comic(_comic('late-device'), stamp: 9999999999999);
      };
      await expectLater(
        service.commit(plan),
        throwsA(
          isA<FullCloudReplaceFailure>().having(
            (e) => e.mayHaveChanged,
            'partial',
            true,
          ),
        ),
      );
      expect(cloud.files[cloud.path('comic_1.bin')], isNotNull);
      expect(cloud.files[cloud.path('comic_9999999999999.bin')], isNotNull);
      expect(cloud.writes.where((e) => e.startsWith('delete:')), isEmpty);
    },
  );

  test(
    'production capture includes retained removed-plugin settings with daily switches off, without changing installation or uploading local controls/downloads',
    () async {
      final dir = await Directory.systemTemp.createTemp('full-replace-images-');
      final images = LocalAppearanceImages(rootDirectory: dir);
      addTearDown(() async {
        images.paths.dispose();
        await dir.delete(recursive: true);
      });
      objectbox.pluginInfoBox.put(
        PluginInfo(
          uuid: 'removed-source',
          version: '1',
          originScript: 'fixture',
          insertedAt: DateTime.utc(2020),
          updatedAt: DateTime.utc(2025),
          isEnabled: false,
          isDeleted: true,
          lastLoadSuccess: false,
          debug: false,
        ),
      );
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: 'removed-source',
          config: '{"ui.displayName":"Retained"}',
        ),
      );
      objectbox.unifiedFavoriteBox.put(createTestFavorite('retained'));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CollectionCoverPrivacyController.enabledKey, true);
      await prefs.setString(
        'synthetic.download.absolutePath',
        '/private/download/file.mp4',
      );
      await images.save(
        LocalAppearanceImages.collectionCoverKey,
        Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
      );
      final folderKey = FolderCoverIdentity.comic('retained-folder');
      await images.save(
        folderKey,
        Uint8List.fromList(img.encodePng(img.Image(width: 9, height: 9))),
      );
      final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      final snapshot = await FullCloudLocalSnapshot.capture(
        const GlobalSettingState(),
        library: VideoLibraryStore(deviceId: 'fixture'),
        images: images,
      );
      expect(
        (snapshot.settings['pluginConfigs'] as List).single['name'],
        'removed-source',
      );
      expect(
        (snapshot.settings['pluginInfos'] as List).single['isDeleted'],
        true,
      );
      expect(objectbox.pluginInfoBox.getAll().single.isDeleted, true);
      expect(snapshot.resources, hasLength(2));
      expect(snapshot.appearance.toJson()['version'], 3);
      expect(snapshot.appearance.records, contains(folderKey));
      expect(
        snapshot.appearance.selection!.key,
        startsWith('collection-cover:'),
      );
      final serialized = jsonEncode([
        snapshot.comic,
        snapshot.settings,
        snapshot.video,
        snapshot.appearance.toJson(),
      ]);
      expect(
        serialized,
        isNot(contains(CollectionCoverPrivacyController.enabledKey)),
      );
      expect(serialized, isNot(contains('/private/download')));
      expect(serialized, isNot(contains(dir.path)));
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
      // Capture does not re-stamp an unchanged unjournalled observed preference.
      expect(
        (await FullCloudLocalSnapshot.capture(
          const GlobalSettingState(),
          library: VideoLibraryStore(deviceId: 'fixture'),
          images: images,
        )).fingerprint,
        snapshot.fingerprint,
      );
      // Use the real captured envelope with the production readers, including
      // checksum byte ordering and the folder-cover manifest format gate.
      final cloud = FullReplaceMemoryServer();
      final service = cloud.service(() => snapshot);
      await service.commit(await service.preview());
      expect(
        cloud.files.keys.where((p) => p.contains('/appearance_resource_')),
        hasLength(2),
      );
      expect(
        objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
        'retained',
      );
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
    },
  );

  for (final interruptedKind in ['comic_', 'appearance_resource_']) {
    test(
      'protected replacement preserves control/profile and recovers a partial encrypted $interruptedKind publication',
      () async {
        final cloud = FullReplaceMemoryServer()..comic(_comic('remote'));
        final raw = FullReplaceMemoryTransport(
          cloud,
          SyncArchiveContext.current,
        );
        final profiles = _Profiles();
        final owner = BackupProtectionManager(
          service: BackupProtectionService(deviceKeys: _NoKeys()),
          profileStore: profiles,
          operationRunner: (action) => action(),
        );
        final setup = await owner.create('synthetic full replacement password');
        await owner.confirmSetup(setup, setup.recoveryCode, trustDevice: false);
        await owner.enableCloud(raw);
        final control = base64Encode(
          cloud.files[cloud.path('protection.json')]!,
        );
        final profileBefore = jsonEncode(profiles.value!.toJson());
        final profileWrites = profiles.writes;
        final local = _artworkSnapshot();
        // Both encrypted structured payloads and content-addressed image residues
        // must recover without altering the protection controls or local profile.
        FullCloudReplaceService artworkService() {
          final protected = BackupProtectionSyncAdapter(raw, manager: owner);
          final adapter = ScopedSyncArchiveAdapter(
            protected,
            SyncArchiveContext.current,
            identity: 'protected-full-replace',
            legacyReader: cloud.adapters().legacyReader,
          );
          adapter.onInvalidate = protected.invalidateProtection;
          return cloud.service(() => local, adapter: adapter);
        }

        final first = artworkService();
        final plan = await first.preview();
        expect(profiles.writes, profileWrites);
        expect(jsonEncode(profiles.value!.toJson()), profileBefore);
        cloud.failPut = (p) => p.contains('/$interruptedKind');
        cloud.truncateFailedPut = true;
        await expectLater(
          first.commit(plan),
          throwsA(isA<FullCloudReplaceFailure>()),
        );
        expect(
          base64Encode(cloud.files[cloud.path('protection.json')]!),
          control,
        );
        cloud.failPut = null;
        final retry = artworkService();
        await retry.commit(await retry.preview());
        expect(
          base64Encode(cloud.files[cloud.path('protection.json')]!),
          control,
        );
        expect(profiles.writes, profileWrites);
        expect(jsonEncode(profiles.value!.toJson()), profileBefore);
        for (final e in cloud.files.entries.where(
          (e) => e.key.endsWith('.bin'),
        )) {
          expect(
            BackupProtectionService.isProtectedBytes(
              Uint8List.fromList(e.value),
            ),
            true,
          );
        }
      },
    );
  }
}
