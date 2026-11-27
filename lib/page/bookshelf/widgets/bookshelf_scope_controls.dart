import 'dart:ui' show MaskFilter, SemanticsRole;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/rendering.dart'
    show FlexParentData, Paint, PaintingContext, PipelineOwner, RenderFlex;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/plugin/plugin_display_name.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

Widget _sourcePressPlate(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child, {
  required bool pointerPressed,
  required bool hoverAllowed,
  required BorderRadius radius,
  bool selected = false,
  double verticalInset = 0,
  Widget? selectionEffect,
}) {
  final colors = Theme.of(context).colorScheme;
  final enabled = !states.contains(WidgetState.disabled);
  final pressed = enabled && pointerPressed;
  final focused = enabled && states.contains(WidgetState.focused);
  final hovered =
      enabled && hoverAllowed && states.contains(WidgetState.hovered);
  final plate = AnimatedContainer(
    duration: !pressed && selected
        ? Duration.zero
        : BreezeControlMotion.press(context, pressed: pressed),
    curve: BreezeControlMotion.curve,
    decoration: BoxDecoration(
      borderRadius: radius,
      color: colors.primary.withValues(
        alpha: pressed
            ? (selected ? .12 : .16)
            : focused
            ? (selected ? .05 : .12)
            : hovered
            ? (selected ? .035 : .08)
            : 0,
      ),
    ),
    foregroundDecoration: focused && MediaQuery.highContrastOf(context)
        ? BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.primary, width: 2),
          )
        : null,
    child: verticalInset == 0 ? child : null,
  );
  if (verticalInset == 0) return plate;
  return Stack(
    alignment: Alignment.center,
    children: [
      if (selectionEffect != null)
        Positioned.fill(
          top: verticalInset,
          bottom: verticalInset,
          child: selectionEffect,
        ),
      Positioned.fill(top: verticalInset, bottom: verticalInset, child: plate),
      ?child,
    ],
  );
}

/// Always-visible source navigation. An empty scope means all local sources,
/// including retained records whose plugin is no longer installed/enabled.
class BookshelfSourceNavigation extends StatelessWidget {
  const BookshelfSourceNavigation({
    super.key,
    required this.sources,
    required this.selected,
    required this.onChanged,
    this.loading = false,
    this.hidden = const {},
    this.onManage,
    this.showManage = true,
    this.classicChips = false,
    this.quietChips = false,
    this.scrollSafeChips = false,
    this.allLabel,
    this.horizontalInset = CollectionToolbarMetrics.horizontalInset,
    this.statusAction,
    this.scrollStartInset,
  });
  final Map<String, String> sources;
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;
  final bool loading;
  final Set<String> hidden;
  final VoidCallback? onManage;
  final bool showManage, classicChips, quietChips, scrollSafeChips;
  final String? allLabel;
  final double horizontalInset;
  final double? scrollStartInset;
  final Widget? statusAction;

