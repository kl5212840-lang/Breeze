/// Registration is an external website action, never a plugin API call.
/// Reject anything that could expose credentials to an insecure scheme.
Uri? validatedRegistrationUri(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
