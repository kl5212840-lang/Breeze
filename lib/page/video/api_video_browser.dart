import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/network/playback_trace.dart';

/// Public catalog DOM only. Cookies remain in WebKit; no source JS is evaluated.
String apiVideoBrowserSnapshotScript(String itemPrefix) =>
    r'''
(() => {
  const prefix = __ITEM_PREFIX__;
  const clean = value => (value || '').replace(/\s+/g,' ').trim().slice(0,1000);
  const publicUrl = value => {
    try { const u = new URL(value, location.href);
      return u.protocol === 'https:' && u.origin === location.origin && !u.username && !u.password ? u.href : '';
    } catch (_) { return ''; }
  };
  const title = document.title || '';
  const verification = /系统安全验证/.test(title) ||
    Array.from(document.querySelectorAll('input[type=button],button')).some(n =>
      /^(继续访问)$/.test((n.value || n.textContent || '').trim()));
  const documentId = typeof performance !== 'undefined' && performance ? String(performance.timeOrigin) : '';
  if (verification) return JSON.stringify({url:location.href,documentId,verification:true});
  const cards = [], seen = new Set();
  for (const heading of Array.from(document.querySelectorAll('h4')).slice(0,200)) {
    const anchor = heading.querySelector('a[href]');
    const href = publicUrl(anchor?.getAttribute('href'));
    const group = heading.closest('[data-key]')?.getAttribute('data-key') || '';
    const key = group + '|' + href;
    if (!href || !new URL(href).pathname.startsWith(prefix) || seen.has(key)) continue;
    const root = heading.parentElement?.parentElement;
    const cover = Array.from(root?.querySelectorAll('a[href],img') || []).find(n =>
      n.hasAttribute('data-original') || n.hasAttribute('data-src') || n.tagName === 'IMG');
    const spans = Array.from(root?.querySelectorAll('a > span') || []).slice(0,8).map(n=>clean(n.textContent)).filter(Boolean);
    const image = cover?.getAttribute('data-original') || cover?.getAttribute('data-src') || cover?.getAttribute('src') || '';
    seen.add(key); cards.push({href,title:clean(anchor?.getAttribute('title') || heading.textContent),
      coverUrl:(() => { try { return image ? new URL(image,location.href).href : ''; } catch (_) { return ''; } })(),
      subtitle:spans[0] || '',remarks:spans[spans.length-1] || '',
      group});
  }
  const links = Array.from(document.querySelectorAll('a[href]')).slice(0,1500)
    .map(n=>({label:clean(n.textContent),href:publicUrl(n.getAttribute('href'))})).filter(n=>n.href);
  const pageText = Array.from(document.querySelectorAll('li,a,span'))
    .slice(0,2000).map(n=>clean(n.textContent)).filter(t=>/^\d+\s*\/\s*\d+$/.test(t));
  const headings = Array.from(document.querySelectorAll('h1,h2,h3')).slice(0,30).map(n=>clean(n.textContent));
  const emptyMessage = Array.from(document.querySelectorAll('h1,h2,h3,p,.empty,.no-result')).some(n =>
    /(?:没有找到|暂无|未找到).{0,15}(?:影片|视频|动漫)|(?:影片|视频|动漫).{0,15}(?:未找到|暂无)/.test(clean(n.textContent)));
  // The current source renders an empty list under its search label, without
  // an empty-state message. Require both semantic signals, not merely 0 cards.
  const emptySearch = location.pathname.startsWith('/search/') && cards.length === 0 &&
    Array.from(document.querySelectorAll('ul')).some(n => !n.querySelector('a') &&
      /与[“「"].{1,100}[”」"]相关的影片/.test(clean(n.parentElement?.textContent)) &&
      n.parentElement?.querySelector('a[href^="/mangasearch/"]'));
  const empty = emptyMessage || emptySearch;
  const groups = Array.from(document.querySelectorAll('[data-key]')).slice(0,20).map(n=>n.getAttribute('data-key'));
  const topicDescription = /^\/topicdetail-\d+\.html$/.test(location.pathname)
    ? Array.from(document.querySelectorAll('p.desc.detail')).map(n=>clean(n.textContent))
      .find(t=>t && !/暂无简介|暂无介绍/.test(t)) || '' : '';
  return JSON.stringify({url:location.href,documentId,title:clean(title),cards,links,pageText,headings,empty,groups,topicDescription});
})()
'''
        .replaceAll('__ITEM_PREFIX__', jsonEncode(itemPrefix));

