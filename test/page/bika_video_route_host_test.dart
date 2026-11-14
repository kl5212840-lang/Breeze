import 'dart:async';

import '../test_helper.dart';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_video_content.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';

class _SettingsRouteApi extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({required String name}) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({required String runtimeName}) async => jsonEncode('settings-route-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({required String runtimeName,
    required String taskGroupKey, required bool isOnce, String? bundleJs,
    String? bundleUrl, required String fnPath, required String argsJson}) async =>
    Uint8List.fromList(utf8.encode(jsonEncode({'data':{'canLogin':false,'canShowUserInfo':false}})));
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected API ${invocation.memberName}');
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

Set<int> _paintedViews(WidgetTester tester) {
  final ids = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) ids.add(layer.viewId);
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        visit(child);
        child = child.nextSibling;
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return ids;
}

bool _hasClippedNativeStrip(WidgetTester tester, Set<int> sourceIds) {
  var found = false;
  void visit(Layer layer) {
    if (layer is PlatformViewLayer && sourceIds.contains(layer.viewId)) {
      var ancestor = layer.parent;
      while (ancestor != null) {
        if (ancestor is ClipRectLayer) {
          final clip = ancestor.clipRect;
          if (clip != null && clip.width > 0 && clip.width < layer.rect.width)
            found = true;
          break;
        }
        ancestor = ancestor.parent;
      }
    }
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        visit(child);
        child = child.nextSibling;
      }
    }
  }

  visit(tester.binding.renderViews.single.debugLayer!);
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _SettingsRouteApi());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  test(
    'only the two reported video composition entrances receive route names',
    () {
      expect(videoDetailRouteSettings(_bika)?.name, bikaVideoDetailRouteName);
      expect(
        videoDetailRouteSettings(omoNetworkSource)?.name,
        omoVideoDetailRouteName,
      );
      expect(videoDetailRouteSettings('future-source'), isNull);
      expect(
        videoDetailRouteSettings('7aaf9572-5baa-4e76-97d3-2625236c0526'),
        isNull,
      );
    },
  );

  testWidgets(
    'actual Discover video-library launcher supplies its stable ordinary route identity',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observed = _Routes();
      late BuildContext sourceContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observed],
          home: Builder(
            builder: (context) {
              sourceContext = context;
              return const Scaffold(body: Text('Discover launcher host'));
            },
          ),
        ),
      );
      final completion = DiscoverRouter.route(
        sourceContext,
        action: {
          'type': 'openVideoLibrary',
          'payload': {
            'protocol': 2,
            'source': omoNetworkSource,
            'url': 'https://fixture.test/',
            'catalogFnPath': 'video.catalog',
            'detailFnPath': 'video.detail',
            'playbackFnPath': 'video.playback',
          },
        },
        currentFrom: 'fixture',
      );
      expect(observed.pushed.last.settings.name, apiVideoLibraryRouteName);
      expect(observed.pushed.last.navigator, same(navigator.currentState));
      // Verify the actual dispatch/route boundary before destination loading:
      // this contract does not need a plugin runtime or a remote catalog read.
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await completion;
      expect(tester.takeException(), isNull);
    },
  );

  for (final (sourceId, detailRouteName) in [
    (_bika, bikaVideoDetailRouteName),
    (omoNetworkSource, omoVideoDetailRouteName),
  ]) {
    for (final style in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$sourceId embedded library to preparing detail and return $style $brightness',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            await tester.binding.setSurfaceSize(const Size(400, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            final channels = <MethodChannel>[];
            final createdIds = <int>{};
            messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
              call,
            ) async {
              if (call.method == 'create') {
                final args = call.arguments as Map;
                createdIds.add(args['id'] as int);
                final channel = MethodChannel(
                  '${args['viewType']}.${args['id']}',
                );
                channels.add(channel);
                messenger.setMockMethodCallHandler(channel, (_) async => null);
              }
              return null;
            });
            const networkChannel = MethodChannel('breeze.video.network');
            messenger.setMockMethodCallHandler(
              networkChannel,
              (_) async => false,
            );
            addTearDown(() {
              messenger.setMockMethodCallHandler(
                SystemChannels.platform_views,
                null,
              );
              messenger.setMockMethodCallHandler(networkChannel, null);
              for (final channel in channels) {
                messenger.setMockMethodCallHandler(channel, null);
              }
            });
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            final navigator = GlobalKey<NavigatorState>();
            final observed = _Routes();
            final media = Completer<Map<String, dynamic>>();
            var playbackReads = 0;
            final isOmo = sourceId == omoNetworkSource;
            final home = isOmo
                ? 'https://www.omofuna.com/'
                : 'https://adult-animate.bidobido.xyz/';
            final detail = isOmo
                ? '${home}voddetail/47.html'
                : '${home}videos/QC-MH-fixture';
            final episodeID = isOmo ? 'omo-episode-fixture' : 'QC-MH-fixture';
            // The API identity is the public detail + explicit line/episode,
            // not the site's transient physical /vodplay document URL.
            final watch = '$detail?line=default&episode=$episodeID';
            final fixtureId = isOmo ? '47' : 'animate:QC-MH-fixture';
            final item = <String, dynamic>{
              'id': fixtureId,
              'title': 'Video route fixture',
              'detailUrl': detail,
              'description':
                  'Public fixture metadata stays readable during preparation.',
              'lines': [
                {
                  'id': 'default',
                  'label': '默认',
                  'episodes': [
                    {
                      'id': episodeID,
                      'title': '播放',
                      'resolveOnPlayback': true,
                      'watchUrl': watch,
                    },
                  ],
                },
              ],
            };
            // This is the actual SourceShell video subtree and its outer navigation;
            // its owning PageRoute is named as in the app, with no nested Navigator.
            Widget source(BuildContext context) => Scaffold(
              extendBody: true,
              body: SourceVideoContent(
                source: sourceId,
                leading: IconButton(
                  tooltip: 'real settings entry',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => openSourceSettings(context, source: sourceId),
                ),
                actions: [
                  SourceShellAction(
                    title: '里番',
                    action: {
                      'type': 'openVideoLibrary',
                      'payload': {
                        'source': sourceId,
                        'title': '视频',
                        'url': home,
                        'protocol': 2,
                        'catalogFnPath': 'catalog',
                        'detailFnPath': 'detail',
                        'playbackFnPath': 'play',
                        'capabilities': {
                          'search': 'none',
                          'year': false,
                          'recent': false,
                          'detailFromSnapshot': true,
                          'itemNamespace': isOmo ? '' : 'animate',
                          'posterAspectRatio': 4 / 3,
                        },
                      },
                    },
                  ),
                ],
                pluginCall: (fn, args) async {
                  if (fn == 'detail') return {'data': item};
                  if (fn == 'play') {
                    playbackReads++;
                    return media.future;
                  }
                  return {
                    'data': {
                      'items': [item],
                      'categories': [],
                      'page': 1,
                      'pageCount': 1,
                      'total': 1,
                    },
                  };
                },
              ),
              bottomNavigationBar: VideoNativeNavigation(
                currentIndex: 1,
                onTap: (_) {},
                symbols: const ['square.grid.2x2', 'film'],
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view),
                    label: '分类',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.video_library),
                    label: '视频',
                  ),
                ],
              ),
            );
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  builder: (context, child) => BlocProvider(
                    create: (_) => PluginRegistryCubit(), child: child!),
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                  ),
                  navigatorKey: navigator,
                  navigatorObservers: [
                    observed,
                    NativeCompositionObserver(
                      candidateOpaqueDestinations: {detailRouteName, 'PluginSettingsRoute'},
                      candidateRoutes: {
                        'SourceShellRoute': {
                          detailRouteName,
                          'PluginSettingsRoute',
                        },
                        detailRouteName: {detailRouteName},
                      },
                    ),
                  ],
                  initialRoute: 'SourceShellRoute',
                  onGenerateRoute: (settings) =>
                      MaterialPageRoute<void>(builder: source),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              observed.pushed.single.settings.name,
              isNull,
              reason:
                  'reported ordinary Navigator library origin was anonymous',
            );
            final libraryState = tester.state(find.byType(ApiVideoLibraryPage));
            final sourceViews = createdIds.toSet();
            final paintedBefore = _paintedViews(
              tester,
            ).intersection(sourceViews);
            final sourceStates = tester
                .stateList(
                  find.descendant(
                    of: find.byType(SourceVideoContent),
                    matching: find.byType(UiKitView),
                  ),
                )
                .toList();
            expect(paintedBefore.isNotEmpty, style == 'system');
            await tester.tap(find.byKey(ValueKey('api-video.$fixtureId')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 180));
            final route = observed.pushed.last;
            expect(route.settings.name, detailRouteName);
            expect(route, isA<CupertinoPageRoute<void>>());
            expect(route.navigator, same(navigator.currentState));
            expect(find.byType(ApiVideoDetailPage), findsOneWidget);
            expect(find.text(t.videoPlayback.preparingMedia), findsOneWidget);
            expect(playbackReads, 1);
            if (style == 'system') {
              expect(
                _paintedViews(tester).intersection(sourceViews).length,
                lessThan(paintedBefore.length),
                reason:
                    'fully covered source controls leave painting during the slide',
              );
              expect(
                _paintedViews(tester).intersection(sourceViews),
                isNotEmpty,
                reason: 'partly exposed native navigation keeps painting',
              );
              expect(
                _hasClippedNativeStrip(tester, sourceViews),
                isTrue,
                reason:
                    'a partially visible native layer paints only its exposed strip',
              );
            }
            expect(
              tester.state(
                find.byType(ApiVideoLibraryPage, skipOffstage: false),
              ),
              same(libraryState),
            );
            await tester.pump(const Duration(milliseconds: 500));
            final gesture = await tester.startGesture(const Offset(5, 400));
            await gesture.moveBy(
              const Offset(110, 0),
              timeStamp: const Duration(milliseconds: 100),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await gesture.moveBy(
              const Offset(-105, 0),
              timeStamp: const Duration(milliseconds: 300),
            );
            await gesture.up();
            await tester.pump(const Duration(milliseconds: 600));
            expect(
              find.byType(ApiVideoDetailPage),
              findsOneWidget,
              reason: 'cancelled back gesture retains the preparing page',
            );
            expect(playbackReads, 1);
            navigator.currentState!.pop();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(find.byType(ApiVideoDetailPage), findsNothing);
            expect(
              tester.state(find.byType(ApiVideoLibraryPage)),
              same(libraryState),
            );
            expect(
              tester.stateList(
                find.descendant(
                  of: find.byType(SourceVideoContent),
                  matching: find.byType(UiKitView),
                ),
              ),
              orderedEquals(sourceStates),
            );
            expect(
              _paintedViews(tester).intersection(sourceViews),
              paintedBefore,
            );
            // The real shared settings entrance must keep the candidate route name
            // when called from an ordinary Navigator source page.
            await tester.tap(find.byTooltip('real settings entry'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 180));
            expect(
              observed.pushed.last.settings.name,
              'PluginSettingsRoute',
            );
            expect(
              tester.state(
                find.byType(ApiVideoLibraryPage, skipOffstage: false),
              ),
              same(libraryState),
            );
            await navigator.currentState!.maybePop();
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            media.complete({'data': {}});
            await tester.pump();
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
