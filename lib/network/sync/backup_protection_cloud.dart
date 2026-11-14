part of 'backup_protection_manager.dart';

const _markerName = 'protection.json';
const _publicLimit = 128 * 1024;
final _payloadName = RegExp(
  r'^(?:comic_\d+\.bin|settings_\d+\.bin|video_library_[a-f0-9]{32}\.bin|chapter_progress_v1_[a-f0-9]{32}\.bin|appearance_[a-f0-9]{32}(?:_[a-f0-9]{64})?\.bin|appearance_resource_[a-f0-9]{64}\.bin)$',
);
final _journalName = RegExp(r'^protection_transition_([a-f0-9]{32})\.json$');
String _rootPath(String name) => '${SyncArchiveContext.currentRoot}/$name';
String? _profileJson(BackupProtectionProfile? profile) =>
    profile == null ? null : jsonEncode(profile.toJson());
Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  return value;
}

BackupProtectionProfile? _publicProfile(Object? value) =>
    value == null ? null : BackupProtectionProfile.fromJson(_map(value));
String _planPath(Map<String, dynamic> plan) =>
    _rootPath('protection_transition_${plan['id']}.json');
String _stagePath(Map<String, dynamic> plan, String path) => _rootPath(
  'protection_stage_${plan['id']}_${sha256.convert(utf8.encode(path)).toString().substring(0, 32)}.bin',
);

class _CloudState {
  _CloudState(
    this.payloads,
    this.marker,
    this.plan,
    this.completed, {
    this.incompleteJournal,
  });
  final List<String> payloads;
  final Map<String, dynamic>? marker, plan;
  final bool completed;
  final String? incompleteJournal;
  BackupProtectionProfile? get readyProfile =>
      marker?['phase'] == 'ready' ? _publicProfile(marker?['profile']) : null;
  BackupProtectionProfile? get visibleProfile => plan != null && !completed
      ? _publicProfile(plan!['targetProfile'] ?? plan!['sourceProfile'])
      : readyProfile;
  CloudBackupProtectionStatus get status => CloudBackupProtectionStatus(
    mode: visibleProfile == null
        ? BackupProtectionMode.standard
        : BackupProtectionMode.passwordProtected,
    profile: visibleProfile,
    transitionOperation: incompleteJournal != null
        ? 'preparing'
        : plan != null && !completed
        ? plan!['operation'] as String
        : null,
    cleanupPending: completed,
  );
}

Future<List<String>> _list(ComicSyncRemoteAdapter raw) async {
  List<String> paths;
  try {
    paths = await raw.listRemoteDataFiles();
  } catch (error) {
    final message = error.toString().toLowerCase();
    if (message.contains('404') ||
        message.contains('not found') ||
        message.contains('nosuchkey')) {
      return [];
    }
    rethrow;
  }
  final root = SyncArchiveContext.currentRoot;
  return paths
      .map((path) => path.replaceFirst(RegExp(r'^/+'), ''))
      .where((path) => path.startsWith('$root/') && path.split('/').length == 2)
      .toSet()
      .toList()
    ..sort();
}