/// Only the requested public work page is read. Cookies remain inside WebKit;
/// account forms/navigation and scripts never cross the plugin bridge.
String apiVideoPublicDetailScript(Uri url, Uri home) =>
    r'''(async () => {
  const expected = new URL(__URL__), origin = __ORIGIN__;
  if (location.origin !== origin || expected.origin !== origin ||
      !/^\/anime\/[a-f0-9]{16,64}\.html$/.test(expected.pathname) ||
      expected.search || expected.hash || expected.username || expected.password) throw new Error('identity');
  const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(expected.href, {credentials:'same-origin',
      cache:'no-store', redirect:'error', signal:controller.signal});
    if (!response.ok || response.url !== expected.href) throw new Error('transport');
    const html = await response.text(); if (html.length > 2000000) throw new Error('size');
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const verification = /系统安全验证/.test(doc.title) ||
      Array.from(doc.querySelectorAll('button,input[type=button]')).some(n =>
        /^(继续访问)$/.test((n.value || n.textContent || '').trim()));
    if (verification) return JSON.stringify({kind:'public-detail',url:expected.href,verification:true});
    doc.querySelectorAll('script,style,form,input,textarea,header,nav,iframe,object,embed').forEach(n => n.remove());
    return JSON.stringify({kind:'public-detail',url:expected.href,verification:false,
      html:doc.documentElement.outerHTML});
  } finally {clearTimeout(timer);}
})()'''
        .replaceAll('__URL__', jsonEncode(url.toString()))
        .replaceAll('__ORIGIN__', jsonEncode(home.origin));

/// Preserve main-document transport evidence instead of disguising a failed
/// network read as an explicit user cancellation.
class ApiVideoBrowserTransportFailure
    implements Exception, ReadFailureEvidence {
  const ApiVideoBrowserTransportFailure(this.kind, this.description);
  final String kind, description;
  @override
  bool get retryable =>
      RegExp(
        r'connect|timed?_?out|host.?lookup|network|internet|\bio\b',
        caseSensitive: false,
      ).hasMatch(kind) ||
      RegExp(
        r'(?:code[= :]*|\()-(?:1001|1003|1004|1005|1006|1009|1018)\b',
        caseSensitive: false,
      ).hasMatch(description) ||
      readFailureIsTransient(Exception(description));
  @override
  String toString() => 'Catalog transport $kind: $description';
}

class ApiVideoBrowserSession extends ChangeNotifier {
  ApiVideoBrowserSession({
    required this.home,
    required this.paths,
    required this.itemPrefix,
    this.network,
    this.accountSource,
    this.interactive = true,
    PluginAccountSyncCoordinator? accountCoordinator,
    VideoAccountCookies? Function(InAppWebViewController)? accountCookieAdapter,
  }) : _accountCoordinator =
           accountCoordinator ?? PluginAccountSyncCoordinator.instance,
       _accountCookieAdapter = accountCookieAdapter ?? videoSiteAccountCookies {
    _accountInstallation = LocalPluginInstallationState.instance
        .installationEpoch(accountSource ?? '');
  }
  final Uri home;
  final List<String> paths;
  final String itemPrefix;
  final Future<OmoNetworkContext?>? network;
  final String? accountSource;
  final bool interactive;
  late final int _accountInstallation;
  final PluginAccountSyncCoordinator _accountCoordinator;
  final VideoAccountCookies? Function(InAppWebViewController)
  _accountCookieAdapter;
  InAppWebViewController? _accountWeb;
  Object? _accountLease;
  Future<void>? _accountRegistering;
  bool _ownerDisposed = false;
  int _backgroundOwners = 0;
  final _ready = Completer<InAppWebViewController>();
  final _firstCatalogReady = Completer<void>();
  final _firstDocumentReady = Completer<void>();
  Completer<Map<String, dynamic>>? _pending;
  Uri? _expected;
  bool visible = false;
  bool _allowVerificationPresentation = true;
  bool _disposed = false;
  int _generation = 0;
  Timer? _watchdog;
  Timer? _documentProbe;
  final _trace = PlaybackTrace();
  String? _previousDocument;

