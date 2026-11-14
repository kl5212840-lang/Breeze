import 'package:zephyr/service/download/comic_download_preview.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';

import '../download_fixture.dart';
import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _source = 'download-cover-offline';
const _states = ['queued', 'completed', 'failed'];

class _Images extends Fake implements HttpClient {
  _Images(this.bytes);
  final Uint8List bytes;
  final requests = <Uri>[];
  Completer<void>? gate;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requests.add(uri);
    return _Request(bytes, gate?.future);
  }

  @override
  void close({bool force = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.bytes, this.gate);
  final Uint8List bytes;
  final Future<void>? gate;
  @override
  final headers = _Headers();
  @override
  Future<HttpClientResponse> close() async {
    await gate;
    return _Response(bytes);
  }
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue, reason: stage);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List bytes;
  String? activeVideo;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await loadUiPreviewFonts();
    // Synthetic 16:9 PNG exercises real horizontal-poster decoding.
    bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAPAAAACHCAYAAAAoctTrAAACkUlEQVR4nO3TMRXCAABDwdrCC4KwgCIs4KZY6OuSF3LD3zPkjsfzdUrq7EgPkHQ/gKXiAJaKA1gqDmCpOICl4gCWigNYKg5gqTiApeIAlooDWCoOYKk4gKXiAJaKA1gqDmCpOICl4gCWipsD/P289cel/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AhhgAQwwwJul/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AhhgAQwwwJul/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AhhgAQwwwJul/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AhhgAQwwwJul/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AhhgAQwwwJul/wUwwAIYYIA3S/8LYIAFMMAAb5b+F8AAC2CAAd4s/S+AARbAAAO8WfpfAAMsgAEGeLP0vwAGWAADDPBm6X8BDLAABhjgzdL/AljS5QCWigNYKg5gqTiApeIAlooDWCoOYKk4gKXiAJaKA1gqDmCpOICl4gCWigNYKg5gqTiApeIAlooDWCoOYKm4H2EzRJ0BHVf1AAAAAElFTkSuQmCC',
    );
  });
  setUp(() async {
    await useIsolatedDownloadFixture();
    for (var i = 0; i < _states.length; i++) {
      final state = _states[i];
      final task = DownloadTask()
        ..comicId = state
        ..comicName = '漫画$state 的长标题和章节下载进度'
        ..isCompleted = state == 'completed'
        ..taskInfo = DownloadTaskJson(
          from: _source,
          comicId: state,
          comicName: '漫画$state 的长标题和章节下载进度',
          stateCode: state,
          completedImages: 1,
          totalImages: 3,
          chapterRef: const DownloadChapterTaskRef(
            chapterId: '1',
            title: '独立章节与状态',
          ),
        );
      objectbox.downloadTaskBox.put(task);
      final record = createTestDownload('$_source:$state')
        ..source = _source
        ..comicId = state
        ..title = '漫画$state 的长标题和章节下载进度'
        ..cover = jsonEncode({
          'id': state,
          'url': '',
          'path': 'offline-cover-$state',
          'extern': {},
        });
      objectbox.unifiedDownloadBox.put(record);
      final url = Uri.parse(
        'https://download-cover.test/voddetail/${i + 1}.html',
      );
      final title = '视频$state 的长标题和传输状态';
      final cover = 'https://download-cover.test/$state.png';
      final completed = state == 'completed';
      const quality = '1080p';
      final resourceId = completed
          ? VideoLocalResources.identity(_source, url, quality)
          : null;
      final video = await VideoExportRecords.beginTransfer(
        source: _source,
        video: url,
        title: title,
        quality: quality,
        cover: cover,
        resourceId: resourceId,
      );
      if (resourceId != null) {
        final file = await VideoLocalResources.file(resourceId);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]),
        );
        await VideoLocalResources.saved(
          resourceId: resourceId,
          bytes: 24,
          source: _source,
          video: url,
          title: title,
          quality: quality,
          taskKey: video,
          cover: cover,
        );
      }
      await VideoExportRecords.updateTransfer(
        video,
        received: completed ? 24 : 1024,
        total: completed ? 24 : 2048,
        status: i == 0
            ? 'downloading'
            : i == 1
            ? 'saved'
            : 'failed',
        terminal: i != 0,
        resourceId: resourceId,
      );
      if (i == 0) activeVideo = video;
    }
    // Unknown covers keep a neutral icon; protection still applies immediately.
    objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = 'empty'
        ..comicName = '无封面任务'
        ..taskInfo = const DownloadTaskJson(
          from: _source,
          comicId: 'empty',
          comicName: '无封面任务',
          chapterRef: DownloadChapterTaskRef(chapterId: '1'),
        ),
    );
  });
  tearDownAll(() async {
    if (activeVideo != null) {
      await VideoExportRecords.updateTransfer(
        activeVideo!,
        received: 1024,
        total: 2048,
        status: 'cancelled',
        terminal: true,
      );
    }
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });

  testWidgets(
    'full task host protects loading, missing and decoded covers across three states and four appearances',
    (tester) async {
      final privacy = CollectionCoverPrivacyController.instance;
      final previous = privacy.state.value;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const connectivityStatus = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      const capacity = MethodChannel('breeze.download.capacity');
      messenger.setMockMethodCallHandler(connectivityStatus, (_) async => null);
      messenger.setMockMethodCallHandler(
        capacity,
        (_) async => 1024 * 1024 * 1024,
      );
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final channel = MethodChannel(
            '${arguments['viewType']}.${arguments['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var images = _Images(bytes);
      debugNetworkImageHttpClientProvider = () => images;
      try {
        await HttpOverrides.runZoned(() async {
          for (final style in ['system', 'breeze']) {
            for (final brightness in Brightness.values) {
              ComicDownloadPreview.resetForTesting();
              final notifier = ValueNotifier(style);
              images = _Images(bytes)..gate = Completer<void>();
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              privacy.state.value = const CollectionCoverPrivacySettings(
                enabled: true,
                ready: true,
              );
              try {
                await tester.pumpWidget(
                  AppInterfaceStyleScope(
                    style: notifier,
                    child: MaterialApp(
                      theme: ThemeData(
                        brightness: brightness,
                        platform: TargetPlatform.iOS,
                        fontFamily: uiPreviewDirectory == null
                            ? null
                            : "AccountPreview",
                      ),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: const TextScaler.linear(1.7)),
                        child: child!,
                      ),
                      home: VideoNetworkScope(
                        source: _source,
                        network: Future.value(null),
                        child: const RepaintBoundary(
                          key: ValueKey('download-privacy-preview'),
                          child: DownloadTaskPage(),
                        ),
                      ),
                    ),
                  ),
                );
                tester
                    .widget<SourceChromeIconButton>(
                      find.byKey(const ValueKey('download-search-action')),
                    )
                    .onPressed!();
                await tester.pump();
                for (var i = 0; i < _states.length; i++) {
                  final state = _states[i];
                  if (i != 0) images.gate = Completer<void>();
                  tester
                      .widget<SearchQueryField>(find.byType(SearchQueryField))
                      .onChanged!(state);
                  await tester.pump();
                  await _until(
                    tester,
                    () => find.text('视频$state 的长标题和传输状态').evaluate().isNotEmpty,
                    'actual video task metadata matches local query $state',
                  );
                  final thumbnail = find.byType(VideoThumbnail);
                  expect(thumbnail, findsOneWidget);
                  final original = tester.state(thumbnail);
                  await _until(
                    tester,
                    () =>
                        images.requests.any((uri) => uri.path == '/$state.png'),
                    'original thumbnail request starts',
                  );
                  final requestCount = images.requests.length;
                  final target = !privacy.state.value.enabled;
                  // Search owns the header. A shared setting change from
                  // another surface must still update these in-flight covers.
                  unawaited(privacy.setEnabled(target));
                  await _until(
                    tester,
                    () => privacy.state.value.enabled == target,
                    'shared switch changes while image request is pending',
                  );
                  expect(tester.state(thumbnail), same(original));
                  expect(images.requests.length, requestCount);
                  expect(
                    tester
                        .widget<ImageFiltered>(
                          find.descendant(
                            of: thumbnail,
                            matching: find.byType(ImageFiltered),
                          ),
                        )
                        .enabled,
                    target,
                  );
                  images.gate!.complete();
                  await _until(
                    tester,
                    () => find
                        .descendant(
                          of: thumbnail,
                          matching: find.byWidgetPredicate(
                            (widget) =>
                                widget is RawImage && widget.image != null,
                          ),
                        )
                        .evaluate()
                        .isNotEmpty,
                    'real PNG response finishes engine decode',
                  );
                  final comicCover = find.byWidgetPredicate(
                    (widget) =>
                        widget is DownloadComicTaskCover &&
                        widget.comicId == state,
                  );
                  final comic = find.descendant(
                    of: comicCover,
                    matching: find.byType(CoverWidget),
                  );
                  expect(comic, findsOneWidget);
                  final builder = find.descendant(
                    of: comic,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is BlocBuilder<PictureBloc, PictureLoadState>,
                    ),
                  );
                  final bloc = tester.element(builder).read<PictureBloc>();
                  await _until(
                    tester,
                    () => bloc.state.status == PictureLoadStatus.failure,
                    'offline comic transport terminates',
                  );
                  bloc.emit(
                    PictureLoadState(
                      status: PictureLoadStatus.success,
                      imagePath: File(
                        'asset/image/assets/default_cover.png',
                      ).absolute.path,
                    ),
                  );
                  await _until(
                    tester,
                    () => find
                        .descendant(
                          of: comicCover,
                          matching: find.byType(ImageFiltered),
                        )
                        .evaluate()
                        .isNotEmpty,
                    'actual comic BlocBuilder applies its success stream event',
                  );
                  expect(
                    tester
                        .widget<ImageFiltered>(
                          find.descendant(
                            of: comicCover,
                            matching: find.byType(ImageFiltered),
                          ),
                        )
                        .enabled,
                    target,
                  );
                  expect(tester.getSize(comic), const Size(94, 141));
                  expect(
                    tester.getSize(find.byType(DownloadVideoTaskCover)),
                    const Size(94, 141),
                  );
                  final title = find.text('漫画$state 的长标题和章节下载进度');
                  expect(title, findsOneWidget);
                  expect(
                    find.ancestor(
                      of: title,
                      matching: find.byType(ImageFiltered),
                    ),
                    findsNothing,
                  );
                  expect(
                    find.byType(CollectionCoverPrivacyButton),
                    findsNothing,
                  );
                  expect(tester.takeException(), isNull);
                  await writeUiPreview(
                    tester,
                    const ValueKey('download-privacy-preview'),
                    'download-cover-$state-$style-${brightness.name}',
                  );
                  if (i == _states.length - 1) {
                    tester
                        .widget<SearchQueryField>(find.byType(SearchQueryField))
                        .onChanged!('');
                    await tester.pump();
                    final empty = find.byWidgetPredicate(
                      (widget) =>
                          widget is DownloadComicTaskCover &&
                          widget.comicId == 'empty',
                    );
                    await tester.scrollUntilVisible(
                      empty,
                      100,
                      scrollable: find.byType(Scrollable).last,
                    );
                    expect(
                      find.descendant(
                        of: empty,
                        matching: find.byType(CoverWidget),
                      ),
                      findsNothing,
                    );
                    final icon = find.descendant(
                      of: empty,
                      matching: find.byIcon(Icons.menu_book_outlined),
                    );
                    expect(icon, findsOneWidget);
                    expect(
                      tester
                          .widget<ImageFiltered>(
                            find.descendant(
                              of: empty,
                              matching: find.byType(ImageFiltered),
                            ),
                          )
                          .enabled,
                      target,
                    );
                    final before = objectbox.unifiedDownloadBox.count();
                    ComicDownloadPreview.publish(_source, 'empty', {
                      'id': 'empty',
                      'url': '',
                      'path': 'public-first-cover',
                      'extern': {},
                    });
                    await tester.pump();
                    expect(
                      find.descendant(
                        of: empty,
                        matching: find.byType(CoverWidget),
                      ),
                      findsOneWidget,
                    );
                    expect(
                      tester
                          .widget<ImageFiltered>(
                            find.descendant(
                              of: empty,
                              matching: find.byType(ImageFiltered),
                            ),
                          )
                          .enabled,
                      target,
                    );
                    expect(
                      objectbox.unifiedDownloadBox.count(),
                      before,
                      reason:
                          'A cover preview never claims a downloaded chapter',
                    );
                  }
                }
                images.gate = null;
              } finally {
                if (images.gate?.isCompleted == false) images.gate!.complete();
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(milliseconds: 100));
                notifier.dispose();
              }
            }
          }
        }, createHttpClient: (_) => images);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        privacy.state.value = previous;
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(connectivityStatus, null);
        messenger.setMockMethodCallHandler(capacity, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    },
  );
}
