import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/tab_reselect_scope.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/widgets/bika_access_lines_page.dart';
import 'package:zephyr/page/source_shell/widgets/bika_settings_content.dart';
import 'package:zephyr/page/source_shell/widgets/bika_games_content.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'dart:async';
import 'dart:convert';
import 'package:zephyr/network/source_network_policy.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/plugin_function/view/plugin_function_page.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/page/source_shell/view/source_video_content.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/breeze_scroll_navigation.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_login_capability.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

@RoutePage()
class SourceShellPage extends StatelessWidget {
  const SourceShellPage({
    super.key,
    required this.source,
    required this.sourceName,
    required this.sections,
    this.initialSectionId = '',
  });

  final String source;
  final String sourceName;
  final List<SourceShellSection> sections;
  final String initialSectionId;

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: source,
    builder: (_) {
      final body = _SourceShellBody(
        source: source,
        sourceName: sourceName,
        sections: sections,
        initialSectionId: initialSectionId,
      );
      return supportsBikaAccessLines(
            source,
            PluginRegistryService.I.getCachedPluginInfo(source),
          )
          ? BikaAccessLineGate(source: source, child: body)
          : body;
    },
  );
}

class _SourceShellBody extends StatefulWidget {
  const _SourceShellBody({
    required this.source,
    required this.sourceName,
    required this.sections,
    required this.initialSectionId,
  });
  final String source, sourceName, initialSectionId;
  final List<SourceShellSection> sections;
  @override
  State<_SourceShellBody> createState() => _SourceShellPageState();
}

