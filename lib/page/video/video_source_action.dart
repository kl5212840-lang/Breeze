/// Enumerate declared video modules without guessing from names or UUIDs.
List<Map<String, dynamic>> videoSourceActions(Object? value, {int depth = 0}) {
  if (depth > 10) return const [];
  if (value is Map) {
    if (const {
          'openVideoLibrary',
          'openVideoCatalog',
        }.contains(value['type']) &&
        value['payload'] is Map) {
      return [Map<String, dynamic>.from(value)];
    }
    return [
      for (final child in value.values)
        ...videoSourceActions(child, depth: depth + 1),
    ];
  }
  if (value is List) {
    return [
      for (final child in value) ...videoSourceActions(child, depth: depth + 1),
    ];
  }
  return const [];
}

/// Omitting [home] preserves the first-module contract for older callers.
/// With a home, never reopen an unrelated module as a fallback.
Map<String, dynamic>? videoSourceAction(
  Object? value, {
  Uri? home,
  String? itemId,
  int depth = 0,
}) {
  final matches = videoSourceActions(value, depth: depth).where((action) {
    if (home == null) return true;
    final raw = (action['payload'] as Map)['url'];
    final uri = raw is String ? Uri.tryParse(raw) : null;
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.origin == home.origin;
  }).toList();
  if (itemId == null) return matches.firstOrNull;
  String namespace(Map<String, dynamic> action) {
    final caps = (action['payload'] as Map)['capabilities'];
    return caps is Map ? '${caps['itemNamespace'] ?? ''}' : '';
  }

  final explicit =
      matches.where((action) {
          final prefix = namespace(action);
          return prefix.isNotEmpty && itemId.startsWith('$prefix:');
        }).toList()
        ..sort((a, b) => namespace(b).length.compareTo(namespace(a).length));
  if (explicit.isNotEmpty) return explicit.first;
  return matches
      .firstOrNull; // Legacy callers without an explicit module keep their existing route.
}

/// A hybrid comic plugin may expose video modules as secondary entrances.
Map<String, dynamic>? aggregateVideoSourceAction(Object? info) {
  if (info is Map) {
    final experience = info['breezeExperience'];
    if (experience is Map && experience['aggregateMedia'] == 'comic') {
      return null;
    }
  }
  return videoSourceAction(info);
}
