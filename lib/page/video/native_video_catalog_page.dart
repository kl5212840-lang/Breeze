import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/video/video_personal_page_window.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/page/video/video_personal_preferences.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';
import 'package:zephyr/page/video/video_personal_recent.dart';
import 'package:zephyr/page/video/video_page_analysis.dart';
import 'package:zephyr/page/video/api_video_playback_diagnostics.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';

import 'package:zephyr/page/video/video_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_website.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_verification_gate.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_catalog_dom.dart';
import 'package:zephyr/page/video/video_catalog_cache.dart';
import 'package:zephyr/page/video/video_content_transition.dart';
import 'package:zephyr/page/video/video_back_gesture.dart';
import 'package:zephyr/page/video/video_site_presentation.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_library_view.dart';
import 'package:zephyr/page/video/video_profile_header.dart';
import 'package:zephyr/page/video/video_creator_shelf.dart';
import 'package:zephyr/page/video/video_creator_reference.dart';
import 'package:zephyr/page/video/video_site_creator_directory.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_personal_shell.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/page/video/native_video_account_form.dart';
import 'package:zephyr/page/video/video_site_account.dart';
import 'package:zephyr/page/video/video_site_forms.dart';
import 'package:zephyr/page/video/video_site_verified_identity.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_playlist_editor.dart';
import 'package:zephyr/page/video/video_comment_drafts.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_filter_panel.dart';
import 'package:zephyr/page/video/video_filter_schema_reader.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef NativeVideoPluginCall =
    Future<Map<String, dynamic>> Function(
      String fnPath,
      Map<String, dynamic> core,
    );

typedef _VideoCreator = ({
  String name,
  Uri url,
  VideoCreatorReference reference,
});

typedef _VideoLocation = ({
  Uri uri,
  _VideoCreator? creator,
  String tab,
  bool website,
  bool personal,
  bool fallback,
  NativePlaybackReturnState? playback,
});

class NativeCatalogCategory {
  const NativeCatalogCategory({required this.title, required this.url});

  final String title;
  final Uri url;
}

class NativeCatalogTab {
  const NativeCatalogTab({
    required this.id,
    required this.title,
    required this.url,
    required this.mode,
  });

  final String id;
  final String title;
  final Uri url;
  final String mode;
}

/// A native video list backed by the site's own loaded page. The platform
/// WebView handles cookies/challenges; the plugin validates and normalizes the
/// DOM snapshot. If extraction fails, the actual website remains usable.
class NativeVideoCatalogPage extends StatefulWidget {
  const NativeVideoCatalogPage({
    super.key,
    required this.source,
    required this.title,
    required this.homeUrl,
    required this.catalogFnPath,
    required this.detailFnPath,
    required this.playbackFnPath,
    required this.selectors,
    required this.categories,
    required this.tabs,
    this.pluginCall,
    this.nativeAccount = false,
    this.nativeSubscriptions = false,
    this.nativeAuth = false,
    this.nativeSiteActions = false,
    this.externalAuthenticationEntries = const [],
    this.searchFilters,
    this.initialUrl,
    this.accountLoginUsername,
    this.initialKeywordScope,
    this.initialCreator,
    this.accountSyncCoordinator,
    this.accountCookies,
    this.readLocalDownloads,
    this.returnToCallerAfterPlayback = false,
  });

  final Uri? initialUrl;
  final String? accountLoginUsername;
  final KeywordSearchScope? initialKeywordScope;
  final VideoCreatorReference? initialCreator;
  final PluginAccountSyncCoordinator? accountSyncCoordinator;
  final VideoAccountCookies? accountCookies;
  final Future<List<Map<String, dynamic>>> Function()? readLocalDownloads;
  final bool returnToCallerAfterPlayback;

  final String source;
  final String title;
  final Uri homeUrl;
  final String catalogFnPath;
  final String detailFnPath;
  final String playbackFnPath;
  final Map<String, String> selectors;
  final List<NativeCatalogCategory> categories;
  final List<NativeCatalogTab> tabs;
  final NativeVideoPluginCall? pluginCall;
  final bool nativeAccount, nativeSubscriptions;
  final bool nativeAuth, nativeSiteActions;

  /// Explicit source opt-in to observed, first-party authentication entries.
  /// Opening the system browser does not authenticate this WebKit session.
  final List<Uri> externalAuthenticationEntries;
  final VideoFilterSchema? searchFilters;

  @override
  State<NativeVideoCatalogPage> createState() => _NativeVideoCatalogPageState();
}

