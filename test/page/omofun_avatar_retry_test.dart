import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

class _AvatarPaths extends RustLibApi {
  @override
  String crateApiSimpleEncodePath({required String path}) =>
      sha256.convert(utf8.encode(path)).toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected avatar boundary');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('breeze.video.network');
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  final home = Uri.parse('https://www.omofuna.com/');
  final red = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );
  final blue = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _AvatarPaths());
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });

  testWidgets(
    'account refresh replaces a portrait, navigation reuses it, and failure retains it',
    (tester) async {
      final visibility = VisibilityDetectorController.instance;
      final previousInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      final network = OmoNetworkContext(
        'omo-account-avatar-fixture',
        source: omoNetworkSource,
      );
      final future = Future.value(network);
      var status = 503;
      var requests = 0;
      Uint8List responseBytes = red;
      final chunks = {};
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'close') return null;
        final args = call.arguments as Map;
        final id = args['request'] as String?;
        switch (call.method) {
          case 'start':
            requests++;
            expect(
              Uri.parse(args['url'] as String).path,
              '/uploads/avatar.png',
            );
            final headers = args['headers'] as Map;
            expect(Uri.parse(headers['Referer'] as String).origin, home.origin);
            if (status == 200) chunks[id!] = responseBytes;
            return {
              'status': status,
              'url': args['url'],
              'headers': {'content-type': 'image/png'},
            };
          case 'read':
            return chunks.remove(id);
          case 'cancel':
            return null;
        }
        throw MissingPluginException(call.method);
      });
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => {
          'kind': 'account',
          'account': {
            'id': 'avatar-refresh-fixture',
            'name': '公开测试昵称',
            'avatar': home.resolve('/uploads/avatar.png').toString(),
          },
        },
      );
      Widget host() => MaterialApp(
        home: Scaffold(
          body: VideoNetworkScope(
            source: omoNetworkSource,
            network: future,
            child: OmoAccountPage(
              client: client,
              active: true,
              onLocalHistory: () {},
            ),
          ),
        ),
      );
      until(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(condition(), isTrue);
      }

      Uint8List portrait() {
        final image = (tester.widget(find.byType(Image)) as Image).image;
        final provider = image is ResizeImage ? image.imageProvider : image;
        return (provider as MemoryImage).bytes;
      }
      refresh() async {
        await (tester.widget(find.byType(RefreshIndicator)) as RefreshIndicator)
            .onRefresh();
        await tester.pump();
      }

      try {
        await tester.pumpWidget(host());
        await until(() => requests == 1);
        status = 200;
        await refresh();
        await until(() => find.byType(Image).evaluate().isNotEmpty);
        expect(requests, 2);
        expect(portrait(), orderedEquals(red));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(host());
        await until(() => find.byType(Image).evaluate().isNotEmpty);
        expect(requests, 2, reason: 'navigation must reuse persistent bytes');
        expect(portrait(), orderedEquals(red));

        status = 503;
        await refresh();
        await until(() => requests == 3);
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        expect(portrait(), orderedEquals(red));

        status = 200;
        responseBytes = blue;
        await refresh();
        await until(
          () =>
              requests == 4 &&
              find.byType(Image).evaluate().isNotEmpty &&
              base64Encode(portrait()) == base64Encode(blue),
        );
        expect(portrait(), orderedEquals(blue));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.dispose();
        await network.close();
        messenger.setMockMethodCallHandler(channel, null);
        visibility.updateInterval = previousInterval;
      }
    },
  );
}