  @override
  Widget build(BuildContext context) {
    final options = {
      '': allLabel ?? t.common.all,
      for (final entry in sources.entries)
        if (!hidden.contains(entry.key)) entry.key: entry.value,
      for (final id in selected)
        if (!sources.containsKey(id) && !hidden.contains(id)) id: id,
    };
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('bookshelf.sources.scroll'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsetsDirectional.fromSTEB(
              scrollStartInset ?? horizontalInset,
              0,
              classicChips ? 4 : horizontalInset,
              0,
            ),
            child: classicChips
                ? _buildClassicChips(context, options)
                : _SourceTabs(
                    options: options,
                    selected: selected,
                    onChanged: onChanged,
                  ),
          ),
        ),
        if (loading)
          Padding(
            padding: EdgeInsetsDirectional.only(end: horizontalInset),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? .5 : null,
              ),
            ),
          ),
        if (statusAction case final action?)
          SizedBox(
            width: CollectionToolbarMetrics.actionExtentOf(context),
            child: action,
          ),
        if (showManage) ...[
          SizedBox(
            height: 20,
            child: VerticalDivider(
              key: const ValueKey('bookshelf.sources.divider'),
              width: 12,
              thickness: 1,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(end: horizontalInset),
            child: SizedBox(
              width: CollectionToolbarMetrics.actionExtentOf(context),
              child: SourceChromeIconButton(
                key: const ValueKey('bookshelf.sources.manage'),
                bare: true,
                icon: Icons.label_outline,
                symbol: 'tag',
                tooltip: t.bookshelf.sourceLabels,
                onPressed: onManage,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClassicChips(BuildContext context, Map<String, String> options) {
    final active = selected.isEmpty ? {''} : selected.toSet();
    if (scrollSafeChips || !AppInterfaceStyleScope.usesSystem(context)) {
      return _ClassicBreezeSources(
        options: options,
        quiet: quietChips,
        active: active,
        onChanged: onChanged,
        duration: BreezeControlMotion.sourceSelection(context),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final entry in options.entries)
          _sourceLabel(
            entry,
            (label) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Semantics(
                selected: active.contains(entry.key),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NativeVideoTextButton(
                      key: ValueKey('bookshelf.source.${entry.key}'),
                      label: label,
                      tooltip: label,
                      maxWidth: label == entry.value ? double.infinity : 180,
                      light: false,
                      bare: quietChips,
                      foregroundColor: active.contains(entry.key)
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      onPressed: onChanged == null
                          ? null
                          : () => onChanged!(
                              entry.key.isEmpty ? [] : [entry.key],
                            ),
                    ),
                    Container(
                      height: 2,
                      width: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: active.contains(entry.key)
                            ? colors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _sourceLabel(
  MapEntry<String, String> entry,
  Widget Function(String label) builder,
) => entry.key.isEmpty
    ? KeyedSubtree(key: const ValueKey(''), child: builder(entry.value))
    : PluginDisplayNameBuilder(
        key: ValueKey(entry.key),
        source: entry.key,
        fallback: entry.value,
        builder: (_, label) => builder(label),
      );

const _classicChipRadius = BorderRadius.all(Radius.circular(999));

class _ClassicBreezeSources extends StatefulWidget {
  const _ClassicBreezeSources({
    required this.options,
    required this.quiet,
    required this.active,
    required this.onChanged,
    required this.duration,
  });

  final Map<String, String> options;
  final Set<String> active;
  final bool quiet;
  final ValueChanged<List<String>>? onChanged;
  final Duration duration;

  @override
  State<_ClassicBreezeSources> createState() => _ClassicBreezeSourcesState();
}

class _ClassicBreezeSourcesState extends State<_ClassicBreezeSources>
    with SingleTickerProviderStateMixin {
  late final _selection = BreezeSelectionProgress<String>(this, widget.active);

  @override
  void didUpdateWidget(_ClassicBreezeSources oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration == Duration.zero ||
        (oldWidget.active.length == 1 &&
            !widget.options.containsKey(oldWidget.active.single))) {
      _selection.snap(widget.active);
    } else if (!setEquals(oldWidget.active, widget.active)) {
      _selection.select(widget.active, duration: widget.duration);
    }
  }

  Widget _label(
    BuildContext context,
    String id,
    String label,
    Color idle,
    Color selected,
    TextStyle style,
  ) {
    // Measure the emphasized label for both states so selecting an item
    // cannot move its neighbors or shift the horizontal scroll position.
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: 160);
    final width = painter.width.ceilToDouble();
    painter.dispose();
    Widget text() => Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: widget.active.contains(id)
            ? FontWeight.w600
            : FontWeight.w500,
        color: widget.onChanged == null
            ? null
            : Color.lerp(idle, selected, _selection.weight(id)),
      ),
    );
    if (widget.onChanged != null && _selection.animates(id)) {
      return SizedBox(
        width: width,
        child: ListenableBuilder(
          listenable: _selection.changes,
          builder: (context, _) => text(),
        ),
      );
    }
    return SizedBox(width: width, child: text());
  }

  Widget? _selectedPlateFeedback(
    String id,
    Set<WidgetState> states, {
    required bool hoverAllowed,
    required bool highContrast,
    required Color fill,
    required Color shadow,
    required Color highlight,
  }) {
    if (highContrast || !widget.active.contains(id)) return null;

    final engaged =
        !states.contains(WidgetState.disabled) &&
        (states.contains(WidgetState.focused) ||
            (hoverAllowed && states.contains(WidgetState.hovered)));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: engaged ? 1 : 0),
      duration: widget.duration,
      curve: Curves.easeInOut,
      builder: (context, progress, _) => ListenableBuilder(
        listenable: _selection.changes,
        builder: (context, _) => CustomPaint(
          painter: _FocusedSourcePlate(
            fill: fill,
            shadow: shadow,
            highlight: highlight,
            progress: _selection.weight(id) >= .999 ? progress : 0,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final backdrop = Color.alphaBlend(
      theme.scaffoldBackgroundColor,
      colors.surface,
    );
    final dark = colors.brightness == Brightness.dark;
    final tint = Color.lerp(backdrop, colors.primary, dark ? .12 : .04)!;
    final highContrast = MediaQuery.highContrastOf(context);
    final fill = highContrast
        ? BreezeThemeColors.readableOn(tint, backdrop, minimumContrast: 3.05)
        : tint;
    final shadow = colors.shadow.withValues(alpha: dark ? .24 : .14);
    final highlight = colors.surfaceBright.withValues(alpha: .62);
    final selectedLabel = BreezeThemeColors.readableOn(
      colors.onPrimaryContainer,
      fill,
    );
    final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w600);
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final onChanged = widget.onChanged;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: _SourceSelectionTrack(
        key: const ValueKey('bookshelf.sources.selection-track'),
        ids: widget.options.keys.toList(),
        active: widget.active,
        repaint: _selection.changes,
        weight: _selection.weight,
        color: fill,
        shadow: shadow,
        highlight: highlight,
        outline: highContrast
            ? BreezeThemeColors.readableOn(
                colors.outline,
                backdrop,
                minimumContrast: 3.05,
              )
            : null,
        children: [
          for (final entry in widget.options.entries)
            _sourceLabel(
              entry,
              (label) => Semantics(
                selected: widget.active.contains(entry.key),
                child: CollectionPressFeedback.builder(
                  enabled: onChanged != null,
                  pressedBuilder: (context, pressed) => TouchHoverIntent(
                    identity: entry.key,
                    builder: (context, hover) => TextButton(
                      key: ValueKey('bookshelf.source.${entry.key}'),
                      onPressed: onChanged == null
                          ? null
                          : () {
                              if (widget.active.length == 1 &&
                                  widget.active.contains(entry.key)) {
                                return;
                              }
                              onChanged(entry.key.isEmpty ? [] : [entry.key]);
                            },
                      style:
                          TextButton.styleFrom(
                            minimumSize: Size.square(extent),
                            visualDensity: VisualDensity.standard,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            textStyle: labelStyle,
                            backgroundColor: Colors.transparent,
                            foregroundColor: colors.onSurfaceVariant,
                            overlayColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            shape: const RoundedRectangleBorder(
                              borderRadius: _classicChipRadius,
                            ),
                          ).copyWith(
                            backgroundBuilder: (context, states, child) =>
                                _sourcePressPlate(
                                  context,
                                  states,
                                  child,
                                  pointerPressed: pressed,
                                  hoverAllowed: hover.allowed,
                                  radius: _classicChipRadius,
                                  verticalInset:
                                      CollectionToolbarMetrics.actionPlateInset,
                                  selected:
                                      !widget.quiet &&
                                      widget.active.contains(entry.key),
                                  selectionEffect: _selectedPlateFeedback(
                                    entry.key,
                                    states,
                                    hoverAllowed: hover.allowed,
                                    highContrast: highContrast,
                                    fill: fill,
                                    shadow: shadow,
                                    highlight: highlight,
                                  ),
                                ),
                          ),
                      child: _label(
                        context,
                        entry.key,
                        label,
                        colors.onSurfaceVariant,
                        selectedLabel,
                        labelStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Paint behind the flex children, using the layout that also drives taps and
// scrolling. An alias can change the child's width without rebuilding the row.
class _SourceSelectionTrack extends Row {
  const _SourceSelectionTrack({
    required super.key,
    required super.children,
    required this.ids,
    required this.active,
    required this.repaint,
    required this.weight,
    required this.color,
    required this.shadow,
    required this.highlight,
    required this.outline,
  }) : super(spacing: 4);

  final List<String> ids;
  final Set<String> active;
  final Listenable repaint;
  final double Function(String) weight;
  final Color color;
  final Color shadow, highlight;
  final Color? outline;

  @override
  _RenderSourceSelectionTrack createRenderObject(BuildContext context) =>
      _RenderSourceSelectionTrack(
        textDirection: getEffectiveTextDirection(context),
        ids: ids,
        active: active,
        repaint: repaint,
        weight: weight,
        color: color,
        shadow: shadow,
        highlight: highlight,
        outline: outline,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSourceSelectionTrack renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..ids = ids
      ..active = active
      ..plate.color = color
      ..shadow = shadow
      ..highlight = highlight
      ..outline = outline
      ..markNeedsPaint();
  }
}

class _RenderSourceSelectionTrack extends RenderFlex {
  _RenderSourceSelectionTrack({
    required super.textDirection,
    required this.ids,
    required this.active,
    required this.repaint,
    required this.weight,
    required Color color,
    required this.shadow,
    required this.highlight,
    required this.outline,
  }) : plate = Paint()..color = color,
       super(direction: Axis.horizontal, spacing: 4);

  List<String> ids;
  Set<String> active;
  final Listenable repaint;
  final double Function(String) weight;
  final Paint plate;
  Color shadow, highlight;
  Color? outline;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final single = active.length == 1;
    Rect? blended;
    Rect? target;
    var totalWeight = 0.0;
    var child = firstChild;
    for (final id in ids) {
      final item = child!;
      final data = item.parentData! as FlexParentData;
      child = data.nextSibling;
      final selected = active.contains(id);
      final emphasis = single ? weight(id) : 0.0;
      if (!selected && emphasis == 0) continue;
      final frame = (offset + data.offset) & item.size;
      const inset = CollectionToolbarMetrics.actionPlateInset;
      final bounds = Rect.fromLTRB(
        frame.left,
        frame.top + inset,
        frame.right,
        frame.bottom - inset,
      );
      if (single) {
        if (selected) target = bounds;
        if (emphasis > 0) {
          totalWeight += emphasis;
          blended = Rect.lerp(
            blended ?? bounds,
            bounds,
            emphasis / totalWeight,
          );
        }
      } else if (selected) {
        _paintPlate(context.canvas, bounds);
      }
    }
    if (target != null) {
      _paintPlate(context.canvas, blended ?? target);
    }
    super.paint(context, offset);
  }

  void _paintPlate(Canvas canvas, Rect bounds) => _drawSourcePlate(
    canvas,
    bounds,
    fill: plate.color,
    shadow: shadow,
    highlight: highlight,
    outline: outline,
  );
}

// From Uiverse.io by adamgiebl - https://uiverse.io/adamgiebl/good-mouse-67
// MIT License, Copyright (c) adamgiebl (Adam Giebl)
void _drawSourcePlate(
  Canvas canvas,
  Rect bounds, {
  required Color fill,
  required Color shadow,
  required Color highlight,
  Color? outline,
  double progress = 0,
}) {
  final shape = _classicChipRadius.toRRect(bounds);
  // The website preview shows the focused style. Its two inset and two
  // outside shadows use 2px offsets and a 5px blur on a 55px-tall button.
  const scale = CollectionToolbarMetrics.actionPlateExtent / 55;
  const delta = Offset(2 * scale, 2 * scale);
  const blur = MaskFilter.blur(BlurStyle.normal, 5 * scale / 2);
  final borderWidth = outline == null ? 2 * scale : 2.0;
  final exterior = bounds.inflate(16);
  final paint = Paint();
  if (outline == null) {
    // The focus pass adds a little light around the resting selected plate.
    final outsideLight = progress == 0 ? highlight.a : .12 * progress;
    final outsideShade = progress == 0 ? .11 : .045 * progress;
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(exterior)
        ..addRRect(shape),
    );
    paint.maskFilter = blur;
    canvas.drawPath(
      Path()..addRRect(shape.shift(-delta)),
      paint..color = highlight.withValues(alpha: outsideLight),
    );
    canvas.drawPath(
      Path()..addRRect(shape.shift(delta)),
      paint..color = shadow.withValues(alpha: outsideShade),
    );
    canvas.restore();
  }
  canvas.drawRRect(
    shape,
    paint
      ..maskFilter = null
      ..color = fill,
  );
  if (outline == null) {
    final innerShape = shape.deflate(borderWidth);
    canvas.save();
    canvas.clipRRect(innerShape);
    paint.maskFilter = blur;
    void inset(Offset offset, Color color) {
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(exterior)
          ..addRRect(innerShape.shift(offset)),
        paint..color = color,
      );
    }

    inset(-delta, highlight);
    inset(delta, shadow);
    canvas.restore();
  }
  canvas.drawPath(
    Path()..addRRect(shape.deflate(borderWidth / 2)),
    paint
      ..maskFilter = null
      ..color = outline ?? shadow.withValues(alpha: .065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth,
  );
}

class _FocusedSourcePlate extends CustomPainter {
  const _FocusedSourcePlate({
    required this.fill,
    required this.shadow,
    required this.highlight,
    required this.progress,
  });

  final Color fill, shadow, highlight;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    _drawSourcePlate(
      canvas,
      Offset.zero & size,
      fill: fill,
      shadow: shadow,
      highlight: highlight,
      progress: progress,
    );
  }

  @override
  bool shouldRepaint(_FocusedSourcePlate oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fill != fill ||
      oldDelegate.shadow != shadow ||
      oldDelegate.highlight != highlight;
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, String> options;
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final selection = breeze
        ? BreezeControlColors.sectionSelection(
            theme,
            highContrast: highContrast,
          )
        : null;
    final style = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
    );
    final active = selected.isEmpty ? {''} : selected.toSet();
    final tabs = <({String id, String label, double start, double width})>[];
    var start = 0.0;
    var height = 44.0;
    for (final option in options.entries) {
      final painter = TextPainter(
        text: TextSpan(text: option.value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = (painter.width.ceilToDouble() + 24).clamp(
        60.0,
        double.infinity,
      );
      height = (painter.height + 16).clamp(height, double.infinity);
      tabs.add((
        id: option.key,
        label: option.value,
        start: start,
        width: width,
      ));
      start += width + 4;
      painter.dispose();
    }
    final thumb = active.length == 1
        ? tabs.where((tab) => active.contains(tab.id)).firstOrNull
        : null;
    Widget tabButton(
      ({String id, String label, double start, double width}) tab, {
      bool pressed = false,
      bool hoverAllowed = false,
    }) => TextButton(
      key: ValueKey('bookshelf.source.${tab.id}'),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        backgroundBuilder: breeze
            ? (context, states, child) => _sourcePressPlate(
                context,
                states,
                child,
                pointerPressed: pressed,
                hoverAllowed: hoverAllowed,
                radius: BorderRadius.circular(height / 2),
              )
            : null,
        textStyle: WidgetStatePropertyAll(style),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.onSurface.withValues(alpha: .38);
          }
          if (selection != null && thumb?.id == tab.id) {
            return selection.foreground;
          }
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed) ||
              (active.length > 1 && active.contains(tab.id))) {
            return colors.primary;
          }
          return colors.onSurface;
        }),
      ),
      onPressed: onChanged == null
          ? null
          : () => onChanged!(tab.id.isEmpty ? [] : [tab.id]),
      child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (thumb != null)
          AnimatedPositionedDirectional(
            key: const ValueKey('bookshelf.sources.thumb'),
            start: thumb.start + 2,
            width: thumb.width - 4,
            top: 4,
            bottom: 4,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selection?.fill ?? colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: !breeze && highContrast
                      ? Border.all(color: colors.outline)
                      : null,
                ),
              ),
            ),
          ),
        Row(
          children: [
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: SizedBox(
                  width: tab.width,
                  height: height,
                  child: MergeSemantics(
                    child: Semantics(
                      role: SemanticsRole.tab,
                      selected: active.contains(tab.id),
                      child: breeze
                          ? CollectionPressFeedback.builder(
                              enabled: onChanged != null,
                              pressedBuilder: (context, pressed) =>
                                  TouchHoverIntent(
                                    identity: tab.id,
                                    builder: (context, hover) => tabButton(
                                      tab,
                                      pressed: pressed,
                                      hoverAllowed: hover.allowed,
                                    ),
                                  ),
                            )
                          : tabButton(tab),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
