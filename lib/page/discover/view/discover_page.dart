import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/discover/view/plugin_order_dialog.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiscoverCubit()..load(),
      child: const _DiscoverView(),
    );
  }
}

enum _DiscoverLayout { list, grid }

class _DiscoverView extends StatefulWidget {
  const _DiscoverView();

  @override
  State<_DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<_DiscoverView> {
  static const _layoutPreferenceKey = 'discover_plugin_layout_v1';
  final ScrollController _scrollController = ScrollController();
  _DiscoverLayout _layout = _DiscoverLayout.list;
  bool _layoutChangedByUser = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || _layoutChangedByUser) return;
      setState(() {
        _layout = preferences.getString(_layoutPreferenceKey) == 'grid'
            ? _DiscoverLayout.grid
            : _DiscoverLayout.list;
      });
    } catch (_) {
      // The in-memory layout remains usable when local preferences are absent.
    }
  }

  Future<void> _setLayout(_DiscoverLayout layout) async {
    if (_layout == layout) return;
    _layoutChangedByUser = true;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _layout = layout);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_layoutPreferenceKey, layout.name);
    } catch (_) {
      // Keep the selected view for this session even if persistence fails.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.discover.title),
        actions: [
          IconButton(
            tooltip: t.discover.customOrder,
            icon: const Icon(Icons.reorder),
            onPressed: () => showPluginOrderDialog(context),
          ),
          IconButton(
            tooltip: t.discover.search,
            icon: const Icon(Icons.search),
            onPressed: () => _search(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: RefreshIndicator(
        onRefresh: () => context.read<DiscoverCubit>().reload(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildPluginHome(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPluginHome(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      builder: (context, state) {
        final plugins = state.plugins.values.toList();

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildPluginStoreButton(context),
                  _buildSectionHeader(context, t.discover.pluginManagement),
                ],
              ),
            ),
            if (plugins.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      t.discover.noPlugins,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else if (_layout == _DiscoverLayout.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverGrid.builder(
                  itemCount: plugins.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisExtent: MediaQuery.textScalerOf(context).scale(160),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) => _buildPluginEntry(
                    context,
                    plugins[index],
                    state,
                    grid: true,
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: plugins.length,
                itemBuilder: (context, index) => _buildPluginEntry(
                  context,
                  plugins[index],
                  state,
                  grid: false,
                ),
              ),
            if (plugins.isNotEmpty)
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }

  Widget _buildPluginEntry(
    BuildContext context,
    PluginRuntimeState plugin,
    DiscoverState state, {
    required bool grid,
  }) {
    final cubit = context.read<DiscoverCubit>();
    final infoState =
        state.infoStates[plugin.uuid] ??
        const DiscoverPluginInfoState(loading: true);
    final info = infoState.data;
    final sections = info == null
        ? const <SourceShellSection>[]
        : SourceShellSection.fromPluginInfo(info, plugin.uuid);

    final onOpen =
        !plugin.isEnabled || !SourceShellSection.canLaunch(info, sections)
        ? null
        : () => context.pushRoute(
            SourceShellRoute(
              source: plugin.uuid,
              sourceName: info?['name']?.toString().trim().isNotEmpty == true
                  ? info!['name'].toString().trim()
                  : t.discover.pluginCapability,
              sections: sections,
            ),
          );
    Future<void> onAction(Map<String, dynamic> action) => DiscoverRouter.route(
      context,
      action: DiscoverRouter.attachSource(action, plugin.uuid),
      currentFrom: cubit.currentFrom,
    );
    if (grid) {
      return PluginGridTile(
        key: ValueKey(plugin.uuid),
        pluginState: plugin,
        infoState: infoState,
        isToggling: state.togglingUuids.contains(plugin.uuid),
        onSearch: () => _openPluginSearch(context, plugin.uuid),
        onOpen: onOpen,
        onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
        onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
        onRetry: () => cubit.retryLoadInfo(plugin.uuid),
        onAction: onAction,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: PluginCard(
        pluginUuid: plugin.uuid,
        pluginState: plugin,
        infoState: infoState,
        isToggling: state.togglingUuids.contains(plugin.uuid),
        onSearch: () => _openPluginSearch(context, plugin.uuid),
        onOpen: onOpen,
        onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
        onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
        onRetry: () => cubit.retryLoadInfo(plugin.uuid),
        onAction: onAction,
      ),
    );
  }

  Widget _buildPluginStoreButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.pushRoute(const PluginStoreRoute()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 24,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.discover.pluginStore,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.discover.browseInstall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SegmentedButton<_DiscoverLayout>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            segments: [
              ButtonSegment(
                value: _DiscoverLayout.list,
                icon: const Icon(Icons.view_agenda_outlined, size: 18),
                label: Text(t.discover.listLayout),
              ),
              ButtonSegment(
                value: _DiscoverLayout.grid,
                icon: const Icon(Icons.grid_view_outlined, size: 18),
                label: Text(t.discover.gridLayout),
              ),
            ],
            selected: {_layout},
            onSelectionChanged: (selection) => _setLayout(selection.first),
          ),
        ],
      ),
    );
  }

  void _openPluginSearch(BuildContext context, String from) {
    final source = from.trim();
    if (source.isEmpty) {
      showErrorToast(t.error.missingPluginSource(action: t.discover.search));
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: false,
      ),
    );
  }

  void _openPluginSettings(BuildContext context, String uuid, String title) {
    context.pushRoute(
      PluginSettingsRoute(
        from: uuid,
        pluginUuid: uuid,
        pluginRuntimeName: uuid,
        pluginDisplayName: title,
      ),
    );
  }

  void _search(BuildContext context) {
    final cubit = context.read<DiscoverCubit>();
    final source = cubit.currentFrom;
    if (source.isEmpty) {
      showErrorToast(t.discover.noPluginForSearch);
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: true,
      ),
    );
  }
}
