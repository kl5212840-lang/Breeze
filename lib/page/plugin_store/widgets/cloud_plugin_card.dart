import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/plugin_version_utils.dart';
import 'package:zephyr/plugin/utils/plugin_update_channel_utils.dart'
    show parseGetInfoJson;
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

final _installedScriptHashes = Expando<String>();

class CloudPluginCard extends StatelessWidget {
  const CloudPluginCard({
    super.key,
    required this.item,
    required this.installing,
    required this.onOpenHome,
    required this.onInstall,
    this.onReinstall,
  });

  final CloudPluginItem item;
  final bool installing;
  final ValueChanged<String> onOpenHome;
  final VoidCallback onInstall;
  final ValueChanged<String>? onReinstall;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final manifest = item.manifest;
    final localState = manifest.uuid.isNotEmpty
        ? PluginRegistryService.I.getByUuid(manifest.uuid)
        : null;
    final isInstalled = localState != null && !localState.isDeleted;
    final localVersion = localState?.version.trim() ?? '';
    final versionDifference = isInstalled
        ? compareVersion(manifest.version, localVersion)
        : 1;
    final migration = isInstalled
        ? item.formalRelease?.migrationFor(
            installedUuid: localState.uuid,
            installedVersion: localVersion,
            scriptFingerprint: () => _installedScriptHashes[localState] ??=
                publishedPluginScriptSha256(localState.originScript),
          )
        : null;
    final canDownload =
        !isInstalled ||
        migration != null ||
        (versionDifference > 0 &&
            preservesFormalPluginChannel(
              installedInfo: PluginRegistryService.I.getCachedPluginInfo(
                manifest.uuid,
              ),
              updateUrl: manifest.updateUrl,
              npmName: manifest.npmName,
            ));
    final downloadLabel = !isInstalled
        ? t.plugin.download
        : canDownload
        ? t.plugin.downloadUpdate
        : versionDifference < 0
        ? t.plugin.localVersionNewer
        : t.plugin.alreadyLatest;
    final title = manifest.name.trim().isNotEmpty
        ? manifest.name.trim()
        : item.repo.split('/').last.trim();
    final canReinstall =
        isInstalled &&
        onReinstall != null &&
        item.canReinstallFromCloud(
          parseGetInfoJson(
            PluginRegistryService.I.readPersistedGetInfoJson(manifest.uuid),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CloudPluginIcon(iconUrl: manifest.iconUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (isInstalled) ...[
                          const SizedBox(width: 8),
                          const _InstalledChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInstalled && localVersion.isNotEmpty
                          ? '${t.plugin.cloudVersion(version: manifest.version)}  ·  ${t.plugin.localVersion(version: localVersion)}'
                          : t.plugin.cloudVersion(version: manifest.version),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (manifest.describe.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        manifest.describe.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (manifest.home.trim().isNotEmpty)
                _CloudTextAction(
                  label: t.plugin.homepage,
                  onTap: installing
                      ? null
                      : () => onOpenHome(manifest.home.trim()),
                ),
              if (item.githubRepositoryUrl.isNotEmpty)
                _CloudTextAction(
                  label: t.plugin.githubRepo,
                  onTap: installing
                      ? null
                      : () => onOpenHome(item.githubRepositoryUrl),
                ),
              _CloudTextAction(
                label: downloadLabel,
                onTap: installing || !canDownload ? null : onInstall,
              ),
              if (canReinstall)
                NativeVideoMenu(
                  key: ValueKey((
                    item.repo,
                    manifest.version,
                    manifest.updateUrl,
                    manifest.npmName,
                    manifest.scriptSha256,
                    localVersion,
                  )),
                  label: '',
                  tooltip: t.common.more,
                  selected: '',
                  hostPresentation: true,
                  noPageDimming: true,
                  options: {
                    if (!installing) 'reinstall': t.pluginLifecycle.reinstall,
                  },
                  optionIcons: const {
                    'reinstall': (
                      icon: Icons.refresh,
                      symbol: 'arrow.clockwise',
                    ),
                  },
                  selectAfterDismissal: const {'reinstall'},
                  onSelected: (_) {
                    if (!installing) onReinstall!(localVersion);
                  },
                  hostTriggerBuilder: (context, onPressed) => IconButton(
                    onPressed: onPressed,
                    tooltip: t.common.more,
                    icon: const Icon(Icons.more_horiz, size: 20),
                    style: _cloudActionStyle(context, iconOnly: true),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

ButtonStyle _cloudActionStyle(BuildContext context, {bool iconOnly = false}) {
  final theme = Theme.of(context);
  return OutlinedButton.styleFrom(
    minimumSize: const Size(44, 44),
    alignment: Alignment.center,
    padding: iconOnly
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    backgroundColor: theme.colorScheme.surfaceContainerLow,
    foregroundColor: theme.colorScheme.primary,
    disabledBackgroundColor: theme.colorScheme.surfaceContainerLow,
    disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: .38),
    side: iconOnly
        ? BorderSide(color: theme.colorScheme.outline.withValues(alpha: .55))
        : null,
    textStyle: theme.textTheme.labelMedium,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

/// Body actions use standard press, hover, focus and disabled feedback.
class _CloudTextAction extends StatelessWidget {
  const _CloudTextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: _cloudActionStyle(context),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _InstalledChip extends StatelessWidget {
  const _InstalledChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            t.plugin.installed,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudPluginIcon extends StatelessWidget {
  const _CloudPluginIcon({required this.iconUrl});

  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        color: colorScheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: PluginIcon(
          url: iconUrl,
          placeholder: Icon(
            Icons.extension_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
