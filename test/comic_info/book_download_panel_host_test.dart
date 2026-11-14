import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/widgets/book_download_panel.dart';
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

class _Parent extends StatefulWidget {
  const _Parent();
  @override
  State<_Parent> createState() => _ParentState();
}

class _ParentState extends State<_Parent> {
  final panel = BookDownloadPanelController();
  final scroll = ScrollController();
  int reads = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('retained detail'),
      actions: [
        TextButton(
          onPressed: () {
            void read(UnifiedComicDownload record) {
              expect(record.source, 'a');
              reads++;
            }

            panel.open(
              context,
              source: 'a',
              comicId: 'comic',
              title: 'book',
              onRead: read,
            );
            panel.open(
              context,
              source: 'a',
              comicId: 'comic',
              title: 'book',
              onRead: read,
            );
          },
          child: const Text('open scoped'),
        ),
      ],
    ),
    body: ListView(
      controller: scroll,
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(height: 44, child: Text('saved filter · row $i')),
      ],
    ),
  );
}

DownloadTask task(String source, String comic, String name, String state) =>
    DownloadTask()
      ..comicId = comic
      ..comicName = name
      ..isCompleted = state == 'completed'
      ..isDownloading = state == 'running'
      ..taskInfo = DownloadTaskJson(
        from: source,
        comicId: comic,
        comicName: name,
        chapterRef: DownloadChapterTaskRef(
          chapterId: name,
          title: name,
          order: 1,
        ),
        stateCode: state,
        completedImages: 2,
        totalImages: 4,
        lastErrorMessage: state == 'failed' ? 'fixture failure' : '',
      );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    objectbox.downloadTaskBox.removeAll();
    objectbox.unifiedDownloadBox.removeAll();
  });
  for (final host in ['navigator', 'router']) {
    for (final style in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'book panel preserves $host parent and isolates tasks $style $brightness',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            var globalOpens = 0;
            final owner = Object();
            DownloadCenterNavigation.attach(owner, () async {
              globalOpens++;
              return true;
            });
            addTearDown(() => DownloadCenterNavigation.detach(owner));
            objectbox.downloadTaskBox.putMany([
              task('a', 'comic', 'running chapter', 'running'),
              task('a', 'comic', 'failed chapter', 'failed'),
              task('a', 'comic', 'completed task only', 'completed'),
              task('b', 'comic', 'other source', 'completed'),
              task('a', 'another', 'other book', 'failed'),
            ]);
            RootStackRouter? router;
            Widget app;
            Widget bridge(BuildContext context, Widget? child) =>
                TouchHoverIntentScope(
                  child: MaterialUiCompatibilityBridge(
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(1.6)),
                      child: child!,
                    ),
                  ),
                );
            if (host == 'router') {
              router = RootStackRouter.build(
                routes: [
                  NamedRouteDef(
                    name: 'Parent',
                    path: '/',
                    initial: true,
                    builder: (_, _) => const _Parent(),
                  ),
                ],
              );
              addTearDown(router.dispose);
              app = MaterialApp.router(
                theme: ThemeData(brightness: brightness),
                builder: bridge,
                routerConfig: router.config(),
              );
            } else {
              app = MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: bridge,
                home: const _Parent(),
              );
            }
            await tester.pumpWidget(
              AppInterfaceStyleScope(style: preference, child: app),
            );
            await tester.pumpAndSettle();
            final parent = tester.state<_ParentState>(find.byType(_Parent));
            parent.scroll.jumpTo(300);
            await tester.pumpAndSettle();
            await tester.tap(find.text('open scoped'));
            await tester.pumpAndSettle();
            expect(find.byType(BookDownloadPanel), findsOneWidget);
            expect(find.text('other source'), findsNothing);
            expect(find.text('other book'), findsNothing);
            expect(find.text('failed chapter'), findsOneWidget);
            expect(find.text('fixture failure'), findsOneWidget);
            expect(
              find.text(t.download.statusDownloadProgress(percent: 50)),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('book-download.read')),
              findsNothing,
              reason: 'A completed transfer log alone is not a local resource',
            );
            expect(globalOpens, 0);
            expect(
              tester.state(find.byType(_Parent, skipOffstage: false)),
              same(parent),
            );
            await tester.tap(find.byKey(const ValueKey('book-download.close')));
            await tester.pumpAndSettle();
            expect(parent.scroll.offset, 300);
            if (router != null) expect(router.stack.length, 1);
            final saved = createTestDownload('a:comic')
              ..source = 'a'
              ..comicId = 'comic';
            objectbox.unifiedDownloadBox.put(saved);
            await tester.tap(find.text('open scoped'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('book-download.read')),
              findsNothing,
              reason: 'An empty record must not claim completed chapters',
            );
            Navigator.of(tester.element(find.byType(BookDownloadPanel))).pop();
            await tester.pumpAndSettle();
            expect(parent.reads, 0);
            expect(parent.scroll.offset, 300);
            saved.chapters = jsonEncode([
              {
                'id': 'chapter',
                'logicalKey': 'chapter',
                'name': 'stored chapter',
                'order': 1,
                'images': [
                  {'id': 'page', 'name': 'page.jpg', 'path': 'page.jpg'},
                ],
              },
            ]);
            objectbox.unifiedDownloadBox.put(saved);
            await tester.tap(find.text('open scoped'));
            await tester.pumpAndSettle();
            final read = find.byKey(const ValueKey('book-download.read'));
            await tester.scrollUntilVisible(
              read,
              160,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            expect(find.text(t.download.downloadedChapters), findsOneWidget);
            expect(find.text(t.download.offlineReading), findsOneWidget);
            await tester.tap(read);
            await tester.pumpAndSettle();
            expect(parent.reads, 1);
            expect(find.byType(BookDownloadPanel), findsNothing);
            expect(parent.scroll.offset, 300);
            expect(globalOpens, 0);
            objectbox.downloadTaskBox.removeAll();
            objectbox.unifiedDownloadBox.removeAll();
            await tester.tap(find.text('open scoped'));
            await tester.pumpAndSettle();
            expect(find.text(t.download.noTasks), findsOneWidget);
            expect(
              tester.getSize(find.byType(BookDownloadPanel)).height,
              lessThan(450),
              reason:
                  'An empty panel contracts to its content instead of occupying 80%',
            );
            expect(
              find.byKey(const ValueKey('book-download.read')),
              findsNothing,
            );
            await tester.tap(find.byKey(const ValueKey('book-download.close')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
