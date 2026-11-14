import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One application-wide choice, including routes, dialogs and plugin chrome.
/// The existing preference store owns persistence and cloud revision ordering.
class AppInterfaceStyleScope extends StatelessWidget {
  const AppInterfaceStyleScope({
    super.key,
    required this.style,
    required this.child,
  });

  final ValueNotifier<String> style;
  final Widget child;

  static ValueNotifier<String>? styleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InterfaceStyleTheme>()?.style;
  static bool usesSystem(BuildContext context) =>
      styleOf(context)?.value != 'breeze';
  static bool usesAndroidSystem(BuildContext context) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      usesSystem(context);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: style,
    child: child,
    builder: (context, value, child) =>
        _InterfaceStyleTheme(style: style, value: value, child: child!),
  );
}

/// Dialogs and sheets capture InheritedTheme across Navigator overlays. The
/// effective source style travels with the colors instead of falling back to
/// the global controls when a route is opened from a local appearance scope.
class _InterfaceStyleTheme extends InheritedTheme {
  const _InterfaceStyleTheme({
    required this.style,
    required this.value,
    required super.child,
  });
  final ValueNotifier<String> style;
  final String value;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      AppInterfaceStyleScope(style: style, child: child);

  @override
  bool updateShouldNotify(_InterfaceStyleTheme oldWidget) =>
      style != oldWidget.style || value != oldWidget.value;
}
