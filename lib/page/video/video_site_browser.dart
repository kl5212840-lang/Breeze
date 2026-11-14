import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'dart:convert';

/// Native iOS must use the cookie store of this exact source-scoped WKWebView.
/// Never fall back to the Flutter plugin's unrelated default store on iOS.
VideoAccountCookies? videoSiteAccountCookies(
  InAppWebViewController controller,
) {
  final platform = controller.platform;
  if (platform is VideoSiteBrowserController) {
    return platform.hasAccountCookieContext
        ? platform.newAccountCookieLease()
        : null;
  }
  return Platform.isIOS ? null : PlatformVideoAccountCookies();
}

/// No localized error descriptions or failing URLs enter a diagnostic label.
String videoSiteNativeFailureLabel(Map<String, dynamic> args) {
  final domain = ['url', 'webkit'].contains(args['domain'])
      ? args['domain']
      : 'other';
  final code = args['code'] is int ? args['code'] as int : 0;
  final stage = ['provisional', 'committed', 'process'].contains(args['stage'])
      ? args['stage']
      : 'other';
  return 'WKNavigation $domain $code $stage';
}

/// Only an explicitly observed, same-site entry can leave WebKit for a user
/// decision. Provider redirects and authorization parameters never cross this
/// bridge. An empty registration list keeps every other source unchanged.
Uri? videoSiteExternalAuthenticationEntry(Uri home, Uri entry) {
  bool origin(Uri value) =>
      value.scheme == 'https' &&
      value.host.isNotEmpty &&
      value.userInfo.isEmpty &&
      !value.authority.contains('@') &&
      value.port == 443;
  if (!origin(home) ||
      !origin(entry) ||
      entry.host != home.host ||
      entry.path != '/auth/google' ||
      entry.hasQuery ||
      entry.hasFragment) {
    return null;
  }
  return Uri(scheme: 'https', host: home.host, path: '/auth/google');
}

/// iOS video sites use a standard WKWebView with no injected bridge, console
/// wrappers or browser polyfills. Other app/plugin browsers are unchanged.
class VideoSiteBrowser extends StatefulWidget {
  const VideoSiteBrowser({
    super.key,
    required this.home,
    required this.configuration,
    this.visible = true,
    this.onDocumentResponse,
    this.networkContext,
    this.source,
    this.externalAuthenticationEntries = const [],
    this.onExternalAuthentication,
  });
  final Uri home;
  final String? networkContext;
  final String? source;
  final InAppWebView configuration;

  /// A native catalog keeps this document alive for data without composing it
  /// below its Flutter controls. Verification and explicit web mode reveal it.
  final bool visible;

  /// Actual same-origin entries observed for this source; never inferred from
  /// a provider redirect. Updating these does not recreate the WKWebView.
  final List<Uri> externalAuthenticationEntries;
  final ValueChanged<Uri>? onExternalAuthentication;

  /// All main-document HTTP responses, not only errors. Challenge detection
  /// uses the provider's response header independently of status or template.
  final void Function(Uri url, int status, Map<String, String> headers)?
  onDocumentResponse;

  @override
  State<VideoSiteBrowser> createState() => _VideoSiteBrowserState();
}

class _VideoSiteBrowserState extends State<VideoSiteBrowser> {
  MethodChannel? _channel;
  InAppWebViewController? _controller;
  bool _dark = false;
  Size? _viewport;
  Size? _sentViewport;

  Future<void> _syncViewport(MethodChannel channel, Size size) async {
    if (_sentViewport == size) return;
    _sentViewport = size;
    try {
      await channel.invokeMethod<void>('viewport', {
        'width': size.width,
        'height': size.height,
      });
    } on PlatformException {
      // Keep the document when its platform view is being disposed.
    } on MissingPluginException {
      // Incremental debug updates can retain an older native implementation.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dark = Theme.of(context).brightness == Brightness.dark;
    final channel = _channel;
    if (channel != null) unawaited(_syncAppearance(channel));
  }

  Future<void> _syncAppearance(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('appearance', {'dark': _dark});
    } on PlatformException {
      // A disposing browser must not interrupt a global appearance change.
    } on MissingPluginException {
      // Older native views remain alive during an incremental debug update.
    }
  }

