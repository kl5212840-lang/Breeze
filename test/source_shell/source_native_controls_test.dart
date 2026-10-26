import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';

void main() {
  testWidgets(
    'source buttons have equal UIKit geometry independent of playback style',
    (tester) async {
      final native = _NativeChannels()..install();
      addTearDown(native.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: VideoControlAppearance(
            systemControls: false,
            child: Scaffold(
              appBar: AppBar(
                leading: SourceBackButton(onPressed: () {}),
                actions: [
                  SourceMoreButton(
                    actions: [
                      SourceMenuAction(
                        id: 'settings',
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        symbol: 'gearshape',
                        onSelected: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final views = find.byType(UiKitView);
      expect(views, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        final view = tester.widget<UiKitView>(views.at(index));
        final arguments = view.creationParams! as Map;
        expect(tester.getSize(views.at(index)), const Size(44, 44));
        expect(arguments['backgroundInset'], 4);
        expect(arguments['iconSize'], 22);
        expect(arguments['light'], false);
      }
      final menu = tester.widget<UiKitView>(views.last).creationParams! as Map;
      final options = menu['options'] as List;
      expect(options.map((item) => (item as Map)['title']), [
        'Settings',
        t.sourceShell.exitPlugin,
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('fallback More consumes outside taps and can reopen repeatedly', (
    tester,
  ) async {
    var contentTaps = 0;
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: SourceBackButton(onPressed: () {}),
            actions: [
              SourceMoreButton(
                actions: [
                  SourceMenuAction(
                    id: 'action',
                    label: 'Page action',
                    icon: Icons.settings_outlined,
                    symbol: 'gearshape',
                    onSelected: () => actions++,
                  ),
                ],
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => contentTaps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    for (final tooltip in [t.common.back, t.sourceShell.navigationActions]) {
      expect(tester.getSize(find.byTooltip(tooltip)), const Size(44, 44));
    }
    for (var iteration = 0; iteration < 3; iteration++) {
      await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.exitPlugin), findsOneWidget);
      await tester.tapAt(const Offset(100, 400));
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.exitPlugin), findsNothing);
      expect(contentTaps, 0);
    }
    await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page action'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text(t.sourceShell.exitPlugin), findsNothing);
    await tester.tapAt(const Offset(100, 400));
    expect(contentTaps, 1);
  });

  testWidgets(
    'native More exit disposes nested source routes and keeps Discover',
    (tester) async {
      final native = _NativeChannels()..install();
      addTearDown(native.dispose);
      var disposed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (sourceContext) => _RouteLifetime(
                      onDispose: () => disposed++,
                      child: Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(sourceContext).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _RouteLifetime(
                                onDispose: () => disposed++,
                                child: Scaffold(
                                  appBar: AppBar(
                                    actions: const [SourceMoreButton()],
                                  ),
                                  body: const Text('Detail'),
                                ),
                              ),
                            ),
                          ),
                          child: const Text('Open detail'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Discover'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      final menu = tester.widget<UiKitView>(find.byType(UiKitView));
      final options = (menu.creationParams! as Map)['options'] as List;
      await native.send(
        'breeze.video.control',
        'select',
        (options.single as Map)['value'],
      );
      await tester.pumpAndSettle();
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Detail'), findsNothing);
      expect(disposed, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'e-ink retains flat source controls and Material navigation on iOS',
    (tester) async {
      final settings = _EInkSettings();
      addTearDown(settings.close);
      SharedPreferences.setMockInitialValues({});
      await SourceReturnPreferences.load();
      await tester.pumpWidget(
        BlocProvider<GlobalSettingCubit>.value(
          value: settings,
          child: const MaterialApp(
            home: SourceShellPage(
              source: 'test-source',
              sourceName: 'Source',
              sections: [
                SourceShellSection(id: 'discover', title: 'First', scene: null),
                SourceShellSection(id: 'ranking', title: 'Second', scene: null),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(FluentPopupMenuButton<String>), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native source tabs preserve by-function back and use one fitted bottom inset',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SourceReturnPreferences.load();
      final native = _NativeChannels()..install();
      addTearDown(native.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 34),
              viewPadding: const EdgeInsets.only(bottom: 34),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SourceShellPage(
                      source: 'test-source',
                      sourceName: 'Source',
                      sections: [
                        SourceShellSection(
                          id: 'discover',
                          title: 'First',
                          scene: null,
                        ),
                        SourceShellSection(
                          id: 'ranking',
                          title: 'Second',
                          scene: null,
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Discover'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      final bar = tester.widget<VideoNativeNavigation>(
        find.byType(VideoNativeNavigation),
      );
      expect(bar.symbols, ['safari', 'chart.bar']);
      final view = find.byWidgetPredicate(
        (widget) =>
            widget is UiKitView && widget.viewType == 'breeze.video.navigation',
      );
      expect(tester.getSize(view).height, 83);
      await native.send('breeze.video.navigation', 'height', 83);
      await tester.pumpAndSettle();
      expect(tester.getSize(view).height, 83);
      await native.send('breeze.video.navigation', 'select', 1);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VideoNativeNavigation>(find.byType(VideoNativeNavigation))
            .currentIndex,
        1,
      );
      expect(find.byTooltip('${t.common.back} · First'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discover'), findsOneWidget);
      expect(find.byType(SourceShellPage), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _NativeChannels {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final Map<String, MethodChannel> channels = {};
  final List<MethodChannel> _allChannels = [];

  void install() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        final type = arguments['viewType'] as String;
        final channel = MethodChannel('$type.${arguments['id']}');
        channels[type] = channel;
        _allChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  }

  Future<void> send(String type, String method, Object? value) =>
      messenger.handlePlatformMessage(
        channels[type]!.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
        (_) {},
      );

  void dispose() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in _allChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }
}

class _EInkSettings extends GlobalSettingCubit {
  _EInkSettings() {
    emit(
      const GlobalSettingState(eInkSetting: EInkSettingState(enabled: true)),
    );
  }
}

class _RouteLifetime extends StatefulWidget {
  const _RouteLifetime({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_RouteLifetime> createState() => _RouteLifetimeState();
}

class _RouteLifetimeState extends State<_RouteLifetime> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}
