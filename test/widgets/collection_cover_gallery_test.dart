import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/service/local_appearance_images.dart';

Uint8List _image(int shade) {
  final image = img.Image(width: 12, height: 18);
  img.fill(image, color: img.ColorRgb8(shade, 40, 70));
  return Uint8List.fromList(img.encodePng(image));
}

class _GalleryPreferences extends InMemorySharedPreferencesStore {
  _GalleryPreferences() : super.withData({});
  bool reject = false, block = false;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (block && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    if (reject) return false;
    return super.setValue(valueType, key, value);
  }
}

String _keyOf(String path) => LocalAppearanceImages.collectionImageKey(
  p.basename(path).substring(p.basename(path).length - 68, p.basename(path).length - 4));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LocalAppearanceImages store;
  late SharedPreferencesStorePlatform originalPreferences;
  setUp(() async {
    originalPreferences = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('breeze_cover_gallery_');
    store = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'owned')));
  });
  tearDown(() async {
    SharedPreferencesStorePlatform.instance = originalPreferences;
    SharedPreferences.resetStatic();
    store.paths.dispose();
    await temporary.delete(recursive: true);
  });

  test('old single image upgrades in place; gallery stays bounded and selectable', () async {
    final old = await store.save('collection-cover', _image(10));
    final legacyPreferences = await SharedPreferences.getInstance();
    await legacyPreferences.setString(LocalAppearanceImages.preferencesKey,
      jsonEncode({'collection-cover': p.basename(old)}));
    await store.load();
    expect(store.collectionCovers, {_keyOf(old): old});
    for (var index = 2; index <= 7; index++) {
      await store.saveCollectionCover(_image(index * 20));
    }
    expect(store.collectionCovers.length, 7);
    final before = {...store.paths.value};
    await expectLater(store.saveCollectionCover(_image(250)), throwsStateError);
    expect(store.paths.value, before);
    expect(await store.selectCollectionCover(_keyOf(old), old), isTrue);
    expect(store.paths.value['collection-cover'], old);
    expect(await File(old).exists(), isTrue);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(LocalAppearanceImages.preferencesKey)!;
    expect(raw, isNot(contains(temporary.path)));
    expect((jsonDecode(raw) as Map).length, 9); // Images, selected alias and changes.
  });

  test('replacement updates selected alias; stale delete/replacement preserves new image', () async {
    final first = await store.saveCollectionCover(_image(10));
    final replacement = await store.saveCollectionCover(_image(100),
      key: _keyOf(first), expectedPath: first);
    expect(store.paths.value['collection-cover'], replacement);
    expect(await File(first).exists(), isFalse);
    expect(await store.removeCollectionCover(_keyOf(first), first), isFalse);
    await expectLater(store.saveCollectionCover(_image(200),
      key: _keyOf(first), expectedPath: first), throwsStateError);
    expect(store.paths.value['collection-cover'], replacement);
    expect(await File(replacement).exists(), isTrue);
  });

  test('delete selected picks retained image; final delete leaves safe empty selection', () async {
    final first = await store.saveCollectionCover(_image(10));
    final second = await store.saveCollectionCover(_image(80));
    final third = await store.saveCollectionCover(_image(160));
    expect(await store.removeCollectionCover(_keyOf(third), third), isTrue);
    expect(store.paths.value['collection-cover'], first);
    expect(await store.removeCollectionCover(_keyOf(second), second), isTrue);
    expect(store.paths.value['collection-cover'], first);
    expect(await File(first).exists(), isTrue);
    expect(await store.removeCollectionCover(_keyOf(first), first), isTrue);
    expect(store.paths.value, isEmpty);
    expect(await File(first).exists(), isFalse);
  });

  test('queued add checks limit when committing rather than when picker opens', () async {
    for (var index = 1; index <= 6; index++) {
      await store.saveCollectionCover(_image(index * 20));
    }
    final one = store.saveCollectionCover(_image(170));
    final two = store.saveCollectionCover(_image(190));
    final rejected = expectLater(two, throwsStateError);
    await one;
    await rejected;
    expect(store.collectionCovers.length, 7);
  });

  test('failed gallery write retains image bytes, selection and reusable capacity', () async {
    final preferences = _GalleryPreferences();
    SharedPreferencesStorePlatform.instance = preferences;
    SharedPreferences.resetStatic();
    final first = await store.saveCollectionCover(_image(20));
    final before = {...store.paths.value};
    preferences.reject = true;
    try {
      await expectLater(store.saveCollectionCover(_image(200),
        key: _keyOf(first), expectedPath: first), throwsA(isA<FileSystemException>()));
      await expectLater(store.removeCollectionCover(_keyOf(first), first),
        throwsA(isA<FileSystemException>()));
      expect(store.paths.value, before);
      expect(await File(first).exists(), isTrue);
      expect(Directory(p.dirname(first)).listSync().whereType<File>().length, 1);
    } finally {
      preferences.reject = false;
    }
    await store.saveCollectionCover(_image(100));
    expect(store.collectionCovers.length, 2);
  });

  test('a queued editor reply cannot commit after its host disappears', () async {
    final preferences = _GalleryPreferences();
    SharedPreferencesStorePlatform.instance = preferences;
    SharedPreferences.resetStatic();
    await store.saveCollectionCover(_image(20));
    preferences.block = true;
    final inFlight = store.saveCollectionCover(_image(70));
    await preferences.started.future;
    var active = true;
    final expired = store.saveCollectionCover(_image(140), canCommit: () => active);
    final rejected = expectLater(expired, throwsStateError);
    active = false;
    preferences.release.complete();
    await inFlight;
    await rejected;
    expect(store.collectionCovers.length, 2);
  });

  test('portable gallery backup restores bytes and selection under a different root', () async {
    final first = await store.saveCollectionCover(_image(20));
    await store.saveCollectionCover(_image(90));
    await store.selectCollectionCover(_keyOf(first), first);
    final backup = Directory(p.join(temporary.path, 'backup'));
    await backup.create();
    await store.exportBackup(backup);
    final target = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'other-device')));
    addTearDown(target.paths.dispose);
    final plan = (await target.prepareBackupRestore(backup))!;
    await plan.activate();
    await plan.finish(committed: true);
    expect(target.collectionCovers.length, 2);
    final selected = target.paths.value['collection-cover']!;
    expect(selected, target.collectionCovers[_keyOf(first)]);
    expect(p.dirname(selected), endsWith('other-device'));
    expect(await File(selected).readAsBytes(), await File(first).readAsBytes());
    final manifest = jsonDecode(await File(p.join(backup.path, 'appearance-local', 'manifest.json')).readAsString()) as Map;
    expect((manifest['images'] as Map).length, 3);
    expect(Directory(p.join(backup.path, 'appearance-local')).listSync().length, 3);
  });

  test('missing current gallery image falls back to retained image without exposing a path', () async {
    final first = await store.saveCollectionCover(_image(20));
    final missing = await store.saveCollectionCover(_image(90));
    await File(missing).delete();
    await store.load();
    expect(store.collectionCovers, {_keyOf(first): first});
    expect(store.paths.value['collection-cover'], first);
  });
  test('sync snapshot pins immutable bytes through replacement until disposed', () async {
    final first = await store.saveCollectionCover(_image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[_keyOf(first)]!;
    expect(record.deleted, isFalse);
    expect(record.file, first);
    expect(record.changeJson.keys, isNot(contains('file')));
    final bytes = await snapshot.readBytes(record.key);
    await store.saveCollectionCover(_image(170),
      key: record.key, expectedPath: first);
    expect(await File(first).exists(), isTrue);
    expect(await snapshot.readBytes(record.key), bytes);
    await snapshot.dispose();
    await snapshot.dispose();
    expect(await File(first).exists(), isFalse);
    await expectLater(snapshot.readBytes(record.key), throwsStateError);
  });

  test('explicit removal persists tombstone; missing bytes remain live after reload', () async {
    final first = await store.saveCollectionCover(_image(20));
    final second = await store.saveCollectionCover(_image(100));
    await File(second).delete();
    await store.load();
    final missing = await store.snapshotForSync();
    expect(missing.records[_keyOf(second)]!.deleted, isFalse);
    expect(missing.records[_keyOf(second)]!.file, isNull);
    await missing.dispose();
    expect(await store.removeCollectionCover(_keyOf(first), first), isTrue);
    await store.load();
    final removed = await store.snapshotForSync();
    expect(removed.records[_keyOf(first)]!.deleted, isTrue);
    expect(removed.records[_keyOf(second)]!.deleted, isFalse);
    await removed.dispose();
  });

  test('scoped sync preserves omitted artwork and applies portable timestamps', () async {
    const a = 'profile:11111111-1111-4111-8111-111111111111';
    const b = 'profile:22222222-2222-4222-8222-222222222222';
    await store.save(a, _image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[a]!;
    final bytes = await snapshot.readBytes(a);
    final target = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'target')));
    addTearDown(target.paths.dispose);
    final kept = await target.save(b, _image(170));
    final plan = await target.prepareSyncRestore([record], {record.digest: bytes});
    final proof = plan.recoveryMapping;
    await plan.activate();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAppearanceImages.preferencesKey), proof);
    expect(target.paths.value[b], kept);
    expect(await File(target.paths.value[a]!).readAsBytes(), bytes);
    final imported = await target.snapshotForSync();
    expect(imported.records[a]!.modifiedAt, record.modifiedAt);
    await imported.dispose();
    await plan.finish(committed: true);
    await snapshot.dispose();
  });

  test('prepared sync refuses intervening writes before publishing any references', () async {
    final first = await store.saveCollectionCover(_image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[_keyOf(first)]!;
    final tombstone = LocalAppearanceSyncRecord(key: record.key,
      digest: record.digest, size: record.size,
      modifiedAt: record.modifiedAt + 1, deleted: true);
    final plan = await store.prepareSyncRestore([tombstone], {});
    final replacement = await store.saveCollectionCover(_image(180),
      key: record.key, expectedPath: first);
    await expectLater(plan.activate(), throwsStateError);
    expect(store.paths.value['collection-cover'], replacement);
    await plan.finish(committed: false);
    await snapshot.dispose();
  });

  test('invalid sync bytes fail preparation and leave both metadata and image unchanged', () async {
    final first = await store.saveCollectionCover(_image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[_keyOf(first)]!;
    final before = {...store.paths.value};
    await expectLater(store.prepareSyncRestore([record], {
      record.digest: _image(200),
    }), throwsFormatException);
    expect(store.paths.value, before);
    final after = await store.snapshotForSync();
    expect(after.records[record.key]!.changeJson, record.changeJson);
    await after.dispose();
    await snapshot.dispose();
  });

  test('sync rollback restores timestamps and tombstones as well as file mapping', () async {
    final first = await store.saveCollectionCover(_image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[_keyOf(first)]!;
    final tombstone = LocalAppearanceSyncRecord(key: record.key,
      digest: record.digest, size: record.size,
      modifiedAt: record.modifiedAt + 1, deleted: true);
    final plan = await store.prepareSyncRestore([tombstone], {});
    await plan.activate();
    expect(store.paths.value, isEmpty);
    await plan.rollback();
    await plan.finish(committed: false);
    final restored = await store.snapshotForSync();
    expect(restored.records[record.key]!.changeJson, record.changeJson);
    expect(restored.records[record.key]!.file, isNotNull);
    await restored.dispose();
    await snapshot.dispose();
  });

  test('sync selection resolves digest to the matching image and avoids duplicate files', () async {
    await store.saveCollectionCover(_image(20));
    final selectedPath = await store.saveCollectionCover(_image(170));
    final snapshot = await store.snapshotForSync();
    final bytes = <String, Uint8List>{};
    for (final record in snapshot.records.values) {
      bytes[record.digest] = await snapshot.readBytes(record.key);
    }
    final target = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'selection-target')));
    addTearDown(target.paths.dispose);
    final plan = await target.prepareSyncRestore(snapshot.records.values, bytes);
    await plan.activate();
    await plan.finish(committed: true);
    expect(target.paths.value['collection-cover'], target.paths.value[_keyOf(selectedPath)]);
    expect(Directory(p.join(temporary.path, 'selection-target')).listSync().length, 2);
    await snapshot.dispose();
  });

  test('file backup retains explicit removals and original modification times', () async {
    final first = await store.saveCollectionCover(_image(20));
    final second = await store.saveCollectionCover(_image(170));
    await store.removeCollectionCover(_keyOf(first), first);
    final snapshot = await store.snapshotForSync();
    final backup = Directory(p.join(temporary.path, 'metadata-backup'));
    await store.exportBackup(backup);
    final target = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'metadata-target')));
    addTearDown(target.paths.dispose);
    final plan = (await target.prepareBackupRestore(backup))!;
    final proof = plan.recoveryMapping;
    await plan.activate();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAppearanceImages.preferencesKey), proof);
    await plan.finish(committed: true);
    final restored = await target.snapshotForSync();
    expect(restored.records[_keyOf(first)]!.deleted, isTrue);
    expect(restored.records[_keyOf(second)]!.changeJson,
      snapshot.records[_keyOf(second)]!.changeJson);
    await restored.dispose();
    await snapshot.dispose();
  });

  test('same artwork is one content identity and replacement tombstones the old image', () async {
    final first = await store.saveCollectionCover(_image(20));
    expect(await store.saveCollectionCover(_image(20)), first);
    expect(store.collectionCovers.length, 1);
    final replacement = await store.saveCollectionCover(_image(170),
      key: _keyOf(first), expectedPath: first);
    expect(store.collectionCovers, {_keyOf(replacement): replacement});
    final snapshot = await store.snapshotForSync();
    expect(snapshot.records[_keyOf(first)]!.deleted, isTrue);
    expect(snapshot.records[_keyOf(replacement)]!.deleted, isFalse);
    await snapshot.dispose();
  });

  test('network snapshot guard rejects an edit made before prepare', () async {
    final first = await store.saveCollectionCover(_image(20));
    final snapshot = await store.snapshotForSync();
    final record = snapshot.records[_keyOf(first)]!;
    final replacement = await store.saveCollectionCover(_image(170),
      key: record.key, expectedPath: first);
    await expectLater(store.prepareSyncRestore([record], {
      record.digest: await snapshot.readBytes(record.key),
    }, expectedRecords: snapshot.records), throwsStateError);
    expect(store.collectionCovers, {_keyOf(replacement): replacement});
    await snapshot.dispose();
  });

  test('independent device additions keep distinct keys; eighth live image rejects atomically', () async {
    final local = await store.saveCollectionCover(_image(5));
    SharedPreferences.setMockInitialValues({});
    final donor = LocalAppearanceImages(rootDirectory: Directory(p.join(temporary.path, 'donor')));
    addTearDown(donor.paths.dispose);
    for (var index = 1; index <= 7; index++) {
      await donor.saveCollectionCover(_image(index * 25));
    }
    final snapshot = await donor.snapshotForSync();
    final records = snapshot.records.values.where((record) => record.key != 'collection-cover');
    expect(records.every((record) => record.key == LocalAppearanceImages.collectionImageKey(record.digest)), isTrue);
    expect(records.any((record) => record.key == _keyOf(local)), isFalse);
    final bytes = <String, Uint8List>{};
    for (final record in records) {
      bytes[record.digest] = await snapshot.readBytes(record.key);
    }
    await expectLater(store.prepareSyncRestore(records, bytes), throwsStateError);
    expect(store.collectionCovers, {_keyOf(local): local});
    await snapshot.dispose();
  });

  test('unpublished numbered gallery upgrades to content identities on load and backup', () async {
    final first = await store.saveCollectionCover(_image(20));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(LocalAppearanceImages.preferencesKey,
      jsonEncode({'collection-cover': p.basename(first), 'collection-cover:1': p.basename(first)}));
    await store.load();
    expect(store.collectionCovers, {_keyOf(first): first});
    final snapshot = await store.snapshotForSync();
    expect(snapshot.records.keys, isNot(contains('collection-cover:1')));
    expect(snapshot.records[_keyOf(first)]!.deleted, isFalse);
    await snapshot.dispose();
    final backup = Directory(p.join(temporary.path, 'legacy-migrated'));
    await store.exportBackup(backup);
    final manifest = jsonDecode(await File(p.join(backup.path, 'appearance-local', 'manifest.json')).readAsString()) as Map;
    expect((manifest['images'] as Map).keys, contains(_keyOf(first)));
    expect((manifest['images'] as Map).keys, isNot(contains('collection-cover:1')));
  });

}
