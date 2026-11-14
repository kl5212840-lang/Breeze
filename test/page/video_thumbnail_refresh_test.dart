import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

class _ImageClient extends Fake implements HttpClient {
  Uint8List bytes = Uint8List(0);
  Completer<void>? waitForResponse;
  final responseStatuses = <int>[];
  final requests = <Uri>[];
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url);
    return _ImageRequest(
      bytes,
      waitForResponse?.future,
      responseStatuses.isEmpty ? 200 : responseStatuses.removeAt(0),
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.bytes, [this.waitForResponse, this.status = 200]);
  final Uint8List bytes;
  final Future<void>? waitForResponse;
  final int status;
  @override
  final headers = _Headers();
  @override
  Future<HttpClientResponse> close() async {
    await waitForResponse;
    return _ImageResponse(bytes, status);
  }
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes, this.statusCode);
  final Uint8List bytes;
  @override
  final int statusCode;
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


class _PosterStore extends VideoLibraryStore {
  _PosterStore(this.snapshot) : super(deviceId: 'poster-refresh-fixture');
  final VideoLibrarySnapshot snapshot;
  bool fail = false;
  int reads = 0;
  @override
  Future<VideoLibrarySnapshot> read() async {
    reads++;
    if (fail) {
      throw StateError('local fixture read failed');
    }
    return snapshot;
  }
}

