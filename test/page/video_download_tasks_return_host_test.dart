import 'package:toastification/toastification.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/video/video_download_navigation.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:zephyr/page/navigation_bar.dart' show MainNativeTabHost;
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/download/download_center_navigation.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';
import 'package:zephyr/page/donwload_task/view/download_task_entry.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

class _PlayingVideoPlatform extends VideoPlayerPlatform {
  final _events = <int, StreamController<VideoEvent>>{};
  int next = 0, plays = 0, pauses = 0, disposals = 0;
  bool playing = false, failPause = false;
  Completer<void>? pauseGate;
  final seeks = <Duration>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    final id = ++next;
    final stream = _events[id] = StreamController<VideoEvent>.broadcast();
    Timer.run(
      () => stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => _events[id]!.stream;
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int id) async {
    disposals++;
    await _events.remove(id)?.close();
  }

  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mix) async {}
  @override
  Future<void> play(int id) async {
    plays++;
    playing = true;
    _events[id]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int id) async {
    pauses++;
    await pauseGate?.future;
    if (failPause) throw PlatformException(code: 'PauseUnavailable');
    playing = false;
    _events[id]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int id, Duration position) async {
    seeks.add(position);
  }

  @override
  Future<Duration> getPosition(int id) async => const Duration(seconds: 37);
}

class _Observer extends NavigatorObserver {
  final pops = <Route<dynamic>>[];
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pops.add(route);
}

/// Stateful playback-document parent. No media engine is needed for this route
/// contract; the popup and VideoDownloadSheet are the actual production UI.
class _PlayerParent extends StatefulWidget {
  const _PlayerParent();
  @override
  State<_PlayerParent> createState() => _PlayerParentState();
}

class _PlayerParentState extends State<_PlayerParent> {
  final scroll = ScrollController();
  int sheetReturns = 0, qualityReads = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    await showVideoTaskSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => VideoDownloadNavigationOrigin(
        origin: context,
        child: VideoDownloadSheet(
          video: Uri.parse('https://hanime1.me/watch?v=42'),
          title: 'retained player',
          onClose: () => Navigator.of(sheetContext).pop(),
          readChoices: () async {
            qualityReads++;
            return (
              status: VideoSiteStatus.ok,
              writeUnconfirmed: false,
              value: [
                for (var i = 0; i < 24; i++)
                  (
                    label: '720p option $i',
                    format: 'MP4',
                    url: Uri.parse('https://media-fixture.test/video-$i.mp4'),
                  ),
              ],
            );
          },
        ),
      ),
    );
    if (mounted) setState(() => sheetReturns++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('retained player')),
    body: Column(
      children: [
        TextButton(
          key: const ValueKey('open-download-sheet'),
          onPressed: _download,
          child: const Text('open download sheet'),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: 60,
            itemBuilder: (_, index) =>
                SizedBox(height: 48, child: Text('player document row $index')),
          ),
        ),
      ],
    ),
  );
}

class _MainDownloadsHost extends StatefulWidget {
  const _MainDownloadsHost({
    required this.style,
    required this.rootPlayer,
    this.playerBuilder,
    this.onOpening,
  });
  final String style;
  final bool rootPlayer;
  final WidgetBuilder? playerBuilder;
  final VoidCallback? onOpening;
  @override
  State<_MainDownloadsHost> createState() => _MainDownloadsHostState();
}

class _MainDownloadsHostState extends State<_MainDownloadsHost> {
  final controller = PersistentTabController(initialIndex: 0);
  int selected = 0, opens = 0;
  @override
  void initState() {
    super.initState();
    DownloadCenterNavigation.attach(this, () async {
      if (!mounted) return false;
      final router = AutoRouter.of(context).root;
      if (!router.stack.any((page) => page.name == 'NavigationBar'))
        return false;
      widget.onOpening?.call();
      router.popUntilRouteWithName('NavigationBar');
      if (!mounted) return false;
      opens++;
      controller.jumpToTab(2);
      setState(() => selected = 2);
      return true;
    });
  }

  @override
  void dispose() {
    DownloadCenterNavigation.detach(this);
    controller.dispose();
    super.dispose();
  }

