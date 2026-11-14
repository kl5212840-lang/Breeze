import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/cubit/episode_download_status_cubit.dart';
import 'package:zephyr/page/comic_info/widgets/chapter_download_selection.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/video/video_episode_ranges.dart';

/// Selection draft only. No task is written until the explicit submit action.
class ChapterDownloadPicker extends StatefulWidget {
  const ChapterDownloadPicker({
    super.key,
    required this.controller,
    required this.owner,
    required this.chapters,
    required this.title,
  });
  final EpisodeDownloadController controller;
  final Object owner;
  final List<DownloadChapter> chapters;
  final String title;
  @override
  State<ChapterDownloadPicker> createState() => _ChapterDownloadPickerState();
}

class _ChapterDownloadPickerState extends State<ChapterDownloadPicker> {
  late final selection = ChapterDownloadSelection(widget.chapters);
  final from = TextEditingController(), to = TextEditingController();
  StreamSubscription<EpisodeDownloadStatusState>? changes;
  late EpisodeDownloadStatusState previousStatus;
  Set<String> eligible = {};
  bool range = false, rangeInvalid = false, submitting = false;
  int chapterRange = 0;
  String? error;
  bool get current => widget.controller.ownsSelection(widget.owner);
  Iterable<DownloadChapter> get currentRange => selection.chapters
      .skip(chapterRange * videoEpisodeRangeSize)
      .take(videoEpisodeRangeSize);
  Set<String> get currentEligibleIds => currentRange
      .map((chapter) => chapter.id)
      .where(eligible.contains)
      .toSet();
  @override
  void initState() {
    super.initState();
    previousStatus = widget.controller.statusCubit.state;
    _readEligible();
    changes = widget.controller.statusCubit.stream.listen((next) {
      final previous = previousStatus;
      previousStatus = next;
      // Progress alone does not rebuild the chapter list or its selection.
      final same =
          setEquals(previous.downloadedIds, next.downloadedIds) &&
          previous.taskSnaps.length == next.taskSnaps.length &&
          next.taskSnaps.entries.every((entry) {
            final before = previous.taskSnaps[entry.key];
            return before != null &&
                before.isDownloading == entry.value.isDownloading &&
                before.isFailed == entry.value.isFailed;
          });
      if (mounted && (!same || !current)) setState(_readEligible);
    });
  }

  void _readEligible() {
    eligible = current
        ? widget.controller
              .downloadableOf(selection.chapters)
              .map((c) => c.id)
              .toSet()
        : {};
    selection.retainEligible(eligible);
  }

