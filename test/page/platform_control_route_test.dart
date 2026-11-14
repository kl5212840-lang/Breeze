import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_return_mode_tile.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import '../test_helper.dart';

Widget _navigation() => VideoNativeNavigation(
  key: const ValueKey('navigation'),
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
  ],
  symbols: const ['house', 'person'],
  currentIndex: 1,
  onTap: (_) {},
);

const _origin = ValueKey('origin');

List<State> _originViews(WidgetTester tester) => tester
    .stateList(
      find.descendant(
        of: find.byKey(_origin, skipOffstage: false),
        matching: find.byType(UiKitView, skipOffstage: false),
      ),
    )
    .toList();

Widget _controls() => Column(
  children: [
    NativeVideoIconButton(
      tooltip: 'Action',
      icon: Icons.star,
      symbol: 'star',
      onPressed: () {},
    ),
    NativeVideoTextButton(label: 'Manage', tooltip: 'Manage', onPressed: () {}),
    NativeVideoSegmentedControl(
      options: const {'a': 'First', 'b': 'Second'},
      selected: 'a',
      onSelected: (_) {},
    ),
    SettingChoice(
      value: 'a',
      items: const {'a': 'First', 'b': 'Second'},
      onChanged: (_) {},
    ),
  ],
);

Widget _settings() => Builder(
  builder: (context) => Scaffold(
    appBar: AppBar(
      actions: [
        SourceChromeIconButton(
          icon: Icons.sync,
          symbol: 'arrow.triangle.2.circlepath',
          tooltip: 'Sync',
          onPressed: () {},
        ),
      ],
    ),
    body: PluginSettingsContent(
      from: 'modu',
      pluginRuntimeName: 'fixture',
      state: const PluginSettingsState(
        loading: false,
        hasLoadedSettings: true,
        sections: [
          {
            'title': 'Source settings',
            'fields': [
              {
                'key': 'quality',
                'kind': 'select',
                'label': 'Quality',
                'options': ['Auto', 'High'],
              },
            ],
          },
        ],
        values: {'quality': 'Auto'},
      ),
      debugEnabled: false,
      debugUrl: '',
      deleted: false,
      pluginVersion: 'fixture',
      colorScheme: Theme.of(context).colorScheme,
      onUpdateDebugConfig: ({required enabled, required url}) async {},
      onConfirmDeletePlugin: () async {},
      onUpdatePlugin: () async {},
      onOpenLoginPage: () async {},
      onOpenDetailPage: () async {},
      onCommitField: (_, _) async {},
      onRunAction: (_) async {},
    ),
  ),
);

