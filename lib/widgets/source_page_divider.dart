import 'package:material_ui/material_ui.dart';

class SourcePageDivider extends StatelessWidget {
  const SourcePageDivider({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Center(
      child: Image.asset(
        'asset/image/source-page-divider-heart.png',
        width: 168,
        height: 14,
        cacheWidth: (168 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        fit: BoxFit.cover,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: .56),
        colorBlendMode: BlendMode.srcIn,
        excludeFromSemantics: true,
      ),
    ),
  );
}

/// Only mark boundaries with known provenance in the displayed source order.
Set<int> sourcePageBreaks<T>(List<T> entries, int? Function(T) pageOf) {
  final breaks = <int>{};
  int? previous;
  int? lastKnown;
  for (var index = 0; index < entries.length; index++) {
    final page = pageOf(entries[index]);
    if (page != null) {
      if (lastKnown != null && page < lastKnown) return const {};
      if (previous != null && page > previous) breaks.add(index);
      lastKnown = page;
    }
    previous = page;
  }
  return breaks;
}
