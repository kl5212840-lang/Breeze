import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/playback_trace.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';

/// Bounded diagnostic categories; never include raw exceptions or request data.
String omoRelayFailureCategory(Object error) {
  if (error is TimeoutException) return 'timeout';
  if (error is HandshakeException || error is TlsException) return 'tls';
  if (error is SocketException) return 'socket';
  if (error is FormatException) return 'format';
  if (error is HttpException) return 'http';
  if (error is PlatformException) {
    if (error.code == 'cancelled') return 'cancelled';
    final code = RegExp(
      r'(?<![0-9])-[0-9]{3,6}(?![0-9])',
    ).firstMatch(error.message ?? '')?.group(0);
    return code == null ? 'native' : 'native_$code';
  }
  if (error is StateError) return 'state';
  return 'other';
}

const omoNetworkSource = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
const _channel = MethodChannel('breeze.video.network');

enum OmoNetworkMode { inherit, system, proxy }

/// Device-local: a proxy's loopback address must never migrate to a new phone.
class OmoNetworkPreference {
  const OmoNetworkPreference({
    this.mode = OmoNetworkMode.inherit,
    this.address = '',
    this.socks = false,
  });
  final OmoNetworkMode mode;
  final String address;
  final bool socks;
  static const key = 'breeze.omo.network.v1';

  static Future<OmoNetworkPreference> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const OmoNetworkPreference();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return OmoNetworkPreference(
        mode: OmoNetworkMode.values.byName(json['mode'] as String),
        address: json['address'] as String? ?? '',
        socks: json['socks'] == true,
      );
    } catch (_) {
      return const OmoNetworkPreference();
    }
  }

  static String proxyUrl(String address, bool socks) {
    final value = address.trim();
    final uri = Uri.tryParse(
      value.contains('://') ? value : '${socks ? 'socks5' : 'http'}://$value',
    );
    if (uri == null ||
        uri.scheme != (socks ? 'socks5' : 'http') ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid proxy address');
    }
    return uri.replace(path: '').toString();
  }

  String effectiveProxy(ProxySettingState global) => switch (mode) {
    OmoNetworkMode.system => '',
    OmoNetworkMode.proxy => proxyUrl(address, socks),
    OmoNetworkMode.inherit =>
      global.enabled && global.address.trim().isNotEmpty
          ? proxyUrl(global.address, global.type == ProxyType.socks5)
          : '',
  };

  Future<void> save() async {
    if (mode == OmoNetworkMode.proxy) proxyUrl(address, socks);
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode({
        'mode': mode.name,
        'address': address.trim(),
        'socks': socks,
      }),
    )) {
      throw StateError('Preference was not saved');
    }
  }
}

