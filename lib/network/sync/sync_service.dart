import 'dart:async';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/sync/plugin_account_profiles_data.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/network/sync/plugin_account_projection.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
export 'package:zephyr/network/sync/sync_direction.dart';
import 'dart:math' show max;
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/backup_protection_adapter.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/navigation/legacy_navigation_settings.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show TxMode;
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/network/sync/chapter_progress_sync.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_recovery.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/sync_archive_service.dart' as archive_ops;
export 'package:zephyr/network/sync/sync_archive_context.dart'
    show SyncRunResult;

import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/s3_sync_service.dart';
import 'package:zephyr/network/sync/webdav_sync_service.dart';

const String _settingsSyncSchemaVersion = 'v2';
const String _settingsBlockMetaPrefsKey = 'sync.settings.block.meta.v3';

const String _appearanceBlockName = 'appearance';
const String _navigationBlockName = 'mainNavigation';
const String _libraryBlockName = 'library';
const String _readerBlockName = 'reader';
const String _pluginsBlockName = 'plugins';
const String _videoBlockName = 'video';

/// Production retains Breeze's existing compression/encryption. A codec seam
/// lets transport/merge tests use a fake remote without native Rust or accounts.
class SettingsSyncCodec {
  const SettingsSyncCodec({
    this.encode = ComicSyncCore.encodeEncryptedPayload,
    this.decode = ComicSyncCore.decodeEncryptedPayload,
  });
  final Future<List<int>> Function(List<int>) encode;
  final Future<List<int>> Function(List<int>) decode;
}

const List<String> _syncableSettingsBlockNames = <String>[
  _appearanceBlockName,
  _navigationBlockName,
  _libraryBlockName,
  _readerBlockName,
  _videoBlockName,
];

bool isSyncServiceConfigured(GlobalSettingState state) {
  switch (state.syncSetting.syncServiceType) {
    case SyncServiceType.none:
      return false;
    case SyncServiceType.webdav:
      return WebDavSyncService.isConfigured(state);
    case SyncServiceType.s3:
      return S3SyncService.isConfigured(state);
  }
}

/// Stable archive ownership derived only from the configured connection.
String? syncArchiveIdentityForState(GlobalSettingState state) {
  if (!isSyncServiceConfigured(state)) return null;
  return ComicSyncCore.calculateMd5(
    utf8.encode(
      jsonEncode({
        'kind': state.syncSetting.syncServiceType.name,
        if (state.syncSetting.syncServiceType == SyncServiceType.webdav) ...{
          'host': state.syncSetting.webdavSetting.host,
          'user': state.syncSetting.webdavSetting.username,
        } else ...{
          'host': state.syncSetting.s3Setting.endpoint,
          'bucket': state.syncSetting.s3Setting.bucket,
        },
      }),
    ),
  );
}

/// Startup can settle this device's interrupted cloud apply without a network
/// connection. A damaged checkpoint remains available to scoped sync preflight.
Future<bool> recoverStartupCloudArchive(GlobalSettingState state) async {
  final identity = syncArchiveIdentityForState(state);
  if (identity == null) return true;
  try {
    await ArchivePreferenceTransaction.recover(identity);
    return true;
  } on ArchiveRestoreFailed {
    return false;
  }
}

ScopedSyncArchiveAdapter? createSyncAdapter(GlobalSettingState state) =>
    createSyncArchiveAdapter(state);

ScopedSyncArchiveAdapter? createSyncArchiveAdapter(
  GlobalSettingState state, {
  SyncArchiveContext archive = SyncArchiveContext.current,
}) {
  final identity = syncArchiveIdentityForState(state);
  if (identity == null) return null;

  final ComicSyncRemoteAdapter transport;
  switch (state.syncSetting.syncServiceType) {
    case SyncServiceType.none:
      return null;
    case SyncServiceType.webdav:
      transport = WebDavSyncService(state, archive: archive);
      break;
    case SyncServiceType.s3:
      transport = S3SyncService(state, archive: archive);
      break;
  }
  final protectedTransport = archive.legacy
      ? null
      : BackupProtectionSyncAdapter(transport);
  final adapter = ScopedSyncArchiveAdapter(
    protectedTransport ?? transport,
    archive,
    identity: identity,
    legacyReader: archive.legacy
        ? null
        : createSyncArchiveAdapter(
            state,
            archive: SyncArchiveContext.legacyReadOnly,
          ),
  );
  adapter.onInvalidate = protectedTransport?.invalidateProtection;
  adapter.roundPreflight = () => preflightSyncRound(adapter);
  return adapter;
}

final _syncOperations = syncStorageOperations;

/// Backup imports/exports share the cloud entrypoints' queue. Acquire any
/// cache workspace lease before enqueueing, so staging stays protected while
/// another data operation finishes.
Future<T> runExclusiveStorageOperation<T>(
  Future<T> Function() action, {
  bool allowPendingRecovery = false,
}) async {
  late T result;
  await _syncOperations.run(() async {
    if (!allowPendingRecovery) LocalImportRecovery.requireRecovered();
    result = await action();
  });
  return result;
}

/// Read every participating contract before the first channel changes local or
/// remote data. Each public channel also validates again at its own boundary.
Future<void> preflightSyncRound(
  ComicSyncRemoteAdapter adapter, {
  ComicSyncCodec comicCodec = const ComicSyncCodec(),
  SettingsSyncCodec settingsCodec = const SettingsSyncCodec(),
  VideoLibrarySyncCodec videoCodec = const VideoLibrarySyncCodec(),
  bool requireCloudBackup = false,
  Future<bool> Function()? checkChapterProgress,
}) async {
  if (adapter is ScopedSyncArchiveAdapter) {
    await ArchivePreferenceTransaction.recover(adapter.identity);
  }
  await adapter.testConnection();
  if (!requireCloudBackup) await adapter.ensureRemoteReady();

  Future<bool> checkRecords(ComicSyncRemoteAdapter source) async {
    final comic = await readComicArchiveData(source, codec: comicCodec);
    final video = await VideoLibrarySync.readArchive(source, codec: videoCodec);
    final settings = await readSettingsArchiveData(
      source,
      codec: settingsCodec,
    );
    return comic != null || video.digests.isNotEmpty || settings != null;
  }

  final hasCurrent = await checkRecords(adapter);
  final hasChapterProgress =
      await (checkChapterProgress?.call() ??
          ChapterProgressSync.read(
            adapter,
            codec: videoCodec,
          ).then((rows) => rows.isNotEmpty));
  final hasArtwork = await preflightAppearanceImages(adapter);
  var hasLegacy = false;
  if (adapter is ScopedSyncArchiveAdapter &&
      !adapter.context.legacy &&
      adapter.legacyReader != null) {
    hasLegacy = await checkRecords(adapter.legacyReader!);
  }
  if (requireCloudBackup) {
    if (!hasCurrent && !hasChapterProgress && !hasArtwork && !hasLegacy)
      throw const NoCloudBackup();
    await adapter.ensureRemoteReady();
  }
}

Future<void> preflightSettingsSync(
  ComicSyncRemoteAdapter adapter, {
  SettingsSyncCodec codec = const SettingsSyncCodec(),
}) async {
  await readSettingsArchiveData(adapter, codec: codec);
}

class SettingsArchiveData {
  SettingsArchiveData._(this._snapshot, this.digest);
  final _SettingsSnapshot _snapshot;
  final String digest;

  /// Read-only projection of a fully validated archive. Device database IDs and
  /// local-only purge provenance are never imported through this preview.
  List<PluginConfig> pluginConfigsForSource(String source) {
    final names = pluginConfigNamesForSource(source);
    return List.unmodifiable(
      _toJsonMapList(_snapshot.blocks[_pluginsBlockName]?.data['pluginConfigs'])
          .where((row) => names.contains('${row['name'] ?? ''}'.trim()))
          .map((row) {
            final parsed = PluginConfig.fromJson(row);
            return PluginConfig(
              name: parsed.name.trim(),
              config: pluginConfigForSync(parsed.config, name: parsed.name),
            );
          }),
    );
  }
}

Future<SettingsArchiveData?> readSettingsArchiveData(
  ComicSyncRemoteAdapter adapter, {
  SettingsSyncCodec codec = const SettingsSyncCodec(),
}) async {
  await LocalPluginInstallationState.instance.load();
  final files = (await adapter.listRemoteDataFiles())
      .where(ComicSyncCore.isSyncRootPath)
      .toList();
  final candidates = ComicSyncCore.sortSettingsFilesByTimestampDesc(files);
  final digest = await _downloadRemoteText(
    adapter,
    _remoteSettingsMd5Path,
    returnEmptyIfMissing: true,
  );
  if (candidates.isEmpty && digest.isEmpty) return null;
  final remote = await _selectLatestRemoteSettingsData(adapter, files, digest);
  if (remote == null) throw const SyncCompatibilityException();
  final snapshot = await _decodeSettingsPayload(
    remote.bytes,
    fallbackSyncTime: remote.timestamp,
    codec: codec,
  );
  return SettingsArchiveData._(
    snapshot,
    ComicSyncCore.calculateMd5(remote.bytes),
  );
}

/// A staged merge. Database persistence is synchronous so an archive importer
/// can commit comic/settings/plugin rows in one ObjectBox transaction.
class SettingsArchiveImportPlan {
  SettingsArchiveImportPlan._(
    this.initial,
    this._result,
    this.applySettings,
    this.applyPlugins,
    this._participation, [
    this._direction = SyncDirection.merge,
    this._baselinePluginData = const {},
    this._remote,
  ]);
  final SyncDirection _direction;
  final Map<String, dynamic> _baselinePluginData;
  final SettingsArchiveData? _remote;
  final GlobalSettingState initial;
  final _SettingsMergeResult _result;
  final bool applySettings, applyPlugins;
  final SyncPluginParticipation? _participation;

  Future<void> applyPreferences(
    Future<void> Function(Map<String, dynamic>) beforeWrite, {
    bool persistMetadata = true,
    Future<void> Function()? commit,
  }) async {
    Future<void> applyRemaining() async {
      if (persistMetadata) {
        final metadata = jsonEncode({
          for (final entry in _result.localBlockMeta.entries)
            entry.key: entry.value.toJson(),
        });
        await beforeWrite({_settingsBlockMetaPrefsKey: metadata});
        if (!await (await SharedPreferences.getInstance()).setString(
          _settingsBlockMetaPrefsKey,
          metadata,
        )) {
          throw StateError('Settings revisions were not saved');
        }
      }
      await commit?.call();
    }

    if (applySettings) {
      await _applyVideoBlock(
        _result.mergedSnapshot.blocks[_videoBlockName],
        beforeWrite: (expected) =>
            beforeWrite({VideoPlaybackPreferences.snapshotKey: expected}),
        commit: commit == null ? null : applyRemaining,
      );
      if (commit != null) return;
    }
    await applyRemaining();
  }

  void persistDatabase() {
    _participation?.check();
    final user = objectbox.userSettingBox.get(1);
    if (user == null) throw StateError('Local settings are unavailable');
    final current = user.globalSetting;
    final blocks = <String, _SettingsBlockPayload>{};
    if (applySettings) {
      final now = _extractSyncableSettingsBlocks(current);
      final before = _extractSyncableSettingsBlocks(initial);
      for (final name in [
        _appearanceBlockName,
        _navigationBlockName,
        _libraryBlockName,
        _readerBlockName,
      ]) {
        final block = _result.mergedSnapshot.blocks[name];
        if (block != null) {
          blocks[name] = _SettingsBlockPayload(
            name: name,
            updatedAt: block.updatedAt,
            data: _unchangedSettingsPatch(
              before[name] ?? {},
              now[name] ?? {},
              block.data,
            ),
          );
        }
      }
    }
    final merged = _applySyncableBlocksToState(current, blocks);
    user.globalSetting = merged.copyWith(
      syncSetting: current.syncSetting.copyWith(
        settingsSyncTime:
            _result.syncTime > current.syncSetting.settingsSyncTime
            ? _result.syncTime
            : current.syncSetting.settingsSyncTime,
      ),
    );
    objectbox.userSettingBox.put(user);
    if (applyPlugins && _result.shouldApplyPluginData) {
      _persistPluginBlockData(
        _result.pluginBlockData,
        participatingSources: _participation?.sources,
        mergeConfigsAt:
            _result.mergedSnapshot.blocks[_pluginsBlockName]?.updatedAt,
        configDirection: _direction,
        baselinePluginData: _direction == SyncDirection.restore
            ? _baselinePluginData
            : null,
      );
    }
  }

