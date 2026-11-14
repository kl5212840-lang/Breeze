import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// Persistent single-choice options in a filter task. Unlike a menu row, each
/// label is centered on its own frame, independently of the selection marker.
class SelectionChoiceGrid<T> extends StatelessWidget {
  const SelectionChoiceGrid({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.optionKey,
    this.maxColumns = 4,
    this.enabled = true,
    this.favorite,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Key Function(T) optionKey;
  final int maxColumns;
  final bool enabled;
  final Widget Function(T)? favorite;

  // Preserve the API filter's existing 16pt mark, 8pt gap and 10pt padding.
  // A matching trailing slot keeps the actual text centered in both states.
  static const _marker = 16.0, _gap = 8.0, _padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final style = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final favorite = this.favorite;
    final favoriteWidth = favorite == null ? 0.0 : 44.0;
    var widest = 0.0;
    for (final label in options.values) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final minimum =
            widest + 2 * (_marker + _gap + _padding) + favoriteWidth;
        final columns = ((bounds.maxWidth + 8) / (minimum + 8)).floor().clamp(
          1,
          maxColumns,
        );
        final width = (bounds.maxWidth - (columns - 1) * 8) / columns;
        var height = 44.0;
        for (final label in options.values) {
          final painter =
              TextPainter(
                text: TextSpan(text: label, style: style),
                textDirection: direction,
                textScaler: scaler,
              )..layout(
                maxWidth: math.max(
                  1,
                  width - favoriteWidth - 2 * (_marker + _gap + _padding),
                ),
              );
          height = math.max(height, painter.height + 2 * _padding);
          painter.dispose();
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in options.entries)
              SizedBox(
                width: width,
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        key: optionKey(entry.key),
                        button: true,
                        enabled: enabled,
                        selected: entry.key == value,
                        label: entry.value,
                        excludeSemantics: true,
                        onTap: enabled
                            ? () {
                                if (entry.key != value) onChanged(entry.key);
                              }
                            : null,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(44, height),
                            padding: const EdgeInsets.all(_padding),
                            backgroundColor: entry.key == value
                                ? colors.secondaryContainer
                                : colors.surfaceContainerLow,
                            foregroundColor: entry.key == value
                                ? colors.onSecondaryContainer
                                : colors.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: entry.key == value
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                            animationDuration: VideoMotion.feedback(context),
                          ),
                          onPressed: enabled
                              ? () {
                                  if (entry.key != value) onChanged(entry.key);
                                }
                              : null,
                          child: Row(
                            children: [
                              SizedBox(
                                width: _marker,
                                child: entry.key == value
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: _marker,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: _gap),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                  style: style.copyWith(
                                    color: entry.key == value
                                        ? colors.onSecondaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: _gap + _marker),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (favorite != null) favorite(entry.key),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
