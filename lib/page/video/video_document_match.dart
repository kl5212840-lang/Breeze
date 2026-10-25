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
  final wanted = expected.queryParametersAll;
  final received = actual.queryParametersAll;
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
