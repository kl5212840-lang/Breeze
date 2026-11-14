import 'dart:convert';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';

/// Public host inventories and saved export choices only. Proxy endpoints,
/// generated-file acknowledgments and external configuration checks stay local.
const portableRoutingKeys = {
  'breeze.routing.observed-media.v1',
  'breeze.routing.domains.v3',
  'breeze.routing.saved-rules.v1',
};

bool validPortableRoutingValue(String key, Object? value) {
  if (!portableRoutingKeys.contains(key) ||
      value is! String ||
      value.length > 16 * 1024 * 1024)
    return false;
  try {
    final data = jsonDecode(value);
    if (data is! Map) return false;
    bool keys(Map row, Set<String> allowed) => row.keys.every(allowed.contains);
    bool id(Object? raw) =>
        raw is String &&
        raw.isNotEmpty &&
        raw.length <= 100 &&
        !RegExp(r'[\x00-\x1f\x7f]').hasMatch(raw);
    bool hosts(Object? raw, [int maximum = 200]) =>
        raw is List &&
        raw.length <= maximum &&
        raw.every(
          (host) =>
              host is String &&
              normalizeRoutingDomain(host) == host &&
              isRoutingContentDomain(host),
        );
    bool hostMap(Object? raw) =>
        raw is Map &&
        raw.length <= 100 &&
        raw.entries.every((entry) => id(entry.key) && hosts(entry.value));
    bool route(Object? raw) =>
        raw is String && PluginRoute.values.any((choice) => choice.name == raw);
    bool time(Object? raw) => raw is int && raw >= 0 && raw <= 8640000000000000;
    if (key == 'breeze.routing.observed-media.v1') {
      return data.length <= 64 &&
          data.entries.every(
            (entry) =>
                entry.key is String &&
                RegExp(
                  r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
                ).hasMatch(entry.key) &&
                entry.value is List &&
                (entry.value as List).length <= 200 &&
                (entry.value as List).every(
                  (row) =>
                      row is Map &&
                      keys(row, {'host', 'at', 'evidence'}) &&
                      hosts([row['host']]) &&
                      time(row['at']) &&
                      row['evidence'] is List &&
                      (row['evidence'] as List).isNotEmpty &&
                      (row['evidence'] as List).length <= 3 &&
                      (row['evidence'] as List).every(
                        {'resolved', 'requested', 'response'}.contains,
                      ),
                ),
          );
    }
    if (key == 'breeze.routing.saved-rules.v1') {
      final sources = data['sources'];
      final valid =
          keys(data, {'version', 'sources', 'fingerprint'}) &&
          data['version'] == 1 &&
          sources is Map &&
          sources.length <= 100 &&
          sources.entries.every((entry) {
            final row = entry.value;
            return id(entry.key) &&
                row is Map &&
                keys(row, {'name', 'route', 'domains', 'revision'}) &&
                row['name'] is String &&
                (row['name'] as String).trim().isNotEmpty &&
                (row['name'] as String).length <= 120 &&
                route(row['route']) &&
                hosts(row['domains']) &&
                row['revision'] is int &&
                row['revision'] > 0;
          });
      if (!valid) return false;
      // This is a digest of the public saved rule content, not a claim that an
      // external configuration was applied. Legacy rows may omit the digest.
      if (!data.containsKey('fingerprint')) return true;
      if (data['fingerprint'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['fingerprint']))
        return false;
      final snapshot = RoutingSavedSnapshot({
        for (final entry in sources.entries)
          entry.key as String: RoutingSavedRule(
            name: entry.value['name'] as String,
            route: PluginRoute.values.byName(entry.value['route'] as String),
            domains: (entry.value['domains'] as List).cast<String>(),
            revision: entry.value['revision'] as int,
          ),
      });
      return snapshot.applyTo(RoutingPlan()).fingerprint == data['fingerprint'];
    }
    if (!keys(data, {
      'choices',
      'extraDomains',
      'customSources',
      'scannedDomains',
      'confirmedDomains',
    }))
      return false;
    final choices = data['choices'], custom = data['customSources'];
    if (choices is! Map ||
        choices.isNotEmpty ||
        custom is! List ||
        custom.length > 100 ||
        !hostMap(data['extraDomains']) ||
        !hostMap(data['scannedDomains']) ||
        !hostMap(data['confirmedDomains']))
      return false;
    return custom.every(
      (row) =>
          row is Map &&
          keys(row, {'id', 'name', 'domains', 'fromFile'}) &&
          id(row['id']) &&
          row['name'] is String &&
          (row['name'] as String).trim().isNotEmpty &&
          (row['name'] as String).length <= 120 &&
          hosts(row['domains']) &&
          row['fromFile'] is bool,
    );
  } catch (_) {
    return false;
  }
}