String _opaque() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class OmoNetworkContext {
  OmoNetworkContext(this.token, {this.source = omoNetworkSource})
    : _delegate = null,
      _lease = null {
    _visits.add(this);
  }
  OmoNetworkContext._owner(OmoNetworkContext delegate, SourceNetworkLease lease)
    : token = delegate.token,
      source = delegate.source,
      _delegate = delegate,
      _lease = lease {
    delegate._owners++;
  }
  final String token;
  final String source;
  final OmoNetworkContext? _delegate;
  final SourceNetworkLease? _lease;
  int _owners = 0;
  bool _closed = false;
  HttpServer? _server;
  Future<HttpServer>? _startingServer;
  final _assets = <String, _OmoMediaAsset>{};
  final _assetIds = <(String, Uri), String>{};
  static const _replayLimit = 12 * 1024 * 1024;
  static const _replayEntryLimit = 3 * 1024 * 1024;
  final _replayClock = Stopwatch()..start();
  final _replays = <(String, String?), _OmoMediaReplay>{};
  int _nextReplay = 0;
  final _seekRenditions = <String, String>{};
  final _seekWindows = <String, _OmoSeekWindow>{};
  int _replayBytes = 0;
  int _collectingBytes = 0;
  final _relayTrace = PlaybackTrace();
  int _relaySequence = 0;
  String get relayDiagnostics =>
      _delegate?.relayDiagnostics ?? _relayTrace.export();

  void notePlaybackSetup(String message) {
    if (_closed) return;
    final delegate = _delegate;
    if (delegate != null) {
      delegate.notePlaybackSetup(message);
      return;
    }
    _relayTrace.add('player_setup', message);
    PlaybackTrace.note(source, 'player_setup', message);
  }

  void _noteRelay(String message) {
    _relayTrace.add('media_relay', message);
    PlaybackTrace.note(source, 'media_relay', message);
  }

  final _requests = <String>{};
  final _jobs = <(String, String), _OmoFetchJob>{};
  final _passiveBridgeTokens = <String>{};

  /// A probe borrows this visit, but owns only its own native HTTP requests.
  String passiveBridgeToken(VideoDownloadResolutionOwner owner) {
    owner.check();
    final visit = _delegate ?? this;
    if (_closed || visit._closed || !owner.passive || owner.source != source) {
      throw const VideoResolutionCancelled();
    }
    final alias = _opaque();
    Future<void>? retirement;
    Future<void> retire() => retirement ??= visit._retirePassiveBridge(alias);
    owner.onCancel(retire);
    owner.onClose(() => unawaited(retire().catchError((Object _) {})));
    visit._passiveBridgeTokens.add(alias);
    return alias;
  }

  Future<void> _retirePassiveBridge(String alias) async {
    _passiveBridgeTokens.remove(alias);
    final owned = _jobs.entries
        .where((entry) => entry.key.$1 == alias)
        .toList();
    for (final entry in owned) {
      _retireFetchJob(entry.key, entry.value);
    }
    await Future.wait(owned.map((entry) => _cancel(entry.value.nativeId)));
  }

  void _retireFetchJob(
    (String, String) key,
    _OmoFetchJob job, [
    String reason = 'Request cancelled',
  ]) {
    if (!identical(_jobs[key], job)) return;
    _jobs.remove(key);
    job.expiry?.cancel();
    if (!job.finished) {
      job.error = StateError(reason);
      job.finished = true;
    }
    if (!job.completed.isCompleted) job.completed.complete();
  }

  final _imageQueue = Queue<Completer<void>>();
  int _imageActive = 0;
  static OmoNetworkContext? active;

  /// Borrow only the already-selected live visit; never create a new route.
  static OmoNetworkContext? findActiveVisit(String source, String token) =>
      _visits
          .where(
            (visit) =>
                !visit._closed &&
                visit.source == source &&
                visit.token == token,
          )
          .firstOrNull;
  static final _visits = <OmoNetworkContext>{};

  static Future<bool> supported() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _channel.invokeMethod<bool>('supported') == true;
    } on MissingPluginException {
      return false;
    }
  }

  // Compatibility only. Production callers pass their visit explicitly.
  static Future<OmoNetworkContext?>? pending;
  static final _sources = <String, OmoNetworkContext>{};
  static final _opening = <String, Future<OmoNetworkContext>>{};

  static Future<OmoNetworkContext?> open(
    ProxySettingState Function()? global, {
    String source = omoNetworkSource,
    Iterable<Uri> siteOrigins = const [],
  }) async {
    if (!await supported()) return null;
    final lease = await SourceNetworkPolicies.acquire(source);
    source = lease.snapshot.source;
    try {
      final current = _sources[source];
      if (current != null && !current._closed) {
        return OmoNetworkContext._owner(current, lease);
      }
      final opening = _opening[source] ??= _openNative(
        source,
        lease.snapshot.proxy,
        siteOrigins.isEmpty && source == omoNetworkSource
            ? [Uri.parse('https://www.omofuna.com')]
            : siteOrigins,
      );
      try {
        final context = await opening;
        _sources[source] = context;
        return OmoNetworkContext._owner(context, lease);
      } finally {
        if (identical(_opening[source], opening)) _opening.remove(source);
      }
    } catch (_) {
      await lease.close();
      rethrow;
    }
  }

  static Future<OmoNetworkContext> _openNative(
    String source,
    String proxy,
    Iterable<Uri> siteOrigins,
  ) async {
    final origins = siteOrigins
        .map((uri) {
          if (uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            throw const FormatException('Invalid site origin');
          }
          return uri.origin;
        })
        .toSet()
        .toList();
    if (origins.isEmpty) throw const FormatException('Missing site origin');
    final opening = _channel.invokeMethod<String>('open', {
      'source': source,
      'proxy': proxy,
      'siteOrigins': origins,
    });
    String? token;
    try {
      token = await opening.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      unawaited(
        opening.then<void>((lateToken) async {
          if (lateToken != null) {
            await _channel.invokeMethod<void>('close', {'context': lateToken});
          }
        }, onError: (Object _) {}),
      );
      rethrow;
    }
    if (token == null || token.isEmpty) {
      throw StateError('Network session unavailable');
    }
    return OmoNetworkContext(token, source: source);
  }

  Future<OmoNetworkResponse> start(
    Uri url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 20),
    String? requestId,
    bool siteCookies = false,
  }) async {
    if (_closed) throw StateError('Network session closed');
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.start(
        url,
        method: method,
        headers: headers,
        timeout: timeout,
        requestId: requestId,
        siteCookies: siteCookies,
      );
    }
    final request = requestId ?? _opaque();
    if (_requests.contains(request)) throw StateError('Duplicate request');
    _requests.add(request);
    final clock = Stopwatch()..start();
    PlaybackTrace.note(
      source,
      'native_http',
      '$method ${url.origin}; begin; siteCookies=$siteCookies',
    );
    try {
      final metadata = await _channel
          .invokeMapMethod<String, dynamic>('start', {
            'context': token,
            'request': request,
            'url': url.toString(),
            'method': method,
            'headers': headers,
            'timeout': timeout.inMilliseconds / 1000,
            'siteCookies': siteCookies,
          })
          .timeout(timeout + const Duration(seconds: 2));
      if (metadata == null || _closed) {
        throw StateError('Network session closed');
      }
      PlaybackTrace.note(
        source,
        'native_http',
        'headers HTTP ${metadata["status"]}; ${clock.elapsedMilliseconds}ms',
      );
      return OmoNetworkResponse._(this, request, metadata);
    } catch (error, stack) {
      PlaybackTrace.error(source, 'native_http', error, stack);
      await _cancel(request);
      rethrow;
    }
  }

  /// Public parser transport only. Account operations stay inside WebKit.
  static Future<String> bridgeFetch(
    String input, {
    bool cancel = false,
    bool poll = false,
  }) async {
    try {
      return await _bridgeFetch(input, cancel: cancel, poll: poll);
    } catch (error, stack) {
      // Validation/queue failures occur before the async HTTP job exists.
      // Keep their original exception here instead of losing it in the
      // plugin's user-facing "episode page unavailable" error.
      try {
        final args = jsonDecode(input) as List;
        final source = SourceNetworkPolicies.canonicalSource(
          args[0].toString().split(':').last,
        );
        PlaybackTrace.error(source, 'dart_transport_entry', error, stack);
      } catch (_) {
        /* Never copy malformed raw arguments to a report. */
      }
      rethrow;
    }
  }

  static Future<String> _bridgeFetch(
    String input, {
    bool cancel = false,
    bool poll = false,
  }) async {
    final args = jsonDecode(input) as List;
    final payload = args[1] is String
        ? jsonDecode(args[1] as String) as Map
        : args[1] as Map;
    final id = payload['request'] as String;
    final bridgeToken = payload['context'] as String;
    final key = (bridgeToken, id);
    final context = _visits
        .where(
          (visit) =>
              !visit._closed &&
              (visit.token == bridgeToken ||
                  visit._passiveBridgeTokens.contains(bridgeToken)),
        )
        .firstOrNull;
    final runtime = args[0].toString().split(':').last;
    final traceSource = SourceNetworkPolicies.canonicalSource(runtime);
    if (!poll && !cancel) {
      PlaybackTrace.note(
        traceSource,
        'dart_transport',
        'fetch callback; sessionFound=${context != null}; '
            'sourceMatches=${context?.source == traceSource}; '
            'requestLength=${id.length}; requestValid=${RegExp(r"^[a-zA-Z0-9_-]{1,80}$").hasMatch(id)}; '
            'jobs=${context?._jobs.length}; duplicate=${context?._jobs.containsKey(key)}; '
            'timeoutType=${payload["timeout"].runtimeType}',
      );
    }
    if (context == null ||
        SourceNetworkPolicies.canonicalSource(runtime) != context.source) {
      throw StateError('Network session unavailable');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid request');
    }
    if (cancel) {
      final job = context._jobs[key];
      if (job != null) {
        context._retireFetchJob(key, job);
        await context._cancel(job.nativeId);
      }
      return '{}';
    }
    if (poll) {
      final job = context._jobs[key];
      if (job == null) throw StateError('Request expired');
      if (!job.finished) return '{"pending":true}';
      PlaybackTrace.note(
        traceSource,
        'dart_transport',
        'poll completed; error=${job.error != null}',
      );
      context._retireFetchJob(key, job);
      if (job.error != null) {
        Error.throwWithStackTrace(job.error!, job.stack ?? StackTrace.current);
      }
      return job.result!;
    }
    // Count running work, not results abandoned by a previous JS consumer.
    // Keep the original eight-request concurrency bound.
    if (context._jobs.values.where((job) => !job.finished).length >= 8 ||
        context._jobs.containsKey(key)) {
      throw StateError('Request capacity reached');
    }
    final mode = payload['responseMode'];
    if (mode != null && mode != 'poll-v1') {
      throw const FormatException('Unsupported bridge response mode');
    }
    final polling = mode == 'poll-v1';
    final timeout = Duration(
      milliseconds: ((payload['timeout'] as num?)?.toInt() ?? 8000).clamp(
        1000,
        25000,
      ),
    );
    // A small bounded completion cache lets pollers consume results; expired
    // or abandoned results can never permanently poison a source visit.
    while (context._jobs.length >= 16) {
      final old = context._jobs.entries.firstWhere(
        (entry) => entry.value.finished,
      );
      context._retireFetchJob(old.key, old.value, 'Response expired');
    }
    final job = _OmoFetchJob(context.token == bridgeToken ? id : _opaque());
    context._jobs[key] = job;
    job.expiry = Timer(timeout + const Duration(seconds: 5), () {
      if (!identical(context._jobs[key], job)) return;
      PlaybackTrace.note(
        traceSource,
        'dart_transport',
        'expired abandoned request',
      );
      context._retireFetchJob(key, job, 'Request expired');
      unawaited(context._cancel(job.nativeId).catchError((Object _) {}));
    });
    PlaybackTrace.note(
      traceSource,
      'dart_transport',
      'accepted; responseMode=${polling ? "poll-v1" : "legacy-final"}',
    );
    Future<void> fetch() async {
      try {
        Future<String> responseBody() async {
          final response = await context.start(
            Uri.parse(payload['url'] as String),
            requestId: job.nativeId,
            // Source HTML needs the same access-verification session as WK.
            // Native code attaches cookies only to declared first-party
            // origins, never to parser/CDN hosts. Media/images keep false.
            siteCookies: true,
            headers: Map<String, String>.from(payload['headers'] as Map? ?? {}),
            timeout: timeout,
          );
          if (job.finished) throw const VideoResolutionCancelled();
          final body = await response.bytes(2500000);
          PlaybackTrace.note(
            context.source,
            'dart_transport',
            'body complete; HTTP ${response.status}; bytes=${body.length}',
          );
          if (kDebugMode) {
            debugPrint(
              'Omo response ${response.url.host}: HTTP ${response.status}, hls=${utf8.decode(body.take(20).toList(), allowMalformed: true).trimLeft().startsWith("#EXTM3U")}',
            );
          }
          return jsonEncode({
            'status': response.status,
            'headers': response.headers,
            'body': utf8.decode(body, allowMalformed: true),
          });
        }

        final result = await responseBody().timeout(timeout);
        if (!job.finished) job.result = result;
      } catch (error, stack) {
        PlaybackTrace.error(context.source, 'dart_transport', error, stack);
        if (!job.finished) {
          job.error = error;
          job.stack = stack;
        }
      } finally {
        if (identical(context._jobs[key], job))
          await context._cancel(job.nativeId);
        job.finished = true;
        if (!job.completed.isCompleted) job.completed.complete();
      }
    }

    // The host bridge has a 15s callback ceiling. Poll an independent bounded
    // job instead of truncating an 18s parser request or blocking the worker.
    unawaited(fetch());
    if (polling) return '{"pending":true}';
    // Legacy consumers expect HTTP metadata from fetch itself. Returning a
    // pending envelope without negotiation makes them fail immediately and
    // leave all eight jobs unconsumed. New plugins explicitly opt into polling.
    try {
      await job.completed.future;
      if (job.error != null) {
        Error.throwWithStackTrace(job.error!, job.stack ?? StackTrace.current);
      }
      return job.result!;
    } finally {
      context._retireFetchJob(key, job);
    }
  }

  Future<void> _cancel(String id) async {
    if (!_requests.remove(id)) return;
    try {
      await _channel.invokeMethod<void>('cancel', {
        'context': token,
        'request': id,
      });
    } on PlatformException {
      /* Already closed. */
    }
  }

  Future<Uint8List> bytes(
    Uri url, {
    Map<String, String> headers = const {},
    int limit = 8 * 1024 * 1024,
  }) async {
    if (_closed) throw StateError('Network session closed');
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.bytes(url, headers: headers, limit: limit);
    }
    // Posters never consume all native transfers. Reserve capacity for media,
    // resolvers and foreground metadata even on a slow proxy.
    if (_imageActive >= 4) {
      final slot = Completer<void>();
      _imageQueue.add(slot);
      await slot.future;
    } else {
      _imageActive++;
    }
    try {
      if (_closed) throw StateError('Network session closed');
      final response = await start(url, headers: headers);
      try {
        if (response.status != 200) {
          throw HttpException('HTTP ${response.status}');
        }
        return await response.bytes(limit);
      } finally {
        await response.cancel();
      }
    } finally {
      if (_imageQueue.isNotEmpty) {
        _imageQueue.removeFirst().complete();
      } else {
        _imageActive--;
      }
    }
  }

  Future<void> prepare() async {
    if (_closed) throw StateError('Network session closed');
    final delegate = _delegate;
    if (delegate != null) return delegate.prepare();
    await (_startingServer ??= HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        .then((server) {
          if (_closed) {
            unawaited(server.close(force: true));
            throw StateError('Network session closed');
          }
          _server = server;
          server.autoCompress = false;
          server.listen(
            (request) => unawaited(_serve(request)),
            onError: (Object _) {},
          );
          return server;
        }));
  }

  VideoPlayerController player(Uri url, Map<String, String> headers) {
    if (_closed) throw StateError('Network session closed');
    final delegate = _delegate;
    if (delegate != null) return delegate.player(url, headers);
    final server = _server;
    if (_closed || server == null) throw StateError('Network session closed');
    final lease = _opaque();
    final local = _asset(url, headers, lease);
    _assets[local]!.isRoot = true;
    final endpoint = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/$local',
    );
    return _OmoPlayer(
      endpoint,
      () => _release(lease),
      () => _assets[local]?.playlist == true,
      (position) => _cachedSeekWindow(lease, endpoint, position),
      () {
        final track = _assets[local]?.iframeTrack;
        if (_closed || track == null || _assets[track]?.lease != lease) {
          return null;
        }
        return endpoint.replace(path: '/$track');
      },
    );
  }

  String _asset(
    Uri url,
    Map<String, String> headers,
    String lease, {
    String kind = 'media',
    bool replayable = false,
  }) {
    // Do not let a server-provided URI escape the chosen network path.
    if (url.scheme != 'https' || url.userInfo.isNotEmpty || url.host.isEmpty) {
      throw const FormatException('Unsupported media URL');
    }
    final key = (lease, url);
    final previous = _assetIds[key];
    if (previous != null) return previous;
    if (_assets.length >= 20000) throw StateError('Media playlist too large');
    final suffix = kind == 'iframe'
        ? '.m3u8'
        : RegExp(
                r'\.(m3u8|mp4|m4a|m4s|ts|aac|key)$',
                caseSensitive: false,
              ).firstMatch(url.path)?.group(0) ??
              '.bin';
    final id = '${_opaque()}$suffix';
    final playlist =
        kind == 'iframe' || url.path.toLowerCase().endsWith('.m3u8');
    _assets[id] = _OmoMediaAsset(
      url,
      Map.unmodifiable(headers),
      lease,
      playlist && kind == 'media' ? 'playlist' : kind,
      playlist: playlist,
      replayable: replayable,
    );
    _assetIds[key] = id;
    return id;
  }

  static Duration _replayLifetime(Map<String, String> headers) {
    final directives = (headers['cache-control'] ?? '').toLowerCase();
    if (directives.contains('no-store') ||
        directives.contains('no-cache') ||
        headers['pragma']?.toLowerCase().contains('no-cache') == true ||
        headers['vary']?.trim() == '*') {
      return Duration.zero;
    }
    var seconds = 30;
    final maxAge = RegExp(
      r'(?:^|,)\s*max-age\s*=\s*"?([0-9]+)',
    ).firstMatch(directives);
    if (maxAge != null) {
      seconds = min(
        seconds,
        (int.tryParse(maxAge[1]!) ?? 0) -
            (int.tryParse(headers['age'] ?? '') ?? 0),
      );
    } else if (headers['expires'] case final expires?) {
      try {
        seconds = min(
          seconds,
          HttpDate.parse(expires).difference(DateTime.now()).inSeconds,
        );
      } on HttpException {
        return Duration.zero;
      }
    }
    return Duration(seconds: max(0, seconds));
  }

  static _OmoProgressiveRepresentation? _progressiveRepresentation(
    OmoNetworkResponse response,
    String? range,
    int length,
  ) {
    final headers = response.headers;
    final mime = headers['content-type']?.split(';').first.trim().toLowerCase();
    final encoding = headers['content-encoding']?.trim().toLowerCase();
    if (response.status != HttpStatus.partialContent ||
        !const {
          'video/mp4',
          'application/mp4',
          'video/quicktime',
        }.contains(mime) ||
        encoding != null && encoding != 'identity' ||
        headers.containsKey('vary')) {
      return null;
    }

    final requested = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range ?? '');
    final returned = RegExp(
      r'^bytes (\d+)-(\d+)/(\d+)$',
    ).firstMatch(headers['content-range'] ?? '');
    if (requested == null || returned == null) return null;
    final start = int.tryParse(returned[1]!);
    final end = int.tryParse(returned[2]!);
    final total = int.tryParse(returned[3]!);
    final requestedEnd = int.tryParse(requested[2]!);
    if (start == null ||
        end == null ||
        total == null ||
        int.tryParse(requested[1]!) != start ||
        requested[2]!.isNotEmpty && requestedEnd == null ||
        end < start ||
        end >= total ||
        end != min(requestedEnd ?? total - 1, total - 1) ||
        end - start + 1 != length) {
      return null;
    }

    final tag = headers['etag']?.trim();
    final strongTag = tag != null && RegExp(r'^"[^"]*"$').hasMatch(tag)
        ? tag
        : null;
    final modified = headers['last-modified'];
    if (strongTag == null &&
        modified == null &&
        !RegExp(
          r'(?:^|,)\s*max-age\s*=',
          caseSensitive: false,
        ).hasMatch(headers['cache-control'] ?? '') &&
        !headers.containsKey('expires')) {
      return null;
    }
    return (response.url, mime!, total, tag, modified);
  }

  void _remember(
    (String, String?) key,
    int status,
    Map<String, String> headers,
    Uint8List body,
    Duration lifetime, {
    _OmoSeekTimeline? timeline,
  }) {
    if (body.isEmpty ||
        body.length > _replayEntryLimit ||
        lifetime <= Duration.zero) {
      return;
    }
    _forget(key);
    while (_replayBytes + body.length > _replayLimit || _replays.length >= 32) {
      _forget(_replays.keys.first);
    }
    _replays[key] = _OmoMediaReplay(
      status,
      headers,
      body,
      _replayClock.elapsed + lifetime,
      ++_nextReplay,
      timeline,
    );
    _replayBytes += body.length;
  }

  void _forget((String, String?) key) {
    _replayBytes -= _replays.remove(key)?.body.length ?? 0;
  }

  _OmoMediaReplay? _freshReplay((String, String?) key) {
    final replay = _replays[key];
    return replay != null && replay.expires > _replayClock.elapsed
        ? replay
        : null;
  }

  void _noteSeekSegment(
    String id,
    _OmoMediaAsset asset,
    _OmoMediaReplay replay,
  ) {
    if (asset.kind != 'segment' ||
        asset.seekAuxiliary ||
        !replay.fullTransportStream) {
      return;
    }
    final matches = [
      for (final entry in _replays.entries)
        if (entry.key.$2 == null &&
            _assets[entry.key.$1]?.lease == asset.lease &&
            _assets[entry.key.$1]?.seekAuxiliary == false &&
            entry.value.expires > _replayClock.elapsed &&
            entry.value.timeline?.ids.contains(id) == true)
          entry.key.$1,
    ];
    if (matches.length == 1) {
      _seekRenditions[asset.lease] = matches.single;
    } else {
      _seekRenditions.remove(asset.lease);
    }
  }

  ({Uri url, Duration position})? _cachedSeekWindow(
    String lease,
    Uri endpoint,
    Duration target,
  ) {
    final rendition = _seekRenditions[lease];
    final renditionAsset = _assets[rendition];
    if (_closed ||
        rendition == null ||
        renditionAsset == null ||
        renditionAsset.lease != lease ||
        renditionAsset.seekAuxiliary) {
      return null;
    }
    final manifest = _freshReplay((rendition, null));
    final segment = manifest?.timeline?.at(target);
    if (segment == null) return null;
    final segmentAsset = _assets[segment.id];
    if (segmentAsset == null ||
        segmentAsset.lease != lease ||
        segmentAsset.seekAuxiliary) {
      return null;
    }
    final entry = _replays.entries
        .where(
          (entry) =>
              entry.key.$1 == segment.id &&
              entry.value.expires > _replayClock.elapsed &&
              entry.value.fullTransportStream,
        )
        .lastOrNull;
    if (entry == null) return null;
    _seekWindows.removeWhere((_, window) => _windowReplay(window) == null);
    final _OmoSeekWindow window = (
      lease: lease,
      rendition: rendition,
      manifestVersion: manifest!.version,
      segmentKey: entry.key,
      segmentVersion: entry.value.version,
      duration: segment.duration,
    );
    var id = _seekWindows.entries
        .where((entry) => entry.value == window)
        .firstOrNull
        ?.key;
    if (id == null) {
      if (_seekWindows.length >= 12) {
        _seekWindows.remove(_seekWindows.keys.first);
      }
      id = _opaque();
      _seekWindows[id] = window;
    }
    return (
      url: endpoint.replace(path: '/seek-preview/$id.m3u8'),
      position: target - segment.start,
    );
  }

  _OmoMediaReplay? _windowReplay(_OmoSeekWindow window) {
    if (_closed ||
        _seekRenditions[window.lease] != window.rendition ||
        _assets[window.rendition]?.seekAuxiliary != false ||
        _assets[window.segmentKey.$1]?.lease != window.lease ||
        _assets[window.segmentKey.$1]?.seekAuxiliary != false ||
        _freshReplay((window.rendition, null))?.version !=
            window.manifestVersion) {
      return null;
    }
    final replay = _freshReplay(window.segmentKey);
    return replay?.version == window.segmentVersion ? replay : null;
  }

  Future<void> _serveSeekWindow(HttpRequest request) async {
    final response = request.response;
    try {
      final match = RegExp(
        r'^/seek-preview/([a-f0-9]+)\.(m3u8|ts)$',
      ).firstMatch(request.uri.path);
      final id = match?[1];
      final window = _seekWindows[id];
      final replay = window == null ? null : _windowReplay(window);
      if (id == null ||
          request.uri.hasQuery ||
          !['GET', 'HEAD'].contains(request.method) ||
          replay == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final playlist = match![2] == 'm3u8';
      final seconds =
          window!.duration.inMicroseconds / Duration.microsecondsPerSecond;
      final bytes = playlist
          ? utf8.encode(
              '#EXTM3U\n#EXT-X-VERSION:3\n'
              '#EXT-X-TARGETDURATION:${seconds.ceil()}\n'
              '#EXT-X-PLAYLIST-TYPE:VOD\n#EXTINF:$seconds,\n'
              '/seek-preview/$id.ts\n#EXT-X-ENDLIST\n',
            )
          : replay.body;
      response.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set(
          HttpHeaders.contentTypeHeader,
          playlist ? 'application/vnd.apple.mpegurl' : 'video/mp2t',
        )
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');
      var start = 0, end = bytes.length - 1;
      final ranges = request.headers[HttpHeaders.rangeHeader];
      if (ranges != null) {
        final range = ranges.singleOrNull;
        final bounds = range == null
            ? null
            : RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        final lower = int.tryParse(bounds?[1] ?? '');
        final upper = int.tryParse(bounds?[2] ?? '');
        if (bounds == null ||
            bounds[1]!.isNotEmpty && lower == null ||
            bounds[2]!.isNotEmpty && upper == null ||
            lower == null && (upper == null || upper <= 0) ||
            lower != null && (lower > end || upper != null && upper < lower)) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */${bytes.length}',
          );
          return;
        }
        start = lower ?? max(0, bytes.length - upper!);
        if (lower != null && upper != null) end = min(end, upper);
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${bytes.length}',
        );
      }
      response.contentLength = end - start + 1;
      if (request.method == 'GET') {
        response.add(Uint8List.sublistView(bytes, start, end + 1));
      }
    } on HttpException {
      // The preview reader disconnected.
    } finally {
      try {
        await response.close();
      } catch (_) {
        /* Client cancelled the preview. */
      }
    }
  }

  Future<void> _serve(HttpRequest request) async {
    if (request.uri.path.startsWith('/seek-preview/')) {
      await _serveSeekWindow(request);
      return;
    }
    final response = request.response;
    final localId = request.uri.path.replaceFirst('/', '');
    final asset = _assets[localId];
    bool live() => !_closed && identical(_assets[localId], asset);
    String? upstreamRequestId;
    final clock = Stopwatch()..start();
    final requestNumber = ++_relaySequence;
    var bytes = 0;
    var bodyObserved = false;
    var terminal = 'retired';
    var category = 'none';
    final kind = asset?.kind ?? 'unknown';
    void firstBody(int length) {
      if (length <= 0) return;
      bytes += length;
      if (!bodyObserved) {
        bodyObserved = true;
        _noteRelay(
          'request=$requestNumber; kind=$kind; first_body_ms=${clock.elapsedMilliseconds}; bytes=$length',
        );
      }
    }

    try {
      if (_closed ||
          asset == null ||
          request.uri.hasQuery ||
          !['GET', 'HEAD'].contains(request.method)) {
        response.statusCode = 404;
        return;
      }
      _noteRelay(
        'request=$requestNumber; kind=$kind; begin; method=${request.method}; host=${asset.url.host}:${asset.url.port}',
      );
      final headers = <String, String>{...asset.headers};
      final knownPlaylist = asset.playlist;
      final range = knownPlaylist
          ? null
          : request.headers.value(HttpHeaders.rangeHeader);
      final progressive = asset.isRoot && kind == 'media' && !knownPlaylist;
      final allowsProgressiveReplay =
          progressive &&
          request.method == 'GET' &&
          !(request.headers[HttpHeaders.cacheControlHeader] ?? const <String>[])
              .any(
                (value) =>
                    _replayLifetime({'cache-control': value}) == Duration.zero,
              ) &&
          !(request.headers['pragma'] ?? const <String>[]).any(
            (value) => value.toLowerCase().contains('no-cache'),
          ) &&
          !const [
            'if-range',
            'if-match',
            'if-none-match',
            'if-modified-since',
            'if-unmodified-since',
          ].any((name) => request.headers[name] != null);
      final playlistHead = knownPlaylist && request.method == 'HEAD';
      if (range != null) headers['Range'] = range;
      final replayKey = (localId, range);
      if (_replays[replayKey] case final cached?
          when request.method == 'GET' &&
              (!progressive || allowsProgressiveReplay)) {
        _forget(replayKey);
        if (cached.expires > _replayClock.elapsed) {
          _replays[replayKey] = cached;
          _replayBytes += cached.body.length;
          response.statusCode = cached.status;
          cached.headers.forEach(response.headers.set);
          response.add(cached.body);
          bytes = cached.body.length;
          terminal = 'reused';
          _noteSeekSegment(localId, asset, cached);
          return;
        }
      }
      // Own the native transfer before waiting for its response headers.
      final id = _opaque();
      if (_requests.contains(id)) throw StateError('Duplicate request');
      asset.requestIds.add(id);
      upstreamRequestId = id;
      final upstream = await start(
        asset.url,
        method: playlistHead ? 'GET' : request.method,
        headers: headers,
        requestId: id,
      );
      if (!live()) return;
      _noteRelay(
        'request=$requestNumber; kind=$kind; headers_ms=${clock.elapsedMilliseconds}; status=${upstream.status}; final_host=${upstream.url.host}:${upstream.url.port}',
      );
      unawaited(
        RoutingObservedMediaDomains.observe(
          source: source,
          requested: asset.url,
          responseUrl: upstream.url,
          status: upstream.status,
        ).then<void>((_) {}, onError: (Object _) {}),
      );
      if (kDebugMode) {
        debugPrint('Omo media ${upstream.url.host}: HTTP ${upstream.status}');
      }
      unawaited(
        response.done
            .then<void>((_) {}, onError: (Object _) {})
            .whenComplete(upstream.cancel),
      );
      response.statusCode = upstream.status;
      if (!live()) return;
      final type = upstream.headers['content-type'] ?? '';
      final first = request.method == 'HEAD' && !playlistHead
          ? null
          : await upstream.read();
      if (!live()) return;
      if (first != null) firstBody(first.length);
      final playlist =
          (request.method != 'HEAD' || playlistHead) &&
          (knownPlaylist ||
              type.toLowerCase().contains('mpegurl') ||
              (first != null &&
                  utf8
                      .decode(first.take(12).toList(), allowMalformed: true)
                      .trimLeft()
                      .startsWith('#EXTM3U')));
      if (playlist && upstream.status == 200) {
        final data = await upstream.bytes(
          1024 * 1024,
          first: first,
          onChunk: (length) {
            if (!live()) throw StateError('Media lease retired');
            firstBody(length);
          },
        );
        if (!live()) return;
        asset.playlist = true;
        bytes = data.length;
        final playlistBody = utf8.decode(data);
        final vod = RegExp(
          r'^#EXT-X-ENDLIST\s*$',
          multiLine: true,
        ).hasMatch(playlistBody);
        String? iframeTrack;
        final body = omoRewritePlaylist(
          playlistBody,
          upstream.url,
          (uri) => '/${_asset(uri, asset.headers, asset.lease)}',
          localTyped: (uri, role) {
            final id = _asset(
              uri,
              asset.headers,
              asset.lease,
              kind: role == 'alternate' ? 'playlist' : role,
              replayable:
                  vod &&
                  asset.kind != 'iframe' &&
                  (role == 'segment' || role == 'map'),
            );
            if (asset.seekAuxiliary || role == 'alternate') {
              _assets[id]!.seekAuxiliary = true;
            }
            if (asset.isRoot && role == 'iframe') iframeTrack ??= id;
            return '/$id';
          },
        );
        if (asset.isRoot) asset.iframeTrack = iframeTrack;
        final encoded = utf8.encode(body);
        const contentType = 'application/vnd.apple.mpegurl';
        response.headers.set('content-type', contentType);
        response.contentLength = encoded.length;
        if (request.method != 'HEAD') {
          response.add(encoded);
          if (vod && encoded.length <= _replayEntryLimit) {
            _remember(
              replayKey,
              200,
              {
                'content-type': contentType,
                'content-length': '${encoded.length}',
              },
              encoded,
              _replayLifetime(upstream.headers),
              timeline: asset.seekAuxiliary
                  ? null
                  : _OmoSeekTimeline.parse(body),
            );
          }
        }
      } else {
        final mediaHeaders = <String, String>{};
        for (final name in [
          'content-type',
          'content-length',
          'content-range',
          'accept-ranges',
        ]) {
          final value = upstream.headers[name];
          if (value != null) mediaHeaders[name] = value;
        }
        mediaHeaders.forEach(response.headers.set);
        final lifetime = _replayLifetime(upstream.headers);
        final expectedLength =
            int.tryParse(mediaHeaders['content-length'] ?? '') ?? 0;
        final representation = progressive && range != null
            ? _progressiveRepresentation(upstream, range, expectedLength)
            : null;
        if (progressive &&
            range != null &&
            requestNumber > asset.progressiveObservation) {
          asset.progressiveObservation = requestNumber;
          if (asset.progressiveRepresentation != representation ||
              lifetime == Duration.zero) {
            for (final key
                in _replays.keys.where((key) => key.$1 == localId).toList()) {
              _forget(key);
            }
            asset.progressiveRepresentation = representation;
            asset.progressiveGeneration = requestNumber;
          }
        }
        final progressiveGeneration = asset.progressiveGeneration;
        final canReplay =
            (asset.replayable ||
                allowsProgressiveReplay &&
                    representation != null &&
                    requestNumber >= progressiveGeneration &&
                    asset.progressiveRepresentation == representation) &&
            request.method == 'GET' &&
            (upstream.status == 200 ||
                upstream.status == 206 &&
                    mediaHeaders.containsKey('content-range')) &&
            lifetime > Duration.zero &&
            expectedLength > 0 &&
            expectedLength <= _replayEntryLimit &&
            _collectingBytes + expectedLength <= _replayEntryLimit * 2;
        if (canReplay) _collectingBytes += expectedLength;
        BytesBuilder? replay = canReplay ? BytesBuilder(copy: false) : null;
        void collect(Uint8List chunk) {
          final buffer = replay;
          if (buffer == null) return;
          if (buffer.length + chunk.length > expectedLength) {
            replay = null;
            return;
          }
          buffer.add(chunk);
        }

        try {
          if (first != null) {
            collect(first);
            response.add(first);
            await response.flush();
          }
          while (request.method != 'HEAD') {
            final chunk = await upstream.read();
            if (!live()) return;
            if (chunk == null) break;
            firstBody(chunk.length);
            collect(chunk);
            response.add(chunk);
            await response.flush();
          }
          final finished = replay;
          if (finished != null &&
              finished.length == expectedLength &&
              asset.progressiveGeneration == progressiveGeneration) {
            _remember(
              replayKey,
              upstream.status,
              mediaHeaders,
              finished.takeBytes(),
              progressive ? lifetime - clock.elapsed : lifetime,
            );
            if (_freshReplay(replayKey) case final replay?) {
              _noteSeekSegment(localId, asset, replay);
            }
          }
        } finally {
          if (canReplay) _collectingBytes -= expectedLength;
        }
      }
      terminal = 'done';
      if (upstream.status >= 400) category = 'http_status';
    } catch (error) {
      terminal = asset == null || !live() ? 'retired' : 'fail';
      category = omoRelayFailureCategory(error);
      // Never expose signed URLs, account cookies or raw native error text.
      try {
        response.statusCode = HttpStatus.badGateway;
      } catch (_) {
        /* Headers already sent. */
      }
    } finally {
      _noteRelay(
        'request=$requestNumber; kind=$kind; $terminal; category=$category; body_bytes=$bytes; elapsed_ms=${clock.elapsedMilliseconds}',
      );
      if (upstreamRequestId != null) {
        asset?.requestIds.remove(upstreamRequestId);
        await _cancel(upstreamRequestId);
      }
      try {
        await response.close();
      } catch (_) {
        /* Client cancelled a seek / switch. */
      }
    }
  }

  Future<void> _release(String lease) async {
    _seekRenditions.remove(lease);
    _seekWindows.removeWhere((_, window) => window.lease == lease);
    final requestIds = [
      for (final asset in _assets.values)
        if (asset.lease == lease) ...asset.requestIds,
    ];
    _assetIds.removeWhere((key, _) => key.$1 == lease);
    _assets.removeWhere((_, asset) => asset.lease == lease);
    for (final key
        in _replays.keys
            .where((key) => !_assets.containsKey(key.$1))
            .toList()) {
      _forget(key);
    }
    await Future.wait(requestIds.map(_cancel));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final delegate = _delegate;
    if (delegate != null) {
      // Each acquisition owns an idempotent handle. The underlying relay,
      // parser jobs and native token stay alive until its last owner leaves.
      delegate._owners--;
      final retiring = delegate._owners == 0 ? delegate.close() : null;
      await _lease!.close();
      await retiring;
      return;
    }
    // Retire before the last handle releases policy ownership, so a new visit
    // cannot borrow a closing native token after changing its proxy.
    _visits.remove(this);
    _passiveBridgeTokens.clear();
    if (identical(_sources[source], this)) _sources.remove(source);
    _assets.clear();
    _assetIds.clear();
    _replays.clear();
    _seekRenditions.clear();
    _seekWindows.clear();
    _replayBytes = 0;
    for (final entry in _jobs.entries.toList()) {
      _retireFetchJob(entry.key, entry.value, 'Network session closed');
    }
    while (_imageQueue.isNotEmpty) {
      _imageQueue.removeFirst().completeError(
        StateError('Network session closed'),
      );
    }
    await _server?.close(force: true);
    for (final id in _requests.toList()) {
      await _cancel(id);
    }
    await _channel.invokeMethod<void>('close', {'context': token});
  }
}

