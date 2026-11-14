import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';

/// Host-only evidence from plugin HTTP and validated media resolution, never a
/// routing policy or a log of URLs. New hosts still require explicit review.
class RoutingObservedMediaHost {
  const RoutingObservedMediaHost(this.host, this.lastSeen, this.evidence);
  final String host;
  final DateTime lastSeen;
  final Set<String> evidence;
}

abstract final class RoutingObservedMediaDomains {
  static Future<void> flush() async {
    await _writes;
  }

  static const storageKey = 'breeze.routing.observed-media.v1';
  // These are the current discovered domains, not an expiring browsing log.
  // Replace only after a complete explicit probe; failed probes retain them.
  static const maxHosts = 200;
  static const _maxSources = 64;
  static const _writeInterval = Duration(hours: 6);
  static const _kinds = {'resolved', 'requested', 'response'};
  static final _captureKey = Object();
  static Future<void>? _writes;

  static String? _host(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.port != 443)
      return null;
    try {
      final host = normalizeRoutingDomain(uri.host);
      return isRoutingContentDomain(host) ? host : null;
    } catch (_) {
      return null;
    }
  }

  static bool _source(String source) => RegExp(
    r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
  ).hasMatch(source);

  static Map<String, List<RoutingObservedMediaHost>> _decode(
    String? raw,
    DateTime now,
  ) {
    final result = <String, List<RoutingObservedMediaHost>>{};
    try {
      final data = jsonDecode(raw ?? '{}') as Map;
      for (final entry in data.entries.take(_maxSources)) {
        if (entry.key is! String ||
            !_source(entry.key as String) ||
            entry.value is! List)
          continue;
        final hosts = <RoutingObservedMediaHost>[];
        for (final row in (entry.value as List).take(maxHosts)) {
          if (row is! Map ||
              row['host'] is! String ||
              row['at'] is! int ||
              row['evidence'] is! List)
            continue;
          final host = _host(Uri.https(row['host'] as String));
          final at = DateTime.fromMillisecondsSinceEpoch(
            row['at'] as int,
            isUtc: true,
          );
          if (host != row['host'] || at.isAfter(now)) continue;
          final kinds = (row['evidence'] as List)
              .whereType<String>()
              .where(_kinds.contains)
              .toSet();
          if (kinds.isNotEmpty)
            hosts.add(RoutingObservedMediaHost(host!, at, kinds));
        }
        if (hosts.isNotEmpty) result[entry.key as String] = hosts;
      }
    } catch (_) {
      // A corrupt optional hint must never stop playback or rule generation.
    }
    return result;
  }

  static Future<Map<String, List<RoutingObservedMediaHost>>> read() async {
    final pending = _writes;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(storageKey), DateTime.now().toUtc());
  }

  static Future<bool> observeResolved({
    required String source,
    required Iterable<Uri> media,
  }) => _observe(source, {
    for (final uri in media.take(8))
      if (_host(uri) case final String host) host: {'resolved'},
  });

  /// The runtime bridge provides hosts only, never request contents.
  static Future<bool> observeHosts(String source, Iterable<String> hosts) =>
      _observe(source, {
        for (final value in hosts.take(maxHosts + 1))
          if (Uri.tryParse('https://$value') case final Uri uri)
            if (_host(uri) case final String host)
              if (host == value) host: {'requested'},
      });

  /// Probe work is staged. Its late callbacks keep this closed scope and are
  /// discarded instead of leaking into passive discovery after cancellation.
  static Future<({T value, List<String> domains})> capture<T>(
    String source,
    Future<T> Function() action,
  ) async {
    if (!_source(source)) throw const FormatException('Invalid source');
    final capture = _RoutingHostCapture();
    final inherited =
        Zone.current[_captureKey] as Map<String, _RoutingHostCapture>?;
    try {
      final value = await runZoned(
        action,
        zoneValues: {
          _captureKey: {...?inherited, source: capture},
        },
      );
      if (capture.overflow) throw const FormatException('Too many domains');
      return (value: value, domains: capture.hosts.toList()..sort());
    } finally {
      capture.closed = true;
    }
  }

  /// Partial success only adds evidence; a complete probe atomically replaces
  /// this source's snapshot. Manual domains and other sources are independent.
  static Future<void> commitProbe({
    required String source,
    required Iterable<String> domains,
    required bool complete,
  }) async {
    final hosts = domains.toSet();
    if (!_source(source) ||
        hosts.isEmpty ||
        hosts.length > maxHosts ||
        hosts.any(
          (value) => switch (Uri.tryParse('https://$value')) {
            null => true,
            final Uri uri => _host(uri) != value,
          },
        )) {
      throw const FormatException('Invalid domain snapshot');
    }
    if (!await _observe(
      source,
      {
        for (final host in hosts) host: {'resolved'},
      },
      replaceSource: complete,
      captureAllowed: false,
    )) {
      throw StateError('Could not save domain snapshot');
    }
  }

  /// Only successful real requests contribute redirect/segment/key hosts.
  /// Errors and persistence failures are deliberately non-fatal to playback.
  static Future<bool> observe({
    required String source,
    required Uri requested,
    required Uri responseUrl,
    required int status,
  }) {
    if (status < 200 || status >= 300) return Future.value(false);
    final evidence = <String, Set<String>>{};
    for (final entry in [(requested, 'requested'), (responseUrl, 'response')]) {
      final host = _host(entry.$1);
      if (host != null) (evidence[host] ??= {}).add(entry.$2);
    }
    return _observe(source, evidence);
  }

  static Future<bool> _observe(
    String source,
    Map<String, Set<String>> evidence, {
    bool replaceSource = false,
    bool captureAllowed = true,
  }) {
    if (!_source(source) || evidence.isEmpty) return Future.value(false);
    final captures =
        Zone.current[_captureKey] as Map<String, _RoutingHostCapture>?;
    final capture = captureAllowed && captures != null
        ? captures[source]
        : null;
    if (capture != null) {
      if (capture.closed) return Future.value(false);
      for (final host in evidence.keys) {
        if (capture.hosts.length > maxHosts) break;
        capture.hosts.add(host);
      }
      if (capture.hosts.length > maxHosts) capture.overflow = true;
      return Future.value(!capture.overflow);
    }
    if (evidence.length > maxHosts) return Future.value(false);
    final previous = _writes;
    final completed = Completer<void>();
    final current = completed.future;
    _writes = current;
    Future<bool> persist() async {
      try {
        if (previous != null) await previous;
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().toUtc();
        final data = _decode(prefs.getString(storageKey), now);
        if (!data.containsKey(source) && data.length >= _maxSources)
          return false;
        final hosts = {
          for (final row
              in replaceSource
                  ? <RoutingObservedMediaHost>[]
                  : data[source] ?? <RoutingObservedMediaHost>[])
            row.host: row,
        };
        if ({...hosts.keys, ...evidence.keys}.length > maxHosts) return false;
        var changed = false;
        for (final entry in evidence.entries) {
          final old = hosts[entry.key];
          if (old != null &&
              old.evidence.containsAll(entry.value) &&
              now.difference(old.lastSeen) < _writeInterval)
            continue;
          hosts[entry.key] = RoutingObservedMediaHost(entry.key, now, {
            ...?old?.evidence,
            ...entry.value,
          });
          changed = true;
        }
        if (!changed) return true;
        final sorted = hosts.values.toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
        data[source] = sorted;
        // Refuse overflow rather than silently deleting another saved source.
        final sources = data.entries.toList()
          ..sort(
            (a, b) => b.value.first.lastSeen.compareTo(a.value.first.lastSeen),
          );
        return await prefs.setString(
          storageKey,
          jsonEncode({
            for (final entry in sources)
              entry.key: [
                for (final row in entry.value)
                  {
                    'host': row.host,
                    'at': row.lastSeen.millisecondsSinceEpoch,
                    'evidence': row.evidence.toList()..sort(),
                  },
              ],
          }),
        );
      } catch (_) {
        return false;
      } finally {
        if (identical(_writes, current)) _writes = null;
        completed.complete();
      }
    }

    return persist();
  }
}

class _RoutingHostCapture {
  final hosts = <String>{};
  bool closed = false;
  bool overflow = false;
}
