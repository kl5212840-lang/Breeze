import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    Finder action(String work, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('download-state-row.comic:$source:$work')),
      matching: find.byIcon(icon),
    );
    final resume = action('Paused work', Icons.play_arrow_rounded);
    await _until(tester, () => resume.evaluate().isNotEmpty);
    expect(action('Running work', Icons.pause_rounded), findsOneWidget);
    expect(action('Retry work', Icons.refresh_rounded), findsOneWidget);
    expect(action('Paused work', Icons.refresh_rounded), findsNothing);

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
