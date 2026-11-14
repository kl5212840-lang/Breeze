import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/local_import_recovery.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_cloud_data.dart';
import 'package:zephyr/service/plugin_account_data_clear.dart';
import 'package:zephyr/service/plugin_comic_file_removal.dart';
import 'package:zephyr/service/plugin_data_removal_models.dart';
import 'package:zephyr/service/plugin_portable_data_clear.dart';
import 'package:zephyr/service/plugin_record_data_clear.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/util/get_path.dart';

export 'package:zephyr/service/plugin_data_removal_models.dart';

/// Isolated storage/checkpoint seams; production still uses the same source
/// plans, transaction, recovery journal and managed-file ownership checks.
class PluginDataRemovalDependencies {
  PluginDataRemovalDependencies({
    LocalAppearanceImages? images,
    this.downloads,
    this.recoveryDirectory,
    this.videoStore,
    this.encodeSource,
    this.checkpoint,
    ReaderHistoryService? readerHistory,
  }) : images = images ?? LocalAppearanceImages.instance,
       readerHistory = readerHistory ?? ReaderHistoryService.instance;
  final LocalAppearanceImages images;
  final ReaderHistoryService readerHistory;
  final Directory? downloads, recoveryDirectory;
  final VideoLibraryStore? videoStore;
  final String Function(String)? encodeSource;
  final Future<void> Function(String)? checkpoint;
}

void _guard(String source, int epoch) {
  final state = LocalPluginInstallationState.instance;
  if (state.installationEpoch(source) != epoch || state.isInstalling(source)) {
    throw const PluginLifecycleChanged();
  }
}

Future<PluginDataRemovalCounts> inspectPluginPersonalData(
  String source, {
  required int expectedEpoch,
  required bool cloudDelete,
  CloudPluginAccountData? knownCloud,
  PluginDataRemovalDependencies? dependencies,
}) async {
  final services = dependencies ?? PluginDataRemovalDependencies();
  await LocalPluginInstallationState.instance.load();
  _guard(source, expectedEpoch);
  final records = await preparePluginRecordDataClear(
    source,
    cloudDelete: cloudDelete,
    expectedEpoch: expectedEpoch,
    includeDownloads: true,
    knownCloudComics: cloudDelete ? knownCloud?.comicRecords : null,
    knownCloudVideo: cloudDelete ? knownCloud?.videoRecords : null,
    store: services.videoStore,
  );
  final account = preparePluginAccountDataClear(
    source,
    cloudDelete: cloudDelete,
    expectedEpoch: expectedEpoch,
    knownCloudConfigs: cloudDelete ? knownCloud?.configs ?? const [] : const [],
  );
  final portable = await preparePluginPortableDataClear(
    source,
    scopes: PluginDataScope.values.toSet(),
    cloudDelete: cloudDelete,
    expectedEpoch: expectedEpoch,
    knownCloudPortable: cloudDelete ? knownCloud?.portable : null,
  );
  final images = await services.images.preparePluginDataRemoval(source);
  final videos = await VideoLocalResources.read();
  _guard(source, expectedEpoch);
  return PluginDataRemovalCounts(
    favorites: records.favoriteCount,
    history: records.historyCount + portable.historyCount,
    follows: records.followCount,
    settings: account.fieldCount,
    downloads:
        records.downloadCount +
        videos.where((row) => row['source'] == source).length,
    images: images.imageCount,
  );
}

Future<PluginDataRemovalResult> clearPluginPersonalData(
  String source, {
  required int expectedEpoch,
  required PluginDataRemovalChoice choice,
  CloudPluginAccountData? knownCloud,
  PluginDataRemovalDependencies? dependencies,
  Future<void> Function()? beforeLocalMutation,
  bool removeInstallation = false,
}) => CacheWorkspaceGuard.withWorkspace(() async {
  LocalImportRecovery.requireRecovered();
  final services = dependencies ?? PluginDataRemovalDependencies();
  return PluginRegistryService.I.withStoppedRuntime(
    source,
    expectedInstallationEpoch: expectedEpoch,
    action: () => services.readerHistory.withWritesPausedForSource(
      source,
      () => _clearStopped(
        source,
        expectedEpoch: expectedEpoch,
        choice: choice,
        knownCloud: knownCloud,
        beforeLocalMutation: beforeLocalMutation,
        removeInstallation: removeInstallation,
        services: services,
      ),
    ),
  );
});

