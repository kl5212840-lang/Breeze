import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/plugin_function/view/plugin_function_page.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

@RoutePage()
class SourceShellPage extends StatefulWidget {
  const SourceShellPage({
    super.key,
    required this.source,
    required this.sourceName,
    required this.sections,
  });

  final String source;
  final String sourceName;
  final List<SourceShellSection> sections;

  @override
  State<SourceShellPage> createState() => _SourceShellPageState();
}

class _SourceShellPageState extends State<SourceShellPage> {
  int _selectedIndex = 0;
  final List<int> _tabHistory = [];
  final SourceProfileBackController _profileBackController =
      SourceProfileBackController();
  final Set<int> _visitedIndexes = {0};
  final Map<int, int> _tabRevisions = {};
  final Set<int> _loginRequiredIndexes = {};
  StreamSubscription<PluginLoginSucceeded>? _loginSubscription;
  StreamSubscription<NeedLogin>? _needLoginSubscription;
  StreamSubscription<Map<String, PluginRuntimeState>>? _pluginSubscription;
  late String _sourceName;
  String? _bundleKey;

  @override
  void initState() {
    super.initState();
    SourceReturnPreferences.changes.addListener(_onReturnModeChanged);
    unawaited(SourceReturnPreferences.load());
    _profileBackController.addListener(_onProfileBackChanged);
    _sourceName = widget.sourceName;
    final plugin = PluginRegistryService.I.getByUuid(widget.source);
    _bundleKey = plugin == null
        ? null
        : '${plugin.version}|${plugin.originScript.hashCode}';
    _pluginSubscription = PluginRegistryService.I.stream.listen((plugins) {
      final updated = plugins[widget.source];
      if (updated == null) return;
      final key = '${updated.version}|${updated.originScript.hashCode}';
      if (key == _bundleKey) return;
      _bundleKey = key;
      _refreshSourceName();
    });
    _refreshSourceName();
    _loginSubscription = eventBus.on<PluginLoginSucceeded>().listen((event) {
      if (!mounted || event.from != widget.source) return;
      setState(() {
        _loginRequiredIndexes.clear();
        for (final index in _visitedIndexes) {
          _tabRevisions[index] = (_tabRevisions[index] ?? 0) + 1;
        }
      });
    });
    _needLoginSubscription = eventBus.on<NeedLogin>().listen((event) {
      if (!mounted || event.from != widget.source) return;
      if (widget.sections.isNotEmpty &&
          (widget.sections[_selectedIndex].id == 'more' ||
              widget.sections[_selectedIndex].profile)) {
        return;
      }
      setState(() => _loginRequiredIndexes.add(_selectedIndex));
    });
  }

  @override
  void dispose() {
    SourceReturnPreferences.changes.removeListener(_onReturnModeChanged);
    _profileBackController.removeListener(_onProfileBackChanged);
    _profileBackController.dispose();
    _pluginSubscription?.cancel();
    _loginSubscription?.cancel();
    _needLoginSubscription?.cancel();
    super.dispose();
  }