void main() {
  final controller = CollectionCoverPrivacyController.instance;
  late _ImageClient client;
  final home = Uri.parse('https://thumbnail-fixture.test/');

  Future<Uint8List> png(WidgetTester tester) async => (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes!.buffer.asUint8List();
  }))!;

  Future<void> until(
    WidgetTester tester,
    bool Function() condition, {
    Duration step = const Duration(milliseconds: 16),
  }) async {
    for (var i = 0; i < 80 && !condition(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(step);
    }
    expect(condition(), isTrue);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _ImageClient();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Future<void> withClient(Future<void> Function() body) async {
    // Flutter verifies painting globals before package:test tearDown runs.
    debugNetworkImageHttpClientProvider = () => client;
    try {
      await HttpOverrides.runZoned(body, createHttpClient: (_) => client);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  }

  testWidgets('missing video posters use play while portrait defaults remain separate', (tester) async {
    final item = ApiVideoItem(id: 'missing', title: 'Video', detailUrl: home.resolve('/watch'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 80, height: 120,
      child: ApiVideoPoster(item: item)))));
    final poster = find.byType(VideoThumbnail);
    expect(find.descendant(of: poster, matching: find.byIcon(Icons.play_arrow_rounded)), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(tester.getSize(poster), const Size(80, 120));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 56, height: 56,
      child: VideoThumbnail(url: '', referrer: home)))));
    expect(find.byIcon(Icons.image_outlined), findsOneWidget,
      reason: 'the shared thumbnail default remains available to avatar and folder consumers');
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ApiVideoEmpty(title: 'No videos'))));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a source placeholder preserves the poster tap and refreshes with the page',
    (tester) async {
      await withClient(() async {
        client.bytes = Uint8List.fromList(
          utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
        );
        final network = Future<Null>.value(null);
        var opened = 0;
        Widget host(int refreshToken) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 96,
              height: 144,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => opened++,
                child: VideoCoverOverlay(
                  child: VideoThumbnail(
                    url: home.resolve('/failed-poster.jpg').toString(),
                    referrer: home,
                    network: network,
                    refreshToken: refreshToken,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(0));
        final poster = find.byType(VideoThumbnail);
        await until(
          tester,
          () =>
              client.requests.isNotEmpty &&
              find
                  .descendant(
                    of: poster,
                    matching: find.byType(CircularProgressIndicator),
                  )
                  .evaluate()
                  .isEmpty,
        );
        await tester.pump(const Duration(seconds: 4));
        expect(client.requests, hasLength(1));
        expect(
          find.descendant(
            of: poster,
            matching: find.byIcon(Icons.play_arrow_rounded),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('重试'), findsNothing);
        expect(find.byIcon(Icons.movie_outlined), findsNothing);
        expect(tester.getSize(poster), const Size(96, 144));
        await tester.tapAt(tester.getTopRight(poster) + const Offset(-22, 22));
        expect(opened, 1);
        client.bytes = await png(tester);
        await tester.pumpWidget(host(1));
        await until(
          tester,
          () => find
              .byWidgetPredicate(
                (widget) => widget is RawImage && widget.image != null,
              )
              .evaluate()
              .isNotEmpty,
        );
        expect(client.requests, hasLength(2));
        expect(
          find.descendant(
            of: poster,
            matching: find.byIcon(Icons.play_arrow_rounded),
          ),
          findsNothing,
          reason: 'the placeholder leaves when the actual image decodes',
        );
        expect(tester.getSize(poster), const Size(96, 144));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'native poster transport separates missing covers from temporary failures',
    (tester) async {
      final visibility = VisibilityDetectorController.instance;
      final previous = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      addTearDown(() => visibility.updateInterval = previous);
      ImageRecoveryHub.instance.updateConnectivity([ConnectivityResult.wifi]);
      final image = await png(tester);
      final svg = Uint8List.fromList(
        utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
      );
      const source = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
      const channel = MethodChannel('breeze.video.network');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final context = OmoNetworkContext('bika-poster-fixture', source: source);
      final requests = <String, int>{};
      final chunks = <String, Uint8List>{};
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        final id = args['request'] as String?;
        switch (call.method) {
          case 'start':
            final url = Uri.parse(args['url'] as String);
            final count = requests.update(
              url.path,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            final status = switch (url.path) {
              '/missing.jpg' => 404,
              '/temporary.jpg' when count <= 2 => 503,
              _ => 200,
            };
            if (status == 200) {
              chunks[id!] = url.path == '/placeholder.jpg' ? svg : image;
            }
            return {
              'status': status,
              'url': url.toString(),
              'headers': {'content-type': 'image/jpeg'},
            };
          case 'read':
            return chunks.remove(id);
          case 'cancel':
          case 'close':
            return null;
        }
        throw MissingPluginException(call.method);
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoNetworkScope(
                source: source,
                network: Future.value(context),
                child: Row(
                  children: [
                    for (final name in ['missing', 'placeholder', 'temporary'])
                      SizedBox(
                        width: 96,
                        height: 144,
                        child: ApiVideoPoster(
                          item: ApiVideoItem(
                            id: 'animate:$name',
                            title: name,
                            detailUrl: home.resolve('/videos/$name'),
                            coverUrl: home.resolve('/$name.jpg'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final decoded = find.byWidgetPredicate(
          (w) => w is RawImage && w.image != null,
        );
        await until(
          tester,
          () => decoded.evaluate().length == 1,
          step: const Duration(milliseconds: 100),
        );
        await tester.pump(const Duration(seconds: 10));
        expect(requests, {
          '/missing.jpg': 1,
          '/placeholder.jpg': 1,
          '/temporary.jpg': 3,
        });
        expect(find.byTooltip('重试'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await context.close();
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  testWidgets('explicit refresh retries failed same URL but leaves decoded image cached', (tester) async {
    await withClient(() async {
      final network = Future<Null>.value(null);
      Widget host(int token) => MaterialApp(home: Scaffold(body: SizedBox(
        width: 96, height: 144,
        child: VideoThumbnail(url: home.resolve('/poster.jpg').toString(),
          referrer: home, network: network, refreshToken: token),
      )));
      client.bytes = Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'));
      await tester.pumpWidget(host(0));
      await until(tester, () => find.byTooltip('重试').evaluate().isNotEmpty);
      expect(client.requests, hasLength(1));
      // No URL mutation, global cache clearing or automatic retry loop.
      client.bytes = await png(tester);
      await tester.pumpWidget(host(1));
      await until(tester, () => find.byWidgetPredicate((w) => w is RawImage && w.image != null).evaluate().isNotEmpty);
      expect(client.requests, hasLength(2));
      final image = tester.widget<RawImage>(find.byType(RawImage)).image;
      await tester.pumpWidget(host(2));
      await tester.pump(const Duration(seconds: 2));
      expect(client.requests, hasLength(2));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(image));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('custom protection file decodes while original is pending and remains after failure', (tester) async {
    await withClient(() async {
      final previous = controller.state.value;
      final previousPath = controller.localImagePath.value;
      final bytes = await png(tester);
      final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('breeze-poster-')))!;
      final file = File('${dir.path}/replacement.png');
      await tester.runAsync(() => file.writeAsBytes(bytes));
      final gate = Completer<void>();
      client.waitForResponse = gate;
      client.responseStatuses.add(503);
      controller.state.value = const CollectionCoverPrivacySettings(
        enabled: true, ready: true, style: CollectionCoverStyle.custom);
      controller.localImagePath.value = file.path;
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body:
          CollectionCoverPrivacyScope(child: SizedBox(width: 96, height: 144,
            child: VideoThumbnail(url: home.resolve('/pending.jpg').toString(), referrer: home),
          )),
        )));
        Finder replacement() => find.byWidgetPredicate((widget) {
          if (widget is! Image || widget.image is! ResizeImage) return false;
          final original = (widget.image as ResizeImage).imageProvider;
          return original is FileImage && original.file.path == file.path;
        });
        await until(tester, () => replacement().evaluate().isNotEmpty &&
          find.descendant(of: replacement(), matching: find.byWidgetPredicate((w) => w is RawImage && w.image != null)).evaluate().isNotEmpty);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(client.requests, hasLength(1));
        gate.complete();
        await until(tester, () => find.byTooltip('重试').evaluate().isNotEmpty);
        expect(replacement(), findsOneWidget);
        expect(find.ancestor(of: find.byTooltip('重试'), matching: find.byType(ImageFiltered)), findsNothing);
        expect(client.requests, hasLength(1));
      } finally {
        if (!gate.isCompleted) {
          gate.complete();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.state.value = previous;
        controller.localImagePath.value = previousPath;
        await tester.runAsync(() => dir.delete(recursive: true));
      }
    });
  });
  testWidgets('actual favorite pull retries failed poster only after a successful local refresh', (tester) async {
    await withClient(() async {
      final item = ApiVideoItem(id: '42', title: '收藏封面',
        detailUrl: home.resolve('/voddetail/42.html'), coverUrl: home.resolve('/42.jpg'));
      final store = _PosterStore(VideoLibrarySnapshot(favorites: {
        VideoLibraryStore.itemKey('poster-source', item.id): VideoLibraryEntry(
          clock: 1, device: 'fixture', deleted: false,
          data: {'source': 'poster-source', 'item': item.toLibraryJson(), 'addedAt': 1}),
      }));
      addTearDown(store.dispose);
      client.bytes = Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: VideoNetworkScope(
        source: 'poster-source', network: Future<Null>.value(null),
        child: ApiVideoFavorites(
          source: 'poster-source', mode: ApiVideoView.grid, store: store,
          onOpen: (_) async {},
        ),
      ))));
      await until(tester, () => client.requests.isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty);
      expect(client.requests, hasLength(1));
      Future<void> pull(int expectedReads) async {
        final scroll = find.descendant(of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable)).first;
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.physics.shouldAcceptUserOffset(position), isTrue);
        await tester.drag(scroll, const Offset(0, 350));
        await until(tester, () => store.reads >= expectedReads);
        for (var frame = 0; frame < 50; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      client.bytes = await png(tester);
      store.fail = true;
      await pull(2);
      expect(client.requests, hasLength(1), reason: 'A failed data refresh is not a successful image-retry intent.');
      store.fail = false;
      await pull(3);
      await until(tester, () => find.byWidgetPredicate((w) => w is RawImage && w.image != null).evaluate().isNotEmpty);
      expect(client.requests, hasLength(2));
      expect(store.reads, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

}
