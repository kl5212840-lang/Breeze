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
  final _jobs = <String, _OmoFetchJob>{};

  void _retireFetchJob(
    String id,
    _OmoFetchJob job, [
    String reason = 'Request cancelled',
  ]) {
    if (!identical(_jobs[id], job)) return;
    _jobs.remove(id);
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
    final context = _visits
        .where((visit) => visit.token == payload['context'] && !visit._closed)
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
            'jobs=${context?._jobs.length}; duplicate=${context?._jobs.containsKey(id)}; '
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
      final job = context._jobs[id];
      if (job != null) context._retireFetchJob(id, job);
      await context._cancel(id);
      return '{}';
    }
    if (poll) {
      final job = context._jobs[id];
      if (job == null) throw StateError('Request expired');
      if (!job.finished) return '{"pending":true}';
      PlaybackTrace.note(
        traceSource,
        'dart_transport',
        'poll completed; error=${job.error != null}',
      );
      context._retireFetchJob(id, job);
      if (job.error != null) {
        Error.throwWithStackTrace(job.error!, job.stack ?? StackTrace.current);
      }
      return job.result!;
    }
    // Count running work, not results abandoned by a previous JS consumer.
    // Keep the original eight-request concurrency bound.
    if (context._jobs.values.where((job) => !job.finished).length >= 8 ||
        context._jobs.containsKey(id)) {
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
    final job = _OmoFetchJob();
    context._jobs[id] = job;
    job.expiry = Timer(timeout + const Duration(seconds: 5), () {
      if (!identical(context._jobs[id], job)) return;
      PlaybackTrace.note(
        traceSource,
        'dart_transport',
        'expired abandoned request',
      );
      context._retireFetchJob(id, job, 'Request expired');
      unawaited(context._cancel(id).catchError((Object _) {}));
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
            requestId: id,
            // Source HTML needs the same access-verification session as WK.
            // Native code attaches cookies only to declared first-party
            // origins, never to parser/CDN hosts. Media/images keep false.
            siteCookies: true,
            headers: Map<String, String>.from(payload['headers'] as Map? ?? {}),
            timeout: timeout,
          );
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
        if (identical(context._jobs[id], job)) await context._cancel(id);
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
      context._retireFetchJob(id, job);
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
    final endpoint = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/$local',
    );
    return _OmoPlayer(endpoint, () => _release(lease));
  }

  String _asset(
    Uri url,
    Map<String, String> headers,
    String lease, {
    String kind = 'media',
  }) {
    if (_assets.length >= 20000) throw StateError('Media playlist too large');
    // Do not let a server-provided URI escape the chosen network path.
    if (url.scheme != 'https' || url.userInfo.isNotEmpty || url.host.isEmpty) {
      throw const FormatException('Unsupported media URL');
    }
    final previous = _assets.entries
        .where((entry) => entry.value.lease == lease && entry.value.url == url)
        .firstOrNull;
    if (previous != null) return previous.key;
    final suffix =
        RegExp(
          r'\.(m3u8|mp4|m4a|m4s|ts|aac|key)$',
          caseSensitive: false,
        ).firstMatch(url.path)?.group(0) ??
        '.bin';
    final id = '${_opaque()}$suffix';
    _assets[id] = _OmoMediaAsset(
      url,
      Map.unmodifiable(headers),
      lease,
      kind == 'media' && url.path.toLowerCase().endsWith('.m3u8')
          ? 'playlist'
          : kind,
    );
    return id;
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    final asset = _assets[request.uri.path.replaceFirst('/', '')];
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
      final range = request.headers.value(HttpHeaders.rangeHeader);
      final knownPlaylist = asset.url.path.toLowerCase().endsWith('.m3u8');
      final playlistHead = knownPlaylist && request.method == 'HEAD';
      if (range != null && !knownPlaylist) headers['Range'] = range;
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
      if (_closed || !_assets.values.contains(asset)) return;
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
      if (_closed || !_assets.values.contains(asset)) return;
      final type = upstream.headers['content-type'] ?? '';
      final first = request.method == 'HEAD' && !playlistHead
          ? null
          : await upstream.read();
      if (_closed || !_assets.values.contains(asset)) return;
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
            if (_closed || !_assets.values.contains(asset))
              throw StateError('Media lease retired');
            firstBody(length);
          },
        );
        if (_closed || !_assets.values.contains(asset)) return;
        bytes = data.length;
        final body = omoRewritePlaylist(
          utf8.decode(data),
          upstream.url,
          (uri) => '/${_asset(uri, asset.headers, asset.lease)}',
          localTyped: (uri, role) =>
              '/${_asset(uri, asset.headers, asset.lease, kind: role)}',
        );
        final encoded = utf8.encode(body);
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        response.contentLength = encoded.length;
        if (request.method != 'HEAD') response.add(encoded);
      } else {
        for (final name in [
          'content-type',
          'content-length',
          'content-range',
          'accept-ranges',
        ]) {
          final value = upstream.headers[name];
          if (value != null) response.headers.set(name, value);
        }
        if (first != null) {
          response.add(first);
          await response.flush();
        }
        while (request.method != 'HEAD') {
          final chunk = await upstream.read();
          if (_closed || !_assets.values.contains(asset)) return;
          if (chunk == null) break;
          firstBody(chunk.length);
          response.add(chunk);
          await response.flush();
        }
      }
      terminal = 'done';
      if (upstream.status >= 400) category = 'http_status';
    } catch (error) {
      terminal = _closed || asset == null || !_assets.values.contains(asset)
          ? 'retired'
          : 'fail';
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
    final requestIds = [
      for (final asset in _assets.values)
        if (asset.lease == lease) ...asset.requestIds,
    ];
    _assets.removeWhere((_, asset) => asset.lease == lease);
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
    if (identical(_sources[source], this)) _sources.remove(source);
    _assets.clear();
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

class _OmoMediaAsset {
  _OmoMediaAsset(this.url, this.headers, this.lease, this.kind);
  final Uri url;
  final Map<String, String> headers;
  final String lease;
  final String kind;
  final requestIds = <String>{};
}

class _OmoPlayer extends VideoPlayerController {
  _OmoPlayer(super.url, this.release)
    : super.networkUrl(
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
  final AsyncCallback release;
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
  final completed = Completer<void>();
  Timer? expiry;
  bool finished = false;
  String? result;
  Object? error;
  StackTrace? stack;
}
