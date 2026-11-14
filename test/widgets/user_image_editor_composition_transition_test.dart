import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/user_image_editor.dart';

Set<int> _sceneIds(WidgetTester tester) {
  final result = <int>{};
  void visit(Layer layer) {
    if (layer is PlatformViewLayer) result.add(layer.viewId);
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

// Advance real codec/stream replies without advancing the route animation.
Future<void> _realReplies(WidgetTester tester, bool Function() ready) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue, reason: 'bounded engine/stream stage completes');
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = img.Image(width: 80, height: 120);
  img.fill(fixture, color: img.ColorRgb8(30, 100, 210));
  final bytes = Uint8List.fromList(img.encodePng(fixture));
  final cases =
      <
        ({
          String label,
          String? sourceName,
          bool configured,
          bool destination,
          bool nested,
        })
      >[
        for (final name in [
          'SourceShellRoute',
          'PluginSettingsRoute',
          'AppearanceSettingRoute',
        ])
          for (final enabled in [false, true])
            (
              label:
                  'actual editor intermediate scene $name exact pair=$enabled',
              sourceName: name,
              configured: enabled,
              destination: false,
              nested: false,
            ),
        (
          label: 'shared editor destination from an arbitrary named caller',
          sourceName: 'third-party.account.task',
          configured: true,
          destination: true,
          nested: false,
        ),
        (
          label: 'shared editor destination from an unnamed root caller',
          sourceName: null,
          configured: true,
          destination: true,
          nested: false,
        ),
        (
          label:
              'shared editor destination from an unnamed nested account caller',
          sourceName: null,
          configured: true,
          destination: true,
          nested: true,
        ),
      ];
  for (final scenario in cases) {
    final sourceName = scenario.sourceName;
    final configured = scenario.configured;
    testWidgets(scenario.label, (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      final idsByTooltip = <String, int>{};
      int? navigationId;
      final edgeY = ValueNotifier(450.0);
      final navigator = GlobalKey<NavigatorState>();
      final nestedNavigator = GlobalKey<NavigatorState>();
      final samples = <Map<String, Object?>>[];
      final gate = Completer<ImageInfo>();
      final memoryKey = MemoryImage(bytes);
      ui.Codec? codec;
      ui.Image? decoded;
      var completed = false;
      Uint8List? result;
      // Delay actual Image rendering, independently of the editor's bounded
      // size read. This exercises late image availability during transition.
      PaintingBinding.instance.imageCache.putIfAbsent(
        memoryKey,
        () => OneFrameImageStreamCompleter(gate.future),
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final id = args['id'] as int;
          if (args['viewType'] == 'breeze.video.navigation') navigationId = id;
          final channel = MethodChannel('${args['viewType']}.$id');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (update) async {
            if (update.method == 'update' && update.arguments is Map) {
              final tooltip = (update.arguments as Map)['tooltip'];
              if (tooltip is String) idsByTooltip[tooltip] = id;
            }
            return null;
          });
        }
        return null;
      });
      // Match MediaQuery's FlutterView to the actual layout viewport. A
      // setSurfaceSize-only fixture leaves MediaQuery at 800x600 and makes
      // the correctly retained native tab bar appear spuriously offscreen.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      try {
        Widget buildSource(BuildContext context) => Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('retained-source'),
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.white)),
                Positioned(
                  left: 20,
                  top: 60,
                  child: SourceChromeIconButton(
                    key: const ValueKey('source-top'),
                    icon: Icons.settings,
                    symbol: 'gearshape',
                    tooltip: 'source top',
                    onPressed: () {},
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: edgeY,
                  builder: (_, y, _) => Positioned(
                    left: 200,
                    top: y,
                    child: SourceChromeIconButton(
                      key: const ValueKey('source-edge'),
                      icon: Icons.search,
                      symbol: 'magnifyingglass',
                      tooltip: 'source edge',
                      onPressed: () {},
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoNativeNavigation(
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                    symbols: const ['house', 'person'],
                    currentIndex: 0,
                    onTap: (_) {},
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(platform: TargetPlatform.iOS),
            navigatorObservers: [
              NativeCompositionObserver(
                candidateRoutes: configured && !scenario.destination
                    ? {
                        sourceName!: {userImageEditorRouteName},
                      }
                    : const {},
                candidateOpaqueDestinations: scenario.destination
                    ? const {userImageEditorRouteName}
                    : const {},
                diagnostics: samples.add,
                diagnosticBudget: 256,
              ),
            ],
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
              settings: RouteSettings(name: sourceName),
              builder: (context) => scenario.nested
                  ? Navigator(
                      key: nestedNavigator,
                      onGenerateRoute: (_) =>
                          CupertinoPageRoute<void>(builder: buildSource),
                    )
                  : buildSource(context),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final originalStates = tester
            .stateList(find.byType(UiKitView))
            .toList();
        final originalIds = _sceneIds(tester);
        expect(originalIds, hasLength(3));
        final sourceContext = tester.element(
          find.byKey(const ValueKey('retained-source')),
        );
        expect(MediaQuery.sizeOf(sourceContext), const Size(430, 932));
        expect(
          ModalRoute.of(sourceContext)!.settings.name,
          scenario.nested ? null : sourceName,
        );
        if (scenario.nested) {
          expect(
            ModalRoute.of(sourceContext)!.navigator,
            same(nestedNavigator.currentState),
          );
          expect(
            ModalRoute.of(nestedNavigator.currentContext!)!.navigator,
            same(navigator.currentState),
            reason: 'root PageRoute remains the tracked coverage owner',
          );
        }
        unawaited(
          showUserImageEditor(
            sourceContext,
            bytes: bytes,
            title: 'Image task',
            aspectRatio: 1,
          ).then((value) {
            result = value;
            completed = true;
          }),
        );
        await tester.pump();
        await _realReplies(
          tester,
          () => find
              .byKey(const ValueKey('user-image-crop-viewport'))
              .evaluate()
              .isNotEmpty,
        );
        expect(gate.isCompleted, isFalse);
        expect(
          PaintingBinding.instance.imageCache.statusForKey(memoryKey).pending,
          isTrue,
        );
        final page = find.byKey(const ValueKey('user-image-editor-page'));
        var cover = tester
            .getRect(page)
            .intersect(const Rect.fromLTWH(0, 0, 430, 932));
        for (var tick = 0; cover.top > 700 && tick < 24; tick++) {
          await tester.pump(const Duration(milliseconds: 16));
          cover = tester
              .getRect(page)
              .intersect(const Rect.fromLTWH(0, 0, 430, 932));
        }
        expect(cover.top, greaterThan(104));
        expect(cover.top, lessThan(880));
        // Place the same retained native control across the actual moving
        // page edge. Its instance and platform-view identity must not change.
        edgeY.value = cover.top - 22;
        await tester.pump();
        final edge = tester.getRect(
          find.byKey(const ValueKey('source-edge'), skipOffstage: false),
        );
        expect(edge.top, lessThan(cover.top));
        expect(edge.bottom, greaterThan(cover.top));
        final topId = idsByTooltip['source top']!;
        final edgeId = idsByTooltip['source edge']!;
        expect(navigationId, isNotNull);
        var scene = _sceneIds(tester);
        expect(
          scene,
          contains(topId),
          reason: 'visible source control keeps its original material',
        );
        expect(
          scene,
          contains(edgeId),
          reason: 'partly covered control is still visible',
        );
        expect(
          scene.contains(navigationId),
          !configured,
          reason:
              'without the exact pair the covered native tab bar remains in the scene; '
              'actual page=$cover, navigation=$navigationId, scene=$scene, '
              'recent observations=${samples.reversed.take(16).toList()}',
        );
        final editorIds = scene.difference(originalIds);
        expect(editorIds, hasLength(2));
        expect(samples.any((s) => s['decision'] == 'covered'), configured);
        // Move farther without changing source geometry. The formerly
        // partial control is now fully covered and must change paint state.
        await tester.pump(const Duration(milliseconds: 80));
        final nextCover = tester
            .getRect(page)
            .intersect(const Rect.fromLTWH(0, 0, 430, 932));
        expect(nextCover.top, lessThan(edge.top));
        scene = _sceneIds(tester);
        expect(scene.contains(edgeId), !configured);
        expect(scene.containsAll(editorIds), isTrue);
        // Complete the real decoder while the page is still moving.
        codec = await tester.runAsync(
          () => ui
              .instantiateImageCodec(bytes)
              .timeout(const Duration(seconds: 5)),
        );
        final frame = await tester.runAsync(
          () => codec!.getNextFrame().timeout(const Duration(seconds: 5)),
        );
        decoded = frame!.image;
        gate.complete(ImageInfo(image: decoded));
        decoded = null; // ownership moves to the completer/cache
        await _realReplies(
          tester,
          () => !PaintingBinding.instance.imageCache
              .statusForKey(memoryKey)
              .pending,
        );
        expect(
          ModalRoute.of(tester.element(page))!.animation!.isCompleted,
          isFalse,
        );
        expect(_sceneIds(tester).contains(edgeId), !configured);
        if (configured && sourceName == 'SourceShellRoute') {
          final viewport = find.byKey(
            const ValueKey('user-image-crop-viewport'),
          );
          final center = tester.getCenter(viewport);
          expect(center.dy, lessThan(932));
          final beforeZoom = tester.getSize(find.byType(Image)).width;
          final first = await tester.startGesture(
            center - const Offset(20, 0),
            pointer: 21,
          );
          final second = await tester.startGesture(
            center + const Offset(20, 0),
            pointer: 22,
          );
          await first.moveTo(center - const Offset(45, 0));
          await tester.pump();
          await second.moveTo(center + const Offset(45, 0));
          await tester.pump();
          await first.moveTo(center - const Offset(60, 0));
          await tester.pump();
          await second.moveTo(center + const Offset(60, 0));
          await tester.pump();
          await second.up();
          await first.up();
          await tester.pump();
          expect(
            tester.getSize(find.byType(Image)).width,
            greaterThan(beforeZoom),
          );
          expect(
            ModalRoute.of(tester.element(page))!.animation!.isCompleted,
            isFalse,
          );
          expect(_sceneIds(tester), containsAll(editorIds));
          expect(_sceneIds(tester), isNot(contains(edgeId)));
        }
        await tester.pumpAndSettle();
        expect(_sceneIds(tester).intersection(originalIds), isEmpty);
        expect(
          tester
              .stateList(find.byType(UiKitView, skipOffstage: false))
              .toSet()
              .containsAll(originalStates),
          isTrue,
        );
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final returnCover = tester
            .getRect(page)
            .intersect(const Rect.fromLTWH(0, 0, 430, 932));
        final returned = _sceneIds(tester);
        for (final entry in [
          (topId, const ValueKey('source-top')),
          (edgeId, const ValueKey('source-edge')),
        ]) {
          final bounds = tester.getRect(
            find.byKey(entry.$2, skipOffstage: false),
          );
          if (bounds.bottom <= returnCover.top)
            expect(returned, contains(entry.$1));
        }
        await tester.pumpAndSettle();
        await _realReplies(tester, () => completed);
        expect(result, isNull);
        expect(_sceneIds(tester), originalIds);
        expect(
          tester.stateList(find.byType(UiKitView)),
          orderedEquals(originalStates),
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) {
          codec ??= await tester.runAsync(
            () => ui
                .instantiateImageCodec(bytes)
                .timeout(const Duration(seconds: 5)),
          );
          final remaining = await tester.runAsync(
            () => codec!.getNextFrame().timeout(const Duration(seconds: 5)),
          );
          gate.complete(ImageInfo(image: remaining!.image));
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.evict(memoryKey);
        decoded?.dispose();
        codec?.dispose();
        edgeY.dispose();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
  for (final transparent in [true, false]) {
    testWidgets(
      'destination opt-in does not admit ${transparent ? "transparent editor" : "unmatched opaque task"}',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final channels = <MethodChannel>[];
        final navigator = GlobalKey<NavigatorState>();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            final channel = MethodChannel('${args['viewType']}.${args['id']}');
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          }
          return null;
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 932);
        try {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              navigatorObservers: [
                NativeCompositionObserver(
                  candidateOpaqueDestinations: const {userImageEditorRouteName},
                ),
              ],
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 820,
                      child: SourceChromeIconButton(
                        key: const ValueKey('negative-source-control'),
                        icon: Icons.settings,
                        symbol: 'gearshape',
                        tooltip: 'retained source',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final ids = _sceneIds(tester);
          final state = tester.state(find.byType(UiKitView));
          expect(ids, hasLength(1));
          Widget target(BuildContext context) => Scaffold(
            key: const ValueKey('negative-cover'),
            backgroundColor: transparent
                ? Colors.white.withValues(alpha: .5)
                : Colors.white,
          );
          final PageRoute<void> route = transparent
              ? PageRouteBuilder<void>(
                  settings: const RouteSettings(name: userImageEditorRouteName),
                  opaque: false,
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, _, _) => target(context),
                )
              : CupertinoPageRoute<void>(
                  settings: const RouteSettings(name: 'not.the.shared.editor'),
                  fullscreenDialog: true,
                  builder: target,
                );
          unawaited(navigator.currentState!.push<void>(route));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          final coverFinder = find.byKey(const ValueKey('negative-cover'));
          for (
            var tick = 0;
            tester.getRect(coverFinder).top > 700 && tick < 20;
            tick++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final cover = tester.getRect(coverFinder);
          final source = tester.getRect(
            find.byKey(const ValueKey('negative-source-control')),
          );
          expect(cover.top, lessThanOrEqualTo(source.top));
          expect(cover.bottom, greaterThanOrEqualTo(source.bottom));
          expect(
            route.animation!.isCompleted,
            isFalse,
            reason:
                'a settled opaque route would hide all previous entries independently of the policy',
          );
          expect(
            _sceneIds(tester),
            containsAll(ids),
            reason:
                'the opt-in is ineffective for translucent or unregistered destinations',
          );
          expect(
            tester.state(find.byType(UiKitView, skipOffstage: false)),
            same(state),
          );
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(_sceneIds(tester), ids);
          expect(tester.state(find.byType(UiKitView)), same(state));
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
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
