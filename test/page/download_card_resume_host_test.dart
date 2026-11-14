import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

import '../download_fixture.dart';
import '../service/reader_history_session_test.dart' as fixture;
import '../test_helper.dart';

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('single download cards show only the matching local position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(useIsolatedDownloadFixture);
    VideoLocalResources.invalidate();
    tester.view.physicalSize = const Size(540, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const source = 'card-resume';
    const comicId = 'comic';
    final watch = Uri.parse('https://hanime1.me/watch?v=47');
    final mp4 = Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
    Future<String> saveVideo(String quality) async {
      final id = VideoLocalResources.identity(source, watch, quality);
      final file = await VideoLocalResources.file(id);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(mp4);
      await VideoLocalResources.saved(
        resourceId: id,
        bytes: mp4.length,
        source: source,
        video: watch,
        title: 'Offline video $quality',
        quality: quality,
        taskKey: 'cleared-$quality',
        durationMs: 180000,
      );
      await VideoLocalResources.hideTasks({'cleared-$quality'});
      return id;
    }

    Future<void> writeWatch(String? resource, {bool complete = false}) =>
        VideoWatchHistory.record(
          source,
          VideoWatchRecord(
            watchUrl: watch,
            title: 'Offline video',
            position: Duration(seconds: complete ? 180 : 12),
            duration: const Duration(minutes: 3),
            updatedAt: DateTime.now().toUtc(),
            completed: complete,
            localResourceId: resource,
          ),
        );

    final comic = createTestDownload('$source:$comicId')
      ..source = source
      ..comicId = comicId
      ..title = 'Offline comic'
      ..detailJson = jsonEncode({'comicInfo': fixture.info.toJson()})
      ..chapters = jsonEncode([
        {
          'id': 'request',
          'logicalKey': 'chapter',
          'storageChapterId': 'storage',
          'name': 'Chapter',
          'order': 1,
          'images': [
            for (var i = 1; i <= 4; i++) {'id': '$i', 'path': '$i.jpg'},
          ],
        },
      ]);
    late String primaryId;
    await tester.runAsync(() async {
      objectbox.unifiedDownloadBox.put(comic);
      objectbox.unifiedHistoryBox.put(
        fixture.history(source: source, comicId: comicId, pageIndex: 4),
      );
      primaryId = await saveVideo('720p');
      await saveVideo('1080p');
      await writeWatch(null);
    });

    await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
    final comicPosition = find.byKey(
      const ValueKey('download-position.comic:$source:$comicId'),
    );
    final videoPosition = find.byKey(
      ValueKey('download-position.video:$primaryId'),
    );
    await _until(
      tester,
      () => find.text('Offline video 1080p').evaluate().isNotEmpty,
    );
    expect(comicPosition, findsNothing, reason: 'other chapter history');
    expect(find.text('Watched to 00:12'), findsNothing, reason: 'two versions');

    await tester.runAsync(() async {
      await ComicChapterReadingProgress.instance.record(
        source: source,
        comicId: comicId,
        chapterId: 'chapter',
        pageIndex: 2,
        lastVisiblePage: 2,
        pageCount: 4,
      );
      await writeWatch(primaryId);
    });
    await _until(
      tester,
      () => find.text('Watched to 00:12').evaluate().isNotEmpty,
    );
    expect(find.text('Read to page 2'), findsOneWidget);
    expect(find.text('Watched to 00:12'), findsOneWidget);
    expect(comicPosition, findsOneWidget);
    expect(videoPosition, findsOneWidget);

    await tester.runAsync(() => writeWatch(primaryId, complete: true));
    await _until(
      tester,
      () => find.text(t.videoPlayback.watchedComplete).evaluate().isNotEmpty,
    );
    expect(find.text('Watched to 00:12'), findsNothing);
    expect(videoPosition, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
