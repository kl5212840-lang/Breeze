import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart' as sdk;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/source_shell/source_settings_hub.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/page/video/video_profile_header.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _source = '78617c71-313f-42fe-9317-460d691890b2';

class _SettingsApi extends RustLibApi {
  final calls = <String>[];
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('canonical-settings-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    calls.add(fnPath);
    final result = fnPath == 'getSettingsBundle'
        ? {
            'scheme': {
              'sections': [
                {
                  'title': 'Source options',
                  'fields': [
                    {
                      'key': 'video.refreshExpiredSources',
                      'kind': 'switch',
                      'label': 'Retry expired media',
                    },
                  ],
                },
              ],
            },
            'data': {
              'mediaType': 'video',
              'canLogin': false,
              'canShowUserInfo': false,
              'values': {
                'video.refreshExpiredSources':
                    (jsonDecode(
                          onLoadPluginConfig(
                            _source,
                            'video.refreshExpiredSources',
                            'true',
                          ),
                        )
                        as Map)['value'],
              },
            },
          }
        : {'data': <String, dynamic>{}};
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _SettingsApi();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final native = <MethodChannel>[];
  final nativeControls = <int, ({String channel, String tooltip})>{};

  Future<void> pressBack(WidgetTester tester) async {
    final back = find.byType(SourceBackButton);
    expect(back, findsOneWidget);
    final views = find.descendant(of: back, matching: find.byType(UiKitView));
    if (views.evaluate().isNotEmpty) {
      expect(views, findsOneWidget);
      final nativeViews = <RenderUiKitView>[];
      void visit(RenderObject object) {
        if (object is RenderUiKitView) nativeViews.add(object);
        object.visitChildren(visit);
      }
      final subtree = tester.element(views).findRenderObject();
      expect(subtree, isNotNull);
      visit(subtree!);
      expect(nativeViews, hasLength(1),
        reason: 'only the real platform view inside the active back button is addressed');
      final control = nativeControls[nativeViews.single.viewController.id];
      expect(
        control,
        isNotNull,
        reason: 'the visible UIKit back button has its actual per-view channel',
      );
      expect(control!.tooltip, t.common.back);
      tester.binding.channelBuffers.push(
        control.channel,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
      await tester.pump();
    } else {
      final button = find.descendant(
        of: back,
        matching: find.byTooltip(t.common.back),
      );
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
    }
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'retained-login-backup-fixture': 'saved-fixture',
    });
    await savePluginConfigValue(_source, 'video.refreshExpiredSources', true);
    api.calls.clear();
    nativeControls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        native.add(channel);
        if (args['viewType'] == 'breeze.video.control') {
          final raw = args['params'];
          final bytes = raw is ByteData
              ? raw
              : raw is Uint8List
              ? ByteData.sublistView(raw)
              : null;
          final params = bytes == null
              ? null
              : const StandardMessageCodec().decodeMessage(bytes);
          if (params is Map && params['tooltip'] is String) {
            nativeControls[args['id'] as int] = (
              channel: channel.name,
              tooltip: params['tooltip'] as String,
            );
          }
        }
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in native) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    native.clear();
  });

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'source More waits for the $style menu and links the AutoRoute settings transition',
      (tester) async {
        final registry = PluginRegistryCubit();
        final preference = ValueNotifier(style);
        final routes = _Routes();
        final router = RootStackRouter.build(
          defaultRouteType: RouteType.material(
            enablePredictiveBackGesture: false,
          ),
          routes: [
            NamedRouteDef(
              name: 'SourceShellRoute',
              path: '/',
              initial: true,
              builder: (_, _) => Scaffold(
                appBar: AppBar(actions: const [SourceMoreButton(source: _source)]),
                body: const Text('Source content'),
              ),
            ),
          ],
        );
        addTearDown(registry.close);
        addTearDown(preference.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: registry,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp.router(
                routerConfig: router.config(navigatorObservers: () => [routes]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourcePage = routes.pushed.single as PageRoute<dynamic>;
        final sourceContent = tester.element(find.text('Source content'));
        expect(sourcePage.settings, isA<AutoRoutePage>());
        if (style == 'system') {
          final nativeMenu = tester.widget<UiKitView>(find.byType(UiKitView));
          final arguments = nativeMenu.creationParams! as Map;
          expect(arguments['selectAfterDismissal'], contains('__source_settings'));
          final control = nativeControls.values.single;
          Future<void> send(String method, Object? value) =>
              messenger.handlePlatformMessage(
                control.channel,
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall(method, value),
                ),
                (_) {},
              );
          await send('menuOpened', {'generation': 1});
          await tester.pump();
          expect(routes.pushed.last, same(sourcePage));
          await send('menuClosed', {'generation': 1});
          await send('select', '__source_settings');
          await tester.pump();
        } else {
          await tester.tap(find.byTooltip(t.sourceShell.navigationActions));
          await tester.pumpAndSettle();
          final menu = routes.pushed.last as PopupRoute<dynamic>;
          await tester.tap(find.text(t.discover.settings));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
          expect(menu.animation!.status, AnimationStatus.reverse);
          expect(routes.pushed.last, same(menu));
          await tester.pump(menu.reverseTransitionDuration);
          await tester.pump();
        }
        final settings = routes.pushed.last as PageRoute<dynamic>;
        expect(settings.settings.name, 'PluginSettingsRoute');
        expect(settings, isA<sdk.CupertinoPageRoute<void>>());
        expect(settings.navigator, same(sourcePage.navigator));
        expect(sourcePage.canTransitionTo(settings), isTrue);
        await tester.pump(const Duration(milliseconds: 80));
        expect(sourcePage.secondaryAnimation!.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byType(PluginSettingsPage), findsOneWidget);
        await pressBack(tester);
        expect(tester.element(find.text('Source content')), same(sourceContent));
        expect(find.byType(PluginSettingsPage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'one formal source root $style persists source and common preferences and returns to the same source',
      (tester) async {
        final registry = PluginRegistryCubit(),
            preference = ValueNotifier(style);
        final sourceQuery = TextEditingController(text: 'retained local query');
        final routes = _Routes();
        addTearDown(registry.close);
        addTearDown(preference.dispose);
        addTearDown(sourceQuery.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: registry,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                navigatorObservers: [routes],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        TextField(controller: sourceQuery),
                        VideoAccountTools(
                          onSourceSettings: () => unawaited(
                            openSourceSettings(
                              context,
                              source: _source,
                              sourceName: 'Fixture',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(t.discover.settings));
        await tester.pumpAndSettle();
        expect(find.byType(PluginSettingsPage), findsOneWidget);
        expect(find.byType(SourceSettingsHub), findsNothing);
        expect(routes.pushed.last.settings.name, 'PluginSettingsRoute');
        expect(routes.pushed.every((route) => route is PageRoute), isTrue);
        expect(find.text('Retry expired media'), findsOneWidget);
        final sourceSwitch = find.byKey(
          const ValueKey('plugin-field-key:video.refreshExpiredSources'),
        );
        await tester.ensureVisible(sourceSwitch);
        await tester.tap(find.text('Retry expired media'));
        await tester.pumpAndSettle();
        expect(
          (jsonDecode(
                onLoadPluginConfig(
                  _source,
                  'video.refreshExpiredSources',
                  'true',
                ),
              )
              as Map)['value'],
          false,
        );
        final playback = find.text(t.videoPlayback.playbackSettings);
        await tester.ensureVisible(playback);
        final rootScroll = find.descendant(
          of: find.byType(PluginSettingsPage), matching: find.byType(Scrollable));
        expect(rootScroll, findsOneWidget);
        final sourceOffsetBeforeChild = tester.state<ScrollableState>(rootScroll).position.pixels;
        await tester.tap(playback);
        await tester.pumpAndSettle();
        expect(find.byType(VideoPlaybackSettingsPage), findsOneWidget);
        expect(
          find.text('Retry expired media'),
          findsNothing,
          reason: 'video.* source fields have only one actual form',
        );
        expect(
          tester
              .widget<VideoPlaybackSettingsPage>(
                find.byType(VideoPlaybackSettingsPage),
              )
              .includeSourcePreferences,
          isFalse,
        );
        final autoplay = find.byKey(const ValueKey('video-setting.autoplay'));
        await tester.ensureVisible(autoplay);
        await tester.tap(autoplay);
        await tester.pumpAndSettle();
        expect((await VideoPlaybackPreferences.read()).autoplay, isFalse);
        await pressBack(tester);
        expect(find.byType(PluginSettingsPage), findsOneWidget);
        final returnedScroll = find.descendant(
          of: find.byType(PluginSettingsPage), matching: find.byType(Scrollable));
        expect(returnedScroll, findsOneWidget);
        final returnedState = tester.state<ScrollableState>(returnedScroll);
        expect(returnedState.widget.axisDirection, AxisDirection.down);
        expect(returnedState.position.pixels, closeTo(sourceOffsetBeforeChild, .5),
          reason: 'returning from playback preferences preserves the source settings scroll position');
        // The source field precedes Access & tools. ensureVisible(playback)
        // left it above the retained viewport, so search toward the head.
        await tester.scrollUntilVisible(sourceSwitch, -250,
          scrollable: returnedScroll);
        await tester.pumpAndSettle();
        expect(returnedState.position.pixels, lessThanOrEqualTo(sourceOffsetBeforeChild));
        final returnedSwitch = find.descendant(of: sourceSwitch,
          matching: find.byType(Switch));
        expect(returnedSwitch, findsOneWidget);
        expect(tester.widget<Switch>(returnedSwitch).value, isFalse);
        expect((jsonDecode(onLoadPluginConfig(_source,
          'video.refreshExpiredSources', 'true')) as Map)['value'], false);
        expect(find.text('Retry expired media'), findsOneWidget);
        await pressBack(tester);
        expect(sourceQuery.text, 'retained local query');
        expect(find.byType(PluginSettingsPage), findsNothing);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'retained-login-backup-fixture',
          ),
          'saved-fixture',
        );
        expect(
          api.calls.where((name) => name == 'getLoginBundle'),
          isEmpty,
          reason:
              'a plugin declaring no login does not invent an account route',
        );
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(milliseconds: 100));
        toastification.managers.clear();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'legacy settings launcher opens the same root and retains saved login data',
    (tester) async {
      final registry = PluginRegistryCubit();
      addTearDown(registry.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: registry,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => unawaited(
                    openSourceSettingsHub(context, source: _source),
                  ),
                  child: const Text('Legacy shortcut'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Legacy shortcut'));
      await tester.pumpAndSettle();
      expect(find.byType(PluginSettingsPage), findsOneWidget);
      expect(find.byType(SourceSettingsHub), findsNothing);
      expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'retained-login-backup-fixture',
        ),
        'saved-fixture',
      );
      await pressBack(tester);
      expect(find.text('Legacy shortcut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
