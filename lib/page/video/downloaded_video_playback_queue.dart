import 'dart:io';

import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';

typedef DownloadedVideoRowsReader =
    Future<List<Map<String, dynamic>>> Function();
typedef DownloadedVideoMetadataReader =
    Future<List<DownloadedVideoMetadata?>> Function(
      Iterable<Map<String, dynamic>>,
    );

class DownloadedVideoQueueEntry {
  DownloadedVideoQueueEntry._(Map<String, dynamic> row, this.metadata)
    : row = Map.unmodifiable(row),
      resourceId = row['resourceId'] as String,
      watchUrl = Uri.parse(row['url'] as String);
  final String resourceId;
  final Uri watchUrl;
  final Map<String, dynamic> row;
  final DownloadedVideoMetadata? metadata;
  NativeVideoCard get card => NativeVideoCard(
    title: metadata?.episodeLabel.isNotEmpty == true
        ? metadata!.episodeLabel
        : (row['publicEpisodeLabel'] as String?)?.isNotEmpty == true
        ? row['publicEpisodeLabel'] as String
        : row['title'] as String,
    episodeLabel:
        metadata?.episodeLabel ?? row['publicEpisodeLabel'] as String? ?? '',
    watchUrl: watchUrl,
    coverUrl: null,
  );
}

/// One immutable, explicitly identified downloaded work/line/quality snapshot.
/// Loading a descriptor never owns a native/Dart reader lease. NativeVideoPage
/// acquires those only when creating the actual player and releases after its
/// controller's real disposal, including late acquisition and cancellation.
class DownloadedVideoPlaybackPlan {
  DownloadedVideoPlaybackPlan._(
    this._owner,
    this._revision,
    this.currentResourceId,
    this.entries,
    this.session,
  );
  final DownloadedVideoPlaybackQueue _owner;
  final int _revision;
  final String currentResourceId;
  final List<DownloadedVideoQueueEntry> entries;
  final NativePlaybackSession session;
  DownloadedVideoQueueEntry get current =>
      entries.singleWhere((entry) => entry.resourceId == currentResourceId);
  String get source => current.row['source'] as String;
  Map<String, dynamic> get currentRow => current.row;
  late final sequence = VideoEpisodeSequence(
    entries.map((entry) => entry.card).toList(),
    order: VideoEpisodeOrder.site,
  );
  Future<NativePlaybackSession> loadEpisode(Uri target) =>
      _owner._load(this, target);
}

class DownloadedVideoPlaybackQueue {
  DownloadedVideoPlaybackQueue({
    DownloadedVideoRowsReader? readRows,
    Future<NativePlaybackSession> Function(String)? readPlayback,
    DownloadedVideoMetadataReader? readMetadata,
  }) : _readRows = readRows ?? VideoLocalResources.readPlaybackQueue,
       _readPlayback = readPlayback,
       _readMetadata = readMetadata ?? VideoDownloadedDetails.readForResources;
  final DownloadedVideoRowsReader _readRows;
  final Future<NativePlaybackSession> Function(String)? _readPlayback;
  final DownloadedVideoMetadataReader _readMetadata;
  int _epoch = 0, _revision = 0;
  bool _closed = false;

  void cancelPending() {
    _epoch++;
  }

  void dispose() {
    _closed = true;
    _epoch++;
  }

  void _live(int epoch) {
    if (_closed || epoch != _epoch)
      throw StateError('Downloaded playback cancelled');
  }

  static bool _available(Map<String, dynamic> row) =>
      row['available'] == true &&
      row['resourceId'] is String &&
      row['source'] is String &&
      row['quality'] is String &&
      row['title'] is String &&
      row['url'] is String &&
      VideoLocalResources.resourcePage(
            Uri.parse(row['url'] as String),
          )?.toString() ==
          row['url'];

  static bool _sameBinding(
    Map<String, dynamic> old,
    Map<String, dynamic> row,
  ) => const [
    'resourceId',
    'source',
    'url',
    'quality',
    'format',
    'bytes',
    'at',
    'assetId',
    'generation',
  ].every((key) => old[key] == row[key]);

  static DownloadedVideoMetadata? _matchingMetadata(
    Map<String, dynamic> row,
    DownloadedVideoMetadata? value,
  ) =>
      value != null &&
          value.resourceId == row['resourceId'] &&
          value.source == row['source'] &&
          value.watchUrl.toString() == row['url'] &&
          value.quality == row['quality']
      ? value
      : null;

  Future<DownloadedVideoPlaybackPlan> build(String resourceId) async {
    final first = await open(resourceId);
    return enrich(first);
  }

