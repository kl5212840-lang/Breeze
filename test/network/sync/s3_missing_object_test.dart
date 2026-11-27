import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minio/minio.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/s3_sync_service.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';

S3SyncService _service(
  HttpServer server, {
  Duration operationTimeout = const Duration(minutes: 2),
}) => S3SyncService(
  GlobalSettingState(
    syncSetting: SyncSettingState(
      s3Setting: S3SettingState(
        endpoint: '127.0.0.1',
        port: server.port,
        region: 'us-east-1',
        bucket: 'fixture',
        accessKey: 'fixture',
        secretKey: 'fixture',
        useSSL: false,
        pathStyle: true,
      ),
    ),
  ),
  operationTimeout: operationTimeout,
);

void main() {
  test(
    'S3 distinguishes a missing object from access and bucket failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var code = 'NoSuchKey';
      var status = HttpStatus.notFound;
      server.listen((request) async {
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType('application', 'xml')
          ..write(
            '<Error><Code>$code</Code><Message>Fixture message</Message></Error>',
          );
        await request.response.close();
      });

      final service = _service(server);

      await expectLater(
        service.downloadRemoteFile('settings.md5'),
        throwsA(isA<SyncRemoteFileNotFound>()),
      );
      code = 'NoSuchBucket';
      await expectLater(
        service.downloadRemoteFile('settings.md5'),
        throwsA(isA<MinioS3Error>()),
      );
      status = HttpStatus.forbidden;
      code = 'AccessDenied';
      await expectLater(
        service.downloadRemoteFile('settings.md5'),
        throwsA(isA<MinioS3Error>()),
      );
    },
  );

  test('S3 limits a chunked object even without a content length', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.add([1, 2, 3]);
      await request.response.flush();
      request.response.add([4, 5, 6]);
      await request.response.close();
    });
    final service = _service(server);
    await expectLater(
      service.downloadBoundedFile('settings.md5', 5),
      throwsA(isA<SyncRemoteFileTooLarge>()),
    );
    expect(await service.downloadBoundedFile('settings.md5', 6), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
  });

  test(
    'S3 continues a v1 listing without NextMarker and rejects a stalled cursor',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final markers = <String?>[];
      var stuck = false;
      server.listen((request) async {
        final marker = request.uri.queryParameters['marker'];
        markers.add(marker);
        final more = marker == null || stuck;
        final key = more ? 'archive/old.bin' : 'archive/new.bin';
        request.response
          ..headers.contentType = ContentType('application', 'xml')
          ..write(
            '''<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
<Name>fixture</Name><IsTruncated>$more</IsTruncated>
<Contents><Key>$key</Key><LastModified>2026-11-23T00:00:00.000Z</LastModified><Size>1</Size></Contents>
</ListBucketResult>''',
          );
        await request.response.close();
      });
      final service = _service(server);
      expect(await service.listRemoteDataFiles(), [
        'archive/old.bin',
        'archive/new.bin',
      ]);
      expect(markers, [null, 'archive/old.bin']);
      stuck = true;
      markers.clear();
      await expectLater(service.listRemoteDataFiles(), throwsFormatException);
      expect(markers, [null, 'archive/old.bin']);
    },
  );

  for (final sendHeaders in [false, true]) {
    test(
      'stalled S3 ${sendHeaders ? 'body' : 'headers'} release the storage queue',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          if (sendHeaders) {
            request.response.contentLength = 10;
            request.response.add([1]);
            await request.response.flush();
          }
        });
        final service = _service(
          server,
          operationTimeout: const Duration(milliseconds: 300),
        );
        final queue = SyncOperationQueue();
        final pending = queue.run(() async {
          await service.downloadBoundedFile('settings.md5', 10);
        });
        final after = queue.run(() async {});
        await expectLater(pending, throwsA(isA<TimeoutException>()));
        await after.timeout(const Duration(seconds: 1));
        expect(queue.busy.value, false);
      },
    );
  }
}
