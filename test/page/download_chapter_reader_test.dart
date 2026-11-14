import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/donwload_task/service/download_chapter_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

UnifiedComicDownload record() => createTestDownload('reader-source:work')
  ..source = 'reader-source'
  ..comicId = 'work'
  ..chapters = jsonEncode([
    for (var index = 1; index <= 2; index++)
      {
        'id': 'shared-storage',
        'logicalKey': 'logical-$index',
        'taskChapterId': 'request-$index',
        'storageChapterId': 'shared-storage',
        'name': 'Chapter $index',
        // Real identity must win when old group-local orders are repeated.
        'order': 1,
        'images': [
          {
            'id': 'page-$index',
            'name': 'Page $index',
            'path': 'page-$index.jpg',
            'url': 'https://offline-must-not-fetch.invalid/$index.jpg',
          },
        ],
      },
  ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => objectbox.unifiedDownloadBox.removeAll());

  test(
    'offline resume uses the latest available chapter and its own page',
    () async {
      SharedPreferences.setMockInitialValues({});
      final progress = ComicChapterReadingProgress();
      final saved = record();
      final chapters = jsonDecode(saved.chapters) as List;
      for (final chapter in chapters) {
        chapter['images'] = List.filled(6, (chapter['images'] as List).single);
      }
      saved.chapters = jsonEncode(chapters);
      final resource = DownloadComicResource(saved);
      await progress.record(
        source: saved.source,
        comicId: saved.comicId,
        chapterId: 'logical-1',
        pageIndex: 2,
        lastVisiblePage: 2,
        pageCount: 6,
        observedAt: 100,
      );
      await progress.record(
        source: saved.source,
        comicId: saved.comicId,
        chapterId: 'logical-2',
        pageIndex: 5,
        lastVisiblePage: 5,
        pageCount: 6,
        observedAt: 200,
      );
      expect(
        resolveDownloadedReaderPosition(resource, (
          chapterId: 'online-only',
          chapterOrder: 50,
          pageIndex: 51,
        ), progress),
        (key: 'logical-2', title: 'Chapter 2', page: 5),
      );
      expect(
        resolveDownloadedReaderPosition(resource, (
          chapterId: 'request-1',
          chapterOrder: 1,
          pageIndex: 5,
        ), progress),
        (key: 'logical-1', title: 'Chapter 1', page: 2),
      );
    },
  );

  test(
    'explicit chapter launch preserves exact offline identities and uses reader-owned history writes',
    () async {
      final saved = record();
      final status = StringSelectCubit()
        ..setDate('a different old history page');
      addTearDown(status.close);
      final route = DownloadChapterReader.route(
        record: saved,
        chapterKey: 'logical-2',
        stringSelectCubit: status,
      )!;
      final args = route.args!;
      expect(args.type, ComicEntryType.download);
      expect(args.comicInfo, same(saved));
      expect(args.comicId, 'work');
      expect(args.from, 'reader-source');
      expect(args.chapterId, 'logical-2');
      expect(args.logicalKey, 'logical-2');
      expect(args.requestId, 'request-2');
      expect(args.storageChapterId, 'shared-storage');
      expect(args.epsNumber, 2);
      expect(args.stringSelectCubit, same(status));
      expect(status.state, 'a different old history page');
      expect(
        DownloadChapterReader.route(
          record: saved,
          chapterKey: 'Chapter 2',
          stringSelectCubit: status,
        ),
        isNull,
      );
      expect(
        DownloadChapterReader.route(
          record: saved,
          chapterKey: '1',
          stringSelectCubit: status,
        ),
        isNull,
      );
      expect(
        DownloadChapterReader.route(
          record: saved,
          chapterKey: 'shared-storage',
          stringSelectCubit: status,
        ),
        isNull,
      );
      expect(
        DownloadChapterReader.route(
          record: saved,
          chapterKey: 'request-2',
          stringSelectCubit: status,
        )!.args!.logicalKey,
        'logical-2',
      );
    },
  );

  test(
    'fresh lookup rejects removed records and chapter-less catalog entries without mutating saved data',
    () async {
      final saved = record();
      objectbox.unifiedDownloadBox.put(saved);
      final before = saved.chapters;
      final status = StringSelectCubit();
      addTearDown(status.close);
      ComicReadRoute? find(String key) => DownloadChapterReader.findRoute(
        source: 'reader-source',
        comicId: 'work',
        chapterKey: key,
        stringSelectCubit: status,
      );
      expect(find('request-2')!.args!.chapterId, 'logical-2');
      final rows = jsonDecode(saved.chapters) as List;
      (rows.last as Map)['images'] = [];
      saved.chapters = jsonEncode(rows);
      objectbox.unifiedDownloadBox.put(saved);
      expect(find('logical-2'), isNull);
      expect(find('logical-1'), isNotNull);
      saved.deleted = true;
      objectbox.unifiedDownloadBox.put(saved);
      expect(find('logical-1'), isNull);
      objectbox.unifiedDownloadBox.remove(saved.id);
      expect(find('logical-1'), isNull);
      expect(before.contains('offline-must-not-fetch'), isTrue);
    },
  );

  test(
    'explicit local key defeats duplicate order and missing key never falls back to another chapter',
    () async {
      objectbox.unifiedDownloadBox.put(record());
      final selected = await getPluginInfoFromLocal(
        'reader-source',
        'work',
        1,
        chapterKey: 'logical-2',
      );
      expect(selected.epId, 'logical-2');
      expect(selected.docs.single.path, 'page-2.jpg');
      expect(selected.docs.single.storageChapterId, 'shared-storage');
      await expectLater(
        getPluginInfoFromLocal(
          'reader-source',
          'work',
          1,
          chapterKey: 'removed-chapter',
        ),
        throwsStateError,
      );
      // Existing callers without an identity retain their original order fallback.
      expect(
        (await getPluginInfoFromLocal('reader-source', 'work', 1)).epId,
        'logical-1',
      );
      expect(
        (await getPluginInfoFromLocal('reader-source', 'work', 99)).epId,
        'logical-1',
      );
    },
  );

  test(
    'legacy stored IDs and detail-only chapter indexes remain readable offline',
    () async {
      final saved = record()
        ..chapters = '[]'
        ..detailJson = jsonEncode({
          'extern': {
            'downloadChapters': [
              {
                'id': 'legacy-id',
                'name': 'Old chapter',
                'order': 7,
                'images': [
                  {
                    'id': 'old-page',
                    'name': 'Old page',
                    'path': 'old.jpg',
                    'url': 'https://must-not-fetch.invalid/old.jpg',
                  },
                ],
              },
            ],
          },
        });
      objectbox.unifiedDownloadBox.put(saved);
      final status = StringSelectCubit();
      addTearDown(status.close);
      final route = DownloadChapterReader.route(
        record: saved,
        chapterKey: 'legacy-id',
        stringSelectCubit: status,
      )!;
      expect(route.args!.chapterId, 'legacy-id');
      expect(route.args!.storageChapterId, 'legacy-id');
      expect(route.args!.epsNumber, 1);
      final chapter = await getPluginInfoFromLocal(
        'reader-source',
        'work',
        7,
        chapterKey: 'legacy-id',
      );
      expect(chapter.docs.single.path, 'old.jpg');
      expect(chapter.docs.single.fileServer, isEmpty);
      expect(
        (await getPluginInfoFromLocal('reader-source', 'work', 7)).epId,
        'legacy-id',
      );
    },
  );

  test(
    'offline docs remove network fallback for missing images and keep the original record intact',
    () async {
      await useIsolatedDownloadFixture();
      final saved = record();
      objectbox.unifiedDownloadBox.put(saved);
      final before = saved.chapters;
      final chapter = await getPluginInfoFromLocal(
        'reader-source',
        'work',
        1,
        chapterKey: 'logical-2',
      );
      final doc = chapter.docs.single;
      expect(doc.fileServer, isEmpty);
      await expectLater(
        getCachePicture(
          from: 'reader-source',
          cartoonId: 'work',
          chapterId: chapter.epId,
          storageChapterId: doc.storageChapterId,
          path: doc.path,
          url: doc.fileServer,
          pictureType: PictureType.page,
          applyRealSr: false,
        ),
        throwsA(isA<DownloadPictureNotFoundException>()),
      );
      expect(objectbox.unifiedDownloadBox.get(saved.id)!.chapters, before);
    },
  );

  test(
    'PageBloc passes the exact local logical key and reports stale identities as local failures',
    () async {
      objectbox.unifiedDownloadBox.put(record());
      final bloc = PageBloc();
      addTearDown(bloc.close);
      final ready = bloc.stream.firstWhere(
        (state) => state.status != PageStatus.initial,
      );
      bloc.add(
        const PageEvent(
          'work',
          1,
          'logical-1',
          'request-1',
          'shared-storage',
          'logical-2',
          {},
          'reader-source',
          ComicEntryType.download,
        ),
      );
      expect((await ready).epInfo!.epId, 'logical-2');
      final stale = PageBloc();
      addTearDown(stale.close);
      final failed = stale.stream.firstWhere(
        (state) => state.status == PageStatus.failure,
      );
      stale.add(
        const PageEvent(
          'work',
          1,
          'logical-1',
          'request-1',
          'shared-storage',
          'deleted-logical-key',
          {},
          'reader-source',
          ComicEntryType.download,
        ),
      );
      expect((await failed).status, PageStatus.failure);
    },
  );

  testWidgets(
    'a pushed exact reader route returns to its original download chapter page',
    (tester) async {
      final status = StringSelectCubit();
      addTearDown(status.close);
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'DownloadChapters',
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Download chapters')),
          ),
          NamedRouteDef(
            name: ComicReadRoute.name,
            path: '/offline-read',
            builder: (_, data) {
              final args = data.argsAs<ComicReadRouteArgs>();
              return Scaffold(body: Text('Offline ${args.logicalKey}'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await tester.pumpAndSettle();
      final route = DownloadChapterReader.route(
        record: record(),
        chapterKey: 'logical-2',
        stringSelectCubit: status,
      )!;
      final returned = router.push(route);
      await tester.pumpAndSettle();
      expect(find.text('Offline logical-2'), findsOneWidget);
      expect(router.stack.length, 2);
      await router.maybePop();
      await tester.pumpAndSettle();
      await returned;
      expect(find.text('Download chapters'), findsOneWidget);
      expect(router.stack.length, 1);
      expect(status.isClosed, isFalse);
    },
  );
}