Future<Uint8List> _download(
  ComicSyncRemoteAdapter raw,
  String path, {
  int limit = BackupProtectionSession.maxBytesPayload + 65536 + 4096,
}) async {
  final bytes = await raw.downloadRemoteFile(path);
  if (bytes.length > limit) {
    throw const BackupProtectionException('cloud_protection_payload_too_large');
  }
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

Map<String, dynamic> _decodePublic(Uint8List bytes) {
  try {
    if (bytes.length > _publicLimit) throw const FormatException();
    return _map(jsonDecode(utf8.decode(bytes)));
  } on BackupProtectionException {
    rethrow;
  } catch (_) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
}

void _fields(Map<String, dynamic> map, Set<String> fields) {
  if (map.length != fields.length || !map.keys.every(fields.contains)) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
}

Map<String, dynamic> _validatePlan(Map<String, dynamic> plan) {
  if (!plan.containsKey('format') || !plan.containsKey('version')) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  if (plan['format'] != 'BreezeProtectionTransition' || plan['version'] != 1) {
    throw const BackupProtectionException(
      'unsupported_cloud_protection_version',
    );
  }
  _fields(plan, {
    'format',
    'version',
    'id',
    'operation',
    'files',
    'sourceProfile',
    'targetProfile',
  });
  if (plan['id'] is! String ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(plan['id'] as String) ||
      !['enable', 'disable', 'password'].contains(plan['operation'])) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  final files = plan['files'];
  if (files is! List ||
      files.length > 512 ||
      files.toSet().length != files.length ||
      !files.every(
        (path) =>
            path is String &&
            path.startsWith('${SyncArchiveContext.currentRoot}/') &&
            path.split('/').length == 2 &&
            _payloadName.hasMatch(path.split('/').last),
      )) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  final source = _publicProfile(plan['sourceProfile']);
  final target = _publicProfile(plan['targetProfile']);
  final operation = plan['operation'];
  if ((operation == 'enable' && (source != null || target == null)) ||
      (operation == 'disable' && (source == null || target != null)) ||
      (operation == 'password' &&
          (source == null ||
              target == null ||
              source.archiveId != target.archiveId))) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  return plan;
}

Map<String, dynamic> _validateMarker(Map<String, dynamic> marker) {
  if (!marker.containsKey('format') || !marker.containsKey('version')) {
    throw const BackupProtectionException('cloud_protection_metadata_invalid');
  }
  if (marker['format'] != 'BreezeBackupProtection' || marker['version'] != 1) {
    throw const BackupProtectionException(
      'unsupported_cloud_protection_version',
    );
  }
  if (marker['phase'] == 'converting') {
    _fields(marker, {'format', 'version', 'phase', 'transition'});
    _validatePlan(_map(marker['transition']));
  } else if (marker['phase'] == 'ready') {
    _fields(marker, {
      'format',
      'version',
      'phase',
      'mode',
      'profile',
      'lastTransition',
    });
    final profile = _publicProfile(marker['profile']);
    if (!['standard', 'protected'].contains(marker['mode']) ||
        (marker['mode'] == 'protected') != (profile != null) ||
        marker['lastTransition'] is! String) {
      throw const BackupProtectionException(
        'cloud_protection_metadata_invalid',
      );
    }
  } else {
    throw const BackupProtectionException(
      'unsupported_cloud_protection_version',
    );
  }
  return marker;
}

Future<_CloudState> _readCloud(ComicSyncRemoteAdapter raw) async {
  final paths = await _list(raw);
  final payloads = paths
      .where((path) => _payloadName.hasMatch(path.split('/').last))
      .toList();
  if (payloads.length > 512) {
    throw const BackupProtectionException('too_many_cloud_payloads');
  }
  final journals = paths
      .where((path) => _journalName.hasMatch(path.split('/').last))
      .toList();
  if (journals.length > 1) {
    throw const BackupProtectionException(
      'cloud_protection_transition_conflict',
    );
  }
  Map<String, dynamic>? marker, plan;
  String? incompleteJournal;
  BackupProtectionException? markerError;
  if (paths.contains(_rootPath(_markerName))) {
    try {
      marker = _validateMarker(
        _decodePublic(
          await _download(raw, _rootPath(_markerName), limit: _publicLimit),
        ),
      );
    } on BackupProtectionException catch (error) {
      // Unknown versions are never interpreted using an older transition file.
      if (error.code == 'unsupported_cloud_protection_version' ||
          error.code == 'unsupported_version') {
        rethrow;
      }
      markerError = error;
    }
  }
  if (journals.isNotEmpty) {
    try {
      plan = _validatePlan(
        _decodePublic(
          await _download(raw, journals.single, limit: _publicLimit),
        ),
      );
      if (_planPath(plan) != journals.single) {
        throw const BackupProtectionException(
          'cloud_protection_metadata_invalid',
        );
      }
    } on BackupProtectionException catch (error) {
      if (error.code == 'unsupported_cloud_protection_version' ||
          error.code == 'unsupported_version') {
        rethrow;
      }
      final id = _journalName
          .firstMatch(journals.single.split('/').last)!
          .group(1)!;
      final hasStage = paths.any(
        (path) => path.split('/').last.startsWith('protection_stage_${id}_'),
      );
      // Our immutable journal is never rewritten. An interrupted initial PUT
      // with no stages and no converting marker preceded all payload changes.
      if (hasStage || marker?['phase'] == 'converting' || markerError != null) {
        rethrow;
      }
      incompleteJournal = journals.single;
    }
  }
  if (marker?['phase'] == 'converting') {
    final embedded = _validatePlan(_map(marker!['transition']));
    if (plan != null && jsonEncode(plan) != jsonEncode(embedded)) {
      throw const BackupProtectionException(
        'cloud_protection_transition_conflict',
      );
    }
    plan ??= embedded;
  }
  if (markerError != null && plan == null) throw markerError;
  final completed =
      plan != null &&
      marker?['phase'] == 'ready' &&
      marker?['lastTransition'] == plan['id'];
  if (completed &&
      _profileJson(_publicProfile(marker!['profile'])) !=
          _profileJson(_publicProfile(plan['targetProfile']))) {
    throw const BackupProtectionException(
      'cloud_protection_transition_conflict',
    );
  }
  return _CloudState(
    payloads,
    marker,
    plan,
    completed,
    incompleteJournal: incompleteJournal,
  );
}

Future<void> _putVerified(
  ComicSyncRemoteAdapter raw,
  String path,
  Uint8List bytes, {
  int? limit,
}) async {
  await raw.uploadRemoteFile(path, bytes);
  final readBack = await _download(raw, path, limit: limit ?? bytes.length);
  if (!await _sameBytes(readBack, bytes)) {
    throw const BackupProtectionException(
      'cloud_protection_write_verification_failed',
    );
  }
}

Future<bool> _sameBytes(Uint8List left, Uint8List right) async {
  if (left.length != right.length) return false;
  bool compare() => sha256.convert(left) == sha256.convert(right);
  return left.length < 128 * 1024 ? compare() : Isolate.run(compare);
}

Future<Uint8List> _stageEncode(Uint8List bytes) async =>
    bytes.length < 128 * 1024
    ? _encodeStage(bytes)
    : Isolate.run(() => _encodeStage(bytes));
Future<Uint8List> _stageDecode(Uint8List bytes) async =>
    bytes.length < 128 * 1024
    ? _decodeStage(bytes)
    : Isolate.run(() => _decodeStage(bytes));

Uint8List _jsonBytes(Map<String, dynamic> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
Map<String, dynamic> _readyMarker(
  BackupProtectionProfile? profile,
  String id,
) => {
  'format': 'BreezeBackupProtection',
  'version': 1,
  'phase': 'ready',
  'mode': profile == null ? 'standard' : 'protected',
  'profile': profile?.toJson(),
  'lastTransition': id,
};

// Temporary stage has an explicit length+SHA-256, so partial failed uploads are
// distinguished from a verified target after process death. Target protected
// bytes retain their AEAD authentication; standard is chosen explicitly only.
Uint8List _encodeStage(Uint8List target) {
  final stage = Uint8List(44 + target.length);
  stage.setRange(0, 8, utf8.encode('BZSTAGE1'));
  ByteData.sublistView(stage).setUint32(8, target.length);
  stage.setRange(12, 44, sha256.convert(target).bytes);
  stage.setRange(44, stage.length, target);
  return stage;
}

Uint8List _decodeStage(Uint8List stage) {
  if (stage.length >= 8 &&
      utf8.decode(stage.sublist(0, 7), allowMalformed: true) == 'BZSTAGE' &&
      stage[7] != 49) {
    throw const BackupProtectionException(
      'unsupported_cloud_protection_version',
    );
  }
  if (stage.length < 44 ||
      utf8.decode(stage.sublist(0, 8), allowMalformed: true) != 'BZSTAGE1') {
    throw const BackupProtectionException('cloud_protection_stage_invalid');
  }
  final length = ByteData.sublistView(stage).getUint32(8);
  if (stage.length != 44 + length) {
    throw const BackupProtectionException('cloud_protection_stage_invalid');
  }
  final target = Uint8List.sublistView(stage, 44);
  final actual = sha256.convert(target).bytes;
  for (var index = 0; index < 32; index++) {
    if (actual[index] != stage[index + 12]) {
      throw const BackupProtectionException('cloud_protection_stage_invalid');
    }
  }
  return target;
}

extension _CloudProtectionOperations on BackupProtectionManager {
  Future<void> _beginTransition(
    ComicSyncRemoteAdapter raw,
    String operation,
    BackupProtectionProfile? target,
  ) async {
    final state = await _readCloud(raw);
    if (state.plan != null) {
      throw const BackupProtectionException(
        'cloud_protection_transition_pending',
      );
    }
    final source = state.readyProfile;
    if (operation == 'enable' && source != null) {
      await discover(source);
      if (source.archiveId == target?.archiveId) {
        await prepareCloud(raw);
        return;
      }
      throw const BackupProtectionException('cloud_already_protected');
    }
    if (operation != 'enable' && source == null) {
      throw const BackupProtectionException('cloud_not_protected');
    }
    final requiredProfile = source ?? target!;
    if (_session == null ||
        _session!.profile.archiveId != requiredProfile.archiveId) {
      await discover(requiredProfile);
      throw const BackupProtectionException('backup_locked');
    }
    // Authenticate all existing envelopes before publishing transition intent.
    // A marker removal must never be interpreted as permission to downgrade.
    for (final path in state.payloads) {
      final bytes = await _download(raw, path);
      if (BackupProtectionService.isProtectedBytes(bytes)) {
        BackupProtectionService.readProfileFromBytes(
          bytes,
        ); // Version preflight.
        if (source == null) {
          throw const BackupProtectionException(
            'cloud_protection_metadata_missing',
          );
        }
        await _session!.decryptBytes(bytes);
      } else if (source != null) {
        throw const BackupProtectionException(
          'cloud_protection_payload_unprotected',
        );
      }
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final plan = _validatePlan({
      'format': 'BreezeProtectionTransition',
      'version': 1,
      'id': id,
      'operation': operation,
      'files': state.payloads,
      'sourceProfile': source?.toJson(),
      'targetProfile': target?.toJson(),
    });
    if (state.incompleteJournal != null) {
      await raw.deleteRemoteFiles([state.incompleteJournal!]);
    }
    await raw.ensureRemoteReady();
    // Immutable verified journal precedes any overwrite, including the marker.
    await _putVerified(
      raw,
      _planPath(plan),
      _jsonBytes(plan),
      limit: _publicLimit,
    );
    await _putVerified(
      raw,
      _rootPath(_markerName),
      _jsonBytes({
        'format': 'BreezeBackupProtection',
        'version': 1,
        'phase': 'converting',
        'transition': plan,
      }),
      limit: _publicLimit,
    );
    await _runTransition(raw, plan);
  }

  Future<void> _runTransition(
    ComicSyncRemoteAdapter raw,
    Map<String, dynamic> plan,
  ) async {
    final source = _publicProfile(plan['sourceProfile']);
    final target = _publicProfile(plan['targetProfile']);
    final requiredProfile = target ?? source!;
    if (_session == null ||
        _session!.profile.archiveId != requiredProfile.archiveId) {
      await discover(requiredProfile);
      throw const BackupProtectionException('backup_locked');
    }
    // Authenticate the plan's public key slots with the authorized root key.
    final selected = await _session!.adoptProfile(requiredProfile);
    await _accept(selected);
    final paths = await _list(raw);
    final files = List<String>.from(plan['files'] as List);
    final unexpected = paths.where(
      (path) =>
          _payloadName.hasMatch(path.split('/').last) && !files.contains(path),
    );
    if (unexpected.isNotEmpty) {
      throw const BackupProtectionException('cloud_protection_changed_retry');
    }
    // Recognize every current/staged format before the first resumed write.
    // A future client must never be overwritten merely because this journal is old.
    for (final path in files) {
      if (paths.contains(path)) {
        final bytes = await _download(raw, path);
        if (BackupProtectionService.isProtectedBytes(bytes)) {
          BackupProtectionService.readProfileFromBytes(bytes);
        }
      }
      final stagePath = _stagePath(plan, path);
      if (paths.contains(stagePath)) {
        try {
          final staged = await _stageDecode(
            await _download(
              raw,
              stagePath,
              limit: BackupProtectionSession.maxBytesPayload + 65536 + 8192,
            ),
          );
          if (BackupProtectionService.isProtectedBytes(staged)) {
            BackupProtectionService.readProfileFromBytes(staged);
          }
        } on BackupProtectionException catch (error) {
          if (error.code.startsWith('unsupported_')) rethrow;
          // A partially uploaded stage will be rebuilt from the original below.
        }
      }
    }
    for (final path in files) {
      final stagePath = _stagePath(plan, path);
      Uint8List? desired;
      if (paths.contains(stagePath)) {
        try {
          desired = await _stageDecode(
            await _download(
              raw,
              stagePath,
              limit: BackupProtectionSession.maxBytesPayload + 65536 + 8192,
            ),
          );
          if (target != null) {
            final stagedProfile = BackupProtectionService.readProfileFromBytes(
              desired,
            );
            if (_profileJson(stagedProfile) != _profileJson(target)) {
              throw const BackupProtectionException(
                'cloud_protection_stage_invalid',
              );
            }
            await _session!.decryptBytes(desired);
          } else if (BackupProtectionService.isProtectedBytes(desired)) {
            throw const BackupProtectionException(
              'cloud_protection_stage_invalid',
            );
          }
        } on BackupProtectionException catch (error) {
          if (error.code.startsWith('unsupported_')) rethrow;
          // Failed stage upload precedes any authoritative overwrite; rebuild
          // from the original if it still authenticates. Never delete it first.
          desired = null;
        }
      }
      if (desired == null) {
        if (!paths.contains(path)) {
          throw const BackupProtectionException(
            'cloud_protection_source_missing',
          );
        }
        final original = await _download(raw, path);
        final protected = BackupProtectionService.isProtectedBytes(original);
        if (protected) {
          BackupProtectionService.readProfileFromBytes(original);
          if (source == null && plan['operation'] != 'enable') {
            throw const BackupProtectionException(
              'cloud_protection_stage_invalid',
            );
          }
          if (target == null) {
            desired = await _session!.decryptBytes(original);
          } else {
            desired = await _session!.rewrapBytesHeader(original);
          }
        } else {
          if (source != null && plan['operation'] != 'disable') {
            throw const BackupProtectionException(
              'cloud_protection_payload_unprotected',
            );
          }
          desired = target == null
              ? original
              : await _session!.encryptBytes(original);
        }
        await _putVerified(
          raw,
          stagePath,
          await _stageEncode(desired),
          limit: BackupProtectionSession.maxBytesPayload + 65536 + 8192,
        );
      }
      await _putVerified(raw, path, desired);
    }
    // Retain every verified stage until every authoritative file and the final
    // marker are durable. A failed final-marker upload resumes from the journal.
    await _putVerified(
      raw,
      _rootPath(_markerName),
      _jsonBytes(_readyMarker(target, plan['id'] as String)),
      limit: _publicLimit,
    );
    if (target == null) {
      await profileStore.write(null);
      _profile = null;
      lock();
    } else {
      final refreshed = await _session!.adoptProfile(target);
      await _accept(refreshed);
    }
    await _cleanupTransition(raw, plan);
  }

  Future<void> _cleanupTransition(
    ComicSyncRemoteAdapter raw,
    Map<String, dynamic> plan,
  ) async {
    // The caller verified ready marker first (or _readCloud matched its tx ID).
    // Stages are never touched while this transaction remains authoritative.
    final paths = await _list(raw);
    final stages = [
      for (final path in List<String>.from(plan['files'] as List))
        if (paths.contains(_stagePath(plan, path))) _stagePath(plan, path),
    ];
    for (final path in List<String>.from(plan['files'] as List)) {
      final stage = _stagePath(plan, path);
      if (!paths.contains(stage)) continue;
      if (!paths.contains(path)) {
        throw const BackupProtectionException(
          'cloud_protection_cleanup_not_safe',
        );
      }
      final target = await _stageDecode(
        await _download(
          raw,
          stage,
          limit: BackupProtectionSession.maxBytesPayload + 65536 + 8192,
        ),
      );
      final current = await _download(raw, path);
      if (!await _sameBytes(current, target)) {
        throw const BackupProtectionException(
          'cloud_protection_cleanup_not_safe',
        );
      }
    }
    if (stages.isNotEmpty) await raw.deleteRemoteFiles(stages);
    if (paths.contains(_planPath(plan))) {
      await raw.deleteRemoteFiles([_planPath(plan)]);
    }
  }
}
