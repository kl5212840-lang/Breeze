import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart'
    show
        RenderSliverList,
        RenderSliverToBoxAdapter,
        ScrollCacheExtent,
        SliverMultiBoxAdaptorParentData;
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/widgets/collection_record_time.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

enum ApiVideoView { grid, list }

class ApiVideoCollection extends StatefulWidget {
  const ApiVideoCollection({
    super.key,
    required this.items,
    required this.mode,
    required this.onOpen,
    required this.storageKey,
    this.onLongPress,
    this.selected = const {},
    this.selecting = false,
    this.editing = false,
    this.editLabel = '',
    this.onNearEnd,
    this.footer,
    this.badges = const {},
    this.header,
    this.compactAnime = false,
    this.loading = false,
    this.emptyState,
    this.loadDetail,
    this.detailsActive = true,
    this.onDetailLoaded,
    this.detailGeneration,
    this.imageRefreshToken = 0,
    this.retryMissingCoverDetailsOnRefresh = true,
    this.recordNoteBuilder,
    this.contentBottomPadding = 24,
    this.sourceByItem = const {},
    this.gridColumns,
    this.gridItemExtent,
    this.listItemExtent,
    this.listTileBuilder,
    this.listSeparatorHeight = 1,
    this.gridMainAxisSpacing = 0,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.gridCaptionBuilder,
    this.leadingItems = const [],
    this.leadingListExtent = 132,
    this.posterRadius = 10,
    this.posterAspectRatio = 2 / 3,
  }) : assert(posterAspectRatio > 0);
  final List<ApiVideoItem> items;
  final ApiVideoView mode;
  final ValueChanged<ApiVideoItem> onOpen;
  final ValueChanged<ApiVideoItem>? onLongPress;
  final Set<String> selected;
  final bool selecting;
  final bool editing;
  final String editLabel;
  final String storageKey;
  final VoidCallback? onNearEnd;
  final Widget? footer;
  final Map<String, String> badges;
  final Widget? header;
  final bool compactAnime;
  final bool loading;
  final double contentBottomPadding;
  final Map<String, String> sourceByItem;
  final Widget? emptyState;
  final int? gridColumns;
  final double? gridItemExtent;
  final double gridMainAxisSpacing, leadingListExtent, posterRadius;
  final double posterAspectRatio;
  final EdgeInsets contentPadding;
  final Widget Function(BuildContext, ApiVideoItem)? gridCaptionBuilder;
  final List<Widget> leadingItems;

  /// Called for visible detailed rows and grid cards without a source poster.
  final Future<ApiVideoItem> Function(ApiVideoItem)? loadDetail;

  /// IndexedStack pages must stop requesting details while hidden.
  final bool detailsActive;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;

  /// Invalidates detail rows without replacing the collection's scroll host.
  final Object? detailGeneration;

  /// Successful explicit refresh retries only failed posters.
  final double? listItemExtent;
  final double listSeparatorHeight;
  final Widget Function(BuildContext, ApiVideoItem)? listTileBuilder;
  final int imageRefreshToken;

  /// Local record refresh may retry failed images without reloading details.
  final bool retryMissingCoverDetailsOnRefresh;

  /// Local record notes use the original snapshot even after details refresh.
  final String Function(ApiVideoItem)? recordNoteBuilder;
  @override
  State<ApiVideoCollection> createState() => _ApiVideoCollectionState();
}

class _ApiVideoCollectionState extends State<ApiVideoCollection> {
  final _gridCoverLoads = <String, Future<ApiVideoItem>>{};

  Future<ApiVideoItem> _loadGridCover(ApiVideoItem item) {
    final key = '${item.id}|${item.detailUrl}';
    final existing = _gridCoverLoads.remove(key);
    if (existing != null) return _gridCoverLoads[key] = existing;
    final result = widget.loadDetail!(item);
    _gridCoverLoads[key] = result;
    while (_gridCoverLoads.length > 128) {
      _gridCoverLoads.remove(_gridCoverLoads.keys.first);
    }
    return result;
  }

  final _scroll = ScrollController();
  final _headerSliverKey = GlobalKey();
  final _listSliverKey = GlobalKey();
  SliverObserverController? _anchorObserver;
  ({int index, double fraction})? _pendingAnchor;
  ({int index, double fraction})? _activeAnchor;
  int _anchorRevision = 0;
  int _columns = 2;
  double _extent = 300;
  double _stride = 300;

