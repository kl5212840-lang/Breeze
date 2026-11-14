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
          appBar: AppBar(
            leading: const SourceBackButton(),
            title: Text(t.plugin.store),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSearchCard(context, state.installing),
                  const SizedBox(height: 14),
                  _buildInstallButtons(state.installing),
                  const SizedBox(height: 16),
                  _buildCloudPluginsSection(state),
                ],
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

  Widget _buildInstallButtons(bool installing) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            alignment: Alignment.center,
          ),
          onPressed: installing ? null : _installFromLocal,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(t.plugin.localInstall),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            alignment: Alignment.center,
          ),
          onPressed: installing ? null : _installFromNetwork,
          icon: const Icon(Icons.language_outlined, size: 18),
          label: Text(t.plugin.networkInstall),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.installing) ...[
          PluginStoreStatusBanner(message: state.installMessage),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Icon(Icons.cloud_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.plugin.cloudComponents,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SourceChromeIconButton(
              tooltip: t.common.refresh,
              busy: state.cloudLoading,
              onPressed: state.cloudLoading
                  ? null
                  : context.read<PluginStoreCubit>().loadCloudPlugins,
              icon: Icons.refresh_rounded,
              symbol: 'arrow.clockwise',
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                  onPressed: state.cloudLoading
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

  Future<void> _confirmCloudReinstall(
    CloudPluginItem item,
    String localVersion,
  ) async {
    final store = context.read<PluginStoreCubit>();
    final name = item.manifest.name.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(t.pluginLifecycle.reinstall),
        content: Text(
          t.plugin.confirmCloudReinstall(
            name: name.isEmpty ? item.repo.split('/').last : name,
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
