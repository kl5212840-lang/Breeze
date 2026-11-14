import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/widgets/collection_record_time.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// Presentation of a committed reading record, never a parsed status string.
class ComicReadingProgress {
  ComicReadingProgress(UnifiedComicHistory history, String comicTitle)
    : chapter = history.chapterOrder > 0 ? history.chapterOrder : null,
      // The reader stores display-page + 1, including double-page layouts.
      page = history.pageIndex > 1 ? history.pageIndex - 1 : null,
      chapterTitle = history.chapterTitle.trim() == comicTitle.trim()
          ? ''
          : history.chapterTitle.trim(),
      readAt = formatComicRecordTimestamp(history.lastReadAt.toIso8601String());

  final int? chapter, page;
  final String chapterTitle, readAt;

  String get label {
    if (chapter != null && page != null) {
      return t.comicInfo.readProgressChapterPage(
        chapter: chapter.toString(),
        page: page.toString(),
      );
    }
    if (chapter != null) {
      return t.comicInfo.readProgressChapter(chapter: chapter.toString());
    }
    if (chapterTitle.isNotEmpty) {
      final position = page == null
          ? ''
          : t.comicInfo.readProgressPage(page: page.toString());
      return position.isEmpty ? chapterTitle : '$chapterTitle · $position';
    }
    if (page != null)
      return t.comicInfo.readProgressPage(page: page.toString());
    return t.comicInfo.readHistory;
  }
}

class ComicReadingHistoryBanner extends StatefulWidget {
  const ComicReadingHistoryBanner({
    super.key,
    required this.source,
    required this.comicId,
    required this.comicTitle,
    this.onContinueRead,
  });
  final String source, comicId, comicTitle;
  final VoidCallback? onContinueRead;

  @override
  State<ComicReadingHistoryBanner> createState() =>
      _ComicReadingHistoryBannerState();
}

class _ComicReadingHistoryBannerState extends State<ComicReadingHistoryBanner> {
  Query<UnifiedComicHistory>? _query;
  StreamSubscription<List<Type>>? _changes;
  UnifiedComicHistory? _history;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _observe();
  }

  @override
  void didUpdateWidget(covariant ComicReadingHistoryBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.comicId != widget.comicId) {
      _stop();
      _observe();
    }
  }

  void _observe() {
    final generation = ++_generation;
    final query = objectbox.unifiedHistoryBox
        .query(
          UnifiedComicHistory_.uniqueKey.equals(
            '${widget.source.trim()}:${widget.comicId}',
          ),
        )
        .build();
    _query = query;
    _history = query.findFirst();
    // ObjectBox observes the entity type; the indexed query and equality gate
    // restrict displayed results/rebuilds to this source and comic.
    _changes = objectbox.store.entityChanges.listen((types) {
      if (!mounted ||
          generation != _generation ||
          !types.contains(UnifiedComicHistory))
        return;
      final next = query.findFirst();
      final old = _history;
      if (old?.chapterOrder == next?.chapterOrder &&
          old?.pageIndex == next?.pageIndex &&
          old?.chapterTitle == next?.chapterTitle &&
          old?.lastReadAt == next?.lastReadAt &&
          old?.deleted == next?.deleted)
        return;
      setState(() => _history = next);
    });
  }

  void _stop() {
    _generation++;
    final changes = _changes;
    _changes = null;
    if (changes != null) unawaited(changes.cancel());
    _query?.close();
    _query = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    if (history == null || history.deleted) return const SizedBox.shrink();
    return ComicReadingHistoryCard(
      progress: ComicReadingProgress(history, widget.comicTitle),
      onContinueRead: widget.onContinueRead,
    );
  }
}

class ComicReadingHistoryCard extends StatelessWidget {
  const ComicReadingHistoryCard({
    super.key,
    required this.progress,
    this.onContinueRead,
  });
  final ComicReadingProgress progress;
  final VoidCallback? onContinueRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TouchHoverIntent(
        identity: 'comic-reading-history',
        builder: (context, hover) => Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const ValueKey('comic-reading-history.open'),
            onTap: onContinueRead,
            hoverColor: hover.hoverColor(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          progress.label,
                          key: const ValueKey('comic-reading-history.progress'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (progress.readAt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.comicEntry.lastReadAt(time: progress.readAt),
                            key: const ValueKey('comic-reading-history.time'),
                            style: collectionRecordTimeStyle(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onContinueRead != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
