import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';

/// Main download list geometry shared by single items and video groups.
abstract final class DownloadCardMetrics {
  static const coverWidth = 94.0;
  static const coverHeight = 141.0;
  // Leaves room for the pin crossing the poster by 6 points.
  static const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 9);
}

/// The poster defines the normal height. The heading and footer stay anchored
/// while longer text can increase the row's height.
class DownloadCardDetails extends StatelessWidget {
  const DownloadCardDetails({
    super.key,
    required this.heading,
    required this.footer,
  });

  final List<Widget> heading;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minHeight: DownloadCardMetrics.coverHeight,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: heading,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: footer,
        ),
      ],
    ),
  );
}

class DownloadCardSelection extends StatelessWidget {
  const DownloadCardSelection({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    start: 0,
    bottom: 0,
    child: Semantics(
      label: label,
      checked: selected,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(
            dimension: 44,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: CollectionSelectionMark.inset,
                  bottom: CollectionSelectionMark.inset,
                ),
                child: Opacity(
                  opacity: onTap == null ? .48 : 1,
                  child: CollectionSelectionMark(
                    visible: true,
                    selected: selected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Readable on a busy poster, without taking over the card's tap target.
class DownloadCardPin extends StatelessWidget {
  const DownloadCardPin({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return PositionedDirectional(
      top: -6,
      start: -6,
      child: IgnorePointer(
        child: Semantics(
          label: chinese ? '已置顶' : 'Pinned',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SizedBox.square(
              dimension: 24,
              child: Icon(
                Icons.push_pin_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadCardFooter extends StatelessWidget {
  const DownloadCardFooter({
    super.key,
    required this.itemKey,
    required this.metrics,
    this.completedAt,
  });

  final String itemKey;
  final List<String> metrics;
  final DateTime? completedAt;

  @override
  Widget build(BuildContext context) {
    final local = completedAt?.toLocal();
    if (metrics.isEmpty && local == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Wrap(
      key: ValueKey('download-info.$itemKey'),
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (local != null) ...[
          Text(
            DateFormat('yyyy-MM-dd').format(local),
            key: ValueKey('download-date.$itemKey'),
            style: style,
          ),
          Text(
            DateFormat('HH:mm').format(local),
            key: ValueKey('download-time.$itemKey'),
            style: style,
          ),
        ],
        for (var index = 0; index < metrics.length; index++)
          Text(
            metrics[index],
            key: index == 0 ? ValueKey('download-size.$itemKey') : null,
            style: style,
          ),
      ],
    );
  }
}