  String diagnosticReport() =>
      'browser_pending: ${_pending != null}\n'
      'document_ready: ${_firstDocumentReady.isCompleted}\n'
      'verification_visible: $visible\n${_trace.export()}';

  bool accepts(Uri url) =>
      url.scheme == 'https' &&
      url.origin == home.origin &&
      url.userInfo.isEmpty &&
      !url.hasFragment &&
      (url.path == '/' || paths.any(url.path.startsWith));

  Future<Map<String, dynamic>> read(Uri url) async {
    final resolutionOwner = VideoDownloadResolutionOwner.current;
    resolutionOwner?.check();
    if (_disposed || !accepts(url)) {
      throw const FormatException('Unsupported browser catalog URL');
    }
    cancel(); // A newer query owns the one browser and invalidates old callbacks.
    final generation = ++_generation;
    _allowVerificationPresentation = interactive && !isAutomaticReadRecovery;
    final pending = Completer<Map<String, dynamic>>();
    _pending = pending;
    _expected = url;
    final removeResolutionCancel = resolutionOwner?.onCancel(() async {
      if (!identical(_pending, pending) || generation != _generation) return;
      cancel();
      if (_ready.isCompleted) {
        final web = await _ready.future;
        await web.stopLoading().timeout(const Duration(seconds: 5));
      }
    });
    try {
      final web = await _ready.future.timeout(const Duration(seconds: 20));
      resolutionOwner?.check();
      if (generation != _generation) return await pending.future;
      if (kDebugMode) debugPrint('ApiCatalog stage=ready');
      // A new WKWebView has no document yet. Evaluating JS before its first
      // navigation can wait indefinitely for WebKit's content process.
      final current = await web.getUrl().timeout(const Duration(seconds: 3));
      final previous = current?.scheme == 'https'
          ? await web
                .evaluateJavascript(source: 'String(performance.timeOrigin)')
                .timeout(const Duration(seconds: 3))
          : null;
      if (generation != _generation) return await pending.future;
      _previousDocument = previous?.toString();
      _watchdog = Timer(const Duration(seconds: 30), () {
        _trace.add('catalog', 'document readiness timeout');
        cancel(error: TimeoutException('Catalog document readiness timed out'));
      });
      _trace.add('catalog', 'navigation requested');
      if (kDebugMode) debugPrint('ApiCatalog stage=load');
      await web.loadUrl(urlRequest: URLRequest(url: WebUri(url.toString())));
      return await pending.future;
    } catch (error, stack) {
      _trace.failure('catalog', error, stack);
      if (identical(_pending, pending)) cancel(error: error);
      rethrow;
    } finally {
      removeResolutionCancel?.call();
    }
  }

  Future<Map<String, dynamic>> readDetail(Uri url) async {
    if (_disposed ||
        url.origin != home.origin ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !RegExp(r'^/anime/[a-f0-9]{16,64}\.html$').hasMatch(url.path)) {
      throw const FormatException('Unsupported public detail URL');
    }
    final resolutionOwner = VideoDownloadResolutionOwner.current;
    resolutionOwner?.check();
    final generation = _generation;
    if (!_firstDocumentReady.isCompleted) {
      final ready = Completer<void>();
      void check() {
        if (ready.isCompleted) return;
        if (_disposed || generation != _generation || visible) {
          ready.completeError(const FormatException('Detail read cancelled'));
        } else if (_firstDocumentReady.isCompleted) {
          ready.complete();
        }
      }

      addListener(check);
      try {
        check();
        await ready.future.timeout(const Duration(seconds: 15));
      } finally {
        if (!_disposed) removeListener(check);
      }
    }
    if (_disposed || generation != _generation || visible) {
      throw const FormatException('Public detail session is unavailable');
    }
    final web = await _ready.future.timeout(const Duration(seconds: 5));
    final current = await web.getUrl().timeout(const Duration(seconds: 3));
    if (current == null ||
        current.origin != home.origin ||
        current.scheme != 'https') {
      throw const FormatException('Public detail session is not ready');
    }
    resolutionOwner?.check();
    final raw = await videoBrowserReadAsync(
      web,
      apiVideoPublicDetailScript(url, home),
    ).timeout(const Duration(seconds: 12));
    if (_disposed || generation != _generation) {
      throw const FormatException('Detail read cancelled');
    }
    final value = asJsonMap(raw is String ? jsonDecode(raw) : raw);
    if (!interactive &&
        value['kind'] == 'public-detail' &&
        value['url'] == url.toString() &&
        value['verification'] == true) {
      throw const VideoDownloadResolutionFailure('verificationRequired');
    }
    if (value['kind'] != 'public-detail' ||
        value['url'] != url.toString() ||
        value['verification'] == true ||
        value['html'] is! String ||
        (value['html'] as String).length > 2000000) {
      throw const FormatException('Public detail requires verification');
    }
    return value;
  }

