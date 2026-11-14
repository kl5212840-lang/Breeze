import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:html/parser.dart' as html;
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/util/json/json_value.dart';

String apiVideoText(Object? raw, [int limit = 500]) {
  if (raw is! String && raw is! num) return '';
  final text = raw
      .toString()
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
      .trim();
  return text.length <= limit ? text : text.substring(0, limit);
}

int apiVideoInt(Object? raw, [int fallback = 0]) {
  final value = raw is int ? raw : int.tryParse('$raw');
  return value != null && value >= 0 && value <= 9007199254740991
      ? value
      : fallback;
}

Uri? apiVideoHttps(Object? raw, {Uri? origin}) {
  final uri = Uri.tryParse(apiVideoText(raw, 4096));
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  if (origin != null &&
      (uri.origin != origin.origin || (uri.hasPort && uri.port != 443))) {
    return null;
  }
  return uri;
}

class ApiVideoCategory {
  const ApiVideoCategory({
    required this.id,
    required this.parentId,
    required this.name,
    this.selectable = true,
    this.coverUrl,
    this.description = '',
  });
  final String id, parentId, name;
  final bool selectable;
  final Uri? coverUrl;
  final String description;
  factory ApiVideoCategory.fromJson(Map<String, dynamic> json) =>
      ApiVideoCategory(
        id: apiVideoText(json['id'], 180),
        parentId: apiVideoText(json['parentId'], 180),
        name: apiVideoText(json['name'], 100),
        selectable: json['selectable'] != false,
        coverUrl: apiVideoHttps(json['coverUrl']),
        description: apiVideoText(json['description'], 1500),
      );
}

/// Source capabilities describe verified contracts, rather than CMS defaults.
/// Omitted values retain protocol 1 behavior for installed plugins.
class ApiVideoCapabilities {
  const ApiVideoCapabilities({
    this.search = 'full',
    this.year = true,
    this.recent = true,
    this.searchHint = '',
    this.searchNotice = '',
    this.browserCatalog = false,
    this.browserDetail = false,
    this.yearOnSearch = true,
    this.browserPaths = const [],
    this.browserItemPrefix = '',
    this.yearTypePrefixes = const [],
    this.filtersOnSearch = true,
    this.presentation = 'library',
    this.siteAccount = false,
    this.sourceSort = false,
    this.searchPath = '',
    this.searchParameter = 'wd',
    this.rawHlsRecovery = false,
    this.detailFromSnapshot = false,
    this.itemNamespace = '',
    this.posterAspectRatio = 2 / 3,
  });
  final String search, searchHint, searchNotice;
  final bool year, recent;
  final bool browserCatalog, browserDetail, yearOnSearch, filtersOnSearch;
  final List<String> browserPaths;
  final String browserItemPrefix;
  final List<String> yearTypePrefixes;
  final String presentation;
  final bool siteAccount;
  final bool sourceSort;
  final bool rawHlsRecovery;

  /// Some catalogs expose complete public metadata only in their list response.
  /// Their detail/playback adapters receive the saved public item explicitly.
  final bool detailFromSnapshot;
  final String itemNamespace;
  final double posterAspectRatio;
  final String searchPath, searchParameter;
  bool get animePresentation => presentation == 'anime';
  bool supportsYearType(String id) =>
      year && (yearTypePrefixes.isEmpty || yearTypePrefixes.any(id.startsWith));
  bool get canSearch => search != 'none';

