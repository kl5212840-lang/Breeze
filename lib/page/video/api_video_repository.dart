import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'dart:async';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'dart:collection';
import 'package:zephyr/network/playback_trace.dart';

import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_public_cover_store.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef ApiVideoPluginCall =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> args,
    );
typedef ApiVideoBrowserRead = Future<Map<String, dynamic>> Function(Uri url);

const _iKunSource = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';

class ApiVideoStageFailure implements Exception {
  const ApiVideoStageFailure(this.stage, this.cause);
  final String stage;
  final Object cause;
  @override
  String toString() => '$stage: $cause';
}

typedef _ApiVideoDetailKey = ({String source, Uri home, String id});

class _ApiVideoDetailLoad {
  _ApiVideoDetailLoad(
    this.key, {
    required this.refresh,
    required this.cacheEpoch,
    this.snapshot,
  });
  final zone = Zone.current;
  final resolutionOwner = VideoDownloadResolutionOwner.current;
  final _ApiVideoDetailKey key;
  final int cacheEpoch;
  final result = Completer<ApiVideoItem>();
  bool refresh;
  bool started = false;
  final Map<String, Object?>? snapshot;
}

class _ApiVideoDetailCache {
  const _ApiVideoDetailCache(this.item, this.expiresAt);
  final ApiVideoItem item;
  final DateTime expiresAt;
}

class ApiVideoRepository implements TemporaryDataCache {
  ApiVideoRepository({
    required this.source,
    required this.home,
    required this.catalogFn,
    required this.detailFn,
    required this.playbackFn,
    this.batchDetailFn,
    this.network,
    this.capabilities = const ApiVideoCapabilities(),
    ApiVideoPluginCall? pluginCall,
    bool? cancellableDownloadTransport,
    this.browserRead,
    this.browserRecoveryAllowed,
    this.browserRecoveryActivity,
    this.browserDetailRead,
    this.retainBrowserForDownloads,
    DateTime Function()? detailClock,
  }) : cancellableDownloadTransport =
           cancellableDownloadTransport ?? pluginCall == null,
       _detailClock = detailClock ?? DateTime.now,
       call =
           pluginCall ??
           ((path, args) => callUnifiedComicPlugin(
             pluginId: source,
             fnPath: path,
             core: args,
           )) {
    TemporaryDataCaches.register(this);
  }
  int _cacheEpoch = 0;
  @override
  String get cacheSource => source;
  @override
  int get cacheEntryCount => _detailCache.length;
  @override
  void clearTemporaryData() {
    _cacheEpoch++;
    _detailCache.clear();
  }

  final String source, catalogFn, detailFn, playbackFn;
  final String? batchDetailFn;
  final Uri home;
  final Future<OmoNetworkContext?>? network;
  OmoNetworkContext? networkContext;
  final ApiVideoPluginCall call;
  final ApiVideoCapabilities capabilities;
  final ApiVideoBrowserRead? browserRead;
  final bool Function()? browserRecoveryAllowed;
  final Listenable? browserRecoveryActivity;
  final ApiVideoBrowserRead? browserDetailRead;
  final Future<Future<void> Function()> Function()? retainBrowserForDownloads;
  final bool cancellableDownloadTransport;
  final DateTime Function() _detailClock;
  final _detailCache = <_ApiVideoDetailKey, _ApiVideoDetailCache>{};
  late final _publicCovers = VideoPublicCoverStore(source: source, home: home);
  final _detailLoads = <_ApiVideoDetailKey, _ApiVideoDetailLoad>{};
  final _detailQueue = Queue<_ApiVideoDetailLoad>();
  final _foregroundDetailQueue = Queue<_ApiVideoDetailLoad>();
  int _activeDetailLoads = 0;
  static const _detailCacheLimit = 64;
  static const _detailCacheTtl = Duration(minutes: 5);
  static const _detailConcurrency = 2;

