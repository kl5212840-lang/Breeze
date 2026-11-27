import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/full_cloud_replace.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/page/setting/common/backup_protection_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/widgets/short_alert.dart';

class FullCloudReplacePage extends StatefulWidget {
  const FullCloudReplacePage({super.key, this.createService});
  final FullCloudReplaceService Function()? createService;
  @override
  State<FullCloudReplacePage> createState() => _FullCloudReplacePageState();
}

class _FullCloudReplacePageState extends State<FullCloudReplacePage> {
  FullCloudReplaceService? _service;
  FullCloudReplacePlan? _plan;
  bool _busy = false,
      _committing = false,
      _confirming = false,
      _complete = false;
  String? _error;

  Future<void> _preview() async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _error = null;
      _plan = null;
      _complete = false;
    });
    try {
      _service =
          widget.createService?.call() ??
          FullCloudReplaceService.fromState(
            () => context.read<GlobalSettingCubit>().state,
          );
      final plan = await retryWithLegacyBackupAccess(
        context,
        _service!.preview,
      );
      if (mounted && plan != null) setState(() => _plan = plan);
    } catch (error) {
      if (mounted) setState(() => _error = _failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final plan = _plan, service = _service;
    if (_busy || _confirming || plan == null || service == null) return;
    setState(() => _confirming = true);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ShortAlert(
          title: Text(t.settings.cloudReplaceConfirmTitle),
          content: Text(t.settings.cloudReplaceConfirmHint),
          actions: [
            ShortAlertAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.common.cancel),
            ),
            ShortAlertAction(
              destructive: true,
              key: const ValueKey('cloud-replace.final-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.settings.cloudReplaceConfirm),
            ),
          ],
        ),
      );
      if (accepted != true ||
          !mounted ||
          ModalRoute.of(context)?.isCurrent != true)
        return;
      setState(() {
        _busy = true;
        _committing = true;
        _error = null;
      });
      try {
        await service.commit(plan);
        if (mounted)
          setState(() {
            _plan = null;
            _complete = true;
          });
      } catch (error) {
        if (mounted)
          setState(() {
            _plan = null;
            _error = _failureText(error);
          });
      }
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _committing = false;
          _confirming = false;
        });
    }
  }

  String _failureText(Object error) {
    if (error is FullCloudReplaceStale) return t.settings.cloudReplaceStale;
    if (error is FullCloudReplaceFailure) {
      if (error.mayHaveChanged) return t.settings.cloudReplacePartial;
      return _failureText(error.cause);
    }
    if (error is BackupProtectionException) return backupProtectionError(error);
    if (error is SyncCompatibilityException) return error.toString();
    return switch (classifySyncFailure(error)) {
      SyncFailureKind.timeout => t.settings.syncTimeout,
      SyncFailureKind.connection => t.settings.syncConnectionFailed,
      SyncFailureKind.secureConnection => t.settings.syncSecureConnectionFailed,
      SyncFailureKind.storage => t.settings.syncStorageFailed,
      SyncFailureKind.format => t.settings.syncFormatFailed,
      SyncFailureKind.noCloudBackup => t.settings.syncNoCloudBackup,
      SyncFailureKind.unknown => t.settings.manualSyncFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final inset = SettingSection.horizontalInsetOf(context);
    final theme = Theme.of(context);
    final summaryStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titles = {
      'comic': t.settings.cloudReplaceComic,
      'video': t.settings.cloudReplaceVideo,
      'plugins': t.settings.cloudReplacePlugins,
      'preferences': t.settings.cloudReplacePreferences,
      'images': t.settings.cloudReplaceImages,
    };
    return PopScope(
      canPop: !_committing,
      child: SettingPageShell(
        grouped: true,
        title: t.settings.cloudReplaceTitle,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (!_complete && plan == null)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 12, inset, 4),
                child: Text(t.settings.cloudReplaceScope, style: summaryStyle),
              ),
            if (_complete)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  t.settings.cloudReplaceSuccess,
                  key: const ValueKey('cloud-replace.success'),
                ),
              ),
            if (plan != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 12, inset, 8),
                child: Text(
                  t.settings.cloudReplaceArchives(
                    current: plan.currentFiles,
                    legacy: plan.legacyFiles,
                  ),
                  style: summaryStyle,
                ),
              ),
              SettingSection(
                hasLeading: false,
                margin: EdgeInsets.symmetric(horizontal: inset),
                children: [
                  for (final entry in plan.counts.entries)
                    ListTile(
                      title: Text(titles[entry.key]!),
                      subtitle: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              t.settings.cloudReplaceLocalCount(
                                count: entry.value.local,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.settings.cloudReplaceRemovedCount(
                                count: entry.value.removed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.settings.cloudReplaceOverwrittenCount(
                                count: entry.value.overwritten,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Text(
                  _error!,
                  key: const ValueKey('cloud-replace.error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _committing
                              ? t.settings.cloudReplaceWriting
                              : t.settings.cloudReplaceReading,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_complete && !_busy)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
                child: plan == null
                    ? FilledButton(
                        key: const ValueKey('cloud-replace.preview'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _confirming ? null : _preview,
                        child: Text(t.settings.cloudReplacePreview),
                      )
                    : OutlinedButton(
                        key: const ValueKey('cloud-replace.confirm'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: _confirming ? null : _confirm,
                        child: Text(t.settings.cloudReplaceReview),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