  void receivedError(WebResourceRequest request, WebResourceError error) {
    if (request.isForMainFrame != true ||
        error.type == WebResourceErrorType.CANCELLED ||
        !videoSiteDocumentMatches(
          _expected,
          Uri.tryParse(request.url.toString()),
        )) {
      return;
    }
    _trace.add(
      'navigation_error',
      defaultTargetPlatform == TargetPlatform.iOS
          ? error.description
          : '${error.type}',
    );
    if (!visible) {
      cancel(
        error: ApiVideoBrowserTransportFailure(
          error.type.toString(),
          error.description,
        ),
      );
    }
  }

  void created(InAppWebViewController web) {
    _accountWeb = web;
    if (accountSource == null) {
      if (!_ready.isCompleted) _ready.complete(web);
      return;
    }
    // Account restore precedes the first catalog navigation and every site API
    // read. It uses the already-created browser, never another hidden view.
    unawaited(
      _ensureAccountRegistration().then<void>(
        (_) {
          if (!_disposed && !_ready.isCompleted) _ready.complete(web);
        },
        onError: (Object _) {
          // A restore failure is not a website login. Keep normal catalog access.
          if (!_disposed && !_ready.isCompleted) _ready.complete(web);
        },
      ),
    );
  }

  Future<void> _ensureAccountRegistration() {
    final source = accountSource, web = _accountWeb, lease = _accountLease;
    if (source != null &&
        _accountInstallation !=
            LocalPluginInstallationState.instance.installationEpoch(source)) {
      return Future.error(const PluginSessionChanged());
    }
    if (_disposed ||
        _ownerDisposed ||
        source == null ||
        web == null ||
        lease != null && _accountCoordinator.isRegistered(source, lease)) {
      if (!_disposed && !_ownerDisposed && source != null && lease != null)
        return _accountCoordinator.restoreOnEntry(source).then<void>((_) {});
      return Future.value();
    }
    return _accountRegistering ??=
        () async {
          final cookies = _accountCookieAdapter(web);
          if (cookies == null) return;
          final registration = await _accountCoordinator.registerStoredSession(
            source: source,
            origin: home,
            cookies: cookies,
            identity: () async {
              if (_disposed || _ownerDisposed || visible) return null;
              try {
                final result = await _requestOmoSite('account', const {
                  'includeProfile': true,
                });
                if (_disposed || _ownerDisposed || !identical(web, _accountWeb))
                  return null;
                if (result['kind'] == 'signedOut')
                  throw const PluginAccountAuthenticationRejected();
                if (result['kind'] != 'account') return null;
                final account = OmoSiteAccount.fromJson(
                  asJsonMap(result['account']),
                  home: home,
                );
                if (account.id.isEmpty ||
                    _disposed ||
                    _ownerDisposed ||
                    !identical(web, _accountWeb))
                  return null;
                return PluginAccountAuthentication(
                  serverIdentity: account.id,
                  label: account.name,
                  origin: home.origin,
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
                );
              } on PluginAccountAuthenticationRejected {
                rethrow;
              } catch (_) {
                return null;
              }
            },
            authenticated: () async {
              if (_disposed || _ownerDisposed || visible) return false;
              try {
                // Bypass the public capture hook to avoid recursive account reads.
                final result = await _requestOmoSite('account', const {});
                return result['kind'] == 'account' &&
                    OmoSiteAccount.fromJson(
                      asJsonMap(result['account']),
                      home: home,
                    ).id.isNotEmpty;
              } catch (_) {
                return false;
              }
            },
          );
          if (_disposed || _ownerDisposed || !identical(web, _accountWeb)) {
            _accountCoordinator.unregister(source, registration);
            return;
          }
          _accountLease = registration;
          await _accountCoordinator.restoreOnEntry(source);
        }().whenComplete(() {
          _accountRegistering = null;
        });
  }