  void _onProfileBackChanged() {
    // A profile child can attach/detach while this shell is being rebuilt.
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  void _onReturnModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openLogin() async {
    await context.pushRoute(app_routes.LoginRoute(from: widget.source));
  }

  void _openAccount() {
    final profileIndex = widget.sections.indexWhere(
      (section) => section.profile,
    );
    if (profileIndex >= 0) {
      _select(profileIndex);
    } else {
      _openLogin();
    }
  }

  Future<void> _openSettings() => context.pushRoute(
    app_routes.PluginSettingsRoute(
      from: widget.source,
      pluginUuid: widget.source,
      pluginRuntimeName: widget.source,
      pluginDisplayName: _sourceName,
      insideSource: true,
    ),
  );

  Future<void> _refreshSourceName() async {
    try {
      final info = await PluginRegistryService.I.fetchPluginInfo(
        uuid: widget.source,
        runtimeName: widget.source,
      );
      final nextName = info['name']?.toString().trim() ?? '';
      if (mounted && nextName.isNotEmpty && nextName != _sourceName) {
        setState(() => _sourceName = nextName);
      }
    } catch (_) {
      // Keep the route title when a disabled/offline plugin cannot be queried.
    }
  }

  void _openSearch() {
    context.pushRoute(
      app_routes.SearchRoute(
        searchState: SearchStates.initial().copyWith(from: widget.source),
        aggregateMode: false,
      ),
    );
  }

  void _searchThisSource(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final searchState = SearchStates.initial().copyWith(
      from: widget.source,
      searchKeyword: trimmed,
    );
    context.pushRoute(
      app_routes.SearchResultRoute(
        searchEvent: SearchEvent().copyWith(searchStates: searchState),
      ),
    );
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      final historyIndex = _tabHistory.indexOf(index);
      if (historyIndex >= 0) {
        _tabHistory.removeRange(historyIndex, _tabHistory.length);
      } else {
        _tabHistory.add(_selectedIndex);
      }
      _selectedIndex = index;
      _visitedIndexes.add(index);
    });
  }

  bool get _profileCanGoBack =>
      widget.sections.isNotEmpty &&
      widget.sections[_selectedIndex].profile &&
      _profileBackController.canGoBack;

  void _goBack() {
    if (_profileCanGoBack) {
      _profileBackController.goBack();
    } else if (SourceReturnPreferences.includesTabHistory &&
        _tabHistory.isNotEmpty) {
      setState(() => _selectedIndex = _tabHistory.removeLast());
    }
  }

  void _exitSource() => exitSourceToDiscover(context);

  Future<void> _routeSourceAction(Map<String, dynamic> action) =>
      DiscoverRouter.route(
        context,
        action: DiscoverRouter.attachSource(action, widget.source),
        currentFrom: widget.source,
      );

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final showingProfile =
        sections.isNotEmpty && sections[_selectedIndex].profile;
    final canGoBack =
        _profileCanGoBack ||
        SourceReturnPreferences.includesTabHistory && _tabHistory.isNotEmpty;
    final backLabel = _profileCanGoBack
        ? _profileBackController.backLabel!
        : SourceReturnPreferences.includesTabHistory && _tabHistory.isNotEmpty
        ? '${t.common.back} · ${sections[_tabHistory.last].title}'
        : null;
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: SourceBackButton(
            tooltip: backLabel,
            onPressed: canGoBack ? _goBack : _exitSource,
          ),
          title: Text(
            showingProfile ? '我的' : _sourceName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (!showingProfile)
              SourceChromeIconButton(
                tooltip: t.sourceShell.search,
                icon: Icons.search,
                symbol: 'magnifyingglass',
                onPressed: _openSearch,
              ),
            if (!showingProfile)
              SourceChromeIconButton(
                tooltip: t.sourceShell.account,
                icon: Icons.person_outline,
                symbol: 'person.crop.circle',
                onPressed: _openAccount,
              ),
            SourceMoreButton(
              source: widget.source,
              actions: [
                SourceMenuAction(
                  id: 'settings',
                  label: t.sourceShell.settings,
                  icon: Icons.settings_outlined,
                  symbol: 'gearshape',
                  onSelected: () => unawaited(_openSettings()),
                ),
              ],
            ),
          ],
        ),
        body: sections.isEmpty
            ? _loginRequiredIndexes.contains(0)
                  ? _buildLoginRequired()
                  : _buildSearchOnly()
            : IndexedStack(
                index: _selectedIndex,
                children: [
                  for (var index = 0; index < sections.length; index++)
                    if (_loginRequiredIndexes.contains(index))
                      _buildLoginRequired()
                    else if (_visitedIndexes.contains(index))
                      if (sections[index].scene case final scene?)
                        ComicListPage(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          title: sections[index].title,
                          scene: scene,
                          embedded: true,
                        )
                      else if (sections[index].functionId
                          case final functionId?)
                        PluginFunctionContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          from: widget.source,
                          functionId: functionId,
                          onAction: _routeSourceAction,
                        )
                      else if (sections[index].cloudFavorite)
                        ComicListPage(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          title: sections[index].title,
                          sceneSource: widget.source,
                          sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
                          sceneBundleFnPathFallback:
                              'get_cloud_favorite_scene_bundle',
                          embedded: true,
                        )
                      else if (sections[index].profile)
                        SourceProfileContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          source: widget.source,
                          legacySources: sections[index].legacySources,
                          avatarUploadFunction:
                              sections[index].profileAvatarFunction,
                          bioUpdateFunction: sections[index].profileBioFunction,
                          profileKind: sections[index].profileKind,
                          checkinFunction:
                              sections[index].profileCheckinFunction,
                          notificationsFunction:
                              sections[index].profileNotificationsFunction,
                          backController: _profileBackController,
                          onLogin: _openLogin,
                          onSettings: _openSettings,
                          onBreezeSettings: () => context.pushRoute(
                            const app_routes.GlobalSettingRoute(),
                          ),
                          onCloudFavorite: () => _routeSourceAction({
                            'type': 'openCloudFavorite',
                            'payload': {'title': '云端收藏'},
                          }),
                        )
                      else
                        _buildMoreActions(sections[index].actions)
                    else
                      const SizedBox.shrink(),
                ],
              ),
        bottomNavigationBar: sections.length <= 1
            ? null
            : usesNativeSourceChrome(context)
            ? VideoNativeNavigation(
                items: [
                  for (final section in sections)
                    BottomNavigationBarItem(
                      icon: Icon(section.icon),
                      label: section.id == 'more'
                          ? t.navigation.more
                          : section.title,
                    ),
                ],
                symbols: [for (final section in sections) _symbol(section)],
                currentIndex: _selectedIndex,
                onTap: _select,
              )
            : NavigationBar(
                selectedIndex: _selectedIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _select,
                destinations: [
                  for (final section in sections)
                    NavigationDestination(
                      icon: Icon(section.icon),
                      label: section.id == 'more'
                          ? t.navigation.more
                          : section.title,
                      tooltip: section.id == 'more'
                          ? t.navigation.more
                          : section.title,
                    ),
                ],
              ),
      ),
    );
  }

  String _symbol(SourceShellSection section) => switch (section.id) {
    'recommend' => 'sparkles',
    'newest' || 'latest' => 'clock',
    'discover' => 'safari',
    'navigation' || 'categories' => 'square.grid.2x2',
    'rank' || 'ranking' => 'chart.bar',
    'cloudFavorite' => 'bookmark',
    'profile' => 'person.crop.circle',
    'more' => 'square.grid.2x2',
    _ => 'list.bullet',
  };

  Widget _buildMoreActions(List<SourceShellAction> actions) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: actions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = actions[index];
        return ListTile(
          title: Text(
            convertChineseForDisplay(item.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => DiscoverRouter.route(
            context,
            action: item.action,
            currentFrom: widget.source,
          ),
        );
      },
    );
  }

  Widget _buildSearchOnly() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                t.sourceShell.noSections,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                textInputAction: TextInputAction.search,
                onSubmitted: _searchThisSource,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: t.sourceShell.search,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                t.navigation.needLoginTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _openLogin,
                icon: const Icon(Icons.login),
                label: Text(t.navigation.goLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
