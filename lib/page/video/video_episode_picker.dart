import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_ranges.dart';

class VideoEpisodePicker extends StatefulWidget {
  const VideoEpisodePicker({
    super.key,
    required this.sequence,
    required this.current,
    required this.onChanged,
    this.onSelected,
  });
  final VideoEpisodeSequence sequence;
  final Uri current;
  final ValueChanged<VideoEpisodeSequence> onChanged;
  final ValueChanged<NativeVideoCard>? onSelected;
  @override
  State<VideoEpisodePicker> createState() => _VideoEpisodePickerState();
}

class _VideoEpisodePickerState extends State<VideoEpisodePicker> {
  VideoEpisodeSequence? _draft;
  int? _range;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Widget _section(Widget child) {
    final side =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: side ? 10 : 0),
      child: Material(
        color: side
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: .84)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(side ? 14 : 0),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = _draft ?? widget.sequence;
    final displayItems =
        _draft == null && queue.order == VideoEpisodeOrder.descending
        ? queue.sorted(VideoEpisodeOrder.ascending).items
        : queue.items;
    final currentIndex = displayItems.indexWhere(
      (card) => card.isCurrent(widget.current),
    );
    final range =
        (_range ??
                (currentIndex < 0 ? 0 : currentIndex ~/ videoEpisodeRangeSize))
            .clamp(
              0,
              queue.items.isEmpty
                  ? 0
                  : (queue.items.length - 1) ~/ videoEpisodeRangeSize,
            );
    final start = queue.items.length > videoEpisodeRangeSize && _draft == null
        ? range * videoEpisodeRangeSize
        : 0;
    final count = queue.items.length > videoEpisodeRangeSize && _draft == null
        ? math.min(videoEpisodeRangeSize, queue.items.length - start)
        : queue.items.length;
    final visibleItems = displayItems.skip(start).take(count).toList();
    if (_draft == null && queue.order == VideoEpisodeOrder.descending) {
      visibleItems.setAll(0, visibleItems.reversed.toList());
    }
    final orderControl = SettingChoiceTile<VideoEpisodeOrder>(
      key: const ValueKey('episode-queue.order'),
      title: t.bookshelf.sort,
      value: !queue.numbered && queue.order != VideoEpisodeOrder.manual
          ? VideoEpisodeOrder.site
          : queue.order,
      items: {
        for (final order in VideoEpisodeOrder.values)
          if (queue.numbered ||
              order == VideoEpisodeOrder.site ||
              order == VideoEpisodeOrder.manual)
            order: switch (order) {
              VideoEpisodeOrder.ascending => t.videoPlayback.episodeAscending,
              VideoEpisodeOrder.descending => t.videoPlayback.episodeDescending,
              VideoEpisodeOrder.site => t.videoPlayback.episodeSite,
              VideoEpisodeOrder.manual => t.videoPlayback.episodeManual,
            },
      },
      onChanged: (order) {
        _range = range;
        _resetScroll();
        if (order == VideoEpisodeOrder.manual) {
          setState(() => _draft = widget.sequence.sorted(order));
        } else {
          setState(() => _draft = null);
          widget.onChanged(widget.sequence.sorted(order));
        }
      },
    );
    final children = <Widget>[
      _section(orderControl),
      if (_draft != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            t.videoPlayback.episodeManualNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (_draft == null && queue.items.length > videoEpisodeRangeSize)
        VideoEpisodeRanges(
          count: queue.items.length,
          index: range,
          onChanged: (value) {
            _resetScroll();
            setState(() => _range = value);
          },
        ),
      Flexible(
        child: _section(
          _draft == null
              ? ListView.builder(
                  key: const ValueKey('episode-queue.list'),
                  controller: _scrollController,
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: count,
                  itemBuilder: (_, i) => _row(visibleItems[i], start + i),
                )
              : ReorderableListView.builder(
                  key: const ValueKey('episode-queue.list'),
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  itemCount: queue.items.length,
                  onReorderItem: (a, b) => setState(
                    () => _draft = _draft!.moved(a, b > a ? b + 1 : b),
                  ),
                  itemBuilder: (_, i) => _row(queue.items[i], i, editing: true),
                ),
        ),
      ),
      if (_draft != null)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _draft = null),
                  child: Text(t.common.cancel),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final next = _draft!;
                    setState(() => _draft = null);
                    widget.onChanged(next);
                  },
                  child: Text(t.videoPlayback.episodeApplyOrder),
                ),
              ],
            ),
          ),
        ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact =
            bounds.hasBoundedHeight &&
            bounds.maxHeight < MediaQuery.textScalerOf(context).scale(16) * 16;
        if (compact)
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children)
                  if (child is Flexible)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(160, bounds.maxHeight * .65),
                      ),
                      child: child.child,
                    )
                  else
                    child,
              ],
            ),
          );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _row(
    NativeVideoCard card,
    int index, {
    bool editing = false,
  }) => ListTile(
    key: ValueKey('episode-queue.${card.watchUrl}'),
    title: Text(
      card.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: card.isCurrent(widget.current)
            ? Theme.of(context).colorScheme.primary
            : null,
        fontWeight: card.isCurrent(widget.current)
            ? FontWeight.w600
            : FontWeight.w500,
      ),
    ),
    selected: card.isCurrent(widget.current),
    subtitle:
        card.episodeLabel.isNotEmpty && card.episodeLabel != card.title.trim()
        ? Text(card.episodeLabel, maxLines: 1, overflow: TextOverflow.ellipsis)
        : null,
    trailing: editing
        ? ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: t.videoPlayback.episodeReorder,
              customSemanticsActions: {
                if (index > 0)
                  CustomSemanticsAction(
                    label: t.videoPlayback.episodeMoveUp,
                  ): () =>
                      setState(() => _draft = _draft!.moved(index, index - 1)),
                if (index < _draft!.items.length - 1)
                  CustomSemanticsAction(
                    label: t.videoPlayback.episodeMoveDown,
                  ): () =>
                      setState(() => _draft = _draft!.moved(index, index + 2)),
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
          )
        : card.isCurrent(widget.current)
        ? const Icon(Icons.play_arrow_rounded)
        : null,
    onTap:
        editing || card.isCurrent(widget.current) || widget.onSelected == null
        ? null
        : () => widget.onSelected!(card),
  );
}
