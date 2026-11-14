import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const capacity = MethodChannel('breeze.download.capacity');
  const hls = MethodChannel('breeze.video.hls');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      capacity,
      (_) async => 390 * 1024 * 1024 * 1024,
    );
    messenger.setMockMethodCallHandler(hls, (_) async => const []);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(capacity, null);
    messenger.setMockMethodCallHandler(hls, null);
  });

  test(
    'legacy settings default safely; new settings round-trip with unknown future fields',
    () {
      final legacy = GlobalSettingState.fromJson({});
      expect(legacy.videoDownloadConcurrency, 1);
      expect(legacy.downloadWifiOnly, isFalse);
      expect(legacy.downloadCompletionNotice, 'work');
      final saved = legacy
          .copyWith(
            videoDownloadConcurrency: 3,
            downloadWifiOnly: true,
            downloadCompletionNotice: 'episode',
          )
          .toJson();
      final restored = GlobalSettingState.fromJson({
        ...saved,
        'futureDownloadField': true,
      });
      expect(restored.videoDownloadConcurrency, 3);
      expect(restored.downloadWifiOnly, isTrue);
      expect(restored.downloadCompletionNotice, 'episode');
    },
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'download settings persist and return to the same main page $style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = GlobalSettingCubit()
          ..updateALl(const GlobalSettingState());
        final preference = ValueNotifier(style);
        addTearDown(cubit.close);
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  bottomNavigationBar: const SizedBox(
                    height: 64,
                    child: Text('MAIN NAV'),
                  ),
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => openDownloadSettings(context),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('MAIN NAV').hitTestable(), findsNothing);
        final concurrency = find.byType(SettingChoiceTile<int>);
        tester.widget<SettingChoiceTile<int>>(concurrency).onChanged(2);
        await tester.pumpAndSettle();
        final wifi = find.byKey(const ValueKey('download-wifi-only'));
        await tester.tap(wifi);
        await tester.pumpAndSettle();
        final keepRetrying = find.byKey(
          const ValueKey('download-keep-retrying'),
        );
        await tester.ensureVisible(keepRetrying);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(keepRetrying).value, isTrue);
        await tester.tap(keepRetrying);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(keepRetrying).value, isFalse);
        expect(
          objectbox.userSettingBox
              .get(1)!
              .globalSetting
              .videoDownloadConcurrency,
          2,
        );
        final cold = GlobalSettingCubit();
        await cold.initBox();
        expect(cold.state.videoDownloadConcurrency, 2);
        expect(cold.state.downloadWifiOnly, isTrue);
        expect(cold.state.retryDownloadUntilSuccess, isFalse);
        await cold.close();
        final freeSpace = find.byKey(
          const ValueKey('download-settings-free-space'),
        );
        await tester.scrollUntilVisible(freeSpace, 100);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: freeSpace, matching: find.text('418.8 GB')),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(DownloadSettingsPage))).pop();
        await tester.pumpAndSettle();
        expect(find.text('MAIN NAV').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
