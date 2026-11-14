import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_resource_paths.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/local_import_recovery.dart'
    show LocalImportRecovery;

part 'backup_protection_cloud.dart';

enum BackupProtectionMode { standard, passwordProtected }

/// Implemented by the transport wrapper so explicit protection operations can
/// reach its raw transport without recursively encrypting migration records.
abstract interface class BackupProtectionTransportAccess {
  ComicSyncRemoteAdapter get protectionTransport;
  void invalidateProtection();
}

abstract interface class BackupProtectionProfileStore {
  Future<BackupProtectionProfile?> read();
  Future<void> write(BackupProtectionProfile? profile);
}

class PreferencesBackupProtectionProfileStore
    implements BackupProtectionProfileStore {
  static const key = 'breeze.local.backup-protection.profile.v1';

  @override
  Future<BackupProtectionProfile?> read() async {
    final encoded = (await SharedPreferences.getInstance()).getString(key);
    if (encoded == null) return null;
    try {
      if (encoded.length > 65536) throw const FormatException();
      return BackupProtectionProfile.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const BackupProtectionException('local_protection_profile_invalid');
    }
  }

  @override
  Future<void> write(BackupProtectionProfile? profile) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = profile == null
        ? await preferences.remove(key)
        : await preferences.setString(key, jsonEncode(profile.toJson()));
    if (!saved) {
      throw const BackupProtectionException('protection_profile_not_saved');
    }
  }
}

class CloudBackupProtectionStatus {
  const CloudBackupProtectionStatus({
    required this.mode,
    this.profile,
    this.transitionOperation,
    this.cleanupPending = false,
  });
  final BackupProtectionMode mode;
  final BackupProtectionProfile? profile;
  final String? transitionOperation;
  final bool cleanupPending;
  bool get transitionPending => transitionOperation != null;
}

/// Shared by cloud settings and file backup UI. Public profiles may persist;
/// sessions, passwords and recovery secrets never enter preferences or logs.
/// Network operations occur only through explicit cloud methods below.
class BackupProtectionManager {
  BackupProtectionManager({
    BackupProtectionService? service,
    BackupProtectionProfileStore? profileStore,
    Future<void> Function(Future<void> Function())? operationRunner,
  }) : service = service ?? BackupProtectionService(),
       profileStore = profileStore ?? PreferencesBackupProtectionProfileStore(),
       _operationRunner = operationRunner ?? syncStorageOperations.run;

  static final shared = BackupProtectionManager();
  final BackupProtectionService service;
  final BackupProtectionProfileStore profileStore;
  final Future<void> Function(Future<void> Function()) _operationRunner;
  BackupProtectionProfile? _profile;
  BackupProtectionSession? _session;
  Future<void>? _loading;
  bool _loaded = false;
  bool _changingCloud = false;
  int _revision = 0;

  BackupProtectionProfile? get profile => _profile;
  BackupProtectionSession? get session => _session;
  BackupProtectionMode get mode => _profile == null
      ? BackupProtectionMode.standard
      : BackupProtectionMode.passwordProtected;
  bool get isUnlocked => _session != null;
  int get revision => _revision;

  Future<void> load() async {
    if (_loaded) return;
    final task = _loading ??= _load();
    try {
      await task;
    } finally {
      if (identical(task, _loading)) _loading = null;
    }
  }

  Future<void> _load() async {
    _profile = await profileStore.read();
    _loaded = true;
    _revision++;
  }

  Future<PendingBackupProtection> create(String password) =>
      service.create(password);

  Future<BackupProtectionSession> confirmSetup(
    PendingBackupProtection pending,
    String enteredRecoveryCode, {
    bool trustDevice = true,
  }) async {
    await load();
    final unlocked = await service.confirmRecovery(
      pending,
      enteredRecoveryCode,
      trustDevice: trustDevice,
    );
    await _accept(unlocked);
    return unlocked;
  }

  Future<BackupProtectionSession> unlock({
    BackupProtectionProfile? profile,
    String? password,
    String? recoveryCode,
    String? recoveryFile,
    bool useTrustedDevice = false,
    bool trustDevice = false,
  }) async {
    await load();
    final target = profile ?? _profile;
    if (target == null) {
      throw const BackupProtectionException('no_protection_profile');
    }
    final unlocked = await service.unlockProfile(
      target,
      password: password,
      recoveryCode: recoveryCode,
      recoveryFile: recoveryFile,
      useTrustedDevice: useTrustedDevice,
      trustDevice: trustDevice,
    );
    await _accept(unlocked);
    return unlocked;
  }