  Future<Future<void> Function()> retainForDownloads() async {
    if (_disposed || _ownerDisposed) throw StateError('Browser session closed');
    _backgroundOwners++;
    VideoBrowserBackgroundLifetime? lifetime;
    try {
      final web = await _ready.future.timeout(const Duration(seconds: 5));
      final Object platform = web.platform;
      if (platform is VideoBrowserBackgroundLifetime) {
        lifetime = platform;
        await platform.retainBackground();
      } else {
        throw StateError('Browser cannot outlive its view');
      }
    } catch (_) {
      _backgroundOwners--;
      if (_ownerDisposed && _backgroundOwners == 0) _finishDispose();
      rethrow;
    }
    var released = false;
    return () async {
      if (released) return;
      released = true;
      _backgroundOwners--;
      if (_ownerDisposed && _backgroundOwners == 0) _finishDispose();
      await lifetime?.releaseBackground();
    };
  }

  /// A document can be usable long before WebKit finishes advertisements and
  /// subframes. Only read after parsing, retaining the same document/generation
  /// checks as load-stop so an old page can never satisfy a newer search.
  Future<void> committed(InAppWebViewController web, Uri? uri) async {
    if (_disposed ||
        _pending == null ||
        !videoSiteDocumentMatches(_expected, uri)) {
      return;
    }
    _documentProbe?.cancel();
    final generation = _generation;
    try {
      final state = await web
          .evaluateJavascript(source: 'document.readyState')
          .timeout(const Duration(seconds: 3));
      if (_disposed || generation != _generation || _pending == null) return;
      if (state == 'interactive' || state == 'complete') {
        _trace.add('catalog', 'main document parsed');
        await loaded(web, uri);
        return;
      }
    } catch (error, stack) {
      if (_disposed || generation != _generation || _pending == null) return;
      _trace.failure('document_probe', error, stack);
    }
    _documentProbe = Timer(const Duration(milliseconds: 150), () {
      if (!_disposed && generation == _generation && _pending != null) {
        unawaited(committed(web, uri));
      }
    });
  }

