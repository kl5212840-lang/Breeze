import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';

/// Compatibility for restored callers. New shortcuts open the formal source
/// settings directly and do not push a navigation-only intermediate page.
Future<void> openSourceSettingsHub(
  BuildContext context, {
  required String source,
  List<SourceMenuAction> actions = const [],
}) => openSourceSettings(context, source: source);

@RoutePage(name: 'SourceSettingsHubRoute')
class SourceSettingsHub extends StatelessWidget {
  const SourceSettingsHub({
    super.key,
    this.actions = const [],
    this.source = '',
  });
  final List<SourceMenuAction> actions;
  final String source;
  @override
  Widget build(BuildContext context) => source.isEmpty
      ? const GlobalSettingPage()
      : sourceSettingsDestination(source: source, sourceName: source);
}
