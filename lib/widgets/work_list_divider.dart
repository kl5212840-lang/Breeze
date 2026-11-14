import 'package:material_ui/material_ui.dart';

class WorkListDivider extends StatelessWidget {
  const WorkListDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) => Divider(
    height: height,
    thickness: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
  );
}

/// Draws the divider within a row's existing bottom spacing. The sliver still
/// has one child per record, so scroll anchors and visible detail reads keep
/// their original indices.
class WorkListRow extends StatelessWidget {
  const WorkListRow({
    super.key,
    required this.child,
    required this.divided,
    this.bottomSpacing = 1,
    this.inset = 0,
    this.startInset,
  });

  final Widget child;
  final bool divided;
  final double bottomSpacing, inset;
  final double? startInset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      if (divided)
        PositionedDirectional(
          start: startInset ?? inset,
          end: inset,
          bottom: 0,
          child: IgnorePointer(child: WorkListDivider(height: bottomSpacing)),
        ),
    ],
  );
}