  @override
  void dispose() {
    unawaited(changes?.cancel());
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting || !current || selection.selectedIds.isEmpty) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final accepted = await widget.controller.submitSelection(
        context,
        selection.selected,
        owner: widget.owner,
      );
      if (!mounted) return;
      if (accepted) {
        showInfoToast(t.download.taskStarted);
        if (ModalRoute.of(context)?.isCurrent == true)
          Navigator.of(context).pop(true);
      } else
        setState(() {
          _readEligible();
          error = current
              ? t.download.selectChaptersPrompt
              : t.common.loadingFailed;
        });
    } catch (_) {
      if (mounted) setState(() => error = t.common.loadingFailed);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.download.batchChapters,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('chapter-batch.close'),
              tooltip: t.common.close,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      Flexible(
        child: CustomScrollView(
          key: const ValueKey('chapter-batch.scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.download.rangeHint(count: selection.chapters.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        TextButton(
                          key: const ValueKey('chapter-batch.all'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: submitting || currentEligibleIds.isEmpty
                              ? null
                              : () => setState(() {
                                  if (currentEligibleIds.every(
                                    selection.selectedIds.contains,
                                  )) {
                                    selection.deselectAll(
                                      currentRange,
                                      eligible,
                                    );
                                  } else {
                                    selection.selectAll(currentRange, eligible);
                                  }
                                }),
                          child: Text(
                            selection.chapters.length > videoEpisodeRangeSize
                                ? (currentEligibleIds.isNotEmpty &&
                                          currentEligibleIds.every(
                                            selection.selectedIds.contains,
                                          )
                                      ? t.videoPlayback.deselectCurrentRange
                                      : t.videoPlayback.selectCurrentRange)
                                : (currentEligibleIds.isNotEmpty &&
                                          currentEligibleIds.every(
                                            selection.selectedIds.contains,
                                          )
                                      ? t.bookshelf.deselectAll
                                      : t.common.selectAll),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('chapter-batch.clear'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: submitting || selection.selectedIds.isEmpty
                              ? null
                              : () => setState(selection.clear),
                          child: Text(t.videoPlayback.clearAllSelections),
                        ),
                        TextButton.icon(
                          key: const ValueKey('chapter-batch.range'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: submitting
                              ? null
                              : () => setState(() => range = !range),
                          icon: Icon(
                            range ? Icons.expand_less : Icons.expand_more,
                          ),
                          label: Text(t.download.chapterRange),
                        ),
                      ],
                    ),
                    if (range) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final fieldWidth =
                              width < 360 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      18
                              ? width
                              : (width - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                  key: const ValueKey('chapter-batch.from'),
                                  controller: from,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  enabled: !submitting,
                                  decoration: InputDecoration(
                                    labelText: t.download.rangeStart,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                  key: const ValueKey('chapter-batch.to'),
                                  controller: to,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  enabled: !submitting,
                                  decoration: InputDecoration(
                                    labelText: t.download.rangeEnd,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (rangeInvalid)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t.download.rangeInvalid(
                              count: selection.chapters.length,
                            ),
                            key: const ValueKey('chapter-batch.range-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const ValueKey('chapter-batch.apply'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          onPressed: submitting
                              ? null
                              : () {
                                  setState(
                                    () => rangeInvalid = !selection.applyRange(
                                      from.text,
                                      to.text,
                                      eligible: eligible,
                                    ),
                                  );
                                  if (!rangeInvalid)
                                    FocusScope.of(context).unfocus();
                                },
                          child: Text(t.videoPlayback.addRange),
                        ),
                      ),
                    ],
                    if (error != null)
                      Text(
                        error!,
                        key: const ValueKey('chapter-batch.error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (selection.chapters.length > videoEpisodeRangeSize)
              SliverToBoxAdapter(
                child: VideoEpisodeRanges(
                  count: selection.chapters.length,
                  index: chapterRange,
                  onChanged: (value) => setState(() => chapterRange = value),
                ),
              ),
            SliverList.builder(
              itemCount:
                  (selection.chapters.length -
                          chapterRange * videoEpisodeRangeSize)
                      .clamp(0, videoEpisodeRangeSize),
              itemBuilder: (context, localIndex) {
                final index = chapterRange * videoEpisodeRangeSize + localIndex;
                final chapter = selection.chapters[index],
                    status = widget.controller.statusOf(chapter);
                final description = [
                  if (chapter.groupTitle.trim().isNotEmpty) chapter.groupTitle,
                  if (status == ChapterDownloadStatus.downloaded)
                    t.download.completed,
                  if (status == ChapterDownloadStatus.queued)
                    t.download.statusWaiting,
                  if (status == ChapterDownloadStatus.downloading)
                    t.download.downloading,
                  if (status == ChapterDownloadStatus.failed)
                    t.download.notificationFailedTitle,
                ].join(' · ');
                return CheckboxListTile(
                  key: ValueKey('chapter-batch.row.$index'),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selection.selectedIds.contains(chapter.id),
                  onChanged:
                      submitting || !current || !eligible.contains(chapter.id)
                      ? null
                      : (_) => setState(
                          () =>
                              selection.toggle(chapter.id, eligible: eligible),
                        ),
                  title: Text(
                    '${index + 1}. ${chapter.displayName.isEmpty ? t.comicInfo.episodeFallback(index: index + 1) : chapter.displayName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: description.isEmpty
                      ? null
                      : Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                );
              },
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.bookshelf.selectedCount(count: selection.selectedIds.length),
              key: const ValueKey('chapter-batch.count'),
            ),
            const SizedBox(height: 6),
            FilledButton(
              key: const ValueKey('chapter-batch.submit'),
              onPressed: submitting || !current || selection.selectedIds.isEmpty
                  ? null
                  : submit,
              child: Text(
                t.download.downloadSelected(
                  count: selection.selectedIds.length,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
