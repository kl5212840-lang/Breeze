import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
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
  });
  final String id, parentId, name;
  factory ApiVideoCategory.fromJson(Map<String, dynamic> json) =>
      ApiVideoCategory(
        id: apiVideoText(json['id'], 30),
        parentId: apiVideoText(json['parentId'], 30),
        name: apiVideoText(json['name'], 100),
      );
}

class ApiVideoEpisode {
  const ApiVideoEpisode({
    required this.id,
    required this.title,
    required this.url,
    required this.watchUrl,
  });
  final String id, title;
  final Uri url, watchUrl;
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

class ApiVideoItem {
  const ApiVideoItem({
    required this.id,
    required this.title,
    required this.detailUrl,
    this.coverUrl,
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
    this.sourceRating,
    this.sourceRatingCount,
    this.lines = const [],
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
  final int plannedEpisodes;
  final bool finished;
  final int? sourceViews, sourceRatingCount;
  final double? sourceRating;
  final double? doubanScore;
  final List<ApiVideoLine> lines;

  factory ApiVideoItem.fromJson(
    Map<String, dynamic> json, {
    required Uri home,
  }) {
    final id = apiVideoText(json['id'], 30),
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
            url == null ||
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
    final doubanId = apiVideoText(json['doubanId'], 20);
    final doubanScore = double.tryParse('${json['doubanScore']}');
    final description = html.parseFragment(
      apiVideoText(json['description'], 20000),
    );
    for (final node in description.querySelectorAll('script,style,iframe')) {
      node.remove();
    }
    return ApiVideoItem(
      id: id,
      title: title,
      detailUrl: detail,
      coverUrl: apiVideoHttps(json['coverUrl']),
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
      finished: json['finished'] == true,
      sourceViews: apiVideoInt(json['sourceViews']) > 0
          ? apiVideoInt(json['sourceViews'])
          : null,
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
      lines: List.unmodifiable(lines),
    );
  }

  /// Public metadata only. Media URLs and browser/account state never enter
  /// favorites or cloud snapshots.
  Map<String, Object?> toLibraryJson() => {
    'id': id,
    'title': title,
    'detailUrl': detailUrl.toString(),
    'coverUrl': coverUrl?.toString(),
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
    'sourceRating': sourceRating,
    'sourceRatingCount': sourceRatingCount,
  };

  List<String> get summary =>
      [year, area, typeName].where((x) => x.isNotEmpty).toList();

  bool get canFollow =>
      lines.isNotEmpty &&
      (lines.first.episodes.length > 1 ||
          plannedEpisodes > 1 ||
          remarks.contains('更新'));

  Set<String> get episodeKeys => {
    if (lines.isNotEmpty)
      for (final e in lines.first.episodes) jsonEncode([lines.first.id, e.id]),
  };

  NativePlaybackSession session(String lineId, String episodeId) {
    final line = lines.where((x) => x.id == lineId).firstOrNull;
    final episode = line?.episodes.where((x) => x.id == episodeId).firstOrNull;
    if (line == null || episode == null) {
      throw const FormatException('Episode is unavailable');
    }
    return NativePlaybackSession(
      title: line.episodes.length > 1 ? '$title · ${episode.title}' : title,
      watchUrl: episode.watchUrl,
      coverUrl: coverUrl,
      description: description,
      tags: const [],
      metadata: VideoPublicMetadata(viewCount: sourceViews),
      sources: [
        NativePlaybackSource(
          url: episode.url,
          label: line.label,
          headers: const {},
        ),
      ],
      episodes: [
        for (final e in line.episodes)
          NativeVideoCard(
            title: e.title,
            watchUrl: e.watchUrl,
            coverUrl: coverUrl,
            episodeLabel: e.title,
          ),
      ],
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
  });
  final List<ApiVideoItem> items;
  final List<ApiVideoCategory> categories;
  final int page, pageCount, total;
  final Map<String, dynamic>? nextCursor;
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
    for (final raw in asJsonList(json['categories']).take(300)) {
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
      nextCursor: json['nextCursor'] is Map
          ? asJsonMap(json['nextCursor'])
          : null,
    );
  }
}
