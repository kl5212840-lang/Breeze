part of 'protection_service.dart';

const _iterations = 600000;
const _maxHeaderBytes = 64 * 1024;
const _chunkSize = 1024 * 1024;
const _family = [66, 90, 80, 83, 69, 67]; // BZPSEC
const _magic = [..._family, 48, 49]; // BZPSEC01

Uint8List _random(int count) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(count, (_) => random.nextInt(256)));
}

String _hex(List<int> value) =>
    value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Map<String, dynamic> _object(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const BackupProtectionException('invalid_header');
  }
  return value;
}

String _canonical(dynamic value) {
  dynamic sort(dynamic item) {
    if (item is Map<String, dynamic>) {
      final keys = item.keys.toList()..sort();
      return {for (final key in keys) key: sort(item[key])};
    }
    if (item is List) return item.map(sort).toList();
    return item;
  }

  return jsonEncode(sort(value));
}

Uint8List _text(String value) => Uint8List.fromList(utf8.encode(value));
Uint8List _jsonBytes(Map<String, dynamic> json) => _text(_canonical(json));

Uint8List _bytes(dynamic text, int count) {
  try {
    if (text is! String || text.length > count * 2 + 8) {
      throw const FormatException();
    }
    final result = base64Decode(text);
    if (result.length != count) throw const FormatException();
    return result;
  } catch (_) {
    throw const BackupProtectionException('invalid_header');
  }
}

void _validatePassword(String password, {bool creating = true}) {
  final bytes = utf8.encode(password);
  if (bytes.length > 1024 ||
      bytes.isEmpty ||
      (creating && password.runes.length < 10)) {
    throw const BackupProtectionException('password_length');
  }
}

Uint8List _passwordKey(String password, Uint8List salt) {
  final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
    ..init(pc.Pbkdf2Parameters(salt, _iterations, 32));
  final passwordBytes = _text(password);
  try {
    return derivator.process(passwordBytes);
  } finally {
    passwordBytes.fillRange(0, passwordBytes.length, 0);
  }
}

Uint8List _payloadKey(Uint8List key, Uint8List payloadId) {
  final derivator = pc.HKDFKeyDerivator(pc.SHA256Digest())
    ..init(
      pc.HkdfParameters(
        key,
        32,
        payloadId,
        _text('Breeze backup payload AES-GCM v1'),
      ),
    );
  final output = Uint8List(32);
  derivator.deriveKey(null, 0, output, 0);
  return output;
}

// PointyCastle authenticates the complete GCM tag before returning plaintext.
Uint8List _gcm(
  bool encrypt,
  Uint8List key,
  Uint8List nonce,
  Uint8List aad,
  Uint8List input,
) {
  try {
    if (key.length != 32 || nonce.length != 12) {
      throw const BackupProtectionException('invalid_key');
    }
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(encrypt, pc.AEADParameters(pc.KeyParameter(key), 128, nonce, aad));
    return cipher.process(input);
  } on BackupProtectionException {
    rethrow;
  } catch (_) {
    throw const BackupProtectionException('authentication_failed');
  }
}

Uint8List _slotAad(String id, String type) =>
    _text('Breeze protected backup v1|$id|$type');

Map<String, dynamic> _sealSlot(
  String id,
  String type,
  Uint8List key,
  Uint8List wrappingKey, {
  Uint8List? salt,
}) {
  final nonce = _random(12);
  try {
    return {
      'algorithm': 'AES-256-GCM',
      if (salt != null) ...{
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _iterations,
        'salt': base64Encode(salt),
      },
      'nonce': base64Encode(nonce),
      'wrappedKey': base64Encode(
        _gcm(true, wrappingKey, nonce, _slotAad(id, type), key),
      ),
    };
  } finally {
    wrappingKey.fillRange(0, wrappingKey.length, 0);
  }
}

Uint8List _openSlot(
  String id,
  String type,
  Map<String, dynamic> slot,
  Uint8List wrappingKey,
) {
  try {
    return _gcm(
      false,
      wrappingKey,
      _bytes(slot['nonce'], 12),
      _slotAad(id, type),
      _bytes(slot['wrappedKey'], 48),
    );
  } finally {
    wrappingKey.fillRange(0, wrappingKey.length, 0);
  }
}

