import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

typedef AppliedFilter = ({
  String id,
  String label,
  VoidCallback remove,
  VoidCallback? edit,
});

class AppliedFilterBar extends StatefulWidget {
  const AppliedFilterBar({
    super.key,
    required this.entries,
    required this.onClearAll,
    this.inset = 16,
    this.clearKey = const ValueKey('applied-filter.clear-all'),
    this.contextChips = const [],
    this.clearWhenEmpty = false,
  });

  final List<AppliedFilter> entries;
  final VoidCallback onClearAll;
  final double inset;
  final Key clearKey;
  final List<Widget> contextChips;
  final bool clearWhenEmpty;

  static final _confirmations = <ModalRoute<dynamic>, DialogRoute<void>>{};

  static bool confirmationIsCovering(BuildContext context) =>
      _confirmations[ModalRoute.of(context)]?.isCurrent == true;

  @override
  State<AppliedFilterBar> createState() => _AppliedFilterBarState();
}

class _AppliedFilterBarState extends State<AppliedFilterBar> {
  String? _revealed;
  bool _confirming = false;

  @override
  void didUpdateWidget(covariant AppliedFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.entries.any((entry) => entry.id == _revealed)) _revealed = null;
  }

  Future<void> _confirmClear() async {
    if (_confirming) return;
    _confirming = true;
    final page = ModalRoute.of(context);
    final selection = widget.entries.map((entry) => entry.id).toList();
    final dialog = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      builder: (dialog) => AlertDialog(
        title: Text(
          LocaleSettings.currentLocale.languageCode == 'zh'
              ? '清除全部筛选？'
              : 'Clear all filters?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              // Publish the new conditions before the underlying page resumes.
              if (mounted &&
                  selection.length == widget.entries.length &&
                  Iterable.generate(
                    selection.length,
                  ).every((i) => selection[i] == widget.entries[i].id)) {
                widget.onClearAll();
              }
              Navigator.pop(dialog);
            },
            child: Text(t.common.clear),
          ),
        ],
      ),
    );
    if (page != null) AppliedFilterBar._confirmations[page] = dialog;
    try {
      await Navigator.of(context, rootNavigator: true).push(dialog);
    } finally {
      if (AppliedFilterBar._confirmations[page] == dialog) {
        AppliedFilterBar._confirmations.remove(page);
      }
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty &&
        widget.contextChips.isEmpty &&
        !widget.clearWhenEmpty)
      return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final height = (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 22)
        .clamp(44.0, double.infinity);
    return Semantics(
      label: t.videoFilters.active,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: widget.inset),
        child: SizedBox(
          height: height,
          child: Row(
            spacing: 6,
            children: [
              if (widget.entries.isNotEmpty || widget.clearWhenEmpty)
                IconButton(
                  key: widget.clearKey,
                  tooltip: t.videoFilters.clearFilters,
                  onPressed: _confirmClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsetsDirectional.only(end: widget.inset),
                  itemCount: widget.entries.length + widget.contextChips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index >= widget.entries.length) {
                      return Center(
                        child:
                            widget.contextChips[index - widget.entries.length],
                      );
                    }
                    final entry = widget.entries[index];
                    final revealed = _revealed == entry.id;
                    return Center(
                      key: ValueKey(entry.id),
                      child: Semantics(
                        customSemanticsActions: {
                          CustomSemanticsAction(
                            label: t.videoFilters.removeFilter,
                          ): entry.remove,
                        },
                        child: GestureDetector(
                          onLongPress: () =>
                              setState(() => _revealed = entry.id),
                          child: Stack(
                            alignment: AlignmentDirectional.centerEnd,
                            children: [
                              ActionChip(
                                label: Text(entry.label),
                                onPressed: revealed
                                    ? () => setState(() => _revealed = null)
                                    : entry.edit ??
                                          () =>
                                              setState(() => _revealed = null),
                              ),
                              if (revealed)
                                PositionedDirectional(
                                  end: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 32,
                                  child: IconButton(
                                    key: ValueKey(
                                      'applied-filter.remove.${entry.id}',
                                    ),
                                    tooltip: t.videoFilters.removeFilter,
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      setState(() => _revealed = null);
                                      entry.remove();
                                    },
                                    icon: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: colors.surfaceContainerHigh,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
