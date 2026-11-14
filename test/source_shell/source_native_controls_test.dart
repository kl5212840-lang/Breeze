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
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_tools_tile.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';


void _openDiagnosticSettings(BuildContext context, String source) {
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => SettingPageShell(
    title: 'Source diagnostic settings', child: SourceDiagnosticToolsTile(source: source),
  )));
}

void main() {
  testWidgets(
    'all maintained sources share opt-in analysis and a settings switch',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      NativeVideoMenu menu() => tester.widget(find.byType(NativeVideoMenu));
      for (final source in [
        'bika',
        'jm',
        'copy',
        'hanime',
        'ikun',
        'oscar',
        'modu',
        'omo',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: [Builder(builder: (context) => SourceMoreButton(
                source: source,
                onOpenSettings: () => _openDiagnosticSettings(context, source),
              ))]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(menu().options.containsKey('analysis'), isFalse, reason: source);
        await SourceDiagnosticPreferences.setEnabled(source, true);
        await tester.pumpAndSettle();
        expect(
          menu().options['analysis'],
          t.videoPlayback.pageAnalysis,
          reason: source,
        );
        await SourceDiagnosticPreferences.setEnabled(source, false);
        await tester.pumpAndSettle();
        expect(menu().options.containsKey('analysis'), isFalse, reason: source);
      }
      menu().onSelected('__source_settings');
      await tester.pumpAndSettle();
      expect(find.byType(SourceDiagnosticToolsTile), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(await SourceDiagnosticPreferences.enabled('omo'), isTrue);
      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      menu().onSelected('analysis');
      await tester.pumpAndSettle();
      expect(find.textContaining(t.sourceShell.analysisLimit), findsOneWidget);
      expect(find.text(t.sourceShell.analysisRead), findsOneWidget);
    },
  );

  testWidgets('empty source never exposes an injected analysis callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SourceMoreButton(
                actions: [
                  SourceMenuAction(
                    id: 'analysis',
                    label: 'Analysis',
                    icon: Icons.analytics,
                    symbol: 'waveform.path.ecg',
                    onSelected: () => fail('Empty source callback'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
    expect(menu.options.containsKey('analysis'), isFalse);
    menu.onSelected('analysis');
  });

  testWidgets('enabled page analysis stays a temporary main-menu shortcut', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    var analyses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (sourceContext, active, child) => Scaffold(
            appBar: AppBar(
              actions: [
                SourceMoreButton(
                  source: 'test-diagnostic',
                  onOpenSettings: () => _openDiagnosticSettings(sourceContext, 'test-diagnostic'),
                  actions: [
                    if (active)
                      SourceMenuAction(
                        id: 'analysis',
                        label: t.videoPlayback.pageAnalysis,
                        icon: Icons.analytics_outlined,
                        symbol: 'waveform.path.ecg',
                        onSelected: () => analyses++,
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
    NativeVideoMenu menu() => tester.widget(find.byType(NativeVideoMenu));
    expect(menu().options.containsKey('analysis'), isFalse);
    await SourceDiagnosticPreferences.setEnabled('test-diagnostic', true);
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(menu().options['analysis'], t.videoPlayback.pageAnalysis);
    menu().onSelected('analysis');
    await tester.pumpAndSettle();
    expect(analyses, 1);
    menu().onSelected('__source_settings');
    await tester.pumpAndSettle();
    expect(find.text(t.videoPlayback.pageAnalysis), findsNothing);
    await tester.tap(find.byType(SourceBackButton));
    await tester.pumpAndSettle();
    await SourceDiagnosticPreferences.setEnabled('test-diagnostic', false);
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(menu().options.containsKey('analysis'), isFalse);
  });

  testWidgets(
    'global style changes existing plugin chrome without replacing page content',
    (tester) async {
      final native = _NativeChannels()..install();
      addTearDown(native.dispose);
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(leading: SourceBackButton(onPressed: () {})),
              body: const Text('Retained content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      final content = tester.element(find.text('Retained content'));
      style.value = 'breeze';
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.element(find.text('Retained content')), same(content));
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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
      final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
      expect(menu.options.values, [
        t.discover.settings,
        t.sourceShell.exitPlugin,
      ]);
      expect(menu.groups, [
        ['__source_settings'],
        ['__source_exit'],
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

  testWidgets('settings shortcut opens its formal target using source context', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (sourceContext) => Scaffold(
            appBar: AppBar(
              actions: [
                SourceMoreButton(
                  actions: [
                    SourceMenuAction(
                      id: 'display',
                      label: 'Change view',
                      icon: Icons.grid_view,
                      symbol: 'square.grid.2x2',
                      onSelected: () {},
                    ),
                    SourceMenuAction(
                      id: 'play',
                      label: 'Playback settings',
                      icon: Icons.play_circle_outline,
                      symbol: 'play.rectangle',
                      onSelected: () {
                        calls++;
                        Navigator.of(sourceContext).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Playback page'),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            body: const Text('Source page'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
    await tester.pumpAndSettle();
    expect(find.text('Change view'), findsOneWidget);
    expect(find.text('Playback settings'), findsNothing);
    expect(find.byType(Divider), findsNWidgets(2));
    await tester.tap(find.text(t.discover.settings));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Playback page'), findsOneWidget);
    expect(find.text(t.sourceShell.appSettings), findsNothing);
    expect(find.text(t.sourceShell.settingsBackup), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Source page'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      // The native glass layer dispatches its chosen command directly; it
      // does not insert Flutter menu rows into the widget tree.
      await native.send('breeze.video.control', 'select', '__source_exit');
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
      expect(find.byType(NativeVideoMenu), findsOneWidget);
      await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
      await tester.pumpAndSettle();
      expect(find.text(t.discover.settings), findsOneWidget);
      expect(find.text(t.sourceShell.exitPlugin), findsOneWidget);
      await tester.tapAt(const Offset(100, 400));
      await tester.pumpAndSettle();
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
