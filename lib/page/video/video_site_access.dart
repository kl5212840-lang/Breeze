import 'dart:convert';

import 'package:zephyr/page/video/video_catalog_dom.dart';
import 'package:zephyr/page/video/video_document_match.dart';

/// Diagnostics retain route kind, not profile IDs or private URL paths.
String videoSiteDiagnosticPath(Uri? uri) =>
    const {
      '/',
      '/search',
      '/watch',
      '/login',
      '/register',
      '/subscriptions',
    }.contains(uri?.path)
    ? uri!.path
    : '/other';

/// Only navigation frames are filtered here, not arbitrary resource requests.
/// Keep third-party top-level pages blocked while allowing the site's human
/// verification frame to run in the existing browser and cookie store.
bool allowVideoSiteNavigation(
  Uri home,
  Uri? destination, {
  required bool isMainFrame,
}) {
  if (destination == null || destination.userInfo.isNotEmpty) return false;
  if (!isMainFrame &&
      destination.scheme == 'about' &&
      const {'blank', 'srcdoc'}.contains(destination.path)) {
    return true;
  }
  if (destination.scheme != 'https' ||
      (destination.hasPort && destination.port != 443)) {
    return false;
  }
  // Subframes are ordinary browser content, not top-level app navigation.
  // Do not impose an incomplete provider allowlist on their HTTPS redirects;
  // WKWebView retains its normal origin isolation and transport protections.
  return !isMainFrame || destination.host == home.host;
}

/// Cloudflare can temporarily add challenge parameters to the same document.
/// Do not let those tokens change video identity, diagnostics or saved URLs.
Uri videoSiteDocumentUrl(Uri uri) {
  final document = uri.removeFragment();
  if (!document.hasQuery) return document;
  final parameters = {
    for (final entry in uri.queryParametersAll.entries)
      if (!entry.key.startsWith('__cf_chl_')) entry.key: entry.value,
  };
  if (parameters.isEmpty) {
    // Uri.replace(queryParameters: {}) creates a trailing '?'. That changes
    // hasQuery and invalidates strict profile identities when restoring back.
    // Remove the delimiter from the encoded URI; do not decode/rebuild paths.
    final encoded = document.toString();
    return Uri.parse(encoded.substring(0, encoded.indexOf('?')));
  }
  return document.replace(queryParameters: parameters);
}

bool videoSiteDocumentMatches(Uri? expected, Uri? actual) =>
    expected != null &&
    actual != null &&
    videoDocumentMatches(
      videoSiteDocumentUrl(expected),
      videoSiteDocumentUrl(actual),
    );

class VideoSiteVerificationRequired implements Exception {
  const VideoSiteVerificationRequired();
}

class VideoSiteState {
  const VideoSiteState({
    required this.url,
    required this.challenge,
    required this.nativeReady,
    required this.websiteReady,
    this.browser = const {},
  });

  final Uri? url;
  final bool challenge, nativeReady, websiteReady;
  final Map<String, Object> browser;