  Map<String, dynamic> get compatibilityPayload {
    return _buildSettingsPayload(_result.mergedSnapshot);
  }

  Future<bool> notifyCommitted({GlobalSettingCubit? globalSettingCubit}) async {
    var ready = true;
    final remote = _remote;
    if (applyPlugins && _direction == SyncDirection.restore && remote != null) {
      try {
        final sources =
            _participation?.sources ??
            (await SyncPluginParticipation.capture()).sources;
        final cookieRestores = <String>{};
        for (final source in sources) {
          final canonical = canonicalQjsSource(source);
          for (final config in remote.pluginConfigsForSource(source)) {
            if (config.name != canonical) continue;
            final backup = _toJsonMap(
              jsonDecode(config.config),
            )['account.backup'];
            if (backup is! Map || backup['version'] != 1) continue;
            final active = readHostPluginConfiguration(
              source,
            )['account.backup'];
            if (accountProfileDigest({'backup': active}) ==
                accountProfileDigest({'backup': backup})) {
              cookieRestores.add(source);
            }
          }
        }
        if (cookieRestores.isNotEmpty) {
          await PluginAccountSyncCoordinator.instance.markRestorePending(
            cookieRestores,
          );
        }
      } catch (_) {
        ready = false;
      }
    }
    try {
      if (globalSettingCubit != null && !globalSettingCubit.isClosed) {
        await globalSettingCubit.initBox();
      }
    } catch (_) {
      ready = false;
    }
    if (applyPlugins && _result.shouldApplyPluginData) {
      try {
        await PluginRegistryService.I.reconcileAfterExternalSync();
      } catch (_) {
        ready = false;
      }
    }
    return ready;
  }
}

/// These unscoped local sync cursors belonged to the previous connection.
/// The scoped legacy import and pending recovery records retain their owners.
Future<void> clearOfflineCloudConnectionMetadata(
  Future<void> Function(Map<String, dynamic>) beforeWrite,
) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = [
    _settingsBlockMetaPrefsKey,
    VideoLibrarySync.syncedDigestKey(VideoLibraryStore.shared),
  ].where(prefs.containsKey).toList();
  if (keys.isEmpty) return;
  await beforeWrite({for (final key in keys) key: null});
  for (final key in keys) {
    if (!await prefs.remove(key)) {
      throw StateError('Local cloud synchronization metadata was not reset');
    }
  }
}

Future<SettingsArchiveImportPlan> prepareSettingsArchiveImport(
  SettingsArchiveData? remote, {
  required GlobalSettingState state,
  bool includeAll = false,
  bool protectVersionedLocalFields = false,
  SyncDirection direction = SyncDirection.merge,
  SyncPluginParticipation? participation,
  bool? importSettings,
  bool? importPlugins,
}) async {
  final effective = includeAll
      ? state.copyWith(
          syncSetting: state.syncSetting.copyWith(
            syncSettings: true,
            syncPlugins: true,
          ),
        )
      : state;
  final local = await _buildLocalSettingsSnapshot(
    effective,
    includeAll: includeAll,
    persistMeta: false,
    participation: participation,
    includeSettings: importSettings,
    includePlugins: importPlugins,
  );
  final merged = await _mergeSettingsSnapshots(
    effective,
    local,
    remote?._snapshot ?? const _SettingsSnapshot(blocks: {}),
    protectVersionedLocalFields: protectVersionedLocalFields,
    direction: direction,
    participation: participation,
    includeSettings: importSettings,
    includePlugins: importPlugins,
  );
  return SettingsArchiveImportPlan._(
    state,
    merged,
    importSettings ?? (includeAll || state.syncSetting.syncSettings),
    importPlugins ?? (includeAll || state.syncSetting.syncPlugins),
    participation,
    direction,
    local.blocks[_pluginsBlockName]?.data ?? const {},
    remote,
  );
}