  Future<void> _accept(
    BackupProtectionSession unlocked, {
    bool persist = true,
  }) async {
    if (persist) await profileStore.write(unlocked.profile);
    _profile = unlocked.profile;
    final old = _session;
    _session = unlocked;
    if (!identical(old, unlocked)) old?.dispose();
    _revision++;
  }

  void lock() {
    _session?.dispose();
    _session = null;
    _revision++;
  }

  /// Changes wrapping metadata for future file exports only. Previously
  /// exported files and any cloud archive retain their existing password.
  Future<void> changeLocalPassword(String password) =>
      _exclusiveCloud(() async {
        await load();
        final unlocked = _session;
        if (unlocked == null) {
          throw const BackupProtectionException('backup_locked');
        }
        final changed = await unlocked.changePassword(password);
        await _accept(changed);
      });

  /// Chooses standard mode for future file exports only. This performs no
  /// network request and cannot disable protection of an existing cloud archive.
  Future<void> useStandardFileBackups() => _exclusiveCloud(() async {
    await load();
    await profileStore.write(null);
    _profile = null;
    lock();
  });

  /// Discovery exposes only public metadata. It never trusts or stores a key.
  Future<void> discover(
    BackupProtectionProfile remote, {
    bool persist = true,
  }) async {
    await load();
    if (_session?.profile.archiveId != remote.archiveId) {
      lock();
      _profile = remote;
      // Trust was granted explicitly during setup/unlock. Reusing that native
      // device key keeps the existing daily Sync action a single operation.
      try {
        final trusted = await service.unlockProfile(
          remote,
          useTrustedDevice: true,
        );
        await _accept(trusted, persist: persist);
      } on BackupProtectionException catch (error) {
        if (error.code != 'device_not_authorized' &&
            error.code != 'device_storage_unavailable') {
          rethrow;
        }
      }
      return;
    }
    if (_profileJson(_session!.profile) == _profileJson(remote)) {
      // The immutable wrapping metadata was authenticated when unlocked.
      // Avoid a worker and preference write on every unchanged sync round.
      _profile = remote;
      return;
    }
    final refreshed = await _session!.adoptProfile(remote);
    await _accept(refreshed, persist: persist);
  }

  Future<CloudBackupProtectionStatus> inspectCloud(
    ComicSyncRemoteAdapter adapter,
  ) async {
    await load();
    final state = await _readCloud(_raw(adapter));
    final visible = state.visibleProfile;
    if (visible != null) await discover(visible);
    return state.status;
  }

  /// Full protection preflight before a domain may alter local or remote data.
  /// Raw payloads are bounded; caller may retain a small cache for this round.
  Future<CloudBackupProtectionStatus> prepareCloud(
    ComicSyncRemoteAdapter adapter, {
    void Function(String path, Uint8List decoded)? onDecoded,
    bool authenticateResources = true,
    Set<String> fullReplaceStagingPaths = const {},
    bool fullReplaceReadOnlyDiscovery = false,
  }) async {
    await load();
    final raw = _raw(adapter);
    final state = await _readCloud(raw);
    if (state.incompleteJournal != null ||
        (state.plan != null && !state.completed)) {
      if (state.visibleProfile != null)
        await discover(
          state.visibleProfile!,
          persist: !fullReplaceReadOnlyDiscovery,
        );
      throw const BackupProtectionException(
        'cloud_protection_transition_pending',
      );
    }
    final remoteProfile = state.readyProfile;
    if (remoteProfile != null) {
      await discover(remoteProfile, persist: !fullReplaceReadOnlyDiscovery);
      if (_session == null) {
        throw const BackupProtectionException('backup_locked');
      }
    }
    for (final path in state.payloads) {
      // Only the explicit full-replacement adapter supplies certified local
      // pending publication names. It reads these bytes separately and binds
      // their actual digest to a fresh destructive preview, never imports them.
      if (fullReplaceStagingPaths.contains(path)) continue;
      // Immutable images are authenticated by the adapter on first use/reuse.
      // Explicit protection transitions still enumerate and convert every blob.
      if (!authenticateResources && isAppearanceResourcePath(path)) continue;
      final bytes = await _download(raw, path);
      final protected = BackupProtectionService.isProtectedBytes(bytes);
      if (protected && remoteProfile == null) {
        final found = BackupProtectionService.readProfileFromBytes(bytes);
        await discover(found, persist: !fullReplaceReadOnlyDiscovery);
        throw const BackupProtectionException(
          'cloud_protection_metadata_missing',
        );
      }
      if (!protected && remoteProfile != null) {
        throw const BackupProtectionException(
          'cloud_protection_payload_unprotected',
        );
      }
      if (protected &&
          _profileJson(BackupProtectionService.readProfileFromBytes(bytes)) !=
              _profileJson(remoteProfile)) {
        throw const BackupProtectionException('cloud_protection_changed_retry');
      }
      final decoded = protected ? await _session!.decryptBytes(bytes) : bytes;
      onDecoded?.call(path, decoded);
    }
    return state.status;
  }