  void select(int index) {
    controller.jumpToTab(index);
    setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      t.navigation.discover,
      t.navigation.bookshelf,
      t.download.title,
      t.navigation.more,
    ];
    final navigation = widget.style == 'system'
        ? VideoNativeNavigation(
            currentIndex: selected,
            onTap: select,
            items: [
              for (final label in labels)
                BottomNavigationBarItem(
                  icon: const Icon(Icons.circle),
                  label: label,
                ),
            ],
            symbols: const [
              'safari',
              'books.vertical',
              'arrow.down.circle',
              'ellipsis.circle',
            ],
          )
        : BreezeNavigationBar(
            contentHeight: 56,
            selectedIndex: selected,
            destinations: [
              for (final label in labels)
                NavigationDestination(
                  icon: const Icon(Icons.circle),
                  label: label,
                ),
            ],
            onSelected: select,
          );
    return MainNativeTabHost(
      controller: controller,
      navBarHeight: 56,
      floatingNavigation: widget.style == 'system',
      navigation: SizedBox(
        key: const ValueKey('main-download-navigation'),
        child: navigation,
      ),
      screens: [
        Builder(
          builder: (tabContext) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-source'),
              child: const Text('Open source'),
              onPressed: () {
                if (widget.rootPlayer) {
                  Navigator.of(tabContext, rootNavigator: true).push(
                    videoPageRoute<void>(
                      settings: const RouteSettings(
                        name: 'breeze.video.library',
                      ),
                      builder:
                          widget.playerBuilder ??
                          ((_) => const _PlayerParent()),
                    ),
                  );
                } else {
                  // Copy opens ordinary source routes in the discovery tab's
                  // Navigator; the player and sheet share that nested owner.
                  Navigator.of(tabContext).push(
                    videoPageRoute<void>(
                      settings: const RouteSettings(name: 'SourceShellRoute'),
                      builder: (sourceContext) => Scaffold(
                        body: TextButton(
                          key: const ValueKey('open-nested-player'),
                          child: const Text('Open player'),
                          onPressed: () => Navigator.of(sourceContext).push(
                            videoPageRoute<void>(
                              settings: const RouteSettings(
                                name: 'copy-source-player',
                              ),
                              builder:
                                  widget.playerBuilder ??
                                  ((_) => const _PlayerParent()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        const Scaffold(body: Text('Main bookshelf')),
        const DownloadTaskPage(embedded: true),
        const Scaffold(body: Text('Main more')),
      ],
    );
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final watch = Stopwatch()..start();
  while (!ready() && watch.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: stage);
  await tester.pump();
}

Future<void> _drainResourceProjection(WidgetTester tester) async {
  var settled = false;
  DownloadCenterResources.readVideos().then(
    (_) => settled = true,
    onError: (Object _, StackTrace _) {
      settled = true;
    },
  );
  await _until(
    tester,
    () => settled,
    'real resource reads finish before the test fake zone is discarded',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = DownloadConnectivityFixture();
  tearDownAll(connectivity.close);
  const transfer = MethodChannel('breeze.video.download');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  var starts = 0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await DownloadAdmission.instance.start();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    starts = 0;
    messenger.setMockMethodCallHandler(transfer, (call) async {
      if (call.method == 'start') {
        starts++;
        return 'cancelled';
      }
      throw TestFailure('Unexpected native transfer operation ${call.method}');
    });
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
    messenger.setMockMethodCallHandler(transfer, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels)
      messenger.setMockMethodCallHandler(channel, null);
    channels.clear();
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  for (final style in ['system', 'breeze']) {
    for (final rootPlayer in [true, false]) {
      testWidgets(
        'download panel reuses main tab from ${rootPlayer ? 'root source' : 'Copy nested source'} $style',
        (tester) async {
          final appearance = ValueNotifier(style);
          final router = RootStackRouter.build(
            routes: [
              NamedRouteDef(
                name: 'NavigationBar',
                path: '/',
                initial: true,
                builder: (_, _) =>
                    _MainDownloadsHost(style: style, rootPlayer: rootPlayer),
              ),
            ],
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          try {
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: appearance,
                child: MaterialApp.router(routerConfig: router.config()),
              ),
            );
            await tester.pumpAndSettle();
            final host = tester.state<_MainDownloadsHostState>(
              find.byType(_MainDownloadsHost),
            );
            await tester.tap(find.byKey(const ValueKey('open-source')));
            await tester.pumpAndSettle();
            if (!rootPlayer) {
              await tester.tap(
                find.byKey(const ValueKey('open-nested-player')),
              );
              await tester.pumpAndSettle();
            }
            await tester.tap(find.byKey(const ValueKey('open-download-sheet')));
            await tester.pumpAndSettle();
            expect(find.byType(VideoDownloadSheet), findsOneWidget);
            final taskLink = find.byKey(const ValueKey('video-download-tasks'));
            expect(
              taskLink.hitTestable(),
              findsOneWidget,
              reason:
                  'the root download sheet must paint above the main navigation bar',
            );
            await tester.tap(taskLink);
            await _until(
              tester,
              () => host.selected == 2,
              'existing main Downloads tab is selected',
            );
            await _until(
              tester,
              () =>
                  find
                      .byKey(const ValueKey('download-inventory-loading'))
                      .evaluate()
                      .isEmpty &&
                  find
                      .byType(VideoDownloadSheet, skipOffstage: false)
                      .evaluate()
                      .isEmpty &&
                  find
                      .byType(_PlayerParent, skipOffstage: false)
                      .evaluate()
                      .isEmpty,
              'the Downloads inventory finishes reading and source routes leave',
            );
            expect(host.opens, 1);
            expect(host.controller.index, 2);
            expect(find.byType(MainNativeTabHost), findsOneWidget);
            expect(
              find.byKey(const ValueKey('main-download-navigation')),
              findsOneWidget,
            );
            final downloads = find.byType(
              DownloadTaskPage,
              skipOffstage: false,
            );
            expect(downloads, findsOneWidget);
            expect(tester.widget<DownloadTaskPage>(downloads).embedded, isTrue);
            expect(
              find.byType(VideoDownloadSheet, skipOffstage: false),
              findsNothing,
            );
            expect(
              find.byType(_PlayerParent, skipOffstage: false),
              findsNothing,
            );
            expect(router.stack.map((page) => page.name), ['NavigationBar']);
            host.select(0);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('open-source')).hitTestable(),
              findsOneWidget,
              reason:
                  'returning to discovery must not reveal an abandoned player or sheet',
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await _drainResourceProjection(tester);
            router.dispose();
            appearance.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  for (final mode in ['inline', 'fullscreen', 'pauseFailure']) {
    testWidgets(
      'playing session pauses before the main Downloads tab without cancelling transfer $mode',
      (tester) async {
        final fullscreen = mode == 'fullscreen';
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = VideoPlayerPlatform.instance;
        final platform = _PlayingVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        await VideoPlaybackPreferences.save('controlsStyle', 'breeze');
        await VideoPlaybackPreferences.save('recordHistory', false);
        messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        final transferDone = Completer<Object?>();
        var cancels = 0;
        messenger.setMockMethodCallHandler(transfer, (call) async {
          if (call.method == 'start') {
            starts++;
            return await transferDone.future;
          }
          if (call.method == 'cancel') {
            cancels++;
            return null;
          }
          throw TestFailure(
            'Unexpected native transfer operation ${call.method}',
          );
        });
        final appearance = ValueNotifier('breeze');
        final router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: 'NavigationBar',
              path: '/',
              initial: true,
              builder: (_, _) => _MainDownloadsHost(
                style: 'breeze',
                rootPlayer: true,
                onOpening: () => expect(
                  platform.playing,
                  isFalse,
                  reason:
                      'native pause must be acknowledged before the main owner navigates',
                ),
                playerBuilder: (_) => NativeVideoPage(
                  source: 'pause-download-fixture',
                  session: NativePlaybackSession(
                    title: 'Native retained playback',
                    watchUrl: Uri.parse('https://hanime1.me/watch?v=42'),
                    sources: [
                      NativePlaybackSource(
                        url: Uri.parse('https://media-fixture.test/video.mp4'),
                        label: '720p',
                        headers: const {},
                      ),
                    ],
                    description: '',
                    tags: const [],
                  ),
                ),
              ),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: appearance,
              child: MaterialApp.router(routerConfig: router.config()),
            ),
          );
          await tester.pumpAndSettle();
          final host = tester.state<_MainDownloadsHostState>(
            find.byType(_MainDownloadsHost),
          );
          await tester.tap(find.byKey(const ValueKey('open-source')));
          await _until(
            tester,
            () => platform.playing,
            'native session starts playing',
          );
          await tester.pump(const Duration(milliseconds: 400));
          if (fullscreen) {
            await tester.tap(find.byTooltip(t.videoPlayback.fullscreen));
            tester.view.physicalSize = const Size(844, 390);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          final download = find.byKey(
            ValueKey(
              fullscreen ? 'video-resolved-download' : 'video-inline.download',
            ),
          );
          await tester.ensureVisible(download);
          await tester.tap(download);
          await _until(
            tester,
            () => find
                .byKey(const ValueKey('video-download-choice-0'))
                .evaluate()
                .isNotEmpty,
            'resolved download choices',
          );
          final choice = find.byKey(const ValueKey('video-download-choice-0'));
          await tester.ensureVisible(choice);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(choice.hitTestable(), findsOneWidget);
          await tester.tap(choice);
          await tester.pump();
          expect(
            starts,
            0,
            reason: 'choosing a quality does not start a transfer',
          );
          final start = find.byKey(const ValueKey('video-download.start'));
          expect(start.hitTestable(), findsOneWidget);
          await tester.tap(start);
          await _until(
            tester,
            () => starts == 1,
            'independent native transfer starts',
          );
          expect(platform.playing, isTrue);
          final plays = platform.plays, seeks = platform.seeks.toList();
          platform.pauseGate = Completer<void>();
          await tester.tap(find.byKey(const ValueKey('video-download-tasks')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            host.opens,
            0,
            reason: 'the main tab switch waits for native pause acknowledgment',
          );
          expect(cancels, 0);
          expect(transferDone.isCompleted, isFalse);
          expect(platform.disposals, 0);
          platform.failPause = mode == 'pauseFailure';
          platform.pauseGate!.complete();
          if (platform.failPause) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(host.opens, 0);
            expect(host.selected, 0);
            expect(find.byType(VideoDownloadSheet), findsOneWidget);
            expect(cancels, 0);
            expect(platform.disposals, 0);
            transferDone.complete('cancelled');
            await _until(
              tester,
              () => !VideoSystemDownload.hasActiveTransfer,
              'failed navigation does not cancel the transfer',
            );
          } else {
            await _until(
              tester,
              () => host.selected == 2,
              'existing main Downloads tab opens after pause',
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(host.opens, 1);
            expect(platform.playing, isFalse);
            expect(
              find.byType(VideoDownloadSheet, skipOffstage: false),
              findsNothing,
            );
            await _until(
              tester,
              () => find
                  .byType(NativeVideoPage, skipOffstage: false)
                  .evaluate()
                  .isEmpty,
              'the actual Cupertino reverse transition retires the departed player',
            );
            expect(
              find.byType(NativeVideoPage, skipOffstage: false),
              findsNothing,
            );
            final downloads = find.byType(
              DownloadTaskPage,
              skipOffstage: false,
            );
            expect(downloads, findsOneWidget);
            expect(tester.widget<DownloadTaskPage>(downloads).embedded, isTrue);
            expect(cancels, 0);
            expect(VideoSystemDownload.hasActiveTransfer, isTrue);
            expect(transferDone.isCompleted, isFalse);
            expect(
              platform.seeks,
              seeks,
              reason: 'leaving playback never seeks to reset progress',
            );
            host.select(0);
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              find.byKey(const ValueKey('open-source')).hitTestable(),
              findsOneWidget,
            );
            expect(
              platform.plays,
              plays,
              reason:
                  'leaving Downloads cannot resurrect or autoplay the old player',
            );
            expect(cancels, 0);
            expect(starts, 1);
            transferDone.complete('cancelled');
            await _until(
              tester,
              () => !VideoSystemDownload.hasActiveTransfer,
              'transfer settles independently after player disposal',
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          if (platform.pauseGate?.isCompleted == false)
            platform.pauseGate!.complete();
          if (!transferDone.isCompleted) transferDone.complete('cancelled');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await _until(
            tester,
            () => !VideoSystemDownload.hasActiveTransfer,
            'native transfer drains with its originating fake zone pumped',
          );
          await _drainResourceProjection(tester);
          router.dispose();
          appearance.dispose();
          VideoPlayerPlatform.instance = original;
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final host in ['navigator', 'auto-route', 'pageless-with-router']) {
    for (final style in ['system', 'breeze']) {
      testWidgets(
        'an unavailable main center never creates a task page or changes the sheet: $host $style',
        (tester) async {
          final appearance = ValueNotifier(style);
          final notices = <ToastEvent>[];
          BuildContext? errorContext;
          final subscription = eventBus.on<ToastEvent>().listen((event) {
            notices.add(event);
            if (event.message == t.videoPlayback.actionFailed &&
                errorContext != null)
              showToastEvent(errorContext, event);
          });
          addTearDown(subscription.cancel);
          final observer = _Observer();
          RootStackRouter? router;
          Widget launch(BuildContext context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-player'),
              child: const Text('open player'),
              onPressed: () {
                if (host == 'auto-route') {
                  context.pushRoute(const PageRouteInfo('Player'));
                } else {
                  Navigator.of(context).push(
                    videoPageRoute<void>(
                      settings: const RouteSettings(name: 'plain-player'),
                      builder: (_) => const _PlayerParent(),
                    ),
                  );
                }
              },
            ),
          );
          if (host != 'navigator') {
            router = RootStackRouter.build(
              routes: [
                NamedRouteDef(
                  name: 'Root',
                  path: '/',
                  initial: true,
                  builder: (context, _) => launch(context),
                ),
                NamedRouteDef(
                  name: 'Player',
                  path: '/player',
                  builder: (_, _) => const _PlayerParent(),
                ),
              ],
            );
          }
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          try {
            Widget media(BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!,
            );
            final theme = ThemeData(
              platform: TargetPlatform.iOS,
              brightness: style == 'system'
                  ? Brightness.light
                  : Brightness.dark,
            );
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: appearance,
                child: router == null
                    ? MaterialApp(
                        theme: theme,
                        navigatorObservers: [observer],
                        builder: media,
                        home: Builder(builder: launch),
                      )
                    : MaterialApp.router(
                        theme: theme,
                        builder: media,
                        routerConfig: router.config(
                          navigatorObservers: () => [observer],
                        ),
                      ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('open-player')));
            await tester.pumpAndSettle();
            final parent = tester.state<_PlayerParentState>(
              find.byType(_PlayerParent),
            );
            errorContext = parent.context;
            parent.scroll.jumpTo(240);
            await tester.pump();
            final parentOffset = parent.scroll.offset;
            final pageNames = router?.stack.map((page) => page.name).toList();
            await tester.tap(find.byKey(const ValueKey('open-download-sheet')));
            await tester.pumpAndSettle();
            expect(parent.qualityReads, 1);
            await tester.ensureVisible(
              find.byKey(const ValueKey('video-download-choice-0')),
            );
            await tester.tap(
              find.byKey(const ValueKey('video-download-choice-0')),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            final start = find.byKey(const ValueKey('video-download.start'));
            expect(start.hitTestable(), findsOneWidget);
            await tester.tap(start);
            await _until(
              tester,
              () =>
                  !VideoSystemDownload.hasActiveTransfer &&
                  find.text(t.videoDownload.cancelled).evaluate().isNotEmpty,
              'the real transfer cancellation is persisted and rendered before navigation',
            );
            expect(starts, 1);
            final sheetFinder = find.byType(VideoDownloadSheet);
            final sheetState = tester.state(sheetFinder);
            final sheetContext = tester.element(sheetFinder);
            expect(ModalRoute.of(sheetContext), isA<PopupRoute>());
            expect(
              ModalRoute.of(sheetContext)!.settings,
              isNot(isA<AutoRoutePage>()),
            );
            if (host != 'navigator') {
              expect(
                sheetContext.findAncestorWidgetOfExactType<RouterScope>(),
                isNotNull,
                reason:
                    'exercise the inherited AutoRoute scope on an actual popup',
              );
            }
            final sheetScroll = tester.state<ScrollableState>(
              find
                  .descendant(
                    of: sheetFinder,
                    matching: find.byType(Scrollable),
                  )
                  .last,
            );
            // Compact panels have an outer controls scroll and an inner
            // quality list. Retain the actual, populated list's offset.
            expect(sheetScroll.position.maxScrollExtent, greaterThan(24));
            sheetScroll.position.jumpTo(24);
            await tester.pump();
            final sheetOffset = sheetScroll.position.pixels;
            expect(
              find.byKey(const ValueKey('video-download-tasks')).hitTestable(),
              findsOneWidget,
            );
            await tester.tap(
              find.byKey(const ValueKey('video-download-tasks')),
            );
            // Toastification mounts an empty holder, inserts the toast in a
            // post-frame callback, then starts its AnimatedList ticker. Advancing
            // time on that ticker's first frame alone leaves opacity at zero.
            await tester.pump();
            final visibleError = find.text(t.videoPlayback.actionFailed);
            double opacity() {
              final matches = visibleError.evaluate();
              if (matches.isEmpty) return 0;
              var value = 1.0;
              matches.single.visitAncestorElements((element) {
                final widget = element.widget;
                if (widget is FadeTransition) value *= widget.opacity.value;
                if (widget is Opacity) value *= widget.opacity;
                return true;
              });
              return value;
            }

            final frames =
                ((const ToastificationConfig())
                            .animationDuration
                            .inMilliseconds /
                        16)
                    .ceil() +
                4;
            for (var frame = 0; frame < frames && opacity() < .999; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(
              find.byType(DownloadTaskPage, skipOffstage: false),
              findsNothing,
            );
            expect(
              notices.where(
                (event) => event.message == t.videoPlayback.actionFailed,
              ),
              hasLength(1),
            );
            expect(visibleError, findsOneWidget);
            final errorElement = tester.element(visibleError);
            expect(
              Overlay.maybeOf(errorElement, rootOverlay: true),
              same(Overlay.maybeOf(sheetContext, rootOverlay: true)),
            );
            var paintOpacity = 1.0;
            errorElement.visitAncestorElements((element) {
              final widget = element.widget;
              if (widget is FadeTransition)
                paintOpacity *= widget.opacity.value;
              if (widget is Opacity) paintOpacity *= widget.opacity;
              if (widget is Offstage) expect(widget.offstage, isFalse);
              return true;
            });
            expect(paintOpacity, closeTo(1, .001));
            final errorRect = tester.getRect(visibleError);
            final viewport =
                Offset.zero &
                (tester.view.physicalSize / tester.view.devicePixelRatio);
            expect(errorRect.width, greaterThan(24));
            expect(errorRect.height, greaterThan(0));
            expect(viewport.contains(errorRect.topLeft), isTrue);
            expect(
              viewport.contains(errorRect.bottomRight - const Offset(.01, .01)),
              isTrue,
            );
            expect(visibleError.hitTestable(), findsOneWidget);
            toastification.dismissAll(delayForAnimation: false);
            await tester.pumpAndSettle();
            expect(parent.mounted, isTrue);
            expect(parent.sheetReturns, 0);
            expect(observer.pops.whereType<PopupRoute>(), isEmpty);
            expect(tester.state(find.byType(_PlayerParent)), same(parent));
            expect(
              tester.state(find.byType(VideoDownloadSheet)),
              same(sheetState),
            );
            expect(parent.scroll.offset, closeTo(parentOffset, .1));
            expect(sheetScroll.position.pixels, closeTo(sheetOffset, .1));
            expect(
              parent.qualityReads,
              1,
              reason: 'the sheet is retained instead of recreated',
            );
            expect(parent.sheetReturns, 0);
            expect(find.text(t.videoDownload.cancelled), findsOneWidget);
            if (router != null)
              expect(router.stack.map((page) => page.name).toList(), pageNames);
            final close = find.byTooltip(t.common.close);
            expect(close.hitTestable(), findsOneWidget);
            await tester.tap(close);
            await _until(
              tester,
              () =>
                  find.byType(VideoDownloadSheet).evaluate().isEmpty &&
                  parent.sheetReturns == 1,
              'the real close callback completes the modal route and returns to its retained document',
            );
            expect(parent.sheetReturns, 1);
            expect(parent.scroll.offset, closeTo(parentOffset, .1));
            expect(tester.takeException(), isNull);
          } finally {
            toastification.dismissAll(delayForAnimation: false);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            router?.dispose();
            appearance.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets('a refusing main owner does not create another task route', (
    tester,
  ) async {
    final owner = Object();
    var calls = 0;
    DownloadCenterNavigation.attach(owner, () async {
      calls++;
      return false;
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openDownloadTasks(context),
                child: const Text('global tasks'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('global tasks'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('global tasks'), findsOneWidget);
      expect(find.byType(DownloadTaskPage, skipOffstage: false), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      DownloadCenterNavigation.detach(owner);
    }
  });
}
