import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef RoutingProbeCall =
    Future<Map<String, dynamic>> Function(
      String fn,
      Map<String, dynamic> core,
      Map<String, dynamic> extern,
    );
typedef RoutingProbeCapture =
    Future<({RoutingProbeResult value, List<String> domains})> Function(
      String source,
      Future<RoutingProbeResult> Function() action,
    );
typedef RoutingProbeCommit =
    Future<void> Function({
      required String source,
      required Iterable<String> domains,
      required bool complete,
    });

class RoutingProbeVideoAccess {
  RoutingProbeVideoAccess({
    required this.repository,
    this.browser,
    Future<void> Function()? close,
  }) : close = close ?? (() async {});
  final ApiVideoRepository repository;
  final ApiVideoBrowserSession? browser;
  final Future<void> Function() close;
}

enum RoutingProbePhase {
  metadata,
  catalog,
  details,
  lines,
  committing,
  finished,
}

class RoutingProbeResult {
  const RoutingProbeResult({
    required this.succeeded,
    required this.failed,
    required this.lines,
    required this.totalLines,
    required this.unsupported,
    this.cancelled = false,
    this.domains = const [],
  });
  final int succeeded, failed, lines, totalLines, unsupported;
  final bool cancelled;
  final List<String> domains;
  bool get complete =>
      !cancelled &&
      succeeded > 0 &&
      failed == 0 &&
      unsupported == 0 &&
      lines == totalLines;
}

class _ProbeCancelled implements Exception {
  const _ProbeCancelled();
}

/// An explicit, read-only source visit. There is no player, media-byte request,
/// account action or arbitrary function discovery. URLs stay inside adapters.
class RoutingProbeSession extends ChangeNotifier {
  RoutingProbeSession({
    required this.source,
    RoutingProbeCall? call,
    Future<Map<String, dynamic>> Function()? info,
    Future<RoutingProbeVideoAccess> Function(Map<String, dynamic>)? openVideo,
    RoutingProbeCapture? capture,
    RoutingProbeCommit? commit,
    bool Function()? isCurrent,
  }) : _call =
           call ??
           ((fn, core, extern) => callUnifiedComicPlugin(
             pluginId: source,
             fnPath: fn,
             core: core,
             extern: extern,
             notifyUnauthorized: false,
           )),
       _info = info,
       _openVideoOverride = openVideo,
       _capture =
           capture ??
           ((source, action) =>
               RoutingObservedMediaDomains.capture(source, action)),
       _commit = commit ?? RoutingObservedMediaDomains.commitProbe,
       _isCurrent = isCurrent {
    if (_isCurrent == null)
      _script = PluginRegistryService.I.getByUuid(source)?.originScript;
  }
  final String source;
  final RoutingProbeCall _call;
  final Future<Map<String, dynamic>> Function()? _info;
  final Future<RoutingProbeVideoAccess> Function(Map<String, dynamic>)?
  _openVideoOverride;
  final RoutingProbeCapture _capture;
  final RoutingProbeCommit _commit;
  final bool Function()? _isCurrent;
  String? _script;
  final _cancelled = Completer<void>();
  bool _closed = false, _started = false, _committing = false;
  bool get canCancel => !_closed && !_committing && !_cancelled.isCompleted;
  bool running = false;
  RoutingProbePhase phase = RoutingProbePhase.metadata;
  int succeeded = 0, failed = 0, lines = 0, totalLines = 0, unsupported = 0;
  ApiVideoBrowserSession? browser;
  RoutingProbeResult? result;

  bool get _current {
    if (_closed || _cancelled.isCompleted) return false;
    if (_isCurrent != null) return _isCurrent();
    final plugin = PluginRegistryService.I.getByUuid(source);
    return plugin != null &&
        !plugin.isDeleted &&
        plugin.originScript == _script;
  }

