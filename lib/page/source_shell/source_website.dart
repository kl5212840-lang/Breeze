import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

/// Reviewed destinations also cover existing installations whose older plugin
/// builds have no separate website field.
const _reviewedWebsites = <String, String>{
  'e9f18928-3ba8-4d86-a12e-b53a62f47933': 'https://www.picacomic.com/', // 哔咔＋
  '0a0e5858-a467-4702-994a-79e608a4589d': 'https://www.picacomic.com/', // 上游哔咔
  '6886291b-f524-441c-844b-c2efae9899a9': 'https://jmcomicmi.net/', // 禁漫＋
  'bf99008d-010b-4f17-ac7c-61a9b57dc3d9': 'https://jmcomicmi.net/', // 上游禁漫
  'b28da416-f2d4-4208-a85e-8b4c7c648e48': 'https://www.mangacopy.com/',
  '371d33c6-a901-434a-a0ae-d4ea80c7612f': 'https://www.copy4000.com/',
  'ccc2fe17-c0a8-4fd8-a596-835772686404': 'https://www.omofuna.com/',
  'f5387e66-9c58-4b8f-beb7-22a939f79e5d': 'https://www.ikunzy.com/',
  'b27083a4-a643-462a-8204-e6f42c19a5b9': 'https://www.mdzyapi.com/',
  '1e600cff-8ebe-4517-8aa4-6678aec46424': 'https://hanime1.me/',
  '7c3f9a2e-5b1d-4e8a-9c4f-1d2e3f4a5b6c': 'https://toomics.com/',
  'dba2a6cf-c495-4416-accf-c29263ab4016': 'https://e-hentai.org/',
  '1b3c1e94-d9a0-4649-b75f-acd1f18d75e8': 'https://baozimh.org/',
  'babe7021-2df8-4abc-bba8-00bbfd7a0f75': 'https://www.noy.asia/',
  'cafbf766-0231-4f99-ace4-0a26631fff12': 'https://komiic.com/',
  '1f03ebc7-997d-494a-abb5-a06d60094f44': 'https://tw.manhuagui.com/',
  '4471434f-c73a-4dd3-b414-a6a53777d8e0': 'https://manwa.wang/',
  'c8f3a1e2-7b4d-4e9a-8f2c-1d5a7b9e3f6a8': 'https://hitomi.la/',
  'd6f2f13a-b4d0-4f6c-9c6d-8a9f1a2b7c31': 'https://www.jjmhw.cc/',
  '416598d0-84d0-4de9-8ec5-e74816e768f2': 'https://nhentai.net/',
  '7166a5fc-b66c-4146-8c40-0f999b592a0a': 'https://wnacg01.link/',
  '7efa2a7c-da0f-4db1-9167-98045ae37fdb': 'https://www.webtoons.com/',
  '65c18db5-eb13-40d0-9ab4-31f473536aa1': 'https://www.zaimanhua.com/',
  '7d1e0b4f-9c2a-4e8f-a3b6-5f2d8c1e9a47': 'https://korsite.net/',
  '3f8a2c71-5d94-4e6b-b0a3-7c1e9d4f2a68': 'https://mangadex.org/',
  '9c4b7a20-1e83-4d5f-8a6b-3d2c9f1e7b45': 'https://weebcentral.com/',
  'b7d1e0c4-3a52-4f8b-9c61-0e2a5f7d8b90': 'https://www.zerobyw33.com/',
};

/// Never infer a website from a repository, content, account, update endpoint,
/// or the current browser navigation.
Uri? sourceOfficialWebsite(String source) {
  final id = canonicalQjsSource(source);
  return validatedSourceWebsite(_reviewedWebsites[id]) ??
      officialWebsiteFromPluginInfo(
        PluginRegistryService.I.getCachedPluginInfo(id),
      );
}

Uri? officialWebsiteFromPluginInfo(Map<String, dynamic>? info) {
  if (info == null) return null;
  final experience = info['breezeExperience'];
  for (final declaration in [
    info['officialWebsiteUrl'],
    info['websiteUrl'],
    if (experience is Map) experience['officialWebsiteUrl'],
    if (experience is Map) experience['websiteUrl'],
  ]) {
    final website = validatedSourceWebsite(declaration);
    if (website != null) return website;
  }

  return null;
}

Uri? validatedSourceWebsite(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme.toLowerCase()) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      _repositoryHost(uri.host)) {
    return null;
  }
  return uri;
}

bool _repositoryHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  return const {
    'github.com',
    'githubusercontent.com',
    'gitlab.com',
    'gitee.com',
    'bitbucket.org',
    'codeberg.org',
  }.any(
    (repository) =>
        normalized == repository || normalized.endsWith('.$repository'),
  );
}

/// Uses the same system-browser launcher as other external links. This never
/// changes the source's native/web presentation or shares its browser session.
Future<void> openSourceOfficialWebsite(
  BuildContext context,
  Uri website,
) async {
  if (validatedSourceWebsite(website.toString()) == null) return;
  try {
    if (await launchUrl(website, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep the current source intact and use the same failure feedback below.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(t.plugin.cannotOpenLink(url: website.toString()))),
  );
}
