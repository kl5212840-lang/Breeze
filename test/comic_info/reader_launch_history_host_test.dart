import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_info/models/go_to_comic_read.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/type/enum.dart';

import '../test_helper.dart';

const _source = 'fixture';
const _comic = 'comic';
const _info = PluginComicDetailSource(
  from: _source,
  normalInfo: normal.NormalComicAllInfo(
    comicInfo: normal.ComicInfo(
      id: _comic,
      title: 'Comic',
      titleMeta: [],
      description: '',
      cover: normal.ComicImage(id: '', url: '', name: ''),
      metadata: [],
    ),
    eps: [
      normal.Ep(id: 'chapter-1', name: 'First chapter', order: 1),
      normal.Ep(id: 'chapter-2', name: 'Second chapter', order: 2),
    ],
    recommend: [],
  ),
  raw: {},
);

Future<ComicReadRouteArgs> _openReader(
  WidgetTester tester,
  StringSelectCubit status, {
  ReaderHistoryService? historyService,
  void Function()? beforeTap,
}) async {
  ComicReadRouteArgs? launch;
  final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        name: 'DetailFixture',
        path: '/',
        builder: (_, _) => BlocProvider.value(
          value: status,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => goToComicRead(
                  context,
                  _comic,
                  ComicEntryType.normal,
                  _info,
                  _source,
                  historyService: historyService,
                ),
                child: const Text('Read'),
              ),
            ),
          ),
        ),
      ),
      NamedRouteDef(
        name: ComicReadRoute.name,
        path: '/read',
        builder: (_, data) {
          launch = data.argsAs<ComicReadRouteArgs>();
          return const Scaffold(body: Text('Reader route'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
  await tester.pumpAndSettle();

  beforeTap?.call();
  await tester.tap(find.text('Read'));
  await tester.pumpAndSettle();
  expect(find.text('Reader route'), findsOneWidget);
  return launch!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => objectbox.unifiedHistoryBox.removeAll());

  for (final deleted in [true, false]) {
    testWidgets(
      deleted
          ? 'read ignores a deleted chapter even with stale resume text'
          : 'read uses new history even before resume text refreshes',
      (tester) async {
        final status = StringSelectCubit();
        addTearDown(status.close);
        if (deleted) status.setDate('Second chapter / 8');
        final launch = await _openReader(
          tester,
          status,
          beforeTap: () {
            objectbox.unifiedHistoryBox.put(
              createTestHistory('$_source:$_comic')
                ..source = _source
                ..comicId = _comic
                ..chapterId = 'chapter-2'
                ..chapterOrder = 2
                ..pageIndex = 9
                ..deleted = deleted,
            );
          },
        );
        expect(launch.logicalKey, deleted ? 'chapter-1' : 'chapter-2');
        expect(
          launch.type,
          deleted ? ComicEntryType.normal : ComicEntryType.history,
        );
      },
    );
  }

  for (final tombstone in [false, true]) {
    testWidgets(
      tombstone
          ? 'an explicit deletion newer than a queued save cancels resume'
          : 'quick reopen selects the chapter and page from the held final save',
      (tester) async {
        final status = StringSelectCubit();
        addTearDown(status.close);
        final stored = createTestHistory('$_source:$_comic')
          ..source = _source
          ..comicId = _comic
          ..chapterId = 'chapter-1'
          ..chapterOrder = 1
          ..pageIndex = 6
          ..updatedAt = DateTime.utc(2024);
        objectbox.unifiedHistoryBox.put(stored);
        final gate = Completer<void>();
        final history = ReaderHistoryService.forTesting(
          readHistory: (_, _) => objectbox.unifiedHistoryBox.getAll().single,
          writePayload: (payload) async {
            await gate.future;
            return applyReaderHistorySnapshot(objectbox, payload);
          },
        );
        final old = history.loadHistory(
          source: _source,
          comicId: _comic,
          comicInfo: _info,
        );
        history.markLoaded(old);
        history.startPeriodicSave(
          old,
          () => HistorySnapshot(
            pageIndex: 17,
            chapterOrder: 2,
            epInfo: NormalComicEpInfo(epId: 'chapter-2'),
          ),
        );
        final finalWrite = history.stop(old);
        try {
          final launch = await _openReader(
            tester,
            status,
            historyService: history,
            beforeTap: () {
              if (tombstone) {
                objectbox.unifiedHistoryBox.put(
                  stored
                    ..deleted = true
                    ..updatedAt = DateTime.now().toUtc().add(
                      const Duration(seconds: 1),
                    ),
                );
              }
            },
          );
          expect(
            objectbox.unifiedHistoryBox.getAll().single.chapterId,
            'chapter-1',
          );
          expect(launch.logicalKey, tombstone ? 'chapter-1' : 'chapter-2');
          expect(
            launch.type,
            tombstone ? ComicEntryType.normal : ComicEntryType.history,
          );
          final reopened = history.loadHistory(
            source: launch.from,
            comicId: launch.comicId,
            comicInfo: launch.comicInfo,
          );
          expect(
            history.historyPageIndex(reopened, launch.logicalKey),
            tombstone ? 0 : 17,
          );
          unawaited(history.stop(reopened));
        } finally {
          gate.complete();
          await tester.pump();
          await finalWrite;
        }
      },
    );
  }
}
