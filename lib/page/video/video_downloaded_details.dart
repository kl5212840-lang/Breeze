import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_local_poster.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/downloaded_video_metadata.dart';
export 'package:zephyr/page/video/downloaded_video_metadata.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';

Uint8List _smallDownloadCover(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 8000000) {
    throw const FormatException('Invalid download cover');
  }
  final decoded = decoder?.decodeFrame(0);
  if (decoded == null) throw const FormatException('Invalid download cover');
  final oriented = img.bakeOrientation(decoded);
  final scale = math.max(
    1.0,
    math.max(oriented.width / 320, oriented.height / 480),
  );
  final small = img.copyResize(
    oriented,
    width: math.max(1, (oriented.width / scale).round()),
    height: math.max(1, (oriented.height / scale).round()),
    interpolation: img.Interpolation.average,
  );
  final clean = img.Image(
    width: small.width,
    height: small.height,
    numChannels: 4,
  );
  img.compositeImage(clean, small);
  return Uint8List.fromList(img.encodePng(clean));
}

/// Device-local public details retained for downloaded playback. Never media
/// URLs, headers, cookies, browser snapshots or another playback authority.
abstract final class VideoDownloadedDetails {
  static const durableStorageKey = 'breeze.local.video.download-details.v2';
  static const _hanimeSource = '1e600cff-8ebe-4517-8aa4-6678aec46424';
  static final posterChanges = ValueNotifier<int>(0);
  static final changes = ValueNotifier<int>(0);
  static final _frameJobs = <String, Future<String?>>{};
  static final _coverJobs = <String, Future<void>>{};
  static final _posterEpochs = <String, int>{};

