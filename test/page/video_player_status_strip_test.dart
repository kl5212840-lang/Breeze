import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_player_status_strip.dart';

const _battery = MethodChannel('dev.fluttercommunity.plus/battery');
const _charging = MethodChannel('dev.fluttercommunity.plus/charging');
const _connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _network = MethodChannel('dev.fluttercommunity.plus/connectivity_status');

class _PlatformStatus {
  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final _methods = <String>[];
  final chargingEvents = <String>[];
  final networkEvents = <String>[];
  int level = 64;
  String power = 'discharging';
  List<String> connections = ['mobile', 'wifi'];

  List<String> get methods => List.unmodifiable(_methods);

  void install() {
    _messenger.setMockMethodCallHandler(_battery, (call) async {
      _methods.add(call.method);
      return switch (call.method) {
        'getBatteryLevel' => level,
        'getBatteryState' => power,
        _ => throw MissingPluginException(),
      };
    });
    _messenger.setMockMethodCallHandler(_connectivity, (call) async {
      _methods.add(call.method);
      if (call.method == 'check') return connections;
      throw MissingPluginException();
    });
    _messenger.setMockMethodCallHandler(_charging, (call) async {
      chargingEvents.add(call.method);
      return null;
    });
    _messenger.setMockMethodCallHandler(_network, (call) async {
      networkEvents.add(call.method);
      return null;
    });
    addTearDown(() {
      for (final channel in [_battery, _charging, _connectivity, _network]) {
        _messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }

  Future<void> emit(MethodChannel channel, Object value) =>
      _messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(value),
        (_) {},
      );
}

Widget _host(bool visible, {bool offline = false}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
  home: Scaffold(
    body: VideoPlayerStatusStrip(visible: visible, offline: offline),
  ),
);

void main() {
  testWidgets('reads device status and updates through plugin channels', (
    tester,
  ) async {
    final platform = _PlatformStatus()..install();
    await tester.pumpWidget(_host(true, offline: true));
    await tester.pump();

    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.byIcon(Icons.battery_std_rounded), findsOneWidget);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);
    final strip = tester.getRect(find.byType(VideoPlayerStatusStrip));
    final clock = tester.getRect(
      find.byKey(const ValueKey('video-player-clock')),
    );
    final network = tester.getRect(find.byIcon(Icons.wifi_rounded));
    expect(clock.center.dx, closeTo(strip.center.dx, .01));
    expect(network.left, greaterThan(clock.right));
    expect(tester.getRect(find.text('Offline')).left, greaterThan(clock.right));

    platform.level = 67;
    await platform.emit(_charging, 'charging');
    await platform.emit(_network, ['mobile']);
    await tester.pump();

    expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(platform.chargingEvents, ['listen', 'cancel']);
    expect(platform.networkEvents, ['listen', 'cancel']);
  });

  testWidgets('invalid battery data is hidden and hidden controls stop reads', (
    tester,
  ) async {
    final platform = _PlatformStatus()
      ..level = -1
      ..connections = ['none']
      ..install();
    await tester.pumpWidget(_host(false));
    await tester.pump();
    expect(platform.methods, isEmpty);
    expect(platform.networkEvents, isEmpty);
    expect(platform.chargingEvents, isEmpty);

    await tester.pumpWidget(_host(true));
    await tester.pump();
    expect(find.textContaining(RegExp(r'%$')), findsNothing);
    expect(find.byIcon(Icons.wifi_rounded), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);

    platform.level = 12;
    await platform.emit(_charging, 'discharging');
    await tester.pump();
    expect(find.text('12%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_alert_rounded), findsOneWidget);

    platform.level = 101;
    await platform.emit(_charging, 'charging');
    await tester.pump();
    expect(find.textContaining(RegExp(r'%$')), findsNothing);

    await tester.pumpWidget(_host(false));
    await tester.pump();
    final readsBefore = platform.methods;
    await tester.pump(const Duration(minutes: 2));
    expect(platform.methods, readsBefore);
    expect(platform.chargingEvents, ['listen', 'cancel']);
    expect(platform.networkEvents, ['listen', 'cancel']);
    expect(tester.takeException(), isNull);
  });
}
