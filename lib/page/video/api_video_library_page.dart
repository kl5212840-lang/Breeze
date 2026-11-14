import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/video/api_video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/omofun_native_history_scope.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_catalog_index.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/video/api_video_filter_panel.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';

/// Deliberately does not retain exception text: plugin errors can embed request
/// arguments, authentication objects and search text. Diagnostics need evidence,
/// not a dump of those values.
String _catalogFailureSummary(Object error) {
  final cause = error is ApiVideoStageFailure ? error.cause : error;
  final stage =
      error is ApiVideoStageFailure &&
          const {
            'network_session',
            'plugin_data',
            'plugin_resolution',
            'media_relay',
          }.contains(error.stage)
      ? error.stage
      : 'catalog_result';
  final text = cause.toString().toLowerCase();
  final status = RegExp(
    r'(?:http(?:\s+error)?|status(?:code)?[ :=]*)\s*([1-5]\d\d)|资源接口暂不可用[（(]([1-5]\d\d)[）)]',
  ).firstMatch(text);
  final http = status?.group(1) ?? status?.group(2) ?? 'unknown';
  final reason = switch (text) {
    _
        when cause is TimeoutException ||
            text.contains('timeout') ||
            text.contains('timed out') =>
      'timeout',
    _ when text.contains('abort') => 'aborted',
    _ when text.contains('tls') || text.contains('certificate') => 'tls',
    _ when text.contains('dns') || text.contains('host lookup') => 'dns',
    _
        when text.contains('connection') ||
            text.contains('socket') ||
            text.contains('fetch failed') =>
      'transport',
    _ when text.contains('referenceerror') => 'javascript_reference',
    _ when text.contains('typeerror') => 'javascript_type',
    _ when text.contains('syntaxerror') => 'javascript_syntax',
    _ when text.contains('未返回有效数据') || text.contains('json') => 'invalid_json',
    _
        when cause is FormatException ||
            text.contains('数据格式') ||
            text.contains('列表格式') =>
      'invalid_data',
    _ when text.contains('暂时无法读取分类') => 'missing_categories',
    _ when http == '401' || http == '403' => 'access_denied',
    _ => 'unclassified',
  };
  final type = cause is FormatException
      ? 'FormatException'
      : cause is TimeoutException
      ? 'TimeoutException'
      : cause is StateError
      ? 'StateError'
      : cause is ArgumentError
      ? 'ArgumentError'
      : cause is PlatformException
      ? 'PlatformException'
      : 'Other';
  return 'stage=$stage type=$type http=$http reason=$reason';
}

const _omoRecommendationGroups = ['week', 'rank', 'topics'];
const _omoAccountIndex = 4;

bool _isOmoRecommendationCategory(ApiVideoCategory category) =>
    _omoRecommendationGroups.contains(category.id) ||
    _omoRecommendationGroups.contains(category.parentId);

class ApiVideoLibraryPage extends StatefulWidget {
  const ApiVideoLibraryPage({
    super.key,
    required this.repository,
    required this.title,
    this.initialQuery = '',
    this.initialFilters,
    this.initialKeywordScope,
    this.initialBrowseUrl,
    this.siteClient,
    this.initialSection = 'discover',
    this.searchTask = false,
    this.initialSearchCategories = const [],
    Future<OmoNetworkContext?>? borrowedNetwork,
    this.bookshelfItem,
    this.bookshelfResume,
    this.forDownloadRecovery = false,
    this.requireExactResume = false,
    this.embedded = false,
    this.browseOnly = false,
    this.active = true,
    this.moduleControl,
    this.leading,
  }) : _borrowedNetwork = borrowedNetwork;
  final bool embedded, active;

  /// A standalone keyword task can keep its editor and results on one route.
  final bool searchTask;
  final List<ApiVideoCategory> initialSearchCategories;
  final Future<OmoNetworkContext?>? _borrowedNetwork;

  /// Opt-in for a source shell whose profile owns local records.
  final bool browseOnly;
  final Widget? moduleControl, leading;
  final ApiVideoRepository repository;
  final String title, initialQuery;
  final VideoSearchFilters? initialFilters;
  final KeywordSearchScope? initialKeywordScope;
  final Uri? initialBrowseUrl;
  final OmoSiteClient? siteClient;
  final String initialSection;
  final ApiVideoItem? bookshelfItem;
  final Uri? bookshelfResume;
  final bool forDownloadRecovery, requireExactResume;
  @override
  State<ApiVideoLibraryPage> createState() => _ApiVideoLibraryPageState();
}

class _ApiVideoLibraryPageState extends State<ApiVideoLibraryPage> {
  late final ApiVideoRepository _repository;
  ApiVideoBrowserSession? _browser;
  Future<OmoNetworkContext?>? _network;
  Future<SourceNetworkLease?>? _networkLease;
  OmoSiteClient? _site;
  Object? _downloadRetryResolver;
  StreamSubscription<PluginLoginSucceeded>? _accountLoginEvents;
  StreamSubscription<PluginAccountSignedOut>? _accountLogoutEvents;
  bool get _embedded => widget.embedded && !_omo;
  bool get _omo => _site != null && _repository.capabilities.animePresentation;
  bool get _recordTask =>
      !_omo && const {'favorite', 'history'}.contains(widget.initialSection);
  bool get _compactBrowsing =>
      (_embedded || _remoteSearchTask) && widget.browseOnly;
  bool get _websiteSearch => _repository.capabilities.search == 'website';
  bool get _remoteSearchTask => widget.searchTask && !_websiteSearch;
  bool get _opensRemoteSearchTask =>
      !_remoteSearchTask &&
      _repository.capabilities.search == 'full' &&
      !_repository.capabilities.browserCatalog;
  bool get _siteSearchInHeader =>
      _repository.capabilities.canSearch && _browseUrl == null;

  bool _putCatalogViewInMore(BuildContext context) =>
      _showOmoRecommendations &&
      _tab == 0 &&
      _siteSearchInHeader &&
      (MediaQuery.sizeOf(context).width <
              (AppInterfaceStyleScope.usesSystem(context) ? 400 : 460) ||
          MediaQuery.textScalerOf(context).scale(14) > 20);

  Widget? _catalogViewButton() {
    if (_repository.capabilities.animePresentation) return null;
    final grid = _modeFor('library') == ApiVideoView.grid;
    return SourceChromeIconButton(
      key: const ValueKey('api-catalog.view-mode'),
      tooltip: grid ? t.videoLibrary.detailList : t.videoLibrary.grid,
      icon: grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
      symbol: grid ? 'list.bullet' : 'square.grid.2x2',
      onPressed: _savingViews.contains('library')
          ? null
          : () => unawaited(_toggleView('library')),
    );
  }

  bool get _localCatalogSupported {
    final caps = _repository.capabilities;
    return !_websiteSearch &&
        !caps.year &&
        !caps.sourceSort &&
        !caps.recent &&
        !caps.animePresentation;
  }

  String _localCatalogQuery = '';
  final _visited = <int>{};
  final _viewModes = <String, ValueNotifier<ApiVideoView>>{
    for (final section in ['library', 'favorite', 'history'])
      section: ValueNotifier<ApiVideoView>(ApiVideoView.grid),
  };
  String get _viewSection => _omo
      ? 'library'
      : (_tab == 1
            ? 'favorite'
            : _tab == 2
            ? 'history'
            : 'library');
  bool get _showOmoRecommendations =>
      _omo && !_remoteSearchTask && widget.initialBrowseUrl == null;
  bool get _omoRecommendationActive =>
      _showOmoRecommendations &&
      _tab > 0 &&
      _tab <= _omoRecommendationGroups.length;

  String _recommendationTitle(String group) => switch (group) {
    'week' => t.videoSource.schedule,
    'rank' => t.videoSource.ranking,
    _ => t.videoSource.topics,
  };
  ApiVideoView _modeFor(String section) => _viewModes[section]!.value;
  ApiVideoView get _mode => _modeFor(_viewSection);
  Future<ApiVideoResult>? _recommendationMetadata;
  late String _query = widget.initialFilters?.query ?? widget.initialQuery;
  late KeywordSearchScope _keywordScope =
      widget.initialKeywordScope ?? KeywordSearchScope.all;
  late KeywordSearchScope? _remoteKeywordScope = widget.initialKeywordScope;
  late VideoSearchFilters _searchFilters =
      widget.initialFilters ?? VideoSearchFilters(query: widget.initialQuery);
  final _catalogKey = GlobalKey<_ApiCatalogState>();
  late List<ApiVideoCategory> _catalogCategories =
      widget.initialSearchCategories;
  late Uri? _browseUrl = widget.initialBrowseUrl;
  int _tab = 0;
  final _catalogSearchFocus = FocusNode();
  bool _editingCatalogSearch = false;
  int _catalogQueryRevision = 0;
  late KeywordSearchScope _draftKeywordScope;
  VideoSearchFilters? _draftSearchFilters;

  final _savingViews = <String>{};
  bool get _savingView => _savingViews.contains(_viewSection);
  final _viewReadEpochs = <String, int>{}, _viewWriteEpochs = <String, int>{};
  bool _diagnostics = false;
  bool _openingOfficialSearch = false;
  bool _openingCatalogSearchTask = false;
  int _diagnosticEpoch = 0;
  String get _viewKey => 'breeze.video.library.view.${_repository.source}';
  String _viewScope(String section) =>
      'plugin|${_repository.source}|'
      '${_repository.capabilities.itemNamespace.isNotEmpty ? _repository.capabilities.itemNamespace : _repository.home}|$section';
  @override
  void initState() {
    super.initState();
    final borrowedNetwork = widget._borrowedNetwork;
    if (borrowedNetwork == null) {
      _networkLease = SourceNetworkPolicies.supports(widget.repository.source)
          ? SourceNetworkPolicies.acquire(widget.repository.source)
          : Future.value(null);
      _network = _networkLease!.then(
        (lease) => lease == null
            ? null
            : OmoNetworkContext.open(
                null,
                source: widget.repository.source,
                siteOrigins: [widget.repository.home],
              ),
      );
      unawaited(
        _network!.then<void>(
          (_) {},
          onError: (Object error) {
            debugPrint('Video network initialization: ${error.runtimeType}');
          },
        ),
      );
    } else {
      _network = borrowedNetwork;
    }
    final original = borrowedNetwork == null
        ? widget.repository.withNetwork(_network!)
        : widget.repository;
    if (original.capabilities.browserCatalog) {
      _browser = ApiVideoBrowserSession(
        accountSource: original.capabilities.siteAccount
            ? original.source
            : null,
        home: original.home,
        network: _network,
        paths: original.capabilities.browserPaths,
        itemPrefix: original.capabilities.browserItemPrefix,
      );
    }
    _repository = _browser == null
        ? original
        : original.withBrowserRead(
            _browser!.read,
            detailReader: _browser!.readDetail,
            retainForDownloads: _browser!.retainForDownloads,
            networkContext: _network,
            recoveryAllowed: () => _browser?.visible != true,
            recoveryActivity: _browser,
          );
    if (borrowedNetwork == null) {
      _downloadRetryResolver = registerApiVideoDownloadRetry(
        _repository,
        current: () => mounted,
      );
    }
    _site =
        widget.siteClient ??
        (original.capabilities.siteAccount && _browser != null
            ? OmoSiteClient(
                home: original.home,
                request: _browser!.requestOmoSite,
              )
            : null);
    if (_omo && widget.initialSection == 'me') {
      _tab = _omoAccountIndex;
    } else if (_recordTask) {
      _tab = widget.initialSection == 'favorite' ? 1 : 2;
    }
    _visited.add(_tab);
    if (_remoteSearchTask && _query.isEmpty) {
      _editingCatalogSearch = true;
      _draftKeywordScope = _keywordScope;
      _draftSearchFilters = _initialKeywordFilters;
      requestSearchKeyboard(
        _catalogSearchFocus,
        isCurrent: () => mounted && _editingCatalogSearch,
      );
    }
    if (_websiteSearch) {
      _localCatalogQuery = VideoSearchHistory.clean(_query);
      _query = '';
      _searchFilters = _searchFilters.copyWith(query: '');
    }
    _accountLoginEvents = eventBus.on<PluginLoginSucceeded>().listen((event) {
      if (mounted && event.from == _repository.source)
        _site?.invalidateAccount();
    });
    _accountLogoutEvents = eventBus.on<PluginAccountSignedOut>().listen((
      event,
    ) {
      if (mounted && event.from == _repository.source)
        _site?.invalidateAccount();
    });
    _viewPreferencesChanged();
    CollectionViewPreferences.changes.addListener(_viewPreferencesChanged);
    PortablePreferences.changes.addListener(_viewPreferencesChanged);
    if (widget.bookshelfItem != null && _browser != null) {
      unawaited(
        _browser!
            .read(_repository.home)
            .catchError((Object _) => <String, dynamic>{}),
      );
    }
    SourceDiagnosticPreferences.changes.addListener(_readDiagnostics);
    _readDiagnostics();
  }

