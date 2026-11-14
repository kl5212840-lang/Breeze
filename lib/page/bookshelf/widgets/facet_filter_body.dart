import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// Shared facet chrome and one lazy option viewport. Category changes do not
/// resize the panel; only the host's available space (including keyboard) does.
class FacetFilterBody extends StatefulWidget {
  const FacetFilterBody({
    super.key,
    required this.header,
    required this.controls,
    required this.options,
    required this.footer,
    required this.scrollKey,
    this.hasScope = false,
  });
  final Widget header, controls, options, footer;
  final Key scrollKey;
  final bool hasScope;
  @override
  State<FacetFilterBody> createState() => _FacetFilterBodyState();
}

class _FacetFilterBodyState extends State<FacetFilterBody> {
  // Reparent the existing chrome/viewport when the keyboard leaves too little
  // room for fixed controls, retaining the field's focus and list's state.
  final _chromeKey = GlobalKey(),
      _viewportKey = GlobalKey(),
      _footerKey = GlobalKey();
  final _position = ValueNotifier<({double progress, double fraction})?>(null);

  void _readPosition(ScrollMetrics metrics) {
    final range = metrics.maxScrollExtent - metrics.minScrollExtent;
    final viewport = metrics.viewportDimension;
    _position.value = range.isFinite && range > 0 && viewport > 0
        ? (
            progress: ((metrics.pixels - metrics.minScrollExtent) / range)
                .clamp(0.0, 1.0),
            fraction: viewport / (viewport + range),
          )
        : null;
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final height = math.max(0.0, math.min(600.0, bounds.maxHeight));
      final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
      // Fixed chrome must leave a usable option hit region; scaled text grows
      // while padding/44pt actions do not multiply with the font scale.
      final minimumFixed = widget.hasScope
          ? 340 + 180 * (scale - 1)
          : 280 + 140 * (scale - 1);
      final compact = height < minimumFixed;
      final chrome = KeyedSubtree(
        key: _chromeKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [widget.header, widget.controls],
        ),
      );
      final footer = KeyedSubtree(key: _footerKey, child: widget.footer);
      final viewport = KeyedSubtree(
        key: widget.scrollKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.metrics.axis == Axis.vertical) {
                  _readPosition(notification.metrics);
                }
                return false;
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0 &&
                      notification.metrics.axis == Axis.vertical) {
                    _readPosition(notification.metrics);
                  }
                  return false;
                },
                child: CustomScrollView(
                  key: _viewportKey,
                  primary: false,
                  scrollBehavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (compact) SliverToBoxAdapter(child: chrome),
                    widget.options,
                    if (compact) SliverToBoxAdapter(child: footer),
                  ],
                ),
              ),
            ),
            // Paint the thumb inside the sheet as a sibling of the scroll
            // viewport, away from its outer compositor edge.
            Positioned(
              top: 5,
              bottom: 5,
              right: 12,
              width: 3,
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, track) => ValueListenableBuilder(
                    valueListenable: _position,
                    builder: (context, position, _) {
                      final height = track.maxHeight;
                      if (position == null || height <= 0) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment(0, position.progress * 2 - 1),
                        child: Container(
                          key: const ValueKey('facet-position-thumb'),
                          width: 3,
                          height: (height * position.fraction).clamp(
                            math.min(30.0, height),
                            height,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(
                                  alpha: MediaQuery.highContrastOf(context)
                                      ? .8
                                      : .60,
                                ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return SizedBox(
        height: height,
        child: compact
            ? viewport
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chrome,
                  Expanded(child: viewport),
                  const Divider(height: 1),
                  footer,
                ],
              ),
      );
    },
  );
}
