import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:zephyr/page/video/omo_network.dart';

/// Requests a small frame for the visible scrubber target on the active player.
class VideoSeekPreviewController extends ChangeNotifier {
  static const _channel = MethodChannel('breeze.video.seek-preview');
  static const _requestInterval = Duration(milliseconds: 160);
  static const _progressiveRetargetDelay = Duration(milliseconds: 1800);
  static const _bucketMs = 1000;
  static const _cacheLimit = 8;
  static int _nextRequest = 0;
  static int _nextOwner = 0;

  final _frames = <int, Uint8List?>{};
  final _progressiveMisses = <int>{};
  VideoPlayerController? _player;
  int? _owner;
  bool _streaming = false;
  bool _wideThumbnail = false;
  int? _target;
  ({int id, int bucket})? _inFlight;
  Timer? _timer;
  Timer? _deadline;
  Timer? _retarget;
  int _consecutiveFailures = 0;
  int? _lastFailedBucket;
  bool _foreground = true;
  bool _disposed = false;
  Uint8List? _frame;

  Uint8List? get frame => _frame;

  static bool supports(VideoPlayerController? player) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) &&
      player != null &&
      player.value.isInitialized &&
      !player.value.hasError &&
      player.value.duration.inMilliseconds > 0 &&
      (player.dataSourceType == DataSourceType.file ||
          player.dataSourceType == DataSourceType.network &&
              (defaultTargetPlatform == TargetPlatform.iOS ||
                  const {
                    'http',
                    'https',
                  }.contains(Uri.tryParse(player.dataSource)?.scheme)));

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) clear();
  }

  static bool _usesHls(VideoPlayerController player) {
    final path = Uri.tryParse(player.dataSource)?.path.toLowerCase() ?? '';
    return player.formatHint == VideoFormat.hls ||
        path.endsWith('.m3u8') ||
        path.endsWith('.movpkg');
  }

  static bool _isProgressive(VideoPlayerController player) =>
      player.dataSourceType == DataSourceType.network && !_usesHls(player);

  void _attach(VideoPlayerController player, bool wideThumbnail) {
    clear();
    _player = player;
    _owner = ++_nextOwner;
    _wideThumbnail = wideThumbnail;
    _streaming = _usesHls(player);
  }

  /// Warm the index of a progressive file after the main player is advancing.
  void prepare(VideoPlayerController player, {bool wideThumbnail = false}) {
    if (_disposed ||
        !_foreground ||
        identical(_player, player) ||
        !supports(player) ||
        !_isProgressive(player)) {
      return;
    }
    _attach(player, wideThumbnail);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_prepare(player));
    }
  }

  Map<String, Object?> _sourceArguments(VideoPlayerController player) => {
    'owner': _owner,
    'url': player.dataSource,
    'headers': player.httpHeaders,
    'streaming': _streaming,
    'wideThumbnail': _wideThumbnail,
  };

  Future<void> _prepare(VideoPlayerController player) async {
    try {
      await _channel.invokeMethod<void>('prepare', _sourceArguments(player));
    } on PlatformException {
      // A thumbnail can still be decoded on demand.
    } on MissingPluginException {
      // This embedder does not provide a preview reader.
    }
  }

  void update(
    VideoPlayerController player,
    Duration target, {
    bool wideThumbnail = false,
  }) {
    if (_disposed || !_foreground) return;
    if (!supports(player)) {
      clear();
      return;
    }
    final duration = player.value.duration.inMilliseconds;
    if (!identical(_player, player) || _wideThumbnail != wideThumbnail) {
      _attach(player, wideThumbnail);
    }
    final bucket = target.inMilliseconds.clamp(0, duration - 1) ~/ _bucketMs;
    if (_target == bucket) return;
    _target = bucket;
    final failed = _lastFailedBucket;
    if (failed != null && (bucket - failed).abs() > 1) {
      _consecutiveFailures = 0;
      _lastFailedBucket = null;
    }
    _showTargetFrame();
    _retarget?.cancel();
    _retarget = null;
    final request = _inFlight;
    if (request != null &&
        player.dataSourceType == DataSourceType.network &&
        (bucket - request.bucket).abs() > 1 &&
        !_frames.containsKey(bucket)) {
      // Replacing a progressive read on each small pause can cancel all
      // frames during a sweep. Retarget only once the new position settles.
      final delay = _isProgressive(player)
          ? _progressiveRetargetDelay
          : _requestInterval;
      _retarget = Timer(delay, () {
        _retarget = null;
        if (_inFlight != request) return;
        _cancelActiveFrame();
        _schedule();
      });
    }
    _schedule();
  }

  void _schedule({bool coalesced = false}) {
    final bucket = _target;
    if (bucket == null ||
        _consecutiveFailures >= 2 ||
        _frames.containsKey(bucket) ||
        _timer != null ||
        _inFlight != null) {
      return;
    }
    final player = _player;
    if (player == null ||
        !player.value.isInitialized ||
        player.value.hasError) {
      return;
    }
    if (_isProgressive(player)) {
      if (!coalesced) {
        // The gesture starts at the current playback position. Give its
        // intentional target a chance to replace that origin before reading.
        _timer = Timer(_requestInterval, () {
          _timer = null;
          _schedule(coalesced: true);
        });
        return;
      }
    } else {
      _timer = Timer(_requestInterval, () {
        _timer = null;
        _schedule();
      });
    }
    unawaited(_read(player, bucket));
  }

  Future<void> _read(VideoPlayerController player, int bucket) async {
    final id = ++_nextRequest;
    _inFlight = (id: id, bucket: bucket);
    final position = Duration(milliseconds: bucket * _bucketMs);
    final cached = omoCachedSeekWindow(player, position);
    final hasKeyframeTrack =
        cached == null && omoIFrameSeekTrack(player) != null;
    final timeout = Duration(
      milliseconds: switch ((cached != null, hasKeyframeTrack)) {
        (true, _) => 7300,
        (_, true) => 8000,
        _ =>
          _streaming || player.dataSourceType == DataSourceType.network
              ? 6500
              : 2500,
      },
    );
    _deadline = Timer(timeout, () {
      unawaited(_release('cancel', id));
      _finish(id, bucket, null);
    });
    Uint8List? result;
    final arguments = {
      ..._sourceArguments(player),
      'id': id,
      'milliseconds': position.inMilliseconds,
      'streaming': _streaming || cached != null || hasKeyframeTrack,
    };
    try {
      if (cached != null || hasKeyframeTrack) {
        result = await _requestFrame({
          ...arguments,
          if (cached != null) ...{
            'url': cached.url.toString(),
            'milliseconds': cached.position.inMilliseconds,
            'cachedWindow': true,
          },
          // AVFoundation selects the advertised I-frames from the master.
          if (hasKeyframeTrack) 'keyframeTrack': true,
        });
        if (result != null || _inFlight?.id != id) return;
      }
      result = await _requestFrame(arguments);
    } finally {
      _finish(id, bucket, result);
    }
  }

  Future<Uint8List?> _requestFrame(Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<Uint8List>('frame', arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void _finish(int id, int bucket, Uint8List? result) {
    if (_inFlight?.id != id) return;
    _inFlight = null;
    _deadline?.cancel();
    _deadline = null;
    _retarget?.cancel();
    _retarget = null;
    final target = _target;
    final player = _player;
    final retryable =
        result == null &&
        player != null &&
        _isProgressive(player) &&
        _progressiveMisses.add(bucket);
    if (retryable) {
      // A transient empty read must not mark its bucket as unavailable.
      _schedule();
      return;
    }
    if (result != null) {
      _progressiveMisses.remove(bucket);
      _consecutiveFailures = 0;
      _lastFailedBucket = null;
    } else if (target != null && (target - bucket).abs() <= 1) {
      _consecutiveFailures++;
      _lastFailedBucket = bucket;
    }
    _frames[bucket] = result;
    if (_frames.length > _cacheLimit) _frames.remove(_frames.keys.first);
    _showTargetFrame();
    _schedule();
  }

  void _cancelActiveFrame() {
    _deadline?.cancel();
    _deadline = null;
    final request = _inFlight;
    _inFlight = null;
    if (request != null) unawaited(_release('cancel', request.id));
  }

  Future<void> _release(String method, int id) async {
    try {
      await _channel.invokeMethod<void>(method, id);
    } on PlatformException {
      // Native work is also bounded by its own deadline.
    } on MissingPluginException {
      // There is no native request to cancel.
    }
  }

  void _showTargetFrame() {
    final bucket = _target;
    if (bucket == null) return;
    final nearby =
        _frames[bucket] ?? _frames[bucket - 1] ?? _frames[bucket + 1];
    final player = _player;
    if (nearby != null || player != null && _isProgressive(player)) {
      _showFrame(nearby);
    }
  }

  void _showFrame(Uint8List? frame) {
    if (identical(_frame, frame)) return;
    _frame = frame;
    if (!_disposed) notifyListeners();
  }

  /// Leaves the small frame cache with the current source for the next drag.
  void endScrub() {
    _timer?.cancel();
    _timer = null;
    _retarget?.cancel();
    _retarget = null;
    _cancelActiveFrame();
    _target = null;
    _frames.removeWhere((_, image) => image == null);
    _progressiveMisses.clear();
    _consecutiveFailures = 0;
    _lastFailedBucket = null;
    _showFrame(null);
  }

  void clear() {
    endScrub();
    final owner = _owner;
    if (owner != null) unawaited(_release('close', owner));
    _owner = null;
    _player = null;
    _frames.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}
