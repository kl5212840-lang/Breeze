import 'dart:async';

import 'package:flutter/services.dart';

/// Explicit, bounded requests only. The disabled observer creates no timer and
/// never invokes a platform channel. Only categorical metadata crosses over.
class NativeCompositionCapture {
  NativeCompositionCapture({
    required bool enabled,
    required bool isIOS,
    Future<void> Function(Map<String, Object?>)? send,
  }) : _enabled = enabled && isIOS,
       _send = send ?? _sendNative;

  final bool _enabled;
  final Future<void> Function(Map<String, Object?>) _send;
  final _phases = <String>{};
  final _activeRoutes = <String, int>{};
  static const _diagnosticRoutes = {
    'PluginSettingsRoute',
    'SourceShellRoute',
    'breeze.video.playback-settings',
    'breeze.video.library',
    'breeze.video.local',
    'breeze.video.local-history',
    'breeze.video.catalog-content',
    'breeze.video.omo-detail',
    'breeze.video.bika-detail',
    'breeze.settings.cover-privacy',
    'breeze.image.editor',
    'breeze.video.source-settings',
    'breeze.download.comic-chapters',
    'breeze.download.video-work',
    'breeze.download.settings',
  };
  var _requests = 0;
  var _routeSequence = 0;
  static const _channel = MethodChannel('breeze.native-composition.capture');

  static Future<void> _sendNative(Map<String, Object?> args) async {
    await _channel.invokeMethod<void>('capture', args);
  }

  void observe(Map<String, Object?> sample) {
    if (!_enabled || _requests >= 32) return;
    final event = sample['event'];
    final route = sample['route'];
    if (event == 'route-removed') {
      if (route is String && _activeRoutes.containsKey(route)) {
        final count = _activeRoutes[route]! - 1;
        if (count == 0) {
          _activeRoutes.remove(route);
        } else {
          _activeRoutes[route] = count;
        }
      }
      return;
    }
    if (event == 'route-added') {
      if (route is! String || !_diagnosticRoutes.contains(route)) return;
      _activeRoutes[route] = (_activeRoutes[route] ?? 0) + 1;
      _routeSequence++;
    } else if (_activeRoutes.isEmpty ||
        event != 'native-scene-audit' ||
        sample['sample'] != 'phase-frame') {
      return;
    }
    final epoch = sample['routeEpoch'];
    final phase = sample['phase'];
    final key = '$event|$_routeSequence|$epoch|$phase';
    if (!_phases.add(key)) return;
    _requests++;
    final args = <String, Object?>{
      'event': event,
      'request': _requests,
      if (epoch is int && epoch >= 0) 'routeEpoch': epoch,
      if (phase is String &&
          RegExp(
            r'^(?:completed|dismissed|forward|reverse|none)(?:\|(?:completed|dismissed|forward|reverse|none))*$',
          ).hasMatch(phase) &&
          phase.length <= 160)
        'phase': phase,
    };
    // Do not forward route names, arbitrary diagnostics, URLs or UI content.
    unawaited(_sendSafely(args));
  }

  Future<void> _sendSafely(Map<String, Object?> args) async {
    try {
      await _send(args);
    } catch (_) {
      // A debug probe must never change navigation or show a user error.
    }
  }
}
