import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// BK's category home retains its scrollable while an explicit reload runs.
/// This widget owns presentation only; the existing plugin controller owns IO,
/// authentication and cancellation. Fatal failures discard retained content.
class BikaHomeContent extends StatefulWidget {
  const BikaHomeContent({
    super.key,
    required this.source,
    required this.data,
    required this.loading,
    required this.error,
    required this.onReload,
    required this.onAction,
  });
  final String source, error;
  final Map<String, dynamic> data;
  final bool loading;
  final Future<void> Function() onReload;
  final Future<void> Function(Map<String, dynamic>) onAction;

  @override
  State<BikaHomeContent> createState() => _BikaHomeContentState();
}

class _BikaHomeContentState extends State<BikaHomeContent> {
  final _scroll = ScrollController();
  Map<String, dynamic>? _content;
  bool _reloading = false;
  bool _expandedKeywords = false;

  @override
  void initState() {
    super.initState();
    _acceptData();
  }

  void _acceptData() {
    if (widget.error.isNotEmpty) {
      _content = null;
    } else if (!widget.loading) {
      _content = widget.data;
    }
  }

  @override
  void didUpdateWidget(BikaHomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _content = null;
      _expandedKeywords = false;
    }
    _acceptData();
  }

  Future<void> _reload() async {
    if (_reloading || widget.loading) return;
    setState(() => _reloading = true);
    try {
      await widget.onReload();
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) {
      return Center(
        child: widget.loading
            ? SourceLoadingIndicator(source: widget.source)
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BikaStatusArtwork(kind: BikaStatusKind.error),
                      const SizedBox(height: 16),
                      Text(widget.error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      _retryButton(),
                    ],
                  ),
                ),
              ),
      );
    }
    final categories = asJsonList(
      content['categories'],
    ).map(asJsonMap).toList();
    final notices = asJsonList(content['notices']).map(asJsonMap).toList();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        key: const ValueKey('bika-home-scroll'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          // Stable slot: neither refresh nor preference changes remove the list.
          SizedBox(
            height: 4,
            child: widget.loading || _reloading
                ? const LinearProgressIndicator()
                : null,
          ),
          if (asJsonList(content['keywords']).isNotEmpty) ...[
            _heading(t.oldHome.hotSearch),
            _chips(
              _expandedKeywords
                  ? content['keywords']
                  : asJsonList(content['keywords']).take(4).toList(),
            ),
            if (asJsonList(content['keywords']).length > 4)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('bika-home-keywords-toggle'),
                  onPressed: () =>
                      setState(() => _expandedKeywords = !_expandedKeywords),
                  child: Text(
                    _expandedKeywords ? t.comicInfo.collapse : t.common.more,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          _chips(content['shortcuts']),
          ...notices.map(
            (notice) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TouchHoverIntent(
                      builder: (context, hover) => TextButton(
                        onPressed: widget.loading || _reloading
                            ? null
                            : _reload,
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(44, 44),
                        ).copyWith(overlayColor: hover.overlayColor(null)),
                        child: Text(
                          convertChineseForDisplay(
                            notice['label']?.toString() ?? '',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (categories.isNotEmpty) ...[
            _heading(t.videoLibrary.categories),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns =
                    (constraints.maxWidth / (80 * scale.clamp(1.0, 1.5)))
                        .floor()
                        .clamp(2, 5)
                        .toInt();
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: width + 6 + 40 * scale,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, index) => _category(categories[index]),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _retryButton() => TouchHoverIntent(
    builder: (context, hover) => TextButton(
      onPressed: widget.loading || _reloading ? null : _reload,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
      ).copyWith(overlayColor: hover.overlayColor(null)),
      child: Text(t.common.retry),
    ),
  );

  Widget _chips(Object? raw) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: asJsonList(raw).map((raw) {
      final item = asJsonMap(raw);
      final action = asJsonMap(item['action']);
      return TouchHoverIntent(
        identity: item['label'],
        builder: (context, hover) => OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
          ).copyWith(overlayColor: hover.overlayColor(null)),
          onPressed: action.isEmpty ? null : () => widget.onAction(action),
          child: Text(
            convertChineseForDisplay(item['label']?.toString() ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList(),
  );

  Widget _category(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final cover = asJsonMap(item['cover']);
    final url = cover['url']?.toString() ?? '';
    final path = cover['path']?.toString() ?? '';
    final action = asJsonMap(item['action']);
    final colors = Theme.of(context).colorScheme;
    return TouchHoverIntent(
      identity: title,
      builder: (context, hover) => Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: action.isEmpty ? null : () => widget.onAction(action),
          overlayColor: hover.overlayColor(null),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (_, constraints) => url.isEmpty && path.isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            color: colors.onPrimaryContainer,
                            size: 36,
                          ),
                        )
                      : CoverWidget(
                          fileServer: url,
                          path: path,
                          id: title,
                          pictureType: PictureType.category,
                          from: widget.source,
                          width: constraints.maxWidth,
                          height: constraints.maxWidth,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  convertChineseForDisplay(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
