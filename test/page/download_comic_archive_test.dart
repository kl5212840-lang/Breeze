import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/service/download_comic_archive.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/src/rust/compressed/compressed.dart';
import 'package:zephyr/type/enum.dart';
import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);
  const source = 'archive-source', comic = 'work-1';
  final pixels = [137, 80, 78, 71, 13, 10, 26, 10];
  Future<File> seed({String owner = source, String id = comic}) async {
    final record = createTestDownload(buildDownloadTaskKey(owner, id))
      ..source = owner ..comicId = id ..title = 'Public work'
      ..chapters = jsonEncode([
        {'id': 'a', 'logicalKey': 'a', 'storageChapterId': 'a', 'name': 'Chapter / A', 'order': 1,
          'images': [{'path': 'saved.png'}, {'path': 'missing.png'}]},
        {'id': 'b', 'logicalKey': 'b', 'storageChapterId': 'b', 'name': 'Chapter B', 'order': 2, 'images': []},
      ]);
    objectbox.unifiedDownloadBox.put(record);
    final store = DownloadAssetStore(from: owner, cartoonId: id, chapterId: 'a',
      storageChapterId: 'a', path: 'saved.png', pictureType: PictureType.page);
    final file = File((await store.canonicalDownloadCandidate()).path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pixels);
    return file;
  }
  Future<void> fakePack(String path, PackInfo info) async {
    // Production uses the existing Rust streaming ZIP packer. This fixture
    // checks its exact immutable input rather than reimplementing ZIP here.
    expect(info.originalImagePaths, hasLength(1));
    expect(await File(info.originalImagePaths.single).readAsBytes(), pixels);
    expect(info.packImagePaths.single, '0001_Chapter   A/00001.png');
    expect(info.comicInfoString, isNot(contains('https://')));
    expect(info.comicInfoString, contains('downloaded-files-only'));
    await File(path).writeAsBytes([80, 75, 3, 4, 0, 0, 0, 0]);
  }
  test('one-work local snapshot reports missing files and stays independent of deleted originals', () async {
    final original = await seed();
    final otherSource = await seed(owner: 'another-source');
    final otherWork = await seed(id: 'another-work');
    var presented = 0;
    final archive = await DownloadComicArchiveService(pack: fakePack, present: (id, title) async {
      expect(id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(title, 'Public work');
      presented++;
      return 'saved';
    }).prepare(source, comic);
    expect(archive.chapters, 1); expect(archive.pages, 1);
    expect(archive.missingPages, 1); expect(archive.unavailableChapters, 1);
    final cache = await getApplicationCacheDirectory();
    final stage = Directory(p.join(cache.path, 'breeze-comic-export', archive.archiveId));
    expect(await stage.exists(), isTrue);
    await expectLater(CacheWorkspaceGuard.clear(() async {}), throwsA(isA<CacheWorkspaceBusy>()));
    await original.delete(); // A later deletion cannot resurrect original data.
    expect(await archive.export(), ComicArchiveExportStatus.saved);
    await archive.dispose();
    expect(presented, 1);
    expect(await stage.exists(), isFalse);
    expect(await original.exists(), isFalse);
    expect(await otherSource.readAsBytes(), pixels);
    expect(await otherWork.readAsBytes(), pixels);
    expect(objectbox.unifiedDownloadBox.count(), 3);
  });
  for (final nativeStatus in ['saved', 'cancelled', 'failed', 'presented']) {
    test('official archive bridge waits for $nativeStatus and never treats mere presentation as saved', () async {
      final original = await seed();
      const channel = MethodChannel('breeze.video.download');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final entered = Completer<void>(), result = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) {
        expect(call.method, 'exportArchive');
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(args.keys, unorderedEquals(['archiveId', 'title']));
        expect(args['archiveId'], matches(RegExp(r'^[a-f0-9]{32}$')));
        entered.complete(); return result.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final archive = await DownloadComicArchiveService(pack: fakePack).prepare(source, comic);
      var completed = false;
      final pending = archive.export().then((value) { completed = true; return value; });
      await entered.future;
      final cache = await getApplicationCacheDirectory();
      final folder = Directory(p.join(cache.path, 'breeze-comic-export', archive.archiveId));
      final names = await folder.list().map((entry) => p.basename(entry.path)).toList();
      expect(completed, isFalse);
      result.complete(nativeStatus);
      expect(await pending, nativeStatus == 'saved' ? ComicArchiveExportStatus.saved
        : nativeStatus == 'cancelled' ? ComicArchiveExportStatus.cancelled : ComicArchiveExportStatus.failed);
      await archive.dispose();
      expect(names, ['archive.zip'], reason: 'The picker needs only the completed copy');
      expect(await original.readAsBytes(), pixels);
    });
  }
  for (final (field, mutate) in <(String, void Function(UnifiedComicDownload))>[
    ('timestamp', (row) => row.updatedAt = DateTime.utc(2040)),
    ('chapters with the same timestamp', (row) => row.chapters += ' '),
    ('details with the same timestamp', (row) => row.detailJson += ' '),
  ]) {
    test(
      '$field change during chunk copy rejects the snapshot before export',
      () async {
        final original = await seed();
        var checks = 0, packed = false;
        await expectLater(
          DownloadComicArchiveService(
            pack: (_, _) async {
              packed = true;
            },
          ).prepare(
            source,
            comic,
            cancelled: () {
              if (++checks == 5) {
                final row = const DownloadTaskRepository()
                    .findDownloadRecord(source, comic)!;
                mutate(row);
                objectbox.unifiedDownloadBox.put(row);
              }
              return false;
            },
          ),
          throwsA(
            isA<ComicArchiveException>().having(
              (error) => error.reason,
              'reason',
              ComicArchiveFailure.changed,
            ),
          ),
        );
        expect(packed, isFalse);
        expect(await original.readAsBytes(), pixels);
      },
    );
  }
  test('explicit cancellation, empty content and file-count limit never open a picker', () async {
    final original = await seed();
    var presented = false;
    final service = DownloadComicArchiveService(pack: fakePack, present: (_, _) async { presented = true; return 'saved'; });
    await expectLater(service.prepare(source, comic, cancelled: () => true),
      throwsA(isA<ComicArchiveException>().having((e) => e.reason, 'reason', ComicArchiveFailure.cancelled)));
    await expectLater(const DownloadComicArchiveService(maxFiles: 1).prepare(source, comic),
      throwsA(isA<ComicArchiveException>().having((e) => e.reason, 'reason', ComicArchiveFailure.limit)));
    await original.delete();
    await expectLater(service.prepare(source, comic), throwsA(isA<ComicArchiveEmpty>()));
    expect(presented, isFalse);
  });
  test('a symlink cannot substitute another work file into the archive', () async {
    final original = await seed();
    final other = await seed(owner: 'another-source');
    await original.delete();
    await Link(original.path).create(other.path);
    await expectLater(const DownloadComicArchiveService().prepare(source, comic),
      throwsA(isA<ComicArchiveException>().having((e) => e.reason, 'reason', ComicArchiveFailure.unsafe)));
    expect(await other.readAsBytes(), pixels);
  });
  test('disk-full ZIP failure reports space without deleting the owned download', () async {
    final original = await seed();
    var presented = false;
    final archive = await DownloadComicArchiveService(pack: (_, _) async {
      throw const FileSystemException('No space left on device', '', OSError('No space left on device', 28));
    }, present: (_, _) async { presented = true; return 'saved'; }).prepare(source, comic);
    expect(await archive.export(), ComicArchiveExportStatus.failed);
    expect(archive.failure, ComicArchiveFailure.noSpace);
    await archive.dispose();
    expect(presented, isFalse);
    expect(await original.readAsBytes(), pixels);
  });
}
