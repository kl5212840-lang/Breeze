import 'dart:convert';

import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_generation_records.dart';

/// Exact DOMAIN content only, never effective traffic routing or runtime state.
enum RoutingConfigurationMatch { matching, missing, different, conflicting }

/// Identity comes only from a valid Breeze marker, never from a domain catalog.
/// No timestamp is invented for a block recovered from configuration text.
class InspectedRoutingBlock {
  InspectedRoutingBlock._(
    String id,
    String name,
    Iterable<String> domains,
    this.route,
  ) : source = RoutingSource(
        id,
        name,
        List<String>.unmodifiable(domains.toList()..sort()),
      );
  final RoutingSource source;
  final PluginRoute route;
}

class RoutingConfigInspection {
  RoutingConfigInspection._({
    required Iterable<InspectedRoutingBlock> ownedBlocks,
    required Map<String, RoutingConfigurationMatch> statusBySource,
    required Iterable<String> conflictingDomains,
    required Iterable<String> unknownPolicyDomains,
    required this.unrecognizedRuleCount,
  }) : ownedBlocks = List.unmodifiable(ownedBlocks),
       statusBySource = Map.unmodifiable(statusBySource),
       conflictingDomains = Set.unmodifiable(
         conflictingDomains.toList()..sort(),
       ),
       unknownPolicyDomains = Set.unmodifiable(
         unknownPolicyDomains.toList()..sort(),
       );

  final List<InspectedRoutingBlock> ownedBlocks;

  /// Every expected ID, plus previously unknown, recoverable marked IDs.
  /// Blocks with custom/mixed policies never acquire an inferred matching entry.
  final Map<String, RoutingConfigurationMatch> statusBySource;
  final Set<String> conflictingDomains, unknownPolicyDomains;

  /// Other rule kinds and DOMAIN forms/policies outside the supported subset.
  /// These are counted, not retained. Even zero does not prove runtime routing.
  final int unrecognizedRuleCount;
  bool get hasUnrecognizedRules => unrecognizedRuleCount != 0;
}

const _maxBytes = 2 * 1024 * 1024;
const _maxSources = 100;
const _maxDomains = 200;
final _identity = RegExp(r'^[a-zA-Z0-9:_-]{1,100}$');
final _unsafeName = RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]');
final _section = RegExp(r'^\[([^\]]+)\][ \t]*(?:[#;].*)?$');
final _malformedRule = RegExp(r'^\[[ \t]*rule\b', caseSensitive: false);
final _marker = RegExp(
  r'^#[ \t]*(?:(.+)[ \t]+-[ \t]+)?(BEGIN|END)[ \t]+BREEZE[ \t]+PLUGIN[ \t]+([a-zA-Z0-9:_-]{1,100})[ \t]*$',
  caseSensitive: false,
);
final _markerWords = RegExp(
  r'\b(?:BEGIN|END)[ \t]+BREEZE(?:[ \t]*PLUGIN)?\b',
  caseSensitive: false,
);

int? _commentStart(String line) {
  var whitespace = -1;
  for (var i = 0; i < line.length; i++) {
    final code = line.codeUnitAt(i);
    if (code == 32 || code == 9) {
      if (whitespace == -1) whitespace = i;
      continue;
    }
    if (whitespace != -1 &&
        (code == 35 ||
            code == 59 ||
            (code == 47 &&
                i + 1 < line.length &&
                line.codeUnitAt(i + 1) == 47)))
      return whitespace;
    whitespace = -1;
  }
  return null;
}

String _domain(String value) {
  final host = value.trim();
  if (host.length > 253) throw const FormatException('Invalid public domain');
  return normalizeRoutingDomain(host);
}

String _checkedId(String id) {
  final match = _identity.firstMatch(id);
  if (match == null || match.end != id.length)
    throw const FormatException('Invalid plugin identity');
  return id.toLowerCase();
}

String _checkedName(String name) {
  final value = name.trim();
  if (value.isEmpty || value.length > 120 || _unsafeName.hasMatch(value)) {
    throw const FormatException('Invalid plugin name');
  }
  return value;
}

PluginRoute? _route(String policy) => switch (policy.toUpperCase()) {
  'DIRECT' => PluginRoute.direct,
  'PROXY' => PluginRoute.proxy,
  _ => null,
};

