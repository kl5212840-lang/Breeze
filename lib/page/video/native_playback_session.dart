import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/page/video/video_creator_reference.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';

/// Transient route return state, independent of persisted history/autoplay.
typedef NativePlaybackReturnState = ({Duration position, bool playing});

class NativePlaybackSource {
  const NativePlaybackSource({
    required this.url,
    required this.label,
    required this.headers,
  });

  final Uri url;
  final String label;
  final Map<String, String> headers;
}

class NativeVideoCard {
  const NativeVideoCard({
    required this.title,
    required this.watchUrl,
    required this.coverUrl,
    this.episodeLabel = '',
    this.metadata = const VideoPublicMetadata(),
    this.creator,
    this.subtitle = '',
  });

  final VideoPublicMetadata metadata;
  final VideoCreatorReference? creator;
  final String subtitle;
  final String episodeLabel;
  bool isCurrent(Uri page) =>
      watchUrl.host == page.host &&
      watchUrl.queryParameters['v'] == page.queryParameters['v'];

  /// Only an explicit episode or special-part token in the actual title.
  /// Bare numbers, video IDs and the card's list position are not evidence.
  static String labelFromTitle(String title) {
    final numbered = RegExp(
      r'第\s*[0-9０-９〇零一二两三四五六七八九十百]{1,6}\s*[集話话]|(?:\bEpisode\s*|\bEp\.?\s*)[0-9]{1,3}(?![0-9.])',
      caseSensitive: false,
    ).allMatches(title).toList();
    if (numbered.length == 1) {
      final match = numbered.single;
      if (!RegExp(
        r'^\s*(?:[-–~&]|至|到|and\b)',
        caseSensitive: false,
      ).hasMatch(title.substring(match.end))) {
        return match.group(0)!;
      }
    }
    if (numbered.isNotEmpty) return '';
    return RegExp(
          r'番外篇?|特別篇|特别篇|特典|上篇|中篇|下篇|預告|预告|\b(?:OVA|OAD|SP|Special|PV)\b',
          caseSensitive: false,
        ).firstMatch(title)?.group(0) ??
        '';
  }

  final String title;
  final Uri watchUrl;
  final Uri? coverUrl;
}

class NativePlaybackSession {
  const NativePlaybackSession({
    required this.title,
    required this.watchUrl,
    required this.sources,
    required this.description,
    required this.tags,
    this.coverUrl,
    this.episodes = const [],
    this.related = const [],
    this.creatorName = '',
    this.creatorUrl,
    this.creator,
    this.uploader,
    this.tagTargets = const {},
    this.metadata = const VideoPublicMetadata(),
  });

  final String title;
  final Uri watchUrl;
  final List<NativePlaybackSource> sources;
  final String description;
  final List<String> tags;
  final Uri? coverUrl;
  final List<NativeVideoCard> episodes;
  final List<NativeVideoCard> related;
  final String creatorName;
  final Uri? creatorUrl;
  final VideoCreatorReference? creator;
  final VideoCreatorReference? uploader;
  final Map<String, Uri> tagTargets;
  final VideoPublicMetadata metadata;

