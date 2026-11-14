import '../video_local_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';
import 'package:zephyr/page/video/video_profile_header.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_library_view.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
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

class _PendingReadStore extends VideoLibraryStore {
  _PendingReadStore(this.initial) : super(deviceId: 'privacy-loading');
  final Future<VideoLibrarySnapshot> initial;
  @override
  Future<VideoLibrarySnapshot> read() => initial;
}

final _home = Uri.parse('https://privacy-video.test/');
final _item = ApiVideoItem(
  id: '1',
  title: '清晰标题',
  detailUrl: _home.resolve('/voddetail/1.html'),
  coverUrl: _home.resolve('/cover.png'),
  remarks: '完整进度',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ImageClient images;
  late CollectionCoverPrivacySettings previous;
  final controller = CollectionCoverPrivacyController.instance;
  const connectivity = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => null);
    SharedPreferences.setMockInitialValues({});
    await useIsolatedVideoResources();
    await controller.ensureLoaded();
    previous = controller.state.value;
    controller.state.value = const CollectionCoverPrivacySettings(
      enabled: true,
      ready: true,
    );
    images = _ImageClient();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
    controller.state.value = previous;
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  // Both NetworkImage and OmoNetworkImage's dart:io fallback use these
  // same PNG bytes. Keep real providers, streams and engine decoding intact.
  void imageHostTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      debugNetworkImageHttpClientProvider = () => images;
      try {
        await HttpOverrides.runZoned(
          () => body(tester),
          createHttpClient: (_) => images,
        );
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });
  }

  Future<void> imageBytes(WidgetTester tester) async {
    images.bytes = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.red, BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 8, 8),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return bytes!.buffer.asUint8List();
    }))!;
  }

  Future<void> decoded(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      // ImmutableBuffer/codec work completes on real engine/IO events. Fake
      // pumpAndSettle cannot deliver those while a loading spinner animates.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final thumbnails = find.byType(VideoThumbnail).evaluate().toList();
      final allDecoded =
          thumbnails.isNotEmpty &&
          thumbnails.every((element) {
            return find
                .descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is RawImage && widget.image != null,
                  ),
                )
                .evaluate()
                .isNotEmpty;
          });
      if (allDecoded) {
        expect(
          images.requests,
          isNotEmpty,
          reason: 'The real image pipeline must consume the PNG HTTP fixture.',
        );
        // Advance a bounded pair of frames after data and every image arrive.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        return;
      }
    }
    fail(
      'PNG fixture did not decode in every visible VideoThumbnail; '
      'thumbnails=${find.byType(VideoThumbnail).evaluate().length}, '
      'requests=${images.requests.length}',
    );
  }

  Future<void> tapProtection(
    WidgetTester tester,
    Finder button, {
    required bool enabled,
  }) async {
    expect(controller.state.value.enabled, !enabled);
    // The app controller survives testWidgets callbacks. Its serialized Future
    // tail must stay in the shared real zone, rather than retaining a completed
    // previous test's FakeAsync microtask scheduler. Exercise the real pointer
    // callback there; widget frames and every UI assertion remain in fake time.
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    // Disabling only publishes after the preference write succeeds. Deliver
    // real plugin completion events before asserting image state or geometry.
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final preferences = await SharedPreferences.getInstance();
      if (controller.state.value.enabled == enabled &&
          preferences.getBool(CollectionCoverPrivacyController.enabledKey) ==
              enabled) {
        await tester.pump(const Duration(milliseconds: 100));
        return;
      }
    }
    expect(
      controller.state.value.enabled,
      enabled,
      reason:
          'The tapped privacy action must finish successfully within 800ms.',
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        CollectionCoverPrivacyController.enabledKey,
      ),
      enabled,
    );
  }

  Finder getImagePrivacy() => find.descendant(
    of: find.byType(VideoThumbnail),
    matching: find.byType(CollectionCoverPrivacy),
  );

  imageHostTest(
    'an SVG response behind a JPEG URL does not automatically reload forever',
    (tester) async {
      images.bytes = Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">'
          '<circle cx="150" cy="150" r="80" fill="gray"/></svg>',
        ),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 96,
                  height: 144,
                  child: VideoThumbnail(
                    url: _home.resolve('/placeholder.jpg').toString(),
                    referrer: _home,
                    network: Future.value(null),
                  ),
                ),
              ),
            ),
          ),
        );
        final retry = find.byTooltip('重试');
        for (var i = 0; i < 50 && retry.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(retry, findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(images.requests, hasLength(1));
        await tester.tap(retry);
        for (var i = 0; i < 30 && images.requests.length < 2; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(images.requests, hasLength(2));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    },
  );

  imageHostTest(
    'protection leaves loading and failed-image retry clear and working',
    (tester) async {
      await imageBytes(tester);
      final gate = Completer<void>();
      images.waitForResponse = gate;
      images.responseStatuses.addAll([503, 200]);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CollectionCoverPrivacyScope(
                  child: SizedBox(
                    width: 96,
                    height: 144,
                    child: VideoThumbnail(
                      url: _item.coverUrl.toString(),
                      referrer: _home,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final activeFilter = find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        );
        final loading = find.byType(CircularProgressIndicator);
        expect(loading, findsOneWidget);
        expect(
          find.ancestor(of: loading, matching: activeFilter),
          findsNothing,
          reason: 'Only original pixels are protected, not loading feedback.',
        );
        gate.complete();
        final retry = find.byTooltip('重试');
        for (var i = 0; i < 40 && retry.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(retry, findsOneWidget);
        expect(find.ancestor(of: retry, matching: activeFilter), findsNothing);
        await tester.tap(retry);
        await decoded(tester);
        expect(controller.state.value.enabled, isTrue);
        expect(images.requests, hasLength(2));
        expect(activeFilter, findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    },
  );

  imageHostTest(
    'enter protected, finish original request while switching privacy without reloading',
    (tester) async {
      await imageBytes(tester);
      final gate = Completer<void>();
      images.waitForResponse = gate;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CollectionCoverPrivacyScope(
                  child: SizedBox(
                    width: 96,
                    height: 144,
                    child: VideoThumbnail(
                      url: _item.coverUrl.toString(),
                      referrer: _home,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 30 && images.requests.isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(images.requests, hasLength(1));
        final original = tester.state(find.byType(Image));
        controller.state.value = controller.state.value.copyWith(
          enabled: false,
        );
        await tester.pump();
        expect(tester.state(find.byType(Image)), same(original));
        controller.state.value = controller.state.value.copyWith(enabled: true);
        await tester.pump();
        gate.complete();
        await decoded(tester);
        for (final style in CollectionCoverStyle.values) {
          controller.state.value = controller.state.value.copyWith(
            style: style,
          );
          await tester.pump();
          expect(tester.state(find.byType(Image)), same(original));
        }
        controller.state.value = controller.state.value.copyWith(
          enabled: false,
        );
        await tester.pump();
        expect(tester.state(find.byType(Image)), same(original));
        expect(images.requests, hasLength(1));
        expect(
          find.byWidgetPredicate(
            (widget) => widget is RawImage && widget.image != null,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    },
  );

  imageHostTest(
    'actual video image is private while duration, selection, title and source remain above it',
    (tester) async {
      await imageBytes(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionCoverPrivacyScope(
              child: Column(
                children: [
                  SizedBox(
                    width: 240,
                    height: 135,
                    child: VideoCardCover(
                      url: _item.coverUrl.toString(),
                      referrer: _home,
                      metadata: const VideoPublicMetadata(duration: '12:34'),
                      current: true,
                    ),
                  ),
                  const Text('清晰标题'),
                  const Text('清晰来源'),
                  const LinearProgressIndicator(value: .4),
                ],
              ),
            ),
          ),
        ),
      );
      await decoded(tester);
      expect(getImagePrivacy(), findsOneWidget);
      final videoMarker = find.byKey(const ValueKey('video-cover-marker'));
      expect(videoMarker, findsOneWidget);
      expect(
        find.ancestor(
          of: videoMarker,
          matching: find.byType(CollectionCoverPrivacy),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: getImagePrivacy(),
          matching: find.byWidgetPredicate(
            (widget) => widget is ImageFiltered && widget.enabled,
          ),
        ),
        findsWidgets,
      );
      for (final text in ['12:34', '清晰标题', '清晰来源']) {
        expect(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsNothing,
        );
      }
      expect(
        find.ancestor(
          of: find.byType(LinearProgressIndicator),
          matching: find.byType(CollectionCoverPrivacy),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final mode in ApiVideoView.values) {
      imageHostTest(
        'API and Omo collections keep image-only privacy and a stable button at 320pt 2x $style $mode',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await imageBytes(tester);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final store = VideoLibraryStore(
            deviceId: 'privacy',
            storageKey: 'privacy-$style-${mode.name}',
          );
          addTearDown(store.dispose);
          await store.setFavorite('api', _item, true);
          final client = OmoSiteClient(
            home: _home,
            request: (operation, _) async => operation == 'account'
                ? {
                    'kind': 'account',
                    'account': {'id': 'fixture', 'name': 'User'},
                  }
                : {
                    'kind': 'favorites',
                    'rawCount': 1,
                    'hasMore': false,
                    'items': [
                      {
                        'recordId': '1',
                        'vodId': '1',
                        'item': _item.toLibraryJson(),
                      },
                    ],
                  },
          );
          addTearDown(client.dispose);
          Future<void> mount(Widget page) => tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(body: page),
              ),
            ),
          );
          for (final page in <Widget>[
            ApiVideoFavorites(
              source: 'api',
              mode: mode,
              store: store,
              onOpen: (_) async {},
            ),
            OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              mode: mode,
              onOpen: (_) async {},
            ),
          ]) {
            await mount(page);
            await decoded(tester);
            final button = find.byType(CollectionCoverPrivacyButton);
            expect(button, findsOneWidget);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
            final editor = find.byType(TextField);
            if (page is OmoSiteFavoritesPage) {
              final originalEye = tester.getRect(button);
              expect(editor, findsNothing);
              await tester.tap(
                find.byKey(const ValueKey('omo-favorites.search-toggle')),
              );
              await tester.pump();
              expect(
                editor,
                findsOneWidget,
                reason: 'One editor opens from the source header.',
              );
              expect(button, findsNothing);
              expect(tester.getSize(editor).height, greaterThanOrEqualTo(44));
              expect(
                find.ancestor(
                  of: editor,
                  matching: find.byType(CustomScrollView),
                ),
                findsNothing,
              );
              await tester.tap(
                find.byKey(const ValueKey('omo-favorites.search-toggle')),
              );
              await tester.pump();
              expect(editor, findsNothing);
              expect(tester.getRect(button), originalEye);
            } else {
              expect(
                editor,
                findsOneWidget,
                reason: 'Move the original editor; do not duplicate it.',
              );
              final editorRect = tester.getRect(editor);
              final eyeRect = tester.getRect(button);
              expect(editorRect.center.dy, closeTo(eyeRect.center.dy, .001));
              final scopeRect = tester.getRect(find.byType(KeywordScopeMenu));
              expect(scopeRect.left - editorRect.right, closeTo(8, .001));
              expect(eyeRect.left, closeTo(scopeRect.right, .001));
              expect(
                find.ancestor(
                  of: editor,
                  matching: find.byType(CustomScrollView),
                ),
                findsNothing,
              );
            }
            expect(
              find.ancestor(
                of: button,
                matching: find.byType(CustomScrollView),
              ),
              findsNothing,
            );
            expect(getImagePrivacy(), findsOneWidget);
            expect(
              find.descendant(
                of: getImagePrivacy(),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ImageFiltered && widget.enabled,
                ),
              ),
              findsWidgets,
            );
            expect(
              find.ancestor(
                of: find.text(_item.title),
                matching: find.byType(CollectionCoverPrivacy),
              ),
              findsNothing,
            );
            final stable = tester.getRect(button);
            await tapProtection(tester, button, enabled: false);
            expect(
              find.descendant(
                of: getImagePrivacy(),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ImageFiltered && widget.enabled,
                ),
              ),
              findsNothing,
            );
            expect(tester.getRect(button), stable);
            await tapProtection(tester, button, enabled: true);
            expect(
              find.descendant(
                of: getImagePrivacy(),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ImageFiltered && widget.enabled,
                ),
              ),
              findsWidgets,
            );
            expect(tester.getRect(button), stable);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }

  imageHostTest(
    'public shelf protects favorite, history and download without affecting title, source and progress',
    (tester) async {
      await imageBytes(tester);
      final store = VideoLibraryStore(
        deviceId: 'privacy',
        storageKey: 'public-privacy',
      );
      final changes = ValueNotifier(0);
      addTearDown(store.dispose);
      addTearDown(changes.dispose);
      final data = VideoBookshelfPaneDataSource(
        load: (_, _) async => [
          VideoBookshelfRow(
            key: 'row',
            source: 'api',
            item: _item,
            progress: '3:00',
            updatedAt: DateTime.utc(2026),
          ),
        ],
        sourceNames: () async => {'api': '清晰来源'},
        open: (_, _) async {},
        remove: (_, _) async {},
        enrich: (row) async => row.item,
        store: store,
        changes: changes,
      );
      for (final mode in ShelfPageMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoBookshelfPane(
                key: ValueKey(mode),
                mode: mode,
                search: const SearchStatusState(),
                dataSource: data,
              ),
            ),
          ),
        );
        await decoded(tester);
        final filters = find.descendant(
          of: getImagePrivacy(),
          matching: find.byWidgetPredicate(
            (widget) => widget is ImageFiltered && widget.enabled,
          ),
        );
        expect(filters, findsWidgets);
        expect(find.byType(CollectionCoverPrivacyButton), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text(_item.title),
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: find.textContaining('清晰来源'),
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  imageHostTest(
    'favorite privacy controls stay in the same 44pt slot through loading and empty states',
    (tester) async {
      final store = VideoLibraryStore(
        deviceId: 'privacy',
        storageKey: 'empty-privacy',
      );
      final changes = ValueNotifier(0);
      final rows = Completer<List<VideoBookshelfRow>>();
      addTearDown(store.dispose);
      addTearDown(changes.dispose);
      final data = VideoBookshelfPaneDataSource(
        load: (_, _) => rows.future,
        sourceNames: () async => {},
        open: (_, _) async {},
        remove: (_, _) async {},
        enrich: (row) async => row.item,
        store: store,
        changes: changes,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoBookshelfPane(
              mode: ShelfPageMode.favorite,
              search: const SearchStatusState(),
              dataSource: data,
            ),
          ),
        ),
      );
      await tester.pump();
      final button = find.byType(CollectionCoverPrivacyButton);
      final before = tester.getRect(button);
      expect(before.size, const Size(44, 44));
      rows.complete([]);
      await tester.pumpAndSettle();
      expect(tester.getRect(button), before);
      final pendingRead = Completer<VideoLibrarySnapshot>();
      final pendingStore = _PendingReadStore(pendingRead.future);
      addTearDown(pendingStore.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoFavorites(
              source: 'empty',
              mode: ApiVideoView.grid,
              store: pendingStore,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      final loadingEye = tester.getRect(button);
      final loadingEditor = tester.getRect(find.byType(TextField));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      pendingRead.complete(VideoLibrarySnapshot());
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);
      expect(tester.getSize(button), const Size(44, 44));
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final emptyEditor = tester.getRect(find.byType(TextField));
      expect(tester.getRect(button), loadingEye);
      expect(emptyEditor, loadingEditor);
      expect(
        emptyEditor.center.dy,
        closeTo(tester.getRect(button).center.dy, .001),
      );
      final account = Completer<Map<String, dynamic>>();
      final client = OmoSiteClient(
        home: _home,
        request: (operation, _) async => operation == 'account'
            ? await account.future
            : {
                'kind': 'favorites',
                'rawCount': 0,
                'hasMore': false,
                'items': [],
              },
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmoSiteFavoritesPage(
              client: client,
              source: 'empty-omo',
              active: true,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      final beforeOmo = tester.getRect(button);
      expect(beforeOmo.size, const Size(44, 44));
      expect(find.byType(TextField), findsNothing);
      account.complete({
        'kind': 'account',
        'account': {'id': 'fixture', 'name': 'User'},
      });
      await tester.pumpAndSettle();
      expect(tester.getRect(button), beforeOmo);
      await tester.tap(
        find.byKey(const ValueKey('omo-favorites.search-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(button, findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('omo-favorites.search-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.getRect(button), beforeOmo);
      expect(tester.takeException(), isNull);
    },
  );

  for (final ratio in [2 / 3, 4 / 3]) {
    imageHostTest(
      'API history protects actual $ratio posters in grid and list and keeps progress clear',
      (tester) async {
        await imageBytes(tester);
        await VideoWatchHistory.record(
          'poster-ratio',
          VideoWatchRecord(
            watchUrl: _item.detailUrl.replace(
              queryParameters: {'line': '1', 'episode': '1'},
            ),
            title: _item.title,
            coverUrl: _item.coverUrl,
            position: const Duration(minutes: 3),
            duration: const Duration(minutes: 10),
            updatedAt: DateTime.utc(2026),
            completed: false,
          ),
        );
        for (final mode in ApiVideoView.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ApiVideoHistory(
                  source: 'poster-ratio',
                  home: _home,
                  posterAspectRatio: ratio,
                  mode: mode,
                  onOpen: (_, _) async {},
                ),
              ),
            ),
          );
          await decoded(tester);
          expect(
            tester
                .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
                .posterAspectRatio,
            ratio,
          );
          expect(
            find.descendant(
              of: getImagePrivacy(),
              matching: find.byWidgetPredicate(
                (widget) => widget is ImageFiltered && widget.enabled,
              ),
            ),
            findsWidgets,
          );
          expect(
            find.ancestor(
              of: find.textContaining('3:00'),
              matching: find.byType(CollectionCoverPrivacy),
            ),
            findsNothing,
          );
          expect(find.byType(CollectionCoverPrivacyButton), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  imageHostTest(
    'personal local history protects portrait thumbnails and leaves progress readable',
    (tester) async {
      await imageBytes(tester);
      await VideoWatchHistory.record(
        'local-history-image',
        VideoWatchRecord(
          watchUrl: _home.resolve('/watch?v=9'),
          title: '本机历史记录',
          coverUrl: _item.coverUrl,
          position: const Duration(minutes: 3),
          duration: const Duration(minutes: 10),
          updatedAt: DateTime.utc(2026),
          completed: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLibraryView(
              source: 'local-history-image',
              siteHost: _home.host,
              onOpenVideo: (_) {},
            ),
          ),
        ),
      );
      await decoded(tester);
      expect(
        find.descendant(
          of: getImagePrivacy(),
          matching: find.byWidgetPredicate(
            (widget) => widget is ImageFiltered && widget.enabled,
          ),
        ),
        findsWidgets,
      );
      expect(
        tester.getSize(find.byType(VideoThumbnail)).aspectRatio,
        closeTo(2 / 3, .001),
      );
      expect(
        find.ancestor(
          of: find.text('本机历史记录'),
          matching: find.byType(CollectionCoverPrivacy),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(LinearProgressIndicator),
          matching: find.byType(CollectionCoverPrivacy),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(CollectionCoverPrivacyButton)),
        const Size(44, 44),
      );
      expect(tester.takeException(), isNull);
    },
  );

  imageHostTest(
    'cloud-history overview masks 2:3 records while both profile-avatar headers stay clear',
    (tester) async {
      await imageBytes(tester);
      final account = {
        'status': 'signedIn',
        'name': '清晰用户',
        'avatarUrl': _home.resolve('/avatar.png').toString(),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPersonalOverview(
              account: account,
              page: _home.resolve('/user/42'),
              tabs: [
                (title: 'History', url: _home.resolve('/user/42/histories')),
              ],
              onTab: (_) {},
              onVideo: (_) {},
              readRecent: (_) async => [
                {
                  'title': '云端记录',
                  'coverUrl': _item.coverUrl.toString(),
                  'watchUrl': _home.resolve('/watch?v=1').toString(),
                  'creatorName': '清晰来源',
                  'duration': '12:34',
                },
              ],
            ),
          ),
        ),
      );
      await decoded(tester);
      final avatar = find.descendant(
        of: find.byType(VideoPersonalAccountHeader),
        matching: find.byType(VideoThumbnail),
      );
      expect(avatar, findsOneWidget);
      expect(
        CollectionCoverPrivacyScope.contains(tester.element(avatar)),
        isFalse,
      );
      expect(
        find.descendant(
          of: avatar,
          matching: find.byWidgetPredicate(
            (widget) => widget is ImageFiltered && widget.enabled,
          ),
        ),
        findsNothing,
      );
      final cover = find.descendant(
        of: find.byType(VideoCardCover),
        matching: find.byType(VideoThumbnail),
      );
      expect(
        CollectionCoverPrivacyScope.contains(tester.element(cover)),
        isTrue,
      );
      expect(
        find.descendant(
          of: cover,
          matching: find.byWidgetPredicate(
            (widget) => widget is ImageFiltered && widget.enabled,
          ),
        ),
        findsWidgets,
      );
      expect(tester.getSize(cover).aspectRatio, closeTo(2 / 3, .001));
      for (final title in ['云端记录', '清晰来源', '清晰用户']) {
        expect(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsNothing,
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionCoverPrivacyScope(
              child: VideoProfileHeader(
                account: account,
                page: _home.resolve('/user/42'),
                onOpenSite: () {},
              ),
            ),
          ),
        ),
      );
      await decoded(tester);
      expect(
        CollectionCoverPrivacyScope.contains(
          tester.element(find.byType(VideoThumbnail)),
        ),
        isFalse,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  imageHostTest(
    'ordinary catalog image stays clear while personal history opts into protection',
    (tester) async {
      await imageBytes(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 240,
              child: ApiVideoPoster(item: _item),
            ),
          ),
        ),
      );
      await decoded(tester);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ImageFiltered && widget.enabled,
        ),
        findsNothing,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLibraryView(
              source: 'history',
              siteHost: _home.host,
              onOpenVideo: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CollectionCoverPrivacyScope), findsOneWidget);
      expect(find.byType(CollectionCoverPrivacyButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
