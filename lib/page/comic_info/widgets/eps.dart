import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/comic_info/cubit/episode_download_status_cubit.dart';
import 'package:zephyr/page/comic_info/cubit/episode_selection_cubit.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

import 'package:zephyr/config/router/router.gr.dart';

/// 繁简转换缓存：convertChineseForDisplay 底层走 Rust FFI（opencc），
/// 每行每次 build 都调一次太贵。这里按「模式|原文」缓存，切换设置后自然 miss。
final Map<String, String> _displayTitleCache = {};

String _cachedConvertForDisplay(String text) {
  if (text.isEmpty) return text;
  final mode = globalSetting.chineseConvertMode;
  if (mode == ChineseConvertMode.off) return text;
  final key = '${mode.name}|$text';
  final cached = _displayTitleCache[key];
  if (cached != null) return cached;
  final converted = convertChineseForDisplay(text);
  if (_displayTitleCache.length > 2000) _displayTitleCache.clear();
  _displayTitleCache[key] = converted;
  return converted;
}

class EpButtonWidget extends StatelessWidget {
  static const double fixedHeight = 56;

  final Ep doc;
  final DownloadChapter chapter;
  final EpisodeDownloadController controller;
  final dynamic allInfo;
  final int epsLength;
  final int? legacyReadPage;

  /// 组内总数：分组显示时行号按组内 1..N 编排（null 时回退 [epsLength]，
  /// 即今天的扁平行为）。阅读器用的总章节数仍走 [epsLength]。
  final int? displayTotal;
  final ComicEntryType type;
  final String comicId;
  final String from;
  final int index;
  final bool isReversed;

  /// 下载是否被插件允许；为 false 时仍显示下载按钮，点击后由调用方弹出禁用原因。
  final bool downloadAllowed;
  final String downloadDisabledReason;
  final VoidCallback? onAction;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEnterSelect;

  const EpButtonWidget({
    super.key,
    required this.doc,
    required this.chapter,
    required this.controller,
    required this.allInfo,
    required this.epsLength,
    this.legacyReadPage,
    this.displayTotal,
    required this.type,
    required this.comicId,
    required this.from,
    required this.index,
    required this.isReversed,
    this.downloadAllowed = true,
    this.downloadDisabledReason = '',
    this.onAction,
    this.onToggleSelect,
    this.onEnterSelect,
  });

