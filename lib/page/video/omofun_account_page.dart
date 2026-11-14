import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';
import 'package:zephyr/page/video/omofun_site_history_preview.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/omofun_native_history_scope.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/video/omofun_notice_page.dart';
import 'dart:io';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/omofun_account_details_page.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/page/video/omo_native_login.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'dart:typed_data';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/util/json/json_value.dart';

bool videoCredentialsMayFill(Uri home, Uri? page) =>
    VideoAccountCredentials.validOrigin(home) &&
    page != null &&
    VideoAccountCredentials.validOrigin(page) &&
    page.origin == home.origin &&
    page.path.contains('/login');

String videoCredentialsFillScript(Uri home, VideoAccountCredentials saved) =>
    """
(() => {
  if (location.origin !== ${jsonEncode(home.origin)} || !location.pathname.includes('/login')) return false;
  const password = document.querySelector('input[type="password"]');
  const form = password && password.form;
  const account = form && form.querySelector('input[autocomplete="username"], input[type="email"], input[name="username"], input[name="account"], input[name="user_name"], input[type="text"]');
  if (!account || !password) return false;
  if (account.value || password.value) return true;
  const set = (el, value) => { const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; setter.call(el, value); el.dispatchEvent(new Event('input', {bubbles:true})); el.dispatchEvent(new Event('change', {bubbles:true})); };
  set(account, ${jsonEncode(saved.account)}); set(password, ${jsonEncode(saved.password)}); return true;
})()
""";

String omoSiteError(Object? error) => switch (error) {
  OmoSiteException(kind: 'signedOut') => t.videoSource.loginRequired,
  OmoSiteException(kind: 'verification' || 'notReady') =>
    t.videoSource.verifyRequired,
  OmoSiteException(kind: 'unconfirmed') => t.videoSource.actionUnconfirmed,
  _ => t.videoSource.readFailed,
};

Future<void> openOmoSitePage(
  BuildContext context,
  OmoSiteClient client, {
  required String title,
  required String path,
  Future<OmoNetworkContext?>? network,
  String? credentialSource,
  String? recoveryUsername,
}) async {
  final source = credentialSource?.trim().isNotEmpty == true
      ? credentialSource!.trim()
      : omoNetworkSource;
  final inherited = VideoNetworkScope.maybeOf(context);
  network ??= inherited?.source == source ? inherited?.network : null;
  Future<OmoNetworkContext?>? owned;
  if (network == null) {
    owned =
        OmoNetworkContext.open(
          null,
          source: source,
          siteOrigins: [client.home],
        ).then((value) {
          if (defaultTargetPlatform == TargetPlatform.iOS && value == null)
            throw const OmoSiteException('unavailable');
          return value;
        });
    network = owned;
  }
  try {
    await Navigator.of(context).push<void>(
      videoPageRoute(
        networkSource: source,
        network: network,
        builder: (_) => OmoSiteWebPage(
          home: client.home,
          url: client.home.resolve(path),
          title: title,
          client: client,
          network: network,
          finishOnSignIn: path.contains('/login'),
          credentialSource: credentialSource,
          recoveryUsername: recoveryUsername,
        ),
      ),
    );
  } finally {
    if (owned != null) {
      await owned.then<void>((owner) async {
        await owner?.close();
      }, onError: (Object _) {});
    }
  }
}

Future<void> openOmoAccountDetails(
  BuildContext context,
  OmoSiteClient client, {
  String source = '',
  Future<OmoNetworkContext?>? network,
}) async {
  network ??= VideoNetworkScope.maybeOf(context)?.network;
  final capturedNetwork = network;
  await Navigator.of(context).push<void>(
    videoPageRoute(
      networkSource: omoNetworkSource,
      network: network,
      settings: const RouteSettings(name: 'breeze.omo.account'),
      builder: (_) => OmoAccountDetailsPage(
        client: client,
        source: source,
        onWebsite: (pageContext, path, title) => openOmoSitePage(
          pageContext,
          client,
          title: title,
          path: path,
          network: capturedNetwork,
          credentialSource: source.isEmpty ? null : source,
        ),
      ),
    ),
  );
}

/// Authentication and source-only account maintenance stay in the site's
/// normal flow. Global account backup uses only this source's filtered session.
/// The explicit close returns to native UI; source clicks never switch modes.
class OmoSiteWebPage extends StatefulWidget {
  const OmoSiteWebPage({
    super.key,
    required this.home,
    required this.url,
    required this.title,
    this.client,
    this.network,
    this.finishOnSignIn = false,
    this.credentialSource,
    this.recoveryUsername,
    this.browsingSource,
  });
  final Uri home, url;
  final Future<OmoNetworkContext?>? network;
  final String title;
  final String? credentialSource;
  final String? recoveryUsername;

  /// Owns website browsing data when the route has no account task.
  final String? browsingSource;
  final OmoSiteClient? client;
  final bool finishOnSignIn;
  @override
  State<OmoSiteWebPage> createState() => _OmoSiteWebPageState();
}

class _OmoSiteWebPageState extends State<OmoSiteWebPage> {
  InAppWebViewController? _web;
  int _progress = 0;
  bool _failed = false;
  bool _checkingLogin = false,
      _finishingLogin = false,
      _loginCheckPending = false;
  Timer? _loginTimer;
  Object? _accountLease;
  final _verification = TextEditingController();
  Uint8List? _captchaBytes;
  bool _forceWebsite = false,
      _nativeSupported = false,
      _readingNative = false,
      _nativeChecked = false,
      _nativeSending = false;
  int _nativeEpoch = 0, _nativeRevision = 0;
  String _nativeFailure = '';
  String? _submittedAccount;
  VideoAccountCredentials? _nativeDraft;
  String get _accountSource =>
      widget.credentialSource?.trim().isNotEmpty == true
      ? widget.credentialSource!.trim()
      : omoNetworkSource;

