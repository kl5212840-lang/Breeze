import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

/// Only plugin metadata may supply a website. Never infer one from the current
/// content, account, update endpoint, or browser navigation.
Uri? sourceOfficialWebsite(String source) => officialWebsiteFromPluginInfo(
  PluginRegistryService.I.getCachedPluginInfo(source.trim()),
);

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

  // Older plugins use `home` both for the site and for the plugin repository.
  // A repository/update host is not a declared official content website.
  final home = validatedSourceWebsite(info['home']);
  if (home == null || _repositoryHost(home.host)) return null;
  return home;
}

Uri? validatedSourceWebsite(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme.toLowerCase()) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

bool _repositoryHost(String host) {
  final normalized = host.toLowerCase();
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
