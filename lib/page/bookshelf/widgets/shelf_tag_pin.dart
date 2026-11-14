import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

class ShelfTagPinButton extends StatelessWidget {
  const ShelfTagPinButton({
    super.key,
    required this.pinned,
    required this.onPressed,
    this.tooltip,
  });
  final bool pinned;
  final VoidCallback? onPressed;
  final String? tooltip;

  static String optionTooltip(
    BuildContext context, {
    required String label,
    required bool pinned,
  }) => Localizations.localeOf(context).languageCode == 'zh'
      ? '${pinned ? '取消收藏' : '收藏'}「$label」'
      : '${pinned ? 'Unpin' : 'Pin'} $label';
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip:
        tooltip ??
        (pinned ? t.bookshelf.facets.unstarTag : t.bookshelf.facets.starTag),
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    style: IconButton.styleFrom(
      fixedSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onPressed,
    iconSize: 22,
    icon: Icon(pinned ? Icons.star_rounded : Icons.star_outline_rounded),
  );
}

class ShelfTagPinError extends StatelessWidget {
  const ShelfTagPinError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        child: Text(t.common.retry),
      ),
    ],
  );
}