  double get _headerExtent {
    final sliver = _headerSliverKey.currentContext?.findRenderObject();
    return sliver is RenderSliverToBoxAdapter
        ? sliver.geometry?.scrollExtent ?? 0
        : 0;
  }

  void _invalidateAnchor({bool stopScroll = false}) {
    _anchorRevision++;
    _pendingAnchor = null;
    _activeAnchor = null;
    // The observer may be searching for an offscreen variable-height row.
    // Its next scroll step must not drive the replacement layout.
    final observer = _anchorObserver;
    if (observer == null) return;
    observer.controller = null;
    _anchorObserver = null;
    if (stopScroll && _scroll.hasClients) _scroll.jumpTo(_scroll.offset);
  }

  void _settleAnchorAfterLayout(int revision) {
    final binding = WidgetsBinding.instance;
    // A jump updates pixels before the destination sliver is laid out. Until
    // then a second layout switch still needs the original work anchor.
    binding.addPostFrameCallback((_) {
      if (mounted && revision == _anchorRevision) _activeAnchor = null;
    });
    binding.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 500) {
        widget.onNearEnd?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ApiVideoCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailGeneration != widget.detailGeneration ||
        (widget.retryMissingCoverDetailsOnRefresh &&
            oldWidget.imageRefreshToken != widget.imageRefreshToken)) {
      _gridCoverLoads.clear();
    }
    if (oldWidget.storageKey != widget.storageKey) {
      _invalidateAnchor();
      return;
    }
    if (oldWidget.mode != widget.mode) {
      final previousAnchor = _activeAnchor ?? _pendingAnchor;
      _invalidateAnchor(stopScroll: true);
      if (previousAnchor != null) {
        _pendingAnchor = previousAnchor;
        return;
      }
      if (!_scroll.hasClients ||
          oldWidget.items.isEmpty && oldWidget.leadingItems.isEmpty) {
        return;
      }
      final offset =
          _scroll.offset - _headerExtent - oldWidget.contentPadding.top;
      // Before the works, the scroll offset belongs to the toolbar and its
      // padding. The existing position keeps it in the same place.
      if (offset <= 0) return;
      final prefix =
          oldWidget.leadingItems.length * oldWidget.leadingListExtent;
      if (oldWidget.mode == ApiVideoView.grid) {
        _pendingAnchor = (
          index: (offset / _stride).floor() * _columns,
          fraction: (offset % _stride) / _stride,
        );
      } else if (offset < prefix) {
        _pendingAnchor = (
          index: (offset / oldWidget.leadingListExtent).floor(),
          fraction:
              (offset % oldWidget.leadingListExtent) /
              oldWidget.leadingListExtent,
        );
      } else {
        final sliver = _listSliverKey.currentContext?.findRenderObject();
        if (sliver is RenderSliverList && sliver.firstChild != null) {
          var child = sliver.firstChild;
          while (child != null) {
            final data = child.parentData! as SliverMultiBoxAdaptorParentData;
            final start = data.layoutOffset ?? 0, height = child.size.height;
            if (start + height >
                sliver.constraints.scrollOffset + precisionErrorTolerance) {
              _pendingAnchor = (
                index: oldWidget.leadingItems.length + (data.index ?? 0),
                fraction: height > 0
                    ? ((sliver.constraints.scrollOffset - start) / height)
                          .clamp(0.0, 1.0)
                    : 0,
              );
              break;
            }
            child = sliver.childAfter(child);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _invalidateAnchor();
    _scroll.dispose();
    super.dispose();
  }

  double _titleExtent = 0, _summaryExtent = 0, _remarksExtent = 0;
  bool _summarySlot = false, _remarksSlot = false;

  double _textExtent(BuildContext context, TextStyle? style, {int lines = 1}) {
    final painter = TextPainter(
      text: TextSpan(text: List.filled(lines, 'M').join('\n'), style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context);
      final grid = widget.mode == ApiVideoView.grid;
      _columns = grid ? 3 : 1;
      if (grid && widget.gridColumns != null) {
        _columns = widget.gridColumns!;
      }
      final width =
          (constraints.maxWidth -
              widget.contentPadding.horizontal -
              (_columns - 1) * 12) /
          _columns;
      final theme = Theme.of(context);
      _titleExtent =
          _textExtent(
            context,
            theme.textTheme.titleSmall?.copyWith(height: 1.3),
            lines: 2,
          ) +
          2;
      _summaryExtent = _textExtent(context, theme.textTheme.bodySmall);
      _remarksExtent = _textExtent(context, theme.textTheme.labelSmall);
      _summarySlot =
          widget.loading ||
          widget.items.any(
            (item) =>
                item.summary.isNotEmpty ||
                widget.compactAnime && item.remarks.isNotEmpty,
          );
      _remarksSlot =
          !widget.compactAnime &&
          widget.items.any((item) => item.remarks.isNotEmpty);
      _extent = grid
          ? width / widget.posterAspectRatio +
                8 +
                _titleExtent +
                (_summarySlot ? 3 + _summaryExtent : 0) +
                (_remarksSlot ? 3 + _remarksExtent : 0) +
                12
          : 34 + scale.scale(16) * 9.5;
      if (!grid && widget.listItemExtent != null) {
        _extent = widget.listItemExtent!;
      }
      if (grid && widget.gridItemExtent != null) {
        _extent = widget.gridItemExtent!;
      }
      _stride = _extent + (grid ? widget.gridMainAxisSpacing : 0);
      if (_pendingAnchor case final anchor?) {
        _pendingAnchor = null;
        _activeAnchor = anchor;
        final revision = _anchorRevision;
        bool isCurrent() =>
            mounted && _scroll.hasClients && revision == _anchorRevision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isCurrent()) return;
          final count = widget.items.length + widget.leadingItems.length;
          if (count == 0) {
            _activeAnchor = null;
            return;
          }
          final index = anchor.index.clamp(0, count - 1);
          if (!grid &&
              widget.listItemExtent == null &&
              index >= widget.leadingItems.length) {
            final sliver = _listSliverKey.currentContext;
            if (sliver != null) {
              final observer = _anchorObserver = SliverObserverController(
                controller: _scroll,
              );
              unawaited(
                observer
                    .jumpTo(
                      index: index - widget.leadingItems.length,
                      sliverContext: sliver,
                      onPrepareScrollToIndex: (position) async {
                        if (isCurrent()) {
                          _scroll.jumpTo(position.calculateTargetLayoutOffset);
                        }
                        return true;
                      },
                    )
                    .whenComplete(() {
                      if (identical(_anchorObserver, observer)) {
                        _anchorObserver = null;
                        _settleAnchorAfterLayout(revision);
                      }
                    }),
              );
            } else {
              _activeAnchor = null;
            }
            return;
          }
          final target = grid
              ? (index ~/ _columns + anchor.fraction) * _stride
              : index < widget.leadingItems.length
              ? (index + anchor.fraction) * widget.leadingListExtent
              : widget.leadingItems.length * widget.leadingListExtent +
                    (index - widget.leadingItems.length + anchor.fraction) *
                        _extent;
          _scroll.jumpTo(
            (_headerExtent + widget.contentPadding.top + target).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
          _settleAnchorAfterLayout(revision);
        });
      }
      final skeleton = widget.loading && widget.items.isEmpty;
      final hydrateGrid =
          grid &&
          widget.loadDetail != null &&
          widget.items.any((item) => item.coverUrl == null);
      Widget tile(int index) {
        if (skeleton) return _skeleton(context, width, grid, index);
        if (grid && index < widget.leadingItems.length) {
          return widget.leadingItems[index];
        }
        final initial =
            widget.items[index - (grid ? widget.leadingItems.length : 0)];
        Widget content(
          ApiVideoItem item, {
          _DetailRowStatus? status,
          VoidCallback? retry,
        }) => Semantics(
          selected: widget.selecting ? widget.selected.contains(item.id) : null,
          button: widget.editing ? true : null,
          label: widget.editing
              ? '${widget.editLabel.isEmpty ? t.videoSource.manage : widget.editLabel} · ${item.title}'
              : null,
          excludeSemantics: widget.editing,
          onTap: widget.editing ? () => widget.onOpen(item) : null,
          child: CollectionPressFeedback(
            enabled: widget.onLongPress != null,
            child: InkWell(
              key: ValueKey('api-video.${item.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onOpen(item),
              onLongPress: widget.onLongPress == null
                  ? null
                  : () => widget.onLongPress!(item),
              child: grid
                  ? _gridTile(context, initial, width, poster: item)
                  : _listTile(
                      context,
                      item,
                      initial: initial,
                      availableWidth: width,
                      status: status,
                      retry: retry,
                    ),
            ),
          ),
        );
        if (widget.loadDetail != null && (!grid || initial.coverUrl == null)) {
          return _ApiVideoDetailedRow(
            key: ValueKey(
              'api-detail.${widget.storageKey}.${initial.id}.'
              '${widget.detailGeneration}.${grid && widget.retryMissingCoverDetailsOnRefresh ? widget.imageRefreshToken : 0}',
            ),
            item: initial,
            active:
                widget.detailsActive &&
                (ModalRoute.isCurrentOf(context) ?? true),
            loadDetail: grid ? _loadGridCover : widget.loadDetail!,
            onDetailLoaded: widget.onDetailLoaded,
            builder: (item, status, retry) =>
                content(item, status: status, retry: retry),
          );
        }
        return content(initial);
      }

      return CustomScrollView(
        key: PageStorageKey(widget.storageKey),
        controller: _scroll,
        // Detail reads belong to visible rows, not the next offscreen page.
        scrollCacheExtent: hydrateGrid || !grid && widget.loadDetail != null
            ? const ScrollCacheExtent.pixels(0)
            : null,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (widget.header != null)
            SliverToBoxAdapter(key: _headerSliverKey, child: widget.header),
          if (!grid && widget.leadingItems.isNotEmpty)
            SliverPadding(
              padding: widget.contentPadding.copyWith(bottom: 0),
              sliver: SliverFixedExtentList(
                itemExtent: widget.leadingListExtent,
                delegate: SliverChildListDelegate([
                  for (final (index, item) in widget.leadingItems.indexed)
                    WorkListRow(
                      key: item.key == null ? null : ValueKey(item.key),
                      divided:
                          index + 1 < widget.leadingItems.length ||
                          widget.items.isNotEmpty,
                      bottomSpacing: widget.listSeparatorHeight,
                      child: item,
                    ),
                ]),
              ),
            ),
          if (widget.items.isEmpty &&
              widget.leadingItems.isEmpty &&
              !skeleton &&
              widget.emptyState != null)
            SliverFillRemaining(hasScrollBody: false, child: widget.emptyState!)
          else
            SliverPadding(
              padding: !grid && widget.leadingItems.isNotEmpty
                  ? widget.contentPadding.copyWith(top: 0)
                  : widget.contentPadding,
              sliver: grid
                  ? SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columns,
                        mainAxisExtent: _extent,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: widget.gridMainAxisSpacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => tile(index),
                        childCount: skeleton
                            ? _columns * 3
                            : widget.items.length + widget.leadingItems.length,
                      ),
                    )
                  : SliverList(
                      key: _listSliverKey,
                      delegate: SliverChildBuilderDelegate(
                        (_, index) {
                          final row = tile(index);
                          return WorkListRow(
                            key: row.key == null ? null : ValueKey(row.key),
                            divided:
                                !skeleton && index + 1 < widget.items.length,
                            bottomSpacing: widget.listSeparatorHeight,
                            child: widget.listItemExtent == null
                                ? row
                                : SizedBox(height: _extent, child: row),
                          );
                        },
                        childCount: skeleton
                            ? _columns * 3
                            : widget.items.length,
                      ),
                    ),
            ),
          if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  widget.contentBottomPadding +
                  MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      );
    },
  );

