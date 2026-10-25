import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zephyr/i18n/strings.g.dart';

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
    this.onDocumentResponse,
    this.externalAuthenticationEntries = const [],
    this.onExternalAuthentication,
  });
  final Uri home;
  final InAppWebView configuration;

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
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return widget.configuration;
    return UiKitView(
      viewType: 'breeze.video.browser.view',
      creationParams: {
        'home': widget.home.toString(),
        'dialogConfirm': t.common.confirm,
        'dialogCancel': t.common.cancel,
        'externalAuthenticationEntries': _authenticationEntries,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        if (!mounted) return;
        final channel = MethodChannel('breeze.video.browser.$id');
        _channel = channel;
        _controller = InAppWebViewController.fromPlatform(
          platform: VideoSiteBrowserController(channel, id),
        );
        channel.setMethodCallHandler(_event);
        // A platform view can finish creating after metadata changed. Sync the
        // current list before callers issue their first load command.
        unawaited(_syncAuthenticationEntries(channel));
        widget.configuration.platform.params.onWebViewCreated?.call(
          _controller!,
        );
      },
    );
  }
}

abstract interface class VideoBrowserInspection {
  Future<bool> setInspectionEnabled(bool enabled);
}

class VideoSiteBrowserController extends PlatformInAppWebViewController
    implements VideoBrowserInspection {
  VideoSiteBrowserController(this.channel, int id)
    : super.implementation(
        PlatformInAppWebViewControllerCreationParams(id: id),
      );
  final MethodChannel channel;

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