Future<SyncRunResult> autoSync(
  GlobalSettingState state, {
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  archive_ops.SyncArchiveAdapters? archives,
  archive_ops.SyncArchiveCodecs codecs = const archive_ops.SyncArchiveCodecs(),
  archive_ops.SyncArchiveHooks? hooks,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) => runExclusiveStorageOperation(() async {
  final current = globalSettingCubit?.state ?? state;
  if (archives == null && !isSyncServiceConfigured(current)) {
    return const SyncRunResult();
  }
  return archive_ops.runArchiveSync(
    state: current,
    direction: SyncDirection.recordsOnly,
    globalSettingCubit: globalSettingCubit,
    comicFollowCubit: comicFollowCubit,
    archives: archives,
    codecs: codecs,
    hooks: hooks,
    resolveGalleryConflict: resolveGalleryConflict,
  );
});

/// The collection's library-only command enters the same storage boundary as
/// full sync and file backups. Full sync already owns it when it runs this channel.
Future<bool> syncVideoLibrary({
  required GlobalSettingState Function() readState,
  VideoLibraryStore? store,
  ComicSyncRemoteAdapter? Function(GlobalSettingState) createAdapter =
      createSyncAdapter,
  VideoLibrarySyncCodec codec = const VideoLibrarySyncCodec(),
}) => runExclusiveStorageOperation(() async {
  final adapter = createAdapter(readState());
  if (adapter == null) return false;
  try {
    await VideoLibrarySync.run(adapter, store: store, codec: codec);
    return true;
  } finally {
    if (adapter is ScopedSyncArchiveAdapter) adapter.invalidate();
  }
});

/// Upload selected settings/accounts/artwork; records always merge.
Future<SyncRunResult> manualUploadToCloud({
  required GlobalSettingState state,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  archive_ops.SyncArchiveAdapters? archives,
  archive_ops.SyncArchiveCodecs codecs = const archive_ops.SyncArchiveCodecs(),
  archive_ops.SyncArchiveHooks? hooks,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) => _manualSync(
  state,
  SyncDirection.upload,
  globalSettingCubit: globalSettingCubit,
  comicFollowCubit: comicFollowCubit,
  archives: archives,
  codecs: codecs,
  hooks: hooks,
  resolveGalleryConflict: resolveGalleryConflict,
);

Future<SyncRunResult> manualDownloadFromCloud({
  required GlobalSettingState state,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  archive_ops.SyncArchiveAdapters? archives,
  archive_ops.SyncArchiveCodecs codecs = const archive_ops.SyncArchiveCodecs(),
  archive_ops.SyncArchiveHooks? hooks,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) => _manualSync(
  state,
  SyncDirection.restore,
  globalSettingCubit: globalSettingCubit,
  comicFollowCubit: comicFollowCubit,
  archives: archives,
  codecs: codecs,
  hooks: hooks,
  resolveGalleryConflict: resolveGalleryConflict,
);

Future<SyncRunResult> _manualSync(
  GlobalSettingState state,
  SyncDirection direction, {
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  archive_ops.SyncArchiveAdapters? archives,
  archive_ops.SyncArchiveCodecs codecs = const archive_ops.SyncArchiveCodecs(),
  archive_ops.SyncArchiveHooks? hooks,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) => runExclusiveStorageOperation(() async {
  final current = globalSettingCubit?.state ?? state;
  if (archives == null && !isSyncServiceConfigured(current)) {
    return const SyncRunResult();
  }
  return archive_ops.runArchiveSync(
    state: current,
    direction: direction,
    globalSettingCubit: globalSettingCubit,
    comicFollowCubit: comicFollowCubit,
    archives: archives,
    codecs: codecs,
    hooks: hooks,
    resolveGalleryConflict: resolveGalleryConflict,
  );
});

/// 手动上传设置与插件数据（以本地为准，直接覆盖云端）。
Future<void> uploadSettingsData(
  ComicSyncRemoteAdapter adapter, {
  required GlobalSettingState state,
  GlobalSettingCubit? globalSettingCubit,
  SettingsSyncCodec codec = const SettingsSyncCodec(),
  bool includeAll = false,
  SyncPluginParticipation? participation,
}) async {
  await runSettingsSync(
    adapter,
    currentGlobalSetting: state,
    globalSettingCubit: globalSettingCubit,
    codec: codec,
    participation: participation,
    direction: SyncDirection.upload,
    includeAll: includeAll,
  );
}

Future<void> downloadSettingsData(
  ComicSyncRemoteAdapter adapter, {
  required GlobalSettingState state,
  GlobalSettingCubit? globalSettingCubit,
  SettingsSyncCodec codec = const SettingsSyncCodec(),
  bool includeAll = false,
  SyncPluginParticipation? participation,
}) async {
  await runSettingsSync(
    adapter,
    currentGlobalSetting: state,
    globalSettingCubit: globalSettingCubit,
    codec: codec,
    participation: participation,
    direction: SyncDirection.restore,
    includeAll: includeAll,
  );
}

/// Automatic account backup is upload/merge only. It never imports settings,
/// plugin metadata or browser sessions into this device.
Future<void> runPluginAccountBackupSync(
  ComicSyncRemoteAdapter adapter, {
  required GlobalSettingState state,
  required SyncPluginParticipation participation,
  SettingsSyncCodec codec = const SettingsSyncCodec(),
}) async {
  if (!state.syncSetting.syncPlugins) return;
  final lifecycle = _PluginSettingsCaptureGuard();
  final local = await _buildLocalSettingsSnapshot(
    state,
    includeSettings: false,
    includePlugins: true,
    persistMeta: false,
    participation: participation,
  );
  final remote = await readSettingsArchiveData(adapter, codec: codec);
  final localBlock = local.blocks[_pluginsBlockName];
  if (localBlock == null) return;
  final remoteBlocks =
      remote?._snapshot.blocks ?? const <String, _SettingsBlockPayload>{};
  final remoteBlock = remoteBlocks[_pluginsBlockName];
  final data = mergePluginAccountsForBackup(
    localBlock.data,
    remoteBlock?.data ?? const {},
    sources: participation.sources,
    localUpdatedAt: localBlock.updatedAt,
    remoteUpdatedAt: remoteBlock?.updatedAt ?? 0,
  );
  if (_calculateStructuredMd5(data) ==
      _calculateStructuredMd5(remoteBlock?.data ?? const {}))
    return;
  final block = _SettingsBlockPayload(
    name: _pluginsBlockName,
    updatedAt: max(localBlock.updatedAt, remoteBlock?.updatedAt ?? 0),
    data: data,
  );
  final snapshot = _SettingsSnapshot(
    blocks: {...remoteBlocks, _pluginsBlockName: block},
  );
  final payload = await codec.encode(
    utf8.encode(jsonEncode(_buildSettingsPayload(snapshot))),
  );
  await _uploadSettingsPayload(
    adapter,
    payloadBytes: payload,
    payloadMd5: ComicSyncCore.calculateMd5(payload),
    syncTime: snapshot.syncTime,
    beforeUpload: () {
      participation.check();
      lifecycle.check();
      final latest = mergePluginAccountsForBackup(
        _buildPluginBlockData(participatingSources: participation.sources),
        const {},
        sources: participation.sources,
        localUpdatedAt: localBlock.updatedAt,
        remoteUpdatedAt: 0,
      );
      final captured = mergePluginAccountsForBackup(
        localBlock.data,
        const {},
        sources: participation.sources,
        localUpdatedAt: localBlock.updatedAt,
        remoteUpdatedAt: 0,
      );
      if (_calculateStructuredMd5(latest) !=
          _calculateStructuredMd5(captured)) {
        throw StateError('Plugin account changed during backup');
      }
    },
  );
  await _cleanupRemoteSettingsFiles(adapter);
}

Future<void> runSettingsSync(
  ComicSyncRemoteAdapter adapter, {
  required GlobalSettingState currentGlobalSetting,
  GlobalSettingCubit? globalSettingCubit,
  SettingsSyncCodec codec = const SettingsSyncCodec(),
  SyncPluginParticipation? participation,
  SyncDirection direction = SyncDirection.merge,
  bool includeAll = false,
  void Function()? onRuntimeReloadPending,
}) async {
  if (direction == SyncDirection.recordsOnly) return;
  if (direction != SyncDirection.merge) {
    return _runDirectedSettingsSync(
      adapter,
      state: currentGlobalSetting,
      globalSettingCubit: globalSettingCubit,
      codec: codec,
      participation: participation,
      direction: direction,
      includeAll: includeAll,
      onRuntimeReloadPending: onRuntimeReloadPending,
    );
  }
  participation ??= await SyncPluginParticipation.capture();
  await prepareScopedSyncArchive(adapter);
  await preflightSettingsSync(adapter, codec: codec);
  final localGlobal = globalSettingCubit?.state ?? currentGlobalSetting;
  final lifecycle = _PluginSettingsCaptureGuard();
  final localSnapshot = await _buildLocalSettingsSnapshot(
    localGlobal,
    participation: participation,
  );
  final localPayload = _buildSettingsPayload(localSnapshot);
  final localBytes = await codec.encode(utf8.encode(jsonEncode(localPayload)));
  final localMd5 = ComicSyncCore.calculateMd5(localBytes);

  final allRemote = await adapter.listRemoteDataFiles();
  final legacyFiles = allRemote
      .where(ComicSyncCore.isLegacyRemotePath)
      .toList();
  if (legacyFiles.isNotEmpty) {
    await adapter.deleteRemoteFiles(legacyFiles);
  }
  final syncRootFiles = allRemote.where(ComicSyncCore.isSyncRootPath).toList();

  final remoteMd5 = await _downloadRemoteText(
    adapter,
    _remoteSettingsMd5Path,
    returnEmptyIfMissing: true,
  );

  logger.d(
    '[sync][settings] precheck localTime=${localSnapshot.syncTime} '
    'localMd5=$localMd5 remoteMd5=$remoteMd5 remoteFiles=${syncRootFiles.length}',
  );

  if (remoteMd5.isNotEmpty && remoteMd5 == localMd5) {
    logger.d('[sync][settings] decision=skip reason=md5_equal');
    participation.check();
    await _cleanupRemoteSettingsFiles(adapter);
    await _updateLocalSettingsSyncTime(
      localGlobal,
      syncTime: localSnapshot.syncTime,
      globalSettingCubit: globalSettingCubit,
    );
    return;
  }

  final remoteData = await _selectLatestRemoteSettingsData(
    adapter,
    syncRootFiles,
    remoteMd5,
  );

  if (remoteMd5.isEmpty || remoteData == null) {
    logger.d('[sync][settings] decision=upload reason=remote_missing');
    await _uploadSettingsPayload(
      adapter,
      payloadBytes: localBytes,
      payloadMd5: localMd5,
      syncTime: localSnapshot.syncTime,
      beforeUpload: () {
        participation!.check();
        lifecycle.check();
      },
    );
    await _updateLocalSettingsSyncTime(
      localGlobal,
      syncTime: localSnapshot.syncTime,
      globalSettingCubit: globalSettingCubit,
    );
    participation.check();
    await _cleanupRemoteSettingsFiles(adapter);
    return;
  }

  final remoteSnapshot = await _decodeSettingsPayload(
    remoteData.bytes,
    fallbackSyncTime: remoteData.timestamp,
    codec: codec,
  );
  final mergeResult = await _mergeSettingsSnapshots(
    localGlobal,
    localSnapshot,
    remoteSnapshot,
    participation: participation,
  );

  logger.d(
    '[sync][settings] compare localTime=${localSnapshot.syncTime} '
    'remoteTime=${remoteSnapshot.syncTime} mergedTime=${mergeResult.syncTime} '
    'localMd5=$localMd5 remoteMd5=$remoteMd5',
  );

  participation.check();
  if (mergeResult.shouldApplyLocalState) {
    logger.d('[sync][settings] decision=apply_remote_blocks');
    await _applyMergedGlobalState(
      mergeResult.mergedState,
      initial: localGlobal,
      globalSettingCubit: globalSettingCubit,
    );
  } else {
    await _updateLocalSettingsSyncTime(
      localGlobal,
      syncTime: mergeResult.syncTime,
      globalSettingCubit: globalSettingCubit,
    );
  }

  if (mergeResult.shouldApplyPluginData) {
    await _applyPluginBlockData(
      mergeResult.pluginBlockData,
      participation: participation,
      sessionGuard: lifecycle,
    );
  }
  if (localGlobal.syncSetting.syncSettings) {
    await _applyVideoBlock(mergeResult.mergedSnapshot.blocks[_videoBlockName]);
  }

  final appliedMeta = {...mergeResult.localBlockMeta};
  final pluginBlock = mergeResult.mergedSnapshot.blocks[_pluginsBlockName];
  if (localGlobal.syncSetting.syncPlugins && pluginBlock != null) {
    appliedMeta[_pluginsBlockName] = _LocalSettingsBlockMeta(
      updatedAt: pluginBlock.updatedAt,
      hash: _calculateStructuredMd5(
        _buildPluginBlockData(participatingSources: participation.sources),
      ),
    );
  }
  await _persistLocalSettingsBlockMeta(appliedMeta);

  final mergedPayload = _buildSettingsPayload(mergeResult.mergedSnapshot);
  final mergedBytes = await codec.encode(
    utf8.encode(jsonEncode(mergedPayload)),
  );
  final mergedMd5 = ComicSyncCore.calculateMd5(mergedBytes);

  if (mergedMd5 != remoteMd5) {
    logger.d('[sync][settings] decision=upload reason=merged_snapshot_changed');
    await _uploadSettingsPayload(
      adapter,
      payloadBytes: mergedBytes,
      payloadMd5: mergedMd5,
      syncTime: mergeResult.syncTime,
      beforeUpload: () {
        participation!.check();
        lifecycle.check();
      },
    );
  } else {
    logger.d(
      '[sync][settings] decision=skip_upload reason=merged_snapshot_equals_remote',
    );
  }

  participation.check();
  await _cleanupRemoteSettingsFiles(adapter);
}

Map<String, dynamic> _unchangedSettingsPatch(
  Map<String, dynamic> before,
  Map<String, dynamic> current,
  Map<String, dynamic> incoming,
) => {
  for (final entry in incoming.entries)
    if (_calculateStructuredMd5({'v': before[entry.key]}) ==
        _calculateStructuredMd5({'v': current[entry.key]}))
      entry.key: entry.value
    else if (entry.value is Map &&
        before[entry.key] is Map &&
        current[entry.key] is Map)
      entry.key: _unchangedSettingsPatch(
        _toJsonMap(before[entry.key]),
        _toJsonMap(current[entry.key]),
        _toJsonMap(entry.value),
      ),
};

Map<String, dynamic> _overlaySettings(
  Map<String, dynamic> base,
  Map<String, dynamic> selected,
) => {
  ...base,
  for (final entry in selected.entries)
    entry.key: entry.value is Map && base[entry.key] is Map
        ? _overlaySettings(_toJsonMap(base[entry.key]), _toJsonMap(entry.value))
        : entry.value,
};

Future<void> _runDirectedSettingsSync(
  ComicSyncRemoteAdapter adapter, {
  required GlobalSettingState state,
  required GlobalSettingCubit? globalSettingCubit,
  required SettingsSyncCodec codec,
  required SyncPluginParticipation? participation,
  required SyncDirection direction,
  required bool includeAll,
  void Function()? onRuntimeReloadPending,
}) async {
  if (!includeAll) participation ??= await SyncPluginParticipation.capture();
  final initial =
      objectbox.userSettingBox.get(1)?.globalSetting ??
      globalSettingCubit?.state ??
      state;
  final includeSettings = includeAll || initial.syncSetting.syncSettings;
  final includePlugins = includeAll || initial.syncSetting.syncPlugins;
  if (!includeSettings && !includePlugins) return;
  await prepareScopedSyncArchive(adapter);
  final identity =
      adapter is ScopedSyncArchiveAdapter &&
          ArchivePreferenceTransaction.supportsIdentity(adapter.identity)
      ? adapter.identity
      : null;
  if (direction == SyncDirection.restore && identity != null) {
    await ArchivePreferenceTransaction.recover(identity);
  }
  final lifecycle = _PluginSettingsCaptureGuard();
  final local = await _buildLocalSettingsSnapshot(
    initial,
    includeAll: includeAll,
    persistMeta: false,
    participation: participation,
  );
  final remote = await readSettingsArchiveData(adapter, codec: codec);
  if (direction == SyncDirection.restore && remote == null) return;
  final result = await _mergeSettingsSnapshots(
    initial,
    local,
    remote?._snapshot ?? const _SettingsSnapshot(blocks: {}),
    direction: direction,
    participation: participation,
    includeSettings: includeSettings,
    includePlugins: includePlugins,
  );
  participation?.check();
  lifecycle.check();
  var runtimePending = false;
  if (direction == SyncDirection.restore) {
    final plan = SettingsArchiveImportPlan._(
      initial,
      result,
      includeSettings,
      includePlugins,
      participation,
      direction,
      local.blocks[_pluginsBlockName]?.data ?? const {},
      remote,
    );
    final recovery = identity == null
        ? await ArchivePreferenceTransaction.createTransient()
        : await ArchivePreferenceTransaction.create(identity);
    try {
      await plan.applyPreferences(
        (updates) async {
          participation?.check();
          lifecycle.check();
          await recovery.prepare(updates);
        },
        commit: () async {
          participation?.check();
          lifecycle.check();
          objectbox.store.runInTransaction(TxMode.write, () {
            if (objectbox.userSettingBox.get(1) != null) {
              plan.persistDatabase();
            } else if (includePlugins && result.shouldApplyPluginData) {
              _persistPluginBlockData(
                result.pluginBlockData,
                participatingSources: participation?.sources,
                mergeConfigsAt:
                    result.mergedSnapshot.blocks[_pluginsBlockName]?.updatedAt,
                configDirection: direction,
                baselinePluginData:
                    local.blocks[_pluginsBlockName]?.data ?? const {},
              );
            }
            recovery.markDatabaseCommitted();
          });
        },
      );
    } catch (_) {
      await recovery.rollback();
      rethrow;
    }
    await recovery.finishCommitted();
    runtimePending = !await plan.notifyCommitted(
      globalSettingCubit: globalSettingCubit,
    );
  } else {
    final payload = await codec.encode(
      utf8.encode(jsonEncode(_buildSettingsPayload(result.mergedSnapshot))),
    );
    await _uploadSettingsPayload(
      adapter,
      payloadBytes: payload,
      payloadMd5: ComicSyncCore.calculateMd5(payload),
      syncTime: result.syncTime,
      beforeUpload: () {
        participation?.check();
        lifecycle.check();
      },
    );
    await _updateLocalSettingsSyncTime(
      initial,
      syncTime: result.syncTime,
      globalSettingCubit: globalSettingCubit,
    );
    await _cleanupRemoteSettingsFiles(adapter);
  }
  // Hash what actually committed, including edits made while I/O was pending.
  final latest = objectbox.userSettingBox.get(1)?.globalSetting ?? initial;
  await _buildLocalSettingsSnapshot(
    latest,
    includeAll: includeAll,
    participation: participation,
  );
  if (runtimePending) onRuntimeReloadPending?.call();
}

/// Pure full-replacement capture. This does not update sync clocks/journals,
/// consult daily scope switches, or reinstall locally removed plugins.
Future<Map<String, dynamic>> captureFullCloudSettings(
  GlobalSettingState state,
) async => _buildSettingsPayload(
  await _buildLocalSettingsSnapshot(
    state,
    includeAll: true,
    persistMeta: false,
    preserveRemovedPluginConfigs: true,
  ),
);

Map<String, dynamic> _buildSettingsPayload(_SettingsSnapshot snapshot) {
  // This older-reader projection must describe the selected/retained snapshot,
  // never preferences excluded from it by this device's sync choices.
  final navigation = snapshot.blocks[_navigationBlockName];
  // Leave unmodified defaults out of the wire format for older readers.
  // A deliberate reset after customization has a real timestamp and syncs.
  final includeNavigation =
      navigation != null &&
      (navigation.updatedAt > 1 ||
          navigation.data['mainNavigationSlots'] != '');
  final globalSettingJson = <String, dynamic>{
    ...?snapshot.blocks[_appearanceBlockName]?.data,
    if (includeNavigation) ...navigation.data,
    ...?snapshot.blocks[_libraryBlockName]?.data,
    if (snapshot.blocks[_readerBlockName] != null)
      'readSetting': snapshot.blocks[_readerBlockName]!.data,
  };

  final pluginBlock = snapshot.blocks[_pluginsBlockName];
  final pluginConfigs = pluginBlock == null
      ? <Map<String, dynamic>>[]
      : _toJsonMapList(pluginBlock.data['pluginConfigs'])
            .map(
              (row) => {
                ...row,
                if (row['config'] is String)
                  'config': pluginConfigForSync(
                    row['config'] as String,
                    name: row['name']?.toString() ?? '',
                  ),
              },
            )
            .toList();
  final pluginInfos = pluginBlock == null
      ? <Map<String, dynamic>>[]
      : _toJsonMapList(pluginBlock.data['pluginInfos']);

  return {
    'version': syncDataVersion,
    'schemaVersion': _settingsSyncSchemaVersion,
    'syncTime': snapshot.syncTime,
    'globalSetting': globalSettingJson,
    'pluginConfigs': pluginConfigs,
    'pluginInfos': pluginInfos,
    'blocks': {
      for (final entry in snapshot.blocks.entries)
        if (entry.key != _navigationBlockName || includeNavigation)
          entry.key: entry.key == _pluginsBlockName
              ? {
                  ...entry.value.toJson(),
                  'data': {...entry.value.data, 'pluginConfigs': pluginConfigs},
                }
              : entry.value.toJson(),
    },
  };
}

Future<_SettingsSnapshot> _buildLocalSettingsSnapshot(
  GlobalSettingState globalSetting, {
  bool includeAll = false,
  bool persistMeta = true,
  bool preserveRemovedPluginConfigs = false,
  SyncPluginParticipation? participation,
  bool? includeSettings,
  bool? includePlugins,
}) async {
  await LocalPluginInstallationState.instance.load();
  final existingMeta = await _loadLocalSettingsBlockMeta();
  final nextMeta = Map<String, _LocalSettingsBlockMeta>.from(existingMeta);
  final blockPayloads = <String, _SettingsBlockPayload>{};
  final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
  final baseTimestamp = _normalizeTimestamp(
    globalSetting.syncSetting.settingsSyncTime,
    fallback: nowMs,
  );

  if (includeSettings ??
      (includeAll || globalSetting.syncSetting.syncSettings)) {
    final blockData = _extractSyncableSettingsBlocks(globalSetting);
    blockData[_videoBlockName] = {
      'version': 1,
      'values': (await VideoPlaybackPreferences.read()).toValues(),
    };
    final videoModifiedAt = await VideoPlaybackPreferences.modifiedAt();
    final defaults = _extractSyncableSettingsBlocks(const GlobalSettingState());
    for (final entry in blockData.entries) {
      final blockName = entry.key;
      final data = entry.value;
      final hash = _calculateStructuredMd5(data);
      final previous = existingMeta[blockName];
      final updatedAt = blockName == _videoBlockName
          ? (previous?.hash == hash
                ? previous!.updatedAt
                : videoModifiedAt > 0
                ? videoModifiedAt
                : 1)
          : previous == null
          ? _calculateStructuredMd5(defaults[blockName] ?? const {}) == hash
                ? 1
                : baseTimestamp
          : previous.hash == hash
          ? _normalizeTimestamp(previous.updatedAt, fallback: baseTimestamp)
          : nowMs;
      final payload = _SettingsBlockPayload(
        name: blockName,
        updatedAt: updatedAt,
        data: data,
      );
      blockPayloads[blockName] = payload;
      nextMeta[blockName] = _LocalSettingsBlockMeta.fromBlock(payload);
    }
  }

  if (includePlugins ?? (includeAll || globalSetting.syncSetting.syncPlugins)) {
    final pluginData = _buildPluginBlockData(
      includeRemovedConfigs: preserveRemovedPluginConfigs,
      participatingSources: participation?.sources,
    );
    final hash = _calculateStructuredMd5(pluginData);
    final previous = existingMeta[_pluginsBlockName];
    final pluginBaseTimestamp = _derivePluginBlockTimestamp(
      pluginData,
      fallback: baseTimestamp,
    );
    final updatedAt = previous == null
        ? pluginBaseTimestamp
        : previous.hash == hash
        ? _normalizeTimestamp(previous.updatedAt, fallback: pluginBaseTimestamp)
        : nowMs;
    final pluginBlock = _SettingsBlockPayload(
      name: _pluginsBlockName,
      updatedAt: updatedAt,
      data: pluginData,
      supportsPluginReinstall: true,
    );
    blockPayloads[_pluginsBlockName] = pluginBlock;
    nextMeta[_pluginsBlockName] = _LocalSettingsBlockMeta.fromBlock(
      pluginBlock,
    );
    logger.d(
      '[sync][plugins] local_snapshot '
      'count=${_toJsonMapList(pluginData['pluginInfos']).length} '
      'hash=$hash baseTs=$pluginBaseTimestamp finalTs=$updatedAt '
      'prevTs=${previous?.updatedAt ?? 0}',
    );
  }

  if (persistMeta) await _persistLocalSettingsBlockMeta(nextMeta);
  return _SettingsSnapshot(blocks: blockPayloads);
}

Future<_SettingsSnapshot> _decodeSettingsPayload(
  List<int> payloadBytes, {
  required int fallbackSyncTime,
  SettingsSyncCodec codec = const SettingsSyncCodec(),
}) async {
  final raw = await codec.decode(payloadBytes);
  final dynamic payloadRaw;
  try {
    payloadRaw = jsonDecode(utf8.decode(raw));
  } catch (_) {
    throw const FormatException('Invalid cloud settings backup');
  }
  return _snapshotFromPayload(
    _toJsonMap(payloadRaw),
    fallbackSyncTime: fallbackSyncTime,
  );
}

Future<void> _applyVideoBlock(
  _SettingsBlockPayload? block, {
  Future<void> Function(String expected)? beforeWrite,
  Future<void> Function()? commit,
}) async {
  // Missing legacy block or a future incompatible version leaves this device
  // untouched. Video settings never flow into comic reader/plugin stores.
  if (block == null || block.data['version'] != 1) {
    await commit?.call();
    return;
  }
  await VideoPlaybackPreferences.restore(
    _toJsonMap(block.data['values']),
    updatedAt: block.updatedAt,
    beforeWrite: beforeWrite,
    commit: commit,
  );
}

_SettingsSnapshot _snapshotFromPayload(
  Map<String, dynamic> payload, {
  required int fallbackSyncTime,
}) {
  _validateSettingsPayload(payload);
  final blocksJson = _toJsonMap(payload['blocks']);
  final remoteSyncTime = _extractSyncTimeFromPayload(
    payload,
    fallbackFromFileName: fallbackSyncTime,
  );
  final blocks = <String, _SettingsBlockPayload>{};

  for (final entry in blocksJson.entries) {
    final blockJson = _toJsonMap(entry.value);
    final data = _toJsonMap(blockJson['data']);
    if (entry.key == _pluginsBlockName && data.containsKey('pluginConfigs')) {
      data['pluginConfigs'] = _portablePluginConfigRows(data['pluginConfigs']);
    }
    if (data.isEmpty) {
      continue;
    }
    blocks[entry.key] = _SettingsBlockPayload(
      name: entry.key,
      updatedAt: _normalizeTimestamp(
        int.tryParse(blockJson['updatedAt']?.toString() ?? ''),
        fallback: remoteSyncTime,
      ),
      data: data,
      supportsPluginReinstall:
          entry.key == _pluginsBlockName && payload['schemaVersion'] == 'v2',
    );
  }

  if (blocks.isEmpty) {
    final globalSettingJson = _toJsonMap(payload['globalSetting']);
    if (globalSettingJson.isNotEmpty) {
      final remoteGlobal = GlobalSettingState.fromJson(globalSettingJson);
      final legacyBlocks = _extractSyncableSettingsBlocks(remoteGlobal);
      for (final entry in legacyBlocks.entries) {
        blocks[entry.key] = _SettingsBlockPayload(
          name: entry.key,
          updatedAt: remoteSyncTime,
          data: {
            for (final field in entry.value.entries)
              if (entry.key == _readerBlockName
                  ? _toJsonMap(
                      globalSettingJson['readSetting'],
                    ).containsKey(field.key)
                  : globalSettingJson.containsKey(field.key))
                field.key: field.value,
          },
        );
      }
    }
  }

  if (!blocks.containsKey(_pluginsBlockName)) {
    final pluginConfigs = _portablePluginConfigRows(payload['pluginConfigs']);
    final pluginInfos = _toJsonMapList(payload['pluginInfos']);
    if (pluginConfigs.isNotEmpty || pluginInfos.isNotEmpty) {
      blocks[_pluginsBlockName] = _SettingsBlockPayload(
        name: _pluginsBlockName,
        updatedAt: remoteSyncTime,
        data: {'pluginConfigs': pluginConfigs, 'pluginInfos': pluginInfos},
      );
    }
  }

  return _SettingsSnapshot(blocks: blocks);
}

List<Map<String, dynamic>> _portablePluginConfigRows(dynamic rows) => [
  for (final row in _toJsonMapList(rows))
    {
      ...row,
      if (row['name'] is String && row['config'] is String)
        'config': stripCopyDeviceRouteSettings(
          row['name'] as String,
          row['config'] as String,
        ),
    },
];

void _validateSettingsPayload(Map<String, dynamic> payload) {
  SyncPayloadCompatibility.version(payload, 'version', {
    'v1',
  }, legacyMissing: true);
  SyncPayloadCompatibility.version(payload, 'schemaVersion', {
    'v1',
    'v2',
  }, legacyMissing: true);
  SyncPayloadCompatibility.keys(payload, {
    'version',
    'schemaVersion',
    'syncTime',
    'globalSetting',
    'pluginConfigs',
    'pluginInfos',
    'blocks',
  });
  if ((payload['blocks'] != null && payload['blocks'] is! Map) ||
      (payload['globalSetting'] != null && payload['globalSetting'] is! Map)) {
    throw const SyncCompatibilityException();
  }
  SyncPayloadCompatibility.tree(
    payload['globalSetting'],
    _materializeJsonMap(const GlobalSettingState().toJson()),
  );
  final supported = _extractSyncableSettingsBlocks(const GlobalSettingState());
  supported[_videoBlockName] = {
    'version': 1,
    'values': VideoPlaybackPreferences.defaults,
  };
  supported[_pluginsBlockName] = {'pluginConfigs': [], 'pluginInfos': []};
  final blocks = _toJsonMap(payload['blocks']);
  SyncPayloadCompatibility.keys(blocks, supported.keys);
  for (final entry in blocks.entries) {
    if (entry.value is! Map) throw const SyncCompatibilityException();
    final block = _toJsonMap(entry.value);
    if (block['data'] is! Map) throw const SyncCompatibilityException();
    SyncPayloadCompatibility.keys(block, {'updatedAt', 'data'});
    final data = _toJsonMap(block['data']);
    SyncPayloadCompatibility.tree(data, supported[entry.key]);
    if (entry.key == _videoBlockName) {
      SyncPayloadCompatibility.version(data, 'version', {1});
    }
  }
  void records(
    Object? raw,
    Map<String, dynamic> Function(Map<String, dynamic>) normalize,
  ) {
    if (raw == null) return;
    if (raw is! List) throw const SyncCompatibilityException();
    for (final value in raw) {
      if (value is! Map<String, dynamic>) {
        throw const SyncCompatibilityException();
      }
      try {
        SyncPayloadCompatibility.keys(value, normalize(value).keys);
        if (value['config'] is String) {
          Object? config;
          try {
            config = jsonDecode(value['config'] as String);
          } on FormatException {
            /* Existing opaque legacy config stays compatible. */
          }
          if (config is Map<String, dynamic>)
            validatePluginAccountProfilesConfiguration(config);
        }
      } catch (_) {
        throw const SyncCompatibilityException();
      }
    }
  }

  final plugin = _toJsonMap(_toJsonMap(blocks[_pluginsBlockName])['data']);
  records(
    payload['pluginConfigs'],
    (row) => PluginConfig.fromJson(row).toJson(),
  );
  records(payload['pluginInfos'], (row) => PluginInfo.fromJson(row).toJson());
  records(
    plugin['pluginConfigs'],
    (row) => PluginConfig.fromJson(row).toJson(),
  );
  records(plugin['pluginInfos'], (row) => PluginInfo.fromJson(row).toJson());
}

Future<_SettingsMergeResult> _mergeSettingsSnapshots(
  GlobalSettingState localGlobal,
  _SettingsSnapshot localSnapshot,
  _SettingsSnapshot remoteSnapshot, {
  bool protectVersionedLocalFields = false,
  SyncDirection direction = SyncDirection.merge,
  SyncPluginParticipation? participation,
  bool? includeSettings,
  bool? includePlugins,
}) async {
  final mergedBlocks = <String, _SettingsBlockPayload>{};
  final localBlockMeta = await _loadLocalSettingsBlockMeta();
  final nextMeta = Map<String, _LocalSettingsBlockMeta>.from(localBlockMeta);
  var shouldApplyLocalState = false;

  if (includeSettings ?? localGlobal.syncSetting.syncSettings) {
    for (final blockName in _syncableSettingsBlockNames) {
      final localBlock = localSnapshot.blocks[blockName];
      if (localBlock == null) {
        continue;
      }
      final remoteBlock = remoteSnapshot.blocks[blockName];
      final mergedBlock = direction == SyncDirection.merge
          ? _pickPreferredBlock(localBlock, remoteBlock)!
          : _SettingsBlockPayload(
              name: blockName,
              updatedAt: max(localBlock.updatedAt, remoteBlock?.updatedAt ?? 0),
              data: direction == SyncDirection.restore
                  ? _overlaySettings(localBlock.data, remoteBlock?.data ?? {})
                  : _overlaySettings(remoteBlock?.data ?? {}, localBlock.data),
            );
      mergedBlocks[blockName] = mergedBlock;
      nextMeta[blockName] = _LocalSettingsBlockMeta.fromBlock(mergedBlock);
      if (!_sameBlock(localBlock, mergedBlock)) {
        shouldApplyLocalState = true;
      }
    }
  } else {
    for (final blockName in _syncableSettingsBlockNames) {
      final remoteBlock = remoteSnapshot.blocks[blockName];
      if (remoteBlock != null) {
        mergedBlocks[blockName] = remoteBlock;
      }
    }
  }

  Map<String, dynamic> pluginBlockData = const <String, dynamic>{};
  var shouldApplyPluginData = false;

  final localPluginBlock = localSnapshot.blocks[_pluginsBlockName];
  final remotePluginBlock = remoteSnapshot.blocks[_pluginsBlockName];

  if (includePlugins ?? localGlobal.syncSetting.syncPlugins) {
    var mergedPluginBlock = _mergePluginBlocks(
      localPluginBlock,
      remotePluginBlock,
      protectVersionedLocalFields: protectVersionedLocalFields,
      direction: direction,
    );
    if (mergedPluginBlock != null && participation != null) {
      mergedPluginBlock = _SettingsBlockPayload(
        name: _pluginsBlockName,
        updatedAt: mergedPluginBlock.updatedAt,
        data: projectPluginSettingsData(
          mergedPluginBlock.data,
          remotePluginBlock?.data ?? const {},
          participation.sources,
        ),
        supportsPluginReinstall: mergedPluginBlock.supportsPluginReinstall,
      );
    }
    final decision = mergedPluginBlock == null
        ? 'none'
        : (localPluginBlock != null &&
              mergedPluginBlock.contentMd5 == localPluginBlock.contentMd5)
        ? 'local_or_merged_local'
        : (remotePluginBlock != null &&
              mergedPluginBlock.contentMd5 == remotePluginBlock.contentMd5)
        ? 'remote_or_merged_remote'
        : 'merged_union';
    logger.d(
      '[sync][plugins] merge '
      'localCount=${_pluginBlockCount(localPluginBlock)} '
      'localTs=${localPluginBlock?.updatedAt ?? 0} '
      'localHash=${localPluginBlock?.contentMd5 ?? ''} '
      'remoteCount=${_pluginBlockCount(remotePluginBlock)} '
      'remoteTs=${remotePluginBlock?.updatedAt ?? 0} '
      'remoteHash=${remotePluginBlock?.contentMd5 ?? ''} '
      'decision=$decision',
    );
    if (mergedPluginBlock != null) {
      mergedBlocks[_pluginsBlockName] = mergedPluginBlock;
      nextMeta[_pluginsBlockName] = _LocalSettingsBlockMeta.fromBlock(
        mergedPluginBlock,
      );
      pluginBlockData = mergedPluginBlock.data;
      final applyData = participation == null
          ? mergedPluginBlock.data
          : projectPluginSettingsData(
              mergedPluginBlock.data,
              const {},
              participation.sources,
            );
      if (localPluginBlock == null ||
          localPluginBlock.contentMd5 != _calculateStructuredMd5(applyData)) {
        shouldApplyPluginData = true;
      }
    }
  } else if (remotePluginBlock != null) {
    mergedBlocks[_pluginsBlockName] = remotePluginBlock;
    logger.d(
      '[sync][plugins] merge skipped_apply '
      'reason=local_sync_disabled remoteCount=${_pluginBlockCount(remotePluginBlock)} '
      'remoteTs=${remotePluginBlock.updatedAt}',
    );
  }

  final syncTimeBlocks = <String, _SettingsBlockPayload>{
    if (includeSettings ?? localGlobal.syncSetting.syncSettings)
      for (final blockName in _syncableSettingsBlockNames)
        if (mergedBlocks.containsKey(blockName))
          blockName: mergedBlocks[blockName]!,
  };
  if ((includePlugins ?? localGlobal.syncSetting.syncPlugins) &&
      mergedBlocks.containsKey(_pluginsBlockName)) {
    syncTimeBlocks[_pluginsBlockName] = mergedBlocks[_pluginsBlockName]!;
  }

  final mergedSyncTime = _computeSnapshotSyncTime(syncTimeBlocks);
  final mergedState = _applySyncableBlocksToState(localGlobal, mergedBlocks)
      .copyWith(
        syncSetting: localGlobal.syncSetting.copyWith(
          settingsSyncTime: mergedSyncTime,
        ),
      );

  return _SettingsMergeResult(
    mergedState: mergedState,
    mergedSnapshot: _SettingsSnapshot(blocks: mergedBlocks),
    syncTime: mergedSyncTime,
    shouldApplyLocalState: shouldApplyLocalState,
    shouldApplyPluginData: shouldApplyPluginData,
    pluginBlockData: pluginBlockData,
    localBlockMeta: nextMeta,
  );
}

Map<String, Map<String, dynamic>> _extractSyncableSettingsBlocks(
  GlobalSettingState state,
) {
  final json = normalizeLegacyNavigationJson(
    _materializeJsonMap(state.toJson()),
  );
  return <String, Map<String, dynamic>>{
    _appearanceBlockName: <String, dynamic>{
      'dynamicColor': json['dynamicColor'],
      'themeMode': json['themeMode'],
      'isAMOLED': json['isAMOLED'],
      'seedColor': json['seedColor'],
      'switchStyle': json['switchStyle'],
      'locale': json['locale'],
      'localeFollowsSystem': json['localeFollowsSystem'],
      'welcomePageNum': json['welcomePageNum'],
      'eInkSetting': _toJsonMap(json['eInkSetting'])
        ..remove('detectionHandled'),
    },
    _navigationBlockName: <String, dynamic>{
      'mainNavigationSlots': json['mainNavigationSlots'],
    },
    _libraryBlockName: <String, dynamic>{
      'maskedKeywords': json['maskedKeywords'],
      'comicChoice': json['comicChoice'],
      'disableBika': json['disableBika'],
      'updateAccelerate': json['updateAccelerate'],
      'retryDownloadUntilSuccess': json['retryDownloadUntilSuccess'],
      'videoDownloadConcurrency': json['videoDownloadConcurrency'],
      'downloadWifiOnly': json['downloadWifiOnly'],
      'downloadCompletionNotice': json['downloadCompletionNotice'],
      'oldPageRollbackEnabled': json['oldPageRollbackEnabled'],
      'autoFollowOnCollect': json['autoFollowOnCollect'],
      'clickCoverToStartReading': json['clickCoverToStartReading'],
      'bookshelfSetting': json['bookshelfSetting'],
      'backPressExitEnabled': json['backPressExitEnabled'],
      'cloudFavoritePreferred': json['cloudFavoritePreferred'],
      'leftHandModeEnabled': json['leftHandModeEnabled'],
      'chineseConvertMode': json['chineseConvertMode'],
      'searchHistory': json['searchHistory'],
    },
    _readerBlockName: _toJsonMap(json['readSetting']),
  };
}

Map<String, dynamic> _buildPluginBlockData({
  bool includeRemovedConfigs = false,
  Set<String>? participatingSources,
}) {
  final deletedUuids = objectbox.pluginInfoBox
      .getAll()
      .where((item) => item.isDeleted)
      .map((item) => item.uuid.trim())
      .where((uuid) => uuid.isNotEmpty)
      .toSet();
  final blockedConfigNames = <String>{
    for (final uuid in deletedUuids)
      ..._buildPluginConfigNameCandidatesForSync(uuid),
  };

  final pluginConfigs = objectbox.pluginConfigBox
      .getAll()
      .map((item) {
        final name = item.name.trim();
        if (name.isEmpty ||
            (!includeRemovedConfigs && blockedConfigNames.contains(name))) {
          return <String, dynamic>{};
        }
        final json = item.toJson();
        json.remove('id');
        json['name'] = name;
        json['config'] = pluginConfigForSync(item.config, name: name);
        return json;
      })
      .where((item) => item.isNotEmpty)
      .toList();
  pluginConfigs.sort((a, b) {
    final aName = a['name']?.toString() ?? '';
    final bName = b['name']?.toString() ?? '';
    return aName.compareTo(bName);
  });

  final pluginInfos = objectbox.pluginInfoBox
      .getAll()
      .where((item) => item.uuid.trim().isNotEmpty)
      .map((item) {
        final json = item.toJson();
        json.remove('id');
        // ObjectBox date properties are read as local DateTimes. Keep an
        // explicit zone on the portable wire; otherwise another timezone would
        // reinterpret an installation/deletion as a different revision.
        json['insertedAt'] = item.insertedAt.toUtc().toIso8601String();
        json['updatedAt'] = item.updatedAt.toUtc().toIso8601String();
        json['deletedAt'] = item.deletedAt?.toUtc().toIso8601String();
        return json;
      })
      .toList();
  pluginInfos.sort((a, b) {
    final aKey = '${a['uuid'] ?? ''}:${a['version'] ?? ''}';
    final bKey = '${b['uuid'] ?? ''}:${b['version'] ?? ''}';
    return aKey.compareTo(bKey);
  });

  final data = {'pluginConfigs': pluginConfigs, 'pluginInfos': pluginInfos};
  return participatingSources == null
      ? data
      : projectPluginSettingsData(data, const {}, participatingSources);
}

GlobalSettingState _applySyncableBlocksToState(
  GlobalSettingState localState,
  Map<String, _SettingsBlockPayload> blocks,
) {
  final json = _materializeJsonMap(localState.toJson());

  final appearance = blocks[_appearanceBlockName]?.data;
  if (appearance != null) {
    json.addAll(_overlaySettings(json, appearance));
  }

  final navigation = blocks[_navigationBlockName]?.data;
  if (navigation != null) {
    json.addAll(navigation);
  }

  final library = blocks[_libraryBlockName]?.data;
  if (library != null) {
    json.addAll(library);
  }

  final reader = blocks[_readerBlockName]?.data;
  if (reader != null) {
    json['readSetting'] = _overlaySettings(
      _toJsonMap(json['readSetting']),
      reader,
    );
  }

  // 同步设置时，以下本地/安全相关配置保持本地值不变：
  // - 自定义导出路径、开屏密码/PIN、缓存管理配置：已从上传负载中移除；
  // - 同步配置本身、调试日志开关/地址：仍可能出现在旧版或未来的云端块中，
  //   这里显式跳过覆盖，确保本地值不被同步下来的内容修改。
  final merged = GlobalSettingState.fromJson(json);
  return merged.copyWith(
    syncSetting: localState.syncSetting,
    customExportPath: localState.customExportPath,
    appLockSetting: localState.appLockSetting,
    cacheSetting: localState.cacheSetting,
    enableMemoryDebug: localState.enableMemoryDebug,
    blockRustHttpRequests: localState.blockRustHttpRequests,
    logAddress: localState.logAddress,
  );
}

Future<void> _applyMergedGlobalState(
  GlobalSettingState value, {
  required GlobalSettingCubit? globalSettingCubit,
  GlobalSettingState? initial,
}) async {
  if (initial != null) {
    final latest =
        objectbox.userSettingBox.get(1)?.globalSetting ??
        globalSettingCubit?.state ??
        initial;
    final before = _materializeJsonMap(initial.toJson());
    final now = _materializeJsonMap(latest.toJson());
    final selected = _materializeJsonMap(value.toJson());
    value =
        GlobalSettingState.fromJson(
          _overlaySettings(now, _unchangedSettingsPatch(before, now, selected)),
        ).copyWith(
          syncSetting: latest.syncSetting.copyWith(
            settingsSyncTime: max(
              latest.syncSetting.settingsSyncTime,
              value.syncSetting.settingsSyncTime,
            ),
          ),
        );
  }
  if (globalSettingCubit != null) {
    globalSettingCubit.applySyncedState(value);
    return;
  }

  final user = objectbox.userSettingBox.get(1);
  if (user != null) {
    user.globalSetting = value;
    objectbox.userSettingBox.put(user);
  }
}

Future<void> _applyPluginBlockData(
  Map<String, dynamic> pluginBlockData, {
  SyncPluginParticipation? participation,
  _PluginSettingsCaptureGuard? sessionGuard,
}) async {
  final previousSnapshot = PluginRegistryService.I.snapshot;
  participation?.check();
  _persistPluginBlockData(
    pluginBlockData,
    participatingSources: participation?.sources,
    sessionGuard: sessionGuard,
  );
  await PluginRegistryService.I.reconcileAfterExternalSync(
    previousSnapshot: previousSnapshot,
  );
}

void _persistPluginBlockData(
  Map<String, dynamic> pluginBlockData, {
  int? mergeConfigsAt,
  Set<String>? participatingSources,
  SyncDirection configDirection = SyncDirection.merge,
  Map<String, dynamic>? baselinePluginData,
  _PluginSettingsCaptureGuard? sessionGuard,
}) {
  sessionGuard?.check();
  final originalConfigs = objectbox.pluginConfigBox.getAll();
  if (participatingSources != null) {
    pluginBlockData = projectPluginSettingsData(
      pluginBlockData,
      const {},
      participatingSources,
    );
  }
  final previousSnapshot = PluginRegistryService.I.snapshot;
  final pluginConfigJsonList = _toJsonMapList(pluginBlockData['pluginConfigs']);
  final pluginInfoJsonList = _toJsonMapList(pluginBlockData['pluginInfos']);
  logger.d(
    '[sync][plugins] apply_remote '
    'incomingInfos=${pluginInfoJsonList.length} incomingConfigs=${pluginConfigJsonList.length} '
    'previousRegistry=${previousSnapshot.length}',
  );

  final localPluginInfos = objectbox.pluginInfoBox.getAll();
  final localPluginByUuid = <String, PluginInfo>{
    for (final item in localPluginInfos)
      if (item.uuid.trim().isNotEmpty) item.uuid.trim(): item,
  };
  final previouslyDeletedUuids = localPluginByUuid.values
      .where((item) => item.isDeleted)
      .map((item) => item.uuid.trim())
      .where((uuid) => uuid.isNotEmpty)
      .toSet();

  final remotePluginInfos = <PluginInfo>[];
  for (final json in pluginInfoJsonList) {
    try {
      final parsed = PluginInfo.fromJson(json);
      final uuid = parsed.uuid.trim();
      if (uuid.isEmpty) {
        continue;
      }
      remotePluginInfos.add(
        PluginInfo(
          uuid: uuid,
          version: parsed.version,
          originScript: parsed.isDeleted ? '' : parsed.originScript,
          insertedAt: parsed.insertedAt.toUtc(),
          updatedAt: parsed.updatedAt.toUtc(),
          isEnabled: !parsed.isDeleted && parsed.isEnabled,
          isDeleted: parsed.isDeleted,
          deletedAt: parsed.deletedAt?.toUtc(),
          lastLoadSuccess: !parsed.isDeleted && parsed.lastLoadSuccess,
          lastLoadError: parsed.lastLoadError,
          sortOrder: parsed.sortOrder,
          debug: parsed.debug,
          debugUrl: parsed.debugUrl,
          getInfoJson: parsed.getInfoJson,
        ),
      );
    } catch (e) {
      logger.w('[sync][plugins] 忽略无效插件信息: $e');
    }
  }

  final baselineInfos = {
    for (final row in _toJsonMapList(baselinePluginData?['pluginInfos']))
      '${row['uuid'] ?? ''}'.trim(): row,
  };
  Map<String, dynamic> directedInfoPreferences(
    PluginInfo existing,
    PluginInfo incoming,
  ) {
    final before =
        baselineInfos[existing.uuid.trim()] ?? const <String, dynamic>{};
    final current = existing.toJson();
    final selected = incoming.toJson();
    return {
      for (final key in ['isEnabled', 'sortOrder'])
        key:
            baselinePluginData != null &&
                _calculateStructuredMd5({'v': before[key]}) !=
                    _calculateStructuredMd5({'v': current[key]})
            ? current[key]
            : selected[key],
    };
  }

  final infoUpserts = <PluginInfo>[];
  var skippedDeletedLocal = 0;
  for (final incoming in remotePluginInfos) {
    final uuid = incoming.uuid.trim();
    final existing = localPluginByUuid[uuid];
    if (participatingSources != null && incoming.isDeleted) continue;
    if (existing != null &&
        !_shouldApplyIncomingPluginInfo(existing, incoming)) {
      if (existing.isDeleted) skippedDeletedLocal++;
      if (configDirection == SyncDirection.restore &&
          !existing.isDeleted &&
          !incoming.isDeleted) {
        // Restore preferences without downgrading the installed executable,
        // changing identity, or treating an older lifecycle record as reinstall.
        infoUpserts.add(
          PluginInfo.fromJson({
            ...existing.toJson(),
            ...directedInfoPreferences(existing, incoming),
          }),
        );
      }
      continue;
    }
    if (PluginHostCompatibility.reportSkippedPluginInfo(incoming.toJson()))
      continue;
    final upsert = PluginInfo(
      id: existing?.id ?? 0,
      uuid: uuid,
      version: incoming.version,
      originScript: incoming.isDeleted ? '' : incoming.originScript,
      insertedAt:
          existing == null || incoming.insertedAt.isAfter(existing.insertedAt)
          ? incoming.insertedAt
          : existing.insertedAt,
      updatedAt: incoming.updatedAt,
      isEnabled: !incoming.isDeleted && incoming.isEnabled,
      isDeleted: incoming.isDeleted,
      deletedAt: incoming.isDeleted
          ? incoming.deletedAt ?? incoming.updatedAt
          : null,
      lastLoadSuccess: !incoming.isDeleted && incoming.lastLoadSuccess,
      lastLoadError: incoming.lastLoadError,
      sortOrder: incoming.sortOrder ?? existing?.sortOrder,
      debug: incoming.debug,
      debugUrl: incoming.debugUrl,
      getInfoJson: incoming.getInfoJson.isNotEmpty
          ? incoming.getInfoJson
          : (existing?.getInfoJson ?? ''),
    );
    infoUpserts.add(upsert);
    localPluginByUuid[uuid] = upsert;
  }
  if (infoUpserts.isNotEmpty) {
    objectbox.pluginInfoBox.putMany(infoUpserts);
  }

  final blockedConfigNames = <String>{
    for (final info in localPluginByUuid.values)
      if (info.isDeleted &&
          (participatingSources == null ||
              participatingSources.contains(info.uuid)))
        ..._buildPluginConfigNameCandidatesForSync(info.uuid),
  };
  // A certified reinstall may import fresh configuration, but stale values
  // written after a prior deletion must not silently restore removed secrets.
  final staleConfigNames = <String>{
    ...blockedConfigNames,
    for (final uuid in previouslyDeletedUuids)
      if (participatingSources == null || participatingSources.contains(uuid))
        ..._buildPluginConfigNameCandidatesForSync(uuid),
  };
  final blockedConfigIds = <int>[];
  final localConfigByName = <String, PluginConfig>{
    for (final item in originalConfigs)
      if (item.name.trim().isNotEmpty &&
          !staleConfigNames.contains(item.name.trim()))
        item.name.trim(): PluginConfig(
          id: item.id,
          name: item.name.trim(),
          config: item.config,
        ),
  };
  for (final item in originalConfigs) {
    final name = item.name.trim();
    if (name.isNotEmpty && staleConfigNames.contains(name)) {
      blockedConfigIds.add(item.id);
    }
  }
  if (blockedConfigIds.isNotEmpty) {
    objectbox.pluginConfigBox.removeMany(blockedConfigIds);
  }
  final baselineConfigs = {
    for (final row in _toJsonMapList(baselinePluginData?['pluginConfigs']))
      '${row['name'] ?? ''}'.trim(): '${row['config'] ?? '{}'}',
  };
  var skippedBlockedConfig = 0;
  final excludedConfigNames = <String>{
    if (participatingSources == null)
      for (final source
          in LocalPluginInstallationState.instance.excludedSources(
            PluginDataScope.accountSettings,
          ))
        ...pluginConfigNamesForSource(source),
  };
  for (final json in pluginConfigJsonList) {
    try {
      final parsed = PluginConfig.fromJson(json);
      final name = parsed.name.trim();
      if (name.isEmpty) {
        continue;
      }
      if (blockedConfigNames.contains(name) ||
          excludedConfigNames.contains(name)) {
        skippedBlockedConfig++;
        continue;
      }
      final existing = localConfigByName[name];
      final incomingConfig = pluginConfigForSync(parsed.config, name: name);
      localConfigByName[name] = PluginConfig(
        id: existing?.id ?? 0,
        name: name,
        config: existing == null
            ? incomingConfig
            : preserveLocalPluginPurgeProvenance(
                existing.config,
                mergeConfigsAt == null
                    ? incomingConfig
                    : mergePluginAccountConfigData(
                        existing.config,
                        incomingConfig,
                        localUpdatedAt:
                            objectbox.userSettingBox
                                .get(1)
                                ?.globalSetting
                                .syncSetting
                                .settingsSyncTime ??
                            0,
                        remoteUpdatedAt: mergeConfigsAt,
                        preferRemoteOnConflict: true,
                        direction: configDirection,
                      ),
              ),
      );
      if (existing != null && baselinePluginData != null) {
        localConfigByName[name]!.config = preserveInterveningPluginConfigEdits(
          baselineConfigs[name] ?? '{}',
          existing.config,
          localConfigByName[name]!.config,
        );
      }
      localConfigByName[name]!.config = preserveCopyDeviceRouteSettings(
        name,
        existing?.config,
        localConfigByName[name]!.config,
      );
    } catch (e) {
      logger.w('[sync][plugins] 忽略无效插件配置: $e');
    }
  }
  if (localConfigByName.isNotEmpty) {
    objectbox.pluginConfigBox.putMany(localConfigByName.values.toList());
  }
  String accountDigest(String? encoded) {
    if (encoded == null) return accountProfileDigest(const {});
    try {
      final map = jsonDecode(encoded);
      return accountProfileDigest(
        map is Map
            ? {
                for (final entry in map.entries)
                  if (entry.key is String &&
                      isActivePluginAccountField(entry.key as String))
                    entry.key: entry.value,
              }
            : const {},
      );
    } catch (_) {
      return accountProfileDigest(const {});
    }
  }

  final beforeConfigs = {
    for (final row in originalConfigs) row.name.trim(): row.config,
  };
  final previousCopyConfig = beforeConfigs[copyPluginConfigSource];
  if (previousCopyConfig != localConfigByName[copyPluginConfigSource]?.config) {
    // This path may run inside an archive's enclosing write transaction.
    scheduleMicrotask(
      () => notifyCopyEndpointAfterExternalRestore(previousCopyConfig),
    );
  }
  for (final source in {
    ...localPluginByUuid.keys,
    ...remotePluginInfos.map((p) => p.uuid),
  }) {
    final names = pluginConfigNamesForSource(source);
    if (names.any(
      (name) =>
          accountDigest(beforeConfigs[name]) !=
          accountDigest(localConfigByName[name]?.config),
    )) {
      if (sessionGuard != null)
        sessionGuard.advanceRestoredAccount(source);
      else
        pluginSessionWriteFence.advance(source);
    }
  }
  logger.d(
    '[sync][plugins] apply_remote_db '
    'upsertInfos=${infoUpserts.length} totalLocalInfos=${localPluginByUuid.length} '
    'savedConfigs=${localConfigByName.length} '
    'skippedDeletedLocal=$skippedDeletedLocal skippedBlockedConfig=$skippedBlockedConfig',
  );
}

Future<Map<String, _LocalSettingsBlockMeta>>
_loadLocalSettingsBlockMeta() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_settingsBlockMetaPrefsKey);
  if (raw == null || raw.trim().isEmpty) {
    return <String, _LocalSettingsBlockMeta>{};
  }

  try {
    final json = _toJsonMap(jsonDecode(raw));
    return json.map(
      (key, value) =>
          MapEntry(key, _LocalSettingsBlockMeta.fromJson(_toJsonMap(value))),
    );
  } catch (e) {
    logger.w('[sync][settings] 本地块元数据读取失败，已忽略: $e');
    return <String, _LocalSettingsBlockMeta>{};
  }
}

Future<void> _persistLocalSettingsBlockMeta(
  Map<String, _LocalSettingsBlockMeta> nextMeta,
) async {
  final prefs = await SharedPreferences.getInstance();
  final payload = {
    for (final entry in (await _loadLocalSettingsBlockMeta()).entries)
      entry.key: entry.value.toJson(),
    for (final entry in nextMeta.entries) entry.key: entry.value.toJson(),
  };
  await prefs.setString(_settingsBlockMetaPrefsKey, jsonEncode(payload));
}

Future<void> _updateLocalSettingsSyncTime(
  GlobalSettingState localGlobal, {
  required int syncTime,
  required GlobalSettingCubit? globalSettingCubit,
}) async {
  final current =
      objectbox.userSettingBox.get(1)?.globalSetting ??
      globalSettingCubit?.state ??
      localGlobal;
  final merged = current.copyWith(
    syncSetting: current.syncSetting.copyWith(
      settingsSyncTime: max(current.syncSetting.settingsSyncTime, syncTime),
    ),
  );
  if (globalSettingCubit != null) {
    globalSettingCubit.applySyncedState(merged);
  } else {
    final user = objectbox.userSettingBox.get(1);
    if (user != null) {
      user.globalSetting = merged;
      objectbox.userSettingBox.put(user);
    }
  }
}

Future<void> _uploadSettingsPayload(
  ComicSyncRemoteAdapter adapter, {
  required List<int> payloadBytes,
  required String payloadMd5,
  required int syncTime,
  void Function()? beforeUpload,
}) async {
  final occupied = {
    for (final path in await adapter.listRemoteDataFiles())
      if (ComicSyncCore.isSyncRootPath(path))
        if (ComicSyncCore.extractSettingsTimestampFromRemotePath(path)
            case final int stamp)
          stamp,
  };
  var stamp = syncTime;
  if (occupied.contains(stamp)) {
    // The settings clock can be unchanged even when payload bytes change.
    // Leave every known file intact until the digest commits the new snapshot.
    stamp = DateTime.now().millisecondsSinceEpoch;
    while (occupied.contains(stamp)) {
      stamp++;
    }
  }
  final fileName = ComicSyncCore.buildSettingsDataFileName(stamp);
  beforeUpload?.call();
  await adapter.uploadRemoteFile(fileName, payloadBytes);
  beforeUpload?.call();
  await adapter.uploadRemoteFile(
    _remoteSettingsMd5Path,
    utf8.encode(payloadMd5),
    contentType: 'text/plain; charset=utf-8',
  );
  logger.d('[sync][settings] uploaded file=$fileName md5=$payloadMd5');
}

/// No retained deletion plan: reject this one stale capture if installation
/// changed while encoding/uploading, so the next Sync reads the actual DB.
class _PluginSettingsCaptureGuard {
  _PluginSettingsCaptureGuard()
    : _sessions = {
        for (final plugin in objectbox.pluginInfoBox.getAll())
          plugin.uuid: pluginSessionWriteFence.generation(plugin.uuid),
      },
      _epochs = {
        for (final source
            in LocalPluginInstallationState.instance.excludedSources(
              PluginDataScope.accountSettings,
            ))
          source: LocalPluginInstallationState.instance.installationEpoch(
            source,
          ),
      };
  final Map<String, int> _epochs, _sessions;
  void advanceRestoredAccount(String source) {
    final before = _sessions[source];
    if (before != null &&
            pluginSessionWriteFence.generation(source) != before ||
        pluginSessionWriteFence.isChanging(source))
      throw const PluginSessionChanged();
    _sessions[source] = pluginSessionWriteFence.advance(source);
  }

  void check() {
    for (final entry in _sessions.entries) {
      if (pluginSessionWriteFence.generation(entry.key) != entry.value ||
          pluginSessionWriteFence.isChanging(entry.key))
        throw const PluginSessionChanged();
    }
    final state = LocalPluginInstallationState.instance;
    for (final entry in _epochs.entries) {
      if (state.installationEpoch(entry.key) != entry.value ||
          state.isInstalling(entry.key)) {
        throw const PluginLifecycleChanged();
      }
    }
  }
}

Future<void> _cleanupRemoteSettingsFiles(ComicSyncRemoteAdapter adapter) async {
  final allRemote = await adapter.listRemoteDataFiles();

  final legacyFiles = allRemote
      .where(ComicSyncCore.isLegacyRemotePath)
      .toList();
  if (legacyFiles.isNotEmpty) {
    await adapter.deleteRemoteFiles(legacyFiles);
  }

  final syncRootFiles = allRemote.where(ComicSyncCore.isSyncRootPath).toList();
  final settingsFiles = syncRootFiles.where((path) {
    final fileName = ComicSyncCore.extractFileName(path);
    return ComicSyncCore.isSettingsDataFileName(fileName);
  }).toList();
  final sorted = ComicSyncCore.sortSettingsFilesByTimestampDesc(settingsFiles);

  final keep = <String>{
    '${ComicSyncCore.syncRemoteRootName}/${ComicSyncCore.settingsMd5FileName}',
  };
  if (sorted.length > 3) {
    final active = await _selectLatestRemoteSettingsData(
      adapter,
      syncRootFiles,
      await _downloadRemoteText(
        adapter,
        _remoteSettingsMd5Path,
        returnEmptyIfMissing: true,
      ),
    );
    // An older file may still be active when the committed target is unreadable.
    if (active == null) return;
    keep.add(ComicSyncCore.normalizeRemotePathNoLeadingSlash(active.path));
  }
  for (var i = 0; i < sorted.length; i++) {
    if (i < 3) {
      keep.add(ComicSyncCore.normalizeRemotePathNoLeadingSlash(sorted[i]));
    }
  }

  final stale = settingsFiles.where((path) {
    final normalized = ComicSyncCore.normalizeRemotePathNoLeadingSlash(path);
    return !keep.contains(normalized);
  }).toList();
  if (stale.isNotEmpty) {
    await adapter.deleteRemoteFiles(stale);
  }
}

Future<_RemoteSettingsData?> _selectLatestRemoteSettingsData(
  ComicSyncRemoteAdapter adapter,
  List<String> remotePaths,
  String remoteMd5,
) async {
  final sorted = ComicSyncCore.sortSettingsFilesByTimestampDesc(remotePaths);
  if (sorted.isEmpty || remoteMd5.isEmpty) {
    return null;
  }

  for (final path in sorted) {
    try {
      final bytes = await adapter.downloadRemoteFile(path);
      final md5 = ComicSyncCore.calculateMd5(bytes);
      if (md5 == remoteMd5) {
        return _RemoteSettingsData(
          path: path,
          bytes: bytes,
          timestamp:
              ComicSyncCore.extractSettingsTimestampFromRemotePath(path) ?? 0,
        );
      }
    } catch (e) {
      logger.w('远端设置文件读取失败，尝试更旧版本: $path, error: $e');
    }
  }

  return null;
}

int _extractSyncTimeFromPayload(
  Map<String, dynamic> payload, {
  required int fallbackFromFileName,
}) {
  final syncTime = int.tryParse(payload['syncTime']?.toString() ?? '') ?? 0;
  if (syncTime > 0) {
    return syncTime;
  }
  return fallbackFromFileName;
}

Future<String> _downloadRemoteText(
  ComicSyncRemoteAdapter adapter,
  String remotePath, {
  bool returnEmptyIfMissing = false,
}) async {
  final bytes = await _downloadRemoteBytes(
    adapter,
    remotePath,
    returnEmptyIfMissing: returnEmptyIfMissing,
  );
  if (bytes.isEmpty) {
    return '';
  }
  return utf8.decode(bytes).trim();
}

Future<List<int>> _downloadRemoteBytes(
  ComicSyncRemoteAdapter adapter,
  String remotePath, {
  bool returnEmptyIfMissing = false,
}) async {
  try {
    return await adapter.downloadRemoteFile(remotePath);
  } catch (e) {
    if (returnEmptyIfMissing && _isNotFoundError(e)) {
      return const [];
    }
    rethrow;
  }
}

bool _isNotFoundError(Object error) {
  if (error is SyncRemoteFileNotFound) return true;
  final message = error.toString();
  final lower = message.toLowerCase();
  return message.contains('404') ||
      message.contains('NoSuchKey') ||
      message.contains('NoSuchObject') ||
      message.contains('NotFound') ||
      lower.contains('does not exist') ||
      lower.contains('specified key') ||
      lower.contains('no such key');
}

Map<String, dynamic> _toJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _toJsonMapList(Object? value) {
  final raw = (value as List? ?? const []);
  return raw
      .map((item) {
        if (item is Map<String, dynamic>) {
          return Map<String, dynamic>.from(item);
        }
        if (item is Map) {
          return item.map((key, val) => MapEntry(key.toString(), val));
        }
        return <String, dynamic>{};
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, dynamic> _materializeJsonMap(Map<String, dynamic> value) {
  return _toJsonMap(jsonDecode(jsonEncode(value)));
}

String _calculateStructuredMd5(Map<String, dynamic> data) {
  return ComicSyncCore.calculateMd5(utf8.encode(jsonEncode(data)));
}

int _derivePluginBlockTimestamp(
  Map<String, dynamic> pluginData, {
  required int fallback,
}) {
  final pluginInfos = _toJsonMapList(pluginData['pluginInfos']);
  var latest = 0;

  for (final item in pluginInfos) {
    final candidate = _pluginInfoUpdatedAtMs(item);
    if (candidate > latest) {
      latest = candidate;
    }
  }

  return latest > 0 ? latest : fallback;
}

int _pluginBlockCount(_SettingsBlockPayload? block) {
  if (block == null) {
    return 0;
  }
  return _toJsonMapList(block.data['pluginInfos']).length;
}

_SettingsBlockPayload? _mergePluginBlocks(
  _SettingsBlockPayload? localBlock,
  _SettingsBlockPayload? remoteBlock, {
  bool protectVersionedLocalFields = false,
  SyncDirection direction = SyncDirection.merge,
}) {
  if (localBlock == null) {
    return remoteBlock;
  }
  if (remoteBlock == null) {
    return localBlock;
  }
  if (_sameBlock(localBlock, remoteBlock)) {
    return localBlock;
  }

  final preferRemoteOnConflict = remoteBlock.updatedAt > localBlock.updatedAt;
  final mergedData = _mergePluginBlockData(
    localBlock.data,
    remoteBlock.data,
    preferRemoteOnConflict: preferRemoteOnConflict,
    localUpdatedAt: localBlock.updatedAt,
    remoteUpdatedAt: remoteBlock.updatedAt,
    protectVersionedLocalFields: protectVersionedLocalFields,
    allowRemotePluginReinstall: remoteBlock.supportsPluginReinstall,
    direction: direction,
  );
  final mergedMd5 = _calculateStructuredMd5(mergedData);
  if (mergedMd5 == localBlock.contentMd5) {
    return localBlock;
  }
  if (mergedMd5 == remoteBlock.contentMd5) {
    return remoteBlock;
  }

  return _SettingsBlockPayload(
    name: _pluginsBlockName,
    updatedAt: localBlock.updatedAt >= remoteBlock.updatedAt
        ? localBlock.updatedAt
        : remoteBlock.updatedAt,
    data: mergedData,
    supportsPluginReinstall: true,
  );
}

Map<String, dynamic> _mergePluginBlockData(
  Map<String, dynamic> localData,
  Map<String, dynamic> remoteData, {
  required bool preferRemoteOnConflict,
  required int localUpdatedAt,
  required int remoteUpdatedAt,
  bool protectVersionedLocalFields = false,
  bool allowRemotePluginReinstall = false,
  SyncDirection direction = SyncDirection.merge,
}) {
  final localInfos = _toJsonMapList(localData['pluginInfos'])
      .where((item) {
        final uuid = item['uuid']?.toString().trim() ?? '';
        return uuid.isNotEmpty;
      })
      .map((item) {
        final next = Map<String, dynamic>.from(item);
        next['uuid'] = item['uuid']?.toString().trim() ?? '';
        return next;
      })
      .toList();
  final remoteInfos = _toJsonMapList(remoteData['pluginInfos'])
      .where((item) {
        final uuid = item['uuid']?.toString().trim() ?? '';
        return uuid.isNotEmpty;
      })
      .map((item) {
        final next = Map<String, dynamic>.from(item);
        next['uuid'] = item['uuid']?.toString().trim() ?? '';
        return next;
      })
      .toList();

  final mergedInfoByUuid = <String, Map<String, dynamic>>{
    for (final item in localInfos) item['uuid'] as String: item,
  };
  for (final remote in remoteInfos) {
    final uuid = remote['uuid'] as String;
    final local = mergedInfoByUuid[uuid];
    if (local == null) {
      mergedInfoByUuid[uuid] = remote;
      continue;
    }
    if (_preferIncomingPluginInfo(
      local,
      remote,
      allowReinstall: allowRemotePluginReinstall,
      preferIncomingOnTie: preferRemoteOnConflict,
    )) {
      mergedInfoByUuid[uuid] = remote;
    }
    if (direction == SyncDirection.upload ||
        direction == SyncDirection.restore) {
      final selected = direction == SyncDirection.upload ? local : remote;
      mergedInfoByUuid[uuid] = {
        ...mergedInfoByUuid[uuid]!,
        for (final key in ['isEnabled', 'sortOrder'])
          if (selected.containsKey(key)) key: selected[key],
      };
    }
  }

  final deletedConfigNames = <String>{
    for (final entry in mergedInfoByUuid.entries)
      if (entry.value['isDeleted'] == true)
        ..._buildPluginConfigNameCandidatesForSync(entry.key),
  };

  final localConfigs = _toJsonMapList(localData['pluginConfigs']);
  final remoteConfigs = _toJsonMapList(remoteData['pluginConfigs']);
  final mergedConfigByName = <String, Map<String, dynamic>>{};

  for (final item in localConfigs) {
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty || deletedConfigNames.contains(name)) {
      continue;
    }
    final next = Map<String, dynamic>.from(item);
    next['name'] = name;
    mergedConfigByName[name] = next;
  }
  for (final item in remoteConfigs) {
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty || deletedConfigNames.contains(name)) {
      continue;
    }
    final next = Map<String, dynamic>.from(item);
    next['name'] = name;
    final local = mergedConfigByName[name];
    if (local == null) {
      mergedConfigByName[name] = next;
    } else {
      mergedConfigByName[name] = {
        ...(preferRemoteOnConflict ? next : local),
        'config': mergePluginAccountConfigData(
          '${local['config'] ?? '{}'}',
          '${next['config'] ?? '{}'}',
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
          preferRemoteOnConflict: preferRemoteOnConflict,
          protectVersionedLocalFields: protectVersionedLocalFields,
          direction: direction,
        ),
      };
    }
  }

  final mergedInfos = mergedInfoByUuid.values.toList()
    ..sort((a, b) {
      final aKey = '${a['uuid'] ?? ''}:${a['version'] ?? ''}';
      final bKey = '${b['uuid'] ?? ''}:${b['version'] ?? ''}';
      return aKey.compareTo(bKey);
    });
  final mergedConfigs = mergedConfigByName.values.toList()
    ..sort((a, b) {
      final aName = a['name']?.toString() ?? '';
      final bName = b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });

  return <String, dynamic>{
    'pluginConfigs': mergedConfigs,
    'pluginInfos': mergedInfos,
  };
}

int _pluginInfoUpdatedAtMs(Map<String, dynamic> item) {
  final updatedAt = DateTime.tryParse(item['updatedAt']?.toString() ?? '');
  final insertedAt = DateTime.tryParse(item['insertedAt']?.toString() ?? '');
  final updatedAtMs = updatedAt?.toUtc().millisecondsSinceEpoch ?? 0;
  final insertedAtMs = insertedAt?.toUtc().millisecondsSinceEpoch ?? 0;
  final deletedAtMs = item['isDeleted'] == true
      ? DateTime.tryParse(
              item['deletedAt']?.toString() ?? '',
            )?.toUtc().millisecondsSinceEpoch ??
            0
      : 0;
  return [
    updatedAtMs,
    insertedAtMs,
    deletedAtMs,
  ].fold<int>(0, (current, next) => next > current ? next : current);
}

/// Block clocks cannot prove that a plugin was reinstalled. Require a current
/// structured archive and an explicit live row written after the deletion.
bool _preferIncomingPluginInfo(
  Map<String, dynamic> local,
  Map<String, dynamic> incoming, {
  required bool allowReinstall,
  bool preferIncomingOnTie = false,
}) {
  final localClock = _pluginInfoUpdatedAtMs(local);
  final incomingClock = _pluginInfoUpdatedAtMs(incoming);
  final deleted = local['isDeleted'] == true;
  final incomingDeleted = incoming['isDeleted'] == true;
  if (deleted && !incomingDeleted) {
    final explicitWrite =
        DateTime.tryParse(
          incoming['updatedAt']?.toString() ?? '',
        )?.toUtc().millisecondsSinceEpoch ??
        0;
    final installedAt =
        DateTime.tryParse(
          incoming['insertedAt']?.toString() ?? '',
        )?.toUtc().millisecondsSinceEpoch ??
        0;
    return allowReinstall &&
        incoming['isDeleted'] == false &&
        incoming['deletedAt'] == null &&
        (incoming['originScript']?.toString().trim().isNotEmpty ?? false) &&
        installedAt > localClock &&
        incomingClock > localClock &&
        explicitWrite > 0;
  }
  if (incomingClock != localClock) return incomingClock > localClock;
  if (deleted != incomingDeleted) return incomingDeleted;
  return preferIncomingOnTie;
}

bool _shouldApplyIncomingPluginInfo(PluginInfo existing, PluginInfo incoming) {
  final remoteUpdatedAt = _pluginInfoUpdatedAtMs(incoming.toJson());
  final localUpdatedAt = _pluginInfoUpdatedAtMs(existing.toJson());
  if (existing.isDeleted && !incoming.isDeleted) {
    return _preferIncomingPluginInfo(
      existing.toJson(),
      incoming.toJson(),
      allowReinstall: true,
    );
  }
  if (remoteUpdatedAt > localUpdatedAt) {
    return true;
  }
  if (remoteUpdatedAt < localUpdatedAt) {
    return false;
  }
  if (existing.isDeleted != incoming.isDeleted) return incoming.isDeleted;
  return existing.version != incoming.version ||
      existing.originScript != incoming.originScript ||
      existing.isEnabled != incoming.isEnabled ||
      existing.debug != incoming.debug ||
      (existing.debugUrl ?? '') != (incoming.debugUrl ?? '') ||
      existing.lastLoadSuccess != incoming.lastLoadSuccess ||
      (existing.lastLoadError ?? '') != (incoming.lastLoadError ?? '') ||
      existing.sortOrder != incoming.sortOrder;
}

Set<String> _buildPluginConfigNameCandidatesForSync(String uuid) =>
    pluginConfigNamesForSource(uuid);

_SettingsBlockPayload? _pickPreferredBlock(
  _SettingsBlockPayload? localBlock,
  _SettingsBlockPayload? remoteBlock,
) {
  if (localBlock == null) {
    return remoteBlock;
  }
  if (remoteBlock == null) {
    return localBlock;
  }

  if (localBlock.updatedAt > remoteBlock.updatedAt) {
    return localBlock;
  }
  if (localBlock.updatedAt < remoteBlock.updatedAt) {
    return remoteBlock;
  }

  if (_sameBlock(localBlock, remoteBlock)) {
    return localBlock;
  }

  return localBlock;
}

bool _sameBlock(_SettingsBlockPayload? a, _SettingsBlockPayload? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return a.contentMd5 == b.contentMd5;
}

int _computeSnapshotSyncTime(Map<String, _SettingsBlockPayload> blocks) {
  var maxSyncTime = 0;
  for (final block in blocks.values) {
    if (block.updatedAt > maxSyncTime) {
      maxSyncTime = block.updatedAt;
    }
  }
  return maxSyncTime;
}

int _normalizeTimestamp(int? timestamp, {required int fallback}) {
  if (timestamp != null && timestamp > 0) {
    return timestamp;
  }
  return fallback;
}

String get _remoteSettingsMd5Path =>
    '${ComicSyncCore.syncRemoteRootName}/${ComicSyncCore.settingsMd5FileName}';

class _SettingsSnapshot {
  const _SettingsSnapshot({required this.blocks});

  final Map<String, _SettingsBlockPayload> blocks;

  int get syncTime => _computeSnapshotSyncTime(blocks);
}

class _SettingsBlockPayload {
  _SettingsBlockPayload({
    required this.name,
    required this.updatedAt,
    required this.data,
    this.supportsPluginReinstall = false,
  }) : contentMd5 = _calculateStructuredMd5(data);

  final String name;
  final int updatedAt;
  final Map<String, dynamic> data;
  final String contentMd5;
  // Parse provenance only, deliberately absent from the serialized wire format.
  final bool supportsPluginReinstall;

  Map<String, dynamic> toJson() {
    return {'updatedAt': updatedAt, 'data': data};
  }
}

class _LocalSettingsBlockMeta {
  const _LocalSettingsBlockMeta({required this.updatedAt, required this.hash});

  factory _LocalSettingsBlockMeta.fromBlock(_SettingsBlockPayload block) {
    return _LocalSettingsBlockMeta(
      updatedAt: block.updatedAt,
      hash: block.contentMd5,
    );
  }

  factory _LocalSettingsBlockMeta.fromJson(Map<String, dynamic> json) {
    return _LocalSettingsBlockMeta(
      updatedAt: int.tryParse(json['updatedAt']?.toString() ?? '') ?? 0,
      hash: json['hash']?.toString() ?? '',
    );
  }

  final int updatedAt;
  final String hash;

  Map<String, dynamic> toJson() {
    return {'updatedAt': updatedAt, 'hash': hash};
  }
}

class _SettingsMergeResult {
  const _SettingsMergeResult({
    required this.mergedState,
    required this.mergedSnapshot,
    required this.syncTime,
    required this.shouldApplyLocalState,
    required this.shouldApplyPluginData,
    required this.pluginBlockData,
    required this.localBlockMeta,
  });

  final GlobalSettingState mergedState;
  final _SettingsSnapshot mergedSnapshot;
  final int syncTime;
  final bool shouldApplyLocalState;
  final bool shouldApplyPluginData;
  final Map<String, dynamic> pluginBlockData;
  final Map<String, _LocalSettingsBlockMeta> localBlockMeta;
}

class _RemoteSettingsData {
  const _RemoteSettingsData({
    required this.bytes,
    required this.timestamp,
    required this.path,
  });

  final List<int> bytes;
  final int timestamp;
  final String path;
}
