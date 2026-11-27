import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_overlay_theme.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

/// A readable modal surface for a task with its own layout.
class TaskDialogSurface extends StatelessWidget {
  const TaskDialogSurface({
    super.key,
    required this.child,
    this.insetPadding = const EdgeInsets.all(24),
    this.radius,
  });

  final Widget child;
  final EdgeInsets insetPadding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final borderRadius = radius == null
        ? BreezeOverlayTheme.dialogRadius
        : BorderRadius.circular(radius!);
    final compact = media.size.height - media.viewInsets.vertical < 300;
    final android = AppInterfaceStyleScope.usesAndroidSystem(context);
    return Dialog(
      insetPadding: compact
          ? insetPadding.copyWith(top: 8, bottom: 8)
          : insetPadding,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: android ? 0 : null,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.none,
      child: NativeMaterialSurface(
        radius: borderRadius.topLeft.x,
        androidGlass: true,
        floating: android,
        readableContent: true,
        child: child,
      ),
    );
  }
}

/// A task with a bounded, scrollable body and persistent actions.
class TaskDialog extends StatelessWidget {
  const TaskDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.width = 360,
    this.maxHeight,
    this.scrollBody = true,
    this.insetPadding = const EdgeInsets.all(24),
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;
  final double? maxHeight;
  final bool scrollBody;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const contentPadding = EdgeInsets.symmetric(horizontal: 24);
    return TaskDialogSurface(
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Semantics(
                header: true,
                namesRoute: true,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: scrollBody
                  ? SingleChildScrollView(
                      padding: contentPadding,
                      child: content,
                    )
                  : Padding(padding: contentPadding, child: content),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Theme(
                data: theme.copyWith(
                  textButtonTheme: TextButtonThemeData(
                    style: (theme.textButtonTheme.style ?? const ButtonStyle())
                        .copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(64, 44),
                          ),
                        ),
                  ),
                  filledButtonTheme: FilledButtonThemeData(
                    style:
                        (theme.filledButtonTheme.style ?? const ButtonStyle())
                            .copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(64, 44),
                              ),
                            ),
                  ),
                ),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 4,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
