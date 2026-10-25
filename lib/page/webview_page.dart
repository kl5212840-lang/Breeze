import 'package:zephyr/page/video/video_page_route.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/event/webview_observe_bus.dart';
import 'package:zephyr/page/web_navigation_config.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_page.dart';

@RoutePage()
class WebViewPage extends StatefulWidget {
  final List<String> info;

  const WebViewPage({super.key, required this.info});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  static const _nativePlaybackHandler = 'breezeNativePlayback';
  static const Set<String> _inAppSchemes = {
    'about',
    'data',
    'file',
    'http',
    'https',
    'javascript',
  };

  Webview? _linuxWebview;
  bool _isWebviewClosed = false;

  InAppWebViewController? _controller;
  int _progress = 0;
  String? _mainFrameError;
  String? _lastObservedUrl;
  String? _currentUrl;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isFullscreen = false;
  bool _exitRequested = false;
  bool _startingNativePlayback = false;

  WebNavigationConfig? get _navigation =>
      WebNavigationConfig.fromRouteInfo(widget.info);

  String get _title =>
      widget.info.isNotEmpty ? widget.info[0] : t.webview.title;

  String get _url => widget.info.length > 1 ? widget.info[1].trim() : '';

  Uri? get _uri {
    if (_url.isEmpty) {
      return null;
    }
    return Uri.tryParse(_url);
  }