  Future<Map<String, dynamic>> requestOmoSite(
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    if (accountSource != null) {
      await _ready.future.timeout(const Duration(seconds: 20));
      await _ensureAccountRegistration();
    }
    final generation = accountSource == null
        ? null
        : pluginSessionWriteFence.generation(accountSource!);
    final result = await _requestOmoSite(operation, parameters);
    if (accountSource != null &&
        _accountInstallation !=
            LocalPluginInstallationState.instance.installationEpoch(
              accountSource!,
            )) {
      throw const PluginSessionChanged();
    }
    if (operation == 'account' &&
        !_disposed &&
        !_ownerDisposed &&
        accountSource != null &&
        generation != null) {
      if (result['kind'] == 'signedOut')
        PluginAccountIdentities.reject(accountSource!, generation: generation);
      if (result['kind'] == 'account') {
        final account = OmoSiteAccount.fromJson(
          asJsonMap(result['account']),
          home: home,
        );
        if (account.id.isNotEmpty)
          PluginAccountIdentities.confirm(
            accountSource!,
            PluginAccountAuthentication(
              serverIdentity: account.id,
              label: account.name,
              origin: home.origin,
              avatarUrl: account.avatar?.toString() ?? '',
              publicSummary: {
                'lines': [
                  account.name,
                  if (account.group.isNotEmpty) account.group,
                ],
              },
            ),
            generation: generation,
          );
      }
    }
    if (operation == 'account' &&
        accountSource != null &&
        result['kind'] == 'account' &&
        OmoSiteAccount.fromJson(
          asJsonMap(result['account']),
          home: home,
        ).id.isNotEmpty) {
      unawaited(
        _accountCoordinator
            .captureAuthenticated(accountSource!)
            .catchError((Object _) {}),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> _requestOmoSite(
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    if (_disposed) throw const OmoSiteException('closed');
    // A valid same-origin document is sufficient. Card parsing and media
    // resolution are independent of account/comment JSON endpoints.
    if (!_firstDocumentReady.isCompleted && _pending == null && !visible) {
      final recovery = read(home), generation = _generation;
      try {
        await recovery.timeout(const Duration(seconds: 15));
      } catch (_) {
        if (!_firstDocumentReady.isCompleted || visible || _disposed) {
          final verifying = visible;
          if (!_disposed && generation == _generation && !verifying) cancel();
          throw OmoSiteException(verifying ? 'verification' : 'notReady');
        }
      }
    }
    try {
      await _firstDocumentReady.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw OmoSiteException(visible ? 'verification' : 'notReady');
    }
    if (visible) throw const OmoSiteException('verification');
    final generation = _generation;
    final web = await _ready.future.timeout(const Duration(seconds: 10));
    if (kDebugMode) debugPrint('OmoSiteBridge $operation invoke');
    final raw = await videoBrowserReadAsync(
      web,
      '(async (operation, parameters, origin) => {$omoSiteRequestScript})'
      '(${jsonEncode(operation)},${jsonEncode(parameters)},${jsonEncode(home.origin)})',
    ).timeout(const Duration(seconds: 15));
    if (_disposed || generation != _generation) {
      throw const OmoSiteException('cancelled');
    }
    final value = asJsonMap(raw is String ? jsonDecode(raw) : raw);
    if (kDebugMode) {
      debugPrint('OmoSiteBridge $operation result=${value['kind']}');
    }
    return value;
  }

  Future<void> loaded(InAppWebViewController web, Uri? uri) async {
    if (_disposed ||
        _pending == null ||
        !videoSiteDocumentMatches(_expected, uri)) {
      return;
    }
    final generation = _generation;
    if (kDebugMode) debugPrint('ApiCatalog stage=stop');
    try {
      final raw = await web
          .evaluateJavascript(source: apiVideoBrowserSnapshotScript(itemPrefix))
          .timeout(const Duration(seconds: 10));
      final value = asJsonMap(raw is String ? jsonDecode(raw) : raw);
      if (_disposed || generation != _generation || _pending == null) return;
      final documentUrl = Uri.tryParse(value['url']?.toString() ?? '');
      if (!videoSiteDocumentMatches(_expected, documentUrl) ||
          (_previousDocument?.isNotEmpty == true &&
              value['documentId'] == _previousDocument)) {
        return; // An old stop callback cannot satisfy a same-URL refresh.
      }
      if (value['verification'] == true) {
        if (!_allowVerificationPresentation) {
          cancel(
            error: interactive
                ? const FormatException('Catalog requires verification')
                : const VideoDownloadResolutionFailure('verificationRequired'),
          );
          return;
        }
        if (kDebugMode) debugPrint('ApiCatalog stage=verification');
        _watchdog?.cancel();
        _documentProbe?.cancel();
        _trace.add('catalog', 'site verification required');
        visible = true;
        notifyListeners();
        return; // User completes the site's normal flow in this same WebView.
      }
      if (!_firstDocumentReady.isCompleted) _firstDocumentReady.complete();
      if (value['cards'] is! List || value['links'] is! List) {
        throw const FormatException('Unrecognized public catalog');
      }
      if (kDebugMode) {
        debugPrint(
          'ApiCatalog stage=snapshot cards=${(value['cards'] as List).length}',
        );
      }
      final pending = _pending!;
      _watchdog?.cancel();
      _documentProbe?.cancel();
      _trace.add(
        'catalog',
        'snapshot ready; cards=${(value['cards'] as List).length}',
      );
      _pending = null;
      if (!_firstCatalogReady.isCompleted) _firstCatalogReady.complete();
      visible = false;
      notifyListeners();
      pending.complete(value);
    } catch (error, stack) {
      _trace.failure('catalog_snapshot', error, stack);
      if (generation == _generation) cancel(error: error);
    }
  }

  void cancel({Object? error}) {
    _watchdog?.cancel();
    _documentProbe?.cancel();
    _generation++;
    final previous = _pending;
    _pending = null;
    _expected = null;
    _previousDocument = null;
    visible = false;
    // Attach a handler before completing: cancellation can precede readiness.
    if (previous != null && !previous.isCompleted) {
      unawaited(previous.future.catchError((Object _) => <String, dynamic>{}));
      previous.completeError(
        error ?? const FormatException('Catalog read cancelled'),
      );
    }
    if (!_disposed) notifyListeners();
  }

  @override
  // The final download owner calls _finishDispose(), which disposes the notifier
  // exactly once after the retained browser is no longer needed.
  // ignore: must_call_super
  void dispose() {
    if (_ownerDisposed) return;
    _ownerDisposed = true;
    // A download can retain media transport after the source UI closes, but
    // cannot retain ownership of account switching or identity reads.
    final source = accountSource, lease = _accountLease;
    if (source != null && lease != null)
      _accountCoordinator.unregister(source, lease);
    _accountLease = null;
    if (_backgroundOwners == 0) _finishDispose();
  }

  void _finishDispose() {
    if (_disposed) return;
    _disposed = true;
    final source = accountSource, lease = _accountLease;
    if (source != null && lease != null)
      _accountCoordinator.unregister(source, lease);
    cancel();
    notifyListeners();
    super.dispose();
  }
}

/// One retained browser: revealing verification never recreates its cookie store.
class ApiVideoBrowserHost extends StatelessWidget {
  const ApiVideoBrowserHost({
    super.key,
    required this.session,
    this.active = true,
  });
  final ApiVideoBrowserSession session;
  final bool active;

  @override
  Widget build(BuildContext context) => FutureBuilder<OmoNetworkContext?>(
    future: session.network,
    builder: (context, snapshot) =>
        session.network != null &&
            snapshot.connectionState != ConnectionState.done
        ? const SizedBox.shrink()
        : snapshot.hasError
        ? const SizedBox.shrink()
        : _browser(context, snapshot.data),
  );

  Widget _browser(BuildContext context, OmoNetworkContext? network) =>
      ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final interceptBack =
              active &&
              session.visible &&
              defaultTargetPlatform == TargetPlatform.android;
          return PopScope(
            canPop: !interceptBack,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && interceptBack) scheduleMicrotask(session.cancel);
            },
            child: IgnorePointer(
              ignoring: !session.visible,
              child: ExcludeSemantics(
                excluding: !session.visible,
                child: Opacity(
                  opacity: session.visible ? 1 : 0,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: t.common.close,
                                onPressed: session.cancel,
                                icon: const Icon(Icons.close),
                              ),
                              Expanded(
                                child: Text(
                                  t.videoPlayback.verificationTitle,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        decoration: TextDecoration.none,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: VideoSiteBrowser(
                              home: session.home,
                              source: session.accountSource ?? network?.source,
                              networkContext: network?.token,
                              configuration: InAppWebView(
                                initialSettings: InAppWebViewSettings(
                                  javaScriptEnabled: true,
                                  domStorageEnabled: true,
                                  useHybridComposition:
                                      defaultTargetPlatform ==
                                          TargetPlatform.android
                                      ? false
                                      : null,
                                  useShouldOverrideUrlLoading: true,
                                ),
                                onWebViewCreated: session.created,
                                onPageCommitVisible: (web, uri) =>
                                    session.committed(
                                      web,
                                      Uri.tryParse(uri?.toString() ?? ''),
                                    ),
                                onLoadStop: (web, uri) => session.loaded(
                                  web,
                                  Uri.tryParse(uri?.toString() ?? ''),
                                ),
                                shouldOverrideUrlLoading: (_, action) async {
                                  final uri = Uri.tryParse(
                                    action.request.url?.toString() ?? '',
                                  );
                                  return allowVideoSiteNavigation(
                                        session.home,
                                        uri,
                                        isMainFrame: action.isForMainFrame,
                                      )
                                      ? NavigationActionPolicy.ALLOW
                                      : NavigationActionPolicy.CANCEL;
                                },
                                onReceivedError: (_, request, error) =>
                                    session.receivedError(request, error),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
