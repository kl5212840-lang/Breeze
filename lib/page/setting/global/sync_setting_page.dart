import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/page/setting/global/sync_task_status.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/page/setting/global/full_cloud_replace_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/page/setting/global/appearance_gallery_conflict_sheet.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/common/backup_protection_ui.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/setting/common/plugin_compatibility_notice.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

Future<SyncRunResult> _synchronize({
  required GlobalSettingState state,
  required SyncDirection direction,
  GlobalSettingCubit? globalSettingCubit,
  ComicFollowCubit? comicFollowCubit,
  AppearanceGalleryResolver? resolveGalleryConflict,
}) =>
    (direction == SyncDirection.upload
    ? manualUploadToCloud
    : manualDownloadFromCloud)(
      state: state,
      globalSettingCubit: globalSettingCubit,
      comicFollowCubit: comicFollowCubit,
      resolveGalleryConflict: resolveGalleryConflict,
    );

class SyncArchiveActions {
  const SyncArchiveActions({this.synchronize = _synchronize});
  final Future<SyncRunResult> Function({
    required GlobalSettingState state,
    required SyncDirection direction,
    GlobalSettingCubit? globalSettingCubit,
    ComicFollowCubit? comicFollowCubit,
    AppearanceGalleryResolver? resolveGalleryConflict,
  })
  synchronize;
}

@RoutePage()
class SyncSettingPage extends StatefulWidget {
  const SyncSettingPage({
    super.key,
    this.archiveActions = const SyncArchiveActions(),
  });
  final SyncArchiveActions archiveActions;
  @override
  State<SyncSettingPage> createState() => _SyncSettingPageState();
}

class _SyncSettingPageState extends State<SyncSettingPage> {
  bool _busy = false;
  bool _choosingGallery = false;
  String? _error;
  SyncDirection? _direction;
  bool get _locked =>
      _busy || syncTaskProgress.running || syncStorageOperations.busy.value;
  bool get _waitingForStorage =>
      syncStorageOperations.busy.value && !syncTaskProgress.running && !_busy;
  SyncDirection? get _runningDirection => _busy
      ? _direction
      : syncTaskProgress.running
      ? syncTaskProgress.value?.direction
      : null;

  @override
  void initState() {
    super.initState();
    syncStorageOperations.busy.addListener(_storageChanged);
    syncTaskProgress.changes.addListener(_storageChanged);
  }

