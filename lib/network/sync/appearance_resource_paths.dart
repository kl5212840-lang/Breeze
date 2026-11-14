final appearanceManifestName = RegExp(
  r'^appearance_[a-f0-9]{32}(?:_[a-f0-9]{64})?\.bin$',
);
final appearanceResourceName = RegExp(
  r'^appearance_resource_[a-f0-9]{64}\.bin$',
);
bool isAppearanceResourcePath(String path) =>
    appearanceResourceName.hasMatch(path.split('/').last);

String? appearanceManifestDigest(String path) {
  final name = path.split('/').last;
  if (!appearanceManifestName.hasMatch(name)) return null;
  final parts = name.substring(0, name.length - 4).split('_');
  return parts.length == 3 ? parts.last : null;
}
