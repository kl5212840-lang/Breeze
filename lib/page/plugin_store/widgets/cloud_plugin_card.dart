import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/utils/plugin_version_utils.dart';
import 'package:zephyr/plugin/utils/plugin_update_channel_utils.dart'
    show parseGetInfoJson;
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

const _pluginIconExtent = 40.0;
const _pluginIconGap = 12.0;

class CloudPluginCard extends StatefulWidget {
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
  State<CloudPluginCard> createState() => _CloudPluginCardState();
}

class _CloudPluginCardState extends State<CloudPluginCard> {
  static const _previewLines = 2;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant CloudPluginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldManifest = oldWidget.item.manifest;
    final manifest = widget.item.manifest;
    if (oldManifest.uuid != manifest.uuid ||
        oldManifest.describe != manifest.describe) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;
    final manifest = item.manifest;
    final localState = manifest.uuid.isNotEmpty
        ? PluginRegistryService.I.getByUuid(manifest.uuid)
        : null;
    final isInstalled = localState != null && !localState.isDeleted;
    final localVersion = localState?.version.trim() ?? '';
    final versionDifference = isInstalled
        ? compareVersion(manifest.version, localVersion)
        : 1;
    final canDownload =
        PluginInstallService.I.cloudBatchActionFor(item) ==
        (isInstalled
            ? CloudPluginBatchAction.update
            : CloudPluginBatchAction.install);
    final canReinstall =
        isInstalled &&
        widget.onReinstall != null &&
        item.canReinstallFromCloud(
          parseGetInfoJson(
            PluginRegistryService.I.readPersistedGetInfoJson(manifest.uuid),
          ),
        );
    final cloudVersion = manifest.version.trim();
    final description = manifest.describe.trim();
    final descriptionStyle = DefaultTextStyle.of(
      context,
    ).style.merge(theme.textTheme.bodySmall);
    final metadata = [
      if (isInstalled && !canDownload)
        if (versionDifference < 0)
          t.plugin.localVersionNewer
        else if (versionDifference == 0 && localVersion.isNotEmpty)
          t.plugin.alreadyLatest
        else
          t.plugin.installed,
      if (isInstalled && localVersion.isNotEmpty)
        if (cloudVersion == localVersion)
          localVersion
        else
          t.plugin.localVersion(version: localVersion),
      if (cloudVersion.isNotEmpty &&
          (!isInstalled || cloudVersion != localVersion))
        t.plugin.cloudVersion(version: cloudVersion),
    ].join(' · ');
    final actionExtent = CollectionToolbarMetrics.actionExtentOf(context);
    final actionStyle = theme.textTheme.labelLarge;
    const actionPadding = 14.0;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    );
    var actionWidth = actionExtent;
    for (final label in [t.plugin.install, t.plugin.update]) {
      painter.text = TextSpan(text: label, style: actionStyle);
      painter.layout();
      final width = painter.width.ceilToDouble() + actionPadding * 2;
      if (width > actionWidth) actionWidth = width;
    }
    painter.dispose();
    final action = FilledButton.tonal(
      key: const ValueKey('cloud-plugin-card.action'),
      onPressed: !canDownload || widget.installing ? null : widget.onInstall,
      style: FilledButton.styleFrom(
        minimumSize: Size(actionWidth, actionExtent),
        padding: const EdgeInsets.symmetric(
          horizontal: actionPadding,
          vertical: 8,
        ),
        textStyle: actionStyle,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      child: Text(isInstalled ? t.plugin.update : t.plugin.install),
    );
    final more = _buildMoreMenu(actionExtent, localVersion, canReinstall);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        action,
        if (more != null) ...[
          const SizedBox(width: CollectionToolbarMetrics.searchControlGap),
          more,
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trailingAction =
              constraints.maxWidth >= 324 &&
              constraints.maxWidth - actionWidth >= 254 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final summary = _buildSummary(
            description: description,
            descriptionStyle: descriptionStyle,
            metadata: metadata,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CloudPluginIcon(iconUrl: manifest.iconUrl),
                  const SizedBox(width: _pluginIconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trailingAction) summary,
                      ],
                    ),
                  ),
                  if (trailingAction) ...[
                    const SizedBox(
                      width: CollectionToolbarMetrics.searchControlGap,
                    ),
                    actions,
                  ],
                ],
              ),
              if (!trailingAction) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: actions,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _pluginIconExtent + _pluginIconGap,
                  ),
                  child: summary,
                ),
              ],
              if (_expanded)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: trailingAction
                        ? _pluginIconExtent + _pluginIconGap
                        : 0,
                    top: 8,
                  ),
                  child: Text(
                    description,
                    style: descriptionStyle.copyWith(height: 1.5),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget? _buildMoreMenu(
    double actionExtent,
    String localVersion,
    bool canReinstall,
  ) {
    final item = widget.item;
    final manifest = item.manifest;
    final home = manifest.home.trim();
    final repository = item.githubRepositoryUrl;
    if (home.isEmpty && repository.isEmpty && !canReinstall) return null;

    return NativeVideoMenu(
      key: ValueKey((
        home,
        repository,
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
        if (!widget.installing) ...{
          if (home.isNotEmpty) 'homepage': t.plugin.homepage,
          if (repository.isNotEmpty) 'repository': t.plugin.githubRepo,
          if (canReinstall) 'reinstall': t.pluginLifecycle.reinstall,
        },
      },
      optionIcons: const {
        'homepage': (icon: Icons.language_outlined, symbol: 'globe'),
        'repository': (
          icon: Icons.code_rounded,
          symbol: 'chevron.left.forwardslash.chevron.right',
        ),
        'reinstall': (icon: Icons.refresh, symbol: 'arrow.clockwise'),
      },
      selectAfterDismissal: const {'homepage', 'repository', 'reinstall'},
      onSelected: (command) {
        if (widget.installing) return;
        switch (command) {
          case 'homepage':
            widget.onOpenHome(home);
          case 'repository':
            widget.onOpenHome(repository);
          case 'reinstall':
            if (canReinstall) widget.onReinstall?.call(localVersion);
        }
      },
      hostTriggerBuilder: (context, onPressed) => IconButton(
        onPressed: onPressed,
        tooltip: t.common.more,
        icon: const Icon(Icons.more_horiz, size: 20),
        style: IconButton.styleFrom(
          minimumSize: Size.square(actionExtent),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSummary({
    required String description,
    required TextStyle descriptionStyle,
    required String metadata,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final preview = TextPainter(
          text: TextSpan(text: description, style: descriptionStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: _previewLines,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        final showDisclosure = _expanded || preview.didExceedMaxLines;
        preview.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty && !_expanded) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: descriptionStyle,
                maxLines: _previewLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (metadata.isNotEmpty || showDisclosure) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (metadata.isNotEmpty)
                    Text(
                      metadata,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (showDisclosure)
                    Semantics(
                      expanded: _expanded,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          textStyle: theme.textTheme.labelMedium,
                          minimumSize: Size.square(
                            CollectionToolbarMetrics.actionExtentOf(context),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                        ),
                        child: Text(
                          _expanded
                              ? t.comicInfo.collapse
                              : t.comicInfo.expandFullText,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
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
        width: _pluginIconExtent,
        height: _pluginIconExtent,
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
