import 'package:flutter/widgets.dart';
import 'package:toastification/toastification.dart';

import 'package:zephyr/main.dart';

enum ToastType { info, success, warning, error }

/// Producers may request longer notices, but never unreadable flash messages.
Duration readableToastDuration(ToastEvent event) {
  final minimum = event.type == ToastType.error || event.onTap != null
      ? 5
      : event.type == ToastType.warning
      ? 4
      : 3;
  final visibleText = [
    event.title,
    event.message,
    event.actionLabel,
  ].nonNulls.join(' ');
  final reading = ((visibleText.runes.length + 17) ~/ 18)
      .clamp(minimum, 10)
      .toInt();
  final requested = event.duration.inMilliseconds;
  final readable = Duration(seconds: reading).inMilliseconds;
  return Duration(milliseconds: requested > readable ? requested : readable);
}

final _activeToasts = Expando<Map<Object, ToastificationItem>>();

/// The same root-overlay banner is used by event-bus and page-local producers.
/// Timers belong to individual notices; an older timeout cannot close a newer one.
void showToastEvent(
  BuildContext context,
  ToastEvent event, {
  OverlayState? overlayState,
}) {
  if (!context.mounted || event.message.trim().isEmpty) return;
  final overlay = overlayState ?? Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || !overlay.mounted) return;
  final action = event.onTap;
  if (action != null && event._actionOverlays[overlay] == true) return;
  final active = _activeToasts[overlay] ??= {};
  active.removeWhere((_, item) => !item.isRunning);
  final Object? key = switch (event.deduplicationKey) {
    final key? => (event.type, key),
    null when action == null => (event.type, event.title, event.message.trim()),
    _ => null,
  };
  if (key != null && active.containsKey(key)) return;
  if (action != null) event._actionOverlays[overlay] = true;

  void remove(ToastificationItem item) {
    if (key != null && identical(active[key], item)) active.remove(key);
  }

  final type = switch (event.type) {
    ToastType.info => ToastificationType.info,
    ToastType.success => ToastificationType.success,
    ToastType.warning => ToastificationType.warning,
    ToastType.error => ToastificationType.error,
  };
  final shown = toastification.show(
    context: context,
    overlayState: overlay,
    alignment: Alignment.topRight,
    title: event.title == null ? null : Text(event.title!),
    description: action == null
        ? Text(event.message)
        : Semantics(
            button: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.message),
                if (event.actionLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
    type: type,
    style: ToastificationStyle.flatColored,
    autoCloseDuration: readableToastDuration(event),
    showProgressBar: true,
    callbacks: ToastificationCallbacks(
      onAutoCompleteCompleted: remove,
      onDismissed: remove,
      onCloseButtonTap: (item) {
        remove(item);
        toastification.dismiss(item);
      },
      onTap: action == null
          ? null
          : (item) async {
              if (event._actionHandled) return;
              event._actionHandled = true;
              remove(item);
              toastification.dismiss(item);
              try {
                await action();
              } catch (error, stackTrace) {
                logger.e(
                  'In-app notice action failed',
                  error: error,
                  stackTrace: stackTrace,
                );
              }
            },
    ),
  );
  if (key != null) active[key] = shown;
}

void showActionToast(BuildContext context, ToastEvent event) {
  if (event.onTap != null) showToastEvent(context, event);
}

class ToastEvent {
  ToastType type;
  String? title;
  String message;
  Duration duration;
  Future<void> Function()? onTap;
  String? actionLabel;
  final Object? deduplicationKey;
  bool _actionHandled = false;
  final _actionOverlays = Expando<bool>();

  ToastEvent({
    required this.type,
    this.title,
    required this.message,
    required this.duration,
    this.onTap,
    this.actionLabel,
    this.deduplicationKey,
  });
}

void _dispatchToast(ToastEvent event, BuildContext? context) {
  if (context == null) {
    eventBus.fire(event);
  } else {
    showToastEvent(context, event);
  }
}

void showInfoToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 3),
  BuildContext? context,
}) => _dispatchToast(
  ToastEvent(
    type: ToastType.info,
    title: title,
    message: message,
    duration: duration,
  ),
  context,
);

void showSuccessToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 3),
  BuildContext? context,
}) => _dispatchToast(
  ToastEvent(
    type: ToastType.success,
    title: title,
    message: message,
    duration: duration,
  ),
  context,
);

void showWarningToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 4),
  BuildContext? context,
}) => _dispatchToast(
  ToastEvent(
    type: ToastType.warning,
    title: title,
    message: message,
    duration: duration,
  ),
  context,
);

void showErrorToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 5),
  BuildContext? context,
}) => _dispatchToast(
  ToastEvent(
    type: ToastType.error,
    title: title,
    message: message,
    duration: duration,
  ),
  context,
);
