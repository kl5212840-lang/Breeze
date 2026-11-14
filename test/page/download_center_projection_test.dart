import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_storage_usage.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

DownloadTask task(
  String source,
  String comicId,
  String state, {
  int id = 1,
  String phase = '',
}) => DownloadTask()
  ..id = id
  ..comicId = comicId
  ..comicName = '同名作品'
  ..isCompleted = {'completed', 'cancelled'}.contains(state)
  ..taskInfo = DownloadTaskJson(
    from: source,
    comicId: comicId,
    comicName: '同名作品',
    stateCode: state,
    phaseCode: phase,
    chapterRef: const DownloadChapterTaskRef(
      chapterId: 'part:1',
      title: '第一章',
      order: 1,
    ),
  );

DownloadComicResource resource(String source, String id, {int at = 1}) =>
    DownloadComicResource(
      createTestDownload(buildDownloadTaskKey(source, id))
        ..source = source
        ..comicId = id
        ..title = '同名作品'
        ..metadata = jsonEncode([
          {
            'type': 'category',
            'value': [
              {'name': '冒险'},
            ],
          },
          {
            'type': 'tags',
            'value': [
              {'name': '旅行'},
            ],
          },
          {'type': 'private-token', 'value': 'must-not-be-a-filter'},
        ])
        ..downloadedAt = DateTime.fromMillisecondsSinceEpoch(at),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('size order uses only visible episodes and verified local bytes', () {
    DownloadCenterItem video(String id, {bool grouped = false}) =>
        DownloadCenterItem(
          key: 'video:$id',
          source: 'source',
          title: id,
          priority: 3,
          at: 0,
          video: {
            'url': 'https://fixture.invalid/watch/$id',
            if (grouped) ...{
              'publicWorkIdentity': 'work',
              'publicWorkTitle': 'Work',
            },
          },
        );
    Map<String, dynamic> saved(String id, int bytes) => {
      'resourceId': id,
      'bytes': bytes,
      'available': true,
      'filePresent': true,
    };
    final small = video('small', grouped: true);
    final hidden = video('hidden', grouped: true);
    final independent = video('independent');
    final unknown = video('unknown');
    final all = [unknown, small, hidden, independent];
    final sizes = savedVideoSizes([
      saved('small', 10),
      saved('hidden', 100),
      saved('independent', 25),
      saved('independent', 25),
      {...saved('unknown', 1000), 'filePresent': false},
      {...saved('receipt', 10000), 'external': true},
    ]);
    expect(sizes.values.fold(0, (sum, bytes) => sum + bytes), 135);
    final visible = groupVideoDownloadItems([
      unknown,
      small,
      independent,
    ], universe: all);
    expect(
      orderDownloadsBySize(
        visible,
        comicSizes: {},
        videoSizes: sizes,
      ).map((row) => row.item),
      [independent, small, unknown],
    );
    final whole = groupVideoDownloadItems(all, universe: all);
    expect(
      orderDownloadsBySize(
        whole,
        comicSizes: {},
        videoSizes: sizes,
      ).map((row) => row.item),
      [small, independent, unknown],
    );
  });

  test(
    'download facets use real duration and keep cancelled terminal state distinct from completed',
    () {
      const video = DownloadCenterItem(
        key: 'video:v',
        source: 's',
        title: 'v',
        priority: 3,
        at: 1,
        video: {'status': 'saved', 'quality': '1080p', 'durationMs': 3600000},
        videoFields: {
          'author': {'Creator'},
        },
      );
      expect(video.facetFields['duration'], {'hour'});
      expect(video.facetFields['author'], {'Creator'});
      expect(
        video.matches(
          facetValues: {
            'author': {'Creator'},
            'duration': {'hour'},
          },
        ),
        isTrue,
      );
      expect(
        video.matches(
          facetValues: {
            'duration': {'short'},
          },
        ),
        isFalse,
      );
      final cancelled = DownloadCenterItem(
        key: 'c',
        source: 's',
        title: 'c',
        priority: 2,
        at: 1,
        tasks: [task('s', 'c', 'cancelled')],
      );
      expect(cancelled.facetFields['status'], {'cancelled'});
      const old = DownloadCenterItem(
        key: 'old',
        source: 's',
        title: 'old',
        priority: 3,
        at: 1,
        video: {'status': 'saved'},
      );
      expect(old.facetFields, isNot(contains('duration')));
      expect(old.facetFields, isNot(contains('author')));
    },
  );

  test(
    'legacy request task and saved logical identity remain one direct-open chapter',
    () {
      final row = createTestDownload('source:work')
        ..source = 'source'
        ..comicId = 'work'
        ..chapters = jsonEncode([
          {
            'id': 'Gallery',
            'logicalKey': 'logical-chapter',
            'taskChapterId': 'request-chapter',
            'storageChapterId': 'Gallery',
            'name': 'Only chapter',
            'order': 1,
            'images': [
              {'id': 'page', 'name': 'Page', 'path': 'page.jpg'},
            ],
          },
        ]);
      final legacyTask = task('source', 'work', 'completed')
        ..taskInfo = const DownloadTaskJson(
          from: 'source',
          comicId: 'work',
          comicName: 'Work',
          stateCode: 'completed',
          chapterRef: DownloadChapterTaskRef(
            chapterId: 'request-chapter',
            title: 'Only chapter',
            order: 1,
          ),
        );
      final before = legacyTask.dbTaskInfoStr;
      final item = projectDownloadCenter(
        tasks: [legacyTask],
        comics: [DownloadComicResource(row)],
        videos: [],
      ).single;
      expect(item.chapterKeys, {'logical-chapter'});
      expect(item.chapterKeys.single, 'logical-chapter');
      expect(item.chapterProgress(item.tasks).completed, {'logical-chapter'});
      expect(legacyTask.dbTaskInfoStr, before);
    },
  );

  test(
    'matching titles, orders and shared storage cannot merge distinct chapter identities',
    () {
      final row = createTestDownload('source:work')
        ..source = 'source'
        ..comicId = 'work'
        ..chapters = jsonEncode([
          for (var i = 1; i <= 2; i++)
            {
              'id': 'Gallery',
              'logicalKey': 'logical-$i',
              'taskChapterId': 'request-$i',
              'storageChapterId': 'Gallery',
              'name': 'Same title',
              'order': 1,
              'images': [
                {'path': 'page-$i.jpg'},
              ],
            },
        ]);
      DownloadTask pending(String key) =>
          task('source', 'work', 'queued')
            ..taskInfo = DownloadTaskJson(
              from: 'source',
              comicId: 'work',
              comicName: 'Work',
              chapterRef: DownloadChapterTaskRef(
                chapterId: key,
                title: 'Same title',
                order: 1,
              ),
            );
      final item = projectDownloadCenter(
        tasks: [
          pending('request-1'),
          pending('request-2'),
          pending('1'),
          pending('Gallery'),
        ],
        comics: [DownloadComicResource(row)],
        videos: [],
      ).single;
      expect(item.chapterKeys, {'logical-1', 'logical-2', '1', 'Gallery'});
      expect(item.chapterProgress(item.tasks).completed, {
        'logical-1',
        'logical-2',
      });
    },
  );

  test(
    'only active and retryable tasks or persistent resources enter the download list',
    () {
      final rows = projectDownloadCenter(
        tasks: [
          task('plugin:source', 'active:comic', 'downloading'),
          task(
            'old-source',
            'removed',
            'completed',
            id: 2,
            phase: 'fileRemoved',
          ),
          task('old-source', 'unbound-completion', 'completed', id: 3),
          task('old-source', 'retryable', 'failed', id: 4),
          task(
            'saved-source',
            'newer',
            'completed',
            id: 5,
            phase: 'fileRemoved',
          ),
        ],
        comics: [
          resource('saved-source', 'older', at: 5),
          resource('saved-source', 'newer', at: 8),
        ],
        videos: [],
      );
      expect(rows.map((row) => row.comicId), [
        'retryable',
        'active:comic',
        'newer',
        'older',
      ]);
      expect(rows.first.resource, isNull);
      expect(rows[1].priority, 0);
      expect(rows[2].tasks, isEmpty);
      expect(rows.last.tasks, isEmpty);
    },
  );

  test(
    'saved video membership needs a local file or external acknowledgment',
    () {
      Map<String, dynamic> row(String key) => {
        'kind': 'transfer',
        'key': key,
        'source': 'video-source',
        'url': 'https://example.com/videos/$key',
        'quality': '1080p',
        'title': key,
        'status': 'saved',
        'at': 5,
      };
      final rows = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          row('unverified'),
          {...row('missing-file'), 'local': true, 'fileRemoved': true},
          {...row('damaged'), 'local': true, 'fileInvalid': true},
          {...row('complete'), 'local': true, 'available': true},
          {...row('queued'), 'status': 'queued'},
          {...row('external'), 'kind': null, 'external': true},
        ],
      );
      expect(
        rows.map((item) => item.title),
        unorderedEquals(['damaged', 'complete', 'queued', 'external']),
      );
    },
  );

  test(
    'opaque comic keys with colons merge tasks and resources without splitting identity',
    () {
      final rows = projectDownloadCenter(
        tasks: [task('source:uuid', 'work:opaque', 'failed')],
        comics: [
          resource('source:uuid', 'work:opaque'),
          resource('other', 'work:opaque'),
        ],
        videos: [],
      );
      expect(rows, hasLength(2));
      expect(rows.first.source, 'source:uuid');
      expect(rows.first.comicId, 'work:opaque');
      expect(rows.first.tasks, hasLength(1));
      expect(rows.first.resource, isNotNull);
    },
  );

  test(
    'actual download metadata drives category and tag filters, missing metadata is absent',
    () {
      final rows = projectDownloadCenter(
        tasks: [task('active', 'work', 'queued')],
        comics: [resource('saved', 'work')],
        videos: [],
      );
      final saved = rows.singleWhere((row) => row.resource != null);
      expect(saved.fields.keys, unorderedEquals(['category', 'tags']));
      expect(
        saved.matches(query: '旅行', categories: {'冒险'}, tags: {'旅行'}),
        isTrue,
      );
      expect(saved.matches(tags: {'missing'}), isFalse);
      expect(
        saved.matches(tags: {'missing', '旅行'}),
        isTrue,
        reason: 'Values in one facet are OR, matching the shared bookshelf.',
      );
      expect(rows.first.matches(categories: {'冒险'}), isFalse);
      expect(saved.matches(type: 'video'), isFalse);
    },
  );

  test(
    'same video title does not merge public page, source or quality identities',
    () {
      Map<String, dynamic> video(
        String key,
        String source,
        String page,
        String quality,
        int at,
      ) => {
        'key': key,
        'source': source,
        'url': 'https://example.com/videos/$page',
        'quality': quality,
        'title': 'same title',
        'status': 'saved',
        'at': at,
      };
      final rows = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          video('first', 'one', 'a', '720p', 5),
          video('repeat', 'one', 'a', '720p', 6),
          video('different-page', 'one', 'b', '720p', 7),
          video('different-quality', 'one', 'a', '1080p', 8),
          video('different-source', 'two', 'a', '720p', 9),
        ],
      );
      expect(rows, hasLength(4));
      expect(
        rows.last.video!['recordKeys'],
        unorderedEquals(['first', 'repeat']),
      );
    },
  );

  test(
    'video filters read only explicit saved public metadata and keep absent fields empty',
    () {
      Map<String, dynamic> video(String key, {Object? metadata}) => {
        'key': key,
        'source': 'video-source',
        'url': 'https://example.com/videos/$key',
        'quality': '1080p',
        'title': '旅行分类不应从标题猜测',
        'status': 'saved',
        'at': 5,
        if (metadata != null) 'metadata': metadata,
      };
      final rows = projectDownloadCenter(
        tasks: [],
        comics: [],
        videos: [
          video(
            'explicit',
            metadata: [
              {
                'type': 'category',
                'value': [
                  {'name': '纪录片'},
                ],
              },
              {
                'type': 'tags',
                'value': [
                  {'name': '自然'},
                ],
              },
              {'type': 'private-token', 'value': 'secret'},
            ],
          ),
          video('missing'),
        ],
      );
      final explicit = rows.singleWhere(
        (row) => row.video!['key'] == 'explicit',
      );
      final absent = rows.singleWhere((row) => row.video!['key'] == 'missing');
      expect(explicit.matches(categories: {'纪录片'}, tags: {'自然'}), isTrue);
      expect(explicit.fields.keys, unorderedEquals(['category', 'tags']));
      expect(absent.fields, isEmpty);
      expect(absent.matches(tags: {'旅行'}), isFalse);
    },
  );

  test(
    'progress checkpoints keep list membership signature while terminal state invalidates it',
    () {
      final row = task('source', 'work', 'downloading');
      final first = downloadTaskStructure([row]);
      row.taskInfo = row.taskInfo!.copyWith(
        completedImages: 5,
        totalImages: 10,
      );
      expect(downloadTaskStructure([row]), first);
      row.taskInfo = row.taskInfo!.copyWith(stateCode: 'completed');
      row.isCompleted = true;
      expect(downloadTaskStructure([row]), isNot(first));
    },
  );

  test('row flags invalidate structure without changing the task JSON', () {
    final previous = task('source', 'work', '');
    final finished = task('source', 'work', '')..isCompleted = true;
    final downloading = task('source', 'work', '')..isDownloading = true;
    for (final updated in [finished, downloading]) {
      expect(updated.dbTaskInfoStr, previous.dbTaskInfoStr);
      expect(sameDownloadTaskStructure([previous], [updated]), isFalse);
      expect(
        downloadTaskStructure([updated]),
        isNot(downloadTaskStructure([previous])),
      );
    }
    final before = projectDownloadCenter(
      tasks: [previous],
      comics: [],
      videos: [],
    );
    final after = projectDownloadCenter(
      tasks: [finished],
      comics: [],
      videos: [],
    );
    expect(before.single.facetFields['status'], isNot(contains('saved')));
    expect(after, isEmpty);
  });

  test('a checkpoint reuses only unchanged task rows', () {
    final original = [
      for (var i = 1; i <= 100; i++) task('source', 'work', 'running', id: i),
    ];
    final fresh = [
      for (var i = 1; i <= 100; i++) task('source', 'work', 'running', id: i),
    ];
    fresh.first.taskInfo = fresh.first.taskInfo!.copyWith(completedImages: 5);
    final reused = reuseDownloadTaskRows(fresh, {
      for (final row in original) row.id: row,
    });
    expect(reused.first, same(fresh.first));
    expect(
      reused
          .skip(1)
          .indexed
          .every((entry) => identical(entry.$2, original[entry.$1 + 1])),
      isTrue,
    );
    expect(sameDownloadTaskStructure(original, reused), isTrue);
    reused.first.taskInfo = reused.first.taskInfo!.copyWith(
      stateCode: 'failed',
    );
    expect(sameDownloadTaskStructure(original, reused), isFalse);
  });

  test(
    'comic projections reuse unchanged resources and replace changed raw metadata',
    () {
      final projection = DownloadComicResourceProjection();
      UnifiedComicDownload record(String title, {bool deleted = false}) =>
          createTestDownload(buildDownloadTaskKey('source', 'work'))
            ..source = 'source'
            ..comicId = 'work'
            ..title = title
            ..updatedAt = DateTime.utc(2026)
            ..downloadedAt = DateTime.utc(2026)
            ..deleted = deleted;
      final initial = projection.project([record('Old title')]);
      expect(projection.project([record('Old title')]), same(initial));
      final updated = projection.project([record('New title')]);
      expect(updated.single.title, 'New title');
      expect(updated.single, isNot(same(initial.single)));
      expect(projection.project([record('New title', deleted: true)]), isEmpty);
    },
  );

  group('download center removal', () {
    setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
    tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
    tearDown(() {
      objectbox.downloadTaskBox.removeAll();
      TestObjectBoxHelper.cleanComicFolderBoxes();
    });

    Future<Directory> seed(String state) async {
      await useIsolatedDownloadFixture();
      final directory = await createDownloadFixture('center-removal', 'work');
      await File('${directory.path}/page.png').writeAsString('owned bytes');
      final key = buildDownloadTaskKey('center-removal', 'work');
      objectbox.unifiedDownloadBox.put(
        createTestDownload(key)
          ..source = 'center-removal'
          ..comicId = 'work',
      );
      objectbox.downloadTaskBox.put(
        task('center-removal', 'work', state, id: 0),
      );
      objectbox.unifiedFavoriteBox.put(createTestFavorite(key));
      objectbox.unifiedHistoryBox.put(createTestHistory(key));
      ComicLinkService.addComic(key, null, ComicFolderType.download);
      return directory;
    }

    test(
      'one removal deletes files, resource and transfer rows, keeping favorite/history',
      () async {
        final directory = await seed('completed');
        await removeComicDownload(from: 'center-removal', comicId: 'work');
        expect(await directory.exists(), isFalse);
        expect(objectbox.downloadTaskBox.count(), 0);
        expect(objectbox.unifiedDownloadBox.count(), 0);
        expect(
          ComicLinkService.linksOfComic(
            'center-removal:work',
            ComicFolderType.download,
          ),
          isEmpty,
        );
        expect(objectbox.unifiedFavoriteBox.count(), 1);
        expect(objectbox.unifiedHistoryBox.count(), 1);
      },
    );

    test(
      'active task refuses removal and keeps both physical and saved data',
      () async {
        final directory = await seed('downloading');
        await expectLater(
          removeComicDownload(from: 'center-removal', comicId: 'work'),
          throwsStateError,
        );
        expect(
          await File('${directory.path}/page.png').readAsString(),
          'owned bytes',
        );
        expect(objectbox.downloadTaskBox.count(), 1);
        expect(objectbox.unifiedDownloadBox.count(), 1);
        expect(
          ComicLinkService.linksOfComic(
            'center-removal:work',
            ComicFolderType.download,
          ),
          hasLength(1),
        );
      },
    );
  });
}
