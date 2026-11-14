import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';

/// Domain metadata and explicit candidate choices only. Export policies and
/// confirmation of a particular generated file are not restored as a draft.
abstract final class RoutingDomainCatalogStore {
  static Future<void> flush() async {
    await _writes;
  }

  static const _key = 'breeze.routing.domains.v3';
  static Future<void>? _writes;

  static RoutingPlan domainsOnly(RoutingPlan value) => RoutingPlan(
    extraDomains: value.extraDomains,
    customSources: value.customSources,
    scannedDomains: {
      for (final entry in value.scannedDomains.entries)
        entry.key: entry.value.where(isRoutingContentDomain).toList(),
    },
    confirmedDomains: {
      for (final entry in value.confirmedDomains.entries)
        entry.key: entry.value.where(isRoutingContentDomain).toList(),
    },
  );

  /// Observation evidence only; used inside explicit-save validation to avoid
  /// reading the saved-store writer that currently owns the commit.
  static Future<RoutingPlan> readEvidence() async =>
      _withObserved(await _readBase());

  static Future<RoutingPlan> read() async =>
      (await RoutingSavedRulesStore.read()).applyTo(
        await _withObserved(await _readBase()),
      );

  static Future<RoutingPlan> _withObserved(RoutingPlan value) async {
    final observed = await RoutingObservedMediaDomains.read();
    final scanned = {...value.scannedDomains};
    for (final entry in observed.entries) {
      scanned[entry.key] = {
        ...?scanned[entry.key],
        ...entry.value.map((row) => row.host),
      }.toList()..sort();
    }
    return RoutingPlan(
      extraDomains: value.extraDomains,
      customSources: value.customSources,
      scannedDomains: scanned,
      confirmedDomains: value.confirmedDomains,
    ).withAvailableSources([
      for (final id in observed.keys)
        if (!value.sources.any((source) => source.id == id))
          RoutingSource(id, id, const []),
    ]);
  }

  static Future<RoutingPlan> _readBase() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _key,
      'breeze.routing.workflow.v2',
      'breeze.routing.export.v1',
    ]) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        var json = jsonDecode(raw) as Map<String, dynamic>;
        if (key == 'breeze.routing.workflow.v2') {
          json = Map<String, dynamic>.from(
            (json['draft'] ?? json['plan']) as Map,
          );
        }
        final base = domainsOnly(RoutingPlan.fromJson(json));
        // Confirmations of runtime candidates live in the catalog, while those
        // candidates themselves remain in the bounded observation store. The
        // general plan decoder intentionally drops absent scanned hosts, so
        // preserve validated confirmations here without inventing candidates.
        final confirmed = <String, List<String>>{};
        for (final entry in (json['confirmedDomains'] as Map? ?? {}).entries) {
          final hosts = (entry.value as List).cast<String>();
          if (hosts.length > 200)
            throw const FormatException('Too many domains');
          confirmed[entry.key as String] =
              hosts
                  .map(normalizeRoutingDomain)
                  .where(isRoutingContentDomain)
                  .toSet()
                  .toList()
                ..sort();
        }
        return RoutingPlan(
          extraDomains: base.extraDomains,
          customSources: base.customSources,
          scannedDomains: base.scannedDomains,
          confirmedDomains: confirmed,
        );
      } catch (_) {
        // Invalid old metadata must not trap users on a permanent retry screen.
      }
    }
    return RoutingPlan();
  }

  static Future<void> _save(RoutingPlan value) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(domainsOnly(value).toJson()),
    )) {
      throw StateError('Could not save domain metadata');
    }
  }

  static Future<RoutingPlan> _mutate(
    FutureOr<RoutingPlan> Function(RoutingPlan) update,
  ) {
    final previous = _writes;
    final completed = Completer<void>();
    final current = completed.future;
    _writes = current;
    Future<RoutingPlan> persist() async {
      try {
        if (previous != null) await previous;
        final proposed = domainsOnly(await update(await _readBase()));
        final combined = await _withObserved(proposed);
        final validated = RoutingPlan.fromJson(combined.toJson());
        final next = RoutingPlan(
          extraDomains: validated.extraDomains,
          customSources: validated.customSources,
          scannedDomains: proposed.scannedDomains,
          confirmedDomains: validated.confirmedDomains,
        );
        await _save(next);
        return (await RoutingSavedRulesStore.read()).applyTo(
          await _withObserved(next),
        );
      } finally {
        if (identical(_writes, current)) _writes = null;
        completed.complete();
      }
    }

    return persist();
  }

  static Future<void> save(RoutingPlan value) async {
    await _mutate((_) => value);
  }

  /// Persist each source change against the latest snapshot, so simultaneous
  /// refreshes or another open tool do not replace one another's metadata.
  static Future<RoutingPlan> saveScannedSource(RoutingSource source) =>
      _mutate((current) => current.withScannedSource(source));

  static Future<RoutingPlan> confirmDomain(
    String source,
    String host,
    bool confirmed,
  ) => _mutate((current) async {
    final reviewed = (await _withObserved(
      current,
    )).withConfirmedDomain(source, host, confirmed);
    return RoutingPlan(
      extraDomains: current.extraDomains,
      customSources: reviewed.customSources,
      scannedDomains: current.scannedDomains,
      confirmedDomains: reviewed.confirmedDomains,
    );
  });

  static Future<RoutingPlan> saveSources(
    RoutingPlan value,
    Set<String> sources,
  ) => _mutate((current) async {
    final fresh = await _withObserved(current);
    final extra = {...current.extraDomains};
    final custom = {...current.customSources};
    // Scans and confirmations are saved when performed, not by this older
    // generation draft; writing it back would resurrect stale candidates.
    for (final id in sources) {
      if (jsonEncode(value.scannedDomains[id] ?? const []) !=
              jsonEncode(fresh.scannedDomains[id] ?? const []) ||
          jsonEncode(value.confirmedDomains[id] ?? const []) !=
              jsonEncode(fresh.confirmedDomains[id] ?? const [])) {
        throw RoutingCatalogChanged();
      }
      extra[id] = value.extraDomains[id] ?? const [];
      if (value.customSources.containsKey(id) && !custom.containsKey(id)) {
        custom[id] = value.customSources[id]!;
      }
    }
    return RoutingPlan(
      extraDomains: extra,
      customSources: custom,
      scannedDomains: current.scannedDomains,
      confirmedDomains: current.confirmedDomains,
    );
  });
}

/// A review cannot silently export an older snapshot of observed media hosts.
class RoutingCatalogChanged extends StateError {
  RoutingCatalogChanged() : super('Domain catalog changed during review');
}
