import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:material_ui/material_ui.dart';

/// The full title stays available to accessibility while the visual track
/// repeats inside the space left by the fullscreen toolbar.
class VideoLandscapeTitle extends StatelessWidget {
  const VideoLandscapeTitle({
    super.key,
    required this.title,
    required this.active,
  });

  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: Colors.white);
    final text = Text(
      title,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    if (!active) return text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final painter = TextPainter(
          text: TextSpan(
            text: title,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width.ceilToDouble();
        painter.dispose();
        if (width <= constraints.maxWidth || constraints.maxWidth <= 0) {
          return text;
        }
        return Semantics(
          label: title,
          excludeSemantics: true,
          child: _ScrollingTitle(
            key: ValueKey((title, width, direction)),
            title: title,
            style: style,
            distance: width + _ScrollingTitle.gap,
          ),
        );
      },
    );
  }
}

class _ScrollingTitle extends StatefulWidget {
  const _ScrollingTitle({
    super.key,
    required this.title,
    required this.style,
    required this.distance,
  });

  static const double gap = 36;
  final String title;
  final TextStyle? style;
  final double distance;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  static const double _holdMs = 1100;
  late final double _travelMs = widget.distance / 32 * 1000;
  late final _scroll = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    duration: Duration(milliseconds: (_holdMs + _travelMs).round()),
  )..repeat();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final label = Text(
      widget.title,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
    return ClipRect(
      child: OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        alignment: AlignmentDirectional.centerStart,
        minWidth: 0,
        maxWidth: double.infinity,
        child: AnimatedBuilder(
          animation: _scroll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(width: _ScrollingTitle.gap),
              label,
            ],
          ),
          builder: (_, child) {
            final elapsed = _scroll.value * (_holdMs + _travelMs);
            final progress = ((elapsed - _holdMs) / _travelMs).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(
                widget.distance *
                    progress *
                    (direction == TextDirection.ltr ? -1 : 1),
                0,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