  static Future<String?> ensureLocalPoster(Map<String, dynamic> row) {
    final id = row['resourceId'];
    if (!VideoLocalPoster.supports(row) ||
        id is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id))
      return localPosterForResource(row);
    return _frameJobs.putIfAbsent(id, () {
      final epoch = _posterEpochs[id] ?? 0;
      late Future<String?> job;
      job = _ensureLocalFrame(row, id, epoch)
          .catchError((Object _) => null)
          .whenComplete(() {
            if (identical(_frameJobs[id], job)) _frameJobs.remove(id);
          });
      return job;
    });
  }

  static Future<String?> _ensureLocalFrame(
    Map<String, dynamic> requested,
    String id,
    int epoch,
  ) async {
    final row = await VideoLocalPoster.current(requested);
    if (row == null || (_posterEpochs[id] ?? 0) != epoch) return null;
    // Always try the actual source provider before considering video pixels.
    await retainForResource(
      row,
      frameFallback: false,
      waitForPoster: true,
      retainIf: () => (_posterEpochs[id] ?? 0) == epoch,
    );
    final existing = await localPosterForResource(row);
    if (existing != null) return existing;
    final data = _durable(await SharedPreferences.getInstance());
    final resource = _map(_map(data['resources'])[id]);
    final work = resource['work'];
    if (work is! String) return null;
    final attempt = _hash(
      'local-frame-v1|$work|${VideoLocalPoster.binding(row)}',
    );
    await VideoLocalPoster.capture(
      row,
      begin: () => _serial(() async {
        final prefs = await SharedPreferences.getInstance(),
            current = _durable(await SharedPreferences.getInstance());
        final resources = _map(current['resources']),
            reference = _map(_map(current['resources'])[id]);
        if ((_posterEpochs[id] ?? 0) != epoch ||
            reference['work'] != work ||
            reference['frameAttempt'] == attempt ||
            await _coverPath(work) != null)
          return false;
        resources[id] = {...reference, 'frameAttempt': attempt};
        current['resources'] = resources;
        await _writeDurable(prefs, current);
        return true;
      }),
      consume: (bytes) async {
        final output = await compute(_smallDownloadCover, bytes);
        await _serial(() async {
          final current = _durable(await SharedPreferences.getInstance());
          final reference = _map(_map(current['resources'])[id]);
          if ((_posterEpochs[id] ?? 0) != epoch ||
              reference['work'] != work ||
              reference['frameAttempt'] != attempt ||
              await _coverPath(work) != null)
            return;
          final file = File(
            p.join((await _coverDirectory()).path, '$work.png'),
          );
          final stage = File('${file.path}.frame.tmp');
          try {
            await stage.writeAsBytes(output, flush: true);
            if ((_posterEpochs[id] ?? 0) != epoch) return;
            await stage.rename(file.path);
            posterChanges.value++;
          } finally {
            if (await stage.exists()) await stage.delete();
          }
        });
      },
    );
    return localPosterForResource(row);
  }

  static final _decodedPosters =
      <String, ({String url, ImageProvider provider})>{};

  /// Transient references to actual decoded poster providers, not credentials
  /// or another image request. Bounded independently of durable download data.
  static void rememberDecodedPoster({
    required String source,
    required Uri page,
    required String url,
    required ImageProvider provider,
  }) {
    final publicPage = videoPublicPage(page);
    if (source.isEmpty || source.length > 200 || publicPage == null) return;
    final key = '$source|$publicPage';
    _decodedPosters.remove(key);
    _decodedPosters[key] = (url: url, provider: provider);
    while (_decodedPosters.length > 64)
      _decodedPosters.remove(_decodedPosters.keys.first);
  }

  static Future<String?> localPosterForResource(
    Map<String, dynamic> row,
  ) async {
    final source = row['source'], page = Uri.tryParse('${row['url']}');
    if (source is! String ||
        page == null ||
        videoPlaybackIdentity(page) == null)
      return null;
    try {
      await _tail;
      final data = _durable(await SharedPreferences.getInstance());
      final key = _pageKey(source, page), id = row['resourceId'];
      final resource = _map(_map(data['resources'])[id]);
      final reference = resource['source'] == source && resource['page'] == key
          ? resource
          : _map(_map(data['pages'])[key]);
      final work = reference['work'];
      return work is String ? await _coverPath(work) : null;
    } catch (_) {
      return null;
    }
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static String _pageKey(String source, Uri watch) =>
      '$source|${videoPlaybackIdentity(watch) ?? videoPublicPage(watch)}';
  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  static String _text(Object? value, [int limit = 1500]) =>
      apiVideoText(value, limit);
  static Map<String, dynamic> _durable(SharedPreferences prefs) {
    final raw = prefs.getString(durableStorageKey);
    if (raw == null)
      return {'version': 2, 'works': {}, 'pages': {}, 'resources': {}};
    final data = _map(jsonDecode(raw));
    if (data['version'] != 2 ||
        data['works'] is! Map ||
        data['pages'] is! Map ||
        data['resources'] is! Map) {
      throw const FormatException('Invalid durable download metadata');
    }
    return data;
  }

  static Future<void> _writeDurable(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    // No age/count eviction: these are download records, not a browsing cache.
    final encoded = jsonEncode(data);
    if (prefs.getString(durableStorageKey) == encoded) return;
    if (!await prefs.setString(durableStorageKey, encoded)) {
      throw StateError('Downloaded metadata was not saved');
    }
    changes.value++;
  }

  static String _sourceName(String source) {
    try {
      return _text(
        PluginRegistryService.I.getCachedPluginInfo(source)?['name'],
        200,
      );
    } catch (_) {
      return '';
    }
  }

  static List<String> _tags(Object? value) {
    final values = value is List
        ? value.whereType<String>()
        : value is String
        ? value.split(RegExp(r'[,，/|]'))
        : const <String>[];
    return values
        .map((entry) => _text(entry, 120))
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .take(80)
        .toList();
  }

  static bool isHanimeWatch(String source, Uri watch) =>
      source == _hanimeSource &&
      watch.host == 'hanime1.me' &&
      videoPlaybackIdentity(watch)?.path == '/watch';

  /// [rows] come from the file backup's verified managed MP4 index.
  static Future<Map<String, String>> captureBackupArtists(
    List<Map<String, dynamic>> rows,
  ) async {
    final metadata = await readForResources(
      rows,
      includeFavoriteFallback: false,
      includeLocalCover: false,
    );
    return {
      for (final item in metadata.whereType<DownloadedVideoMetadata>())
        if (isHanimeWatch(item.source, item.watchUrl) &&
            item.creatorName.isNotEmpty &&
            !RegExp(r'[\x00-\x1f\x7f]').hasMatch(item.creatorName))
          item.resourceId: item.creatorName,
    };
  }

  static Future<void> restoreBackupArtists(
    Map<String, ({Uri watch, String title, String artist})> artists, {
    required bool merge,
    required Future<void> Function(
      Map<String, dynamic> updates, {
      Map<String, dynamic>? beforeValues,
    })
    beforeWrite,
  }) async {
    if (artists.isEmpty) return;
    await _serial(() async {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(durableStorageKey);
      final data = _durable(prefs);
      final works = _map(data['works']);
      final pages = _map(data['pages']);
      final resources = _map(data['resources']);
      var changed = false;
      for (final entry in artists.entries) {
        final saved = entry.value;
        final key = _pageKey(_hanimeSource, saved.watch);
        final workId = _hash(key);
        final page = _map(pages[key]);
        final resource = _map(resources[entry.key]);
        final work = _map(works[workId]);
        if ((page.isNotEmpty && page['work'] != workId) ||
            (resource.isNotEmpty &&
                (resource['source'] != _hanimeSource ||
                    resource['page'] != key ||
                    resource['work'] != workId)) ||
            (work.isNotEmpty && work['source'] != _hanimeSource) ||
            (merge && _text(work['creatorName'], 120).isNotEmpty)) {
          continue;
        }
        works[workId] = {
          'title': saved.title,
          ...work,
          'source': _hanimeSource,
          'creatorName': saved.artist,
        };
        pages[key] = {...page, 'work': workId};
        resources[entry.key] = {
          ...resource,
          'source': _hanimeSource,
          'page': key,
          'work': workId,
        };
        changed = true;
      }
      if (!changed) return;
      data['works'] = works;
      data['pages'] = pages;
      data['resources'] = resources;
      final next = jsonEncode(data);
      if (next == previous) return;
      await beforeWrite(
        {durableStorageKey: next},
        beforeValues: {durableStorageKey: previous},
      );
      await _writeDurable(prefs, data);
    });
  }

  static String _storedArtist(Map<String, dynamic> session) {
    final artist = _map(session['creator']);
    if (artist.isNotEmpty) {
      return artist['role'] == 'artist' ? _text(artist['name'], 120) : '';
    }
    // NativePlaybackSession.creatorName is the artist, independently of uploader.
    return _text(session['creatorName'], 120);
  }

  static List<String> _downloadTags(
    Object? value, {
    required bool hanime,
    Object? explicitLabels,
  }) {
    final tags = _tags(value);
    if (!hanime) return tags;
    // Hanime's older detail DOM snapshot stored the anchor's vote badge with
    // the tag name. Apply this only to that source's saved watch-page labels.
    final badge = RegExp(r'\s+\([0-9]+\)$');
    final literal = _tags(explicitLabels).toSet();
    return tags
        .map(
          (tag) =>
              literal.contains(tag) ? tag : tag.replaceFirst(badge, '').trim(),
        )
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  static String _sessionArtist(String source, NativePlaybackSession session) {
    if (!isHanimeWatch(source, session.watchUrl)) return '';
    final creator = session.creator;
    if (creator != null && creator.role != 'artist') return '';
    return _text(creator?.name ?? session.creatorName, 120);
  }

  static Future<void> _retainArtist(
    SharedPreferences prefs,
    String source,
    Uri watch,
    String artist,
  ) async {
    final data = _durable(prefs);
    final key = _pageKey(source, watch);
    final reference = _map(_map(data['pages'])[key]);
    final workId = reference['work'];
    if (workId is! String || workId != _hash(key)) return;
    final works = _map(data['works']);
    final work = _map(works[workId]);
    if (work['source'] != source || work['creatorName'] == artist) return;
    final resourceExists = _map(data['resources']).values.any((raw) {
      final resource = _map(raw);
      return resource['source'] == source &&
          resource['page'] == key &&
          resource['work'] == workId;
    });
    if (!resourceExists) return;
    works[workId] = {...work, 'creatorName': artist};
    data['works'] = works;
    await _writeDurable(prefs, data);
  }

  /// Reuses the artist already read by an explicitly opened online detail.
  /// Only a retained download of that exact source/page can be updated.
  static Future<void> retainObservedCreator(
    String source,
    NativePlaybackSession session,
  ) async {
    final artist = _sessionArtist(source, session);
    if (artist.isEmpty) return;
    try {
      await _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        await _retainArtist(prefs, source, session.watchUrl, artist);
      });
    } catch (_) {
      // Optional offline presentation is independent of the online detail.
    }
  }

  static Map<String, dynamic> _itemFields(ApiVideoItem item) => {
    'title': _text(item.title, 500),
    'description': _text(item.description),
    'tags': _tags(item.genres),
    'typeName': _text(item.typeName, 120),
    'year': _text(item.year, 80),
    'region': _text(item.area, 120),
    'language': _text(item.language, 120),
    'releaseDate': _text(item.releaseDate, 80),
    'actors': _text(item.actors, 500),
    'directors': _text(item.directors, 500),
    'writers': _text(item.writers, 500),
    'sourceDuration': videoCoverDurationText(
      item.sourceDuration,
      clockFallback: item.remarks,
    ),
  };

  /// Only a validated API work/line/episode selection can grant shared work
  /// authority. A Hanime single-item playlist does not call this path.
  static Future<void> captureItem(
    String source,
    ApiVideoItem item,
    List<NativeVideoCard> episodes, {
    OmoNetworkContext? network,
    String sourceDisplayName = '',
    String namespace = '',
  }) async {
    final page = videoPublicPage(item.detailUrl);
    if (page == null || item.id.isEmpty || source.isEmpty) return;
    final canonical = '$source|$namespace|${item.id}|$page';
    final work = _hash('$source|$canonical');
    await _serial(() async {
      final prefs = await SharedPreferences.getInstance(),
          data = _durable(await SharedPreferences.getInstance());
      final works = _map(data['works']), pages = _map(data['pages']);
      final previousWork = _map(works[work]);
      final fields = _itemFields(item);
      final previousDuration = knownVideoDurationText(
        _text(previousWork['sourceDuration'], 120),
      );
      works[work] = {
        ...previousWork,
        ...fields,
        if (knownVideoDurationText(
              _text(fields['sourceDuration'], 120),
            ).isEmpty &&
            previousDuration.isNotEmpty)
          'sourceDuration': previousDuration,
        'source': source,
        'canonicalWorkId': canonical,
        'moduleNamespace': namespace,
        'plannedEpisodes': item.plannedEpisodes > 0
            ? item.plannedEpisodes
            : previousWork['plannedEpisodes'] is int
            ? previousWork['plannedEpisodes']
            : 0,
        'sourceDisplayName': _text(
          sourceDisplayName.isEmpty ? _sourceName(source) : sourceDisplayName,
          200,
        ),
      };
      for (final card in episodes) {
        final identity = videoPlaybackIdentity(card.watchUrl);
        if (identity == null || videoPublicPage(identity) != page) continue;
        final line = item.lines
            .where((line) => line.id == identity.queryParameters['line'])
            .firstOrNull;
        final order =
            line?.episodes.indexWhere(
              (episode) => episode.id == identity.queryParameters['episode'],
            ) ??
            -1;
        if (order < 0) continue;
        final pageKey = _pageKey(source, identity);
        final previous = _map(pages[pageKey]);
        if (previous['ambiguous'] == true ||
            previous['work'] != null && previous['work'] != work) {
          // The resource URL itself does not distinguish these modules. Keep
          // it singleton rather than attaching another module's work details.
          pages[pageKey] = {'ambiguous': true};
          continue;
        }
        pages[pageKey] = {
          'work': work,
          'episodeLabel': _text(card.episodeLabel, 300),
          'episodeOrder': order,
        };
      }
      data['works'] = works;
      data['pages'] = pages;
      await _writeDurable(prefs, data);
    });
    if (item.coverUrl != null)
      unawaited(
        _scheduleCover(
          work,
          item.coverUrl!,
          source: source,
          page: item.detailUrl,
          network: network,
        ),
      );
  }

  // Poster decode/network IO is optional presentation work. Never run it
  // under a caller's storage/transfer transaction or make queued rows wait.
  static Future<void> _scheduleCover(
    String work,
    Uri? url, {
    required String source,
    Uri? page,
    OmoNetworkContext? network,
  }) {
    final pending = _coverJobs[work];
    if (pending != null) return pending;
    if (url == null &&
        !_decodedPosters.containsKey(
          '$source|${page == null ? null : videoPublicPage(page)}',
        )) {
      return Future.value();
    }
    late Future<void> job;
    job = _cacheCover(work, url, source: source, page: page, network: network)
        .catchError((Object _) {})
        .whenComplete(() {
          if (identical(_coverJobs[work], job)) _coverJobs.remove(work);
        });
    _coverJobs[work] = job;
    return job;
  }

  static Future<Directory> _coverDirectory({bool create = true}) async {
    final directory = Directory(
      p.join(await getFilePath(), 'video-download-covers'),
    );
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked download cover directory');
    }
    if (create) await directory.create(recursive: true);
    return directory;
  }

  static Future<String?> _coverPath(String work) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(work)) return null;
    final file = File(
      p.join((await _coverDirectory(create: false)).path, '$work.png'),
    );
    return await FileSystemEntity.type(file.path, followLinks: false) ==
                FileSystemEntityType.file &&
            await file.length() <= 1024 * 1024
        ? file.path
        : null;
  }

  static Future<void> _cacheCover(
    String work,
    Uri? url, {
    required String source,
    Uri? page,
    OmoNetworkContext? network,
  }) async {
    if (await _coverPath(work) != null) return;
    if (url != null && (url.scheme != 'https' || url.userInfo.isNotEmpty))
      return;
    Uint8List? bytes;
    // An existing decoded provider may be reused. A cache miss only fetches
    // through the already selected source visit, never a new direct client.
    final publicPage = page == null ? null : videoPublicPage(page);
    final remembered = _decodedPosters['$source|$publicPage'];
    ImageProvider? provider;
    for (final candidate in [
      if (remembered != null &&
          (url == null || remembered.url == url.toString()))
        remembered.provider,
      if (url != null) NetworkImage(url.toString()),
    ]) {
      final key = await candidate.obtainKey(ImageConfiguration.empty);
      if (PaintingBinding.instance.imageCache.containsKey(key)) {
        provider = candidate;
        break;
      }
    }
    if (provider != null) {
      final completed = Completer<ui.Image>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completed.isCompleted) completed.complete(info.image.clone());
        },
        onError: (Object error, StackTrace? stack) {
          if (!completed.isCompleted) completed.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      try {
        final decoded = await completed.future.timeout(
          const Duration(seconds: 3),
        );
        final encoded = await decoded.toByteData(
          format: ui.ImageByteFormat.png,
        );
        decoded.dispose();
        bytes = encoded?.buffer.asUint8List();
      } finally {
        stream.removeListener(listener);
      }
    } else if (network != null && url != null) {
      final response = await network.start(
        url,
        timeout: const Duration(seconds: 3),
      );
      try {
        if (response.status >= 200 && response.status < 300) {
          bytes = await response
              .bytes(2 * 1024 * 1024)
              .timeout(const Duration(seconds: 5));
        }
      } finally {
        await response.cancel();
      }
    }
    if (bytes == null || bytes.length > 2 * 1024 * 1024) return;
    final output = await compute(_smallDownloadCover, bytes);
    await _serial(() async {
      final data = _durable(await SharedPreferences.getInstance());
      if (!_map(data['works']).containsKey(work) ||
          await _coverPath(work) != null)
        return;
      final file = File(p.join((await _coverDirectory()).path, '$work.png'));
      final stage = File('${file.path}.tmp');
      try {
        await stage.writeAsBytes(output, flush: true);
        await stage.rename(file.path);
        posterChanges.value++;
      } finally {
        if (await stage.exists()) await stage.delete();
      }
    });
  }

  /// Called after a managed file/package was committed. Optional presentation
  /// failures never alter the file, its availability or its download result.
  static Future<void> retainForResource(
    Map<String, dynamic> row, {
    OmoNetworkContext? network,
    bool frameFallback = true,
    bool waitForPoster = false,
    bool Function()? retainIf,
  }) async {
    final source = _text(row['source'], 200), id = _text(row['resourceId'], 64);
    final watch = Uri.tryParse('${row['url']}');
    if (source.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
        watch == null ||
        videoPlaybackIdentity(watch) == null)
      return;
    await _serial(() async {
      if (retainIf?.call() == false) return;
      final prefs = await SharedPreferences.getInstance(),
          data = _durable(await SharedPreferences.getInstance());
      final pages = _map(data['pages']),
          works = _map(data['works']),
          resources = _map(data['resources']);
      final key = _pageKey(source, watch);
      var reference = _map(pages[key]);
      if (reference.isEmpty || reference['ambiguous'] == true) {
        final legacy = _decode(
          prefs.getString(storageKey),
        ).where((entry) => entry['key'] == _key(source, watch)).firstOrNull;
        final session = _map(legacy?['session']), item = _map(legacy?['item']);
        final work = _hash(key);
        final artist =
            isHanimeWatch(source, watch) &&
                session['watchUrl'] == videoPlaybackIdentity(watch).toString()
            ? _storedArtist(session)
            : '';
        works[work] = {
          'source': source,
          'sourceDisplayName': _text(
            session['sourceDisplayName'] ??
                item['sourceDisplayName'] ??
                _sourceName(source),
            200,
          ),
          'title': _text(
            session['title'] ?? item['title'] ?? row['title'],
            500,
          ),
          'description': _text(session['description'] ?? item['description']),
          if (artist.isNotEmpty) 'creatorName': artist,
          'tags': _tags(session['tags'] ?? item['genres']),
          if (session['literalTagLabels'] is List)
            'literalTagLabels': _tags(session['literalTagLabels']),
          'typeName': _text(item['typeName'], 120),
          'language': _text(item['language'], 120),
          'actors': _text(item['actors'], 500),
          'directors': _text(item['directors'], 500),
          'writers': _text(item['writers'], 500),
          'year': _text(item['year'], 80),
          'region': _text(item['area'], 120),
          'releaseDate': _text(
            item['releaseDate'] ?? session['releaseDate'],
            80,
          ),
        };
        reference = {'work': work};
        pages[key] = reference;
      }
      resources[id] = {
        ..._map(resources[id]),
        'source': source,
        'page': key,
        ...reference,
      };
      data['works'] = works;
      data['pages'] = pages;
      data['resources'] = resources;
      await _writeDurable(prefs, data);
    });
    final data = _durable(await SharedPreferences.getInstance());
    final work = _map(_map(data['resources'])[id])['work'];
    final url = Uri.tryParse('${row['cover']}');
    if (work is String) {
      final poster = _scheduleCover(
        work,
        url?.scheme == 'https' ? url : null,
        source: source,
        page: watch,
        network: network,
      );
      if (waitForPoster) {
        await poster;
      } else {
        unawaited(poster);
      }
    }
    if (frameFallback && VideoLocalPoster.supports(row))
      unawaited(ensureLocalPoster(row));
  }

  static Future<List<DownloadedVideoMetadata?>> readForResources(
    Iterable<Map<String, dynamic>> rows, {
    bool includeFavoriteFallback = true,
    bool includeLocalCover = true,
  }) async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data;
    try {
      data = _durable(prefs);
    } catch (_) {
      data = {'works': {}, 'pages': {}, 'resources': {}};
    }
    List<Map<String, dynamic>> legacy;
    try {
      legacy = _decode(prefs.getString(storageKey));
    } catch (_) {
      legacy = [];
    }
    final legacyByPage = {for (final entry in legacy) '${entry['key']}': entry};
    final resources = _map(data['resources']);
    final pages = _map(data['pages']);
    final works = _map(data['works']);
    final input = rows.toList(growable: false);
    final needsLibrary =
        includeFavoriteFallback &&
        input.any((row) {
          final source = _text(row['source'], 200),
              watch = Uri.tryParse('${row['url']}');
          if (watch == null) return false;
          final reference = _map(resources[_text(row['resourceId'], 64)]);
          final page = reference.isNotEmpty
              ? reference
              : _map(pages[_pageKey(source, watch)]);
          return _map(works[page['work']]).isEmpty &&
              _map(legacyByPage[_key(source, watch)]?['item']).isEmpty;
        });
    Map<String, dynamic> library = {};
    try {
      if (needsLibrary) {
        final snapshot = await VideoLibraryStore.shared.read();
        library = {
          for (final entry in snapshot.favorites.values)
            if (!entry.deleted)
              '${entry.data['source']}|${_map(entry.data['item'])['detailUrl']}':
                  _map(entry.data['item']),
        };
      }
    } catch (_) {}
    final covers = <String, Future<String?>>{};
    final result = <DownloadedVideoMetadata?>[];
    for (final row in input) {
      final source = _text(row['source'], 200),
          id = _text(row['resourceId'], 64);
      final watch = Uri.tryParse('${row['url']}');
      if (source.isEmpty ||
          watch == null ||
          videoPlaybackIdentity(watch) == null) {
        result.add(null);
        continue;
      }
      var reference = _map(resources[id]);
      if (reference['source'] != source ||
          reference['page'] != _pageKey(source, watch))
        reference = {};
      final page = reference.isNotEmpty
          ? reference
          : _map(pages[_pageKey(source, watch)]);
      var work = _map(works[page['work']]);
      if (work['source'] != source) work = {};
      final old = legacyByPage[_key(source, watch)];
      final item = _map(old?['item']).isNotEmpty
          ? _map(old?['item'])
          : _map(library['$source|${videoPublicPage(watch)}']);
      final session = _map(old?['session']);
      final hanime = isHanimeWatch(source, watch);
      final savedArtist = hanime ? _text(work['creatorName'], 120) : '';
      final observedArtist =
          hanime &&
              session['watchUrl'] == videoPlaybackIdentity(watch).toString()
          ? _storedArtist(session)
          : '';
      String value(String field, [String? legacyField]) =>
          _text(work[field] ?? session[field] ?? item[legacyField ?? field]);
      final at = row['at'];
      result.add(
        DownloadedVideoMetadata(
          source: source,
          resourceId: id,
          watchUrl: watch,
          title: _text(
            work['title'] ?? session['title'] ?? item['title'] ?? row['title'],
            500,
          ),
          canonicalWorkId: work['canonicalWorkId'] is String
              ? work['canonicalWorkId'] as String
              : null,
          moduleNamespace: _text(work['moduleNamespace'], 200),
          plannedEpisodes: apiVideoInt(
            work['plannedEpisodes'] ?? item['plannedEpisodes'],
          ),
          episodeLabel: _text(page['episodeLabel'], 300),
          episodeOrder:
              page['episodeOrder'] is int && (page['episodeOrder'] as int) >= 0
              ? page['episodeOrder'] as int
              : null,
          sourceDisplayName: value('sourceDisplayName'),
          quality: _text(row['quality'], 200),
          durationMs: row['durationMs'] is int
              ? row['durationMs'] as int
              : null,
          sourceDuration: _text(
            row['sourceDuration'] ??
                work['sourceDuration'] ??
                session['sourceDuration'] ??
                item['sourceDuration'],
            120,
          ),
          description: value('description'),
          creatorName: savedArtist.isNotEmpty ? savedArtist : observedArtist,
          tags: _downloadTags(
            work['tags'] ?? session['tags'] ?? item['genres'],
            hanime: hanime,
            explicitLabels:
                work['literalTagLabels'] ?? session['literalTagLabels'],
          ),
          typeName: value('typeName'),
          year: value('year'),
          region: value('region', 'area'),
          language: value('language'),
          releaseDate: value('releaseDate'),
          actors: value('actors'),
          directors: value('directors'),
          writers: value('writers'),
          localCoverPath: includeLocalCover && page['work'] is String
              ? await covers.putIfAbsent(
                  page['work'] as String,
                  () => _coverPath(
                    page['work'] as String,
                  ).catchError((Object _) => null),
                )
              : null,
          downloadedAt: at is int && at.abs() <= 8640000000000000
              ? DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)
              : null,
        ),
      );
    }
    return result;
  }

  static Future<DownloadedVideoMetadata?> readForResource(
    Map<String, dynamic> row,
  ) async => (await readForResources([row])).single;

  static Future<void> removeResource(String id) {
    _posterEpochs[id] = (_posterEpochs[id] ?? 0) + 1;
    return _serial(() async {
      final prefs = await SharedPreferences.getInstance(),
          data = _durable(await SharedPreferences.getInstance());
      final resources = _map(data['resources']);
      final removed = _map(resources.remove(id));
      if (removed.isEmpty) return;
      final work = removed['work'];
      final retained = resources.values.any(
        (entry) => _map(entry)['work'] == work,
      );
      data['resources'] = resources;
      if (!retained && work is String) {
        final works = _map(data['works'])..remove(work),
            pages = _map(data['pages']);
        pages.removeWhere((_, entry) => _map(entry)['work'] == work);
        data['works'] = works;
        data['pages'] = pages;
      }
      await _writeDurable(prefs, data);
      if (!retained && work is String) {
        final path = await _coverPath(work);
        if (path != null) {
          await File(path).delete();
          posterChanges.value++;
        }
      }
    });
  }

  static Future<void> removeSourceResources(String source) async {
    await _tail;
    final data = _durable(await SharedPreferences.getInstance());
    final ids = _map(data['resources']).entries
        .where((entry) => _map(entry.value)['source'] == source)
        .map((entry) => entry.key)
        .toList();
    for (final id in ids) {
      await removeResource(id);
    }
  }

  static const storageKey = 'breeze.local.video.download-details.v1';
  static Future<void>? _tail;
  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return [];
    final value = jsonDecode(raw);
    if (value is! List)
      throw const FormatException('Invalid downloaded details');
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static String _key(String source, Uri watch) =>
      '$source|${videoPublicPage(watch)}';
  static Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _tail;
    final result = () async {
      if (previous != null) await previous;
      return await action();
    }();
    final completed = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = completed;
    completed.then((_) {
      if (identical(_tail, completed)) _tail = null;
    });
    return result;
  }

  static String? _cover(Uri? uri) =>
      uri?.scheme == 'https' &&
          uri?.userInfo.isEmpty == true &&
          uri?.hasQuery == false &&
          uri?.hasFragment == false
      ? uri.toString()
      : null;
  static Map<String, dynamic> publicItem(ApiVideoItem item) => {
    'id': item.id,
    'title': item.title,
    'detailUrl': item.detailUrl.toString(),
    'description': _text(item.description),
    'genres': _text(item.genres, 500),
    'typeId': _text(item.typeId, 120),
    'typeName': _text(item.typeName, 120),
    'language': _text(item.language, 120),
    'year': _text(item.year, 80),
    'area': _text(item.area, 120),
    'releaseDate': _text(item.releaseDate, 80),
    'actors': _text(item.actors, 500),
    'directors': _text(item.directors, 500),
    'writers': _text(item.writers, 500),
    'sourceDuration': videoCoverDurationText(
      item.sourceDuration,
      clockFallback: item.remarks,
    ),
    // Keep the source's explicit scope proof; a single currently listed
    // episode without these declarations must not become a work's total.
    'plannedEpisodes': item.plannedEpisodes,
    'finished': item.finished,
    'coverUrl': _cover(item.coverUrl),
    'lines': [
      for (final line in item.lines)
        {
          'id': line.id,
          'label': line.label,
          'episodes': [
            for (final episode in line.episodes)
              if (videoPlaybackIdentity(episode.watchUrl) == episode.watchUrl)
                {
                  'id': episode.id,
                  'title': episode.title,
                  'watchUrl': episode.watchUrl.toString(),
                  'resolveOnPlayback': true,
                },
          ],
        },
    ],
  };
  static Future<void> _save(
    String source,
    Uri page,
    String field,
    Map<String, dynamic> value,
  ) => _serial(() async {
    if (source.isEmpty || source.length > 200 || videoPublicPage(page) == null)
      return;
    final prefs = await SharedPreferences.getInstance();
    final rows = _decode(prefs.getString(storageKey));
    final key = _key(source, page);
    final old = rows.where((row) => row['key'] == key).firstOrNull;
    final previous = _map(old?[field]);
    final sameIdentity = field == 'item'
        ? previous['id'] == value['id'] &&
              previous['detailUrl'] == value['detailUrl']
        : field == 'session' && previous['watchUrl'] == value['watchUrl'];
    final previousDuration = knownVideoDurationText(
      _text(previous['sourceDuration'], 120),
    );
    if (sameIdentity &&
        knownVideoDurationText(_text(value['sourceDuration'], 120)).isEmpty &&
        previousDuration.isNotEmpty) {
      value = {...value, 'sourceDuration': previousDuration};
    }
    if (field == 'session' && isHanimeWatch(source, page)) {
      final author = _storedArtist(value);
      final previousAuthor = sameIdentity ? _storedArtist(previous) : '';
      final known = author.isNotEmpty ? author : previousAuthor;
      if (known.isNotEmpty) value = {...value, 'creatorName': known};
      if (author.isNotEmpty) {
        // Reopening the existing Download sheet can also fill a retained
        // item's missing author. It does not submit a transfer.
        try {
          await _retainArtist(prefs, source, page, author);
        } catch (_) {
          // Optional display metadata must not block the session snapshot.
        }
      }
    }
    rows.removeWhere((row) => row['key'] == key);
    rows.insert(0, {...?old, 'key': key, 'source': source, field: value});
    var kept = rows.take(32).toList();
    while (jsonEncode(kept).length > 4000000 && kept.isNotEmpty)
      kept.removeLast();
    final encoded = jsonEncode(kept);
    if (prefs.getString(storageKey) == encoded) return;
    if (!await prefs.setString(storageKey, encoded)) {
      throw StateError('Downloaded public details were not saved');
    }
    changes.value++;
  });
  static Future<void> saveItem(String source, ApiVideoItem item) => _save(
    source,
    item.detailUrl,
    'item',
    {...publicItem(item), 'sourceDisplayName': _sourceName(source)},
  );

  /// Bulk, local-only projection for exact public work identities. A module's
  /// same numeric ID or an arbitrary episode never grants another work's tags.
  static Future<Map<String, ApiVideoItem>> readKnownItems(
    String source,
    Iterable<ApiVideoItem> items,
  ) async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> legacyRows = [];
    try {
      legacyRows = _decode(prefs.getString(storageKey));
    } catch (_) {}
    final legacy = {
      for (final row in legacyRows)
        if (row['source'] == source) row['key']: row,
    };
    late final works = () {
      try {
        return _map(_durable(prefs)['works']).values.whereType<Map>().toList();
      } catch (_) {
        return const <Map>[];
      }
    }();
    final result = <String, ApiVideoItem>{};
    for (final item in items) {
      final page = videoPublicPage(item.detailUrl);
      if (page == null || item.id.isEmpty) continue;
      final raw = legacy[_key(source, item.detailUrl)]?['item'];
      if (raw is Map && raw['id'] == item.id) {
        final candidate = ApiVideoItem.fromJson(
          Map<String, dynamic>.from(raw),
          home: item.detailUrl,
        );
        if (videoPublicPage(candidate.detailUrl) == page) {
          result[item.id] = candidate;
          continue;
        }
      }
      for (final work in works) {
        final namespace = work['moduleNamespace'];
        if (namespace is! String ||
            namespace.isNotEmpty && !item.id.startsWith('$namespace:') ||
            work['source'] != source ||
            work['canonicalWorkId'] != '$source|$namespace|${item.id}|$page')
          continue;
        result[item.id] = ApiVideoItem.fromJson({
          ...item.toLibraryJson(),
          'description': work['description'],
          'genres':
              (work['tags'] is List
                      ? (work['tags'] as List).whereType<String>()
                      : const <String>[])
                  .join(' / '),
          'typeName': work['typeName'],
          'year': work['year'],
          'area': work['region'],
          'language': work['language'],
          'writers': work['writers'],
          'actors': work['actors'],
          'directors': work['directors'],
        }, home: item.detailUrl);
        break;
      }
    }
    return result;
  }

  static Future<ApiVideoItem?> readItem(String source, Uri watch) async {
    await _tail;
    final rows = _decode(
      (await SharedPreferences.getInstance()).getString(storageKey),
    );
    final value = rows
        .where((row) => row['key'] == _key(source, watch))
        .firstOrNull?['item'];
    return value is Map
        ? ApiVideoItem.fromJson(Map<String, dynamic>.from(value), home: watch)
        : null;
  }

  static Future<void> saveSession(
    String source,
    NativePlaybackSession session,
  ) => _save(source, session.watchUrl, 'session', {
    'title': session.title,
    'sourceDisplayName': _sourceName(source),
    'watchUrl': session.watchUrl.toString(),
    'description': session.description,
    if (_sessionArtist(source, session) case final artist
        when artist.isNotEmpty)
      'creatorName': artist,
    'tags': session.tags,
    if (isHanimeWatch(source, session.watchUrl))
      'literalTagLabels': [
        for (final tag in session.tags)
          if (session.tagTargets[tag] case final target?
              when target.origin == session.watchUrl.origin &&
                  target.path == '/search' &&
                  target.queryParametersAll['tags[]']?.contains(tag) == true)
            tag,
      ],
    'releaseDate': session.metadata.publishedDate,
    'sourceDuration': session.metadata.duration,
    'cover': _cover(session.coverUrl),
    'episodes': [
      for (final card in session.episodes)
        if (videoPlaybackIdentity(card.watchUrl) == card.watchUrl)
          {
            'title': card.title,
            'watchUrl': card.watchUrl.toString(),
            'episodeLabel': card.episodeLabel,
            'cover': _cover(card.coverUrl),
          },
    ],
  });
  static Future<NativePlaybackSession> enrichSession(
    String source,
    NativePlaybackSession local,
  ) async {
    await _tail;
    final rows = _decode(
      (await SharedPreferences.getInstance()).getString(storageKey),
    );
    final value = rows
        .where((row) => row['key'] == _key(source, local.watchUrl))
        .firstOrNull?['session'];
    if (value is! Map) return local;
    return NativePlaybackSession(
      title: value['title'] as String? ?? local.title,
      watchUrl: local.watchUrl,
      sources: local.sources,
      description: value['description'] as String? ?? '',
      tags: (value['tags'] as List? ?? const []).whereType<String>().toList(),
      coverUrl: Uri.tryParse(value['cover'] as String? ?? ''),
      episodes: [
        for (final raw in (value['episodes'] as List? ?? const []))
          if (raw is Map)
            if (Uri.tryParse('${raw['watchUrl']}') case final Uri watch)
              if (videoPlaybackIdentity(watch) == watch)
                NativeVideoCard(
                  title: '${raw['title']}',
                  watchUrl: watch,
                  coverUrl: Uri.tryParse(raw['cover'] as String? ?? ''),
                  episodeLabel: raw['episodeLabel'] as String? ?? '',
                ),
      ],
    );
  }

  static Future<void> removeSource(
    String source, {
    required Future<void> Function(Map<String, dynamic>) beforeWrite,
  }) => _serial(() async {
    final prefs = await SharedPreferences.getInstance(),
        original = prefs.getString(storageKey);
    final rows = _decode(original),
        kept = rows.where((row) => row['source'] != source).toList();
    if (kept.length == rows.length) return;
    final next = jsonEncode(kept);
    await beforeWrite({storageKey: next});
    if (prefs.getString(storageKey) != original ||
        !await prefs.setString(storageKey, next)) {
      throw StateError('Downloaded details changed during removal');
    }
  });
}
