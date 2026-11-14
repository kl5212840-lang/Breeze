import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cbor/simple.dart' as cbor;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/page/setting/common/plugin_account_avatar.dart';
import 'package:zephyr/service/download/download_asset_store.dart'
    show DownloadAssetStore;
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/type/enum.dart';
import '../test_helper.dart';

final _red = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);
final _blue = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==',
);
Future<List<int>> _rgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return pixels!.buffer.asUint8List().toList();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class _AvatarApi extends RustLibApi {
  int status = 200;
  Uint8List bytes = _red;
  Future<void>? responseGate;
  final sources = <String>[];
  @override
  String crateApiSimpleEncodePath({required String path}) =>
      sha256.convert(utf8.encode(path)).toString();
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('avatar-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async => Uint8List.fromList(utf8.encode('{}'));

  @override
  Future<Uint8List> crateApiQjsQjsFetchImage({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    expect(fnPath, 'fetchImageBytes');
    expect(jsonDecode(argsJson)['url'], 'https://images.example/avatar.jpg');
    sources.add(normalizePluginId(runtimeName));
    final response = Uint8List.fromList(
      cbor.cbor.encode({
        'version': 1,
        'bytes': bytes,
        'statusCode': status,
        'responseBodyLength': bytes.length,
        'error': null,
      }),
    );
    await responseGate;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected avatar boundary ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  final api = _AvatarApi();
  const source = PluginAccountAuthenticationService.copy;
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(() async {
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
  });
  testWidgets('a successful HTTP challenge page is not a cached picture', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final calls = api.sources.length;
      api.status = 200;
      api.bytes = Uint8List.fromList(
        utf8.encode('<!doctype html><title>Verify</title>'),
      );
      Future<String> load() => getCachePicture(
        from: source,
        url: 'https://images.example/avatar.jpg',
        path: 'cache-audit/gateway.jpg',
        pictureType: PictureType.cover,
      );
      try {
        await expectLater(load(), throwsA(isA<Exception>()));
        expect(api.sources.length, calls + 1);
        // A WebP container that declares bytes we never received remains
        // retryable, and must not occupy the successful cache entry either.
        api.bytes = Uint8List.fromList([
          ...ascii.encode('RIFF'),
          40,
          0,
          0,
          0,
          ...ascii.encode('WEBP'),
        ]);
        await expectLater(
          load(),
          throwsA(
            isA<DownloadPictureInvalidPayload>().having(
              (error) => error.retryable,
              'retryable',
              isTrue,
            ),
          ),
        );
        expect(api.sources.length, calls + 2);
        api.bytes = _red;
        final path = await load();
        expect(await File(path).readAsBytes(), _red);
        expect(api.sources.length, calls + 3);
        expect(await load(), path);
        expect(api.sources.length, calls + 3);
      } finally {
        api.bytes = _red;
        api.sources.clear();
      }
    });
  });

  testWidgets('a plugin can return a valid URL without a cover path', (
    tester,
  ) async {
    await tester.runAsync(() async {
      api.bytes = _red;
      api.status = 200;
      Future<String> load() => getCachePicture(
        from: source,
        url: 'https://images.example/avatar.jpg',
        cartoonId: 'url-only-cover-fixture',
        pictureType: PictureType.cover,
      );
      try {
        final path = await load();
        expect(path, isNot('404'));
        expect(await File(path).readAsBytes(), _red);
        expect(await load(), path);
        expect(api.sources, [source]);
      } finally {
        api.sources.clear();
      }
    });
  });
  testWidgets(
    'offline download never promotes a gateway response from the online cache',
    (tester) async {
      await tester.runAsync(() async {
        const path = 'cache-audit/previous-version.jpg';
        const work = 'cached-gateway-fixture';
        const url = 'https://images.example/avatar.jpg';
        final store = DownloadAssetStore(
          from: source,
          path: path,
          cartoonId: work,
          chapterId: '',
          pictureType: PictureType.cover,
        );
        final gateway = utf8.encode('<html><title>Verify</title></html>');
        await DownloadAssetStore.writeBytesAtomically(
          Uint8List.fromList(gateway),
          finalPath: await store.canonicalCachePath(),
        );
        api.status = 200;
        api.bytes = _red;
        try {
          final result = await downloadPictureResult(
            from: source,
            url: url,
            path: path,
            cartoonId: work,
            pictureType: PictureType.cover,
          );
          expect(result.path, await store.canonicalDownloadPath());
          expect(await File(result.path).readAsBytes(), _red);
          expect(api.sources, [source]);
        } finally {
          api.sources.clear();
        }
      });
    },
  );
  testWidgets(
    'real proof-to-avatar transport retries same URL and preserves good scoped cache on 404',
    (tester) async {
      await tester.runAsync(() async {
        final sentinel = File(
          '${TestObjectBoxHelper.tempPath}/unrelated-avatar-sentinel',
        );
        await sentinel.writeAsString('keep');
        final proof = PluginAccountAuthenticationService(source)
            .fromServerResponse({
              'data': {
                'avatar': {
                  'id': 'copy-42',
                  'url': 'https://images.example/avatar.jpg',
                  'path': 'users/42/avatar.jpg',
                },
                'extern': {'userId': 'copy-42', 'username': 'Member'},
              },
            });
        final avatar = proof.toUserInfo()['avatar'] as Map;
        expect(avatar['path'], 'users/42/avatar.jpg');
        // Demonstrate the actual old failure boundary: no request can occur when
        // the proof projection loses its path, regardless of a valid URL.
        expect(
          await getCachePicture(from: source, url: avatar['url'], path: ''),
          '404',
        );
        expect(api.sources, isEmpty);
        Future<Uint8List> load({bool refresh = false}) =>
            loadPluginAccountAvatar(
              source: source,
              identity: proof.serverIdentity,
              url: avatar['url'],
              path: avatar['path'],
              refresh: refresh,
            );
        expect(await load(), _red);
        expect(api.sources, [source]);
        expect(await load(), _red);
        expect(api.sources, hasLength(1));
        api.bytes = _blue;
        expect(await load(refresh: true), _blue);
        expect(api.sources, [source, source]);
        api.status = 404;
        await expectLater(
          load(refresh: true),
          throwsA(isA<DownloadPictureNotFoundException>()),
        );
        final retained = await load();
        expect(
          retained,
          _blue,
          reason: 'a failed refresh cannot remove the previous good portrait',
        );
        expect(
          await _rgba(retained),
          [0, 0, 255, 255],
          reason:
              'the persistent avatar is the refreshed blue image, never the previous red image',
        );
        expect(api.sources, hasLength(3));
        expect(await sentinel.readAsString(), 'keep');
      });
    },
  );
  testWidgets(
    'URL-only Web avatar has a cache key; old-account completion cannot replace it',
    (tester) async {
      await tester.runAsync(() async {
        var current = true;
        final gate = Completer<Uint8List>();
        final old = loadPluginAccountAvatar(
          source: 'web-avatar-source',
          identity: 'A',
          url: 'https://images.example/avatar.jpg',
          path: '',
          refresh: true,
          download: (_, _) => gate.future,
          isCurrent: () => current,
        );
        final next = await loadPluginAccountAvatar(
          source: 'web-avatar-source',
          identity: 'B',
          url: 'https://images.example/avatar.jpg',
          path: '',
          download: (_, actualSource) async {
            expect(actualSource, 'web-avatar-source');
            return _blue;
          },
        );
        expect(next, _blue);
        current = false;
        gate.complete(_red);
        await expectLater(old, throwsStateError);
        expect(
          await loadPluginAccountAvatar(
            source: 'web-avatar-source',
            identity: 'B',
            url: 'https://images.example/avatar.jpg',
            path: '',
            download: (_, _) async =>
                throw StateError('must use only the current account cache'),
          ),
          _blue,
        );
        await expectLater(
          loadPluginAccountAvatar(
            source: 'web-avatar-source',
            identity: 'B',
            url: 'https://images.example/avatar.jpg',
            path: '',
            refresh: true,
            download: (_, _) async =>
                Uint8List.fromList(utf8.encode('not an image')),
          ),
          throwsA(anything),
        );
        expect(
          await loadPluginAccountAvatar(
            source: 'web-avatar-source',
            identity: 'B',
            url: 'https://images.example/avatar.jpg',
            path: '',
            download: (_, _) async => throw StateError('keep image'),
          ),
          _blue,
        );
      });
    },
  );

  testWidgets('same-URL refresh survives hiding, supersession and a 503', (
    tester,
  ) async {
    final visibility = VisibilityDetectorController.instance;
    final previousInterval = visibility.updateInterval;
    visibility.updateInterval = Duration.zero;
    final gate = Completer<void>();
    api.sources.clear();
    api.status = 200;
    api.bytes = _red;

    Widget host({required int revision, bool visible = true}) => MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: visible,
          child: PluginAccountAvatar(
            source: source,
            identity: 'refresh-host-account',
            url: 'https://images.example/avatar.jpg',
            path: 'users/42/avatar.jpg',
            revision: revision,
          ),
        ),
      ),
    );

    Uint8List? displayedBytes() {
      final image = find.byType(Image);
      if (image.evaluate().isEmpty) return null;
      return switch (tester.widget<Image>(image).image) {
        ResizeImage(imageProvider: MemoryImage(:final bytes)) => bytes,
        MemoryImage(:final bytes) => bytes,
        _ => null,
      };
    }

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 100 && !condition(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(condition(), isTrue);
    }

    try {
      await tester.pumpWidget(host(revision: 0));
      await waitFor(() => listEquals(displayedBytes(), _red));
      expect(api.sources, [source]);

      await tester.pumpWidget(host(revision: 0, visible: false));
      await tester.pumpWidget(host(revision: 1, visible: false));
      expect(api.sources, [source]);
      api.responseGate = gate.future;
      await tester.pumpWidget(host(revision: 1));
      await waitFor(() => api.sources.length == 2);

      await tester.pumpWidget(host(revision: 2));
      api.responseGate = null;
      api.status = 503;
      gate.complete();
      await waitFor(() => api.sources.length == 3);
      expect(displayedBytes(), _red);

      api.status = 200;
      api.bytes = _blue;
      await waitFor(() => listEquals(displayedBytes(), _blue));
      await tester.pump(const Duration(seconds: 3));
      expect(api.sources, List.filled(4, source));
    } finally {
      api.responseGate = null;
      if (!gate.isCompleted) gate.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      visibility.updateInterval = previousInterval;
    }
  });
}
