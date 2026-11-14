import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../../test_helper.dart';
import 'sync_installed_fixture.dart';

const _source = '99999999-1111-4222-8333-444444444444';
const _other = '88888888-1111-4222-8333-444444444444';

class _Cloud implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  final writes = <String>[];

  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String path) async =>
      files[path] ?? (throw StateError('404'));
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('Not used by artwork sync');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    writes.add(path);
    files[path] = List.of(data);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    for (final path in paths) {
      writes.add(path);
      files.remove(path);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root;
  late LocalAppearanceImages images;
  final input = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 3, height: 2)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins([_source]);
    root = await Directory.systemTemp.createTemp('appearance-local-removal-');
    images = LocalAppearanceImages(
      rootDirectory: Directory(p.join(root.path, 'images')),
    );
  });
  tearDown(() async {
    images.paths.dispose();
    await root.delete(recursive: true);
  });

  Future<void> sync(_Cloud cloud) async {
    await syncAppearanceImages(
      cloud,
      images: images,
      participation: await SyncPluginParticipation.capture(),
      includeGlobal: true,
      includePlugins: true,
      deviceId: 'local-removal-fixture',
    );
  }

  Future<Map<String, Object?>> records() async {
    final snapshot = await images.snapshotForSync();
    try {
      return {
        for (final e in snapshot.records.entries) e.key: e.value.changeJson,
      };
    } finally {
      await snapshot.dispose();
    }
  }

  test('local-only removal keeps cloud artwork and reinstall imports it', () async {
    final icon = await images.savePluginIcon(_source, input);
    final background = await images.save('profile:$_source', input);
    final iconBytes = await File(icon).readAsBytes();
    final backgroundBytes = await File(background).readAsBytes();
    final other = await images.savePluginIcon(_other, input);
    final gallery = await images.saveCollectionCover(input);
    final cloud = _Cloud();
    await sync(cloud);
    final before = cloud.files.map(
      (key, bytes) => MapEntry(key, List.of(bytes)),
    );

    final local = LocalPluginInstallationState.instance;
    await local.setDataExclusions(
      _source,
      PluginDataScope.values.toSet(),
      beforeWrite: (_) async {},
    );
    await local.markRemoved(_source);
    final plan = await images.preparePluginDataRemoval(_source);
    await plan.activate();
    await plan.finish(committed: true);
    final afterRemoval = await records();
    expect(afterRemoval.containsKey('plugin-icon:$_source'), isFalse);
    expect(afterRemoval.containsKey('profile:$_source'), isFalse);
    expect(images.pluginIconPath(_other), other);
    expect(
      images.paths.value[LocalAppearanceImages.collectionCoverKey],
      gallery,
    );
    expect(await File(icon).exists(), isFalse);
    expect(await File(background).exists(), isFalse);

    // File backups record the local absence, not a newly invented cloud delete.
    final backup = Directory(p.join(root.path, 'backup'));
    await images.exportBackup(backup);
    final manifest =
        jsonDecode(
              await File(
                p.join(backup.path, 'appearance-local', 'manifest.json'),
              ).readAsString(),
            )
            as Map;
    for (final section in ['images', 'changes']) {
      expect(
        (manifest[section] as Map).containsKey('plugin-icon:$_source'),
        false,
      );
      expect((manifest[section] as Map).containsKey('profile:$_source'), false);
    }

    cloud.writes.clear();
    await sync(cloud);
    expect(cloud.writes, isEmpty);
    expect(cloud.files, before);
    expect(images.pluginIconPath(_source), isNull);
    expect(images.paths.value['profile:$_source'], isNull);

    // Existing record/account masks do not create an extra artwork restore gate.
    await local.completeExplicitInstallation(_source);
    expect(local.isDataExcluded(_source, PluginDataScope.records), isTrue);
    await sync(cloud);
    expect(cloud.files, before);
    expect(
      await File(images.pluginIconPath(_source)!).readAsBytes(),
      iconBytes,
    );
    expect(
      await File(images.paths.value['profile:$_source']!).readAsBytes(),
      backgroundBytes,
    );
  });

  test(
    'cleanup rollback restores exact prior artwork change records',
    () async {
      final saved = await images.savePluginIcon(_source, input);
      await images.save('profile:$_source', input);
      final before = await records();
      final plan = await images.preparePluginDataRemoval(_source);
      expect(images.pluginIconPath(_source), saved);
      expect(await records(), before, reason: 'preparation is read-only');
      await plan.activate();
      expect((await records()).containsKey('plugin-icon:$_source'), isFalse);
      await plan.rollback();
      await plan.finish(committed: false);
      expect(await records(), before);
      expect(images.pluginIconPath(_source), saved);
      expect(await File(saved).exists(), isTrue);
    },
  );

  test('late artwork replacement invalidates a prepared cleanup', () async {
    await images.savePluginIcon(_source, input);
    final plan = await images.preparePluginDataRemoval(_source);
    final replacement = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4, height: 3)),
    );
    final saved = await images.savePluginIcon(_source, replacement);
    await expectLater(plan.activate(), throwsStateError);
    await plan.finish(committed: false);
    expect(images.pluginIconPath(_source), saved);
    expect(await File(saved).exists(), isTrue);
  });

  test('late metadata revision also invalidates a prepared cleanup', () async {
    final saved = await images.savePluginIcon(_source, input);
    final plan = await images.preparePluginDataRemoval(_source);
    final snapshot = await images.snapshotForSync();
    try {
      final previous = snapshot.records['plugin-icon:$_source']!;
      final revised = LocalAppearanceSyncRecord(
        key: previous.key,
        digest: previous.digest,
        size: previous.size,
        modifiedAt: previous.modifiedAt + 1,
        deleted: false,
      );
      final incoming = await images.prepareSyncRestore(
        [revised],
        {previous.digest: await snapshot.readBytes(previous.key)},
      );
      await incoming.activate();
      await incoming.finish(committed: true);
      final before = await records();
      expect(images.pluginIconPath(_source), saved);
      await expectLater(plan.activate(), throwsStateError);
      await plan.finish(committed: false);
      expect(await records(), before);
    } finally {
      await snapshot.dispose();
    }
  });

  test(
    'ordinary image reset remains an explicit synchronized deletion',
    () async {
      final saved = await images.savePluginIcon(_source, input);
      final cloud = _Cloud();
      await sync(cloud);
      expect(await images.resetPluginIcon(_source, saved), isTrue);
      await sync(cloud);
      final manifests = cloud.files.entries
          .where((e) => appearanceManifestName.hasMatch(e.key.split('/').last))
          .map((e) => AppearanceSyncManifest.fromBytes(e.value));
      expect(
        manifests.any(
          (m) => m.records['plugin-icon:$_source']?.deleted == true,
        ),
        isTrue,
      );
      // A later bulk local clear also forgets this prior device-side deletion.
      final plan = await images.preparePluginDataRemoval(_source);
      await plan.activate();
      await plan.finish(committed: true);
      expect((await records()).containsKey('plugin-icon:$_source'), isFalse);
    },
  );

  test(
    'selection follows its stable key across devices without extra image bytes',
    () async {
      final first = await images.saveCollectionCover(input);
      final firstKey = images.collectionCovers.keys.single;
      await images.saveCollectionCover(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 5, height: 4))),
      );
      await images.selectCollectionCover(firstKey, first);
      final cloud = _Cloud();
      await sync(cloud);
      final manifestBytes = cloud.files.entries
          .singleWhere(
            (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
          )
          .value;
      final manifest = AppearanceSyncManifest.fromBytes(manifestBytes);
      expect(manifest.selection!.key, firstKey);
      expect(manifest.records.containsKey('collection-cover'), isFalse);
      expect(cloud.files.keys.where(isAppearanceResourcePath), hasLength(2));
      expect(utf8.decode(manifestBytes), isNot(contains(root.path)));

      SharedPreferences.setMockInitialValues({
        CollectionCoverPrivacyController.enabledKey: false,
      });
      final target = LocalAppearanceImages(
        rootDirectory: Directory(p.join(root.path, 'second')),
      );
      try {
        await syncAppearanceImages(
          cloud,
          images: target,
          participation: await SyncPluginParticipation.capture(),
          includeGlobal: true,
          includePlugins: true,
          deviceId: 'second',
        );
        expect(
          target.paths.value['collection-cover'],
          target.collectionCovers[firstKey],
        );
        expect(
          (await SharedPreferences.getInstance()).getBool(
            CollectionCoverPrivacyController.enabledKey,
          ),
          isFalse,
        );
        final previousUploads = cloud.writes.length;
        final otherKey = target.collectionCovers.keys.firstWhere(
          (key) => key != firstKey,
        );
        await target.selectCollectionCover(
          otherKey,
          target.collectionCovers[otherKey]!,
        );
        await syncAppearanceImages(
          cloud,
          images: target,
          participation: await SyncPluginParticipation.capture(),
          includeGlobal: true,
          includePlugins: true,
          deviceId: 'second',
        );
        expect(
          cloud.writes.skip(previousUploads).where(isAppearanceResourcePath),
          isEmpty,
        );
        await sync(cloud);
        expect(
          images.paths.value['collection-cover'],
          images.collectionCovers[otherKey],
        );
      } finally {
        target.paths.dispose();
      }
    },
  );

  test(
    'old manifest without selection preserves the current local image',
    () async {
      final first = await images.saveCollectionCover(input);
      final cloud = _Cloud();
      await sync(cloud);
      final legacy = AppearanceSyncManifest.fromBytes(
        cloud.files.entries
            .singleWhere(
              (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
            )
            .value,
      );
      cloud.files.removeWhere(
        (path, _) => appearanceManifestName.hasMatch(path.split('/').last),
      );
      final bytes = utf8.encode(
        jsonEncode({...AppearanceSyncManifest(legacy.records).toJson(), 'version': 1}),
      );
      cloud.files['${ComicSyncCore.syncRemoteRootName}/appearance_${'a' * 32}.bin'] =
          bytes;
      await sync(cloud);
      expect(images.paths.value['collection-cover'], first);
    },
  );

  test(
    'deleted selected image falls back and empty gallery clears selection',
    () async {
      await images.saveCollectionCover(input);
      final firstKey = images.collectionCovers.keys.single;
      final selectedPath = await images.saveCollectionCover(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 6, height: 4))),
      );
      final selectedKey = images.collectionCovers.keys.firstWhere(
        (key) => key != firstKey,
      );
      final cloud = _Cloud();
      await sync(cloud);
      await images.removeCollectionCover(selectedKey, selectedPath);
      await sync(cloud);
      final latest = cloud.files.entries
          .where((e) => appearanceManifestName.hasMatch(e.key.split('/').last))
          .map((e) => AppearanceSyncManifest.fromBytes(e.value))
          .reduce(
            (a, b) =>
                (a.selection?.modifiedAt ?? 0) > (b.selection?.modifiedAt ?? 0)
                ? a
                : b,
          );
      expect(latest.selection!.key, firstKey);
      expect(
        images.paths.value['collection-cover'],
        images.collectionCovers[firstKey],
      );
      await images.removeCollectionCover(
        firstKey,
        images.collectionCovers[firstKey]!,
      );
      await sync(cloud);
      expect(images.collectionCovers, isEmpty);
      expect(images.paths.value['collection-cover'], isNull);
    },
  );

  test(
    'late selection change is rejected by the restore version fence',
    () async {
      final first = await images.saveCollectionCover(input);
      final firstKey = images.collectionCovers.keys.single;
      await images.saveCollectionCover(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 7, height: 5))),
      );
      final before = await images.snapshotForSync();
      try {
        final alias = before.records['collection-cover']!;
        final plan = await images.prepareSyncRestore(
          [],
          {},
          expectedRecords: before.records,
          gallerySelection: AppearanceGallerySelection(
            key: firstKey,
            modifiedAt: alias.modifiedAt + 1,
          ),
        );
        await images.selectCollectionCover(firstKey, first);
        await expectLater(plan.activate(), throwsStateError);
        await plan.finish(committed: false);
        expect(images.paths.value['collection-cover'], first);
      } finally {
        await before.dispose();
      }
    },
  );

  test(
    'capacity decision that discards the selected image publishes a valid fallback',
    () async {
      final cloud = _Cloud();
      final rows = <String, LocalAppearanceSyncRecord>{};
      for (var i = 0; i < 8; i++) {
        final picture = img.Image(width: 2, height: 2)
          ..setPixelRgb(0, 0, i * 30, 0, 0);
        final bytes = img.encodeJpg(picture);
        final digest = sha256.convert(bytes).toString();
        final key = 'collection-cover:$digest';
        rows[key] = LocalAppearanceSyncRecord(
          key: key,
          digest: digest,
          size: bytes.length,
          modifiedAt: 2,
          deleted: false,
        );
        cloud.files['${ComicSyncCore.syncRemoteRootName}/appearance_resource_$digest.bin'] =
            bytes;
      }
      final selectedKey = rows.keys.last;
      final bytes = utf8.encode(
        jsonEncode(
          AppearanceSyncManifest(
            rows,
            selection: AppearanceGallerySelection(
              key: selectedKey,
              modifiedAt: 3,
            ),
          ).toJson(),
        ),
      );
      cloud.files['${ComicSyncCore.syncRemoteRootName}/appearance_${'b' * 32}_${sha256.convert(bytes)}.bin'] =
          bytes;
      await syncAppearanceImages(
        cloud,
        images: images,
        participation: await SyncPluginParticipation.capture(),
        includeGlobal: true,
        includePlugins: true,
        deviceId: 'local-removal-fixture',
        resolveGalleryConflict: (_) async => rows.keys.take(7).toSet(),
      );
      final newest = cloud.files.entries
          .where((e) => appearanceManifestName.hasMatch(e.key.split('/').last))
          .map((e) => AppearanceSyncManifest.fromBytes(e.value))
          .reduce(
            (a, b) =>
                (a.selection?.modifiedAt ?? 0) > (b.selection?.modifiedAt ?? 0)
                ? a
                : b,
          );
      expect(newest.selection!.key, isNot(selectedKey));
      expect(images.collectionCovers, hasLength(7));
      expect(
        images.paths.value['collection-cover'],
        images.collectionCovers[newest.selection!.key],
      );
      expect(newest.records[selectedKey]!.deleted, isTrue);
    },
  );
}
