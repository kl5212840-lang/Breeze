import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_web_account.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_detail_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';

import 'package:auto_route/auto_route.dart';
import 'package:zephyr/plugin/utils/plugin_local_file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/method/plugin_settings_web_login.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/plugin/plugin_cloud_update_service.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show createSyncArchiveAdapter;
import 'package:zephyr/page/setting/common/backup_protection_ui.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/service/plugin_cloud_purge.dart';
import 'package:zephyr/service/plugin_data_removal.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_removal_flow.dart';
import 'package:zephyr/page/video/video_local_resources.dart'
    show ManagedVideoResourceBusy;
import 'package:zephyr/widgets/plugin_installation_guard.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/event/webview_observe_bus.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/page/plugin_settings/plugin_settings_action_policy.dart';

@RoutePage()
class PluginSettingsPage extends StatelessWidget {
  const PluginSettingsPage({
    super.key,
    required this.from,
    required this.pluginUuid,
    required this.pluginRuntimeName,
    required this.pluginDisplayName,
    this.insideSource = false,
    this.scope = PluginSettingsScope.all,
  });

  final String from;
  final String pluginUuid;
  final String pluginRuntimeName;
  final String pluginDisplayName;
  final bool insideSource;
  final PluginSettingsScope scope;

  @override
  Widget build(BuildContext context) =>
      SourceExperienceBoundary(source: pluginUuid, builder: _buildSourcePage);

  Widget _buildSourcePage(BuildContext context) {
    String? settingsUserInfoFunction;
    final plugin = PluginRegistryService.I.getByUuid(pluginUuid);
    if (plugin != null) {
      try {
        final info = asJsonMap(
          PluginRegistryService.I.getCachedPluginInfo(plugin.uuid),
        );
        final experience = asJsonMap(info['breezeExperience']);
        final summaryFunction = experience['settingsUserInfoFunction'];
        if (summaryFunction is String && summaryFunction.trim().isNotEmpty) {
          settingsUserInfoFunction = summaryFunction.trim();
        }
      } catch (_) {}
    }
    final effectiveScope = scope;
    // Personal avatars and account shortcuts lead here too. Read only the
    // plugin's declared account capabilities; a profile tab no longer hides
    // the account task from this shared settings destination.
    final showAccount = effectiveScope != PluginSettingsScope.management;
    return PluginSettingsWebAccount(
      key: ValueKey('settings-account:$from'),
      source: showAccount ? from : '',
      builder: (readWebIdentity) => BlocProvider(
        create: (_) => PluginSettingsCubit(
          includeAccount: showAccount,
          includeLogin: showAccount,
          userInfoFunction: settingsUserInfoFunction,
          readWebIdentity: readWebIdentity,
        )..load(from),
        child: _PluginSettingsPageView(
          from: from,
          pluginUuid: pluginUuid,
          pluginRuntimeName: pluginRuntimeName,
          pluginDisplayName: pluginDisplayName,
          insideSource: insideSource,
          scope: effectiveScope,
          showAccount: showAccount,
          readOnlyAccount: settingsUserInfoFunction != null,
        ),
      ),
    );
  }
}

class _PluginSettingsPageView extends StatefulWidget {
  const _PluginSettingsPageView({
    required this.from,
    required this.pluginUuid,
    required this.pluginRuntimeName,
    required this.pluginDisplayName,
    required this.insideSource,
    required this.scope,
    required this.showAccount,
    required this.readOnlyAccount,
  });

  final String from;
  final String pluginUuid;
  final String pluginRuntimeName;
  final String pluginDisplayName;
  final bool insideSource;
  final PluginSettingsScope scope;
  final bool showAccount;
  final bool readOnlyAccount;

  @override
  State<_PluginSettingsPageView> createState() =>
      _PluginSettingsPageViewState();
}

class _PluginSettingsPageViewState extends State<_PluginSettingsPageView> {
  bool _lifecycleBusy = false;
  bool _confirmingRemoval = false;
  int _purgeGeneration = 0;
  final Set<String> _pendingFields = {};
  final Set<String> _pendingActions = {};
  final Map<String, String> _fieldErrors = {};
  StreamSubscription<WebViewObserveEvent>? _webLoginSub;
  PluginWebLoginFlowConfig? _activeWebLogin;
  int? _webLoginSessionGeneration;
  bool _submittingWebCookie = false;
  bool _externalFallbackTriggered = false;
  bool _externalLoginPolling = false;
  Timer? _externalCookiePollTimer;
  ExternalChromiumLoginSession? _externalChromiumSession;

  @override
  void dispose() {
    final sub = _webLoginSub;
    _webLoginSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    _stopExternalChromiumLoginFlow();
    super.dispose();
  }

  int? _webLoginReadGeneration(
    String source,
    String fnPath,
    bool sessionChange,
  ) {
    if (sessionChange || isStandardPluginSessionChange(fnPath)) return null;
    return pluginSessionWriteFence.generation(normalizePluginId(source));
  }

