import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/user_image_editor.dart';

import '../ui_preview_helper.dart';

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = previousRoute;
  }
}

Set<int> _scenePlatformIds(WidgetTester tester) {
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

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue, reason: reason);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiPreviewFonts);
  const captureKey = ValueKey('editor-native-parent-preview');
  final pattern = img.Image(width: 80, height: 120);
  img.fillRect(
    pattern,
    x1: 0,
    y1: 0,
    x2: 39,
    y2: 119,
    color: img.ColorRgb8(40, 80, 200),
  );
  img.fillRect(
    pattern,
    x1: 40,
    y1: 0,
    x2: 79,
    y2: 119,
    color: img.ColorRgb8(220, 150, 40),
  );
  final prepared = Uint8List.fromList(img.encodePng(pattern));

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'opaque image task above native source controls and navigation: $style $brightness',
        (tester) async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final channels = <MethodChannel>[];
          final byTooltip = <String, MethodChannel>{};
          final created = <int>{};
          final routeLog = _Routes();
          final preference = ValueNotifier(style);
          // Exercise an embedded source as well as an ordinary page. The editor
          // must still belong to the root navigator, just as the old dialog did.
          final nested = brightness == Brightness.dark;
          final rootNavigator = GlobalKey<NavigatorState>();
          final sourceNavigator = GlobalKey<NavigatorState>();
          var avatarWrites = 0, localWrites = 0, completions = 0;
          String? result = 'not opened';
          Uint8List? exportedAvatar;
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              created.add(args['id'] as int);
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (update) async {
                if (update.method == 'update' && update.arguments is Map) {
                  final tooltip = (update.arguments as Map)['tooltip'];
                  if (tooltip is String) byTooltip[tooltip] = channel;
                }
                return null;
              });
            }
            return null;
          });
          await tester.binding.setSurfaceSize(const Size(430, 932));
          try {
            Future<void> open(BuildContext context, bool avatar) async {
              result = 'pending';
              if (avatar) {
                // The account caller receives bytes only on confirmation. No
                // real account, picker, storage or remote upload is invoked.
                final edited = await showUserImageEditor(
                  context,
                  bytes: prepared,
                  title: 'Avatar image task',
                  aspectRatio: 1,
                  confirmLabel: 'Upload',
                  circularPreview: true,
                );
                if (edited != null) {
                  avatarWrites++;
                  exportedAvatar = edited;
                }
                result = edited == null ? null : 'avatar submitted';
              } else {
                result = await pickLocalAppearanceImage(
                  context,
                  imageKey: 'plugin-icon:78617c71-313f-42fe-9317-460d691890b2',
                  title: 'Local icon image task',
                  aspectRatio: 1,
                  pickBytes: () async => prepared,
                  prepare: (bytes) async => bytes,
                  save: (_, _) async {
                    localWrites++;
                    return 'local saved';
                  },
                );
              }
              completions++;
            }

            Widget source(BuildContext context) => Scaffold(
              body: Column(
                children: [
                  const Text('Source page remains mounted'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SourceChromeIconButton(
                        icon: Icons.account_circle_outlined,
                        symbol: 'person.crop.circle',
                        tooltip: 'avatar caller',
                        onPressed: () => unawaited(open(context, true)),
                      ),
                      SourceChromeIconButton(
                        icon: Icons.settings_outlined,
                        symbol: 'gearshape',
                        tooltip: 'local caller',
                        onPressed: () => unawaited(open(context, false)),
                      ),
                    ],
                  ),
                ],
              ),
              bottomNavigationBar: VideoNativeNavigation(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Library',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Account',
                  ),
                ],
                symbols: const ['house', 'person'],
                currentIndex: 0,
                onTap: (_) {},
              ),
            );
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  navigatorKey: rootNavigator,
                  navigatorObservers: [NativeCompositionObserver(), routeLog],
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                    fontFamily: uiPreviewDirectory == null
                        ? null
                        : 'AccountPreview',
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 54, bottom: 34),
                    ),
                    child: RepaintBoundary(key: captureKey, child: child!),
                  ),
                  home: nested
                      ? Navigator(
                          key: sourceNavigator,
                          onGenerateRoute: (_) =>
                              CupertinoPageRoute<void>(builder: source),
                        )
                      : Builder(builder: source),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final parentStates = tester
                .stateList(find.byType(UiKitView))
                .toList();
            final parentIds = _scenePlatformIds(tester);
            expect(parentIds.length, style == 'system' ? 3 : 0);
            if (style == 'system' && brightness == Brightness.light) {
              // Preserve the exact distinction behind the regression: a
              // full-screen Dialog is still a PopupRoute and keeps the covered
              // source's native layers. No observer candidate list is involved.
              unawaited(
                showDialog<void>(
                  context: rootNavigator.currentContext!,
                  barrierDismissible: false,
                  builder: (_) => Dialog.fullscreen(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            NativeVideoTextButton(
                              label: 'Cancel',
                              tooltip: 'baseline cancel',
                              light: false,
                              bare: true,
                              onPressed: () =>
                                  rootNavigator.currentState!.pop(),
                            ),
                            NativeVideoTextButton(
                              label: 'Upload',
                              tooltip: 'baseline upload',
                              light: false,
                              bare: true,
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const Expanded(child: ColoredBox(color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(routeLog.latest, isA<PopupRoute<void>>());
              expect((routeLog.latest as ModalRoute<dynamic>).opaque, isFalse);
              expect(
                _scenePlatformIds(tester).intersection(parentIds),
                parentIds,
              );
              rootNavigator.currentState!.pop();
              await tester.pumpAndSettle();
              expect(_scenePlatformIds(tester), parentIds);
            }

            Future<void> press(String tooltip, Finder fallback) async {
              if (style == 'system') {
                expect(byTooltip[tooltip], isNotNull);
                await messenger.handlePlatformMessage(
                  byTooltip[tooltip]!.name,
                  const StandardMethodCodec().encodeMethodCall(
                    const MethodCall('press'),
                  ),
                  (_) {},
                );
              } else {
                await tester.tap(fallback);
              }
              await tester.pump();
            }

            for (final avatar in [true, false]) {
              final beforeCreates = Set<int>.of(created);
              final previousCompletions = completions;
              final tooltip = avatar ? 'avatar caller' : 'local caller';
              await press(tooltip, find.byTooltip(tooltip));
              await _until(
                tester,
                () =>
                    routeLog.latest?.settings.name == userImageEditorRouteName,
                'the image editor is pushed onto the root navigator',
              );
              final route = routeLog.latest!;
              expect(route, isA<CupertinoPageRoute<Uint8List>>());
              expect(route, isA<PageRoute<Uint8List>>());
              final page = route as PageRoute<Uint8List>;
              expect(
                page.opaque,
                isTrue,
                reason:
                    'a full-screen task must not retain a translucent PopupRoute',
              );
              expect(page.fullscreenDialog, isTrue);
              expect(page.navigator, same(rootNavigator.currentState));
              if (nested)
                expect(sourceNavigator.currentState!.canPop(), isFalse);
              // Observe a real transition frame, rather than replacing the route
              // by a settled widget or suppressing its animation.
              await tester.pump(const Duration(milliseconds: 80));
              expect(page.animation!.value, greaterThan(0));
              expect(page.animation!.value, lessThan(1));
              await _until(
                tester,
                () =>
                    find
                        .byKey(const ValueKey('image-editor-confirm'))
                        .evaluate()
                        .isNotEmpty &&
                    tester
                            .widget<NativeVideoIconButton>(
                              find.byKey(
                                const ValueKey('image-editor-confirm'),
                              ),
                            )
                            .onPressed !=
                        null,
                'bounded image codec is ready',
              );
              await tester.pumpAndSettle();
              final viewport = find.byKey(
                const ValueKey('user-image-crop-viewport'),
              );
              final editorContext = tester.element(viewport);
              expect(ModalRoute.of(editorContext), same(page));
              expect(
                editorContext.findAncestorWidgetOfExactType<Dialog>(),
                isNull,
              );
              final editorViews = find.descendant(
                of: find.byKey(const ValueKey('image-editor-cancel')),
                matching: find.byType(UiKitView),
              );
              for (final element in editorViews.evaluate()) {
                final clips = <String>[];
                element.visitAncestorElements((ancestor) {
                  final w = ancestor.widget;
                  if (w is ClipRRect && w.clipBehavior != Clip.none ||
                      w is ClipPath && w.clipBehavior != Clip.none ||
                      w is ClipOval && w.clipBehavior != Clip.none ||
                      w is PhysicalModel && w.clipBehavior != Clip.none ||
                      w is PhysicalShape && w.clipBehavior != Clip.none) {
                    clips.add(w.runtimeType.toString());
                  }
                  return true;
                });
                expect(
                  clips,
                  isEmpty,
                  reason:
                      'navigation controls do not inherit the photo crop clip',
                );
              }
              final frame = tester.getRect(viewport);
              expect(frame.width / frame.height, closeTo(1, .001));
              final scene = _scenePlatformIds(tester);
              expect(
                scene.intersection(parentIds),
                isEmpty,
                reason:
                    'covered source controls and tab bar must leave the composed scene',
              );
              final editorIds = created.difference(beforeCreates);
              expect(editorIds.length, style == 'system' ? 2 : 0);
              expect(
                scene.containsAll(editorIds),
                isTrue,
                reason:
                    'the editor retains its own real native Cancel/Upload or Done controls',
              );
              final allStates = tester.stateList(
                find.byType(UiKitView, skipOffstage: false),
              );
              expect(
                allStates.toSet().containsAll(parentStates),
                isTrue,
                reason:
                    'the parent native controls are retained, not disposed or replaced',
              );
              await _until(
                tester,
                () =>
                    PaintingBinding.instance.imageCache.pendingImageCount == 0,
                'actual memory-image raster decoding finishes',
              );
              await tester.pump();
              // Raster evidence for the Flutter photo region. This does not
              // render UIKit glass or claim that real-device overlays are fixed.
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(captureKey),
              );
              final raster = await tester.runAsync(() async {
                final image = await boundary
                    .toImage(pixelRatio: 1)
                    .timeout(const Duration(seconds: 5));
                try {
                  return await image
                      .toByteData(format: ui.ImageByteFormat.rawRgba)
                      .timeout(const Duration(seconds: 5));
                } finally {
                  image.dispose();
                }
              });
              expect(raster, isNotNull);
              final data = raster!;
              final pixels = data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              );
              final width = boundary.size.width.round();
              int channel(double x, double y, int c) =>
                  pixels[(y.floor() * width + x.floor()) * 4 + c];
              final y = frame.top + frame.height * .25;
              final left = frame.left + frame.width * .25;
              final right = frame.left + frame.width * .75;
              expect(
                channel(left, y, 2),
                greaterThan(channel(left, y, 0) + 80),
              );
              expect(
                channel(right, y, 0),
                greaterThan(channel(right, y, 2) + 80),
              );
              final cornerX = frame.left + frame.width * .05;
              final cornerY = frame.top + frame.height * .05;
              final cornerBlue =
                  channel(cornerX, cornerY, 2) - channel(cornerX, cornerY, 0);
              expect(
                cornerBlue,
                avatar ? lessThan(60) : greaterThan(80),
                reason:
                    'only explicit avatar previews mask the square corners; icons stay square',
              );
              final canvasRect = tester.getRect(
                find.byKey(const ValueKey('image-editor-canvas')),
              );
              final toolsRect = tester.getRect(
                find.byKey(const ValueKey('image-editor-tools-scroll')),
              );
              expect(canvasRect.bottom, closeTo(toolsRect.top, .001));
              expect(find.byType(Slider), findsNothing);
              expect(
                frame.width,
                lessThanOrEqualTo((canvasRect.width - 32) * .8 + .01),
              );
              expect(
                frame.height,
                lessThanOrEqualTo((canvasRect.height - 32) * .65 + .01),
              );
              expect(frame.center.dx, closeTo(canvasRect.center.dx, .01));
              expect(frame.center.dy, closeTo(canvasRect.center.dy, .01));
              expect(
                toolsRect.bottom,
                closeTo(932 - 34, .001),
                reason: 'necessary tools are pinned above the bottom safe area',
              );
              await writeUiPreview(
                tester,
                captureKey,
                'image-editor-native-parent-$style-${brightness.name}-${avatar ? "avatar" : "local"}',
              );
              expect(avatarWrites, 0);
              expect(localWrites, 0);
              await press(
                t.common.cancel,
                find.byKey(const ValueKey('image-editor-cancel')),
              );
              await tester.pumpAndSettle();
              await _until(
                tester,
                () => completions == previousCompletions + 1,
                'cancel reaches the correct account or local-image caller',
              );
              expect(result, isNull);
              expect(avatarWrites, 0);
              expect(localWrites, 0);
              expect(rootNavigator.currentState!.canPop(), isFalse);
              expect(_scenePlatformIds(tester), parentIds);
              expect(
                tester.stateList(find.byType(UiKitView)),
                orderedEquals(parentStates),
              );
              expect(tester.takeException(), isNull);
            }
            if (style == 'system' && brightness == Brightness.light) {
              await press('avatar caller', find.byTooltip('avatar caller'));
              await _until(
                tester,
                () =>
                    find
                        .byKey(const ValueKey('image-editor-confirm'))
                        .evaluate()
                        .isNotEmpty &&
                    tester
                            .widget<NativeVideoIconButton>(
                              find.byKey(
                                const ValueKey('image-editor-confirm'),
                              ),
                            )
                            .onPressed !=
                        null,
                'avatar editor ready for explicit confirmation',
              );
              await tester.pumpAndSettle();
              await press(
                'Upload',
                find.byKey(const ValueKey('image-editor-confirm')),
              );
              await _until(
                tester,
                () => exportedAvatar != null,
                'the confirmed avatar crop reaches its caller',
              );
              await tester.pumpAndSettle();
              final exported = img.decodeJpg(exportedAvatar!)!;
              expect(exported.width, exported.height);
              final corner = exported.getPixel(2, 2);
              expect(
                corner.b,
                greaterThan(corner.r + 80),
                reason:
                    'the circular preview mask is never baked into square upload bytes',
              );
              expect(avatarWrites, 1);
              expect(localWrites, 0);
              expect(_scenePlatformIds(tester), parentIds);
              expect(tester.takeException(), isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            preference.dispose();
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in channels) {
              messenger.setMockMethodCallHandler(channel, null);
            }
            await tester.binding.setSurfaceSize(null);
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  testWidgets(
    'non-iOS editor keeps an opaque Material full-screen task and cancel result',
    (tester) async {
      final routes = _Routes();
      Uint8List? result;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Choose icon'),
                onPressed: () async {
                  result = await showUserImageEditor(
                    context,
                    bytes: prepared,
                    title: 'Icon',
                    aspectRatio: 1,
                  );
                  completed = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose icon'));
      await _until(
        tester,
        () =>
            find
                .byKey(const ValueKey('image-editor-confirm'))
                .evaluate()
                .isNotEmpty &&
            tester
                    .widget<NativeVideoIconButton>(
                      find.byKey(const ValueKey('image-editor-confirm')),
                    )
                    .onPressed !=
                null,
        'Material route image is ready',
      );
      await tester.pumpAndSettle();
      expect(routes.latest, isA<MaterialPageRoute<Uint8List>>());
      final page = routes.latest as PageRoute<Uint8List>;
      expect(page.opaque, isTrue);
      expect(page.fullscreenDialog, isTrue);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.byKey(const ValueKey('image-editor-cancel')));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
