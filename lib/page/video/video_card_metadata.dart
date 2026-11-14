import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';

/// The same source duration badge is used by catalog, shelf and detail cards.
/// Episode selection stays in the opposite corner and has independent meaning.
class VideoCardCover extends StatelessWidget {
  const VideoCardCover({
    super.key,
    required this.url,
    required this.referrer,
    required this.metadata,
    this.current = false,
  });
  final String url;
  final Uri referrer;
  final VideoPublicMetadata metadata;
  final bool current;
  @override
  Widget build(BuildContext context) => VideoCoverOverlay(
    durationText: metadata.duration ?? '',
    child: Stack(
      fit: StackFit.expand,
      children: [
        VideoThumbnail(url: url, referrer: referrer),
        if (current)
          PositionedDirectional(
            top: 4,
            start: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  t.videoPlayback.currentEpisode,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class VideoCardFacts extends StatelessWidget {
  const VideoCardFacts({
    super.key,
    required this.metadata,
    this.creator = '',
    this.fallback = '',
    this.showCreator = true,
  });
  final VideoPublicMetadata metadata;
  final String creator, fallback;
  final bool showCreator;
  @override
  Widget build(BuildContext context) {
    final byline = metadata.byline(
      creator: creator,
      fallback: fallback,
      showCreator: showCreator,
    );
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final statistics = [
      if (metadata.viewsLabel case final value?)
        t.videoMetadata.views(value: value),
      if (metadata.ratingLabel case final value?)
        t.videoMetadata.rating(value: value),
      if (metadata.positiveVotes case final value?)
        t.videoMetadata.positiveVotes(count: value),
      if (metadata.totalVotes case final value?)
        t.videoMetadata.totalVotes(count: value),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (byline.isNotEmpty)
          Tooltip(
            message: byline,
            child: Text(
              byline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        if (statistics.isNotEmpty)
          Tooltip(
            message: statistics,
            child: Text(
              statistics,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}
