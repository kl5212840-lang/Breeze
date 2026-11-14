import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

/// An inline single-choice editor inside a filter draft. The surrounding
/// task retains ownership of Apply/Cancel; this widget never opens a route.
class CompactFilterChoice extends StatefulWidget {
  const CompactFilterChoice({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.searchHint,
    this.keyboardType,
    this.enabled = true,
    this.favorite,
  });

  final String keyPrefix, label, selected;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;
  final String? searchHint;
  final TextInputType? keyboardType;
  final bool enabled;
  final Widget Function(String)? favorite;

  @override
  State<CompactFilterChoice> createState() => _CompactFilterChoiceState();
}

class _CompactFilterChoiceState extends State<CompactFilterChoice> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  bool _expanded = false;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
    _expanded = !_expanded;
    _query.clear();
  });

  void _pick(String value) {
    FocusScope.of(context).unfocus();
    setState(() {
      _expanded = false;
      _query.clear();
    });
    if (value != widget.selected) widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final query = _query.text.trim().toLowerCase();
    final entries = widget.options.entries
        .where(
          (entry) =>
              query.isEmpty ||
              entry.key.toLowerCase().contains(query) ||
              entry.value.toLowerCase().contains(query),
        )
        .toList();
    // Match the existing filter option padding and reserved 16pt check slot.
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      foregroundColor: colors.onSurface,
      side: BorderSide(color: colors.outlineVariant),
      overlayColor: breeze ? colors.primary : null,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          label: widget.label,
          child: OutlinedButton(
            key: ValueKey('${widget.keyPrefix}.trigger'),
            style: breeze
                ? buttonStyle.copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? null
                          : _expanded
                          ? colors.surfaceContainerHigh
                          : colors.surfaceContainerLow,
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                  )
                : buttonStyle,
            onPressed: widget.enabled && widget.options.isNotEmpty
                ? _toggle
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.options[widget.selected] ?? widget.selected,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                VideoDisclosureIndicator(expanded: _expanded, size: 20),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          SearchFieldSurface(
            child: TextField(
              key: ValueKey('${widget.keyPrefix}.search'),
              controller: _query,
              keyboardType: widget.keyboardType,
              onChanged: (_) {
                if (_scroll.hasClients) _scroll.jumpTo(0);
                setState(() {});
              },
              decoration: searchFieldDecoration(
                context,
                hintText: widget.searchHint ?? t.comicList.searchOptions,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t.common.clear,
                        onPressed: () => setState(_query.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t.comicList.noMatchingOptions),
            )
          else
            ConstrainedBox(
              key: ValueKey('${widget.keyPrefix}.options'),
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * .3).clamp(
                  144.0,
                  280.0,
                ),
              ),
              child: Scrollbar(
                controller: _scroll,
                child: ListView.separated(
                  controller: _scroll,
                  primary: false,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final selected = entry.key == widget.selected;
                    return Row(
                      key: ValueKey(entry.key),
                      children: [
                        Expanded(
                          child: Semantics(
                            selected: selected,
                            child: TextButton(
                              key: ValueKey(
                                '${widget.keyPrefix}.${entry.key.isEmpty ? 'all' : entry.key}',
                              ),
                              style: buttonStyle.copyWith(
                                side: const WidgetStatePropertyAll(
                                  BorderSide.none,
                                ),
                                backgroundColor: WidgetStatePropertyAll(
                                  selected
                                      ? (breeze
                                            ? colors.surfaceContainerHigh
                                            : colors.secondaryContainer)
                                      : null,
                                ),
                              ),
                              onPressed: widget.enabled
                                  ? () => _pick(entry.key)
                                  : null,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    child: selected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: breeze
                                                ? colors.primary
                                                : null,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: selected && !breeze
                                                ? colors.onSecondaryContainer
                                                : colors.onSurface,
                                            fontWeight: selected && breeze
                                                ? FontWeight.w600
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (widget.favorite case final favorite?)
                          favorite(entry.key),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }
}