  factory ApiVideoCapabilities.fromJson(Map<String, dynamic> json) =>
      ApiVideoCapabilities(
        search:
            const {
              'none',
              'full',
              'suggestions',
              'website',
            }.contains(json['search'])
            ? json['search'] as String
            : 'full',
        year: json['year'] != false,
        recent: json['recent'] != false,
        searchHint: apiVideoText(json['searchHint'], 100),
        searchNotice: apiVideoText(json['searchNotice'], 300),
        browserCatalog: json['browserCatalog'] == true,
        browserDetail: json['browserDetail'] == true,
        yearOnSearch: json['yearOnSearch'] != false,
        filtersOnSearch: json['filtersOnSearch'] != false,
        presentation: json['presentation'] == 'anime' ? 'anime' : 'library',
        siteAccount: json['siteAccount'] == true,
        sourceSort: json['sourceSort'] == true,
        rawHlsRecovery: json['rawHlsRecovery'] == true,
        detailFromSnapshot: json['detailFromSnapshot'] == true,
        posterAspectRatio:
            json['posterAspectRatio'] is num &&
                (json['posterAspectRatio'] as num).isFinite &&
                (json['posterAspectRatio'] as num) >= .4 &&
                (json['posterAspectRatio'] as num) <= 2
            ? (json['posterAspectRatio'] as num).toDouble()
            : 2 / 3,
        itemNamespace:
            RegExp(
              r'^[A-Za-z0-9_-]{1,24}$',
            ).hasMatch(apiVideoText(json['itemNamespace'], 25))
            ? apiVideoText(json['itemNamespace'], 25)
            : '',
        searchPath: apiVideoText(json['searchPath'], 200),
        searchParameter: apiVideoText(json['searchParameter'], 40).isEmpty
            ? 'wd'
            : apiVideoText(json['searchParameter'], 40),
        browserPaths: List.unmodifiable(
          asJsonList(json['browserPaths'])
              .map((v) => apiVideoText(v, 100))
              .where((v) => v.startsWith('/') && v.length > 1)
              .take(20),
        ),
        browserItemPrefix: apiVideoText(json['browserItemPrefix'], 100),
        yearTypePrefixes: List.unmodifiable(
          asJsonList(
            json['yearTypePrefixes'],
          ).map((v) => apiVideoText(v, 30)).where((v) => v.isNotEmpty).take(20),
        ),
      );
}

class ApiVideoEpisode {
  const ApiVideoEpisode({
    required this.id,
    required this.title,
    required this.url,
    required this.watchUrl,
    this.webPlaybackUrls = const [],
  });
  final String id, title;
  final Uri? url;
  final Uri watchUrl;
  final List<Uri> webPlaybackUrls;
}

class ApiVideoLine {
  const ApiVideoLine({
    required this.id,
    required this.label,
    required this.episodes,
  });
  final String id, label;
  final List<ApiVideoEpisode> episodes;
}

class ApiVideoCredit {
  const ApiVideoCredit({
    required this.name,
    required this.role,
    required this.url,
  });
  final String name, role;
  final Uri url;
}

class ApiVideoItem {
  const ApiVideoItem({
    required this.id,
    required this.title,
    required this.detailUrl,
    this.coverUrl,
    this.containCover = false,
    this.description = '',
    this.typeId = '',
    this.typeName = '',
    this.remarks = '',
    this.alternateTitle = '',
    this.genres = '',
    this.writers = '',
    this.doubanId = '',
    this.doubanScore,
    this.year = '',
    this.area = '',
    this.language = '',
    this.actors = '',
    this.directors = '',
    this.updatedAt = '',
    this.releaseDate = '',
    this.plannedEpisodes = 0,
    this.finished = false,
    this.sourceViews,
    this.sourceViewsAreClicks = false,
    this.sourceRating,
    this.sourceRatingCount,
    this.sourceRatingCountConsistent = true,
    this.lines = const [],
    this.vodId = '',
    this.credits = const [],
    this.related = const [],
    this.discussionUrl,
    this.sourceCounters = const {},
    this.sourceDuration = '',
    this.sourceVersion = '',
    this.sourceAddedAt = '',
    this.sourceStatus = '',
  });

