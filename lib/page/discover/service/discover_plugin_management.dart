import 'package:zephyr/page/discover/service/discover_plugin_visibility.dart';

class DiscoverPluginManagementDraft {
  DiscoverPluginManagementDraft({
    required Iterable<String> order,
    required Iterable<String> hiddenIds,
    this.restoreDefaultOrder = false,
  }) : order = List.unmodifiable(order),
       hiddenIds = Set.unmodifiable(hiddenIds);
  final List<String> order;
  final Set<String> hiddenIds;
  final bool restoreDefaultOrder;
}

/// Both controls are presentation preferences; this never enables/disables a
/// plugin. If visibility persistence fails, restore the previous effective
/// order so a failed combined save can be retried from the same draft.
Future<void> saveDiscoverPluginManagement({
  required DiscoverPluginManagementDraft draft,
  required DiscoverPluginVisibility visibility,
  required List<String> previousOrder,
  required Future<void> Function(List<String>) writeOrder,
  required Future<void> Function() resetOrder,
}) async {
  try {
    if (draft.restoreDefaultOrder) {
      await resetOrder();
    } else {
      await writeOrder(draft.order);
    }
    await visibility.saveHiddenIds(draft.hiddenIds);
  } catch (error, stack) {
    // The registry may have failed partway through its multi-record write.
    // A rollback failure still leaves the panel open; the complete draft is
    // retained and the next retry reapplies both preferences.
    try {
      await writeOrder(previousOrder);
    } catch (_) {}
    Error.throwWithStackTrace(error, stack);
  }
}
