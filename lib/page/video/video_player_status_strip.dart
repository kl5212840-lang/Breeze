import 'dart:async';
import 'dart:math' show pi;
import 'dart:ui' show FontFeature;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Device status in immersive playback, where the system status bar is hidden.
class VideoPlayerStatusStrip extends StatefulWidget {
  const VideoPlayerStatusStrip({
    super.key,
    required this.visible,
    this.offline = false,
  });

  final bool visible;
  final bool offline;

  @override
  State<VideoPlayerStatusStrip> createState() => _VideoPlayerStatusStripState();
}

class _VideoPlayerStatusStripState extends State<VideoPlayerStatusStrip> {
  final _battery = Battery();
  final _connectivity = Connectivity();
  DateTime _time = DateTime.now();
  int? _level;
  BatteryState? _batteryState;
  List<ConnectivityResult> _network = const [];
  Timer? _minute;
  StreamSubscription<BatteryState>? _charging;
  StreamSubscription<List<ConnectivityResult>>? _networkChanges;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _start();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerStatusStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _start();
    } else {
      _stop();
    }
  }

  bool _current(int generation) => mounted && _generation == generation;

  Future<T?> _read<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      // The simulator and some devices do not report every status field.
      return null;
    }
  }

  Future<void> _readPower(int generation) async {
    final level = await _read(() => _battery.batteryLevel);
    if (!_current(generation)) return;
    setState(
      () => _level = level != null && level >= 0 && level <= 100 ? level : null,
    );
  }

  void _scheduleMinute(int generation) {
    final now = DateTime.now();
    final nextMinute = now.add(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
    );
    _minute = Timer(nextMinute.difference(now), () {
      if (!_current(generation)) return;
      setState(() => _time = DateTime.now());
      unawaited(_readPower(generation));
      _scheduleMinute(generation);
    });
  }

  void _start() {
    final generation = ++_generation;
    _time = DateTime.now();
    _scheduleMinute(generation);
    unawaited(_readPower(generation));
    // The snapshot also confirms the platform implementation exists before
    // opening an event channel. Some playback hosts only implement the player.
    unawaited(
      _read(() => _battery.batteryState).then((state) {
        if (!_current(generation)) return;
        setState(() => _batteryState = state);
        if (state == null) return;
        _charging = _battery.onBatteryStateChanged.listen((value) {
          if (!_current(generation)) return;
          setState(() => _batteryState = value);
          unawaited(_readPower(generation));
        }, onError: (Object _) {});
      }),
    );
    unawaited(
      _read(_connectivity.checkConnectivity).then((results) {
        if (!_current(generation)) return;
        setState(() => _network = results ?? const []);
        if (results == null) return;
        _networkChanges = _connectivity.onConnectivityChanged.listen((values) {
          if (!_current(generation)) return;
          setState(() => _network = values);
        }, onError: (Object _) {});
      }),
    );
  }

  void _stop() {
    _generation++;
    _minute?.cancel();
    unawaited(_charging?.cancel());
    unawaited(_networkChanges?.cancel());
    _charging = null;
    _networkChanges = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final wifi = _network.contains(ConnectivityResult.wifi);
    final mobile = _network.contains(ConnectivityResult.mobile);
    final charging = _batteryState == BatteryState.charging;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final safeInsets = MediaQuery.paddingOf(context);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      excluding: !widget.visible,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            const Spacer(flex: 2),
            Expanded(
              child: Transform.translate(
                offset: Offset((safeInsets.right - safeInsets.left) / 2, 0),
                child: Text(
                  clock,
                  key: const ValueKey('video-player-clock'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      if (widget.offline)
                        Text(chinese ? '本地播放' : 'Offline', style: style),
                      if (wifi || mobile)
                        Icon(
                          wifi
                              ? Icons.wifi_rounded
                              : Icons.signal_cellular_alt_rounded,
                          color: Colors.white70,
                          size: 15,
                          semanticLabel: wifi
                              ? 'Wi-Fi'
                              : t.reader.networkStatus,
                        ),
                      if (_level case final level?)
                        Semantics(
                          label:
                              '${t.reader.battery} $level%${charging ? (chinese ? '，充电中' : ', charging') : ''}',
                          excludeSemantics: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Text('$level%', style: style),
                              Transform.rotate(
                                angle: pi / 2,
                                child: Icon(
                                  charging
                                      ? Icons.battery_charging_full_rounded
                                      : level <= 15
                                      ? Icons.battery_alert_rounded
                                      : Icons.battery_std_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
