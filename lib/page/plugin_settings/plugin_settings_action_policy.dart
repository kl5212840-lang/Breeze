/// Legacy maintenance commands must not become ordinary user actions, even
/// when an installed or third-party bundle still advertises them.
bool isUserFacingPluginSettingsAction(Map<String, dynamic> action) {
  final path = action['fnPath']?.toString().trim() ?? '';
  return path.isNotEmpty && !isInternalPluginMaintenanceFunction(path);
}

bool isInternalPluginMaintenanceFunction(Object? path) => const {
  'clearPluginSession',
  'dumpRuntimeInfo',
}.contains(path?.toString().trim());
