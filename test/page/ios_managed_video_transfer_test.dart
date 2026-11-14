import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/ios_managed_video_transfer.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/ios_background_transfer.dart';

import '../download_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'background MP4 stages bytes and acknowledges by exact attempt',
    () async {
      await useIsolatedDownloadFixture();
      final folder = await Directory.systemTemp.createTemp(
        'breeze-transfer-test-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final source = await File(
        '${folder.path}/private-stage',
      ).writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112, ...List.filled(16, 0)]);
      final transfer = IosManagedVideoTransfer(
        source: 'source',
        scope: 'a' * 64,
        taskKey: 'attempt',
        attempt: 1,
        resourceId: 'b' * 64,
        media: Uri.parse('https://example.com/video.mp4'),
        headers: const {},
        wifiOnly: true,
      );
      final calls = <String>[];
      var terminal = false;
      messenger.setMockMethodCallHandler(IosBackgroundTransfer.channel, (
        call,
      ) async {
        calls.add(call.method);
        switch (call.method) {
          case 'submit':
            final args = call.arguments as Map;
            expect(args['attempt'], 1);
            expect(args['wifiOnly'], true);
            expect(args['concurrency'], 1);
            expect(
              (args['items'] as List).single['redirectPolicy'],
              'same-url',
            );
            return true;
          case 'snapshot':
            return [
              {
                ...transfer.binding,
                'status': terminal ? 'staged' : 'running',
                'items': [
                  {'index': 0, 'bytes': terminal ? 24 : 12},
                ],
              },
            ];
          case 'linkVideoStage':
            expect(call.arguments, transfer.binding);
            final stage = await VideoLocalResources.stagedFile('c' * 32);
            await stage.parent.create(recursive: true);
            await source.copy(stage.path);
            return 'c' * 32;
          case 'ack':
            expect(call.arguments, transfer.binding);
            return true;
        }
        throw MissingPluginException();
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          IosBackgroundTransfer.channel,
          null,
        ),
      );

      final progress = <int>[];
      final result = await transfer.download(
        onProgress: (bytes, saving) async {
          progress.add(bytes);
          if (saving) return;
          terminal = true;
          final reply = Completer<void>();
          await messenger.handlePlatformMessage(
            IosBackgroundTransfer.channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('changed'),
            ),
            (_) => reply.complete(),
          );
          await reply.future;
        },
      );
      expect(progress, [12, 24]);
      expect(result?['status'], 'staged');
      final staged = await VideoLocalResources.stagedFile(
        result!['stageId'] as String,
      );
      expect(await staged.readAsBytes(), await source.readAsBytes());
      expect(await source.exists(), isTrue);
      await transfer.acknowledge();
      expect(calls, [
        'submit',
        'snapshot',
        'snapshot',
        'linkVideoStage',
        'ack',
      ]);
    },
  );
}
