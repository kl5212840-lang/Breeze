import 'package:zephyr/service/plugin_account_identity.dart';

/// Converts only a fresh same-site identity response, never a stored profile.
PluginAccountAuthentication? videoSiteVerifiedIdentity(
  Map<String, dynamic> value,
  Uri home, {
  Map<String, dynamic> ownProfile = const {},
}) {
  if (value['status'] == 'signedOut') {
    throw const PluginAccountAuthenticationRejected();
  }
  final id = value['id']?.toString() ?? '';
  if (home.scheme != 'https' ||
      home.host.isEmpty ||
      home.userInfo.isNotEmpty ||
      !RegExp(r'^\d+$').hasMatch(id)) {
    return null;
  }
  final rawAvatar = ownProfile['avatarUrl']?.toString().trim() ?? '';
  final requestAvatar = rawAvatar.isNotEmpty
      ? rawAvatar
      : value['avatarUrl']?.toString().trim() ?? '';
  final avatar = Uri.tryParse(requestAvatar);
  final profileName = ownProfile['name']?.toString().trim() ?? '';
  return PluginAccountAuthentication(
    serverIdentity: id,
    origin: home.origin,
    label: profileName.isNotEmpty
        ? profileName
        : value['label']?.toString().trim() ?? '',
    avatarUrl:
        avatar != null &&
            avatar.scheme == 'https' &&
            avatar.userInfo.isEmpty &&
            !avatar.hasFragment
        ? requestAvatar
        : '',
  );
}