  ApiVideoRepository withBrowserRead(
    ApiVideoBrowserRead reader, {
    ApiVideoBrowserRead? detailReader,
    Future<Future<void> Function()> Function()? retainForDownloads,
    Future<OmoNetworkContext?>? networkContext,
    bool Function()? recoveryAllowed,
    Listenable? recoveryActivity,
  }) => ApiVideoRepository(
    source: source,
    home: home,
    catalogFn: catalogFn,
    detailFn: detailFn,
    playbackFn: playbackFn,
    batchDetailFn: batchDetailFn,
    network: networkContext ?? network,
    capabilities: capabilities,
    pluginCall: call,
    cancellableDownloadTransport: cancellableDownloadTransport,
    browserRead: reader,
    browserRecoveryAllowed: recoveryAllowed ?? browserRecoveryAllowed,
    browserRecoveryActivity: recoveryActivity ?? browserRecoveryActivity,
    browserDetailRead: detailReader,
    retainBrowserForDownloads: retainForDownloads ?? retainBrowserForDownloads,
    detailClock: _detailClock,
  );

  ApiVideoRepository withNetwork(Future<OmoNetworkContext?> network) =>
      ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: catalogFn,
        detailFn: detailFn,
        playbackFn: playbackFn,
        batchDetailFn: batchDetailFn,
        network: network,
        capabilities: capabilities,
        pluginCall: call,
        cancellableDownloadTransport: cancellableDownloadTransport,
        browserRead: browserRead,
        browserRecoveryAllowed: browserRecoveryAllowed,
        browserRecoveryActivity: browserRecoveryActivity,
        browserDetailRead: browserDetailRead,
        retainBrowserForDownloads: retainBrowserForDownloads,
        detailClock: _detailClock,
      );

  bool get supportsDownloadBrowser =>
      retainBrowserForDownloads == null ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android));

  Future<({ApiVideoRepository repository, Future<void> Function()? release})>
  acquireDownloadBrowser() async {
    final retain = retainBrowserForDownloads;
    if (retain == null) return (repository: this, release: null);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return (repository: this, release: await retain());
    }
    if (browserRecoveryAllowed?.call() == false) {
      throw const VideoDownloadResolutionFailure('verificationRequired');
    }

    // The visible Android platform view releases its Dart controller when the
    // route closes. Use a separate, bounded transport that shares Android's
    // persistent WebView cookie store and owns no account-changing UI.
    final session = ApiVideoBrowserSession(
      home: home,
      paths: capabilities.browserPaths,
      itemPrefix: capabilities.browserItemPrefix,
      interactive: false,
    );
    final view = HeadlessInAppWebView(
      initialSize: const Size(320, 480),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useShouldOverrideUrlLoading: true,
        blockNetworkImage: true,
      ),
      onWebViewCreated: session.created,
      onPageCommitVisible: (web, uri) =>
          session.committed(web, Uri.tryParse(uri?.toString() ?? '')),
      onLoadStop: (web, uri) =>
          session.loaded(web, Uri.tryParse(uri?.toString() ?? '')),
      onReceivedError: (_, request, error) =>
          session.receivedError(request, error),
      shouldOverrideUrlLoading: (_, action) async =>
          allowVideoSiteNavigation(
            home,
            Uri.tryParse(action.request.url?.toString() ?? ''),
            isMainFrame: action.isForMainFrame,
          )
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL,
    );
    Future<void>? startingView;
    Future<void>? closing;
    Future<void> release() => closing ??= Future<void>.sync(() async {
      session.dispose();
      final opening = startingView;
      if (opening == null) return;
      // The Android bridge only disposes a headless view after run() has
      // completed. A late creation must still be cleaned up after cancellation.
      await opening.catchError((Object _) {});
      await view.dispose().timeout(const Duration(seconds: 5));
    });
    Future<void>? starting;
    Future<Map<String, dynamic>> detail(Uri url) async {
      final owner = VideoDownloadResolutionOwner.current;
      owner?.check();
      await (starting ??= () async {
        await (startingView ??= view.run()).timeout(const Duration(seconds: 5));
        owner?.check();
        await session.read(home).timeout(const Duration(seconds: 35));
      }());
      owner?.check();
      return session.readDetail(url);
    }

    return (
      repository: withBrowserRead(session.read, detailReader: detail),
      release: release,
    );
  }

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic> args,
  ) async {
    VideoDownloadResolutionOwner.current?.check();
    OmoNetworkContext? transport;
    // iKun's public catalog uses QuickJS fetch on the source's pinned route.
    // The native session is only needed for its separate media path.
    if (source == _iKunSource && path == catalogFn) {
      // Keep the original future for media callers to await and report.
      network?.ignore();
    } else {
      PlaybackTrace.note(source, 'network_session', 'waiting');
      try {
        transport = await network?.timeout(const Duration(seconds: 10));
      } catch (error, stack) {
        Error.throwWithStackTrace(
          ApiVideoStageFailure('network_session', error),
          stack,
        );
      }
      VideoDownloadResolutionOwner.current?.check();
      PlaybackTrace.note(
        source,
        'network_session',
        'ready; native=${transport != null}',
      );
      networkContext = transport;
    }
    final request = {
      'clientProtocol': 2,
      ...args,
      if (capabilities.detailFromSnapshot) 'home': home.toString(),
      if (transport != null) 'networkContext': transport.token,
    };
    late Map<String, dynamic> result;
    Map<String, dynamic> responseData(Map<String, dynamic> response) {
      requireSuccessfulPluginEnvelope(response);
      final data = asJsonMap(response['data']);
      if (path == catalogFn || path == detailFn || path == playbackFn) {
        requireSuccessfulPluginEnvelope(data);
      }
      return data;
    }

    PlaybackTrace.note(source, 'plugin_call', 'begin fn=$path');
    try {
      result = responseData(
        await call(
          path,
          request,
        ).timeout(Duration(seconds: path == playbackFn ? 45 : 35)),
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(
        ApiVideoStageFailure(
          path == playbackFn ? 'plugin_resolution' : 'plugin_data',
          error,
        ),
        stack,
      );
    }
    PlaybackTrace.note(
      source,
      'plugin_call',
      'returned; browserDetail=${result["browserDetailRequest"] is Map}; media=${result["sources"] is List}',
    );
    if (result['browserDetailRequest'] is Map) {
      if (path != playbackFn ||
          !capabilities.browserDetail ||
          browserDetailRead == null) {
        throw const FormatException('Browser detail transport unavailable');
      }
      PlaybackTrace.note(source, 'browser_detail', 'requested');
      final snapshot = await _publicDetailSnapshot('${args['id']}');
      if (asJsonMap(result['browserDetailRequest'])['url'] != snapshot['url']) {
        throw const FormatException('Wrong public detail requested');
      }
      result = responseData(
        await call(path, {
          ...request,
          'browserSnapshot': snapshot,
        }).timeout(const Duration(seconds: 45)),
      );
      PlaybackTrace.note(
        source,
        'browser_detail',
        'plugin returned after snapshot',
      );
      if (result.containsKey('browserDetailRequest')) {
        throw const FormatException('Repeated browser detail request');
      }
    }
    if (result['browserRequest'] is Map) {
      if (!capabilities.browserCatalog ||
          browserRead == null ||
          path != catalogFn) {
        throw const FormatException('Browser catalog transport unavailable');
      }
      final url = apiVideoHttps(
        asJsonMap(result['browserRequest'])['url'],
        origin: home,
      );
      if (url == null) {
        throw const FormatException('Invalid browser catalog request');
      }
      final snapshot = await browserRead!(url);
      result = responseData(
        await call(path, {
          ...request,
          'browserSnapshot': snapshot,
        }).timeout(const Duration(seconds: 35)),
      );
      if (result.containsKey('browserRequest')) {
        throw const FormatException('Repeated browser verification request');
      }
    }
    return result;
  }

  Future<ApiVideoResult> page({
    String query = '',
    String typeId = '',
    String year = '',
    int page = 1,
    Map<String, dynamic>? cursor,
    bool refresh = false,
    int recentHours = 0,
    Uri? browseUrl,
    String sort = '',
  }) async {
    final data = await _request(catalogFn, {
      'query': query,
      'typeId': typeId,
      'year': year,
      'page': page,
      'cursor': cursor,
      'refresh': refresh,
      'recentHours': recentHours,
      if (browseUrl != null) 'browseUrl': browseUrl.toString(),
      if (sort.isNotEmpty) 'sort': sort,
    });
    final items = data['items'];
    if (items is! List || items.any((item) => item is! Map)) {
      throw const FormatException('Invalid video result items');
    }
    return ApiVideoResult.fromJson(
      await _publicCovers.supplement(data, refresh: refresh),
      home: home,
    );
  }

  /// Summary cards never populate or replace the full-detail cache.
  Future<ApiVideoItem> enrich(ApiVideoItem summary, {bool refresh = false}) {
    if (summary.detailUrl.origin != home.origin) {
      return Future.error(const FormatException('Wrong video library'));
    }
    return _item(
      summary.id,
      refresh: refresh,
      background: true,
      snapshot: summary,
    );
  }

  Future<ApiVideoItem> item(
    String id, {
    bool refresh = false,
    ApiVideoItem? snapshot,
  }) => _item(id, refresh: refresh, background: false, snapshot: snapshot);

  Map<String, Object?>? _publicSnapshot(String id, ApiVideoItem? item) {
    if (!capabilities.detailFromSnapshot) return null;
    if (item == null ||
        item.id != id ||
        item.detailUrl.origin != home.origin ||
        (capabilities.itemNamespace.isNotEmpty &&
            !id.startsWith('${capabilities.itemNamespace}:'))) {
      throw const FormatException(
        'Missing or mismatched public video snapshot',
      );
    }
    return item.toLibraryJson();
  }

  Future<ApiVideoItem> _item(
    String id, {
    required bool refresh,
    required bool background,
    ApiVideoItem? snapshot,
  }) {
    final publicSnapshot = _publicSnapshot(id, snapshot);
    final key = (source: source, home: home, id: id);
    var pending = _detailLoads[key];
    if (pending?.resolutionOwner?.cancelled == true ||
        pending?.resolutionOwner?.closed == true) {
      // A cancelled attempt must not lend its future/zone to the next reader.
      _detailQueue.remove(pending);
      _foregroundDetailQueue.remove(pending);
      pending = null;
    }
    // A tapped title moves ahead of queued list enrichment. Already running
    // reads remain bounded by the shared two-request limit.
    if (!background && pending != null && !pending.started) {
      if (_detailQueue.remove(pending)) _foregroundDetailQueue.addLast(pending);
    }
    if (refresh) {
      _detailCache.remove(key);
      if (pending != null && (!pending.started || pending.refresh)) {
        pending.refresh = true;
        return pending.result.future;
      }
    } else {
      if (pending != null) return pending.result.future;
      final cached = _detailCache.remove(key);
      if (cached != null && _detailClock().isBefore(cached.expiresAt)) {
        _detailCache[key] = cached;
        return Future.value(cached.item);
      }
    }
    final load = _ApiVideoDetailLoad(
      key,
      refresh: refresh,
      cacheEpoch: _cacheEpoch,
      snapshot: publicSnapshot,
    );
    _detailLoads[key] = load;
    if (background) {
      _detailQueue.add(load);
    } else {
      _foregroundDetailQueue.addLast(load);
    }
    _drainDetailQueue();
    return load.result.future;
  }

  void _drainDetailQueue() {
    while (_activeDetailLoads < _detailConcurrency &&
        (_foregroundDetailQueue.isNotEmpty || _detailQueue.isNotEmpty)) {
      final load = _foregroundDetailQueue.isNotEmpty
          ? _foregroundDetailQueue.removeFirst()
          : _detailQueue.removeFirst();
      load.started = true;
      _activeDetailLoads++;
      unawaited(load.zone.run(() => _loadDetail(load)));
    }
  }

  Future<void> _loadDetail(_ApiVideoDetailLoad load) async {
    try {
      final value = ApiVideoItem.fromJson(
        await _readDetail(
          load.key.id,
          refresh: load.refresh,
          snapshot: load.snapshot,
        ),
        home: home,
      );
      if (value.id != load.key.id) {
        throw const FormatException('Wrong video returned');
      }
      // A refresh can supersede a slower normal request. Only the current
      // load may write the cache, including when its predecessor finishes last.
      if (load.cacheEpoch == _cacheEpoch &&
          identical(_detailLoads[load.key], load)) {
        _detailCache.remove(load.key);
        _detailCache[load.key] = _ApiVideoDetailCache(
          value,
          _detailClock().add(_detailCacheTtl),
        );
        while (_detailCache.length > _detailCacheLimit) {
          _detailCache.remove(_detailCache.keys.first);
        }
        unawaited(_publicCovers.remember([value]));
      }
      load.result.complete(value);
    } catch (error, stack) {
      load.result.completeError(error, stack);
    } finally {
      if (identical(_detailLoads[load.key], load)) {
        _detailLoads.remove(load.key);
      }
      _activeDetailLoads--;
      _drainDetailQueue();
    }
  }

  Future<Map<String, dynamic>> _readDetail(
    String id, {
    required bool refresh,
    Map<String, Object?>? snapshot,
  }) async {
    if (!capabilities.browserDetail || browserDetailRead == null) {
      return _request(detailFn, {
        'id': id,
        'refresh': refresh,
        'snapshot': ?snapshot,
      });
    }
    final browserSnapshot = await _publicDetailSnapshot(id);
    return _request(detailFn, {
      'id': id,
      'refresh': true,
      'browserSnapshot': browserSnapshot,
    });
  }

  Future<Map<String, dynamic>> _publicDetailSnapshot(String id) async {
    // Session-backed sources use the same browser transport for catalog and
    // public details. An anonymous GET must not delay or invalidate that session.
    if (capabilities.browserItemPrefix != '/anime/' ||
        !RegExp(r'^[a-f0-9]{16,64}$').hasMatch(id)) {
      throw const FormatException('Unsupported public detail identity');
    }
    final url = home.resolve('${capabilities.browserItemPrefix}$id.html');
    final snapshot = await browserDetailRead!(
      url,
    ).timeout(const Duration(seconds: 15));
    if (snapshot['kind'] != 'public-detail' ||
        snapshot['url'] != url.toString() ||
        snapshot['verification'] == true ||
        snapshot['html'] is! String ||
        (snapshot['html'] as String).isEmpty ||
        (snapshot['html'] as String).length > 2000000) {
      throw const FormatException('Public detail requires verification');
    }
    return snapshot;
  }

  Future<List<ApiVideoItem>> items(List<String> ids) async {
    if (ids.isEmpty || ids.length > 20) {
      throw ArgumentError.value(ids.length, 'ids');
    }
    if (capabilities.browserDetail && browserDetailRead != null) {
      // Browser sources share the bounded detail queue for batch reads.
      return Future.wait([for (final id in ids) item(id, refresh: true)]);
    }
    if (batchDetailFn == null || batchDetailFn!.isEmpty) {
      final result = <ApiVideoItem>[];
      for (final id in ids) {
        result.add(await item(id, refresh: true));
      }
      return result;
    }
    final raw = await _request(batchDetailFn!, {'ids': ids});
    requireSuccessfulPluginEnvelope(raw);
    if (raw['items'] is! List) {
      throw const FormatException('Missing video detail items');
    }
    final result = <ApiVideoItem>[], seen = <String>{};
    for (final row in asJsonList(raw['items'])) {
      final item = ApiVideoItem.fromJson(asJsonMap(row), home: home);
      if (!ids.contains(item.id)) {
        throw const FormatException('Unexpected detail item');
      }
      if (!seen.add(item.id)) {
        throw const FormatException('Duplicate detail item');
      }
      result.add(item);
    }
    return result;
  }

  Future<({ApiVideoItem item, NativePlaybackSession session})> session(
    String id, {
    String? lineId,
    String? episodeId,
    bool refresh = false,
    bool rawHlsRecovery = false,
    ApiVideoItem? snapshot,
  }) async {
    if (rawHlsRecovery && !capabilities.rawHlsRecovery) {
      throw UnsupportedError('Source does not declare raw HLS recovery');
    }
    final observationEpoch = _cacheEpoch;
    final publicSnapshot = _publicSnapshot(id, snapshot);
    final raw = await _request(playbackFn, {
      'id': id,
      'lineId': lineId,
      'episodeId': episodeId,
      'refresh': refresh,
      'snapshot': ?publicSnapshot,
      if (capabilities.browserDetail && browserDetailRead != null)
        'browserDetailTransport': true,
      if (rawHlsRecovery) 'rawHlsRecovery': true,
    });
    try {
      PlaybackTrace.note(source, 'media_relay', 'prepare');
      await networkContext?.prepare().timeout(const Duration(seconds: 3));
    } catch (error, stack) {
      Error.throwWithStackTrace(
        ApiVideoStageFailure('media_relay', error),
        stack,
      );
    }
    PlaybackTrace.note(source, 'media_contract', 'validating');
    final item = ApiVideoItem.fromJson(asJsonMap(raw['item']), home: home);
    final selectedLine = apiVideoText(raw['lineId'], 160),
        selectedEpisode = apiVideoText(raw['episodeId'], 300);
    if (item.id != id ||
        (lineId != null && lineId != selectedLine) ||
        (episodeId != null && episodeId != selectedEpisode)) {
      throw const FormatException('Wrong episode returned');
    }
    final line = item.lines
        .where((value) => value.id == selectedLine)
        .firstOrNull;
    if (line == null ||
        !line.episodes.any((value) => value.id == selectedEpisode)) {
      throw const FormatException('Wrong episode returned');
    }
    List<NativePlaybackSource>? sources;
    if (raw.containsKey('sources')) {
      final seen = <Uri>{};
      sources = [];
      for (final value in asJsonList(raw['sources']).take(8)) {
        final source = asJsonMap(value);
        final url = apiVideoHttps(source['url']);
        if (url == null || !seen.add(url)) continue;
        final headers = <String, String>{};
        final rawHeaders = asJsonMap(source['headers']);
        for (final name in ['Referer', 'Origin', 'User-Agent']) {
          final value = apiVideoText(rawHeaders[name], 2000);
          if (value.isEmpty || value.contains('\r') || value.contains('\n')) {
            continue;
          }
          if (name != 'User-Agent' && apiVideoHttps(value)?.host != home.host) {
            continue;
          }
          headers[name] = value;
        }
        sources.add(
          NativePlaybackSource(
            url: url,
            label: apiVideoText(source['quality'], 100).isEmpty
                ? line.label
                : apiVideoText(source['quality'], 100),
            headers: Map.unmodifiable(headers),
          ),
        );
      }
      if (sources.isEmpty) {
        throw const FormatException('No valid playback sources');
      }
    }
    final session = item.session(
      selectedLine,
      selectedEpisode,
      sources: sources,
    );
    if (videoPlaybackIdentity(Uri.parse(apiVideoText(raw['watchUrl'], 4096))) !=
        session.watchUrl) {
      throw const FormatException('Episode identity mismatch');
    }
    // Only a validated, exact episode contract can add routing candidates.
    // The store discards URL paths, queries and headers before persistence.
    if (observationEpoch == _cacheEpoch) {
      unawaited(
        RoutingObservedMediaDomains.observeResolved(
          source: source,
          media: session.sources.map((value) => value.url),
        ),
      );
    }
    PlaybackTrace.note(
      source,
      'media_contract',
      'ready; sources=${session.sources.length}',
    );
    return (item: item, session: session);
  }
}
