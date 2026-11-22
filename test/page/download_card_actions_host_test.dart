import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../download_fixture.dart';
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

  testWidgets('work cards distinguish resume, pause and retry', (tester) async {
    tester.view.physicalSize = const Size(320, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(useIsolatedDownloadFixture);
    VideoLocalResources.invalidate();
    addTearDown(objectbox.downloadTaskBox.removeAll);

    const source = 'card-actions';
    DownloadTask addTask(String work, int chapter, String state, String phase) {
      final task = DownloadTask()
        ..comicId = work
        ..comicName = work
        ..isDownloading = state == 'running'
        ..taskInfo = DownloadTaskJson(
          from: source,
          comicId: work,
          comicName: work,
          stateCode: state,
          phaseCode: phase,
          chapterRef: DownloadChapterTaskRef(
            chapterId: 'chapter-$chapter',
            order: chapter,
          ),
        );
      objectbox.downloadTaskBox.put(task);
      return task;
    }

    final paused = addTask('Paused work', 1, 'paused', 'paused');
    final failed = addTask('Paused work', 2, 'failed', 'failed');
    addTask('Running work', 1, 'running', 'downloadingChapter');
    addTask('Retry work', 1, 'queued', 'waitingRetry');

    await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
    Finder action(String work, String label) => find.descendant(
      of: find.byKey(ValueKey('download-state-row.comic:$source:$work')),
      matching: find.widgetWithText(TextButton, label),
    );
    final resume = action('Paused work', 'Resume download');
    await _until(tester, () => resume.evaluate().isNotEmpty);
    expect(action('Running work', 'Pause downloads'), findsOneWidget);
    expect(action('Retry work', t.common.retry), findsOneWidget);
    expect(action('Paused work', t.common.retry), findsNothing);

    const workKey = 'comic:$source:Paused work';
    final workMore = find.byKey(const ValueKey('download-row-more.$workKey'));
    final workCard = find.byKey(const ValueKey('download-card.$workKey'));
    final workTitle = find.byKey(const ValueKey('download-title.$workKey'));
    final mark = find.descendant(
      of: workMore,
      matching: find.byIcon(Icons.more_vert_rounded),
    );
    await _until(tester, () => workMore.hitTestable().evaluate().isNotEmpty);
    expect(tester.getSize(workMore), const Size.square(48));
    expect(tester.getSize(resume).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(workMore).right, tester.getRect(workCard).right - 12);
    expect(tester.getRect(workMore).top, tester.getRect(workTitle).top);
    expect(
      tester
          .getRect(workTitle)
          .contains(
            Offset(tester.getCenter(workTitle).dx, tester.getCenter(mark).dy),
          ),
      isTrue,
    );
    expect(tester.getRect(workMore).overlaps(tester.getRect(resume)), isFalse);
    expect(
      find.descendant(
        of: workCard,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    await tester.tap(workMore);
    final workSheet = find.byKey(
      const ValueKey('download-action-sheet.$workKey'),
    );
    await _until(tester, () => workSheet.evaluate().isNotEmpty);
    expect(
      find.descendant(
        of: workSheet,
        matching: find.byKey(
          const ValueKey('download-action-sheet-title.$workKey'),
        ),
      ),
      findsOneWidget,
    );
    final chapterKey = 'task:${paused.id}';
    final chapterOpen = find.byKey(
      ValueKey('download-chapter-open.$chapterKey'),
    );
    expect(chapterOpen, findsNothing);
    Future<void> closeSheetAndSettle(String key) async {
      final close = find.byKey(ValueKey('download-action-sheet-close.$key'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(close);
      final sheet = find.byKey(
        ValueKey('download-action-sheet.$key'),
        skipOffstage: false,
      );
      await _until(tester, () => sheet.evaluate().isEmpty);
    }

    await closeSheetAndSettle(workKey);
    await _until(tester, () => workTitle.hitTestable().evaluate().isNotEmpty);
    await tester.tap(workTitle);

    final chapterMore = find.byKey(ValueKey('download-row-more.$chapterKey'));
    final chapterResume = find.byKey(
      ValueKey('download-chapter-resume.$chapterKey'),
    );
    await _until(tester, () => chapterMore.hitTestable().evaluate().isNotEmpty);
    expect(tester.getSize(chapterMore), const Size.square(48));
    expect(
      tester.getRect(chapterMore).right,
      tester.getRect(chapterOpen).right - 12,
    );
    expect(
      find.descendant(
        of: chapterResume,
        matching: find.text('Resume download'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(chapterMore).left,
      greaterThanOrEqualTo(tester.getRect(chapterResume).right),
    );
    await tester.tap(chapterMore);
    final chapterSheet = find.byKey(
      ValueKey('download-action-sheet.$chapterKey'),
    );
    await _until(tester, () => chapterSheet.evaluate().isNotEmpty);
    expect(
      find.descendant(
        of: chapterSheet,
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsOneWidget,
    );
    await closeSheetAndSettle(chapterKey);
    final manage = find.byKey(const ValueKey('download-episodes-manage'));
    await _until(tester, () => manage.hitTestable().evaluate().isNotEmpty);
    await tester.tap(manage);
    await tester.pump();
    expect(chapterMore, findsNothing);
    await tester.tap(manage);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await _until(tester, () => resume.hitTestable().evaluate().isNotEmpty);

    await tester.tap(resume);
    await _until(
      tester,
      () =>
          objectbox.downloadTaskBox.get(paused.id)?.taskInfo?.stateCode ==
          'queued',
    );
    expect(
      objectbox.downloadTaskBox.get(failed.id)?.taskInfo?.stateCode,
      'failed',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
