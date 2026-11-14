import 'package:flutter/foundation.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

class RoutingPluginDiscovery {
  const RoutingPluginDiscovery();

  Stream<void> get changes => PluginRegistryService.I.stream.map((_) {});

  List<RoutingSource> installedSources() => [
    for (final plugin in PluginRegistryService.I.orderedPlugins())
      if (!plugin.isDeleted)
        RoutingSource(
          plugin.uuid,
          PluginRegistryService.I
                  .getCachedPluginInfo(plugin.uuid)?['name']
                  ?.toString() ??
              routingSources
                  .where((s) => s.id == plugin.uuid)
                  .firstOrNull
                  ?.name ??
              plugin.uuid,
          const [],
        ),
  ];

  bool isInstalled(String id) =>
      PluginRegistryService.I.getByUuid(id)?.isDeleted == false;

  Future<RoutingSource> scanInstalled(RoutingSource source) async {
    final plugin = PluginRegistryService.I.getByUuid(source.id);
    if (plugin == null || plugin.isDeleted || plugin.originScript.isEmpty) {
      throw const FormatException('Plugin file unavailable');
    }
    final script = plugin.originScript;
    final domains = await compute(scanRoutingDomains, script);
    final latest = PluginRegistryService.I.getByUuid(source.id);
    if (latest == null || latest.isDeleted || latest.originScript != script) {
      throw const FormatException('Plugin changed during extraction');
    }
    final declared = routingDeclaredSiteDomains(
      PluginRegistryService.I.getCachedPluginInfo(source.id)?['routing'],
    );
    return RoutingSource(
      source.id,
      source.name,
      {...domains, ...declared}.toList()..sort(),
    );
  }

  Future<RoutingSource> scanFile(String script, String name) =>
      compute(_scanFile, [script, name]);
}

RoutingSource _scanFile(List<String> input) =>
    scanRoutingPluginFile(input[0], input[1]);
