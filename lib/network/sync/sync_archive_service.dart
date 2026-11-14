import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_adapter.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_recovery.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/network/sync/sync_plugin_participation.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/network/sync/chapter_progress_sync.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show TxMode;
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/service/folder_cover_identity.dart';

export 'package:zephyr/network/sync/sync_archive_adapter.dart'
    show SyncArchiveStatus;
export 'package:zephyr/network/sync/sync_archive_context.dart'
    show SyncRunResult, ArchiveRestoreFailed;

class SyncArchiveCodecs {
  const SyncArchiveCodecs({
    this.comic = const ComicSyncCodec(),
    this.settings = const SettingsSyncCodec(),
    this.video = const VideoLibrarySyncCodec(),
  });
  final ComicSyncCodec comic;
  final SettingsSyncCodec settings;
  final VideoLibrarySyncCodec video;
}

class SyncArchiveAdapters {
  const SyncArchiveAdapters({
    required this.current,
    required this.legacyReader,
  });
  final ScopedSyncArchiveAdapter current, legacyReader;

  factory SyncArchiveAdapters.fromState(GlobalSettingState state) {
    final current = createSyncAdapter(state);
    if (current == null) throw StateError('未配置同步服务');
    return SyncArchiveAdapters(
      current: current,
      legacyReader: current.legacyReader!,
    );
  }

  factory SyncArchiveAdapters.forTransports(
    ComicSyncRemoteAdapter Function(SyncArchiveContext) factory, {
    required String identity,
  }) {
    final reader = ScopedSyncArchiveAdapter(
      factory(SyncArchiveContext.legacyReadOnly),
      SyncArchiveContext.legacyReadOnly,
      identity: identity,
    );
    return SyncArchiveAdapters(
      current: ScopedSyncArchiveAdapter(
        factory(SyncArchiveContext.current),
        SyncArchiveContext.current,
        identity: identity,
        legacyReader: reader,
      ),
      legacyReader: reader,
    );
  }
}

class SyncArchiveHooks {
  const SyncArchiveHooks({
    this.recoveryDirectory,
    this.beforeDatabaseCommit,
    this.appearanceImages,
    this.onStarted,
  });
  final Directory? recoveryDirectory;
  final void Function()? beforeDatabaseCommit;
  final LocalAppearanceImages? appearanceImages;
  final void Function()? onStarted;
}