  void _check() {
    if (!_current) throw const _ProbeCancelled();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void invalidateIfChanged() {
    if (!_current) cancel();
  }

  void cancel() {
    if (_committing) return; // The one atomic save has already begun.
    if (!_cancelled.isCompleted) _cancelled.complete();
    browser?.cancel();
    _notify();
  }

  @override
  void dispose() {
    cancel();
    _closed = true;
    super.dispose();
  }

  Future<T> _wait<T>(Future<T> task) => Future.any([
    task,
    _cancelled.future.then<T>((_) => throw const _ProbeCancelled()),
  ]);
  Future<T?> _step<T>(
    RoutingProbePhase next,
    Future<T> Function() action,
  ) async {
    _check();
    phase = next;
    _notify();
    try {
      final value = await _wait(action().timeout(const Duration(seconds: 55)));
      _check();
      succeeded++;
      _notify();
      return value;
    } on _ProbeCancelled {
      rethrow;
    } catch (_) {
      _check();
      failed++;
      _notify();
      return null;
    }
  }

  Future<RoutingProbeVideoAccess> _openVideo(
    Map<String, dynamic> payload,
  ) async {
    if (_openVideoOverride != null) return _openVideoOverride(payload);
    final home = apiVideoHttps(payload['url']);
    if (home == null)
      throw const FormatException('Invalid declared video home');
    final capabilities = ApiVideoCapabilities.fromJson(
      asJsonMap(payload['capabilities']),
    );
    SourceNetworkLease? lease;
    OmoNetworkContext? network;
    ApiVideoBrowserSession? session;
    try {
      if (SourceNetworkPolicies.supports(source)) {
        lease = await SourceNetworkPolicies.acquire(source);
        network = await OmoNetworkContext.open(
          null,
          source: source,
          siteOrigins: [home],
        );
      }
      _check();
      final future = Future<OmoNetworkContext?>.value(network);
      var repository = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: '${payload['catalogFnPath']}',
        detailFn: '${payload['detailFnPath']}',
        playbackFn: '${payload['playbackFnPath']}',
        capabilities: capabilities,
        pluginCall: (fn, args) => _call(fn, args, const {}),
        network: future,
      );
      if (capabilities.browserCatalog || capabilities.browserDetail) {
        // Existing source store/route, with no account restore/capture hooks.
        session = ApiVideoBrowserSession(
          home: home,
          paths: capabilities.browserPaths,
          itemPrefix: capabilities.browserItemPrefix,
          network: future,
        );
        repository = repository.withBrowserRead(
          session.read,
          detailReader: session.readDetail,
          networkContext: future,
        );
      }
      final retainedSession = session,
          retainedNetwork = network,
          retainedLease = lease;
      return RoutingProbeVideoAccess(
        repository: repository,
        browser: session,
        close: () async {
          retainedSession?.dispose();
          try {
            await retainedNetwork?.close();
          } finally {
            await retainedLease?.close();
          }
        },
      );
    } catch (_) {
      session?.dispose();
      try {
        await network?.close();
      } finally {
        await lease?.close();
      }
      rethrow;
    }
  }

  static bool _function(Object? raw) =>
      raw is String &&
      RegExp(r'^[A-Za-z_$][A-Za-z0-9_$.]{0,119}$').hasMatch(raw);
  static List<Map<String, dynamic>> _comicReads(Map<String, dynamic> info) {
    final reads = <Map<String, dynamic>>[];
    final home = asJsonMap(asJsonMap(info['nativeContent'])['home']);
    if (home['readonly'] == true && _function(home['fnPath'])) reads.add(home);
    // Only the declared public list action has a read contract. Do not walk
    // unrelated fnPath values (settings/onChanged/sign-in/write actions).
    for (final raw in asJsonList(info['function'])) {
      final action = asJsonMap(asJsonMap(raw)['action']);
      if (action['type'] != 'openComicList') continue;
      final body = asJsonMap(
        asJsonMap(asJsonMap(action['payload'])['scene'])['body'],
      );
      final request = asJsonMap(body['request']);
      if (body['type'] == 'pluginPagedComicList' &&
          _function(request['fnPath']))
        reads.add(request);
    }
    final seen = <String>{};
    return [
      for (final read in reads)
        if (seen.add('${read['fnPath']}|${read['core']}|${read['extern']}'))
          read,
    ].take(1).toList();
  }

