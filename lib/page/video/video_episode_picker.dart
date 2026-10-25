import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';

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
  @override
  Widget build(BuildContext context) {
    final queue = _draft ?? widget.sequence;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final order in VideoEpisodeOrder.values)
                ChoiceChip(
                  label: Text(switch (order) {
                    VideoEpisodeOrder.ascending =>
                      t.videoPlayback.episodeAscending,
                    VideoEpisodeOrder.descending =>
                      t.videoPlayback.episodeDescending,
                    VideoEpisodeOrder.site => t.videoPlayback.episodeSite,
                    VideoEpisodeOrder.manual => t.videoPlayback.episodeManual,
                  }),
                  selected: queue.order == order,
                  showCheckmark: false,
                  onSelected: (_) {
                    if (order == VideoEpisodeOrder.manual) {
                      setState(() => _draft = widget.sequence.sorted(order));
                    } else {
                      setState(() => _draft = null);
                      widget.onChanged(widget.sequence.sorted(order));
                    }
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            _draft != null
                ? t.videoPlayback.episodeManualNote
                : !queue.numbered &&
                      queue.order != VideoEpisodeOrder.manual &&
                      queue.order != VideoEpisodeOrder.site
                ? t.videoPlayback.episodeOrderFallback
                : t.videoPlayback.episodeSessionOrder,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: _draft == null
              ? ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: queue.items.length,
                  itemBuilder: (_, i) => _row(queue.items[i], i),
                )
              : ReorderableListView.builder(
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  itemCount: queue.items.length,
                  onReorderItem: (a, b) => setState(
                    () => _draft = _draft!.moved(a, b > a ? b + 1 : b),
                  ),
                  itemBuilder: (_, i) => _row(queue.items[i], i, editing: true),
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
      ],
    );
  }

  Widget _row(
    NativeVideoCard card,
    int index, {
    bool editing = false,
  }) => ListTile(
    key: ValueKey('episode-queue.${card.watchUrl}'),
    title: Text(card.title),
    selected: card.isCurrent(widget.current),
    subtitle:
        card.episodeLabel.isNotEmpty && card.episodeLabel != card.title.trim()
        ? Text(card.episodeLabel)
        : null,
    leading: Text(
      '${index + 1}',
      style: Theme.of(context).textTheme.labelMedium,
    ),
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
