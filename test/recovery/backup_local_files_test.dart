import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/local_appearance_images.dart';

import '../test_helper.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

Uint8List _jpeg(int red) {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(red, 0, 0));
  return Uint8List.fromList(img.encodeJpg(image));
}
final _mp4 = <int>[0,0,0,24,102,116,121,112,105,115,111,109,0,0,0,0,105,115,111,109,109,112,52,50,0,0,0,8,109,100,97,116];
final _page = Uri.parse('https://video.fixture/watch?v=1');
const _icon = 'plugin-icon:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _hanime = '1e600cff-8ebe-4517-8aa4-6678aec46424';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late Directory root, extract, downloads;
  late LocalAppearanceImages images;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    root = await Directory.systemTemp.createTemp('breeze_backup_local_files_');
    extract = await Directory(p.join(root.path, 'extract')).create();
    downloads = await Directory(p.join(root.path, 'files', 'downloads')).create(recursive: true);
    images = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'target-images')));
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    await File(p.join(downloads.path, 'keep.txt')).writeAsString('local download');
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });
  Future<void> metadata(bool include) async {
    await File(p.join(extract.path, 'config.json')).writeAsString(jsonEncode({'includeDownloads': include}));
    final raw = jsonDecode(objectbox.collectAllDataJson(removeIds: true)) as Map<String, dynamic>;
    raw['unifiedComicFavorite'] = [(createTestFavorite('incoming:favorite')..schemaVersion = 2).toJson()..remove('id')];
    await File(p.join(extract.path, 'objectbox.json')).writeAsString(jsonEncode(raw));
  }
  Future<Map<String, dynamic>> video(
    Directory target, {
    bool present = true,
    String source = 'fixture',
    Uri? page,
  }) async {
    final directory = await Directory(p.join(target.path, 'video-v1')).create(recursive: true);
    final watch = page ?? _page;
    final id = VideoLocalResources.identity(source, watch, 'HD');
    final index = {'format': 'breeze-local-video', 'version': 1, 'resources': [
      {'resourceId': id, 'source': source, 'url': watch.toString(), 'title': 'Fixture',
        'quality': 'HD', 'bytes': _mp4.length, 'taskKey': 'fixture-task', 'showTask': true, 'at': 1000},
    ]};
    await File(p.join(directory.path, 'index.json')).writeAsString(jsonEncode(index));
    if (present) await File(p.join(directory.path, '$id.mp4')).writeAsBytes(_mp4);
    return index;
  }
  BackupImportHooks hook({void Function()? beforeCommit}) => BackupImportHooks(
    downloadDirectory: downloads, appearanceImages: images, beforeCommit: beforeCommit);
  Future<void> artistSidecar(String id) =>
      File(p.join(extract.path, 'downloaded-video-artists.json')).writeAsString(
        jsonEncode({
          'format': 'breeze-downloaded-video-artists',
          'version': 1,
          'artists': {id: 'Verified artist'},
        }),
      );

  final artistWatch = Uri.parse('https://hanime1.me/watch?v=42');
  final artistId = VideoLocalResources.identity(_hanime, artistWatch, 'HD');
  for (final mode in [BackupImportMode.merge, BackupImportMode.restore]) {
    test('including downloads retains exact verified artist in ${mode.name}', () async {
      await metadata(true);
      await video(
        Directory(p.join(extract.path, 'downloads')),
        source: _hanime,
        page: artistWatch,
      );
      await artistSidecar(artistId);
      await importExtractedBreezeData(
        extract.path,
        mode: mode,
        restoreDownloadFiles: true,
        hooks: hook(),
      );
      final rows = await VideoLocalResources.read(fresh: true);
      final saved = await VideoDownloadedDetails.captureBackupArtists(rows);
      expect(saved, {artistId: 'Verified artist'});
      expect(rows.single['available'], isTrue);
    });
  }

  test('artist file is ignored when restoring without downloads', () async {
    await metadata(false);
    await artistSidecar(artistId);
    await importExtractedBreezeData(
      extract.path,
      mode: BackupImportMode.restore,
      restoreDownloadFiles: true,
      hooks: hook(),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(VideoDownloadedDetails.durableStorageKey), isNull);
  });

  test('artist must identify a physical Hanime file in the incoming archive', () async {
    await metadata(true);
    await video(downloads, source: _hanime, page: artistWatch);
    await video(
      Directory(p.join(extract.path, 'downloads')),
      source: _hanime,
      page: artistWatch,
      present: false,
    );
    await artistSidecar(artistId);
    await expectLater(
      importExtractedBreezeData(
        extract.path,
        mode: BackupImportMode.merge,
        restoreDownloadFiles: true,
        hooks: hook(),
      ),
      throwsA(isA<BackupCompatibilityException>()),
    );
    expect((await VideoLocalResources.read(fresh: true)).single['available'], isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(VideoDownloadedDetails.durableStorageKey), isNull);
  });

  test('failed file restore also rolls back its artist metadata', () async {
    await metadata(true);
    await video(
      Directory(p.join(extract.path, 'downloads')),
      source: _hanime,
      page: artistWatch,
    );
    await artistSidecar(artistId);
    await expectLater(
      importExtractedBreezeData(
        extract.path,
        mode: BackupImportMode.restore,
        restoreDownloadFiles: true,
        hooks: hook(beforeCommit: () => throw StateError('rollback fixture')),
      ),
      throwsA(isA<BackupRestoreIncomplete>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(VideoDownloadedDetails.durableStorageKey), isNull);
    expect(await File(p.join(downloads.path, 'keep.txt')).exists(), isTrue);
  });

  for (final include in [false, true]) {
    test('active local reader ${include ? 'blocks download replacement before changes' : 'does not block settings-only restore'}', () async {
      await metadata(include);
      await video(downloads);
      if (include) await video(Directory(p.join(extract.path, 'downloads')));
      final id = VideoLocalResources.identity('fixture', _page, 'HD');
      final session = await VideoLocalResources.playback(id);
      final lease = VideoLocalResources.acquireReadLease(session.sources.single.url, id);
      final before = objectbox.collectAllDataJson(removeIds: false);
      try {
        if (include) {
          await expectLater(importExtractedBreezeData(extract.path, mode: BackupImportMode.restore,
            restoreDownloadFiles: true, hooks: hook()), throwsA(isA<ManagedVideoResourceBusy>()));
          expect(objectbox.collectAllDataJson(removeIds: false), before);
          expect(await File(p.join(downloads.path, 'keep.txt')).readAsString(), 'local download');
        } else {
          await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore,
            restoreDownloadFiles: true, hooks: hook());
          expect(objectbox.unifiedFavoriteBox.getAll().single.uniqueKey, 'incoming:favorite');
          expect(await File(p.join(downloads.path, 'keep.txt')).readAsString(), 'local download');
        }
      } finally { lease.release(); }
    });
  }

  test('excluding downloads preserves local managed media and index and ignores incoming download files', () async {
    await metadata(false);
    await video(downloads);
    final localIndex = await File(p.join(downloads.path, 'video-v1', 'index.json')).readAsString();
    final incoming = await Directory(p.join(extract.path, 'downloads', 'video-v1')).create(recursive: true);
    await File(p.join(incoming.path, 'index.json')).writeAsString('{"version":99}');
    final before = VideoLocalResources.changes.value;
    await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true, hooks: hook());
    expect(await File(p.join(downloads.path, 'video-v1', 'index.json')).readAsString(), localIndex);
    expect((await VideoLocalResources.read(fresh: true)).single['available'], isTrue);
    expect(VideoLocalResources.changes.value, before);
  });

  test('including downloads restores real managed media and refreshes actual offline availability', () async {
    await metadata(true);
    await video(Directory(p.join(extract.path, 'downloads')));
    final before = VideoLocalResources.changes.value;
    await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true, hooks: hook());
    final rows = await VideoLocalResources.read(fresh: true);
    expect(rows.single['available'], isTrue);
    expect(rows.single['taskKey'], 'fixture-task');
    expect(VideoLocalResources.changes.value, before + 1);
    expect(objectbox.unifiedFavoriteBox.getAll().single.schemaVersion, 2);
  });

  test('an index entry without its media remains unavailable after a fresh-device restore', () async {
    await metadata(true);
    await video(Directory(p.join(extract.path, 'downloads')), present: false);
    await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true, hooks: hook());
    expect((await VideoLocalResources.read(fresh: true)).single['available'], isFalse);
    await expectLater(VideoLocalResources.playback(VideoLocalResources.identity('fixture', _page, 'HD')), throwsA(isA<FileSystemException>()));
  });

  for (final damage in ['version', 'id', 'bytes', 'temporary', 'unlisted', 'link']) {
    test('invalid managed-video $damage is rejected before changing local files or database', () async {
      await metadata(true);
      final source = Directory(p.join(extract.path, 'downloads'));
      final index = await video(source);
      final directory = Directory(p.join(source.path, 'video-v1'));
      final row = (index['resources'] as List).single as Map;
      if (damage == 'version') index['version'] = 99;
      if (damage == 'id') row['resourceId'] = '../outside';
      if (damage == 'bytes') row['bytes'] = 999;
      if (damage == 'unlisted') await File(p.join(directory.path, '${List.filled(64, 'b').join()}.mp4')).writeAsBytes(_mp4);
      if (damage == 'temporary') await File(p.join(directory.path, '.transfer.partial')).writeAsString('temporary');
      if (damage == 'link') {
        final media = File(p.join(directory.path, '${row['resourceId']}.mp4'));
        await media.delete();
        await Link(media.path).create(p.join(downloads.path, 'keep.txt'));
      }
      await File(p.join(directory.path, 'index.json')).writeAsString(jsonEncode(index));
      final db = objectbox.collectAllDataJson(removeIds: true), before = VideoLocalResources.changes.value;
      await expectLater(importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true, hooks: hook()), throwsA(isA<BackupCompatibilityException>()));
      expect(objectbox.collectAllDataJson(removeIds: true), db);
      expect(await File(p.join(downloads.path, 'keep.txt')).readAsString(), 'local download');
      expect(VideoLocalResources.changes.value, before);
    });
  }

  test('local icon artwork restores even without downloads and does not carry an old device path', () async {
    await metadata(false);
    final source = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'source-images')));
    await source.save(_icon, _jpeg(220));
    await source.exportBackup(extract);
    await images.save(_icon, _jpeg(40));
    await importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, hooks: hook());
    final restored = images.paths.value[_icon]!;
    expect(p.isWithin(p.join(root.path, 'target-images'), restored), isTrue);
    expect(await File(restored).exists(), isTrue);
    final manifest = await File(p.join(extract.path, 'appearance-local', 'manifest.json')).readAsString();
    expect(manifest, isNot(contains(root.path)));
    expect(manifest, isNot(contains('file://')));
  });

  test('invalid local image manifest is rejected before otherwise valid download swap', () async {
    await metadata(true);
    await video(Directory(p.join(extract.path, 'downloads')));
    final directory = await Directory(p.join(extract.path, 'appearance-local')).create();
    await File(p.join(directory.path, 'manifest.json')).writeAsString(jsonEncode({
      'format': 'breeze-local-appearance', 'version': 99, 'images': {},
    }));
    final db = objectbox.collectAllDataJson(removeIds: true), before = VideoLocalResources.changes.value;
    await expectLater(importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true, hooks: hook()),
      throwsA(isA<BackupCompatibilityException>()));
    expect(objectbox.collectAllDataJson(removeIds: true), db);
    expect(await File(p.join(downloads.path, 'keep.txt')).readAsString(), 'local download');
    expect(VideoLocalResources.changes.value, before);
  });

  test('database failure restores both previous managed download tree and local image choice', () async {
    await metadata(true);
    await video(Directory(p.join(extract.path, 'downloads')));
    final source = LocalAppearanceImages(rootDirectory: Directory(p.join(root.path, 'source-images')));
    await source.save(_icon, _jpeg(220));
    await source.exportBackup(extract);
    final previous = await images.save(_icon, _jpeg(40));
    final db = objectbox.collectAllDataJson(removeIds: true), before = VideoLocalResources.changes.value;
    await expectLater(importExtractedBreezeData(extract.path, mode: BackupImportMode.restore, restoreDownloadFiles: true,
      hooks: hook(beforeCommit: () => throw StateError('synthetic commit failure'))), throwsA(isA<BackupRestoreIncomplete>()));
    expect(objectbox.collectAllDataJson(removeIds: true), db);
    expect(images.paths.value[_icon], previous);
    expect(await File(previous).exists(), isTrue);
    expect(await File(p.join(downloads.path, 'keep.txt')).readAsString(), 'local download');
    expect(VideoLocalResources.changes.value, before);
  });
}