  factory VideoSiteState.fromRaw(dynamic raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) throw const FormatException('Invalid site state');
    final nativeReady = decoded['nativeContent'] == true;
    // A Turnstile widget in a real login form is not an interstitial. Nor is
    // an empty directory sufficient evidence of a challenge or a bad network.
    final challenge =
        !nativeReady &&
        (decoded['challengeForm'] == true ||
            decoded['challengeShell'] == true ||
            (decoded['clearanceConfig'] == true &&
                (decoded['challengeTitle'] == true ||
                    decoded['challengeFrame'] == true)));
    return VideoSiteState(
      url: Uri.tryParse(decoded['url']?.toString() ?? ''),
      challenge: challenge,
      nativeReady: nativeReady,
      websiteReady: !challenge && (nativeReady || decoded['siteUi'] == true),
      browser: {
        'challengeErrorCodes': [
          for (final code
              in (decoded['challengeErrorCodes'] is List
                      ? decoded['challengeErrorCodes'] as List
                      : const [])
                  .take(8))
            if (code is String &&
                RegExp(
                  r'^(?:110\d{3}|200100|200500|300\d{3}|400\d{3}|600\d{3})$',
                ).hasMatch(code))
              code,
        ],
        'challengeResources': [
          for (final entry
              in (decoded['challengeResources'] is List
                      ? decoded['challengeResources'] as List
                      : const [])
                  .take(12))
            if (entry is Map)
              {
                'host': entry['host'] == 'provider' ? 'provider' : 'site',
                'stage':
                    ['pat', 'script', 'flow', 'other'].contains(entry['stage'])
                    ? entry['stage']
                    : 'other',
                'type':
                    [
                      'script',
                      'iframe',
                      'fetch',
                      'xmlhttprequest',
                    ].contains(entry['type'])
                    ? entry['type']
                    : 'other',
                'status':
                    entry['status'] is int &&
                        entry['status'] >= 0 &&
                        entry['status'] < 600
                    ? entry['status']
                    : 0,
                'durationMs': entry['durationMs'] is int
                    ? (entry['durationMs'] as int).clamp(0, 120000)
                    : 0,
              },
        ],
        for (final key in [
          'visibility',
          'viewportWidth',
          'viewportHeight',
          'cookiesEnabled',
          'challengeFrames',
          'readyState',
          'online',
          'secureContext',
          'domStorage',
          'userAgent',
          'frameObservation',
          'challengeScripts',
          'challengeResourceCount',
        ])
          if (decoded[key] is bool ||
              decoded[key] is int ||
              (key == 'visibility' &&
                  ['visible', 'hidden', 'prerender'].contains(decoded[key])) ||
              (key == 'readyState' &&
                  [
                    'loading',
                    'interactive',
                    'complete',
                  ].contains(decoded[key])) ||
              (key == 'domStorage' &&
                  ['available', 'unavailable'].contains(decoded[key])) ||
              (key == 'frameObservation' &&
                  decoded[key] == 'main-and-open-shadow-only') ||
              (key == 'userAgent' &&
                  decoded[key] is String &&
                  (decoded[key] as String).length <= 300))
            key: decoded[key] as Object,
      },
    );
  }
}

