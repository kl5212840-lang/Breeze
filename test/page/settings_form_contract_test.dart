import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_return_mode_tile.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final nativeMethods = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceReturnPreferences.resetForTests();
    nativeMethods.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final channel = MethodChannel(
          'breeze.video.control.${(call.arguments as Map)['id']}',
        );
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeMethods.add(call.method);
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'large Breeze return value stays complete and commits once ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: SettingPageShell(
                title: t.settings.appBehavior,
                grouped: true,
                child: const SettingListView(
                  children: [SourceReturnModeTile()],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final value = tester.renderObject<RenderParagraph>(
          find.text(t.sourceShell.returnByFunction),
        );
        expect(
          value.didExceedMaxLines,
          isFalse,
          reason:
              'The whole setting value has a full row available at large text',
        );
        await tester.tap(find.text(t.sourceShell.returnMode));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.sourceShell.returnStepByStep));
        await tester.pumpAndSettle();
        expect(
          SourceReturnPreferences.changes.value,
          SourceReturnMode.stepByStep,
        );
        // pumpAndSettle waits for frames, not the serialized preferences write.
        // Observe the backing store rather than treating the optimistic label
        // as proof of persistence.
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 50; attempt++) {
            final store = await SharedPreferences.getInstance();
            await store.reload();
            if (store.getString(SourceReturnPreferences.storageKey) ==
                'stepByStep') {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        });
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(SourceReturnPreferences.storageKey),
          'stepByStep',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      'return setting signals a choice and opens from its title ${brightness.name}',
      (tester) async {
        final style = ValueNotifier('system');
        addTearDown(style.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const Scaffold(body: SourceReturnModeTile()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final native = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(
          (native.creationParams as Map)['selectionIndicator'],
          isTrue,
          reason: 'The current value must visibly communicate selection',
        );
        await tester.tap(find.text(t.sourceShell.returnMode));
        await tester.pumpAndSettle();
        expect(
          nativeMethods.where((method) => method == 'openMenu'),
          hasLength(1),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(SourceReturnPreferences.storageKey), isNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
