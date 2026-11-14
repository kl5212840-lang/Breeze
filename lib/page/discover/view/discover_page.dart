import 'dart:async';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';
import 'package:zephyr/page/discover/view/plugin_management_island.dart';
import 'package:zephyr/page/discover/service/discover_plugin_management.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/discover/widgets/plugin_grid_tile.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';

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
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();
  final _visibility = DiscoverPluginVisibility();
  _DiscoverLayout _layout = _DiscoverLayout.list;
  bool _layoutChangedByUser = false;
  bool _managementOpen = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
    _visibility.addListener(_visibilityChanged);
    _loadVisibility();
  }

  void _visibilityChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadVisibility() async {
    try {
      await _visibility.load();
    } catch (_) {
      // A read failure keeps the explicit retry state; do not flash plugins
      // that the user may have deliberately hidden.
    }
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
    _visibility.removeListener(_visibilityChanged);
    _visibility.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.discover.title),
        actions: [
          SourceChromeIconButton(
            tooltip: t.discover.search,
            icon: Icons.search,
            symbol: 'magnifyingglass',
            onPressed: () => _search(context),
          ),
          VideoControlAppearance(
            systemControls: usesNativeSourceChrome(context),
            child: NativeVideoMenu(
              label: '',
              tooltip: t.common.more,
              selected: '',
              width: 44,
              light: false,
              icon: Icons.more_horiz,
              symbol: 'ellipsis',
              hostPresentation: true,
              options: {'manage': t.discover.pluginManagement},
              selectAfterDismissal: const {'manage'},
              optionIcons: const {
                'manage': (icon: Icons.tune, symbol: 'slider.horizontal.3'),
              },
              onSelected: (action) {
                if (action == 'manage') _showManagement(context);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: PullRefreshFeedback.indicator(
        indicatorKey: _refreshIndicator,
        onRefresh: () async {
          final cubit = context.read<DiscoverCubit>();
          final reloaded = await cubit.reload();
          if (!context.mounted || cubit.isClosed || !reloaded) {
            // Cold card failures and retained metadata each have an inline retry.
            return PullRefreshResult.ignored;
          }
          return PullRefreshResult.checked;
        },
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
    if (!_visibility.loaded) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPluginStoreButton(context),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: _visibility.loadError == null
                  ? const CircularProgressIndicator()
                  : VideoControlAppearance(
                      systemControls: usesNativeSourceChrome(context),
                      child: NativeVideoTextButton(
                        onPressed: _loadVisibility,
                        light: false,
                        label: t.common.retry,
                        tooltip: t.common.retry,
                      ),
                    ),
            ),
          ),
        ],
      );
    }
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      builder: (context, state) {
        final plugins = state.plugins.values
            .where((plugin) => _visibility.isVisible(plugin.uuid))
            .toList();

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (context.read<DiscoverCubit>().refreshError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(t.common.refreshRetained)),
                      TextButton.icon(
                        key: const ValueKey('discover.refresh-retry'),
                        onPressed: context.read<DiscoverCubit>().refreshing
                            ? null
                            : () => _refreshIndicator.currentState?.show(),
                        icon: const Icon(Icons.refresh),
                        label: Text(t.common.retry),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildPluginStoreButton(context),
                  _buildSectionHeader(context, t.discover.visiblePlugins),
                ],
              ),
            ),
            if (plugins.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.plugins.isEmpty
                              ? t.discover.noPlugins
                              : t.discover.allPluginsHidden,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (state.plugins.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          VideoControlAppearance(
                            systemControls: usesNativeSourceChrome(context),
                            child: NativeVideoTextButton(
                              onPressed: () => _showManagement(context),
                              light: false,
                              label: t.discover.pluginManagement,
                              tooltip: t.discover.pluginManagement,
                            ),
                          ),
                        ],
                      ],
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
                    mainAxisExtent:
                        114 + 2 * MediaQuery.textScalerOf(context).scale(16),
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
                  first: index == 0,
                  last: index == plugins.length - 1,
                ),
              ),
            if (plugins.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(height: 28 + NativeNavigationInset.of(context)),
              ),
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
    bool first = false,
    bool last = false,
  }) {
    final cubit = context.read<DiscoverCubit>();
    final infoState =
        state.infoStates[plugin.uuid] ??
        const DiscoverPluginInfoState(loading: true);
    final info = infoState.data;
    final sections = info == null
        ? const <SourceShellSection>[]
        : SourceShellSection.fromPluginInfo(info, plugin.uuid);

    final functions = asJsonList(
      info?['functions'] ?? info?['function'] ?? const <dynamic>[],
    ).map(asJsonMap).toList();
    final webAction = functions.length == 1
        ? asJsonMap(functions.first['action'])
        : const <String, dynamic>{};
    final webOnly = webAction['type'] == 'openWeb';
    final nativeVideoOnly = const {
      'openVideoCatalog',
      'openVideoLibrary',
    }.contains(webAction['type']);
    final videoSearchAction = DiscoverRouter.videoSearchAction(webAction);
    final showSearch =
        !webOnly && (!nativeVideoOnly || videoSearchAction != null);
    void onSearch() {
      if (nativeVideoOnly) {
        if (videoSearchAction == null) return;
        DiscoverRouter.route(
          context,
          action: DiscoverRouter.attachSource(videoSearchAction, plugin.uuid),
          currentFrom: cubit.currentFrom,
        );
      } else {
        _openPluginSearch(context, plugin.uuid);
      }
    }

    // Launch capability is independent of the current enabled state. Both card
    // presentations already disable interaction when off; dropping the callback
    // here misclassified a disabled source as legacy and changed its geometry.
    final onOpen = !SourceShellSection.canLaunch(info, sections)
        ? null
        : webOnly || nativeVideoOnly
        ? () => DiscoverRouter.route(
            context,
            action: DiscoverRouter.attachSource(webAction, plugin.uuid),
            currentFrom: cubit.currentFrom,
          )
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
        isToggling: state.pendingEnabled.containsKey(plugin.uuid),
        onSearch: onSearch,
        showSearch: showSearch,
        onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
        onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
        onOpen: onOpen,
        onRetry: () => cubit.retryLoadInfo(plugin.uuid),
        onAction: onAction,
      );
    }
    final card = PluginCard(
      pluginUuid: plugin.uuid,
      onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
      onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
      pluginState: plugin,
      infoState: infoState,
      pendingEnabled: state.pendingEnabled[plugin.uuid],
      onSearch: onSearch,
      showSearch: showSearch,
      onOpen: onOpen,
      onRetry: () => cubit.retryLoadInfo(plugin.uuid),
      onAction: onAction,
    );
    final colors = Theme.of(context).colorScheme;
    if (AppInterfaceStyleScope.usesAndroidSystem(context)) {
      const corner = Radius.circular(16);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.vertical(
            top: first ? corner : Radius.zero,
            bottom: last ? corner : Radius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              card,
              if (!last)
                Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: colors.outlineVariant.withValues(alpha: .45),
                ),
            ],
          ),
        ),
      );
    }
    if (!AppInterfaceStyleScope.usesSystem(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            card,
            Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant.withValues(alpha: .45),
            ),
          ],
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // UIKit owns its controls' shapes. A rounded Flutter clip here also
      // clips later route overlays in the iOS 3.47 platform-view slicer.
      clipBehavior: Clip.none,
      child: card,
    );
  }

  Widget _buildPluginStoreButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final system = AppInterfaceStyleScope.usesSystem(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: system
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerLow,
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
                  color: system
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
    final android = AppInterfaceStyleScope.usesAndroidSystem(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppInterfaceStyleScope.usesSystem(context)
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 168,
            child: android
                ? SegmentedButton<_DiscoverLayout>(
                    segments: [
                      ButtonSegment(
                        value: _DiscoverLayout.list,
                        label: Text(t.discover.listLayout),
                      ),
                      ButtonSegment(
                        value: _DiscoverLayout.grid,
                        label: Text(t.discover.gridLayout),
                      ),
                    ],
                    selected: {_layout},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primaryContainer
                            : Colors.transparent,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: colors.outline),
                      ),
                    ),
                    onSelectionChanged: (value) => _setLayout(value.single),
                  )
                : !AppInterfaceStyleScope.usesSystem(context)
                ? BreezeSectionSelector(
                    options: {
                      'list': t.discover.listLayout,
                      'grid': t.discover.gridLayout,
                    },
                    selected: _layout.name,
                    dragEnabled: true,
                    onSelected: (value) => _setLayout(
                      value == 'grid'
                          ? _DiscoverLayout.grid
                          : _DiscoverLayout.list,
                    ),
                  )
                : VideoControlAppearance(
                    systemControls: usesNativeSourceChrome(context),
                    child: NativeVideoSegmentedControl(
                      options: {
                        'list': t.discover.listLayout,
                        'grid': t.discover.gridLayout,
                      },
                      selected: _layout.name,
                      dragEnabled: true,
                      onSelected: (value) => _setLayout(
                        value == 'grid'
                            ? _DiscoverLayout.grid
                            : _DiscoverLayout.list,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManagement(BuildContext context) async {
    if (_managementOpen) return;
    _managementOpen = true;
    try {
      try {
        await _visibility.load();
      } catch (_) {
        if (mounted) showErrorToast(t.error.loadFailed);
        return;
      }
      if (!mounted || !context.mounted) return;
      final cubit = context.read<DiscoverCubit>();
      await showBookshelfManagementIsland<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: BlocBuilder<DiscoverCubit, DiscoverState>(
            builder: (_, state) {
              final plugins = PluginRegistryService.I.sortPlugins(
                state.plugins.values.where((plugin) => !plugin.isDeleted),
              );
              final defaults = [...plugins]
                ..sort((a, b) {
                  final installed = a.insertedAt.compareTo(b.insertedAt);
                  return installed != 0 ? installed : a.uuid.compareTo(b.uuid);
                });
              return PluginManagementIsland(
                hiddenIds: _visibility.hiddenIds,
                defaultOrder: defaults.map((plugin) => plugin.uuid).toList(),
                plugins: [
                  for (final plugin in plugins)
                    DiscoverPluginManagementOption(
                      id: plugin.uuid,
                      enabled: plugin.isEnabled,
                      toggling: state.pendingEnabled.containsKey(plugin.uuid),
                      title:
                          state.infoStates[plugin.uuid]?.data?['name']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? state.infoStates[plugin.uuid]!.data!['name']
                                .toString()
                                .trim()
                          : plugin.uuid,
                      iconUrl:
                          state.infoStates[plugin.uuid]?.data?['iconUrl']
                              ?.toString()
                              .trim() ??
                          '',
                    ),
                ],
                onToggleEnabled: _layout == _DiscoverLayout.grid
                    ? cubit.toggleEnabled
                    : null,
                onSettings: _layout == _DiscoverLayout.grid
                    ? (plugin) =>
                          _openPluginSettings(context, plugin.id, plugin.title)
                    : null,
                onSave: (draft) => saveDiscoverPluginManagement(
                  draft: draft,
                  visibility: _visibility,
                  previousOrder: PluginRegistryService.I
                      .orderedPlugins()
                      .map((plugin) => plugin.uuid)
                      .toList(),
                  writeOrder: PluginRegistryService.I.reorderPlugins,
                  resetOrder: PluginRegistryService.I.resetPluginOrder,
                ),
              );
            },
          ),
        ),
      );
    } finally {
      _managementOpen = false;
    }
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

  Future<void> _openPluginSettings(
    BuildContext context,
    String uuid,
    String title,
  ) async {
    await context.pushRoute(
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
