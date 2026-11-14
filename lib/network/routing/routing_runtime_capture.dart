import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/src/rust/api/qjs.dart';

/// Drain the actual, already-running plugin VM before its owner releases it.
/// Failure in optional routing discovery must never change the business call.
Future<void> collectRoutingRuntimeDomains({
  required String source,
  required String runtime,
}) async {
  try {
    final hosts = await qjsDrainObservedHttpDomains(
      runtimeName: runtime,
    ).timeout(const Duration(seconds: 1));
    if (hosts.isNotEmpty) {
      await RoutingObservedMediaDomains.observeHosts(source, hosts);
    }
  } catch (_) {
    // Tests without a native bridge, retired VMs and unavailable storage are
    // not network failures of the plugin operation that just completed.
  }
}