class OmoNetworkResponse {
  OmoNetworkResponse._(this.context, this.id, Map<String, dynamic> metadata)
    : status = metadata['status'] as int,
      url = Uri.parse(metadata['url'] as String),
      headers = Map<String, String>.from(metadata['headers'] as Map);
  final OmoNetworkContext context;
  final String id;
  final int status;
  final Uri url;
  final Map<String, String> headers;
  Future<Uint8List?> read() => _channel
      .invokeMethod<Uint8List>('read', {
        'context': context.token,
        'request': id,
      })
      .timeout(const Duration(seconds: 35));
  Future<Uint8List> bytes(
    int limit, {
    Uint8List? first,
    void Function(int length)? onChunk,
  }) async {
    final output = BytesBuilder(copy: false);
    if (first != null) output.add(first);
    final length = int.tryParse(headers['content-length'] ?? '');
    if (length != null && length > limit || output.length > limit) {
      throw const FormatException('Response too large');
    }
    while (true) {
      final chunk = await read();
      if (chunk == null) break;
      onChunk?.call(chunk.length);
      if (output.length + chunk.length > limit) {
        throw const FormatException('Response too large');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }

  Future<void> cancel() => context._cancel(id);
}

typedef _OmoProgressiveRepresentation = (Uri, String, int, String?, String?);

class _OmoMediaAsset {
  _OmoMediaAsset(
    this.url,
    this.headers,
    this.lease,
    this.kind, {
    required this.playlist,
    required this.replayable,
  });
  final Uri url;
  final Map<String, String> headers;
  final String lease;
  final String kind;
  bool playlist;
  bool isRoot = false;
  _OmoProgressiveRepresentation? progressiveRepresentation;
  int progressiveGeneration = 0;
  int progressiveObservation = 0;
  bool seekAuxiliary = false;
  String? iframeTrack;
  final bool replayable;
  final requestIds = <String>{};
}

class _OmoMediaReplay {
  _OmoMediaReplay(
    this.status,
    this.headers,
    this.body,
    this.expires,
    this.version,
    this.timeline,
  );
  final int status;
  final Map<String, String> headers;
  final Uint8List body;
  final Duration expires;
  final int version;
  final _OmoSeekTimeline? timeline;

  bool get fullTransportStream =>
      (status == HttpStatus.ok ||
          status == HttpStatus.partialContent &&
              headers['content-range'] ==
                  'bytes 0-${body.length - 1}/${body.length}') &&
      body.length >= 188 * 3 &&
      body.length % 188 == 0 &&
      body[0] == 0x47 &&
      body[188] == 0x47 &&
      body[376] == 0x47;
}

typedef _OmoSeekSegment = ({String id, Duration start, Duration duration});
typedef _OmoSeekWindow = ({
  String lease,
  String rendition,
  int manifestVersion,
  (String, String?) segmentKey,
  int segmentVersion,
  Duration duration,
});

class _OmoSeekTimeline {
  const _OmoSeekTimeline(this.segments, this.ids);
  final List<_OmoSeekSegment> segments;
  final Set<String> ids;

  static _OmoSeekTimeline? parse(String rewritten) {
    final segments = <_OmoSeekSegment>[];
    final ids = <String>{};
    final unsupported = RegExp(
      r'^#EXT-X-(?:BYTERANGE|DISCONTINUITY|GAP|I-FRAMES-ONLY|KEY|MAP|PART|PRELOAD-HINT|SESSION-KEY|SKIP|START|STREAM-INF)(?:$|:|-)',
    );
    var start = Duration.zero;
    Duration? segmentDuration;
    for (final raw in const LineSplitter().convert(rewritten)) {
      final line = raw.trim();
      if (unsupported.hasMatch(line)) return null;
      if (line.startsWith('#EXTINF:')) {
        final seconds = double.tryParse(line.substring(8).split(',').first);
        if (segmentDuration != null ||
            seconds == null ||
            !seconds.isFinite ||
            seconds <= 0 ||
            seconds > 3600) {
          return null;
        }
        segmentDuration = Duration(
          microseconds: (seconds * Duration.microsecondsPerSecond).round(),
        );
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (!RegExp(r'^/[a-f0-9]+\.(?:ts|bin)$').hasMatch(line) ||
            segmentDuration == null ||
            segmentDuration == Duration.zero) {
          return null;
        }
        final id = line.substring(1);
        if (!ids.add(id)) return null;
        segments.add((id: id, start: start, duration: segmentDuration));
        start += segmentDuration;
        segmentDuration = null;
      }
    }
    return segments.isEmpty || segmentDuration != null
        ? null
        : _OmoSeekTimeline(segments, ids);
  }

  _OmoSeekSegment? at(Duration target) {
    var lower = 0, upper = segments.length;
    while (lower < upper) {
      final middle = (lower + upper) ~/ 2;
      final segment = segments[middle];
      if (target < segment.start) {
        upper = middle;
      } else if (target >= segment.start + segment.duration) {
        lower = middle + 1;
      } else {
        return segment;
      }
    }
    return null;
  }
}

/// An optional preview backed solely by bytes already forwarded to this player.
({Uri url, Duration position})? omoCachedSeekWindow(
  VideoPlayerController player,
  Duration target,
) => player is _OmoPlayer ? player.cachedSeekWindow(target) : null;

/// The I-frame rendition advertised by the current root playlist, if any.
Uri? omoIFrameSeekTrack(VideoPlayerController player) =>
    player is _OmoPlayer ? player.iframeSeekTrack() : null;

class _OmoPlayer extends VideoPlayerController {
  _OmoPlayer(
    super.url,
    this.release,
    this._servesPlaylist,
    this.cachedSeekWindow,
    this.iframeSeekTrack,
  ) : super.networkUrl(
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
  final AsyncCallback release;
  final bool Function() _servesPlaylist;
  final ({Uri url, Duration position})? Function(Duration) cachedSeekWindow;
  final Uri? Function() iframeSeekTrack;
  @override
  VideoFormat? get formatHint =>
      _servesPlaylist() ? VideoFormat.hls : super.formatHint;

  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } finally {
      await release();
    }
  }
}

/// Rewrites every standard HLS URI, including variants, renditions, keys, maps,
/// byte-range segments and low-latency parts. Relative URLs use the final
/// redirect URL. Unsupported steering/variable/DRM references fail closed.
String omoRewritePlaylist(
  String body,
  Uri base,
  String Function(Uri) local, {
  String Function(Uri uri, String kind)? localTyped,
}) {
  if (!body.replaceFirst('\uFEFF', '').trimLeft().startsWith('#EXTM3U') ||
      body.contains('#EXT-X-CONTENT-STEERING') ||
      body.contains('#EXT-X-DEFINE') ||
      RegExp(r'KEYFORMAT="(?!identity")[^"]+"').hasMatch(body)) {
    throw const FormatException('Unsupported HLS playlist');
  }
  String rewrite(String value, String kind) {
    final uri = base.resolve(value);
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        value.contains(r'{$')) {
      throw const FormatException('Unsupported HLS URI');
    }
    return localTyped?.call(uri, kind) ?? local(uri);
  }

