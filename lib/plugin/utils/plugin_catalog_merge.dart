import 'dart:convert';

/// Keep the official catalog intact and show independent entries first.
/// An unavailable or malformed extra catalog must not affect the official one.
String mergeCloudPluginCatalogPayloads(
  String officialPayload,
  String? extraPayload,
) {
  if (extraPayload == null || extraPayload.trim().isEmpty) {
    return officialPayload;
  }

  final List<dynamic> official;
  try {
    official = jsonDecode(officialPayload) as List<dynamic>;
  } catch (_) {
    return officialPayload;
  }

  final List<dynamic> extra;
  try {
    extra = jsonDecode(extraPayload) as List<dynamic>;
  } catch (_) {
    return officialPayload;
  }

  String uuidOf(Object? entry) {
    if (entry is! Map) return '';
    final manifest = entry['manifest'];
    if (manifest is! Map) return '';
    return manifest['uuid']?.toString().trim() ?? '';
  }

  final uuids = official.map(uuidOf).where((uuid) => uuid.isNotEmpty).toSet();
  final independent = <dynamic>[];
  for (final entry in extra) {
    final uuid = uuidOf(entry);
    if (uuid.isEmpty || !uuids.add(uuid)) continue;
    independent.add(entry);
  }
  return jsonEncode(<dynamic>[...independent, ...official]);
}