class _Expected {
  _Expected(RoutingGenerationRecord record)
    : id = record.source.id,
      name = _checkedName(record.source.name),
      route = record.route,
      domains = _domains(record.source.domains) {
    _checkedId(id);
    if (route == PluginRoute.existing)
      throw const FormatException('Missing expected policy');
  }
  final String id, name;
  final PluginRoute route;
  final Set<String> domains;
}

Set<String> _domains(List<String> values) {
  if (values.isEmpty || values.length > _maxDomains) {
    throw const FormatException('Invalid source domain count');
  }
  return values.map(_domain).toSet();
}

class _Block {
  _Block(this.id, this.name);
  final String id;
  final String? name;
  final domains = <String>{};
  PluginRoute? route;
  int lines = 0;
  bool recoverable = true;
}

class _Policy {
  _Policy(this.first, {required this.unknown, required this.unsupported});
  final String first;
  bool unknown, unsupported, conflicting = false;
  void add(String token, {required bool unknown, required bool unsupported}) {
    if (token != first) conflicting = true;
    this.unknown |= unknown;
    this.unsupported |= unsupported;
  }
}

/// Inspect one user-chosen Shadowrocket configuration without executing it,
/// retaining its full text, reading storage or interpreting proxy/server nodes.
///
/// Only a single [Rule] section and exact DOMAIN rules participate. Other rule
/// kinds, ordering, DNS, rewrites and an external app's active profile are not
/// evaluated. Malformed ownership structure rejects atomically. Custom or
/// mixed DOMAIN policies decline recovery of that block, without rejecting
/// the other blocks or hiding its differences from known expected content.
RoutingConfigInspection inspectRoutingConfiguration(
  String config,
  List<RoutingGenerationRecord> expected,
) {
  if (config.length > _maxBytes ||
      utf8.encode(config).length > _maxBytes ||
      config.contains('\u0000') ||
      (config.length > 1 && config.indexOf('\uFEFF', 1) != -1)) {
    throw const FormatException('Invalid configuration input');
  }
  if (expected.length > _maxSources)
    throw const FormatException('Too many sources');
  final wanted = <String, _Expected>{};
  for (final record in expected) {
    final value = _Expected(record), key = _checkedId(record.source.id);
    if (wanted.containsKey(key))
      throw const FormatException('Duplicate expected identity');
    wanted[key] = value;
  }

  final blocks = <String, InspectedRoutingBlock>{};
  final declaredBlocks = <String, _Block>{};
  final seen = <String>{};
  final policies = <String, _Policy>{};
  var ruleSections = 0, inRules = false, unrecognized = 0;
  _Block? active;
  final input = config.startsWith('\uFEFF') ? config.substring(1) : config;

  for (final raw in LineSplitter.split(input)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    // Earlier exports used one anonymous shared block. Its DOMAIN lines can
    // check expected content, but it cannot recover a plugin identity.
    final legacy =
        line.toUpperCase() == routingRuleBlockStart.toUpperCase() ||
        line.toUpperCase() == routingRuleBlockEnd.toUpperCase();
    final commentLine =
        line.startsWith('#') || line.startsWith(';') || line.startsWith('//');
    if (!legacy && commentLine && _markerWords.hasMatch(line)) {
      if (line.length > 512)
        throw const FormatException('Invalid owned marker');
      final match = _marker.firstMatch(line);
      if (match == null || !inRules)
        throw const FormatException('Invalid owned marker');
      final id = match.group(3)!, key = _checkedId(id);
      final name = match.group(1) == null
          ? null
          : _checkedName(match.group(1)!);
      if (match.group(2)!.toUpperCase() == 'BEGIN') {
        if (active != null || !seen.add(key))
          throw const FormatException('Duplicate or nested owned block');
        if ({...wanted.keys, ...seen}.length > _maxSources)
          throw const FormatException('Too many sources');
        active = _Block(id, name);
      } else {
        final block = active;
        if (block == null ||
            _checkedId(block.id) != key ||
            block.name?.toLowerCase() != name?.toLowerCase()) {
          throw const FormatException('Mismatched owned marker');
        }
        if (block.domains.isEmpty)
          throw const FormatException('Empty owned block');
        declaredBlocks[key] = block;
        if (block.recoverable) {
          final known = wanted[key];
          blocks[key] = InspectedRoutingBlock._(
            known?.id ?? block.id,
            block.name ?? known?.name ?? block.id,
            block.domains,
            block.route!,
          );
        }
        active = null;
      }
      continue;
    }
    if (line.startsWith('#') || line.startsWith(';') || line.startsWith('//'))
      continue;
    final headerComment = _commentStart(line);
    final header = headerComment == null
        ? line
        : line.substring(0, headerComment).trimRight();
    final section = _section.firstMatch(header);
    if (section != null) {
      if (active != null)
        throw const FormatException('Owned block crosses section boundary');
      inRules = section.group(1)!.trim().toLowerCase() == 'rule';
      if (inRules && ++ruleSections != 1)
        throw const FormatException('Expected one Rule section');
      continue;
    }
    if (_malformedRule.hasMatch(line)) {
      throw const FormatException('Malformed Rule section');
    }
    if (!inRules) continue;
    final content = header;
    final first = content.indexOf(',');
    final second = first == -1 ? -1 : content.indexOf(',', first + 1);
    if (first == -1 ||
        second == -1 ||
        content.substring(0, first).trim().toUpperCase() != 'DOMAIN') {
      if (active != null) throw const FormatException('Unsupported owned rule');
      unrecognized++;
      continue;
    }
    final third = content.indexOf(',', second + 1);
    String host;
    try {
      host = _domain(content.substring(first + 1, second));
    } on FormatException {
      if (active != null) throw const FormatException('Invalid owned domain');
      unrecognized++;
      continue;
    }
    final policy = content
        .substring(second + 1, third == -1 ? content.length : third)
        .trim();
    final route = _route(policy);
    final unsupported = third != -1;
    if (active != null) {
      if (policy.isEmpty || unsupported)
        throw const FormatException('Unsupported owned policy');
      if (++active.lines > _maxDomains)
        throw const FormatException('Too many source domains');
      if (route == null) {
        active.recoverable = false;
      } else if (active.route != null && active.route != route) {
        // The rules are legitimate configuration content, but one uniform
        // DIRECT/PROXY source snapshot cannot represent this edited block.
        if (active.recoverable) unrecognized++;
        active.recoverable = false;
      }
      active.route ??= route;
      active.domains.add(host);
    }
    if (route == null || unsupported) unrecognized++;
    // Unknown strategies remain opaque; never silently map a named group or
    // server to PROXY. Tokens live only during this call, not in the result.
    final token = route == null ? 'unknown:$policy' : 'known:${route.name}';
    final previous = policies[host];
    if (previous == null) {
      policies[host] = _Policy(
        token,
        unknown: route == null,
        unsupported: unsupported,
      );
    } else {
      previous.add(token, unknown: route == null, unsupported: unsupported);
    }
  }
  if (ruleSections != 1)
    throw const FormatException('Expected one Rule section');
  if (active != null) throw const FormatException('Unterminated owned block');

  RoutingConfigurationMatch compare(
    Set<String> domains,
    PluginRoute route, {
    _Block? block,
  }) {
    final relevant = {...domains, ...?block?.domains};
    if (relevant.any((host) => policies[host]?.conflicting == true))
      return RoutingConfigurationMatch.conflicting;
    if (block != null &&
        (!block.recoverable ||
            block.route != route ||
            !domains.containsAll(block.domains) ||
            domains.length != block.domains.length)) {
      return RoutingConfigurationMatch.different;
    }
    final present = domains.where(policies.containsKey).length;
    if (present == 0 && block == null) return RoutingConfigurationMatch.missing;
    if (present != domains.length ||
        domains.any((host) {
          final value = policies[host];
          return value == null ||
              value.unknown ||
              value.unsupported ||
              value.first != 'known:${route.name}';
        }))
      return RoutingConfigurationMatch.different;
    return RoutingConfigurationMatch.matching;
  }

  final statuses = <String, RoutingConfigurationMatch>{};
  for (final entry in wanted.entries) {
    final value = entry.value;
    statuses[value.id] = compare(
      value.domains,
      value.route,
      block: declaredBlocks[entry.key],
    );
  }
  for (final entry in blocks.entries) {
    if (wanted.containsKey(entry.key)) continue;
    final block = entry.value;
    statuses[block.source.id] = compare(
      block.source.domains.toSet(),
      block.route,
      block: declaredBlocks[entry.key],
    );
  }
  return RoutingConfigInspection._(
    ownedBlocks: blocks.values,
    statusBySource: statuses,
    conflictingDomains: policies.entries
        .where((entry) => entry.value.conflicting)
        .map((entry) => entry.key),
    unknownPolicyDomains: policies.entries
        .where((entry) => entry.value.unknown)
        .map((entry) => entry.key),
    unrecognizedRuleCount: unrecognized,
  );
}
