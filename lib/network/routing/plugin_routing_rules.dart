import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export intentions only. These values never change a request's transport or
/// claim to bypass the device's VPN. The external proxy client applies rules.
enum PluginRoute { existing, direct, proxy }

const routingRuleBlockStart = '# BEGIN BREEZE NETWORK RULES v1';
const routingRuleBlockEnd = '# END BREEZE NETWORK RULES v1';

class RoutingSource {
  const RoutingSource(
    this.id,
    this.name,
    this.domains, {
    this.fromFile = false,
  });
  final String id, name;
  final List<String> domains;
  final bool fromFile;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'domains': domains,
    'fromFile': fromFile,
  };

  static RoutingSource fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (id.isEmpty ||
        id.length > 100 ||
        name.trim().isEmpty ||
        name.length > 120) {
      throw const FormatException('Invalid routing source');
    }
    final domains = (json['domains'] as List).cast<String>();
    if (domains.length > 200) throw const FormatException('Too many domains');
    return RoutingSource(
      id,
      name,
      domains.map(normalizeRoutingDomain).toSet().toList(),
      fromFile: json['fromFile'] == true,
    );
  }
}

/// Exact hosts from maintained source configs and the public API inventory.
/// No parent suffixes, shared developer CDNs, ads, or analytics are included.
/// This is a reviewed starting set, not an exhaustive live CDN inventory.
const routingSources = [
  RoutingSource('ccc2fe17-c0a8-4fd8-a596-835772686404', 'OmoFun 动漫', [
    'www.omofuna.com',
    'as.cfhls.top',
    's6.cfhls.top',
    'vip.dytt-tvs.com',
    'vip.dytt-cinema.com',
    'v.baofeng9.com',
    'art.v2player.top',
    'art2.v2player.top',
    'danmu.v2player.top',
    'm3u8.web.sgzm.net',
  ]),
  RoutingSource('e9f18928-3ba8-4d86-a12e-b53a62f47933', '哔咔漫画+', [
    'picaapi.picacomic.com',
    'picaapi.go2778.com',
    'storage1.picacomic.com',
    'storage-b.picacomic.com',
    'img.picacomic.com',
    's3.picacomic.com',
    'storage.diwodiwo.xyz',
    'storage-b.diwodiwo.xyz',
  ]),
  RoutingSource('6886291b-f524-441c-844b-c2efae9899a9', '禁漫天堂+', [
    'www.cdnhjk.net',
    'cdn-msp3.jmdanjonproxy.vip',
    'cdn-msp.jmapiproxy1.cc',
    'cdn-msp.jmapiproxy2.cc',
    'cdn-msp2.jmapiproxy2.cc',
    'cdn-msp3.jmapiproxy2.cc',
    'cdn-msp.jmapinodeudzn.net',
    'cdn-msp3.jmapinodeudzn.net',
  ]),
  RoutingSource('1e600cff-8ebe-4517-8aa4-6678aec46424', 'Hanime1', [
    'hanime1.me',
  ]),
  RoutingSource('b28da416-f2d4-4208-a85e-8b4c7c648e48', '拷贝漫画', [
    'www.mangacopy.com',
    'api.mangacopy.com',
    'api.copy2000.online',
    'api.copy3000.com',
    'mapi.copy20.com',
    'mapi.copy2000.site',
    'api.2025copy.com',
    'api.2026copy.com',
    '2026copy.com',
    'mapi.hotmangasd.com',
    'api.manga2025.com',
    'mapi.hotmangasf.com',
    'mapi.hotmangasg.com',
    'mapi.elfgjfghkk.club',
    'mapi.fgjfghkk.club',
    'mapi.fgjfghkkcenter.club',
  ]),
  RoutingSource('b27083a4-a643-462a-8204-e6f42c19a5b9', '魔都资源', [
    'www.mdzyapi.com',
    'moduzy.vip',
    'moduzy1.com',
    'www.modujiexi66.com',
  ]),
  RoutingSource('f5387e66-9c58-4b8f-beb7-22a939f79e5d', 'iKun 资源', [
    'www.ikunzy.com',
    'ikunzyapi.com',
    'bfikuncdn.com',
    'kkzycdn.com',
  ]),
];

