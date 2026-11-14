import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/offline_backup_merge.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root;
  late LocalAppearanceImages images;
  late VideoLibraryStore videos;
  final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width: 16, height: 24)));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    root = await Directory.systemTemp.createTemp('folder-cover-');
    images = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'images')));
    videos = VideoLibraryStore(deviceId: 'test', storageKey: 'folder-cover.test.videos');
    await images.load();
  });
  tearDown(() async { videos.dispose(); images.paths.dispose(); await root.delete(recursive: true); });

  test('stable IDs isolate domains and same-named folders; rename and move retain artwork', () async {
    final a = ComicFolderService.createFolder('', 'A', ComicFolderType.favorite);
    final b = ComicFolderService.createFolder('', 'B', ComicFolderType.favorite);
    final nested = ComicFolderService.createFolder('/B', 'A', ComicFolderType.favorite);
    final key = FolderCoverIdentity.comic(a.syncId);
    expect(key, isNot(FolderCoverIdentity.comic(nested.syncId)));
    expect(key, isNot(FolderCoverIdentity.video(a.syncId)));
    final target = FolderCoverService.comic(a, images: images);
    final path = await target.save(bytes, images.revisionOf(key));
    ComicFolderService.renameFolder('/A', 'Renamed', ComicFolderType.favorite);
    expect(target.isCurrent(), isFalse);
    final renamed = objectbox.comicFolderBox.get(a.id)!;
    expect(FolderCoverIdentity.comic(renamed.syncId), key);
    ComicFolderService.batchMoveFolders({'/Renamed'}, '/B', ComicFolderType.favorite);
    expect(images.paths.value[key], path);
    expect(images.paths.value[FolderCoverIdentity.comic(b.syncId)], isNull);
  });

  test('identical-byte replacement still expires a pending reset and editor', () async {
    final folder = ComicFolderService.createFolder('', 'Folder', ComicFolderType.favorite);
    final target = FolderCoverService.comic(folder, images: images);
    await target.save(bytes, images.revisionOf(target.key));
    final old = images.revisionOf(target.key), path = images.paths.value[target.key];
    await target.save(bytes, old);
    expect(images.paths.value[target.key], path);
    expect(await target.restore(old), isFalse);
    await expectLater(target.save(bytes, old), throwsStateError);
    expect(images.paths.value[target.key], path);
  });

  test('video queue rejects the editor after rename or deletion', () async {
    final id = await videos.createFolder('source', 'Folder');
    final original = (await videos.read()).folders[id]!;
    final target = FolderCoverService.video(id, original, videos, images: images);
    await videos.renameFolder(id, 'Changed');
    await expectLater(target.save(bytes, 0), throwsStateError);
    expect(images.paths.value, isEmpty);
    final fresh = FolderCoverService.video(id, (await videos.read()).folders[id]!, videos, images: images);
    await fresh.save(bytes, 0);
    await videos.deleteFolder(id);
    await expectLater(fresh.restore(images.revisionOf(fresh.key)), throwsStateError);
    await FolderCoverService.reconcileDeleted(images: images, library: videos);
    expect(images.paths.value[fresh.key], isNull);
    final snapshot = await images.snapshotForSync();
    expect(snapshot.records[fresh.key]!.deleted, isTrue);
    await snapshot.dispose();
  });

  test('deleted comic folder cleans bytes while an unknown folder identity is retained', () async {
    final folder = ComicFolderService.createFolder('', 'Folder', ComicFolderType.favorite);
    final key = FolderCoverIdentity.comic(folder.syncId), unknown = FolderCoverIdentity.comic('not-arrived-yet');
    final path = await images.save(key, bytes);
    await images.save(unknown, bytes);
    ComicFolderService.deleteFolder('/Folder', ComicFolderType.favorite);
    await FolderCoverService.reconcileDeleted(images: images, library: videos);
    expect(images.paths.value[key], isNull);
    expect(await File(path).exists(), isFalse);
    expect(images.paths.value[unknown], isNotNull);
  });

  test('portable cloud manifest and backup keep the identity, bytes and revision without absolute paths', () async {
    final key = FolderCoverIdentity.video('legacy-stable-folder');
    await images.save(key, bytes);
    final snapshot = await images.snapshotForSync();
    final cloud = AppearanceSyncManifest(snapshot.records).toJson();
    expect(cloud['version'], 3);
    expect(AppearanceSyncManifest.fromBytes(utf8.encode(jsonEncode(cloud))).records.keys, contains(key));
    cloud['version'] = 2;
    expect(() => AppearanceSyncManifest.fromBytes(utf8.encode(jsonEncode(cloud))), throwsFormatException);
    await snapshot.dispose();
    final backup = Directory(p.join(root.path, 'backup'));
    await images.exportBackup(backup);
    final raw = await File(p.join(backup.path, 'appearance-local', 'manifest.json')).readAsString();
    expect(raw, isNot(contains(root.path)));
    expect(jsonDecode(raw)['version'], 2);
    SharedPreferences.setMockInitialValues({});
    final restored = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'restored')));
    final plan = await restored.prepareBackupRestore(backup);
    await plan!.activate(); await plan.finish(committed: true);
    expect(await File(restored.paths.value[key]!).readAsBytes(), await File(images.paths.value[key]!).readAsBytes());
    final recovered = await restored.snapshotForSync();
    expect(recovered.records[key]!.deleted, isFalse);
    await recovered.dispose();
    restored.paths.dispose();
    expect(const BackupImportOptions(importSettings: false, importPlugins: false).includesImage(key), isTrue);
  });
}
