import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

List<InkHighlight> highlights(WidgetTester tester, Finder control) {
  final ink = find
      .descendant(of: control, matching: find.byType(InkWell))
      .first;
  final dynamic material = Material.of(tester.element(ink));
  return ((material.debugInkFeatures as List<InkFeature>?) ?? <InkFeature>[])
      .whereType<InkHighlight>()
      .where((feature) => feature.active)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final action in ['profile-view-all', 'profile-open']) {
        testWidgets(
          'Omo local history $action passive arrival and return preserve press feedback: $style $brightness',
          (tester) async {
            tester.view.physicalSize = const Size(430, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            final visible = ValueNotifier(true);
            final navigator = GlobalKey<NavigatorState>();
            const source = 'omo-hover-fixture';
            final home = Uri.parse('https://www.omofuna.com/');
            final site = OmoSiteClient(
              home: home,
              request: (operation, _) async => switch (operation) {
                'history' || 'favorites' => {
                  'kind': operation,
                  'items': [],
                  'rawCount': 0,
                  'hasMore': false,
                },
                _ => {
                  'kind': 'account',
                  'account': {'id': '1', 'name': '昵称', 'group': '游客'},
                },
              },
            );
            addTearDown(preference.dispose);
            addTearDown(visible.dispose);
            addTearDown(site.dispose);
            var opened = 0;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  navigatorKey: navigator,
                  theme: ThemeData(brightness: brightness),
                  builder: (_, child) => TouchHoverIntentScope(child: child!),
                  home: Scaffold(
                    body: ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (_, show, _) => show
                          ? OmoAccountPage(
                              client: site,
                              source: source,
                              active: true,
                              onLocalHistory: () {
                                opened++;
                                navigator.currentState!.push(
                                  MaterialPageRoute<void>(
                                    settings: const RouteSettings(
                                      name: 'breeze.video.local-history',
                                    ),
                                    builder: (_) => Scaffold(
                                      body: ApiVideoHistory(
                                        source: source,
                                        home: home,
                                        mode: ApiVideoView.list,
                                        onOpen: (_, _) async {},
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            );
            Future<void> settlePreviews() async {
              await tester.pump();
              bool loading() => tester
                  .widgetList<SourceProfileVideoPreview>(
                    find.byType(SourceProfileVideoPreview),
                  )
                  .any((preview) => preview.loading);
              final elapsed = Stopwatch()..start();
              while (loading() &&
                  elapsed.elapsed < const Duration(seconds: 5)) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 5)),
                );
                await tester.pump(const Duration(milliseconds: 16));
              }
              expect(loading(), isFalse);
              await tester.pumpAndSettle();
            }

            await settlePreviews();
            final row = find.byKey(
              ValueKey<(String, Key)>((
                action,
                const ValueKey('local-history.$source'),
              )),
            );
            expect(find.text(t.omoAccount.localHistory), findsOneWidget);
            expect(row.hitTestable(), findsOneWidget);
            final position = tester.getCenter(row);
            visible.value = false;
            await tester.pumpAndSettle();
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            addTearDown(mouse.removePointer);
            await mouse.addPointer(location: position);
            visible.value = true;
            await settlePreviews();
            expect(highlights(tester, row), isNotEmpty);
            expect(
              highlights(tester, row).every((ink) => ink.color.a == 0),
              isTrue,
            );
            expect(opened, 0);
            await mouse.moveTo(position + const Offset(2, 0));
            await tester.pumpAndSettle();
            expect(
              highlights(tester, row).any((ink) => ink.color.a > 0),
              isTrue,
            );
            final press = await tester.startGesture(position);
            await tester.pump(
              kPressTimeout + const Duration(milliseconds: 100),
            );
            expect(
              highlights(tester, row).any((ink) => ink.color.a > 0),
              isTrue,
            );
            expect(opened, 0);
            await press.cancel();
            await tester.pumpAndSettle();
            expect(opened, 0);
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(opened, 1);
            final history = find.byType(ApiVideoHistory);
            expect(history, findsOneWidget);
            expect(tester.widget<ApiVideoHistory>(history).source, source);
            expect(
              ModalRoute.of(tester.element(history))?.settings.name,
              'breeze.video.local-history',
            );
            navigator.currentState!.pop();
            await settlePreviews();
            expect(history, findsNothing);
            expect(row.hitTestable(), findsOneWidget);
            expect(
              highlights(tester, row).every((ink) => ink.color.a == 0),
              isTrue,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
