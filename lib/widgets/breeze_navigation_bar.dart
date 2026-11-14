import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

/// Breeze's fixed tab bar, with immediate selection at each destination.
class BreezeNavigationBar extends StatelessWidget {
  const BreezeNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.contentHeight,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double contentHeight;

  static double contentHeightOf(BuildContext context) =>
      64 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = BreezeControlColors.navigationSurface(theme);
    final idleForeground = BreezeThemeColors.readableOn(
      colors.onSurfaceVariant,
      surface,
    );
    final selectedForeground = BreezeThemeColors.readableOn(
      colors.primary,
      surface,
    );
    return Material(
      color: surface,
      child: Stack(
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: contentHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, tab) in destinations.indexed)
                      Expanded(
                        child: _BreezeTab(
                          tab: tab,
                          selected: index == selectedIndex,
                          foreground: index == selectedIndex
                              ? selectedForeground
                              : idleForeground,
                          onTap: () => onSelected(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreezeTab extends StatelessWidget {
  const _BreezeTab({
    required this.tab,
    required this.selected,
    required this.foreground,
    required this.onTap,
  });

  final NavigationDestination tab;
  final bool selected;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tab.tooltip ?? '',
      excludeFromSemantics: true,
      child: Semantics(
        role: SemanticsRole.tab,
        selected: selected,
        enabled: tab.enabled,
        label: tab.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: _BreezeNavigationPress(
              enabled: tab.enabled,
              radius: 12,
              builder: (context, hover, content) => InkWell(
                borderRadius: BorderRadius.circular(12),
                hoverColor: hover.hoverColor(),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                onTap: tab.enabled ? onTap : null,
                child: content,
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(size: 23, color: foreground),
                      child: selected ? tab.selectedIcon ?? tab.icon : tab.icon,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BreezeSectionSelector<T> extends StatelessWidget {
  const BreezeSectionSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.dragEnabled = false,
    this.direction = Axis.horizontal,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T>? onSelected;
  final bool enabled;
  final bool dragEnabled;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = BreezeControlColors.track(theme);
    final selection = BreezeControlColors.sectionSelection(
      theme,
      track: track,
      highContrast: MediaQuery.highContrastOf(context),
    );
    final entries = options.entries.toList(growable: false);
    final onSelected = this.onSelected;
    void select(T value) {
      if (enabled && value != selected) onSelected?.call(value);
    }

    return RepaintBoundary(
      child: Material(
        color: track,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: IntrinsicHeight(
            child: _BreezeSelectionTrack(
              ids: [for (final entry in entries) entry.key],
              selectedIndex: entries.indexWhere(
                (entry) => entry.key == selected,
              ),
              direction: direction,
              onDragSelected:
                  dragEnabled &&
                      enabled &&
                      onSelected != null &&
                      direction == Axis.horizontal
                  ? (index) => select(entries[index].key)
                  : null,
              inset: direction == Axis.horizontal
                  ? const EdgeInsets.symmetric(horizontal: 1)
                  : const EdgeInsets.symmetric(vertical: 1),
              radius: 9,
              color: selection.fill,
              duration: BreezeControlMotion.segmentSelection(context),
              builder: (progress) => Flex(
                direction: direction,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, entry) in entries.indexed)
                    Expanded(
                      key: ValueKey(entry.key),
                      child: _BreezeSegmentButton(
                        label: entry.value,
                        index: index,
                        selected: entry.key == selected,
                        selectedForeground: selection.foreground,
                        progress: progress,
                        onPressed: enabled && onSelected != null
                            ? () => select(entry.key)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreezeSegmentButton extends StatelessWidget {
  const _BreezeSegmentButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.selectedForeground,
    required this.progress,
    required this.onPressed,
  });

  final String label;
  final int index;
  final bool selected;
  final Color selectedForeground;
  final BreezeSelectionProgress<int> progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: CollectionPressFeedback.builder(
        enabled: onPressed != null,
        pressedBuilder: (context, pressed) => TouchHoverIntent(
          builder: (context, hover) => TextButton(
            onPressed: onPressed,
            style:
                TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  visualDensity: VisualDensity.standard,
                  animationDuration: Duration.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  foregroundColor: colors.onSurfaceVariant,
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  splashFactory: NoSplash.splashFactory,
                ).copyWith(
                  overlayColor: hover.overlayColor(
                    WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return Colors.transparent;
                      }
                      return null;
                    }),
                  ),
                ),
            child: onPressed == null
                ? Text(label, textAlign: TextAlign.center)
                : ListenableBuilder(
                    listenable: progress.changes,
                    builder: (context, _) => BreezePressedContent(
                      pressed: pressed,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.lerp(
                            colors.onSurfaceVariant,
                            selectedForeground,
                            progress.weight(index),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BreezeNavigationPress extends StatelessWidget {
  const _BreezeNavigationPress({
    required this.enabled,
    required this.radius,
    required this.builder,
    required this.child,
  });

  final bool enabled;
  final double radius;
  final Widget Function(BuildContext, TouchHoverStyle, Widget) builder;
  final Widget child;

  @override
  Widget build(BuildContext context) => CollectionPressFeedback.builder(
    enabled: enabled,
    pressedBuilder: (context, pressed) => TouchHoverIntent(
      builder: (context, hover) => AnimatedContainer(
        duration: BreezeControlMotion.press(context, pressed: pressed),
        curve: BreezeControlMotion.curve,
        decoration: BoxDecoration(
          color: pressed
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: builder(
          context,
          hover,
          BreezePressedContent(pressed: pressed, child: child),
        ),
      ),
    ),
  );
}

/// Moves one plate over the fixed layout. Each label follows the selection
/// progress of its own identity, independent of the plate passing underneath.
class _BreezeSelectionTrack extends StatefulWidget {
  const _BreezeSelectionTrack({
    required this.ids,
    required this.selectedIndex,
    required this.inset,
    required this.radius,
    required this.color,
    required this.duration,
    required this.builder,
    this.onDragSelected,
    this.direction = Axis.horizontal,
  });

  final List<Object?> ids;
  final int selectedIndex;
  int get count => ids.length;
  final EdgeInsets inset;
  final double radius;
  final Color color;
  final Duration duration;
  final Widget Function(BreezeSelectionProgress<int>) builder;
  final Axis direction;
  final ValueChanged<int>? onDragSelected;

  bool get hasSelection => selectedIndex >= 0 && selectedIndex < count;

  @override
  State<_BreezeSelectionTrack> createState() => _BreezeSelectionTrackState();
}

class _BreezeSelectionTrackState extends State<_BreezeSelectionTrack>
    with SingleTickerProviderStateMixin {
  late final _selection = BreezeSelectionProgress<int>(this, _selected(widget));

  double? _dragPosition;

  Set<int> _selected(_BreezeSelectionTrack track) => {
    if (track.hasSelection) track.selectedIndex,
  };

  @override
  void didUpdateWidget(_BreezeSelectionTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.duration == Duration.zero &&
            oldWidget.duration != Duration.zero) ||
        !listEquals(widget.ids, oldWidget.ids) ||
        widget.direction != oldWidget.direction ||
        (oldWidget.onDragSelected != null && widget.onDragSelected == null)) {
      _dragPosition = null;
      _selection.snap(_selected(widget));
    } else if (widget.selectedIndex != oldWidget.selectedIndex) {
      _dragPosition = null;
      _selection.select(_selected(widget), duration: widget.duration);
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  double get _position {
    var position = 0.0;
    for (var index = 0; index < widget.count; index++) {
      position += index * _selection.weight(index);
    }
    return position;
  }

  void _updateDrag(Offset pointer) {
    final width = context.size!.width;
    if (width <= 0) return;
    final logicalX = Directionality.of(context) == TextDirection.rtl
        ? width - pointer.dx
        : pointer.dx;
    final position = (logicalX * widget.count / width - .5).clamp(
      0.0,
      widget.count - 1.0,
    );
    _dragPosition = position;
    if (widget.duration == Duration.zero) return;
    final leading = position.floor();
    final trailing = position.ceil();
    _selection.scrub({
      leading: 1 - (position - leading),
      if (trailing != leading) trailing: position - leading,
    });
  }

  void _finishDrag({required bool commit}) {
    final target = _dragPosition?.round();
    if (target == null) return;
    _dragPosition = null;
    _selection.select(_selected(widget), duration: widget.duration);
    if (commit) widget.onDragSelected?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.direction == Axis.horizontal;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final track = Stack(
      children: [
        if (widget.hasSelection)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: horizontal
                    ? AlignmentDirectional.centerStart
                    : Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: horizontal ? 1 / widget.count : 1,
                  heightFactor: horizontal ? 1 : 1 / widget.count,
                  child: ListenableBuilder(
                    listenable: _selection.changes,
                    child: Padding(
                      padding: widget.inset,
                      child: DecoratedBox(
                        key: const ValueKey('breeze.selection.plate'),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(widget.radius),
                        ),
                      ),
                    ),
                    builder: (context, child) => FractionalTranslation(
                      translation: horizontal
                          ? Offset(sign * _position, 0)
                          : Offset(0, _position),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        widget.builder(_selection),
      ],
    );
    if (widget.onDragSelected == null || widget.count < 2) return track;
    return Listener(
      // The drag recognizer sends onEnd for an accepted pointer cancellation.
      onPointerCancel: (_) => _finishDrag(commit: false),
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) => _updateDrag(details.localPosition),
        onHorizontalDragUpdate: (details) {
          if (_dragPosition != null) _updateDrag(details.localPosition);
        },
        onHorizontalDragEnd: (_) => _finishDrag(commit: true),
        onHorizontalDragCancel: () => _finishDrag(commit: false),
        child: track,
      ),
    );
  }
}
