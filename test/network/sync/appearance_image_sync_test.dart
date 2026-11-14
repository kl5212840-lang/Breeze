import 'dart:convert';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_identity.dart';

import '../../test_helper.dart';
import 'sync_installed_fixture.dart';

const source = '99999999-1111-4222-8333-444444444444';
const absent = '88888888-1111-4222-8333-444444444444';

class Cloud implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  final puts = <String>[];
  final gets = <String>[];
  bool failManifest = false;
  bool failDelete = false;
  Future<void> Function(String path)? afterUpload;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String path) async {
    gets.add(path);
    return files[path] ?? (throw StateError('404'));
  }

  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async =>
      throw StateError('not used');
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    puts.add(path);
    if (failManifest && appearanceManifestName.hasMatch(path.split('/').last)) {
      files[path] = bytes.take(10).toList();
      throw StateError('interrupted');
    }
    files[path] = List.of(bytes);
    await afterUpload?.call(path);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    if (failDelete) throw StateError('cleanup failed');
    for (final p in paths) {
      files.remove(p);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root;
  late LocalAppearanceImages images;
  late SyncPluginParticipation participation;
  final jpeg = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 2, height: 2)),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await installSyncPlugins([source]);
    participation = await SyncPluginParticipation.capture();
    root = await Directory.systemTemp.createTemp('appearance-sync-');
    images = LocalAppearanceImages(rootDirectory: root);
  });
  tearDown(() async {
    images.paths.dispose();
    await root.delete(recursive: true);
  });
  Future<void> sync(Cloud c, {bool global = true, bool plugins = true}) =>
      syncAppearanceImages(
        c,
        images: images,
        participation: participation,
        includeGlobal: global,
        includePlugins: plugins,
        includeFolders: global,
        deviceId: 'fixture',
      );
  Future<void> resolve(Cloud c, AppearanceGalleryResolver resolver) =>
      syncAppearanceImages(
        c,
        images: images,
        participation: participation,
        includeGlobal: true,
        includePlugins: true,
        deviceId: 'fixture',
        resolveGalleryConflict: resolver,
      );
  List<String> seedGallery(Cloud c) {
    final refs = <String, LocalAppearanceSyncRecord>{};
    for (var i = 0; i < 8; i++) {
      final image = img.Image(width: 2, height: 2)
        ..setPixelRgb(0, 0, i * 30, 0, 0);
      final bytes = img.encodeJpg(image);
      final digest = sha256.convert(bytes).toString();
      final key = 'collection-cover:$digest';
      refs[key] = LocalAppearanceSyncRecord(
        key: key,
        digest: digest,
        size: bytes.length,
        modifiedAt: 2,
        deleted: false,
      );
      c.files['${ComicSyncCore.syncRemoteRootName}/appearance_resource_$digest.bin'] =
          bytes;
    }
    final bytes = utf8.encode(
      jsonEncode(AppearanceSyncManifest(refs).toJson()),
    );
    c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'a').join()}_${sha256.convert(bytes)}.bin'] =
        bytes;
    return refs.keys.toList();
  }

  test(
    'content deduplicates; bytes precede refs; unchanged sync does not reread blobs',
    () async {
      await images.save('plugin-icon:$source', jpeg);
      await images.save('profile:$source', jpeg);
      final c = Cloud();
      await sync(c);
      expect(
        c.puts.where((p) => appearanceResourceName.hasMatch(p.split('/').last)),
        hasLength(1),
      );
      expect(
        appearanceResourceName.hasMatch(c.puts.first.split('/').last),
        isTrue,
      );
      final manifest = c.files.entries.singleWhere(
        (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
      );
      expect(utf8.decode(manifest.value), isNot(contains(root.path)));
      expect(
        AppearanceSyncManifest.fromBytes(manifest.value).records.length,
        2,
      );
      c.gets.clear();
      final count = c.puts.length;
      await sync(c);
      expect(c.puts.length, count);
      expect(
        c.gets.where((p) => appearanceResourceName.hasMatch(p.split('/').last)),
        isEmpty,
      );
    },
  );
  test(
    'scope excludes uninstalled plugin and independent selection alias',
    () async {
      await images.save('plugin-icon:$absent', jpeg);
      await images.saveCollectionCover(jpeg);
      final c = Cloud();
      await sync(c, global: false);
      expect(c.puts, isEmpty);
      await sync(c);
      final manifest = AppearanceSyncManifest.fromBytes(
        c.files.entries
            .singleWhere(
              (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
            )
            .value,
      );
      expect(manifest.records.keys.single, startsWith('collection-cover:'));
      final ref = manifest.records.values.single;
      expect(ref.key, 'collection-cover:${ref.digest}');
    },
  );
  test(
    'cross-device restores exact bytes; missing blob preserves local mapping',
    () async {
      await images.save('profile:$source', jpeg);
      final c = Cloud();
      await sync(c);
      final before = File(
        images.paths.value['profile:$source']!,
      ).readAsBytesSync();
      final secondRoot = await Directory.systemTemp.createTemp(
        'appearance-target-',
      );
      final target = LocalAppearanceImages(rootDirectory: secondRoot);
      try {
        // A separate mock preference store represents the other device.
        SharedPreferences.setMockInitialValues({});
        await syncAppearanceImages(
          c,
          images: target,
          participation: participation,
          includeGlobal: true,
          includePlugins: true,
          deviceId: 'second',
        );
        expect(
          await File(target.paths.value['profile:$source']!).readAsBytes(),
          before,
        );
        final mapping = {...target.paths.value};
        final key = c.files.keys.firstWhere(
          (p) => appearanceResourceName.hasMatch(p.split('/').last),
        );
        c.files.remove(key);
        // Missing local bytes cannot be turned into a remote deletion.
        await File(target.paths.value['profile:$source']!).delete();
        await expectLater(
          syncAppearanceImages(
            c,
            images: target,
            participation: participation,
            includeGlobal: true,
            includePlugins: true,
            deviceId: 'second',
          ),
          throwsFormatException,
        );
        expect(
          c.files.keys.where(
            (p) => appearanceManifestName.hasMatch(p.split('/').last),
          ),
          isNotEmpty,
        );
        expect(mapping, isNotEmpty);
      } finally {
        target.paths.dispose();
        await secondRoot.delete(recursive: true);
      }
    },
  );
  test(
    'interrupted new immutable manifest retains previous cloud refs and local image',
    () async {
      await images.save('profile:$source', jpeg);
      final c = Cloud();
      await sync(c);
      final old = c.files.keys
          .where((p) => appearanceManifestName.hasMatch(p.split('/').last))
          .single;
      final oldBytes = List<int>.of(c.files[old]!);
      await images.save('plugin-icon:$source', jpeg);
      final mapping = {...images.paths.value};
      c.failManifest = true;
      await expectLater(sync(c), throwsStateError);
      expect(c.files[old], oldBytes);
      expect(images.paths.value, mapping);
      c.failManifest = false;
      await sync(c);
    },
  );
  test(
    'two devices with more than seven distinct gallery images keep both manifests and publish nothing',
    () async {
      final c = Cloud();
      for (var device = 0; device < 2; device++) {
        final refs = <String, LocalAppearanceSyncRecord>{};
        for (var i = 0; i < 4; i++) {
          final digest = sha256.convert([device, i]).toString();
          final key = 'collection-cover:$digest';
          refs[key] = LocalAppearanceSyncRecord(
            key: key,
            digest: digest,
            size: 1,
            modifiedAt: 2,
            deleted: false,
          );
        }
        final bytes = utf8.encode(
          jsonEncode(AppearanceSyncManifest(refs).toJson()),
        );
        final id = List.filled(32, device == 0 ? 'a' : 'b').join();
        c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${id}_${sha256.convert(bytes)}.bin'] =
            bytes;
      }
      final before = c.files.map((k, v) => MapEntry(k, List<int>.of(v)));
      await expectLater(
        sync(c),
        throwsA(
          isA<AppearanceGalleryCapacityExceeded>().having(
            (e) => e.candidates.length,
            'candidates',
            8,
          ),
        ),
      );
      expect(c.puts, isEmpty);
      expect(c.files, before);
      expect(images.paths.value, isEmpty);
    },
  );
  test('folder artwork participates independently of settings and auto-sync never changes it', () async {
    final key = FolderCoverIdentity.video('folder-only');
    await images.save(key, jpeg);
    final cloud = Cloud();
    await syncAppearanceImages(cloud, images: images, participation: participation,
      includeGlobal: false, includePlugins: false, includeFolders: true,
      direction: SyncDirection.upload, deviceId: 'fixture');
    expect(cloud.puts, isNotEmpty);
    final before = Map<String, List<int>>.from(cloud.files), oldPath = images.paths.value[key];
    cloud.puts.clear();
    await syncAppearanceImages(cloud, images: images, participation: participation,
      includeGlobal: true, includePlugins: true, includeFolders: true,
      direction: SyncDirection.recordsOnly, deviceId: 'fixture', retiredFolderKeys: (_) async => {key});
    expect(cloud.puts, isEmpty);
    expect(cloud.files, before);
    expect(images.paths.value[key], oldPath);
  });

  test('retired folder cleanup waits for the record commit and cancellation leaves artwork intact', () async {
    final key = FolderCoverIdentity.comic('retired-folder');
    final path = await images.save(key, jpeg);
    final cloud = Cloud();
    var retirementChecks = 0;
    await expectLater(syncAppearanceImages(cloud, images: images, participation: participation,
      includeGlobal: false, includePlugins: false, includeFolders: true, deviceId: 'fixture',
      beforePublish: () async => throw StateError('record-write-failed'),
      retiredFolderKeys: (_) async { retirementChecks++; return {key}; }), throwsStateError);
    expect(retirementChecks, 0);
    expect(cloud.puts, isEmpty);
    expect(images.paths.value[key], path);
    expect(await File(path).exists(), isTrue);
    await syncAppearanceImages(cloud, images: images, participation: participation,
      includeGlobal: false, includePlugins: false, includeFolders: true, deviceId: 'fixture',
      retiredFolderKeys: (_) async => {key});
    expect(images.paths.value[key], isNull);
    expect(await File(path).exists(), isFalse);
    final manifest = cloud.files.entries.where((e) => appearanceManifestName.hasMatch(e.key.split('/').last)).map((e) => AppearanceSyncManifest.fromBytes(e.value)).first;
    expect(manifest.records[key]!.deleted, isTrue);
  });

  test('folder cover travels through the existing cloud blobs and portable identity', () async {
    final key = FolderCoverIdentity.comic('same-name-independent-stable-folder');
    final firstPath = await images.save(key, jpeg);
    final normalized = await File(firstPath).readAsBytes();
    final cloud = Cloud();
    await sync(cloud);
    final manifestPath = cloud.files.keys.firstWhere((path) => appearanceManifestName.hasMatch(path.split('/').last));
    expect(jsonDecode(utf8.decode(cloud.files[manifestPath]!))['version'], 3);
    expect(utf8.decode(cloud.files[manifestPath]!), isNot(contains(root.path)));
    final original = images;
    SharedPreferences.setMockInitialValues({});
    images = LocalAppearanceImages(rootDirectory: Directory('${root.path}/second-device'));
    await sync(cloud);
    final restored = images.paths.value[key]!;
    expect(restored, contains('second-device'));
    expect(restored, isNot(firstPath));
    expect(await File(restored).readAsBytes(), normalized);
    await images.remove(key);
    await sync(cloud);
    final latest = cloud.files.values.map((v) {
      try { return AppearanceSyncManifest.fromBytes(v); } catch (_) { return null; }
    }).whereType<AppearanceSyncManifest>().expand((m) => m.records.values).where((r) => r.key == key).toList();
    expect(latest.any((r) => r.deleted), isTrue);
    original.paths.dispose();
  });

  test(
    'future manifest and invalid absolute keys reject before writes',
    () async {
      for (final payload in [
        {'format': 'BreezeAppearanceImages', 'version': 4, 'entries': {}},
        {
          'format': 'BreezeAppearanceImages',
          'version': 1,
          'entries': {'/private/file.jpg': {}},
        },
      ]) {
        final c = Cloud();
        final bytes = utf8.encode(jsonEncode(payload));
        c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'a').join()}_${sha256.convert(bytes)}.bin'] =
            bytes;
        await expectLater(sync(c), throwsFormatException);
        expect(c.puts, isEmpty);
      }
    },
  );
  test(
    'verified publication followed by local conflict reports partial completion and retry preserves newer local image',
    () async {
      final c = Cloud();
      await images.save('profile:$source', jpeg);
      await sync(c);
      final remote = AppearanceSyncManifest.fromBytes(
        c.files.entries
            .singleWhere(
              (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
            )
            .value,
      ).records['profile:$source']!;
      // A remote revision requires a scoped local apply. Change local data only
      // after the new own publication, in the prepare -> activate window.
      final incoming = LocalAppearanceSyncRecord(
        key: remote.key,
        digest: remote.digest,
        size: remote.size,
        modifiedAt: remote.modifiedAt + 1,
        deleted: false,
      );
      final bytes = utf8.encode(
        jsonEncode(AppearanceSyncManifest({incoming.key: incoming}).toJson()),
      );
      c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'a').join()}_${sha256.convert(bytes)}.bin'] =
          bytes;
      final replacement = Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: 3, height: 3)..setPixelRgb(0, 0, 255, 0, 0),
        ),
      );
      c.afterUpload = (path) async {
        if (appearanceManifestName.hasMatch(path.split('/').last)) {
          c.afterUpload = null;
          await images.save('profile:$source', replacement);
        }
      };
      await expectLater(
        sync(c),
        throwsA(
          isA<AppearanceSyncIncomplete>()
              .having((e) => e.cloudManifestVerified, 'cloud verified', true)
              .having((e) => e.localApplied, 'local applied', false)
              .having((e) => e.cause, 'cause', isA<StateError>()),
        ),
      );
      final kept = await File(
        images.paths.value['profile:$source']!,
      ).readAsBytes();
      expect(kept, isNot(jpeg));
      await sync(c);
      expect(
        await File(images.paths.value['profile:$source']!).readAsBytes(),
        kept,
      );
    },
  );
  test(
    'cleanup failure does not block local apply; retry keeps two candidates and tombstone defeats old live refs',
    () async {
      await images.save('profile:$source', jpeg);
      final c = Cloud();
      await sync(c);
      final first = c.files.entries.singleWhere(
        (e) => appearanceManifestName.hasMatch(e.key.split('/').last),
      );
      final prefix = first.key.substring(0, first.key.lastIndexOf('_'));
      final row = AppearanceSyncManifest.fromBytes(
        first.value,
      ).records.values.single;
      // Additional complete own candidates simulate interrupted prior cleanup.
      for (var i = 1; i <= 2; i++) {
        final old = LocalAppearanceSyncRecord(
          key: row.key,
          digest: row.digest,
          size: row.size,
          modifiedAt: row.modifiedAt - i,
          deleted: false,
        );
        final bytes = utf8.encode(
          jsonEncode(AppearanceSyncManifest({old.key: old}).toJson()),
        );
        c.files['${prefix}_${sha256.convert(bytes)}.bin'] = bytes;
      }
      await images.remove('profile:$source');
      final icon = LocalAppearanceSyncRecord(
        key: 'plugin-icon:$source',
        digest: row.digest,
        size: row.size,
        modifiedAt: row.modifiedAt + 1,
        deleted: false,
      );
      final incoming = utf8.encode(
        jsonEncode(AppearanceSyncManifest({icon.key: icon}).toJson()),
      );
      c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'b').join()}_${sha256.convert(incoming)}.bin'] =
          incoming;
      c.failDelete = true;
      await expectLater(
        sync(c),
        throwsA(
          isA<AppearanceSyncIncomplete>()
              .having((e) => e.cloudManifestVerified, 'cloud verified', true)
              .having((e) => e.localApplied, 'local applied', true),
        ),
      );
      expect(images.paths.value.containsKey('profile:$source'), false);
      expect(images.paths.value.containsKey('plugin-icon:$source'), true);
      c.failDelete = false;
      await sync(c);
      final own = c.files.entries
          .where((e) => e.key.startsWith('${prefix}_'))
          .toList();
      expect(own, hasLength(2));
      expect(
        own.any(
          (e) => AppearanceSyncManifest.fromBytes(
            e.value,
          ).records[row.key]!.deleted,
        ),
        true,
      );
      await sync(c);
      expect(images.paths.value.containsKey('profile:$source'), false);
    },
  );
  test(
    'conflict previews are read-only and cancellation publishes nothing',
    () async {
      final c = Cloud();
      seedGallery(c);
      final before = c.files.map((k, v) => MapEntry(k, List<int>.of(v)));
      await expectLater(
        resolve(c, (conflict) async {
          expect(conflict.candidates, hasLength(8));
          expect(conflict.bytesByDigest, hasLength(8));
          expect(conflict.localKeys, isEmpty);
          expect(conflict.cloudKeys, hasLength(8));
          expect(c.puts, isEmpty);
          expect(images.paths.value, isEmpty);
          return null;
        }),
        throwsA(isA<AppearanceGalleryResolutionCancelled>()),
      );
      expect(c.files, before);
      expect(c.puts, isEmpty);
      expect(images.paths.value, isEmpty);
    },
  );
  test('bad or unreadable blob fails before conflict decision', () async {
    for (final inaccessible in [false, true]) {
      final c = Cloud();
      seedGallery(c);
      final blob = c.files.keys.firstWhere(
        (p) => appearanceResourceName.hasMatch(p.split('/').last),
      );
      if (inaccessible) {
        c.files.remove(blob);
      } else {
        c.files[blob] = [99];
      }
      var called = false;
      await expectLater(
        resolve(c, (conflict) async {
          called = true;
          return {};
        }),
        throwsA(isA<AppearanceGalleryPreviewUnavailable>()),
      );
      expect(called, false);
      expect(c.puts, isEmpty);
      expect(images.paths.value, isEmpty);
    }
  });
  test(
    'cloud or local edits while choosing invalidate the explicit decision before writes',
    () async {
      for (final editCloud in [false, true]) {
        final c = Cloud();
        final keys = seedGallery(c);
        await expectLater(
          resolve(c, (conflict) async {
            if (editCloud) {
              final bytes = utf8.encode(
                jsonEncode(AppearanceSyncManifest({}).toJson()),
              );
              c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'b').join()}_${sha256.convert(bytes)}.bin'] =
                  bytes;
            } else {
              await images.saveCollectionCover(jpeg);
            }
            return keys.take(7).toSet();
          }),
          throwsA(isA<AppearanceGalleryResolutionStale>()),
        );
        expect(c.puts, isEmpty);
        if (!editCloud) {
          expect(
            images.paths.value.keys.any(
              (k) => k.startsWith('collection-cover:'),
            ),
            true,
          );
        }
      }
    },
  );
  test(
    'explicit seven-image decision publishes tombstone; stale live manifest cannot resurrect discarded image',
    () async {
      final c = Cloud();
      final keys = seedGallery(c);
      // Use real JPEGs: the receiving service validates decoded image content
      // in addition to the transport's digest and length checks.
      await resolve(c, (conflict) async => keys.take(7).toSet());
      final own = c.files.entries
          .where((e) => appearanceManifestName.hasMatch(e.key.split('/').last))
          .map((e) => AppearanceSyncManifest.fromBytes(e.value))
          .singleWhere((m) => m.records[keys.last]!.deleted);
      expect(own.records.values.where((r) => !r.deleted), hasLength(7));
      final snapshot = await images.snapshotForSync();
      try {
        expect(snapshot.records[keys.last]!.deleted, true);
      } finally {
        await snapshot.dispose();
      }
      await sync(c);
      expect(images.paths.value.containsKey(keys.last), false);
    },
  );
  test(
    'oversized outbound history fails before PUT instead of poisoning future manifest preflight',
    () async {
      final c = Cloud();
      final refs = <String, LocalAppearanceSyncRecord>{};
      for (var i = 0; i < 256; i++) {
        final digest = sha256.convert(utf8.encode('deleted-$i')).toString();
        final key = 'collection-cover:$digest';
        refs[key] = LocalAppearanceSyncRecord(
          key: key,
          digest: digest,
          size: 1,
          modifiedAt: 1,
          deleted: true,
        );
      }
      final bytes = utf8.encode(
        jsonEncode(AppearanceSyncManifest(refs).toJson()),
      );
      final device = sha256
          .convert(utf8.encode('fixture'))
          .toString()
          .substring(0, 32);
      c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${device}_${sha256.convert(bytes)}.bin'] =
          bytes;
      await images.save('plugin-icon:$source', jpeg);
      await expectLater(sync(c), throwsFormatException);
      expect(c.puts, isEmpty);
    },
  );
  for (final direction in [SyncDirection.upload, SyncDirection.restore]) {
    test(
      'artwork $direction honors explicit direction rather than newer clocks',
      () async {
        await images.save('profile:$source', jpeg);
        final originalPath = images.paths.value['profile:$source']!;
        final localBytes = await File(originalPath).readAsBytes();
        final cloudBytes = Uint8List.fromList(
          img.encodeJpg(
            img.Image(width: 2, height: 2)..setPixelRgb(0, 0, 200, 50, 0),
          ),
        );
        final digest = sha256.convert(cloudBytes).toString();
        final c = Cloud();
        c.files['${ComicSyncCore.syncRemoteRootName}/appearance_resource_$digest.bin'] =
            cloudBytes;
        final row = LocalAppearanceSyncRecord(
          key: 'profile:$source',
          digest: digest,
          size: cloudBytes.length,
          modifiedAt: direction == SyncDirection.upload ? 8000000000000000 : 1,
          deleted: false,
        );
        final manifest = utf8.encode(
          jsonEncode(AppearanceSyncManifest({row.key: row}).toJson()),
        );
        c.files['${ComicSyncCore.syncRemoteRootName}/appearance_${List.filled(32, 'b').join()}_${sha256.convert(manifest)}.bin'] =
            manifest;
        await syncAppearanceImages(
          c,
          images: images,
          participation: participation,
          includeGlobal: true,
          includePlugins: true,
          deviceId: 'fixture',
          direction: direction,
        );
        final actual = await File(
          images.paths.value['profile:$source']!,
        ).readAsBytes();
        if (direction == SyncDirection.upload) {
          expect(actual, localBytes);
          expect(images.paths.value['profile:$source'], originalPath);
          final written = c.puts
              .where((p) => appearanceManifestName.hasMatch(p.split('/').last))
              .single;
          final chosen = AppearanceSyncManifest.fromBytes(
            c.files[written]!,
          ).records['profile:$source']!;
          expect(chosen.digest, sha256.convert(localBytes).toString());
          expect(chosen.modifiedAt, greaterThan(row.modifiedAt));
        } else {
          expect(actual, cloudBytes);
          expect(await File(originalPath).exists(), isFalse);
          expect(c.puts, isEmpty);
        }
      },
    );
  }

  test(
    'restore with absent cloud artwork preserves local mapping and selection',
    () async {
      await images.saveCollectionCover(jpeg);
      await images.save('profile:$source', jpeg);
      final before = Map<String, String>.from(images.paths.value);
      final c = Cloud();
      await syncAppearanceImages(
        c,
        images: images,
        participation: participation,
        includeGlobal: true,
        includePlugins: true,
        deviceId: 'fixture',
        direction: SyncDirection.restore,
      );
      expect(images.paths.value, before);
      expect(c.puts, isEmpty);
    },
  );
}
