import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

DownloadComicResource resource({
  List<Map<String, dynamic>> images = const [
    {'path': 'page.jpg'},
  ],
  bool sharedChapter = false,
  int revision = 1000,
  String cover = '',
}) {
  final chapter = <String, dynamic>{
    'id': 'stored',
    'logicalKey': 'logical-1',
    'storageChapterId': 'shared',
    'name': 'Chapter',
    'order': 1,
    'images': images,
  };
  return DownloadComicResource(
    createTestDownload('source:comic')
      ..source = 'source'
      ..comicId = 'comic'
      ..cover = cover
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(revision, isUtc: true)
      ..downloadedAt = DateTime.fromMillisecondsSinceEpoch(500, isUtc: true)
      ..chapters = jsonEncode([
        chapter,
        if (sharedChapter) {...chapter, 'logicalKey': 'logical-2', 'order': 2},
      ]),
  );
}

Future<File> pageFile(
  String path,
  String content, {
  bool legacy = false,
  bool cover = false,
}) async {
  final store = DownloadAssetStore(
    from: 'source',
    cartoonId: 'comic',
    chapterId: cover ? '' : 'logical-1',
    storageChapterId: cover ? '' : 'shared',
    path: path,
    pictureType: cover ? PictureType.cover : PictureType.page,
  );
  final candidates = await store.downloadCandidates();
  final candidate = legacy
      ? candidates.firstWhere(
          (row) => row.location == DownloadAssetLocation.legacyDownload,
        )
      : candidates.first;
  final file = File(candidate.path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('task page counters alone do not open the download directory', () async {
    await useIsolatedDownloadFixture();
    final downloadRoot = Directory(
      p.join(await getAppDirectory(), 'files', 'downloads'),
    );
    final measured = await DownloadResourceMetrics().readComicProgress(
      source: 'source',
      comicId: 'comic',
      tasks: const [
        DownloadTaskJson(
          from: 'source',
          comicId: 'comic',
          comicName: 'Comic',
          stateCode: 'paused',
          completedImages: 3,
          totalImages: 10,
          imagePaths: [''],
          chapterRef: DownloadChapterTaskRef(chapterId: 'chapter'),
        ),
      ],
    );
    expect(measured.status, DownloadResourceSizeStatus.unavailable);
    expect(measured.sizeBytes, isNull);
    expect(await downloadRoot.exists(), isFalse);
  });

  test(
    'actual canonical and legacy file sizes include cover, deduplicate shared chapters and never migrate',
    () async {
      await useIsolatedDownloadFixture();
      final first = await pageFile('page.jpg', '123');
      final legacy = await pageFile('old.jpg', '12345', legacy: true);
      await pageFile('cover.jpg', '12', cover: true);
      await pageFile('skipped.jpg', 'not part of the download');
      final value = resource(
        sharedChapter: true,
        cover: jsonEncode({'path': 'cover.jpg'}),
        images: [
          {'path': 'page.jpg'},
          {'path': 'old.jpg'},
          {
            'path': 'skipped.jpg',
            'extern': {'downloadSkipped': true},
          },
        ],
      );
      final measured = await DownloadResourceMetrics().readComic(value);
      expect(measured.status, DownloadResourceSizeStatus.complete);
      expect(measured.sizeBytes, 10);
      expect(measured.knownFiles, 3);
      // Per-chapter sizes come from the same pass and exclude the 2-byte cover.
      expect(measured.chapters.keys, containsAll(['logical-1', 'logical-2']));
      expect(measured.chapters['logical-1']!.sizeBytes, 8);
      expect(measured.chapters['logical-2']!.sizeBytes, 8);
      expect(measured.chapters['logical-1']!.knownFiles, 2);
      expect(await first.readAsString(), '123');
      expect(await legacy.readAsString(), '12345');
      final canonical = (await DownloadAssetStore(
        from: 'source',
        cartoonId: 'comic',
        chapterId: 'logical-1',
        storageChapterId: 'shared',
        path: 'old.jpg',
        pictureType: PictureType.page,
      ).canonicalDownloadCandidate()).path;
      expect(await File(canonical).exists(), isFalse);
    },
  );

  test(
    'missing and empty files expose only a confirmed lower bound, never a complete zero',
    () async {
      await useIsolatedDownloadFixture();
      await pageFile('page.jpg', '1234');
      await pageFile('empty.jpg', '');
      final metrics = DownloadResourceMetrics();
      final partial = await metrics.readComic(
        resource(
          images: [
            {'path': 'page.jpg'},
            {'path': 'missing.jpg'},
            {'path': 'empty.jpg'},
          ],
        ),
      );
      expect(partial.status, DownloadResourceSizeStatus.partial);
      expect(partial.sizeBytes, isNull);
      expect(partial.knownBytes, 4);
      expect(partial.missingFiles, 2);
      expect(partial.chapters['logical-1']!.sizeBytes, isNull);
      expect(partial.chapters['logical-1']!.knownBytes, 4);
      expect(partial.chapters['logical-1']!.missingFiles, 2);
      final absent = await metrics.readComic(
        resource(
          images: [
            {'path': 'unknown.jpg'},
          ],
        ),
      );
      expect(absent.status, DownloadResourceSizeStatus.unavailable);
      expect(absent.sizeBytes, isNull);
      final noImages = await metrics.readComic(resource(images: []));
      expect(noImages.status, DownloadResourceSizeStatus.unavailable);
      expect(noImages.sizeBytes, isNull);
      expect(noImages.chapters['logical-1']!.sizeBytes, isNull);
    },
  );

  test('file and ancestor symlinks cannot contribute external bytes', () async {
    await useIsolatedDownloadFixture();
    final outside = await Directory.systemTemp.createTemp(
      'breeze-metric-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final secret = await File(
      p.join(outside.path, 'private'),
    ).writeAsString('outside bytes');
    final leaf = await pageFile('linked.jpg', 'temporary');
    await leaf.delete();
    await Link(leaf.path).create(secret.path);
    final metrics = DownloadResourceMetrics();
    final linked = await metrics.readComic(
      resource(
        images: [
          {'path': 'linked.jpg'},
        ],
      ),
    );
    expect(linked.status, DownloadResourceSizeStatus.error);
    expect(linked.sizeBytes, isNull);
    expect(linked.knownFiles, 0);
    await Link(leaf.path).delete();
    await leaf.parent.delete();
    await Link(leaf.parent.path).create(outside.path);
    final directoryLink = await metrics.readComic(
      resource(
        images: [
          {'path': 'private'},
        ],
      ),
    );
    expect(directoryLink.status, DownloadResourceSizeStatus.error);
    expect(directoryLink.sizeBytes, isNull);
    expect(await secret.readAsString(), 'outside bytes');
  }, skip: Platform.isWindows);

  test(
    'same-version requests share one measurement and version or file events invalidate it',
    () async {
      await useIsolatedDownloadFixture();
      final file = await pageFile('page.jpg', '123');
      final metrics = DownloadResourceMetrics();
      final row = resource();
      final first = metrics.readComic(row);
      expect(identical(first, metrics.readComic(row)), isTrue);
      expect((await first).sizeBytes, 3);
      await file.writeAsString('12345');
      expect((await metrics.readComic(row)).sizeBytes, 3);
      metrics.invalidate(row.key);
      expect((await metrics.readComic(row)).sizeBytes, 5);
      await file.writeAsString('1234567');
      final changed = resource(revision: 1001);
      expect((await metrics.readComic(changed)).sizeBytes, 7);
      metrics.retainResources([]);
      await file.delete();
      expect((await metrics.readComic(changed)).sizeBytes, isNull);
    },
  );

  test(
    'projection exposes real completion time and accepts only matching complete comic measurements',
    () async {
      await useIsolatedDownloadFixture();
      await pageFile('page.jpg', '123');
      final row = resource();
      final size = await DownloadResourceMetrics().readComic(row);
      final tasks = [
        DownloadTask()
          ..id = 999999999
          ..comicId = 'other'
          ..taskInfo = const DownloadTaskJson(
            from: 'source',
            comicId: 'other',
            comicName: 'Other',
            chapterRef: DownloadChapterTaskRef(chapterId: 'chapter'),
          ),
      ];
      final items = projectDownloadCenter(
        tasks: tasks,
        comics: [row],
        videos: [],
        comicSizes: {row.key: size},
      );
      expect(items.first.completedAt, isNull);
      expect(items.first.sizeBytes, isNull);
      final comic = items.singleWhere((item) => item.resource != null);
      expect(
        comic.completedAt,
        DateTime.fromMillisecondsSinceEpoch(500, isUtc: true),
      );
      expect(comic.sizeBytes, 3);
      expect(comic.totalBytes, isNull);
      expect(comic.receivedBytes, isNull);
      final changed = resource(revision: 1001);
      expect(
        projectDownloadCenter(
          tasks: [],
          comics: [changed],
          videos: [],
          comicSizes: {changed.key: size},
        ).single.sizeBytes,
        isNull,
      );
    },
  );

  test(
    'video resource bytes and commit time win over stale transfer progress without mutating its log',
    () {
      final task = <String, dynamic>{
        'key': 'transfer',
        'resourceId': 'id',
        'source': 'video',
        'url': 'https://hanime1.me/watch?v=1',
        'quality': '720p',
        'title': 'Video',
        'local': true,
        'status': 'saved',
        'at': 100,
        'received': 3,
        'total': 1000,
      };
      final rows = DownloadCenterResources.mergeVideos(
        [task],
        [
          {'resourceId': 'id', 'available': true, 'bytes': 24, 'at': 200},
        ],
      );
      expect(rows.single['bytes'], 24);
      expect(rows.single['at'], 200);
      expect(rows.single['startedAt'], 100);
      expect(rows.single['received'], 3);
      expect(task.containsKey('bytes'), isFalse);
      final item = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: rows,
      ).single;
      expect(item.sizeBytes, 24);
      expect(item.totalBytes, 24);
      expect(item.receivedBytes, 24);
      expect(
        item.completedAt,
        DateTime.fromMillisecondsSinceEpoch(200, isUtc: true),
      );
      final external = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          {...task, 'key': 'external', 'local': false, 'external': true},
        ],
      ).single;
      expect(external.sizeBytes, isNull);
      expect(external.completedAt, isNull);
      final active = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          {...task, 'status': 'downloading', 'received': 40, 'total': null},
        ],
      ).single;
      expect(active.receivedBytes, 40);
      expect(active.totalBytes, isNull);
      expect(active.sizeBytes, isNull);
      expect(active.completedAt, isNull);
      final removed = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          {...rows.single, 'fileRemoved': true},
        ],
      );
      expect(removed, isEmpty);
    },
  );

  test(
    'video rate uses monotonic byte deltas and resets on rollback, task change or terminal state',
    () {
      final rate = VideoTransferRate();
      double? sample(
        int received,
        int seconds, {
        String key = 'one',
        bool active = true,
      }) => rate.update(
        taskKey: key,
        received: received,
        elapsed: Duration(seconds: seconds),
        active: active,
      );
      expect(sample(100, 0), isNull);
      expect(sample(600, 1), 500);
      expect(sample(600, 2), 0);
      expect(sample(700, 2), isNull);
      expect(sample(900, 3), 300);
      expect(sample(10, 4), isNull);
      expect(sample(110, 5), 100);
      expect(sample(210, 6, key: 'two'), isNull);
      expect(sample(310, 7, key: 'two'), 100);
      expect(sample(410, 8, key: 'two', active: false), isNull);
      expect(sample(510, 9, key: 'two'), isNull);
      expect(sample(610, 1, key: 'two'), isNull);
      expect(sample(710, 2, key: 'two'), 100);
    },
  );
  test(
    'running task paths expose actual bytes before the first chapter commit and preserve aliases',
    () async {
      await useIsolatedDownloadFixture();
      await pageFile('written.jpg', '1234567');
      const running = DownloadTaskJson(
        from: 'source',
        comicId: 'comic',
        comicName: 'Comic',
        stateCode: 'running',
        completedImages: 1,
        totalImages: 8,
        imagePaths: ['written.jpg'],
        chapterRef: DownloadChapterTaskRef(
          chapterId: 'request-1',
          logicalKey: 'logical-1',
          requestId: 'request-1',
          storageChapterId: 'shared',
        ),
      );
      var fingerprints = 0;
      final metrics = DownloadResourceMetrics(
        clock: () => DateTime.utc(2026),
        onProgressFingerprint: () => fingerprints++,
      );
      final first = metrics.readComicProgress(
        source: 'source',
        comicId: 'comic',
        tasks: [running],
      );
      final measured = await first;
      expect(measured.knownBytes, 7);
      expect(measured.status, DownloadResourceSizeStatus.partial);
      expect(
        measured.sizeBytes,
        isNull,
        reason: 'Eight expected pages are not an expected byte total',
      );
      expect(measured.chapters['logical-1']!.knownBytes, 7);
      expect(
        measured.chapters['request-1'],
        same(measured.chapters['logical-1']),
      );
      for (var tick = 0; tick < 30; tick++) {
        expect(
          metrics.readComicProgress(
            source: 'source',
            comicId: 'comic',
            tasks: [
              running.copyWith(
                completedImages: tick + 2,
                imagePaths: [
                  'written.jpg',
                  for (var i = 0; i < 200; i++) 'pending-$tick-$i.jpg',
                ],
              ),
            ],
          ),
          same(first),
        );
      }
      expect(fingerprints, 1, reason: 'Coalescing precedes page path hashing');
      final complete = await metrics.readComicProgress(
        source: 'source',
        comicId: 'comic',
        tasks: [
          running.copyWith(
            stateCode: 'completed',
            completedImages: 1,
            totalImages: 1,
          ),
        ],
      );
      expect(
        complete.sizeBytes,
        7,
        reason: 'Real terminal commit bypasses the progress window',
      );
      expect(fingerprints, 2);
      final foreign = await DownloadResourceMetrics().readComicProgress(
        source: 'other',
        comicId: 'comic',
        tasks: [running],
      );
      expect(foreign.knownBytes, 0);
      expect(foreign.sizeBytes, isNull);
    },
  );
}
