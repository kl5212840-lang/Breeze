import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('system surface never constructs UIKit on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NativeMaterialSurface(child: SizedBox(width: 200, height: 120)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'unspecified surface follows ambient $style without a player override',
      (tester) async {
        final appearance = ValueNotifier(style);
        addTearDown(appearance.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: appearance,
            child: const MaterialApp(
              home: Scaffold(
                body: NativeMaterialSurface(
                  child: SizedBox(width: 200, height: 120),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NativeMaterialSurface>(find.byType(NativeMaterialSurface))
              .systemStyle,
          isNull,
        );
        expect(
          find.byType(UiKitView),
          style == 'system' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final style in ['system', 'breeze']) {
    for (final playerSystem in [true, false]) {
      for (final sheet in [true, false]) {
        testWidgets('video material $style player=$playerSystem task=$sheet', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final appearance = ValueNotifier(style);
          addTearDown(appearance.dispose);
          var underlyingTaps = 0;
          for (final size in [const Size(320, 700), const Size(844, 390)]) {
            for (final scale in [1.0, 1.4, 2.0]) {
              tester.view.physicalSize = size;
              await tester.pumpWidget(
                AppInterfaceStyleScope(
                  style: appearance,
                  child: MaterialApp(
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        padding: const EdgeInsets.only(top: 24, bottom: 20),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: child!,
                    ),
                    home: VideoControlAppearance(
                      systemControls: playerSystem,
                      child: Scaffold(
                        body: Builder(
                          builder: (context) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => underlyingTaps++,
                            child: Center(
                              child: TextButton(
                                child: const Text('Open selection'),
                                onPressed: () {
                                  Widget content(
                                    BuildContext context,
                                  ) => ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: 30,
                                    itemBuilder: (_, index) => ListTile(
                                      title: Text(
                                        'Line $index with a full descriptive label',
                                      ),
                                      selected: index == 0,
                                      trailing: index == 0
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  );
                                  if (sheet) {
                                    showVideoTaskSheet<void>(
                                      context: context,
                                      builder: content,
                                    );
                                  } else {
                                    showVideoSelectionPanel<void>(
                                      context: context,
                                      title: 'Select a playback line',
                                      builder: content,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('Open selection'));
              await tester.pumpAndSettle();
              final surface = find.byType(NativeMaterialSurface);
              final portrait = size.width <= size.height;
              final radius = portrait ? (sheet ? 24.0 : 20.0) : 14.0;
              final material = tester.widget<NativeMaterialSurface>(surface);
              expect(material.radius, radius);
              expect(material.topOnly, portrait);
              final native = find.descendant(
                of: surface,
                matching: find.byType(UiKitView),
              );
              expect(native, playerSystem ? findsOneWidget : findsNothing);
              if (native.evaluate().isNotEmpty) {
                final view = tester.widget<UiKitView>(native);
                expect((view.creationParams as Map)['panelRadius'], radius);
                expect((view.creationParams as Map)['topOnly'], portrait);
                RenderObject? ancestor = tester.renderObject(native).parent;
                while (ancestor != null) {
                  if (ancestor is RenderClipRRect)
                    expect(ancestor.clipBehavior, Clip.none);
                  if (ancestor is RenderPhysicalShape)
                    expect(ancestor.clipBehavior, Clip.none);
                  ancestor = ancestor.parent;
                }
              }
              final first = find.widgetWithText(
                ListTile,
                'Line 0 with a full descriptive label',
              );
              expect(tester.getSize(first).height, greaterThanOrEqualTo(44));
              expect(tester.widget<ListTile>(first).selected, isTrue);
              await tester.scrollUntilVisible(
                find.text('Line 29 with a full descriptive label'),
                160,
                maxScrolls: 100,
                scrollable: find.byType(Scrollable).last,
              );
              // A newly built, multiline last tile updates lazy scroll metrics
              // in layout; settle that frame before asking for full visibility.
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.widgetWithText(
                  ListTile,
                  'Line 29 with a full descriptive label',
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find
                    .text('Line 29 with a full descriptive label')
                    .hitTestable(),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull, reason: '$size / $scale');
              final before = underlyingTaps;
              await tester.tapAt(const Offset(4, 4));
              await tester.pump(const Duration(milliseconds: 20));
              await tester.tapAt(const Offset(4, 4));
              expect(
                underlyingTaps,
                before,
                reason: 'closing touches stay in the modal barrier',
              );
              await tester.pumpAndSettle();
              expect(find.byType(NativeMaterialSurface), findsNothing);
            }
          }
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
      }
    }
  }
}
