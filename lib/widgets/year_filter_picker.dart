import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:material_ui/material_ui.dart';

/// A calendar year is selected directly in the surrounding filter draft.
/// No disclosure, search keyboard or second confirmation is needed.
class YearFilterPicker extends StatefulWidget {
  const YearFilterPicker({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.favorite,
    this.favoriteValues = const [],
  });

  final String keyPrefix, label, selected;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final Widget Function(String)? favorite;
  final List<String> favoriteValues;

  @override
  State<YearFilterPicker> createState() => _YearFilterPickerState();
}

class _YearFilterPickerState extends State<YearFilterPicker> {
  late final FixedExtentScrollController _controller;
  late String _reportedValue;
  double? _extent;
  int _syncVersion = 0;
  bool _synchronizing = false;

  List<MapEntry<String, String>> get _entries => [
    ...widget.options.entries,
    if (widget.selected.isNotEmpty &&
        !widget.options.containsKey(widget.selected))
      MapEntry(widget.selected, widget.selected),
  ];

  int get _selectedIndex =>
      math.max(0, _entries.indexWhere((entry) => entry.key == widget.selected));

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
    _reportedValue = widget.selected;
  }

  @override
  void didUpdateWidget(covariant YearFilterPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _reportedValue = widget.selected;
    }
    // Parent reset, category changes and embedded controlled filters must move
    // the wheel too. A normal scroll callback already has the correct offset.
    if (_controller.hasClients && _controller.selectedItem != _selectedIndex) {
      _synchronize();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    final entries = _entries;
    if (!widget.enabled ||
        _synchronizing ||
        index < 0 ||
        index >= entries.length) {
      return;
    }
    final next = entries[index].key;
    // A jump reports synchronously, before the parent can rebuild its value.
    if (next == _reportedValue) return;
    _reportedValue = next;
    widget.onSelected(next);
  }

  void _synchronize() {
    final version = ++_syncVersion;
    _synchronizing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _syncVersion) return;
      if (_controller.hasClients) _controller.jumpToItem(_selectedIndex);
      _reportedValue = widget.selected;
      _synchronizing = false;
    });
  }

  void _jumpTo(int index) {
    _controller.jumpToItem(index);
    _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    final style = theme.textTheme.titleMedium!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.titleSmall),
            ),
            if (widget.favorite case final favorite?) favorite(widget.selected),
            if (widget.options.containsKey(''))
              TextButton(
                key: ValueKey('${widget.keyPrefix}.all'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: !widget.enabled || widget.selected.isEmpty
                    ? null
                    : () => _jumpTo(
                        entries.indexWhere((entry) => entry.key.isEmpty),
                      ),
                child: Text(widget.options['']!),
              ),
          ],
        ),
        if (widget.favoriteValues.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in widget.favoriteValues)
                  if (widget.options[value] case final label?)
                    TextButton(
                      key: ValueKey('${widget.keyPrefix}.favorite.$value'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: widget.enabled && value != widget.selected
                          ? () => _jumpTo(
                              entries.indexWhere((entry) => entry.key == value),
                            )
                          : null,
                      child: Text(label),
                    ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, bounds) {
            var extent = 44.0;
            // A row grows with actual scaled text instead of clipping its glyphs.
            for (final entry in entries) {
              final painter = TextPainter(
                text: TextSpan(text: entry.value, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: math.max(1, bounds.maxWidth - 32));
              extent = math.max(extent, painter.height + 16);
              painter.dispose();
            }
            if (_extent != extent) {
              _extent = extent;
              _synchronize();
            }
            return SizedBox(
              key: ValueKey('${widget.keyPrefix}.wheel'),
              height: extent * 3,
              child: Semantics(
                label: widget.label,
                child: IgnorePointer(
                  ignoring: !widget.enabled,
                  child: CupertinoPicker(
                    scrollController: _controller,
                    itemExtent: extent,
                    onSelectedItemChanged: widget.enabled ? _select : null,
                    children: [
                      for (var index = 0; index < entries.length; index++)
                        GestureDetector(
                          // Cupertino's standard tap-to-scroll remains intact.
                          // Reduced motion selects immediately without an animated trip.
                          onTap: MediaQuery.disableAnimationsOf(context)
                              ? () {
                                  _controller.jumpToItem(index);
                                  _select(index);
                                }
                              : null,
                          child: Padding(
                            key: ValueKey(
                              '${widget.keyPrefix}.item.${entries[index].key.isEmpty ? 'all' : entries[index].key}',
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                entries[index].value,
                                style: style,
                                textAlign: TextAlign.center,
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
      ],
    );
  }
}