String normalizeRoutingDomain(String value) {
  final host = value.trim().toLowerCase();
  final labels = host.split('.');
  if (host.length > 253 ||
      labels.length < 2 ||
      !RegExp(r'^[a-z]{2,63}$|^xn--[a-z0-9-]+$').hasMatch(labels.last) ||
      labels.any(
        (label) =>
            label.length > 63 ||
            !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
      ) ||
      host.endsWith('.local') ||
      host.endsWith('.localhost')) {
    throw const FormatException('Invalid public domain');
  }
  return host;
}

class RoutingPlan {
  RoutingPlan({
    Map<String, PluginRoute>? choices,
    Map<String, List<String>>? extraDomains,
    Map<String, RoutingSource>? customSources,
    Map<String, List<String>>? scannedDomains,
    Map<String, List<String>>? confirmedDomains,
  }) : choices = Map.unmodifiable(choices ?? {}),
       customSources = Map.unmodifiable(customSources ?? {}),
       scannedDomains = Map.unmodifiable({
         for (final entry
             in (scannedDomains ?? <String, List<String>>{}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       confirmedDomains = Map.unmodifiable({
         for (final entry
             in (confirmedDomains ?? <String, List<String>>{}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       extraDomains = Map.unmodifiable({
         for (final entry in (extraDomains ?? <String, List<String>>{}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });
  final Map<String, PluginRoute> choices;
  final Map<String, List<String>> extraDomains;
  final Map<String, RoutingSource> customSources;
  final Map<String, List<String>> scannedDomains;
  final Map<String, List<String>> confirmedDomains;

  List<RoutingSource> get sources => [
    for (final base in routingSources)
      RoutingSource(
        base.id,
        customSources[base.id]?.name ?? base.name,
        {...base.domains, ...?customSources[base.id]?.domains}.toList()..sort(),
      ),
    ...customSources.values.where(
      (s) => !routingSources.any((base) => base.id == s.id),
    ),
  ];

  RoutingPlan withAvailableSources(Iterable<RoutingSource> available) =>
      RoutingPlan(
        choices: choices,
        extraDomains: extraDomains,
        scannedDomains: scannedDomains,
        confirmedDomains: confirmedDomains,
        customSources: {
          ...customSources,
          for (final source in available)
            if (!routingSources.any((base) => base.id == source.id))
              source.id: RoutingSource(
                source.id,
                source.name,
                customSources[source.id]?.domains ?? source.domains,
                fromFile: customSources[source.id]?.fromFile ?? false,
              ),
        },
      );

  /// A scan replaces only previously scanned hosts. Reviewed and manual hosts
  /// remain intact; callers validate conflicts before saving the draft.
  RoutingPlan withScannedSource(RoutingSource source) => RoutingPlan(
    choices: choices,
    extraDomains: extraDomains,
    customSources: {
      ...customSources,
      if (source.fromFile ||
          !routingSources.any((base) => base.id == source.id))
        source.id: RoutingSource(
          source.id,
          source.name,
          const [],
          fromFile:
              source.fromFile || (customSources[source.id]?.fromFile ?? false),
        ),
    },
    scannedDomains: {...scannedDomains, source.id: source.domains},
    confirmedDomains: confirmedDomains,
  );

  RoutingPlan withoutSource(String id) => RoutingPlan(
    choices: {...choices}..remove(id),
    extraDomains: {...extraDomains}..remove(id),
    scannedDomains: {...scannedDomains}..remove(id),
    confirmedDomains: {...confirmedDomains}..remove(id),
    customSources: {...customSources}..remove(id),
  );

  List<String> candidatesFor(RoutingSource source) =>
      {...?scannedDomains[source.id]}.difference({
        ...source.domains,
        ...?customSources[source.id]?.domains,
        ...?extraDomains[source.id],
      }).toList()..sort();

  List<String> pendingFor(RoutingSource source) => candidatesFor(source)
      .where(
        (host) => !(confirmedDomains[source.id] ?? const []).contains(host),
      )
      .toList();

  RoutingPlan withConfirmedDomain(
    String source,
    String domain,
    bool confirmed,
  ) {
    final host = normalizeRoutingDomain(domain);
    if (!(scannedDomains[source] ?? const []).contains(host)) {
      throw const FormatException('Domain is no longer in this extraction');
    }
    final hosts = {...?confirmedDomains[source]};
    if (confirmed) {
      hosts.add(host);
    } else {
      hosts.remove(host);
    }
    return RoutingPlan(
      choices: choices,
      extraDomains: extraDomains,
      customSources: customSources,
      scannedDomains: scannedDomains,
      confirmedDomains: {...confirmedDomains, source: hosts.toList()..sort()},
    );
  }

  List<String> domainsFor(RoutingSource source) => {
    ...source.domains,
    ...?customSources[source.id]?.domains,
    for (final host in scannedDomains[source.id] ?? const <String>[])
      if ((confirmedDomains[source.id] ?? const []).contains(host)) host,
    ...?extraDomains[source.id],
  }.map(normalizeRoutingDomain).toList()..sort();

  Map<String, PluginRoute> get rules {
    final result = <String, PluginRoute>{};
    for (final source in sources) {
      final route = choices[source.id] ?? PluginRoute.existing;
      if (route == PluginRoute.existing) continue;
      for (final host in domainsFor(source)) {
        if (result.containsKey(host) && result[host] != route) {
          throw RoutingConflict(host);
        }
        result[host] = route;
      }
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String get shadowrocketRules => rules.entries
      .map(
        (entry) =>
            'DOMAIN,${entry.key},${entry.value == PluginRoute.direct ? 'DIRECT' : 'PROXY'}',
      )
      .join('\n');

  /// A replaceable block for the existing [Rule] section, not a full profile.
  /// Empty plans deliberately retain markers so the previous block can be
  /// replaced without retaining stale routes.
  String get shadowrocketRuleBlock => [
    routingRuleBlockStart,
    if (rules.isNotEmpty) shadowrocketRules,
    routingRuleBlockEnd,
  ].join('\n');

  String get fingerprint =>
      sha256.convert(utf8.encode(shadowrocketRules)).toString();

  RoutingPlan withSource(
    String source,
    PluginRoute route,
    List<String> extra,
  ) => RoutingPlan(
    choices: {...choices, source: route},
    extraDomains: {...extraDomains, source: extra},
    customSources: customSources,
    scannedDomains: scannedDomains,
    confirmedDomains: confirmedDomains,
  );

  /// Keep the exported scope identical to the selection shown for review.
  RoutingPlan onlySources(Set<String> sources) => RoutingPlan(
    choices: {
      for (final entry in choices.entries)
        if (sources.contains(entry.key)) entry.key: entry.value,
    },
    extraDomains: extraDomains,
    customSources: customSources,
    scannedDomains: scannedDomains,
    confirmedDomains: confirmedDomains,
  );

  Map<String, dynamic> toJson() => {
    'choices': choices.map((key, value) => MapEntry(key, value.name)),
    'extraDomains': extraDomains,
    'customSources': customSources.values.map((s) => s.toJson()).toList(),
    'scannedDomains': scannedDomains,
    'confirmedDomains': confirmedDomains,
  };

  static RoutingPlan fromJson(Map<String, dynamic> json) {
    final custom = <String, RoutingSource>{};
    final storedSources = json['customSources'] as List? ?? [];
    if (storedSources.length > 100) {
      throw const FormatException('Too many sources');
    }
    for (final value in storedSources) {
      final source = RoutingSource.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      custom[source.id] = source;
    }
    final ids = {...routingSources.map((source) => source.id), ...custom.keys};
    final choices = <String, PluginRoute>{};
    for (final entry in (json['choices'] as Map? ?? {}).entries) {
      if (ids.contains(entry.key)) {
        choices[entry.key as String] = PluginRoute.values.byName(
          entry.value as String,
        );
      }
    }
    final extra = <String, List<String>>{};
    for (final entry in (json['extraDomains'] as Map? ?? {}).entries) {
      if (ids.contains(entry.key)) {
        final hosts = (entry.value as List).cast<String>();
        if (hosts.length > 100) throw const FormatException('Too many domains');
        extra[entry.key as String] = hosts
            .map(normalizeRoutingDomain)
            .toSet()
            .toList();
      }
    }
    final scanned = <String, List<String>>{};
    for (final entry in (json['scannedDomains'] as Map? ?? {}).entries) {
      if (!ids.contains(entry.key)) continue;
      final hosts = (entry.value as List).cast<String>();
      if (hosts.length > 200) throw const FormatException('Too many domains');
      scanned[entry.key as String] = hosts
          .map(normalizeRoutingDomain)
          .toSet()
          .toList();
    }
    final confirmed = <String, List<String>>{};
    for (final entry in (json['confirmedDomains'] as Map? ?? {}).entries) {
      if (!ids.contains(entry.key)) continue;
      final hosts = (entry.value as List).cast<String>();
      if (hosts.length > 200) throw const FormatException('Too many domains');
      confirmed[entry.key as String] = hosts
          .map(normalizeRoutingDomain)
          .where((host) => (scanned[entry.key] ?? const []).contains(host))
          .toSet()
          .toList();
    }
    return RoutingPlan(
      choices: choices,
      extraDomains: extra,
      customSources: custom,
      scannedDomains: scanned,
      confirmedDomains: confirmed,
    );
  }
}

class RoutingConflict implements Exception {
  RoutingConflict(this.domain);
  final String domain;
}

/// Preserves the original file's other rules, groups, servers and newline style.
/// A single owned block is replaced idempotently, ahead of pre-existing rules.
/// The input is never saved, logged or modified on disk.
String mergeShadowrocketConfig(String original, RoutingPlan plan) {
  const begin = routingRuleBlockStart;
  const end = routingRuleBlockEnd;
  if (original.length > 2 * 1024 * 1024 || original.contains('\u0000')) {
    throw const FormatException('Invalid config');
  }
  final newline = original.contains('\r\n') ? '\r\n' : '\n';
  final section = RegExp(
    r'^(?:\uFEFF)?[ \t]*\[Rule\][ \t]*(?:\r?\n|$)',
    multiLine: true,
    caseSensitive: false,
  );
  final matches = section.allMatches(original).toList();
  if (matches.length != 1) {
    throw const FormatException('Expected one Rule section');
  }
  final start = matches.single.end;
  final next = RegExp(
    r'^[ \t]*\[[^\]\r\n]+\]',
    multiLine: true,
  ).firstMatch(original.substring(start));
  final stop = next == null ? original.length : start + next.start;
  var body = original.substring(start, stop);
  if (body.contains(begin) || body.contains(end)) {
    final owned = RegExp(
      '^${RegExp.escape(begin)}\\r?\\n[\\s\\S]*?^${RegExp.escape(end)}(?:\\r?\\n|\$)',
      multiLine: true,
    );
    if (owned.allMatches(body).length != 1 ||
        begin.allMatches(body).length != 1 ||
        end.allMatches(body).length != 1) {
      throw const FormatException('Invalid owned rule block');
    }
    body = body.replaceFirst(owned, '');
  }
  final rules = plan.shadowrocketRules;
  final block = rules.isEmpty
      ? ''
      : '$begin$newline${rules.replaceAll('\n', newline)}$newline$end$newline';
  final header = original.substring(0, start);
  final delimiter = header.endsWith('\n') ? '' : newline;
  return '$header$delimiter$block$body${original.substring(stop)}';
}

abstract final class RoutingPlanStore {
  static const _key = 'breeze.routing.export.v1';
  static const _exportKey = 'breeze.routing.exported.v1';
  static Future<RoutingPlan> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return RoutingPlan();
    return RoutingPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save(RoutingPlan plan) async {
    // Validate before storage, including shared-host conflicts.
    plan.rules;
    if (!await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(plan.toJson()),
    )) {
      throw StateError('Could not save routing plan');
    }
  }

  static Future<String?> lastExport() async =>
      (await SharedPreferences.getInstance()).getString(_exportKey);
  static Future<void> recordExport(RoutingPlan plan) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _exportKey,
      plan.fingerprint,
    )) {
      throw StateError('Could not save export status');
    }
  }
}
