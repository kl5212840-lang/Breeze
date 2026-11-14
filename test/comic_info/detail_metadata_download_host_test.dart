import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/all_chip.dart';
import 'package:zephyr/page/comic_info/widgets/eps.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    objectbox.downloadTaskBox.removeAll();
    objectbox.unifiedDownloadBox.removeAll();
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'metadata disclosure follows actual width and text scale $style $brightness',
        (tester) async {
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          var width = 300.0;
          var scale = 1.0;
          var labels = ['节操', '冒险'];
          late StateSetter rebuild;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, update) {
                      rebuild = update;
                      return MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: width,
                            child: AllChipWidget(
                              comicId: 'fixture',
                              from: 'unknown-source',
                              metadata: ComicInfoMetadata(
                                type: 'tags',
                                name: '标签',
                                value: [
                                  for (final label in labels)
                                    ComicInfoActionItem(name: label),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('展开'),
            findsNothing,
            reason: 'Two fitting tags need no disclosure.',
          );
          rebuild(() => labels = ['第一项长标签', '第二项长标签', '第三项长标签', '第四项长标签']);
          await tester.pumpAndSettle();
          expect(find.text('展开'), findsOneWidget);
          final collapsed = tester.getSize(find.byType(AllChipWidget));
          await tester.tap(find.text('展开'));
          await tester.pumpAndSettle();
          expect(find.text('收起'), findsOneWidget);
          expect(
            tester.getSize(find.byType(AllChipWidget)).height,
            greaterThan(collapsed.height),
          );
          rebuild(() => width = 760);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('comic-metadata.expand')),
            findsNothing,
            reason:
                'The control disappears after enough space becomes available.',
          );
          rebuild(() {
            width = 300;
            scale = 2;
            labels = ['很长的单个标签需要完整换行显示而不能挤出页面'];
          });
          await tester.pumpAndSettle();
          await tester.tap(find.text('展开'));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byType(AllChipWidget)).right,
            lessThanOrEqualTo(300),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'chapter reads real task progress and keeps geometry through completion $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          const ep = Ep(id: 'chapter', name: '第01话与很长很长的标题', order: 1);
          final chapter = const DownloadChapterAdapter().fromEp(ep);
          final old = DownloadTask()
            ..comicId = 'comic'
            ..comicName = 'fixture'
            ..taskInfo = DownloadTaskJson(
              from: 'fixture',
              comicId: 'comic',
              comicName: 'fixture',
              stateCode: 'failed',
              completedImages: 1,
              totalImages: 10,
              chapterRef: DownloadChapterTaskRef(
                chapterId: chapter.id,
                title: ep.name,
                order: 1,
              ),
            );
          objectbox.downloadTaskBox.put(old);
          final task = DownloadTask()
            ..comicId = 'comic'
            ..comicName = 'fixture'
            ..isDownloading = true
            ..taskInfo = DownloadTaskJson(
              from: 'fixture',
              comicId: 'comic',
              comicName: 'fixture',
              completedImages: 2,
              totalImages: 10,
              chapterRef: DownloadChapterTaskRef(
                chapterId: chapter.id,
                title: ep.name,
                order: 1,
              ),
            );
          objectbox.downloadTaskBox.put(task);
          final controller = EpisodeDownloadController()
            ..attach(
              from: 'fixture',
              comicId: 'comic',
              comicTitle: 'fixture',
              allowDownload: true,
            );
          addTearDown(controller.dispose);
          var actions = 0;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                // Mirrors the app's actual legacy/material_ui host.
                // ignore: deprecated_member_use
                builder: (context, child) => MaterialUiCompatibilityBridge(
                  child: TouchHoverIntentScope(
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(2)),
                      child: child!,
                    ),
                  ),
                ),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        EpButtonWidget(
                          doc: ep,
                          chapter: chapter,
                          controller: controller,
                          allInfo: null,
                          epsLength: 2,
                          type: ComicEntryType.normal,
                          comicId: 'comic',
                          from: 'fixture',
                          index: 0,
                          isReversed: false,
                          onAction: () => actions++,
                        ),
                        const Text('next chapter'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final progress = find.byKey(
            ValueKey('chapter-progress:${chapter.id}'),
          );
          final action = find.byKey(
            ValueKey('chapter-download-action:${chapter.id}'),
          );
          expect(tester.widget<LinearProgressIndicator>(progress).value, 0.2);
          final row = tester.getRect(find.byType(EpButtonWidget));
          final next = tester.getTopLeft(find.text('next chapter'));
          expect(tester.getSize(action), const Size(44, 44));
          expect(tester.getRect(progress).bottom, row.bottom);
          await tester.tap(action);
          await tester.pump();
          expect(actions, 1);

          task.taskInfo = task.taskInfo!.copyWith(completedImages: 7);
          objectbox.downloadTaskBox.put(task);
          await _flushDatabase(tester);
          expect(tester.widget<LinearProgressIndicator>(progress).value, 0.7);
          task.isDownloading = false;
          task.taskInfo = task.taskInfo!.copyWith(stateCode: 'failed');
          objectbox.downloadTaskBox.put(task);
          await _flushDatabase(tester);
          expect(progress, findsNothing);
          expect(find.byIcon(Icons.refresh), findsOneWidget);
          await tester.tap(action);
          await tester.pump();
          expect(actions, 2);
          task.isDownloading = true;
          task.taskInfo = task.taskInfo!.copyWith(
            stateCode: 'running',
            totalImages: 0,
          );
          objectbox.downloadTaskBox.put(task);
          await _flushDatabase(tester);
          expect(
            tester.widget<LinearProgressIndicator>(progress).value,
            isNull,
            reason: 'Unknown totals must remain indeterminate.',
          );
          // A transfer log is not proof of a readable resource; completion is
          // taken from the same persistent chapter index as the bookshelf.
          final saved =
              createTestDownload(buildDownloadTaskKey('fixture', 'comic'))
                ..source = 'fixture'
                ..comicId = 'comic'
                ..chapters = jsonEncode([
                  {
                    'id': chapter.id,
                    'logicalKey': chapter.id,
                    'order': 1,
                    'name': ep.name,
                    'images': [
                      {'id': 'page', 'name': 'page.jpg', 'path': 'page.jpg'},
                    ],
                  },
                ]);
          objectbox.unifiedDownloadBox.put(saved);
          await _flushDatabase(tester);
          expect(tester.widget<LinearProgressIndicator>(progress).value, 1);
          expect(find.byIcon(Icons.check_circle), findsOneWidget);
          expect(tester.getRect(find.byType(EpButtonWidget)), row);
          expect(tester.getTopLeft(find.text('next chapter')), next);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

Future<void> _flushDatabase(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}
