import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Host-owned video defaults. Comic reader preferences and site configuration
/// intentionally use different stores and are never read by the player.
class VideoPlaybackPreferences {
  const VideoPlaybackPreferences({
    this.autoplay = true,
    this.resumeProgress = true,
    this.recordHistory = true,
    this.defaultSpeed = 1,
    this.holdSpeed = 2,
    this.doubleTap = 'seek',
    this.swipeSeek = true,
    this.hideSeconds = 5,
    this.cover = false,
    this.fullscreenOrientation = 'landscape',
    this.controlsStyle = 'system',
    this.portraitMode = 'focus',
  });

  final bool autoplay;
  final bool resumeProgress;
  final bool recordHistory;
  final double defaultSpeed;
  final double holdSpeed;
  final String doubleTap;
  final bool swipeSeek;
  final int hideSeconds;
  final bool cover;
  final String fullscreenOrientation;
  final String controlsStyle;
  final String portraitMode;

  static const defaults = <String, Object>{
    'autoplay': true,
    'resumeProgress': true,
    'recordHistory': true,
    'defaultSpeed': 1.0,
    'holdSpeed': 2.0,
    'doubleTap': 'seek',
    'swipeSeek': true,
    'hideSeconds': 5,
    'cover': false,
    'fullscreenOrientation': 'landscape',
    'controlsStyle': 'system',
    'portraitMode': 'focus',
  };
  static const prefix = 'breeze.video.defaults.';
  static const snapshotKey = '${prefix}snapshot.v1';
  static Future<void>? _writes;

  /// Only a revision signal; credentials and preference values stay in their
  /// existing stores. Players also observe changes made by settings or sync.
  static final _changes = ValueNotifier<int>(0);
  static ValueListenable<int> get changes => _changes;

  static Future<void> _serialize(Future<void> Function() action) async {
    final previous = _writes;
    final write = previous == null
        ? action()
        : previous.catchError((_) {}).then((_) => action());
    _writes = write;
    try {
      await write;
    } finally {
      if (identical(_writes, write)) _writes = null;
    }
  }

  Map<String, Object> toValues() => {
    'autoplay': autoplay,
    'resumeProgress': resumeProgress,
    'recordHistory': recordHistory,
    'defaultSpeed': defaultSpeed,
    'holdSpeed': holdSpeed,
    'doubleTap': doubleTap,
    'swipeSeek': swipeSeek,
    'hideSeconds': hideSeconds,
    'cover': cover,
    'fullscreenOrientation': fullscreenOrientation,
    'controlsStyle': controlsStyle,
    'portraitMode': portraitMode,
  };

