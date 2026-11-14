import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:battery_plus_platform_interface/battery_plus_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/overlay/page_count.dart';

class _BatteryFixture extends BatteryPlatform {
  final initialLevel = Completer<int>();
  final initialState = Completer<BatteryState>();
  final changes = StreamController<BatteryState>.broadcast(sync: true);
  int stateReads = 0;

  @override
  Future<int> get batteryLevel => initialLevel.future;

  @override
  Future<BatteryState> get batteryState {
    stateReads++;
    return initialState.future;
  }

  @override
  Stream<BatteryState> get onBatteryStateChanged => changes.stream;
}

class _ConnectivityFixture extends ConnectivityPlatform {
  final initial = Completer<List<ConnectivityResult>>();
  final changes = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );

  @override
  Future<List<ConnectivityResult>> checkConnectivity() => initial.future;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

Future<void> _showPageInfo(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ReaderCubit()),
        BlocProvider(
          create: (_) {
            final settings = GlobalSettingCubit();
            settings.emit(
              settings.state.copyWith(
                readSetting: const ReadSettingState(pageInfoShowBattery: true),
              ),
            );
            return settings;
          },
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(children: [PageCountWidget(epPages: '12')]),
        ),
      ),
    ),
  );
}

void main() {
  late _BatteryFixture battery;
  late _ConnectivityFixture connectivity;

  void installPlatformFixtures() {
    final previousBattery = BatteryPlatform.instance;
    final previousConnectivity = ConnectivityPlatform.instance;
    battery = _BatteryFixture();
    connectivity = _ConnectivityFixture();
    BatteryPlatform.instance = battery;
    ConnectivityPlatform.instance = connectivity;
    addTearDown(() async {
      BatteryPlatform.instance = previousBattery;
      ConnectivityPlatform.instance = previousConnectivity;
      await battery.changes.close();
      await connectivity.changes.close();
    });
  }

  testWidgets('removing the overlay stops initialization after a late level', (
    tester,
  ) async {
    installPlatformFixtures();
    await _showPageInfo(tester);
    await tester.pumpWidget(const SizedBox.shrink());

    battery.initialLevel.complete(75);
    battery.initialState.complete(BatteryState.charging);
    await tester.pump();

    expect(battery.stateReads, 0);
    expect(battery.changes.hasListener, isFalse);
  });

  testWidgets('late battery and connectivity samples cannot attach listeners', (
    tester,
  ) async {
    installPlatformFixtures();
    battery.initialLevel.complete(75);
    await _showPageInfo(tester);
    await tester.pump();
    expect(battery.stateReads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    battery.initialState.complete(BatteryState.charging);
    connectivity.initial.complete([ConnectivityResult.wifi]);
    await tester.pump();

    expect(
      [battery.changes.hasListener, connectivity.changes.hasListener],
      [false, false],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live overlay keeps the newest transport and charging state', (
    tester,
  ) async {
    installPlatformFixtures();
    battery.initialLevel.complete(75);
    battery.initialState.complete(BatteryState.full);
    await _showPageInfo(tester);
    await tester.pump();
    expect(find.text('1/12'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_5_bar), findsOneWidget);

    connectivity.changes.add([
      ConnectivityResult.mobile,
      ConnectivityResult.wifi,
    ]);
    battery.changes.add(BatteryState.charging);
    await tester.pump();
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.battery_charging_full), findsOneWidget);

    connectivity.initial.complete([ConnectivityResult.none]);
    await tester.pump();
    expect(find.byIcon(Icons.wifi), findsOneWidget);

    connectivity.changes.add([ConnectivityResult.ethernet]);
    await tester.pump();
    expect(find.byIcon(Icons.router), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(battery.changes.hasListener, isFalse);
    expect(connectivity.changes.hasListener, isFalse);
  });
}