  final String id,
      title,
      description,
      typeId,
      typeName,
      remarks,
      alternateTitle,
      genres,
      writers,
      doubanId,
      year,
      area,
      language,
      actors,
      directors,
      updatedAt,
      releaseDate;
  final Uri detailUrl;
  final Uri? coverUrl;
  final bool containCover;
  final int plannedEpisodes;
  final bool finished;
  final int? sourceViews, sourceRatingCount;
  final bool sourceViewsAreClicks, sourceRatingCountConsistent;
  int? get sourceRatingDisplayCount =>
      sourceRatingCountConsistent ? sourceRatingCount : null;
  final double? sourceRating;
  final double? doubanScore;
  final List<ApiVideoLine> lines;
  final String vodId;
  final List<ApiVideoCredit> credits;
  final List<ApiVideoItem> related;
  final Uri? discussionUrl;
  final Map<String, int> sourceCounters;
  final String sourceDuration, sourceVersion, sourceAddedAt, sourceStatus;

  factory ApiVideoItem.fromJson(
    Map<String, dynamic> json, {
    required Uri home,
    bool parseRelations = true,
  }) {
    final id = apiVideoText(json['id'], 80),
        title = apiVideoText(json['title']);
    final detail = apiVideoHttps(json['detailUrl'], origin: home);
    if (id.isEmpty || title.isEmpty || detail == null) {
      throw const FormatException('Invalid video item');
    }
    final lines = <ApiVideoLine>[];
    for (final raw in asJsonList(json['lines']).take(12)) {
      final value = asJsonMap(raw), episodes = <ApiVideoEpisode>[];
      final lineId = apiVideoText(value['id'], 160),
          label = apiVideoText(value['label'], 100);
      if (lineId.isEmpty || lines.any((x) => x.id == lineId)) continue;
      for (final rawEpisode in asJsonList(value['episodes']).take(5000)) {
        final episode = asJsonMap(rawEpisode);
        final episodeId = apiVideoText(episode['id'], 300),
            title = apiVideoText(episode['title'], 200);
        final url = apiVideoHttps(episode['url']);
        final watch = apiVideoHttps(episode['watchUrl'], origin: home);
        final canonical = watch == null ? null : videoPlaybackIdentity(watch);
        if (episodeId.isEmpty ||
            title.isEmpty ||
            (url == null && episode['resolveOnPlayback'] != true) ||
            canonical == null ||
            canonical.path != detail.path ||
            canonical.queryParameters['line'] != lineId ||
            canonical.queryParameters['episode'] != episodeId ||
            episodes.any((e) => e.id == episodeId)) {
          continue;
        }
        episodes.add(
          ApiVideoEpisode(
            id: episodeId,
            title: title,
            url: url,
            watchUrl: canonical,
            webPlaybackUrls: List.unmodifiable(
              asJsonList(episode['webPlaybackUrls'])
                  .take(3)
                  .map(apiVideoHttps)
                  .whereType<Uri>()
                  .where((uri) => !uri.hasFragment)
                  .toSet(),
            ),
          ),
        );
      }
      if (episodes.isNotEmpty) {
        lines.add(
          ApiVideoLine(
            id: lineId,
            label: label.isEmpty ? lineId : label,
            episodes: List.unmodifiable(episodes),
          ),
        );
      }
    }
    final score = double.tryParse('${json['sourceRating']}');
    final sourceViews = apiVideoInt(json['sourceViews'], -1);
    final counters = asJsonMap(json['sourceCounters']);
    final sourceCounters = {
      for (final key in const ['day', 'week', 'month'])
        if (apiVideoInt(counters[key], -1) case final count when count >= 0)
          key: count,
    };
    // Installed legacy adapters used the generic sourceViews key for CMS
    // clicks. Identify only the confirmed public origins.
    final knownCms = const {
      'www.ikunzy.com',
      'www.mdzyapi.com',
    }.contains(home.host);
    final sourceViewsAreClicks =
        json['sourceViewsKind'] == 'clicks' || knownCms;
    // Legacy MacCMS adapters emitted all three default zeros but didn't
    // identify whether their window counters had been initialized.
    if (knownCms &&
        json['sourceViewsKind'] != 'clicks' &&
        sourceCounters.length == 3 &&
        sourceCounters.values.every((count) => count == 0)) {
      sourceCounters.clear();
    }
    final doubanId = apiVideoText(json['doubanId'], 20);
    final doubanScore = double.tryParse('${json['doubanScore']}');
    final description = html.parseFragment(
      apiVideoText(json['description'], 20000),
    );
    for (final node in description.querySelectorAll('script,style,iframe')) {
      node.remove();
    }
    final credits = <ApiVideoCredit>[], seenCredits = <String>{};
    for (final raw in asJsonList(json['credits']).take(100)) {
      final credit = asJsonMap(raw),
          uri = apiVideoHttps(credit['url'], origin: home);
      final name = apiVideoText(credit['name'], 100),
          role = apiVideoText(credit['role'], 30);
      if (uri != null &&
          uri.path.startsWith('/search/') &&
          name.isNotEmpty &&
          const {'voice', 'director'}.contains(role) &&
          seenCredits.add('$role|$uri')) {
        credits.add(ApiVideoCredit(name: name, role: role, url: uri));
      }
    }
    final related = <ApiVideoItem>[], seenRelated = <String>{id};
    if (parseRelations) {
      for (final raw in asJsonList(json['related']).take(24)) {
        try {
          final item = ApiVideoItem.fromJson(
            asJsonMap(raw),
            home: home,
            parseRelations: false,
          );
          if (seenRelated.add(item.id)) related.add(item);
        } on FormatException {
          // One malformed recommendation must not hide the actual work.
        }
      }
    }
    final vodId = apiVideoText(json['vodId'], 20),
        discussion = apiVideoHttps(json['discussionUrl'], origin: home);
    return ApiVideoItem(
      id: id,
      title: title,
      detailUrl: detail,
      coverUrl: apiVideoHttps(json['coverUrl']),
      containCover: json['containCover'] == true,
      description: (description.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      typeId: apiVideoText(json['typeId'], 30),
      typeName: apiVideoText(json['typeName'], 100),
      remarks: apiVideoText(json['remarks'], 200),
      alternateTitle: apiVideoText(json['alternateTitle'], 500),
      genres: apiVideoText(json['genres'], 500),
      writers: apiVideoText(json['writers'], 1000),
      doubanId: RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(doubanId)
          ? doubanId
          : '',
      doubanScore:
          RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(doubanId) &&
              doubanScore != null &&
              doubanScore > 0 &&
              doubanScore <= 10
          ? doubanScore
          : null,
      year: apiVideoText(json['year'], 100),
      area: apiVideoText(json['area'], 300),
      language: apiVideoText(json['language'], 300),
      actors: apiVideoText(json['actors'], 3000),
      directors: apiVideoText(json['directors'], 1000),
      updatedAt: apiVideoText(json['updatedAt'], 80),
      releaseDate: apiVideoText(json['releaseDate'], 80),
      plannedEpisodes: apiVideoInt(json['plannedEpisodes']),
      finished:
          json['finished'] == true ||
          !json.containsKey('finished') &&
              RegExp(
                r'完[结結]|全集|^全\s*\d+\s*[集话話]$',
              ).hasMatch(apiVideoText(json['remarks'], 200)),
      sourceViews: sourceViews >= 0 ? sourceViews : null,
      sourceViewsAreClicks: sourceViewsAreClicks,
      sourceRating:
          score != null &&
              score > 0 &&
              score <= 10 &&
              apiVideoInt(json['sourceRatingCount']) > 0
          ? score
          : null,
      sourceRatingCount: apiVideoInt(json['sourceRatingCount']) > 0
          ? apiVideoInt(json['sourceRatingCount'])
          : null,
      sourceRatingCountConsistent: json['sourceRatingCountConsistent'] != false,
      sourceCounters: Map.unmodifiable(sourceCounters),
      sourceDuration: apiVideoText(json['sourceDuration'], 200),
      sourceVersion: apiVideoText(json['sourceVersion'], 100),
      sourceAddedAt: apiVideoText(json['sourceAddedAt'], 80),
      sourceStatus: apiVideoText(json['sourceStatus'], 200),
      lines: List.unmodifiable(lines),
      vodId: RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(vodId) ? vodId : '',
      credits: List.unmodifiable(credits),
      related: List.unmodifiable(related),
      discussionUrl:
          discussion?.path == '/square.html' &&
              discussion?.queryParameters['vod_id'] == vodId &&
              vodId.isNotEmpty
          ? discussion
          : null,
    );
  }

  /// Public metadata only. Media URLs and browser/account state never enter
  /// favorites or cloud snapshots.
  Map<String, Object?> toLibraryJson() => {
    'id': id,
    'title': title,
    'detailUrl': detailUrl.toString(),
    'coverUrl': coverUrl?.toString(),
    if (containCover) 'containCover': true,
    'description': description.length > 1500
        ? description.substring(0, 1500)
        : description,
    'typeId': typeId,
    'typeName': typeName,
    'remarks': remarks,
    'alternateTitle': alternateTitle,
    'genres': genres,
    'writers': writers,
    'doubanId': doubanId,
    'doubanScore': doubanScore,
    'year': year,
    'area': area,
    'language': language,
    'actors': actors,
    'directors': directors,
    'updatedAt': updatedAt,
    'releaseDate': releaseDate,
    'plannedEpisodes': plannedEpisodes,
    'finished': finished,
    'sourceViews': sourceViews,
    if (sourceViewsAreClicks) 'sourceViewsKind': 'clicks',
    'sourceRating': sourceRating,
    'sourceRatingCount': sourceRatingCount,
    if (!sourceRatingCountConsistent) 'sourceRatingCountConsistent': false,
    'sourceCounters': sourceCounters,
    'sourceDuration': sourceDuration,
    'sourceVersion': sourceVersion,
    'sourceAddedAt': sourceAddedAt,
    'sourceStatus': sourceStatus,
  };

  bool hasSameCatalogSummary(ApiVideoItem other) =>
      description == other.description &&
      const DeepCollectionEquality().equals(
        toLibraryJson(),
        other.toLibraryJson(),
      );

  List<String> get summary =>
      [year, area, typeName].where((x) => x.isNotEmpty).toList();

  bool get canFollow =>
      lines.isNotEmpty &&
      (lines.first.episodes.length > 1 ||
          plannedEpisodes > 1 ||
          remarks.contains('更新'));

  Set<String> get episodeKeys => episodeKeysForLine();

  Set<String> episodeKeysForLine([String? lineId]) {
    final line = lineId == null
        ? lines.firstOrNull
        : lines.where((line) => line.id == lineId).firstOrNull;
    return {
      if (line != null)
        for (final episode in line.episodes) jsonEncode([line.id, episode.id]),
    };
  }

  /// Episode navigation is public metadata and must not require a resolved
  /// media URL. Some sources resolve expiring URLs only when playback starts.
  List<NativeVideoCard> episodeCards(String lineId) => [
    for (final line in lines.where((line) => line.id == lineId))
      for (final episode in line.episodes)
        NativeVideoCard(
          title: episode.title,
          watchUrl: episode.watchUrl,
          coverUrl: coverUrl,
          episodeLabel: episode.title,
        ),
  ];

  /// Do not assume source-local sequence IDs describe the same episode. Some
  /// lines include a trailer or omit an episode, shifting all following IDs.
  ApiVideoEpisode? matchingEpisode(ApiVideoLine line, ApiVideoEpisode current) {
    final currentLineId = current.watchUrl.queryParameters['line'];
    if (line.id == currentLineId) {
      return line.episodes
          .where((episode) => episode.watchUrl == current.watchUrl)
          .firstOrNull;
    }
    String normalized(String value) =>
        value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    // The display sorter can extract numbers from longer titles. For identity,
    // only equate number formats when the entire label is an episode number.
    final episodeLabel = RegExp(
      r'^(?:第[0-9０-９〇零一二两三四五六七八九十百]{1,6}[集話话]|'
      r'[0-9０-９]{1,4}[集話话]|(?:episode|ep\.?)[0-9０-９]{1,4})$',
    );
    int? episodeNumber(String label) => episodeLabel.hasMatch(label)
        ? VideoEpisodeSequence.number(label)
        : null;
    final label = normalized(current.title);
    if (label.isEmpty) return null;
    final number = episodeNumber(label);
    bool matchesLabel(ApiVideoEpisode episode) {
      final candidate = normalized(episode.title);
      return candidate == label ||
          number != null && episodeNumber(candidate) == number;
    }

    final currentLine = lines
        .where((line) => line.id == currentLineId)
        .firstOrNull;
    if (currentLine != null &&
        currentLine.episodes.where(matchesLabel).take(2).length > 1) {
      return null;
    }
    final matches = line.episodes.where(matchesLabel).take(2).toList();
    return matches.length == 1 ? matches.single : null;
  }

  NativePlaybackSession session(
    String lineId,
    String episodeId, {
    List<NativePlaybackSource>? sources,
  }) {
    final line = lines.where((x) => x.id == lineId).firstOrNull;
    final episode = line?.episodes.where((x) => x.id == episodeId).firstOrNull;
    if (line == null || episode == null) {
      throw const FormatException('Episode is unavailable');
    }
    if (sources == null && episode.url == null) {
      throw const FormatException('Playback URL must be resolved first');
    }
    return NativePlaybackSession(
      title: line.episodes.length > 1 ? '$title · ${episode.title}' : title,
      watchUrl: episode.watchUrl,
      coverUrl: coverUrl,
      description: description,
      tags: const [],
      metadata: VideoPublicMetadata(
        viewCount: sourceViewsAreClicks ? null : sourceViews,
      ),
      sources:
          sources ??
          [
            NativePlaybackSource(
              url: episode.url!,
              label: line.label,
              headers: const {},
            ),
          ],
      episodes: episodeCards(lineId),
    );
  }
}

class ApiVideoResult {
  const ApiVideoResult({
    required this.items,
    required this.categories,
    required this.page,
    required this.pageCount,
    required this.total,
    this.nextCursor,
    this.totalKnown = true,
    this.heading = '',
    this.description = '',
  });
  final List<ApiVideoItem> items;
  final List<ApiVideoCategory> categories;
  final int page, pageCount, total;
  final Map<String, dynamic>? nextCursor;
  final bool totalKnown;
  final String heading;
  final String description;
  factory ApiVideoResult.fromJson(
    Map<String, dynamic> json, {
    required Uri home,
  }) {
    final items = <ApiVideoItem>[], seen = <String>{};
    for (final value in asJsonList(json['items']).take(100)) {
      final item = ApiVideoItem.fromJson(asJsonMap(value), home: home);
      if (seen.add(item.id)) items.add(item);
    }
    final categories = <ApiVideoCategory>[], ids = <String>{};
    for (final raw in asJsonList(json['categories']).take(600)) {
      final category = ApiVideoCategory.fromJson(asJsonMap(raw));
      if (category.id.isNotEmpty &&
          category.name.isNotEmpty &&
          ids.add(category.id)) {
        categories.add(category);
      }
    }
    return ApiVideoResult(
      items: List.unmodifiable(items),
      categories: List.unmodifiable(categories),
      page: apiVideoInt(json['page'], 1),
      pageCount: apiVideoInt(json['pageCount']),
      total: apiVideoInt(json['total']),
      totalKnown: json['totalKnown'] != false,
      heading: apiVideoText(json['heading'], 100),
      description: apiVideoText(json['description'], 1500),
      nextCursor: json['nextCursor'] is Map
          ? asJsonMap(json['nextCursor'])
          : null,
    );
  }
}
