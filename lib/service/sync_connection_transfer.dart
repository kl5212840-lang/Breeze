import 'dart:convert';

import 'package:zephyr/config/global/global_setting.dart';

enum SyncConnectionTransferIssue { invalid, unsupportedVersion, wrongService }

/// Transfer errors never retain the input or expose credential values.
class SyncConnectionTransferException implements Exception {
  const SyncConnectionTransferException(this.issue);

  final SyncConnectionTransferIssue issue;

  @override
  String toString() => 'SyncConnectionTransferException(${issue.name})';
}

/// One service's connection profile. The model has no preferences, device
/// identity, sync switches or network operations.
class SyncConnectionConfig {
  const SyncConnectionConfig.webdav(WebDavSettingState settings)
    : serviceType = SyncServiceType.webdav,
      webdavSettings = settings,
      s3Settings = null;

  const SyncConnectionConfig.s3(S3SettingState settings)
    : serviceType = SyncServiceType.s3,
      webdavSettings = null,
      s3Settings = settings;

  static const _format = 'breeze-sync-connection';
  static const _version = 1;
  static const _prefix = 'BREEZE-SYNC-1:';
  static const _maximumJsonBytes = 32 * 1024;
  static const _maximumCodeLength = (_maximumJsonBytes * 4 + 2) ~/ 3 + 32;
  static final _versionedPrefix = RegExp(r'^BREEZE-SYNC-[1-9][0-9]{0,5}:');
  static final _nonBase64Url = RegExp(r'[^A-Za-z0-9_-]');
  static const _invalid = SyncConnectionTransferException(
    SyncConnectionTransferIssue.invalid,
  );

  final SyncServiceType serviceType;
  final WebDavSettingState? webdavSettings;
  final S3SettingState? s3Settings;

  bool get isComplete => switch ((webdavSettings, s3Settings)) {
    (final WebDavSettingState value, _) =>
      value.host.trim().isNotEmpty &&
          value.username.trim().isNotEmpty &&
          value.password.isNotEmpty,
    (_, final S3SettingState value) =>
      value.endpoint.trim().isNotEmpty &&
          value.accessKey.trim().isNotEmpty &&
          value.secretKey.isNotEmpty &&
          value.bucket.trim().isNotEmpty &&
          value.port >= 0 &&
          value.port <= 65535,
    _ => false,
  };

  /// A copyable, unencrypted code. The provider settings are recoverable by
  /// anyone who can read the code.
  String encode() {
    if (!isComplete) throw _invalid;
    final webdav = webdavSettings;
    final s3 = s3Settings;
    final output = utf8.encode(
      jsonEncode({
        'format': _format,
        'version': _version,
        'service': serviceType.name,
        'connection': {
          if (webdav != null) ...{
            'host': webdav.host,
            'username': webdav.username,
            'password': webdav.password,
          },
          if (s3 != null) ...{
            'endpoint': s3.endpoint,
            'accessKey': s3.accessKey,
            'secretKey': s3.secretKey,
            'bucket': s3.bucket,
            'region': s3.region,
            'useSSL': s3.useSSL,
            'port': s3.port,
            'pathStyle': s3.pathStyle,
          },
        },
      }),
    );
    try {
      if (output.length > _maximumJsonBytes) throw _invalid;
      return '$_prefix${_base64(output)}';
    } finally {
      output.fillRange(0, output.length, 0);
    }
  }

  static SyncConnectionConfig decode(
    String text, {
    SyncServiceType? expectedType,
  }) {
    if (text.length > _maximumCodeLength) throw _invalid;
    final code = text.trim();
    if (!code.startsWith(_prefix)) {
      if (_versionedPrefix.hasMatch(code)) {
        throw const SyncConnectionTransferException(
          SyncConnectionTransferIssue.unsupportedVersion,
        );
      }
      throw _invalid;
    }
    final payload = code.substring(_prefix.length);
    if (payload.isEmpty || _nonBase64Url.hasMatch(payload)) throw _invalid;
    try {
      final bytes = base64Url.decode(base64Url.normalize(payload));
      final Object? decoded;
      try {
        if (bytes.length > _maximumJsonBytes || _base64(bytes) != payload) {
          throw _invalid;
        }
        decoded = jsonDecode(utf8.decode(bytes));
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      final root = _object(decoded, {
        'format',
        'version',
        'service',
        'connection',
      });
      if (root['format'] != _format || root['version'] is! int) throw _invalid;
      if (root['version'] != _version) {
        throw const SyncConnectionTransferException(
          SyncConnectionTransferIssue.unsupportedVersion,
        );
      }
      final serviceType = switch (root['service']) {
        'webdav' => SyncServiceType.webdav,
        's3' => SyncServiceType.s3,
        _ => throw _invalid,
      };
      if (expectedType != null && expectedType != serviceType) {
        throw const SyncConnectionTransferException(
          SyncConnectionTransferIssue.wrongService,
        );
      }
      final config = switch (serviceType) {
        SyncServiceType.webdav => _decodeWebdav(root['connection']),
        SyncServiceType.s3 => _decodeS3(root['connection']),
        SyncServiceType.none => throw _invalid,
      };
      if (!config.isComplete) throw _invalid;
      return config;
    } on SyncConnectionTransferException {
      rethrow;
    } catch (_) {
      // Dart parser/type exceptions can retain or quote the supplied JSON.
      throw _invalid;
    }
  }

  static String _base64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static SyncConnectionConfig _decodeWebdav(Object? input) {
    final value = _object(input, {'host', 'username', 'password'});
    return SyncConnectionConfig.webdav(
      WebDavSettingState(
        host: value['host'] as String,
        username: value['username'] as String,
        password: value['password'] as String,
      ),
    );
  }

  static SyncConnectionConfig _decodeS3(Object? input) {
    final value = _object(
      input,
      {'endpoint', 'accessKey', 'secretKey', 'bucket'},
      optional: {'region', 'useSSL', 'port', 'pathStyle'},
    );
    return SyncConnectionConfig.s3(
      S3SettingState(
        endpoint: value['endpoint'] as String,
        accessKey: value['accessKey'] as String,
        secretKey: value['secretKey'] as String,
        bucket: value['bucket'] as String,
        region: value.containsKey('region') ? value['region'] as String : '',
        useSSL: value.containsKey('useSSL') ? value['useSSL'] as bool : true,
        port: value.containsKey('port') ? value['port'] as int : 0,
        pathStyle: value.containsKey('pathStyle')
            ? value['pathStyle'] as bool
            : false,
      ),
    );
  }

  static Map<String, dynamic> _object(
    Object? value,
    Set<String> keys, {
    Set<String> optional = const {},
  }) {
    if (value is! Map<String, dynamic> ||
        !keys.every(value.containsKey) ||
        value.keys.any(
          (key) => !keys.contains(key) && !optional.contains(key),
        )) {
      throw _invalid;
    }
    return value;
  }
}