  /// Resolve only the selected local resource before constructing the player.
  Future<DownloadedVideoPlaybackPlan> open(
    String resourceId, {
    Map<String, dynamic>? resource,
  }) async {
    final epoch = ++_epoch, revision = ++_revision;
    _live(epoch);
    final Map<String, dynamic> row;
    final NativePlaybackSession local;
    if (_readPlayback == null) {
      final selected = await VideoLocalResources.readPlaybackResource(
        resourceId,
        resource: resource,
      );
      row = selected.row;
      local = selected.session;
    } else {
      final rows = await _readRows();
      _live(epoch);
      row = _selectedRow(rows, resourceId);
      local = await _descriptor(DownloadedVideoQueueEntry._(row, null), epoch);
    }
    _live(epoch);
    final entry = DownloadedVideoQueueEntry._({
      ...row,
      if (resource?['resourceId'] == resourceId &&
          resource?['source'] == row['source'] &&
          resource?['url'] == row['url'] &&
          resource?['quality'] == row['quality'])
        for (final key in ['publicWorkTitle', 'publicEpisodeLabel'])
          if (resource?[key] is String) key: resource![key],
    }, null);
    return DownloadedVideoPlaybackPlan._(
      this,
      revision,
      resourceId,
      List.unmodifiable([entry]),
      _session(local, entry, [entry]),
    );
  }

  static Map<String, dynamic> _selectedRow(
    List<Map<String, dynamic>> rows,
    String id,
  ) {
    final selected = rows.where((row) => row['resourceId'] == id).toList();
    if (selected.length != 1 || !_available(selected.single)) {
      throw StateError('Downloaded video is unavailable');
    }
    return Map<String, dynamic>.from(selected.single);
  }

  /// Read optional episode metadata after the selected player has prepared.
  Future<DownloadedVideoPlaybackPlan> enrich(
    DownloadedVideoPlaybackPlan first,
  ) async {
    final epoch = _epoch;
    _live(epoch);
    if (first._revision != _revision) {
      throw StateError('Downloaded queue was replaced');
    }
    final rows = (await _readRows())
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    _live(epoch);
    final resourceId = first.currentResourceId;
    final current = _selectedRow(rows, resourceId);
    if (!_sameBinding(first.currentRow, current)) {
      throw StateError('Downloaded video changed or was removed');
    }
    final watch = Uri.parse(current['url'] as String);
    final line = watch.queryParameters['line'];
    final quality = current['quality'] as String;
    final candidates = rows
        .where(
          (row) =>
              _available(row) &&
              row['source'] == current['source'] &&
              row['quality'] == quality &&
              Uri.parse(row['url'] as String).queryParameters['line'] == line,
        )
        .toList();
    final metadata = await _readMetadata(candidates);
    _live(epoch);
    if (metadata.length != candidates.length)
      throw StateError('Incomplete downloaded metadata');
    final entries = [
      for (var i = 0; i < candidates.length; i++)
        DownloadedVideoQueueEntry._(
          candidates[i],
          _matchingMetadata(candidates[i], metadata[i]),
        ),
    ];
    final selected = entries.singleWhere(
      (entry) => entry.resourceId == resourceId,
    );
    final work = selected.metadata?.canonicalWorkId;
    final namespace = selected.metadata?.moduleNamespace;
    // A Hanime playlist can span different works. No episode-looking title,
    // public URL prefix, current list position or old cache creates authority.
    final sameWork =
        work != null &&
            work.isNotEmpty &&
            line != null &&
            line.isNotEmpty &&
            quality.isNotEmpty
        ? entries
              .where(
                (entry) =>
                    entry.metadata?.canonicalWorkId == work &&
                    entry.metadata?.moduleNamespace == namespace,
              )
              .toList()
        : [selected];
    final unique = <Uri, DownloadedVideoQueueEntry>{};
    for (final entry in sameWork) {
      final old = unique[entry.watchUrl];
      if (old == null || _prefer(entry, old, selected))
        unique[entry.watchUrl] = entry;
    }
    final queue = unique.values.toList();
    final ordered = queue.every(
      (entry) => entry.metadata?.episodeOrder != null,
    );
    final numeric = queue.every(
      (entry) =>
          int.tryParse(entry.watchUrl.queryParameters['episode'] ?? '') != null,
    );
    queue.sort((a, b) {
      final order = ordered
          ? a.metadata!.episodeOrder!.compareTo(b.metadata!.episodeOrder!)
          : numeric
          ? int.parse(
              a.watchUrl.queryParameters['episode']!,
            ).compareTo(int.parse(b.watchUrl.queryParameters['episode']!))
          : 0;
      return order != 0
          ? order
          : a.watchUrl.toString().compareTo(b.watchUrl.toString());
    });
    final frozen = List<DownloadedVideoQueueEntry>.unmodifiable(queue);
    return DownloadedVideoPlaybackPlan._(
      this,
      first._revision,
      resourceId,
      frozen,
      _session(first.session, selected, frozen),
    );
  }

