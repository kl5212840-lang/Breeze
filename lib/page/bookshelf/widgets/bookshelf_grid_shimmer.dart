import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';

class BookshelfGridShimmer extends StatelessWidget {
  const BookshelfGridShimmer({
    super.key,
    this.itemCount = 12,
    this.view = BookshelfContentView.grid,
  });
  final int itemCount;
  final BookshelfContentView view;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = Theme.of(context).colorScheme.surfaceContainerHighest;
      final highlight = Theme.of(context).colorScheme.surface;
      Widget block({double? height}) => Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(5),
        ),
      );
      Widget caption() => SizedBox(
        height: BookshelfContentLayout.captionHeight(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            block(height: 14),
            const SizedBox(height: 5),
            block(height: 14),
          ],
        ),
      );
      Widget item(BuildContext context, int index) {
        final poster = AspectRatio(
          aspectRatio: BookshelfContentLayout.coverAspectRatio,
          child: block(),
        );
        final child = view == BookshelfContentView.grid
            ? Column(children: [poster, const SizedBox(height: 8), caption()])
            : Row(
                children: [
                  SizedBox(width: 80, child: poster),
                  const SizedBox(width: 12),
                  Expanded(child: caption()),
                ],
              );
        if (MediaQuery.disableAnimationsOf(context)) return child;
        return child
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: highlight.withValues(alpha: .4));
      }

      return view == BookshelfContentView.grid
          ? GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gridDelegate: BookshelfContentLayout.gridDelegate(
                context,
                constraints.maxWidth,
              ),
              itemCount: itemCount,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: item,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: itemCount,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: item,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
            );
    },
  );
}
