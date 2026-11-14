const _publicDisplayFields = {
  'cover',
  'durationMs',
  'metadata',
  'publicEpisodeLabel',
  'publicEpisodeOrder',
  'publicModuleNamespace',
  'publicPlannedEpisodes',
  'publicSearchText',
  'publicTags',
  'publicWorkIdentity',
  'publicWorkTitle',
  'sourceDuration',
  'title',
};

/// Combines a resource snapshot with progress without reviving an old attempt.
Map<String, dynamic> mergeVideoDownloadSnapshot(
  Map<String, dynamic> snapshot,
  Map<String, dynamic>? progress,
) {
  if (progress == null) return snapshot;
  final snapshotAttempt = snapshot['attempt'];
  final progressAttempt = progress['attempt'];
  if (snapshotAttempt is int && progressAttempt is int) {
    if (snapshotAttempt > progressAttempt) return snapshot;
    if (snapshotAttempt < progressAttempt) {
      // A retry can resolve to another quality or format. Keep only public
      // display metadata from the same page, independent of the old attempt.
      return {
        if (snapshot['source'] == progress['source'] &&
            snapshot['url'] == progress['url'])
          for (final field in _publicDisplayFields)
            if (snapshot.containsKey(field)) field: snapshot[field],
        ...progress,
      };
    }
    const active = {'preparing', 'downloading', 'saving'};
    if (!active.contains(snapshot['status']) &&
        active.contains(progress['status'])) {
      return snapshot;
    }
  }
  return {...snapshot, ...progress};
}
