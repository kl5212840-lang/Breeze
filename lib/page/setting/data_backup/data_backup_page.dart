import 'dart:io';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/permission.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/backup_security/private_backup_workspace.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/page/setting/common/backup_protection_ui.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/setting/common/plugin_compatibility_notice.dart';

import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

/// Offline host boundaries; production always uses the validated file importer.
class DataBackupActions {
  const DataBackupActions({
    this.selectBackup,
    this.inspectBackup,
    this.importBackup,
    this.importBackupWithOptions,
    this.exportBackup,
  });
  final Future<BackupConfig?> Function(BuildContext)? selectBackup;
  final Future<OfflineBackupPreview> Function(BackupConfig)? inspectBackup;
  final Future<void> Function(BackupConfig, BackupImportMode)? importBackup;
  final Future<void> Function(
    BackupConfig,
    BackupImportMode,
    BackupImportOptions,
  )?
  importBackupWithOptions;
  final Future<void> Function(bool)? exportBackup;
}

class _BackupImportDraft {
  const _BackupImportDraft(this.mode, this.options);
  final BackupImportMode mode;
  final BackupImportOptions options;
}

@RoutePage()
class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key, this.actions = const DataBackupActions()});
  final DataBackupActions actions;

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  bool _includeDownloads = false;
  bool _usesSharedPassword = false;
  bool _busy = false;
  BackupConfig? _pendingImport;

  @override
  void initState() {
    super.initState();
    _loadProtection();
  }

  Future<void> _loadProtection() async {
    try {
      await BackupProtectionManager.shared.load();
      if (mounted) {
        setState(
          () => _usesSharedPassword =
              BackupProtectionManager.shared.mode ==
              BackupProtectionMode.passwordProtected,
        );
      }
    } catch (_) {
      // Export reads the manager again and fails closed if it is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) => SettingPageShell(
    grouped: true,
    title: t.dataBackup.title,
    child: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SettingSection(
          title: t.dataBackup.exportSection,
          footer: t.backupFlow.includeFilesHint,
          children: [
            TouchHoverIntent(
              identity: 'backup.includeDownloads',
              builder: (context, hover) => BreezeSwitchListTile(
                SwitchListTile.adaptive(
                  key: const ValueKey('backup.include-downloads'),
                  hoverColor: hover.hoverColor(),
                  secondary: const InterfaceSymbol(
                    symbol: 'folder',
                    fallback: Icons.folder_outlined,
                  ),
                  title: Text(t.backupFlow.includeFiles),
                  thumbIcon: settingSwitchThumbIcon(context),
                  value: _includeDownloads,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _includeDownloads = value),
                ),
              ),
            ),
            TouchHoverIntent(
              identity: 'backup.export',
              builder: (context, hover) => ListTile(
                key: const ValueKey('backup.export'),
                hoverColor: hover.hoverColor(),
                leading: const InterfaceSymbol(
                  symbol: 'archivebox',
                  fallback: Icons.archive_outlined,
                ),
                title: Text(t.dataBackup.exportData),
                subtitle: Text(
                  _usesSharedPassword
                      ? t.backupFlow.encryptedExportHint
                      : t.backupFlow.standardHint,
                ),
                trailing: const InterfaceSymbol(
                  symbol: 'chevron.right',
                  fallback: Icons.chevron_right,
                ),
                onTap: _busy ? null : _exportData,
              ),
            ),
          ],
        ),
        SettingSection(
          title: t.dataBackup.importSection,
          footer: t.backupFlow.importHint,
          children: [
            TouchHoverIntent(
              identity: 'backup.import',
              builder: (context, hover) => ListTile(
                key: const ValueKey('backup.import'),
                hoverColor: hover.hoverColor(),
                leading: const InterfaceSymbol(
                  symbol: 'tray.and.arrow.up',
                  fallback: Icons.unarchive_outlined,
                ),
                title: Text(t.backupFlow.importBackup),
                trailing: const InterfaceSymbol(
                  symbol: 'chevron.right',
                  fallback: Icons.chevron_right,
                ),
                onTap: _busy ? null : _importData,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _protectedAction(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    if (_busy) return;
    _setBusy(true);
    try {
      await CacheWorkspaceGuard.withWorkspace(action);
    } on BackupProtectionCancelled {
      // An explicit cancellation must never become a plaintext export.
    } on CacheWorkspaceBusy {
      showErrorToast(t.cache.backupBusy);
    } on HlsPortableBackupUnsupported {
      if (mounted) {
        await _showResultDialog(
          t.dataBackup.exportData,
          t.dataBackup.hlsNotPortable,
        );
      }
    } on ComicDownloadTreeBusy {
      showErrorToast(t.dataBackup.downloadsBusy);
    } on SyncCompatibilityException {
      showErrorToast(t.dataBackup.unsupportedData);
    } on BackupCompatibilityException {
      showErrorToast(t.dataBackup.unsupportedData);
    } on BackupRestoreIncomplete {
      showErrorToast(t.dataBackup.restoreIncomplete);
    } catch (_) {
      showErrorToast(failureMessage);
    } finally {
      final config = _pendingImport;
      _pendingImport = null;
      if (config != null) _cleanupImportCache(config);
      _setBusy(false);
    }
  }

  Future<void> _exportData() => _protectedAction(
    () => widget.actions.exportBackup?.call(_includeDownloads) ?? _saveBackup(),
    t.dataBackup.exportFailed,
  );

  Future<void> _saveBackup() async {
    if (_includeDownloads) await VideoLocalResources.requirePortableBackup();
    if (!mounted) return;
    final session = await resolveFileBackupProtection(context);
    if (mounted) await _writeBackup(session);
  }

  Future<void> _writeBackup(BackupProtectionSession? session) async {
    // Mobile saves through its system document picker.
    final granted =
        Platform.isIOS || Platform.isAndroid || await requestExportPermission();
    if (!granted) {
      showErrorToast(t.comicInfo.exportPermissionDenied);
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        'Breeze-export-$timestamp.${session == null ? 'zip' : 'breezebackup'}';
    final privateWork = await createPrivateBackupWorkspace();
    late final String zipPath;

    // The mobile picker needs a private staging file until the save finishes.
    if (Platform.isIOS || Platform.isAndroid) {
      zipPath = p.join(privateWork.path, fileName);
    } else {
      String? selectedDir;
      try {
        selectedDir = await getDirectoryPath();
      } catch (e, s) {
        logger.e('选择导出目录失败', error: e, stackTrace: s);
        await privateWork.delete(recursive: true);
        showErrorToast(t.dataBackup.selectExportDirFailed);
        return;
      }

      if (selectedDir == null || selectedDir.trim().isEmpty) {
        await privateWork.delete(recursive: true);
        return;
      }
      zipPath = p.join(selectedDir, fileName);
    }

    if (!mounted) {
      await privateWork.delete(recursive: true);
      return;
    }
    _setBusy(true);
    _showLoadingDialog(t.dataBackup.exporting);
    var loadingOpen = true;
    void closeLoading() {
      if (!loadingOpen || !mounted) return;
      loadingOpen = false;
      Navigator.of(context).pop();
    }

    final plainZip = session == null
        ? zipPath
        : p.join(privateWork.path, 'backup.zip');
    try {
      await exportBreezeBackup(
        zipPath: plainZip,
        includeDownloads: _includeDownloads,
        protectionSession: session,
      );
      if (session != null) await session.encryptFile(plainZip, zipPath);
      if (!mounted) return;
      closeLoading();

      if (Platform.isIOS || Platform.isAndroid) {
        final status = await const MethodChannel(
          'breeze/backup_security',
        ).invokeMethod<String>('exportFile', {'path': zipPath});
        if (status == 'cancelled') return;
        if (status != 'saved') {
          throw const FileSystemException('Backup export did not finish');
        }
        if (mounted)
          showSuccessToast(t.dataBackup.exportSuccess, context: context);
      } else {
        await _showResultDialog(
          t.dataBackup.exportSuccess,
          t.dataBackup.savedTo(path: zipPath),
        );
      }
    } on ComicDownloadTreeBusy {
      closeLoading();
      rethrow;
    } catch (e, s) {
      closeLoading();
      logger.e('导出数据失败', error: e, stackTrace: s);
      showErrorToast(t.dataBackup.exportFailed);
    } finally {
      if (session != null) {
        try {
          await File(plainZip).delete();
        } catch (_) {}
      }
      try {
        await privateWork.delete(recursive: true);
      } catch (_) {}
      _setBusy(false);
    }
  }

  Future<void> _importData() =>
      _protectedAction(_importDataProtected, t.dataBackup.importFailed);

  Future<void> _importDataProtected() async {
    if (!mounted) return;
    final config =
        await (widget.actions.selectBackup?.call(context) ??
            _readSelectedBackup());
    if (config == null) return;
    _pendingImport = config;
    final preview = await _withLoading(t.dataBackup.readingBackup, () async {
      if (widget.actions.inspectBackup != null) {
        return widget.actions.inspectBackup!(config);
      }
      await prepareBreezeBackupImport(config);
      return readOfflineBackupPreview(Directory(config.extractDir));
    });
    if (!mounted) return;
    final draft = await _showImportConfirmDialog(
      preview: preview,
      hasCloudSyncAccount: config.hasCloudSyncAccount,
    );
    if (draft == null || !mounted) return;
    final mode = draft.mode;
    if (mode == BackupImportMode.restore &&
        !await _showReplaceConfirmDialog(preview, draft.options))
      return;
    if (!mounted) return;
    await _withLoading(
      t.dataBackup.importing,
      () =>
          widget.actions.importBackupWithOptions?.call(
            config,
            mode,
            draft.options,
          ) ??
          widget.actions.importBackup?.call(config, mode) ??
          applyBreezeBackupImport(
            config,
            mode: mode,
            options: draft.options,
            globalSettingCubit: context.read<GlobalSettingCubit?>(),
            comicFollowCubit: context.read<ComicFollowCubit?>(),
          ),
    );
    if (mounted) await showPluginCompatibilityNotices(context);
    if (mounted) await _showRestartDialog(mode);
  }

  Future<T> _withLoading<T>(
    String message,
    Future<T> Function() operation,
  ) async {
    _showLoadingDialog(message);
    try {
      return await operation();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<BackupConfig?> _readSelectedBackup() async {
    final path = await _pickImportZipPath();
    if (path == null || !mounted) return null;
    final protected = await BackupProtectionService.isProtectedFile(path);
    if (!protected) {
      return _withLoading(
        t.dataBackup.readingBackup,
        () => readBackupConfig(path, skipCopy: Platform.isAndroid),
      );
    }
    try {
      final profile = await BackupProtectionService.readProfileFromFile(path);
      if (!mounted) return null;
      final session = await unlockFileBackupProtection(context, profile);
      if (session == null) return null;
      try {
        if (!mounted) return null;
        return await _withLoading(
          t.dataBackup.readingBackup,
          () => readProtectedBackupConfig(path, session),
        );
      } finally {
        session.dispose();
      }
    } finally {
      if (Platform.isAndroid) {
        try {
          await Directory(p.dirname(p.dirname(path))).delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  /// 选择要导入的 zip 备份文件。
  ///
  /// Android 上使用原生 MethodChannel 选择器，把文件直接拷贝到应用缓存，
  /// 绕过 [file_selector] 选择大文件时把整个文件读入内存导致的 OOM；
  /// 其他平台继续使用 [file_selector]。
  Future<String?> _pickImportZipPath() async {
    if (Platform.isAndroid) {
      logger.i('Android 平台，使用原生选择器');
      return pickBackupZipAndroid();
    }

    logger.i('非 Android 平台，使用 file_selector');
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'zip',
          extensions: ['zip', 'breezebackup'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    return file?.path;
  }

  void _cleanupImportCache(BackupConfig config) {
    try {
      Directory(config.cacheDir).deleteSync(recursive: true);
    } catch (_) {
    } finally {
      config.releaseWorkspace();
    }
  }

  void _showLoadingDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResultDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 520),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
  }

  Future<_BackupImportDraft?> _showImportConfirmDialog({
    required OfflineBackupPreview preview,
    required bool hasCloudSyncAccount,
  }) async {
    var mode = BackupImportMode.merge;
    var settings = true, plugins = true, cloudAccount = false;
    final count = preview.counts.entries
        .where((e) => e.key != 'downloadTask')
        .fold<int>(0, (sum, row) => sum + row.value);
    return showDialog<_BackupImportDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          key: const ValueKey('backup.import-preview'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          constraints: const BoxConstraints(maxWidth: 520),
          title: Text(t.backupFlow.previewTitle),
          scrollable: true,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.backupFlow.createdAt(
                    value:
                        preview.exportedAt
                            ?.toLocal()
                            .toString()
                            .split('.')
                            .first ??
                        t.backupFlow.unknownDate,
                  ),
                ),
                Text(
                  t.backupFlow.version(
                    value: preview.version.isEmpty
                        ? t.backupFlow.unknownVersion
                        : preview.version,
                  ),
                ),
                Text(t.backupFlow.records(count: count)),
                const SizedBox(height: 12),
                Text(
                  t.backupFlow.importMethod,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                RadioGroup<BackupImportMode>(
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) update(() => mode = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<BackupImportMode>(
                        key: const ValueKey('backup.mode.merge'),
                        contentPadding: EdgeInsets.zero,
                        value: BackupImportMode.merge,
                        title: Text(t.backupFlow.merge),
                        subtitle: Text(t.backupFlow.mergeHint),
                      ),
                      RadioListTile<BackupImportMode>(
                        key: const ValueKey('backup.mode.restore'),
                        contentPadding: EdgeInsets.zero,
                        value: BackupImportMode.restore,
                        title: Text(t.backupFlow.restore),
                        subtitle: Text(t.backupFlow.restoreHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.backupFlow.importContents,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(t.backupFlow.localRecordsHint),
                CheckboxListTile(
                  key: const ValueKey('backup.option.settings'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: settings,
                  onChanged: (value) => update(() => settings = value ?? false),
                  title: Text(t.backupFlow.importSettings),
                  subtitle: Text(t.backupFlow.importSettingsHint),
                ),
                CheckboxListTile(
                  key: const ValueKey('backup.option.plugins'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: plugins,
                  onChanged: (value) => update(() => plugins = value ?? false),
                  title: Text(t.backupFlow.importPlugins),
                  subtitle: Text(t.backupFlow.importPluginsHint),
                ),
                if (hasCloudSyncAccount)
                  CheckboxListTile(
                    key: const ValueKey('backup.option.cloud-account'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: cloudAccount,
                    onChanged: (value) =>
                        update(() => cloudAccount = value ?? false),
                    title: Text(t.backupFlow.restoreCloudAccount),
                    subtitle: Text(t.backupFlow.restoreCloudAccountHint),
                  ),
                const SizedBox(height: 12),
                Text(
                  preview.includeDownloads
                      ? mode == BackupImportMode.restore
                            ? t.backupFlow.restoreFilesHint
                            : t.backupFlow.mergeFilesHint
                      : t.backupFlow.downloadsExcluded,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text(t.common.cancel),
            ),
            TextButton(
              key: const ValueKey('backup.confirm-import'),
              onPressed: () => Navigator.of(dialogContext).pop(
                _BackupImportDraft(
                  mode,
                  BackupImportOptions(
                    importSettings: settings,
                    importPlugins: plugins,
                    importCloudSyncAccount: cloudAccount,
                  ),
                ),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text(
                mode == BackupImportMode.restore
                    ? t.backupFlow.continueImport
                    : t.backupFlow.merge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showReplaceConfirmDialog(
    OfflineBackupPreview preview,
    BackupImportOptions options,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('backup.replace-confirm'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 520),
        title: Text(t.backupFlow.restoreTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.backupFlow.replaceRecordsWarning),
            if (options.importSettings)
              Text(t.backupFlow.replaceSettingsWarning),
            if (options.importPlugins) Text(t.backupFlow.replacePluginsWarning),
            if (options.importCloudSyncAccount)
              Text(t.backupFlow.restoreCloudAccountHint),
            const SizedBox(height: 12),
            Text(
              preview.includeDownloads
                  ? t.backupFlow.restoreFilesHint
                  : t.backupFlow.downloadsExcluded,
            ),
            const SizedBox(height: 12),
            Text(
              options.importCloudSyncAccount
                  ? t.backupFlow.replaceIrreversibleWithCloudAccount
                  : t.backupFlow.replaceIrreversible,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(t.common.cancel),
          ),
          TextButton(
            key: const ValueKey('backup.confirm-replace'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(44, 44),
            ),
            child: Text(t.backupFlow.restore),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showRestartDialog(BackupImportMode mode) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          mode == BackupImportMode.merge
              ? t.backupFlow.mergeDone
              : t.backupFlow.restoreDone,
        ),
        content: Text(t.backupFlow.restart),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
  }
}
