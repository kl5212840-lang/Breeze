part of 'protection_service.dart';

Uint8List _be32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.big)).buffer.asUint8List();
int _u32(Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint32(0, Endian.big);

void _checkMagic(List<int> bytes) {
  if (bytes.length != _magic.length ||
      !List.generate(
        _magic.length,
        (i) => bytes[i] == _magic[i],
      ).every((v) => v)) {
    throw BackupProtectionException(
      BackupProtectionService.isProtectedBytes(bytes)
          ? 'unsupported_version'
          : 'not_protected',
    );
  }
}

Map<String, dynamic> _descriptor(int length) => {
  'version': 1,
  'algorithm': 'AES-256-GCM-HKDF-SHA256',
  'payloadId': base64Encode(_random(32)),
  'chunkSize': _chunkSize,
  'length': length,
};

Map<String, dynamic> _makeHeader(
  Map<String, dynamic> descriptor,
  BackupProtectionProfile profile,
  Uint8List key,
) {
  final body = {'descriptor': descriptor, 'profile': profile.toJson()};
  final nonce = _random(12);
  return {
    ...body,
    'authentication': {
      'nonce': base64Encode(nonce),
      'tag': base64Encode(
        _gcm(
          true,
          key,
          nonce,
          _text('Breeze envelope v1|${_canonical(body)}'),
          Uint8List(0),
        ),
      ),
    },
  };
}

Map<String, dynamic> _parseHeader(Uint8List bytes) {
  try {
    if (bytes.isEmpty || bytes.length > _maxHeaderBytes) {
      throw const BackupProtectionException('invalid_header');
    }
    final header = _object(jsonDecode(utf8.decode(bytes)));
    _exactFields(header, {'descriptor', 'profile', 'authentication'});
    BackupProtectionProfile.fromJson(_object(header['profile']));
    final descriptor = _object(header['descriptor']);
    _exactFields(descriptor, {
      'version',
      'algorithm',
      'payloadId',
      'chunkSize',
      'length',
    });
    if (descriptor['version'] != 1) {
      throw const BackupProtectionException('unsupported_version');
    }
    if (descriptor['algorithm'] != 'AES-256-GCM-HKDF-SHA256') {
      throw const BackupProtectionException('unsupported_algorithm');
    }
    if (descriptor['chunkSize'] != _chunkSize ||
        descriptor['length'] is! int ||
        (descriptor['length'] as int) < 0 ||
        (descriptor['length'] as int) >
            BackupProtectionSession.maxFilePayload) {
      throw const BackupProtectionException('invalid_size');
    }
    _bytes(descriptor['payloadId'], 32);
    final auth = _object(header['authentication']);
    _exactFields(auth, {'nonce', 'tag'});
    _bytes(auth['nonce'], 12);
    _bytes(auth['tag'], 16);
    return header;
  } on BackupProtectionException {
    rethrow;
  } catch (_) {
    throw const BackupProtectionException('invalid_header');
  }
}

void _verifyHeader(Map<String, dynamic> header, Uint8List key) {
  final profile = BackupProtectionProfile.fromJson(_object(header['profile']));
  _verifyProfile(profile, key);
  final auth = _object(header['authentication']);
  final body = Map<String, dynamic>.from(header)..remove('authentication');
  _gcm(
    false,
    key,
    _bytes(auth['nonce'], 12),
    _text('Breeze envelope v1|${_canonical(body)}'),
    _bytes(auth['tag'], 16),
  );
}

Uint8List _headerBytes(Map<String, dynamic> header) {
  final json = _jsonBytes(header);
  if (json.length > _maxHeaderBytes) {
    throw const BackupProtectionException('invalid_header');
  }
  return Uint8List.fromList([..._magic, ..._be32(json.length), ...json]);
}

int _headerOffset(Uint8List bytes) {
  if (bytes.length < 12) {
    throw const BackupProtectionException('invalid_header');
  }
  _checkMagic(Uint8List.sublistView(bytes, 0, 8));
  final size = _u32(Uint8List.sublistView(bytes, 8, 12));
  if (size == 0 || size > _maxHeaderBytes || bytes.length < 12 + size) {
    throw const BackupProtectionException('invalid_header');
  }
  return 12 + size;
}

Map<String, dynamic> _headerFromBytes(Uint8List envelope) {
  final end = _headerOffset(envelope);
  return _parseHeader(Uint8List.sublistView(envelope, 12, end));
}

Uint8List _readExact(RandomAccessFile input, int length) {
  final bytes = Uint8List(length);
  var offset = 0;
  while (offset < length) {
    final read = input.readIntoSync(bytes, offset, length);
    if (read == 0) throw const BackupProtectionException('truncated_archive');
    offset += read;
  }
  return bytes;
}

Map<String, dynamic> _readHeader(RandomAccessFile input) {
  _checkMagic(_readExact(input, 8));
  final size = _u32(_readExact(input, 4));
  if (size == 0 || size > _maxHeaderBytes) {
    throw const BackupProtectionException('invalid_header');
  }
  return _parseHeader(_readExact(input, size));
}

Uint8List _chunkNonce(int index) {
  final nonce = Uint8List(12);
  nonce.setRange(8, 12, _be32(index));
  return nonce;
}

Uint8List _chunkAad(Uint8List descriptorHash, int index, int length) =>
    Uint8List.fromList([
      ...descriptorHash,
      ..._be32(index),
      ..._be32(length),
      length == 0 ? 1 : 0,
    ]);

Uint8List _descriptorHash(Map<String, dynamic> descriptor) =>
    Uint8List.fromList(crypto.sha256.convert(_jsonBytes(descriptor)).bytes);

Uint8List _frame(
  Uint8List plaintext,
  Uint8List key,
  Uint8List descriptorHash,
  int index,
) {
  final encrypted = _gcm(
    true,
    key,
    _chunkNonce(index),
    _chunkAad(descriptorHash, index, plaintext.length),
    plaintext,
  );
  final frame = Uint8List(4 + encrypted.length);
  frame.setRange(0, 4, _be32(plaintext.length));
  frame.setRange(4, frame.length, encrypted);
  return frame;
}

Uint8List _encryptBytes(
  Uint8List plaintext,
  BackupProtectionProfile profile,
  Uint8List key,
) {
  final descriptor = _descriptor(plaintext.length);
  final header = _makeHeader(descriptor, profile, key);
  final payloadKey = _payloadKey(key, _bytes(descriptor['payloadId'], 32));
  final hash = _descriptorHash(descriptor);
  final output = BytesBuilder(copy: false)..add(_headerBytes(header));
  var index = 0;
  for (var start = 0; start < plaintext.length; start += _chunkSize) {
    final end = min(start + _chunkSize, plaintext.length);
    output.add(
      _frame(
        Uint8List.sublistView(plaintext, start, end),
        payloadKey,
        hash,
        index++,
      ),
    );
  }
  output.add(_frame(Uint8List(0), payloadKey, hash, index));
  payloadKey.fillRange(0, payloadKey.length, 0);
  return output.takeBytes();
}

Uint8List _decryptBytes(Uint8List envelope, Uint8List key) {
  final header = _headerFromBytes(envelope);
  _verifyHeader(header, key);
  if ((_object(header['descriptor'])['length'] as int) >
      BackupProtectionSession.maxBytesPayload) {
    throw const BackupProtectionException('use_streaming_file_backup');
  }
  return _walkBytes(envelope, header, key);
}

Uint8List _walkBytes(
  Uint8List envelope,
  Map<String, dynamic> header,
  Uint8List key, {
  bool discard = false,
}) {
  final descriptor = _object(header['descriptor']);
  final payloadKey = _payloadKey(key, _bytes(descriptor['payloadId'], 32));
  final hash = _descriptorHash(descriptor);
  var remaining = descriptor['length'] as int;
  var offset = _headerOffset(envelope);
  var index = 0;
  final output = BytesBuilder(copy: false);
  try {
    while (true) {
      final expected = min(_chunkSize, remaining);
      if (offset + 4 > envelope.length) {
        throw const BackupProtectionException('truncated_archive');
      }
      final length = _u32(Uint8List.sublistView(envelope, offset, offset + 4));
      offset += 4;
      if (length != expected || offset + length + 16 > envelope.length) {
        throw const BackupProtectionException('invalid_frame');
      }
      final plaintext = _gcm(
        false,
        payloadKey,
        _chunkNonce(index),
        _chunkAad(hash, index, length),
        Uint8List.sublistView(envelope, offset, offset + length + 16),
      );
      index++;
      offset += length + 16;
      if (!discard) output.add(plaintext);
      if (length == 0) break;
      remaining -= length;
    }
    if (offset != envelope.length) {
      throw const BackupProtectionException('trailing_data');
    }
    return output.takeBytes();
  } finally {
    payloadKey.fillRange(0, payloadKey.length, 0);
  }
}

/// Authenticates each frame before invoking either callback. No plaintext is
/// exposed to the caller outside the private staging file until terminal+EOF.
void _walkFile(
  RandomAccessFile input,
  Map<String, dynamic> header,
  Uint8List key, {
  void Function(Uint8List)? plaintextSink,
  void Function(Uint8List)? frameSink,
}) {
  final descriptor = _object(header['descriptor']);
  final payloadKey = _payloadKey(key, _bytes(descriptor['payloadId'], 32));
  final hash = _descriptorHash(descriptor);
  var remaining = descriptor['length'] as int;
  var index = 0;
  try {
    while (true) {
      final expected = min(_chunkSize, remaining);
      final prefix = _readExact(input, 4);
      final length = _u32(prefix);
      if (length != expected) {
        throw const BackupProtectionException('invalid_frame');
      }
      final ciphertext = _readExact(input, length + 16);
      final plaintext = _gcm(
        false,
        payloadKey,
        _chunkNonce(index),
        _chunkAad(hash, index, length),
        ciphertext,
      );
      index++;
      plaintextSink?.call(plaintext);
      if (frameSink != null) {
        final frame = Uint8List(4 + ciphertext.length);
        frame.setRange(0, 4, prefix);
        frame.setRange(4, frame.length, ciphertext);
        frameSink(frame);
      }
      if (plaintextSink == null) plaintext.fillRange(0, plaintext.length, 0);
      if (length == 0) break;
      remaining -= length;
    }
    if (input.readByteSync() != -1) {
      throw const BackupProtectionException('trailing_data');
    }
  } finally {
    payloadKey.fillRange(0, payloadKey.length, 0);
  }
}

// The private directory is on the destination volume, so successful publication
// is a rename. Refuse overwrites: callers promote a reviewed output themselves.
void _withStaging(
  String sourcePath,
  String destinationPath,
  void Function(RandomAccessFile, RandomAccessFile) action,
) {
  final source = File(sourcePath);
  final destination = File(destinationPath);
  if (source.absolute.path == destination.absolute.path ||
      destination.existsSync()) {
    throw const BackupProtectionException('destination_exists');
  }
  final staging = destination.parent.createTempSync('.breeze-protected-');
  final temporary = File('${staging.path}/payload');
  RandomAccessFile? input;
  RandomAccessFile? output;
  try {
    input = source.openSync();
    output = temporary.openSync(mode: FileMode.write);
    action(input, output);
    output.flushSync();
    output.closeSync();
    output = null;
    input.closeSync();
    input = null;
    // Recheck avoids replacing an unrelated file created during processing.
    if (destination.existsSync()) {
      throw const BackupProtectionException('destination_exists');
    }
    temporary.renameSync(destinationPath);
  } finally {
    input?.closeSync();
    output?.closeSync();
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

void _cryptFile(
  String sourcePath,
  String destinationPath,
  BackupProtectionProfile profile,
  Uint8List key,
  bool encrypt,
) {
  _withStaging(sourcePath, destinationPath, (input, output) {
    if (!encrypt) {
      final header = _readHeader(input);
      _verifyHeader(header, key);
      _walkFile(input, header, key, plaintextSink: output.writeFromSync);
      return;
    }
    final length = input.lengthSync();
    if (length > BackupProtectionSession.maxFilePayload) {
      throw const BackupProtectionException('invalid_size');
    }
    final descriptor = _descriptor(length);
    output.writeFromSync(_headerBytes(_makeHeader(descriptor, profile, key)));
    final payloadKey = _payloadKey(key, _bytes(descriptor['payloadId'], 32));
    final hash = _descriptorHash(descriptor);
    try {
      var remaining = length;
      var index = 0;
      while (remaining > 0) {
        final plaintext = _readExact(input, min(_chunkSize, remaining));
        output.writeFromSync(_frame(plaintext, payloadKey, hash, index++));
        remaining -= plaintext.length;
      }
      if (input.readByteSync() != -1) {
        throw const BackupProtectionException('source_changed');
      }
      output.writeFromSync(_frame(Uint8List(0), payloadKey, hash, index));
    } finally {
      payloadKey.fillRange(0, payloadKey.length, 0);
    }
  });
}

void _rewrapFile(
  String sourcePath,
  String destinationPath,
  BackupProtectionProfile profile,
  Uint8List key,
) {
  _withStaging(sourcePath, destinationPath, (input, output) {
    final header = _readHeader(input);
    _verifyHeader(header, key);
    final previous = BackupProtectionProfile.fromJson(
      _object(header['profile']),
    );
    if (previous.archiveId != profile.archiveId) {
      throw const BackupProtectionException('profile_mismatch');
    }
    output.writeFromSync(
      _headerBytes(_makeHeader(_object(header['descriptor']), profile, key)),
    );
    _walkFile(input, header, key, frameSink: output.writeFromSync);
  });
}
