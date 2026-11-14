import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/plugin_scheme_widgets.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/storage_setting_page.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

class _SettingsApi extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-settings-hover-fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async => Uint8List.fromList(
    utf8.encode(
      jsonEncode(
        fnPath == 'getSettingsBundle'
            ? {
                'scheme': {
                  'sections': [
                    {
                      'fields': [
                        {
                          'key': 'address',
                          'kind': 'text',
                          'label': 'Offline address',
                        },
                      ],
                    },
                  ],
                },
                'data': {
                  'values': {'address': 'original'},
                },
              }
            : {'ok': true},
      ),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API ${invocation.memberName}');
}

List<InkHighlight> _ink(WidgetTester tester, Finder tile) {
  final finder = find
      .descendant(of: tile, matching: find.byType(InkWell))
      .first;
  final dynamic material = Material.of(tester.element(finder));
  return (material.debugInkFeatures as List<InkFeature>? ?? [])
      .whereType<InkHighlight>()
      .where((feature) => feature.active)
      .toList();
}

void _idle(WidgetTester tester, Finder tile) {
  final highlights = _ink(tester, tile);
  expect(highlights, isNotEmpty);
  expect(highlights.every((feature) => feature.color.a == 0), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _SettingsApi());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final channel = MethodChannel(
          'breeze.video.control.${(call.arguments as Map)['id']}',
        );
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
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

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final plugin in [false, true]) {
        testWidgets(
          '${plugin ? 'Plugin edit action' : 'Storage cache action'} keeps idle ink, actual navigation and cancellation, $style $brightness',
          (tester) async {
            tester.view.physicalSize = const Size(390, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            var writes = 0;
            final router = RootStackRouter.build(
              routes: [
                NamedRouteDef(
                  name: 'Home',
                  path: '/',
                  initial: true,
                  builder: (_, _) => const Scaffold(body: SizedBox.expand()),
                ),
                NamedRouteDef(
                  name: 'SettingsFixture',
                  path: '/settings-fixture',
                  builder: (_, _) => plugin
                      ? SettingPageShell(
                          title: 'Offline plugin settings',
                          grouped: true,
                          child: SettingSection(
                            children: [
                              PluginSettingSchemeSection(
                                from: 'settings-hover-fixture',
                                pluginName: 'settings-hover-fixture',
                                onValueChanged: (_, _) async {
                                  writes++;
                                },
                              ),
                            ],
                          ),
                        )
                      : const StorageSettingPage(),
                ),
                NamedRouteDef(
                  name: 'CacheSettingRoute',
                  path: '/cache-fixture',
                  builder: (_, _) =>
                      const Scaffold(body: Text('cache destination fixture')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              BlocProvider(
                create: (_) => GlobalSettingCubit(),
                child: AppInterfaceStyleScope(
                  style: preference,
                  child: MaterialApp.router(
                    theme: ThemeData(brightness: brightness),
                    routerConfig: router.config(),
                    builder: (_, child) => TouchHoverIntentScope(child: child!),
                  ),
                ),
              ),
            );
            void open() => unawaited(
              router.push<void>(const PageRouteInfo('SettingsFixture')),
            );
            await tester.pumpAndSettle();
            open();
            await tester.pumpAndSettle();
            final target = find.widgetWithText(
              ListTile,
              plugin ? 'Offline address' : t.settings.cache,
            );
            expect(target.hitTestable(), findsOneWidget);
            final position = tester.getCenter(target);
            router.pop();
            await tester.pumpAndSettle();
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            addTearDown(mouse.removePointer);
            await mouse.addPointer(location: position);
            open();
            await tester.pumpAndSettle();
            _idle(tester, target);
            await mouse.moveTo(position + const Offset(2, 0));
            await tester.pumpAndSettle();
            expect(_ink(tester, target).any((f) => f.color.a > 0), isTrue);
            expect(find.byType(AlertDialog), findsNothing);
            expect(writes, 0);
            await tester.tap(target);
            await tester.pumpAndSettle();
            if (plugin) {
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.enterText(find.byType(TextFormField), 'cancelled');
              await tester.tap(find.text(t.common.cancel));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsNothing);
              expect(find.text('original'), findsOneWidget);
              expect(writes, 0, reason: 'Cancel must not persist an edit');
            } else {
              expect(find.text('cache destination fixture'), findsOneWidget);
              router.pop();
              await tester.pumpAndSettle();
            }
            _idle(tester, target);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
