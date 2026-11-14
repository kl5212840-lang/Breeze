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
  final rawAvatar = ownProfile['avatarUrl']?.toString() ?? '';
  final avatar = Uri.tryParse(rawAvatar);
  return PluginAccountAuthentication(
    serverIdentity: id,
    origin: home.origin,
    label: ownProfile['name']?.toString() ?? value['label']?.toString() ?? '',
    avatarUrl:
        avatar != null &&
            avatar.scheme == 'https' &&
            avatar.userInfo.isEmpty &&
            !avatar.hasFragment
        ? rawAvatar
        : '',
  );
}