  List<String> _entries(VideoSiteBrowser browser) =>
      browser.externalAuthenticationEntries
          .map(
            (entry) =>
                videoSiteExternalAuthenticationEntry(browser.home, entry),
          )
          .nonNulls
          .map((entry) => entry.toString())
          .toSet()
          .toList()
        ..sort();

  List<String> get _authenticationEntries => _entries(widget);

  @override
  void didUpdateWidget(covariant VideoSiteBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Metadata can arrive after the native view was created. Dart also checks
    // every event against current entries, rejecting a late event after revoke.
    final channel = _channel;
    if (channel != null &&
        !listEquals(_entries(oldWidget), _authenticationEntries)) {
      unawaited(_syncAuthenticationEntries(channel));
    }
  }

  Future<void> _syncAuthenticationEntries(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('externalAuthenticationEntries', {
        'entries': _authenticationEntries,
      });
    } on PlatformException {
      // A disposed native view may race this metadata update. Do not reload it
      // or broaden navigation; current-entry validation still rejects events.
    } on MissingPluginException {
      // The platform view/channel may already have been disposed.
    }
  }

  Future<dynamic> _event(MethodCall call) async {
    final controller = _controller;
    if (!mounted || controller == null) return false;
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final url = WebUri(args['url']?.toString() ?? '');
    final config = widget.configuration.platform.params;
    switch (call.method) {
      case 'externalAuth':
        final target = Uri.tryParse(args['url']?.toString() ?? '');
        final entry = target == null
            ? null
            : videoSiteExternalAuthenticationEntry(widget.home, target);
        if (entry != null &&
            _authenticationEntries.contains(entry.toString())) {
          widget.onExternalAuthentication?.call(entry);
        }
      case 'start':
        config.onLoadStart?.call(controller, url);
      case 'stop':
        config.onLoadStop?.call(controller, url);
      case 'commit':
        config.onPageCommitVisible?.call(controller, url);
      case 'history':
        config.onUpdateVisitedHistory?.call(controller, url, false);
      case 'navigation':
        return await config.shouldOverrideUrlLoading?.call(
              controller,
              NavigationAction(
                request: URLRequest(url: url),
                isForMainFrame: args['main'] == true,
              ),
            ) ==
            NavigationActionPolicy.ALLOW;
      case 'http':
        config.onReceivedHttpError?.call(
          controller,
          WebResourceRequest(url: url, isForMainFrame: args['main'] == true),
          WebResourceResponse(
            statusCode: args['status'] as int?,
            headers: Map<String, String>.from(args['headers'] as Map? ?? {}),
          ),
        );
      case 'response':
        final responseUrl = Uri.tryParse(args['url']?.toString() ?? '');
        final status = args['status'];
        if (responseUrl != null && status is int) {
          widget.onDocumentResponse?.call(
            responseUrl,
            status,
            Map<String, String>.from(args['headers'] as Map? ?? {}),
          );
        }
      case 'error':
        if (args['stage'] == 'process' &&
            args['domain'] == 'webkit' &&
            args['code'] == 2 &&
            config.onWebContentProcessDidTerminate != null) {
          config.onWebContentProcessDidTerminate?.call(controller);
          break;
        }
        config.onReceivedError?.call(
          controller,
          WebResourceRequest(url: url, isForMainFrame: true),
          WebResourceError(
            type: args['code'] == -999 && args['domain'] == 'url'
                ? WebResourceErrorType.CANCELLED
                : WebResourceErrorType.UNKNOWN,
            description: videoSiteNativeFailureLabel(args),
          ),
        );
    }
    return null;
  }

  @override
  void dispose() {
    final platform = _controller?.platform;
    if (platform is VideoSiteBrowserController) {
      unawaited(platform.closeAccountCookieAccess().catchError((Object _) {}));
    }
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isFinite && !size.isEmpty) {
          _viewport = size;
          final channel = _channel;
          if (channel != null) unawaited(_syncViewport(channel, size));
        }
        return Offstage(
          offstage: !widget.visible,
          child: !Platform.isIOS ? widget.configuration : _nativeView(),
        );
      },
    );
  }

  Widget _nativeView() => UiKitView(
    viewType: 'breeze.video.browser.view',
    creationParams: {
      'home': widget.home.toString(),
      'viewportWidth': _viewport?.width,
      'viewportHeight': _viewport?.height,
      'dark': _dark,
      'source': widget.source,
      'networkContext': widget.networkContext,
      'dialogConfirm': t.common.confirm,
      'dialogCancel': t.common.cancel,
      'externalAuthenticationEntries': _authenticationEntries,
      'verificationWindowTitle': t.videoPlayback.verificationTitle,
      'verificationWindowReturn': t.videoPlayback.verificationWindowReturn,
      'verificationWindowHint': t.videoPlayback.verificationWindowHint,
      'verificationWindowCancel': t.common.cancel,
    },
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      final channel = MethodChannel('breeze.video.browser.$id');
      _channel = channel;
      final viewport = _viewport;
      if (viewport != null) unawaited(_syncViewport(channel, viewport));
      _controller = InAppWebViewController.fromPlatform(
        platform: VideoSiteBrowserController(
          channel,
          id,
          accountSource: widget.source,
          accountHome: widget.home,
        ),
      );
      channel.setMethodCallHandler(_event);
      unawaited(_syncAppearance(channel));
      // A platform view can finish creating after metadata changed. Sync the
      // current list before callers issue their first load command.
      unawaited(_syncAuthenticationEntries(channel));
      widget.configuration.platform.params.onWebViewCreated?.call(_controller!);
    },
  );
}

