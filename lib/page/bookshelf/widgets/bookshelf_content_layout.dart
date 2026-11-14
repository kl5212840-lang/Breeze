import 'package:material_ui/material_ui.dart';

enum BookshelfContentView { grid, list }

/// The local bookshelf uses one density for both media, independently of each
/// plugin's browsing layout. Accessibility grows text rows rather than hiding it.
abstract final class BookshelfContentLayout {
  static const horizontalPadding = 12.0;
  static const spacing = 12.0;
  static const coverAspectRatio = 2 / 3;

  static int columns(double width) => 3;

  static double itemWidth(double width) =>
      (width - horizontalPadding * 2 - spacing * (columns(width) - 1)) /
      columns(width);

  static double titleHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    return (scale.scale(theme.textTheme.titleSmall?.fontSize ?? 14) * 2.6 + 2)
        .ceilToDouble();
  }

  static double subtitleHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(
                context,
              ).scale(Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
              1.3)
          .ceilToDouble();

  static double captionHeight(BuildContext context) =>
      titleHeight(context) + 3 + subtitleHeight(context);

  static double itemExtent(BuildContext context, double width) =>
      itemWidth(width) / coverAspectRatio + 8 + captionHeight(context);

  static SliverGridDelegate gridDelegate(BuildContext context, double width) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns(width),
        mainAxisExtent: itemExtent(context, width),
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      );
}

class BookshelfCardCaption extends StatelessWidget {
  const BookshelfCardCaption({
    super.key,
    required this.title,
    this.subtitle = '',
    this.fixedHeight = true,
  });
  final String title, subtitle;
  final bool fixedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fixedHeight)
          SizedBox(
            height: BookshelfContentLayout.titleHeight(context),
            child: heading,
          )
        else
          heading,
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.3,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return fixedHeight
        ? SizedBox(
            height: BookshelfContentLayout.captionHeight(context),
            child: content,
          )
        : content;
  }
}
