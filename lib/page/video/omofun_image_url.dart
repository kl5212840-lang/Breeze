/// MacCMS exposes both CDN URLs and /upload paths. The latter belong to the
/// image host, even if an older catalog snapshot resolved them on the site.
String omofunImageUrl(String raw) {
  var value = raw.trim();
  if (value.startsWith('mac://')) value = 'https://${value.substring(6)}';
  final url = Uri.tryParse(value);
  if (url == null) return raw;
  final site =
      url.host.isEmpty ||
      const ['www.omofuna.com', 'omofuna.com'].contains(url.host);
  if (site && RegExp(r'^/+upload/').hasMatch(url.path)) {
    return Uri.parse('https://as.cfhls.top/')
        .resolve(
          '${url.path.replaceFirst(RegExp(r'^/+'), '')}${url.hasQuery ? '?${url.query}' : ''}',
        )
        .toString();
  }
  return value;
}
