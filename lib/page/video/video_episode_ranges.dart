import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

const videoEpisodeRangeSize = 50;

class VideoEpisodeRanges extends StatelessWidget {
  const VideoEpisodeRanges({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    this.pageSize = videoEpisodeRangeSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : assert(pageSize > 0);
  final int count, index, pageSize;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var start = 0; start < count; start += pageSize)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${start + 1}-${math.min(start + pageSize, count)}'),
              selected: index == start ~/ pageSize,
              onSelected: (_) => onChanged(start ~/ pageSize),
            ),
          ),
      ],
    ),
  );
}
