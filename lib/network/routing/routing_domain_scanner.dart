import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';

/// Reads literal addresses only: no plugin execution, site requests, DNS lookup,
/// or account/configuration access. Playback observations are merged separately.
RoutingSource scanRoutingPluginFile(String script, String fileName) {
  if (utf8.encode(script).length > 4 * 1024 * 1024 ||
      script.contains('\u0000') ||
      !RegExp(r'\b(?:exports|module)\b').hasMatch(script)) {
    throw const FormatException('Invalid plugin file');
  }
  final ids = RegExp(
    r'''["']?(?:uuid|id)["']?\s*:\s*["']([a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12})["']''',
  ).allMatches(script).map((m) => m.group(1)!.toLowerCase()).toSet();
  final id = ids.length == 1
      ? ids.single
      : 'file:${sha256.convert(utf8.encode(script))}';
  final reviewed = routingSources.where((s) => s.id == id);
  final name = reviewed.isNotEmpty
      ? reviewed.first.name
      : fileName
            .replaceAll(RegExp(r'\.(cjs|js)$', caseSensitive: false), '')
            .trim();
  return RoutingSource(
    id,
    (name.isEmpty ? 'Plugin' : name).substring(
      0,
      (name.isEmpty ? 'Plugin' : name).length.clamp(0, 120),
    ),
    scanRoutingDomains(script),
    fromFile: true,
  );
}

List<String> scanRoutingDomains(String script) {
  if (script.length > 4 * 1024 * 1024) {
    throw const FormatException('Plugin too large');
  }
  final decoded = script
      .replaceAll(r'\/', '/')
      .replaceAll(r'\u002f', '/')
      .replaceAll(r'\u002F', '/');
  final hosts = <String>{};
  void add(String candidate) {
    try {
      final host = normalizeRoutingDomain(candidate);
      if (isRoutingContentDomain(host)) hosts.add(host);
    } on FormatException {
      // Dynamic hosts, IPs, local addresses and non-domain values are omitted.
    }
  }

  for (final match in RegExp(
    r'''https?://[^\s"'`<>\\]+''',
    caseSensitive: false,
  ).allMatches(decoded)) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri != null && uri.userInfo.isEmpty) add(uri.host);
  }
  for (final match in RegExp(
    r'''\b(?:host|domain|apiHost|imageHost|mediaHost)["']?\s*[:=]\s*["']([a-zA-Z0-9.-]+)["']''',
    caseSensitive: false,
  ).allMatches(decoded)) {
    add(match.group(1)!);
  }
  if (hosts.length > 200) throw const FormatException('Too many hosts');
  return hosts.toList()..sort();
}

/// Literal extraction is only a candidate, never proof of a live business host.
/// In particular dependency feature checks use reserved names such as .invalid.
bool isRoutingContentDomain(String value) {
  try {
    final host = normalizeRoutingDomain(value);
    return !_infrastructure(host) &&
        !const [
          'invalid',
          'test',
          'example',
          'localhost',
          'local',
        ].any((suffix) => host == suffix || host.endsWith('.$suffix'));
  } on FormatException {
    return false;
  }
}

bool _infrastructure(String host) => const [
  'example.com',
  'example.net',
  'example.org',
  'localhost',
  'github.com',
  'github.io',
  'githubusercontent.com',
  'jsdelivr.net',
  'unpkg.com',
  'cdnjs.com',
  'w3.org',
  'googletagmanager.com',
  'google-analytics.com',
  'googlesyndication.com',
  'sentry.io',
  'flutter.dev',
  'developer.mozilla.org',
].any((domain) => host == domain || host.endsWith('.$domain'));

/// Declarative site origins complement literal extraction; runtime media hosts
/// come only from the validated playback pipeline, never suffix declarations.
List<String> routingDeclaredSiteDomains(Object? metadata) {
  if (metadata is! Map ||
      metadata['version'] != 1 ||
      metadata['siteOrigins'] is! List)
    return const [];
  final hosts = <String>{};
  for (final raw in (metadata['siteOrigins'] as List).take(16)) {
    if (raw is! String) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/'))
      continue;
    if (isRoutingContentDomain(uri.host))
      hosts.add(normalizeRoutingDomain(uri.host));
  }
  return hosts.toList()..sort();
}