  Future<PluginAccountAuthentication?> _accountIdentityForBackup() async {
    final web = _web, client = widget.client;
    if (!mounted || web == null || client == null || _failed) return null;
    final page = Uri.tryParse((await web.getUrl())?.toString() ?? '');
    if (page == null || page.origin != widget.home.origin) return null;
    final account = await client.readAccount(
      includeProfile: true,
      read: (operation, parameters) async {
        final raw = await videoBrowserReadAsync(
          web,
          '(async (operation, parameters, origin) => {$omoSiteRequestScript})'
          '(${jsonEncode(operation)},${jsonEncode(parameters)},${jsonEncode(widget.home.origin)})',
        ).timeout(const Duration(seconds: 15));
        return asJsonMap(raw is String ? jsonDecode(raw) : raw);
      },
    );
    if (mounted && identical(web, _web) && account == null)
      throw const PluginAccountAuthenticationRejected();
    return mounted && identical(web, _web) && account != null
        ? PluginAccountAuthentication(
            serverIdentity: account.id,
            label: account.name,
            origin: widget.home.origin,
            publicSummary: {
              'extern': {
                if (account.loginName != null) 'username': account.loginName,
              },
            },
          )
        : null;
  }

  Future<void> _registerAccountBrowser(InAppWebViewController web) async {
    final cookies = videoSiteAccountCookies(web);
    if (cookies == null) return;
    final coordinator = PluginAccountSyncCoordinator.instance;
    final lease = await coordinator.registerStoredSession(
      source: _accountSource,
      origin: widget.home,
      cookies: cookies,
      identity: _accountIdentityForBackup,
      authenticated: () async => await _accountIdentityForBackup() != null,
    );
    if (!mounted || !identical(web, _web)) {
      coordinator.unregister(_accountSource, lease);
      return;
    }
    _accountLease = lease;
    await coordinator.restoreOnEntry(_accountSource);
  }

  void _scheduleLoginCheck() {
    if (!widget.finishOnSignIn ||
        _finishingLogin ||
        (!_forceWebsite && _submittedAccount == null))
      return;
    if (_checkingLogin) {
      _loginCheckPending = true;
      return;
    }
    _loginTimer?.cancel();
    _loginTimer = Timer(const Duration(milliseconds: 500), _checkLogin);
  }

