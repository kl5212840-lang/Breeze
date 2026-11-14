import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';

class RoutingSavedRule {
  const RoutingSavedRule({
    required this.name,
    required this.route,
    required this.domains,
    required this.revision,
  });
  final String name;
  final PluginRoute route;
  final List<String> domains;
  final int revision;
  Map<String, dynamic> toJson() => {
    'name': name,
    'route': route.name,
    'domains': domains,
    'revision': revision,
  };
}

class RoutingSavedSnapshot {
  const RoutingSavedSnapshot(this.sources);
  final Map<String, RoutingSavedRule> sources;
  Map<String, int> get revisions => {
    for (final e in sources.entries) e.key: e.value.revision,
  };
  RoutingPlan applyTo(RoutingPlan catalog) => RoutingPlan(
    choices: {
      ...catalog.choices,
      for (final e in sources.entries) e.key: e.value.route,
    },
    extraDomains: {
      for (final e in catalog.extraDomains.entries)
        if (!sources.containsKey(e.key)) e.key: e.value,
    },
    scannedDomains: catalog.scannedDomains,
    confirmedDomains: {
      for (final e in catalog.confirmedDomains.entries)
        if (!sources.containsKey(e.key)) e.key: e.value,
    },
    customSources: {
      ...catalog.customSources,
      for (final e in sources.entries)
        e.key: RoutingSource(
          e.key,
          e.value.name,
          e.value.domains,
          fromFile: catalog.customSources[e.key]?.fromFile ?? false,
        ),
    },
  );
}

class RoutingSavedRulesChanged extends StateError {
  RoutingSavedRulesChanged()
    : super('Saved routing rules changed; review a new preview');
}

/// Explicit local Save only. Candidate selection and generation never write here.
abstract final class RoutingSavedRulesStore {
  static Future<void> flush() async {
    await _tail;
  }

  static const storageKey = 'breeze.routing.saved-rules.v1';
  static Future<void>? _tail;

  static RoutingSavedSnapshot _decode(String? raw) {
    if (raw == null) return const RoutingSavedSnapshot({});
    final json = jsonDecode(raw) as Map;
    if (json['version'] != 1)
      throw const FormatException('Unsupported saved rules version');
    final values = json['sources'] as Map;
    if (values.length > 100)
      throw const FormatException('Too many saved sources');
    final result = <String, RoutingSavedRule>{};
    for (final e in values.entries) {
      final id = e.key as String;
      final row = e.value as Map;
      final domains = (row['domains'] as List).cast<String>();
      final name = row['name'] as String;
      final revision = row['revision'] as int;
      if (id.isEmpty ||
          id.length > 100 ||
          name.trim().isEmpty ||
          name.length > 120 ||
          revision < 1 ||
          domains.length > 200)
        throw const FormatException('Invalid saved source');
      final normalized = domains.map(normalizeRoutingDomain).toSet().toList()
        ..sort();
      if (normalized.any((host) => !isRoutingContentDomain(host))) {
        throw const FormatException('Invalid saved domain');
      }
      result[id] = RoutingSavedRule(
        name: name,
        route: PluginRoute.values.byName(row['route'] as String),
        domains: List.unmodifiable(normalized),
        revision: revision,
      );
    }
    return RoutingSavedSnapshot(Map.unmodifiable(result));
  }

  static Future<RoutingSavedSnapshot> read() async {
    final pending = _tail;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decode(prefs.getString(storageKey));
  }

  /// Selected sources use optimistic per-source revisions. Other sources merge
  /// against the latest snapshot inside one process-owned serialized write.
  static Future<RoutingSavedSnapshot> save({
    required RoutingPlan plan,
    required List<RoutingSource> sources,
    required Map<String, int> expectedRevisions,
    Future<void> Function()? validateFresh,
  }) {
    final previous = _tail;
    final result = () async {
      if (previous != null) await previous;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final previousRaw = prefs.getString(storageKey);
      final current = _decode(
        previousRaw,
      ); // Unknown future formats fail closed.
      if (sources.isEmpty) throw const FormatException('No selected source');
      final next = {...current.sources};
      for (final source in sources) {
        if ((current.sources[source.id]?.revision ?? 0) !=
            (expectedRevisions[source.id] ?? 0)) {
          throw RoutingSavedRulesChanged();
        }
        final domains = plan.domainsFor(source).toSet().toList()..sort();
        if (domains.isEmpty ||
            domains.length > 200 ||
            domains.any((host) => !isRoutingContentDomain(host))) {
          throw const FormatException('Invalid saved domains');
        }
        final validatedSource = RoutingSource.fromJson({
          ...source.toJson(),
          'domains': domains,
        });
        next[source.id] = RoutingSavedRule(
          name: validatedSource.name,
          route: plan.choices[source.id] ?? PluginRoute.existing,
          domains: List.unmodifiable(domains),
          revision: (current.sources[source.id]?.revision ?? 0) + 1,
        );
      }
      if (next.length > 100)
        throw const FormatException('Too many saved sources');
      await validateFresh?.call();
      final combined = RoutingSavedSnapshot(next).applyTo(RoutingPlan());
      final encoded = jsonEncode({
        'version': 1,
        'fingerprint': combined.fingerprint,
        'sources': {for (final e in next.entries) e.key: e.value.toJson()},
      });
      if (!await prefs.setString(storageKey, encoded))
        throw StateError('Could not save routing rules');
      await prefs.reload();
      if (prefs.getString(storageKey) != encoded)
        throw RoutingSavedRulesChanged();
      try {
        // A plugin/observation may change across the platform persistence await.
        await validateFresh?.call();
      } catch (_) {
        if (prefs.getString(storageKey) == encoded) {
          final restored = previousRaw == null
              ? await prefs.remove(storageKey)
              : await prefs.setString(storageKey, previousRaw);
          if (!restored)
            throw StateError(
              'Routing review changed; rollback could not be verified',
            );
          await prefs.reload();
          if (prefs.getString(storageKey) != previousRaw)
            throw RoutingSavedRulesChanged();
        }
        rethrow;
      }
      return RoutingSavedSnapshot(Map.unmodifiable(next));
    }();
    final completed = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = completed;
    // Retain only active writes. A settled Future may belong to an old caller
    // zone (notably another widget-test clock), and must not gate future reads.
    completed.then((_) {
      if (identical(_tail, completed)) _tail = null;
    });
    return result;
  }
}