  static bool _prefer(
    DownloadedVideoQueueEntry next,
    DownloadedVideoQueueEntry old,
    DownloadedVideoQueueEntry selected,
  ) {
    if (next.resourceId == selected.resourceId) return true;
    if (old.resourceId == selected.resourceId) return false;
    final format = selected.row['format'];
    if ((next.row['format'] == format) != (old.row['format'] == format)) {
      return next.row['format'] == format;
    }
    final nextAt = next.row['at'] as int? ?? 0,
        oldAt = old.row['at'] as int? ?? 0;
    if (nextAt != oldAt) return nextAt > oldAt;
    return next.resourceId.compareTo(old.resourceId) < 0;
  }

  Future<NativePlaybackSession> _load(
    DownloadedVideoPlaybackPlan plan,
    Uri target,
  ) async {
    if (plan._revision != _revision)
      throw StateError('Downloaded queue was replaced');
    final epoch = ++_epoch;
    _live(epoch);
    final canonical = videoPlaybackIdentity(target);
    if (canonical != target)
      throw StateError('Episode outside downloaded queue');
    final matches = plan.entries
        .where((entry) => entry.watchUrl == canonical)
        .toList();
    if (matches.length != 1)
      throw StateError('Episode outside downloaded queue');
    final entry = matches.single;
    final local = await _descriptor(entry, epoch);
    _live(epoch);
    return _session(local, entry, plan.entries);
  }

  Future<NativePlaybackSession> _descriptor(
    DownloadedVideoQueueEntry entry,
    int epoch,
  ) async {
    final read = _readPlayback;
    if (read == null) {
      try {
        final selected = await VideoLocalResources.readPlaybackResource(
          entry.resourceId,
          resource: entry.row,
        );
        _live(epoch);
        if (!_sameBinding(entry.row, selected.row)) {
          throw StateError('Downloaded video changed or was removed');
        }
        return selected.session;
      } on FileSystemException {
        throw StateError('Downloaded video changed or was removed');
      }
    }
    Future<void> check() async {
      final fresh = await _readRows();
      _live(epoch);
      final rows = fresh
          .where((row) => row['resourceId'] == entry.resourceId)
          .toList();
      if (rows.length != 1 ||
          !_available(rows.single) ||
          !_sameBinding(entry.row, rows.single)) {
        throw StateError('Downloaded video changed or was removed');
      }
    }

    await check();
    final local = await read(entry.resourceId);
    _live(epoch);
    if (local.watchUrl != entry.watchUrl ||
        local.sources.length != 1 ||
        local.sources.any(
          (source) =>
              source.localResourceId != entry.resourceId ||
              source.headers.isNotEmpty ||
              source.label != entry.row['quality'] ||
              source.url.scheme !=
                  (entry.row['format'] == 'hls' ? 'breeze-hls' : 'file') ||
              (entry.row['format'] == 'hls' &&
                  source.url != VideoHlsAssets.playbackUri(entry.row)),
        )) {
      throw StateError('Invalid downloaded playback descriptor');
    }
    await check();
    return local;
  }

  static NativePlaybackSession _session(
    NativePlaybackSession local,
    DownloadedVideoQueueEntry entry,
    List<DownloadedVideoQueueEntry> entries,
  ) => NativePlaybackSession(
    title: entry.metadata?.title.isNotEmpty == true
        ? entry.metadata!.title
        : (entry.row['publicWorkTitle'] as String?)?.isNotEmpty == true
        ? entry.row['publicWorkTitle'] as String
        : local.title,
    watchUrl: local.watchUrl,
    sources: List.unmodifiable([
      for (final source in local.sources)
        NativePlaybackSource(
          url: source.url,
          label: source.label,
          headers: const {},
          localResourceId: source.localResourceId,
        ),
    ]),
    description: entry.metadata?.description ?? '',
    tags: List.unmodifiable(entry.metadata?.tags ?? const <String>[]),
    metadata: VideoPublicMetadata(duration: entry.metadata?.sourceDuration),
    episodes: List.unmodifiable(entries.map((entry) => entry.card)),
  );
}
