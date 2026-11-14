import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/service/sync_connection_transfer.dart';

const _webdav = WebDavSettingState(
  host: 'https://cloud.invalid:8443/路径',
  username: '用户一',
  password: '  引号" 与空格 🔐  ',
);

const _s3 = S3SettingState(
  endpoint: '[::1]',
  accessKey: 'access-key',
  secretKey: '  密钥🔐  ',
  bucket: 'fixture-bucket',
  region: 'custom-region-1',
  useSSL: false,
  port: 65535,
  pathStyle: true,
);

Matcher _problem(SyncConnectionTransferIssue issue) =>
    isA<SyncConnectionTransferException>().having(
      (error) => error.issue,
      'issue',
      issue,
    );

const _prefix = 'BREEZE-SYNC-1:';

String _wrap(String json) =>
    '$_prefix${base64Url.encode(utf8.encode(json)).replaceAll('=', '')}';

Map<String, dynamic> _s3Json() {
  final code = const SyncConnectionConfig.s3(_s3).encode();
  final raw = base64Url.decode(
    base64Url.normalize(code.substring(_prefix.length)),
  );
  return jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
}

void main() {
  test(
    'copied text is versioned and does not display fields or credentials',
    () {
      for (final (config, secrets) in [
        (
          const SyncConnectionConfig.webdav(_webdav),
          [
            'host',
            'username',
            'password',
            _webdav.host,
            _webdav.username,
            _webdav.password,
          ],
        ),
        (
          const SyncConnectionConfig.s3(_s3),
          [
            'endpoint',
            'accessKey',
            'secretKey',
            _s3.accessKey,
            _s3.secretKey,
            _s3.bucket,
          ],
        ),
      ]) {
        final code = config.encode();
        expect(code, startsWith(_prefix));
        expect(code.substring(_prefix.length), matches(r'^[A-Za-z0-9_-]+$'));
        for (final secret in secrets) {
          expect(code, isNot(contains(secret)));
        }
      }
    },
  );

  test('only valid marked codes are accepted, with no plain JSON fallback', () {
    final valid = const SyncConnectionConfig.s3(_s3).encode();
    expect(SyncConnectionConfig.decode(' $valid\n').s3Settings, _s3);
    expect(
      () => SyncConnectionConfig.decode(
        valid.replaceFirst(_prefix, 'BREEZE-SYNC-2:'),
      ),
      throwsA(_problem(SyncConnectionTransferIssue.unsupportedVersion)),
    );
    for (final text in [
      jsonEncode(_s3Json()),
      valid.substring(_prefix.length),
      '$valid=',
      '$_prefix%',
      '${_prefix}_w',
      _prefix,
    ]) {
      expect(
        () => SyncConnectionConfig.decode(text),
        throwsA(_problem(SyncConnectionTransferIssue.invalid)),
      );
    }
  });

  test('WebDAV round trips endpoint, username and exact Unicode password', () {
    const config = SyncConnectionConfig.webdav(_webdav);
    final decoded = SyncConnectionConfig.decode(
      config.encode(),
      expectedType: SyncServiceType.webdav,
    );

    expect(decoded.serviceType, SyncServiceType.webdav);
    expect(decoded.webdavSettings, _webdav);
    expect(decoded.s3Settings, isNull);
    expect(decoded.isComplete, isTrue);
  });

  test('S3 round trips endpoint, keypair, options and explicit port', () {
    const config = SyncConnectionConfig.s3(_s3);
    final decoded = SyncConnectionConfig.decode(
      config.encode(),
      expectedType: SyncServiceType.s3,
    );

    expect(decoded.serviceType, SyncServiceType.s3);
    expect(decoded.s3Settings, _s3);
    expect(decoded.webdavSettings, isNull);
    expect(decoded.isComplete, isTrue);
  });

  test('S3 can use default optional fields and port zero', () {
    final raw = _s3Json();
    final connection = raw['connection'] as Map<String, dynamic>;
    for (final field in ['region', 'useSSL', 'port', 'pathStyle']) {
      connection.remove(field);
    }
    final expected = _s3.copyWith(
      region: '',
      useSSL: true,
      port: 0,
      pathStyle: false,
    );
    expect(
      SyncConnectionConfig.decode(_wrap(jsonEncode(raw))).s3Settings,
      expected,
    );
    expect(
      SyncConnectionConfig.decode(
        SyncConnectionConfig.s3(expected).encode(),
      ).s3Settings,
      expected,
    );
  });

  test('WebDAV and S3 clipboard texts cannot cross service forms', () {
    for (final (config, target) in [
      (const SyncConnectionConfig.webdav(_webdav), SyncServiceType.s3),
      (const SyncConnectionConfig.s3(_s3), SyncServiceType.webdav),
    ]) {
      expect(
        () =>
            SyncConnectionConfig.decode(config.encode(), expectedType: target),
        throwsA(_problem(SyncConnectionTransferIssue.wrongService)),
      );
    }
  });

  test('rejects future versions, other formats and non-provider fields', () {
    final future = _s3Json()..['version'] = 2;
    expect(
      () => SyncConnectionConfig.decode(_wrap(jsonEncode(future))),
      throwsA(_problem(SyncConnectionTransferIssue.unsupportedVersion)),
    );
    for (final raw in [
      _s3Json()..['format'] = 'unknown-format',
      _s3Json()..['service'] = 'none',
      _s3Json()..['autoSync'] = true,
      _s3Json()..['connection']['deviceId'] = 'foreign-device',
    ]) {
      expect(
        () => SyncConnectionConfig.decode(_wrap(jsonEncode(raw))),
        throwsA(_problem(SyncConnectionTransferIssue.invalid)),
      );
    }
  });

  test('rejects incomplete credentials and invalid S3 option types', () {
    final missing = _s3Json();
    (missing['connection'] as Map).remove('accessKey');
    for (final raw in [
      missing,
      _s3Json()..['connection']['secretKey'] = '',
      _s3Json()..['connection']['region'] = null,
      _s3Json()..['connection']['port'] = '443',
      _s3Json()..['connection']['port'] = -1,
      _s3Json()..['connection']['port'] = 65536,
      _s3Json()..['connection']['port'] = 443.0,
      _s3Json()..['connection']['useSSL'] = 'true',
      _s3Json()..['connection']['pathStyle'] = 1,
    ]) {
      expect(
        () => SyncConnectionConfig.decode(_wrap(jsonEncode(raw))),
        throwsA(_problem(SyncConnectionTransferIssue.invalid)),
      );
    }
    const incomplete = SyncConnectionConfig.webdav(WebDavSettingState());
    expect(incomplete.isComplete, isFalse);
    expect(
      incomplete.encode,
      throwsA(_problem(SyncConnectionTransferIssue.invalid)),
    );
  });

  test(
    'bounded input and malformed JSON errors never echo pasted contents',
    () {
      const marker = 'SYNTHETIC_SENSITIVE_VALUE';
      for (final text in ['{"password":"$marker"', marker * (64 * 1024)]) {
        expect(
          () => SyncConnectionConfig.decode(text),
          throwsA(
            isA<SyncConnectionTransferException>()
                .having(
                  (error) => error.issue,
                  'issue',
                  SyncConnectionTransferIssue.invalid,
                )
                .having(
                  (error) => error.toString(),
                  'redacted message',
                  isNot(contains(marker)),
                ),
          ),
        );
      }
    },
  );
}