  @override
  void didUpdateWidget(covariant ApiVideoLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _endCatalogSearch();
  }

  @override
  void dispose() {
    _catalogSearchFocus.dispose();
    final retry = _downloadRetryResolver;
    if (retry != null) VideoDownloadRetry.unregister(_repository.source, retry);
    unawaited(_accountLoginEvents?.cancel());
    unawaited(_accountLogoutEvents?.cancel());
    for (final section in _viewModes.keys) {
      _viewReadEpochs[section] = (_viewReadEpochs[section] ?? 0) + 1;
      _viewWriteEpochs[section] = (_viewWriteEpochs[section] ?? 0) + 1;
    }
    CollectionViewPreferences.changes.removeListener(_viewPreferencesChanged);
    PortablePreferences.changes.removeListener(_viewPreferencesChanged);
    for (final mode in _viewModes.values) {
      mode.dispose();
    }
    _browser?.dispose();
    final network = _network;
    if (network != null && widget._borrowedNetwork == null) {
      unawaited(
        network.then<void>(
          (value) async => value?.close(),
          onError: (Object _) {},
        ),
      );
    }
    unawaited(
      _networkLease?.then<void>(
        (lease) async => lease?.close(),
        onError: (Object _) {},
      ),
    );
    if (widget.siteClient == null) _site?.dispose();
    _diagnosticEpoch++;
    SourceDiagnosticPreferences.changes.removeListener(_readDiagnostics);
    super.dispose();
  }

  Future<void> _readDiagnostics() async {
    final epoch = ++_diagnosticEpoch;
    final enabled = await SourceDiagnosticPreferences.enabled(
      _repository.source,
    );
    if (mounted && epoch == _diagnosticEpoch) {
      setState(() => _diagnostics = enabled);
    }
  }

  Future<void> _analyzeLibrary() => showVideoTaskSheet<void>(
    context: context,
    builder: (_) => VideoPageAnalysis(
      analyze: () async {
        final catalog = _catalogKey.currentState;
        final status = catalog?._failed == true
            ? t.common.loadingFailed
            : catalog?._loading == true
            ? t.common.loading
            : t.videoPlayback.analysisDisplayed;
        return VideoPageAnalysisResult(
          mode: t.videoPlayback.nativeCatalog,
          page: widget.title,
          status: status,
          report:
              'Breeze API library\nsource: ${_repository.source}\n'
              'state: $status\nitems: ${catalog?._items.length ?? 0}\n'
              'categories: ${catalog?._categories.length ?? 0}\nview: ${_mode.name}\n'
              'query_present: ${_query.isNotEmpty}\n'
              'last_failure: ${catalog?._lastFailure ?? 'none'}\n'
              '${_browser?.diagnosticReport() ?? "browser: not required"}\n'
              'Local state only. No requests, search text, history or account data included.',
        );
      },
      onCopy: (report) => Clipboard.setData(ClipboardData(text: report)),
    ),
  );

  void _viewPreferencesChanged() {
    for (final section in _viewModes.keys) {
      if (!_savingViews.contains(section)) unawaited(_readView(section));
    }
  }

  Future<void> _readView(String section) async {
    final epoch = (_viewReadEpochs[section] ?? 0) + 1;
    _viewReadEpochs[section] = epoch;
    final scope = _viewScope(section);
    try {
      final value = await CollectionViewPreferences.read(
        scope,
        legacyKey: _viewKey,
      );
      if (mounted &&
          epoch == _viewReadEpochs[section] &&
          scope == _viewScope(section) &&
          !_savingViews.contains(section)) {
        setState(
          () => _viewModes[section]!.value = value == 'list'
              ? ApiVideoView.list
              : ApiVideoView.grid,
        );
      }
    } catch (_) {
      // Unavailable preferences must not block the existing collection.
    }
  }

