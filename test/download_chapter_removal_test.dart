import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show TxMode;
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_chapter_assets.dart';
import 'package:zephyr/service/download/download_chapter_removal.dart';
import 'package:zephyr/service/download/download_chapter_removal_recovery.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_resource_lifecycle.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/get_path.dart';

import 'download_fixture.dart';
import 'test_helper.dart';

const _source = 'chapter-removal',
    _comic = 'work',
    _workKey = '$_source:$_comic';
DownloadTask _task(String id, {String state = 'completed'}) => DownloadTask()
  ..comicId = _comic
  ..comicName = 'Work'
  ..isCompleted = state == 'completed'
  ..isDownloading = state == 'downloading'
  ..taskInfo = DownloadTaskJson(
    from: _source,
    comicId: _comic,
    comicName: 'Work',
    stateCode: state,
    chapterRef: DownloadChapterTaskRef(
      chapterId: id,
      logicalKey: id,
      storageChapterId: 'shared',
      title: id,
    ),
  );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  Future<Map<String, File>> seed({bool tasks = true}) async {
    final files = <String, File>{};
    for (final path in ['a.jpg', 'b.jpg', 'shared.jpg', 'unindexed.jpg']) {
      final store = DownloadAssetStore(
        from: _source,
        cartoonId: _comic,
        chapterId: 'a',
        storageChapterId: 'shared',
        path: path,
        pictureType: PictureType.page,
      );
      final file = File((await store.canonicalDownloadCandidate()).path);
      await file.parent.create(recursive: true);
      await file.writeAsString('owned $path');
      files[path] = file;
    }
    objectbox.unifiedDownloadBox.put(
      createTestDownload(_workKey)
        ..source = _source
        ..comicId = _comic
        ..detailJson = jsonEncode(
          const NormalComicAllInfo(
            comicInfo: ComicInfo(
              id: _comic,
              title: 'Work',
              titleMeta: [],
              description: '',
              cover: ComicImage(id: '', url: '', name: ''),
              metadata: [],
            ),
            eps: [],
            recommend: [],
          ).toJson(),
        )
        ..chapters = jsonEncode([
          for (final id in ['a', 'b'])
            {
              'id': id,
              'logicalKey': id,
              'storageChapterId': 'shared',
              'name': id,
              'order': id == 'a' ? 1 : 2,
              'images': [
                {'path': '$id.jpg'},
                {'path': 'shared.jpg'},
              ],
            },
        ]),
    );
    if (tasks) objectbox.downloadTaskBox.putMany([_task('a'), _task('b')]);
    return files;
  }

  ChapterDownloadRemovalToken bind(String id) => bindChapterDownloadRemoval(
    from: _source,
    comicId: _comic,
    chapterKey: id,
  );

  Future<DeleteDownloadedChapterResult> deleteFromDetails(String id) =>
      deleteDownloadedChapter(from: _source, comicId: _comic, chapterKey: id);

  for (final action in [
    'cancel',
    'delete one',
    'delete selection',
    'delete before status refresh',
  ]) {
    testWidgets('detail $action confirmation keeps the intended target', (
      tester,
    ) async {
      const next = 'another-work';
      final cancelled = action == 'cancel';
      final unseenChapter = action == 'delete before status refresh';
      await tester.runAsync(() => seed(tasks: !cancelled));
      final first = objectbox.unifiedDownloadBox.getAll().single;
      final original = first.chapters;
      if (unseenChapter) {
        final existing = (jsonDecode(original) as List).first;
        objectbox.unifiedDownloadBox.put(
          first..chapters = jsonEncode([existing]),
        );
      } else {
        objectbox.unifiedDownloadBox.put(
          first
            ..id = 0
            ..uniqueKey = '$_source:$next'
            ..comicId = next,
        );
      }
      if (cancelled) {
        objectbox.unifiedDownloadBox.removeAll();
        final pending = _task('a', state: 'queued');
        objectbox.downloadTaskBox.put(pending);
        objectbox.downloadTaskBox.put(
          _task('a', state: 'queued')
            ..comicId = next
            ..taskInfo = pending.taskInfo!.copyWith(comicId: next),
        );
      }
      final controller = EpisodeDownloadController()
        ..attach(
          from: _source,
          comicId: _comic,
          comicTitle: 'Original',
          allowDownload: true,
        );
      addTearDown(controller.dispose);
      const chapter = DownloadChapter(
        id: 'a',
        displayName: 'Chapter A',
        order: 1,
        extern: {},
        images: [],
      );
      late Future<void> operation;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  if (unseenChapter) {
                    objectbox.unifiedDownloadBox.put(
                      first..chapters = original,
                    );
                  }
                  operation = () async {
                    switch (action) {
                      case 'cancel':
                        await controller.cancelChapter(context, chapter);
                      case 'delete one':
                        await controller.deleteSingle(context, chapter);
                      case 'delete selection':
                      case 'delete before status refresh':
                        await controller.deleteChapters(context, [chapter]);
                    }
                  }();
                },
                child: const Text('Open confirmation'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open confirmation'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      if (!unseenChapter) {
        controller.attach(
          from: _source,
          comicId: next,
          comicTitle: 'Another',
          allowDownload: true,
        );
      }
      await tester.tap(find.text(t.common.ok));
      var finished = false;
      operation.whenComplete(() => finished = true);
      for (var frame = 0; frame < 120 && !finished; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(finished, isTrue);
      await operation;
      if (cancelled) {
        expect(
          {
            for (final task in objectbox.downloadTaskBox.getAll())
              task.comicId: task.taskInfo!.stateCode,
          },
          {_comic: 'queued', next: 'queued'},
        );
      } else if (unseenChapter) {
        final rows = objectbox.unifiedDownloadBox.getAll();
        expect(rows, hasLength(1));
        final remaining = jsonDecode(rows.single.chapters) as List;
        expect(remaining.single['logicalKey'], 'b');
      } else {
        expect(
          objectbox.unifiedDownloadBox.getAll().map((row) => row.chapters),
          [original, original],
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('details deletion cannot race a different running chapter', () async {
    final files = await seed();
    objectbox.downloadTaskBox.put(_task('next', state: 'downloading'));
    final before = objectbox.unifiedDownloadBox.getAll().single.chapters;

    await expectLater(
      deleteFromDetails('a'),
      throwsA(isA<ActiveChapterDownloadRemoval>()),
    );

    expect(objectbox.unifiedDownloadBox.getAll().single.chapters, before);
    expect(await files['a.jpg']!.exists(), isTrue);
    expect(await files['b.jpg']!.exists(), isTrue);
  });

  test(
    'details deletion defers new download and removes only its chapter transfer',
    () async {
      final files = await seed();
      final removal = deleteFromDetails('a');
      try {
        DownloadQueueManager.instance.addTask(
          _task('next', state: 'queued').taskInfo!,
        );
        expect(objectbox.downloadTaskBox.count(), 2);
      } finally {
        expect(await removal, DeleteDownloadedChapterResult.chapterDeleted);
      }

      expect(await files['a.jpg']!.exists(), isFalse);
      expect(await files['b.jpg']!.exists(), isTrue);
      expect(await files['shared.jpg']!.exists(), isTrue);
      final tasks = {
        for (final task in objectbox.downloadTaskBox.getAll())
          task.taskInfo!.chapterKey: task.taskInfo!,
      };
      expect(tasks, isNot(contains('a')));
      expect(tasks['b']!.stateCode, 'completed');
      expect(tasks['next']!.stateCode, 'queued');
    },
  );

  test(
    'details deletion removes files in the supported legacy layout',
    () async {
      final files = await seed();
      final legacy = File(
        (await DownloadAssetStore(
              from: _source,
              cartoonId: _comic,
              chapterId: 'a',
              storageChapterId: 'shared',
              path: 'a.jpg',
              pictureType: PictureType.page,
            ).downloadCandidates())
            .firstWhere(
              (candidate) =>
                  candidate.location == DownloadAssetLocation.legacyDownload,
            )
            .path,
      );
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString('legacy copy of chapter a');
      await files['a.jpg']!.delete();

      expect(
        await deleteFromDetails('a'),
        DeleteDownloadedChapterResult.chapterDeleted,
      );

      expect(await legacy.exists(), isFalse);
      expect(await files['b.jpg']!.exists(), isTrue);
      expect(await files['shared.jpg']!.exists(), isTrue);
      expect(
        objectbox.downloadTaskBox.getAll().single.taskInfo!.chapterKey,
        'b',
      );
    },
  );

  for (final tasks in [true, false]) {
    test(
      'single and last chapter removal preserves shared assets and unrelated data, tasks=$tasks',
      () async {
        final files = await seed(tasks: tasks);
        objectbox.unifiedFavoriteBox.put(createTestFavorite(_workKey));
        objectbox.unifiedHistoryBox.put(createTestHistory(_workKey));
        ComicLinkService.addComic(_workKey, null, ComicFolderType.download);
        final before = objectbox.unifiedDownloadBox.getAll().single.chapters;
        bind('a'); // Binding/abandoning a confirmation must be read-only.
        expect(objectbox.unifiedDownloadBox.getAll().single.chapters, before);
        await const ChapterDownloadRemoval().remove(bind('a'));
        expect(await files['a.jpg']!.exists(), isFalse);
        expect(await files['b.jpg']!.exists(), isTrue);
        expect(await files['shared.jpg']!.exists(), isTrue);
        expect(
          (jsonDecode(objectbox.unifiedDownloadBox.getAll().single.chapters)
                  as List)
              .length,
          1,
        );
        if (tasks)
          expect(
            objectbox.downloadTaskBox.getAll().single.taskInfo!.chapterKey,
            'b',
          );
        await const ChapterDownloadRemoval().remove(bind('b'));
        expect(objectbox.unifiedDownloadBox.count(), 0);
        expect(objectbox.downloadTaskBox.count(), 0);
        expect(
          ComicLinkService.linksOfComic(_workKey, ComicFolderType.download),
          isEmpty,
        );
        expect(objectbox.unifiedFavoriteBox.count(), 1);
        expect(objectbox.unifiedHistoryBox.count(), 1);
        expect(await files['shared.jpg']!.exists(), isFalse);
        expect(await files['unindexed.jpg']!.exists(), isTrue);
      },
    );
  }

  test(
    'batch removal uses the bound work and only cleans its selected assets',
    () async {
      final files = await seed();
      objectbox.unifiedFavoriteBox.put(createTestFavorite(_workKey));
      objectbox.unifiedHistoryBox.put(createTestHistory(_workKey));
      final stale = bind('a').work;
      objectbox.downloadTaskBox.put(_task('b'));
      await expectLater(
        const ChapterDownloadRemoval().removeChapters(stale, ['a', 'b']),
        throwsA(isA<StateError>()),
      );
      for (final file in files.values) {
        expect(await file.exists(), isTrue);
      }
      await const ChapterDownloadRemoval().removeChapters(bind('a').work, [
        'a',
        'b',
      ]);
      expect(objectbox.unifiedDownloadBox.count(), 0);
      expect(objectbox.downloadTaskBox.count(), 0);
      expect(objectbox.unifiedFavoriteBox.count(), 1);
      expect(objectbox.unifiedHistoryBox.count(), 1);
      expect(await files['a.jpg']!.exists(), isFalse);
      expect(await files['b.jpg']!.exists(), isFalse);
      expect(await files['shared.jpg']!.exists(), isFalse);
      expect(await files['unindexed.jpg']!.exists(), isTrue);
    },
  );

  test(
    'new task or resource version after confirmation rejects before deleting files',
    () async {
      final files = await seed();
      final expected = bind('a');
      objectbox.downloadTaskBox.put(_task('a'));
      await expectLater(
        const ChapterDownloadRemoval().remove(expected),
        throwsStateError,
      );
      expect(await files['a.jpg']!.exists(), isTrue);
      final second = bind('a');
      final record = objectbox.unifiedDownloadBox.getAll().single;
      record.updatedAt = record.updatedAt.add(const Duration(seconds: 1));
      objectbox.unifiedDownloadBox.put(record);
      await expectLater(
        const ChapterDownloadRemoval().remove(second),
        throwsStateError,
      );
      expect(await files['shared.jpg']!.exists(), isTrue);
    },
  );

  test(
    'task-only partial files use exact chapter paths and retain another task sharing an image',
    () async {
      final files = await seed();
      objectbox.unifiedDownloadBox.removeAll();
      for (final task in objectbox.downloadTaskBox.getAll()) {
        final payload = task.taskInfo!;
        task.taskInfo = payload.copyWith(
          imagePaths: ['${payload.chapterKey}.jpg', 'shared.jpg'],
        );
        objectbox.downloadTaskBox.put(task);
      }
      await const ChapterDownloadRemoval().remove(bind('a'));
      expect(
        objectbox.downloadTaskBox.getAll().single.taskInfo!.chapterKey,
        'b',
      );
      expect(await files['a.jpg']!.exists(), isFalse);
      expect(await files['shared.jpg']!.exists(), isTrue);
      expect(await files['b.jpg']!.exists(), isTrue);
    },
  );

  test(
    'shared request aliases and equal display order never merge distinct logical chapters',
    () async {
      final files = await seed();
      final record = objectbox.unifiedDownloadBox.getAll().single;
      final chapters = (jsonDecode(record.chapters) as List)
          .cast<Map<String, dynamic>>();
      record.chapters = jsonEncode(
        chapters
            .map(
              (chapter) => {
                ...chapter,
                'taskChapterId': 'shared-request',
                'order': 1,
              },
            )
            .toList(),
      );
      objectbox.unifiedDownloadBox.put(record);
      await expectLater(
        const ChapterDownloadRemoval().remove(bind('shared-request')),
        throwsStateError,
      );
      expect(await files['a.jpg']!.exists(), isTrue);
      await const ChapterDownloadRemoval().remove(bind('a'));
      expect(await files['b.jpg']!.exists(), isTrue);
      expect(
        objectbox.downloadTaskBox.getAll().single.taskInfo!.chapterKey,
        'b',
      );
    },
  );

  test(
    'a request alias cannot claim a different chapter’s canonical task',
    () async {
      final files = await seed();
      final record = objectbox.unifiedDownloadBox.getAll().single;
      final chapters = (jsonDecode(record.chapters) as List)
          .cast<Map<String, dynamic>>();
      chapters.first['taskChapterId'] = 'b';
      chapters.last['taskChapterId'] = 'request-b';
      objectbox.unifiedDownloadBox.put(record..chapters = jsonEncode(chapters));

      await const ChapterDownloadRemoval().remove(bind('a'));

      expect(await files['a.jpg']!.exists(), isFalse);
      expect(await files['b.jpg']!.exists(), isTrue);
      expect(
        objectbox.downloadTaskBox.getAll().map(
          (task) => task.taskInfo!.chapterKey,
        ),
        ['b'],
      );
    },
  );

  test(
    'online entry selects the exact offline chapter before old aliases',
    () async {
      await seed();
      final record = objectbox.unifiedDownloadBox.getAll().single;
      final chapters = (jsonDecode(record.chapters) as List)
          .cast<Map<String, dynamic>>();
      chapters.first['taskChapterId'] = 'b';
      chapters.last['taskChapterId'] = 'request-b';
      chapters.last['order'] = 1;
      objectbox.unifiedDownloadBox.put(record..chapters = jsonEncode(chapters));
      DownloadChapter? lookup(String key) =>
          const DownloadTaskRepository().findDownloadedChapter(
            from: _source,
            comicId: _comic,
            chapterKey: key,
          );

      expect(lookup('b')?.id, 'b');
      expect(lookup('request-b')?.id, 'b');
      expect(lookup('1'), isNull);
    },
  );

  test(
    'legacy candidates are removed by the resolver, while symlinks reject before any deletion',
    () async {
      final files = await seed();
      final store = DownloadAssetStore(
        from: _source,
        cartoonId: _comic,
        chapterId: 'a',
        storageChapterId: 'shared',
        path: 'a.jpg',
        pictureType: PictureType.page,
      );
      final legacy = File(
        (await store.downloadCandidates())
            .firstWhere(
              (candidate) =>
                  candidate.location == DownloadAssetLocation.legacyDownload,
            )
            .path,
      );
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString('legacy page');
      await const ChapterDownloadRemoval().remove(bind('a'));
      expect(await legacy.exists(), isFalse);
      expect(await files['b.jpg']!.exists(), isTrue);
      final outside = await Directory.systemTemp.createTemp(
        'breeze-chapter-external-',
      );
      addTearDown(() => outside.delete(recursive: true));
      final external = await File(
        '${outside.path}/external.jpg',
      ).writeAsString('external');
      await files['b.jpg']!.delete();
      await Link(files['b.jpg']!.path).create(external.path);
      await expectLater(
        const ChapterDownloadRemoval().remove(bind('b')),
        throwsA(isA<FileSystemException>()),
      );
      expect(await external.readAsString(), 'external');
      expect(objectbox.unifiedDownloadBox.count(), 1);
      expect(await files['shared.jpg']!.exists(), isTrue);
    },
  );

  test(
    'late task generation during file IO cannot be erased by the old confirmation',
    () async {
      final files = await seed();
      var injected = false;
      await expectLater(
        ChapterDownloadRemoval(
          stageFile: (original, staged) async {
            await stageDownloadAssetFile(original, staged);
            if (!injected) {
              injected = true;
              objectbox.downloadTaskBox.put(_task('a'));
            }
          },
        ).remove(bind('a')),
        throwsStateError,
      );
      expect(objectbox.downloadTaskBox.count(), 3);
      expect(
        (jsonDecode(objectbox.unifiedDownloadBox.getAll().single.chapters)
                as List)
            .length,
        2,
      );
      expect(await files['a.jpg']!.exists(), isTrue);
      expect(
        DownloadResourceLifecycle.removing(
          DownloadResourceLifecycle.comic(_workKey),
        ),
        isNull,
      );
    },
  );

  test('a later file failure preserves all indexed chapter pages', () async {
    final files = await seed();
    final before = objectbox.unifiedDownloadBox.getAll().single.chapters;
    var calls = 0;
    await expectLater(
      ChapterDownloadRemoval(
        stageFile: (original, staged) async {
          if (++calls == 2) {
            throw const FileSystemException('synthetic second file failure');
          }
          await stageDownloadAssetFile(original, staged);
        },
      ).removeChapters(bind('a').work, ['a', 'b']),
      throwsA(isA<FileSystemException>()),
    );
    expect(calls, 2);
    expect(objectbox.unifiedDownloadBox.getAll().single.chapters, before);
    expect(objectbox.downloadTaskBox.count(), 2);
    for (final entry in files.entries) {
      expect(await entry.value.readAsString(), 'owned ${entry.key}');
    }
  });

  test(
    'aborted metadata transaction restores all staged chapter pages',
    () async {
      final files = await seed();
      final rows = objectbox.downloadTaskBox.getAll();
      final record = objectbox.unifiedDownloadBox.getAll().single;
      final stagedPaths = <String>[];
      await expectLater(
        removeOwnedDownloadAssets(
          keeping: const [],
          removing: [
            for (final id in ['a', 'b'])
              DownloadAssetStore(
                from: _source,
                cartoonId: _comic,
                chapterId: id,
                storageChapterId: 'shared',
                path: '$id.jpg',
                pictureType: PictureType.page,
              ),
          ],
          check: () {},
          stageFile: (original, staged) async {
            await stageDownloadAssetFile(original, staged);
            stagedPaths.add(staged);
          },
          commit: () {
            expect(stagedPaths, hasLength(2));
            expect(files['a.jpg']!.existsSync(), isFalse);
            expect(files['b.jpg']!.existsSync(), isFalse);
            objectbox.downloadTaskBox.remove(rows.first.id);
            objectbox.unifiedDownloadBox.remove(record.id);
            throw StateError('synthetic metadata transaction failure');
          },
        ),
        throwsStateError,
      );
      expect(objectbox.downloadTaskBox.count(), 2);
      expect(
        objectbox.unifiedDownloadBox.get(record.id)!.chapters,
        record.chapters,
      );
      for (final entry in files.entries) {
        expect(await entry.value.readAsString(), 'owned ${entry.key}');
      }
      for (final path in stagedPaths) {
        expect(await File(path).exists(), isFalse);
      }
    },
  );

  for (final interruption in [
    'before commit',
    'after commit',
    'after proof removal',
    'replacement at original path',
  ]) {
    test('chapter removal recovers an interruption $interruption', () async {
      final files = await seed();
      final root = await getDownloadPath();
      final canonicalRoot = await Directory(root).resolveSymbolicLinks();
      final original = files['a.jpg']!;
      final removal = await DownloadChapterRemovalRecovery.begin(
        root: root,
        canonicalRoot: canonicalRoot,
        paths: [original.path],
      );
      final staged = File(removal.stagedPath(original.path));
      await stageDownloadAssetFile(original.path, staged.path);
      final checkpoint = (await Directory(
        '${await getFilePath(create: false)}/download-chapter-removal',
      ).list().toList()).whereType<File>().single;
      final proofs = objectbox.store.box<LocalStorageCommit>();
      final committed = interruption.startsWith('after');
      if (committed) {
        objectbox.store.runInTransaction(TxMode.write, () {
          objectbox.unifiedDownloadBox.removeAll();
          objectbox.downloadTaskBox.removeAll();
          removal.markDatabaseCommitted();
        });
      }
      if (interruption == 'after proof removal') {
        final persisted = jsonDecode(await checkpoint.readAsString()) as Map;
        await checkpoint.writeAsString(
          jsonEncode({...persisted, 'committed': true}),
        );
        proofs.removeAll();
      }
      if (interruption == 'replacement at original path') {
        await original.writeAsString('new page');
        expect(await DownloadChapterRemovalRecovery.recover(), isFalse);
        expect(await original.readAsString(), 'new page');
        expect(await staged.readAsString(), 'owned a.jpg');
        expect(await checkpoint.exists(), isTrue);
        await original.delete();
      }

      expect(await DownloadChapterRemovalRecovery.recover(), isTrue);
      expect(await DownloadChapterRemovalRecovery.recover(), isTrue);
      expect(await staged.exists(), isFalse);
      expect(await checkpoint.exists(), isFalse);
      expect(proofs.count(), 0);
      if (committed) {
        expect(await original.exists(), isFalse);
        expect(objectbox.unifiedDownloadBox.count(), 0);
        expect(objectbox.downloadTaskBox.count(), 0);
      } else {
        expect(await original.readAsString(), 'owned a.jpg');
        expect(objectbox.unifiedDownloadBox.count(), 1);
        expect(objectbox.downloadTaskBox.count(), 2);
      }
      expect(await files['b.jpg']!.readAsString(), 'owned b.jpg');
    });
  }

  test(
    'active work is rejected and a filesystem failure retains metadata and releases the lock',
    () async {
      final files = await seed();
      objectbox.downloadTaskBox.put(_task('other', state: 'downloading'));
      await expectLater(
        const ChapterDownloadRemoval().remove(bind('a')),
        throwsA(isA<ActiveChapterDownloadRemoval>()),
      );
      expect(await files['a.jpg']!.exists(), isTrue);
      final active = objectbox.downloadTaskBox.getAll().last;
      objectbox.downloadTaskBox.remove(active.id);
      final before = objectbox.unifiedDownloadBox.getAll().single.chapters;
      await expectLater(
        ChapterDownloadRemoval(
          stageFile: (_, _) async {
            expect(
              DownloadResourceLifecycle.removing(
                DownloadResourceLifecycle.comic(_workKey),
              ),
              isNotNull,
            );
            throw const FileSystemException('synthetic failure');
          },
        ).remove(bind('a')),
        throwsA(isA<FileSystemException>()),
      );
      expect(objectbox.unifiedDownloadBox.getAll().single.chapters, before);
      expect(objectbox.downloadTaskBox.count(), 2);
      expect(await files['a.jpg']!.exists(), isTrue);
      expect(
        DownloadResourceLifecycle.removing(
          DownloadResourceLifecycle.comic(_workKey),
        ),
        isNull,
      );
    },
  );
}