  /// Every write rechecks public control state. A default standard client can
  /// never replace or delete payloads belonging to a protected remote archive.
  Future<void> guardCloudMutation(
    ComicSyncRemoteAdapter adapter,
    CloudBackupProtectionStatus expected,
  ) async {
    final state = await _readCloud(_raw(adapter));
    if (state.incompleteJournal != null || state.plan != null) {
      throw const BackupProtectionException(
        'cloud_protection_transition_pending',
      );
    }
    if (state.status.mode != expected.mode ||
        _profileJson(state.readyProfile) != _profileJson(expected.profile)) {
      throw const BackupProtectionException('cloud_protection_changed_retry');
    }
    sessionForProfile(state.readyProfile);
  }

  /// An in-flight operation may outlive discovery of another endpoint.
  /// Resolve against its own archive before capturing the key.
  BackupProtectionSession? sessionForProfile(BackupProtectionProfile? profile) {
    if (profile == null) return null;
    final active = _session;
    if (active == null) {
      throw const BackupProtectionException('backup_locked');
    }
    if (_profileJson(active.profile) != _profileJson(profile)) {
      throw const BackupProtectionException('cloud_protection_changed_retry');
    }
    return active;
  }

  Future<void> enableCloud(ComicSyncRemoteAdapter adapter) =>
      _exclusiveCloud(() async {
        await load();
        if (_session == null) {
          throw const BackupProtectionException('backup_locked');
        }
        await _beginTransition(_raw(adapter), 'enable', _session!.profile);
      });

  Future<void> disableCloud(ComicSyncRemoteAdapter adapter) =>
      _exclusiveCloud(() async {
        await load();
        await _beginTransition(_raw(adapter), 'disable', null);
      });

  Future<void> changeCloudPassword(
    ComicSyncRemoteAdapter adapter,
    String password,
  ) => _exclusiveCloud(() async {
    await load();
    final raw = _raw(adapter);
    final state = await _readCloud(raw);
    if (state.plan != null) {
      throw const BackupProtectionException(
        'cloud_protection_transition_pending',
      );
    }
    if (state.readyProfile == null) {
      throw const BackupProtectionException('cloud_not_protected');
    }
    await discover(state.readyProfile!);
    if (_session == null) {
      throw const BackupProtectionException('backup_locked');
    }
    final changed = await _session!.changePassword(password);
    // Save public target metadata before starting remote work; the trusted root
    // key remains the same, and the cloud plan carries both public profiles.
    await _accept(changed);
    await _beginTransition(raw, 'password', changed.profile);
  });

  Future<void> resumeCloudTransition(
    ComicSyncRemoteAdapter adapter, {
    bool approveDisable = false,
  }) => _exclusiveCloud(() async {
    await load();
    final raw = _raw(adapter);
    final state = await _readCloud(raw);
    if (state.incompleteJournal != null) {
      await raw.deleteRemoteFiles([state.incompleteJournal!]);
      return;
    }
    if (state.plan == null) return;
    if (state.completed) {
      final target = _publicProfile(state.plan!['targetProfile']);
      if (target == null) {
        await profileStore.write(null);
        _profile = null;
        lock();
      } else {
        await discover(target);
      }
      await _cleanupTransition(raw, state.plan!);
      return;
    }
    if (state.plan!['operation'] == 'disable' && !approveDisable) {
      throw const BackupProtectionException('disable_confirmation_required');
    }
    await _runTransition(raw, state.plan!);
  });

  Future<void> _exclusiveCloud(Future<void> Function() action) async {
    if (_changingCloud) {
      throw const BackupProtectionException('cloud_protection_busy');
    }
    _changingCloud = true;
    try {
      await _operationRunner(() async {
        LocalImportRecovery.requireRecovered();
        await action();
      });
    } finally {
      _changingCloud = false;
    }
  }

  ComicSyncRemoteAdapter _raw(ComicSyncRemoteAdapter adapter) {
    var result = adapter;
    if (result is ScopedSyncArchiveAdapter) {
      if (result.context.readOnly) throw const LegacyArchiveReadOnly();
      result.invalidate();
      result = result.transport;
    }
    if (result is BackupProtectionTransportAccess) {
      final access = result as BackupProtectionTransportAccess;
      access.invalidateProtection();
      result = access.protectionTransport;
    }
    return result;
  }
}