class _NativeVideoCatalogPageState extends State<NativeVideoCatalogPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _web;
  Object? _downloadRetryResolver;
  Object? _accountSyncRegistration;
  int _accountSyncEpoch = 0;
  bool _applyingAccountRestore = false;
  void _registerDownloadRetry() {
    if (!widget.nativeSiteActions || _web == null) return;
    final previous = _downloadRetryResolver;
    if (previous != null)
      VideoDownloadRetry.unregister(widget.source, previous);
    final web = _web;
    _downloadRetryResolver = VideoDownloadRetry.register(
      widget.source,
      (row) async {
        final page = Uri.parse(row['url'] as String);
        if (page.origin != widget.homeUrl.origin || page.path != '/watch')
          throw const VideoDownloadRetryFailure('missingIdentity');
        if (!mounted || !identical(web, _web))
          throw const VideoDownloadRetryFailure('sourceVisitRequired');
        if (_verificationVisible || _applyingAccountRestore)
          throw const VideoDownloadRetryFailure('verificationRequired');
        final operations = VideoSiteOperations(
          page: page,
          evaluate: (script) => _evaluate(script),
        );
        try {
          final result = await operations.readDownloadChoices();
          if (result.value == null)
            throw VideoDownloadRetryFailure(switch (result.status.name) {
              'login' => 'loginRequired',
              'verification' => 'verificationRequired',
              'changed' => 'accountChanged',
              'unsupported' => 'unsupported',
              _ => 'network',
            });
          await _networkContext?.prepare();
          return VideoDownloadRetryResolution(
            choices: result.value!,
            networkContext: _networkContext?.token,
          );
        } finally {
          operations.dispose();
        }
      },
      current: () => mounted && identical(web, _web),
      accepts: (row) {
        final page = Uri.tryParse('${row['url']}');
        return page?.origin == widget.homeUrl.origin && page?.path == '/watch';
      },
    );
  }

  PluginAccountSyncCoordinator get _accountSync =>
      widget.accountSyncCoordinator ?? PluginAccountSyncCoordinator.instance;

  void _unregisterAccountSync() {
    _accountSyncEpoch++;
    final registration = _accountSyncRegistration;
    _accountSyncRegistration = null;
    if (registration != null)
      _accountSync.unregister(widget.source, registration);
  }

  Future<bool> _authenticatedAccountSession() async {
    if (!mounted ||
        _web == null ||
        !_currentAccountDocument ||
        _applyingAccountRestore ||
        _verificationWindowActive ||
        _verificationVisible)
      return false;
    final epoch = _loadEpoch;
    try {
      final state = await _readSiteState();
      if (!mounted ||
          epoch != _loadEpoch ||
          state.challenge ||
          state.accessBlocked ||
          !videoSiteDocumentMatches(_requestedUrl, state.url) ||
          !(state.nativeReady || state.websiteReady))
        return false;
      final header = await _evaluate(videoSiteProfileLinkScript);
      return mounted &&
          epoch == _loadEpoch &&
          _currentAccountDocument &&
          _personalRoot(Uri.tryParse(header?.toString() ?? '')) != null;
    } catch (_) {
      return false;
    }
  }

  Future<PluginAccountAuthentication?> _freshAccountIdentity() async {
    final web = _web, epoch = _loadEpoch;
    final generation = _accountGeneration;
    if (!mounted ||
        web == null ||
        _verificationVisible ||
        _verificationWindowActive)
      return null;
    try {
      final raw = await videoBrowserReadAsync(
        web,
        videoSiteFreshAccountScript(widget.homeUrl),
      ).timeout(const Duration(seconds: 15));
      final value = asJsonMap(raw is String ? jsonDecode(raw) : raw);
      if (!mounted ||
          epoch != _loadEpoch ||
          generation != _accountGeneration ||
          !identical(web, _web))
        return null;
      final id = value['id']?.toString() ?? '';
      final own = _ownIdentityRoot == widget.homeUrl.resolve('/user/$id')
          ? _ownIdentity
          : const <String, dynamic>{};
      return videoSiteVerifiedIdentity(value, widget.homeUrl, ownProfile: own);
    } on PluginAccountAuthenticationRejected {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> _configureAccountSync(Map<String, dynamic> config) async {
    final web = _web;
    if (web == null || !VideoAccountService.supported(config, widget.homeUrl))
      return;
    final cookies = widget.accountCookies ?? videoSiteAccountCookies(web);
    if (cookies == null)
      return; // Never substitute the default iOS cookie store.
    final epoch = ++_accountSyncEpoch;
    final registration = await _accountSync.register(
      source: widget.source,
      origin: Uri.parse(widget.homeUrl.origin),
      accountSync: config,
      call: _callPlugin,
      cookies: cookies,
      authenticated: _authenticatedAccountSession,
      identity: _freshAccountIdentity,
      continueLogin: () async {
        if (!mounted || !identical(web, _web))
          throw const PluginAccountNeedsLogin();
        _loginReturnUrl = _requestedUrl;
        await _load(widget.homeUrl.resolve('/login'));
      },
    );
    if (!mounted || epoch != _accountSyncEpoch) {
      _accountSync.unregister(widget.source, registration);
      return;
    }
    final previous = _accountSyncRegistration;
    _accountSyncRegistration = registration;
    if (previous != null) _accountSync.unregister(widget.source, previous);
    _applyingAccountRestore = true;
    try {
      // A normal entry is a no-op. Only global restore's pending marker may
      // apply cookies; successful readback never changes the page's login UI.
      await _accountSync.restoreOnEntry(widget.source);
    } finally {
      if (mounted && epoch == _accountSyncEpoch)
        _applyingAccountRestore = false;
    }
  }

  Future<void> _captureAccountSession() async {
    if (!mounted || _accountSyncRegistration == null || _applyingAccountRestore)
      return;
    try {
      await _accountSync.captureAuthenticated(
        widget.source,
        explicitSave: _loginReturnUrl != null && _requestedUrl.path != '/login',
      );
    } catch (_) {
      /* Backup failure is not a website login failure. */
    }
  }

  late final Future<SourceNetworkLease?> _networkLease;
  late final Future<OmoNetworkContext?> _network;
  OmoNetworkContext? _networkContext;
  Timer? _loadWatchdog;
  Timer? _loadDeadline;
  int? _deadlineEpoch;
  Timer? _siteMonitor;
  bool _foreground = true;
  bool _inspecting = false;
  bool _detailVisible = false;
  bool _verificationReloading = false;
  bool _verificationWindowActive = false;
  bool _inspectionEnabled = false;
  bool _inspectionChanging = false;
  bool _diagnosticToolsEnabled = false;
  int _diagnosticPreferenceEpoch = 0;
  bool _externalAuthenticationBusy = false;
  final _siteVerificationRequired = ValueNotifier<bool>(false);
  final _browserDiagnostics = VideoBrowserDiagnostics();
  Uri? _lastDocumentUrl;
  Uri? _challengeResponseUrl;
  Uri? _accessDeniedResponseUrl;
  Uri? _blockedDocumentUrl;
  bool _websiteRefreshInFlight = false;
  Object? _documentReadFailure;
  Completer<void>? _automaticRead;
  late final _readRecovery = ReadRecoveryController(
    source: widget.source,
    retry: _retryCatalogRead,
  );

  bool get _automaticCatalogAllowed =>
      !_websiteVisible &&
      !_catalogWebsite &&
      !_personalVisible &&
      !_detailVisible &&
      !_verificationVisible &&
      !_verificationWindowActive &&
      !_authSubmissionStarted &&
      !_accountSubmissionStarted &&
      !_recoverySubmissionStarted &&
      !_isAccountEdit(_requestedUrl) &&
      !const {
        '/login',
        '/register',
        '/password/reset',
        '/password/email',
        '/watch',
      }.contains(_requestedUrl.path);

  void _completeAutomaticRead() {
    final pending = _automaticRead;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> _retryCatalogRead() async {
    if (!mounted ||
        !_automaticCatalogAllowed ||
        _busy ||
        _refreshingCatalog ||
        _documentLoading ||
        _refreshCompleter != null)
      return;
    final pending = _automaticRead = Completer<void>();
    try {
      await _load(
        _requestedUrl,
        rememberHistory: false,
        creator: _creatorContext,
        automaticRecovery: true,
      );
      await pending.future.timeout(
        Duration(seconds: _sourceOptions.parseTimeoutSeconds + 10),
      );
    } finally {
      if (identical(_automaticRead, pending)) _automaticRead = null;
    }
  }

  void _clearDocumentFailureEvidence() {
    _documentReadFailure = null;
    _challengeResponseUrl = null;
    _accessDeniedResponseUrl = null;
    _blockedDocumentUrl = null;
  }

  int _loadEpoch = 0;
  int? _parsingEpoch;
  bool _busy = true;
  bool _refreshingCatalog = false;
  bool _catalogRefreshFailed = false;
  bool _documentLoading = false;
  bool _browserNeedsRecovery = false;
  bool _awaitingCommit = false;
  bool _websiteVisible = false;
  // Explicit renderer intent lasts for this open source session. Required
  // website surfaces (verification/unsupported pages) do not change it.
  bool? _displayModeChoice;
  bool get _catalogWebsite => _displayModeChoice ?? _sourceOptions.website;
  // Required fallbacks remain document-scoped until the user chooses a mode.
  Uri? _websiteFallbackUrl;
  _VideoLocation? _watchOrigin;
  bool _personalVisible = false;
  bool _personalSearching = false, _personalFilterOpen = false;
  final _personalSearchFocus = FocusNode();
  final _personalQueries = <Uri, String>{}, _personalSorts = <Uri, String>{};
  final _personalKeywordScopes = <Uri, KeywordSearchScope>{};
  final _personalFacets = <Uri, ShelfFacetSelection>{};
  bool _returnToPersonal = false;
  bool _openingLocalHistory = false;
  bool _siteLoadFailed = false;
  bool _verificationVisible = false;
  bool _verificationStalled = false;
  Timer? _verificationDeadline;
  Duration? _verificationResumePosition;
  Uri? _verificationResumeUrl;
  ({Uri url, NativePlaybackReturnState state})? _pendingPlaybackReturn;
  bool _searchVisible = false;
  final _keywordScopes = <String, KeywordSearchScope>{};
  String _activeTab = 'recommend';
  String _nativeTab = 'recommend';
  String? _message;
  String? _diagnostic;
  Uri? _listUrl;
  late Uri _requestedUrl = widget.initialUrl ?? widget.homeUrl;
  late String? _accountLoginUsername = widget.accountLoginUsername;
  Uri? _nextVideoUrl;
  late _VideoCreator? _creatorContext = widget.initialCreator == null
      ? null
      : (
          name: widget.initialCreator!.name,
          url: _requestedUrl,
          reference: widget.initialCreator!,
        );
  _VideoCreator? _nextCreator;
  Uri? _refreshWatchUrl;
  int _refreshCommitSerial = 0;
  Completer<void>? _refreshCompleter;
  Future<void> _playbackDocumentQueue = Future<void>.value();
  List<Map<String, dynamic>> _sections = const [];
  List<Map<String, dynamic>> _videos = const [];
  List<NativeCatalogCategory> _siteCategories = const [];
  Map<String, dynamic> _paging = const {};
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic> _publicProfile = const {};
  Map<String, dynamic> _ownIdentity = const {};
  Uri? _ownIdentityRoot;
  PageStorageBucket _personalStorage = PageStorageBucket();
  PageStorageBucket _subscriptionStorage = PageStorageBucket();
  Map<String, dynamic> _authForm = const {};
  Map<String, dynamic> _playlistEditor = const {};
  final _accountFormKey = GlobalKey<NativeVideoAccountFormState>();
  Uri? _accountTaskUri;
  bool _accountTaskReady = false;
  bool _accountSubmissionStarted = false;
  bool _accountReadback = false;
  String? _accountOperation;
  int _accountRevision = 0;
  String? _accountEntryTabId;
  Uri? _recoveryPage;
  bool _recoveryReady = false, _recoverySubmissionStarted = false;
  int _recoveryRevision = 0;
  bool _authSubmissionStarted = false;
  int _authRevision = 0;
  List<Map<String, dynamic>> _creators = const [];
  List<Map<String, dynamic>> _creatorGroups = const [];
  Map<String, dynamic>? _creatorDirectory;
  Uri? _creatorDirectoryOwner;
  DateTime? _creatorDirectoryReadAt;
  VideoCreatorDirectoryReader? _creatorDirectoryReader;
  VideoCreatorProfileResolver? _creatorResolver;
  Future<Map<String, dynamic>?>? _creatorDirectoryPending;
  int _creatorDirectoryGeneration = 0;
  final _creatorBridges = <String, Map<String, dynamic>>{};
  String? _openingCreator;
  int _creatorIntent = 0;
  bool _loadingMoreCreators = false;
  bool _creatorDirectoryFailed = false;
  String _catalogTitle = '';
  Uri? _loginReturnUrl;
  VideoSourceOptions _sourceOptions = const VideoSourceOptions();
  final _backStack = <_VideoLocation>[];
  final _tabHistory = <String>[];
  final _detailParents = <String, _VideoLocation?>{};
  late final _catalogCache = VideoCatalogCache(cacheSource: widget.source);
  Object _catalogImageRefresh = Object();
  int _documentCacheGeneration = 0;
  int _documentPersonalCacheGeneration = 0;
  late final _accountSource = canonicalQjsSource(widget.source);
  int get _accountGeneration =>
      pluginSessionWriteFence.generation(_accountSource);
  bool get _accountChanging =>
      pluginSessionWriteFence.isChanging(_accountSource);
  int? _documentAccountGeneration;
  bool get _currentAccountDocument =>
      !widget.nativeAccount ||
      !_accountChanging && _documentAccountGeneration == _accountGeneration;
  StreamSubscription<PluginSessionBoundary>? _accountChanges;
  ({Uri from, bool account, bool website})? _accountRefresh;
  late final _personalSnapshots = VideoPersonalSnapshotStore(
    cacheSource: widget.source,
  );
  int _personalLoadIntent = 0;
  final _personalPageWindow = VideoPersonalPageWindow();
  Uri? _personalContinuationTarget;
  bool _personalContinuationFailed = false;
  final _personalViews = <Uri, String>{};
  final _personalPreferencesLoaded = <String>{};
  final _personalRecentCache =
      <Uri, ({DateTime readAt, List<Map<String, dynamic>> videos})>{};
  final _commentDrafts = VideoCommentDraftStore();
  VideoFilterSchema? _siteFilters;
  Map<String, List<VideoFilterChoice>> _observedTagGroups = const {};
  bool _filterPanelOpen = false;
  bool _returning = false;
  bool _animateCatalogArrival = true;
  final _modeMenu = NativeVideoMenuController();
  NativeVideoMenuController? _openNativeMenu;
  Size? _menuPhysicalSize;
  EdgeInsets? _menuInsets;

  bool get _canGoBackInside =>
      _openNativeMenu != null ||
      _searchVisible ||
      _personalVisible ||
      _inPersonalLibrary ||
      _requestedUrl.path == '/watch' && _watchOrigin != null ||
      _backStack.isNotEmpty ||
      SourceReturnPreferences.includesTabHistory && _previousTab != null;

  NativeCatalogTab? get _previousTab =>
      widget.tabs
          .where((tab) => tab.id == _tabHistory.lastOrNull)
          .firstOrNull ??
      (widget.tabs.isNotEmpty && _activeTab != widget.tabs.first.id
          ? widget.tabs.first
          : null);

  _VideoLocation get _location => (
    uri: videoSiteDocumentUrl(_requestedUrl),
    creator: _creatorContext,
    tab: _activeTab,
    website: _websiteVisible,
    personal: _personalVisible,
    fallback: videoSiteDocumentMatches(_websiteFallbackUrl, _requestedUrl),
    playback: null,
  );

  void _rememberLocation() {
    if (_busy || _detailVisible || _verificationVisible) return;
    final entry = _location;
    if (_backStack.isNotEmpty && _backStack.last == entry) return;
    if (_backStack.length >= 30) _backStack.removeAt(0);
    _backStack.add(entry);
  }

  Future<void> _goBackInside({bool leaveVerification = false}) async {
    if (_openNativeMenu != null) {
      _dismissCatalogMenu();
      return;
    }
    if (_returning || _verificationVisible && !leaveVerification) return;
    if (_searchVisible) {
      FocusScope.of(context).unfocus();
      setState(() => _searchVisible = false);
      return;
    }
    _returning = true;
    try {
      if (!await _allowLeaveAccount() || !mounted) return;
      if (_verificationVisible) {
        if (!leaveVerification) return;
        _loadEpoch++;
        _clearVerification();
      }
      _resetAccountTask();
      if (_inPersonalLibrary && _ownIdentityRoot != null) {
        await _load(
          _ownIdentityRoot!,
          rememberHistory: false,
          reuseFresh: true,
        );
        return;
      } else if (_requestedUrl.path == '/watch' &&
          await _restoreWatchOrigin()) {
        return;
      } else if (_backStack.isNotEmpty) {
        final entry = _backStack.removeLast();
        _activeTab = entry.tab;
        if (entry.personal) {
          _showPersonal(remember: false);
        } else if (_usesWebsiteFor(entry.uri, fallback: entry.website)) {
          _creatorContext = entry.creator;
          await _openWebsitePage(
            entry.uri,
            fallback: entry.fallback,
            rememberHistory: false,
          );
        } else if (entry.uri.path == '/watch') {
          _watchOrigin =
              _detailParents.remove(entry.uri.toString()) ?? _location;
          await _load(
            entry.uri,
            rememberHistory: false,
            preserveWatchOrigin: true,
            playbackReturn: entry.playback,
          );
        } else {
          final cached = _cachedCatalog(entry.uri);
          if (cached == null) {
            await _load(
              entry.uri,
              rememberHistory: false,
              creator: entry.creator,
            );
          } else {
            _authSubmissionStarted = false;
            _loginReturnUrl = null;
            _loadEpoch++;
            _clearVerification();
            _parsingEpoch = null;
            _nativeTab = entry.tab;
            _requestedUrl = entry.uri;
            _creatorContext = entry.creator;
            _listUrl = entry.uri;
            setState(() {
              // The interactive edge-back already provides this transition.
              _animateCatalogArrival = false;
              _applyCatalog(cached);
              _personalVisible = false;
              _documentLoading = false;
              _siteLoadFailed = false;
            });
            _recordCatalogFrame('cache-frame-ready');
            unawaited(_web?.stopLoading().catchError((_) {}));
          }
        }
      } else if (_personalVisible) {
        final account = widget.tabs
            .where((tab) => tab.mode == 'account')
            .firstOrNull;
        if (account != null) await _openSiteAccount(account);
      } else if (_previousTab case final NativeCatalogTab previous
          when SourceReturnPreferences.includesTabHistory) {
        if (_tabHistory.isNotEmpty) _tabHistory.removeLast();
        await _openTab(previous, rememberTab: false, leaveChecked: true);
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _returning = false;
    }
  }

  Future<Map<String, dynamic>> _callPlugin(
    String fnPath,
    Map<String, dynamic> core,
  ) {
    final call = widget.pluginCall;
    return (call != null
            ? call(fnPath, core)
            : callUnifiedComicPlugin(
                from: widget.source,
                fnPath: fnPath,
                core: core,
              ))
        .timeout(const Duration(seconds: 8));
  }

  Future<dynamic> _evaluate(String script, {int timeoutSeconds = 5}) {
    final web = _web;
    if (web == null) return Future.error(StateError('WebView unavailable'));
    return web
        .evaluateJavascript(source: script)
        .timeout(Duration(seconds: timeoutSeconds));
  }

  @override
  void initState() {
    super.initState();
    if (widget.nativeAccount) {
      _accountChanges = pluginSessionWriteFence.changes.listen(
        _accountSessionChanged,
      );
    }
    _networkLease = SourceNetworkPolicies.supports(widget.source)
        ? SourceNetworkPolicies.acquire(widget.source)
        : Future.value(null);
    _network = _networkLease
        .then(
          (lease) => lease == null
              ? null
              : OmoNetworkContext.open(
                  null,
                  source: widget.source,
                  siteOrigins: [widget.homeUrl],
                ),
        )
        .then((value) {
          _networkContext = value;
          return value;
        });
    unawaited(_network.then<void>((_) {}, onError: (Object _) {}));
    SourceReturnPreferences.changes.addListener(_onReturnModeChanged);
    SourceDiagnosticPreferences.changes.addListener(_onDiagnosticToolsChanged);
    unawaited(_readDiagnosticToolsPreference());
    unawaited(SourceReturnPreferences.load());
    WidgetsBinding.instance.addObserver(this);
    _siteMonitor = Timer.periodic(const Duration(seconds: 5), (_) {
      // Active verification already has a short bounded observation loop.
      // After its soft deadline, the existing foreground monitor must still
      // notice late content changes without requesting/solving anything.
      if (!_verificationVisible || _verificationStalled) {
        unawaited(_inspectSite());
      }
    });
  }

  void _onReturnModeChanged() {
    if (mounted) setState(() {});
  }

  void _onDiagnosticToolsChanged() =>
      unawaited(_readDiagnosticToolsPreference());

  Future<void> _readDiagnosticToolsPreference() async {
    final epoch = ++_diagnosticPreferenceEpoch;
    final enabled = await SourceDiagnosticPreferences.enabled(widget.source);
    if (!mounted || epoch != _diagnosticPreferenceEpoch) return;
    setState(() => _diagnosticToolsEnabled = enabled);
    // Revoking the setting also revokes a live inspector session. Hiding a
    // command alone must not leave the page inspectable in the background.
    final browser = _web?.platform;
    if (!enabled && _inspectionEnabled && browser is VideoBrowserInspection) {
      try {
        final actual = await (browser as VideoBrowserInspection)
            .setInspectionEnabled(false)
            .timeout(const Duration(seconds: 4));
        if (mounted && identical(_web?.platform, browser)) {
          setState(() => _inspectionEnabled = actual);
        }
      } catch (_) {
        // The browser may already have been disposed with its route.
      }
    }
  }

  bool get _usesVerificationWindow =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      _web?.platform is VideoBrowserVerificationWindow;

  Future<void> _exitSource() async {
    if (!await _allowLeaveAccount() || !mounted) return;
    _dismissCatalogMenu();
    exitSourceToDiscover(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _dismissCatalogMenu();
    if (_foreground) {
      if (_browserNeedsRecovery) {
        unawaited(_recoverBrowserDocument());
      } else {
        unawaited(_inspectSite());
      }
    }
  }

  void _browserProcessTerminated() {
    if (!mounted) return;
    _browserDiagnostics.document('process-terminated', _requestedUrl);
    _browserNeedsRecovery = true;
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _deadlineEpoch = null;
    // Process eviction is neither a website choice nor a failed native parse.
    // Keep the rendered catalog; defer a single GET until the app is active.
    if (_foreground) unawaited(_recoverBrowserDocument());
  }

  Future<void> _recoverBrowserDocument() async {
    final web = _web;
    if (!mounted ||
        _accountChanging ||
        !_foreground ||
        !_browserNeedsRecovery ||
        web == null ||
        _detailVisible ||
        _personalVisible ||
        _refreshCompleter != null ||
        // The watch parser also owns restoration after its detail route pops.
        // Wait until it has selected the originating page, never reopen watch
        // while that Navigator completion is still restoring the catalog.
        _requestedUrl.path == '/watch' && _parsingEpoch == _loadEpoch ||
        _verificationWindowActive)
      return;
    _browserNeedsRecovery = false;
    final target = _requestedUrl;
    final keepNative =
        !_websiteVisible &&
        !_verificationVisible &&
        (!_busy && !_siteLoadFailed || _refreshingCatalog);
    final epoch = ++_loadEpoch;
    _documentCacheGeneration = _catalogCache.generation;
    _documentPersonalCacheGeneration = _personalSnapshots.generation;
    _documentAccountGeneration = _accountGeneration;
    _parsingEpoch = null;
    _documentLoading = true;
    _awaitingCommit = true;
    _authSubmissionStarted = false;
    _accountSubmissionStarted = false;
    _recoverySubmissionStarted = false;
    setState(() {
      _refreshingCatalog = keepNative;
      _busy = !keepNative;
      _siteLoadFailed = false;
      _catalogRefreshFailed = false;
      _message = null;
    });
    _startLoadWatchdog(target);
    try {
      _clearDocumentFailureEvidence();
      _browserDiagnostics.requested('process-recovery');
      await web
          .loadUrl(urlRequest: URLRequest(url: WebUri(target.toString())))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (mounted && epoch == _loadEpoch) {
        _showLoadError(reason: 'process-recovery-failed', path: target.path);
      }
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted || _openNativeMenu == null) return;
    final view = View.of(context);
    final insets = EdgeInsets.fromViewPadding(view.viewInsets, 1);
    // iOS also emits redundant metrics during focus/presentation. Only actual
    // geometry or keyboard changes invalidate this anchored menu.
    if (_menuPhysicalSize != view.physicalSize || _menuInsets != insets) {
      _dismissCatalogMenu();
    }
  }

  void _catalogMenuOpened(NativeVideoMenuController controller) {
    if (!mounted || !controller.attached) return;
    final previous = _openNativeMenu;
    final view = View.of(context);
    _menuPhysicalSize = view.physicalSize;
    _menuInsets = EdgeInsets.fromViewPadding(view.viewInsets, 1);
    setState(() => _openNativeMenu = controller);
    if (previous != null && previous != controller) {
      unawaited(previous.dismiss());
    }
  }

  void _catalogMenuClosed(NativeVideoMenuController controller) {
    if (mounted && identical(_openNativeMenu, controller)) {
      setState(() => _openNativeMenu = null);
    }
  }

  void _dismissCatalogMenu() {
    final menu = _openNativeMenu;
    if (menu == null) return;
    // Retain the barrier through UIKit's exit. An immediate second tap must
    // not pass through a menu that is still visibly closing.
    unawaited(menu.dismiss());
  }

  Future<VideoSiteState> _readSiteState({bool diagnostics = false}) async {
    if (_verificationWindowActive) {
      throw StateError('Verification window is active');
    }
    final state = VideoSiteState.fromRaw(
      await _evaluate(
        videoSiteStateScript(widget.selectors, diagnostics: diagnostics),
        timeoutSeconds: 2,
      ),
    );
    if (mounted) {
      if (diagnostics) _browserDiagnostics.browser = state.browser;
      _browserDiagnostics.observed(
        state,
        matchesRequested: videoSiteDocumentMatches(_requestedUrl, state.url),
      );
      _lastDocumentUrl = state.url;
    }
    return state;
  }

  Future<void> _inspectSite() async {
    if (_browserNeedsRecovery) {
      await _recoverBrowserDocument();
      return;
    }
    if (!mounted ||
        _verificationWindowActive ||
        !_foreground ||
        _web == null ||
        _inspecting ||
        _busy && !_detailVisible ||
        _personalVisible ||
        _refreshCompleter != null ||
        _parsingEpoch == _loadEpoch && !_detailVisible) {
      return;
    }
    final epoch = _loadEpoch;
    _inspecting = true;
    try {
      final state = await _readSiteState();
      if (!mounted ||
          _verificationWindowActive ||
          !_foreground ||
          epoch != _loadEpoch ||
          !videoSiteDocumentMatches(_requestedUrl, state.url)) {
        return;
      }
      if (_verificationVisible) {
        final ready =
            (_websiteVisible ? state.websiteReady : state.nativeReady) ||
            _authenticationReady(state);
        if (!state.challenge && ready) {
          await _onLoaded(state.url, observedState: state);
        } else if (!_verificationStalled) {
          _showVerification(epoch);
        }
        return;
      }
      if (!state.challenge) {
        if (_detailVisible && state.nativeReady) {
          _siteVerificationRequired.value = false;
        }
        return;
      }
      if (_detailVisible) {
        _siteVerificationRequired.value = true;
      } else {
        await _onLoaded(state.url, observedState: state);
      }
    } catch (_) {
      // A settled page may be navigating again. Never refresh it here.
    } finally {
      _inspecting = false;
    }
  }

  void _clearVerification() {
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _deadlineEpoch = null;
    _verificationVisible = false;
    _verificationStalled = false;
    _verificationDeadline?.cancel();
    _verificationDeadline = null;
  }

  void _showVerification(int epoch) {
    if (!mounted ||
        _verificationWindowActive ||
        epoch != _loadEpoch ||
        _personalVisible) {
      return;
    }
    _readRecovery.reset();
    _completeAutomaticRead();
    // Read-only observation revisits this state every two seconds. Only the
    // transition into verification owns focus/menu cleanup; repeating it would
    // close the verification actions while the user is trying to use them.
    if (!_verificationVisible) {
      FocusScope.of(context).unfocus();
      _accountFormKey.currentState?.clearSensitiveInputs();
      _dismissCatalogMenu();
    }
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _deadlineEpoch = null;
    _invalidateCatalogCaches();
    if (_verificationDeadline == null) {
      _browserDiagnostics.verification('shown');
      _verificationStalled = false;
      _verificationDeadline = Timer(const Duration(seconds: 60), () {
        if (mounted && epoch == _loadEpoch && _verificationVisible) {
          _browserDiagnostics.verification('observation-deadline');
          _loadWatchdog?.cancel();
          setState(() => _verificationStalled = true);
        }
      });
    }
    setState(() {
      _verificationVisible = true;
      _refreshingCatalog = false;
      _catalogRefreshFailed = false;
      _busy = false;
      _siteLoadFailed = false;
      _searchVisible = false;
      _message = null;
      _diagnostic = null;
    });
    // The website, not the app, performs the verification. These bounded,
    // read-only probes only notice when real site content has returned.
    if (!_verificationStalled) {
      _loadWatchdog = Timer(const Duration(seconds: 2), () {
        if (mounted &&
            _foreground &&
            epoch == _loadEpoch &&
            _verificationVisible) {
          unawaited(_onLoaded(_requestedUrl));
        }
      });
    }
  }

  Future<void> _refreshWebsiteDocument() async {
    if (_verificationVisible) return _reloadVerification();
    final web = _web;
    if (!mounted || !_websiteVisible || _websiteRefreshInFlight || web == null)
      return;
    _websiteRefreshInFlight = true;
    final target = _requestedUrl, epoch = ++_loadEpoch;
    _parsingEpoch = null;
    _clearVerification();
    _clearDocumentFailureEvidence();
    setState(() {
      _busy = true;
      _documentLoading = true;
      _awaitingCommit = true;
      _siteLoadFailed = false;
      _message = null;
    });
    try {
      await web.stopLoading().timeout(const Duration(seconds: 5));
      final current = Uri.tryParse(
        (await web.getUrl().timeout(const Duration(seconds: 3)))?.toString() ??
            '',
      );
      if (!mounted || epoch != _loadEpoch || target != _requestedUrl) return;
      _startLoadWatchdog(target);
      if (videoSiteDocumentMatches(target, current)) {
        await web.reload().timeout(const Duration(seconds: 5));
      } else {
        await web
            .loadUrl(urlRequest: URLRequest(url: WebUri(target.toString())))
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      if (mounted && epoch == _loadEpoch)
        _showLoadError(reason: 'website-refresh-failed', path: target.path);
    } finally {
      _websiteRefreshInFlight = false;
    }
  }

  Future<void> _reloadVerification() async {
    if (_verificationReloading || !_verificationVisible) return;
    _verificationReloading = true;
    final target = _requestedUrl;
    var reloadEpoch = _loadEpoch;
    bool ownsVerification() =>
        mounted &&
        reloadEpoch == _loadEpoch &&
        _requestedUrl == target &&
        _verificationVisible;
    try {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(t.videoPlayback.reloadVerification),
          content: Text(t.videoPlayback.reloadVerificationPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.common.retry),
            ),
          ],
        ),
      );
      if (confirmed != true || !ownsVerification()) return;
      reloadEpoch = ++_loadEpoch;
      _parsingEpoch = null;
      _verificationDeadline?.cancel();
      _verificationDeadline = null;
      _showVerification(_loadEpoch);
      // Keep the browser visible and at exactly the same size while restarting.
      // Do not route through _load/_openWebsitePage, which cover the document.
      await _web?.stopLoading().timeout(const Duration(seconds: 5));
      if (!ownsVerification()) return;
      _documentLoading = true;
      _clearDocumentFailureEvidence();
      _browserDiagnostics.requested('user-verification-reload');
      await _web
          ?.loadUrl(urlRequest: URLRequest(url: WebUri(target.toString())))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (ownsVerification()) setState(() => _verificationStalled = true);
    } finally {
      _verificationReloading = false;
    }
  }

  bool get _allowsAndroidVerificationWindow =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _openVerificationWindow() async {
    final browser = _web?.platform;
    if (_verificationWindowActive ||
        !_verificationVisible ||
        _web == null ||
        (!_allowsAndroidVerificationWindow && !_usesVerificationWindow)) {
      return;
    }
    final epoch = _loadEpoch;
    final target = _requestedUrl;
    if (!allowVideoSiteNavigation(widget.homeUrl, target, isMainFrame: true)) {
      return;
    }
    _dismissCatalogMenu();
    setState(() => _verificationWindowActive = true);
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _deadlineEpoch = null;
    _verificationDeadline?.cancel();
    _verificationDeadline = null;
    var retry = false;
    try {
      if (_allowsAndroidVerificationWindow) {
        retry =
            await Navigator.of(context, rootNavigator: true).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _AndroidVideoVerificationPage(
                  home: widget.homeUrl,
                  target: target,
                ),
              ),
            ) ??
            false;
      } else {
        retry = await (browser as VideoBrowserVerificationWindow)
            .openVerificationWindow(target);
      }
    } catch (error) {
      final reason =
          error is PlatformException &&
              const {
                'BUSY',
                'UNAVAILABLE',
                'NETWORK_CLOSED',
                'URL_REJECTED',
              }.contains(error.code)
          ? error.code.toLowerCase()
          : 'unknown';
      _browserDiagnostics.document('verification-window-open-$reason', null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.videoPlayback.verificationWindow} · ${t.error.operationFailed}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verificationWindowActive = false);
    }
    if (!mounted || epoch != _loadEpoch || target != _requestedUrl) return;
    // Returning never means the provider accepted a challenge. Only the
    // explicit retry choice reloads the original destination once.
    _showVerification(epoch);
    if (retry) {
      try {
        _documentLoading = true;
        _clearDocumentFailureEvidence();
        _browserDiagnostics.requested('user-verification-window-return');
        await _web
            ?.loadUrl(urlRequest: URLRequest(url: WebUri(target.toString())))
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        if (mounted && epoch == _loadEpoch) {
          setState(() => _verificationStalled = true);
        }
      }
    }
  }

  void _onDocumentResponse(Uri uri, int status, Map<String, String> headers) {
    if (!_isFirstParty(uri)) return;
    _browserDiagnostics.response(headers, main: true);
    _browserDiagnostics.resource(uri, 'HTTP $status', main: true);
    final challenged = headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() == 'cf-mitigated' &&
          entry.value.toLowerCase() == 'challenge',
    );
    if (videoSiteDocumentMatches(_requestedUrl, uri)) {
      _challengeResponseUrl = challenged ? uri : null;
      _accessDeniedResponseUrl = status == 403 ? uri : null;
      if (!challenged &&
          (status == 408 || status == 425 || status == 429 || status >= 500)) {
        final retry = headers.entries
            .where((e) => e.key.toLowerCase() == 'retry-after')
            .firstOrNull
            ?.value;
        _documentReadFailure = HttpException(
          'HTTP $status${retry == null ? '' : ' Retry-After: $retry'}',
        );
      }
    }
    // The document must commit before it is revealed. The response alone may
    // still be followed by a cancelled navigation or a different document.
  }

  bool _stopBlockedDocument(VideoSiteState state, Uri expected) {
    if (!state.accessBlocked ||
        !videoSiteDocumentMatches(expected, state.url) ||
        !videoSiteDocumentMatches(expected, _accessDeniedResponseUrl))
      return false;
    _blockedDocumentUrl = expected;
    _clearVerification();
    _showLoadError(reason: 'site-access-blocked-http-403', path: expected.path);
    return true;
  }

  Future<void> _readSourceOptions() async {
    try {
      final response = await _callPlugin(
        'getSettingsBundle',
        const {},
      ).timeout(const Duration(seconds: 5));
      _sourceOptions = VideoSourceOptions.fromValues(
        asJsonMap(asJsonMap(response['data'])['values']),
      );
      if (mounted)
        await _configureAccountSync(
          asJsonMap(asJsonMap(response['data'])['accountSync']),
        );
    } catch (_) {
      // Older video plugins use the documented host defaults.
    }
  }

  Future<void> _initializeCatalog() async {
    final epoch = _loadEpoch;
    await _readSourceOptions();
    if (!mounted || epoch != _loadEpoch || _personalVisible) return;
    if (_catalogWebsite) {
      await _openWebsitePage(_requestedUrl);
    } else {
      await _load(_requestedUrl);
    }
  }

  bool get _isPersonalContext =>
      _personalVisible ||
      _hasPersonalShell ||
      widget.tabs.any((tab) => tab.id == _activeTab && tab.mode == 'account');

  Future<void> _showTools() async {
    _dismissCatalogMenu();
    await _openSettings();
  }

  Future<void> _openSearch() async {
    _dismissCatalogMenu();
    if (_websiteVisible) {
      await _openWebsitePage(widget.homeUrl.resolve('/search'));
      return;
    }
    if (_searchVisible || _verificationVisible) return;
    final epoch = _loadEpoch;
    final searchUrl = _listUrl ?? widget.homeUrl;
    var scope = _keywordScopeFor(searchUrl) ?? KeywordSearchScope.all;
    setState(() => _searchVisible = true);
    final result = await Navigator.of(context).push<VideoSearchFilters>(
      videoPageRoute(
        networkSource: widget.source,
        network: _network,
        builder: (_) => VideoSearchPage(
          source: widget.source,
          initial: widget.searchFilters == null
              ? VideoSearchFilters(
                  query:
                      (_listUrl ?? widget.homeUrl).queryParameters['query'] ??
                      '',
                )
              : VideoSearchFilters.fromUri(searchUrl),
          authorEnabled: widget.searchFilters != null,
          initialScope: scope,
          onSubmitScope: (value) => scope = value,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _searchVisible = false);
    if (result == null) return;
    if (epoch != _loadEpoch) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.videoSearch.contextChanged)));
      return;
    }
    if (!result.author) {
      _keywordScopes.remove(result.query);
      _keywordScopes[result.query] = scope;
      if (_keywordScopes.length > VideoSearchHistory.limit) {
        _keywordScopes.remove(_keywordScopes.keys.first);
      }
    }
    _rememberLocation();
    final tab = widget.tabs.where((tab) => tab.mode == 'catalog').firstOrNull;
    if (tab != null) {
      _activeTab = tab.id;
      _nativeTab = tab.id;
    }
    _returnToPersonal = false;
    unawaited(
      VideoSearchHistory.add(widget.source, result.query).catchError((
        Object _,
      ) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.videoSearch.historyWriteFailed)),
          );
        }
      }),
    );
    await _load(
      widget.searchFilters == null
          ? widget.homeUrl
                .resolve('/search')
                .replace(queryParameters: {'query': result.query})
          : result.toUri(widget.homeUrl),
      rememberHistory: false,
    );
  }

  void _clearCatalogSearch() {
    final url = _listUrl;
    if (url == null ||
        url.path != '/search' ||
        url.queryParameters['query']?.isNotEmpty != true)
      return;
    final filters = VideoSearchFilters.fromUri(
      url,
    ).copyWith(query: '', author: false, page: 1);
    unawaited(
      _load(
        filters.activeCount == 0
            ? widget.homeUrl
            : filters.toUri(widget.homeUrl),
      ),
    );
  }

  KeywordSearchScope? _keywordScopeFor(Uri url) {
    if (url.path != '/search' || url.queryParameters['type'] == 'artist')
      return null;
    final query = url.queryParameters['query'];
    if (query == null || query.isEmpty) return null;
    return _keywordScopes[query] ??
        (query == widget.initialUrl?.queryParameters['query']
            ? widget.initialKeywordScope
            : null) ??
        KeywordSearchScope.all;
  }

  VideoFilterChoice? _exactKeywordTag(Uri page) {
    if (widget.homeUrl.host != 'hanime1.me' ||
        _observedTagGroups.isEmpty ||
        _keywordScopeFor(page) != KeywordSearchScope.all) {
      return null;
    }
    final filters = VideoSearchFilters.fromUri(page);
    if (filters.tags.isNotEmpty) return null;
    String fold(String value) => value.trim().toLowerCase();
    final keyword = fold(filters.query);
    if (keyword.isEmpty) return null;
    VideoFilterChoice? match;
    for (final group in _observedTagGroups.values) {
      for (final tag in group) {
        if (tag.value.isEmpty ||
            tag.value.length > 100 ||
            (fold(tag.label) != keyword && fold(tag.value) != keyword)) {
          continue;
        }
        // A display name can be shared by several different site values.
        if (match != null && match.value != tag.value) return null;
        match = tag;
      }
    }
    return match;
  }

  Future<void> _editPlaylist() async {
    if (!widget.nativeSiteActions || _playlistEditor['supported'] != true) {
      return;
    }
    final page = _requestedUrl;
    final operations = VideoSiteOperations(
      page: page,
      evaluate: (script) => _evaluate(script),
    );
    final result = await Navigator.of(context)
        .push<String>(
          videoPageRoute(
            networkSource: widget.source,
            network: _network,
            builder: (_) => VideoPlaylistEditor(
              initial: _playlistEditor,
              operations: operations,
              onLogin: widget.nativeAuth
                  ? () => Navigator.of(context).pop('login')
                  : null,
              onWebsite: () => Navigator.of(context).pop('website'),
            ),
          ),
        )
        .whenComplete(operations.dispose);
    if (!mounted || !videoSiteDocumentMatches(page, _requestedUrl)) return;
    _invalidateCatalogCaches();
    if (result == 'website') {
      await _openWebsitePage(page, fallback: true, rememberHistory: false);
    } else if (result == 'login') {
      _loginReturnUrl = page;
      await _load(widget.homeUrl.resolve('/login'));
    } else if (result == 'deleted') {
      if (_canGoBackInside) {
        await _goBackInside();
      } else {
        await _load(widget.homeUrl, rememberHistory: false);
      }
    } else {
      await _load(page, rememberHistory: false);
    }
  }

  Future<void> _openSettings() async {
    await openSourceSettings(
      context,
      source: widget.source,
      sourceName: widget.title,
      network: _network,
    );
    if (mounted) {
      await _readSourceOptions();
      if (_websiteVisible && !_verificationVisible) {
        await _updateWebsitePresentation();
      }
    }
  }

  bool get _accountNavigationInUse =>
      _authSubmissionStarted ||
      _externalAuthenticationBusy ||
      _accountSubmissionStarted ||
      _recoverySubmissionStarted ||
      _verificationVisible ||
      _verificationWindowActive ||
      _detailVisible ||
      _refreshCompleter != null;

  bool _accountPage(Uri uri, Uri? owner) =>
      _recordPrivacyPage(uri) ||
      _isAccountEdit(uri) ||
      owner != null && _personalRoot(uri) == owner;

  void _accountSessionChanged(PluginSessionBoundary boundary) {
    if (!mounted || boundary.source != _accountSource) return;
    final owner = _ownIdentityRoot;
    final account = _accountPage(_requestedUrl, owner);
    final subscriptions = _requestedUrl.path == '/subscriptions';
    if (_accountRefresh?.from != _requestedUrl) _accountRefresh = null;
    if ((account ||
            subscriptions ||
            !_websiteVisible && (_busy || _refreshingCatalog)) &&
        !_isAuthenticationPage(_requestedUrl)) {
      _accountRefresh ??= (
        from: _requestedUrl,
        account: account,
        website: _websiteVisible,
      );
    }
    // Keep a WebKit login, verification, or player in progress. The account
    // generation still revokes its old private catalog and cache results.
    if (_documentAccountGeneration != null && !_accountNavigationInUse) {
      _loadEpoch++;
      _parsingEpoch = null;
      _loadWatchdog?.cancel();
      _loadDeadline?.cancel();
      _deadlineEpoch = null;
      _readRecovery.reset();
      _completeAutomaticRead();
    }
    _personalLoadIntent++;
    _backStack.removeWhere((entry) => _accountPage(entry.uri, owner));
    _detailParents.removeWhere(
      (_, entry) => entry != null && _accountPage(entry.uri, owner),
    );
    if (_watchOrigin case final origin? when _accountPage(origin.uri, owner)) {
      _watchOrigin = null;
    }
    setState(() {
      if (_creatorDirectoryOwner == null) {
        _resetPersonalCollections();
        _invalidateCatalogCaches();
      } else {
        _bindCreatorOwner(null);
      }
      _ownIdentity = const {};
      _ownIdentityRoot = null;
      _profile = const {};
      _playlistEditor = const {};
      _personalStorage = PageStorageBucket();
      _commentDrafts.clear();
      if (account || subscriptions) {
        _publicProfile = const {};
        _sections = const [];
        _videos = const [];
        _paging = const {};
        _creators = const [];
        _creatorGroups = const [];
        _catalogTitle = '';
        _busy = true;
        _refreshingCatalog = false;
        _siteLoadFailed = false;
        if (!_accountSubmissionStarted) _resetAccountTask();
      }
    });
    if (!boundary.changing) {
      scheduleMicrotask(() {
        if (mounted && boundary.generation == _accountGeneration) {
          _resumeAccountCatalog();
        }
      });
    }
  }

  bool _resumeAccountCatalog() {
    final refresh = _accountRefresh;
    if (refresh == null ||
        _accountChanging ||
        _accountNavigationInUse ||
        _web == null)
      return false;
    _accountRefresh = null;
    if (_requestedUrl != refresh.from || _websiteVisible != refresh.website) {
      return false;
    }
    final target = refresh.account ? widget.homeUrl : refresh.from;
    if (refresh.website) {
      unawaited(_openWebsitePage(target, rememberHistory: false));
      return true;
    }
    if (refresh.account &&
        widget.tabs.any(
          (tab) => tab.id == _activeTab && tab.mode == 'account',
        )) {
      _accountEntryTabId = _activeTab;
    }
    unawaited(_load(target, rememberHistory: false));
    return true;
  }

  bool _isAuthenticationPage(Uri uri) => const {
    '/login',
    '/register',
    '/password/reset',
    '/password/email',
  }.contains(uri.path);

  @override
  void dispose() {
    unawaited(_accountChanges?.cancel());
    _readRecovery.dispose();
    _completeAutomaticRead();
    _personalSearchFocus.dispose();
    final retry = _downloadRetryResolver;
    if (retry != null) VideoDownloadRetry.unregister(widget.source, retry);
    _unregisterAccountSync();
    unawaited(
      _network.then<void>(
        (value) async => value?.close(),
        onError: (Object _) {},
      ),
    );
    unawaited(
      _networkLease.then<void>(
        (lease) async => lease?.close(),
        onError: (Object _) {},
      ),
    );
    SourceReturnPreferences.changes.removeListener(_onReturnModeChanged);
    SourceDiagnosticPreferences.changes.removeListener(
      _onDiagnosticToolsChanged,
    );
    _diagnosticPreferenceEpoch++;
    _commentDrafts.clear();
    _creatorDirectoryReader?.dispose();
    _creatorResolver?.dispose();
    unawaited(_openNativeMenu?.dismiss());
    _openNativeMenu = null;
    _loadEpoch++;
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _verificationDeadline?.cancel();
    _siteMonitor?.cancel();
    _siteVerificationRequired.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_refreshCompleter?.isCompleted == false) {
      _refreshCompleter!.complete();
    }
    super.dispose();
  }

  bool _isFirstParty(Uri? uri) =>
      uri?.scheme == 'https' &&
      uri?.host == widget.homeUrl.host &&
      uri?.userInfo.isEmpty == true &&
      (uri?.hasPort != true || uri?.port == 443);

  bool _hasNativePage(Uri uri) =>
      _isFirstParty(uri) &&
      (uri.path == '/' ||
          uri.path == '/search' ||
          uri.path == '/watch' &&
              uri.queryParameters['v']?.isNotEmpty == true ||
          widget.nativeSubscriptions && uri.path == '/subscriptions' ||
          widget.nativeAccount &&
              (uri.path == '/login' ||
                  widget.nativeAuth && uri.path == '/password/reset' ||
                  _recoveryPage != null && uri.path == '/password/email' ||
                  _isAccountEdit(uri) ||
                  widget.nativeAuth && uri.path == '/register' ||
                  RegExp(
                    r'^/user/\d+(?:/(?:histories|saves|likes|playlists|uploaded|uploading))?/?$',
                  ).hasMatch(uri.path) ||
                  uri.path == '/playlist' &&
                      RegExp(
                        r'^[A-Za-z0-9_-]{1,80}$',
                      ).hasMatch(uri.queryParameters['list'] ?? '')));

  void _rememberWatchOrigin(Uri destination) {
    if (destination.path == '/watch') {
      _personalRecentCache.clear();
      _personalSnapshots.invalidate();
    }
    if (destination.path == '/watch' &&
        (_requestedUrl.path != '/watch' || _personalVisible)) {
      _watchOrigin = _location;
    }
  }

  /// Follow a real website link while retaining the user's renderer choice.
  /// Account/subscription pages do not turn all video links into web pages.
  bool _adoptWebsiteNavigation(Uri? uri) {
    if (_browserNeedsRecovery ||
        (_allowsAndroidVerificationWindow && _verificationWindowActive)) {
      return false;
    }
    // A real account form posts to the owner's root, then may redirect back
    // to edit. Keep this task mounted; its private inputs never join catalog
    // extraction or a cached frame. Only the same owner can be adopted.
    if (_accountTaskUri case final task?
        when !_catalogWebsite &&
            _accountSubmissionStarted &&
            _isFirstParty(uri)) {
      final root = task.path.replaceFirst(RegExp(r'/edit/?$'), '');
      final permitted =
          uri!.path == root ||
          uri.path == task.path ||
          (_accountOperation == 'logout' &&
              const {'/logout', '/', '/login'}.contains(uri.path)) ||
          uri.path == '/login';
      if (permitted && !videoSiteDocumentMatches(_requestedUrl, uri)) {
        if (uri.path == '/login' && _accountOperation != 'logout') {
          _loginReturnUrl = task;
          _accountSubmissionStarted = false;
          _accountFormKey.currentState?.clearSensitiveInputs();
        }
        _requestedUrl = videoSiteDocumentUrl(uri);
        _loadEpoch++;
        _parsingEpoch = null;
        _invalidateCatalogCaches();
        setState(() {
          _busy = true;
          _websiteVisible = false;
          _message = null;
        });
        return true;
      }
    }
    if (!_catalogWebsite &&
        _recoverySubmissionStarted &&
        _recoveryPage != null &&
        _isFirstParty(uri) &&
        const {'/password/reset', '/password/email'}.contains(uri!.path) &&
        !videoSiteDocumentMatches(_requestedUrl, uri)) {
      _requestedUrl = videoSiteDocumentUrl(uri);
      _loadEpoch++;
      _parsingEpoch = null;
      setState(() {
        _busy = true;
        _websiteVisible = false;
      });
      return true;
    }
    // Only normalization within the same author identity can be adopted by a
    // native author request. A redirect to home never becomes an author page.
    if (!_websiteVisible &&
        !_detailVisible &&
        !_personalVisible &&
        _busy &&
        _documentLoading &&
        _sameCreatorPage(_creatorContext, uri) &&
        !videoSiteDocumentMatches(_requestedUrl, uri)) {
      _requestedUrl = videoSiteDocumentUrl(uri!);
      _listUrl = _requestedUrl;
      _loadEpoch++;
      _parsingEpoch = null;
      return true;
    }
    if (!_catalogWebsite &&
        widget.nativeAuth &&
        _authSubmissionStarted &&
        _isFirstParty(uri) &&
        !_detailVisible &&
        !_personalVisible &&
        !videoSiteDocumentMatches(_requestedUrl, uri)) {
      _requestedUrl = videoSiteDocumentUrl(uri!);
      _loadEpoch++;
      _parsingEpoch = null;
      _invalidateCatalogCaches();
      _verificationDeadline?.cancel();
      _verificationDeadline = null;
      setState(() {
        _websiteVisible = !_hasNativePage(_requestedUrl);
        _busy = true;
        _message = null;
      });
      if (_verificationVisible) _showVerification(_loadEpoch);
      return true;
    }
    // A native request can be redirected to login by the site. This is a
    // required authentication flow, not a parser fallback or a mode change.
    if (widget.nativeAccount &&
        _isFirstParty(uri) &&
        uri?.path == '/login' &&
        _requestedUrl.path != '/login' &&
        !_websiteVisible &&
        !_detailVisible &&
        !_personalVisible &&
        !_verificationVisible &&
        _refreshCompleter == null &&
        _busy &&
        _documentLoading &&
        _hasNativePage(_requestedUrl)) {
      _loginReturnUrl = _requestedUrl;
      if (!_accountTaskReady) {
        _resetAccountTask();
      } else {
        _accountSubmissionStarted = false;
        _accountFormKey.currentState?.clearSensitiveInputs();
      }
      _requestedUrl = videoSiteDocumentUrl(uri!);
      _websiteFallbackUrl = _requestedUrl;
      _loadEpoch++;
      _parsingEpoch = null;
      _invalidateCatalogCaches();
      setState(() {
        _websiteVisible = !widget.nativeAuth;
        _refreshingCatalog = false;
        _catalogRefreshFailed = false;
        _siteLoadFailed = false;
        _message = null;
      });
      return true;
    }
    if (!_isFirstParty(uri) ||
        !_websiteVisible ||
        _detailVisible ||
        _personalVisible ||
        _verificationVisible ||
        videoSiteDocumentMatches(_requestedUrl, uri)) {
      return false;
    }
    final destination = videoSiteDocumentUrl(uri!);
    if (destination.path == '/login' &&
        _requestedUrl.path != '/login' &&
        _hasNativePage(_requestedUrl)) {
      _loginReturnUrl = _requestedUrl;
    }
    final native =
        !_catalogWebsite &&
        _hasNativePage(destination) &&
        !videoSiteDocumentMatches(_websiteFallbackUrl, destination);
    _rememberWatchOrigin(destination);
    if (!native || destination.path != '/watch') _rememberLocation();
    // Website navigation owns its actual route too. Returning to native must
    // select that section, rather than retaining the tab before the fallback.
    final actualTab = widget.tabs.where((tab) {
      return videoSiteDocumentMatches(tab.url, destination) ||
          tab.mode == 'account' &&
              _ownIdentityRoot != null &&
              _personalRoot(destination) == _ownIdentityRoot;
    }).firstOrNull;
    if (actualTab != null) {
      _activeTab = actualTab.id;
      if (actualTab.mode == 'catalog') _nativeTab = actualTab.id;
    } else if (destination.path == '/' || destination.path == '/search') {
      // A website search can originate from My. Restore its browsing context,
      // not the account toolbar/tab that happened to precede the web session.
      _activeTab = _nativeTab;
    }
    _requestedUrl = destination;
    if (!_sameCreatorPage(_creatorContext, destination)) _creatorContext = null;
    _loadEpoch++;
    _parsingEpoch = null;
    if (destination.path == '/' || destination.path == '/search') {
      _listUrl = destination;
    }
    setState(() {
      _websiteVisible = !native;
      _refreshingCatalog = false;
      _catalogRefreshFailed = false;
      _busy = true;
      _siteLoadFailed = false;
      _message = null;
      _diagnostic = null;
    });
    return true;
  }

  Future<bool> _restoreWatchOrigin() async {
    final origin = _watchOrigin;
    _watchOrigin = null;
    if (origin == null) return false;
    _activeTab = origin.tab;
    if (_backStack.lastOrNull == origin) _backStack.removeLast();
    if (origin.personal) {
      _showPersonal(remember: false);
    } else if (_usesWebsiteFor(origin.uri, fallback: origin.website)) {
      await _openWebsitePage(
        origin.uri,
        fallback: origin.fallback,
        rememberHistory: false,
      );
    } else {
      await _load(
        origin.uri,
        rememberHistory: false,
        reuseFresh: true,
        creator: origin.creator,
      );
    }
    return true;
  }

  void _startLoadWatchdog(Uri? uri) {
    _loadWatchdog?.cancel();
    if (!_isFirstParty(uri) || _refreshCompleter != null) return;
    final epoch = _loadEpoch;
    if (_deadlineEpoch != epoch) {
      _loadDeadline?.cancel();
      _deadlineEpoch = epoch;
      _loadDeadline = Timer(
        Duration(seconds: _sourceOptions.parseTimeoutSeconds),
        () {
          if (mounted && epoch == _loadEpoch && (_busy || _refreshingCatalog)) {
            _showLoadError(
              reason: 'dom-not-ready-${_sourceOptions.parseTimeoutSeconds}s',
              path: uri!.path,
            );
          }
        },
      );
    }
    _scheduleDomProbe(uri!, epoch, 1);
  }

  void _scheduleDomProbe(Uri expected, int epoch, int attempt) {
    _loadWatchdog?.cancel();
    // Detect usable content without waiting for ads/subframes to finish.
    final delay = [100, 250, 500, 1000, 2000][(attempt - 1).clamp(0, 4)];
    _loadWatchdog = Timer(Duration(milliseconds: delay), () async {
      if (!mounted ||
          epoch != _loadEpoch ||
          !(_busy || _refreshingCatalog) ||
          _refreshCompleter != null ||
          _parsingEpoch == epoch) {
        return;
      }
      try {
        if (_awaitingCommit) {
          _scheduleDomProbe(expected, epoch, attempt + 1);
          return;
        }
        final state = await _readSiteState();
        if (!mounted || epoch != _loadEpoch) return;
        if (_stopBlockedDocument(state, expected)) return;
        if (videoSiteDocumentMatches(expected, state.url) &&
            (state.challenge ||
                (_websiteVisible ? state.websiteReady : state.nativeReady) ||
                _authenticationReady(state))) {
          await _onLoaded(expected, observedState: state);
          return;
        }
      } catch (_) {
        // A navigation may be between documents; probe the next settled DOM.
      }
      if (!mounted || epoch != _loadEpoch || !(_busy || _refreshingCatalog)) {
        return;
      }
      _scheduleDomProbe(expected, epoch, attempt + 1);
    });
  }

  void _showLoadError({
    String reason = 'main-frame-error',
    String path = '/',
    Object? error,
  }) {
    _loadWatchdog?.cancel();
    _loadDeadline?.cancel();
    _deadlineEpoch = null;
    if (!mounted || _refreshCompleter != null || _personalVisible) return;
    if (_verificationVisible) {
      // Do not cover an interactive challenge with a generic network error.
      setState(() => _verificationStalled = true);
      return;
    }
    _completeAutomaticRead();
    final transport =
        RegExp(
          r'^WKNavigation url -(1001|1003|1004|1005|1006|1009) ',
        ).hasMatch(reason) ||
        const {
          'HOST_LOOKUP',
          'CONNECT',
          'IO',
          'TIMEOUT',
          'ERROR_HOST_LOOKUP',
          'ERROR_CONNECT',
          'ERROR_IO',
          'ERROR_TIMEOUT',
        }.contains(reason);
    final failure =
        error ??
        _documentReadFailure ??
        (transport
            ? const SocketException('Web document connection failed')
            : StateError(reason));
    if (_automaticCatalogAllowed)
      _readRecovery.failed(failure);
    else
      _readRecovery.reset();
    setState(() {
      final keepCatalog = _refreshingCatalog && !_websiteVisible;
      final showOriginalBlockedPage =
          _websiteVisible && reason == 'site-access-blocked-http-403';
      _busy = false;
      _accountSubmissionStarted = false;
      _documentLoading = false;
      _refreshingCatalog = false;
      _catalogRefreshFailed = keepCatalog;
      if (_personalContinuationTarget == _requestedUrl)
        _personalContinuationFailed = true;
      if (keepCatalog) _browserDiagnostics.catalog('refresh-failed');
      _siteLoadFailed = !keepCatalog && !showOriginalBlockedPage;
      _searchVisible = false;
      _message = keepCatalog || showOriginalBlockedPage
          ? null
          : reason == 'site-access-blocked-http-403'
          ? (Localizations.localeOf(context).languageCode == 'zh'
                ? '站点已拒绝本次访问（HTTP 403），此页面没有可完成的验证。请稍后重试，或在官方浏览器中核对访问情况。'
                : 'The site refused this visit (HTTP 403). This page has no verification to complete. Try later or check the official site in your browser.')
          : _websiteVisible
          ? t.webview.loadFailed
          : t.videoPlayback.catalogFallback;
      _diagnostic =
          'Hanime1 native catalog\npath: ${videoSiteDiagnosticPath(Uri(path: path))}\nfailure: $reason';
    });
  }

  Future<void> _load(
    Uri uri, {
    bool rememberHistory = true,
    bool reuseFresh = false,
    bool preserveWatchOrigin = false,
    _VideoCreator? creator,
    bool preserveAccountTask = false,
    NativePlaybackReturnState? playbackReturn,
    bool automaticRecovery = false,
  }) async {
    if (!mounted || !_isFirstParty(uri)) return;
    if (uri.path != '/login') _accountLoginUsername = null;
    final accountGeneration = _accountGeneration;
    if (!automaticRecovery) {
      _readRecovery.reset();
      _completeAutomaticRead();
    }
    final personalLoadIntent = ++_personalLoadIntent;
    final personalCacheGeneration = _personalSnapshots.generation;
    final continuingPersonal =
        _personalContinuationTarget == uri &&
        _personalScope(uri) == _personalScope(_requestedUrl) &&
        _personalSnapshotAllowed(uri, _ownIdentityRoot) &&
        _videos.isNotEmpty;
    if (!continuingPersonal) {
      _personalContinuationTarget = null;
      _personalContinuationFailed = false;
    }
    if (_personalScope(uri) != _personalScope(_requestedUrl)) {
      _personalSearchFocus.unfocus();
      _personalSearching = false;
    }
    if (_catalogWebsite) {
      await _openWebsitePage(uri, rememberHistory: rememberHistory);
      return;
    }
    if (!preserveAccountTask) {
      final sameAccount = _accountTaskUri == uri && _accountTaskReady;
      if (!sameAccount) {
        _resetAccountTask();
        if (_isAccountEdit(uri)) _accountTaskUri = uri;
      }
    }
    if (uri.path != '/password/reset') {
      _recoveryPage = null;
      _recoveryReady = false;
      _recoverySubmissionStarted = false;
    } else if (_recoveryPage == null && widget.nativeAuth) {
      _recoveryPage = uri;
      _recoveryReady = false;
    }
    _dismissCatalogMenu();
    _authSubmissionStarted = false;
    if (!const {'/login', '/register', '/password/reset'}.contains(uri.path)) {
      _loginReturnUrl = null;
    }
    final web = _web;
    if (!preserveWatchOrigin) _rememberWatchOrigin(uri);
    if (rememberHistory &&
        uri.path != '/watch' &&
        !videoSiteDocumentMatches(uri, _requestedUrl)) {
      _rememberLocation();
    }
    final key = _catalogKey(uri);
    final snapshotOwner = _ownIdentityRoot, snapshotEpoch = _loadEpoch;
    Map<String, dynamic>? personalSnapshot;
    if (_personalSnapshotAllowed(uri, snapshotOwner)) {
      personalSnapshot = await _personalSnapshots.read(
        VideoPersonalSnapshotStore.scope(widget.source, snapshotOwner!, uri),
      );
      if (!mounted ||
          personalLoadIntent != _personalLoadIntent ||
          snapshotEpoch != _loadEpoch ||
          accountGeneration != _accountGeneration ||
          snapshotOwner != _ownIdentityRoot)
        return;
      await _readPersonalPreferences(uri);
      if (!mounted ||
          personalLoadIntent != _personalLoadIntent ||
          snapshotEpoch != _loadEpoch ||
          accountGeneration != _accountGeneration ||
          snapshotOwner != _ownIdentityRoot)
        return;
    }
    final cached =
        (_isAccountEdit(uri) ||
            const {'/login', '/register', '/password/reset'}.contains(uri.path))
        ? null
        : _cachedCatalog(uri) ??
              (personalSnapshot == null
                  ? null
                  : {...personalSnapshot, 'account': _ownIdentity});
    final useFresh =
        reuseFresh &&
        !_verificationVisible &&
        cached != null &&
        (_catalogCache.isFresh(key) ||
            personalSnapshot != null &&
                _personalSnapshots.fresh(personalSnapshot));
    final wasLoading = _documentLoading;
    if (_creatorDirectoryPending != null) {
      _creatorDirectoryReader?.dispose();
      _creatorDirectoryReader = null;
      _creatorDirectoryPending = null;
    }
    _creatorIntent++;
    _creatorResolver?.dispose();
    _creatorResolver = null;
    _openingCreator = null;
    if (uri.path == '/' || uri.path == '/search') _listUrl = uri;
    _loadEpoch++;
    _documentCacheGeneration = _catalogCache.generation;
    _documentPersonalCacheGeneration = personalCacheGeneration;
    _documentAccountGeneration = accountGeneration;
    final epoch = _loadEpoch;
    _requestedUrl = uri;
    _pendingPlaybackReturn = uri.path == '/watch' && playbackReturn != null
        ? (url: uri, state: playbackReturn)
        : null;
    _creatorContext =
        creator ??
        (_sameCreatorPage(_creatorContext, uri) ? _creatorContext : null);
    _websiteFallbackUrl = null;
    _parsingEpoch = null;
    _documentLoading = !useFresh;
    _awaitingCommit = !useFresh;
    _clearVerification();
    if (_searchVisible) FocusScope.of(context).unfocus();
    setState(() {
      _animateCatalogArrival = !_returning && (cached == null || useFresh);
      if (cached != null) _applyCatalog(cached);
      _refreshingCatalog = (cached != null || continuingPersonal) && !useFresh;
      _catalogRefreshFailed = false;
      _busy = cached == null && !continuingPersonal;
      _websiteVisible = false;
      _personalVisible = false;
      _siteLoadFailed = false;
      _searchVisible = false;
      _message = null;
      _diagnostic = null;
    });
    if (cached != null) _recordCatalogFrame('cache-frame-ready');
    if (useFresh) {
      _personalContinuationTarget = null;
      _personalContinuationFailed = false;
      // No network, DOM traversal or plugin call on a recent tab revisit.
      // The existing browser remains available for a genuine fresh request
      // or website mode; do not create a second browser/session.
      if (wasLoading) unawaited(web?.stopLoading().catchError((_) {}));
      return;
    }
    if (web == null) return;
    _startLoadWatchdog(uri);
    try {
      await web.stopLoading().timeout(const Duration(seconds: 5));
      if (!mounted || epoch != _loadEpoch) return;
      _browserDiagnostics.requested('native-navigation');
      _clearDocumentFailureEvidence();
      await web
          .loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())))
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      if (epoch == _loadEpoch) {
        _showLoadError(
          reason: 'load-url-exception',
          path: uri.path,
          error: error,
        );
      }
    }
  }

  bool _sameCreatorPage(_VideoCreator? creator, Uri? uri) =>
      creator != null &&
      uri != null &&
      _isFirstParty(uri) &&
      creator.reference.contains(uri);

  Map<String, dynamic> _creatorWire(VideoCreatorReference creator) => {
    'role': creator.role,
    'name': creator.name,
    'title': creator.name,
    'entityKey': creator.entityKey,
    if (creator.artistId != null) 'artistId': creator.artistId,
    if (creator.profileId != null) 'profileId': creator.profileId,
    if (creator.profileUrl != null) 'profileUrl': creator.profileUrl.toString(),
    if (creator.nameSearchUrl != null)
      'nameSearchUrl': creator.nameSearchUrl.toString(),
    if (creator.avatarUrl != null) 'avatarUrl': creator.avatarUrl.toString(),
    if (creator.avatarUrl != null) 'coverUrl': creator.avatarUrl.toString(),
    if (creator.profileUrl ?? creator.nameSearchUrl case final target?)
      'pageUrl': target.toString(),
    'pages': {
      for (final entry in creator.pages.entries)
        entry.key: entry.value.toString(),
    },
  };

  void _invalidateCatalogCaches() {
    _catalogCache.clear();
    _personalRecentCache.clear();
    _personalSnapshots.invalidate();
    _creatorDirectoryGeneration++;
    _creatorDirectoryReader?.dispose();
    _creatorDirectoryReader = null;
    _creatorDirectory = null;
    _creatorDirectoryReadAt = null;
    _creatorDirectoryFailed = false;
    _creatorDirectoryPending = null;
  }

  void _bindCreatorOwner(Uri? owner) {
    if (owner == _creatorDirectoryOwner) return;
    _resetPersonalCollections();
    _invalidateCatalogCaches();
    _creatorIntent++;
    _creatorResolver?.dispose();
    _creatorResolver = null;
    _creatorDirectoryOwner = owner;
    _creatorBridges.clear();
    _openingCreator = null;
    _subscriptionStorage = PageStorageBucket();
  }

  void _resetPersonalCollections() {
    _personalPageWindow.clear();
    _personalContinuationTarget = null;
    _personalContinuationFailed = false;
    _personalPreferencesLoaded.clear();
    _personalQueries.clear();
    _personalKeywordScopes.clear();
    _personalSorts.clear();
    _personalFacets.clear();
    _personalViews.clear();
  }

  void _rememberCreator(VideoCreatorReference? creator) {
    if (creator?.artistId == null ||
        creator?.profileUrl == null ||
        _creatorDirectoryOwner == null) {
      return;
    }
    final wire = _creatorWire(creator!);
    final previous = _creatorBridges[creator.entityKey];
    // Different observed profiles for the same artist are a conflict, not a
    // reason to select whichever result arrived last.
    if (previous != null && previous['profileUrl'] != wire['profileUrl']) {
      _creatorBridges[creator.entityKey] = {'conflict': true};
    } else if (previous?['conflict'] != true) {
      _creatorBridges[creator.entityKey] = wire;
    }
  }

  VideoCreatorReference _knownCreator(VideoCreatorReference creator) {
    final bridge = _creatorBridges[creator.entityKey];
    if (bridge == null || bridge['conflict'] == true) return creator;
    return VideoCreatorReference.fromWire(
          {..._creatorWire(creator), ...bridge},
          widget.homeUrl,
          role: creator.role,
        ) ??
        creator;
  }

  Future<Map<String, dynamic>?> _readCreatorDirectory({Uri? page}) async {
    if (_creatorDirectoryOwner == null) return null;
    if (page == null &&
        !_creatorDirectoryFailed &&
        _creatorDirectory != null &&
        _creatorDirectoryReadAt != null &&
        DateTime.now().difference(_creatorDirectoryReadAt!) <
            const Duration(seconds: 30)) {
      return _creatorDirectory;
    }
    if (page == null && _creatorDirectoryPending != null) {
      return _creatorDirectoryPending;
    }
    final generation = _creatorDirectoryGeneration;
    final epoch = _loadEpoch;
    final owner = _creatorDirectoryOwner;
    final reader = _creatorDirectoryReader ??= VideoCreatorDirectoryReader(
      home: widget.homeUrl,
      evaluate: (script) => _evaluate(script),
    );
    final task = () async {
      final result = await reader.read(page: page);
      if (!mounted ||
          epoch != _loadEpoch ||
          generation != _creatorDirectoryGeneration ||
          owner != _creatorDirectoryOwner) {
        return null;
      }
      if (result.status != VideoSiteStatus.ok ||
          result.value?['ownerUrl'] != owner.toString()) {
        _creatorDirectoryFailed = true;
        return null;
      }
      _creatorDirectoryFailed = false;
      final creators = <String, Map<String, dynamic>>{};
      if (page != null) {
        for (final raw in asJsonList(_creatorDirectory?['creators'])) {
          final creator = asJsonMap(raw);
          creators[creator['entityKey'].toString()] = creator;
        }
      }
      for (final raw in asJsonList(result.value?['creators']).take(500)) {
        final creator = asJsonMap(raw);
        final ref = VideoCreatorReference.fromWire(creator, widget.homeUrl);
        if (ref?.artistId == null || ref!.entityKey.isEmpty) continue;
        creators[ref.entityKey] = {..._creatorWire(ref), 'followed': true};
      }
      _creatorDirectory = {
        ...result.value!,
        'creators': creators.values.take(500).toList(),
      };
      _creatorDirectoryReadAt = DateTime.now();
      return _creatorDirectory;
    }();
    _creatorDirectoryPending = task;
    try {
      return await task;
    } finally {
      if (identical(_creatorDirectoryPending, task)) {
        _creatorDirectoryPending = null;
      }
    }
  }

  Future<VideoCreatorReference?> _resolveCreator(
    VideoCreatorReference creator, {
    Uri? representativeWatch,
  }) async {
    final intent = ++_creatorIntent;
    _creatorResolver?.dispose();
    _creatorResolver = null;
    var known = _knownCreator(creator);
    if (known.profileUrl != null) {
      if (_openingCreator != null) setState(() => _openingCreator = null);
      return known;
    }
    if (known.artistId == null || _creatorDirectoryOwner == null) {
      if (_openingCreator != null) setState(() => _openingCreator = null);
      return null;
    }
    final owner = _creatorDirectoryOwner;
    final epoch = _loadEpoch;
    setState(() => _openingCreator = known.entityKey);
    final resolver = _creatorResolver ??= VideoCreatorProfileResolver(
      home: widget.homeUrl,
      evaluate: (script) => _evaluate(script),
    );
    try {
      final result = await resolver.resolve(
        creator: _creatorWire(known),
        representativeWatch: representativeWatch,
      );
      if (!mounted ||
          intent != _creatorIntent ||
          epoch != _loadEpoch ||
          owner != _creatorDirectoryOwner ||
          result.status != VideoSiteStatus.ok ||
          result.value?['ownerUrl'] != owner.toString()) {
        return null;
      }
      known =
          VideoCreatorReference.fromWire(result.value!, widget.homeUrl) ??
          known;
      if (known.profileUrl == null ||
          known.entityKey != creator.entityKey ||
          known.artistId != creator.artistId) {
        return null;
      }
      _rememberCreator(known);
      return known;
    } finally {
      if (mounted && intent == _creatorIntent) {
        setState(() => _openingCreator = null);
      }
    }
  }

  void _creatorUnavailable() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.videoCommunity.creatorUnavailable)),
      );
    }
  }

  Future<void> _openCreatorReference(
    VideoCreatorReference creator, {
    bool works = false,
    Uri? representativeWatch,
  }) async {
    final intent = _creatorIntent + 1;
    final resolved = await _resolveCreator(
      creator,
      representativeWatch: representativeWatch,
    );
    if (!mounted || intent != _creatorIntent) return;
    // Both profile and all-works actions retain the same real identity.
    // Only use a child page actually observed for this author.
    final target = works
        ? resolved?.pages['uploaded'] ?? resolved?.profileUrl
        : resolved?.profileUrl;
    if (resolved == null || target == null) {
      _creatorUnavailable();
      return;
    }
    await _pushContentPage(target, creator: resolved);
  }

  Future<void> _openCreator(
    Uri target,
    String name, {
    Map<String, dynamic>? raw,
  }) async {
    final creator = VideoCreatorReference.fromWire(
      raw ?? {'name': name, 'url': target.toString()},
      widget.homeUrl,
    );
    if (creator == null) return;
    if (creator.profileUrl != null) {
      await _openCreatorReference(creator);
    } else if (creator.artistId != null) {
      await _openCreatorReference(creator);
    } else if (creator.nameSearchUrl != null) {
      // An actual name-search link remains a search, without claiming to be a profile.
      await _load(creator.nameSearchUrl!);
    }
  }

  Future<void> _queueCreatorFromPlayer(
    VideoCreatorReference creator, {
    bool works = false,
    Uri? representativeWatch,
  }) async {
    final intent = _creatorIntent + 1;
    final resolved = await _resolveCreator(
      creator,
      representativeWatch: representativeWatch,
    );
    if (!mounted || !_detailVisible || intent != _creatorIntent) {
      return;
    }
    // Both profile and all-works actions retain the same real identity.
    // Only use a child page actually observed for this author.
    final target = works
        ? resolved?.pages['uploaded'] ?? resolved?.profileUrl
        : resolved?.profileUrl;
    if (resolved == null || target == null) {
      _creatorUnavailable();
      return;
    }
    await _pushContentPage(target, creator: resolved);
  }

  Future<void> _pushContentPage(
    Uri target, {
    VideoCreatorReference? creator,
    BuildContext? navigatorContext,
  }) async {
    await Navigator.of(navigatorContext ?? context).push<void>(
      videoPageRoute<void>(
        settings: const RouteSettings(name: 'breeze.video.catalog-content'),
        networkSource: widget.source,
        network: _network,
        builder: (_) => NativeVideoCatalogPage(
          source: widget.source,
          title: widget.title,
          homeUrl: widget.homeUrl,
          catalogFnPath: widget.catalogFnPath,
          detailFnPath: widget.detailFnPath,
          playbackFnPath: widget.playbackFnPath,
          selectors: widget.selectors,
          categories: widget.categories,
          tabs: const [],
          pluginCall: widget.pluginCall,
          nativeAccount: widget.nativeAccount,
          nativeSubscriptions: widget.nativeSubscriptions,
          nativeAuth: widget.nativeAuth,
          nativeSiteActions: widget.nativeSiteActions,
          externalAuthenticationEntries: widget.externalAuthenticationEntries,
          searchFilters: widget.searchFilters,
          initialUrl: target,
          initialCreator: creator,
          returnToCallerAfterPlayback:
              navigatorContext != null && target.path == '/watch',
        ),
      ),
    );
  }

  Future<void> _loadMoreCreators() async {
    final next = Uri.tryParse(_creatorDirectory?['nextUrl']?.toString() ?? '');
    if (next?.hasScheme != true || _loadingMoreCreators) return;
    setState(() => _loadingMoreCreators = true);
    final epoch = _loadEpoch;
    try {
      final directory = await _readCreatorDirectory(page: next);
      if (!mounted || epoch != _loadEpoch) return;
      if (directory == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoCommunity.network)));
        return;
      }
      // A fresh cached feed can be showing while WK still holds a profile.
      // Reload the actual feed rather than parsing that unrelated document.
      await _load(_requestedUrl, rememberHistory: false);
    } finally {
      if (mounted) setState(() => _loadingMoreCreators = false);
    }
  }

  Future<void> _showNativeCatalog() async {
    final wasBusy = _busy || _refreshingCatalog || _documentLoading;
    final target = _requestedUrl;
    final epoch = ++_loadEpoch;
    // Website navigation invalidates older native snapshots. This new native
    // extraction belongs to the current generation; later invalidations still
    // prevent its asynchronous result from entering the cache.
    _documentCacheGeneration = _catalogCache.generation;
    _parsingEpoch = null;
    _clearVerification();
    setState(() {
      _websiteVisible = false;
      _refreshingCatalog = false;
      _catalogRefreshFailed = false;
      _siteLoadFailed = false;
      _personalVisible = false;
      _busy = true;
      _message = null;
    });
    if (!_currentAccountDocument && _hasNativePage(target)) {
      await _load(target, rememberHistory: false);
      return;
    }
    // Changing presentation must not restart an in-flight site request.
    if (wasBusy && _hasNativePage(target)) {
      _startLoadWatchdog(target);
      return;
    }
    Uri? current;
    try {
      current = Uri.tryParse(
        (await _web?.getUrl().timeout(
              const Duration(seconds: 3),
            ))?.toString() ??
            '',
      );
    } catch (_) {
      // A stuck website still allows a fresh native navigation below.
    }
    if (!mounted || epoch != _loadEpoch) return;
    // The requested video/search remains authoritative when getUrl still
    // exposes the previous document. Changing renderer must not go home.
    if (_hasNativePage(target)) {
      if (videoSiteDocumentMatches(target, current)) {
        await _onLoaded(target);
      } else {
        await _load(target, rememberHistory: false);
      }
      return;
    }
    final tab = widget.tabs.where((tab) => tab.id == _nativeTab).firstOrNull;
    if (tab != null) {
      await _openTab(tab);
      return;
    }
    await _load(_listUrl ?? widget.homeUrl);
  }

  bool _usesWebsiteFor(Uri uri, {bool fallback = false}) =>
      !_hasNativePage(uri) ||
      _catalogWebsite ||
      (_displayModeChoice == null && fallback);

  void _setDisplayModeChoice(bool website) {
    _displayModeChoice = website;
    if (!website) return;
    // Native form continuations must not reclaim a user-owned web session.
    _accountFormKey.currentState?.clearSensitiveInputs();
    _resetAccountTask();
    _recoveryPage = null;
    _recoveryReady = false;
    _recoverySubmissionStarted = false;
    _authSubmissionStarted = false;
    _loginReturnUrl = null;
  }

  Future<void> _chooseDisplayMode(bool website) async {
    if (!await _allowLeaveAccount() || !mounted) return;
    // A deliberate choice governs subsequent links and back navigation;
    // it never writes the plugin's default or another source's preference.
    _setDisplayModeChoice(website);
    _websiteFallbackUrl = website ? videoSiteDocumentUrl(_requestedUrl) : null;
    if (website) _invalidateCatalogCaches();
    if (_verificationVisible) {
      // Choose the destination after verification without restarting it.
      setState(() => _websiteVisible = website);
      return;
    }
    if (!website) {
      if (!_websiteVisible && !_personalVisible) return;
      await _showNativeCatalog();
      return;
    }
    if (_websiteVisible) return;
    final account = widget.tabs
        .where((tab) => tab.id == _activeTab && tab.mode == 'account')
        .firstOrNull;
    if (account != null &&
        (_personalVisible || !_hasNativePage(_requestedUrl))) {
      await _openSiteAccount(account);
      return;
    }
    final target = _requestedUrl;
    final settled =
        !_documentLoading && videoSiteDocumentMatches(target, _lastDocumentUrl);
    if (!_personalVisible &&
        (!_siteLoadFailed ||
            videoSiteDocumentMatches(target, _blockedDocumentUrl)) &&
        (videoSiteDocumentMatches(target, _lastDocumentUrl) ||
            (_busy || _refreshingCatalog || _documentLoading) &&
                videoSiteDocumentMatches(target, _requestedUrl))) {
      _loadEpoch++;
      _parsingEpoch = null;
      setState(() {
        _websiteVisible = true;
        _refreshingCatalog = false;
        _catalogRefreshFailed = false;
        _requestedUrl = target;
        _siteLoadFailed = false;
        _message = null;
        _busy = !settled;
      });
      if (_busy) {
        _startLoadWatchdog(target);
      } else {
        await _onLoaded(target);
      }
      return;
    }
    await _openWebsitePage(target);
  }

  Future<void> _openWebsitePage(
    Uri uri, {
    bool fallback = false,
    bool rememberHistory = true,
    bool userChoice = false,
  }) async {
    if (!_isFirstParty(uri)) return;
    if (userChoice) {
      if (!await _allowLeaveAccount() || !mounted) return;
      _setDisplayModeChoice(true);
    }
    _dismissCatalogMenu();
    _authSubmissionStarted = false;
    if (!const {'/login', '/register'}.contains(uri.path)) {
      _loginReturnUrl = null;
    }
    final web = _web;
    if (rememberHistory && !videoSiteDocumentMatches(uri, _requestedUrl)) {
      _rememberLocation();
    }
    _rememberWatchOrigin(uri);
    _websiteFallbackUrl = fallback ? videoSiteDocumentUrl(uri) : null;
    // Website sessions can change login/subscription state. Never reuse a
    // catalog snapshot across those changes (or a subsequent challenge).
    _invalidateCatalogCaches();
    if (uri.path == '/' || uri.path == '/search') _listUrl = uri;
    _loadEpoch++;
    final epoch = _loadEpoch;
    _documentAccountGeneration = _accountGeneration;
    _requestedUrl = uri;
    if (!_sameCreatorPage(_creatorContext, uri)) _creatorContext = null;
    _parsingEpoch = null;
    _documentLoading = true;
    _awaitingCommit = true;
    _clearVerification();
    setState(() {
      _websiteVisible = true;
      _refreshingCatalog = false;
      _catalogRefreshFailed = false;
      _personalVisible = false;
      _busy = true;
      _siteLoadFailed = false;
      _searchVisible = false;
      _message = null;
    });
    if (web == null) return;
    _startLoadWatchdog(uri);
    try {
      await web.stopLoading().timeout(const Duration(seconds: 5));
      if (!mounted || epoch != _loadEpoch) return;
      _browserDiagnostics.requested('website-navigation');
      _clearDocumentFailureEvidence();
      await web
          .loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      if (epoch == _loadEpoch) {
        _showLoadError(reason: 'website-load-exception', path: uri.path);
      }
    }
  }

  Future<void> _openTab(
    NativeCatalogTab tab, {
    bool rememberTab = true,
    bool leaveChecked = false,
  }) async {
    if ((!leaveChecked && !await _allowLeaveAccount()) || !mounted) return;
    // A challenge belongs to the current browser session, not a catalog tab.
    // Stopping it to open another tab restarts the challenge and can prevent
    // an otherwise valid human interaction from finishing.
    if (_verificationVisible ||
        tab.id == _activeTab && (_busy || _refreshingCatalog)) {
      return;
    }
    if (rememberTab && tab.id != _activeTab) {
      final previous = _tabHistory.indexOf(tab.id);
      if (previous >= 0) {
        _tabHistory.removeRange(previous, _tabHistory.length);
      } else {
        if (_tabHistory.length >= 30) _tabHistory.removeAt(0);
        _tabHistory.add(_activeTab);
      }
    }
    _accountEntryTabId = null;
    _authSubmissionStarted = false;
    _returnToPersonal = false;
    _watchOrigin = null;
    _detailParents.clear();
    _loginReturnUrl = null;
    _backStack.clear();
    final sameTab = tab.id == _activeTab;
    setState(() {
      _activeTab = tab.id;
      _searchVisible = false;
    });
    if (tab.mode == 'catalog') {
      _nativeTab = tab.id;
      if (_catalogWebsite) {
        await _openWebsitePage(tab.url, rememberHistory: false);
      } else {
        await _load(tab.url, rememberHistory: false, reuseFresh: !sameTab);
      }
      return;
    }
    if (tab.mode == 'account') {
      await _openSiteAccount(tab);
      return;
    }
    if (!mounted || _activeTab != tab.id) return;
    await _openWebsitePage(tab.url, rememberHistory: false);
  }

  Future<void> _showPersonal({bool remember = true}) async {
    if (!mounted || _verificationVisible || _openingLocalHistory) return;
    if (!await _allowLeaveAccount() || !mounted) return;
    _resetAccountTask();
    _dismissCatalogMenu();
    FocusScope.of(context).unfocus();
    _openingLocalHistory = true;
    try {
      await _evaluate(
        'document.querySelector(${jsonEncode(widget.selectors['video'])})?.pause();',
      ).catchError((_) => null);
      if (!mounted) return;
      await openVideoLocalHistory(
        context,
        source: widget.source,
        siteHost: widget.homeUrl.host,
        onOpenVideo: (recordContext, uri) =>
            unawaited(_pushContentPage(uri, navigatorContext: recordContext)),
      );
    } finally {
      _openingLocalHistory = false;
    }
  }

  Future<void> _openSiteAccount(
    NativeCatalogTab tab, {
    bool website = false,
  }) async {
    final epoch = _loadEpoch;
    Future<void> open(Uri target) =>
        widget.nativeAccount && !_catalogWebsite && !website
        ? _load(target, rememberHistory: false, reuseFresh: true)
        : _openWebsitePage(target, fallback: website, rememberHistory: false);
    if (!_currentAccountDocument && widget.nativeAccount && !website) {
      if (_accountChanging) return;
      _accountEntryTabId = tab.id;
      await _load(widget.homeUrl, rememberHistory: false);
      return;
    }
    try {
      final raw = await _evaluate(videoSiteProfileLinkScript);
      if (!mounted || epoch != _loadEpoch || _activeTab != tab.id) return;
      final profile = widget.homeUrl.resolve(raw?.toString() ?? '');
      if (_isFirstParty(profile) &&
          RegExp(r'^/user/\d+(?:/)?$').hasMatch(profile.path)) {
        if (_ownIdentityRoot != null && profile != _ownIdentityRoot) {
          _invalidateCatalogCaches();
        }
        await open(profile);
        return;
      }
      final signedOut = await _evaluate(r'''
        (() => { const breezeAccountEntry = true;
          return Boolean(document.querySelector('a[href="/login"], a[href="https://hanime1.me/login"], form[action$="/login"]'));
        })()
      ''');
      if (!mounted || epoch != _loadEpoch || _activeTab != tab.id) return;
      if (signedOut == true) {
        _invalidateCatalogCaches();
        await open(tab.url);
        return;
      }
    } catch (_) {
      // A missing marker is an unknown session, not proof of signed-out state.
    }
    if (!mounted || epoch != _loadEpoch || _activeTab != tab.id) return;
    _accountEntryTabId = tab.id;
    await _load(widget.homeUrl, rememberHistory: false);
  }

  String _catalogKey(Uri uri) =>
      widget.searchFilters != null && uri.path == '/search'
      ? VideoSearchFilters.fromUri(uri).toUri(widget.homeUrl).toString()
      : videoSiteDocumentUrl(uri).toString();

  Uri? _catalogOwner(Map<String, dynamic> data) {
    final account = asJsonMap(data['account']);
    if (account['status'] != 'signedIn') return null;
    return _personalRoot(Uri.tryParse('${account['profileUrl'] ?? ''}'));
  }

  Map<String, dynamic>? _cachedCatalog(Uri uri) {
    final data = _catalogCache[_catalogKey(uri)];
    if (data == null || !widget.nativeAccount) return data;
    if (_recordPrivacyPage(uri) ||
        asJsonMap(data['account'])['isOwnProfile'] == true &&
            _personalRoot(uri) != null) {
      final owner = _ownIdentityRoot;
      final root = _personalRoot(uri);
      if (!_currentAccountDocument ||
          owner == null ||
          _catalogOwner(data) != owner ||
          root != null && root != owner) {
        return null;
      }
    }
    return data;
  }

  Future<void> _openFilters(
    VideoFilterSection section, {
    bool advanced = false,
  }) async {
    final base = _siteFilters ?? widget.searchFilters;
    if (base == null || _filterPanelOpen) return;
    _filterPanelOpen = true;
    _dismissCatalogMenu();
    final epoch = _loadEpoch;
    final reader = VideoFilterSchemaReader(
      home: widget.homeUrl,
      evaluate: _evaluate,
    );
    try {
      final initial = VideoSearchFilters.fromUri(_listUrl ?? widget.homeUrl);
      VideoSearchFilters? result;
      if (!advanced &&
          section != VideoFilterSection.tags &&
          section != VideoFilterSection.query) {
        final choice = await showVideoTaskSheet<Object>(
          context: context,
          builder: (_) => VideoQuickFilterPanel(
            source: widget.source,
            section: section,
            initial: initial,
            schema: base,
          ),
        );
        if (!mounted) return;
        if (epoch != _loadEpoch) {
          if (choice != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.videoFilters.contextChanged)),
            );
          }
          return;
        }
        if (choice is String) result = initial.change(section, choice);
        if (choice is! VideoFilterSection) {
          if (result != null &&
              result.copyWith(page: 1) != initial.copyWith(page: 1)) {
            await _load(result.toUri(widget.homeUrl));
          }
          return;
        }
      }
      if (!mounted) return;
      result = await showVideoTaskSheet<VideoSearchFilters>(
        context: context,
        builder: (_) => VideoSearchFilterPanel(
          source: widget.source,
          initial: initial,
          schema: base,
          initialSection: section,
          readSchema: reader.read,
          onCancelRead: reader.dispose,
          onSchema: (schema) {
            if (mounted && epoch == _loadEpoch) {
              setState(() {
                _siteFilters = schema;
                _observedTagGroups = schema.tagGroups;
              });
            }
          },
        ),
      );
      if (!mounted || result == null) return;
      if (epoch != _loadEpoch) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoFilters.contextChanged)));
        return;
      }
      await _load(result.toUri(widget.homeUrl, pageNumber: 1));
    } finally {
      reader.dispose();
      _filterPanelOpen = false;
    }
  }

  Future<void> _queueTagFilter({String? tag, Uri? target}) async {
    late final Uri next;
    if (widget.searchFilters == null) {
      next = widget.homeUrl
          .resolve('/search')
          .replace(queryParameters: {'query': tag ?? ''});
    } else {
      var filters = VideoSearchFilters.fromUri(
        _listUrl ?? widget.homeUrl,
      ).copyWith(page: 1);
      if (tag != null) filters = filters.change(VideoFilterSection.tags, tag);
      if (target != null && _isFirstParty(target) && target.path == '/search') {
        for (final section in [
          VideoFilterSection.query,
          VideoFilterSection.genre,
          VideoFilterSection.sort,
          VideoFilterSection.date,
          VideoFilterSection.duration,
        ]) {
          if (target.queryParameters.containsKey(section.name)) {
            filters = filters.change(
              section,
              target.queryParameters[section.name]!,
            );
          }
        }
        for (final value
            in target.queryParametersAll['tags[]'] ?? const <String>[]) {
          filters = filters.change(VideoFilterSection.tags, value);
        }
        if (target.queryParameters.containsKey('broad')) {
          filters = filters.copyWith(
            anyTag: VideoSearchFilters.fromUri(target).anyTag,
          );
        }
        if (target.queryParameters.containsKey('type')) {
          filters = filters.copyWith(
            author: target.queryParameters['type'] == 'artist',
          );
        }
      }
      next = filters.toUri(widget.homeUrl);
    }
    await _pushContentPage(next);
  }

  Future<void> _openCategory(NativeCatalogCategory category) async {
    final current = _listUrl ?? widget.homeUrl;
    if (widget.searchFilters != null) {
      var filters = VideoSearchFilters.fromUri(current);
      if (_activeTab == 'ranking' && filters.sort.isEmpty) {
        final ranking = widget.tabs
            .where((tab) => tab.id == 'ranking')
            .firstOrNull;
        filters = filters.copyWith(
          sort: ranking?.url.queryParameters['sort'] ?? '',
        );
      }
      await _load(
        filters
            .change(
              VideoFilterSection.genre,
              category.url.queryParameters['genre'] ?? '',
            )
            .toUri(widget.homeUrl),
      );
      return;
    }
    final query = <String, String>{};
    if (current.path == '/search') {
      final search = current.queryParameters['query'];
      if (search != null && search.isNotEmpty) query['query'] = search;
    }
    final ranking = widget.tabs.where((tab) => tab.id == 'ranking').firstOrNull;
    if (_activeTab == 'ranking') {
      final sort = ranking?.url.queryParameters['sort'];
      if (sort != null) query['sort'] = sort;
    }
    final genre = category.url.queryParameters['genre'];
    if (genre != null) query['genre'] = genre;
    await _load(
      widget.homeUrl.resolve('/search').replace(queryParameters: query),
    );
  }

  Future<Map<String, dynamic>> _snapshot(bool detail) async {
    final web = _web;
    if (web == null) throw StateError('WebView unavailable');
    final epoch = _loadEpoch, generation = _accountGeneration;
    final script = detail ? _detailScript() : _catalogScript();
    final raw = await _evaluate(script);
    if (!detail &&
        (!mounted || epoch != _loadEpoch || generation != _accountGeneration)) {
      throw const PluginSessionChanged();
    }
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) throw const FormatException('Invalid DOM snapshot');
    final snapshot = Map<String, dynamic>.from(decoded);
    if (!detail &&
        widget.nativeSubscriptions &&
        _requestedUrl.path == '/subscriptions') {
      final account = asJsonMap(snapshot['account']);
      final owner = _personalRoot(
        widget.homeUrl.resolve(account['profileUrl']?.toString() ?? ''),
      );
      _bindCreatorOwner(owner);
      final directory = await _readCreatorDirectory();
      if (directory != null) {
        snapshot['creatorDirectory'] = {
          ...directory,
          'creators': [
            for (final raw in asJsonList(directory['creators']))
              if (VideoCreatorReference.fromWire(asJsonMap(raw), widget.homeUrl)
                  case final ref?)
                {..._creatorWire(_knownCreator(ref)), 'followed': true},
          ],
        };
      }
    }
    if (!detail &&
        widget.nativeAuth &&
        const {'/login', '/register'}.contains(_requestedUrl.path)) {
      final auth = await _evaluate(videoAuthMetadataScript);
      snapshot['auth'] = auth is String ? jsonDecode(auth) : auth;
    }
    if (!detail &&
        widget.nativeSiteActions &&
        _requestedUrl.path == '/playlist') {
      final value = await _evaluate(
        videoSiteOperationScript(_requestedUrl, 'playlistState', const {}),
      );
      snapshot['playlistEditor'] = value is String ? jsonDecode(value) : value;
    }
    return snapshot;
  }

  Future<String> _safeDiagnostic(Uri uri, Object error) async {
    final web = _web;
    final counts = <String, dynamic>{};
    if (web != null) {
      try {
        final script =
            '''
          (() => {
            const selectors = ${jsonEncode(widget.selectors)};
            const keys = ['row', 'cards', 'video', 'detailDescription', 'episodes'];
            const counts = {};
            for (const key of keys) {
              try { counts[key] = document.querySelectorAll(selectors[key]).length; }
              catch (_) { counts[key] = -1; }
            }
            return JSON.stringify(counts);
          })()
        ''';
        final raw = await _evaluate(script, timeoutSeconds: 2);
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is Map) counts.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // A failed page may not allow script execution at all.
      }
    }
    // Export only an allowlisted category from a wrapped plugin exception,
    // never its arbitrary text (which may contain a private page or URL).
    final category = RegExp(
      r'\[(catalog_not_ready|catalog_results_unrecognized)\]',
    ).firstMatch(error.toString())?.group(1);
    return 'Hanime1 native parser\n'
        'path: ${videoSiteDiagnosticPath(uri)}\n'
        'failure: ${category ?? error.runtimeType}\n'
        'selector counts: ${jsonEncode(counts)}';
  }

  String get _analysisPageTitle {
    if (_personalVisible) return t.videoPlayback.localWatchHistory;
    if (_creatorContext != null) return t.videoPlayback.analysisCreator;
    final path = _requestedUrl.path;
    if (_isAccountEdit(_requestedUrl)) return t.videoSiteAccount.title;
    if (_personalRoot(_requestedUrl) != null) {
      return t.videoPlayback.analysisProfile;
    }
    return switch (path) {
      '/' => t.videoPlayback.analysisHome,
      '/search' => t.videoPlayback.search,
      '/subscriptions' => t.videoPlayback.analysisSubscriptions,
      '/watch' => t.videoPlayback.analysisVideo,
      '/playlist' => t.videoPlayback.analysisPlaylist,
      '/login' || '/register' => t.videoPlayback.personalPage,
      '/password/reset' ||
      '/password/email' => t.videoSiteAccount.recoveryTitle,
      _ => t.videoPlayback.analysisSitePage,
    };
  }

  Future<VideoPageAnalysisResult> _analyzePage() async {
    if (!_diagnosticToolsEnabled) throw StateError('Diagnostics disabled');
    final epoch = _loadEpoch;
    final page = _analysisPageTitle;
    // Refresh metadata at the user's request. No background network probes,
    // browser mutation or credential export is involved.
    try {
      await _readSiteState(diagnostics: true);
    } catch (_) {}
    try {
      _browserDiagnostics.native =
          await const MethodChannel('breeze.video.browser')
              .invokeMapMethod<String, dynamic>('diagnostics', {
                'host': widget.homeUrl.host,
              })
              .timeout(const Duration(seconds: 4)) ??
          const {};
    } catch (_) {
      _browserDiagnostics.native = {'metadata': 'unavailable'};
    }
    final diagnostic =
        '${_diagnostic ?? 'Hanime1 browser\npath: ${videoSiteDiagnosticPath(_requestedUrl)}\nverification: $_verificationVisible'}\n'
        'presentation: ${jsonEncode({'preferred': _catalogWebsite ? 'website' : 'native', 'current': _verificationVisible
            ? 'verification'
            : _websiteVisible
            ? 'website'
            : 'native', 'page': videoSiteDiagnosticPath(_requestedUrl), 'pageFallback': videoSiteDocumentMatches(_websiteFallbackUrl, _requestedUrl), 'detailVisible': _detailVisible, 'returnPage': videoSiteDiagnosticPath(_watchOrigin?.uri)})}\n'
        '${_browserDiagnostics.report()}';
    if (!mounted || epoch != _loadEpoch || !_diagnosticToolsEnabled) {
      throw StateError('Page changed or diagnostics disabled');
    }
    return VideoPageAnalysisResult(
      mode: _websiteVisible
          ? t.videoPlayback.backToWeb
          : t.videoPlayback.nativeCatalog,
      page: page,
      status: _verificationVisible
          ? t.videoPlayback.analysisVerification
          : _siteLoadFailed
          ? t.webview.loadFailed
          : _busy || _documentLoading
          ? t.videoPlayback.analysisLoading
          : t.videoPlayback.analysisDisplayed,
      report: diagnostic,
    );
  }

  Future<void> _showPageAnalysis() async {
    if (!_diagnosticToolsEnabled) return;
    await showVideoTaskSheet<void>(
      context: context,
      builder: (_) => VideoPageAnalysis(
        analyze: _analyzePage,
        onCopy: (report) async {
          if (_diagnosticToolsEnabled) {
            await Clipboard.setData(ClipboardData(text: report));
          }
        },
      ),
    );
  }

  Future<void> _copyDiagnostic({String? report}) async {
    if (!_diagnosticToolsEnabled) return;
    try {
      final text = report ?? (await _analyzePage()).report;
      if (!_diagnosticToolsEnabled) return;
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoPlayback.analysisFailed)));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.videoPlayback.diagnosticCopied)));
  }

  String _catalogScript() => videoCatalogSnapshotScript(
    widget.selectors,
    includeFilters: widget.searchFilters != null,
  );

  String _detailScript() => videoDetailSnapshotScript(widget.selectors);

  Future<T> _onceAfterDomSettles<T>(
    Future<T> Function() read,
    int epoch,
  ) async {
    try {
      return await read();
    } catch (_) {
      // Some site cards and <source> nodes arrive just after onLoadStop.
      // One bounded retry avoids a false verification fallback.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted || epoch != _loadEpoch) rethrow;
      return read();
    }
  }

  Future<Map<String, dynamic>> _watchSnapshot(Uri watchUrl) async {
    final snapshot = await _snapshot(true);
    final documentUrl = Uri.tryParse(snapshot['documentUrl']?.toString() ?? '');
    if (!videoSiteDocumentMatches(watchUrl, documentUrl)) {
      throw const FormatException('Watch snapshot identity unavailable');
    }
    return snapshot;
  }

  Future<NativePlaybackSession> _watchDetails(
    Uri watchUrl,
    Map<String, dynamic> snapshot,
  ) async {
    final result = await _callPlugin(widget.detailFnPath, {
      'watchUrl': watchUrl.toString(),
      'snapshot': snapshot,
    });
    final title = asJsonMap(result['data'])['title']?.toString().trim();
    if (title?.isNotEmpty != true) {
      throw const FormatException('Video detail unavailable');
    }
    return NativePlaybackSession.fromDetailResponse(result, watchUrl: watchUrl);
  }

  Future<NativePlaybackSession> _refreshPlayback(Uri watchUrl) {
    final epoch = _loadEpoch;
    final task = _playbackDocumentQueue.then((_) async {
      if (!mounted || epoch != _loadEpoch) {
        throw StateError('Video source closed');
      }
      return _readPlaybackDocument(watchUrl, epoch);
    });
    _playbackDocumentQueue = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return task;
  }

  Future<NativePlaybackSession> _readPlaybackDocument(
    Uri watchUrl,
    int epoch,
  ) async {
    final web = _web;
    if (web == null || _refreshCompleter != null) {
      throw StateError('Video source unavailable');
    }
    final ready = Completer<void>();
    _refreshWatchUrl = watchUrl;
    _refreshCompleter = ready;
    final totalDeadline = DateTime.now().add(const Duration(seconds: 35));
    Future<T> bounded<T>(Future<T> task) {
      final left = totalDeadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        throw TimeoutException('Video document deadline');
      }
      return task.timeout(left);
    }

    try {
      final commitSerial = _refreshCommitSerial;
      Object? previousOrigin;
      try {
        previousOrigin = await _evaluate(
          'performance.timeOrigin',
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
      // The route can leave during the awaited metadata read above, including
      // an untracked expired-source refresh. Never navigate its old document.
      if (!mounted || epoch != _loadEpoch) {
        throw StateError('Video source closed');
      }
      // The underlying WebView may have followed a site redirect while the
      // native detail was open. Refresh this video, not whichever page won.
      _browserDiagnostics.requested('playback-source-refresh');
      _clearDocumentFailureEvidence();
      await web
          .loadUrl(urlRequest: URLRequest(url: WebUri(watchUrl.toString())))
          .timeout(const Duration(seconds: 5));
      // A whole-page load-stop can wait indefinitely on unrelated media or
      // frames. Require a new document, then its interactive video DOM instead.
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      var documentReady = false;
      while (mounted &&
          epoch == _loadEpoch &&
          DateTime.now().isBefore(deadline)) {
        VideoSiteState? state;
        try {
          state = await _readSiteState().timeout(const Duration(seconds: 2));
        } catch (_) {}
        if (state != null && videoSiteDocumentMatches(watchUrl, state.url)) {
          var fresh = ready.isCompleted || _refreshCommitSerial > commitSerial;
          if (!fresh && previousOrigin is num) {
            try {
              final origin = await _evaluate(
                'performance.timeOrigin',
              ).timeout(const Duration(seconds: 2));
              fresh = origin is num && origin != previousOrigin;
            } catch (_) {}
          }
          if (fresh &&
              state.accessBlocked &&
              videoSiteDocumentMatches(watchUrl, _accessDeniedResponseUrl)) {
            throw const VideoSiteAccessBlocked();
          }
          if (fresh && state.challenge) {
            throw const VideoSiteVerificationRequired();
          }
          if (fresh && state.nativeReady) {
            documentReady = true;
            break;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (!mounted || epoch != _loadEpoch) {
        throw StateError('Video source closed');
      }
      if (!documentReady) throw TimeoutException('Video document not ready');
      final session = await bounded(
        _onceAfterDomSettles(() async {
          final snapshot = await _watchSnapshot(watchUrl);
          final response = await _callPlugin(widget.playbackFnPath, {
            'watchUrl': watchUrl.toString(),
            'snapshot': snapshot,
          });
          final detail = await _watchDetails(watchUrl, snapshot);
          final media = NativePlaybackSession.fromPluginResponse(
            response,
            watchUrl: watchUrl,
          );
          return detail.withSources(media.sources);
        }, epoch),
      );
      try {
        await _evaluate(
          'document.querySelector(${jsonEncode(widget.selectors['video'])})?.pause();',
        );
      } catch (_) {}
      final current = await _readSiteState();
      if (!mounted ||
          epoch != _loadEpoch ||
          !videoSiteDocumentMatches(watchUrl, current.url)) {
        throw const FormatException('Episode document changed during parsing');
      }
      return session;
    } finally {
      _refreshWatchUrl = null;
      _refreshCompleter = null;
      if (_browserNeedsRecovery) unawaited(_recoverBrowserDocument());
    }
  }

  Future<void> _onLoaded(
    Uri? loadedUri, {
    VideoSiteState? observedState,
  }) async {
    if (_verificationWindowActive || _personalVisible) return;
    if (!videoSiteDocumentMatches(_requestedUrl, loadedUri)) return;
    final uri = _requestedUrl;
    final epoch = _loadEpoch;
    final accountGeneration = _accountGeneration;
    if (_parsingEpoch == epoch) return;
    _parsingEpoch = epoch;
    try {
      final state = observedState ?? await _readSiteState();
      if (!mounted ||
          _verificationWindowActive ||
          epoch != _loadEpoch ||
          _personalVisible) {
        return;
      }
      if (!videoSiteDocumentMatches(uri, state.url)) {
        if (_verificationVisible) {
          _showVerification(epoch);
        } else {
          _startLoadWatchdog(uri);
        }
        return;
      }
      if (_stopBlockedDocument(state, uri)) return;
      if (_authenticationReady(state) && _hasNativePage(uri)) {
        final raw = await _evaluate(videoSiteProfileLinkScript);
        if (!mounted || epoch != _loadEpoch) return;
        final profile = widget.homeUrl.resolve(raw?.toString() ?? '');
        if (_isFirstParty(profile) &&
            RegExp(r'^/user/\d+/?$').hasMatch(profile.path)) {
          var resume = _loginReturnUrl!;
          if (_isAccountEdit(resume) &&
              resume.path.replaceFirst(RegExp(r'/edit/?$'), '') !=
                  profile.path.replaceFirst(RegExp(r'/$'), '')) {
            _resetAccountTask();
            resume = profile;
          }
          if (_accountTaskUri == resume && _accountOperation != null) {
            _accountReadback = true;
          }
          if (const {'/login', '/register'}.contains(resume.path)) {
            resume = profile;
          }
          _loginReturnUrl = null;
          _authSubmissionStarted = false;
          _invalidateCatalogCaches();
          await _load(
            resume,
            rememberHistory: false,
            preserveWatchOrigin: resume.path == '/watch',
          );
          return;
        }
      }
      if (state.challenge ||
          (_verificationVisible &&
              !(_websiteVisible ? state.websiteReady : state.nativeReady))) {
        _showVerification(epoch);
        return;
      }
      if (_documentReadFailure != null) {
        _showLoadError(
          reason: 'document-http-error',
          path: uri.path,
          error: _documentReadFailure,
        );
        return;
      }
      if (!(_websiteVisible ? state.websiteReady : state.nativeReady)) {
        _startLoadWatchdog(uri);
        return;
      }
      if (_verificationVisible) {
        _browserDiagnostics.verification('content-returned');
      }
      _clearVerification();
      _documentLoading = false;
      if (!_currentAccountDocument && _resumeAccountCatalog()) return;
      if (!_currentAccountDocument && _accountRefresh?.from == uri) return;
      if (_websiteVisible) {
        unawaited(_captureAccountSession());
        await _updateWebsitePresentation();
        if (mounted && epoch == _loadEpoch) {
          setState(() {
            _busy = false;
            _siteLoadFailed = false;
          });
        }
        return;
      }
      if (_recoveryPage != null &&
          const {'/password/reset', '/password/email'}.contains(uri.path)) {
        setState(() {
          _busy = false;
          _siteLoadFailed = false;
          _recoveryReady = true;
          _recoverySubmissionStarted = false;
          _recoveryRevision++;
        });
        return;
      }
      if (_accountTaskUri case final task?) {
        if (_accountOperation == 'logout' &&
            const {'/', '/login'}.contains(uri.path)) {
          final profile = await _evaluate(videoSiteProfileLinkScript);
          if (!mounted || epoch != _loadEpoch) return;
          // Absence alone is not success: require the site's signed-out entry.
          final signedOut = await _evaluate(
            r'''Boolean(document.querySelector('a[href="/login"], a[href="https://hanime1.me/login"], form[action$="/login"]'))''',
          );
          if (!mounted || epoch != _loadEpoch) return;
          if ((profile?.toString() ?? '').isEmpty && signedOut == true) {
            await _accountSync.recordSignOut(widget.source);
            if (!mounted || epoch != _loadEpoch) return;
            _resetAccountTask();
            _profile = {'status': 'signedOut'};
            _captureOwnIdentity();
            await _load(uri, rememberHistory: false);
            return;
          }
        }
        final root = task.path.replaceFirst(RegExp(r'/edit/?$'), '');
        if (_accountSubmissionStarted && uri.path == root) {
          // A redirect or 200 is not a saved-profile confirmation. Read the
          // actual edit document independently, then let the form compare.
          _accountReadback = true;
          await _load(task, rememberHistory: false, preserveAccountTask: true);
          return;
        }
        if (videoSiteDocumentMatches(task, uri)) {
          setState(() {
            _busy = false;
            _siteLoadFailed = false;
            _accountTaskReady = true;
            _accountSubmissionStarted = false;
            _accountRevision++;
          });
          return;
        }
      }
      setState(() {
        _busy = !_refreshingCatalog;
        _siteLoadFailed = false;
      });
      if (uri.path == '/watch') {
        Map<String, dynamic>? detailSnapshot;
        var session = await _onceAfterDomSettles(() async {
          final snapshot = detailSnapshot = await _watchSnapshot(uri);
          return _watchDetails(uri, snapshot);
        }, epoch);
        if (!mounted || epoch != _loadEpoch) return;
        var operations = widget.nativeSiteActions
            ? VideoSiteOperations(
                page: uri,
                evaluate: (script) => _evaluate(script),
                onMutation: _invalidateCatalogCaches,
                onUncertainWrite: _invalidateCatalogCaches,
                drafts: _commentDrafts,
              )
            : null;
        // Read the controls from the current document before exposing them.
        // This is a bounded DOM read. Playlists and comments load on demand.
        final initialSiteInteraction = await operations?.readInteraction();
        if (!mounted ||
            epoch != _loadEpoch ||
            accountGeneration != _accountGeneration ||
            ModalRoute.of(context)?.isActive != true) {
          operations?.dispose();
          return;
        }
        var verifyRequested = false;
        final initialPosition =
            videoSiteDocumentMatches(_verificationResumeUrl, uri)
            ? _verificationResumePosition
            : null;
        _verificationResumePosition = null;
        _verificationResumeUrl = null;
        _detailVisible = true;
        _siteVerificationRequired.value = false;
        _rememberCreator(session.creator);
        bool currentDetail() =>
            mounted && epoch == _loadEpoch && _detailVisible;
        final initialMedia = () async {
          try {
            // Reuse the validated document snapshot for media. If its source
            // tags have not arrived, retry once from a fresh snapshot.
            var initialSnapshot = detailSnapshot;
            final resolved = await _onceAfterDomSettles(() async {
              if (!currentDetail()) throw StateError('Video detail closed');
              final snapshot = initialSnapshot ?? await _watchSnapshot(uri);
              initialSnapshot = null;
              if (!currentDetail()) throw StateError('Video detail closed');
              final playback = await _callPlugin(widget.playbackFnPath, {
                'watchUrl': uri.toString(),
                'snapshot': snapshot,
              });
              return NativePlaybackSession.fromPluginResponse(
                playback,
                watchUrl: uri,
              ).sources;
            }, epoch);
            if (!currentDetail()) return null;
            await _networkContext?.prepare();
            if (!currentDetail()) return null;
            session = session.withSources(resolved);
            return session;
          } catch (_) {
            return null;
          }
        }();
        // A website video should stay paused even while native media is pending.
        unawaited(
          _evaluate(
            'if (location.pathname === "/watch" && '
            'new URL(location.href).searchParams.get("v") === '
            '${jsonEncode(uri.queryParameters['v'])}) '
            'document.querySelector(${jsonEncode(widget.selectors['video'])})?.pause();',
          ).then<void>((_) {}, onError: (Object _) {}),
        );
        var detailLocation = _location;
        final initialPlaybackState =
            videoSiteDocumentMatches(_pendingPlaybackReturn?.url, uri)
            ? _pendingPlaybackReturn?.state
            : null;
        _pendingPlaybackReturn = null;
        Future<NativePlaybackSession>? episodeDocumentTask;
        final callerRoute = ModalRoute.of(context);
        final callerNavigator = callerRoute?.navigator;
        final useWebsite = await Navigator.of(context)
            .push<bool>(
              videoPageRoute<bool>(
                networkSource: widget.source,
                network: _network,
                builder: (_) => NativeVideoPage(
                  session: session,
                  initialMedia: initialMedia,
                  networkContext: _networkContext,
                  playerFactory: _networkContext == null
                      ? null
                      : (source) =>
                            _networkContext!.player(source.url, source.headers),
                  analyzePlayback: (context, current, error) =>
                      showApiPlaybackAnalysis(
                        context,
                        source: widget.source,
                        network: _networkContext,
                        session: current,
                        lineCount: session.sources.length,
                        platformError: error,
                      ),
                  loadEpisode: (next) async {
                    if (!_isFirstParty(next) ||
                        next.path != '/watch' ||
                        !RegExp(
                          r'^[0-9]+$',
                        ).hasMatch(next.queryParameters['v'] ?? '')) {
                      throw const FormatException('Invalid episode');
                    }
                    // Both reads share the same WebView document. Finish the
                    // bounded initial parse before moving it to another episode.
                    await initialMedia;
                    if (!currentDetail())
                      throw StateError('Video detail closed');
                    final task = episodeDocumentTask = _refreshPlayback(next);
                    late NativePlaybackSession nextSession;
                    try {
                      nextSession = await task;
                    } finally {
                      if (identical(episodeDocumentTask, task)) {
                        episodeDocumentTask = null;
                      }
                    }
                    return (
                      session: nextSession,
                      operations: widget.nativeSiteActions
                          ? VideoSiteOperations(
                              page: next,
                              evaluate: (script) => _evaluate(script),
                              onMutation: _invalidateCatalogCaches,
                              onUncertainWrite: _invalidateCatalogCaches,
                              drafts: _commentDrafts,
                            )
                          : null,
                    );
                  },
                  onEpisodeChanged: (next) {
                    session = next.session;
                    operations = next.operations;
                    _requestedUrl = session.watchUrl;
                    _rememberCreator(session.creator);
                  },
                  source: widget.source,
                  siteOperations: operations,
                  initialSiteInteraction: initialSiteInteraction,
                  onOpenAccount: widget.nativeAuth
                      ? () {
                          _loginReturnUrl = session.watchUrl;
                          _nextVideoUrl = widget.homeUrl.resolve('/login');
                          Navigator.of(context).pop();
                        }
                      : null,
                  siteVerification: _siteVerificationRequired,
                  initialPosition: initialPosition,
                  initialPlaybackState: initialPlaybackState,
                  onPlaybackExit: (state) {
                    detailLocation = (
                      uri: session.watchUrl,
                      creator: detailLocation.creator,
                      tab: detailLocation.tab,
                      website: detailLocation.website,
                      personal: detailLocation.personal,
                      fallback: detailLocation.fallback,
                      playback: state,
                    );
                  },
                  onVerifySite: (position) {
                    verifyRequested = true;
                    _verificationResumeUrl = session.watchUrl;
                    _verificationResumePosition = position;
                    Navigator.of(context).pop();
                  },
                  onOpenVideo: (next) {
                    _nextVideoUrl = next;
                    Navigator.of(context).pop();
                  },
                  onOpenCreator: () async {
                    if (session.creator case final creator?) {
                      await _queueCreatorFromPlayer(
                        creator,
                        representativeWatch: session.watchUrl,
                      );
                    }
                  },
                  onOpenCreatorWorks: () async {
                    if (session.creator case final creator?) {
                      await _queueCreatorFromPlayer(
                        creator,
                        works: true,
                        representativeWatch: session.watchUrl,
                      );
                    }
                  },
                  onOpenUploader: () async {
                    if (session.uploader case final uploader?) {
                      await _queueCreatorFromPlayer(uploader);
                    }
                  },
                  onSearchTag: (tag) => _queueTagFilter(tag: tag),
                  onOpenTag: widget.searchFilters == null
                      ? null
                      : (target) => _queueTagFilter(target: target),
                  refreshSession: _sourceOptions.refreshExpiredSources
                      ? () async {
                          await initialMedia;
                          if (!currentDetail()) {
                            throw StateError('Video detail closed');
                          }
                          final current = session;
                          final refreshed = await _refreshPlayback(
                            current.watchUrl,
                          );
                          return current.withSources(refreshed.sources);
                        }
                      : null,
                  preferredSource: _sourceOptions.preferredSource,
                ),
              ),
            )
            .whenComplete(() {
              _detailVisible = false;
              operations?.dispose();
            });
        // Explicit plugin exit can pop both routes in the same frame. A route
        // remains mounted during its reverse transition; it must not restore
        // the watch origin or start another selection after being popped.
        if (!mounted ||
            epoch != _loadEpoch ||
            ModalRoute.of(context)?.isActive != true) {
          return;
        }
        // If the user left during a manual selection, finish that bounded read
        // before restoring the originating page; a late document cannot win.
        try {
          await episodeDocumentTask?.timeout(const Duration(seconds: 25));
        } catch (_) {}
        if (mounted &&
            epoch == _loadEpoch &&
            ModalRoute.of(context)?.isActive == true) {
          if (verifyRequested) {
            _parsingEpoch = null;
            // Reveal the challenge already loaded during source refresh,
            // rather than starting a second challenge in another browser.
            await _onLoaded(session.watchUrl);
            return;
          }
          if (useWebsite == true) {
            await _openWebsitePage(
              session.watchUrl,
              fallback: true,
              userChoice: true,
            );
            return;
          }
          final next = _nextVideoUrl;
          final nextCreator = _nextCreator;
          _nextVideoUrl = null;
          _nextCreator = null;
          if (next != null) {
            if (next.path != '/watch') {
              if (_backStack.length >= 30) _backStack.removeAt(0);
              if (_detailParents.length >= 30) {
                _detailParents.remove(_detailParents.keys.first);
              }
              _backStack.add(detailLocation);
              _detailParents[detailLocation.uri.toString()] = _watchOrigin;
            }
            await _load(
              next,
              rememberHistory: next.path == '/watch',
              creator: nextCreator,
            );
          } else if (await _restoreWatchOrigin()) {
            return;
          } else if (widget.returnToCallerAfterPlayback) {
            if (callerRoute != null &&
                callerRoute.isActive &&
                callerNavigator != null) {
              // The player is already reversing to this temporary catalog
              // route. Remove it so that one animation returns directly to
              // the caller instead of starting a second route pop.
              callerNavigator.removeRoute(callerRoute);
            }
            return;
          } else if (_returnToPersonal) {
            _showPersonal(remember: false);
          } else if (_sections.isNotEmpty || _videos.isNotEmpty) {
            setState(() {
              _requestedUrl = _listUrl ?? widget.homeUrl;
              _websiteVisible = false;
              _siteLoadFailed = false;
              _busy = false;
              _message = null;
            });
          } else {
            await _load(_listUrl ?? widget.homeUrl);
          }
        }
        return;
      }
      if (!_hasNativePage(uri)) {
        _showLoadError(reason: 'unsupported-native-page', path: uri.path);
        return;
      }
      final authentication = _isAuthenticationPage(uri);
      if (!authentication && !_currentAccountDocument) return;
      final result = await _onceAfterDomSettles(() async {
        final snapshot = await _snapshot(false);
        if (!mounted ||
            epoch != _loadEpoch ||
            accountGeneration != _accountGeneration) {
          throw const PluginSessionChanged();
        }
        return _callPlugin(widget.catalogFnPath, {
          'pageUrl': uri.toString(),
          'snapshot': snapshot,
        });
      }, epoch);
      if (!mounted ||
          epoch != _loadEpoch ||
          accountGeneration != _accountGeneration ||
          !authentication && !_currentAccountDocument)
        return;
      final data = Map<String, dynamic>.from(asJsonMap(result['data']));
      if (_accountEntryTabId == _activeTab) {
        _accountEntryTabId = null;
        final account = asJsonMap(data['account']);
        final profile = widget.homeUrl.resolve(
          account['profileUrl']?.toString() ?? '',
        );
        if (account['status'] == 'signedIn' &&
            _isFirstParty(profile) &&
            RegExp(r'^/user/\d+/?$').hasMatch(profile.path)) {
          await _load(profile, rememberHistory: false);
        } else if (account['status'] == 'signedOut') {
          final tab = widget.tabs
              .where((tab) => tab.id == _activeTab && tab.mode == 'account')
              .firstOrNull;
          if (tab != null) await _load(tab.url, rememberHistory: false);
        } else {
          _showLoadError(
            reason: 'account-identity-unconfirmed',
            path: uri.path,
          );
        }
        return;
      }
      if (widget.nativeAuth &&
          const {'/login', '/register'}.contains(uri.path) &&
          asJsonMap(data['auth'])['supported'] != true &&
          asJsonMap(data['account'])['status'] != 'signedIn') {
        _authForm = asJsonMap(data['auth']);
        if (_authForm['reason'] == 'verification') {
          // Human verification belongs to the same real site document.
          setState(() {
            _websiteVisible = true;
            _busy = false;
          });
        } else {
          // Missing adaptation is not proof that native UI is impossible.
          // Keep native recovery and let the user explicitly open the site.
          _showLoadError(reason: 'unsupported-auth-form', path: uri.path);
        }
        return;
      }
      if (_loginReturnUrl != null &&
          !_catalogWebsite &&
          asJsonMap(data['account'])['status'] == 'signedIn') {
        var resume = _loginReturnUrl!;
        if (const {'/login', '/register'}.contains(resume.path)) {
          final profile = Uri.tryParse(
            asJsonMap(data['account'])['profileUrl']?.toString() ?? '',
          );
          resume = profile != null && _hasNativePage(profile)
              ? profile
              : widget.homeUrl;
        }
        _loginReturnUrl = null;
        _authSubmissionStarted = false;
        await _load(
          resume,
          rememberHistory: false,
          preserveWatchOrigin: resume.path == '/watch',
        );
        return;
      }
      final responseOwner = _catalogOwner(data);
      final pageOwner = _personalRoot(uri);
      final privateList = _recordPrivacyPage(uri) && pageOwner != null;
      if (privateList && responseOwner != pageOwner) {
        data['sections'] = const [];
        data['videos'] = const [];
        data['paging'] = const {};
      }
      final key = _catalogKey(uri);
      if (_documentCacheGeneration == _catalogCache.generation &&
          !authentication &&
          (!_recordPrivacyPage(uri) ||
              responseOwner != null &&
                  responseOwner == _ownIdentityRoot &&
                  (pageOwner == null || responseOwner == pageOwner))) {
        _catalogCache[key] = data;
      }
      setState(() {
        if (_refreshingCatalog) _catalogImageRefresh = Object();
        _applyCatalog(data);
      });
      final owner = _ownIdentityRoot;
      if (_personalSnapshotAllowed(uri, owner) &&
          _currentAccountDocument &&
          responseOwner == owner) {
        unawaited(
          _personalSnapshots
              .write(
                VideoPersonalSnapshotStore.scope(widget.source, owner!, uri),
                data,
                _documentPersonalCacheGeneration,
              )
              .catchError((Object _) {}),
        );
      }
      _personalContinuationTarget = null;
      _personalContinuationFailed = false;
      _recordCatalogFrame('fresh-frame-ready');
    } catch (error) {
      if (!mounted ||
          epoch != _loadEpoch ||
          accountGeneration != _accountGeneration)
        return;
      if (_verificationVisible) {
        setState(() {
          _verificationStalled = true;
          _busy = false;
        });
        return;
      }
      // Verification can begin between readiness detection and extraction.
      // Reclassify that document before showing a parser/network error.
      try {
        final state = await _readSiteState();
        if (!mounted || epoch != _loadEpoch) return;
        if (videoSiteDocumentMatches(uri, state.url) && state.challenge) {
          _showVerification(epoch);
          return;
        }
        if (uri.path == '/search' &&
            videoSiteDocumentMatches(uri, state.url) &&
            !state.nativeReady) {
          // Results can become busy between observation and extraction. Keep
          // the existing bounded document deadline instead of showing empty
          // content or a premature parser error for that transient state.
          _startLoadWatchdog(uri);
          return;
        }
      } catch (_) {}
      if (!mounted || epoch != _loadEpoch) return;
      final diagnostic = await _safeDiagnostic(uri, error);
      if (!mounted || epoch != _loadEpoch) return;
      // The catalog plugin parses a captured DOM; its deadline is not proof
      // of a failed network GET. Keep parser failures out of transport retries.
      _showLoadError(reason: 'parser-failed', path: uri.path);
      setState(() => _diagnostic = diagnostic);
    } finally {
      if (_parsingEpoch == epoch) _parsingEpoch = null;
      // A popped detail first restores _requestedUrl to its source above.
      // Only now can an evicted data document resume without opening another
      // detail route or stealing a still-running playback-document refresh.
      if (_browserNeedsRecovery &&
          mounted &&
          ModalRoute.of(context)?.isActive == true) {
        unawaited(_recoverBrowserDocument());
      }
    }
  }

  bool _authenticationReady(VideoSiteState state) =>
      !_catalogWebsite &&
      widget.nativeAuth &&
      _authSubmissionStarted &&
      _loginReturnUrl != null &&
      !state.challenge &&
      state.websiteReady;

  void _applyCatalog(Map<String, dynamic> data) {
    _readRecovery.succeeded();
    _completeAutomaticRead();
    if (widget.searchFilters case final base?) {
      final observed = VideoFilterSchema.fromWire(
        asJsonMap(data['searchFilters']),
      );
      _siteFilters = (_siteFilters ?? base).merge(observed);
      if (observed.tagGroups.isNotEmpty) {
        _observedTagGroups = observed.tagGroups;
      }
    }
    final siteCategories = <NativeCatalogCategory>[];
    for (final item in asJsonList(data['categories']).take(30)) {
      final entry = asJsonMap(item);
      final title = entry['title']?.toString().trim() ?? '';
      final url = Uri.tryParse(entry['url']?.toString() ?? '');
      if (title.isNotEmpty &&
          title.length <= 30 &&
          _isFirstParty(url) &&
          url?.path == '/search' &&
          url?.queryParameters['genre']?.isNotEmpty == true) {
        siteCategories.add(NativeCatalogCategory(title: title, url: url!));
      }
    }
    _sections = asJsonList(data['sections']).map(asJsonMap).toList();
    _videos = asJsonList(data['videos']).map(asJsonMap).toList();
    _siteCategories = siteCategories;
    _paging = asJsonMap(data['paging']);
    _profile = asJsonMap(data['account']);
    _publicProfile = asJsonMap(data['publicProfile']);
    if (_creatorContext case final creator?) {
      final pages = <String, Uri>{};
      for (final raw in asJsonList(_publicProfile['links'])) {
        final link = asJsonMap(raw);
        final target = Uri.tryParse(link['url']?.toString() ?? '');
        if (target != null) {
          pages[link['title']?.toString() ?? target.path] = target;
        }
      }
      _creatorContext = (
        name: creator.name,
        url: creator.url,
        reference: creator.reference.withPages(pages),
      );
    }
    _authForm = asJsonMap(data['auth']);
    _playlistEditor = asJsonMap(data['playlistEditor']);
    if (_authForm['failed'] == true) _authSubmissionStarted = false;
    _authRevision++;
    _creators = asJsonList(data['creators']).map(asJsonMap).toList();
    _creatorGroups = asJsonList(data['creatorGroups']).map(asJsonMap).toList();
    if (_currentAccountDocument) _captureOwnIdentity();
    if (_personalSnapshotAllowed(_requestedUrl, _ownIdentityRoot) &&
        _profile['status'] == 'signedIn' &&
        _personalRoot(Uri.tryParse('${_profile['profileUrl'] ?? ''}')) ==
            _ownIdentityRoot) {
      _personalPageWindow.put(
        _personalPreferenceScope(_requestedUrl),
        _requestedUrl,
        data,
      );
      _videos = _personalPageWindow.videos;
      _paging = _personalPageWindow.paging;
    }
    _catalogTitle = data['title']?.toString() ?? '';
    _websiteVisible = false;
    _refreshingCatalog = false;
    _catalogRefreshFailed = false;
    _busy = false;
    _message = null;
  }

  bool _isAccountEdit(Uri uri) =>
      widget.nativeAccount &&
      widget.nativeAuth &&
      _isFirstParty(uri) &&
      RegExp(r'^/user/\d+/edit/?$').hasMatch(uri.path) &&
      !uri.hasQuery &&
      !uri.hasFragment;

  Future<bool> _allowLeaveAccount() async =>
      await _accountFormKey.currentState?.requestClose() ?? true;

  void _resetAccountTask() {
    _accountTaskUri = null;
    _accountTaskReady = false;
    _accountSubmissionStarted = false;
    _accountReadback = false;
    _accountOperation = null;
  }

  Future<void> _openAccountSettings() async {
    final root = _ownIdentityRoot;
    if (root == null) return;
    final target = Uri.tryParse(_ownIdentity['settingsUrl']?.toString() ?? '');
    if (target == null ||
        !_isAccountEdit(target) ||
        target.path != '${root.path}/edit') {
      return;
    }
    await _load(target);
  }

  Uri? _personalRoot(Uri? uri) {
    if (!_isFirstParty(uri)) return null;
    final match = RegExp(
      r'^/user/(\d+)(?:/(?:histories|saves|likes|playlists|uploaded|uploading))?/?$',
    ).firstMatch(uri!.path);
    return match == null ? null : widget.homeUrl.resolve('/user/${match[1]}');
  }

  void _captureOwnIdentity() {
    final observedOwner = _personalRoot(
      Uri.tryParse(_profile['profileUrl']?.toString() ?? ''),
    );
    if (_profile['status'] == 'signedIn' && observedOwner != null) {
      unawaited(_captureAccountSession());
      // Header identity is authoritative even while viewing someone else's profile.
      _bindCreatorOwner(observedOwner);
      _commentDrafts.bindOwner(observedOwner);
      if (_ownIdentityRoot != null && _ownIdentityRoot != observedOwner) {
        _ownIdentity = const {};
        _ownIdentityRoot = null;
        _personalStorage = PageStorageBucket();
      }
    }
    if (_profile['status'] == 'signedOut') {
      _bindCreatorOwner(null);
      if (_loginReturnUrl == null) _commentDrafts.clear();
      _ownIdentity = const {};
      _ownIdentityRoot = null;
      _personalStorage = PageStorageBucket();
      _personalPreferencesLoaded.clear();
      _personalQueries.clear();
      _personalKeywordScopes.clear();
      _personalSorts.clear();
      _personalFacets.clear();
      _personalViews.clear();
      _subscriptionStorage = PageStorageBucket();
      _invalidateCatalogCaches();
      return;
    }
    if (_profile['status'] != 'signedIn' || _profile['isOwnProfile'] != true) {
      return;
    }
    final root =
        _personalRoot(Uri.tryParse(_profile['profileUrl']?.toString() ?? '')) ??
        _personalRoot(_requestedUrl);
    if (root == null) return;
    _commentDrafts.bindOwner(root);
    if (_ownIdentityRoot != null && _ownIdentityRoot != root) {
      _ownIdentity = const {};
      _personalStorage = PageStorageBucket();
      _personalPreferencesLoaded.clear();
      _personalQueries.clear();
      _personalKeywordScopes.clear();
      _personalSorts.clear();
      _personalFacets.clear();
      _personalViews.clear();
      _subscriptionStorage = PageStorageBucket();
      _invalidateCatalogCaches();
    }
    _ownIdentityRoot = root;
    if (_creatorContext == null && _personalRoot(_requestedUrl) == root) {
      final accountTab = widget.tabs
          .where((tab) => tab.mode == 'account')
          .firstOrNull;
      if (accountTab != null) _activeTab = accountTab.id;
    }
    _ownIdentity = {
      ..._ownIdentity,
      'status': 'signedIn',
      'isOwnProfile': true,
      'profileUrl': root.toString(),
      for (final key in ['name', 'avatarUrl', 'summary'])
        if (_profile[key]?.toString().trim().isNotEmpty == true)
          key: _profile[key],
      if (asJsonList(_profile['links']).isNotEmpty) 'links': _profile['links'],
      if (_profile['settingsUrl'] is String)
        'settingsUrl': _profile['settingsUrl'],
    };
  }

  bool get _hasPersonalShell =>
      widget.nativeAccount &&
      _ownIdentity.isNotEmpty &&
      _personalRoot(_requestedUrl) == _ownIdentityRoot &&
      (_busy ||
          _siteLoadFailed ||
          _profile['status'] != 'signedIn' ||
          _profile['isOwnProfile'] != false);

  List<({String title, Uri url})> get _personalTabs {
    final seen = <String>{};
    return [
      for (final raw in asJsonList(_ownIdentity['links']))
        if (asJsonMap(raw) case final link)
          if (Uri.tryParse(link['url']?.toString() ?? '') case final target?
              when _personalRoot(target) == _ownIdentityRoot &&
                  seen.add(target.path.replaceFirst(RegExp(r'/$'), '')) &&
                  (link['title']?.toString().trim().isNotEmpty ?? false))
            (title: link['title'].toString(), url: target),
    ];
  }

  Map<String, dynamic> get _personalDisplayAccount => {
    ..._ownIdentity,
    if (!_busy && !_siteLoadFailed && _profile['status'] != 'signedIn') ...{
      'status': 'unknown',
      'cachedIdentity': true,
    },
  };

  bool get _personalOverviewEnabled =>
      _hasPersonalShell && _personalTabs.isNotEmpty;
  bool get _inPersonalLibrary =>
      !_websiteVisible &&
      !_verificationVisible &&
      ((_personalOverviewEnabled &&
              _requestedUrl.path.replaceFirst(RegExp(r'/$'), '') !=
                  _ownIdentityRoot!.path.replaceFirst(RegExp(r'/$'), '')) ||
          _requestedUrl.path == '/playlist' &&
              _recordPrivacyPage(_requestedUrl));

  String _personalTabTitle(({String title, Uri url}) tab) =>
      switch (tab.url.path.split('/').last) {
        'histories' => t.videoPersonal.histories,
        'saves' => t.videoPersonal.watchLater,
        'likes' => t.videoPersonal.likes,
        'playlists' => t.videoPersonal.playlists,
        _ => tab.title,
      };

  Future<List<Map<String, dynamic>>?> _readCachedPersonalRecent(
    Uri page,
  ) async {
    final owner = _ownIdentityRoot, epoch = _loadEpoch;
    final generation = _accountGeneration;
    if (!_currentAccountDocument || !_personalSnapshotAllowed(page, owner)) {
      return null;
    }
    final scope = VideoPersonalSnapshotStore.scope(widget.source, owner!, page);
    final value =
        await _personalSnapshots.read(scope) ??
        await _personalSnapshots.read('$scope|preview');
    if (!mounted ||
        epoch != _loadEpoch ||
        generation != _accountGeneration ||
        owner != _ownIdentityRoot)
      return null;
    return value == null
        ? null
        : asJsonList(value['videos']).map(asJsonMap).take(4).toList();
  }

  Future<List<Map<String, dynamic>>> _readPersonalRecent(Uri history) async {
    final owner = _ownIdentityRoot;
    final epoch = _loadEpoch, cacheGeneration = _personalSnapshots.generation;
    final generation = _accountGeneration;
    bool current() =>
        mounted &&
        owner == _ownIdentityRoot &&
        epoch == _loadEpoch &&
        generation == _accountGeneration &&
        !_websiteVisible;
    if (!_currentAccountDocument ||
        owner == null ||
        !const [
          'histories',
          'saves',
          'likes',
          'playlists',
        ].any((kind) => history.path == '${owner.path}/$kind') ||
        !_isFirstParty(history) ||
        !_personalTabs.any((tab) => tab.url == history)) {
      throw StateError('History unavailable');
    }
    final key = _catalogKey(history);
    final full = _cachedCatalog(history);
    if (full != null && _catalogCache.isFresh(key)) {
      return asJsonList(full['videos'])
          .map(asJsonMap)
          .where((card) => card['watchUrl'] != null || card['pageUrl'] != null)
          .take(4)
          .toList();
    }
    final snapshotScope = VideoPersonalSnapshotStore.scope(
      widget.source,
      owner,
      history,
    );
    final persistent =
        await _personalSnapshots.read(snapshotScope) ??
        await _personalSnapshots.read('$snapshotScope|preview');
    if (!current()) throw const PluginSessionChanged();
    if (persistent != null && _personalSnapshots.fresh(persistent)) {
      return asJsonList(persistent['videos']).map(asJsonMap).take(4).toList();
    }
    final script = videoPersonalRecentScript(history, widget.selectors);
    final web = _web;
    if (web == null) throw StateError('WebView unavailable');
    final raw = await videoBrowserReadAsync(
      web,
      script,
    ).timeout(const Duration(seconds: 9));
    if (!current()) throw const PluginSessionChanged();
    final data = asJsonMap(raw is String ? jsonDecode(raw) : raw);
    if (data['status'] != 'ok') throw StateError('History unavailable');
    final parsed = await _callPlugin(widget.catalogFnPath, {
      'pageUrl': history.toString(),
      'snapshot': asJsonMap(data['snapshot']),
    });
    if (!current()) throw const PluginSessionChanged();
    final videos = asJsonList(asJsonMap(parsed['data'])['videos'])
        .map(asJsonMap)
        .where((card) => card['watchUrl'] != null || card['pageUrl'] != null)
        .take(4)
        .toList();
    _personalRecentCache[history] = (readAt: DateTime.now(), videos: videos);
    await _personalSnapshots.write('$snapshotScope|preview', {
      'videos': videos,
    }, cacheGeneration);
    if (!current()) throw const PluginSessionChanged();
    return videos;
  }

  Future<void> _loadMorePersonal({bool retry = false}) async {
    if (!mounted ||
        !_currentAccountDocument ||
        _documentLoading ||
        _busy ||
        _websiteVisible ||
        (_personalContinuationTarget != null && !retry) ||
        (_personalContinuationFailed && !retry))
      return;
    final owner = _ownIdentityRoot, scope = _personalScope(_requestedUrl);
    final next = _searchPage(_paging['nextUrl']);
    if (owner == null ||
        next == null ||
        _personalScope(next) != scope ||
        !_personalSnapshotAllowed(next, owner) ||
        _personalPageWindow.contains(next))
      return;
    setState(() {
      _personalContinuationTarget = next;
      _personalContinuationFailed = false;
    });
    await _load(next, rememberHistory: false, reuseFresh: true);
  }

  bool _personalSnapshotAllowed(Uri page, Uri? owner) =>
      owner != null &&
      _creatorDirectoryOwner == owner &&
      _isFirstParty(page) &&
      (_personalRoot(page) == owner &&
              RegExp(
                r'/(histories|saves|likes|playlists)/?$',
              ).hasMatch(page.path) ||
          page.path == '/playlist' && _recordPrivacyPage(page));

  String _personalPreferenceScope(Uri page) => VideoPersonalSnapshotStore.scope(
    widget.source,
    _ownIdentityRoot ?? _personalRoot(page) ?? widget.homeUrl,
    _personalScope(page),
  );

  Future<void> _readPersonalPreferences(Uri page) async {
    final scope = _personalScope(page), key = _personalPreferenceScope(page);
    if (!_personalPreferencesLoaded.add(key)) return;
    final owner = _ownIdentityRoot;
    final generation = _accountGeneration;
    final values = await VideoPersonalPreferences.read(key);
    final view = await CollectionViewPreferences.read(key);
    if (!mounted ||
        owner != _ownIdentityRoot ||
        generation != _accountGeneration)
      return;
    _personalViews[scope] = view ?? 'grid';
    _personalQueries[scope] = values['query'] is String
        ? values['query'] as String
        : '';
    _personalKeywordScopes[scope] =
        parseKeywordSearchScope(values['keywordScope']) ??
        KeywordSearchScope.all;
    _personalSorts[scope] = values['sort'] == 'title' ? 'title' : 'source';
    final facets = asJsonMap(values['facets']);
    _personalFacets[scope] = ShelfFacetSelection(
      values: {
        for (final entry in facets.entries)
          if (shelfFacetDimensions.contains(entry.key) && entry.value is List)
            entry.key: (entry.value as List).whereType<String>().toSet(),
      },
    );
  }

  void _savePersonalPreferences(Uri page) {
    final scope = _personalScope(page), key = _personalPreferenceScope(page);
    unawaited(
      VideoPersonalPreferences.write(key, {
        'query': _personalQueries[scope] ?? '',
        'keywordScope':
            (_personalKeywordScopes[scope] ?? KeywordSearchScope.all).name,
        'sort': _personalSorts[scope] ?? 'source',
        'facets': {
          for (final entry
              in (_personalFacets[scope]?.values ?? <String, Set<String>>{})
                  .entries)
            entry.key: entry.value.toList(),
        },
      }).catchError((Object _) {
        if (mounted) showErrorToast(t.videoLibrary.saveFailed);
      }),
    );
  }

  Uri _personalScope(Uri page) => page.replace(
    queryParameters: page.path == '/playlist'
        ? {'list': page.queryParameters['list'] ?? ''}
        : const <String, String>{},
    fragment: '',
  );
  ShelfFacetEntry _personalFacet(Map<String, dynamic> row) {
    Set<String> values(Object? raw) => raw is Iterable
        ? raw
              .whereType<String>()
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toSet()
        : raw is String && raw.trim().isNotEmpty
        ? {raw.trim()}
        : <String>{};
    final fields = <String, Set<String>>{
      'tags': {...values(row['tags']), ...values(row['genres'])},
      'category': values(row['category']),
      'author': values(row['creatorName']),
      'year': values(row['year']),
      'area': values(row['area']),
      'language': values(row['language']),
    }..removeWhere((_, values) => values.isEmpty);
    return ShelfFacetEntry(
      key: '${row['watchUrl'] ?? row['pageUrl'] ?? ''}',
      source: widget.source,
      searchText:
          '${row['title'] ?? ''} ${row['subtitle'] ?? ''} ${fields.values.expand((v) => v).join(' ')}',
      fields: fields,
    );
  }

  List<Map<String, dynamic>> _personalFiltered(
    List<Map<String, dynamic>> rows,
    Uri page,
  ) {
    final scope = _personalScope(page),
        query = normalizePublicSearchText(
          _personalQueries[_personalScope(page)] ?? '',
        );
    final facets = _personalFacets[scope] ?? const ShelfFacetSelection();
    final searchAll = _personalKeywordScopes[scope] != KeywordSearchScope.title;
    final result = rows.where((row) {
      final entry = _personalFacet(row);
      return (query.isEmpty ||
              normalizePublicSearchText(
                searchAll ? entry.searchText : '${row['title'] ?? ''}',
              ).contains(query)) &&
          shelfFacetMatches(entry, facets, currentFolder: null);
    }).toList();
    if (_personalSorts[scope] == 'title') {
      result.sort(
        (a, b) => '${a['title'] ?? ''}'.compareTo('${b['title'] ?? ''}'),
      );
    }
    return result;
  }

  Future<void> _personalFilter(
    List<Map<String, dynamic>> rows,
    Uri page,
  ) async {
    if (_personalFilterOpen) return;
    _personalFilterOpen = true;
    _personalSearchFocus.unfocus();
    final scope = _personalScope(page), owner = _ownIdentityRoot;
    try {
      final selected = await showShelfFilterSheet(
        context,
        entries: rows.map(_personalFacet).toList(),
        initial: _personalFacets[scope] ?? const ShelfFacetSelection(),
        preferenceKey: _personalPreferenceScope(page),
        scopeLabel: t.videoLibrary.localCatalogSearchHint,
        currentFolder: null,
        hierarchical: false,
        focusedLayout: true,
      );
      if (!mounted ||
          owner != _ownIdentityRoot ||
          scope != _personalScope(_requestedUrl) ||
          selected == null) {
        return;
      }
      setState(() => _personalFacets[scope] = selected);
      _savePersonalPreferences(page);
    } finally {
      _personalFilterOpen = false;
    }
  }

  void _togglePersonalView(Uri page) {
    final scope = _personalScope(page), owner = _ownIdentityRoot;
    if (scope != _personalScope(_requestedUrl)) return;
    final old = _personalViews[scope] ?? 'grid';
    final next = old == 'list' ? 'grid' : 'list';
    _personalSearchFocus.unfocus();
    setState(() => _personalViews[scope] = next);
    unawaited(
      CollectionViewPreferences.write(
        _personalPreferenceScope(page),
        next,
      ).catchError((Object _) {
        if (mounted &&
            owner == _ownIdentityRoot &&
            _personalViews[scope] == next) {
          setState(() => _personalViews[scope] = old);
          showErrorToast(t.videoLibrary.saveFailed);
        }
      }),
    );
  }

  PreferredSizeWidget _personalListAppBar() {
    final scope = _personalScope(_requestedUrl);
    final title =
        _personalTabs
            .where((tab) => tab.url.path == _requestedUrl.path)
            .map(_personalTabTitle)
            .firstOrNull ??
        (_catalogTitle.isNotEmpty ? _catalogTitle : t.videoPersonal.playlists);
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: SourceVideoListHeader(
        keyPrefix: 'personal-records',
        leading: SourceBackButton(onPressed: () => unawaited(_goBackInside())),
        title: title,
        searching: _personalSearching,
        searchScope: KeywordScopeMenu(
          scope: _personalKeywordScopes[scope] ?? KeywordSearchScope.all,
          compact: true,
          onChanged: (value) {
            if (!mounted || scope != _personalScope(_requestedUrl)) return;
            setState(() => _personalKeywordScopes[scope] = value);
            _savePersonalPreferences(_requestedUrl);
          },
        ),
        searchField: SearchQueryField(
          query: _personalQueries[scope] ?? '',
          inline: true,
          focusNode: _personalSearchFocus,
          closeOnSubmit: false,
          hintText: t.videoLibrary.localCatalogSearchHint,
          onChanged: (value) {
            setState(() => _personalQueries[scope] = value);
            _savePersonalPreferences(_requestedUrl);
          },
        ),
        onSearch: () {
          setState(() => _personalSearching = !_personalSearching);
          if (_personalSearching) {
            requestSearchKeyboard(
              _personalSearchFocus,
              isCurrent: () =>
                  mounted &&
                  _inPersonalLibrary &&
                  _personalSearching &&
                  scope == _personalScope(_requestedUrl),
            );
          } else {
            _personalSearchFocus.unfocus();
          }
        },
        options: {
          'refresh': t.common.refresh,
          if (widget.nativeSiteActions && _playlistEditor['supported'] == true)
            'playlist-edit': t.videoCommunity.editPlaylist,
          'website': t.videoPlayback.backToWeb,
        },
        onMore: (action) {
          _personalSearchFocus.unfocus();
          if (action == 'refresh') {
            _personalPageWindow.clear();
            unawaited(
              _load(_personalScope(_requestedUrl), rememberHistory: false),
            );
          } else if (action == 'playlist-edit') {
            unawaited(_editPlaylist());
          } else if (action == 'website') {
            unawaited(
              _openWebsitePage(_requestedUrl, fallback: true, userChoice: true),
            );
          }
        },
      ),
    );
  }

  bool _recordPrivacyPage(Uri page) =>
      _isFirstParty(page) &&
      (RegExp(
            r'^/user/[0-9]+/(?:histories|saves|likes|playlists)/?$',
          ).hasMatch(page.path) ||
          page.path == '/playlist' &&
              (page.queryParameters['list']?.isNotEmpty ?? false));

  Widget _catalogBody() => _recordPrivacyPage(_requestedUrl)
      ? CollectionCoverPrivacyScope(child: _catalogBodyContent())
      : _catalogBodyContent();

  Widget _catalogBodyContent() {
    if (_recoveryPage case final page?) {
      if (!_recoveryReady) {
        return const Center(child: CircularProgressIndicator());
      }
      return NativeVideoPasswordRecoveryForm(
        key: ValueKey('recovery.${page.path}'),
        revision: _recoveryRevision,
        read: () async {
          if (_documentLoading ||
              _verificationVisible ||
              !_isFirstParty(_requestedUrl) ||
              !const {
                '/password/reset',
                '/password/email',
              }.contains(_requestedUrl.path)) {
            return {'supported': false};
          }
          final raw = await _evaluate(videoRecoveryMetadataScript);
          final decoded = raw is String ? jsonDecode(raw) : raw;
          return decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : {'supported': false};
        },
        submit: (email) async {
          if (_documentLoading ||
              _verificationVisible ||
              !_isFirstParty(_requestedUrl) ||
              !const {
                '/password/reset',
                '/password/email',
              }.contains(_requestedUrl.path)) {
            return 'changed';
          }
          _recoverySubmissionStarted = true;
          final raw = await _evaluate(
            videoRecoverySubmitScript(page: _requestedUrl, email: email),
          );
          if (raw != 'submitted') _recoverySubmissionStarted = false;
          return raw?.toString() ?? 'changed';
        },
        onLogin: () => unawaited(_load(widget.homeUrl.resolve('/login'))),
        onWebsite: () =>
            unawaited(_openWebsitePage(page, fallback: true, userChoice: true)),
      );
    }
    if (_accountTaskUri case final page?) {
      if (!_accountTaskReady) {
        return const Center(child: CircularProgressIndicator());
      }
      final form = NativeVideoAccountForm(
        key: _accountFormKey,
        page: page,
        revision: _accountRevision,
        readback: _accountReadback,
        submitting: _accountSubmissionStarted && _documentLoading,
        read: () async {
          if (!videoSiteDocumentMatches(page, _requestedUrl) ||
              _documentLoading ||
              _verificationVisible) {
            return {'supported': false};
          }
          final raw = await _evaluate(videoAccountReadScript(page));
          final decoded = raw is String ? jsonDecode(raw) : raw;
          return decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : {'supported': false};
        },
        submit: (operation, values) async {
          if (!videoSiteDocumentMatches(page, _requestedUrl) ||
              _documentLoading ||
              _verificationVisible) {
            return 'changed';
          }
          final navigation = !const {
            'requestOtp',
            'verifyOtp',
          }.contains(operation);
          if (navigation) {
            _accountSubmissionStarted = true;
            _accountOperation = operation;
            _accountReadback = false;
            _invalidateCatalogCaches();
          }
          final raw = await _evaluate(
            videoAccountSubmitScript(
              page: page,
              operation: operation,
              values: values,
            ),
          );
          if (raw != 'submitted' && navigation) {
            _accountSubmissionStarted = false;
          }
          return raw?.toString() ?? 'changed';
        },
        onRefresh: () {
          _accountReadback = _accountOperation != null;
          unawaited(
            _load(page, rememberHistory: false, preserveAccountTask: true),
          );
        },
        onWebsite: () =>
            unawaited(_openWebsitePage(page, fallback: true, userChoice: true)),
      );
      final accountVisible = videoSiteDocumentMatches(page, _requestedUrl);
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: !accountVisible, child: form),
          if (!accountVisible) _nativeContent(),
        ],
      );
    }
    Widget content({bool personal = false}) => VideoContentTransition(
      ready: !_busy,
      revision: _loadEpoch,
      enabled: _animateCatalogArrival,
      child: PageImageRefreshScope(
        revision: _catalogImageRefresh,
        child: _nativeContent(contentOnly: personal),
      ),
    );
    if (_hasPersonalShell) {
      return PageStorage(
        bucket: _personalStorage,
        child: VideoPersonalShell(
          showTabs: false,
          key: ValueKey(_ownIdentityRoot),
          account: _personalDisplayAccount,
          page: _ownIdentityRoot!,
          current: _requestedUrl,
          tabs: [
            for (final tab in _personalTabs)
              (title: _personalTabTitle(tab), url: tab.url),
          ],
          overview: !_personalOverviewEnabled
              ? null
              : VideoPersonalOverview(
                  account: _personalDisplayAccount,
                  page: _ownIdentityRoot!,
                  tabs: _personalTabs,
                  onTab: (target) => unawaited(
                    _load(target, rememberHistory: false, reuseFresh: true),
                  ),
                  onVideo: (target) => unawaited(_load(target)),
                  onAccountSettings: _ownIdentity['settingsUrl'] is String
                      ? () => unawaited(_openAccountSettings())
                      : null,
                  showPrivacyAction: false,
                  localRecords: SourceProfileLocalVideoPreviews(
                    source: widget.source,
                    readDownloads: widget.readLocalDownloads,
                    active:
                        !_websiteVisible &&
                        ModalRoute.of(context)?.isCurrent != false,
                    responsivePreview: true,
                    groupDownloads: true,
                    showPrivacyAction: false,
                    onHistory: () => unawaited(_showPersonal()),
                  ),
                  readRecent: _readPersonalRecent,
                  readCached: _readCachedPersonalRecent,
                  readReady: !_documentLoading && !_busy,
                ),
          onTab: (target) {
            if (target.path != _requestedUrl.path) {
              unawaited(
                _load(target, rememberHistory: false, reuseFresh: true),
              );
            }
          },
          onOpenSite: () => _openWebsitePage(
            _ownIdentityRoot!,
            fallback: true,
            userChoice: true,
          ),
          onAccountSettings: _ownIdentity['settingsUrl'] is String
              ? () => unawaited(_openAccountSettings())
              : null,
          child: content(personal: true),
        ),
      );
    }
    if (widget.nativeSubscriptions && _requestedUrl.path == '/subscriptions') {
      return PageStorage(
        key: ValueKey(_subscriptionStorage),
        bucket: _subscriptionStorage,
        child: content(),
      );
    }
    return content();
  }

  Widget _personalContentError() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.wifi_off_rounded, size: 36),
      const SizedBox(height: 12),
      Text(t.videoCommunity.network, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          TextButton.icon(
            onPressed: () => _load(_requestedUrl, rememberHistory: false),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.common.retry),
          ),
          TextButton.icon(
            onPressed: () => _openWebsitePage(
              _requestedUrl,
              fallback: true,
              userChoice: true,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(t.videoPlayback.backToWeb),
          ),
        ],
      ),
    ],
  );

  List<Map<String, dynamic>> _subscriptionGroups(
    List<Map<String, dynamic>> groups,
    List<Map<String, dynamic>> creators,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final raw in [
      ...groups.take(500),
      ...creators.take(500).map((creator) => {'creator': creator}),
    ]) {
      final wire = asJsonMap(raw['creator']);
      final initial = VideoCreatorReference.fromWire(wire, widget.homeUrl);
      if (initial == null || initial.entityKey.isEmpty) continue;
      final creator = _knownCreator(initial);
      final group = result.putIfAbsent(
        creator.entityKey,
        () => {
          'creator': {...wire, ..._creatorWire(creator)},
          'videos': <Map<String, dynamic>>[],
        },
      );
      final cards = group['videos'] as List<Map<String, dynamic>>;
      final seen = cards.map((card) => card['watchUrl']).toSet();
      for (final card in asJsonList(raw['videos']).take(160).map(asJsonMap)) {
        final watch = Uri.tryParse(card['watchUrl']?.toString() ?? '');
        if (_isFirstParty(watch) &&
            watch!.path == '/watch' &&
            RegExp(r'^\d+$').hasMatch(watch.queryParameters['v'] ?? '') &&
            seen.add(watch.toString())) {
          cards.add(card);
        }
      }
    }
    return result.values.take(500).toList();
  }

  Widget _subscriptionUpdates(List<Map<String, dynamic>> cards) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t.videoCommunity.unassignedSubscriptionUpdates,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = videoShelfCardWidth(context, constraints.maxWidth);
          return SizedBox(
            height: _cardExtent(
              width,
              statistics: cards.any(
                (card) => VideoPublicMetadata.fromWire(card).hasCardStatistics,
              ),
            ),
            child: ListView.separated(
              key: const PageStorageKey('subscription.updates'),
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) =>
                  SizedBox(width: width, child: _videoCard(cards[index])),
            ),
          );
        },
      ),
      const SizedBox(height: 24),
    ],
  );

  void _recordCatalogFrame(String event) {
    final epoch = _loadEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          epoch == _loadEpoch &&
          !_busy &&
          !_websiteVisible &&
          !_verificationVisible &&
          !_personalVisible) {
        _browserDiagnostics.catalog(event);
      }
    });
  }

  Future<void> _updateWebsitePresentation() async {
    // Presentation only, on a verified site document. The original nodes can
    // be restored; verification, login forms and media are never filtered.
    try {
      await _evaluate(
        videoSitePresentationScript(
          hideAdvertisements: _sourceOptions.hideAdvertisements,
        ),
      );
    } catch (_) {
      // A site redesign must not prevent the website fallback from opening.
    }
  }

  TextStyle get _cardTitleStyle =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(height: 1.4);

  TextStyle get _cardSubtitleStyle =>
      (Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  double _cardExtent(
    double width, {
    bool subtitle = true,
    bool statistics = false,
    bool portrait = false,
  }) {
    double lineHeight(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag国', style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // Keep both title lines and the author at the user's chosen text scale.
    // Fixed card aspect ratios clip metadata when accessibility text grows.
    return (portrait ? width * 3 / 2 : width * 9 / 16) +
        6 +
        lineHeight(_cardTitleStyle) * 2 +
        ((subtitle ? 1 : 0) + (statistics ? 1 : 0)) *
            lineHeight(_cardSubtitleStyle) +
        4;
  }

  Widget _videoCard(
    Map<String, dynamic> card, {
    bool showSubtitle = true,
    bool portrait = false,
  }) {
    final title = card['title']?.toString() ?? '';
    final cover = card['coverUrl']?.toString() ?? '';
    final metadata = VideoPublicMetadata.fromWire(card);
    final watchUrl = Uri.tryParse(
      (card['watchUrl'] ?? card['pageUrl'])?.toString() ?? '',
    );
    return InkWell(
      onTap: !_isFirstParty(watchUrl)
          ? null
          : watchUrl!.path == '/search' ||
                RegExp(r'^/user/\d+/?$').hasMatch(watchUrl.path)
          ? () => _openCreator(watchUrl, title, raw: card)
          : () => _load(watchUrl),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: portrait ? 2 / 3 : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VideoCardCover(
                url: cover,
                referrer: watchUrl ?? widget.homeUrl,
                metadata: metadata,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _cardTitleStyle,
          ),
          VideoCardFacts(
            metadata: metadata,
            creator: card['creatorName']?.toString() ?? '',
            fallback: card['subtitle']?.toString() ?? '',
            showCreator: showSubtitle,
          ),
        ],
      ),
    );
  }

  Widget _nativeContent({
    Map<String, dynamic>? preview,
    Uri? page,
    bool contentOnly = false,
  }) {
    if (_siteLoadFailed && preview == null) {
      // A failed new destination must not expose the preceding home/profile
      // beneath the recovery layer, including through accessibility semantics.
      return contentOnly ? _personalContentError() : const SizedBox.shrink();
    }
    if (_busy &&
        preview == null &&
        !(widget.nativeAuth &&
            _authForm['supported'] == true &&
            _authForm['mode'] == _requestedUrl.path.substring(1))) {
      return const Center(child: CircularProgressIndicator());
    }
    if (preview == null &&
        widget.nativeAuth &&
        _authForm['supported'] == true &&
        const {'/login', '/register'}.contains(_requestedUrl.path)) {
      final authPage = _requestedUrl;
      return NativeVideoAuthForm(
        key: ValueKey('native-auth.${authPage.path}'),
        revision: _authRevision,
        loginUsername: _accountLoginUsername,
        credentials: _accountLoginUsername == null
            ? VideoAccountCredentials.load(widget.source, widget.homeUrl)
            : null,
        saveCredentials: (account, password) => VideoAccountCredentials.save(
          widget.source,
          widget.homeUrl,
          account,
          password,
        ),
        clearCredentials: () =>
            VideoAccountCredentials.clear(widget.source, widget.homeUrl),
        registration: authPage.path == '/register',
        hasRemember: _authForm['remember'] == true,
        onForgotPassword:
            _authForm['recoveryUrl'] is String &&
                _authForm['recoveryUrl'].toString().isNotEmpty
            ? () => unawaited(
                _load(
                  widget.homeUrl.resolve(_authForm['recoveryUrl'].toString()),
                ),
              )
            : null,
        onExternalAuthentication: _observedGoogleAuthenticationEntry == null
            ? null
            : () => unawaited(
                _continueExternalAuthentication(
                  _observedGoogleAuthenticationEntry!,
                ),
              ),
        siteRejected: _authForm['failed'] == true,
        siteErrorKind: _authForm['errorKind'] is String
            ? _authForm['errorKind'] as String
            : '',
        submit: (email, password, name, remember) async {
          if (!videoSiteDocumentMatches(authPage, _requestedUrl) ||
              _documentLoading ||
              _verificationVisible) {
            return 'changed';
          }
          _loginReturnUrl ??= authPage;
          final epoch = _loadEpoch;
          _authSubmissionStarted = true;
          _invalidateCatalogCaches();
          final raw = await _evaluate(
            videoAuthSubmitScript(
              page: authPage,
              email: email,
              password: password,
              name: name,
              remember: remember,
            ),
          );
          if (mounted && epoch == _loadEpoch && raw != 'submitted') {
            _authSubmissionStarted = false;
          }
          return raw?.toString() ?? 'changed';
        },
        onChangeMode: () => _load(
          widget.homeUrl.resolve(
            authPage.path == '/login' ? '/register' : '/login',
          ),
        ),
        onWebsite: () =>
            _openWebsitePage(authPage, fallback: true, userChoice: true),
      );
    }
    final sections = preview == null
        ? _sections
        : asJsonList(preview['sections']).map(asJsonMap).toList();
    final unfilteredVideos = preview == null
        ? _videos
        : asJsonList(preview['videos']).map(asJsonMap).toList();
    final paging = preview == null ? _paging : asJsonMap(preview['paging']);
    final account = preview == null ? _profile : asJsonMap(preview['account']);
    final publicProfile = preview == null
        ? _publicProfile
        : asJsonMap(preview['publicProfile']);
    final creators = preview == null
        ? _creators
        : asJsonList(preview['creators']).map(asJsonMap).toList();
    final profile = account['isOwnProfile'] != true && publicProfile.isNotEmpty
        ? publicProfile
        : account;
    final catalogTitle = preview == null
        ? _catalogTitle
        : preview['title']?.toString() ?? '';
    final currentPage = page ?? _requestedUrl;
    final recordCollection = _recordPrivacyPage(currentPage);
    final titleOnly = _keywordScopeFor(currentPage) == KeywordSearchScope.title;
    final exactTag = _exactKeywordTag(currentPage);
    final matchesTitle = titleOnly
        ? keywordTitleMatcher(currentPage.queryParameters['query'] ?? '')
        : null;
    final videos = recordCollection
        ? _personalFiltered(unfilteredVideos, currentPage)
        : matchesTitle != null
        ? unfilteredVideos
              .where(
                (row) => matchesTitle([
                  '${row['title'] ?? ''}',
                  if (row['alternateTitle'] is String)
                    row['alternateTitle'] as String,
                ]),
              )
              .toList()
        : unfilteredVideos;
    if (recordCollection) {
      final scope = _personalScope(currentPage);
      final items = <ApiVideoItem>[];
      for (final row in videos) {
        final target = Uri.tryParse(
          '${row['watchUrl'] ?? row['pageUrl'] ?? ''}',
        );
        if (!_isFirstParty(target)) continue;
        items.add(
          ApiVideoItem(
            id: target.toString(),
            title: '${row['title'] ?? ''}',
            detailUrl: target!,
            coverUrl: Uri.tryParse('${row['coverUrl'] ?? ''}'),
            description: '${row['creatorName'] ?? row['subtitle'] ?? ''}',
            sourceViews: VideoPublicMetadata.fromWire(row).viewCount,
            sourceDuration: VideoPublicMetadata.fromWire(row).duration ?? '',
            year: '${row['year'] ?? ''}',
            area: '${row['area'] ?? ''}',
            language: '${row['language'] ?? ''}',
            genres: (row['tags'] is List
                ? (row['tags'] as List).join(' / ')
                : '${row['tags'] ?? ''}'),
          ),
        );
      }
      return CollectionCoverPrivacyScope(
        child: ApiVideoCollection(
          key: PageStorageKey(
            'video-catalog.${Uri(scheme: currentPage.scheme, host: currentPage.host, path: currentPage.path, queryParameters: currentPage.path == '/playlist' ? {'list': currentPage.queryParameters['list'] ?? ''} : null)}',
          ),
          items: items,
          mode: _personalViews[scope] == 'list'
              ? ApiVideoView.list
              : ApiVideoView.grid,
          storageKey:
              'hanime-personal.${_personalPreferenceScope(currentPage)}',
          gridColumns: 3,
          posterAspectRatio: 2 / 3,
          onOpen: (item) => unawaited(_load(item.detailUrl)),
          onNearEnd: () => unawaited(_loadMorePersonal()),
          header: SourceVideoResultsToolbar(
            keyPrefix: 'personal-records',
            count: _searchPage(paging['nextUrl']) == null
                ? t.videoLibrary.results(count: videos.length)
                : t.videoLibrary.localCatalogUnknownTotal(
                    loaded: unfilteredVideos.length,
                    shown: videos.length,
                  ),
            sort: _personalSorts[scope] ?? 'source',
            sortOptions: {
              'source': t.videoSource.sourceOrder,
              'title': t.videoLibrary.titleOrder,
            },
            onSort: (value) {
              if (!mounted || scope != _personalScope(_requestedUrl)) return;
              _personalSearchFocus.unfocus();
              setState(() => _personalSorts[scope] = value);
              _savePersonalPreferences(currentPage);
            },
            gridView: _personalViews[scope] != 'list',
            onToggleView: () => _togglePersonalView(currentPage),
            filter: SourceFilterIconButton(
              key: const ValueKey('personal-records.filter'),
              bare: false,
              tooltip: (_personalFacets[scope]?.isActive ?? false)
                  ? t.videoFilters.active
                  : t.videoFilters.title,
              active: _personalFacets[scope]?.isActive ?? false,
              onPressed: _personalFilterOpen
                  ? null
                  : () => _personalFilter(unfilteredVideos, currentPage),
            ),
          ),
          emptyState: Center(
            child: Text(
              contentOnly
                  ? t.videoLibrary.noResults
                  : switch (account['status']) {
                      'signedOut' => t.videoCommunity.loginRequired,
                      'unknown' => t.videoPlayback.accountUnconfirmed,
                      _ => t.videoLibrary.noResults,
                    },
            ),
          ),
          footer: _searchPage(paging['nextUrl']) == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _documentLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TextButton.icon(
                          key: const ValueKey('personal-records.load-more'),
                          onPressed: () =>
                              unawaited(_loadMorePersonal(retry: true)),
                          icon: Icon(
                            _personalContinuationFailed
                                ? Icons.refresh_rounded
                                : Icons.expand_more_rounded,
                          ),
                          label: Text(
                            _personalContinuationFailed
                                ? t.common.retry
                                : t.videoLibrary.continueCatalogSearch,
                          ),
                        ),
                ),
        ),
      );
    }
    final personal =
        widget.nativeAccount &&
        (currentPage.path == '/login' || currentPage.path.startsWith('/user/'));
    final subscriptions =
        widget.nativeSubscriptions && currentPage.path == '/subscriptions';
    final groups = subscriptions
        ? _subscriptionGroups(
            preview == null
                ? _creatorGroups
                : asJsonList(preview['creatorGroups']).map(asJsonMap).toList(),
            creators,
          )
        : const <Map<String, dynamic>>[];
    final groupedVideos = {
      for (final group in groups)
        for (final card in asJsonList(group['videos']))
          asJsonMap(card)['watchUrl'],
    };
    final unassignedVideos = subscriptions
        ? videos
              .where((card) => !groupedVideos.contains(card['watchUrl']))
              .toList()
        : const <Map<String, dynamic>>[];
    final profileRoot =
        currentPage.path == '/login' ||
        RegExp(r'^/user/\d+/?$').hasMatch(currentPage.path);
    final activeCategory = _categories
        .where((item) => _categorySelected(item.url, page: page))
        .firstOrNull;
    return CollectionCoverPrivacyScope(
      enabled: _recordPrivacyPage(currentPage),
      child: CustomScrollView(
        key: PageStorageKey('video-catalog.${page ?? _requestedUrl}'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverList.list(
                  children: [
                    if (!contentOnly &&
                        profile.isNotEmpty &&
                        (personal || subscriptions))
                      VideoProfileHeader(
                        account: profile,
                        page: currentPage,
                        personal: personal,
                        onOpenSite: () {
                          final login =
                              profile['status'] != 'signedIn' &&
                              profile['status'] != 'profile';
                          if (login && currentPage.path != '/login') {
                            _loginReturnUrl = currentPage;
                          }
                          unawaited(
                            (login && widget.nativeAuth
                                ? _load
                                : (Uri uri) => _openWebsitePage(
                                    uri,
                                    fallback: true,
                                    userChoice: !login,
                                  ))(
                              login
                                  ? widget.homeUrl.resolve('/login')
                                  : currentPage,
                            ),
                          );
                        },
                        onRegister:
                            widget.nativeAuth && profile['status'] != 'signedIn'
                            ? () => _load(widget.homeUrl.resolve('/register'))
                            : null,
                      ),
                    if (!contentOnly &&
                        personal &&
                        asJsonList(profile['links']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final raw in asJsonList(profile['links']))
                                if (Uri.tryParse(
                                      asJsonMap(raw)['url']?.toString() ?? '',
                                    )
                                    case final target?
                                    when _hasNativePage(target) &&
                                        target.path.startsWith('/user/'))
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: ChoiceChip(
                                      selected:
                                          currentPage.path.replaceFirst(
                                            RegExp(r'/$'),
                                            '',
                                          ) ==
                                          target.path.replaceFirst(
                                            RegExp(r'/$'),
                                            '',
                                          ),
                                      label: Text(
                                        asJsonMap(raw)['title']?.toString() ??
                                            '',
                                      ),
                                      onSelected: (_) => _load(target),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    if (subscriptions &&
                        preview == null &&
                        _creatorDirectoryFailed)
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.videoCommunity.followedCreators),
                          ),
                          TextButton(
                            onPressed: () {
                              unawaited(
                                _load(_requestedUrl, rememberHistory: false),
                              );
                            },
                            child: Text(t.common.retry),
                          ),
                        ],
                      ),
                    if (_refreshingCatalog && preview == null)
                      const LinearProgressIndicator(
                        key: ValueKey('catalog-background-refresh'),
                        minHeight: 2,
                      ),
                    if (_catalogRefreshFailed && preview == null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.videoPlayback.catalogRefreshFailed),
                          ),
                          TextButton(
                            onPressed: () =>
                                _load(_requestedUrl, rememberHistory: false),
                            child: Text(t.common.retry),
                          ),
                        ],
                      ),
                    if (exactTag != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: const ValueKey('video-search.exact-tag'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          icon: const Icon(Icons.sell_outlined, size: 18),
                          label: Text(
                            '${t.videoFilters.searchTags} · ${exactTag.label}',
                          ),
                          onPressed: preview != null
                              ? null
                              : () {
                                  if (_requestedUrl != currentPage || _busy)
                                    return;
                                  final filters =
                                      VideoSearchFilters.fromUri(
                                        currentPage,
                                      ).copyWith(
                                        query: '',
                                        tags: [exactTag.value],
                                        anyTag: false,
                                        page: 1,
                                      );
                                  unawaited(
                                    _load(filters.toUri(widget.homeUrl)),
                                  );
                                },
                        ),
                      ),
                    if (personal &&
                        (contentOnly || !profileRoot) &&
                        videos.isEmpty &&
                        sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(t.videoCommunity.emptyLibrary),
                        ),
                      ),
                    if (sections.isEmpty &&
                        videos.isEmpty &&
                        creators.isEmpty &&
                        groups.isEmpty &&
                        !personal &&
                        !(subscriptions &&
                            profile['status'] != 'signedIn')) ...[
                      const SizedBox(height: 72),
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          subscriptions
                              ? t.videoPlayback.subscriptionsEmpty
                              : titleOnly &&
                                    (unfilteredVideos.isNotEmpty ||
                                        _searchPage(paging['nextUrl']) != null)
                              ? t.videoLibrary.filteredLoaded(
                                  loaded: unfilteredVideos.length,
                                  shown: 0,
                                )
                              : t.search.noResults,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _load(currentPage),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(t.common.retry),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subscriptions)
                  SliverList.builder(
                    itemCount: groups.length,
                    itemBuilder: (_, index) {
                      final group = groups[index];
                      final creator = asJsonMap(group['creator']);
                      return VideoCreatorShelf(
                        key: ValueKey(
                          '${widget.source}.$_creatorDirectoryOwner.${creator['entityKey']}',
                        ),
                        creator: creator,
                        videos: asJsonList(
                          group['videos'],
                        ).map(asJsonMap).toList(),
                        page: currentPage,
                        opening: _openingCreator == creator['entityKey'],
                        onOpenCreator: () {
                          final ref = VideoCreatorReference.fromWire(
                            creator,
                            widget.homeUrl,
                          );
                          final cards = asJsonList(group['videos']);
                          final watch = cards.isEmpty
                              ? null
                              : Uri.tryParse(
                                  asJsonMap(
                                        cards.first,
                                      )['watchUrl']?.toString() ??
                                      '',
                                );
                          if (ref != null) {
                            unawaited(
                              _openCreatorReference(
                                ref,
                                representativeWatch: watch,
                              ),
                            );
                          }
                        },
                        onOpenWorks: () {
                          final ref = VideoCreatorReference.fromWire(
                            creator,
                            widget.homeUrl,
                          );
                          if (ref != null) {
                            final cards = asJsonList(group['videos']);
                            final watch = cards.isEmpty
                                ? null
                                : Uri.tryParse(
                                    asJsonMap(
                                          cards.first,
                                        )['watchUrl']?.toString() ??
                                        '',
                                  );
                            unawaited(
                              _openCreatorReference(
                                ref,
                                works: true,
                                representativeWatch: watch,
                              ),
                            );
                          }
                        },
                        cardBuilder: (card) =>
                            _videoCard(card, showSubtitle: false),
                        cardExtent: (width) => _cardExtent(
                          width,
                          subtitle: asJsonList(group['videos'])
                              .map(asJsonMap)
                              .any(
                                (card) =>
                                    VideoPublicMetadata.fromWire(
                                      card,
                                    ).publishedRelative !=
                                    null,
                              ),
                          statistics: asJsonList(group['videos'])
                              .map(asJsonMap)
                              .any(
                                (card) => VideoPublicMetadata.fromWire(
                                  card,
                                ).hasCardStatistics,
                              ),
                        ),
                      );
                    },
                  ),
                if (subscriptions &&
                    (_creatorDirectory?['nextUrl']?.toString().isNotEmpty ??
                        false))
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _loadingMoreCreators
                            ? null
                            : _loadMoreCreators,
                        child: Text(t.videoCommunity.moreSubscribedCreators),
                      ),
                    ),
                  ),
                if (subscriptions && unassignedVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _subscriptionUpdates(unassignedVideos),
                  ),
                SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (_, index) {
                    final section = sections[index];
                    final cards = asJsonList(section['videos']);
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                section['title']?.toString() ?? '',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (Uri.tryParse(
                                  section['moreUrl']?.toString() ?? '',
                                )
                                case final more? when _isFirstParty(more))
                              TextButton(
                                onPressed: () => _load(more),
                                child: const Icon(Icons.chevron_right_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: _cardExtent(
                            180,
                            statistics: cards
                                .map(asJsonMap)
                                .any(
                                  (card) => VideoPublicMetadata.fromWire(
                                    card,
                                  ).hasCardStatistics,
                                ),
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: cards.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, index) => SizedBox(
                              width: 180,
                              child: _videoCard(asJsonMap(cards[index])),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
                if (preview == null &&
                    !_inPersonalLibrary &&
                    widget.nativeSiteActions &&
                    currentPage.path == '/playlist' &&
                    _playlistEditor['supported'] == true)
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _editPlaylist,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(t.videoCommunity.editPlaylist),
                      ),
                    ),
                  ),
                if (!contentOnly &&
                    !_inPersonalLibrary &&
                    !subscriptions &&
                    videos.isNotEmpty &&
                    sections.isEmpty)
                  SliverList.list(
                    children: [
                      Text(
                        catalogTitle.isNotEmpty
                            ? catalogTitle
                            : personal
                            ? t.videoPlayback.siteContents
                            : subscriptions
                            ? t.videoCommunity.subscriptionFeed
                            : activeCategory?.title ??
                                  t.videoPlayback.searchVideos,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                if (!subscriptions && videos.isNotEmpty && sections.isEmpty)
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const columns = 3;
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          mainAxisExtent: _cardExtent(
                            (constraints.crossAxisExtent - (columns - 1) * 12) /
                                columns,
                            portrait: recordCollection,
                            statistics: videos.any(
                              (card) => VideoPublicMetadata.fromWire(
                                card,
                              ).hasCardStatistics,
                            ),
                          ),
                        ),
                        itemCount: videos.length,
                        itemBuilder: (_, index) => _videoCard(
                          videos[index],
                          portrait: recordCollection,
                        ),
                      );
                    },
                  ),
                if (!contentOnly &&
                    personal &&
                    profileRoot &&
                    profile['status'] != 'profile')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: VideoAccountTools(
                        onSourceSettings: () => unawaited(_openSettings()),
                      ),
                    ),
                  ),
                if (paging.isNotEmpty &&
                    ((paging['totalPages'] as num? ?? 1) > 1 ||
                        titleOnly && _searchPage(paging['nextUrl']) != null))
                  SliverList.list(
                    children: [
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final previous = OutlinedButton(
                            onPressed:
                                _searchPage(paging['previousUrl']) == null
                                ? null
                                : () => _load(
                                    _searchPage(paging['previousUrl'])!,
                                  ),
                            child: Text(
                              t.common.previousPage,
                              textAlign: TextAlign.center,
                            ),
                          );
                          final next = OutlinedButton(
                            onPressed: _searchPage(paging['nextUrl']) == null
                                ? null
                                : () => _load(_searchPage(paging['nextUrl'])!),
                            child: Text(
                              t.common.nextPage,
                              textAlign: TextAlign.center,
                            ),
                          );
                          final counter = Text(
                            paging['totalPages'] is num
                                ? '${paging['page'] ?? 1} / ${paging['totalPages']}'
                                : t.searchResult.pageOnly(
                                    page:
                                        (paging['page'] as num?)?.toInt() ?? 1,
                                  ),
                          );
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          if (constraints.maxWidth < 360 * scale) {
                            return Column(
                              children: [
                                counter,
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: previous),
                                    const SizedBox(width: 12),
                                    Expanded(child: next),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [previous, counter, next],
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Uri? _searchPage(dynamic value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    if (uri == null || !_hasNativePage(uri) || uri.path == '/watch') {
      return null;
    }
    if (widget.searchFilters != null &&
        uri.path == '/search' &&
        _listUrl?.path == '/search') {
      final page = int.tryParse(uri.queryParameters['page'] ?? '1');
      if (page == null || page < 1 || page > 10000) return null;
      return VideoSearchFilters.fromUri(
        _listUrl!,
      ).toUri(widget.homeUrl, pageNumber: page);
    }
    return uri;
  }

  bool _categorySelected(Uri url, {Uri? page}) {
    final current = page ?? _listUrl ?? widget.homeUrl;
    final genre = url.queryParameters['genre'];
    if (genre == null) {
      return current.path == '/' ||
          (current.path == '/search' &&
              !current.queryParameters.containsKey('genre'));
    }
    if (current.path != '/search') return false;
    return current.queryParameters['genre'] == genre;
  }

  List<NativeCatalogCategory> get _categories {
    if (_siteCategories.isEmpty) return widget.categories;
    final result = <NativeCatalogCategory>[];
    final genres = <String>{};
    for (final category in [
      ...widget.categories.take(1),
      ..._siteCategories,
      ...widget.categories.skip(1),
    ]) {
      final genre = category.url.queryParameters['genre'] ?? '';
      if (genres.add(genre)) result.add(category);
    }
    return result;
  }

  Widget _categoryBar({Uri? page}) => widget.searchFilters != null
      ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: VideoSearchFilterBar(
                filters: VideoSearchFilters.fromUri(
                  page ?? _listUrl ?? widget.homeUrl,
                ),
                schema: _siteFilters ?? widget.searchFilters!,
                onOpen: (section) => unawaited(_openFilters(section)),
                onAll: () => unawaited(
                  _openFilters(VideoFilterSection.tags, advanced: true),
                ),
              ),
            ),
            VideoActiveFilters(
              filters: VideoSearchFilters.fromUri(
                page ?? _listUrl ?? widget.homeUrl,
              ),
              schema: _siteFilters ?? widget.searchFilters!,
              onChanged: (filters) =>
                  unawaited(_load(filters.toUri(widget.homeUrl))),
            ),
          ],
        )
      : Material(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = _categories[index];
                return Center(
                  child: ChoiceChip(
                    label: Text(category.title),
                    selected: _categorySelected(category.url, page: page),
                    showCheckmark: false,
                    onSelected: (_) => _openCategory(category),
                  ),
                );
              },
            ),
          ),
        );

  Widget? _backPreview() {
    if (_searchVisible ||
        _verificationVisible ||
        _catalogWebsite ||
        _inPersonalLibrary) {
      return null;
    }
    final previous = _requestedUrl.path == '/watch'
        ? _watchOrigin ?? _backStack.lastOrNull
        : _backStack.lastOrNull;
    if (previous?.website == true || previous?.personal == true) return null;
    final uri = previous?.uri ?? _previousTab?.url;
    final data = uri == null ? null : _cachedCatalog(uri);
    if (data == null || uri == null) return null;
    return Scaffold(
      appBar: AppBar(
        title: Text(previous?.creator?.name ?? widget.title),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if ((_categories.isNotEmpty || widget.searchFilters != null) &&
              const {'/', '/search'}.contains(uri.path))
            _categoryBar(page: uri),
          Expanded(
            child:
                _personalRoot(uri) == _ownIdentityRoot &&
                    _ownIdentity.isNotEmpty &&
                    asJsonMap(data['account'])['isOwnProfile'] == true
                ? PageStorage(
                    bucket: _personalStorage,
                    child: VideoPersonalShell(
                      showTabs: false,
                      account: _personalDisplayAccount,
                      page: _ownIdentityRoot!,
                      current: uri,
                      tabs: _personalTabs,
                      onTab: (_) {},
                      onOpenSite: () {},
                      child: _nativeContent(
                        preview: data,
                        page: uri,
                        contentOnly: true,
                      ),
                    ),
                  )
                : uri.path == '/subscriptions' && widget.nativeSubscriptions
                ? PageStorage(
                    bucket: _subscriptionStorage,
                    child: _nativeContent(preview: data, page: uri),
                  )
                : _nativeContent(preview: data, page: uri),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerificationHelp() => showAdaptiveDialog<void>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(t.videoPlayback.verificationTitle),
      scrollable: true,
      content: Text(
        '${t.videoPlayback.verificationNote}\n\n'
        '${_verificationStalled ? t.videoPlayback.verificationSlow : t.videoPlayback.verificationStableNote}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.videoPlayback.acknowledge),
        ),
      ],
    ),
  );

  Future<void> _toggleBrowserInspection() async {
    if (_inspectionChanging || !_diagnosticToolsEnabled) return;
    final VideoBrowserInspection? controller = switch (_web?.platform) {
      VideoBrowserInspection browser => browser,
      _ => null,
    };
    if (controller == null) return;
    _inspectionChanging = true;
    final enabled = !_inspectionEnabled;
    try {
      if (enabled) {
        final confirmed = await showAdaptiveDialog<bool>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            title: Text(t.videoPlayback.enableBrowserInspection),
            scrollable: true,
            content: Text(t.videoPlayback.browserInspectionPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.common.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t.videoPlayback.enableBrowserInspection),
              ),
            ],
          ),
        );
        if (!mounted ||
            confirmed != true ||
            !_diagnosticToolsEnabled ||
            !identical(_web?.platform, controller)) {
          return;
        }
      }
      final actual = await controller
          .setInspectionEnabled(enabled)
          .timeout(const Duration(seconds: 4));
      if (!mounted || !identical(_web?.platform, controller)) return;
      if (enabled && !_diagnosticToolsEnabled) {
        final revoked = await controller.setInspectionEnabled(false);
        if (mounted && identical(_web?.platform, controller)) {
          setState(() => _inspectionEnabled = revoked);
        }
        return;
      }
      setState(() => _inspectionEnabled = actual);
      if (actual != enabled) throw StateError('Inspection preference rejected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.videoPlayback.browserInspectionNote)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.videoPlayback.browserInspectionFailed)),
        );
      }
    } finally {
      _inspectionChanging = false;
    }
  }

  List<Uri> get _externalAuthenticationEntries => [
    for (final rawEntry in widget.externalAuthenticationEntries.take(4))
      if (videoSiteExternalAuthenticationEntry(widget.homeUrl, rawEntry)
          case final Uri entry)
        entry,
  ];

  Uri? get _observedGoogleAuthenticationEntry {
    final actual = Uri.tryParse(_authForm['googleUrl']?.toString() ?? '');
    return _externalAuthenticationEntries
        .where((entry) => entry == actual)
        .firstOrNull;
  }

  Future<void> _continueExternalAuthentication(Uri entry) async {
    if (_externalAuthenticationBusy ||
        !_externalAuthenticationEntries.contains(entry)) {
      return;
    }
    _externalAuthenticationBusy = true;
    final epoch = _loadEpoch;
    _dismissCatalogMenu();
    FocusScope.of(context).unfocus();
    try {
      final proceed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(t.videoSiteAccount.googleWebsiteTitle),
          scrollable: true,
          content: Text(t.videoSiteAccount.googleWebsiteNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.videoSiteAccount.continueInBrowser),
            ),
          ],
        ),
      );
      if (!mounted ||
          epoch != _loadEpoch ||
          proceed != true ||
          !_externalAuthenticationEntries.contains(entry)) {
        return;
      }
      // Reopen the observed first-party entry, never an OAuth redirect URL.
      // Safari and this WebKit store are independent; no identity is inferred.
      final opened = await launchUrl(
        entry,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('External authentication could not open');
    } catch (_) {
      if (mounted && epoch == _loadEpoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.videoSiteAccount.browserOpenFailed),
            action: SnackBarAction(
              label: t.common.retry,
              onPressed: () =>
                  unawaited(_continueExternalAuthentication(entry)),
            ),
          ),
        );
      }
    } finally {
      _externalAuthenticationBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) => ReadRecoveryHost(
    onActiveChanged: (active) =>
        _readRecovery.setActive(active && _automaticCatalogAllowed),
    child: _buildNetwork(context),
  );

  Widget _buildNetwork(BuildContext context) => VideoNetworkScope(
    source: widget.source,
    network: _network,
    child: FutureBuilder<OmoNetworkContext?>(
      future: _network,
      builder: (context, snapshot) =>
          snapshot.connectionState != ConnectionState.done
          ? _networkStatus(loading: true)
          : snapshot.hasError
          ? _networkStatus(loading: false)
          : _buildPage(context),
    ),
  );

  Widget _networkStatus({required bool loading}) => Scaffold(
    appBar: AppBar(
      leading: const SourceBackButton(),
      title: Text(widget.title),
    ),
    body: Center(
      child: loading
          ? const CircularProgressIndicator()
          : Text(t.videoSource.readFailed),
    ),
  );

  Widget _buildPage(BuildContext context) {
    final officialWebsite = sourceOfficialWebsite(widget.source);
    final tabIndex = widget.tabs.indexWhere((tab) => tab.id == _activeTab);
    final android = defaultTargetPlatform == TargetPlatform.android;
    final internalBack = !_verificationVisible && _canGoBackInside;
    final verificationBack =
        android && _verificationVisible && _canGoBackInside;
    final requiredBrowser =
        _verificationVisible ||
        _websiteVisible &&
            (!_hasNativePage(_requestedUrl) ||
                const {'/login', '/register'}.contains(_requestedUrl.path) &&
                    (!widget.nativeAuth || _authForm['supported'] != true));
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: PopScope<Object?>(
        canPop: !_canGoBackInside && (!_verificationVisible || android),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_goBackInside(leaveVerification: android));
        },
        child: VideoBackGesture(
          enabled: !android && internalBack && _openNativeMenu == null,
          onBack: _goBackInside,
          previousPage: android ? null : _backPreview(),
          child: Stack(
            children: [
              Scaffold(
                extendBody: usesNativeSourceChrome(context),
                appBar: _personalVisible
                    ? null
                    : _inPersonalLibrary
                    ? _personalListAppBar()
                    : AppBar(
                        leading: Center(
                          child: NativeVideoIconButton(
                            light: false,
                            tooltip:
                                internalBack ||
                                    verificationBack ||
                                    widget.initialUrl != null
                                ? t.common.back
                                : t.videoPlayback.closeSource,
                            symbol:
                                internalBack ||
                                    verificationBack ||
                                    widget.initialUrl != null
                                ? 'chevron.left'
                                : 'xmark',
                            icon:
                                internalBack ||
                                    verificationBack ||
                                    widget.initialUrl != null
                                ? Icons.arrow_back_rounded
                                : Icons.close_rounded,
                            onPressed: () {
                              if (_verificationVisible && !verificationBack) {
                                Navigator.of(context).pop();
                              } else {
                                unawaited(
                                  _goBackInside(leaveVerification: android),
                                );
                              }
                            },
                          ),
                        ),
                        titleSpacing: 0,
                        title:
                            !_verificationVisible &&
                                !_websiteVisible &&
                                !_isPersonalContext &&
                                _creatorContext == null
                            ? VideoSearchEntry(
                                query: VideoSearchFilters.fromUri(
                                  _listUrl ?? widget.homeUrl,
                                ).query,
                                onTap: _openSearch,
                                onClear: _clearCatalogSearch,
                              )
                            : Text(
                                _verificationVisible
                                    ? t.videoPlayback.verificationTitle
                                    : _personalVisible
                                    ? t.videoPlayback.localWatchHistory
                                    : _personalOverviewEnabled &&
                                          !_websiteVisible
                                    ? _inPersonalLibrary
                                          ? _personalTabs
                                                    .where(
                                                      (tab) =>
                                                          tab.url.path ==
                                                          _requestedUrl.path,
                                                    )
                                                    .map(_personalTabTitle)
                                                    .firstOrNull ??
                                                t.videoPersonal.my
                                          : t.videoPersonal.my
                                    : _creatorContext?.name ?? widget.title,
                              ),
                        actionsPadding: const EdgeInsetsDirectional.only(
                          start: 8,
                          end: 8,
                        ),
                        actions: [
                          if (!_verificationVisible &&
                              !_websiteVisible &&
                              _hasPersonalShell)
                            const CollectionCoverPrivacyButton(),
                          if (_creatorContext != null &&
                              !_verificationVisible &&
                              !_websiteVisible)
                            NativeVideoIconButton(
                              light: false,
                              tooltip: t.videoPlayback.search,
                              symbol: 'magnifyingglass',
                              icon: Icons.search_rounded,
                              onPressed: _openSearch,
                            ),
                          NativeVideoMenu(
                            hostPresentation: true,
                            selectAfterDismissal: const {
                              collectionCoverSettingsAction,
                            },
                            // UIKit and the Breeze fallback each own outside-tap
                            // dismissal; the page must not add a second barrier.
                            controller: _modeMenu,
                            onOpened: () => _catalogMenuOpened(_modeMenu),
                            onClosed: () => _catalogMenuClosed(_modeMenu),
                            tooltip: _verificationVisible
                                ? t.videoPlayback.verificationActions
                                : requiredBrowser
                                ? t.videoPlayback.browserActions
                                : t.videoPlayback.websiteToggle,
                            selected: _websiteVisible ? 'website' : 'native',
                            label: '',
                            width: 44,
                            symbol: 'ellipsis',
                            icon: Icons.more_horiz_rounded,
                            options: {
                              if (!_websiteVisible &&
                                  !_verificationVisible &&
                                  (_personalVisible ||
                                      _hasPersonalShell ||
                                      _recordPrivacyPage(_requestedUrl)))
                                collectionCoverSettingsAction:
                                    collectionCoverSettingsLabel(context),
                              if (!_verificationVisible &&
                                  !_personalVisible &&
                                  !_isPersonalContext &&
                                  !_inPersonalLibrary)
                                'personal': t.videoPlayback.localWatchHistory,
                              if (!requiredBrowser) ...{
                                'native': t.videoPlayback.nativeCatalog,
                                'website': t.videoPlayback.backToWeb,
                              },
                              if (_verificationVisible) ...{
                                'check': t.videoPlayback.checkVerification,
                                'reload': t.videoPlayback.reloadVerification,
                                if ((_allowsAndroidVerificationWindow &&
                                        _web != null) ||
                                    _usesVerificationWindow)
                                  'verificationWindow':
                                      t.videoPlayback.verificationWindow,
                                'help': t.videoPlayback.verificationHelp,
                              },
                              if (_websiteVisible && !_verificationVisible)
                                'webRefresh': t.common.refresh,
                              if (_diagnosticToolsEnabled)
                                'diagnostics': t.videoPlayback.pageAnalysis,
                              if (_diagnosticToolsEnabled &&
                                  _web?.platform is VideoBrowserInspection)
                                'browserInspection': _inspectionEnabled
                                    ? t.videoPlayback.disableBrowserInspection
                                    : t.videoPlayback.enableBrowserInspection,
                              'tools': t.discover.settings,
                              if (officialWebsite != null)
                                'officialWebsite':
                                    t.sourceShell.openOfficialWebsite,
                              'exit': t.sourceShell.exitPlugin,
                            },
                            groups: const [
                              [
                                'personal',
                                'native',
                                'website',
                                'check',
                                'reload',
                                'webRefresh',
                                'verificationWindow',
                                'help',
                              ],
                              ['diagnostics', 'browserInspection'],
                              [
                                collectionCoverSettingsAction,
                                'tools',
                                'officialWebsite',
                              ],
                              ['exit'],
                            ],
                            optionIcons: const {
                              collectionCoverSettingsAction: (
                                icon: Icons.visibility_off_outlined,
                                symbol: 'eye.slash',
                              ),
                              'browserInspection': (
                                icon: Icons.bug_report_outlined,
                                symbol: 'ladybug',
                              ),
                              'diagnostics': (
                                icon: Icons.analytics_outlined,
                                symbol: 'waveform.path.ecg',
                              ),
                              'officialWebsite': (
                                icon: Icons.open_in_browser_outlined,
                                symbol: 'safari',
                              ),
                              'exit': (
                                icon: Icons.exit_to_app,
                                symbol: 'rectangle.portrait.and.arrow.right',
                              ),
                              'native': (
                                icon: Icons.grid_view_rounded,
                                symbol: 'square.grid.2x2',
                              ),
                              'website': (
                                icon: Icons.language_rounded,
                                symbol: 'safari',
                              ),
                              'tools': (
                                icon: Icons.settings_outlined,
                                symbol: 'gearshape',
                              ),
                              'personal': (
                                icon: Icons.history_rounded,
                                symbol: 'clock.arrow.circlepath',
                              ),
                              'check': (
                                icon: Icons.verified_user_outlined,
                                symbol: 'checkmark.shield',
                              ),
                              'reload': (
                                icon: Icons.refresh_rounded,
                                symbol: 'arrow.clockwise',
                              ),
                              'webRefresh': (
                                icon: Icons.refresh_rounded,
                                symbol: 'arrow.clockwise',
                              ),
                              'verificationWindow': (
                                icon: Icons.open_in_new_rounded,
                                symbol: 'arrow.up.right.square',
                              ),
                              'help': (
                                icon: Icons.help_outline_rounded,
                                symbol: 'questionmark.circle',
                              ),
                            },
                            onSelected: (value) {
                              _dismissCatalogMenu();
                              if (requiredBrowser &&
                                  const {'native', 'website'}.contains(value)) {
                                return;
                              }
                              unawaited(switch (value) {
                                collectionCoverSettingsAction =>
                                  openCollectionCoverSettings(context),
                                'personal' => Future<void>.sync(_showPersonal),
                                'tools' => _showTools(),
                                'officialWebsite' =>
                                  officialWebsite == null
                                      ? Future<void>.value()
                                      : openSourceOfficialWebsite(
                                          context,
                                          officialWebsite,
                                        ),
                                'check' => _onLoaded(_requestedUrl),
                                'reload' => _reloadVerification(),
                                'webRefresh' => _refreshWebsiteDocument(),
                                'verificationWindow' =>
                                  _openVerificationWindow(),
                                'help' => _showVerificationHelp(),
                                'diagnostics' => _showPageAnalysis(),
                                'browserInspection' =>
                                  _toggleBrowserInspection(),
                                'exit' => _exitSource(),
                                'native' => _chooseDisplayMode(false),
                                'website' => _chooseDisplayMode(true),
                                _ => Future<void>.value(),
                              });
                            },
                          ),
                        ],
                      ),
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring:
                            (_verificationVisible && _usesVerificationWindow) ||
                            !_verificationVisible &&
                                (!_websiteVisible || _busy || _siteLoadFailed),
                        child: VideoSiteBrowser(
                          visible:
                              _websiteVisible ||
                              _verificationVisible && !_usesVerificationWindow,
                          home: widget.homeUrl,
                          source: widget.source,
                          networkContext: _networkContext?.token,
                          externalAuthenticationEntries:
                              _externalAuthenticationEntries,
                          onExternalAuthentication: (entry) =>
                              unawaited(_continueExternalAuthentication(entry)),
                          onDocumentResponse: _onDocumentResponse,
                          configuration: InAppWebView(
                            key: ObjectKey(this),
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              domStorageEnabled: true,
                              databaseEnabled: true,
                              // This browser sits beneath the native catalog.
                              // Keep Android in Flutter's texture compositor so
                              // the catalog does not retain a stale surface.
                              useHybridComposition:
                                  defaultTargetPlatform ==
                                      TargetPlatform.android
                                  ? false
                                  : null,
                              useShouldOverrideUrlLoading: true,
                            ),
                            onWebViewCreated: (controller) {
                              _web = controller;
                              _registerDownloadRetry();
                              unawaited(_initializeCatalog());
                            },
                            onWebContentProcessDidTerminate: (_) =>
                                _browserProcessTerminated(),
                            onLoadStart: (_, url) {
                              if (!mounted ||
                                  _refreshCompleter != null ||
                                  _personalVisible) {
                                return;
                              }
                              final uri = Uri.tryParse(url?.toString() ?? '');
                              if (_browserNeedsRecovery &&
                                  !videoSiteDocumentMatches(
                                    _requestedUrl,
                                    uri,
                                  )) {
                                return;
                              }
                              _clearDocumentFailureEvidence();
                              _browserDiagnostics.document('load-start', uri);
                              if (!_isFirstParty(uri)) return;
                              // A real main-document navigation invalidates
                              // the open menu even when verification stays
                              // visible. Read-only observation does not.
                              _dismissCatalogMenu();
                              if (!_websiteVisible &&
                                  !_verificationVisible &&
                                  !_busy &&
                                  !_siteLoadFailed &&
                                  videoSiteDocumentMatches(
                                    _requestedUrl,
                                    uri,
                                  )) {
                                // WebKit can restart the current document after
                                // suspension. Keep native content while probing
                                // its replacement; a real challenge still owns
                                // the commit/state verification path below.
                                _refreshingCatalog = true;
                              }
                              _documentLoading = true;
                              _awaitingCommit = true;
                              _adoptWebsiteNavigation(uri);
                              if (!videoSiteDocumentMatches(
                                _requestedUrl,
                                uri,
                              )) {
                                return;
                              }
                              if (_verificationVisible) return;
                              _startLoadWatchdog(uri);
                              setState(() {
                                _busy = !_refreshingCatalog;
                                _siteLoadFailed = false;
                                _message = null;
                              });
                            },
                            onPageCommitVisible: (_, url) {
                              final uri = Uri.tryParse(url?.toString() ?? '');
                              if (_refreshCompleter != null &&
                                  videoSiteDocumentMatches(
                                    _refreshWatchUrl,
                                    uri,
                                  )) {
                                _refreshCommitSerial++;
                              }
                              if (!_personalVisible &&
                                  _refreshCompleter == null) {
                                _adoptWebsiteNavigation(uri);
                              }
                              if (videoSiteDocumentMatches(
                                _requestedUrl,
                                uri,
                              )) {
                                // A provisional callback can outlive an
                                // evicted process. Only the current commit
                                // can satisfy pending browser recovery.
                                _browserNeedsRecovery = false;
                                _awaitingCommit = false;
                              }
                              _browserDiagnostics.document(
                                'document-commit',
                                uri,
                              );
                              if (!_personalVisible &&
                                  videoSiteDocumentMatches(
                                    _requestedUrl,
                                    uri,
                                  ) &&
                                  videoSiteDocumentMatches(
                                    _challengeResponseUrl,
                                    uri,
                                  )) {
                                // A challenge response is now the actual document. Show
                                // it before waiting for the verification scripts to end.
                                // No reload, cookie operation or injected script occurs.
                                _showVerification(_loadEpoch);
                              } else if (!_personalVisible &&
                                  !_verificationVisible &&
                                  (_busy || _refreshingCatalog) &&
                                  videoSiteDocumentMatches(
                                    _requestedUrl,
                                    uri,
                                  )) {
                                _startLoadWatchdog(uri);
                              }
                            },
                            onLoadStop: (_, url) async {
                              if (_personalVisible) return;
                              final uri = Uri.tryParse(url?.toString() ?? '');
                              // A previous auth document may finish after its
                              // redirect has committed. Only the actual current
                              // document can move an in-flight authentication.
                              if ((_authSubmissionStarted ||
                                      _accountSubmissionStarted ||
                                      _recoverySubmissionStarted) &&
                                  !videoSiteDocumentMatches(
                                    _requestedUrl,
                                    uri,
                                  )) {
                                final epoch = _loadEpoch;
                                try {
                                  final state = await _readSiteState();
                                  if (!mounted ||
                                      epoch != _loadEpoch ||
                                      !videoSiteDocumentMatches(
                                        uri,
                                        state.url,
                                      )) {
                                    return;
                                  }
                                } catch (_) {
                                  return;
                                }
                              }
                              _browserDiagnostics.document('load-stop', uri);
                              final refreshing = _refreshCompleter;
                              if (refreshing != null) {
                                if (_isFirstParty(uri) &&
                                    uri?.path == '/watch' &&
                                    uri?.queryParameters['v'] ==
                                        _refreshWatchUrl
                                            ?.queryParameters['v'] &&
                                    !refreshing.isCompleted) {
                                  refreshing.complete();
                                }
                                return;
                              }
                              _adoptWebsiteNavigation(uri);
                              if (!videoSiteDocumentMatches(
                                _requestedUrl,
                                uri,
                              )) {
                                return;
                              }
                              _documentLoading = false;
                              _awaitingCommit = false;
                              _loadWatchdog?.cancel();
                              if (!_busy &&
                                  !_refreshingCatalog &&
                                  !_siteLoadFailed &&
                                  !_verificationVisible) {
                                unawaited(_inspectSite());
                                return;
                              }
                              unawaited(_onLoaded(uri));
                            },
                            onReceivedError: (_, request, error) {
                              final nativeFailure =
                                  RegExp(
                                    r'^WKNavigation (url|webkit|other) -?\d+ (provisional|committed|process|other)$',
                                  ).hasMatch(error.description)
                                  ? error.description
                                  : null;
                              _browserDiagnostics.resource(
                                Uri.parse(request.url.toString()),
                                nativeFailure ?? error.type.toString(),
                                main: request.isForMainFrame == true,
                              );
                              if (!_browserNeedsRecovery &&
                                  request.isForMainFrame == true &&
                                  videoSiteDocumentMatches(
                                    _requestedUrl,
                                    Uri.tryParse(request.url.toString()),
                                  ) &&
                                  error.type !=
                                      WebResourceErrorType.CANCELLED) {
                                _showLoadError(
                                  reason:
                                      nativeFailure ?? error.type.toString(),
                                  path:
                                      Uri.tryParse(
                                        request.url.toString(),
                                      )?.path ??
                                      '/',
                                );
                              }
                            },
                            onReceivedHttpError: (_, request, response) {
                              if (request.isForMainFrame == true) {
                                _onDocumentResponse(
                                  Uri.parse(request.url.toString()),
                                  response.statusCode ?? 0,
                                  response.headers ?? const {},
                                );
                              } else {
                                _browserDiagnostics.resource(
                                  Uri.parse(request.url.toString()),
                                  'HTTP ${response.statusCode}',
                                  main: false,
                                );
                              }
                              // A 401 PAT probe or a failed subframe is not a fatal
                              // main-document error. Keep the actual page usable.
                              unawaited(_inspectSite());
                            },
                            onUpdateVisitedHistory: (_, url, _) {
                              final uri = Uri.tryParse(url?.toString() ?? '');
                              _browserDiagnostics.document('history', uri);
                              if (_adoptWebsiteNavigation(uri)) {
                                _startLoadWatchdog(uri);
                              }
                              unawaited(_inspectSite());
                            },
                            onConsoleMessage: (_, message) {
                              _browserDiagnostics.console(message.message);
                            },
                            shouldOverrideUrlLoading: (_, action) async {
                              final uri = Uri.tryParse(
                                action.request.url?.toString() ?? '',
                              );
                              if (action.isForMainFrame &&
                                  uri != null &&
                                  _externalAuthenticationEntries.contains(
                                    uri,
                                  )) {
                                unawaited(_continueExternalAuthentication(uri));
                                return NavigationActionPolicy.CANCEL;
                              }
                              final allowed = allowVideoSiteNavigation(
                                widget.homeUrl,
                                uri,
                                isMainFrame: action.isForMainFrame,
                              );
                              _browserDiagnostics.navigation(
                                uri,
                                main: action.isForMainFrame,
                                allowed: allowed,
                              );
                              if (allowed &&
                                  action.isForMainFrame &&
                                  _refreshCompleter == null) {
                                _adoptWebsiteNavigation(uri);
                              }
                              return allowed
                                  ? NavigationActionPolicy.ALLOW
                                  : NavigationActionPolicy.CANCEL;
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_verificationVisible && _usesVerificationWindow)
                      Positioned.fill(
                        child: VideoVerificationGate(
                          active: _verificationWindowActive,
                          onVerify: () => unawaited(_openVerificationWindow()),
                          onHelp: () => unawaited(_showVerificationHelp()),
                        ),
                      ),
                    if ((!_websiteVisible && !_verificationVisible) ||
                        _accountTaskReady ||
                        _recoveryReady)
                      Positioned.fill(
                        child: Offstage(
                          offstage: _websiteVisible || _verificationVisible,
                          child: TickerMode(
                            enabled: !_websiteVisible && !_verificationVisible,
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              child: Column(
                                children: [
                                  if ((_categories.isNotEmpty ||
                                          widget.searchFilters != null) &&
                                      const {
                                        '/',
                                        '/search',
                                      }.contains(_requestedUrl.path))
                                    _categoryBar(),
                                  Expanded(child: _catalogBody()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_websiteVisible &&
                        _busy &&
                        !_siteLoadFailed &&
                        !_verificationVisible)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    if (_siteLoadFailed && !_hasPersonalShell)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sync_problem_rounded,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _message ?? t.webview.loadFailed,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: () => _websiteVisible
                                            ? _openWebsitePage(
                                                _requestedUrl,
                                                fallback:
                                                    videoSiteDocumentMatches(
                                                      _websiteFallbackUrl,
                                                      _requestedUrl,
                                                    ),
                                              )
                                            : _load(_requestedUrl),
                                        child: Text(t.common.retry),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _openWebsitePage(
                                          _requestedUrl,
                                          fallback: true,
                                          userChoice: true,
                                        ),
                                        child: Text(t.videoPlayback.website),
                                      ),
                                    ],
                                  ),
                                  if (_diagnosticToolsEnabled &&
                                      _diagnostic != null)
                                    TextButton(
                                      onPressed: _copyDiagnostic,
                                      child: Text(
                                        t.videoPlayback.copyDiagnostic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_websiteVisible && _message != null && !_siteLoadFailed)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: MaterialBanner(
                          content: Text(_message!),
                          actions: [
                            if (_diagnosticToolsEnabled && _diagnostic != null)
                              TextButton(
                                onPressed: _copyDiagnostic,
                                child: Text(t.videoPlayback.copyDiagnostic),
                              ),
                            TextButton(
                              onPressed: () => setState(() => _message = null),
                              child: Text(t.videoPlayback.acknowledge),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                bottomNavigationBar:
                    widget.tabs.isEmpty ||
                        _inPersonalLibrary ||
                        _personalVisible ||
                        _websiteVisible ||
                        _verificationVisible
                    ? null
                    : VideoNativeNavigation(
                        symbols: [
                          for (final tab in widget.tabs)
                            switch (tab.id) {
                              'recommend' => 'house',
                              'ranking' => 'chart.bar',
                              'subscriptions' => 'play.rectangle.on.rectangle',
                              _ => 'person.crop.circle',
                            },
                        ],
                        currentIndex: tabIndex < 0 ? 0 : tabIndex,
                        onTap: _verificationVisible
                            ? null
                            : (index) =>
                                  unawaited(_openTab(widget.tabs[index])),
                        items: [
                          for (final tab in widget.tabs)
                            BottomNavigationBarItem(
                              icon: Icon(switch (tab.id) {
                                'recommend' => Icons.home_outlined,
                                'ranking' => Icons.leaderboard_outlined,
                                'subscriptions' => Icons.subscriptions_outlined,
                                _ => Icons.person_outline_rounded,
                              }),
                              activeIcon: Icon(switch (tab.id) {
                                'recommend' => Icons.home_rounded,
                                'ranking' => Icons.leaderboard_rounded,
                                'subscriptions' => Icons.subscriptions_rounded,
                                _ => Icons.person_rounded,
                              }),
                              label: tab.title,
                            ),
                        ],
                      ),
              ),
              if (_openNativeMenu != null && !_openNativeMenu!.ownsBarrier)
                Positioned.fill(
                  child: BlockSemantics(
                    child: ModalBarrier(
                      key: const ValueKey('catalog-native-menu-barrier'),
                      color: Colors.transparent,
                      dismissible: true,
                      semanticsLabel: MaterialLocalizations.of(
                        context,
                      ).modalBarrierDismissLabel,
                      onDismiss: _dismissCatalogMenu,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses Android WebView's regular shared cookie and site-storage profile, just
/// like the inline site. The dedicated route owns no catalog or account logic.
class _AndroidVideoVerificationPage extends StatelessWidget {
  const _AndroidVideoVerificationPage({
    required this.home,
    required this.target,
  });

  final Uri home;
  final Uri target;

  bool _allows(WebUri? destination, {required bool isMainFrame}) =>
      allowVideoSiteNavigation(
        home,
        Uri.tryParse(destination?.toString() ?? ''),
        isMainFrame: isMainFrame,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.videoPlayback.verificationTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(target.toString())),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useHybridComposition: false,
                  useShouldOverrideUrlLoading: true,
                ),
                shouldOverrideUrlLoading: (_, action) async =>
                    _allows(
                      action.request.url,
                      isMainFrame: action.isForMainFrame,
                    )
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL,
                // Android does not report all POST requests to the override.
                onLoadStart: (controller, url) async {
                  if (!_allows(url, isMainFrame: true)) {
                    await controller.stopLoading();
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(t.videoPlayback.verificationWindowReturn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
