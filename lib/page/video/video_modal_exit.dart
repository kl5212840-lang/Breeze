import 'dart:async';

import 'package:flutter/widgets.dart';

/// Flutter releases a modal's own barrier as soon as reverse starts. Keep an
/// invisible hit surface until that exact route completes its exit so a second
/// closing tap cannot reach the video below. No timer or new route is involved.
Future<T?> retainVideoModalExitBarrier<T>(
  Future<T?> shown,
  ModalRoute<T>? Function() currentRoute,
) => shown.then((value) {
  final route = currentRoute();
  final overlay = route?.navigator?.overlay;
  if (route == null ||
      overlay == null ||
      !overlay.mounted ||
      route.animation?.status != AnimationStatus.reverse)
    return value;
  final shield = OverlayEntry(
    builder: (_) =>
        const ExcludeSemantics(child: AbsorbPointer(child: SizedBox.expand())),
  );
  overlay.insert(shield);
  unawaited(
    route.completed.whenComplete(() {
      if (overlay.mounted) shield.remove();
      shield.dispose();
    }),
  );
  return value;
});