/// Records always merge. Manual settings and artwork follow their explicit
/// direction; automatic rounds merge records and back up account fields only.
Future<SyncRunResult> runArchiveSync({
  required GlobalSettingState state,
  SyncDirection direction = SyncDirection.merge,
  SyncArchiveAdapters? archives,
  SyncArchiveCodecs codecs = const SyncArchiveCodecs(),
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  SyncArchiveHooks? hooks,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) => syncTaskProgress.run(
  direction: direction,
  cancelled: (error) => error is AppearanceGalleryResolutionCancelled,
  action: () async {
    final scope = archives ?? SyncArchiveAdapters.fromState(state);
    final participation = await SyncPluginParticipation.capture();
    _configure(scope, codecs);
    try {
      late Map<String, ChapterProgressArchive> chapterArchives;
      await preflightSyncRound(
        scope.current,
        comicCodec: codecs.comic,
        settingsCodec: codecs.settings,
        videoCodec: codecs.video,
        requireCloudBackup: direction == SyncDirection.restore,
        checkChapterProgress: () async {
          chapterArchives = await ChapterProgressSync.read(
            scope.current,
            codec: codecs.video,
          );
          return chapterArchives.isNotEmpty;
        },
      );
      hooks?.onStarted?.call();
      if (direction != SyncDirection.restore && state.syncSetting.syncPlugins) {
        syncTaskProgress.phase(SyncTaskPhase.accounts);
        await PluginAccountSyncCoordinator.instance.captureForUpload(
          participation.sources,
        );
        participation.check();
      }
      var legacy = const SyncRunResult();
      var settingsRuntimePending = false;
      final local = objectbox.userSettingBox.get(1)?.globalSetting ?? state;
      final retiredComicFolders = <String>{};
      syncTaskProgress.phase(SyncTaskPhase.artwork);
      await syncAppearanceImages(
        scope.current,
        onUploadProgress: (completed, total) => syncTaskProgress.phase(
          SyncTaskPhase.artworkUploading,
          completed: completed,
          total: total,
        ),
        onPrepareProgress: (completed, total) => syncTaskProgress.phase(
          SyncTaskPhase.artworkPreparing,
          completed: completed,
          total: total,
        ),
        includeFolders: direction != SyncDirection.recordsOnly,
        retiredFolderKeys: (keys) => FolderCoverService.retiredKeys(
          keys,
          retiredComicIds: retiredComicFolders,
        ),
        participation: participation,
        includeGlobal:
            direction != SyncDirection.recordsOnly &&
            local.syncSetting.syncSettings,
        includePlugins:
            direction != SyncDirection.recordsOnly &&
            local.syncSetting.syncPlugins,
        direction: direction,
        images: hooks?.appearanceImages,
        resolveGalleryConflict: resolveGalleryConflict,
        beforePublish: () async {
          syncTaskProgress.phase(SyncTaskPhase.comics);
          legacy = await _mergeLegacyArchive(
            state: objectbox.userSettingBox.get(1)?.globalSetting ?? state,
            direction: direction,
            archives: scope,
            globalSettingCubit: globalSettingCubit,
            comicFollowCubit: comicFollowCubit,
            codecs: codecs,
            hooks: hooks,
            participation: participation,
          );
          participation.check();
          scope.current.validated();
          final current =
              objectbox.userSettingBox.get(1)?.globalSetting ?? state;
          await runComicSync(
            scope.current,
            codec: codecs.comic,
            onRetiredFolders: retiredComicFolders.addAll,
            preferenceDirection: current.syncSetting.syncSettings
                ? direction
                : SyncDirection.recordsOnly,
            participation: participation,
          );
          await ChapterProgressSync.run(
            scope.current,
            codec: codecs.video,
            participation: participation,
            archives: chapterArchives,
          );
          syncTaskProgress.phase(SyncTaskPhase.videos);
          await VideoLibrarySync.run(
            scope.current,
            codec: codecs.video,
            includeSettings:
                direction != SyncDirection.recordsOnly &&
                current.syncSetting.syncSettings,
            includePluginSettings:
                direction != SyncDirection.recordsOnly &&
                current.syncSetting.syncPlugins,
            direction: direction,
            participation: participation,
          );
          if (direction == SyncDirection.recordsOnly &&
              current.syncSetting.syncPlugins) {
            syncTaskProgress.phase(SyncTaskPhase.accounts);
            await runPluginAccountBackupSync(
              scope.current,
              state: current,
              participation: participation,
              codec: codecs.settings,
            );
          }
          if (direction != SyncDirection.recordsOnly &&
              (current.syncSetting.syncSettings ||
                  current.syncSetting.syncPlugins)) {
            syncTaskProgress.phase(SyncTaskPhase.settings);
            await runSettingsSync(
              scope.current,
              currentGlobalSetting: current,
              globalSettingCubit: globalSettingCubit,
              codec: codecs.settings,
              direction: direction,
              onRuntimeReloadPending: () => settingsRuntimePending = true,
              participation: participation,
            );
          }
          syncTaskProgress.phase(SyncTaskPhase.artwork);
        },
      );
      syncTaskProgress.phase(SyncTaskPhase.finishing);
      if (direction != SyncDirection.recordsOnly) {
        final artwork =
            hooks?.appearanceImages ?? LocalAppearanceImages.instance;
        for (final id in retiredComicFolders) {
          final key = FolderCoverIdentity.comic(id);
          if (artwork.paths.value.containsKey(key)) await artwork.remove(key);
        }
        await FolderCoverService.reconcileDeleted(images: artwork);
      }
      var runtimePending =
          legacy.runtimeReloadPending || settingsRuntimePending;
      try {
        await comicFollowCubit?.loadFromDatabase();
      } catch (_) {
        runtimePending = true;
      }
      return SyncRunResult(
        newArchiveSynced: true,
        legacyArchiveImported: legacy.legacyArchiveImported,
        runtimeReloadPending: runtimePending,
      );
    } finally {
      scope.current.invalidate();
    }
  },
);

String _digest(Object? data) =>
    sha256.convert(utf8.encode(jsonEncode(data))).toString();
String _journalKey(String identity) =>
    'breeze.local.sync-archive.v2.$identity.journal';
Map<String, dynamic> _object(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : {};
Map<String, dynamic> _journal(SharedPreferences prefs, String identity) {
  try {
    return _object(jsonDecode(prefs.getString(_journalKey(identity)) ?? '{}'));
  } catch (_) {
    return {};
  }
}

void _configure(SyncArchiveAdapters archives, SyncArchiveCodecs codecs) {
  archives.current.roundPreflight = () => preflightSyncRound(
    archives.current,
    comicCodec: codecs.comic,
    settingsCodec: codecs.settings,
    videoCodec: codecs.video,
  );
}

Future<SyncArchiveStatus> readArchiveStatus(
  GlobalSettingState state, {
  SyncArchiveAdapters? archives,
}) async {
  final scope = archives ?? SyncArchiveAdapters.fromState(state);
  if ((await SharedPreferences.getInstance()).getBool(
        ArchivePreferenceTransaction.pendingKey(scope.current.identity),
      ) ==
      true) {
    throw const ArchiveRestoreFailed();
  }
  await scope.current.testConnection();
  return readScopedArchiveStatus(scope.current, scope.legacyReader);
}

class _LegacyData {
  const _LegacyData(this.comic, this.settings, this.video);
  final Map<String, dynamic>? comic;
  final SettingsArchiveData? settings;
  final VideoArchiveData video;
  bool get present =>
      comic != null || settings != null || video.digests.isNotEmpty;
  Map<String, dynamic> get revisions => {
    'comic': comic == null ? null : _digest(comic),
    'settings': settings?.digest,
    'video': video.digests,
  };
}

Future<_LegacyData> _readLegacy(
  SyncArchiveAdapters archives,
  SyncArchiveCodecs codecs, {
  bool includeSettings = true,
}) async {
  final reader = archives.legacyReader;
  // All three sources are fully decoded before any local persistence begins.
  final comic = await readComicArchiveData(reader, codec: codecs.comic);
  final settings = await readSettingsArchiveData(
    reader,
    codec: codecs.settings,
  );
  final video = await VideoLibrarySync.readArchive(
    reader,
    codec: codecs.video,
    includeSettings: includeSettings,
  );
  return _LegacyData(comic, settings, video);
}

Map<String, dynamic> _stableLegacyComic(Map<String, dynamic> raw) {
  final data = _object(jsonDecode(jsonEncode(raw)));
  for (final folder in (data['folders'] as List? ?? [])) {
    if (folder is Map && '${folder['syncId'] ?? ''}'.isEmpty) {
      folder['syncId'] =
          'legacy-${_digest([SyncArchiveContext.legacyRoot, folder['typeData'], folder['uniqueKey']])}';
    }
  }
  return data;
}

const _legacyVideoFields = {
  'id',
  'title',
  'detailUrl',
  'coverUrl',
  'description',
  'typeId',
  'typeName',
  'remarks',
  'alternateTitle',
  'genres',
  'writers',
  'doubanId',
  'doubanScore',
  'year',
  'area',
  'language',
  'actors',
  'directors',
  'updatedAt',
  'releaseDate',
  'plannedEpisodes',
  'finished',
  'sourceViews',
  'sourceRating',
  'sourceRatingCount',
};

const _publicVideoMeasurements = [
  ['sourceViews', 'sourceViewsKind'],
  ['sourceRating', 'sourceRatingCount', 'sourceRatingCountConsistent'],
];

VideoLibrarySnapshot _keepNewVideoFields(
  VideoLibrarySnapshot local,
  VideoLibrarySnapshot legacy,
) {
  final raw = _object(jsonDecode(jsonEncode(legacy.toJson())));
  for (final entry in (raw['favorites'] as Map).entries) {
    final previous = local.favorites[entry.key];
    if (previous == null) continue;
    final oldItem = _object(previous.data['item']);
    final revision = entry.value as Map;
    final data = revision['data'] as Map;
    final legacyItem = _object(data['item']);
    final mergedItem = {
      ...legacyItem,
      for (final field in oldItem.entries)
        if (!_legacyVideoFields.contains(field.key) &&
            !_publicVideoMeasurements.any((group) => group.last == field.key))
          field.key: field.value,
    };
    // Old clients cannot revise a measurement independently of the local
    // evidence for its meaning. A modern incoming tuple stays authoritative.
    for (final group in _publicVideoMeasurements) {
      if (!legacyItem.containsKey(group.last) &&
          oldItem.containsKey(group.last)) {
        for (final field in group) {
          mergedItem[field] = oldItem[field];
        }
      }
    }
    data['item'] = mergedItem;
    if (!oldItem.containsKey('containCover')) {
      (data['item'] as Map).remove('containCover');
    }
  }
  for (final field in ['folders', 'memberships']) {
    final previous = field == 'folders' ? local.folders : local.memberships;
    final common = field == 'folders'
        ? const {'id', 'source', 'name'}
        : const {'itemKey', 'folderId'};
    for (final entry in (raw[field] as Map).entries) {
      final current = previous[entry.key];
      if (current == null) continue;
      final revision = entry.value as Map;
      revision['data'] = {
        ..._object(revision['data']),
        for (final extra in current.data.entries)
          if (!common.contains(extra.key)) extra.key: extra.value,
      };
    }
  }
  return VideoLibrarySnapshot.fromJson(raw);
}

String _canonical(Object? value) {
  Object? sorted(Object? input) {
    if (input is Map) {
      final keys = input.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sorted(input[key])};
    }
    if (input is List) return input.map(sorted).toList();
    return input;
  }

  return jsonEncode(sorted(value));
}

/// Internal orchestration entry, already inside the same storage-operation queue.
Future<SyncRunResult> _mergeLegacyArchive({
  required GlobalSettingState state,
  required SyncArchiveAdapters archives,
  required SyncDirection direction,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  SyncArchiveCodecs codecs = const SyncArchiveCodecs(),
  SyncArchiveHooks? hooks,
  required SyncPluginParticipation participation,
}) async {
  _configure(archives, codecs);
  await ArchivePreferenceTransaction.recover(
    archives.current.identity,
    directory: hooks?.recoveryDirectory,
  );
  await archives.legacyReader.testConnection();
  final incoming = await _readLegacy(archives, codecs, includeSettings: true);
  if (!incoming.present) return const SyncRunResult();
  participation.check();
  final members = participation.sources.toList()..sort();
  // The existing device-only import journal must reconsider unchanged legacy
  // data when a user installs a previously skipped plugin. No cloud format or
  // separate per-plugin sync state is introduced.
  final revisions = {
    for (final entry in incoming.revisions.entries)
      entry.key: _digest([entry.value, members]),
  };
  final prefs = await SharedPreferences.getInstance();
  final oldJournal = _journal(prefs, archives.current.identity);
  final previous = _object(oldJournal['legacyRevisions']);
  final oldSelections = _object(oldJournal['legacySelections']);
  final selections = {
    'settings':
        direction != SyncDirection.recordsOnly &&
        direction != SyncDirection.upload &&
        state.syncSetting.syncSettings,
    'plugins':
        direction != SyncDirection.recordsOnly &&
        direction != SyncDirection.upload &&
        state.syncSetting.syncPlugins,
    'direction': direction.name,
  };
  final comicChanged =
      incoming.comic != null &&
      (previous['comic'] != revisions['comic'] ||
          direction == SyncDirection.restore && state.syncSetting.syncSettings);
  final settingsChanged =
      incoming.settings != null &&
      (previous['settings'] != revisions['settings'] ||
          _canonical(oldSelections) != _canonical(selections) ||
          direction == SyncDirection.restore);
  final videoChanged =
      incoming.video.digests.isNotEmpty &&
      (previous['video'] != revisions['video'] ||
          _canonical(oldSelections) != _canonical(selections) ||
          direction == SyncDirection.restore);
  // The old archive is an input, never a second output. Do not replay unchanged
  // old rows after a local removal, or bump clocks for normalized legacy folders.
  if (!comicChanged && !settingsChanged && !videoChanged) {
    return const SyncRunResult();
  }
  final plan =
      settingsChanged &&
          (selections['settings'] == true || selections['plugins'] == true)
      ? await prepareSettingsArchiveImport(
          incoming.settings,
          state: state,
          protectVersionedLocalFields: true,
          direction: direction,
          participation: participation,
        )
      : null;
  final store = VideoLibraryStore.shared;
  final recovery = await ArchivePreferenceTransaction.create(
    archives.current.identity,
    directory: hooks?.recoveryDirectory,
  );
  try {
    await plan?.applyPreferences(recovery.prepare);
    if (videoChanged && incoming.video.hasPreferences) {
      await PortablePreferences.restore(
        PortablePreferences.forSync(
          incoming.video.preferences,
          includeSettings: selections['settings'] == true,
          includePluginSettings: selections['plugins'] == true,
        ),
        direction: direction == SyncDirection.upload
            ? SyncDirection.recordsOnly
            : direction,
        shouldWriteKey: (key) => PortablePreferences.settingsKeySelected(
          key,
          includeSettings: selections['settings'] == true,
          includePluginSettings: selections['plugins'] == true,
        ),
        beforeWrite: (updates) async {
          participation.check();
          await recovery.prepare(updates);
        },
        participatingSources: participation.sources,
      );
    }
    if (videoChanged) {
      await store.updateSnapshot(
        (current) => projectPluginVideoData(
          current.merged(_keepNewVideoFields(current, incoming.video.snapshot)),
          current,
          participation.sources,
        ),
        beforeWrite: (_, next) async {
          await recovery.prepare({VideoLibraryStore.prefsKey: next});
          participation.check();
        },
      );
    }
    final changes = <String, dynamic>{
      _journalKey(archives.current.identity): jsonEncode({
        ...oldJournal,
        'legacyRevisions': revisions,
        'legacySelections': selections,
      }),
    };
    await recovery.prepare(changes);
    for (final change in changes.entries) {
      if (!await writeArchivePreference(prefs, change.key, change.value)) {
        throw const ArchiveRestoreFailed();
      }
    }
    await ensureSyncDeviceId();
    participation.check();
    objectbox.store.runInTransaction(TxMode.write, () {
      if (comicChanged) {
        ComicSyncCore.mergeUnifiedData(
          objectbox.store,
          _stableLegacyComic(incoming.comic!),
          participatingSources: participation.sources,
          preferenceDirection: selections['settings'] == true
              ? direction
              : SyncDirection.recordsOnly,
        );
      }
      plan?.persistDatabase();
      hooks?.beforeDatabaseCommit?.call();
      recovery.markDatabaseCommitted();
    });
  } catch (_) {
    try {
      await recovery.rollback();
    } catch (_) {
      throw const ArchiveRestoreFailed();
    }
    throw const ArchiveRestoreFailed();
  }
  await recovery.finishCommitted();
  var ready =
      plan == null ||
      await plan.notifyCommitted(globalSettingCubit: globalSettingCubit);
  try {
    await comicFollowCubit?.loadFromDatabase();
  } catch (_) {
    ready = false;
  }
  return SyncRunResult(
    legacyArchiveImported: true,
    runtimeReloadPending: !ready,
  );
}