  @override
  Widget build(BuildContext context) {
    // 不依赖插件返回的 order，按当前显示位置自主计算序号：
    // 正序从上到下 1..N，倒序从下到上 N..1。分组时 N 为组内总数。
    // 标题只在外层 build 算一次（带 FFI 缓存），选中/进度变化只走内层监听，
    final numberTotal = displayTotal ?? epsLength;
    final displayNumber = isReversed ? numberTotal - index : index + 1;
    final rawTitle = doc.name.trim();
    final title = rawTitle.isEmpty
        ? t.comicInfo.episodeFallback(index: displayNumber)
        : _cachedConvertForDisplay(rawTitle);
    final episodeLabel = t.comicInfo.episodeLabel(index: displayNumber);

    // RepaintBoundary 把进度动画隔离在行内；选中态只听 selectionCubit，
    // 下载进度 tick 不会重建标题/背景整行。
    return RepaintBoundary(
      child: BlocBuilder<EpisodeSelectionCubit, int>(
        bloc: controller.selectionCubit,
        builder: (context, _) {
          final selectionMode = controller.selectionMode;
          final selected = controller.selectedIds.contains(chapter.id);
          final colorScheme = context.theme.colorScheme;
          return InkWell(
            onTap: selectionMode ? onToggleSelect : () => _openRead(context),
            onLongPress: onEnterSelect,
            child: Container(
              width: double.infinity,
              height: fixedHeight,
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : context.theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        width: 1,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 6,
                      top: 6,
                      bottom: 6,
                    ),
                    child: Row(
                      children: [
                        if (selectionMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? colorScheme.primary
                                  : context.textColor.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                        Text(
                          episodeLabel,
                          style: context.theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.textColor,
                            ),
                          ),
                        ),
                        _EpisodeReadingStatus(
                          source: from,
                          comicId: comicId,
                          chapterId: chapter.id,
                          legacyPage: legacyReadPage,
                        ),
                        _EpisodeTrailing(
                          controller: controller,
                          chapter: chapter,
                          downloadAllowed: downloadAllowed,
                          onAction: onAction,
                        ),
                      ],
                    ),
                  ),
                  if (downloadAllowed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: EpisodeDownloadProgress(
                        controller: controller,
                        chapter: chapter,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openRead(BuildContext context) {
    final chapter = const DownloadChapterAdapter().fromEp(doc);
    final chapterExtern = Map<String, dynamic>.from(doc.extern);
    context.pushRoute(
      ComicReadRoute(
        comicInfo: allInfo,
        comicId: comicId,
        type: type,
        order: chapter.order,
        chapterId: chapter.id,
        requestId: chapter.effectiveRequestId,
        storageChapterId: chapter.storageId ?? '',
        logicalKey: chapter.id,
        chapterExtern: enrichEpisodeChapterExtern(doc, chapterExtern),
        epsNumber: epsLength,
        from: from,
        stringSelectCubit: context.read<StringSelectCubit>(),
      ),
    );
  }

  ChapterExtern enrichEpisodeChapterExtern(
    Ep episode,
    ChapterExtern chapterExtern,
  ) {
    return chapterExtern;
  }
}

/// 真实任务进度只重绘当前章，覆盖在行内底边，不改变行高或滚动位置。
class EpisodeDownloadProgress extends StatelessWidget {
  const EpisodeDownloadProgress({
    super.key,
    required this.controller,
    required this.chapter,
  });

  final EpisodeDownloadController controller;
  final DownloadChapter chapter;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        EpisodeDownloadStatusCubit,
        EpisodeDownloadStatusState,
        (ChapterDownloadStatus, double?)
      >(
        bloc: controller.statusCubit,
        selector: (state) =>
            (state.statusOf(chapter), state.progressOf(chapter)),
        builder: (context, selected) {
          final status = selected.$1;
          if (status != ChapterDownloadStatus.downloading &&
              status != ChapterDownloadStatus.downloaded) {
            return const SizedBox.shrink();
          }
          final progress = status == ChapterDownloadStatus.downloaded
              ? 1.0
              : selected.$2;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
            child: TickerMode(
              enabled: !MediaQuery.disableAnimationsOf(context),
              child: LinearProgressIndicator(
                key: ValueKey('chapter-progress:${chapter.id}'),
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: context.theme.colorScheme.primary,
                semanticsLabel: status == ChapterDownloadStatus.downloaded
                    ? t.download.completed
                    : t.download.downloading,
              ),
            ),
          );
        },
      );
}

class _EpisodeReadingStatus extends StatelessWidget {
  const _EpisodeReadingStatus({
    required this.source,
    required this.comicId,
    required this.chapterId,
    required this.legacyPage,
  });

  final String source, comicId, chapterId;
  final int? legacyPage;

  @override
  Widget build(BuildContext context) {
    final reading = ComicChapterReadingProgress.instance;
    return ListenableBuilder(
      listenable: reading.changes,
      builder: (context, _) {
        final progress = reading.lookup(source, comicId, [chapterId]);
        final page = progress?.pageIndex ?? legacyPage;
        if (page == null || page < 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .28,
            ),
            child: Text(
              progress?.completed == true
                  ? t.comicInfo.chapterReadComplete
                  : t.comicInfo.readProgressPage(page: page),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// 右侧动作按任务状态更新，保留至少44pt触控区。
class _EpisodeTrailing extends StatelessWidget {
  const _EpisodeTrailing({
    required this.controller,
    required this.chapter,
    required this.downloadAllowed,
    this.onAction,
  });

  final EpisodeDownloadController controller;
  final DownloadChapter chapter;
  final bool downloadAllowed;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (!downloadAllowed) {
      // 不允许下载时显示静态按钮，无需订阅，点击后由 onAction 弹出禁用原因。
      return _slot(context, const Icon(Icons.download_outlined, size: 20));
    }
    // 进度由行底部单独监听；动作图标不随每次进度更新重建。
    return BlocSelector<
      EpisodeDownloadStatusCubit,
      EpisodeDownloadStatusState,
      ChapterDownloadStatus
    >(
      bloc: controller.statusCubit,
      selector: (state) => state.statusOf(chapter),
      builder: (context, status) {
        switch (status) {
          case ChapterDownloadStatus.notDownloaded:
            return _slot(
              context,
              const Icon(Icons.download_outlined, size: 20),
            );
          case ChapterDownloadStatus.queued:
            return _slot(context, const Icon(Icons.hourglass_empty, size: 20));
          case ChapterDownloadStatus.downloading:
            return _slot(
              context,
              const Icon(Icons.close, size: 20),
              label: t.download.cancelTask,
            );
          case ChapterDownloadStatus.failed:
            return _slot(
              context,
              Icon(
                Icons.refresh,
                size: 20,
                color: context.theme.colorScheme.error,
              ),
              label: t.common.retry,
            );
          case ChapterDownloadStatus.downloaded:
            return _slot(
              context,
              Icon(
                Icons.check_circle,
                size: 20,
                color: context.theme.colorScheme.primary,
              ),
            );
        }
      },
    );
  }

  Widget _slot(BuildContext context, Widget child, {String? label}) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        key: ValueKey('chapter-download-action:${chapter.id}'),
        onTap: onAction,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(dimension: 44, child: Center(child: child)),
      ),
    );
  }
}