  bool get _isValidUrl {
    final uri = _uri;
    if (uri == null) {
      return false;
    }
    return uri.hasScheme && (uri.isScheme('http') || uri.isScheme('https'));
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux && _isValidUrl) {
      _openLinuxWebView();
    }
  }

  Future<void> _openLinuxWebView() async {
    final url = _url;
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(title: _title, titleBarHeight: 0),
    );

    webview.setOnUrlRequestCallback((nextUrl) {
      unawaited(
        _reportUrlChangeAndCookies(nextUrl, trigger: 'linux_url_request'),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          await _reportUrlChangeAndCookies(
            nextUrl,
            trigger: 'linux_url_settled',
            force: true,
          );
        }),
      );
      return true;
    });

    _linuxWebview = webview;
    webview.launch(url);
    unawaited(
      _reportUrlChangeAndCookies(url, trigger: 'linux_launch', force: true),
    );

    webview.onClose.then((_) {
      if (mounted) {
        setState(() => _isWebviewClosed = true);
      }
    });
  }

  @override
  void dispose() {
    if (Platform.isLinux && !_isWebviewClosed && _linuxWebview != null) {
      _linuxWebview!.close();
    }
    super.dispose();
  }

  Future<void> _openExternal(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.webview.cannotOpenLink(uri: uri.toString()))),
      );
    }
  }

  Future<void> _openExternalFromRaw(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await _openExternal(uri);
  }

  Future<void> _updateHistory(InAppWebViewController controller) async {
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  Future<void> _loadSiteUrl(Uri url) async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _mainFrameError = null);
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url.toString())),
    );
  }

  Future<void> _tryNativePlayback(
    WebPlaybackConfig playback,
    Uri watchUrl, {
    bool fromWebsitePlay = false,
  }) async {
    final controller = _controller;
    if (controller == null || _startingNativePlayback) return;
    setState(() => _startingNativePlayback = true);
    try {
      // Read only the standard video element. The site-specific selector and
      // source normalization belong to the plugin, not the host player.
      final selector = jsonEncode(playback.videoSelector);
      final raw = await controller.evaluateJavascript(
        source:
            '''
          (() => {
            const video = document.querySelector($selector);
            if (!video) return JSON.stringify({title: document.title, video: null});
            return JSON.stringify({
              title: document.title,
              description: document.querySelector('.video-description-panel .video-caption-text')?.textContent?.trim() || '',
              tags: Array.from(document.querySelectorAll('.video-tags-wrapper .single-video-tag a'))
                .map((item) => item.textContent?.trim() || '')
                .filter(Boolean).slice(0, 32),
              video: {
                currentSrc: video.currentSrc || video.getAttribute('src') || '',
                sources: Array.from(video.querySelectorAll('source')).map((item) => ({
                  src: item.getAttribute('src') || '',
                  size: item.getAttribute('size') || '',
                  label: item.getAttribute('label') || ''
                }))
              }
            });
          })()
        ''',
      );
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) throw const FormatException('Video not found');
      final snapshot = Map<String, dynamic>.from(decoded);
      final result = await callUnifiedComicPlugin(
        from: playback.source,
        fnPath: playback.fnPath,
        core: {'watchUrl': watchUrl.toString(), 'snapshot': snapshot},
      );
      final session = NativePlaybackSession.fromPluginResponse(
        result,
        watchUrl: watchUrl,
      );
      if (!mounted) return;
      final useWebsite = await Navigator.of(context).push<bool>(
        videoPageRoute(
          builder: (_) =>
              NativeVideoPage(session: session, source: playback.source),
        ),
      );
      if (useWebsite == true) {
        await _allowWebsitePlayback(watchUrl);
      }
    } catch (_) {
      if (fromWebsitePlay) await _allowWebsitePlayback(watchUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.webview.nativePlaybackUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _startingNativePlayback = false);
    }
  }

  Future<void> _allowWebsitePlayback(Uri watchUrl) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(
        source:
            'window.__breezeNativePlaybackDisabledFor = ${jsonEncode(watchUrl.toString())};',
      );
    } catch (_) {
      // The web page may have navigated while the native player was open.
    }
  }

  String _nativePlaybackTapScript(WebPlaybackConfig playback) {
    final origin = jsonEncode(playback.origin);
    final path = jsonEncode(playback.watchPath);
    final selector = jsonEncode(playback.playTriggerSelector);
    final videoSelector = jsonEncode(playback.videoSelector);
    return '''
      (() => {
        if (window.__breezeNativePlaybackTapHook) return;
        window.__breezeNativePlaybackTapHook = true;
        document.addEventListener('click', (event) => {
          if (location.origin !== $origin || location.pathname !== $path ||
              window.__breezeNativePlaybackDisabledFor === location.href) return;
          const target = event.target;
          if (!(target instanceof Element) || !target.closest($selector)) return;
          const video = document.querySelector($videoSelector);
          if (!video || !(video.currentSrc || video.getAttribute('src') ||
              video.querySelector('source[src]'))) return;
          if (!window.flutter_inappwebview?.callHandler) return;
          event.preventDefault();
          event.stopImmediatePropagation();
          window.flutter_inappwebview.callHandler('$_nativePlaybackHandler');
        }, true);
      })()
    ''';
  }

  Future<void> _installNativePlaybackTapHook(
    InAppWebViewController controller,
  ) async {
    final playback = _navigation?.playback;
    if (playback == null || playback.playTriggerSelector.isEmpty) return;
    try {
      await controller.evaluateJavascript(
        source: _nativePlaybackTapScript(playback),
      );
    } catch (_) {
      // If injection fails, the website's original player remains usable.
    }
  }

  void _closeWebPage() {
    setState(() => _exitRequested = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Widget _siteNavigationBar(
    BuildContext context,
    WebNavigationConfig navigation,
  ) {
    final colors = Theme.of(context).colorScheme;
    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) => Expanded(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              action(
                icon: Icons.arrow_back_rounded,
                label: t.webview.siteBack,
                onPressed: _canGoBack ? () => _controller?.goBack() : null,
              ),
              action(
                icon: Icons.home_outlined,
                label: t.webview.siteHome,
                onPressed: () => _loadSiteUrl(navigation.homeUrl),
              ),
              if (navigation.searchUrl != null)
                action(
                  icon: Icons.search_rounded,
                  label: t.webview.siteSearch,
                  onPressed: () => _loadSiteUrl(navigation.searchUrl!),
                )
              else
                action(
                  icon: Icons.arrow_forward_rounded,
                  label: t.webview.forward,
                  onPressed: _canGoForward
                      ? () => _controller?.goForward()
                      : null,
                ),
              action(
                icon: Icons.refresh_rounded,
                label: t.common.refresh,
                onPressed: () {
                  setState(() => _mainFrameError = null);
                  _controller?.reload();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _platformTag => Platform.isLinux ? 'linux' : 'inappwebview';

  Future<void> _reportUrlChangeAndCookies(
    String? rawUrl, {
    required String trigger,
    bool force = false,
    int? statusCode,
    String? errorDescription,
  }) async {
    final url = (rawUrl ?? '').trim();
    if (url.isEmpty) {
      return;
    }
    if (!force && _lastObservedUrl == url) {
      return;
    }
    _lastObservedUrl = url;

    final cookies = await _collectAllCookieSnapshots(url);
    final event = WebViewObserveEvent(
      url: url,
      trigger: trigger,
      platform: _platformTag,
      observedAt: DateTime.now(),
      cookies: cookies,
      statusCode: statusCode,
      errorDescription: errorDescription,
    );
    WebViewObserveBus.emit(event);
    logger.d(
      '[WebViewObserve] platform=${event.platform} trigger=${event.trigger} '
      'url=${event.url} cookies=${event.cookies.length}',
    );
  }

  Future<List<WebViewCookieSnapshot>> _collectAllCookieSnapshots(
    String currentUrl,
  ) async {
    if (Platform.isLinux) {
      final webview = _linuxWebview;
      if (webview == null) {
        return const [];
      }
      try {
        final cookies = await webview.getAllCookies(allDomains: true);
        return cookies
            .map(
              (cookie) => WebViewCookieSnapshot(
                name: cookie.name,
                value: cookie.value,
                domain: cookie.domain,
                path: cookie.path,
                expiresDate: cookie.expires?.millisecondsSinceEpoch,
                isSecure: cookie.secure,
                isHttpOnly: cookie.httpOnly,
                isSessionOnly: cookie.sessionOnly,
              ),
            )
            .toList(growable: false);
      } catch (e, stackTrace) {
        logger.e(
          '[WebViewObserve] linux getAllCookies failed',
          error: e,
          stackTrace: stackTrace,
        );
        return const [];
      }
    }

    return _collectMobileCookies(currentUrl);
  }

  Future<List<WebViewCookieSnapshot>> _collectMobileCookies(
    String currentUrl,
  ) async {
    final manager = CookieManager.instance();
    try {
      final cookies = await manager.getAllCookies();
      if (cookies.isNotEmpty) {
        return cookies
            .map(
              (cookie) => WebViewCookieSnapshot(
                name: cookie.name,
                value: '${cookie.value ?? ''}',
                domain: cookie.domain,
                path: cookie.path,
                expiresDate: cookie.expiresDate,
                isSecure: cookie.isSecure,
                isHttpOnly: cookie.isHttpOnly,
                isSessionOnly: cookie.isSessionOnly,
              ),
            )
            .toList(growable: false);
      }
    } catch (e, stackTrace) {
      logger.e(
        '[WebViewObserve] getAllCookies failed',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final uri = Uri.tryParse(currentUrl);
    if (uri == null || !uri.hasScheme) {
      return const [];
    }

    try {
      final cookies = await manager.getCookies(
        url: WebUri(uri.toString()),
        webViewController: _controller,
      );
      return cookies
          .map(
            (cookie) => WebViewCookieSnapshot(
              name: cookie.name,
              value: '${cookie.value ?? ''}',
              domain: cookie.domain,
              path: cookie.path,
              expiresDate: cookie.expiresDate,
              isSecure: cookie.isSecure,
              isHttpOnly: cookie.isHttpOnly,
              isSessionOnly: cookie.isSessionOnly,
            ),
          )
          .toList(growable: false);
    } catch (e, stackTrace) {
      logger.e(
        '[WebViewObserve] getCookies(url) failed',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Widget _buildInvalidUrlView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            Text(t.webview.invalidLink),
            const SizedBox(height: 8),
            Text(
              _url.isEmpty ? t.webview.emptyLink : _url,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainFrameError(BuildContext context) {
    final uri = Uri.tryParse(_currentUrl ?? _url);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_mainFrameError ?? t.webview.loadFailed),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      _mainFrameError = null;
                      _progress = 0;
                    });
                    _controller?.reload();
                  },
                  child: Text(t.webview.retry),
                ),
                if (uri != null)
                  FilledButton.tonalIcon(
                    onPressed: () => _openExternal(uri),
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(t.webview.openInExternalBrowser),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinuxBody(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isWebviewClosed ? Icons.check_circle_outline : Icons.open_in_new,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _isWebviewClosed
                ? t.webview.windowClosed
                : t.webview.openedInExternalWindow,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _url,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (_isWebviewClosed) ...[
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.webview.back),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    if (!_isValidUrl) {
      return _buildInvalidUrlView(context);
    }

    final webUri = WebUri(_url);
    final playback = _navigation?.playback;

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: webUri),
          initialUserScripts:
              playback != null && playback.playTriggerSelector.isNotEmpty
              ? UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _nativePlaybackTapScript(playback),
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                  ),
                ])
              : null,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useShouldOverrideUrlLoading: true,
            isInspectable: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            cacheEnabled: true,
            transparentBackground: false,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
            // Android 15/16 + 部分机型使用 Hybrid Composition 可能出现白屏。
            useHybridComposition: false,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            final playback = _navigation?.playback;
            if (playback != null && playback.playTriggerSelector.isNotEmpty) {
              controller.addJavaScriptHandler(
                handlerName: _nativePlaybackHandler,
                callback: (_) {
                  final uri = Uri.tryParse(_currentUrl ?? _url);
                  if (playback.matches(uri) && uri != null) {
                    unawaited(
                      _tryNativePlayback(playback, uri, fromWebsitePlay: true),
                    );
                  }
                  return null;
                },
              );
            }
          },
          onEnterFullscreen: (_) {
            if (mounted) setState(() => _isFullscreen = true);
          },
          onExitFullscreen: (_) {
            if (mounted) setState(() => _isFullscreen = false);
          },
          onLoadStart: (_, url) {
            if (mounted) {
              setState(() {
                _mainFrameError = null;
                _currentUrl = url?.toString();
              });
            }
            unawaited(
              _reportUrlChangeAndCookies(
                url?.toString(),
                trigger: 'load_start',
              ),
            );
          },
          onLoadStop: (controller, url) {
            unawaited(_updateHistory(controller));
            unawaited(_installNativePlaybackTapHook(controller));
            unawaited(
              _reportUrlChangeAndCookies(
                url?.toString(),
                trigger: 'load_stop',
                force: true,
              ),
            );
          },
          onUpdateVisitedHistory: (controller, url, _) {
            _currentUrl = url?.toString();
            unawaited(_updateHistory(controller));
            unawaited(
              _reportUrlChangeAndCookies(
                url?.toString(),
                trigger: 'history_changed',
              ),
            );
          },
          onProgressChanged: (_, progress) {
            if (mounted) {
              setState(() {
                _progress = progress.clamp(0, 100).toInt();
              });
            }
          },
          shouldOverrideUrlLoading: (_, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) {
              return NavigationActionPolicy.ALLOW;
            }
            if (!_inAppSchemes.contains(uri.scheme)) {
              await _openExternalFromRaw(uri.toString());
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame != true ||
                error.type == WebResourceErrorType.CANCELLED) {
              return;
            }
            unawaited(
              _reportUrlChangeAndCookies(
                request.url.toString(),
                trigger: 'load_error',
                force: true,
                errorDescription: '${error.type}: ${error.description}',
              ),
            );
            if (mounted) {
              setState(() {
                _mainFrameError = t.webview.loadFailed;
              });
            }
          },
          onReceivedHttpError: (_, request, response) {
            if (request.isForMainFrame != true) {
              return;
            }
            unawaited(
              _reportUrlChangeAndCookies(
                request.url.toString(),
                trigger: 'http_error',
                force: true,
                statusCode: response.statusCode,
                errorDescription: response.reasonPhrase,
              ),
            );
            // Keep the server response visible (including verification pages).
          },
        ),
        if (_mainFrameError != null)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _buildMainFrameError(context),
            ),
          ),
        if (_mainFrameError == null && _progress < 100)
          Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(value: _progress / 100),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(_currentUrl ?? _url);
    final navigation = _navigation;
    final playback = navigation?.playback;
    final canTryNativePlayback =
        !Platform.isLinux &&
        playback != null &&
        playback.matches(uri) &&
        _mainFrameError == null;

    final page = Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: navigation == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: t.webview.closeWebpage,
                onPressed: _closeWebPage,
              ),
        actions: <Widget>[
          if (canTryNativePlayback)
            _startingNativePlayback
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    tooltip: t.webview.nativePlaybackTrial,
                    onPressed: () =>
                        unawaited(_tryNativePlayback(playback, uri!)),
                  ),
          if (Platform.isLinux && !_isWebviewClosed)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: t.webview.closeWindow,
              onPressed: () {
                _linuxWebview?.close();
                if (mounted) {
                  setState(() => _isWebviewClosed = true);
                }
              },
            ),
          if (uri != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => _openExternal(uri),
            ),
        ],
      ),
      body: Platform.isLinux
          ? _buildLinuxBody(context)
          : _buildMobileBody(context),
      bottomNavigationBar:
          !Platform.isLinux && navigation != null && !_isFullscreen
          ? _siteNavigationBar(context, navigation)
          : null,
    );
    if (navigation == null || Platform.isLinux) return page;
    return PopScope(
      canPop: _exitRequested || !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoBack && !_exitRequested) _controller?.goBack();
      },
      child: page,
    );
  }
}
