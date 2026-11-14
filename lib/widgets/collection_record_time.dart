import 'package:material_ui/material_ui.dart';

TextStyle? collectionRecordTimeStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );

/// Reading/watching events stay separate from mutable descriptive metadata.
class CollectionRecordTimeLine extends StatelessWidget {
  const CollectionRecordTimeLine({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, softWrap: true, style: collectionRecordTimeStyle(context));
}