  Widget _skeleton(BuildContext context, double width, bool grid, int index) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context);
    final listPoster = _listPosterSize(width);
    Widget bar(double factor, double height) => FractionallySizedBox(
      widthFactor: factor,
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        height: height,
        child: ColoredBox(color: colors.surfaceContainerHigh),
      ),
    );
    Widget titleBars(double height) => SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: bar(.9, double.infinity)),
          const SizedBox(height: 3),
          Expanded(child: bar(.65, double.infinity)),
        ],
      ),
    );
    final posterHeight = width / widget.posterAspectRatio;
    final captionBudget = math.max(0.0, _extent - posterHeight - 8);
    final customCaption = widget.gridCaptionBuilder != null;
    final caption = customCaption
        ? SizedBox(
            height: captionBudget,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: titleBars(double.infinity)),
                const SizedBox(height: 3),
                Expanded(child: bar(.5, double.infinity)),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBars(_titleExtent),
              if (_summarySlot) ...[
                const SizedBox(height: 3),
                bar(.5, _summaryExtent),
              ],
              if (_remarksSlot) ...[
                const SizedBox(height: 3),
                bar(.5, _remarksExtent),
              ],
            ],
          );
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        key: ValueKey('api-skeleton.poster.$index'),
        color: colors.surfaceContainerHigh,
      ),
    );
    return Semantics(
      label: index == 0 ? t.common.loading : null,
      excludeSemantics: true,
      child: grid
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: width / widget.posterAspectRatio,
                  width: width,
                  child: poster,
                ),
                const SizedBox(height: 8),
                caption,
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: listPoster.width,
                    height: listPoster.height,
                    child: poster,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(.9, scale.scale(14) * 1.3),
                        const SizedBox(height: 8),
                        bar(.65, scale.scale(14) * 1.3),
                        const SizedBox(height: 8),
                        bar(.5, scale.scale(12) * 1.3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _poster(ApiVideoItem item, {bool showBadge = true}) => Stack(
    fit: StackFit.expand,
    children: [
      CollectionSelectionTint(
        selected: widget.selecting && widget.selected.contains(item.id),
        child: ApiVideoPoster(
          item: item,
          source: widget.sourceByItem[item.id],
          refreshToken: widget.imageRefreshToken,
        ),
      ),
      PositionedDirectional(
        top: CollectionSelectionMark.inset,
        end: CollectionSelectionMark.inset,
        child: CollectionSelectionMark(
          visible: widget.selecting,
          selected: widget.selected.contains(item.id),
        ),
      ),
      if (widget.editing && !widget.selecting)
        Positioned(
          top: 6,
          right: 6,
          child: ExcludeSemantics(
            child: DecoratedBox(
              key: ValueKey('api-video.edit.${item.id}'),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      if (showBadge && widget.badges[item.id] != null)
        PositionedDirectional(
          start: 6,
          end: widget.selecting
              ? CollectionSelectionMark.inset + CollectionSelectionMark.size + 6
              : widget.editing
              ? 42
              : 6,
          top: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                widget.badges[item.id]!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _gridTile(
    BuildContext context,
    ApiVideoItem item,
    double width, {
    ApiVideoItem? poster,
  }) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    if (widget.gridCaptionBuilder case final caption?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: width / widget.posterAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.posterRadius),
              child: _poster(poster ?? item, showBadge: false),
            ),
          ),
          const SizedBox(height: 8),
          caption(context, item),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: width / widget.posterAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _poster(poster ?? item),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _titleExtent,
          child: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
          ),
        ),
        if (_summarySlot) ...[
          const SizedBox(height: 3),
          SizedBox(
            height: _summaryExtent,
            child: Text(
              [
                ...item.summary,
                if (widget.compactAnime && item.remarks.isNotEmpty)
                  item.remarks,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (_remarksSlot) ...[
          const SizedBox(height: 3),
          SizedBox(
            height: _remarksExtent,
            child: Text(
              item.remarks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Size _listPosterSize(double width) {
    if (widget.posterAspectRatio <= 1) return const Size(80, 120);
    final posterWidth = math.min(width * .36, 148.0);
    return Size(posterWidth, posterWidth / widget.posterAspectRatio);
  }

  Widget _listTile(
    BuildContext context,
    ApiVideoItem item, {
    required ApiVideoItem initial,
    required double availableWidth,
    _DetailRowStatus? status,
    VoidCallback? retry,
  }) {
    if (widget.listTileBuilder case final builder?) {
      return builder(context, initial);
    }
    final theme = Theme.of(context), colors = theme.colorScheme;
    final description = status == _DetailRowStatus.ready
        ? item.description
        : initial.description;
    final posterItem = item.coverUrl != null ? item : initial;
    final poster = _listPosterSize(availableWidth);
    final recordNote = widget.recordNoteBuilder?.call(initial) ?? '';
    final summary = [
      ...item.summary,
      if (item.sourceVersion.isNotEmpty && item.sourceVersion != item.remarks)
        item.sourceVersion,
      if (recordNote.isEmpty &&
          item.remarks.isNotEmpty &&
          clockVideoDurationText(item.remarks).isEmpty)
        item.remarks,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: poster.width,
            height: poster.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _poster(posterItem),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                if (recordNote.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  CollectionRecordTimeLine(text: recordNote),
                ],
                if (description.isNotEmpty ||
                    status == _DetailRowStatus.ready ||
                    status == _DetailRowStatus.loading ||
                    status == _DetailRowStatus.failed) ...[
                  const SizedBox(height: 7),
                  SizedBox(
                    height: math.max(
                      44,
                      MediaQuery.textScalerOf(
                            context,
                          ).scale(theme.textTheme.bodySmall?.fontSize ?? 12) *
                          2.8,
                    ),
                    child: description.isNotEmpty
                        ? Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                          )
                        : status == _DetailRowStatus.loading
                        ? Semantics(
                            liveRegion: true,
                            child: Row(
                              children: [
                                if (MediaQuery.disableAnimationsOf(context))
                                  const Icon(
                                    Icons.hourglass_empty_rounded,
                                    size: 16,
                                  )
                                else
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.common.loading,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : status == _DetailRowStatus.failed
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.common.loadingFailed,
                                  maxLines: 2,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              TextButton.icon(
                                key: ValueKey('api-detail.retry.${item.id}'),
                                onPressed: retry,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: Text(t.common.retry),
                              ),
                            ],
                          )
                        : Text(
                            t.videoLibrary.noSynopsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                  ),
                ],
                if (item.sourceViews != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.sourceViewsAreClicks
                        ? t.videoLibrary.sourceClicks(count: item.sourceViews!)
                        : t.videoLibrary.sourceViews(count: item.sourceViews!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _DetailRowStatus { loading, ready, failed }

class _ApiVideoDetailedRow extends StatefulWidget {
  const _ApiVideoDetailedRow({
    super.key,
    required this.item,
    required this.active,
    required this.loadDetail,
    this.onDetailLoaded,
    required this.builder,
  });
  final ApiVideoItem item;
  final bool active;
  final Future<ApiVideoItem> Function(ApiVideoItem) loadDetail;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;
  final Widget Function(ApiVideoItem, _DetailRowStatus?, VoidCallback?) builder;
  @override
  State<_ApiVideoDetailedRow> createState() => _ApiVideoDetailedRowState();
}

class _ApiVideoDetailedRowState extends State<_ApiVideoDetailedRow> {
  ApiVideoItem? _detail;
  _DetailRowStatus? _status;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _ApiVideoDetailedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        _identity(oldWidget.item.detailUrl) !=
            _identity(widget.item.detailUrl)) {
      _epoch++;
      _detail = null;
      _status = null;
      if (widget.active) unawaited(_load());
    } else if (!widget.active && oldWidget.active) {
      _epoch++;
      if (_status == _DetailRowStatus.loading) _status = null;
    } else if (widget.active && !oldWidget.active && _status == null) {
      unawaited(_load());
    }
  }

  Uri? _identity(Uri value) =>
      videoPublicPage(value) ??
      (value.scheme == 'https' &&
              value.host.isNotEmpty &&
              value.userInfo.isEmpty &&
              (!value.hasPort || value.port == 443)
          ? Uri(scheme: 'https', host: value.host, path: value.path)
          : null);

  Future<void> _load() async {
    if (!mounted || !widget.active || _status == _DetailRowStatus.loading) {
      return;
    }
    final epoch = ++_epoch, initial = widget.item;
    setState(() => _status = _DetailRowStatus.loading);
    try {
      final detail = await widget.loadDetail(initial);
      if (!mounted || !widget.active || epoch != _epoch) return;
      final expected = _identity(initial.detailUrl);
      if (detail.id != initial.id ||
          expected == null ||
          _identity(detail.detailUrl) != expected) {
        throw StateError('detail_identity_mismatch');
      }
      setState(() {
        _detail = detail;
        _status = _DetailRowStatus.ready;
      });
      widget.onDetailLoaded?.call(detail);
    } catch (_) {
      if (mounted && widget.active && epoch == _epoch) {
        setState(() => _status = _DetailRowStatus.failed);
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    _detail ?? widget.item,
    _status,
    widget.active ? () => unawaited(_load()) : null,
  );
}

class ApiVideoPoster extends StatelessWidget {
  const ApiVideoPoster({
    super.key,
    required this.item,
    this.source,
    this.refreshToken = 0,
  });
  final ApiVideoItem item;
  final String? source;
  final int refreshToken;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => VideoCoverOverlay(
      durationText: videoCoverDurationText(
        item.sourceDuration,
        clockFallback: item.remarks,
      ),
      child: VideoThumbnail(
        source: source,
        refreshToken: refreshToken,
        url: item.coverUrl?.toString() ?? '',
        fit: item.containCover ? BoxFit.contain : BoxFit.cover,
        referrer: item.detailUrl,
        cacheWidth:
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(160, 600),
        placeholderIcon: Icons.play_arrow_rounded,
      ),
    ),
  );
}

class ApiVideoEmpty extends StatelessWidget {
  const ApiVideoEmpty({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.play_arrow_rounded,
    this.action,
    this.scrollable = false,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
    if (!scrollable) return content;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: content)],
    );
  }
}
