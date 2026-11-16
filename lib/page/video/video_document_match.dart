/// WebView callbacks may arrive after another tab has been requested. Only a
/// completion for the current document may update the native presentation.
bool videoDocumentMatches(Uri? expected, Uri? actual) {
  if (expected == null || actual == null) return false;
  if (expected.scheme != 'https' ||
      actual.scheme != 'https' ||
      expected.host.isEmpty ||
      actual.host.isEmpty) {
    return false;
  }
  if (expected.origin != actual.origin || expected.path != actual.path) {
    return false;
  }
  final hanimeSearch =
      expected.host == 'hanime1.me' && expected.path == '/search';
  final wanted = hanimeSearch
      ? _hanimeSearchQuery(expected)
      : expected.queryParametersAll;
  final received = hanimeSearch
      ? _hanimeSearchQuery(actual)
      : actual.queryParametersAll;
  if (wanted.length != received.length) return false;
  for (final entry in wanted.entries) {
    final values = received[entry.key];
    if (values == null || values.length != entry.value.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != entry.value[i]) return false;
    }
  }
  return true;
}

// Hanime's form uses repeated tags[] and its published page links can use
// indexed tags. Only normalize this field. All other criteria must still match.
Map<String, List<String>> _hanimeSearchQuery(Uri uri) {
  final query = uri.queryParametersAll;
  final indexed = query.keys
      .where((key) => RegExp(r'^tags\[[0-9]+\]$').hasMatch(key))
      .toList();
  final repeated = query['tags[]'];
  if (repeated != null && indexed.isNotEmpty) return query;
  if (repeated == null && indexed.isEmpty) return query;
  return {
    for (final entry in query.entries)
      if (!indexed.contains(entry.key) && entry.key != 'tags[]')
        entry.key: entry.value,
    'tags[]': [...?repeated, for (final key in indexed) ...query[key]!]..sort(),
  };
}
