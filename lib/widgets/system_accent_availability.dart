import 'package:flutter/widgets.dart';

/// Reflects the system palette actually returned to the app theme builder.
class SystemAccentAvailability extends InheritedWidget {
  const SystemAccentAvailability({
    super.key,
    required this.available,
    required super.child,
  });

  final bool available;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SystemAccentAvailability>()
          ?.available ??
      false;

  @override
  bool updateShouldNotify(SystemAccentAvailability oldWidget) =>
      available != oldWidget.available;
}
