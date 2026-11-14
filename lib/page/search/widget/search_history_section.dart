import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_tool_glyph.dart';

/// Shared by comic and video search. Destructive actions affect only the
/// confirmed words provided by this scope, never an implicit global history.
class SearchHistorySection extends StatefulWidget {
  const SearchHistorySection({
    super.key,
    required this.words,
    required this.onSubmit,
    required this.onRemove,
    required this.scopeLabel,
    this.compact = false,
    this.loading = false,
    this.readFailed = false,
    this.onRetry,
  });
  final List<String> words;
  final ValueChanged<String> onSubmit;
  final Future<void> Function(Set<String>) onRemove;
  final String scopeLabel;
  final bool compact, loading, readFailed;
  final VoidCallback? onRetry;
  @override
  State<SearchHistorySection> createState() => _SearchHistorySectionState();
}

class _SearchHistorySectionState extends State<SearchHistorySection> {
  static const _chipPadding = 11.0;
  static const _chipGap = 8.0;
  final _selected = <String>{};
  final _historyFocus = FocusNode(skipTraversal: true);
  bool _managing = false,
      _busy = false,
      _confirming = false,
      _all = false,
      _writeFailed = false;
  bool get _locked => _busy || _confirming;
  @override
  void dispose() {
    _historyFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected.retainAll(widget.words);
    if (widget.words.isEmpty) _managing = false;
  }

  void _toggle(String word) => setState(() {
    _selected.contains(word) ? _selected.remove(word) : _selected.add(word);
  });

  void _toggleManagement() {
    _historyFocus.requestFocus();
    setState(() {
      _managing = !_managing;
      _selected.clear();
    });
  }

  void _toggleAll(bool allSelected) => setState(() {
    allSelected ? _selected.clear() : _selected.addAll(widget.words);
  });

  Future<void> _remove(Set<String> words, {bool clearing = false}) async {
    if (_locked || words.isEmpty) return;
    _historyFocus.requestFocus();
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(clearing ? t.search.clearHistory : t.common.delete),
        content: Text(
          clearing
              ? t.search.clearScopedHistoryConfirm
              : words.length == 1
              ? t.search.deleteSingleHistoryConfirm
              : t.search.deleteHistoryConfirm(count: words.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(clearing ? t.search.clearHistory : t.common.delete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _writeFailed = false;
    });
    try {
      await widget.onRemove(words);
      if (mounted) setState(() => _selected.removeAll(words));
    } catch (_) {
      if (mounted) setState(() => _writeFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allSelected =
        widget.words.isNotEmpty && _selected.containsAll(widget.words);
    final clearing = !_managing || widget.compact && allSelected;
    final scope = Text(
      _managing
          ? t.search.selectedCount(count: _selected.length)
          : widget.scopeLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
    final selectAllLabel = allSelected
        ? t.bookshelf.deselectAll
        : t.bookshelf.selectAll;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Focus(
      focusNode: _historyFocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.compact ? 52 : 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.search.history,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (widget.compact && widget.words.isNotEmpty) scope,
                    ],
                  ),
                ),
                if (widget.words.isNotEmpty) ...[
                  TextButton(
                    key: const ValueKey('search-history.manage'),
                    onPressed: _locked ? null : _toggleManagement,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      _managing ? t.common.done : t.videoSource.manage,
                    ),
                  ),
                  if (widget.compact && _managing)
                    IconButton(
                      key: const ValueKey('search-history.select-all'),
                      tooltip: selectAllLabel,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      visualDensity: VisualDensity.standard,
                      onPressed: _locked ? null : () => _toggleAll(allSelected),
                      icon: SearchToolGlyph(
                        allSelected
                            ? SearchTool.deselectAll
                            : SearchTool.selectAll,
                        size: 22,
                      ),
                    ),
                  if (_managing || !widget.compact)
                    IconButton(
                      key: ValueKey(
                        clearing
                            ? 'search-history.clear'
                            : 'search-history.delete-selected',
                      ),
                      tooltip: clearing
                          ? t.search.clearHistory
                          : t.bookshelf.deleteSelected,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      visualDensity: VisualDensity.standard,
                      onPressed: _locked || (_managing && _selected.isEmpty)
                          ? null
                          : () => _remove(
                              _managing
                                  ? Set.of(_selected)
                                  : widget.words.toSet(),
                              clearing: clearing,
                            ),
                      icon: const SearchToolGlyph(SearchTool.trash, size: 22),
                    ),
                ],
              ],
            ),
          ),
          // The scope/count and selection action share a permanent row. Entering
          // management never inserts a toolbar above the first history item.
          if (!widget.compact && (widget.words.isNotEmpty || _managing))
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(child: scope),
                  if (_managing)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _locked ? null : () => _toggleAll(allSelected),
                      child: Text(selectAllLabel),
                    ),
                ],
              ),
            ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.readFailed || _writeFailed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(child: Text(t.search.historyActionFailed)),
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: _locked ? null : widget.onRetry,
                      child: Text(t.common.retry),
                    ),
                ],
              ),
            ),
          if (!widget.loading && !widget.readFailed && widget.words.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                t.search.noHistory,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              if (availableWidth <= 0) return const SizedBox.shrink();
              const gap = _chipGap;
              final style = theme.textTheme.bodyMedium!;
              final scale = MediaQuery.textScalerOf(context);
              final widths = <double>[];
              var row = 1, visibleCount = 0;
              var usedWidth = 0.0;
              for (final word in widget.words) {
                final painter = TextPainter(
                  text: TextSpan(text: word, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: scale,
                  maxLines: 1,
                )..layout();
                final width = (painter.width.ceilToDouble() + _chipPadding * 2)
                    .clamp(
                      availableWidth < 44 ? availableWidth : 44.0,
                      availableWidth,
                    );
                painter.dispose();
                widths.add(width);
                if (usedWidth > 0 && usedWidth + gap + width > availableWidth) {
                  row++;
                  usedWidth = 0;
                }
                usedWidth += (usedWidth == 0 ? 0 : gap) + width;
                if (row <= 3) visibleCount++;
              }
              final hasOverflow = visibleCount < widget.words.length;
              final shown = _all || _managing
                  ? widget.words.length
                  : visibleCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: 0,
                    children: [
                      for (var index = 0; index < shown; index++)
                        _historyChip(widget.words[index], widths[index]),
                    ],
                  ),
                  if (!_managing && hasOverflow)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        key: const ValueKey('search-history.expand'),
                        onPressed: () => setState(() => _all = !_all),
                        icon: AnimatedRotation(
                          turns: _all ? -.25 : .25,
                          duration: duration,
                          child: const Icon(Icons.chevron_right_rounded),
                        ),
                        label: Text(
                          _all ? t.search.lessHistory : t.search.moreHistory,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _historyChip(String word, double width) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selected.contains(word);
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    );
    return SizedBox(
      width: width,
      child: Semantics(
        checked: _managing ? selected : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('search-history.word.$word'),
            customBorder: const StadiumBorder(),
            onTap: _locked
                ? null
                : () => _managing ? _toggle(word) : widget.onSubmit(word),
            onLongPress: _locked || _managing
                ? null
                : () {
                    _historyFocus.requestFocus();
                    setState(() {
                      _managing = true;
                      _selected.add(word);
                    });
                  },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: 5,
                  bottom: 5,
                  child: Ink(
                    decoration: ShapeDecoration(
                      shape: shape,
                      color: selected
                          ? colors.secondaryContainer
                          : colors.surface,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _chipPadding,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      heightFactor: 1,
                      child: Text(
                        word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: selected ? colors.onSecondaryContainer : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