abstract interface class VideoBrowserInspection {
  Future<bool> setInspectionEnabled(bool enabled);
}

/// Retain this document for same-origin reads after its platform view leaves.
abstract interface class VideoBrowserBackgroundLifetime {
  Future<void> retainBackground();
  Future<void> releaseBackground();
}

abstract interface class VideoBrowserVerificationWindow {
  /// The user decides when to return; opening a window is not verification.
  Future<bool> openVerificationWindow(Uri url);
}

/// Resolve a host-authored expression on both the plain iOS browser and the
/// standard Android WebView. evaluateJavascript alone cannot await a Promise.
Future<dynamic> videoBrowserReadAsync(
  InAppWebViewController controller,
  String expression,
) async {
  final owner = VideoDownloadResolutionOwner.current;
  if (owner == null) return _rawVideoBrowserReadAsync(controller, expression);
  owner.check();
  final token = '${owner.token}-${++_downloadReadSequence}';
  final key = jsonEncode(token);
  final remove = owner.onCancel(() async {
    final stopped = await _rawVideoBrowserReadAsync(controller, """
(async () => {
  const key = $key;
  const cancelled = globalThis.__breezeDownloadReadCancelled ||= new Set();
  cancelled.add(key);
  while (cancelled.size > 64) cancelled.delete(cancelled.values().next().value);
  const entry = globalThis.__breezeDownloadReads?.get(key);
  if (entry) { entry.controller.abort(); await entry.done; }
  return true;
})()
""").timeout(const Duration(seconds: 5));
    if (stopped != true) throw StateError('Owned document read did not stop');
  });
  try {
    return await _rawVideoBrowserReadAsync(controller, """
(async () => {
  const key = $key;
  const cancelled = globalThis.__breezeDownloadReadCancelled ||= new Set();
  if (cancelled.has(key)) { cancelled.delete(key); throw new Error('cancelled'); }
  const reads = globalThis.__breezeDownloadReads ||= new Map();
  const controller = new AbortController(), cleanup = [];
  let finish; const done = new Promise(resolve => { finish = resolve; });
  reads.set(key, {controller, done});
  const fetch = (url, init = {}) => {
    if (controller.signal.aborted) return Promise.reject(new Error('cancelled'));
    const merged = new AbortController();
    for (const signal of [controller.signal, init.signal].filter(Boolean)) {
      const abort = () => merged.abort();
      if (signal.aborted) abort(); else signal.addEventListener('abort', abort, {once:true});
      cleanup.push(() => signal.removeEventListener('abort', abort));
    }
    return globalThis.fetch(url, {...init, signal:merged.signal});
  };
  try { return await ($expression); }
  finally { for (const remove of cleanup) remove(); reads.delete(key); cancelled.delete(key); finish(); }
})()
""");
  } finally {
    remove();
  }
}

int _downloadReadSequence = 0;