Future<PluginDataRemovalResult> _clearStopped(
  String source, {
  required int expectedEpoch,
  required PluginDataRemovalChoice choice,
  required CloudPluginAccountData? knownCloud,
  required PluginDataRemovalDependencies services,
  required Future<void> Function()? beforeLocalMutation,
  required bool removeInstallation,
}) async {
  _guard(source, expectedEpoch);
  // Run the cloud phase under the existing stopped-runtime/storage boundary,
  // before even beginning the local rollback journal. A cloud failure therefore
  // preserves all local data and installation. Never wrap this API in its queue.
  await beforeLocalMutation?.call();
  _guard(source, expectedEpoch);
  final local = LocalPluginInstallationState.instance;
  final downloads = services.downloads ?? Directory(await getDownloadPath());
  final recovery = await LocalImportRecovery.begin(
    downloads: downloads,
    images: services.images,
    recoveryDirectory: services.recoveryDirectory,
  );
  LocalAppearanceRestorePlan? images;
  PluginComicFileRemovalPlan? comics;
  PluginVideoRemovalPlan? videos;
  var databaseCommitted = false;

  Future<bool> finishCommitted() async {
    await recovery.markCommitted();
    TemporaryDataCaches.clear(source: source);
    await VideoPersonalSnapshotStore.clearDisk(source: source);
    await JmCollectionSnapshots.instance.clearDisk(source: source);
    await images?.finish(committed: true);
    final videoClean = await videos?.finish(committed: true) ?? true;
    final comicClean = await comics?.finish(committed: true) ?? true;
    if (!videoClean || !comicClean) return false;
    await recovery.finish();
    return true;
  }

  try {
    var epoch = await local.setDataExclusions(
      source,
      PluginDataScope.values.toSet(),
      beforeWrite: recovery.beforePreferences,
    );
    // Capture all plans against the final journaled installation revision.
    // Marking removal after preparation would invalidate their epoch guards.
    if (removeInstallation) {
      await local.markRemoved(
        source,
        expectedEpoch: epoch,
        beforeWrite: recovery.beforePreferences,
      );
      epoch = local.installationEpoch(source);
      await services.checkpoint?.call('installation-staged');
    }
    final records = await preparePluginRecordDataClear(
      source,
      cloudDelete: choice.cloudDelete,
      expectedEpoch: epoch,
      includeDownloads: choice.includeDownloads,
      knownCloudComics: choice.cloudDelete ? knownCloud?.comicRecords : null,
      knownCloudVideo: choice.cloudDelete ? knownCloud?.videoRecords : null,
      store: services.videoStore,
    );
    final account = preparePluginAccountDataClear(
      source,
      cloudDelete: choice.cloudDelete,
      expectedEpoch: epoch,
      knownCloudConfigs: choice.cloudDelete
          ? knownCloud?.configs ?? const []
          : const [],
    );
    final portable = await preparePluginPortableDataClear(
      source,
      scopes: PluginDataScope.values.toSet(),
      cloudDelete: choice.cloudDelete,
      expectedEpoch: epoch,
      knownCloudPortable: choice.cloudDelete ? knownCloud?.portable : null,
    );
    // Device cleanup forgets artwork history. Only the explicitly requested
    // cloud phase above removes remote references/resources; reinstalling can
    // therefore import artwork retained by a local-only removal.
    images = await services.images.preparePluginDataRemoval(source);
    if (choice.includeDownloads) {
      videos = await PluginVideoRemovalPlan.prepare(source, recovery: recovery);
      comics = await PluginComicFileRemovalPlan.prepare(
        source,
        downloadsRoot: downloads,
        ownedStorageRoots: objectbox.unifiedDownloadBox
            .getAll()
            .where((row) => row.source == source)
            .map((row) => row.storageRoot),
        encodeSource: services.encodeSource,
      );
      await comics.stage(beforeFileMoves: recovery.beforeFileMoves);
      await videos.stage(beforeFileMoves: recovery.beforeFileMoves);
    }
    await services.checkpoint?.call('files-staged');
    await recovery.beforeImages(images.recoveryBasenames, strict: true);
    await recovery.beforePreferences({
      LocalAppearanceImages.preferencesKey: images.recoveryMapping,
    });
    await images.activate();
    await records.applyPreferences(beforeWrite: recovery.beforePreferences);
    await services.readerHistory.clearSourceProgress(
      source,
      beforeWrite: recovery.beforePreferences,
    );
    await portable.applyPreferences(beforeWrite: recovery.beforePreferences);
    await videos?.applyPreferences(beforeWrite: recovery.beforePreferences);
    await services.checkpoint?.call('preferences-applied');
    _guard(source, epoch);
    // This is the sole application-DB write. A throw rolls back this transaction
    // itself; no whole-database replay can erase another source's late write.
    objectbox.store.runInTransaction(TxMode.write, () {
      _guard(source, epoch);
      records.persistDatabase();
      account.persistDatabase();
      recovery.markDatabaseCommitted();
    });
    databaseCommitted = true;
    await services.checkpoint?.call('database-committed');
    return PluginDataRemovalResult(cleanupPending: !await finishCommitted());
  } catch (_) {
    if (databaseCommitted ||
        recovery.hasDatabaseCommit ||
        recovery.journal['phase'] == 'committed') {
      // The user's confirmed deletion already committed. Complete the new state
      // or retain its durable journal; never put deleted data/files back.
      try {
        return PluginDataRemovalResult(
          cleanupPending: !await finishCommitted(),
        );
      } catch (_) {
        try {
          await images?.releaseForRecovery();
        } catch (_) {}
        try {
          await videos?.finish(committed: true);
        } catch (_) {}
        return const PluginDataRemovalResult(cleanupPending: true);
      }
    }
    try {
      await videos?.rollback();
      await comics?.rollback();
      await images?.rollback();
      await recovery.restorePreferences(onlyOwnedValues: true);
      await local.reload();
      await PortablePreferences.notifyRestored();
      VideoLocalResources.invalidate();
      await services.videoStore?.read();
      await recovery.markRolledBack();
      await images?.finish(committed: false);
      await videos?.finish(committed: false);
      await recovery.finish();
    } catch (_) {
      try {
        await images?.releaseForRecovery();
      } catch (_) {}
      try {
        await videos?.finish(committed: false);
      } catch (_) {}
      throw const LocalImportRecoveryFailed();
    }
    rethrow;
  }
}
