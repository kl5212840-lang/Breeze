import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart'
    show usesNativeSourceChrome;
import 'package:zephyr/page/video/native_video_controls.dart';

class BookshelfBatchAction {
  const BookshelfBatchAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.symbol,
    required this.onPressed,
  });
  final String id, label, symbol;
  final IconData icon;
  final VoidCallback? onPressed;
}

/// Use the regular header's height while managing the same contents.
class BookshelfSelectionHeader extends StatelessWidget {
  const BookshelfSelectionHeader({
    super.key,
    required this.regular,
    this.selection,
  });

  final Widget regular;
  final Widget? selection;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.center,
    clipBehavior: Clip.none,
    children: [
      Visibility(
        visible: selection == null,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: regular,
      ),
      if (selection case final toolbar?)
        Positioned.fill(child: Center(child: toolbar)),
    ],
  );
}

/// Selection context stays above the list even when floating actions hide.
class BookshelfSelectionToolbar extends StatelessWidget {
  const BookshelfSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onCancel,
    required this.onToggleAll,
    this.keyPrefix = 'shelf-selection',
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.privacyAction,
  });
  final int selectedCount;
  final bool allSelected;
  final VoidCallback? onCancel, onToggleAll;
  final String keyPrefix;
  final EdgeInsetsGeometry padding;
  final Widget? privacyAction;

  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < (privacyAction == null ? 350 : 400) ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final allLabel = allSelected
              ? t.bookshelf.deselectAll
              : t.common.selectAll;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                KeyedSubtree(
                  key: ValueKey('$keyPrefix.cancel'),
                  child: MediaQuery.textScalerOf(context).scale(14) > 20
                      ? NativeVideoIconButton(
                          icon: Icons.close,
                          symbol: 'xmark',
                          tooltip: t.common.cancel,
                          light: false,
                          bare: true,
                          onPressed: onCancel,
                        )
                      : NativeVideoTextButton(
                          label: t.common.cancel,
                          tooltip: t.common.cancel,
                          light: false,
                          bare: true,
                          maxWidth: compact ? 88 : 120,
                          onPressed: onCancel,
                        ),
                ),
                Expanded(
                  child: Text(
                    t.bookshelf.selectedCount(count: selectedCount),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ?privacyAction,
                KeyedSubtree(
                  key: ValueKey('$keyPrefix.select-all'),
                  child: compact
                      ? NativeVideoIconButton(
                          icon: allSelected ? Icons.deselect : Icons.select_all,
                          symbol: allSelected
                              ? 'checkmark.square.fill'
                              : 'square.dashed',
                          tooltip: allLabel,
                          light: false,
                          bare: true,
                          onPressed: onToggleAll,
                        )
                      : SizedBox(
                          width: 112,
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: NativeVideoTextButton(
                              label: allLabel,
                              tooltip: allLabel,
                              light: false,
                              bare: true,
                              maxWidth: 112,
                              onPressed: onToggleAll,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