BackupProtectionProfile _makeProfile(
  String id,
  Uint8List key,
  String password,
  Uint8List recovery,
) {
  final salt = _random(16);
  // _sealSlot wipes its wrapping key, so keep a separate recovery copy.
  return _authenticateProfile({
    'format': 'breeze-backup-protection',
    'version': 1,
    'archiveId': id,
    'password': _sealSlot(
      id,
      'password',
      key,
      _passwordKey(password, salt),
      salt: salt,
    ),
    'recovery': _sealSlot(id, 'recovery', key, Uint8List.fromList(recovery)),
  }, key);
}

BackupProtectionProfile _authenticateProfile(
  Map<String, dynamic> json,
  Uint8List key,
) {
  final body = Map<String, dynamic>.from(json)..remove('authentication');
  final nonce = _random(12);
  body['authentication'] = {
    'nonce': base64Encode(nonce),
    'tag': base64Encode(
      _gcm(
        true,
        key,
        nonce,
        _text('Breeze profile v1|${_canonical(body)}'),
        Uint8List(0),
      ),
    ),
  };
  return BackupProtectionProfile.fromJson(body);
}

void _verifyProfile(BackupProtectionProfile profile, Uint8List key) {
  final body = profile.toJson();
  final auth = _object(body.remove('authentication'));
  _gcm(
    false,
    key,
    _bytes(auth['nonce'], 12),
    _text('Breeze profile v1|${_canonical(body)}'),
    _bytes(auth['tag'], 16),
  );
}

void _exactFields(Map<String, dynamic> value, Set<String> fields) {
  if (value.length != fields.length || !value.keys.every(fields.contains)) {
    throw const BackupProtectionException('invalid_header');
  }
}

void _validateProfile(Map<String, dynamic> json) {
  if (json['format'] != 'breeze-backup-protection' || json['version'] != 1) {
    throw const BackupProtectionException('unsupported_version');
  }
  _exactFields(json, {
    'format',
    'version',
    'archiveId',
    'password',
    'recovery',
    'authentication',
  });
  if (json['archiveId'] is! String ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(json['archiveId'] as String)) {
    throw const BackupProtectionException('invalid_header');
  }
  for (final type in ['password', 'recovery']) {
    final slot = _object(json[type]);
    _exactFields(slot, {
      'algorithm',
      'nonce',
      'wrappedKey',
      if (type == 'password') ...{'kdf', 'iterations', 'salt'},
    });
    if (slot['algorithm'] != 'AES-256-GCM') {
      throw const BackupProtectionException('unsupported_algorithm');
    }
    _bytes(slot['nonce'], 12);
    _bytes(slot['wrappedKey'], 48);
    if (type == 'password') {
      // Fixed v1 cost prevents attacker-controlled unbounded KDF work.
      if (slot['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          slot['iterations'] != _iterations) {
        throw const BackupProtectionException('unsupported_kdf');
      }
      _bytes(slot['salt'], 16);
    }
  }
  final auth = _object(json['authentication']);
  _exactFields(auth, {'nonce', 'tag'});
  _bytes(auth['nonce'], 12);
  _bytes(auth['tag'], 16);
}

String _recoveryCode(Uint8List secret) {
  final checksum = crypto.sha256
      .convert([..._text('Breeze recovery key v1'), ...secret])
      .bytes
      .take(4)
      .toList();
  final encoded = _hex([...secret, ...checksum]).toUpperCase();
  return 'BR1-${List.generate(9, (i) => encoded.substring(i * 8, (i + 1) * 8)).join('-')}';
}

Uint8List _decodeRecoveryCode(String code) {
  if (code.length > 128) {
    throw const BackupProtectionException('invalid_recovery_code');
  }
  final compact = code.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^BR1[A-F0-9]{72}$').hasMatch(compact)) {
    throw const BackupProtectionException('invalid_recovery_code');
  }
  final raw = compact.substring(3);
  final secret = Uint8List.fromList(
    List.generate(
      32,
      (i) => int.parse(raw.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
  if (_recoveryCode(secret).replaceAll('-', '') != compact) {
    secret.fillRange(0, secret.length, 0);
    throw const BackupProtectionException('invalid_recovery_code');
  }
  return secret;
}

String _readRecoveryFile(String contents, String id) {
  try {
    if (contents.length > 4096) throw const FormatException();
    final json = _object(jsonDecode(contents));
    _exactFields(json, {'format', 'version', 'archiveId', 'recoveryCode'});
    if (json['format'] != 'breeze-recovery-key' ||
        json['version'] != 1 ||
        json['archiveId'] != id ||
        json['recoveryCode'] is! String) {
      throw const FormatException();
    }
    return json['recoveryCode'] as String;
  } catch (_) {
    throw const BackupProtectionException('invalid_recovery_file');
  }
}
