import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minio/minio.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/s3_sync_service.dart';
import 'package:zephyr/network/sync/sync_failure.dart';

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

      final service = S3SyncService(
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
      );

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
}
