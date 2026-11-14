import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/network/routing_rules_page.dart';
import 'package:zephyr/page/video/omo_network.dart';

/// Compatibility entry; every maintained source uses the same settings page.
class OmoNetworkSettingsPage extends StatelessWidget {
  const OmoNetworkSettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const RoutingRulesPage(source: omoNetworkSource);
}
