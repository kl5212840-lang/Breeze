/// Public, device-local download presentation. Resource properties are read from
/// the actual managed row; publication date is never the download timestamp.
class DownloadedVideoMetadata {
  const DownloadedVideoMetadata({
    required this.source,
    required this.resourceId,
    required this.watchUrl,
    required this.title,
    this.canonicalWorkId,
    this.moduleNamespace = '',
    this.plannedEpisodes = 0,
    this.episodeLabel = '',
    this.episodeOrder,
    this.sourceDisplayName = '',
    this.quality = '',
    this.durationMs,
    this.sourceDuration = '',
    this.description = '',
    this.creatorName = '',
    this.tags = const [],
    this.typeName = '',
    this.year = '',
    this.region = '',
    this.language = '',
    this.releaseDate = '',
    this.actors = '',
    this.directors = '',
    this.writers = '',
    this.localCoverPath,
    this.downloadedAt,
  });
  final String source, resourceId, title;
  final Uri watchUrl;
  final String? canonicalWorkId;
  final String moduleNamespace;
  final int plannedEpisodes;
  final String episodeLabel, sourceDisplayName, quality, sourceDuration;
  final int? episodeOrder, durationMs;
  final String typeName;
  final String description,
      creatorName,
      year,
      region,
      language,
      releaseDate,
      actors,
      directors,
      writers;
  final List<String> tags;
  final String? localCoverPath;
  final DateTime? downloadedAt;
}