  static Map<String, dynamic> _snapshot(SharedPreferences store) {
    try {
      final raw = jsonDecode(store.getString(snapshotKey) ?? '');
      if (raw is Map && raw['version'] == 1 && raw['values'] is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return {};
  }

  static VideoPlaybackPreferences _read(SharedPreferences store) {
    final snapshot = _snapshot(store);
    return VideoPlaybackPreferences.fromValues(
      snapshot.isNotEmpty
          ? Map<String, dynamic>.from(snapshot['values'] as Map)
          : {for (final key in defaults.keys) key: store.get('$prefix$key')},
    );
  }

  static Future<VideoPlaybackPreferences> read() async {
    await _writes?.catchError((_) {});
    final store = await SharedPreferences.getInstance();
    return _read(store);
  }

  /// Zero means untouched defaults; a new installation must not beat an older
  /// real cloud preference with freshly-created default values.
  static Future<int> modifiedAt() async {
    await _writes?.catchError((_) {});
    final store = await SharedPreferences.getInstance();
    final value = _snapshot(store)['updatedAt'];
    return value is int && value > 0 ? value : 0;
  }

  factory VideoPlaybackPreferences.fromValues(Map<String, dynamic> values) {
    double rate(String key, List<double> allowed, double fallback) {
      final raw = values[key];
      final value = raw is num ? raw.toDouble() : null;
      return allowed.contains(value) ? value! : fallback;
    }

    final tap = values['doubleTap'];
    final hide = values['hideSeconds'];
    return VideoPlaybackPreferences(
      autoplay: values['autoplay'] is bool ? values['autoplay'] : true,
      resumeProgress: values['resumeProgress'] is bool
          ? values['resumeProgress']
          : true,
      recordHistory: values['recordHistory'] is bool
          ? values['recordHistory']
          : true,
      defaultSpeed: rate('defaultSpeed', [0.75, 1, 1.25, 1.5, 2], 1),
      holdSpeed: rate('holdSpeed', [0, 1.5, 2, 3], 2),
      doubleTap: ['seek', 'playPause', 'off'].contains(tap) ? tap : 'seek',
      swipeSeek: values['swipeSeek'] is bool ? values['swipeSeek'] : true,
      hideSeconds: [3, 5, 8].contains(hide) ? hide : 5,
      cover: values['cover'] is bool ? values['cover'] : false,
      fullscreenOrientation: values['fullscreenOrientation'] == 'portrait'
          ? 'portrait'
          : 'landscape',
      controlsStyle: values['controlsStyle'] == 'breeze' ? 'breeze' : 'system',
      portraitMode:
          'focus', // Legacy episodes preference no longer enables swipe switching.
    );
  }

  static Future<void> save(String key, Object value) async {
    if (!_valid(key, value)) throw ArgumentError.value(value, key);
    await _serialize(() async {
      final store = await SharedPreferences.getInstance();
      final values = _read(store).toValues()..[key] = value;
      await _writeSnapshot(
        store,
        values,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    });
  }

  static bool _valid(String key, Object? value) {
    if (!defaults.containsKey(key)) return false;
    return switch (key) {
      'defaultSpeed' => value is num && [0.75, 1, 1.25, 1.5, 2].contains(value),
      'holdSpeed' => value is num && [0, 1.5, 2, 3].contains(value),
      'hideSeconds' => value is int && [3, 5, 8].contains(value),
      'doubleTap' => ['seek', 'playPause', 'off'].contains(value),
      'fullscreenOrientation' => ['portrait', 'landscape'].contains(value),
      'controlsStyle' => ['system', 'breeze'].contains(value),
      'portraitMode' => ['focus', 'episodes'].contains(value),
      _ => value is bool,
    };
  }

  /// Restores only declared video fields. Unknown/invalid remote values cannot
  /// overwrite another store, reset good local fields or introduce credentials.
  static Future<void> restore(
    Map<String, dynamic> values, {
    required int updatedAt,
  }) async {
    final valid = {
      for (final entry in values.entries)
        if (_valid(entry.key, entry.value)) entry.key: entry.value as Object,
    };
    if (valid.isEmpty) return;
    await _serialize(() async {
      final store = await SharedPreferences.getInstance();
      final merged = _read(store).toValues()..addAll(valid);
      await _writeSnapshot(store, merged, updatedAt);
    });
  }

  static Future<void> _writeSnapshot(
    SharedPreferences store,
    Map<String, Object> values,
    int updatedAt,
  ) async {
    final saved = await store.setString(
      snapshotKey,
      jsonEncode({'version': 1, 'updatedAt': updatedAt, 'values': values}),
    );
    if (!saved) throw StateError('Video preference was not saved');
    _changes.value++;
  }
}

/// Values declared and persisted by the video-source plugin, consumed by the
/// host's DOM loader/player. No account data or comic preferences are involved.
class VideoSourceOptions {
  const VideoSourceOptions({
    this.website = false,
    this.parseTimeoutSeconds = 30,
    this.preferredSource = 'auto',
    this.refreshExpiredSources = true,
    this.hideAdvertisements = true,
  });
  final bool website;
  final int parseTimeoutSeconds;
  final String preferredSource;
  final bool refreshExpiredSources;
  final bool hideAdvertisements;

  factory VideoSourceOptions.fromValues(Map<String, dynamic> values) {
    final timeout = int.tryParse('${values['video.parseTimeoutSeconds']}');
    final source = values['video.preferredSource'];
    return VideoSourceOptions(
      website: values['video.defaultMode'] == 'website',
      parseTimeoutSeconds: [15, 30, 45].contains(timeout) ? timeout! : 30,
      preferredSource: ['auto', 'highest', 'lowest'].contains(source)
          ? source
          : 'auto',
      refreshExpiredSources: values['video.refreshExpiredSources'] != false,
      hideAdvertisements: values['video.hideAdvertisements'] != false,
    );
  }
}
