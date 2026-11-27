import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:auto_route/auto_route.dart';
import 'package:zephyr/plugin/utils/plugin_local_file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_store/cubit/plugin_store_cubit.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/page/plugin_store/widgets/cloud_plugin_card.dart';
import 'package:zephyr/page/plugin_store/widgets/plugin_store_status_banner.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class PluginStorePage extends StatelessWidget {
  const PluginStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginStoreCubit()..loadCloudPlugins(),
      child: const _PluginStorePageContent(),
    );
  }
}

class _PluginStorePageContent extends StatefulWidget {
  const _PluginStorePageContent();

  @override
  State<_PluginStorePageContent> createState() =>
      _PluginStorePageContentState();
}

class _PluginStorePageContentState extends State<_PluginStorePageContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginStoreCubit, PluginStoreState>(
      builder: (context, state) {
        return Scaffold(
          appBar: sourceSecondaryAppBar(
            context,
            title: t.plugin.store,
            actions: [_buildImportMenu(state.installing)],
          ),
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(
                    CollectionToolbarMetrics.sourceContentInset,
                  ),
                  children: [
                    _buildSearchCard(context, state.installing),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: PluginRegistryService.I.stream,
                      builder: (context, _) => _buildCloudPluginsSection(state),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchCard(BuildContext context, bool installing) {
    return SearchFieldSurface(
      child: TextField(
        controller: _searchController,
        enabled: !installing,
        decoration: searchFieldDecoration(
          context,
          hintText: t.plugin.searchHint,
        ),
      ),
    );
  }

  Widget _buildImportMenu(bool installing) {
    final label = t.common.import;
    return NativeVideoMenu(
      label: label,
      tooltip: label,
      selected: '',
      options: {
        if (!installing) ...{
          'local': t.plugin.localInstall,
          'network': t.plugin.networkInstall,
        },
      },
      optionIcons: const {
        'local': (icon: Icons.folder_open_outlined, symbol: 'folder'),
        'network': (icon: Icons.language_outlined, symbol: 'globe'),
      },
      noPageDimming: true,
      selectAfterDismissal: const {'local', 'network'},
      onSelected: (action) {
        if (context.read<PluginStoreCubit>().state.installing) return;
        if (action == 'local') _installFromLocal();
        if (action == 'network') _installFromNetwork();
      },
      hostTriggerBuilder: (context, onPressed) => SourceChromeIconButton(
        tooltip: label,
        bare: !usesSystemSourceChrome(context),
        icon: Icons.file_download_outlined,
        symbol: 'square.and.arrow.down',
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCloudPluginsSection(PluginStoreState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final displayPlugins = state.cloudPlugins.where((item) {
      if (query.isEmpty) return true;
      final name = item.manifest.name.toLowerCase();
      final description = item.manifest.describe.toLowerCase();
      final repo = item.repo.split('/').last.toLowerCase();
      return name.contains(query) ||
          description.contains(query) ||
          repo.contains(query);
    }).toList();

    final hasData = state.cloudPlugins.isNotEmpty;
    final candidates = context.read<PluginStoreCubit>().cloudBatchCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  t.plugin.cloudComponents,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(width: CollectionToolbarMetrics.searchControlGap),
            SourceChromeIconButton(
              tooltip: t.common.refresh,
              bare: true,
              busy: state.cloudLoading,
              onPressed: state.cloudLoading || state.installing
                  ? null
                  : context.read<PluginStoreCubit>().loadCloudPlugins,
              icon: Icons.refresh_rounded,
              symbol: 'arrow.clockwise',
            ),
          ],
        ),
        const SizedBox(height: CollectionToolbarMetrics.searchControlGap),
        _buildCloudBatchButtons(
          candidates,
          showCounts:
              !state.cloudLoading &&
              !state.installing &&
              (hasData || state.cloudError.trim().isEmpty),
        ),
        const SizedBox(height: 12),
        if (state.installing && state.installMessage.isNotEmpty) ...[
          PluginStoreStatusBanner(message: state.installMessage),
          const SizedBox(height: 12),
        ],
        if (state.cloudLoading && !hasData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.cloudError.trim().isNotEmpty && !hasData)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.cloudError,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.cloudLoading || state.installing
                      ? null
                      : context.read<PluginStoreCubit>().loadCloudPlugins,
                  icon: const Icon(Icons.refresh),
                  label: Text(t.common.retry),
                ),
              ],
            ),
          )
        else if (!hasData)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t.plugin.noCloudPlugins,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          )
        else if (displayPlugins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t.plugin.noMatchingPlugins,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          )
        else
          Column(
            children: displayPlugins
                .map(
                  (item) => CloudPluginCard(
                    key: ValueKey(item.manifest.uuid),
                    item: item,
                    installing: state.installing,
                    onOpenHome: _openExternalUrl,
                    onInstall: () =>
                        context.read<PluginStoreCubit>().installFromCloud(item),
                    onReinstall: (localVersion) =>
                        _confirmCloudReinstall(item, localVersion),
                  ),
                )
                .toList(),
          ),
        if (state.cloudError.trim().isNotEmpty && hasData) ...[
          const SizedBox(height: 8),
          Text(
            state.cloudError,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildCloudBatchButtons(
    Map<CloudPluginBatchAction, List<CloudPluginItem>> candidates, {
    required bool showCounts,
  }) {
    final updates = candidates[CloudPluginBatchAction.update]!;
    final installs = candidates[CloudPluginBatchAction.install]!;
    const shape = StadiumBorder();
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 4);
    final minimumSize = Size.square(
      CollectionToolbarMetrics.actionExtentOf(context),
    );
    const gap = CollectionToolbarMetrics.searchControlGap;
    const labelKey = ValueKey('plugin-store-batch-actions');
    final detailStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    Widget label(String title, String detail) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, textAlign: TextAlign.center),
        if (showCounts)
          Text(
            detail,
            textAlign: TextAlign.center,
            style: detailStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    final update = FilledButton.tonal(
      style: FilledButton.styleFrom(
        shape: shape,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      onPressed: updates.isEmpty
          ? null
          : () => _confirmCloudBatch(CloudPluginBatchAction.update, updates),
      child: label(
        t.plugin.cloudUpdateAll,
        updates.isEmpty
            ? t.plugin.cloudNoUpdates
            : t.plugin.cloudUpdateCount(count: updates.length),
      ),
    );
    final install = OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: shape,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      onPressed: installs.isEmpty
          ? null
          : () => _confirmCloudBatch(CloudPluginBatchAction.install, installs),
      child: label(
        t.plugin.cloudInstallAll,
        installs.isEmpty
            ? t.plugin.cloudNoInstalls
            : t.plugin.cloudInstallCount(count: installs.length),
      ),
    );
    return Align(
      key: labelKey,
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 288 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [update, install],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  Expanded(child: update),
                  Expanded(child: install),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _cloudBatchLabel(CloudPluginBatchAction action) =>
      action == CloudPluginBatchAction.update
      ? t.plugin.cloudUpdateAll
      : t.plugin.cloudInstallAll;

  Future<void> _confirmCloudBatch(
    CloudPluginBatchAction action,
    List<CloudPluginItem> items,
  ) async {
    final store = context.read<PluginStoreCubit>();
    final label = _cloudBatchLabel(action);
    final updating = action == CloudPluginBatchAction.update;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(label),
        content: Text(
          updating
              ? t.plugin.confirmCloudUpdateAll(count: items.length)
              : t.plugin.confirmCloudInstallAll(count: items.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(updating ? t.plugin.update : t.plugin.install),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final result = await store.installCloudBatch(action, items);
    if (!mounted || result == null || result.failures.isEmpty) return;
    if (ModalRoute.of(context)?.isCurrent == false) {
      showWarningToast(result.message);
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.plugin.cloudBatchFailureTitle),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            for (final failure in result.failures)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${failure.plugin}\n${failure.reason}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t.common.done),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloudReinstall(
    CloudPluginItem item,
    String localVersion,
  ) async {
    final store = context.read<PluginStoreCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.pluginLifecycle.reinstall),
        content: Text(
          t.plugin.confirmCloudReinstall(
            name: item.displayName,
            local: localVersion,
            cloud: item.manifest.version,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.pluginLifecycle.reinstall),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await store.installFromCloud(item, reinstall: true);
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final resolved = rawUrl.trim();
    if (resolved.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      showErrorToast(t.plugin.invalidLink(url: resolved));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      showErrorToast(t.plugin.cannotOpenLink(url: resolved));
    }
  }

  Future<void> _installFromLocal() async {
    try {
      final file = await pickPluginScriptFile();
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      await context.read<PluginStoreCubit>().installFromLocalBytes(
        bytes,
        fileName: file.name,
      );
    } catch (e) {
      showErrorToast(t.plugin.readLocalPluginFailed(error: e.toString()));
    }
  }

  Future<void> _installFromNetwork() async {
    final url = await _showInputDialog(
      context,
      title: t.plugin.addFromNetwork,
      hintText: t.plugin.networkInstallHint,
    );
    if (url == null) {
      return;
    }

    final resolvedUrl = url.trim();
    if (resolvedUrl.isEmpty) {
      showErrorToast(t.plugin.urlCannotBeEmpty);
      return;
    }

    if (!mounted) {
      return;
    }
    await context.read<PluginStoreCubit>().installFromNetworkUrl(resolvedUrl);
  }

  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required String hintText,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(t.plugin.startInstall),
          ),
        ],
      ),
    );
  }
}