  Future<bool> _maybeHandleWebLoginResult(
    Map<String, dynamic> result, {
    required String source,
    required int installationEpoch,
    required int? readGeneration,
  }) async {
    final config = _parseWebLoginFlowConfig(result);
    if (config == null) {
      return false;
    }
    final canonicalSource = normalizePluginId(source);
    // Session-changing calls have already verified their own transition.
    // An ordinary read must keep the generation from its original dispatch.
    final generation =
        readGeneration ?? pluginSessionWriteFence.generation(canonicalSource);
    await _startWebLoginFlow(
      config,
      sessionGeneration: generation,
      current: () =>
          mounted &&
          !_lifecycleBusy &&
          widget.from == source &&
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) ==
              installationEpoch &&
          pluginSessionWriteFence.generation(canonicalSource) == generation,
    );
    return true;
  }

  PluginWebLoginFlowConfig? _parseWebLoginFlowConfig(
    Map<String, dynamic> result,
  ) {
    final merged = Map<String, dynamic>.from(result);
    merged.addAll(asJsonMap(result['data']));

    final action = asJsonMap(merged['action']);
    final actionPayload = asJsonMap(action['payload']);

    final openUrl =
        (merged['openUrl']?.toString() ??
                actionPayload['url']?.toString() ??
                '')
            .trim();
    final setCookieFnPath = (merged['setCookieFnPath']?.toString() ?? '')
        .trim();
    if (openUrl.isEmpty || setCookieFnPath.isEmpty) {
      return null;
    }

    final openUri = Uri.tryParse(openUrl);
    if (openUri == null || !openUri.hasScheme || openUri.host.isEmpty) {
      return null;
    }

    final redirectWatchUrl = (merged['redirectWatchUrl']?.toString() ?? '')
        .trim();
    final parsedRedirectWatchUri = redirectWatchUrl.isEmpty
        ? null
        : Uri.tryParse(redirectWatchUrl);
    final redirectWatchUri =
        parsedRedirectWatchUri != null &&
            parsedRedirectWatchUri.hasScheme &&
            parsedRedirectWatchUri.host.isNotEmpty
        ? parsedRedirectWatchUri
        : null;

    final ignoreCookieNames = <String>{
      'cf_clearance',
      ...asJsonList(merged['ignoreCookieNames'])
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty),
    };
    final cookiePollIntervalMs = toPositiveInt(
      merged['cookiePollIntervalMs'],
      fallback: 500,
    );
    final openTitle =
        (merged['openTitle']?.toString() ??
                actionPayload['title']?.toString() ??
                t.plugin.loginTitle(name: widget.pluginDisplayName))
            .trim();

    return PluginWebLoginFlowConfig(
      openTitle: openTitle.isEmpty
          ? t.plugin.loginTitle(name: widget.pluginDisplayName)
          : openTitle,
      openUrl: openUrl,
      openUri: openUri,
      redirectWatchUrl: redirectWatchUrl,
      redirectWatchUri: redirectWatchUri,
      setCookieFnPath: setCookieFnPath,
      cookiePollIntervalMs: cookiePollIntervalMs,
      ignoreCookieNames: ignoreCookieNames,
    );
  }

  Future<void> _startWebLoginFlow(
    PluginWebLoginFlowConfig config, {
    required int sessionGeneration,
    required bool Function() current,
  }) async {
    if (!current()) return;
    await _stopWebLoginFlow();
    if (!current()) return;
    _stopExternalChromiumLoginFlow();
    _activeWebLogin = config;
    _webLoginSessionGeneration = sessionGeneration;
    _submittingWebCookie = false;
    _externalFallbackTriggered = false;
    _externalLoginPolling = false;

    _webLoginSub = WebViewObserveBus.stream.listen(
      (event) => unawaited(_handleWebLoginObserveEvent(event)),
    );

    unawaited(
      context.pushRoute(WebViewRoute(info: [config.openTitle, config.openUrl])),
    );
    showSuccessToast(t.plugin.loginSuccess);
  }

  Future<void> _stopWebLoginFlow() async {
    final sub = _webLoginSub;
    _webLoginSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    _activeWebLogin = null;
    _webLoginSessionGeneration = null;
    _submittingWebCookie = false;
  }

  void _stopExternalChromiumLoginFlow() {
    _externalCookiePollTimer?.cancel();
    _externalCookiePollTimer = null;
    _externalChromiumSession = null;
    _externalLoginPolling = false;
  }

  Future<void> _handleWebLoginObserveEvent(WebViewObserveEvent event) async {
    final config = _activeWebLogin;
    if (config == null) {
      return;
    }
    if (!_isRelevantWebLoginEvent(event, config)) {
      return;
    }

    if (_shouldFallbackToExternalChromium(event)) {
      await _startExternalChromiumFallback(config);
      return;
    }

    if (config.redirectWatchUrl.isNotEmpty &&
        matchesRedirectWatchUrl(event.url, config.redirectWatchUrl)) {
      await _submitWebLoginCookie(event);
    }
  }

  bool _shouldFallbackToExternalChromium(WebViewObserveEvent event) {
    if (_externalFallbackTriggered) {
      return false;
    }
    if (event.trigger == 'http_error') {
      final code = event.statusCode ?? 0;
      return code == 403 || code == 429 || code == 503;
    }
    if (event.trigger == 'load_error') {
      return true;
    }
    return false;
  }

  Future<void> _startExternalChromiumFallback(
    PluginWebLoginFlowConfig config,
  ) async {
    if (_externalFallbackTriggered) {
      return;
    }
    _externalFallbackTriggered = true;

    await _stopWebLoginFlow();
    _stopExternalChromiumLoginFlow();

    if (!mounted) {
      return;
    }
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      showErrorToast(t.plugin.chromiumFallbackUnsupported);
      return;
    }

    showErrorToast(t.plugin.switchingToExternalBrowser);
    unawaited(context.router.maybePop());

    final session = await ExternalChromiumLoginSession.start(
      openUrl: config.openUrl,
    );
    if (session == null) {
      logger.d('[WebLoginFallback] session start failed, open chrome download');
      showErrorToast(t.plugin.chromiumNotFound);
      unawaited(
        launchUrl(
          Uri.parse(ExternalChromiumLoginSession.chromeDownloadUrl),
          mode: LaunchMode.externalApplication,
        ),
      );
      return;
    }

    _externalChromiumSession = session;
    logger.d(
      '[WebLoginFallback] external chromium ready: ${session.browserName} port=${session.debugPort}',
    );
    showSuccessToast(t.plugin.browserSwitched(browser: session.browserName));
    _externalCookiePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollExternalChromiumCookie(config)),
    );
    unawaited(_pollExternalChromiumCookie(config));
  }

  Future<void> _pollExternalChromiumCookie(
    PluginWebLoginFlowConfig config,
  ) async {
    final session = _externalChromiumSession;
    if (session == null || _externalLoginPolling) {
      return;
    }
    if (_submittingWebCookie) {
      return;
    }
    _externalLoginPolling = true;
    try {
      logger.d(
        '[WebLoginFallback] polling cookies from ${session.browserName} port=${session.debugPort}',
      );
      final cookies = await session.fetchCookies();
      logger.d('[WebLoginFallback] fetched cookies count=${cookies.length}');
      if (cookies.isEmpty) {
        return;
      }
      if (config.redirectWatchUrl.isNotEmpty) {
        final urls = await session.fetchOpenPageUrls();
        logger.d('[WebLoginFallback] open pages count=${urls.length}');
        final reached = urls.any(
          (url) => matchesRedirectWatchUrl(url, config.redirectWatchUrl),
        );
        logger.d(
          '[WebLoginFallback] redirect target reached=$reached target=${config.redirectWatchUrl}',
        );
        if (!reached) {
          return;
        }
      }

      final snapshots = cookies
          .map(
            (item) => WebViewCookieSnapshot(
              name: item['name']?.toString() ?? '',
              value: item['value']?.toString() ?? '',
              domain: item['domain']?.toString(),
              path: item['path']?.toString(),
              expiresDate: toOptionalInt(item['expires']),
              isSecure: item['secure'] == true,
              isHttpOnly: item['httpOnly'] == true,
              isSessionOnly: item['session'] == true,
            ),
          )
          .toList(growable: false);
      final cookie = buildCookieHeader(
        snapshots,
        config,
        nameOf: (snapshot) => snapshot.name as String,
        valueOf: (snapshot) => snapshot.value as String,
        domainOf: (snapshot) => snapshot.domain as String?,
      );
      if (cookie.isEmpty) {
        logger.d('[WebLoginFallback] cookie header is empty after filtering');
        return;
      }

      final submitUrl = config.redirectWatchUrl.isNotEmpty
          ? config.redirectWatchUrl
          : config.openUrl;
      await _submitCookieWithConfig(config, cookie: cookie, url: submitUrl);
    } catch (e, stackTrace) {
      logger.e(
        '[PluginSettings] External chromium cookie poll failed',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _externalLoginPolling = false;
    }
  }

  bool _isRelevantWebLoginEvent(
    WebViewObserveEvent event,
    PluginWebLoginFlowConfig config,
  ) {
    final uri = Uri.tryParse(event.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    if (matchesHost(uri.host, config.openUri.host)) {
      return true;
    }
    final watchHost = config.redirectWatchUri?.host ?? '';
    if (watchHost.isNotEmpty && matchesHost(uri.host, watchHost)) {
      return true;
    }
    return false;
  }

  Future<void> _submitWebLoginCookie(WebViewObserveEvent? event) async {
    final config = _activeWebLogin;
    if (config == null || event == null || _submittingWebCookie) {
      return;
    }

    final cookie = buildCookieHeader(
      event.cookies,
      config,
      nameOf: (snapshot) => snapshot.name as String,
      valueOf: (snapshot) => snapshot.value as String,
      domainOf: (snapshot) => snapshot.domain as String?,
    );
    if (cookie.isEmpty) {
      return;
    }

    await _submitCookieWithConfig(config, cookie: cookie, url: event.url);
  }

  Future<void> _submitCookieWithConfig(
    PluginWebLoginFlowConfig config, {
    required String cookie,
    required String url,
  }) async {
    if (_lifecycleBusy || _submittingWebCookie) {
      return;
    }
    if (_webLoginSessionGeneration !=
        pluginSessionWriteFence.generation(normalizePluginId(widget.from))) {
      // An old browser flow is not a fresh user login after logout/account change.
      await _stopWebLoginFlow();
      _stopExternalChromiumLoginFlow();
      return;
    }
    final cookieNames = extractCookieNames(cookie);
    logger.d(
      '[PluginSettings] setCookie fn=${config.setCookieFnPath} '
      'count=${cookieNames.length} names=${cookieNames.join(',')}',
    );
    _submittingWebCookie = true;
    final epoch = LocalPluginInstallationState.instance.installationEpoch(
      widget.pluginUuid,
    );
    try {
      final result = await callUnifiedComicPlugin(
        from: widget.from,
        fnPath: config.setCookieFnPath,
        sessionChange: true,
        core: {'cookie': cookie, 'url': url},
        extern: const <String, dynamic>{},
      );
      if (!mounted ||
          _lifecycleBusy ||
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) !=
              epoch) {
        return;
      }
      final message = result['message']?.toString().trim();
      showSuccessToast(
        message?.isNotEmpty == true ? message! : t.plugin.cookieSynced,
      );
      await _stopWebLoginFlow();
      _stopExternalChromiumLoginFlow();
      if (mounted) {
        await context.read<PluginSettingsCubit>().load(widget.from);
      }
    } catch (e, stackTrace) {
      logger.e(
        '[PluginSettings] Web login cookie sync failed',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _submittingWebCookie = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pluginState = context
        .watch<PluginRegistryCubit>()
        .state[widget.pluginUuid];
    final debugEnabled = pluginState?.debug ?? false;
    final debugUrl = pluginState?.debugUrl ?? '';
    final deleted = pluginState?.isDeleted == true;
    final pluginVersion = pluginState?.version ?? '';
    final state = context.watch<PluginSettingsCubit>().state;

    return SettingPageShell(
      title: widget.scope == PluginSettingsScope.management
          ? t.plugin.management
          : t.plugin.pluginSettingsTitle(name: widget.pluginDisplayName),
      grouped: true,
      actions: [
        if (widget.insideSource)
          SourceMoreButton(source: widget.from, showSettings: false),
      ],
      child: PluginSettingsContent(
        from: widget.from,
        pluginUuid: widget.pluginUuid,
        pluginRuntimeName: widget.pluginRuntimeName,
        state: state,
        debugEnabled: debugEnabled,
        debugUrl: debugUrl,
        deleted: deleted,
        pluginVersion: pluginVersion,
        colorScheme: colorScheme,
        scope: widget.scope,
        showAccount: widget.showAccount,
        readOnlyAccount: widget.readOnlyAccount,
        jmEndpointBusy:
            widget.from == PluginAccountAuthenticationService.jm &&
            isPluginEndpointUpdating(widget.from),
        pendingActions: _pendingActions,
        onUpdateDebugConfig: _updateDebugConfig,
        onConfirmDeletePlugin: _confirmDeletePlugin,
        lifecycleBusy: _lifecycleBusy,
        lifecycleExecuting: _lifecycleBusy && !_confirmingRemoval,
        onReinstall: () async {
          if (_lifecycleBusy) return;
          setState(() => _lifecycleBusy = true);
          try {
            await ensurePluginInstalled(context, widget.pluginUuid);
          } finally {
            if (mounted) setState(() => _lifecycleBusy = false);
          }
        },
        dataExcluded: PluginDataScope.values.any(
          (scope) => LocalPluginInstallationState.instance.isDataExcluded(
            widget.pluginUuid,
            scope,
          ),
        ),
        onRefresh: deleted || _lifecycleBusy ? null : _refresh,
        onCheckPluginUpdate: _syncPlugin,
        onUpdatePlugin: _updatePlugin,
        onOpenLoginPage:
            state.loginSupported ||
                (state.userInfoLoginRequired &&
                    state.accountProfilesSupported &&
                    _hasVideoAccountLogin())
            ? _openLoginPage
            : null,
        onOpenSavedAccounts:
            state.loginSupported || state.accountProfilesSupported
            ? _openSavedAccounts
            : null,
        onOpenDetailPage: _openDetailPage,
        onCommitField: _commitField,
        pendingFields: Set.unmodifiable(_pendingFields),
        fieldErrors: Map.unmodifiable(_fieldErrors),
        onRunAction: (action) => _runAction(context, action),
      ),
    );
  }

  Future<void> _openSavedAccounts() async {
    final revealBrowser = await openPluginSavedAccounts(
      context,
      source: widget.from,
      onAddAccount: () async {
        await _openAccountLogin();
      },
      prepareSession: () =>
          context.read<PluginSettingsCubit>().loadUserInfo(widget.from),
    );
    if (!mounted) return;
    if (revealBrowser) {
      final coordinator = PluginAccountSyncCoordinator.instance;
      // Reveal the existing source browser, retaining its store and mode.
      Navigator.of(context).pop();
      await coordinator.continueProfileLogin(widget.from);
      return;
    }
    await context.read<PluginSettingsCubit>().load(widget.from);
  }

  ({Uri? home, Map<String, dynamic>? catalog}) _videoAccountLogin() {
    final info = PluginRegistryService.I.getCachedPluginInfo(widget.pluginUuid);
    final actions = asJsonList(
      info?['function'],
    ).map(asJsonMap).map((f) => asJsonMap(f['action'])).toList();
    if (widget.from == omoNetworkSource) {
      final action = actions
          .where((a) => a['type'] == 'openVideoLibrary')
          .firstOrNull;
      final raw = asJsonMap(action?['payload'])['url']?.toString();
      final home =
          PluginAccountSyncCoordinator.instance.profileOrigin(widget.from) ??
          Uri.tryParse(raw ?? '');
      return (
        home:
            home != null &&
                home.scheme == 'https' &&
                home.host.isNotEmpty &&
                home.userInfo.isEmpty &&
                home.port == 443
            ? home
            : null,
        catalog: null,
      );
    }
    return (
      home: null,
      catalog: actions
          .where(
            (a) =>
                a['type'] == 'openVideoCatalog' &&
                asJsonMap(a['payload'])['nativeAuth'] == true,
          )
          .firstOrNull,
    );
  }

  bool _hasVideoAccountLogin() {
    final target = _videoAccountLogin();
    return target.home != null || target.catalog != null;
  }

  Future<bool> _openAccountLogin({bool recoverCurrent = false}) async {
    final state = context.read<PluginSettingsCubit>().state;
    final source = widget.from;
    if (state.loginSupported) {
      final generation = pluginSessionWriteFence.generation(
        normalizePluginId(source),
      );
      final sessionField = switch (source) {
        PluginAccountAuthenticationService.copy => 'auth.token',
        PluginAccountAuthenticationService.jm => 'auth.jwt',
        _ when PluginAccountAuthenticationService.bika.contains(source) =>
          'auth.authorization',
        _ => null,
      };
      final username = recoverCurrent
          ? await PluginAccountProfiles.currentLoginHint(
              source,
              legacySessionKey: sessionField,
            )
          : null;
      if (!mounted ||
          source != widget.from ||
          isPluginEndpointUpdating(source)) {
        return false;
      }
      await openPluginAccountLoginForm(
        context,
        source: source,
        username: username,
        recoveryGeneration: recoverCurrent && username != null
            ? generation
            : null,
      );
      return PluginAccountIdentities.current(source) != null;
    }
    final target = _videoAccountLogin();
    if (target.home case final home?) {
      final username = recoverCurrent
          ? await PluginAccountProfiles.currentLoginHint(
                  source,
                  origin: home,
                ) ??
                ''
          : null;
      if (!mounted || source != widget.from) return false;
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => throw const OmoSiteException('unavailable'),
      );
      try {
        await openOmoSitePage(
          context,
          client,
          title: t.plugin.accountLogin,
          path: '/user/login',
          credentialSource: source,
          recoveryUsername: username,
        );
        return client.account?.id.isNotEmpty == true;
      } finally {
        client.dispose();
      }
    }
    final action = target.catalog;
    if (action == null) throw StateError(t.accountProfiles.verificationHint);
    final payload = asJsonMap(action['payload']);
    final origin = Uri.tryParse(payload['url']?.toString() ?? '');
    final username = !recoverCurrent
        ? null
        : origin == null
        ? ''
        : await PluginAccountProfiles.currentLoginHint(
                source,
                origin: origin,
              ) ??
              '';
    if (!mounted || source != widget.from) return false;
    await DiscoverRouter.route(
      context,
      currentFrom: source,
      accountLoginUsername: username,
      action: {
        ...action,
        'payload': {...payload, 'source': source, 'initialAccountLogin': true},
      },
    );
    return PluginAccountIdentities.current(source) != null;
  }

  bool _openingLoginPage = false;
  Future<void> _openLoginPage() async {
    final source = widget.from;
    if (!mounted ||
        _openingLoginPage ||
        _lifecycleBusy ||
        isPluginEndpointUpdating(source)) {
      return;
    }
    _openingLoginPage = true;
    var submitted = false;
    final signIn = eventBus.on<PluginLoginSucceeded>().listen((event) {
      if (event.from == source) submitted = true;
    });
    try {
      final confirmed = await _openAccountLogin(recoverCurrent: true);
      if (mounted && source == widget.from && (confirmed || submitted)) {
        await context.read<PluginSettingsCubit>().load(source);
      }
    } catch (_) {
      if (mounted && source == widget.from) {
        showErrorToast(t.login.loginNotSupported);
      }
    } finally {
      await signIn.cancel();
      _openingLoginPage = false;
    }
  }

  Future<void> _openDetailPage() async {
    await openSettingPage(
      context,
      route: PluginDetailRoute(
        from: widget.from,
        pluginUuid: widget.pluginUuid,
        pluginDisplayName: widget.pluginDisplayName,
      ),
      builder: (_) => PluginDetailPage(
        from: widget.from,
        pluginUuid: widget.pluginUuid,
        pluginDisplayName: widget.pluginDisplayName,
      ),
    );
  }

  Future<void>? _refreshRequest;
  Future<void> _refresh() {
    if (_lifecycleBusy || !mounted) return Future.value();
    late final Future<void> request;
    request = _refreshRequest ??= context
        .read<PluginSettingsCubit>()
        .load(widget.from, refreshAvatar: true)
        .whenComplete(() {
          if (identical(_refreshRequest, request)) _refreshRequest = null;
        });
    return request;
  }

  Future<void> _syncPlugin() async {
    showInfoToast(t.plugin.syncing);
    try {
      final updated = await PluginCloudUpdateService.I
          .syncPluginFromSelfChannel(widget.pluginUuid);
      if (!mounted) {
        return;
      }
      showSuccessToast(updated ? t.plugin.syncSuccess : t.plugin.alreadyLatest);
    } catch (e) {
      showErrorToast(
        t.plugin.syncFailed(error: normalizePluginInstallErrorMessage(e)),
      );
    }
  }

  Future<void> _updatePlugin() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.plugin.updateChooseSource),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('local'),
            child: Text(t.plugin.updateFromLocal),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('network'),
            child: Text(t.plugin.updateFromNetwork),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    if (choice == 'network') {
      await _updatePluginFromNetwork();
      return;
    }
    if (choice == 'local') {
      await _updatePluginFromLocal();
    }
  }

  Future<void> _updatePluginFromNetwork() async {
    final url = await _showUrlInputDialog(
      title: t.plugin.updateFromNetwork,
      hintText: t.plugin.networkInstallHint,
    );
    if (url == null || !mounted) {
      return;
    }
    final resolvedUrl = url.trim();
    if (resolvedUrl.isEmpty) {
      showErrorToast(t.plugin.urlCannotBeEmpty);
      return;
    }

    showInfoToast(t.plugin.updating);
    try {
      final message = await PluginInstallService.I.installFromNetworkUrl(
        resolvedUrl,
        expectedUuid: widget.pluginUuid,
        allowReplaceExisting: true,
      );
      if (!mounted) {
        return;
      }
      showSuccessToast(message.isNotEmpty ? message : t.plugin.updateSuccess);
    } catch (e) {
      showErrorToast(
        t.plugin.updateFailed(error: normalizePluginInstallErrorMessage(e)),
      );
    }
  }

  Future<String?> _showUrlInputDialog({
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

  Future<void> _updatePluginFromLocal() async {
    try {
      final file = await pickPluginScriptFile();
      if (file == null) {
        return;
      }
      showInfoToast(t.plugin.updating);
      final bytes = await file.readAsBytes();
      final message = await PluginInstallService.I.installFromLocalBytes(
        bytes,
        fileName: file.name,
        expectedUuid: widget.pluginUuid,
        allowReplaceExisting: true,
      );
      if (!mounted) {
        return;
      }
      showSuccessToast(message.isNotEmpty ? message : t.plugin.updateSuccess);
    } catch (e) {
      showErrorToast(
        t.plugin.updateFailed(error: normalizePluginInstallErrorMessage(e)),
      );
    }
  }

  Future<void> _updateDebugConfig({
    required bool enabled,
    required String url,
  }) async {
    await PluginRegistryService.I.updateDebugConfig(
      widget.pluginUuid,
      debug: enabled,
      debugUrl: url,
    );
    if (!mounted) return;
    showSuccessToast(t.plugin.debugConfigUpdated);
  }

  Future<void> _confirmDeletePlugin() async {
    if (_lifecycleBusy) return;
    if (_pendingFields.isNotEmpty ||
        _pendingActions.isNotEmpty ||
        _submittingWebCookie) {
      showInfoToast(t.pluginLifecycle.working);
      return;
    }
    setState(() {
      _lifecycleBusy = true;
      _confirmingRemoval = true;
    });
    final generation = ++_purgeGeneration;
    final local = LocalPluginInstallationState.instance;
    final epoch = local.installationEpoch(widget.pluginUuid);
    var cloudCompleted = false;
    PluginRemovalScope? scope;
    void guard() {
      if (!mounted ||
          generation != _purgeGeneration ||
          local.installationEpoch(widget.pluginUuid) != epoch ||
          local.isInstalling(widget.pluginUuid)) {
        throw const PluginLifecycleChanged();
      }
    }

    try {
      scope = await showPluginRemovalScope(
        context,
        pluginName: widget.pluginDisplayName,
      );
      if (scope == null || !mounted) return;
      guard();
      if (!await confirmPluginRemoval(
            context,
            pluginName: widget.pluginDisplayName,
            scope: scope,
          ) ||
          !mounted)
        return;
      guard();
      setState(() => _confirmingRemoval = false);
      await _stopWebLoginFlow();
      _stopExternalChromiumLoginFlow();
      if (!scope.local) {
        await PluginRegistryService.I.deletePlugin(
          widget.pluginUuid,
          expectedInstallationEpoch: epoch,
        );
      } else {
        final adapter = scope.cloud
            ? createSyncArchiveAdapter(context.read<GlobalSettingCubit>().state)
            : null;
        if (scope.cloud && adapter == null) {
          showInfoToast(t.pluginLifecycle.deleteCloudUnconfigured);
          return;
        }
        final result = await clearPluginPersonalData(
          widget.pluginUuid,
          expectedEpoch: epoch,
          // Cloud deletion is completed now, not represented by future-sync
          // tombstones. Local clearing uses the existing physical-delete path.
          choice: const PluginDataRemovalChoice(
            cloudDelete: false,
            includeDownloads: true,
          ),
          removeInstallation: true,
          beforeLocalMutation: scope.cloud
              ? () async {
                  Future<void> purge() => purgeCloudPluginAccountData(
                    adapter!,
                    widget.pluginUuid,
                    guard: guard,
                  );
                  try {
                    await purge();
                  } on CloudPluginPurgeFailure catch (error) {
                    final cause = error.cause;
                    if (error.mayHaveChanged ||
                        cause is! BackupProtectionException ||
                        cause.code != 'backup_locked')
                      rethrow;
                    guard();
                    if (!await unlockCloudBackupProtection(context))
                      throw const BackupProtectionCancelled();
                    guard();
                    await purge();
                  }
                  cloudCompleted = true;
                }
              : null,
        );
        if (!local.isRemoved(widget.pluginUuid)) {
          throw StateError(
            'Local data committed but plugin removal is incomplete',
          );
        }
        if (!mounted) return;
        context.read<PluginSettingsCubit>().resetAfterPersonalDataClear();
        _fieldErrors.clear();
        if (result.cleanupPending) {
          showInfoToast(t.pluginLifecycle.cleanupPending);
          return;
        }
      }
      if (!mounted) return;
      showSuccessToast(t.pluginLifecycle.removed);
      if (ModalRoute.of(context)?.isCurrent == true &&
          Navigator.of(context).canPop())
        Navigator.of(context).pop();
    } on BackupProtectionCancelled {
      // Unlock cancellation happens before the local journal or data mutations.
    } catch (error) {
      if (!mounted) return;
      showErrorToast(
        cloudCompleted
            ? t.pluginLifecycle.cloudDeleteCompleteLocalFailed
            : scope?.cloud == true
            ? t.pluginLifecycle.cloudDeleteFailed
            : error is ManagedVideoResourceBusy
            ? t.backupSecurity.localVideoInUse
            : error is PluginLifecycleChanged
            ? t.pluginLifecycle.changed
            : t.pluginLifecycle.removeFailed,
      );
    } finally {
      _purgeGeneration++;
      if (mounted) {
        setState(() {
          _lifecycleBusy = false;
          _confirmingRemoval = false;
        });
      }
    }
  }

  Future<void> _runAction(
    BuildContext context,
    Map<String, dynamic> action,
  ) async {
    if (_lifecycleBusy) return;
    final fnPath = action['fnPath']?.toString() ?? '';
    final source = widget.from;
    final epoch = LocalPluginInstallationState.instance.installationEpoch(
      widget.pluginUuid,
    );
    if (!mounted ||
        !isUserFacingPluginSettingsAction(action) ||
        _pendingActions.contains(fnPath)) {
      return;
    }
    final sessionChange = action['sessionChange'] == true;
    final cubit = context.read<PluginSettingsCubit>();
    final copyAutoMeasurement =
        source == PluginAccountAuthenticationService.copy &&
        fnPath == 'testLineSpeeds' &&
        cubit.state.values['api.domain'] == 'auto';
    final jmMeasurement =
        source == PluginAccountAuthenticationService.jm &&
        fnPath == 'measureEndpointSpeeds';
    final resumeAccount =
        (copyAutoMeasurement || jmMeasurement) && cubit.state.loadingUserInfo;
    final endpointUpdate = copyAutoMeasurement || jmMeasurement
        ? beginPluginEndpointUpdate(source, supersede: copyAutoMeasurement)
        : null;
    if (jmMeasurement && endpointUpdate == null) return;
    bool currentEndpoint() =>
        endpointUpdate == null ||
        endpointUpdate == pluginEndpointRevision(source);
    var effectiveRouteChanged = false;
    final readGeneration = _webLoginReadGeneration(
      source,
      fnPath,
      sessionChange,
    );
    setState(() => _pendingActions.add(fnPath));
    try {
      final result = await callUnifiedComicPlugin(
        from: source,
        fnPath: fnPath,
        sessionChange: sessionChange,
        core: const <String, dynamic>{},
        extern: const <String, dynamic>{},
      );
      final data = asJsonMap(result['data']);
      if (result['ok'] == false ||
          result['success'] == false ||
          data['ok'] == false ||
          data['success'] == false) {
        throw StateError(t.error.operationFailed);
      }
      if (!mounted ||
          _lifecycleBusy ||
          !currentEndpoint() ||
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) !=
              epoch) {
        return;
      }
      effectiveRouteChanged = data['effectiveRouteChanged'] == true;
      final handledWebLogin = await _maybeHandleWebLoginResult(
        result,
        source: source,
        installationEpoch: epoch,
        readGeneration: readGeneration,
      );
      if (!mounted || !currentEndpoint()) return;
      if (!handledWebLogin) {
        if (jmMeasurement) {
          // Completing the measurement is not evidence that a route works.
          // Read the measured results, including those from older bundles.
          final api = data['api'] is List ? data['api'] as List : const [];
          final images = data['image'] is List
              ? data['image'] as List
              : const [];
          bool passed(Object? value) => asJsonMap(value)['ok'] == true;
          final anyPassed = [...api, ...images].any(passed);
          if (!anyPassed) {
            showErrorToast(t.plugin.lineTestFailure);
          } else if (api.isEmpty ||
              images.isEmpty ||
              ![...api, ...images].every(passed)) {
            showWarningToast(t.plugin.lineTestPartial);
          } else {
            showSuccessToast(t.plugin.lineTestSuccess);
          }
        } else {
          final message =
              result['message']?.toString() ?? t.plugin.executeSuccess;
          showSuccessToast(message);
        }
      }
      if ((source == PluginAccountAuthenticationService.copy &&
              fnPath == 'testLineSpeeds') ||
          jmMeasurement) {
        // The schema reflects the last measurement. The endpoint fence
        // separately refreshes the account if Auto actually changed lines.
        await cubit.load(widget.from, refreshAccount: false);
      }
    } catch (e) {
      if (mounted && currentEndpoint()) {
        showErrorToast(
          t.plugin.executeFailed(error: userFacingErrorMessage(e)),
        );
      }
    } finally {
      if (endpointUpdate != null) {
        finishPluginEndpointUpdate(
          source,
          endpointUpdate,
          refreshSettings:
              resumeAccount || (jmMeasurement && effectiveRouteChanged),
          refreshProfile: copyAutoMeasurement && effectiveRouteChanged,
        );
      }
      if (mounted) setState(() => _pendingActions.remove(fnPath));
    }
  }

  Future<void> _commitField(Map<String, dynamic> field, dynamic value) async {
    if (_lifecycleBusy) return;
    if (isInternalPluginMaintenanceFunction(field['fnPath'])) return;
    final identity = pluginSettingsFieldIdentity(field);
    // Callbacks retained by a closing menu share this guard with current rows.
    if (!mounted || _pendingFields.contains(identity)) return;
    final key = field['key']?.toString() ?? '';
    final fnPath = field['fnPath']?.toString().trim() ?? '';
    final persist = field['persist'] != false;
    final source = widget.from;
    final runtime = widget.pluginRuntimeName;
    if (persist &&
        key.isNotEmpty &&
        const DeepCollectionEquality().equals(
          context.read<PluginSettingsCubit>().state.values[key],
          value,
        ))
      return;
    final epoch = LocalPluginInstallationState.instance.installationEpoch(
      widget.pluginUuid,
    );
    final sessionChange = field['sessionChange'] == true;
    final readGeneration = _webLoginReadGeneration(
      source,
      fnPath,
      sessionChange,
    );
    final appliesJmNetwork =
        source == PluginAccountAuthenticationService.jm &&
        fnPath == 'onNetworkChanged' &&
        (key == 'network.apiBase' || key == 'network.imageBase');
    if (appliesJmNetwork && isPluginEndpointUpdating(source)) return;
    final appliesJmApiLine = appliesJmNetwork && key == 'network.apiBase';
    final mayMeasureJmApi =
        appliesJmNetwork && key == 'network.imageBase' && value == '';
    final appliesJmEndpoint = appliesJmApiLine || mayMeasureJmApi;
    final appliesCopyNetwork =
        !persist &&
        source == PluginAccountAuthenticationService.copy &&
        fnPath == 'saveSettings' &&
        (key == 'api.domain' || key == 'api.platform');
    final cubit = context.read<PluginSettingsCubit>();
    final hadAccountRead = cubit.state.loadingUserInfo;
    final endpointUpdate = appliesJmEndpoint || appliesCopyNetwork
        ? beginPluginEndpointUpdate(source, supersede: appliesCopyNetwork)
        : null;
    if (appliesJmEndpoint && endpointUpdate == null) return;
    bool currentEndpoint() =>
        endpointUpdate == null ||
        endpointUpdate == pluginEndpointRevision(source);
    var fieldCommitted = false;
    var savingLocally = false;
    var handledWebLogin = false;
    bool? effectiveRouteChanged;
    setState(() {
      _pendingFields.add(identity);
      _fieldErrors.remove(identity);
    });
    try {
      if (fnPath.isNotEmpty) {
        final result = await callUnifiedComicPlugin(
          from: source,
          fnPath: fnPath,
          sessionChange: sessionChange,
          core: {'key': key, 'value': value},
          extern: const <String, dynamic>{},
        );
        final data = asJsonMap(result['data']);
        if (result['ok'] == false ||
            result['success'] == false ||
            data['ok'] == false ||
            data['success'] == false) {
          throw StateError(
            result['message']?.toString() ??
                data['message']?.toString() ??
                t.error.saveFailed,
          );
        }
        if (!mounted ||
            source != widget.from ||
            runtime != widget.pluginRuntimeName ||
            _lifecycleBusy ||
            !currentEndpoint() ||
            LocalPluginInstallationState.instance.installationEpoch(
                  widget.pluginUuid,
                ) !=
                epoch) {
          return;
        }
        final routeChange = data['effectiveRouteChanged'];
        if (routeChange is bool) effectiveRouteChanged = routeChange;
        handledWebLogin = await _maybeHandleWebLoginResult(
          result,
          source: source,
          installationEpoch: epoch,
          readGeneration: readGeneration,
        );
      }
      if (!mounted ||
          source != widget.from ||
          runtime != widget.pluginRuntimeName ||
          _lifecycleBusy ||
          !currentEndpoint() ||
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) !=
              epoch) {
        return;
      }
      if (persist && key.isNotEmpty) {
        // This awaits the bridge's ObjectBox transaction, not a Cubit-only value.
        savingLocally = true;
        await savePluginConfigValue(runtime, key, value);
        final actual = loadPluginConfigValue<dynamic>(
          runtime,
          key,
          fallback: null,
        );
        if (!const DeepCollectionEquality().equals(actual, value)) {
          throw StateError(t.error.saveFailed);
        }
      }
      if (!mounted ||
          source != widget.from ||
          runtime != widget.pluginRuntimeName ||
          _lifecycleBusy ||
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) !=
              epoch)
        return;
      if (persist && key.isNotEmpty) {
        cubit.saveFieldValue(key, value);
      }
      fieldCommitted = true;
      if (appliesCopyNetwork || appliesJmNetwork) {
        await cubit.load(source, refreshAccount: false);
      }
      if (!mounted || !currentEndpoint()) return;
      if (!handledWebLogin) {
        showActionFeedback(
          context,
          persist || appliesCopyNetwork
              ? t.common.saved
              : t.plugin.executeSuccess,
        );
      }
    } catch (error) {
      if (mounted &&
          source == widget.from &&
          runtime == widget.pluginRuntimeName &&
          !_lifecycleBusy &&
          currentEndpoint() &&
          LocalPluginInstallationState.instance.installationEpoch(
                widget.pluginUuid,
              ) ==
              epoch) {
        setState(
          () => _fieldErrors[identity] = savingLocally
              ? t.error.saveFailed
              : _fieldSaveError(field, error),
        );
        showErrorToast(t.error.saveFailed, context: context);
      }
    } finally {
      if (endpointUpdate != null) {
        final resumeAccount =
            hadAccountRead &&
            (appliesCopyNetwork ||
                mayMeasureJmApi ||
                (appliesJmApiLine && fieldCommitted));
        finishPluginEndpointUpdate(
          source,
          endpointUpdate,
          refreshSettings:
              resumeAccount ||
              (!appliesCopyNetwork &&
                  fieldCommitted &&
                  (effectiveRouteChanged ??
                      (appliesJmApiLine && widget.readOnlyAccount))),
          refreshProfile: appliesCopyNetwork && effectiveRouteChanged == true,
        );
      }
      if (mounted) setState(() => _pendingFields.remove(identity));
    }
  }

  String _fieldSaveError(Map<String, dynamic> field, Object error) {
    // Third-party exceptions may echo submitted credentials. Never log them or
    // render credential fields' raw errors, even when their message is short.
    final key = field['key']?.toString().toLowerCase() ?? '';
    final text = error.toString();
    final sensitive =
        field['kind'] == 'password' ||
        RegExp(
          r'password|passwd|token|secret|cookie|credential|authorization',
        ).hasMatch(key) ||
        RegExp(
          r'password|passwd|token|secret|cookie|authorization',
          caseSensitive: false,
        ).hasMatch(text);
    if (sensitive) return t.error.saveFailed;
    return '${t.error.saveFailed} · ${userFacingErrorMessage(error)}';
  }
}