/// Read-only readiness signals. Never reads cookies, challenge tokens, form
/// inputs or the user's account data, and never clicks or solves a challenge.
String videoSiteStateScript(
  Map<String, String> selectors, {
  bool diagnostics = true,
}) =>
    '''
  (() => {
    const breezeSiteState = true;
    const config = ${jsonEncode(selectors)};
    const query = (selector) => selector ? document.querySelector(selector) : null;
    $videoSearchDiscoveryScript
    const diagnostic = {};
    if ($diagnostics) {
    // Turnstile may render inside a shadow root. A zero count only means
    // "not observable here", never "the widget did not load".
    let frames = 0, scripts = 0, inspected = 0;
    const visit = (root, depth) => {
      if (!root || depth > 6 || inspected >= 2000) return;
      for (const node of root.querySelectorAll('*')) {
        if (++inspected > 2000) break;
        const src = node.getAttribute('src') || '';
        if (node.tagName === 'IFRAME' && src.startsWith('https://challenges.cloudflare.com/')) frames++;
        if (node.tagName === 'SCRIPT' && (src.includes('challenges.cloudflare.com') || src.includes('/cdn-cgi/challenge-platform/'))) scripts++;
        if (node.shadowRoot) visit(node.shadowRoot, depth + 1);
      }
    };
    visit(document, 0);
    let domStorage = 'unavailable';
    try { if (window.localStorage && window.sessionStorage) domStorage = 'available'; } catch (_) {}
    const resourceEntries = performance.getEntriesByType('resource').filter((entry) => {
      try {
        const url = new URL(entry.name);
        return url.hostname === 'challenges.cloudflare.com' ||
          (url.origin === location.origin && url.pathname.startsWith('/cdn-cgi/challenge-platform/'));
      } catch (_) { return false; }
    });
    const challengeResources = resourceEntries.slice(-12).map((entry) => {
      const url = new URL(entry.name);
      return { host: url.hostname === 'challenges.cloudflare.com' ? 'provider' : 'site',
        stage: url.pathname.includes('/pat/') ? 'pat' : entry.initiatorType === 'script' ? 'script' : 'flow',
        type: entry.initiatorType,
        status: Number.isInteger(entry.responseStatus) ? entry.responseStatus : 0,
        durationMs: Math.round(entry.duration) };
    });
    const errorCodes = typeof window._cf_chl_opt === 'object'
      ? Array.from(document.querySelectorAll('[id*="error"], [class*="error"]')).slice(0, 20)
          .flatMap((node) => (node.textContent || '').match(/(?:110[0-9]{3}|200100|200500|300[0-9]{3}|400[0-9]{3}|600[0-9]{3})/g) || []).slice(0, 8)
      : [];
    Object.assign(diagnostic, {
      visibility: document.visibilityState,
      viewportWidth: Math.round(innerWidth), viewportHeight: Math.round(innerHeight),
      cookiesEnabled: navigator.cookieEnabled === true,
      challengeFrames: frames, challengeScripts: scripts,
      frameObservation: 'main-and-open-shadow-only',
      challengeResourceCount: resourceEntries.length, challengeResources,
      challengeErrorCodes: errorCodes,
      readyState: document.readyState, online: navigator.onLine === true,
      secureContext: window.isSecureContext === true, domStorage,
      userAgent: String(navigator.userAgent || '').slice(0, 300)
    });
    }
    const searchState = location.pathname === '/search' ? videoSearchResults(true).state : '';
    // The player appears before the author/description in the streamed HTML.
    // Wait only for DOM parsing; ads, images and subframes may keep loading.
    const nativeContent = location.pathname === '/watch'
      ? document.readyState !== 'loading' && Boolean(query(config.video) || query(config.detailDescription) || query(config.episodes))
      : location.pathname === '/search' ? searchState !== 'waiting'
      : ['/password/reset', '/password/email'].includes(location.pathname) ? document.readyState !== 'loading' && Boolean(query('form[action\$="/password/email"], .alert-success'))
      : Boolean(query(config.cards) || query(config.rowCards) ||
          ((location.pathname === '/subscriptions' || location.pathname === '/login' || location.pathname === '/register' || location.pathname === '/playlist' ||
            new RegExp('^/user/[0-9]+(?:/(?:histories|saves|likes|playlists|uploaded|uploading|edit))?/?\$').test(location.pathname)) &&
           document.readyState !== 'loading' && query('#user-modal-trigger, form[action*="/login"], form[action*="/register"], .content-padding-new, .content-padding, .playlist-video-list')));
    return JSON.stringify({
      url: location.href,
      nativeContent,
      searchState,
      siteUi: Boolean(query('#user-modal-trigger, a[href*="/subscriptions"], form[action*="/login"], form[action*="/register"]')),
      challengeForm: Boolean(query('form#challenge-form, form[action*="__cf_chl_"]')),
      challengeShell: Boolean(query('#challenge-running, #challenge-stage, #cf-challenge-running, #challenge-error-title, .cf-challenge')),
      challengeTitle: /just a moment|checking your browser|verify.*human|security verification|正在进行安全验证|正在進行安全驗證|请稍候|請稍候/i.test(document.title || ''),
      clearanceConfig: typeof window._cf_chl_opt === 'object',
      challengeFrame: Boolean(query('iframe[src^="https://challenges.cloudflare.com/"]'))
      ,...diagnostic
    });
  })()
''';

/// Bounded transport metadata only; never captures URLs, queries, cookies,
/// console text, form inputs or challenge responses.
class VideoBrowserDiagnostics {
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, int> _events = {};
  final List<Map<String, Object>> _timeline = [];
  Map<String, Object> browser = const {};
  Map<String, dynamic> native = const {};
  String? _lastObservedState;