  Future<RoutingProbeResult> _probe() async {
    final info = await _step(
      RoutingProbePhase.metadata,
      () => _info?.call() ?? _call('getInfo', const {}, const {}),
    );
    if (info == null) return _snapshot();
    final modules = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final action in videoSourceActions(info)) {
      if (action['type'] != 'openVideoLibrary') {
        unsupported++;
        continue;
      }
      final payload = asJsonMap(action['payload']);
      if (apiVideoHttps(payload['url']) == null ||
          ![
            'catalogFnPath',
            'detailFnPath',
            'playbackFnPath',
          ].every((key) => _function(payload[key]))) {
        unsupported++;
        continue;
      }
      final key = '${payload['url']}|${payload['catalogFnPath']}';
      if (seen.add(key)) modules.add(payload);
    }
    final comic = _comicReads(info);
    if (modules.isEmpty && comic.isEmpty && unsupported == 0) unsupported++;
    for (final request in comic) {
      await _step(
        RoutingProbePhase.catalog,
        () => _call(request['fnPath'] as String, {
          ...asJsonMap(request['core']),
          'page': 1,
        }, asJsonMap(request['extern'])),
      );
    }
    for (final payload in modules) {
      _check();
      RoutingProbeVideoAccess? access;
      try {
        access = await _openVideo(payload);
        _check();
        browser = access.browser;
        browser?.addListener(_notify);
        _notify();
        final repository = access.repository;
        final page = await _step(
          RoutingProbePhase.catalog,
          () => repository.page(refresh: true),
        );
        if (page == null) continue;
        final summary = page.items.firstOrNull;
        if (summary == null) {
          unsupported++;
          continue;
        }
        final item = await _step(
          RoutingProbePhase.details,
          () => repository.item(summary.id, refresh: true, snapshot: summary),
        );
        if (item == null) continue;
        final available = item.lines
            .where((line) => line.episodes.isNotEmpty)
            .toList();
        totalLines += available.length;
        if (available.isEmpty) unsupported++;
        for (final line in available) {
          final resolved = await _step(
            RoutingProbePhase.lines,
            () => repository.session(
              item.id,
              lineId: line.id,
              episodeId: line.episodes.first.id,
              refresh: true,
              snapshot: item,
            ),
          );
          if (resolved != null) lines++;
        }
      } on _ProbeCancelled {
        rethrow;
      } catch (_) {
        _check();
        failed++;
      } finally {
        browser?.removeListener(_notify);
        browser = null;
        _notify();
        await access?.close();
      }
    }
    _check();
    return _snapshot();
  }

  RoutingProbeResult _snapshot({
    bool cancelled = false,
    List<String> domains = const [],
  }) => RoutingProbeResult(
    succeeded: succeeded,
    failed: failed,
    lines: lines,
    totalLines: totalLines,
    unsupported: unsupported,
    cancelled: cancelled,
    domains: domains,
  );

  Future<RoutingProbeResult> run() async {
    if (_started) throw StateError('Probe already started');
    _started = true;
    running = true;
    _notify();
    try {
      final captured = await _capture(source, _probe);
      _check();
      if (succeeded > 1 && captured.domains.isNotEmpty) {
        _committing = true;
        phase = RoutingProbePhase.committing;
        _notify();
        await _commit(
          source: source,
          domains: captured.domains,
          complete: captured.value.complete,
        );
      }
      // Once the atomic save began it may finish even if its page left.
      // Cancellation before that boundary was checked above and never writes.
      if (!_committing) _check();
      result = _snapshot(domains: captured.domains);
    } on _ProbeCancelled {
      result = _snapshot(cancelled: true);
    } catch (_) {
      if (_current) failed++;
      result = _snapshot(cancelled: !_current);
    } finally {
      _committing = false;
      running = false;
      phase = RoutingProbePhase.finished;
      _notify();
    }
    return result!;
  }
}
