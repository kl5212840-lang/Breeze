import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/cache/cache_setting_page.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// Shared by plugin settings and source-specific settings hosts.
class PluginCacheSettingsTile extends StatelessWidget {
  const PluginCacheSettingsTile({
    super.key,
    required this.source,
    this.sourceName,
    this.enabled = true,
  });
  final String source;
  final String? sourceName;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TouchHoverIntent(
    identity: 'plugin.image-cache:$source',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const Icon(Icons.cleaning_services_outlined),
      title: Text(t.cache.title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: !enabled || source.trim().isEmpty
          ? null
          : () => Navigator.of(context).push<void>(
              videoPageRoute<void>(
                settings: const RouteSettings(name: 'SourceImageCacheSettings'),
                builder: (_) =>
                    CacheSettingPage(source: source, sourceName: sourceName),
              ),
            ),
    ),
  );
}