  void requested(String reason) => _record('app-load $reason');

  /// Local UI milestones, not website timings or proof of a displayed GPU frame.
  /// No titles, account identifiers, URLs or media addresses are accepted.
  void catalog(String event) {
    if (const {
      'cache-frame-ready',
      'fresh-frame-ready',
      'refresh-failed',
    }.contains(event)) {
      _record('catalog $event');
    }
  }

  /// Record transitions, not every polling tick. Content readiness and a
  /// server response are independent facts; neither is a CAPTCHA result.
  void observed(VideoSiteState state, {required bool matchesRequested}) {
    final phase = !matchesRequested
        ? 'different-document'
        : state.challenge
        ? 'challenge'
        : state.nativeReady
        ? 'native-content'
        : state.websiteReady
        ? 'website-content'
        : 'not-ready';
    if (_lastObservedState == phase) return;
    _lastObservedState = phase;
    _record('observed $phase');
  }

  void verification(String event) {
    if (const {
      'shown',
      'observation-deadline',
      'content-returned',
    }.contains(event)) {
      _record('verification $event');
    }
  }

  void _record(String key) {
    if (!_events.containsKey(key) && _events.length >= 64) return;
    _events[key] = ((_events[key] ?? 0) + 1).clamp(0, 999);
    if (_timeline.length >= 80) _timeline.removeAt(0);
    _timeline.add({'ms': _clock.elapsedMilliseconds, 'event': key});
  }

  void document(String event, Uri? uri) {
    final kind = videoSiteDiagnosticPath(uri);
    _record('$event $kind');
  }

  void console(String message) {
    if (!RegExp(
      r'cloudflare|turnstile|challenge-platform',
      caseSensitive: false,
    ).hasMatch(message)) {
      return;
    }
    final code = RegExp(
      r'\b(?:110100|110110|110200|110600|110620|200100|200500|300\d{3}|400020|400021|400070|600\d{3})\b',
    ).firstMatch(message)?.group(0);
    if (code != null) _record('challenge-code $code');
    for (final kind in [
      'SecurityError',
      'ReferenceError',
      'TypeError',
      'Content Security Policy',
      'blocked by',
    ]) {
      if (message.contains(kind)) _record('challenge-console $kind');
    }
  }

  void response(Map<String, String>? headers, {required bool main}) {
    if (!main || headers == null) return;
    final safe = {
      for (final e in headers.entries) e.key.toLowerCase(): e.value,
    };
    if (safe['cf-mitigated'] == 'challenge') {
      _record('main cf-mitigated challenge');
    }
    final ray = safe['cf-ray'];
    if (ray != null &&
        RegExp(r'^[a-fA-F0-9]{12,24}(?:-[A-Z]{3})?$').hasMatch(ray)) {
      _record('main ray $ray');
    }
  }

  void navigation(Uri? uri, {required bool main, required bool allowed}) {
    if (allowed) return;
    _record(
      'blocked ${main ? 'main' : 'frame'} ${uri?.scheme ?? 'unknown'}://${uri?.host ?? ''}',
    );
  }

  void resource(Uri uri, String result, {required bool main}) {
    if (main ||
        uri.host == 'challenges.cloudflare.com' ||
        uri.host.endsWith('.challenges.cloudflare.com')) {
      _record('${main ? 'main' : 'frame/resource'} ${uri.host} $result');
    }
  }

  String report() =>
      'diagnosticVersion: 5\n'
      'observationLimits: resource-status-0-is-unknown; '
      'closed-shadow-and-cross-origin-frame-errors-not-observed; '
      'clearance-presence-is-not-acceptance\n'
      'browser: ${jsonEncode(browser)}\n'
      'native: ${jsonEncode(native)}\n'
      'transport: ${jsonEncode(_events)}\n'
      'timeline: ${jsonEncode(_timeline)}';
}
