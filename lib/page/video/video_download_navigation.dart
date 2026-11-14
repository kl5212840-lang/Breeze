import 'dart:async';

import 'package:flutter/widgets.dart';

/// Root download sheets must cover the main bottom bar, but their task jump
/// still belongs to the source navigator that originally opened the sheet.
class VideoDownloadNavigationOrigin extends InheritedWidget {
  const VideoDownloadNavigationOrigin({
    super.key,
    required this.origin,
    required super.child,
  });
  final BuildContext origin;
  static BuildContext of(BuildContext context) {
    final origin = context
        .dependOnInheritedWidgetOfExactType<VideoDownloadNavigationOrigin>()
        ?.origin;
    if (origin != null && origin.mounted) return origin;
    return context;
  }

  @override
  bool updateShouldNotify(VideoDownloadNavigationOrigin oldWidget) =>
      !identical(origin, oldWidget.origin);
}

/// Mounted native playback owners, including players retained below a modal or
/// an API-detail download picker. Downloads themselves never register here.
class VideoDownloadPlaybackOwner {
  VideoDownloadPlaybackOwner._(this._pause);
  final Future<bool> Function() _pause;
  bool _closed = false;
  void release() {
    if (_closed) return;
    _closed = true;
    VideoDownloadNavigation._owners.remove(this);
  }
}

abstract final class VideoDownloadNavigation {
  static final _owners = <VideoDownloadPlaybackOwner>{};
  static Future<bool>? _pausing;
  static VideoDownloadPlaybackOwner register(Future<bool> Function() pause) {
    final owner = VideoDownloadPlaybackOwner._(pause);
    _owners.add(owner);
    return owner;
  }

  static Future<bool> pauseBeforeOpeningTasks() {
    final pending = _pausing;
    if (pending != null) return pending;
    final result = _pauseOwners();
    _pausing = result;
    void release() {
      if (identical(_pausing, result)) _pausing = null;
    }

    result.then(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    return result;
  }

  static Future<bool> _pauseOwners() async {
    final checked = <VideoDownloadPlaybackOwner>{};
    // A player added while an older owner awaits its native pause is checked
    // too. Bound unusual route churn rather than navigating with live audio.
    for (var round = 0; round < 8; round++) {
      final owners = _owners
          .where((owner) => !checked.contains(owner))
          .toList();
      if (owners.isEmpty) return true;
      for (final owner in owners) {
        checked.add(owner);
        if (owner._closed) continue;
        try {
          if (!await owner._pause().timeout(const Duration(seconds: 5)))
            return false;
        } catch (_) {
          return false;
        }
      }
    }
    return false;
  }
}