Widget _app(GlobalKey<NavigatorState> navigator, {Widget? home}) => MaterialApp(
  navigatorKey: navigator,
  // Match the app's bridge for AutoRoute's Flutter Material routes.
  // ignore: deprecated_member_use
  builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
  home:
      home ??
      Scaffold(
        key: _origin,
        body: _controls(),
        bottomNavigationBar: _navigation(),
      ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final nativeCalls = <String, List<MethodCall>>{};
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        nativeCalls[channel.name] = [];
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls[channel.name]!.add(call);
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
    nativeCalls.clear();
  });

  testWidgets(
    'settings and original controls retain their native identities throughout route motion',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator));
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNWidgets(5));
      final originals = _originViews(tester);
      final originalChannels = nativeCalls.keys.toSet();
      final geometry = tester
          .getRect(find.byKey(const ValueKey('navigation')))
          .shift(-tester.getTopLeft(find.byKey(_origin)));
      for (final calls in nativeCalls.values) {
        calls.clear();
      }
      navigator.currentState!.push(
        legacy.MaterialPageRoute<void>(builder: (_) => _settings()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_originViews(tester), orderedEquals(originals));
      final candidate = find.descendant(
        of: find.byType(PluginSettingsContent),
        matching: find.byType(UiKitView),
      );
      expect(candidate, findsOneWidget);
      final candidateState = tester.state(candidate);
      for (final channel in originalChannels) {
        final calls = nativeCalls[channel]!;
        expect(
          calls.any(
            (call) =>
                call.method == 'setTransitionContained' &&
                call.arguments == true,
          ),
          isFalse,
          reason:
              'Withdrawn containment must not be applied to native controls',
        );
        expect(
          calls.where((call) => call.method == 'update'),
          isEmpty,
          reason:
              'Route motion must not rebuild the native glass configuration',
        );
      }
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('navigation'), skipOffstage: false),
            )
            .shift(
              -tester.getTopLeft(find.byKey(_origin, skipOffstage: false)),
            ),
        geometry,
      );
      await tester.pumpAndSettle();
      expect(tester.state(candidate), same(candidateState));
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_originViews(tester), orderedEquals(originals));
      await tester.pumpAndSettle();
      expect(_originViews(tester), orderedEquals(originals));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('AutoRoute settings keep original native view identities', (
    tester,
  ) async {
    final router = RootStackRouter.build(
      routes: [
        NamedRouteDef(
          name: 'Home',
          path: '/',
          initial: true,
          builder: (_, _) => Scaffold(
            key: _origin,
            body: _controls(),
            bottomNavigationBar: _navigation(),
          ),
        ),
        NamedRouteDef(
          name: 'Settings',
          path: '/settings',
          builder: (_, _) => _settings(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        // ignore: deprecated_member_use
        builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
      ),
    );
    await tester.pumpAndSettle();
    final originals = _originViews(tester);
    router.push(const PageRouteInfo('Settings'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PluginSettingsContent), findsOneWidget);
    expect(_originViews(tester), orderedEquals(originals));
    await tester.pumpAndSettle();
    router.maybePop();
    await tester.pumpAndSettle();
    expect(_originViews(tester), orderedEquals(originals));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('nested tab native identities survive parent route motion', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        navigator,
        home: Scaffold(
          key: _origin,
          body: Navigator(
            onGenerateRoute: (_) => legacy.MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: _controls()),
            ),
          ),
          bottomNavigationBar: _navigation(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final originals = _originViews(tester);
    expect(originals, hasLength(5));
    navigator.currentState!.push(
      legacy.MaterialPageRoute<void>(builder: (_) => _settings()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_originViews(tester), orderedEquals(originals));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_originViews(tester), orderedEquals(originals));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'popup entry and exit retain underlying platform view identities',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator));
      await tester.pumpAndSettle();
      final originals = _originViews(tester);
      showDialog<void>(
        context: tester.element(find.byType(SettingChoice<String>)),
        builder: (_) => AlertDialog(
          content: SizedBox(
            width: 200,
            child: SourceChoiceMenu(
              value: 'a',
              label: 'First',
              tooltip: 'Choose',
              options: const {'a': 'First', 'b': 'Second'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_originViews(tester), orderedEquals(originals));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_originViews(tester), orderedEquals(originals));
      await tester.pumpAndSettle();
      expect(_originViews(tester), orderedEquals(originals));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'cancelled Navigator gesture retains native identities and selection',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        legacy.MaterialPageRoute<void>(
          builder: (_) =>
              Scaffold(body: _controls(), bottomNavigationBar: _navigation()),
        ),
      );
      await tester.pumpAndSettle();
      final foreground = tester.stateList(find.byType(UiKitView)).toList();
      final originals = _originViews(tester);
      navigator.currentState!.didStartUserGesture();
      await tester.pump();
      expect(_originViews(tester), orderedEquals(originals));
      expect(
        tester.stateList(find.byType(UiKitView)),
        orderedEquals(foreground),
      );
      navigator.currentState!.didStopUserGesture();
      await tester.pumpAndSettle();
      expect(
        tester.stateList(find.byType(UiKitView)),
        orderedEquals(foreground),
      );
      expect(
        tester
            .widget<VideoNativeNavigation>(find.byType(VideoNativeNavigation))
            .currentIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('app-wide return setting retains its original native identity', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        navigator,
        home: const Scaffold(key: _origin, body: SourceReturnModeTile()),
      ),
    );
    await tester.pumpAndSettle();
    final originals = _originViews(tester);
    expect(originals, hasLength(1));
    for (final calls in nativeCalls.values) {
      calls.clear();
    }
    navigator.currentState!.push(
      legacy.MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_originViews(tester), orderedEquals(originals));
    expect(
      nativeCalls.values
          .expand((calls) => calls)
          .where(
            (call) =>
                call.method == 'setTransitionContained' &&
                call.arguments == true,
          ),
      isEmpty,
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_originViews(tester), orderedEquals(originals));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