  final mediaPlaylist = body.contains('#EXTINF:');
  return body
      .split('\n')
      .map((line) {
        if (line.trim().isEmpty) return line;
        if (!line.trimLeft().startsWith('#'))
          return rewrite(line.trim(), mediaPlaylist ? 'segment' : 'playlist');
        final role =
            RegExp(r'^#EXT-X-(?:SESSION-)?KEY:').hasMatch(line.trimLeft())
            ? 'key'
            : line.trimLeft().startsWith('#EXT-X-MAP:')
            ? 'map'
            : line.trimLeft().startsWith('#EXT-X-I-FRAME-STREAM-INF:')
            ? 'iframe'
            : line.trimLeft().startsWith('#EXT-X-MEDIA:')
            ? 'alternate'
            : RegExp(
                r'^#EXT-X-(?:PART|PRELOAD-HINT):',
              ).hasMatch(line.trimLeft())
            ? 'segment'
            : 'playlist';
        return line.replaceAllMapped(
          RegExp(r'\bURI="([^"]+)"'),
          (match) => 'URI="${rewrite(match[1]!, role)}"',
        );
      })
      .join('\n');
}

class _OmoFetchJob {
  _OmoFetchJob(this.nativeId);

  final String nativeId;
  final completed = Completer<void>();
  Timer? expiry;
  bool finished = false;
  String? result;
  Object? error;
  StackTrace? stack;
}