  void _storageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    syncStorageOperations.busy.removeListener(_storageChanged);
    syncTaskProgress.changes.removeListener(_storageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    final configured = isSyncServiceConfigured(state);
    return SettingPageShell(
      grouped: true,
      title: t.settings.sync,
      child: ListView(
        children: [
          if (_waitingForStorage)
            ListTile(
              key: const ValueKey('sync.storage-waiting'),
              leading: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(t.settings.syncStorageWaiting),
            ),
          SettingSection(
            children: [
              _syncServiceType(state, cubit),
              webdavSync(
                context,
                state.syncSetting.syncServiceType,
                enabled: !_locked,
                showDescription: false,
              ),
            ],
          ),
          if (configured) ...[
            SettingSection(
              title: t.settings.syncContent,
              footer: t.settings.syncScopeNote,
              children: [
                _syncSettings(state, cubit),
                _syncPlugins(state, cubit),
              ],
            ),
            _taskStatus(_waitingForStorage ? null : syncTaskProgress.value),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: FilledButton.icon(
                key: const ValueKey('sync.upload'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _locked ? null : () => _sync(SyncDirection.upload),
                icon: SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      _runningDirection == SyncDirection.upload &&
                          !_choosingGallery
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.cloud_upload_outlined),
                ),
                label: Text(
                  _runningDirection == SyncDirection.upload
                      ? t.settings.syncWorking
                      : t.settings.syncUploadLocal,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: OutlinedButton.icon(
                key: const ValueKey('sync.restore'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _locked ? null : () => _sync(SyncDirection.restore),
                icon: SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      _runningDirection == SyncDirection.restore &&
                          !_choosingGallery
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.cloud_download_outlined),
                ),
                label: Text(
                  _runningDirection == SyncDirection.restore
                      ? t.settings.syncWorking
                      : t.settings.syncRestoreCloud,
                ),
              ),
            ),
            const PluginCompatibilityNotice(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  _error!,
                  key: const ValueKey('sync.error'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SettingSection(
              title: t.settings.syncBehavior,
              children: [_autoSync(state, cubit)],
            ),
            SettingSection(
              title: t.settings.syncAdvanced,
              children: [
                TouchHoverIntent(
                  identity: 'sync.full-replace',
                  builder: (context, hover) => ListTile(
                    key: const ValueKey('sync.full-replace'),
                    hoverColor: hover.hoverColor(),
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: Text(t.settings.cloudReplaceTitle),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_locked,
                    onTap: _locked
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FullCloudReplacePage(),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _taskStatus(SyncTaskSnapshot? task) {
    final title = switch (task?.direction) {
      SyncDirection.upload => t.settings.syncUploadLocal,
      SyncDirection.restore => t.settings.syncRestoreCloud,
      _ => t.settings.sync,
    };
    final phase = task == null
        ? t.settings.syncMergeNote
        : switch (task.status) {
            SyncTaskStatus.completed => t.settings.syncTaskFinished,
            SyncTaskStatus.cancelled => t.settings.syncTaskCancelled,
            SyncTaskStatus.failed => switch (task.failure) {
              SyncFailureKind.timeout => t.settings.syncTimeout,
              SyncFailureKind.connection => t.settings.syncConnectionFailed,
              SyncFailureKind.secureConnection =>
                t.settings.syncSecureConnectionFailed,
              SyncFailureKind.storage => t.settings.syncStorageFailed,
              SyncFailureKind.format => t.settings.syncFormatFailed,
              SyncFailureKind.noCloudBackup => t.settings.syncNoCloudBackup,
              _ => t.settings.manualSyncFailed,
            },
            SyncTaskStatus.running =>
              task.fraction != null
                  ? t.settings.syncTaskImageProgress(
                      action: task.phase == SyncTaskPhase.artworkUploading
                          ? t.settings.syncTaskImageUpload
                          : t.settings.syncTaskImagePrepare,
                      done: task.completedItems!,
                      total: task.totalItems!,
                      percent: (task.fraction! * 100).floor(),
                    )
                  : switch (task.phase) {
                      SyncTaskPhase.preparing => t.settings.syncTaskPreparing,
                      SyncTaskPhase.accounts => t.settings.syncTaskAccounts,
                      SyncTaskPhase.artwork ||
                      SyncTaskPhase.artworkPreparing ||
                      SyncTaskPhase.artworkUploading =>
                        t.settings.syncTaskArtwork,
                      SyncTaskPhase.comics ||
                      SyncTaskPhase.videos => t.settings.syncTaskRecords,
                      SyncTaskPhase.settings => t.settings.syncTaskSettings,
                      SyncTaskPhase.finishing => t.settings.syncTaskFinishing,
                      SyncTaskPhase.waiting => t.settings.syncTaskWaiting,
                    },
          };
    return SyncTaskStatusCard(
      key: const ValueKey('sync.task-status'),
      task: task,
      title: title,
      phase: phase,
      foregroundHint: defaultTargetPlatform == TargetPlatform.iOS
          ? t.settings.syncKeepForeground
          : null,
    );
  }

  Future<void> _sync(SyncDirection direction) async {
    if (_locked) return;
    final cubit = context.read<GlobalSettingCubit>();
    final follows = context.read<ComicFollowCubit>();
    setState(() {
      _busy = true;
      _direction = direction;
      _error = null;
    });
    int? taskId;
    try {
      Future<SyncRunResult> synchronize() {
        final pending = syncTaskProgress.run(
          direction: direction,
          cancelled: (error) => error is AppearanceGalleryResolutionCancelled,
          action: () => widget.archiveActions.synchronize(
            state: cubit.state,
            direction: direction,
            globalSettingCubit: cubit,
            comicFollowCubit: follows,
            resolveGalleryConflict: (conflict) async {
              if (!mounted) return null;
              syncTaskProgress.phase(SyncTaskPhase.waiting);
              setState(() => _choosingGallery = true);
              try {
                return await showAppearanceGalleryConflictSheet(
                  context,
                  conflict,
                );
              } finally {
                syncTaskProgress.phase(SyncTaskPhase.artwork);
                if (mounted) setState(() => _choosingGallery = false);
              }
            },
          ),
        );
        taskId = syncTaskProgress.value?.id;
        return pending;
      }

      final result = await retryWithLegacyBackupAccess(context, synchronize);
      if (result == null) {
        if (taskId != null) syncTaskProgress.markCancelled(taskId!);
        return;
      }
      if (syncTaskProgress.value?.id != taskId) return;
      final hasSkippedPlugins = mounted
          ? await showPluginCompatibilityNotices(context)
          : PluginHostCompatibilityNotices.instance.issues.value.isNotEmpty;
      if (syncTaskProgress.value?.id != taskId) return;
      if (result.runtimeReloadPending) {
        showWarningToast(t.settings.archiveReloadPending);
      } else if (!hasSkippedPlugins) {
        showSuccessToast(
          direction == SyncDirection.upload
              ? t.settings.manualUploadSuccess
              : t.settings.manualDownloadSuccess,
        );
      }
    } catch (error, stack) {
      logger.e(
        'Synchronization failed: ${direction.name}/${classifySyncFailure(error).name}',
        stackTrace: stack,
      );
      if (syncTaskProgress.value?.id != taskId) return;
      final message = switch (error) {
        AppearanceGalleryResolutionCancelled() =>
          t.settings.appearanceGalleryCancelled,
        AppearanceGalleryResolutionStale() =>
          t.settings.appearanceGalleryConflictStale,
        AppearanceGalleryPreviewUnavailable() =>
          t.settings.appearanceGalleryUnavailable,
        AppearanceSyncIncomplete(localApplied: true) =>
          t.settings.appearanceSyncCleanupPending,
        AppearanceSyncIncomplete(cloudManifestVerified: true) =>
          t.settings.appearanceSyncLocalPending,
        BackupProtectionException() => backupProtectionError(error),
        SyncCompatibilityException() ||
        ArchiveRestoreFailed() => error.toString(),
        _ => switch (classifySyncFailure(error)) {
          SyncFailureKind.timeout => t.settings.syncTimeout,
          SyncFailureKind.connection => t.settings.syncConnectionFailed,
          SyncFailureKind.secureConnection =>
            t.settings.syncSecureConnectionFailed,
          SyncFailureKind.storage => t.settings.syncStorageFailed,
          SyncFailureKind.format => t.settings.syncFormatFailed,
          SyncFailureKind.noCloudBackup => t.settings.syncNoCloudBackup,
          SyncFailureKind.unknown => t.settings.manualSyncFailed,
        },
      };
      if (mounted) {
        if (error is! NoCloudBackup) setState(() => _error = message);
      } else if (error is AppearanceGalleryResolutionCancelled) {
        showInfoToast(message);
      } else {
        showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _syncServiceType(GlobalSettingState state, GlobalSettingCubit cubit) {
    final syncServiceItems = <SyncServiceType, String>{
      SyncServiceType.none: t.settings.syncServiceNone,
      SyncServiceType.webdav: t.settings.syncServiceWebdav,
      SyncServiceType.s3: t.settings.syncServiceS3,
    };

    return SettingChoiceTile<SyncServiceType>(
      leading: const Icon(Icons.storage_outlined),
      title: t.settings.syncService,
      value: state.syncSetting.syncServiceType,
      items: syncServiceItems,
      enabled: !_locked,
      onChanged: (SyncServiceType value) {
        if (value == state.syncSetting.syncServiceType) return;
        cubit.updateSyncSetting(
          (current) => current.copyWith(
            syncServiceType: value,
            syncSettings: value == SyncServiceType.none
                ? false
                : current.syncSettings,
          ),
        );
      },
    );
  }

  Widget _syncToggle({
    Key? key,
    Color? hoverColor,
    Widget? secondary,
    Widget? title,
    Widget? subtitle,
    WidgetStateProperty<Icon>? thumbIcon,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) => BreezeSwitchListTile(
    SwitchListTile.adaptive(
      key: key,
      hoverColor: hoverColor,
      secondary: secondary,
      title: title,
      subtitle: subtitle,
      thumbIcon: thumbIcon,
      value: value,
      onChanged: _locked ? null : onChanged,
    ),
  );

  Widget _autoSync(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'sync-toggle-1',
      builder: (context, hover) => _syncToggle(
        hoverColor: hover.hoverColor(),
        secondary: const Icon(Icons.cloud_sync_outlined),
        title: Text(t.settings.autoSync),
        subtitle: Text(t.settings.autoSyncSubtitle),
        thumbIcon: settingSwitchThumbIcon(context),
        value: state.syncSetting.autoSync,
        onChanged: (bool value) {
          cubit.updateSyncSetting(
            (current) => current.copyWith(autoSync: value),
          );
          if (value) {
            eventBus.fire(NoticeSync());
          }
        },
      ),
    );
  }

  Widget _syncSettings(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'sync-toggle-3',
      builder: (context, hover) => _syncToggle(
        hoverColor: hover.hoverColor(),
        secondary: const Icon(Icons.tune_outlined),
        title: Text(t.settings.syncSettings),
        thumbIcon: settingSwitchThumbIcon(context),
        value: state.syncSetting.syncSettings,
        onChanged: (bool value) {
          cubit.updateSyncSetting(
            (current) => current.copyWith(syncSettings: value),
          );
        },
      ),
    );
  }

  Widget _syncPlugins(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'sync-toggle-4',
      builder: (context, hover) => _syncToggle(
        hoverColor: hover.hoverColor(),
        secondary: const Icon(Icons.extension_outlined),
        title: Text(t.settings.syncPlugins),
        subtitle: Text(t.settings.syncPluginsSubtitle),
        thumbIcon: settingSwitchThumbIcon(context),
        value: state.syncSetting.syncPlugins,
        onChanged: (bool value) {
          cubit.updateSyncSetting(
            (current) => current.copyWith(syncPlugins: value),
          );
        },
      ),
    );
  }
}
