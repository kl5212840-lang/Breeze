import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart';
import 'package:zephyr/page/navigation_bar.dart' as app;
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

// Diagnostic labels only; no account or media data.
// ignore: avoid_print
void _filterStage(String value) => print('SHELF_FILTER_HOST_STAGE:$value');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _filterStage('setup.objectbox.begin');
    await TestObjectBoxHelper.setUpTestObjectBox();
    _filterStage('setup.objectbox.done');
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    _filterStage('setup.worker.begin');
    await workerManager.init(isolatesCount: 1);
    _filterStage('setup.worker.done');
  });
  tearDownAll(() async {
    _filterStage('teardown.worker.begin');
    await workerManager.dispose();
    _filterStage('teardown.worker.done');
    debugShelfDbRootPath = null;
    _filterStage('teardown.objectbox.begin');
    await TestObjectBoxHelper.tearDownTestObjectBox();
    _filterStage('teardown.objectbox.done');
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final controls = <String, MethodChannel>{};
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityStatus = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUp(() {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityStatus, (_) async => null);
    messenger.setMockMethodCallHandler(
      paths,
      (_) async => TestObjectBoxHelper.tempPath,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'update' && call.arguments is Map) {
            final tooltip = (call.arguments as Map)['tooltip'];
            if (tooltip is String) controls[tooltip] = channel;
          }
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityStatus, null);
    messenger.setMockMethodCallHandler(paths, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
    controls.clear();
    _filterStage('case.cleanup.begin');
    TestObjectBoxHelper.cleanComicFolderBoxes();
    _filterStage('case.cleanup.done');
  });

  for (final medium in ['comic', 'video']) {
    for (final styleName in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'main tab $medium filter $styleName ${brightness.name}: open, search, cancel, apply above navigation',
          (tester) async {
            _filterStage('$medium.$styleName.${brightness.name}.begin');
            final errorHandler = FlutterError.onError!;
            FlutterError.onError = (details) {
              if (details.exceptionAsString().contains('context.select')) {
                debugPrint(
                  'Filter provider dependency failure: ${details.exceptionAsString()}',
                );
                debugPrintStack(stackTrace: details.stack);
              }
              errorHandler(details);
            };
            addTearDown(() => FlutterError.onError = errorHandler);
            Future<void> pumpTransition() async {
              for (var frame = 0; frame < 5; frame++) {
                await tester.pump(const Duration(milliseconds: 200));
              }
            }

            // Shared stores retain serialized Future tails across test cases.
            // Create and settle those local persistence operations in the real
            // zone so later cases never await a disposed FakeAsync queue.
            _filterStage('seed.begin');
            await tester.runAsync(() async {
              SharedPreferences.setMockInitialValues({
                'breeze.bookshelf.media.v1': 'comic',
              });
              for (var i = 0; i < 12; i++) {
                final row = createTestFavorite('filter-fixture:$i')
                  ..source = 'filter-fixture'
                  ..comicId = '$i'
                  ..title = 'Work $i'
                  ..metadata = jsonEncode([
                    {
                      'type': 'tag',
                      'value': [
                        {'name': 'Tag$i'},
                      ],
                    },
                  ]);
                objectbox.unifiedFavoriteBox.put(row);
                ComicLinkService.addComic(
                  row.uniqueKey,
                  null,
                  ComicFolderType.favorite,
                );
              }
              _filterStage('seed.video-import.begin');
              await VideoLibraryStore.shared.importFavorites('filter-fixture', [
                for (var i = 0; i < 12; i++)
                  ApiVideoItem(
                    id: '$i',
                    title: 'Work $i',
                    genres: 'Tag$i',
                    detailUrl: Uri.parse('https://fixture.invalid/item/$i'),
                  ),
              ]);
              _filterStage('seed.video-import.done');
              expect(
                (await VideoLibraryStore.shared.read())
                    .itemsFor('filter-fixture')
                    .length,
                12,
              );
              // Validate the production read boundary before entering the UI;
              // dependency errors must surface here, not as a disabled-button timeout.
              expect(
                (await VideoBookshelfIndex.sourceNames()).keys,
                contains('filter-fixture'),
              );
              _filterStage('seed.index-load.begin');
              expect(
                (await VideoBookshelfIndex.load(
                  ShelfPageMode.favorite,
                  const SearchStatusState(),
                )).length,
                12,
              );
            });
            _filterStage('seed.done');
            final preview =
                uiPreviewDirectory != null &&
                styleName == 'breeze' &&
                medium == 'comic';
            const previewKey = ValueKey('bookshelf.selection.preview');
            if (preview) await loadUiPreviewFonts();
            tester.view.physicalSize = preview
                ? const Size(390, 844)
                : const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final style = ValueNotifier(styleName);
            final controller = PersistentTabController(initialIndex: 1);
            _filterStage('mount.begin');
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => GlobalSettingCubit()),
                  BlocProvider(create: (_) => PluginRegistryCubit()),
                ],
                child: AppInterfaceStyleScope(
                  style: style,
                  child: MaterialApp(
                    theme: preview
                        ? ThemeData.from(
                            colorScheme: BreezeThemeColors.fromSeed(
                              const Color(0xff009688),
                              brightness,
                            ),
                          ).copyWith(
                            textTheme: ThemeData(
                              brightness: brightness,
                            ).textTheme.apply(fontFamily: 'AccountPreview'),
                          )
                        : ThemeData(brightness: brightness),
                    builder: preview
                        ? (_, child) =>
                              RepaintBoundary(key: previewKey, child: child)
                        : null,
                    home: preview
                        ? app.MainNativeTabHost(
                            controller: controller,
                            screens: const [
                              SizedBox.shrink(),
                              BookshelfPage(),
                              SizedBox.shrink(),
                            ],
                            navBarHeight: 64,
                            floatingNavigation: false,
                            navigation: BreezeNavigationBar(
                              contentHeight: 64,
                              selectedIndex: 1,
                              onSelected: controller.jumpToTab,
                              destinations: const [
                                NavigationDestination(
                                  icon: Icon(Icons.explore_outlined),
                                  label: '发现',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.menu_book_outlined),
                                  label: '书架',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.more_horiz),
                                  label: '更多',
                                ),
                              ],
                            ),
                          )
                        : styleName == 'system'
                        ? app.MainNativeTabHost(
                            controller: controller,
                            screens: const [
                              SizedBox.shrink(),
                              BookshelfPage(),
                              SizedBox.shrink(),
                            ],
                            navBarHeight: 84,
                            navigation: VideoNativeNavigation(
                              items: const [
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.explore),
                                  label: 'Discover',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.book),
                                  label: 'Bookshelf',
                                ),
                                BottomNavigationBarItem(
                                  icon: Icon(Icons.more_horiz),
                                  label: 'More',
                                ),
                              ],
                              symbols: const [
                                'safari',
                                'books.vertical',
                                'ellipsis.circle',
                              ],
                              currentIndex: 1,
                              onTap: controller.jumpToTab,
                            ),
                          )
                        : Builder(
                            builder: (context) => PersistentTabView(
                              context,
                              controller: controller,
                              screens: const [
                                SizedBox.shrink(),
                                BookshelfPage(),
                                SizedBox.shrink(),
                              ],
                              items: [
                                PersistentBottomNavBarItem(
                                  icon: const Icon(Icons.explore),
                                  title: 'Discover',
                                ),
                                PersistentBottomNavBarItem(
                                  icon: const Icon(Icons.book),
                                  title: 'Bookshelf',
                                ),
                                PersistentBottomNavBarItem(
                                  icon: const Icon(Icons.more_horiz),
                                  title: 'More',
                                ),
                              ],
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              resizeToAvoidBottomInset: false,
                              hideNavigationBarWhenKeyboardAppears: false,
                              stateManagement: true,
                              navBarStyle: NavBarStyle.style3,
                            ),
                          ),
                  ),
                ),
              ),
            );
            Future<void> wait(bool Function() ready) async {
              for (var i = 0; i < 150; i++) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 30)),
                );
                await tester.pump();
                if (ready()) return;
              }
              final toolbars = tester
                  .widgetList<BookshelfContentToolbar>(
                    find.byType(BookshelfContentToolbar),
                  )
                  .map(
                    (bar) =>
                        '${bar.keyPrefix}:filterEnabled=${bar.onFilter != null}',
                  )
                  .join(', ');
              final panes = tester
                  .widgetList<VideoBookshelfPane>(
                    find.byType(VideoBookshelfPane, skipOffstage: false),
                  )
                  .map((pane) => '${pane.mode.name}:active=${pane.isActive}')
                  .join(', ');
              fail(
                'main shelf did not reach expected state; visible toolbars: $toolbars; video panes: $panes',
              );
            }

            _filterStage('mount.done');
            // Enter video through the production media selector. This test
            // targets the filter flow, independently of preference restoration.
            await pumpTransition();
            if (medium == 'video') {
              if (styleName == 'system') {
                final selector = find.byWidgetPredicate(
                  (widget) =>
                      widget is NativeVideoSegmentedControl &&
                      widget.options.containsKey('video'),
                );
                expect(selector, findsOneWidget);
                final mediaControl = tester.widget<NativeVideoSegmentedControl>(
                  selector,
                );
                expect(mediaControl.enabled, isTrue);
                mediaControl.onSelected!('video');
              } else {
                final video = find.descendant(
                  of: find.byType(BreezeSectionSelector<String>),
                  matching: find.text(t.bookshelf.mediaVideos),
                );
                expect(video.hitTestable(), findsOneWidget);
                await tester.tap(video);
              }
              await pumpTransition();
            }
            final trigger = find.byKey(ValueKey('$medium-shelf.filter'));
            await wait(
              () =>
                  trigger.evaluate().isNotEmpty &&
                  tester.widget<SourceChromeIconButton>(trigger).onPressed !=
                      null,
            );
            await pumpTransition();
            if (medium == 'comic') {
              if (preview) {
                await writeUiPreview(
                  tester,
                  previewKey,
                  'bookshelf-teal-${brightness.name}',
                );
              }
              final card = find.byType(ComicSimplifyEntry).first;
              final bloc = tester.element(card).read<FolderShelfBloc>();
              final cover = find
                  .descendant(of: card, matching: find.byType(CoverWidget))
                  .first;
              final restingRect = tester.getRect(cover);
              final restingWidth = restingRect.width;
              final mark = find.descendant(
                of: card,
                matching: find.byType(CollectionSelectionMark),
              );
              final hold = await tester.startGesture(tester.getCenter(card));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 250));
              expect(bloc.state.selectionMode, isFalse);
              expect(tester.getRect(cover).width, lessThan(restingWidth));
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump();
              expect(bloc.state.selectionMode, isTrue);
              expect(bloc.state.selectedComicKeys, hasLength(1));
              await hold.up();
              await pumpTransition();
              expect(tester.getRect(cover), restingRect);
              expect(
                tester.widget<CollectionSelectionMark>(mark).selected,
                isTrue,
              );
              expect(bloc.state.selectedComicKeys, hasLength(1));
              tester
                  .widget<BookshelfSelectionToolbar>(
                    find.byType(BookshelfSelectionToolbar),
                  )
                  .onCancel!();
              await pumpTransition();
              expect(bloc.state.selectionMode, isFalse);
              expect(tester.getRect(cover), restingRect);
              expect(
                tester.widget<CollectionSelectionMark>(mark).visible,
                isFalse,
              );
              final scroll = await tester.startGesture(
                tester.getCenter(find.byType(ComicSimplifyEntry).first),
              );
              await tester.pump(const Duration(milliseconds: 200));
              await scroll.moveBy(const Offset(0, -80));
              await tester.pump(const Duration(milliseconds: 350));
              await scroll.up();
              await pumpTransition();
              expect(bloc.state.selectionMode, isFalse);
              expect(bloc.state.selectedComicKeys, isEmpty);
              expect(tester.takeException(), isNull);
            }
            final hostContext = tester.element(find.byType(BookshelfPage));
            final rootNavigator = Navigator.of(
              hostContext,
              rootNavigator: true,
            );
            expect(
              Navigator.of(hostContext),
              isNot(same(rootNavigator)),
              reason: 'Exercise the real nested tab Navigator',
            );
            Future<void> open() async {
              _filterStage('sheet.open.begin');
              if (styleName == 'system') {
                final native = find.descendant(
                  of: trigger,
                  matching: find.byType(NativeVideoIconButton),
                );
                expect(
                  find.descendant(of: native, matching: find.byType(UiKitView)),
                  findsOneWidget,
                );
                tester.widget<NativeVideoIconButton>(native).onPressed!();
              } else {
                await tester.tap(trigger);
              }
              await pumpTransition();
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(const ValueKey('shelf-filter-apply')),
                findsOneWidget,
              );
            }

            Future<void> choose() async {
              _filterStage('sheet.choose.begin');
              // This fixture has only tags, already active in the common sheet.
              expect(
                find.byKey(const ValueKey('shelf-facet-search')),
                findsOneWidget,
              );
              await pumpTransition();
              expect(tester.takeException(), isNull);
              await tester.enterText(
                find.byKey(const ValueKey('shelf-facet-search')),
                'Tag0',
              );
              await pumpTransition();
              await tester.ensureVisible(
                find.byKey(const ValueKey('shelf-option-tags-Tag0')),
              );
              await tester.tap(
                find.byKey(const ValueKey('shelf-option-tags-Tag0')),
              );
              await pumpTransition();
              expect(
                find.text(t.bookshelf.facets.resultTitle(count: 1)),
                findsOneWidget,
              );
            }

            _filterStage('sheet.open.await');
            await open();
            _filterStage('sheet.open.done');
            final footer = find.byKey(const ValueKey('shelf-filter-apply'));
            expect(
              Navigator.of(tester.element(footer)),
              same(rootNavigator),
              reason: 'Sheet route must cover the tab navigation and barrier',
            );
            expect(footer.hitTestable(), findsOneWidget);
            await choose();
            _filterStage('sheet.choose.done');
            // Keep the navigation mounted, with its existing native material.
            if (styleName == 'system') {
              expect(find.byType(VideoNativeNavigation), findsOneWidget);
            }
            await tester.tap(find.byTooltip(t.common.cancel));
            await pumpTransition();
            _filterStage('sheet.open.await');
            await open();
            _filterStage('sheet.open.done');
            expect(
              find.text(t.bookshelf.facets.resultTitle(count: 12)),
              findsOneWidget,
            );
            await choose();
            _filterStage('sheet.choose.done');
            _filterStage('sheet.apply.begin');
            await tester.tap(footer);
            await pumpTransition();
            final toolbar = find.byWidgetPredicate(
              (widget) =>
                  widget is BookshelfContentToolbar &&
                  widget.keyPrefix == '$medium-shelf' &&
                  widget.filterActive &&
                  widget.canRun?.call() == true,
            );
            await wait(() => toolbar.evaluate().isNotEmpty);
            expect(
              find.byKey(ValueKey('$medium-shelf.clear-filter')),
              findsNothing,
            );
            expect(
              find.byKey(ValueKey('$medium-shelf.filter-status')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            _filterStage('unmount.begin');
            await tester.pumpWidget(const SizedBox.shrink());
            // Both media panes can still be finishing local filesystem reads.
            // Drain their shared read boundary while this case's FakeAsync
            // zone is alive; the next runAsync seed cannot pump an old zone.
            var drained = false;
            Object? readError;
            VideoBookshelfIndex.sourceNames().then<void>(
              (_) => drained = true,
              onError: (Object error, StackTrace stack) {
                readError = error;
                drained = true;
              },
            );
            final elapsed = Stopwatch()..start();
            while (!drained && elapsed.elapsed < const Duration(seconds: 5)) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(
              drained,
              isTrue,
              reason:
                  'Local source reads must finish before leaving this test zone.',
            );
            expect(readError, isNull);
            await tester.pump(const Duration(seconds: 1));
            controller.dispose();
            style.dispose();
            _filterStage('$medium.$styleName.${brightness.name}.done');
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
