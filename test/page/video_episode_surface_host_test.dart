import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_download_picker.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
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
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  testWidgets(
    'explicit system player material survives original plugin Breeze scope',
    (tester) async {
      final original = ValueNotifier('breeze');
      addTearDown(original.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: original,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: VideoControlAppearance(
                  systemControls: true,
                  child: VideoSelectionPanel(
                    title: 'Player episodes',
                    onClose: () {},
                    child: const ListTile(title: Text('Current line')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<NativeMaterialSurface>(
        find.byType(NativeMaterialSurface),
      );
      expect(surface.systemStyle, isTrue);
      expect(surface.readableContent, isTrue);
      expect(
        find.byType(UiKitView),
        Theme.of(tester.element(find.byType(VideoSelectionPanel))).platform ==
                TargetPlatform.iOS
            ? findsOneWidget
            : findsNothing,
      );
      final content = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('video-selection.content')),
      );
      expect((content.decoration as BoxDecoration).color!.toARGB32() >>> 24, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
  testWidgets(
    'bottom player geometry reserves video and keyboard without a second safe inset',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: const VideoBottomPanelLayout(
              reservedTop: 267,
              child: SizedBox(
                key: ValueKey('bounded-player-panel'),
                height: 600,
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('bounded-player-panel')),
      );
      expect(rect.left, 0);
      expect(rect.right, 390);
      expect(rect.top, greaterThanOrEqualTo(267));
      expect(rect.bottom, 844 - 280);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('portrait task rotation keeps route and body while the material reaches the physical right edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(AppInterfaceStyleScope(style: style,
      child: MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(right: 44, bottom: 21),
          viewPadding: const EdgeInsets.only(right: 44, bottom: 21)),
        child: child!),
        home: Builder(builder: (context) => Scaffold(body: TextButton(
          onPressed: () => showVideoTaskSheet<void>(context: context,
            builder: (_) => ListView(key: const ValueKey('rotation-task-list'), shrinkWrap: true,
              children: [for (var i = 0; i < 30; i++) ListTile(title: Text('Item $i'))])),
          child: const Text('Open rotation task')))),
    )));
    await tester.tap(find.text('Open rotation task'));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('rotation-task-list'));
    final element = tester.element(list);
    final route = ModalRoute.of(element);
    final scroll = find.descendant(of: list, matching: find.byType(Scrollable));
    final scrollState = tester.state<ScrollableState>(scroll);
    final position = scrollState.position;
    position.jumpTo(80);
    await tester.pump();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(identical(tester.element(list), element), isTrue);
    expect(identical(ModalRoute.of(tester.element(list)), route), isTrue);
    expect(tester.state<ScrollableState>(scroll), same(scrollState));
    expect(scrollState.position.pixels, 80);
    final rect = tester.getRect(find.byKey(const ValueKey('video-task.surface')));
    expect(rect.right, closeTo(844, .01));
    expect(rect.width, lessThanOrEqualTo(844 * .56 + .01));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(list)).pop();
    await tester.pumpAndSettle();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'high contrast task supplies a solid semantic surface $brightness',
      (tester) async {
        final preference = ValueNotifier('system');
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(highContrast: true),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open task'),
                    onPressed: () => showVideoSelectionPanel<void>(
                      context: context,
                      title: 'Episodes',
                      builder: (_) => ListView(
                        shrinkWrap: true,
                        children: const [
                          ListTile(
                            title: Text('Current episode'),
                            selected: true,
                            trailing: Icon(Icons.play_arrow_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open task'));
        await tester.pumpAndSettle();
        final body = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('video-selection.content')),
        );
        expect(
          (body.decoration as BoxDecoration).color!.toARGB32() >>> 24,
          255,
        );
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(320, 800), const Size(800, 360)]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'episode task thick material, readable colors and bounds $style/$brightness/$size/$scale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final preference = ValueNotifier(style);
              addTearDown(preference.dispose);
              final cards = List.generate(
                80,
                (index) => NativeVideoCard(
                  title: 'Episode $index long actual source title',
                  coverUrl: null,
                  watchUrl: Uri.parse(
                    'https://fixture.test/voddetail/1.html?line=main&episode=$index',
                  ),
                ),
              );
              var count = 2;
              List<NativeVideoCard>? submitted;
              await tester.pumpWidget(
                AppInterfaceStyleScope(
                  style: preference,
                  child: MaterialApp(
                    theme: ThemeData(brightness: brightness),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: Builder(
                        builder: (context) => Column(
                          children: [
                            TextButton(
                              child: const Text('Play episodes'),
                              onPressed: () => showVideoSelectionPanel<void>(
                                context: context,
                                title: t.videoPlayback.episodes,
                                builder: (_) => VideoEpisodePicker(
                                  sequence: VideoEpisodeSequence(
                                    cards.take(count).toList(),
                                  ),
                                  current: cards.first.watchUrl,
                                  onChanged: (_) {},
                                ),
                              ),
                            ),
                            TextButton(
                              child: const Text('Download episodes'),
                              onPressed: () async {
                                submitted =
                                    await showVideoEpisodeDownloadPicker(
                                      context,
                                      episodes: cards,
                                      currentWatch: cards.first.watchUrl,
                                      lineLabels: const {
                                        'main': 'Current source',
                                      },
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.text('Play episodes'));
              await tester.pumpAndSettle();
              final panelRect = tester.getRect(
                find.byType(VideoSelectionPanel),
              );
              if (size.width > size.height) {
                expect(panelRect.width, lessThanOrEqualTo(size.width * .56 + .01));
                expect(panelRect.left, greaterThanOrEqualTo(size.width * .44 - .01));
              } else {
                expect(panelRect.left, closeTo(0, .01));
              }
              expect(panelRect.right, closeTo(size.width, .01));
              expect(panelRect.bottom, closeTo(size.height, .01));
              if (size.height > size.width) {
                expect(
                  panelRect.top,
                  greaterThanOrEqualTo(size.width * 9 / 16),
                );
              }
              expect(
                tester
                    .widget<VideoSelectionPanel>(
                      find.byType(VideoSelectionPanel),
                    )
                    .floating,
                isFalse,
              );

              final body = tester.widget<DecoratedBox>(
                find.byKey(const ValueKey('video-selection.content')),
              );
              expect(
                (body.decoration as BoxDecoration).color!.toARGB32() >>> 24,
                0,
                reason: 'normal task content retains its native thick material',
              );
              final surface = tester.widget<NativeMaterialSurface>(
                find.descendant(
                  of: find.byType(VideoSelectionPanel),
                  matching: find.byType(NativeMaterialSurface),
                ),
              );
              expect(surface.readableContent, isTrue);
              final taskTheme = Theme.of(
                tester.element(
                  find.byKey(const ValueKey('video-selection.content')),
                ),
              );
              expect(
                taskTheme.textTheme.titleMedium?.fontWeight,
                FontWeight.w600,
              );
              expect(
                taskTheme.textTheme.bodyLarge?.fontWeight,
                FontWeight.w500,
              );
              expect(taskTheme.textTheme.bodyLarge?.fontSize, 17);
              double contrast(Color a, Color b) {
                final x = a.computeLuminance(), y = b.computeLuminance();
                return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
              }

              expect(
                contrast(
                  taskTheme.colorScheme.onSurface,
                  taskTheme.colorScheme.surface,
                ),
                greaterThanOrEqualTo(4.5),
              );
              expect(
                contrast(
                  taskTheme.listTileTheme.selectedColor!,
                  Color.alphaBlend(taskTheme.listTileTheme.selectedTileColor!,
                    taskTheme.colorScheme.surface),
                ),
                greaterThanOrEqualTo(4.5),
              );
              expect(
                taskTheme.colorScheme.onSurface.computeLuminance(),
                (size.width > size.height || brightness == Brightness.dark) ? greaterThan(.7) : lessThan(.1),
              );
              expect(
                taskTheme.listTileTheme.selectedTileColor,
                style == 'system'
                    ? Colors.transparent
                    : taskTheme.colorScheme.surfaceContainerHigh,
              );
              expect(taskTheme.listTileTheme.selectedColor, taskTheme.colorScheme.onSurface);
              final contentSurface = find.descendant(
                of: find.byType(VideoSelectionPanel), matching: find.byType(NativeMaterialSurface));
              final small = tester.getSize(contentSurface).height;
              expect(small, lessThan(size.height), reason: 'Short lists shrink their functional material block, even when the sidebar occupies full height');
              await tester.tap(find.byTooltip(t.common.close));
              await tester.pumpAndSettle();
              count = 80;
              await tester.tap(find.text('Play episodes'));
              await tester.pumpAndSettle();
              expect(
                tester.getSize(contentSurface).height,
                greaterThanOrEqualTo(small),
              );
              final last = find.byKey(
                ValueKey('episode-queue.${cards.last.watchUrl}'),
              );
              final episodeList = find.byKey(
                const ValueKey('episode-queue.list'),
              );
              final lastRange = find.text('51-80');
              await tester.ensureVisible(lastRange);
              await tester.pumpAndSettle();
              await tester.tap(lastRange);
              await tester.pumpAndSettle();
              // Bring the inner viewport into the compact panel before dragging it.
              await tester.ensureVisible(episodeList);
              await tester.pumpAndSettle();
              final epScroll = find.descendant(of: episodeList, matching: find.byType(Scrollable)).first;
              await tester.scrollUntilVisible(last,
                tester.getSize(epScroll).height * .6,
                maxScrolls: cards.length * 2, scrollable: epScroll);
              await tester.pumpAndSettle();
              expect(last.hitTestable(), findsOneWidget);
              expect(last, findsOneWidget);
              await tester.tap(find.byTooltip(t.common.close));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Download episodes'));
              await tester.pumpAndSettle();
              final taskRect = tester.getRect(find.byKey(const ValueKey('video-task.surface')));
              expect(taskRect.right, closeTo(size.width, .01));
              expect(taskRect.bottom, closeTo(size.height, .01));
              if (size.width > size.height) {
                expect(taskRect.width, lessThanOrEqualTo(size.width * .56 + .01));
                expect(taskRect.left, greaterThanOrEqualTo(size.width * .44 - .01));
                final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
                expect(barrier.color?.a ?? 0, 0);
                final scrim = tester.widget<DecoratedBox>(find.byKey(const ValueKey('video-panel.side-depth')));
                final gradient = (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
                expect(gradient.colors.first.a, 0);
                expect(gradient.colors.last.a, greaterThan(gradient.colors[1].a));
              }
              final content = tester.widget<ColoredBox>(
                find.byKey(const ValueKey('video-task.content')),
              );
              expect(content.color.toARGB32() >>> 24, 0);
              expect(
                tester
                    .widget<NativeMaterialSurface>(
                      find.byType(NativeMaterialSurface),
                    )
                    .readableContent,
                isTrue,
              );
              final item = find.byKey(
                ValueKey('download-episodes.item.${cards[1].watchUrl}'),
              );
              final downloadList = find.byKey(
                const ValueKey('download-episodes.list'),
              );
              await tester.ensureVisible(downloadList);
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                item,
                160,
                scrollable: find
                    .descendant(
                      of: downloadList,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              // Align within the inner viewport after ensureVisible has also
              // moved the outer compact-panel scroll position.
              final inner = find
                  .descendant(
                    of: downloadList,
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await tester
                  .state<ScrollableState>(inner)
                  .position
                  .ensureVisible(tester.renderObject(item));
              await tester.pumpAndSettle();
              // A full long title can exceed the inner viewport at 2x.
              // Tap the visible row portion, never its clipped offscreen center.
              final visibleItem = tester
                  .getRect(item)
                  .intersect(tester.getRect(downloadList));
              expect(visibleItem.height, greaterThanOrEqualTo(44));
              await tester.tapAt(visibleItem.center);
              await tester.pump();
              final submit = find.byKey(
                const ValueKey('download-episodes.submit'),
              );
              await tester.ensureVisible(submit);
              await tester.tap(submit);
              await tester.pumpAndSettle();
              expect(submitted?.map((card) => card.watchUrl), [
                cards[1].watchUrl,
              ]);
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant({
              TargetPlatform.iOS,
              TargetPlatform.android,
            }),
          );
        }
      }
    }
  }
}
