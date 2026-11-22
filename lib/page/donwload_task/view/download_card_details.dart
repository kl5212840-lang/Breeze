import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// Main download list geometry shared by single items and video groups.
abstract final class DownloadCardMetrics {
  static const coverWidth = 94.0;
  static const coverHeight = 141.0;
  // Leaves room for the pin crossing the poster by 6 points.
  static const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 9);
}

/// Pairs the text column with a stable, title-aligned row action.
class DownloadRowHeading extends StatelessWidget {
  const DownloadRowHeading({super.key, required this.child, this.action});

  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    if (action == null) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Expanded(child: child),
        SizedBox.square(
          dimension: CollectionToolbarMetrics.actionExtentOf(context),
          child: action,
        ),
      ],
    );
  }
}

/// The poster defines the normal height. The heading and footer stay anchored
/// while longer text can increase the row's height.
class DownloadCardDetails extends StatelessWidget {
  const DownloadCardDetails({
    super.key,
    required this.identity,
    required this.heading,
    required this.footer,
    this.identityAction,
    this.minimumHeight = DownloadCardMetrics.coverHeight,
  });

  final List<Widget> identity, heading, footer;
  final Widget? identityAction;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    Widget lines(List<Widget> children) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: children,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          lines([
            DownloadRowHeading(action: identityAction, child: lines(identity)),
            ...heading,
          ]),
          if (footer.isNotEmpty) lines(footer),
        ],
      ),
    );
  }
}

/// Keeps transfer feedback next to the action that controls it.
class DownloadCardTransfer extends StatelessWidget {
  const DownloadCardTransfer({
    super.key,
    required this.status,
    this.detail,
    this.progress,
    this.action,
    this.showAction = true,
  });

  final Widget status;
  final Widget? detail, progress, action;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        if (action == null)
          status
        else
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              status,
              DownloadRowControl(
                visible: showAction,
                child: TextButtonTheme(
                  data: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      minimumSize: Size.square(extent),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  child: action,
                ),
              ),
            ],
          ),
        ?detail,
        ?progress,
      ],
    );
  }
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
