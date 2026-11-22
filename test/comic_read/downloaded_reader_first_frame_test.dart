import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_read/view/comic_read.dart';
import 'package:zephyr/page/comic_read/widgets/image/image_display.dart';
import 'package:zephyr/page/donwload_task/service/download_chapter_reader.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';
import '../service/reader_history_session_test.dart' as fixture;
import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('a downloaded page paints while online image requests are busy', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const source = 'offline-first-frame';
    const comicId = 'first-frame';
    const chapterId = 'chapter';
    const fileName = 'first.png';
    final saved = createTestDownload('$source:$comicId')
      ..source = source
      ..comicId = comicId
      ..detailJson = jsonEncode({
        'comicInfo': fixture.info.toJson(),
        'eps': [],
        'recommend': [],
      })
      ..chapters = jsonEncode([
        {
          'id': chapterId,
          'name': 'First chapter',
          'order': 1,
          'images': [
            {'path': fileName, 'url': 'https://unused.invalid/page.png'},
          ],
        },
      ]);
    objectbox.unifiedDownloadBox.put(saved);
    final savedPath = (await tester.runAsync(() async {
      await useIsolatedDownloadFixture();
      final path = await DownloadAssetStore(
        from: source,
        cartoonId: comicId,
        chapterId: chapterId,
        path: fileName,
        pictureType: PictureType.page,
      ).canonicalDownloadPath();
      final file = File(path);
      await file.parent.create(recursive: true);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xff44aacc), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 24);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      return path;
    }))!;

    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in const [
      MethodChannel('window_manager'),
      MethodChannel('system_ui_control'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final connectivity = DownloadConnectivityFixture();
    addTearDown(connectivity.close);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final global = GlobalSettingCubit();
    final preference = ComicReadPreferenceCubit();
    final selection = StringSelectCubit();
    addTearDown(global.close);
    addTearDown(preference.close);
    addTearDown(selection.close);
    final router = RootStackRouter.build(
      routes: [
        NamedRouteDef(
          name: 'DownloadFirstFrameHost',
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Downloads')),
        ),
        NamedRouteDef(
          name: ComicReadRoute.name,
          path: '/read',
          builder: (_, data) {
            final args = data.argsAs<ComicReadRouteArgs>();
            return ComicReadPage(
              comicId: args.comicId,
              order: args.order,
              chapterId: args.chapterId,
              requestId: args.requestId,
              storageChapterId: args.storageChapterId,
              logicalKey: args.logicalKey,
              chapterExtern: args.chapterExtern,
              epsNumber: args.epsNumber,
              from: args.from,
              stringSelectCubit: args.stringSelectCubit,
              type: args.type,
              comicInfo: args.comicInfo,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    final onlineRequests = ImageRecoveryHub.requests;
    final release = Completer<void>();
    final pending = Future.wait([
      for (var i = 0; i < onlineRequests.concurrency; i++)
        onlineRequests.run<void>(
          'blocking-online-image-$i',
          () => release.future,
        ),
    ]);

    try {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: global),
            BlocProvider.value(value: preference),
          ],
          child: MaterialApp.router(routerConfig: router.config()),
        ),
      );
      await tester.pumpAndSettle();
      final route = DownloadChapterReader.findRoute(
        source: source,
        comicId: comicId,
        chapterKey: chapterId,
        stringSelectCubit: selection,
      )!;
      await router.pushAll([route]);

      final image = find.byWidgetPredicate(
        (widget) => widget is ImageDisplay && widget.imagePath == savedPath,
      );
      final decoded = find.descendant(
        of: image,
        matching: find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        ),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (decoded.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(decoded.hitTestable(), findsOneWidget);
      expect(release.isCompleted, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      release.complete();
      await pending;
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
