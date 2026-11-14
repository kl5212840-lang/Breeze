import 'dart:convert';

/// Parse only public shared-metadata dimensions; arbitrary map keys are never indexed.
Map<String, Set<String>> shelfFacetFieldsFromMetadata(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return {};
  }
  if (decoded is! List) return {};
  const dimensions = {
    'tag': 'tags',
    'tags': 'tags',
    'category': 'category',
    'categories': 'category',
    'author': 'author',
    'year': 'year',
    'area': 'area',
    'language': 'language',
  };
  final fields = <String, Set<String>>{};
  for (final row in decoded) {
    if (row is! Map || row['type'] is! String) continue;
    final dimension = dimensions[(row['type'] as String).trim().toLowerCase()];
    if (dimension == null) continue;
    final rawValues = row['value'] is List
        ? row['value'] as List
        : [row['value']];
    for (final rawValue in rawValues) {
      final value = rawValue is Map ? rawValue['name'] : rawValue;
      if (value is! String && value is! num) continue;
      final label = value.toString().trim();
      if (label.isNotEmpty) {
        fields.putIfAbsent(dimension, () => <String>{}).add(label);
      }
    }
  }
  return fields;
}
