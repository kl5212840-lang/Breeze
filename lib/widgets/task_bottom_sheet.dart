import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/breeze_overlay_theme.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

/// Uses the standard draggable bottom-sheet route for tasks with their own
/// layout and safe-area policy.
Future<T?> showReadableTaskBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    clipBehavior: Clip.none,
    elevation: 0,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => NativeMaterialSurface(
      radius: BreezeOverlayTheme.sheetRadius.topLeft.x,
      androidGlass: true,
      readableContent: true,
      topOnly: true,
      child: showDragHandle
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TaskDragHandle(),
                Flexible(child: builder(sheetContext)),
              ],
            )
          : builder(sheetContext),
    ),
  );
}

class _TaskDragHandle extends StatelessWidget {
  const _TaskDragHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4);
    final color =
        theme.bottomSheetTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      button: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Center(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size.height / 2),
            ),
          ),
        ),
      ),
    );
  }
}
