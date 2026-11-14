import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _source = 'download-failure-dialog-fixture';

class _FailingRuntime extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async {
    throw StateError('fixture runtime failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDownAll(connectivity.close);

  final queue = DownloadQueueManager.instance;
  setUp(() => RustLib.initMock(api: _FailingRuntime()));
  tearDown(() {
    queue.stopWatchingTasks();
    objectbox.downloadTaskBox.removeAll();
    RustLib.dispose();
  });

  int seed(String chapter) {
    return objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = 'work'
        ..comicName = 'Fixture work'
        ..taskInfo = DownloadTaskJson(
          from: _source,
          comicId: 'work',
          comicName: 'Fixture work',
          chapterRef: DownloadChapterTaskRef(
            chapterId: chapter,
            title: chapter,
          ),
        ),
    );
  }

  Future<void> start(WidgetTester tester, int expectedFailures) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Download queue host')),
      ),
    );
    await tester.runAsync(() async {
      final failures = queue.progressStream
          .where((event) => event.isFailed)
          .take(expectedFailures)
          .toList();
      queue.watchTasks();
      await failures.timeout(const Duration(seconds: 5));
    });
    await tester.pump();
    // Toastification inserts the list item in the overlay's post-frame
    // callback. Render that item before advancing its entrance animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> dismissNotices(WidgetTester tester) async {
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    toastification.managers.clear();
  }

  testWidgets('chapter failures coalesce without interrupting another page', (
    tester,
  ) async {
    final firstId = seed('First chapter');
    final secondId = seed('Second chapter');
    await start(tester, 2);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(t.common.retry), findsOneWidget);
    expect(find.textContaining('First chapter'), findsOneWidget);
    expect(find.textContaining('Second chapter'), findsNothing);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('First chapter'), findsOneWidget);
    expect(
      objectbox.downloadTaskBox.get(secondId)!.taskInfo!.stateCode,
      'failed',
    );

    // A different attempt for the same row finished while the prompt was open.
    final latest = objectbox.downloadTaskBox.get(firstId)!;
    latest.taskInfo = latest.taskInfo!.copyWith(attempt: 2);
    objectbox.downloadTaskBox.put(latest);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final afterRetry = objectbox.downloadTaskBox.get(firstId)!.taskInfo!;
    expect(afterRetry.attempt, 2);
    expect(afterRetry.stateCode, 'failed');
    expect(objectbox.downloadTaskBox.get(secondId)!.taskInfo!.attempt, 1);
    await dismissNotices(tester);
  });

  testWidgets('the old account failure prompt is removed on account change', (
    tester,
  ) async {
    final id = seed('Account-bound chapter');
    await start(tester, 1);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    pluginSessionWriteFence.advance('unrelated-source');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    pluginSessionWriteFence.advance(_source);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final task = objectbox.downloadTaskBox.get(id)!.taskInfo!;
    expect(task.attempt, 1);
    expect(task.stateCode, 'failed');
    await dismissNotices(tester);
  });
}
