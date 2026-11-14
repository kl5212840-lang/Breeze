import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

/// A source with a permanent settings tab opens that existing tab. Child video
/// modules and profile shortcuts must not push another copy over the shell.
class SourceSettingsShortcutScope extends InheritedWidget {
  const SourceSettingsShortcutScope({
    super.key,
    required this.source,
    required this.open,
    required super.child,
  });
  final String source;
  final Future<void> Function() open;
  static SourceSettingsShortcutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SourceSettingsShortcutScope>();
  @override
  bool updateShouldNotify(SourceSettingsShortcutScope oldWidget) =>
      source != oldWidget.source || open != oldWidget.open;
}

/// Every shortcut resolves the same source-owned settings root. Account
/// capabilities remain the responsibility of the plugin settings schema.
Widget sourceSettingsDestination({
  required String source,
  required String sourceName,
  Map<String, dynamic>? pluginInfo,
}) {
  final info =
      pluginInfo ?? PluginRegistryService.I.getCachedPluginInfo(source);
  if (supportsBikaExperienceDeclaration(source, info)) {
    final sections = SourceShellSection.fromPluginInfo(info!, source);
    if (sections.any((section) => section.sourceSettings)) {
      return SourceShellPage(
        source: source,
        sourceName: sourceName,
        sections: sections,
        initialSectionId: 'bikaSettings',
      );
    }
  }
  return PluginSettingsPage(
    from: source,
    pluginUuid: source,
    pluginRuntimeName: source,
    pluginDisplayName: sourceName,
    insideSource: true,
    scope: PluginSettingsScope.all,
  );
}

Future<void> openSourceSettings(
  BuildContext context, {
  required String source,
  String? sourceName,
  Future<OmoNetworkContext?>? network,
  bool rootNavigator = false,
}) async {
  if (source.isEmpty || !context.mounted) return;
  final tab = SourceSettingsShortcutScope.maybeOf(context);
  if (tab?.source == source) {
    await tab!.open();
    return;
  }
  final info = PluginRegistryService.I.getCachedPluginInfo(source);
  final declaredName = info?['name']?.toString().trim() ?? '';
  final name = declaredName.isNotEmpty ? declaredName : sourceName ?? source;
  final destination = sourceSettingsDestination(
    source: source,
    sourceName: name,
    pluginInfo: info,
  );
  final inherited = VideoNetworkScope.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: rootNavigator);
  final route = videoPageRoute<void>(
    settings: RouteSettings(
      name: destination is SourceShellPage
          ? 'SourceShellRoute'
          : 'PluginSettingsRoute',
    ),
    networkSource: source,
    network:
        network ?? (inherited?.source == source ? inherited?.network : null),
    builder: (_) => destination,
  );
  final completion = navigator.push<void>(route);
  NativeCompositionObserver.observeSharedDestination(context, route);
  await completion;
}
