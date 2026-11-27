import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDialogRoute;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_overlay_theme.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

bool _usesCupertinoAlertRoute(BuildContext context) {
  final platform = Theme.of(context).platform;
  return AppInterfaceStyleScope.usesSystem(context) &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);
}

/// Builds the route separately for notices that own its lifecycle.
ModalRoute<T> shortAlertRoute<T>({
  required BuildContext context,
  required NavigatorState navigator,
  required WidgetBuilder builder,
  bool? barrierDismissible,
}) {
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  if (_usesCupertinoAlertRoute(context)) {
    return CupertinoDialogRoute<T>(
      context: context,
      barrierDismissible: barrierDismissible ?? false,
      builder: (_) => themes.wrap(Builder(builder: builder)),
    );
  }
  return DialogRoute<T>(
    context: context,
    themes: themes,
    barrierDismissible: barrierDismissible ?? true,
    builder: builder,
  );
}

Future<T?> showShortAlert<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool? barrierDismissible,
}) {
  if (!_usesCupertinoAlertRoute(context)) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible ?? true,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    shortAlertRoute<T>(
      context: context,
      navigator: navigator,
      builder: builder,
      barrierDismissible: barrierDismissible,
    ),
  );
}

Future<bool?> confirmShortAlert({
  required BuildContext context,
  required Widget title,
  Widget? content,
  required String confirmLabel,
  bool destructive = false,
  bool filled = false,
  bool? barrierDismissible,
  bool adaptiveRoute = false,
}) {
  Widget buildConfirmation(BuildContext dialog) => ShortAlert(
    title: title,
    content: content,
    actions: [
      ShortAlertAction(
        onPressed: () => _closeShortAlert(dialog, false),
        child: Text(t.common.cancel),
      ),
      ShortAlertAction(
        destructive: destructive,
        filled: filled,
        onPressed: () => _closeShortAlert(dialog, true),
        child: Text(confirmLabel),
      ),
    ],
  );

  if (adaptiveRoute) {
    return showShortAlert<bool>(
      context: context,
      builder: buildConfirmation,
      barrierDismissible: barrierDismissible,
    );
  }
  return showDialog<bool>(
    context: context,
    builder: buildConfirmation,
    barrierDismissible: barrierDismissible ?? true,
  );
}

void _closeShortAlert(BuildContext context, bool confirmed) {
  if (ModalRoute.of(context)?.isCurrent == true) {
    Navigator.pop(context, confirmed);
  }
}

/// A short, readable interruption. Forms and selection panels keep their
/// own layout and application logic.
class ShortAlert extends StatelessWidget {
  const ShortAlert({
    super.key,
    required this.title,
    this.content,
    required this.actions,
  });

  final Widget title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: BreezeOverlayTheme.alertSurface(
      Theme.of(context).colorScheme,
    ),
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    constraints: BoxConstraints(
      minWidth: 280,
      maxWidth: _usesCupertinoAlertRoute(context) ? 360 : 400,
    ),
    scrollable: true,
    title: title,
    content: content,
    actions: actions,
  );
}

class ShortAlertAction extends StatelessWidget {
  const ShortAlertAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.destructive = false,
    this.filled = false,
    this.isDefaultAction = false,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool destructive;
  final bool filled;
  final bool isDefaultAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const minimumSize = Size(64, 44);
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          backgroundColor: destructive ? colors.error : null,
          foregroundColor: destructive
              ? BreezeThemeColors.readableOn(colors.onError, colors.error)
              : null,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: minimumSize,
        textStyle: isDefaultAction
            ? const TextStyle(fontWeight: FontWeight.w600)
            : null,
        foregroundColor: destructive
            ? BreezeThemeColors.readableOn(
                colors.error,
                BreezeOverlayTheme.alertSurface(colors),
              )
            : null,
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
