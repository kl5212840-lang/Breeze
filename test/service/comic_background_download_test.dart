import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/service/download/comic_background_download.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/image_download.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';

const _taskKey = 'source:work:chapter';
const _job = DownloadImageJob(
  url: 'https://cdn.example.com/1.jpg',
  path: 'generation-1-page-1',
  cartoonId: 'work',
  chapterId: 'chapter',
);
const _declaration = <String, dynamic>{
  'version': 1,
  'credentialFree': true,
  'redirectPolicy': 'same-url',
  'headers': <String, String>{'Accept': 'image/*'},
};

Future<ComicBackgroundDownload> _start({
  bool Function()? current,
  String manifest = 'c',
  int attempt = 2,
}) => ComicBackgroundDownload.start(
  source: 'source',
  taskKey: _taskKey,
  attempt: attempt,
  scope: 'a' * 64,
  resourceId: 'b' * 64,
  manifestId: manifest * 64,
  wifiOnly: true,
  jobs: [_job],
  headers: [
    {'Accept': 'image/*'},
  ],
  concurrency: 1,
  isCurrent: current ?? () => true,
);

Map<String, dynamic> _oldBinding({String manifest = 'c'}) => {
  'batchId': 'old-batch',
  'kind': 'comic',
  'source': 'source',
  'taskKey': _taskKey,
  'attempt': 1,
  'scope': 'a' * 64,
  'resourceId': 'b' * 64,
  'manifestId': manifest * 64,
  'wifiOnly': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => prepareDownloadCancelSignal(_taskKey));
  tearDown(() {
    clearDownloadCancelSignal(_taskKey);
    messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, null);
  });

  test('only explicit credential-free canonical image declarations opt in', () {
    DownloadImageJob job(
      String url, {
      Map<String, dynamic> declaration = _declaration,
    }) => DownloadImageJob(
      url: url,
      path: '1',
      cartoonId: 'w',
      chapterId: 'c',
      extern: {'backgroundDownload': declaration},
    );
    expect(comicBackgroundHeaders(_job), isNull);
    expect(comicBackgroundHeaders(job(_job.url)), {'Accept': 'image/*'});
    for (final url in [
      'http://cdn.example.com/a.jpg',
      'https://127.0.0.1/a',
      'https://localhost/a',
      'https://thing.local/a',
      'https://a.localhost/a',
      'https://user@cdn.example.com/a',
      'https://cdn.example.com/a?token=secret',
      'https://cdn.example.com:444/a',
      'https://cdn.example.com/a#fragment',
    ]) {
      expect(comicBackgroundHeaders(job(url)), isNull, reason: url);
    }
    for (final headers in [
      {'Authorization': 'secret'},
      {'Cookie': 'secret'},
      {'Host': 'other.example.com'},
      {'Referer': 'https://example.com/private/path'},
      {'Accept': 'image/*\r\nHost:other'},
      {'Accept': 'image/*', 'accept': 'text/*'},
    ]) {
      expect(
        comicBackgroundHeaders(
          job(_job.url, declaration: {..._declaration, 'headers': headers}),
        ),
        isNull,
      );
    }
  });

  test(
    'leased native bytes remain private until the original image validation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'breeze-comic-native-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/raw',
      ).writeAsString('<html>gateway</html>');
      Map<String, dynamic>? binding;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        calls.add(call.method);
        switch (call.method) {
          case 'snapshot':
            return binding == null
                ? []
                : [
                    {
                      ...binding!,
                      'status': 'staged',
                      'items': [
                        {'index': 0, 'status': 'staged'},
                      ],
                    },
                  ];
          case 'submit':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            binding = ComicBackgroundDownload.bindingOf(args);
            expect(args['concurrency'], 1);
            expect(
              (args['items'] as List).single['redirectPolicy'],
              'same-url',
            );
            return true;
          case 'holdStage':
            return {'path': file.path, 'lease': 'lease'};
          case 'releaseStage':
            expect(call.arguments, 'lease');
            return null;
          case 'cancel':
          case 'ack':
            expect(call.arguments, binding);
            return true;
        }
        throw MissingPluginException();
      });
      await useIsolatedDownloadFixture();
      final transfer = await _start();
      final result = await downloadPictureResult(
        from: 'source',
        url: _job.url,
        path: _job.path,
        cartoonId: _job.cartoonId,
        chapterId: _job.chapterId,
        isolatedPage: true,
        applyRealSr: false,
        preparedImage: () => transfer.read(_job),
      );
      expect(result.status, DownloadPictureResultStatus.failed);
      expect(result.error, isA<DownloadPictureInvalidPayload>());
      await transfer.close();
      expect(calls.sublist(calls.indexOf('holdStage')), [
        'holdStage',
        'releaseStage',
        'cancel',
        'ack',
      ]);
      expect(
        await file.exists(),
        isTrue,
      ); // Test bridge did not delete the private stage.
    },
  );

  test(
    'same isolated manifest reattaches across queue attempt rollover',
    () async {
      final old = _oldBinding();
      var submitted = false;
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        if (call.method == 'snapshot')
          return [
            {...old, 'status': 'running'},
          ];
        if (call.method == 'submit') submitted = true;
        if (call.method == 'cancel' || call.method == 'ack')
          expect(call.arguments, old);
        return true;
      });
      final transfer = await _start(attempt: 9);
      expect(transfer.binding, old);
      expect(submitted, isFalse);
      await transfer.close();
    },
  );

  test(
    'changed page generation stops old daemon before submitting replacement',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'snapshot')
          return [
            {..._oldBinding(manifest: 'd'), 'status': 'running'},
          ];
        return true;
      });
      final transfer = await _start();
      expect(calls, ['snapshot', 'cancel', 'ack', 'submit']);
      expect(transfer.binding['attempt'], 2);
      expect(transfer.binding['batchId'], isNot('old-batch'));
      await transfer.close();
    },
  );

  test(
    'pause wakes a waiting page and cleanup waits for native cancellation',
    () async {
      final entered = Completer<void>(), stopped = Completer<bool>();
      var acknowledged = false;
      var binding = <String, dynamic>{};
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        switch (call.method) {
          case 'snapshot':
            if (binding.isEmpty) return [];
            if (!entered.isCompleted) entered.complete();
            return [
              {
                ...binding,
                'status': 'running',
                'items': [
                  {'index': 0, 'status': 'running'},
                ],
              },
            ];
          case 'submit':
            binding = ComicBackgroundDownload.bindingOf(
              Map<String, dynamic>.from(call.arguments as Map),
            );
            return true;
          case 'cancel':
            return stopped.future;
          case 'ack':
            acknowledged = true;
            return true;
        }
        throw MissingPluginException();
      });
      final transfer = await _start();
      final read = expectLater(
        transfer.read(_job),
        throwsA(isA<DownloadTaskCancelledException>()),
      );
      await entered.future;
      triggerDownloadCancelSignal(_taskKey, preserveFiles: true);
      await read;
      var cleaned = false;
      final close = transfer.close().then((_) => cleaned = true);
      await Future<void>.delayed(Duration.zero);
      expect(cleaned, isFalse);
      expect(acknowledged, isFalse);
      stopped.complete(true);
      await close;
      expect(acknowledged, isTrue);
    },
  );

  test(
    'account change during stage acquisition releases lease without publishing',
    () async {
      var current = true;
      var released = false;
      final directory = await Directory.systemTemp.createTemp(
        'breeze-comic-native-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/raw').writeAsBytes([1, 2, 3]);
      final old = _oldBinding();
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        switch (call.method) {
          case 'snapshot':
            return [
              {
                ...old,
                'status': 'staged',
                'items': [
                  {'index': 0, 'status': 'staged'},
                ],
              },
            ];
          case 'holdStage':
            current = false;
            return {'path': file.path, 'lease': 'lease'};
          case 'releaseStage':
            released = true;
            return null;
          case 'cancel':
          case 'ack':
            return true;
        }
        throw MissingPluginException();
      });
      final transfer = await _start(current: () => current);
      await expectLater(
        transfer.read(_job),
        throwsA(isA<DownloadTaskCancelledException>()),
      );
      expect(released, isTrue);
      await transfer.close();
    },
  );

  test(
    'failed native stop cannot acknowledge or report cleanup success',
    () async {
      var attempts = 0, acknowledged = false;
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        if (call.method == 'snapshot') return [];
        if (call.method == 'cancel') return ++attempts > 1;
        if (call.method == 'ack') acknowledged = true;
        return true;
      });
      final transfer = await _start();
      await expectLater(transfer.close(), throwsA(isA<FileSystemException>()));
      expect(acknowledged, isFalse);
      await transfer.close();
      expect(attempts, 2);
      expect(acknowledged, isTrue);
    },
  );

  test(
    'pre-submit cache check accepts only the same committed image layout',
    () async {
      await useIsolatedDownloadFixture();
      final store = DownloadAssetStore(
        from: 'source',
        path: _job.path,
        cartoonId: _job.cartoonId,
        chapterId: _job.chapterId,
        pictureType: PictureType.page,
      );
      final path = await store.canonicalDownloadPath();
      final file = File(path);
      await file.parent.create(recursive: true);
      Future<bool> reusable() => hasCommittedDownloadPage(
        from: 'source',
        path: _job.path,
        cartoonId: _job.cartoonId,
        chapterId: _job.chapterId,
        storageChapterId: '',
      );
      expect(await reusable(), isFalse);
      await file.writeAsString('<html>error</html>');
      expect(await reusable(), isFalse);
      await file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1sAAAAASUVORK5CYII=',
        ),
      );
      expect(await reusable(), isTrue);
    },
  );
}
