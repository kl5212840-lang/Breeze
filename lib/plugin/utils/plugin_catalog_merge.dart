import 'dart:convert';

import 'package:zephyr/plugin/utils/plugin_version_utils.dart';

/// Only these explicitly managed forks may replace a matching official UUID.
const managedPluginUuids = <String>{
  'e9f18928-3ba8-4d86-a12e-b53a62f47933',
  '6886291b-f524-441c-844b-c2efae9899a9',
  'b28da416-f2d4-4208-a85e-8b4c7c648e48',
  'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
  '1e600cff-8ebe-4517-8aa4-6678aec46424',
};

List<dynamic>? decodeCloudPluginCatalog(String? payload) {
  try {
    final decoded = jsonDecode(payload ?? '');
    if (decoded is! List || decoded.isEmpty) return null;
    if (!decoded.every((entry) => cloudPluginUuid(entry).isNotEmpty)) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

String cloudPluginUuid(Object? entry) {
  if (entry is! Map || entry['manifest'] is! Map) return '';
  return entry['manifest']['uuid']?.toString().trim() ?? '';
}

/// Independent source failures must never discard another usable catalog.
String mergeCloudPluginCatalogPayloads(
  String officialPayload,
  String? extraPayload,
) {
  final official = decodeCloudPluginCatalog(officialPayload);
  final extra = decodeCloudPluginCatalog(extraPayload);
  if (extra == null) return officialPayload;
  if (official == null) return jsonEncode(extra);

  final originals = {
    for (final entry in official) cloudPluginUuid(entry): entry,
  };
  final seen = <String>{};
  final independent = <dynamic>[];
  for (final entry in extra) {
    final uuid = cloudPluginUuid(entry);
    if (!seen.add(uuid)) continue;
    final original = originals[uuid];
    if (original != null) {
      if (!managedPluginUuids.contains(uuid)) continue;
      final oldVersion = original['manifest']['version']?.toString() ?? '';
      final newVersion = entry['manifest']['version']?.toString() ?? '';
      final sameChannel = original['repo'] == entry['repo'];
      independent.add(
        sameChannel && compareVersion(oldVersion, newVersion) > 0
            ? original
            : entry,
      );
    } else {
      independent.add(entry);
    }
  }
  final overridden = independent.map(cloudPluginUuid).toSet();
  return jsonEncode(<dynamic>[
    ...independent,
    ...official.where((entry) => !overridden.contains(cloudPluginUuid(entry))),
  ]);
}

/// Both requests start together. Invalid HTML/JSON and timeouts are source-local.
Future<String> loadCloudPluginCatalog({
  required Future<String?> Function() official,
  required Future<String?> Function() personal,
  required String fallback,
  Duration timeout = const Duration(seconds: 12),
}) async {
  Future<String?> read(Future<String?> Function() request) async {
    try {
      final value = await request().timeout(timeout);
      return decodeCloudPluginCatalog(value) == null ? null : value;
    } catch (_) {
      return null;
    }
  }

  final results = await Future.wait([read(official), read(personal)]);
  if (results.every((value) => value == null)) {
    throw StateError('插件目录暂不可用，已保留可用目录');
  }
  final savedPersonal = jsonEncode(
    (decodeCloudPluginCatalog(fallback) ?? [])
        .where((entry) => managedPluginUuids.contains(cloudPluginUuid(entry)))
        .toList(),
  );
  final refreshed = mergeCloudPluginCatalogPayloads(
    results[0] ?? fallback,
    savedPersonal,
  );
  return mergeCloudPluginCatalogPayloads(refreshed, results[1]);
}
