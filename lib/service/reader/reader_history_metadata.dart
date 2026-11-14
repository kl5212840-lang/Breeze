import 'dart:convert';

String _dimension(Object? type) => switch (type) {
  'tag' => 'tags',
  'categories' => 'category',
  final String value => value,
  _ => '',
};

/// Only a source-declared missing dimension retains its previous value.
/// An explicitly empty successful response remains a real clear operation.
String readerHistoryMetadataForWrite({
  required String incoming,
  required String previous,
  required Iterable<String>? fieldsMissing,
}) {
  if (fieldsMissing == null) return incoming;
  final missing = fieldsMissing
      .map(_dimension)
      .where(const {'tags', 'category', 'author'}.contains)
      .toSet();
  List<dynamic> decode(String value) {
    try {
      final parsed = jsonDecode(value);
      return parsed is List ? parsed : [];
    } catch (_) {
      return [];
    }
  }

  final current = decode(incoming);
  // The existing detail contract explicitly distinguishes absent tags from a
  // successful empty tags response. Keep that distinction in metadata itself.
  if (!missing.contains('tags') &&
      !current.whereType<Map>().any((m) => _dimension(m['type']) == 'tags')) {
    current.add({'type': 'tags', 'name': '', 'value': []});
  }
  final old = decode(previous)
      .whereType<Map>()
      .where((m) => missing.contains(_dimension(m['type'])))
      .toList();
  if (old.isEmpty) return jsonEncode(current);
  final retained = old.map((m) => _dimension(m['type'])).toSet();
  return jsonEncode([
    for (final m in current)
      if (m is! Map || !retained.contains(_dimension(m['type']))) m,
    ...old,
  ]);
}