class _SourceShellPageState extends State<_SourceShellBody>
    with WidgetsBindingObserver {
  late List<SourceShellSection> _sections;
  String _bikaInfoKey = '';
  int _searchSubmission = 0;
  int _selectedIndex = 0;
  final List<int> _tabHistory = [];
  final _tabReselect = <String, TabReselectController>{};
  final SourceProfileBackController _profileBackController =
      SourceProfileBackController();
  final _videoContentKeys = <String, ({int revision, GlobalKey key})>{};
  final Set<int> _visitedIndexes = {0};
  final Map<int, int> _tabRevisions = {};
  final Set<int> _loginRequiredIndexes = {};
  StreamSubscription<PluginLoginSucceeded>? _loginSubscription;
  StreamSubscription<PluginAccountSignedOut>? _signOutSubscription;
  StreamSubscription<NeedLogin>? _needLoginSubscription;
  StreamSubscription<Map<String, PluginRuntimeState>>? _pluginSubscription;
  late String _sourceName;
  String? _bundleKey;
  String? _loginProbeKey;
  int _loginProbeEpoch = 0;
  int _sourceNameEpoch = 0;
  bool _loginSupported = false;
  Future<SourceNetworkLease>? _networkLease;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BikaAccessLines.changes.addListener(_onAccessLineChanged);
    _sections = List.of(widget.sections);
    _refreshBikaSections(notify: false);
    final initial = _sections.indexWhere(
      (section) => section.id == widget.initialSectionId,
    );
    if (initial >= 0) {
      _selectedIndex = initial;
      _visitedIndexes.add(initial);
    }
    if (SourceNetworkPolicies.supports(widget.source)) {
      _networkLease = SourceNetworkPolicies.acquire(widget.source);
      unawaited(_networkLease!.then<void>((_) {}, onError: (Object _) {}));
    }
    SourceReturnPreferences.changes.addListener(_onReturnModeChanged);
    unawaited(SourceReturnPreferences.load());
    _profileBackController.addListener(_onProfileBackChanged);
    _profileBackController.jmHeader.addListener(_onJmSearchChanged);
    _sourceName = widget.sourceName;
    final plugin = PluginRegistryService.I.getByUuid(widget.source);
    _bundleKey = plugin == null
        ? null
        : '${plugin.version}|${plugin.originScript.hashCode}';
    _pluginSubscription = PluginRegistryService.I.stream.listen((plugins) {
      final updated = plugins[widget.source];
      if (updated == null) return;
      final key = '${updated.version}|${updated.originScript.hashCode}';
      final sectionsChanged = _refreshBikaSections();
      if (key == _bundleKey && !sectionsChanged) return;
      _bundleKey = key;
      _refreshSourceName();
      _refreshLoginCapability();
    });
    _refreshSourceName();
    _refreshLoginCapability();
    _loginSubscription = eventBus.on<PluginLoginSucceeded>().listen((event) {
      if (!mounted || event.from != widget.source) return;
      setState(() {
        _loginRequiredIndexes.clear();
        for (final index in _visitedIndexes) {
          _tabRevisions[index] = (_tabRevisions[index] ?? 0) + 1;
        }
      });
    });
    _signOutSubscription = eventBus.on<PluginAccountSignedOut>().listen((
      event,
    ) {
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
      if (_sections.isNotEmpty &&
          (_sections[_selectedIndex].id == 'more' ||
              _sections[_selectedIndex].sourceSettings ||
              _sections[_selectedIndex].profile)) {
        return;
      }
      setState(() => _loginRequiredIndexes.add(_selectedIndex));
    });
  }

  @override
  void didUpdateWidget(covariant _SourceShellBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _searchSubmission++;
      _sections = List.of(widget.sections);
      _bikaInfoKey = '';
      _selectedIndex = 0;
      _visitedIndexes.clear();
      _visitedIndexes.add(0);
      _tabHistory.clear();
      _tabRevisions.clear();
      _videoContentKeys.clear();
      _loginRequiredIndexes.clear();
      _refreshBikaSections(notify: false);
      _sourceName = widget.sourceName;
      final plugin = PluginRegistryService.I.getByUuid(widget.source);
      _bundleKey = plugin == null
          ? null
          : '${plugin.version}|${plugin.originScript.hashCode}';
      _refreshSourceName();
    }
    _refreshLoginCapability();
  }

  // The route's section list is a launch snapshot. Reconcile only the exact
  // declared BK experience when getInfo arrives or the bundle is replaced.
  // Existing destinations keep their identity, scroll state and return chain.
  bool _refreshBikaSections({bool notify = true}) {
    final info = PluginRegistryService.I.getCachedPluginInfo(widget.source);
    if (!supportsBikaExperienceDeclaration(widget.source, info)) return false;
    final infoKey = jsonEncode(info);
    if (infoKey == _bikaInfoKey) return false;
    _bikaInfoKey = infoKey;
    final next = SourceShellSection.fromPluginInfo(info!, widget.source);
    if (next.isEmpty) return false;
    final old = _sections;
    final selected = old.isEmpty
        ? ''
        : old[_selectedIndex.clamp(0, old.length - 1).toInt()].id;
    final visited = {
      for (final i in _visitedIndexes)
        if (i < old.length) old[i].id,
    };
    final history = [
      for (final i in _tabHistory)
        if (i < old.length) old[i].id,
    ];
    final locked = {
      for (final i in _loginRequiredIndexes)
        if (i < old.length) old[i].id,
    };
    final revisions = {
      for (final entry in _tabRevisions.entries)
        if (entry.key < old.length) old[entry.key].id: entry.value,
    };
    void accept() {
      _sections = next;
      _videoContentKeys.removeWhere(
        (id, _) => !next.any((section) => section.id == id),
      );
      _selectedIndex = next.indexWhere((s) => s.id == selected);
      if (_selectedIndex < 0) _selectedIndex = 0;
      _visitedIndexes
        ..clear()
        ..addAll([
          for (var i = 0; i < next.length; i++)
            if (visited.contains(next[i].id)) i,
          _selectedIndex,
        ]);
      _tabHistory
        ..clear()
        ..addAll(
          history
              .map((id) => next.indexWhere((s) => s.id == id))
              .where((i) => i >= 0),
        );
      _loginRequiredIndexes
        ..clear()
        ..addAll([
          for (var i = 0; i < next.length; i++)
            if (locked.contains(next[i].id)) i,
        ]);
      _tabRevisions.clear();
      for (var i = 0; i < next.length; i++) {
        final matches = old.where((s) => s.id == next[i].id);
        final prior = matches.isEmpty ? null : matches.first;
        final bindingChanged =
            prior != null &&
            prior.profileCloudFavoriteFunction !=
                next[i].profileCloudFavoriteFunction;
        _tabRevisions[i] =
            (revisions[next[i].id] ?? 0) + (bindingChanged ? 1 : 0);
      }
    }

    if (notify && mounted) {
      setState(accept);
    } else {
      accept();
    }
    return true;
  }

  void _refreshLoginCapability() {
    if (_sections.any((section) => section.profile)) {
      _loginProbeEpoch++;
      _loginProbeKey = null;
      _loginSupported = false;
      return;
    }
    final key = '${widget.source}|${_bundleKey ?? ''}';
    if (key == _loginProbeKey) return;
    _loginProbeKey = key;
    final epoch = ++_loginProbeEpoch;
    final source = widget.source;
    // Unknown capabilities never expose a clickable account destination.
    setState(() => _loginSupported = false);
    unawaited(
      resolvePluginLoginSupported(source).then((supported) {
        if (!mounted ||
            epoch != _loginProbeEpoch ||
            source != widget.source ||
            key != _loginProbeKey) {
          return;
        }
        setState(() => _loginSupported = supported);
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _tabReselect.values) {
      controller.dispose();
    }
    BikaAccessLines.changes.removeListener(_onAccessLineChanged);
    _loginProbeEpoch++;
    _sourceNameEpoch++;
    final network = _networkLease;
    if (network != null) {
      unawaited(
        network.then<void>((lease) => lease.close(), onError: (Object _) {}),
      );
    }
    SourceReturnPreferences.changes.removeListener(_onReturnModeChanged);
    _profileBackController.removeListener(_onProfileBackChanged);
    _profileBackController.jmHeader.removeListener(_onJmSearchChanged);
    _profileBackController.dispose();
    _pluginSubscription?.cancel();
    _loginSubscription?.cancel();
    _signOutSubscription?.cancel();
    _needLoginSubscription?.cancel();
    super.dispose();
  }

  void _onAccessLineChanged() {
    if (widget.source != bikaPlusSourceId || !mounted) return;
    setState(() {
      for (final i in _visitedIndexes)
        _tabRevisions[i] = (_tabRevisions[i] ?? 0) + 1;
    });
  }

  bool _jmSearching = false;
  void _onJmSearchChanged() {
    final searching = _profileBackController.jmHeader.searchField != null;
    if (!mounted || searching == _jmSearching) return;
    _jmSearching = searching;
    _onProfileBackChanged();
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

  Future<void> _openLogin({bool addAccount = false}) async {
    await context.pushRoute(
      app_routes.LoginRoute(
        from: widget.source,
        key: addAccount ? LoginPage.addAccountKey : null,
      ),
    );
  }

  void _openAccount() {
    final profileIndex = _sections.indexWhere((section) => section.profile);
    if (profileIndex >= 0) {
      _select(profileIndex);
    } else {
      _openLogin();
    }
  }

  void _onBikaSignedOut() {
    if (!mounted || !isBikaExperienceSource(widget.source)) return;
    setState(() {
      _loginRequiredIndexes.clear();
      for (final index in _visitedIndexes) {
        if (index < _sections.length && !_sections[index].sourceSettings) {
          _tabRevisions[index] = (_tabRevisions[index] ?? 0) + 1;
        }
      }
    });
  }

  Future<void> _openPluginPreferences() async {
    final settingsIndex = _sections.indexWhere(
      (section) => section.sourceSettings,
    );
    if (SourceExperienceScope.maybeOf(context)?.enabled == true &&
        settingsIndex >= 0) {
      _select(settingsIndex);
      return;
    }
    await openSourceSettings(
      context,
      source: widget.source,
      sourceName: _sourceName,
    );
  }

  // Extra Bika schema options are a child of its formal settings tab.
  Future<void> _openPluginPreferencesPage() => openSourcePreferences(
    context,
    source: widget.source,
    sourceName: _sourceName,
  );

  Future<void> _refreshSourceName() async {
    final source = widget.source;
    final epoch = ++_sourceNameEpoch;
    try {
      final info = await PluginRegistryService.I.fetchPluginInfo(
        uuid: source,
        runtimeName: source,
      );
      final nextName = info['name']?.toString().trim() ?? '';
      if (mounted &&
          epoch == _sourceNameEpoch &&
          source == widget.source &&
          nextName.isNotEmpty &&
          nextName != _sourceName) {
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

  Future<void> _searchThisSource(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    final source = widget.source;
    final route = ModalRoute.of(context);
    final submission = ++_searchSubmission;
    final scope = await readKeywordSearchDefault(source: source);
    if (!mounted ||
        route?.isCurrent == false ||
        _searchSubmission != submission ||
        _sections.isNotEmpty ||
        _loginRequiredIndexes.contains(0)) {
      return;
    }
    final searchState = SearchStates.initial().copyWith(
      from: source,
      searchKeyword: trimmed,
      pluginExtern: changeKeywordSearchScope({}, scope),
    );
    context.pushRoute(
      app_routes.SearchResultRoute(
        searchEvent: SearchEvent().copyWith(searchStates: searchState),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (index != _selectedIndex) {
      _select(index);
      return;
    }
    _reselectCurrentTab();
  }

  @override
  void handleStatusBarTap() {
    if (defaultTargetPlatform == TargetPlatform.iOS) _reselectCurrentTab();
  }

  void _reselectCurrentTab() {
    if (!mounted ||
        _sections.isEmpty ||
        _jmSearching ||
        _profileCanGoBack ||
        _loginRequiredIndexes.contains(_selectedIndex) ||
        !TabReselectScope.canHandle(context)) {
      return;
    }
    _tabReselect[_sections[_selectedIndex].id]?.request();
  }

  Widget _tabContent(int index, Widget child) {
    final section = _sections[index];
    if (section.scene == null &&
        section.functionId == null &&
        !section.cloudFavorite &&
        !section.videoGroup) {
      return child;
    }
    return TabReselectScope(
      controller: _tabReselect.putIfAbsent(
        section.id,
        TabReselectController.new,
      ),
      child: child,
    );
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    _closeActiveJmSearch();
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
      _sections.isNotEmpty &&
      _sections[_selectedIndex].profile &&
      _profileBackController.canGoBack;

  void _goBack() {
    if (_closeActiveJmSearch()) return;
    if (_profileCanGoBack) {
      _profileBackController.goBack();
    } else if (SourceReturnPreferences.includesTabHistory &&
        _tabHistory.isNotEmpty) {
      setState(() => _selectedIndex = _tabHistory.removeLast());
    }
  }

  bool _closeActiveJmSearch() {
    if (!_jmSearching || !_profileCanGoBack) return false;
    final close = _profileBackController.jmHeader.actions?.onSearch;
    if (close == null) return false;
    close();
    return true;
  }

  void _exitSource() => exitSourceToDiscover(context);

  Future<void> _routeSourceAction(Map<String, dynamic> action) =>
      DiscoverRouter.route(
        context,
        action: DiscoverRouter.attachSource(action, widget.source),
        currentFrom: widget.source,
      );

  GlobalKey _videoContentKey(int index) {
    final id = _sections[index].id;
    final revision = _tabRevisions[index] ?? 0;
    final previous = _videoContentKeys[id];
    if (previous != null && previous.revision == revision) return previous.key;
    final key = GlobalKey();
    _videoContentKeys[id] = (revision: revision, key: key);
    return key;
  }

  Widget _sourceTabStack({required int index, required List<Widget> children}) {
    if (!isBikaExperienceSource(widget.source)) {
      return IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < children.length; i++)
            ReadRecoveryScope(
              active: i == index,
              child: TickerMode(
                enabled: i == index,
                child: _tabContent(i, children[i]),
              ),
            ),
        ],
      );
    }
    // IndexedStack's internal Visibility wrappers are positional. A newly
    // declared destination must not replace the visited settings/profile state.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          Offstage(
            key: ValueKey(_sections[i].id),
            offstage: i != index,
            child: ReadRecoveryScope(
              active: i == index,
              child: TickerMode(
                enabled: i == index,
                child: _tabContent(i, children[i]),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => BreezeScrollNavigation(
    ownsNavigation: _sections.length > 1,
    content: (
      _sections.elementAtOrNull(_selectedIndex)?.id,
      _tabRevisions[_selectedIndex],
      _profileBackController.title,
      _loginRequiredIndexes.contains(_selectedIndex),
    ),
    acceptsScroll: !_jmSearching,
    builder: _buildWithNavigation,
  );

  Widget _buildWithNavigation(
    BuildContext context,
    BreezeScrollNavigationState navigation,
  ) {
    final sections = _sections;
    final section = sections.isEmpty ? null : sections[_selectedIndex];
    final showingProfile = section?.profile == true;
    final jmSearching = showingProfile && _jmSearching;
    final jmCollection =
        showingProfile &&
        _profileBackController.title != null &&
        sections[_selectedIndex].profileKind == 'jm';
    final showingSettings = section?.sourceSettings == true;
    final showingVideo = section?.videoGroup == true;
    final showingBrowseSearch =
        section != null &&
        !showingProfile &&
        !showingSettings &&
        !showingVideo &&
        !section.bikaGames &&
        !section.cloudFavorite &&
        !_loginRequiredIndexes.contains(_selectedIndex);
    final canGoBack =
        _profileCanGoBack ||
        SourceReturnPreferences.includesTabHistory && _tabHistory.isNotEmpty;
    final androidVideoBack =
        showingVideo && defaultTargetPlatform == TargetPlatform.android;
    final backLabel = _profileCanGoBack
        ? _profileBackController.backLabel!
        : SourceReturnPreferences.includesTabHistory && _tabHistory.isNotEmpty
        ? '${t.common.back} · ${_sectionTitle(sections[_tabHistory.last])}'
        : null;
    final body = PopScope(
      canPop: !canGoBack && !androidVideoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (androidVideoBack) {
          final section = sections[_selectedIndex];
          final key = _videoContentKeys[section.id]?.key;
          if (key != null && SourceVideoContent.handleAndroidBackFor(key)) {
            return;
          }
          if (!canGoBack) {
            Navigator.of(context).pop();
            return;
          }
        }
        _goBack();
      },
      child: Scaffold(
        extendBody: navigation.automatic || usesSystemSourceChrome(context),
        appBar: showingVideo
            ? null
            : SearchToolbarScope.appBar(
                context,
                (height) => AppBar(
                  backgroundColor:
                      showingProfile &&
                          SourceExperienceScope.maybeOf(context)?.isOriginal ==
                              true
                      ? Theme.of(context).scaffoldBackgroundColor
                      : null,
                  foregroundColor:
                      showingProfile &&
                          SourceExperienceScope.maybeOf(context)?.isOriginal ==
                              true
                      ? Theme.of(context).colorScheme.onSurface
                      : null,
                  automaticallyImplyLeading: false,
                  leadingWidth: CollectionToolbarMetrics.leadingExtentOf(
                    context,
                  ),
                  actionsPadding: CollectionToolbarMetrics.trailingPadding,
                  leading: jmSearching
                      ? null
                      : CollectionToolbarMetrics.leading(
                          context,
                          SourceBackButton(
                            tooltip: backLabel,
                            onPressed: canGoBack ? _goBack : _exitSource,
                          ),
                        ),
                  titleSpacing: jmSearching
                      ? CollectionToolbarMetrics.sourceContentInset
                      : 0,
                  toolbarHeight:
                      showingProfile &&
                          _profileBackController.title != null &&
                          sections[_selectedIndex].profileKind == 'jm'
                      ? SearchToolbarScope.stableHeight(
                          context,
                          (MediaQuery.textScalerOf(context).scale(14) * 1.5 +
                                  20)
                              .clamp(56.0, double.infinity),
                        )
                      : height,
                  title: showingProfile
                      ? ListenableBuilder(
                          listenable: _profileBackController.jmHeader,
                          builder: (_, _) =>
                              _profileBackController.jmHeader.searchField ??
                              Text(
                                sections.any(
                                      (section) =>
                                          section.profile &&
                                          section.profileKind == 'jm',
                                    )
                                    ? (_profileBackController.title ??
                                          t.videoSource.me)
                                    : t.videoSource.me,
                              ),
                        )
                      : showingSettings
                      ? Text(t.discover.settings)
                      : Text(
                          section == null || section.title.trim().isEmpty
                              ? _sourceName
                              : section.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  actions: jmSearching
                      ? const []
                      : [
                          if (jmCollection)
                            JmCollectionHeaderActions(
                              controller: _profileBackController.jmHeader,
                            ),
                          if (showingProfile &&
                              !jmSearching &&
                              !_profileBackController.canGoBack)
                            const CollectionCoverPrivacyButton(),
                          if (showingBrowseSearch)
                            SourceChromeIconButton(
                              key: const ValueKey('source-shell.search'),
                              tooltip: t.sourceShell.search,
                              icon: Icons.search_rounded,
                              symbol: 'magnifyingglass',
                              bare: !usesSystemSourceChrome(context),
                              onPressed: _openSearch,
                            ),
                          if (!showingProfile &&
                              !sections.any((section) => section.profile) &&
                              _loginSupported)
                            SourceChromeIconButton(
                              tooltip: t.sourceShell.account,
                              icon: Icons.person_outline,
                              symbol: 'person.crop.circle',
                              onPressed: _openAccount,
                            ),
                          if (!jmCollection)
                            SourceMoreButton(
                              source: widget.source,
                              showCoverSettings: showingProfile,
                              showSettings: !showingSettings,
                              onOpenSettings: () =>
                                  unawaited(_openPluginPreferences()),
                            ),
                        ],
                ),
                searching: jmSearching,
              ),
        body: sections.isEmpty
            ? _loginRequiredIndexes.contains(0)
                  ? _buildLoginRequired()
                  : _buildSearchOnly()
            : _sourceTabStack(
                index: _selectedIndex,
                children: [
                  for (var index = 0; index < sections.length; index++)
                    if (_loginRequiredIndexes.contains(index))
                      _buildLoginRequired()
                    else if (_visitedIndexes.contains(index))
                      if (sections[index].videoGroup)
                        SourceVideoContent(
                          key: _videoContentKey(index),
                          source: widget.source,
                          actions: sections[index].actions,
                          browseOnly: sections[index].videoBrowseOnly,
                          active: _selectedIndex == index,
                          leading: SourceBackButton(
                            tooltip: backLabel,
                            onPressed: canGoBack ? _goBack : _exitSource,
                          ),
                        )
                      else if (sections[index].bikaGames)
                        BikaGamesContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          source: widget.source,
                        )
                      else if (sections[index].sourceSettings)
                        BikaSettingsContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          source: widget.source,
                          sourceName: _sourceName,
                          videoActions: [
                            for (final section in sections.where(
                              (section) => section.videoGroup,
                            ))
                              ...section.actions,
                          ],
                          onOpenPreferences: _openPluginPreferencesPage,
                          onAction: _routeSourceAction,
                          onSignedOut: _onBikaSignedOut,
                        )
                      else if (sections[index].scene case final scene?)
                        ComicListPage(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          title: sections[index].title,
                          scene: scene,
                          embedded: true,
                          titleInParent: true,
                        )
                      else if (sections[index].functionId
                          case final functionId?)
                        PluginFunctionContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          from: widget.source,
                          functionId: functionId,
                          tabReselectEnabled: true,
                          extern: {
                            if (sections.any((section) => section.videoGroup))
                              'nativeVideoTab': true,
                          },
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
                          titleInParent: true,
                        )
                      else if (sections[index].profile)
                        SourceProfileContent(
                          key: ValueKey(
                            '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                          ),
                          source: widget.source,
                          sourceName: _sourceName,
                          videoModules: [
                            if (sections[index].profileVideoRecords ||
                                widget.source ==
                                    'e9f18928-3ba8-4d86-a12e-b53a62f47933')
                              for (final section in sections.where(
                                (section) => section.videoGroup,
                              ))
                                for (final action in section.actions)
                                  ?SourceVideoModule.fromAction(
                                    action.action,
                                    widget.source,
                                  ),
                          ],
                          legacySources: sections[index].legacySources,
                          avatarUploadFunction:
                              sections[index].profileAvatarFunction,
                          bioUpdateFunction: sections[index].profileBioFunction,
                          profileKind: sections[index].profileKind,
                          jmAccountCollections:
                              sections[index].jmAccountCollections,
                          jmSiteWatchHistory:
                              sections[index].jmSiteWatchHistory,
                          checkinFunction:
                              sections[index].profileCheckinFunction,
                          notificationsFunction:
                              sections[index].profileNotificationsFunction,
                          checkinStatusFunction:
                              sections[index].profileCheckinStatusFunction,
                          checkinStatusSource:
                              sections[index].profileCheckinStatusSource,
                          markNotificationReadFunction: sections[index]
                              .profileMarkNotificationReadFunction,
                          markNotificationsReadFunction: sections[index]
                              .profileMarkNotificationsReadFunction,
                          cloudFavoriteFunction:
                              sections[index].profileCloudFavoriteFunction,
                          backController: _profileBackController,
                          onLogin: _openLogin,
                          onAddAccount: () => _openLogin(addAccount: true),
                          onSettings: _openPluginPreferences,
                          onCloudFavorite: () => _routeSourceAction({
                            'type': 'openCloudFavorite',
                            'payload': {
                              'title': t.oldHome.cloudFavorite,
                              'jmCollection':
                                  sections[index].profileKind == 'jm',
                            },
                          }),
                        )
                      else
                        _buildMoreActions(
                          sections[index].actions,
                          reserveNavigation:
                              navigation.automatic ||
                              AppInterfaceStyleScope.usesAndroidSystem(context),
                        )
                    else
                      const SizedBox.shrink(),
                ],
              ),
        bottomNavigationBar: sections.length <= 1
            ? null
            : navigation.bar(
                usesNativeSourceChrome(context) ||
                        AppInterfaceStyleScope.usesAndroidSystem(context) ||
                        !AppInterfaceStyleScope.usesSystem(context)
                    ? VideoNativeNavigation(
                        items: [
                          for (final section in sections)
                            BottomNavigationBarItem(
                              icon: Icon(_sectionIcon(section)),
                              label: _sectionTitle(section),
                            ),
                        ],
                        symbols: [
                          for (final section in sections) _symbol(section),
                        ],
                        currentIndex: _selectedIndex,
                        onTap: _onDestinationSelected,
                      )
                    : NavigationBar(
                        selectedIndex: _selectedIndex,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        onDestinationSelected: _onDestinationSelected,
                        destinations: [
                          for (final section in sections)
                            NavigationDestination(
                              icon: Icon(_sectionIcon(section)),
                              label: _sectionTitle(section),
                              tooltip: _sectionTitle(section),
                            ),
                        ],
                      ),
              ),
      ),
    );
    final settingsIndex = sections.indexWhere(
      (section) => section.sourceSettings,
    );
    return settingsIndex < 0
        ? body
        : SourceSettingsShortcutScope(
            source: widget.source,
            open: () async => _select(settingsIndex),
            child: body,
          );
  }

  String _sectionTitle(SourceShellSection section) => section.sourceSettings
      ? t.discover.settings
      : section.bikaGames
      ? t.sourceShell.games
      : section.id == 'more'
      ? t.navigation.more
      : section.profile
      ? t.videoSource.me
      : section.title;

  IconData _sectionIcon(SourceShellSection section) {
    if (section.id == 'home' &&
        SourceExperienceScope.maybeOf(context)?.enabled == true) {
      return Icons.home_outlined;
    }
    return section.icon;
  }

  String _symbol(SourceShellSection section) => switch (section.id) {
    'home' when SourceExperienceScope.maybeOf(context)?.enabled == true =>
      'house',
    'bikaSettings' => 'gearshape',
    'bikaGames' => 'gamecontroller',
    'recommend' => 'sparkles',
    'newest' || 'latest' => 'clock',
    'discover' => 'safari',
    'navigation' || 'categories' => 'square.grid.2x2',
    'rank' || 'ranking' => 'chart.bar',
    'cloudFavorite' => 'bookmark',
    'profile' => 'person.crop.circle',
    'video' => 'film',
    'more' => 'square.grid.2x2',
    _ => 'list.bullet',
  };

  Widget _buildMoreActions(
    List<SourceShellAction> actions, {
    required bool reserveNavigation,
  }) => Builder(
    builder: (context) => ListView.separated(
      padding: EdgeInsets.only(
        top: 8,
        bottom:
            8 + (reserveNavigation ? MediaQuery.paddingOf(context).bottom : 0),
      ),
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
    ),
  );

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
              SearchToolbarScope(
                extent: SearchToolbarScope.fieldExtent(context),
                child: SearchQueryField(
                  query: '',
                  inline: true,
                  showSubmit: true,
                  dismissKeyboardOnTapOutside: true,
                  hintText: t.sourceShell.search,
                  onSubmitted: _searchThisSource,
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
