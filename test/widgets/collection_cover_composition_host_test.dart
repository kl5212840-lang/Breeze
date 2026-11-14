import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/navigation_bar.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

import '../download_fixture.dart';

Map<int, PlatformViewLayer> _scene(WidgetTester tester) {
  final result = <int, PlatformViewLayer>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) result[layer.viewId] = layer;
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        visit(child);
        child = child.nextSibling;
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
  });
  for (final nested in [false, true]) {
    testWidgets(
      'real cover settings ${nested ? 'tab nested' : 'root'} push clips only covered native pixels and returns unchanged',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final channels = <MethodChannel>[];
        final samples = <Map<String, Object?>>[];
        final navigator = GlobalKey<NavigatorState>();
        final tabs = PersistentTabController();
        final sourceKey = GlobalKey();
        int? searchId;
        int? navigationId;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            final id = args['id'] as int;
            if (args['viewType'] == 'breeze.search.surface') searchId = id;
            if (args['viewType'] == 'breeze.video.navigation')
              navigationId = id;
            final channel = MethodChannel('${args['viewType']}.$id');
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          }
          return null;
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 932);
        try {
          Widget source() => Scaffold(
            body: Stack(
              key: sourceKey,
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 350,
                  height: 48,
                  child: SearchFieldSurface(child: Text('retained source')),
                ),
                Positioned(
                  left: 330,
                  top: 200,
                  child: SourceChromeIconButton(
                    icon: Icons.settings,
                    symbol: 'gearshape',
                    tooltip: 'retained source action',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          );
          final navigation = VideoNativeNavigation(
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Other'),
            ],
            symbols: const ['house', 'person'],
            currentIndex: 0,
            onTap: (_) {},
          );
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              navigatorObservers: [
                NativeCompositionObserver(
                  candidateOpaqueDestinations: const {
                    collectionCoverSettingsRouteName,
                  },
                  diagnostics: samples.add,
                  diagnosticBudget: 256,
                ),
              ],
              onGenerateRoute: (_) => CupertinoPageRoute<void>(
                builder: (_) => nested
                    ? MainNativeTabHost(
                        controller: tabs,
                        screens: [source(), const SizedBox()],
                        navBarHeight: 80,
                        navigation: navigation,
                        handleAndroidBackButtonPress: true,
                      )
                    : source(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final originalIds = _scene(tester).keys.toSet();
          final originalStates = tester
              .stateList(find.byType(UiKitView))
              .toList();
          expect(originalIds, isNotEmpty);
          final sourceContext = sourceKey.currentContext!;
          final sourceNavigator = Navigator.of(sourceContext);
          expect(identical(sourceNavigator, navigator.currentState), !nested);
          unawaited(openCollectionCoverSettings(sourceContext));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          final page = find.byType(SettingPageShell);
          expect(page, findsOneWidget);
          final route = ModalRoute.of(tester.element(page))!;
          expect(route.settings.name, collectionCoverSettingsRouteName);
          expect(route.navigator, same(sourceNavigator));
          final intermediate = _scene(tester);
          if (nested) {
            expect(navigationId, isNotNull);
            expect(
              intermediate.containsKey(navigationId),
              isTrue,
              reason:
                  'root tab bar paints above the nested cover page during push',
            );
          }
          final search = intermediate[searchId];
          expect(
            search,
            isNotNull,
            reason: 'the exposed native source remains in the scene',
          );
          var ancestor = search!.parent;
          ClipRectLayer? clip;
          while (ancestor != null) {
            if (ancestor is ClipRectLayer) {
              clip = ancestor;
              break;
            }
            ancestor = ancestor.parent;
          }
          expect(
            clip?.clipRect?.width,
            allOf(greaterThan(0), lessThan(search.rect.width)),
          );
          expect(
            samples.any(
              (sample) =>
                  sample['decision'] == 'partly-visible' &&
                  sample['cover'] == collectionCoverSettingsRouteName &&
                  sample['partlyVisibleRect'] is List,
            ),
            isTrue,
          );
          expect(
            intermediate.keys.toSet().difference(originalIds),
            isNotEmpty,
            reason:
                'nested destination must never occlude its own UIKit controls',
          );
          expect(
            tester
                .stateList(find.byType(UiKitView, skipOffstage: false))
                .contains(originalStates.first),
            isTrue,
          );
          await tester.pumpAndSettle();
          if (nested) {
            expect(
              _scene(tester).containsKey(navigationId),
              isTrue,
              reason:
                  'settled nested settings must retain the root tab bar in the scene',
            );
          }
          sourceNavigator.pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingPageShell), findsNothing);
          expect(_scene(tester).keys.toSet(), originalIds);
          expect(
            tester.stateList(find.byType(UiKitView)),
            orderedEquals(originalStates),
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(channel, null);
          }
          tabs.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