  static NativePlaybackSession fromPluginResponse(
    Map<String, dynamic> response, {
    required Uri watchUrl,
    Map<String, dynamic>? detailResponse,
    bool allowEmptySources = false,
  }) {
    if (watchUrl.scheme != 'https') {
      throw const FormatException('Invalid watch URL');
    }
    final data = asJsonMap(response['data']);
    final detail = asJsonMap(detailResponse?['data']);
    final creator = VideoCreatorReference.fromWire(
      asJsonMap(detail['creator']),
      watchUrl,
    );
    final uploader = VideoCreatorReference.fromWire(
      asJsonMap(detail['uploader']),
      watchUrl,
      role: 'uploader',
    );
    Uri? coverUrl;
    final parsedCover = Uri.tryParse(detail['coverUrl']?.toString() ?? '');
    if (parsedCover?.scheme == 'https' &&
        parsedCover?.host.isNotEmpty == true) {
      coverUrl = parsedCover;
    }
    List<NativeVideoCard> cards(String field) {
      final items = <NativeVideoCard>[];
      final seen = <Uri>{};
      for (final raw in asJsonList(detail[field]).take(100)) {
        final card = asJsonMap(raw);
        final title = card['title']?.toString().trim() ?? '';
        final uri = Uri.tryParse(card['watchUrl']?.toString() ?? '');
        if (title.isEmpty ||
            uri?.scheme != 'https' ||
            uri?.host != watchUrl.host ||
            uri?.userInfo.isNotEmpty == true ||
            (uri?.hasPort == true && uri?.port != 443) ||
            uri?.path != '/watch' ||
            !RegExp(r'^\d+$').hasMatch(uri?.queryParameters['v'] ?? '') ||
            !seen.add(uri!)) {
          continue;
        }
        final poster = Uri.tryParse(card['coverUrl']?.toString() ?? '');
        items.add(
          NativeVideoCard(
            title: title,
            watchUrl: uri,
            metadata: VideoPublicMetadata.fromWire(card),
            creator: VideoCreatorReference.fromWire({
              'name': card['creatorName'] ?? '',
              'profileUrl': card['creatorProfileUrl'],
              'nameSearchUrl': card['creatorNameSearchUrl'],
              'url': card['creatorUrl'],
            }, watchUrl),
            subtitle: card['subtitle'] is String
                ? card['subtitle'] as String
                : '',
            episodeLabel: field == 'episodes'
                ? NativeVideoCard.labelFromTitle(title)
                : '',
            coverUrl:
                poster?.scheme == 'https' && poster?.host.isNotEmpty == true
                ? poster
                : null,
          ),
        );
      }
      return List.unmodifiable(items);
    }

    final title = data['title']?.toString().trim() ?? '';
    final description = data['description']?.toString().trim() ?? '';
    final tags = asJsonList(data['tags'])
        .take(80)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final tagTargets = <String, Uri>{};
    for (final entry in asJsonMap(detail['tagTargets']).entries.take(80)) {
      final target = Uri.tryParse(entry.value?.toString() ?? '');
      if (target?.scheme == 'https' &&
          target?.host == watchUrl.host &&
          target?.userInfo.isEmpty == true &&
          (target?.hasPort != true || target?.port == 443) &&
          target?.path == '/search') {
        tagTargets[entry.key] = target!;
      }
    }
    final rawSources = asJsonList(data['sources']);
    final sources = <NativePlaybackSource>[];
    final seen = <String>{};
    for (final raw in rawSources.take(8)) {
      final item = asJsonMap(raw);
      final uri = Uri.tryParse(item['url']?.toString() ?? '');
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      if (!seen.add(uri.toString())) continue;
      final rawHeaders = asJsonMap(item['headers']);
      final headers = <String, String>{};
      for (final key in const ['Referer', 'Origin', 'User-Agent']) {
        final value = rawHeaders[key]?.toString() ?? '';
        if (value.isEmpty || value.contains('\n') || value.contains('\r')) {
          continue;
        }
        if (key == 'Referer' || key == 'Origin') {
          final headerUri = Uri.tryParse(value);
          if (headerUri == null ||
              headerUri.scheme != 'https' ||
              headerUri.host != watchUrl.host) {
            continue;
          }
        }
        headers[key] = value;
      }
      sources.add(
        NativePlaybackSource(
          url: uri,
          label: item['quality']?.toString().trim().isNotEmpty == true
              ? item['quality'].toString().trim()
              : 'Auto',
          headers: headers,
        ),
      );
    }
    if (sources.isEmpty && !allowEmptySources) {
      throw const FormatException('No playable HTTPS source');
    }
    return NativePlaybackSession(
      title: title.isEmpty ? 'Video' : title,
      watchUrl: watchUrl,
      sources: sources,
      description: description.length > 4000
          ? description.substring(0, 4000)
          : description,
      tags: tags,
      tagTargets: Map.unmodifiable(tagTargets),
      coverUrl: coverUrl,
      episodes: cards('episodes'),
      related: cards('related'),
      metadata: VideoPublicMetadata.fromWire(detail),
      // The artist and uploader remain distinct, including unresolved profiles.
      creator: creator,
      uploader: uploader,
      creatorName: creator?.name ?? '',
      creatorUrl: creator?.profileUrl,
    );
  }

  /// Keep a valid detail page visible while its media URL is unavailable.
  /// The player then offers a bounded refresh and the original website.
  static NativePlaybackSession fromDetailResponse(
    Map<String, dynamic> detailResponse, {
    required Uri watchUrl,
  }) => fromPluginResponse(
    {
      'data': {...asJsonMap(detailResponse['data']), 'sources': const []},
    },
    watchUrl: watchUrl,
    detailResponse: detailResponse,
    allowEmptySources: true,
  );
}
