import 'dart:async';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _source = 'persistent-poster';
final _page = Uri.parse('https://hanime1.me/watch?v=47');

bool _isResizedLocalImage(Widget widget, String path) {
  if (widget is! Image || widget.image is! ResizeImage) return false;
  final image = (widget.image as ResizeImage).imageProvider;
  return image is FileImage && image.file.path == path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
  });

  Future<File> seed({
    String? cover,
    int? durationMs,
    String? sourceDuration,
  }) async {
    final id = VideoLocalResources.identity(_source, _page, '720p');
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
    );
    await VideoLocalResources.saved(
      resourceId: id,
      bytes: 24,
      source: _source,
      video: _page,
      title: '旧版已完成视频',
      quality: '720p',
      taskKey: 'cleared-transfer',
      cover: cover,
      durationMs: durationMs,
      sourceDuration: sourceDuration,
    );
    await VideoLocalResources.hideTasks({'cleared-transfer'});
    return file;
  }

  test(
    'a real saved file keeps its poster after transfer history is cleared',
    () async {
      final file = await seed(
        cover: 'https://poster.invalid/original.png',
        durationMs: 125000,
        sourceDuration: '9:59',
      );
      final rows = await DownloadCenterResources.readVideos();
      expect(rows.single['resourceOnly'], isTrue);
      expect(rows.single['cover'], 'https://poster.invalid/original.png');
      expect(rows.single['source'], _source);
      expect(rows.single['durationMs'], 125000);
      expect(rows.single['sourceDuration'], '9:59');
      final merged = DownloadCenterResources.mergeVideos([
        {
          'key': 'old-task',
          'resourceId': rows.single['resourceId'],
          'status': 'saved',
          'local': true,
          'at': 1,
        },
      ], await VideoLocalResources.read());
      expect(merged.single['cover'], 'https://poster.invalid/original.png');
      expect(merged.single['source'], _source);
      expect(merged.single['durationMs'], 125000);
      expect(merged.single['sourceDuration'], '9:59');
      expect(await file.length(), 24);
    },
  );

  test(
    'legacy poster recovery matches source and canonical watch without rewriting the owned index',
    () async {
      final file = await seed();
      final index = File('${file.parent.path}/index.json');
      final before = await index.readAsBytes();
      Future<void> history(String source, Uri page, String poster) =>
          VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: page,
              title: '已读资料',
              position: const Duration(seconds: 8),
              duration: const Duration(minutes: 2),
              updatedAt: DateTime.now().toUtc(),
              completed: false,
              coverUrl: Uri.parse(poster),
            ),
          );
      await history(
        'another-source',
        _page,
        'https://poster.invalid/wrong-source.png',
      );
      await history(
        _source,
        Uri.parse('https://hanime1.me/watch?v=48'),
        'https://poster.invalid/wrong-work.png',
      );
      final unmatched = (await DownloadCenterResources.readVideos()).single;
      expect(unmatched['cover'], isNull);
      expect(unmatched['durationMs'], isNull);
      await VideoLibraryStore.shared.setFavorite(
        _source,
        ApiVideoItem(
          id: '47',
          title: '本机真实收藏',
          detailUrl: _page,
          coverUrl: Uri.parse('https://poster.invalid/favorite.png'),
        ),
        true,
      );
      expect(
        (await DownloadCenterResources.readVideos()).single['cover'],
        'https://poster.invalid/favorite.png',
      );
      await history(
        _source,
        Uri.parse('https://hanime1.me/watch?v=47&tracking=omit'),
        'https://poster.invalid/history.png',
      );
      final recovered = (await DownloadCenterResources.readVideos()).single;
      expect(recovered['cover'], 'https://poster.invalid/history.png');
      expect(
        recovered['durationMs'],
        const Duration(minutes: 2).inMilliseconds,
      );
      expect(
        recovered['durationMs'],
        isNot(const Duration(seconds: 8).inMilliseconds),
      );
      expect(await index.readAsBytes(), orderedEquals(before));
      expect(await file.length(), 24);
    },
  );

  test(
    'known poster does not suppress exact local-history total-duration recovery',
    () async {
      final file = await seed(cover: 'https://poster.invalid/keep.png');
      final index = File('${file.parent.path}/index.json');
      final before = await index.readAsBytes();
      await VideoWatchHistory.record(
        _source,
        VideoWatchRecord(
          watchUrl: _page,
          title: '本机观看记录',
          position: const Duration(seconds: 11),
          duration: const Duration(seconds: 190),
          updatedAt: DateTime.now().toUtc(),
          completed: false,
          coverUrl: Uri.parse('https://poster.invalid/other.png'),
        ),
      );
      final row = (await DownloadCenterResources.readVideos()).single;
      expect(row['cover'], 'https://poster.invalid/keep.png');
      expect(row['durationMs'], 190000);
      expect(await index.readAsBytes(), orderedEquals(before));
    },
  );

  testWidgets('persistent download page uses its durable local official poster without a remote cover URL', (tester) async {
    late String localPath;
    final privacy = CollectionCoverPrivacyController.instance;
    final previous = privacy.state.value;
    privacy.state.value = const CollectionCoverPrivacySettings(ready: true, enabled: false);
    addTearDown(() => privacy.state.value = previous);
    await tester.runAsync(() async {
      await seed(durationMs: 125000);
      final row = (await DownloadCenterResources.readVideos()).single;
      final pixels = Uint8List.fromList(img.encodePng(img.Image(width: 120, height: 240)
        ..clear(img.ColorRgb8(25, 160, 65))));
      final image = ResizeImage(MemoryImage(pixels), width: 96);
      final ready = Completer<void>();
      final stream = image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((_, _) { if (!ready.isCompleted) ready.complete(); },
        onError: (Object error, StackTrace? stack) => ready.completeError(error, stack));
      stream.addListener(listener);
      await ready.future;
      try {
        VideoDownloadedDetails.rememberDecodedPoster(source: _source, page: _page,
          url: 'https://signed-poster.invalid/p.jpg?token=NOT_PERSISTED', provider: image);
        await VideoDownloadedDetails.retainForResource(row, waitForPoster: true);
        localPath = (await VideoDownloadedDetails.localPosterForResource(row))!;
      } finally { stream.removeListener(listener); }
    });
    await tester.pumpWidget(const MaterialApp(home: DownloadTaskPage()));
    final deadline = Stopwatch()..start();
    Finder localImage() => find.byWidgetPredicate((widget) => _isResizedLocalImage(widget, localPath));
    while (localImage().evaluate().isEmpty && deadline.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(localImage(), findsOneWidget);
    expect(find.byType(VideoThumbnail), findsNothing,
      reason: 'a retained local cover does not create a source network thumbnail');
    expect(tester.getSize(find.byType(DownloadVideoTaskCover)), const Size(88, 132));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'actual persistent download host protects the missing-poster fallback and keeps its video badge',
    (tester) async {
      const capacity = MethodChannel('breeze.download.capacity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(capacity, (_) async => 1024 * 1024 * 1024);
      addTearDown(() => messenger.setMockMethodCallHandler(capacity, null));
      late File file;
      await tester.runAsync(() async {
        file = await seed(durationMs: 125000, sourceDuration: '9:59');
      });
      final privacy = CollectionCoverPrivacyController.instance;
      final previous = privacy.state.value;
      final previousImage = privacy.localImagePath.value;
      final artwork = File(
        'asset/image/assets/default_cover.png',
      ).absolute.path;
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      privacy.state.value = const CollectionCoverPrivacySettings(
        ready: true,
        enabled: true,
        style: CollectionCoverStyle.custom,
      );
      privacy.localImagePath.value = artwork;
      Future<void> until(bool Function() ready) async {
        final deadline = Stopwatch()..start();
        while (!ready() && deadline.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), isTrue);
      }

      try {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: const MaterialApp(home: DownloadTaskPage()),
          ),
        );
        await until(() => find.text('旧版已完成视频').evaluate().isNotEmpty);
        final cover = find.byType(DownloadVideoTaskCover);
        expect(cover, findsOneWidget);
        final overlay = find.descendant(
          of: cover,
          matching: find.byType(VideoCoverOverlay),
        );
        expect(overlay, findsOneWidget);
        expect(tester.widget<VideoCoverOverlay>(overlay).durationText, '2:05');
        expect(
          find.descendant(of: cover, matching: find.text('2:05')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cover, matching: find.text('9:59')),
          findsNothing,
        );
        final filter = find.descendant(
          of: cover,
          matching: find.byType(ImageFiltered),
        );
        expect(tester.widget<ImageFiltered>(filter).enabled, isFalse);
        final original = find.ancestor(of: filter, matching: find.byType(Opacity)).first;
        expect(tester.widget<Opacity>(original).opacity, 0);
        final replacement = find.descendant(
          of: cover,
          matching: find.byWidgetPredicate(
            (widget) => _isResizedLocalImage(widget, artwork),
          ),
        );
        expect(replacement, findsOneWidget);
        privacy.state.value = privacy.state.value.copyWith(enabled: false);
        await tester.pump();
        expect(tester.widget<ImageFiltered>(filter).enabled, isFalse);
        expect(tester.widget<Opacity>(original).opacity, 1);
        expect(replacement, findsNothing);
        expect(await tester.runAsync(file.length), 24);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        privacy.state.value = previous;
        privacy.localImagePath.value = previousImage;
      }
    },
  );
}