Future<dynamic> _rawVideoBrowserReadAsync(
  InAppWebViewController controller,
  String expression,
) async {
  final platform = controller.platform;
  if (platform is VideoSiteBrowserController) {
    return platform.evaluateAsyncJavascript(expression);
  }
  final result = await controller.callAsyncJavaScript(
    functionBody: 'return await ($expression);',
  );
  if (result == null || result.error != null) {
    // Script errors can include private page values. Keep the failure generic.
    throw StateError('Asynchronous document read failed');
  }
  return result.value;
}

class VideoSiteBrowserController extends PlatformInAppWebViewController
    implements
        VideoBrowserInspection,
        VideoBrowserVerificationWindow,
        VideoBrowserBackgroundLifetime,
        VideoAccountCookies {
  VideoSiteBrowserController(
    this.channel,
    int id, {
    String? accountSource,
    Uri? accountHome,
  }) : _accountSource = accountSource,
       _accountHome = accountHome,
       super.implementation(
         PlatformInAppWebViewControllerCreationParams(id: id),
       );
  final MethodChannel channel;
  final String? _accountSource;
  final Uri? _accountHome;
  bool _accountViewDisposed = false;
  String? _accountViewToken;
  final _accountLeases = <_NativeVideoAccountCookies>{};
  _NativeVideoAccountCookies? _defaultAccountLease;

  bool get hasAccountCookieContext {
    final source = _accountSource;
    final home = _accountHome;
    return !_accountViewDisposed &&
        source != null &&
        source.isNotEmpty &&
        source.length <= 200 &&
        home != null &&
        home.scheme == 'https' &&
        home.host.isNotEmpty &&
        home.userInfo.isEmpty &&
        (!home.hasPort || home.port == 443);
  }

  VideoAccountCookies newAccountCookieLease() {
    if (!hasAccountCookieContext)
      throw StateError('Source account cookie context is unavailable');
    final lease = _NativeVideoAccountCookies(this);
    _accountLeases.add(lease);
    return lease;
  }

  _NativeVideoAccountCookies get _defaultCookies => _defaultAccountLease ??=
      newAccountCookieLease() as _NativeVideoAccountCookies;
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async =>
      _defaultCookies.read(origin);
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async =>
      _defaultCookies.set(origin, cookie);
  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async =>
      _defaultCookies.delete(origin, cookie);

  Future<void> _disposeNativeAccountView(String token) async {
    if (await channel.invokeMethod<Object?>('accountCookiesDispose', {
          'viewToken': token,
        }) !=
        true) {
      throw StateError('Source account cookie context could not be closed');
    }
  }

  bool _acceptAccountViewToken(String token) {
    if (_accountViewToken != null && _accountViewToken != token) return false;
    _accountViewToken = token;
    if (_accountViewDisposed) {
      unawaited(_disposeNativeAccountView(token).catchError((Object _) {}));
      return false;
    }
    return true;
  }

  /// Widget disposal is permanent; registration leases can close independently
  /// while the same browser remains usable by a later source registration.
  Future<void> closeAccountCookieAccess() async {
    if (_accountViewDisposed) return;
    _accountViewDisposed = true;
    final closes = [
      for (final lease in _accountLeases.toList())
        lease.closeAccountCookieAccess(),
    ];
    final viewToken = _accountViewToken;
    if (viewToken != null) closes.add(_disposeNativeAccountView(viewToken));
    await Future.wait(closes);
  }

  @override
  Future<void> retainBackground() async {
    if (await channel.invokeMethod<bool>('retainBackground') != true) {
      throw StateError('Browser document could not be retained');
    }
  }

  @override
  Future<void> releaseBackground() async {
    if (await channel.invokeMethod<bool>('releaseBackground') != true) {
      throw StateError('Browser document could not be released');
    }
  }

  @override
  Future<bool> openVerificationWindow(Uri url) async =>
      await channel.invokeMethod<String>('verificationWindow', {
        'url': url.toString(),
      }) ==
      'retry';

  /// Resolve the result of a host-authored asynchronous read, including its Promise.
  Future<dynamic> evaluateAsyncJavascript(String source) =>
      channel.invokeMethod<dynamic>('evaluateAsync', {'source': source});

  /// Explicit, session-only consent. Does not reload the website or export a
  /// HAR/console log; inspection itself is performed with Apple's tools.
  @override
  Future<bool> setInspectionEnabled(bool enabled) async =>
      await channel.invokeMethod<bool>('inspectable', {'enabled': enabled}) ??
      false;

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    await channel.invokeMethod<void>('load', {
      'url': urlRequest.url.toString(),
    });
  }

  @override
  Future<void> stopLoading() => channel.invokeMethod<void>('stop');
  @override
  Future<void> reload() => channel.invokeMethod<void>('reload');
  @override
  Future<WebUri?> getUrl() async {
    final value = await channel.invokeMethod<String>('url');
    return value == null ? null : WebUri(value);
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) => channel.invokeMethod<dynamic>('evaluate', {'source': source});
  @override
  Future<bool> canGoBack() async =>
      await channel.invokeMethod<bool>('canGoBack') ?? false;
  @override
  Future<void> goBack() => channel.invokeMethod<void>('goBack');
}

