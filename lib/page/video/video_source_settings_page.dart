import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/video/omo_network.dart';

// Kept for callers restoring an older route. It resolves the same canonical
// plugin settings widget rather than creating a second source settings root.
const videoSourceSettingsRouteName = 'breeze.video.source-settings';
Future<void> openVideoSourceSettings(
  BuildContext context, {
  required String source,
  required String sourceName,
  required Future<void> Function() onSourcePreferences,
  Future<OmoNetworkContext?>? network,
  Future<void> Function()? onToggleBrowserInspection,
  bool Function()? browserInspectionEnabled,
}) => openSourceSettings(
  context,
  source: source,
  sourceName: sourceName,
  network: network,
);

class VideoSourceSettingsPage extends StatelessWidget {
  const VideoSourceSettingsPage({
    super.key,
    required this.source,
    required this.sourceName,
    required this.onSourcePreferences,
    this.onToggleBrowserInspection,
    this.browserInspectionEnabled,
  });
  final String source, sourceName;
  final Future<void> Function() onSourcePreferences;
  final Future<void> Function()? onToggleBrowserInspection;
  final bool Function()? browserInspectionEnabled;
  @override
  Widget build(BuildContext context) =>
      sourceSettingsDestination(source: source, sourceName: sourceName);
}