  Future<void> _toggleView([String? requestedSection]) async {
    final section = requestedSection ?? _viewSection;
    if (_savingViews.contains(section)) return;
    final old = _modeFor(section), scope = _viewScope(section);
    final epoch = (_viewWriteEpochs[section] ?? 0) + 1;
    _viewWriteEpochs[section] = epoch;
    _viewReadEpochs[section] = (_viewReadEpochs[section] ?? 0) + 1;
    setState(() {
      _savingViews.add(section);
      _viewModes[section]!.value = old == ApiVideoView.grid
          ? ApiVideoView.list
          : ApiVideoView.grid;
    });
    try {
      await CollectionViewPreferences.write(scope, _modeFor(section).name);
    } catch (_) {
      if (mounted &&
          epoch == _viewWriteEpochs[section] &&
          scope == _viewScope(section)) {
        setState(() => _viewModes[section]!.value = old);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoLibrary.saveFailed)));
      }
    } finally {
      if (mounted &&
          epoch == _viewWriteEpochs[section] &&
          scope == _viewScope(section)) {
        setState(() => _savingViews.remove(section));
        await _readView(section);
      }
    }
  }

  List<ApiVideoCategory> _groupChoices(String group) => _catalogCategories
      .where((category) => category.parentId == group && category.selectable)
      .toList();

  Future<List<ApiVideoCategory>> _readRecommendationChoices(
    String group,
  ) async {
    // An early tap can reuse the initial Discover read. If it did not contain
    // this group (for example, entering from My), query its metadata separately.
    await _catalogKey.currentState?._currentLoadTask;
    final available = _groupChoices(group);
    if (available.isNotEmpty || !mounted) return available;
    final pending = _recommendationMetadata ??= _repository.page();
    try {
      final result = await pending;
      return result.categories
          .where(
            (category) => category.parentId == group && category.selectable,
          )
          .toList();
    } finally {
      if (identical(_recommendationMetadata, pending)) {
        _recommendationMetadata = null;
      }
    }
  }

  Future<void> _openOfficialSearch(String query) async {
    if (_openingOfficialSearch ||
        query.isEmpty ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final caps = _repository.capabilities;
    final path = caps.searchPath;
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(caps.searchParameter)) {
      return;
    }
    final url = _repository.home
        .resolve(path)
        .replace(queryParameters: {caps.searchParameter: query});
    if (url.origin != _repository.home.origin) return;
    _openingOfficialSearch = true;
    try {
      await Navigator.of(context).push<void>(
        videoPageRoute(
          networkSource: _repository.source,
          network: _network,
          builder: (_) => OmoSiteWebPage(
            home: _repository.home,
            url: url,
            title: t.videoLibrary.officialSearch,
            network: _network,
            browsingSource: _repository.source,
          ),
        ),
      );
    } finally {
      _openingOfficialSearch = false;
    }
  }

  VideoSearchFilters get _initialKeywordFilters {
    final initial = _catalogKey.currentState?.draftFilters ?? _searchFilters;
    return !_repository.capabilities.filtersOnSearch && _query.isEmpty
        ? initial.copyWith(genre: '', date: '', sort: '')
        : initial;
  }

  Future<void> _openCatalogSearchTask() async {
    if (_openingCatalogSearchTask) return;
    _openingCatalogSearchTask = true;
    try {
      await Navigator.of(context).push<void>(
        videoPageRoute(
          settings: const RouteSettings(name: 'breeze.video.search-task'),
          networkSource: _repository.source,
          network: _network,
          builder: (_) => ApiVideoLibraryPage(
            repository: _repository,
            title: widget.title,
            searchTask: true,
            browseOnly: widget.browseOnly,
            initialKeywordScope: _keywordScope,
            initialFilters: _initialKeywordFilters.copyWith(query: '', page: 1),
            initialSearchCategories: _catalogCategories,
            borrowedNetwork: _network,
          ),
        ),
      );
    } finally {
      _openingCatalogSearchTask = false;
    }
  }

  Future<void> _openSearchEditor() async {
    final caps = _repository.capabilities;
    if (!caps.canSearch) return;
    var scope = _keywordScope;
    var initial = _catalogKey.currentState?.draftFilters ?? _searchFilters;
    if (!caps.filtersOnSearch && _query.isEmpty) {
      initial = initial.copyWith(genre: '', date: '', sort: '');
    }
    final result = await Navigator.of(context).push<VideoSearchFilters>(
      videoPageRoute(
        networkSource: _repository.source,
        network: _network,
        builder: (_) => VideoSearchPage(
          source: _repository.source,
          initial: initial.copyWith(
            query: _websiteSearch ? _localCatalogQuery : _query,
          ),
          authorEnabled: false,
          initialScope: scope,
          onSubmitScope: (value) => scope = value,
          hint: caps.searchHint.isEmpty
              ? t.videoLibrary.searchHint
              : caps.searchHint,
          scopeHint: caps.search == 'website'
              ? t.videoLibrary.officialSearchHint
              : null,
          filterBuilder: apiVideoKeywordFilterBuilder(
            caps,
            source: _repository.source,
            namespace: caps.itemNamespace,
            categories: _showOmoRecommendations
                ? _catalogCategories
                      .where((value) => !_isOmoRecommendationCategory(value))
                      .toList()
                : _catalogCategories,
            initialCategory: initial.genre,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _submitCatalogSearch(result.query, filters: result, selectedScope: scope);
  }

  void _beginCatalogSearch() {
    if (_editingCatalogSearch) return;
    setState(() {
      _editingCatalogSearch = true;
      _draftKeywordScope = _keywordScope;
      _draftSearchFilters = _initialKeywordFilters;
    });
  }

  void _endCatalogSearch() {
    if (!_editingCatalogSearch) return;
    _catalogSearchFocus.unfocus();
    setState(() {
      _editingCatalogSearch = false;
      _draftSearchFilters = null;
      _catalogQueryRevision++;
    });
  }

  Widget Function(BuildContext, VideoSearchFilters)?
  get _keywordFilterBuilder => apiVideoKeywordFilterBuilder(
    _repository.capabilities,
    source: _repository.source,
    namespace: _repository.capabilities.itemNamespace,
    categories: _showOmoRecommendations
        ? _catalogCategories
              .where((value) => !_isOmoRecommendationCategory(value))
              .toList()
        : _catalogCategories,
    initialCategory: (_draftSearchFilters ?? _initialKeywordFilters).genre,
  );

  Future<void> _editKeywordFilters() async {
    final builder = _keywordFilterBuilder;
    if (builder == null || !_editingCatalogSearch) return;
    final draft = _draftSearchFilters!;
    _catalogSearchFocus.unfocus();
    final result = await showVideoTaskSheet<VideoSearchFilters>(
      context: context,
      builder: (context) => builder(context, draft),
    );
    if (mounted && _editingCatalogSearch && result != null) {
      setState(() => _draftSearchFilters = result);
    }
  }

  void _submitCatalogSearch(
    String value, {
    VideoSearchFilters? filters,
    KeywordSearchScope? selectedScope,
  }) {
    final query = VideoSearchHistory.clean(value);
    if (query.isEmpty) return;
    final caps = _repository.capabilities;
    final scope =
        selectedScope ??
        (_editingCatalogSearch ? _draftKeywordScope : _keywordScope);
    final result = (filters ?? _draftSearchFilters ?? _initialKeywordFilters)
        .copyWith(query: query, page: 1);
    _endCatalogSearch();
    unawaited(
      VideoSearchHistory.add(_repository.source, query).catchError((Object _) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.videoSearch.historyWriteFailed)),
          );
        }
      }),
    );
    if (_websiteSearch) {
      setState(() {
        _localCatalogQuery = query;
        _keywordScope = scope;
      });
      return;
    }
    final next = !caps.filtersOnSearch && query != _query
        ? result.copyWith(genre: '', date: '', sort: '', completed: false)
        : result;
    setState(() {
      _query = query;
      _keywordScope = scope;
      _remoteKeywordScope = scope;
      _searchFilters = next;
      _browseUrl = null;
      _tab = 0;
    });
  }

  void _clearCatalogQuery() {
    _endCatalogSearch();
    setState(() {
      if (_remoteSearchTask) {
        _query = '';
        _searchFilters = _repository.capabilities.filtersOnSearch
            ? _searchFilters.copyWith(query: '', page: 1)
            : const VideoSearchFilters();
        _editingCatalogSearch = true;
        _draftKeywordScope = _keywordScope;
        _draftSearchFilters = _searchFilters;
      } else if (_websiteSearch) {
        _localCatalogQuery = '';
      } else {
        _query = '';
        // Search-only local filters belong to the previous query's results.
        _searchFilters = _repository.capabilities.filtersOnSearch
            ? _searchFilters.copyWith(query: '')
            : const VideoSearchFilters();
      }
    });
  }

  Future<void> _open(
    ApiVideoItem item, {
    Uri? resume,
    bool requireExactResume = false,
  }) async {
    // The detail page shares this request/cache. Record only the explicit
    // opened item's public detail; never crawl unvisited rows for filtering.
    _catalogKey.currentState?._observeOpenedItem(item);
    await Navigator.of(context).push<void>(
      videoPageRoute(
        settings: videoDetailRouteSettings(_repository.source),
        networkSource: _repository.source,
        network: _network,
        builder: (_) => ApiVideoDetailPage(
          repository: _repository,
          initialItem: item,
          resume: resume,
          requireExactResume: requireExactResume,
          siteClient: _site,
        ),
      ),
    );
  }

  void _selectTab(int value) {
    _endCatalogSearch();
    setState(() {
      _tab = value;
      _visited.add(value);
    });
  }

  void _rememberDetail(ApiVideoItem item) {
    unawaited(
      VideoLibraryStore.shared
          .observeDetails(_repository.source, [item])
          .catchError((Object _) {}),
    );
  }

  Future<void> _localHistory() => Navigator.of(context).push<void>(
    videoPageRoute(
      settings: const RouteSettings(name: 'breeze.video.local-history'),
      networkSource: _repository.source,
      network: _network,
      builder: (_) => ValueListenableBuilder<ApiVideoView>(
        valueListenable: _viewModes['history']!,
        builder: (context, mode, _) => Scaffold(
          body: ApiVideoHistory(
            compactHeader: true,
            headerLeading: const SourceBackButton(),
            onToggleView: () => unawaited(_toggleView('history')),
            loadDetail: _repository.enrich,
            onDetailLoaded: _rememberDetail,
            source: _repository.source,
            home: _repository.home,
            itemNamespace: _repository.capabilities.itemNamespace,
            posterAspectRatio: _repository.capabilities.posterAspectRatio,
            mode: mode,
            onOpen: (item, resume) => _open(item, resume: resume),
          ),
        ),
      ),
    ),
  );

  Future<void> _localFavorites() => Navigator.of(context).push<void>(
    videoPageRoute(
      settings: const RouteSettings(name: 'breeze.video.local-favorites'),
      networkSource: _repository.source,
      network: _network,
      builder: (_) => ValueListenableBuilder<ApiVideoView>(
        valueListenable: _viewModes['favorite']!,
        builder: (context, mode, _) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: ApiVideoFavorites(
              compactHeader: true,
              headerLeading: const SourceBackButton(),
              onToggleView: () => unawaited(_toggleView('favorite')),
              loadDetail: _repository.enrich,
              onDetailLoaded: _rememberDetail,
              source: _repository.source,
              mode: mode,
              onOpen: _open,
              repository: _repository,
              onExplore: () {
                Navigator.of(context).pop();
                _selectTab(0);
              },
              onImportSite: () => unawaited(_siteFollows(importing: true)),
              compact: MediaQuery.viewInsetsOf(context).bottom > 0,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _siteFollows({bool importing = false}) {
    var selecting = importing;
    return Navigator.of(context).push<void>(
      videoPageRoute(
        settings: const RouteSettings(name: 'breeze.video.site-follows'),
        networkSource: _repository.source,
        network: _network,
        builder: (_) => ValueListenableBuilder<ApiVideoView>(
          valueListenable: _viewModes['favorite']!,
          builder: (context, mode, _) => Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => OmoSiteFavoritesPage(
                standalone: true,
                active: true,
                onToggleView: () => unawaited(_toggleView('favorite')),
                loadDetail: _repository.enrich,
                onDetailLoaded: _rememberDetail,
                client: _site!,
                source: _repository.source,
                mode: mode,
                onOpen: _open,
                importing: selecting,
                onImportMode: (value) => update(() => selecting = value),
                onImported: () => update(() => selecting = false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: _repository.source,
    builder: (context) => VideoNetworkScope(
      source: _repository.source,
      network: _network,
      child: OmoNativeHistoryScope(
        source: _repository.source,
        mode: _modeFor('history'),
        openEntry: (entry) async {
          if (!mounted ||
              entry.url.origin != _repository.home.origin ||
              entry.url.scheme != 'https' ||
              entry.url.userInfo.isNotEmpty ||
              (entry.resume == null &&
                  !RegExp(
                    r'^/anime/[a-f0-9]{16,64}\.html$',
                  ).hasMatch(entry.url.path))) {
            throw const FormatException('History episode unavailable');
          }
          await _open(
            entry.item,
            resume: entry.resume,
            requireExactResume: entry.resume != null,
          );
        },
        child: _buildPage(context),
      ),
    ),
  );

  Widget _recordSafeBody(Widget child) =>
      !_omo && _tab != 0 ? SafeArea(bottom: false, child: child) : child;

  Widget _catalogBody(Widget content) => Stack(
    fit: StackFit.expand,
    children: [
      content,
      if (widget.active &&
          _tab == 0 &&
          (_editingCatalogSearch || _remoteSearchTask && _query.isEmpty))
        Positioned.fill(
          child: CatalogSearchOverlay(
            source: _repository.source,
            inPage: _remoteSearchTask && _query.isEmpty,
            hint: _websiteSearch ? t.videoLibrary.officialSearchHint : null,
            onSubmit: _submitCatalogSearch,
            onClose: _remoteSearchTask && _query.isEmpty
                ? null
                : _endCatalogSearch,
            controls: _keywordFilterBuilder == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SourceFilterIconButton(
                      key: const ValueKey('video-search.filters'),
                      tooltip: t.videoFilters.title,
                      active: (_draftSearchFilters?.activeCount ?? 0) != 0,
                      onPressed: _editKeywordFilters,
                    ),
                  ),
          ),
        ),
    ],
  );

  Widget _embeddedBody(Widget content) {
    final catalog = _catalogBody(content);
    if (!_embedded) return catalog;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.moduleControl case final module?) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: module,
                ),
                const SizedBox(height: 4),
              ],
              if (!widget.browseOnly)
                NativeVideoSegmentedControl(
                  key: const ValueKey('api-library.scope'),
                  selected: '$_tab',
                  options: {
                    '0': t.videoLibrary.library,
                    '1': t.videoLibrary.favorites,
                    '2': t.videoLibrary.history,
                  },
                  onSelected: (value) => _selectTab(int.parse(value)),
                ),
            ],
          ),
        ),
        Expanded(child: catalog),
      ],
    );
  }

  Widget _buildPage(BuildContext context) => widget.bookshelfItem != null
      ? Theme(
          data: videoBrowseTheme(Theme.of(context)),
          child: Stack(
            children: [
              ApiVideoDetailPage(
                repository: _repository,
                initialItem: widget.bookshelfItem!,
                resume: widget.bookshelfResume,
                forDownloadRecovery: widget.forDownloadRecovery,
                requireExactResume: widget.requireExactResume,
                siteClient: _site,
              ),
              if (_browser != null)
                Positioned.fill(child: ApiVideoBrowserHost(session: _browser!)),
            ],
          ),
        )
      : Theme(
          data: videoBrowseTheme(Theme.of(context)),
          child: PopScope<Object?>(
            canPop:
                !_editingCatalogSearch ||
                !widget.active ||
                _remoteSearchTask && _query.isEmpty,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && widget.active) _endCatalogSearch();
            },
            child: Stack(
              children: [
                Scaffold(
                  extendBody: !_embedded && usesNativeSourceChrome(context),
                  appBar: !_omo && _tab != 0
                      ? null
                      : SearchToolbarScope.appBar(
                          context,
                          (height) => AppBar(
                            toolbarHeight: height,
                            leadingWidth: height == null ? null : 56,
                            leading: _embedded
                                ? widget.leading
                                : SourceBackButton(
                                    onPressed: _remoteSearchTask
                                        ? () => Navigator.of(context).pop()
                                        : null,
                                  ),
                            automaticallyImplyLeading: !_embedded,
                            titleSpacing: 0,
                            title: _tab == 0 && _siteSearchInHeader
                                ? VideoSearchEntry(
                                    query: _websiteSearch
                                        ? _localCatalogQuery
                                        : _query,
                                    hint:
                                        _repository
                                            .capabilities
                                            .searchHint
                                            .isEmpty
                                        ? t.videoLibrary.searchHint
                                        : _repository.capabilities.searchHint,
                                    onTap: _remoteSearchTask || _websiteSearch
                                        ? _beginCatalogSearch
                                        : _opensRemoteSearchTask
                                        ? _openCatalogSearchTask
                                        : _openSearchEditor,
                                    onSubmitted:
                                        _remoteSearchTask || _websiteSearch
                                        ? _submitCatalogSearch
                                        : null,
                                    onClear: _opensRemoteSearchTask
                                        ? null
                                        : _clearCatalogQuery,
                                    focusNode: _catalogSearchFocus,
                                    queryRevision: _catalogQueryRevision,
                                  )
                                : _tab == 0 &&
                                      _compactBrowsing &&
                                      _localCatalogSupported
                                ? SearchQueryField(
                                    key: const ValueKey(
                                      'api-catalog.local-query',
                                    ),
                                    query: _localCatalogQuery,
                                    inline: true,
                                    hintText:
                                        t.videoLibrary.localCatalogSearchHint,
                                    semanticLabel:
                                        t.videoLibrary.localCatalogSearchHint,
                                    onChanged: (value) => setState(
                                      () => _localCatalogQuery = value,
                                    ),
                                  )
                                : Text(
                                    _omo && _tab == _omoAccountIndex
                                        ? t.omoAccount.my
                                        : _omoRecommendationActive
                                        ? _recommendationTitle(
                                            _omoRecommendationGroups[_tab - 1],
                                          )
                                        : widget.title,
                                  ),
                            actions: [
                              const SizedBox(width: 8),
                              if (_tab == 0 &&
                                  (_siteSearchInHeader ||
                                      _compactBrowsing &&
                                          _localCatalogSupported))
                                KeywordScopeMenu(
                                  compact:
                                      MediaQuery.sizeOf(context).width < 400 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) >
                                          20,
                                  scope: _editingCatalogSearch
                                      ? _draftKeywordScope
                                      : _keywordScope,
                                  onChanged: (scope) => setState(() {
                                    if (_editingCatalogSearch) {
                                      _draftKeywordScope = scope;
                                    } else {
                                      _keywordScope = scope;
                                      if (_siteSearchInHeader &&
                                          !_websiteSearch) {
                                        _remoteKeywordScope = scope;
                                      }
                                    }
                                  }),
                                ),
                              if (_tab == 0 &&
                                  !_editingCatalogSearch &&
                                  (!_remoteSearchTask || _query.isNotEmpty) &&
                                  widget.initialBrowseUrl == null &&
                                  (_query.isNotEmpty &&
                                          _repository
                                              .capabilities
                                              .filtersOnSearch ||
                                      _repository.capabilities.year ||
                                      _repository.capabilities.sourceSort ||
                                      _compactBrowsing &&
                                          _localCatalogSupported))
                                SourceChromeIconButton(
                                  key: const ValueKey('api-library.filters'),
                                  tooltip: t.videoFilters.title,
                                  symbol: 'line.3.horizontal.decrease',
                                  icon: Icons.filter_list_rounded,
                                  onPressed: () =>
                                      _catalogKey.currentState?.editFilters(),
                                ),
                              if (_omoRecommendationActive ||
                                  _showOmoRecommendations &&
                                      _tab == 0 &&
                                      !_putCatalogViewInMore(context))
                                SourceChromeIconButton(
                                  key: const ValueKey('api-library.view-mode'),
                                  tooltip: _mode == ApiVideoView.grid
                                      ? t.videoLibrary.detailList
                                      : t.videoLibrary.grid,
                                  symbol: _mode == ApiVideoView.grid
                                      ? 'list.bullet'
                                      : 'square.grid.2x2',
                                  icon: _mode == ApiVideoView.grid
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view_outlined,
                                  onPressed: _savingView ? null : _toggleView,
                                ),
                              if (_omo && _tab == _omoAccountIndex)
                                const CollectionCoverPrivacyButton(),
                              if (!_remoteSearchTask)
                                SourceMoreButton(
                                  source: _repository.source,
                                  showSettings:
                                      !(_omo && _tab == _omoAccountIndex) &&
                                      SourceSettingsShortcutScope.maybeOf(
                                            context,
                                          )?.source !=
                                          _repository.source,
                                  showCoverSettings: false,
                                  actions: [
                                    if (_putCatalogViewInMore(context) ||
                                        _tab == 0 &&
                                            !_showOmoRecommendations &&
                                            _repository
                                                .capabilities
                                                .animePresentation)
                                      SourceMenuAction(
                                        id: 'display',
                                        label: _mode == ApiVideoView.grid
                                            ? t.videoLibrary.detailList
                                            : t.videoLibrary.grid,
                                        icon: _mode == ApiVideoView.grid
                                            ? Icons.view_list_outlined
                                            : Icons.grid_view_outlined,
                                        symbol: _mode == ApiVideoView.grid
                                            ? 'list.bullet'
                                            : 'square.grid.2x2',
                                        onSelected: () =>
                                            unawaited(_toggleView()),
                                      ),
                                    if (_diagnostics)
                                      SourceMenuAction(
                                        id: 'analysis',
                                        label: t.videoPlayback.pageAnalysis,
                                        icon: Icons.analytics_outlined,
                                        symbol: 'waveform.path.ecg',
                                        onSelected: () =>
                                            unawaited(_analyzeLibrary()),
                                      ),
                                    SourceMenuAction(
                                      id: 'plugin',
                                      label: t.discover.settings,
                                      icon: Icons.settings_outlined,
                                      symbol: 'gearshape',
                                      onSelected: () => unawaited(
                                        openSourceSettings(
                                          context,
                                          source: _repository.source,
                                          sourceName: widget.title,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          searching:
                              _tab == 0 &&
                              (_siteSearchInHeader ||
                                  _compactBrowsing && _localCatalogSupported),
                        ),
                  body: _recordSafeBody(
                    _embeddedBody(
                      IndexedStack(
                        index: _tab,
                        children: [
                          if (_visited.contains(0) &&
                              (!_remoteSearchTask || _query.isNotEmpty))
                            _ApiCatalog(
                              compactBrowsing: _compactBrowsing,
                              siteSearchInHeader: _siteSearchInHeader,
                              headingAction: _catalogViewButton(),
                              localQuery: _compactBrowsing || _websiteSearch
                                  ? _localCatalogQuery
                                  : null,
                              onLocalQueryChanged: (value) =>
                                  setState(() => _localCatalogQuery = value),
                              onWebsiteSearch: _websiteSearch
                                  ? _openOfficialSearch
                                  : null,
                              loadDetail: _repository.enrich,
                              onDetailLoaded: _rememberDetail,
                              active: widget.active && _tab == 0,
                              key: _catalogKey,
                              keywordScope: _keywordScope,
                              remoteKeywordScope: _remoteKeywordScope,
                              onKeywordScopeChanged: (scope) =>
                                  setState(() => _keywordScope = scope),
                              searchFilters: _searchFilters,
                              onFiltersChanged: (filters) =>
                                  setState(() => _searchFilters = filters),
                              onCategories: (values) {
                                _catalogCategories =
                                    values.isEmpty && _remoteSearchTask
                                    ? widget.initialSearchCategories
                                    : values;
                              },
                              repository: _repository,
                              mode: _modeFor('library'),
                              query: _query,
                              browseUrl: _browseUrl,
                              onOpen: _open,
                              onClearQuery: _clearCatalogQuery,
                              onResume: (item, resume) =>
                                  _open(item, resume: resume),
                              separateRecommendationTabs:
                                  _showOmoRecommendations,
                            )
                          else
                            const SizedBox.shrink(),
                          if (!_remoteSearchTask && _omo) ...[
                            for (final (offset, group)
                                in _omoRecommendationGroups.indexed)
                              _visited.contains(offset + 1)
                                  ? _ApiRecommendationTab(
                                      key: ValueKey(
                                        'api-recommendation.$group',
                                      ),
                                      repository: _repository,
                                      group: group,
                                      title: _recommendationTitle(group),
                                      choices: _groupChoices(group),
                                      loadChoices: () =>
                                          _readRecommendationChoices(group),
                                      mode: _modeFor('library'),
                                      active:
                                          widget.active && _tab == offset + 1,
                                      onOpen: _open,
                                      onDetailLoaded: _rememberDetail,
                                    )
                                  : const SizedBox.shrink(),
                            _visited.contains(_omoAccountIndex)
                                ? OmoAccountPage(
                                    source: _repository.source,
                                    client: _site!,
                                    active:
                                        widget.active &&
                                        _tab == _omoAccountIndex,
                                    onLocalHistory: () => _localHistory(),
                                    localFavorites:
                                        SourceProfileLocalVideoFavorites(
                                          source: _repository.source,
                                          home: _repository.home,
                                          posterAspectRatio: _repository
                                              .capabilities
                                              .posterAspectRatio,
                                          active:
                                              widget.active &&
                                              _tab == _omoAccountIndex,
                                          onViewAll: () =>
                                              unawaited(_localFavorites()),
                                          onOpen: (item) =>
                                              unawaited(_open(item)),
                                        ),
                                    onSiteFollows: () => _siteFollows(),
                                  )
                                : const SizedBox.shrink(),
                          ] else if (!_remoteSearchTask) ...[
                            if (!_compactBrowsing &&
                                (!_recordTask || _tab == 1))
                              ApiVideoFavorites(
                                compactHeader: true,
                                headerLeading: _embedded
                                    ? widget.leading
                                    : const SourceBackButton(),
                                onToggleView: () =>
                                    unawaited(_toggleView('favorite')),
                                loadDetail: _repository.enrich,
                                onDetailLoaded: _rememberDetail,
                                source: _repository.source,
                                mode: _modeFor('favorite'),
                                onOpen: _open,
                                repository: _repository,
                                active: widget.active && _tab == 1,
                                onExplore: _recordTask
                                    ? null
                                    : () => _selectTab(0),
                                exploreLabel: t.videoLibrary.library,
                                compact:
                                    MediaQuery.viewInsetsOf(context).bottom > 0,
                              )
                            else
                              const SizedBox.shrink(),
                            if (!_compactBrowsing &&
                                (!_recordTask || _tab == 2))
                              ApiVideoHistory(
                                compactHeader: true,
                                headerLeading: _embedded
                                    ? widget.leading
                                    : const SourceBackButton(),
                                onToggleView: () =>
                                    unawaited(_toggleView('history')),
                                loadDetail: _repository.enrich,
                                onDetailLoaded: _rememberDetail,
                                active: widget.active && _tab == 2,
                                source: _repository.source,
                                home: _repository.home,
                                itemNamespace:
                                    _repository.capabilities.itemNamespace,
                                posterAspectRatio:
                                    _repository.capabilities.posterAspectRatio,
                                mode: _modeFor('history'),
                                onOpen: (item, resume) =>
                                    _open(item, resume: resume),
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  bottomNavigationBar:
                      _embedded ||
                          _remoteSearchTask ||
                          _recordTask ||
                          widget.initialBrowseUrl != null
                      ? null
                      : VideoNativeNavigation(
                          currentIndex: _tab,
                          onTap: _selectTab,
                          symbols: _omo
                              ? const [
                                  'sparkles',
                                  'calendar',
                                  'flame',
                                  'books.vertical',
                                  'person',
                                ]
                              : const ['film', 'star', 'clock'],
                          items: [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.video_library_outlined),
                              label: _omo
                                  ? t.videoSource.discover
                                  : t.videoLibrary.library,
                            ),
                            if (_omo) ...[
                              BottomNavigationBarItem(
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: t.videoSource.weeklyTab,
                              ),
                              BottomNavigationBarItem(
                                icon: const Icon(
                                  Icons.local_fire_department_outlined,
                                ),
                                label: t.videoSource.rankingTab,
                              ),
                              BottomNavigationBarItem(
                                icon: const Icon(
                                  Icons.collections_bookmark_outlined,
                                ),
                                label: t.videoSource.topicsTab,
                              ),
                            ] else
                              BottomNavigationBarItem(
                                icon: const Icon(Icons.star_border_rounded),
                                label: t.videoLibrary.favorites,
                              ),
                            BottomNavigationBarItem(
                              icon: Icon(
                                _omo
                                    ? Icons.person_outline_rounded
                                    : Icons.history_rounded,
                              ),
                              label: _omo
                                  ? t.videoSource.me
                                  : t.videoLibrary.history,
                            ),
                          ],
                        ),
                ),
                if (_browser != null)
                  Positioned.fill(
                    child: ApiVideoBrowserHost(session: _browser!),
                  ),
              ],
            ),
          ),
        );
}

/// Recommendation tabs keep their own category and catalog. Discover's
/// query and filters are never used to build these requests.
class _ApiRecommendationTab extends StatefulWidget {
  const _ApiRecommendationTab({
    super.key,
    required this.repository,
    required this.group,
    required this.title,
    required this.choices,
    required this.loadChoices,
    required this.mode,
    required this.active,
    required this.onOpen,
    required this.onDetailLoaded,
  });
  final ApiVideoRepository repository;
  final String group, title;
  final List<ApiVideoCategory> choices;
  final Future<List<ApiVideoCategory>> Function() loadChoices;
  final ApiVideoView mode;
  final bool active;
  final Future<void> Function(ApiVideoItem, {Uri? resume}) onOpen;
  final ValueChanged<ApiVideoItem> onDetailLoaded;

  @override
  State<_ApiRecommendationTab> createState() => _ApiRecommendationTabState();
}

class _ApiRecommendationTabState extends State<_ApiRecommendationTab> {
  late List<ApiVideoCategory> _choices = widget.choices;
  String? _selected;
  bool _loading = false, _failed = false, _choosing = false;
  bool _recent = false, _recentVisited = false;

  @override
  void initState() {
    super.initState();
    _selectInitial();
    if (_selected == null) unawaited(_readChoices());
  }

  void _selectInitial() {
    if (_selected != null || _choices.isEmpty) return;
    final today = 'week:${DateTime.now().weekday - 1}';
    _selected =
        widget.group == 'week' && _choices.any((choice) => choice.id == today)
        ? today
        : _choices.first.id;
  }

  Future<void> _readChoices() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final choices = await widget.loadChoices();
      if (!mounted) return;
      setState(() {
        _choices = choices;
        _selectInitial();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose() async {
    if (_choosing ||
        !widget.active ||
        _selected == null ||
        _choices.length < 2) {
      return;
    }
    _choosing = true;
    try {
      final selected = await _chooseCatalogGroup(
        context,
        _choices,
        widget.title,
        _selected!,
        widget.repository.home,
      );
      if (!mounted ||
          !widget.active ||
          selected == null ||
          selected == _selected) {
        return;
      }
      setState(() => _selected = selected);
    } finally {
      _choosing = false;
    }
  }

  Widget _catalog(String type, {required bool visible}) => _ApiCatalog(
    key: ValueKey('api-recommendation.catalog.$type'),
    repository: widget.repository,
    mode: widget.mode,
    query: '',
    initialType: type,
    showFilters: false,
    active: widget.active && visible,
    loadDetail: widget.repository.enrich,
    onDetailLoaded: widget.onDetailLoaded,
    onCategories: (values) {
      final choices = values
          .where((value) => value.parentId == widget.group && value.selectable)
          .toList();
      if (choices.isNotEmpty && mounted && visible) {
        setState(() => _choices = choices);
      }
    },
    onOpen: (item) => widget.onOpen(item),
    onClearQuery: () {},
    onResume: (item, resume) => widget.onOpen(item, resume: resume),
  );

  Widget _recommendations() {
    final selected = _selected;
    if (selected == null) {
      return ApiVideoEmpty(
        title: _loading
            ? t.common.loading
            : _failed
            ? t.common.loadingFailed
            : t.videoLibrary.noResults,
        action: _loading
            ? null
            : TextButton(onPressed: _readChoices, child: Text(t.common.retry)),
      );
    }
    return Column(
      children: [
        ListTile(
          key: const ValueKey('api-recommendation.selection'),
          title: Text(
            _choices
                    .where((choice) => choice.id == selected)
                    .firstOrNull
                    ?.name ??
                selected,
          ),
          trailing: _choices.length > 1 ? const Icon(Icons.expand_more) : null,
          onTap: _choices.length > 1 ? _choose : null,
        ),
        Expanded(child: _catalog(selected, visible: !_recent)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.group == 'week')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: NativeVideoSegmentedControl(
              key: const ValueKey('api-recommendation.week-feed'),
              selected: _recent ? 'feed' : 'week',
              options: {
                'week': t.videoSource.weeklyTab,
                'feed': t.videoSource.updates,
              },
              onSelected: (value) => setState(() {
                _recent = value == 'feed';
                if (_recent) _recentVisited = true;
              }),
            ),
          ),
        ),
      Expanded(
        child: IndexedStack(
          index: _recent ? 1 : 0,
          children: [
            _recommendations(),
            if (_recentVisited)
              _catalog('recent:feed', visible: _recent)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    ],
  );
}

Future<String?> _chooseCatalogGroup(
  BuildContext context,
  List<ApiVideoCategory> values,
  String title,
  String selected,
  Uri home,
) => showVideoTaskSheet<String>(
  context: context,
  builder: (sheet) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(title: Text(title)),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in values)
              ListTile(
                leading: item.coverUrl == null
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 72,
                          height: 44,
                          child: VideoThumbnail(
                            url: item.coverUrl.toString(),
                            referrer: home,
                          ),
                        ),
                      ),
                title: Text(item.name),
                subtitle: item.description.isEmpty
                    ? null
                    : Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                selected: item.id == selected,
                onTap: () => Navigator.pop(sheet, item.id),
              ),
          ],
        ),
      ),
    ],
  ),
);

class _ApiCatalog extends StatefulWidget {
  const _ApiCatalog({
    super.key,
    this.compactBrowsing = false,
    this.siteSearchInHeader = false,
    this.headingAction,
    this.localQuery,
    this.keywordScope = KeywordSearchScope.all,
    this.remoteKeywordScope,
    this.onKeywordScopeChanged,
    this.onLocalQueryChanged,
    this.onWebsiteSearch,
    this.searchFilters = const VideoSearchFilters(),
    this.onFiltersChanged,
    this.onCategories,
    required this.repository,
    required this.mode,
    required this.query,
    required this.onOpen,
    required this.onClearQuery,
    required this.onResume,
    this.browseUrl,
    this.initialType = '',
    this.showFilters = true,
    this.separateRecommendationTabs = false,
    this.loadDetail,
    this.onDetailLoaded,
    this.active = true,
  });
  final ApiVideoRepository repository;
  final Future<ApiVideoItem> Function(ApiVideoItem)? loadDetail;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;
  final bool active;
  final bool compactBrowsing, siteSearchInHeader;
  final Widget? headingAction;
  final String? localQuery;
  final KeywordSearchScope keywordScope;
  final KeywordSearchScope? remoteKeywordScope;
  final ValueChanged<KeywordSearchScope>? onKeywordScopeChanged;
  final ValueChanged<String>? onLocalQueryChanged;
  final Future<void> Function(String query)? onWebsiteSearch;
  final VideoSearchFilters searchFilters;
  final ValueChanged<VideoSearchFilters>? onFiltersChanged;
  final ValueChanged<List<ApiVideoCategory>>? onCategories;
  final ApiVideoView mode;
  final String query;
  final Uri? browseUrl;
  final String initialType;
  final bool showFilters;
  final bool separateRecommendationTabs;
  final Future<void> Function(ApiVideoItem) onOpen;
  final VoidCallback onClearQuery;
  final Future<void> Function(ApiVideoItem, Uri) onResume;
  @override
  State<_ApiCatalog> createState() => _ApiCatalogState();
}

class _ApiCatalogState extends State<_ApiCatalog> {
  late final ReadRecoveryController _readRecovery;
  bool _hostReadActive = false;
  void _updateReadDemand() => _readRecovery.setActive(
    _hostReadActive &&
        widget.active &&
        widget.repository.browserRecoveryAllowed?.call() != false,
  );
  void _hostActiveChanged(bool active) {
    _hostReadActive = active;
    _updateReadDemand();
  }

  final _filterChanges = ValueNotifier<int>(0);
  String _inlineLocalQuery = '';
  String get _localQuery => widget.localQuery ?? _inlineLocalQuery;
  set _localQuery(String value) {
    _inlineLocalQuery = value;
    widget.onLocalQueryChanged?.call(value);
  }

  final _localDetails = <String, ApiVideoItem>{};
  int _snapshotRevision = 0;
  bool _refreshVisitedDetails = false;
  final _freshDetailReads = <String>{};

  Future<ApiVideoItem> _readCatalogDetail(ApiVideoItem item) =>
      widget.repository.enrich(
        item,
        refresh: _refreshVisitedDetails && _freshDetailReads.add(item.id),
      );

  void _observeOpenedItem(ApiVideoItem item) {
    if (!_items.any(
      (row) => row.id == item.id && row.detailUrl == item.detailUrl,
    )) {
      return;
    }
    final revision = _snapshotRevision;
    unawaited(
      _readCatalogDetail(item).then<void>((detail) {
        if (mounted && revision == _snapshotRevision) _observedDetail(detail);
      }, onError: (Object _) {}),
    );
  }

  ShelfFacetSelection _localFacets = const ShelfFacetSelection();
  bool _openingLocalFilters = false;
  // This local browsing workflow is opt-in through the existing absence of
  // remote filtering capabilities. Preserve reviewed remote-filter and weekly
  // pages; the shared index does not require another visible search field.
  bool get _usesLocalCatalog {
    final caps = widget.repository.capabilities;
    return widget.showFilters &&
        widget.onWebsiteSearch == null &&
        !caps.year &&
        !caps.sourceSort &&
        !caps.recent &&
        !caps.animePresentation;
  }

  bool get _hasWebsiteSearchQuery =>
      widget.onWebsiteSearch != null && _localQuery.trim().isNotEmpty;

  bool get _hasLocalConditions =>
      _hasWebsiteSearchQuery ||
      _usesLocalCatalog &&
          (_localQuery.trim().isNotEmpty || _localFacets.isActive);

  Future<void> _editLocalFilters() async {
    if (!_usesLocalCatalog || _openingLocalFilters || !widget.active) {
      return;
    }
    _openingLocalFilters = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      // A toolbar tap during an existing read waits for that same request.
      // It never starts a second catalog read to populate the filter options.
      await _currentLoadTask;
      if (!mounted || !widget.active) return;
      final epoch = _epoch, keyword = _localQuery;
      final scope = widget.keywordScope;
      final items = List<ApiVideoItem>.of(_catalogCandidates);
      final details = Map<String, ApiVideoItem>.of(_localDetails);
      List<ShelfFacetEntry> entriesFor(
        String query,
        KeywordSearchScope scope,
      ) =>
          filterApiCatalogItems(
                items,
                query: query,
                scope: scope,
                details: details,
              )
              .map(
                (item) => apiCatalogFacetEntry(item, detail: details[item.id]),
              )
              .toList();
      var nextKeyword = keyword, nextScope = scope;
      final result = await showShelfFilterSheet(
        context,
        entries: entriesFor(keyword, scope),
        initial: _localFacets,
        preferenceKey:
            'api-video.catalog|${widget.repository.source}|${widget.repository.home}|${widget.repository.capabilities.itemNamespace}',
        scopeLabel: t.videoLibrary.loadedResultScope,
        currentFolder: null,
        hierarchical: false,
        showAllRecordsLabel: false,
        keyword: widget.siteSearchInHeader
            ? (
                query: keyword,
                scope: scope,
                entriesFor: entriesFor,
                onApply: (query, scope) {
                  nextKeyword = query;
                  nextScope = scope;
                },
              )
            : null,
      );
      if (!mounted ||
          !widget.active ||
          epoch != _epoch ||
          keyword != _localQuery ||
          scope != widget.keywordScope ||
          result == null) {
        return;
      }
      setState(() {
        _localFacets = result;
        if (nextKeyword != keyword) _localQuery = nextKeyword;
      });
      if (nextScope != scope) widget.onKeywordScopeChanged?.call(nextScope);
    } finally {
      _openingLocalFilters = false;
    }
  }

  void _continueLocalSearch() {
    if (_loading || !widget.active) return;
    setState(() => _appendFailed = false);
    unawaited(_load(append: true));
  }

  void _observedDetail(ApiVideoItem detail) {
    if (!mounted ||
        !_items.any(
          (item) => item.id == detail.id && item.detailUrl == detail.detailUrl,
        )) {
      return;
    }
    if (!identical(_localDetails[detail.id], detail)) {
      setState(() => _localDetails[detail.id] = detail);
    }
    widget.onDetailLoaded?.call(detail);
  }

  List<ApiVideoItem> _items = [];
  List<ApiVideoCategory> _categories = [];
  late String _type = widget.initialType.isEmpty
      ? widget.searchFilters.genre
      : widget.initialType;
  late String _year = _localSearch ? '' : widget.searchFilters.date;
  late String _localYear = _localSearch ? widget.searchFilters.date : '';
  late bool _completedOnly = widget.searchFilters.completed;
  late String _sort = widget.searchFilters.sort;
  bool get _localSearch =>
      widget.query.isNotEmpty &&
      !widget.repository.capabilities.filtersOnSearch;

  bool get _titleOnly =>
      widget.query.isNotEmpty &&
      widget.onWebsiteSearch == null &&
      widget.remoteKeywordScope == KeywordSearchScope.title;

  List<ApiVideoItem> get _catalogCandidates {
    final matchesTitle = _titleOnly ? keywordTitleMatcher(widget.query) : null;
    if (matchesTitle == null && !_localSearch) return _items;
    return _items
        .where(
          (item) =>
              (matchesTitle?.call([item.title, item.alternateTitle]) ?? true) &&
              (!_localSearch ||
                  (_localYear.isEmpty || item.year == _localYear) &&
                      (!_completedOnly || item.finished)),
        )
        .toList();
  }

  VideoSearchFilters get draftFilters => VideoSearchFilters(
    query: widget.query,
    genre: _type,
    date: _localSearch ? _localYear : _year,
    sort: _sort,
    completed: _completedOnly,
  );

  List<ApiVideoCategory> get _browseCategories =>
      widget.separateRecommendationTabs
      ? _categories
            .where((value) => !_isOmoRecommendationCategory(value))
            .toList()
      : _categories;

  Future<void> editFilters() async {
    if (widget.compactBrowsing && _usesLocalCatalog) return _editLocalFilters();
    final draft = await showVideoTaskSheet<VideoSearchFilters>(
      context: context,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _filterChanges,
        builder: (_, _, _) => ApiVideoFilterPanel(
          source: widget.repository.source,
          namespace: widget.repository.capabilities.itemNamespace,
          initial: draftFilters,
          capabilities: widget.repository.capabilities,
          categories: _browseCategories,
          includeCategory: widget.query.isNotEmpty,
          categoriesLoading: _loading && _categories.isEmpty,
          categoriesFailed: _failed && _categories.isEmpty,
          onRetryCategories: () => unawaited(_load(refresh: true)),
          searching: widget.query.isNotEmpty,
        ),
      ),
    );
    if (draft == null || !mounted) return;
    if (_localSearch) {
      setState(() {
        _localYear = draft.date;
        _completedOnly = draft.completed;
      });
    } else {
      final changed =
          _type != draft.genre || _year != draft.date || _sort != draft.sort;
      setState(() {
        _type = draft.genre;
        _year = draft.date;
        _sort = draft.sort;
      });
      if (changed) _load();
    }
    widget.onFiltersChanged?.call(draft);
  }

  late Uri? _browseUrl = widget.browseUrl;
  Map<String, dynamic>? _cursor;
  int _page = 0, _pageCount = 0, _total = 0, _epoch = 0;
  int _imageRefreshToken = 0;
  bool _loading = true, _failed = false, _appendFailed = false;
  bool _recent = false;
  bool _totalKnown = true;
  String _lastFailure = 'none';

  String get _catalogFailureMessage =>
      _lastFailure.endsWith('reason=transport') ||
          _lastFailure.endsWith('reason=timeout') ||
          _lastFailure.endsWith('reason=tls') ||
          _lastFailure.endsWith('reason=dns')
      ? t.login.networkUnavailable
      : '';
  String _heading = '';
  String _introduction = '';
  Map<String, String> _badges = const {};
  @override
  void initState() {
    super.initState();
    _readRecovery = ReadRecoveryController(
      source: widget.repository.source,
      retry: () async {
        if (!widget.active ||
            widget.repository.browserRecoveryAllowed?.call() == false) {
          _updateReadDemand();
          return;
        }
        final pending = _currentLoadTask;
        if (pending != null) {
          await pending;
          return;
        }
        final append = _appendFailed;
        if (append) _appendFailed = false;
        await _load(append: append, refresh: !append);
      },
    );
    widget.repository.browserRecoveryActivity?.addListener(_updateReadDemand);
    _load();
  }

  @override
  void didUpdateWidget(covariant _ApiCatalog old) {
    super.didUpdateWidget(old);
    final repositoryChanged = old.repository != widget.repository;
    if (repositoryChanged) {
      old.repository.browserRecoveryActivity?.removeListener(_updateReadDemand);
      widget.repository.browserRecoveryActivity?.addListener(_updateReadDemand);
      _readRecovery.reset();
    }
    _updateReadDemand();
    if (repositoryChanged ||
        old.query != widget.query ||
        old.browseUrl != widget.browseUrl ||
        old.initialType != widget.initialType ||
        old.searchFilters != widget.searchFilters) {
      final filters = widget.searchFilters;
      final nextType = _localSearch
          ? ''
          : (widget.initialType.isEmpty ? filters.genre : widget.initialType);
      final nextYear = _localSearch ? '' : filters.date;
      final remoteChanged =
          repositoryChanged ||
          old.query != widget.query ||
          old.browseUrl != widget.browseUrl ||
          old.initialType != widget.initialType ||
          _type != nextType ||
          _year != nextYear ||
          _sort != filters.sort;
      _browseUrl = widget.browseUrl;
      _type = nextType;
      _year = nextYear;
      _localYear = _localSearch ? filters.date : '';
      _completedOnly = filters.completed;
      _sort = filters.sort;
      if (remoteChanged) _load();
    }
  }

  @override
  void dispose() {
    _epoch++;
    _readRecovery.dispose();
    widget.repository.browserRecoveryActivity?.removeListener(
      _updateReadDemand,
    );
    _filterChanges.dispose();
    super.dispose();
  }

  Future<PullRefreshResult>? _refreshLoadTask, _pullTask, _currentLoadTask;
  Object? _refreshLoadScope, _catalogSnapshotScope;
  int _firstPageLength = 0;
  Map<String, dynamic>? _firstPageCursor;
  int? _pullEpoch;
  bool get _pullRefreshing => _pullTask != null && _pullEpoch == _epoch;

  Object get _catalogScope => (
    widget.repository,
    widget.query,
    _type,
    _year,
    _recent,
    _sort,
    _browseUrl,
  );

  Future<PullRefreshResult> _load({bool append = false, bool refresh = false}) {
    if (!append && !refresh) _readRecovery.reset();
    final scope = _catalogScope;
    if (refresh &&
        !append &&
        _refreshLoadScope == scope &&
        _refreshLoadTask != null &&
        identical(_refreshLoadTask, _currentLoadTask)) {
      return _refreshLoadTask!;
    }
    final task = _loadNow(append: append, refresh: refresh);
    _currentLoadTask = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_currentLoadTask, task)) _currentLoadTask = null;
      }),
    );
    if (!refresh || append) return task;
    _refreshLoadTask = task;
    _refreshLoadScope = scope;
    return task.whenComplete(() {
      if (identical(_refreshLoadTask, task)) {
        _refreshLoadTask = null;
      }
    });
  }

  Future<PullRefreshResult> _refreshFromPull() {
    final pending = _pullTask;
    if (pending != null && _pullEpoch == _epoch) {
      return pending;
    }
    final task = _load(refresh: true);
    setState(() {
      _pullTask = task;
      _pullEpoch = _epoch;
    });
    return task.whenComplete(() {
      if (mounted && identical(_pullTask, task)) {
        setState(() => _pullTask = null);
      }
    });
  }

  Future<PullRefreshResult> _loadNow({
    bool append = false,
    bool refresh = false,
  }) async {
    if (append &&
        (!widget.active || _loading || _appendFailed || _page >= _pageCount)) {
      return PullRefreshResult.ignored;
    }
    final epoch = append ? _epoch : ++_epoch, next = append ? _page + 1 : 1;
    final scope = _catalogScope;
    final hadAppendFailure = _appendFailed;
    setState(() {
      _loading = true;
      if (!refresh || _items.isEmpty) _failed = false;
      _appendFailed = false;
      if (!append && !refresh) {
        _items = [];
        _localDetails.clear();
        _catalogSnapshotScope = null;
      }
    });
    _filterChanges.value++;
    try {
      final result = await widget.repository.page(
        query: widget.query,
        typeId: _type,
        year: _year,
        page: next,
        cursor: append ? _cursor : null,
        refresh: refresh,
        recentHours: _recent ? 24 : 0,
        browseUrl: _browseUrl,
        sort: _sort,
      );
      if (!mounted || epoch != _epoch) return PullRefreshResult.ignored;
      if (result.page != next) throw const FormatException('Wrong result page');
      var badges = <String, String>{};
      if (_type == 'recent:feed') {
        final local = await VideoLibraryStore.shared.read();
        if (!mounted || epoch != _epoch) return PullRefreshResult.ignored;
        badges = {
          for (final item in result.items)
            if (local.contains(widget.repository.source, item.id))
              item.id: t.videoSource.localSaved,
        };
      }
      final feedback = refresh
          ? _compareRefresh(result, badges)
          : PullRefreshResult.updated;
      final keepTail =
          _page > 1 &&
          feedback == PullRefreshResult.checked &&
          const DeepCollectionEquality().equals(
            _firstPageCursor,
            result.nextCursor,
          );
      setState(() {
        if (keepTail) {
          _loading = false;
          _failed = false;
          _appendFailed = hadAppendFailure;
          _imageRefreshToken++;
          return;
        }
        if (!append) {
          // Publish a new live first-page snapshot only after success. Old
          // detail callbacks/cache must not override changed tags or years.
          _localDetails.clear();
          _catalogSnapshotScope = scope;
          _firstPageLength = result.items.length;
          _firstPageCursor = result.nextCursor;
          _snapshotRevision++;
          if (refresh) _imageRefreshToken++;
          _refreshVisitedDetails = refresh;
          _freshDetailReads.clear();
        }
        _items = {
          if (append)
            for (final item in _items) item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        _categories = result.categories;
        _page = result.page;
        _pageCount = result.pageCount;
        _total = result.total;
        _totalKnown = result.totalKnown;
        _heading = result.heading;
        _introduction = result.description;
        _badges = badges;
        _cursor = result.nextCursor;
        _loading = false;
        _failed = false;
      });
      _lastFailure = 'none';
      _readRecovery.succeeded();
      _filterChanges.value++;
      widget.onCategories?.call(result.categories);
      return feedback;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _lastFailure = _catalogFailureSummary(error);
        debugPrint('[api-catalog-failure] $_lastFailure');
        _readRecovery.failed(
          error is ApiVideoStageFailure ? error.cause : error,
        );
        _updateReadDemand();
        setState(() {
          _loading = false;
          if (append) {
            _appendFailed = true;
          } else {
            _failed = true;
          }
        });
        _filterChanges.value++;
      }
      // The empty or retained list already includes a scoped retry action.
      return PullRefreshResult.ignored;
    }
  }

  PullRefreshResult _compareRefresh(
    ApiVideoResult incoming,
    Map<String, String> badges,
  ) {
    if (_catalogSnapshotScope != _catalogScope ||
        _pageCount != incoming.pageCount ||
        _totalKnown != incoming.totalKnown ||
        incoming.totalKnown && _total != incoming.total ||
        _heading != incoming.heading ||
        _introduction != incoming.description ||
        !mapEquals(_badges, badges) ||
        _categories.length != incoming.categories.length ||
        _firstPageLength != incoming.items.length) {
      return PullRefreshResult.updated;
    }
    for (var index = 0; index < _categories.length; index++) {
      final before = _categories[index], after = incoming.categories[index];
      if ((
            before.id,
            before.parentId,
            before.name,
            before.selectable,
            before.coverUrl,
            before.description,
          ) !=
          (
            after.id,
            after.parentId,
            after.name,
            after.selectable,
            after.coverUrl,
            after.description,
          )) {
        return PullRefreshResult.updated;
      }
    }
    for (var index = 0; index < _firstPageLength; index++) {
      if (!_items[index].hasSameCatalogSummary(incoming.items[index])) {
        return PullRefreshResult.updated;
      }
    }
    return incoming.pageCount > 1 ||
            incoming.totalKnown && incoming.total > incoming.items.length
        ? PullRefreshResult.checked
        : PullRefreshResult.unchanged;
  }

  void _typeSelected(String id) {
    if (id == _type) return;
    setState(() {
      _type = id;
      _browseUrl = null;
      if (!id.startsWith('type:') && !id.startsWith('genre:')) _sort = '';
      if (!widget.repository.capabilities.supportsYearType(id)) _year = '';
    });
    widget.onFiltersChanged?.call(draftFilters);
    _load();
  }

  Future<void> _allCategories() async {
    final result = await showVideoTaskSheet<String>(
      context: context,
      builder: (_) =>
          _CategoryPicker(categories: _browseCategories, selected: _type),
    );
    if (result != null && mounted) _typeSelected(result);
  }

  Future<void> _group(String id, String title) async {
    final values = _categories.where((c) => c.parentId == id).toList();
    if (values.isEmpty) return;
    final selected = await _chooseCatalogGroup(
      context,
      values,
      title,
      _type,
      widget.repository.home,
    );
    if (mounted && selected != null) _typeSelected(selected);
  }

  @override
  Widget build(BuildContext context) => ReadRecoveryHost(
    onActiveChanged: _hostActiveChanged,
    child: _buildCatalog(context),
  );

  Widget _buildCatalog(BuildContext context) {
    final selected = _categories.where((c) => c.id == _type).firstOrNull;
    final major = _browseCategories
        .where((c) => c.parentId == '0')
        .take(6)
        .toList();
    final parent = selected == null
        ? ''
        : selected.parentId == '0'
        ? selected.id
        : selected.parentId;
    final children = parent.isEmpty
        ? <ApiVideoCategory>[]
        : _categories.where((c) => c.parentId == parent).toList();
    Widget category(String id, String name) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(name),
        selected: id == _type || id.isNotEmpty && id == parent,
        chipAnimationStyle: VideoMotion.chip(context),
        onSelected: (_) => _typeSelected(id),
      ),
    );
    final titleOnly = _titleOnly;
    final candidates = _catalogCandidates;
    final visibleItems = _usesLocalCatalog || _hasWebsiteSearchQuery
        ? filterApiCatalogItems(
            candidates,
            query: _localQuery,
            scope: widget.keywordScope,
            facets: _localFacets,
            details: _localDetails,
          )
        : candidates;
    final detailRevision = _snapshotRevision;
    final hasMore = _page < _pageCount;
    final localScope = _totalKnown
        ? t.videoLibrary.localCatalogScope(
            loaded: _items.length,
            total: _total,
            shown: visibleItems.length,
          )
        : t.videoLibrary.localCatalogUnknownTotal(
            loaded: _items.length,
            shown: visibleItems.length,
          );
    final localScopeLabel = Text(
      localScope,
      key: const ValueKey('api-catalog.local-scope'),
      style: Theme.of(context).textTheme.bodySmall,
    );
    final searching = widget.query.isNotEmpty;
    final useLoadedSearchCount =
        titleOnly ||
        _localSearch && (_localYear.isNotEmpty || _completedOnly) ||
        _usesLocalCatalog && _hasLocalConditions;
    final showLocalScope = !_failed || _items.isNotEmpty;
    final showQueryChip = searching && !widget.siteSearchInHeader;
    void resetCatalogFilters() {
      setState(() {
        _type = '';
        _year = '';
        _sort = '';
        _recent = false;
        _localYear = '';
        _completedOnly = false;
      });
      widget.onFiltersChanged?.call(draftFilters);
      _load();
    }

    final catalogHeader = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showFilters &&
            !widget.separateRecommendationTabs &&
            widget.repository.capabilities.animePresentation &&
            widget.query.isEmpty &&
            _browseUrl == null &&
            (_categories.isNotEmpty || _loading))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _categories.any((c) => c.parentId == 'rank')
                        ? () => _group('rank', t.videoSource.ranking)
                        : null,
                    icon: const Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                    ),
                    label: Text(t.videoSource.ranking),
                  ),
                  TextButton.icon(
                    onPressed: _categories.any((c) => c.parentId == 'topics')
                        ? () => _group('topics', t.videoSource.topics)
                        : null,
                    icon: const Icon(
                      Icons.collections_bookmark_outlined,
                      size: 18,
                    ),
                    label: Text(t.videoSource.topics),
                  ),
                ],
              ),
            ),
          ),
        if (widget.query.isEmpty &&
            _browseUrl == null &&
            _type.isEmpty &&
            _year.isEmpty &&
            !_recent &&
            !widget.compactBrowsing)
          ApiVideoContinueEntry(
            source: widget.repository.source,
            home: widget.repository.home,
            itemNamespace: widget.repository.capabilities.itemNamespace,
            posterAspectRatio: widget.repository.capabilities.posterAspectRatio,
            onOpen: widget.onResume,
          ),
        if (widget.showFilters &&
            _browseUrl == null &&
            (_categories.isNotEmpty || _loading) &&
            (widget.query.isEmpty ||
                widget.repository.capabilities.filtersOnSearch))
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                category('', t.videoLibrary.all),
                if (widget.repository.capabilities.recent)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.videoLibrary.recent24Hours),
                      selected: _recent,
                      onSelected: (value) {
                        setState(() => _recent = value);
                        _load();
                      },
                      chipAnimationStyle: VideoMotion.chip(context),
                    ),
                  ),
                for (final type in major) category(type.id, type.name),
                if (_categories.isEmpty && _loading)
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 58,
                        height: 44,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ActionChip(
                  label: Text(t.videoLibrary.moreCategories),
                  onPressed: _categories.isEmpty ? null : _allCategories,
                ),
              ],
            ),
          ),
        if (widget.showFilters &&
            _browseUrl == null &&
            children.isNotEmpty &&
            (widget.query.isEmpty ||
                widget.repository.capabilities.filtersOnSearch))
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                for (final type in children) category(type.id, type.name),
              ],
            ),
          ),
        if (!(widget.repository.capabilities.animePresentation &&
            widget.query.isEmpty &&
            _type.isEmpty &&
            _year.isEmpty &&
            _browseUrl == null))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _items.isEmpty && _failed
                        ? ''
                        : _loading && _items.isEmpty
                        ? t.common.loading
                        : !searching
                        ? (_heading.isEmpty
                              ? t.videoLibrary.updatedFirst
                              : _heading)
                        : useLoadedSearchCount
                        ? t.videoLibrary.filteredLoaded(
                            shown: visibleItems.length,
                            loaded: _items.length,
                          )
                        : _totalKnown
                        ? t.videoLibrary.results(count: _total)
                        : t.videoLibrary.loadedResults(count: _items.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (widget.showFilters &&
                    (_type.isNotEmpty ||
                        _year.isNotEmpty ||
                        _sort.isNotEmpty ||
                        _recent ||
                        _localYear.isNotEmpty ||
                        _completedOnly))
                  if (widget.headingAction == null)
                    TextButton(
                      onPressed: resetCatalogFilters,
                      child: Text(t.videoLibrary.clearFilters),
                    )
                  else
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        tooltip: t.videoLibrary.clearFilters,
                        onPressed: resetCatalogFilters,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    ),
                ?widget.headingAction,
              ],
            ),
          ),
        if (widget.compactBrowsing &&
            _usesLocalCatalog &&
            !searching &&
            showLocalScope)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: localScopeLabel,
          ),
        if (widget.compactBrowsing && _usesLocalCatalog && _hasLocalConditions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('api-catalog.local-reset'),
                onPressed: () => setState(() {
                  _localQuery = '';
                  _localFacets = const ShelfFacetSelection();
                }),
                icon: const Icon(Icons.clear, size: 18),
                label: Text(t.videoLibrary.clearFilters),
              ),
            ),
          ),
        if (_hasWebsiteSearchQuery)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLocalScope)
                  Text(
                    localScope,
                    key: const ValueKey('api-catalog.local-scope'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                TextButton(
                  key: const ValueKey('api-catalog.website-search'),
                  onPressed: () =>
                      unawaited(widget.onWebsiteSearch!(_localQuery)),
                  child: Text(t.videoLibrary.officialSearch),
                ),
              ],
            ),
          ),
        if (_introduction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => showVideoTaskSheet<void>(
                context: context,
                builder: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(_introduction),
                ),
              ),
              child: Text(
                _introduction,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        if (widget.query.isNotEmpty &&
            widget.repository.capabilities.searchNotice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              widget.repository.capabilities.searchNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (showQueryChip ||
            _year.isNotEmpty ||
            _sort.isNotEmpty ||
            _localYear.isNotEmpty ||
            _completedOnly)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showQueryChip)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(widget.query),
                      onDeleted: widget.onClearQuery,
                    ),
                  ),
                if (_localYear.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(_localYear),
                      onDeleted: () {
                        setState(() => _localYear = '');
                        widget.onFiltersChanged?.call(draftFilters);
                      },
                    ),
                  ),
                if (_completedOnly)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(t.videoLibrary.completedOnly),
                      onDeleted: () {
                        setState(() => _completedOnly = false);
                        widget.onFiltersChanged?.call(draftFilters);
                      },
                    ),
                  ),
                if (_year.isNotEmpty)
                  InputChip(
                    label: Text(_year),
                    onDeleted: () {
                      setState(() => _year = '');
                      widget.onFiltersChanged?.call(draftFilters);
                      _load();
                    },
                  ),
                if (_sort.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InputChip(
                      label: Text(
                        _sort == 'hits'
                            ? t.videoSource.sourcePopularity
                            : t.videoSource.sourceScore,
                      ),
                      onDeleted: () {
                        setState(() => _sort = '');
                        widget.onFiltersChanged?.call(draftFilters);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 2,
          child: _loading && !_pullRefreshing
              ? MediaQuery.disableAnimationsOf(context)
                    ? const LinearProgressIndicator(value: .5)
                    : const LinearProgressIndicator()
              : null,
        ),
      ],
    );
    return Column(
      children: [
        if (_usesLocalCatalog && !widget.compactBrowsing)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchToolbarScope(
                  extent: widget.siteSearchInHeader
                      ? null
                      : SearchToolbarScope.breezeExtent(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.siteSearchInHeader
                            ? searching || !showLocalScope
                                  ? const SizedBox.shrink()
                                  : localScopeLabel
                            : SearchQueryField(
                                key: const ValueKey('api-catalog.local-query'),
                                query: _localQuery,
                                inline: true,
                                autoExpand: false,
                                closeOnSubmit: false,
                                hintText: t.videoLibrary.localCatalogSearchHint,
                                semanticLabel:
                                    t.videoLibrary.localCatalogSearchHint,
                                onChanged: (value) =>
                                    setState(() => _localQuery = value),
                              ),
                      ),
                      if (!widget.siteSearchInHeader &&
                          widget.onKeywordScopeChanged != null)
                        KeywordScopeMenu(
                          compact: MediaQuery.sizeOf(context).width < 352,
                          scope: widget.keywordScope,
                          onChanged: widget.onKeywordScopeChanged!,
                        ),
                      SourceFilterIconButton(
                        key: const ValueKey('api-catalog.local-filters'),
                        bare: false,
                        tooltip: _localFacets.isActive
                            ? t.videoFilters.active
                            : t.videoLibrary.localCatalogFilters,
                        active: _localFacets.isActive,
                        onPressed: _loading ? null : _editLocalFilters,
                      ),
                      if (_hasLocalConditions)
                        SourceChromeIconButton(
                          key: const ValueKey('api-catalog.local-reset'),
                          tooltip: t.common.clear,
                          icon: Icons.clear,
                          symbol: 'xmark',
                          onPressed: () => setState(() {
                            _localQuery = '';
                            _localFacets = const ShelfFacetSelection();
                          }),
                        ),
                    ],
                  ),
                ),
                if (!widget.siteSearchInHeader && !searching && showLocalScope)
                  localScopeLabel,
              ],
            ),
          ),
        if (_failed && _items.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('api-catalog.refresh-retry'),
              onPressed: _loading ? null : () => _load(refresh: true),
              icon: const Icon(Icons.refresh),
              label: Text('${t.common.loadingFailed} · ${t.common.retry}'),
            ),
          ),
        Expanded(
          child: PullRefreshFeedback.indicator(
            active: widget.active,
            scope: _catalogScope,
            onRefresh: _refreshFromPull,
            child: ApiVideoCollection(
              detailGeneration: _snapshotRevision,
              imageRefreshToken: _imageRefreshToken,
              loadDetail: _readCatalogDetail,
              onDetailLoaded: (detail) {
                if (detailRevision == _snapshotRevision) {
                  _observedDetail(detail);
                }
              },
              detailsActive: widget.active,
              key: ValueKey(
                'library.${widget.query}.$_type.$_year.$_recent.$_hasLocalConditions',
              ),
              header: catalogHeader,
              loading: _loading && !_pullRefreshing,
              emptyState: _failed
                  ? ApiVideoEmpty(
                      title: t.common.loadingFailed,
                      message: _catalogFailureMessage,
                      action: TextButton(
                        onPressed: () => _load(refresh: true),
                        child: Text(t.common.retry),
                      ),
                    )
                  : ApiVideoEmpty(
                      title: _hasLocalConditions
                          ? t.videoLibrary.localCatalogNoMatches
                          : titleOnly ||
                                _localSearch &&
                                    (_localYear.isNotEmpty || _completedOnly)
                          ? t.videoLibrary.noLoadedMatches
                          : t.videoLibrary.noResults,
                      message:
                          (_hasLocalConditions ||
                              titleOnly ||
                              _localSearch &&
                                  (_localYear.isNotEmpty || _completedOnly))
                          ? t.videoLibrary.loadedResultScope
                          : t.videoLibrary.noResultsHint,
                      action:
                          (_hasLocalConditions || _localSearch || titleOnly) &&
                              hasMore
                          ? TextButton(
                              key: const ValueKey(
                                'api-catalog.local-load-next',
                              ),
                              onPressed: _loading ? null : _continueLocalSearch,
                              child: Text(t.videoLibrary.continueCatalogSearch),
                            )
                          : null,
                    ),
              compactAnime: widget.repository.capabilities.animePresentation,
              posterAspectRatio:
                  widget.repository.capabilities.posterAspectRatio,
              items: visibleItems,
              badges: _badges,
              mode: widget.mode,
              storageKey:
                  '${widget.repository.source}|${widget.repository.home}|'
                  '${widget.repository.capabilities.itemNamespace}|library|'
                  '${widget.query}|$_type|$_year|$_recent|$_hasLocalConditions',
              onOpen: (item) => unawaited(widget.onOpen(item)),
              onNearEnd: visibleItems.isEmpty || _hasLocalConditions
                  ? null
                  : () => _load(append: true),
              footer: _appendFailed
                  ? TextButton.icon(
                      onPressed: () {
                        setState(() => _appendFailed = false);
                        _load(append: true);
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(t.videoLibrary.appendFailed),
                    )
                  : _loading && _items.isNotEmpty && !_pullRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : hasMore && _hasLocalConditions && visibleItems.isNotEmpty
                  ? TextButton(
                      key: const ValueKey('api-catalog.local-load-next'),
                      onPressed: _continueLocalSearch,
                      child: Text(t.videoLibrary.continueCatalogSearch),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({required this.categories, required this.selected});
  final List<ApiVideoCategory> categories;
  final String selected;
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _query = '';
  late String _group =
      widget.categories
          .where((c) => c.id == widget.selected)
          .map((c) => c.parentId == '0' ? c.id : c.parentId)
          .firstOrNull ??
      widget.categories.where((c) => c.parentId == '0').firstOrNull?.id ??
      '';
  @override
  Widget build(BuildContext context) {
    final parents = widget.categories.where((c) => c.parentId == '0').toList();
    final group = widget.categories.where((c) => c.id == _group).firstOrNull;
    final values = _query.isEmpty
        ? widget.categories.where((c) => c.parentId == _group)
        : widget.categories.where(
            (c) =>
                c.selectable &&
                c.name.toLowerCase().contains(_query.toLowerCase()),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.videoLibrary.moreCategories,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SearchFieldSurface(
            child: TextField(
              decoration: searchFieldDecoration(
                context,
                hintText: t.videoLibrary.searchCategoriesHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 12),
          if (_query.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in parents)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.name),
                        selected: p.id == _group,
                        onSelected: (_) => setState(() => _group = p.id),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_query.isEmpty && group != null && group.selectable)
                    ChoiceChip(
                      label: Text('${t.videoLibrary.all} ${group.name}'),
                      selected: widget.selected == group.id,
                      onSelected: (_) => Navigator.pop(context, group.id),
                    ),
                  for (final value in values)
                    ChoiceChip(
                      label: Text(
                        _query.isNotEmpty && value.parentId != '0'
                            ? '${value.name} · ${widget.categories.where((c) => c.id == value.parentId).firstOrNull?.name ?? ''}'
                            : value.name,
                      ),
                      selected: value.id == widget.selected,
                      onSelected: (_) => Navigator.pop(context, value.id),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(t.videoLibrary.allTypes),
          ),
        ],
      ),
    );
  }
}