/// One coordinator registration owns one independently revocable native lease.
/// Raw cookie values and native tokens never enter persistence or diagnostics.
class _NativeVideoAccountCookies
    implements VideoAccountCookies, VideoAccountCookieLifetime {
  _NativeVideoAccountCookies(this._owner);
  final VideoSiteBrowserController _owner;
  bool _closed = false;
  int _epoch = 0;
  String? _token;
  Future<String>? _binding;

  void _check(int epoch, Uri origin) {
    if (_closed ||
        epoch != _epoch ||
        !_owner.hasAccountCookieContext ||
        origin.scheme != 'https' ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        origin.origin != _owner._accountHome!.origin) {
      throw StateError('Source account cookie context is unavailable');
    }
  }

  Future<void> _closeNative(String token) async {
    if (await _owner.channel.invokeMethod<Object?>('accountCookiesClose', {
          'token': token,
        }) !=
        true) {
      throw StateError('Source account cookie lease could not be closed');
    }
  }

  Future<String> _bind() => _binding ??= () async {
    final value = await _owner.channel
        .invokeMethod<Object?>('accountCookieContext', {
          'source': _owner._accountSource,
          'origin': _owner._accountHome!.origin,
          if (_owner._accountViewToken != null)
            'viewToken': _owner._accountViewToken,
        });
    bool token(Object? raw) =>
        raw is String && RegExp(r'^[a-f0-9-]{36}$').hasMatch(raw);
    if (value is! Map ||
        value['source'] != _owner._accountSource ||
        value['origin'] != _owner._accountHome.origin ||
        !token(value['token']) ||
        !token(value['viewToken'])) {
      throw StateError('Source account cookie context is unavailable');
    }
    final leaseToken = _token = value['token'] as String;
    final accepted = _owner._acceptAccountViewToken(
      value['viewToken'] as String,
    );
    if (_closed || !accepted) {
      await _closeNative(leaseToken);
      throw StateError('Source account cookie context is unavailable');
    }
    return leaseToken;
  }();
  Future<Object?> _request(
    String method,
    Uri origin, [
    Map<String, dynamic>? cookie,
  ]) async {
    final epoch = _epoch;
    _check(epoch, origin);
    final token = await _bind();
    _check(epoch, origin);
    final value = await _owner.channel.invokeMethod<Object?>(method, {
      'token': token,
      'origin': origin.origin,
      if (cookie != null)
        'cookie': {
          for (final key in const [
            'name',
            'value',
            'domain',
            'path',
            'httpOnly',
            'secure',
            'expires',
          ])
            if (cookie.containsKey(key)) key: cookie[key],
        },
    });
    _check(epoch, origin);
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async {
    final value = await _request('accountCookiesRead', origin);
    if (value is! List || value.any((cookie) => cookie is! Map)) {
      throw StateError('Source account cookies could not be read');
    }
    return [
      for (final cookie in value) Map<String, dynamic>.from(cookie as Map),
    ];
  }

  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    if (await _request('accountCookiesSet', origin, cookie) != true) {
      throw StateError('Source account cookie write was not verified');
    }
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    if (await _request('accountCookiesDelete', origin, cookie) != true) {
      throw StateError('Source account cookie removal was not verified');
    }
  }

  @override
  Future<void> closeAccountCookieAccess() async {
    if (_closed) return;
    _closed = true;
    _epoch++;
    _owner._accountLeases.remove(this);
    final token = _token;
    if (token != null) await _closeNative(token);
  }
}