  Future<void> _checkLogin() async {
    final web = _web, client = widget.client;
    if (!widget.finishOnSignIn ||
        web == null ||
        client == null ||
        _checkingLogin ||
        _finishingLogin ||
        !mounted) {
      return;
    }
    _checkingLogin = true;
    try {
      final account = await client.readAccount(
        includeProfile: true,
        read: (operation, parameters) async {
          final raw = await videoBrowserReadAsync(
            web,
            '(async (operation, parameters, origin) => {$omoSiteRequestScript})'
            '(${jsonEncode(operation)},${jsonEncode(parameters)},${jsonEncode(widget.home.origin)})',
          ).timeout(const Duration(seconds: 15));
          return asJsonMap(raw is String ? jsonDecode(raw) : raw);
        },
      );
      if (mounted &&
          account != null &&
          (_submittedAccount == null ||
              account.loginName == _submittedAccount)) {
        await _saveNativeDraft(account);
        if (!mounted) return;
        _finishingLogin = true;
        _loginTimer?.cancel();
        try {
          await PluginAccountSyncCoordinator.instance.captureAuthenticated(
            _accountSource,
            explicitSave: true,
          );
        } catch (_) {
          // A backup failure must not misreport the website's confirmed login.
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // An unfinished form or challenge stays visible in its normal flow.
    } finally {
      _checkingLogin = false;
      if (_loginCheckPending && mounted) {
        _loginCheckPending = false;
        _scheduleLoginCheck();
      }
    }
  }

  Future<void> _saveNativeDraft(OmoSiteAccount account) async {
    final draft = _nativeDraft;
    if (draft == null || account.loginName != draft.account) return;
    final source = _accountSource;
    final generation = pluginSessionWriteFence.generation(source);
    final credentials = {
      'version': 1,
      'deleted': false,
      'origin': draft.origin.origin,
      'account': draft.account,
      'password': draft.password,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    PluginAccountProfiles.read(source);
    if (pluginSessionWriteFence.isChanging(source)) {
      final active = activePluginAccountSnapshot(
        readHostPluginConfiguration(source),
      );
      final target = VideoAccountCredentials.decode(
        active['account.credentials'],
        draft.origin,
      );
      final pending = active['account.backup'];
      final manualTarget =
          target == null &&
          pending is Map &&
          pending['requiresLogin'] == true &&
          pending['origin'] == draft.origin.origin &&
          pending['serverIdentity'] == account.id;
      if (target?.account != draft.account && !manualTarget)
        throw const PluginSessionChanged();
      replaceActivePluginAccount(
        source,
        {...active, 'account.credentials': credentials},
        expectedDigest: accountProfileDigest(active),
        expectedGeneration: generation,
      );
    } else {
      await savePluginConfigValue(
        source,
        VideoAccountCredentials.key,
        credentials,
      );
    }
    if (!mounted || pluginSessionWriteFence.generation(source) != generation)
      throw const PluginSessionChanged();
    _nativeDraft = null;
  }

  Future<void> _readNativeLogin({bool refreshCaptcha = false}) async {
    final web = _web;
    if (!widget.finishOnSignIn || web == null || _readingNative) return;
    final epoch = ++_nativeEpoch,
        generation = pluginSessionWriteFence.generation(_accountSource);
    setState(() => _readingNative = true);
    try {
      final raw = asJsonMap(
        await videoBrowserReadAsync(
          web,
          omoNativeLoginSnapshot(widget.home, refreshCaptcha: refreshCaptcha),
        ).timeout(const Duration(seconds: 12)),
      );
      if (!mounted ||
          epoch != _nativeEpoch ||
          generation != pluginSessionWriteFence.generation(_accountSource) ||
          !identical(web, _web))
        return;
      Uint8List? bytes;
      final encoded = raw['captchaData'];
      if (encoded is String &&
          encoded.length <= 180000 &&
          encoded.startsWith('data:image/')) {
        bytes = UriData.parse(encoded).contentAsBytes();
      }
      setState(() {
        _nativeSupported = raw['supported'] == true;
        _nativeChecked = true;
        _captchaBytes = bytes;
        if (refreshCaptcha) _verification.clear();
      });
    } catch (_) {
      if (mounted && epoch == _nativeEpoch)
        setState(() {
          _nativeChecked = true;
          _captchaBytes = null;
        });
    } finally {
      if (mounted && epoch == _nativeEpoch)
        setState(() => _readingNative = false);
    }
  }

  Future<void> _readNativeLoginDocument() async {
    // A signed-in visit may redirect /user/login to its account page. Read that
    // same document before asking it for a login form. A switch transaction is
    // different: its old identity must never confirm the requested new account.
    if (_submittedAccount == null &&
        !pluginSessionWriteFence.isChanging(_accountSource)) {
      await _checkLogin();
      if (!mounted || _finishingLogin) return;
    }
    await _readNativeLogin();
  }

  Future<String> _submitNative(
    String account,
    String password,
    String _,
    bool __,
  ) async {
    final web = _web;
    if (web == null ||
        !_nativeSupported ||
        _captchaBytes == null ||
        _verification.text.trim().isEmpty)
      return 'unsupported';
    final generation = pluginSessionWriteFence.generation(_accountSource);
    _submittedAccount = account;
    _nativeDraft = VideoAccountCredentials(account, password, widget.home);
    setState(() {
      _nativeSending = true;
      _nativeFailure = '';
    });
    try {
      final raw = asJsonMap(
        await videoBrowserReadAsync(
          web,
          omoNativeLoginSubmit(
            widget.home,
            account: account,
            password: password,
            verification: _verification.text.trim(),
          ),
        ).timeout(const Duration(seconds: 21)),
      );
      if (!mounted ||
          generation != pluginSessionWriteFence.generation(_accountSource) ||
          !identical(web, _web))
        return 'unconfirmed';
      if (raw['status'] == 'accepted') {
        await _checkLogin();
        if (!mounted || _finishingLogin) return 'submitted';
      }
      final reason = raw['reason'];
      setState(() {
        _nativeFailure =
            const {'credentials', 'verification', 'rejected'}.contains(reason)
            ? reason as String
            : 'unknown';
        _nativeRevision++;
      });
      if (raw['status'] == 'rejected' || raw['status'] == 'unsupported')
        _nativeDraft = null;
      await _readNativeLogin(refreshCaptcha: true);
      return 'submitted'; // The new revision carries the actual rejected/unknown state.
    } catch (_) {
      if (mounted &&
          generation == pluginSessionWriteFence.generation(_accountSource)) {
        setState(() {
          _nativeFailure = 'unknown';
          _nativeRevision++;
        });
      }
      return 'unconfirmed';
    } finally {
      if (mounted && identical(web, _web))
        setState(() => _nativeSending = false);
    }
  }

  Widget _nativeLogin(BuildContext context) {
    if (!_nativeSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_nativeChecked || _readingNative)
                const CircularProgressIndicator()
              else
                Text(
                  _failed
                      ? t.videoSource.readFailed
                      : t.videoCommunity.unsupported,
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _readingNative ? null : () => _readNativeLogin(),
                child: Text(t.common.retry),
              ),
              TextButton(
                onPressed: () => setState(() => _forceWebsite = true),
                child: Text(t.videoPlayback.backToWeb),
              ),
            ],
          ),
        ),
      );
    }
    return NativeVideoAuthForm(
      registration: false,
      hasRemember: false,
      accountIsEmail: false,
      allowRegistration: false,
      loginUsername: widget.recoveryUsername,
      credentials: widget.recoveryUsername == null
          ? VideoAccountCredentials.load(_accountSource, widget.home)
          : null,
      siteRejected: _nativeFailure.isNotEmpty,
      siteErrorKind: _nativeFailure,
      revision: _nativeRevision,
      allowRetryAfterRejection: const {
        'credentials',
        'verification',
        'rejected',
      }.contains(_nativeFailure),
      submit: _submitNative,
      onChangeMode: () {},
      onWebsite: () => setState(() => _forceWebsite = true),
      verification: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _verification,
            enabled: !_nativeSending,
            maxLength: 32,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: t.videoCommunity.captcha),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : t.videoCommunity.required,
          ),
          Semantics(
            button: true,
            label: t.login.captchaTapToRefresh,
            child: InkWell(
              onTap: _nativeSending || _readingNative
                  ? null
                  : () => _readNativeLogin(refreshCaptcha: true),
              child: SizedBox(
                height: 64,
                child: _readingNative
                    ? const Center(child: CircularProgressIndicator())
                    : _captchaBytes == null
                    ? Center(child: Text(t.login.captchaLoadFailed))
                    : Image.memory(_captchaBytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fillCredentials({bool silent = false}) async {
    final web = _web, source = widget.credentialSource;
    if (web == null || source == null || widget.recoveryUsername != null) {
      return;
    }
    final saved = VideoAccountCredentials.load(source, widget.home);
    if (saved == null) return;
    try {
      final url = Uri.tryParse((await web.getUrl())?.toString() ?? '');
      if (!videoCredentialsMayFill(widget.home, url)) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.videoCommunity.credentialsUnavailable)),
          );
        }
        return;
      }
      final result = await web.evaluateJavascript(
        source: videoCredentialsFillScript(widget.home, saved),
      );
      if (mounted && result != true && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.videoCommunity.credentialsUnavailable)),
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.videoCommunity.credentialsUnavailable)),
        );
      }
    }
  }

  @override
  void dispose() {
    _nativeEpoch++;
    _nativeDraft = null;
    _captchaBytes = null;
    _verification.clear();
    _verification.dispose();
    _loginTimer?.cancel();
    final lease = _accountLease;
    if (lease != null)
      PluginAccountSyncCoordinator.instance.unregister(_accountSource, lease);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OmoNetworkContext?>(
    future: widget.network,
    builder: (context, snapshot) =>
        widget.network != null &&
            snapshot.connectionState != ConnectionState.done
        ? _networkStatus(loading: true)
        : snapshot.hasError
        ? _networkStatus(loading: false)
        : _buildPage(context, snapshot.data),
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

  Widget _buildPage(
    BuildContext context,
    OmoNetworkContext? network,
  ) => Scaffold(
    appBar: AppBar(
      leading: const SourceBackButton(),
      title: Text(widget.title),
      actions: [
        if (widget.finishOnSignIn &&
            _forceWebsite &&
            widget.recoveryUsername == null &&
            widget.credentialSource != null &&
            VideoAccountCredentials.load(
                  widget.credentialSource!,
                  widget.home,
                ) !=
                null)
          IconButton(
            tooltip: t.videoCommunity.fillCredentials,
            icon: const Icon(Icons.key_outlined),
            onPressed: () => _fillCredentials(),
          ),
        SourceChromeIconButton(
          tooltip: t.common.retry,
          symbol: 'arrow.clockwise',
          icon: Icons.refresh_rounded,
          onPressed: () {
            setState(() => _failed = false);
            unawaited(
              _web?.loadUrl(
                    urlRequest: URLRequest(url: WebUri(widget.url.toString())),
                  ) ??
                  Future<void>.value(),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.done),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_progress < 100 && !_failed)
            LinearProgressIndicator(value: _progress / 100),
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.videoSource.readFailed),
            ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: widget.finishOnSignIn && !_forceWebsite,
                  child: VideoSiteBrowser(
                    home: widget.home,
                    source: widget.browsingSource ?? _accountSource,
                    networkContext: network?.token,
                    configuration: InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        useShouldOverrideUrlLoading: true,
                      ),
                      onWebViewCreated: (web) async {
                        _web = web;
                        if (widget.browsingSource == null) {
                          try {
                            await _registerAccountBrowser(web);
                          } catch (_) {}
                        }
                        if (!mounted || !identical(web, _web)) return;
                        await web.loadUrl(
                          urlRequest: URLRequest(
                            url: WebUri(widget.url.toString()),
                          ),
                        );
                      },
                      onProgressChanged: (_, progress) {
                        if (mounted) setState(() => _progress = progress);
                      },
                      onLoadStart: (_, _) {
                        if (mounted) {
                          setState(() {
                            _failed = false;
                            _progress = 0;
                            if (widget.finishOnSignIn) {
                              _nativeEpoch++;
                              _readingNative = false;
                              _nativeFailure = '';
                              _nativeRevision++;
                              _verification.clear();
                              _captchaBytes = null;
                            }
                          });
                        }
                      },
                      onLoadStop: (_, _) {
                        if (widget.finishOnSignIn && !_nativeSending)
                          unawaited(_readNativeLoginDocument());
                        if (mounted) setState(() => _progress = 100);
                        if (widget.finishOnSignIn &&
                            _forceWebsite &&
                            widget.credentialSource != null) {
                          unawaited(_fillCredentials(silent: true));
                        }
                        _scheduleLoginCheck();
                      },
                      onUpdateVisitedHistory: (_, _, _) =>
                          _scheduleLoginCheck(),
                      onReceivedError: (_, request, error) {
                        if (request.isForMainFrame == true &&
                            error.type != WebResourceErrorType.CANCELLED &&
                            mounted) {
                          setState(() => _failed = true);
                        }
                      },
                      shouldOverrideUrlLoading: (_, action) async =>
                          allowVideoSiteNavigation(
                            widget.home,
                            Uri.tryParse(action.request.url?.toString() ?? ''),
                            isMainFrame: action.isForMainFrame,
                          )
                          ? NavigationActionPolicy.ALLOW
                          : NavigationActionPolicy.CANCEL,
                    ),
                  ),
                ),
                if (widget.finishOnSignIn && !_forceWebsite)
                  _nativeLogin(context),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class OmoAccountPage extends StatefulWidget {
  const OmoAccountPage({
    super.key,
    required this.client,
    this.source = '',
    required this.active,
    required this.onLocalHistory,
    this.localFavorites,
    this.onSiteFollows,
  });
  final OmoSiteClient client;
  final String source;
  final bool active;
  final VoidCallback onLocalHistory;
  final Widget? localFavorites;
  final Future<void> Function()? onSiteFollows;
  @override
  State<OmoAccountPage> createState() => _OmoAccountPageState();
}

class _OmoAccountPageState extends State<OmoAccountPage> {
  bool _loading = false;
  Object? _error;
  int _epoch = 0;
  int _avatarRefresh = 0;
  bool _appearanceBusy = false, _accountOpening = false;
  StreamSubscription<String>? _identityChanges;
  int? _identityGeneration;
  String? _identityFingerprint;
  bool _identityReloadPending = false;

  @override
  void initState() {
    super.initState();
    if (widget.source.isNotEmpty) {
      _identityGeneration = pluginSessionWriteFence.generation(widget.source);
      _identityFingerprint = PluginAccountIdentities.fingerprint(widget.source);
      _identityChanges = PluginAccountIdentities.changes.listen((source) {
        if (!mounted || source != widget.source) return;
        final generation = pluginSessionWriteFence.generation(source),
            fingerprint = PluginAccountIdentities.fingerprint(source);
        final proof = PluginAccountIdentities.current(source),
            account = widget.client.account;
        final changed =
            generation != _identityGeneration ||
            fingerprint != _identityFingerprint;
        final confirmedOther =
            proof != null &&
            (account?.id != proof.serverIdentity ||
                proof.label.isNotEmpty && account?.name != proof.label);
        _identityGeneration = generation;
        _identityFingerprint = fingerprint;
        if (!changed && !confirmedOther) return;
        _epoch++;
        widget.client.invalidateAccount();
        _identityReloadPending = true;
        if (widget.active &&
            !pluginSessionWriteFence.isChanging(source) &&
            _readTask == null) {
          _identityReloadPending = false;
          unawaited(_read());
        }
      });
    }
    if (widget.active) _read();
    LocalAppearanceImages.instance.load().catchError((Object _) {});
  }

  @override
  void didUpdateWidget(covariant OmoAccountPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _read();
  }

  @override
  void dispose() {
    _epoch++;
    unawaited(_identityChanges?.cancel());
    super.dispose();
  }

  Future<void>? _readTask, _pullTask;
  bool _pullRefreshing = false;

  Future<void> _read() {
    final task = _readNow();
    _readTask = task;
    return task.whenComplete(() {
      if (identical(_readTask, task)) {
        _readTask = null;
        if (mounted &&
            widget.active &&
            _identityReloadPending &&
            !pluginSessionWriteFence.isChanging(widget.source)) {
          _identityReloadPending = false;
          unawaited(_read());
        }
      }
    });
  }

  Future<void> _refreshFromPull() {
    final pending = _pullTask;
    if (pending != null) {
      return pending;
    }
    setState(() => _pullRefreshing = true);
    final task = _readTask ?? _read();
    _pullTask = task;
    return task.whenComplete(() {
      if (identical(_pullTask, task)) {
        _pullTask = null;
        if (mounted) setState(() => _pullRefreshing = false);
      }
    });
  }

  Future<void> _readNow() async {
    final epoch = ++_epoch;
    final generation = pluginSessionWriteFence.generation(widget.source);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await widget.client.readAccount();
      if (mounted &&
          epoch == _epoch &&
          pluginSessionWriteFence.generation(widget.source) == generation) {
        _avatarRefresh++;
        if (widget.source.isNotEmpty) {
          if (account == null)
            PluginAccountIdentities.reject(
              widget.source,
              generation: generation,
            );
          else
            PluginAccountIdentities.confirm(
              widget.source,
              PluginAccountAuthentication(
                serverIdentity: account.id,
                label: account.name,
                origin: widget.client.home.origin,
                avatarUrl: account.avatar?.toString() ?? '',
                publicSummary: {
                  'lines': [
                    account.name,
                    if (account.group.isNotEmpty) account.group,
                    if (account.points != null)
                      '${t.omoAccount.points}: ${account.points}',
                  ],
                  'extern': {
                    if (account.loginName != null)
                      'username': account.loginName,
                    if (account.email != null) 'email': account.email,
                    if (account.points != null) 'points': account.points,
                  },
                },
              ),
              generation: generation,
            );
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('OmoAccountRead failure=${error.runtimeType}');
      if (mounted && epoch == _epoch) _error = error;
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _accountDetails() async {
    if (_accountOpening) return;
    _accountOpening = true;
    try {
      await openOmoAccountDetails(
        context,
        widget.client,
        source: widget.source,
      );
    } finally {
      _accountOpening = false;
    }
    if (mounted) await _read();
  }

  Future<void> _savedAccounts() async {
    if (_accountOpening) return;
    _accountOpening = true;
    try {
      await openPluginSavedAccounts(
        context,
        source: widget.source,
        prepareSession: () async {
          await widget.client.readAccount();
        },
        onAddAccount: () => openOmoSitePage(
          context,
          widget.client,
          title: t.videoSource.login,
          path: '/user/login',
          credentialSource: widget.source,
        ),
      );
    } finally {
      _accountOpening = false;
    }
    if (mounted) await _read();
  }

  Future<void> _settings() async {
    await openSourceSettings(
      context,
      source: widget.source,
      network: VideoNetworkScope.maybeOf(context)?.network,
    );
    if (mounted) await _read();
  }

  Future<void> _background() async {
    if (_appearanceBusy) return;
    final source = widget.source, revision = widget.client.revision;
    setState(() => _appearanceBusy = true);
    try {
      await pickLocalAppearanceImage(
        context,
        imageKey: 'profile:$source',
        title: t.omoAccount.chooseBackground,
        aspectRatio: 16 / 9,
        canCommit: () =>
            mounted &&
            widget.source == source &&
            widget.client.revision == revision,
      );
    } finally {
      if (mounted) setState(() => _appearanceBusy = false);
    }
  }

  Future<void> _openFollowing(OmoFavorite favorite) async {
    final open = OmoNativeHistoryScope.maybeOf(context)?.openEntry;
    if (open == null) throw const OmoSiteException('unavailable');
    await open(
      OmoHistoryEntry(url: favorite.item.detailUrl, title: favorite.item.title),
    );
  }

  Future<void> _following() async {
    if (widget.onSiteFollows case final open?) {
      await open();
      if (mounted) await _read();
      return;
    }
    final scope = OmoNativeHistoryScope.maybeOf(context);
    final open = scope?.openEntry,
        client = widget.client,
        source = widget.source;
    final mode = scope?.mode ?? ApiVideoView.list;
    await Navigator.of(context).push<void>(
      videoPageRoute(
        networkSource: omoNetworkSource,
        network: VideoNetworkScope.maybeOf(context)?.network,
        builder: (_) => Scaffold(
          body: OmoSiteFavoritesPage(
            standalone: true,
            client: client,
            source: source,
            active: true,
            mode: mode,
            onOpen: (item) async {
              if (!mounted ||
                  open == null ||
                  widget.client != client ||
                  widget.source != source)
                throw const OmoSiteException('unavailable');
              await open(
                OmoHistoryEntry(url: item.detailUrl, title: item.title),
              );
            },
          ),
        ),
      ),
    );
    if (mounted) await _read();
  }

  Future<void> _private(String kind) => Navigator.of(context).push<void>(
    videoPageRoute(
      networkSource: omoNetworkSource,
      network: VideoNetworkScope.maybeOf(context)?.network,
      builder: (_) => OmoPrivateIndexPage(
        client: widget.client,
        kind: kind,
        source: widget.source,
        mode: OmoNativeHistoryScope.maybeOf(context)?.mode ?? ApiVideoView.list,
        onOpenRecord: OmoNativeHistoryScope.maybeOf(context)?.openEntry,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.client,
    builder: (context, _) {
      final account = widget.client.account,
          theme = Theme.of(context),
          colors = theme.colorScheme;
      Widget entry(
        IconData icon,
        String title,
        VoidCallback action, {
        String? subtitle,
        Widget? badge,
      }) => TouchHoverIntent(
        identity: 'omo-my.$title',
        builder: (context, hover) => ListTile(
          hoverColor: hover.hoverColor(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minLeadingWidth: 24,
          horizontalTitleGap: 14,
          minVerticalPadding: 6,
          leading: Icon(icon, size: 24),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: badge ?? const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: action,
        ),
      );
      Widget group(String title, List<Widget> entries) => SettingSection(
        title: title,
        margin: const EdgeInsets.only(bottom: 12),
        children: entries,
      );
      return RefreshIndicator(
        onRefresh: _refreshFromPull,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            28 + NativeNavigationInset.scrollBottom(context),
          ),
          children: [
            ValueListenableBuilder<Map<String, String>>(
              valueListenable: LocalAppearanceImages.instance.paths,
              builder: (context, paths, _) {
                final path = paths['profile:${widget.source}'];
                final hasImage = path != null;
                final foreground = hasImage ? Colors.white : colors.onSurface;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      if (path != null)
                        Positioned.fill(
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 1000,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: colors.surfaceContainer),
                          ),
                        ),
                      if (hasImage)
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0x99000000)),
                        ),
                      Padding(
                        padding: EdgeInsets.all(hasImage ? 16 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Theme(
                              data: hasImage
                                  ? theme.copyWith(
                                      textTheme: theme.textTheme.apply(
                                        bodyColor: foreground,
                                        displayColor: foreground,
                                      ),
                                    )
                                  : theme,
                              child: VideoPersonalAccountHeader(
                                account: {
                                  'status': account == null
                                      ? 'unconfirmed'
                                      : 'signedIn',
                                  'name': account == null
                                      ? _loading
                                            ? t.common.loading
                                            : _error != null
                                            ? t.videoSource.readFailed
                                            : t.videoSource.notSignedIn
                                      : account.name,
                                  'summary': account?.group ?? '',
                                },
                                page: widget.client.home,
                                avatarKey: const ValueKey('omo-my.avatar'),
                                avatar: OmoAccountAvatar(
                                  client: widget.client,
                                  revision: _avatarRefresh,
                                  source: widget.source,
                                  size: 52,
                                ),
                                onAccountSettings: _accountDetails,
                              ),
                            ),
                            if (LocalAppearanceImages.pluginIconKey(
                                  widget.source,
                                ) !=
                                null)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton.icon(
                                  key: const ValueKey('omo-my.background'),
                                  onPressed: _appearanceBusy
                                      ? null
                                      : _background,
                                  icon: Icon(
                                    Icons.wallpaper_outlined,
                                    size: 18,
                                    color: foreground,
                                  ),
                                  label: Text(
                                    t.omoAccount.changeBackground,
                                    style: TextStyle(color: foreground),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 4,
              child: _loading && !_pullRefreshing
                  ? MediaQuery.disableAnimationsOf(context)
                        ? const LinearProgressIndicator(value: .5)
                        : const LinearProgressIndicator()
                  : null,
            ),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(omoSiteError(_error)),
                trailing: TextButton(
                  onPressed: _read,
                  child: Text(t.common.retry),
                ),
              ),
            if (account == null && _error == null && !_loading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () => _accountDetails(),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: Text(t.videoSource.login),
                ),
              ),
            const SizedBox(height: 16),
            ?widget.localFavorites,
            SourceProfileLocalVideoPreviews(
              source: widget.source,
              groupDownloads: true,
              showPrivacyAction: false,
              responsivePreview: true,
              active: widget.active,
              onHistory: widget.onLocalHistory,
              afterHistory: OmoSiteFollowingPreview(
                client: widget.client,
                source: widget.source,
                active: widget.active,
                responsivePreview: true,
                onViewAll: () => unawaited(_following()),
                onOpen: _openFollowing,
              ),
            ),
            group(t.omoAccount.siteServices, [
              entry(
                Icons.notifications_none_rounded,
                t.videoSource.messages,
                () => _private('messages'),
                badge: (account?.unread ?? 0) > 0
                    ? Badge(label: Text('${account!.unread}'))
                    : null,
              ),
              entry(
                Icons.campaign_outlined,
                t.videoSource.siteNotices,
                () => _private('notices'),
              ),
            ]),
            group(t.videoSource.accountGroup, [
              entry(
                Icons.switch_account_outlined,
                t.plugin.switchAccount,
                () => unawaited(_savedAccounts()),
              ),
              entry(
                Icons.tune_rounded,
                t.plugin.pluginSettings,
                () => unawaited(_settings()),
              ),
            ]),
          ],
        ),
      );
    },
  );
}

/// Empty authenticated samples are handled natively; unknown nonempty records
/// keep a clear website fallback instead of guessed targets or lost content.
class OmoPrivateIndexPage extends StatefulWidget {
  const OmoPrivateIndexPage({
    super.key,
    required this.client,
    required this.kind,
    this.onOpenWebsite,
    this.onOpenRecord,
    this.source = '',
    this.mode = ApiVideoView.list,
  });
  final OmoSiteClient client;
  final String kind, source;
  final ApiVideoView mode;
  final Future<void> Function(OmoHistoryEntry entry)? onOpenRecord;
  final Future<void> Function(Uri url)? onOpenWebsite;
  @override
  State<OmoPrivateIndexPage> createState() => _OmoPrivateIndexPageState();
}

class _OmoPrivateIndexPageState extends State<OmoPrivateIndexPage> {
  bool _loading = true;
  int? _count;
  int _offset = 0, _unmapped = 0, _readEpoch = 0;
  int? _loadedAccountRevision;
  bool _hasMore = false, _openingHistory = false;
  List<OmoHistoryEntry> _history = [];
  List<OmoMessageEntry> _messages = [];
  int _messageType = 1;
  List<Map<String, dynamic>> _notices = [];
  Object? _error;
  String _query = '', _date = '';
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  Object? _openError;
  String get _title => widget.kind == 'notices'
      ? t.videoSource.siteNotices
      : widget.kind == 'messages'
      ? t.videoSource.messages
      : t.videoSource.siteHistory;
  @override
  void initState() {
    super.initState();
    widget.client.addListener(_accountChanged);
    _read();
  }

  void _accountChanged() {
    if (!mounted ||
        _loadedAccountRevision == null ||
        _loadedAccountRevision == widget.client.revision)
      return;
    setState(() {
      _history = [];
      _messages = [];
      _count = null;
      _offset = 0;
      _hasMore = false;
      _unmapped = 0;
      _loadedAccountRevision = null;
      _error = const OmoSiteException('accountChanged');
    });
  }

  Future<void>? _readTask;
  bool _openingNotice = false;

  Future<void> _read() =>
      _readTask ??= _readNow().whenComplete(() => _readTask = null);

  Future<void> _readNow({bool append = false}) async {
    final epoch = ++_readEpoch, messageType = _messageType;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.kind == 'notices') {
        final rows = await widget.client.notices();
        if (mounted && epoch == _readEpoch) setState(() => _notices = rows);
        return;
      }
      final account = await widget.client.readAccount();
      if (account == null) throw const OmoSiteException('signedOut');
      final revision = widget.client.revision;
      final result = await widget.client.privateIndex(
        widget.kind,
        type: messageType,
        offset: append ? _offset : 0,
      );
      if (!mounted ||
          epoch != _readEpoch ||
          revision != widget.client.revision ||
          messageType != _messageType)
        return;
      _error = null;
      _loadedAccountRevision = revision;
      _count = (append ? (_count ?? 0) : 0) + result.count;
      _offset = result.nextOffset;
      _hasMore = result.hasMore;
      _unmapped = (append ? _unmapped : 0) + result.unmappedCount;
      _history = [if (append) ..._history, ...result.items];
      _messages = [if (append) ..._messages, ...result.messages];
    } catch (error) {
      if (mounted && epoch == _readEpoch) _error = error;
    } finally {
      if (mounted && epoch == _readEpoch) setState(() => _loading = false);
    }
  }

  Future<void> _website([Uri? target]) async {
    if (_openingHistory) return;
    final url =
        target ??
        widget.client.home.resolve(
          widget.kind == 'notices'
              ? '/arttype/20.html'
              : widget.kind == 'messages'
              ? '/user/message'
              : '/user/history.html',
        );
    if (url.origin != widget.client.home.origin ||
        url.userInfo.isNotEmpty ||
        url.scheme != 'https')
      return;
    if (target != null && _loadedAccountRevision != widget.client.revision)
      return;
    _openingHistory = true;
    try {
      if (widget.onOpenWebsite case final open?) {
        await open(url);
      } else {
        await openOmoSitePage(
          context,
          widget.client,
          title: _title,
          path: '${url.path}${url.hasQuery ? '?${url.query}' : ''}',
        );
      }
    } finally {
      _openingHistory = false;
    }
    if (mounted) await _read();
  }

  Future<void> _openNotice(Map<String, dynamic> row) async {
    if (_openingNotice) return;
    final url = apiVideoHttps(row['url'], origin: widget.client.home);
    if (url == null) return;
    _openingNotice = true;
    final network = VideoNetworkScope.maybeOf(context)?.network;
    try {
      await Navigator.of(context).push<void>(
        videoPageRoute(
          networkSource: omoNetworkSource,
          network: network,
          builder: (_) => OmoNoticePage(
            client: widget.client,
            url: url,
            onWebsite: (pageContext) => openOmoSitePage(
              pageContext,
              widget.client,
              title: t.videoSource.siteNotices,
              path: url.path,
              network: network,
            ),
          ),
        ),
      );
    } finally {
      _openingNotice = false;
    }
  }

  Widget _noticeList() => RefreshIndicator(
    onRefresh: _read,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SizedBox(
          height: 4,
          child: _loading ? const LinearProgressIndicator() : null,
        ),
        if (_error != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(omoSiteError(_error)),
            trailing: TextButton(
              onPressed: _loading ? null : _read,
              child: Text(t.common.retry),
            ),
          ),
        for (final row in _notices)
          TouchHoverIntent(
            identity: row['url'],
            builder: (context, hover) => ListTile(
              key: ValueKey('omo-notice.${row['url']}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              hoverColor: hover.hoverColor(),
              title: Text(
                '${row['title']}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _openNotice(row),
            ),
          ),
        if (!_loading && _notices.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Text(t.videoSource.noNotices, textAlign: TextAlign.center),
          ),
        if (_error != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _website,
              child: Text(t.videoLibrary.openWebsite),
            ),
          ),
      ],
    ),
  );

  Future<void> _openRecord(OmoHistoryEntry entry) async {
    if (_openingHistory || _loadedAccountRevision != widget.client.revision)
      return;
    final open = widget.onOpenRecord;
    if (entry.resume == null || open == null) {
      setState(() => _openError = const OmoSiteException('unsupportedHistory'));
      return;
    }
    setState(() {
      _openingHistory = true;
      _openError = null;
    });
    try {
      await open(entry);
    } catch (error) {
      if (mounted) setState(() => _openError = error);
    } finally {
      if (mounted) setState(() => _openingHistory = false);
    }
  }

  String get _unknownEpisode =>
      Localizations.localeOf(context).languageCode == 'zh'
      ? '这条记录的剧集信息暂不可用'
      : 'The episode for this record is unavailable.';

  String _day(OmoHistoryEntry row) {
    final match = RegExp(
      r'^\d{4}-\d{2}-\d{2}(?:$|[ T])',
    ).firstMatch(row.watchedAt);
    return match == null ? '' : row.watchedAt.substring(0, 10);
  }

  Widget _historyList() {
    final query = _query.trim().toLowerCase();
    final dates = _history.map(_day).where((d) => d.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final visible = _history
        .where(
          (row) =>
              (_date.isEmpty || _day(row) == _date) &&
              (query.isEmpty ||
                  (_keywordScope == KeywordSearchScope.title
                          ? row.title
                          : '${row.title} ${row.episodeLabel}')
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    final cards = <String, OmoHistoryEntry>{};
    final items = <ApiVideoItem>[];
    for (var i = 0; i < visible.length; i++) {
      final entry = visible[i], key = '${visible[i].cardId}|$i';
      cards[key] = entry;
      items.add(
        ApiVideoItem(
          id: key,
          title: entry.title,
          detailUrl: entry.detailUrl,
          coverUrl: entry.coverUrl,
          remarks: entry.episodeLabel,
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SearchQueryField(
                  query: _query,
                  inline: true,
                  autoExpand: false,
                  closeOnSubmit: false,
                  hintText: t.videoLibrary.searchHint,
                  semanticLabel: t.videoLibrary.searchHint,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 4),
              KeywordScopeMenu(
                scope: _keywordScope,
                onChanged: (scope) => setState(() => _keywordScope = scope),
              ),
              const CollectionCoverPrivacyButton(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.videoLibrary.results(count: visible.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SourceChoiceMenu<String>(
                value: _date,
                label: _date.isEmpty ? t.common.all : _date,
                tooltip: t.bookshelf.facets.title,
                options: {'': t.common.all, for (final day in dates) day: day},
                onChanged: (value) => setState(() => _date = value),
              ),
            ],
          ),
        ),
        if (_openError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _openError is OmoSiteException
                  ? _unknownEpisode
                  : t.videoSource.readFailed,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _read,
            child: ApiVideoCollection(
              items: items,
              mode: widget.mode,
              storageKey:
                  'omo-site-history.${widget.source}.${widget.client.account?.id}',
              sourceByItem: {for (final item in items) item.id: widget.source},
              loading: _loading && _history.isEmpty,
              header: Column(
                children: [
                  if (_loading && _history.isNotEmpty)
                    const LinearProgressIndicator(),
                  if (_error != null && _history.isNotEmpty)
                    ListTile(
                      title: Text(omoSiteError(_error)),
                      trailing: TextButton(
                        onPressed: _loading ? null : _read,
                        child: Text(t.common.retry),
                      ),
                    ),
                ],
              ),
              emptyState: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error != null
                          ? omoSiteError(_error)
                          : _history.isNotEmpty
                          ? t.videoLibrary.noResults
                          : _count == 0
                          ? t.videoSource.emptySiteList
                          : _websiteOnly,
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null)
                      TextButton(
                        onPressed: _loading ? null : _read,
                        child: Text(t.common.retry),
                      ),
                    if (_history.isEmpty)
                      TextButton(
                        onPressed: () => _website(),
                        child: Text(t.videoLibrary.openWebsite),
                      ),
                  ],
                ),
              ),
              onOpen: (item) {
                final entry = cards[item.id];
                if (entry != null) unawaited(_openRecord(entry));
              },
              recordNoteBuilder: (item) {
                final entry = cards[item.id]!;
                if (entry.resume == null) return _unknownEpisode;
                // The shared list hides remarks when a record note is present;
                // retain the real episode beside the timestamp in that branch.
                return widget.mode == ApiVideoView.list
                    ? [
                        entry.episodeLabel,
                        entry.watchedAt,
                      ].where((value) => value.isNotEmpty).join(' · ')
                    : entry.watchedAt;
              },
              footer: Column(
                children: [
                  if (_unmapped > 0)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(t.videoSource.siteListFallback),
                    ),
                  if (_hasMore)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _readTask ??= _readNow(
                              append: true,
                            ).whenComplete(() => _readTask = null),
                      child: Text(t.comments.loadMore),
                    ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: () => _website(),
                      child: Text(t.videoLibrary.openWebsite),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _websiteOnly =>
      Localizations.localeOf(context).languageCode == 'zh'
      ? '记录已读取，请在原网页查看'
      : 'Records loaded. Open the website to view them.';

  Future<void> _openMessage(OmoMessageEntry message) async {
    final url = message.url;
    if (_openingHistory ||
        url == null ||
        _loadedAccountRevision != widget.client.revision)
      return;
    if (url.path.startsWith('/anime/')) {
      final open = widget.onOpenRecord;
      if (open == null) {
        setState(() => _openError = const OmoSiteException('unavailable'));
        return;
      }
      setState(() {
        _openingHistory = true;
        _openError = null;
      });
      try {
        await open(
          OmoHistoryEntry(
            url: url,
            title: message.workTitle.isNotEmpty
                ? message.workTitle
                : message.title,
          ),
        );
      } catch (error) {
        if (mounted) setState(() => _openError = error);
      } finally {
        if (mounted) setState(() => _openingHistory = false);
      }
    } else {
      await _website(url);
    }
  }

  Widget _privateList() => RefreshIndicator(
    onRefresh: _read,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (widget.kind == 'messages')
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in const [1, 2, 3])
                ChoiceChip(
                  key: ValueKey('omo-message-type-$type'),
                  label: Text(switch (type) {
                    1 => t.videoSource.messagePosts,
                    2 => t.videoSource.messageReplies,
                    _ => t.videoSource.messageLikes,
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selected: _messageType == type,
                  onSelected: _loading
                      ? null
                      : (_) {
                          if (_messageType == type) return;
                          setState(() {
                            _messageType = type;
                            _messages = [];
                            _count = null;
                            _offset = 0;
                            _unmapped = 0;
                            _hasMore = false;
                            _openError = null;
                          });
                          _read();
                        },
                ),
            ],
          ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(omoSiteError(_error)),
            trailing: TextButton(
              onPressed: _loading ? null : _read,
              child: Text(t.common.retry),
            ),
          ),
        if (_openError != null) Text(omoSiteError(_openError)),
        for (final message in _messages)
          Padding(
            key: ValueKey('omo-message.${message.id}'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message.title.isNotEmpty)
                  Text(
                    message.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (message.workTitle.isNotEmpty)
                  Text(
                    message.workTitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (message.reply.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      message.reply,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (message.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(message.content),
                  ),
                if (message.createdAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      message.createdAt,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (message.url != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: ValueKey('omo-message-open.${message.id}'),
                      onPressed: _openingHistory
                          ? null
                          : () => _openMessage(message),
                      icon: Icon(
                        message.url!.path.startsWith('/anime/')
                            ? Icons.play_arrow_rounded
                            : Icons.open_in_new_rounded,
                      ),
                      label: Text(
                        message.url!.path.startsWith('/anime/')
                            ? t.download.openSourceVideo
                            : t.videoLibrary.openWebsite,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (var i = 0; i < _history.length; i++)
          ListTile(
            key: ValueKey('omo-history.$i'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            title: Text(
              _history[i].title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle:
                [
                  _history[i].episodeLabel,
                  _history[i].watchedAt,
                ].where((v) => v.isNotEmpty).isEmpty
                ? null
                : Text(
                    [
                      _history[i].episodeLabel,
                      _history[i].watchedAt,
                    ].where((v) => v.isNotEmpty).join(' · '),
                  ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _website(_history[i].url),
          ),
        if (!_loading &&
            _error == null &&
            _history.isEmpty &&
            _messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Text(
              _count == 0 ? t.videoSource.emptySiteList : _websiteOnly,
              textAlign: TextAlign.center,
            ),
          ),
        if (_unmapped > 0 && (_history.isNotEmpty || _messages.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              t.videoSource.siteListFallback,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_hasMore)
          TextButton(
            onPressed: _loading
                ? null
                : () => _readTask ??= _readNow(
                    append: true,
                  ).whenComplete(() => _readTask = null),
            child: Text(t.comments.loadMore),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _website(),
            child: Text(t.videoLibrary.openWebsite),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _readEpoch++;
    widget.client.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const SourceBackButton(), title: Text(_title)),
    body: widget.kind == 'notices'
        ? _noticeList()
        : widget.kind == 'history'
        ? _historyList()
        : _privateList(),
  );
}
