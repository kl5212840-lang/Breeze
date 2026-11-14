import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';

enum RoutingRecordOrigin { generated, configuration }

/// A local record of generated output, never a claim about an external app's
/// active profile. Store exact hosts, not a live reference to the domain catalog.
class RoutingGenerationRecord {
  const RoutingGenerationRecord({
    required this.source,
    required this.route,
    required this.generatedAt,
    this.origin = RoutingRecordOrigin.generated,
    this.configurationStatus,
    this.checkedAt,
  });

  final RoutingSource source;
  final PluginRoute route;
  final DateTime generatedAt;
  final RoutingRecordOrigin origin;
  final String? configurationStatus;
  final DateTime? checkedAt;

  RoutingGenerationRecord checked(String status, DateTime at) {
    if (!const {
      'matching',
      'missing',
      'different',
      'conflicting',
    }.contains(status)) {
      throw const FormatException('Invalid configuration check');
    }
    return RoutingGenerationRecord(
      source: source,
      route: route,
      generatedAt: generatedAt,
      origin: origin,
      configurationStatus: status,
      checkedAt: at.toUtc(),
    );
  }

  String get ruleBlock => routingRuleBlockFor(source, route, source.domains);

  Map<String, dynamic> toJson() => {
    'source': source.toJson(),
    'route': route.name,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    if (origin != RoutingRecordOrigin.generated) 'origin': origin.name,
    if (configurationStatus != null) 'configurationStatus': configurationStatus,
    if (checkedAt != null) 'checkedAt': checkedAt!.toUtc().toIso8601String(),
  };

  static RoutingGenerationRecord fromJson(Map<String, dynamic> json) {
    final record = RoutingGenerationRecord(
      source: RoutingSource.fromJson(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      route: PluginRoute.values.byName(json['route'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
      origin: json['origin'] == null
          ? RoutingRecordOrigin.generated
          : RoutingRecordOrigin.values.byName(json['origin'] as String),
      configurationStatus: json['configurationStatus'] as String?,
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String).toUtc(),
    );
    record.ruleBlock; // Validate identity, policy and public hosts before use.
    if ((record.checkedAt == null) != (record.configurationStatus == null)) {
      throw const FormatException('Incomplete configuration check');
    }
    if (record.configurationStatus != null) {
      record.checked(record.configurationStatus!, record.checkedAt!);
    }
    return record;
  }
}

abstract final class RoutingGenerationRecords {
  static const _key = 'breeze.routing.generated-records.v1';
  static Future<void>? _pending;

  static Future<List<RoutingGenerationRecord>> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    return values
        .map(
          (v) => RoutingGenerationRecord.fromJson(
            Map<String, dynamic>.from(v as Map),
          ),
        )
        .toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  /// Keep one latest snapshot per plugin. Generating a selection never changes
  /// other records and never restores a selection in the generation wizard.
  static Future<void> record(
    RoutingPlan plan,
    Iterable<String> selection, {
    DateTime? now,
  }) {
    final ids = selection.toSet();
    selectedRoutingRuleBlocks(plan, ids);
    final at = (now ?? DateTime.now()).toUtc();
    final snapshots = [
      for (final source in plan.sources.where((s) => ids.contains(s.id)))
        RoutingGenerationRecord(
          source: RoutingSource(
            source.id,
            source.name,
            List.unmodifiable(plan.domainsFor(source)),
            fromFile: source.fromFile,
          ),
          route: plan.choices[source.id]!,
          generatedAt: at,
        ),
    ];
    return _mutate((records) {
      for (final record in snapshots) {
        records[record.source.id] = record;
      }
    });
  }

  /// A successful file read never replaces a generated target or removes an
  /// unrelated record. A generation completed while the picker was open wins.
  /// Only public rule summaries are retained, never the profile or node data.
  static Future<void> applyConfigurationInspection({
    required List<RoutingGenerationRecord> expected,
    required List<RoutingGenerationRecord> recovered,
    required Map<String, String> statuses,
    required DateTime checkedAt,
  }) => _mutate((records) {
    for (final snapshot in expected) {
      final current = records[snapshot.source.id];
      final status = statuses[snapshot.source.id];
      if (current != null &&
          status != null &&
          current.generatedAt == snapshot.generatedAt &&
          current.origin == snapshot.origin &&
          current.ruleBlock == snapshot.ruleBlock) {
        records[current.source.id] = current.checked(status, checkedAt);
      }
    }
    for (final record in recovered) {
      if (record.origin != RoutingRecordOrigin.configuration ||
          !statuses.containsKey(record.source.id)) {
        throw const FormatException('Invalid recovered configuration rule');
      }
      records.putIfAbsent(
        record.source.id,
        () => record.checked(statuses[record.source.id]!, checkedAt),
      );
    }
  });

  static Future<void> _mutate(
    void Function(Map<String, RoutingGenerationRecord>) change,
  ) {
    final previous = _pending;
    final completed = Completer<void>();
    final current = completed.future;
    _pending = current;
    Future<void> persist() async {
      try {
        if (previous != null) await previous;
        final records = {for (final r in await read()) r.source.id: r};
        change(records);
        if (!await (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode(records.values.map((r) => r.toJson()).toList()),
        )) {
          throw StateError('Could not save generation records');
        }
      } finally {
        if (identical(_pending, current)) _pending = null;
        completed.complete();
      }
    }

    return persist();
  }
}
