import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// The scroll rail owns a trailing touch lane separate from the options.
class FilterScrollRail extends StatefulWidget {
  const FilterScrollRail({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });

  final ScrollController controller;
  final Widget child;
  final bool enabled;

  @override
  State<FilterScrollRail> createState() => _FilterScrollRailState();
}

class _FilterScrollRailState extends State<FilterScrollRail> {
  final _metrics = ValueNotifier<ScrollMetrics?>(null);
  bool _pressed = false;
  double? _grabOffset;
  ScrollMetrics? _queuedMetrics;
  bool _metricsScheduled = false;

  void _read(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _queuedMetrics = null;
      _metrics.value = metrics;
      return;
    }
    // Scroll views can publish a clamped position during keyboard relayout.
    // The rail's rebuild belongs in the next frame, not that layout pass.
    _queuedMetrics = metrics;
    if (_metricsScheduled) return;
    _metricsScheduled = true;
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      _metricsScheduled = false;
      if (_queuedMetrics case final latest?) {
        _queuedMetrics = null;
        _metrics.value = latest;
      }
    });
  }

  void _seek(double fraction) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    controller.jumpTo(
      position.minScrollExtent +
          fraction.clamp(0.0, 1.0) *
              (position.maxScrollExtent - position.minScrollExtent),
    );
  }

  void _page(double direction) {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (!position.hasContentDimensions) return;
    widget.controller.jumpTo(
      (position.pixels + direction * position.viewportDimension).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _release() {
    _grabOffset = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _metrics,
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _read(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _read(notification.metrics);
          return false;
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: widget.child,
        ),
      ),
    ),
    builder: (context, metrics, child) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child!),
        if (widget.enabled &&
            metrics != null &&
            metrics.maxScrollExtent.isFinite &&
            metrics.maxScrollExtent > metrics.minScrollExtent &&
            metrics.viewportDimension > 0)
          SizedBox(
            width: width,
            child: LayoutBuilder(
              builder: (context, bounds) =>
                  _rail(context, bounds.maxHeight, metrics),
            ),
          ),
      ],
    ),
  );

  static const width = 44.0;

  Widget _rail(BuildContext context, double height, ScrollMetrics metrics) {
    if (height <= 0 || !height.isFinite) return const SizedBox.shrink();
    final range = metrics.maxScrollExtent - metrics.minScrollExtent;
    final fraction =
        metrics.viewportDimension / (metrics.viewportDimension + range);
    final thumbHeight = (height * fraction)
        .clamp(math.min(30.0, height), height)
        .toDouble();
    final travel = height - thumbHeight;
    final progress = ((metrics.pixels - metrics.minScrollExtent) / range).clamp(
      0.0,
      1.0,
    );
    final thumbTop = (progress * travel).toDouble();
    final color = Theme.of(context).colorScheme.onSurface;
    final highContrast = MediaQuery.highContrastOf(context);
    void seekPointer(double y, double offset) {
      if (travel > 0) _seek((y - offset) / travel);
    }

    return Semantics(
      label: t.searchResult.returnToTop,
      button: true,
      onTap: () => _seek(0),
      customSemanticsActions: {
        CustomSemanticsAction(label: t.common.previousPage): () => _page(-1),
        CustomSemanticsAction(label: t.common.nextPage): () => _page(1),
      },
      child: GestureDetector(
        key: const ValueKey('filter-scroll-rail'),
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (details) {
          seekPointer(details.localPosition.dy, thumbHeight / 2);
          _release();
        },
        onTapCancel: () {
          if (_grabOffset == null) _release();
        },
        onVerticalDragStart: (details) {
          final y = details.localPosition.dy;
          _grabOffset = y >= thumbTop && y <= thumbTop + thumbHeight
              ? y - thumbTop
              : thumbHeight / 2;
          setState(() => _pressed = true);
          seekPointer(y, _grabOffset!);
        },
        onVerticalDragUpdate: (details) {
          if (_grabOffset case final offset?) {
            seekPointer(details.localPosition.dy, offset);
          }
        },
        onVerticalDragEnd: (_) => _release(),
        onVerticalDragCancel: _release,
        child: Stack(
          children: [
            if (_pressed)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: thumbTop,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const ValueKey('facet-position-thumb'),
                  width: _pressed ? 6 : 3,
                  height: thumbHeight,
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: _pressed || highContrast ? .85 : .60,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
