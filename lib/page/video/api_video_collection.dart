import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';

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
    this.onNearEnd,
    this.footer,
    this.badges = const {},
  });
  final List<ApiVideoItem> items;
  final ApiVideoView mode;
  final ValueChanged<ApiVideoItem> onOpen;
  final ValueChanged<ApiVideoItem>? onLongPress;
  final Set<String> selected;
  final bool selecting;
  final String storageKey;
  final VoidCallback? onNearEnd;
  final Widget? footer;
  final Map<String, String> badges;
  @override
  State<ApiVideoCollection> createState() => _ApiVideoCollectionState();
}

class _ApiVideoCollectionState extends State<ApiVideoCollection> {
  final _scroll = ScrollController();
  int _columns = 2;
  double _extent = 300;
  bool _restoreAnchor = false;
  int _anchor = 0;
  double _anchorFraction = 0;
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
    if (oldWidget.mode != widget.mode && _scroll.hasClients) {
      _anchor = (_scroll.offset / _extent).floor() * _columns;
      _anchorFraction = (_scroll.offset % _extent) / _extent;
      _restoreAnchor = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context);
      final grid = widget.mode == ApiVideoView.grid;
      _columns = grid
          ? (constraints.maxWidth / (scale.scale(14) > 23 ? 230 : 170))
                .floor()
                .clamp(2, 6)
          : 1;
      final width =
          (constraints.maxWidth - 32 - (_columns - 1) * 12) / _columns;
      _extent = grid
          ? width * 1.5 + scale.scale(14) * 6.7 + 12
          : 34 + scale.scale(16) * 9.5;
      if (_restoreAnchor) {
        _restoreAnchor = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final target = (_anchor ~/ _columns + _anchorFraction) * _extent;
          _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
        });
      }
      Widget tile(int index) {
        final item = widget.items[index];
        return Semantics(
          selected: widget.selecting ? widget.selected.contains(item.id) : null,
          child: InkWell(
            key: ValueKey('api-video.${item.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onOpen(item),
            onLongPress: widget.onLongPress == null
                ? null
                : () => widget.onLongPress!(item),
            child: grid
                ? _gridTile(context, item, width)
                : _listTile(context, item),
          ),
        );
      }

      return CustomScrollView(
        key: PageStorageKey(widget.storageKey),
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: grid
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns,
                      mainAxisExtent: _extent,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => tile(index),
                      childCount: widget.items.length,
                    ),
                  )
                : SliverFixedExtentList(
                    itemExtent: _extent,
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => tile(index),
                      childCount: widget.items.length,
                    ),
                  ),
          ),
          if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      );
    },
  );

  Widget _poster(ApiVideoItem item) => Stack(
    fit: StackFit.expand,
    children: [
      ApiVideoPoster(item: item),
      if (widget.selecting)
        Positioned(
          top: 6,
          right: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.selected.contains(item.id)
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 26,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      if (widget.badges[item.id] case final badge?)
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                badge,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _gridTile(BuildContext context, ApiVideoItem item, double width) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: width * 1.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _poster(item),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 3),
        Text(
          item.summary.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (item.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
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
    );
  }

  Widget _listTile(BuildContext context, ApiVideoItem item) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final posterHeight = math.min(_extent - 20, 148.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: posterHeight * 2 / 3,
            height: posterHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _poster(item),
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
                const SizedBox(height: 5),
                Text(
                  [
                    ...item.summary,
                    if (item.remarks.isNotEmpty) item.remarks,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
                if (item.sourceViews != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    t.videoLibrary.sourceViews(count: item.sourceViews!),
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

class ApiVideoPoster extends StatelessWidget {
  const ApiVideoPoster({super.key, required this.item});
  final ApiVideoItem item;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Icon(icon, color: colors.onSurfaceVariant, size: 28),
      ),
    );
    if (item.coverUrl == null) return placeholder(Icons.movie_outlined);
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        item.coverUrl.toString(),
        headers: {'Referer': item.detailUrl.toString()},
        fit: BoxFit.cover,
        cacheWidth:
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(160, 600),
        excludeFromSemantics: true,
        frameBuilder: (_, child, frame, synchronous) =>
            synchronous || frame != null
            ? child
            : placeholder(Icons.movie_outlined),
        errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
      ),
    );
  }
}

class ApiVideoEmpty extends StatelessWidget {
  const ApiVideoEmpty({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.movie_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
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
}
