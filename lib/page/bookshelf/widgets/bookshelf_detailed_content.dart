import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/widgets/collection_record_time.dart';

/// pageIndex is a stored, zero-based reading position. Chapter order from a
/// source is not necessarily an ordinal and must never manufacture a label.
String shelfReadingPosition(String title, String chapter, int pageIndex) {
  String normalized(String value) => value.replaceAll(RegExp(r'\s+'), '');
  final name = chapter.trim();
  if (name.isNotEmpty && normalized(name) != normalized(title)) {
    return t.bookshelf.readTo(chapter: name);
  }
  return pageIndex < 0 ? '' : t.bookshelf.readToPage(page: pageIndex + 1);
}

/// One information hierarchy for local comic/video records. Uses the public
/// metadata already in each record; this row never starts a network request.
class BookshelfDetailedContent extends StatelessWidget {
  const BookshelfDetailedContent({
    super.key,
    required this.cover,
    required this.title,
    required this.source,
    this.progress = '',
    this.time = '',
    this.metadata = '',
    this.description = '',
    this.statistics = '',
  });
  final Widget cover;
  final String title, source, progress, time, metadata, description, statistics;

  static const coverWidth = 80.0;
  static const coverHeight =
      coverWidth / BookshelfContentLayout.coverAspectRatio;
  static double contentHeight(BuildContext context) {
    final theme = Theme.of(context), scale = MediaQuery.textScalerOf(context);
    final body = theme.textTheme.bodySmall?.fontSize ?? 12;
    if (scale.scale(body) <= body * 1.2) return coverHeight;
    return math.max(
      coverHeight,
      scale.scale(theme.textTheme.titleSmall?.fontSize ?? 14) * 2.6 +
          scale.scale(body) * 6.75 +
          14,
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: coverWidth, height: coverHeight, child: cover),
      const SizedBox(width: BookshelfContentLayout.spacing),
      Expanded(
        child: BookshelfDetailedCaption(
          title: title,
          source: source,
          metadata: metadata,
          description: description,
          statistics: statistics,
          progress: progress,
          time: time,
        ),
      ),
    ],
  );
}

class BookshelfDetailedCaption extends StatelessWidget {
  const BookshelfDetailedCaption({
    super.key,
    required this.title,
    required this.source,
    this.progress = '',
    this.time = '',
    this.metadata = '',
    this.description = '',
    this.statistics = '',
  });
  final String title, source, progress, time, metadata, description, statistics;

  static final _closingMarks = RegExp(r'[ \t]*[+＋)）\]］】」』》〉]+$');

  String get _displayTitle {
    final match = _closingMarks.firstMatch(title);
    if (match == null || match.start == 0) return title;
    // Keep a terminal bracket or plus with the preceding text at a line break.
    const joiner = '\u2060';
    return title.substring(0, match.start) +
        joiner +
        title.substring(match.start).split('').join(joiner);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    final displayTime = time
        .replaceFirst('上次观看：', '观看：')
        .replaceFirst('上次阅读：', '阅读：')
        .replaceFirst('最后阅读：', '阅读：')
        .replaceFirst('Last watched: ', 'Watched: ')
        .replaceFirst('Last read: ', 'Read: ');
    final displayTitle = _displayTitle;
    final heading = theme.textTheme.titleSmall?.copyWith(height: 1.3);
    final summary = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    final distinctSummary =
        summary == title.replaceAll(RegExp(r'\s+'), ' ').trim() ? '' : summary;
    final minimumHeight = BookshelfDetailedContent.contentHeight(context);
    final timeStyle = collectionRecordTimeStyle(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double measured(String text, TextStyle? style, [int? lines]) {
          if (text.isEmpty) return 0;
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: lines,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth);
          final value = painter.height;
          painter.dispose();
          return value;
        }

        final information = [
          source,
          metadata,
        ].where((value) => value.isNotEmpty).join(' · ');
        final top =
            measured(displayTitle, heading, 2) +
            (information.isEmpty ? 0 : 3 + measured(information, secondary, 1));
        final bottom =
            measured(progress, secondary, 1) +
            measured(displayTime, timeStyle) +
            (progress.isNotEmpty && time.isNotEmpty ? 3 : 0);
        // Reserve the full time at the actual width. Narrow, large-text
        // captions can wrap the date and clock onto more than two lines.
        final height = displayTime.isEmpty
            ? minimumHeight
            : math.max(minimumHeight, top + bottom + 4);
        final available = height - top - bottom - 4;
        final summaryHeight = measured(distinctSummary, secondary, 1) + 4;
        final showSummary =
            distinctSummary.isNotEmpty && summaryHeight <= available;
        final statisticsHeight = measured(statistics, secondary, 1) + 4;
        final showStatistics =
            statistics.isNotEmpty &&
            statisticsHeight <= available - (showSummary ? summaryHeight : 0);
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                semanticsLabel: displayTitle == title ? null : title,
                key: const ValueKey('shelf-detail.title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: heading,
              ),
              if (information.isNotEmpty) ...[
                const SizedBox(height: 3),
                Semantics(
                  label: information,
                  excludeSemantics: true,
                  child: Text(
                    information,
                    key: const ValueKey('shelf-detail.metadata'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ),
              ],
              if (showSummary) ...[
                const SizedBox(height: 4),
                Text(
                  distinctSummary,
                  key: const ValueKey('shelf-detail.description'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ],
              if (showStatistics) ...[
                const SizedBox(height: 4),
                Text(
                  statistics,
                  key: const ValueKey('shelf-detail.statistics'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ],
              if (bottom > 0) ...[
                const Spacer(),
                if (progress.isNotEmpty)
                  Text(
                    progress,
                    key: const ValueKey('shelf-detail.progress'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                if (progress.isNotEmpty && time.isNotEmpty)
                  const SizedBox(height: 3),
                if (time.isNotEmpty)
                  Semantics(
                    label: time,
                    excludeSemantics: true,
                    child: Text(
                      displayTime,
                      key: const ValueKey('shelf-detail.time'),
                      softWrap: true,
                      style: timeStyle,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
