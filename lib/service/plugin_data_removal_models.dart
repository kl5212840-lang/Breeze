class PluginDataRemovalCounts {
  const PluginDataRemovalCounts({
    required this.favorites,
    required this.history,
    required this.follows,
    required this.settings,
    required this.downloads,
    required this.images,
  });
  final int favorites, history, follows, settings, downloads, images;
  bool sameAs(PluginDataRemovalCounts other) =>
      favorites == other.favorites &&
      history == other.history &&
      follows == other.follows &&
      settings == other.settings &&
      downloads == other.downloads &&
      images == other.images;
}

class PluginDataRemovalChoice {
  const PluginDataRemovalChoice({
    required this.cloudDelete,
    required this.includeDownloads,
  });
  final bool cloudDelete, includeDownloads;
}

class PluginDataRemovalInspectionFailure implements Exception {
  const PluginDataRemovalInspectionFailure(this.message);
  final String message;
}

class PluginDataRemovalResult {
  const PluginDataRemovalResult({required this.cleanupPending});
  final bool cleanupPending;
}

/// The two scopes are independent. Local deletion always includes managed files.
class PluginRemovalOptions {
  const PluginRemovalOptions({
    this.deleteLocalData = false,
    this.deleteCloudData = false,
  });
  final bool deleteLocalData, deleteCloudData;
}

enum PluginRemovalFailureStage {
  none,
  preparation,
  cloud,
  localData,
  installation,
}

/// A cloud operation and the following device operation cannot be one atomic
/// transaction. Report committed boundaries, including a partially written cloud.
class PluginRemovalExecutionResult {
  const PluginRemovalExecutionResult({
    this.pluginRemoved = false,
    this.localDataDeleted = false,
    this.cloudDataDeleted = false,
    this.cloudDataMayHaveChanged = false,
    this.localDataMayHaveChanged = false,
    this.cleanupPending = false,
    this.failureStage = PluginRemovalFailureStage.none,
    this.failure,
  });
  final bool pluginRemoved,
      localDataDeleted,
      cloudDataDeleted,
      cloudDataMayHaveChanged,
      localDataMayHaveChanged,
      cleanupPending;
  final PluginRemovalFailureStage failureStage;

  /// Internal typed cause for existing safe error mapping; never stringify a
  /// whole result or expose transport request bodies to the product UI.
  final Object? failure;
  bool get completed =>
      pluginRemoved && failureStage == PluginRemovalFailureStage.none;
}
