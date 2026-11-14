import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

class _Images extends Fake implements HttpClient {
  final requests = <_ImageRequest>[];
  Uint8List bytes = Uint8List(0);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final request = _ImageRequest(url, requests.isEmpty ? 503 : 200, bytes);
    requests.add(request);
    return request;
  }
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.url, this.status, this.bytes);
  final Uri url;
  final int status;
  final Uint8List bytes;
  @override
  final _Headers headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(status, bytes);
}

class _Headers extends Fake implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name.toLowerCase()] = value;
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.statusCode, this.bytes);
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

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  late _Images images;
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    images = _Images();
    debugNetworkImageHttpClientProvider = () => images;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      null,
    );
  });

  testWidgets(
    'successful same-account retry reloads a failed same-URL avatar',
    (tester) async {
      try {
        images.bytes = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(const Color(0xff887799), BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(2, 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          picture.dispose();
          return bytes!.buffer.asUint8List();
        }))!;
        final client = OmoSiteClient(
          home: home,
          request: (_, _) async => {
            'kind': 'account',
            'account': {
              'id': '1',
              'name': '公开测试昵称',
              'avatar': '${home}uploads/avatar.png',
            },
          },
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OmoAccountPage(
                client: client,
                active: true,
                onLocalHistory: () {},
              ),
            ),
          ),
        );
        // A temporary 503 now starts a bounded automatic recovery. Inspect the
        // first failure before its retry delay; settling a loading animation
        // cannot stand in for waiting for the real image codec.
        for (var frame = 0; frame < 30 && images.requests.isEmpty; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await tester.pump();
        expect(images.requests.length, 1);
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        expect(images.requests.length, 2);
        expect(images.requests.last.headers.values['referer'], '$home');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RawImage), findsOneWidget);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        // A live, decoded ResizeImage is now cached. A same-URL refresh must
        // evict that exact key too, not just a bare NetworkImage key.
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(images.requests.length, 3);
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
