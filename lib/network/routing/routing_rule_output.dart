import 'package:zephyr/network/routing/plugin_routing_rules.dart';

String _marker(String id, bool start, {String? name}) {
  if (!RegExp(r'^[a-zA-Z0-9:_-]{1,100}$').hasMatch(id)) {
    throw const FormatException('Invalid plugin identity');
  }
  return '# ${name == null ? '' : '$name - '}${start ? 'BEGIN' : 'END'} BREEZE PLUGIN $id';
}

/// Only explicitly selected plugins enter the output. A plugin owns its own
/// block so updating it need not replace another plugin's rules.
String selectedRoutingRuleBlocks(RoutingPlan plan, Iterable<String> selection) {
  final ids = selection.toSet();
  if (ids.isEmpty) throw const FormatException('No plugins selected');
  final scoped = plan.onlySources(ids);
  scoped
      .rules; // Validate conflicts within this generation, not old intentions.
  final blocks = <String>[];
  for (final id in ids) {
    final source = scoped.sources.where((s) => s.id == id).firstOrNull;
    final route = scoped.choices[id] ?? PluginRoute.existing;
    if (source == null || route == PluginRoute.existing) {
      throw const FormatException('Selected plugin has no routing policy');
    }
    final domains = scoped.domainsFor(source);
    if (domains.isEmpty) {
      throw const FormatException('Selected plugin has no domains');
    }
    blocks.add(routingRuleBlockFor(source, route, domains));
  }
  return blocks.join('\n\n');
}

/// NekoBox for Android's domain field uses `full:` for exact matching. Bare
/// hosts would also match subdomains and silently broaden the selected policy.
/// Keep each outbound separate; this is a domain-field value, not a profile.
String selectedNekoBoxDomains(
  RoutingPlan plan,
  Iterable<String> selection, {
  required PluginRoute route,
}) {
  if (route == PluginRoute.existing) {
    throw const FormatException('No routing policy');
  }
  final ids = selection.toSet();
  selectedRoutingRuleBlocks(plan, ids); // Validate the exact reviewed scope.
  final hosts =
      plan
          .onlySources(ids)
          .rules
          .entries
          .where((entry) => entry.value == route)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  if (hosts.isEmpty) throw const FormatException('No matching domains');
  return hosts.map((host) => 'full:$host').join('\n');
}

/// Build from an exact domain snapshot, including records saved before a
/// maintained plugin's domain inventory changes.
String routingRuleBlockFor(
  RoutingSource source,
  PluginRoute route,
  Iterable<String> domains,
) {
  if (route == PluginRoute.existing) {
    throw const FormatException('No routing policy');
  }
  final hosts = domains.map(normalizeRoutingDomain).toSet().toList()..sort();
  if (hosts.isEmpty) throw const FormatException('No domains');
  final name = source.name.replaceAll(
    RegExp(r'[\r\n\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'),
    ' ',
  );
  final policy = route == PluginRoute.direct ? 'DIRECT' : 'PROXY';
  return [
    _marker(source.id, true, name: name),
    '# $policy',
    ...hosts.map((host) => 'DOMAIN,$host,$policy'),
    _marker(source.id, false, name: name),
  ].join('\n');
}

/// Patches selected owned blocks in the actual user-chosen profile. Unselected
/// blocks, unrelated rules, servers, and sections remain byte-for-byte intact.
String mergeSelectedRoutingRules(
  String original,
  RoutingPlan plan,
  Iterable<String> selection, {
  Map<String, List<String>> previousDomains = const {},
}) {
  final ids = selection.toSet();
  final output = selectedRoutingRuleBlocks(plan, ids);
  if (original.length > 2 * 1024 * 1024 || original.contains('\u0000')) {
    throw const FormatException('Invalid config');
  }
  final newline = original.contains('\r\n') ? '\r\n' : '\n';
  final matches = RegExp(
    r'^(?:\uFEFF)?[ \t]*\[Rule\][ \t]*(?:\r?\n|$)',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(original).toList();
  if (matches.length != 1) {
    throw const FormatException('Expected one Rule section');
  }
  final start = matches.single.end;
  final next = RegExp(
    r'^[ \t]*\[[^\]\r\n]+\]',
    multiLine: true,
  ).firstMatch(original.substring(start));
  final end = next == null ? original.length : start + next.start;
  var body = original.substring(start, end);

  String replaceBlock(
    String text,
    String begin,
    String finish,
    String Function(String) transform, {
    bool named = false,
  }) {
    // Names are for people; the stable identity owns the block, even if the
    // plugin is renamed. Also accepts unnamed markers from earlier exports.
    String linePattern(String value) => named
        ? '# (?:[^\\r\\n]* - )?${RegExp.escape(value.substring(2))}'
        : RegExp.escape(value);
    final beginPattern = linePattern(begin), endPattern = linePattern(finish);
    final begins = RegExp(
      '^$beginPattern\\r?\$',
      multiLine: true,
    ).allMatches(text).length;
    final ends = RegExp(
      '^$endPattern\\r?\$',
      multiLine: true,
    ).allMatches(text).length;
    if (begins == 0 && ends == 0) return text;
    final block = RegExp(
      '^$beginPattern\\r?\\n[\\s\\S]*?^$endPattern(?:\\r?\\n|\$)',
      multiLine: true,
    );
    if (begins != 1 || ends != 1 || block.allMatches(text).length != 1) {
      throw const FormatException('Ambiguous Breeze rule block');
    }
    return text.replaceFirstMapped(
      block,
      (match) => transform(match.group(0)!),
    );
  }

  for (final id in ids) {
    body = replaceBlock(
      body,
      _marker(id, true),
      _marker(id, false),
      (_) => '',
      named: true,
    );
  }
  // Old versions used one shared block. Remove only this selection's known
  // hosts from that block; never inject cached rules for unselected plugins.
  final hosts = <String>{};
  for (final id in ids) {
    final source = plan.sources.where((s) => s.id == id).first;
    hosts.addAll(plan.domainsFor(source));
    hosts.addAll((previousDomains[id] ?? []).map(normalizeRoutingDomain));
  }
  body = replaceBlock(body, routingRuleBlockStart, routingRuleBlockEnd, (
    legacy,
  ) {
    return legacy
        .split(newline)
        .where((line) {
          final parts = line.trim().split(',').map((s) => s.trim()).toList();
          return !(parts.length >= 3 &&
              parts[0].toUpperCase() == 'DOMAIN' &&
              hosts.contains(parts[1].toLowerCase()));
        })
        .join(newline);
  });
  final header = original.substring(0, start);
  final separator = header.endsWith('\n') ? '' : newline;
  final result =
      '$header$separator${output.replaceAll('\n', newline)}$newline$body${original.substring(end)}';
  if (result.length > 2 * 1024 * 1024) {
    throw const FormatException('Config too large');
  }
  return result;
}
