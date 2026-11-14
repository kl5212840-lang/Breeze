import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_grid_shimmer.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_item.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

import '../test_helper.dart';

/// 书架文件夹返回：进子文件夹后按系统返回逐级回退，到根放行。
///
/// 回归背景：书架 tab 嵌在 PersistentTabView 内部 Navigator 里，文件夹下钻
/// 是 bloc 状态而非路由 push；该库在非首页 tab 按返回时内部 `canPop == false`
/// 就直接切回首页，tab 内部的 PopScope 永远收不到事件（三导航时代书架是
/// tab 0，库走 maybePop 转发，所以没暴露）。
/// 修复用 LocalHistoryEntry 把「待处理返回」注册到 tab 内部路由上：
/// 有 entry → 库正常 pop → entry 消费 → bloc 回退一级；
/// 到根（entry 已清）→ 放行，库按既有逻辑切 tab/退应用。
///
/// 注意：testWidgets 测试体跑在 FakeAsync zone，真异步（ObjectBox IO、
/// worker isolate 握手/回包）必须包在 tester.runAsync 里走真实时间，
/// 否则零 CPU 卡死；pump 只负责刷 microtask + 重建帧。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // setUpAll 跑在真实 zone，可以直接做真异步初始化。
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    // worker isolate 的 ObjectBox 指向同一测试库（attach 共享），
    // 否则 load 读不到测试建的数据。
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  final channelsByTooltip = <String, MethodChannel>{};
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (update) async {
          if (update.method == 'update' && update.arguments is Map) {
            final tooltip = (update.arguments as Map)['tooltip'];
            if (tooltip is String) channelsByTooltip[tooltip] = channel;
          }
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
    channelsByTooltip.clear();
  });
  Future<void> pressControl(WidgetTester tester, Finder control) async {
    final native = find.descendant(
      of: control,
      matching: find.byType(UiKitView),
    );
    if (native.evaluate().isEmpty) {
      await tester.tap(control);
    } else {
      final args = tester.widget<UiKitView>(native).creationParams as Map;
      final channel = channelsByTooltip[args['tooltip']];
      expect(channel, isNotNull);
      await messenger.handlePlatformMessage(
        channel!.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
        (_) {},
      );
    }
  }

  /// 等指定文案出现：真实等待让 worker 回包，pump 刷重建。
  /// loading 态有 shimmer 无限动画，不能用 pumpAndSettle。
  Future<void> waitForText(WidgetTester tester, String text) async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      if (find.text(text).evaluate().isNotEmpty) return;
    }
    throw StateError('等待 "$text" 出现超时');
  }

  /// 等指定文案消失（load 完成后文件夹行不再出现）。
  Future<void> waitForFolderGone(WidgetTester tester, String text) async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      if (find.widgetWithText(FolderShelfItem, text).evaluate().isEmpty) return;
    }
    throw StateError('等待 "$text" 消失超时');
  }

  Future<void> pumpShelf(
    WidgetTester tester, {
    bool overlayBottomBar = false,
    double textScale = 1,
    bool reduceMotion = true,
    Map<String, String> sourceNames = const {},
    ShelfPageMode mode = ShelfPageMode.favorite,
    String interfaceStyle = 'system',
    Brightness brightness = Brightness.light,
  }) async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    addTearDown(() => LocaleSettings.useDeviceLocale());
    final stylePreference = ValueNotifier(interfaceStyle);
    addTearDown(stylePreference.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GlobalSettingCubit>(create: (_) => GlobalSettingCubit()),
          BlocProvider<BookshelfSearchCubit>(
            create: (_) => BookshelfSearchCubit(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => AppInterfaceStyleScope(
            style: stylePreference,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reduceMotion,
              ),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  bottom: overlayBottomBar ? 120 : 0,
                  child: FolderShelfPage(
                    sourceNames: sourceNames,
                    mode: mode,
                    isActive: true,
                  ),
                ),
                if (overlayBottomBar)
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: ColoredBox(color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final mode in [ShelfPageMode.favorite, ShelfPageMode.history]) {
    testWidgets('first comic ${mode.name} frame waits for a real snapshot', (
      tester,
    ) async {
      await pumpShelf(tester, mode: mode);
      expect(find.text(t.comicList.nothingHere), findsNothing);
      expect(find.byType(BookshelfGridShimmer), findsOneWidget);
      final toolbar = find.byType(BookshelfContentToolbar);
      expect(tester.widget<BookshelfContentToolbar>(toolbar).subtitle, isEmpty);
      expect(tester.widget<BookshelfContentToolbar>(toolbar).onFilter, isNull);
      await waitForText(tester, t.comicList.nothingHere);
      expect(find.byType(BookshelfGridShimmer), findsNothing);
      expect(
        tester.widget<BookshelfContentToolbar>(toolbar).subtitle,
        t.videoLibrary.results(count: 0),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'actual comic history shelf list shows full reading time $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            objectbox.unifiedHistoryBox.put(
              createTestHistory(
                  'shelf-reading',
                  updatedAt: DateTime(2030, 1, 1),
                )
                ..lastReadAt = DateTime(2026, 11, 1, 9, 5)
                ..chapterTitle = '第8话',
            );
          });
          await pumpShelf(
            tester,
            mode: ShelfPageMode.history,
            textScale: 2,
            interfaceStyle: style,
            brightness: brightness,
          );
          await waitForText(tester, 'Test Comic shelf-reading');
          expect(
            find.byType(ComicLastReadLine),
            findsNothing,
            reason: 'grid layout is retained',
          );
          await pressControl(
            tester,
            find.byKey(const ValueKey('comic-shelf.view')),
          );
          await tester.pumpAndSettle();
          final time = find.byKey(const ValueKey('shelf-detail.time'));
          expect(time, findsOneWidget);
          final text = tester.widget<Text>(time);
          expect(text.data, contains('2026-11-01 09:05'));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: time, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            find.ancestor(
              of: time,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label ==
                        t.comicEntry.lastReadAt(time: '2026-11-01 09:05'),
              ),
            ),
            findsOneWidget,
          );
          expect(text.style?.fontWeight, FontWeight.w400);
          expect(
            text.style?.color,
            Theme.of(tester.element(time)).colorScheme.onSurfaceVariant,
          );
          expect(tester.getRect(time).right, lessThanOrEqualTo(320));
          expect(
            tester
                .getRect(find.text(t.bookshelf.readTo(chapter: '第8话')))
                .bottom,
            lessThanOrEqualTo(tester.getRect(time).top),
          );
          expect(find.textContaining('2030-01-01'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 5));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets('进两级文件夹后返回逐级回退，到根放行', (tester) async {
    await tester.runAsync(() async {
      final parent = ComicFolderService.createFolder(
        '',
        'parent',
        ComicFolderType.favorite,
      );
      final parentPath = ComicFolderService.folderPath(parent);
      ComicFolderService.createFolder(
        parentPath,
        'child',
        ComicFolderType.favorite,
      );
    });

    await pumpShelf(tester);
    await waitForText(tester, 'parent');

    // 进 parent，再进 child。
    await tester.tap(find.text('parent'));
    await waitForText(tester, 'child');
    expect(find.widgetWithText(FolderShelfItem, 'parent'), findsNothing);
    expect(
      tester
          .widget<BookshelfContentToolbar>(find.byType(BookshelfContentToolbar))
          .title,
      'parent',
    );

    await tester.tap(find.text('child'));
    // child 为空文件夹：load 完成后文件夹行消失（显示空态）。
    await waitForFolderGone(tester, 'child');

    // 第一次返回：child -> parent（entry 消费，路由仍在）。
    var consumed = await tester.binding.handlePopRoute();
    expect(consumed, isTrue);
    await waitForText(tester, 'child');
    expect(
      tester
          .widget<BookshelfContentToolbar>(find.byType(BookshelfContentToolbar))
          .title,
      'parent',
    );

    // 第二次返回：parent -> 根。
    consumed = await tester.binding.handlePopRoute();
    expect(consumed, isTrue);
    await waitForText(tester, 'parent');

    // 到根：entry 已清，不再拦截，放行给导航（路由本身不被 pop）。
    consumed = await tester.binding.handlePopRoute();
    expect(consumed, isFalse);
    await tester.pump();
    expect(find.text('parent'), findsOneWidget);
    // 放行测试体结束时的 FakeAsync 检查：把一次性 Timer 跑完。
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('根目录直接返回不拦截', (tester) async {
    await tester.runAsync(() async {
      ComicFolderService.createFolder('', 'solo', ComicFolderType.favorite);
    });

    await pumpShelf(tester);
    await waitForText(tester, 'solo');

    final consumed = await tester.binding.handlePopRoute();
    expect(consumed, isFalse);
    await tester.pump();
    expect(find.text('solo'), findsOneWidget);
    // 放行测试体结束时的 FakeAsync 检查：把一次性 Timer 跑完。
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('多选上下文常驻顶部，浮动操作在已预留底栏的视口内可操作', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      ComicFolderService.createFolder('', 'keep', ComicFolderType.favorite);
    });
    await pumpShelf(tester, overlayBottomBar: true, textScale: 2);
    await waitForText(tester, 'keep');
    final bloc = tester.element(find.text('keep')).read<FolderShelfBloc>();
    bloc.add(const FolderShelfEnterSelectionMode());
    await tester.pump();
    final cancel = find.byKey(const ValueKey('comic-shelf.cancel'));
    expect(cancel.hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(cancel).dy, lessThan(620));
    final selectAll = find.byTooltip(t.common.selectAll);
    await tester.tap(selectAll);
    await tester.pump();
    expect(bloc.state.selectedCount, 1);
    expect(cancel.hitTestable(), findsOneWidget);
    expect(find.byTooltip(t.common.delete).hitTestable(), findsOneWidget);
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('comic-shelf.floating-actions')),
          )
          .dy,
      lessThanOrEqualTo(608),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('comic-shelf.remove'))).dy,
      greaterThan(tester.getBottomLeft(cancel).dy),
    );
    expect(
      find.byTooltip(t.bookshelf.deselectAll).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(t.bookshelf.deselectAll));
    await tester.pump();
    expect(bloc.state.selectedCount, 0);
    expect(bloc.state.selectionMode, isTrue);
    expect(find.byTooltip(t.common.selectAll).hitTestable(), findsOneWidget);
    await tester.tap(cancel);
    await tester.pump();
    expect(bloc.state.selectionMode, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('输入后点空白取消保留退场资源，可再次打开并正常创建', (tester) async {
    await tester.runAsync(() async {
      ComicFolderService.createFolder('', 'keep', ComicFolderType.favorite);
    });
    await pumpShelf(tester, reduceMotion: false);
    await waitForText(tester, 'keep');
    tester
        .widget<NativeVideoMenu>(find.byKey(const ValueKey('comic-shelf.more')))
        .onSelected('__new');
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('shelf-folder-name.input'));
    await tester.showKeyboard(input);
    await tester.enterText(input, '不应创建');
    await tester.tapAt(const Offset(5, 5));
    // showDialog's Future completes before its reverse transition. The field
    // must keep its controller alive through these intermediate frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      ComicFolderService.listChildFolders(
        '',
        ComicFolderType.favorite,
      ).map((f) => f.name),
      ['keep'],
    );
    tester
        .widget<NativeVideoMenu>(find.byKey(const ValueKey('comic-shelf.more')))
        .onSelected('__new');
    await tester.pumpAndSettle();
    await tester.enterText(input, '创建成功');
    await tester.tap(find.byKey(const ValueKey('shelf-folder-name.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);
    await waitForText(tester, '创建成功');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('进文件夹时列表先回顶再渲染', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        ComicFolderService.createFolder(
          '',
          'f${i.toString().padLeft(2, '0')}',
          ComicFolderType.favorite,
        );
      }
    });

    await pumpShelf(tester);
    // 默认倒序，最晚建的 f39 在最前（懒加载只渲染可见行，等 f00 必超时）。
    await waitForText(tester, 'f39');

    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    // 向下滚一段：offset > 0。fling 有惯性，多推几帧等它停稳再点，
    // 否则 tap 会打偏（hitTestWarning）根本没进文件夹。
    await tester.fling(find.byType(GridView), const Offset(0, -2000), 2000);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(offset(), greaterThan(0));

    // 点当前可见的任一文件夹：路径变化 → 回顶。
    // Slivers keep cached text above the viewport. The fixed path toolbar must
    // not make such cached rows count as a visible folder to tap.
    final visibleFolder = find
        .byWidgetPredicate(
          (widget) =>
              widget is Text && RegExp(r'^f\d\d$').hasMatch(widget.data ?? ''),
        )
        .hitTestable()
        .first;
    expect(visibleFolder, findsOneWidget);
    await tester.tap(visibleFolder);
    // 进子文件夹后面包屑仍显示文件夹名，不能用文本消失断言；
    // 等 bloc 路径切过去，再断言已回顶。
    String currentPath() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .context
        .read<FolderShelfBloc>()
        .state
        .currentPath;
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      if (currentPath().isNotEmpty) break;
    }
    expect(currentPath(), isNotEmpty);
    await tester.pump();
    expect(offset(), 0);
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('选择反馈更新单行，返回先退选再退文件夹', (tester) async {
    late String childPath;
    await tester.runAsync(() async {
      final parent = ComicFolderService.createFolder(
        '',
        'parent',
        ComicFolderType.favorite,
      );
      final child = ComicFolderService.createFolder(
        ComicFolderService.folderPath(parent),
        'child',
        ComicFolderType.favorite,
      );
      childPath = ComicFolderService.folderPath(child);
    });
    await pumpShelf(tester);
    await waitForText(tester, 'parent');
    await tester.tap(find.text('parent'));
    await waitForText(tester, 'child');
    final context = tester.element(find.text('child'));
    final bloc = context.read<FolderShelfBloc>();
    final parentPath = bloc.state.currentPath;
    bloc.add(const FolderShelfEnterSelectionMode());
    bloc.add(FolderShelfToggleFolderSelection(childPath));
    await tester.pump();
    expect(
      tester
          .widget<FolderShelfItem>(find.byType(FolderShelfItem).first)
          .isSelected,
      isTrue,
    );
    expect(bloc.state.selectedCount, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(bloc.state.selectionMode, isFalse);
    expect(bloc.state.currentPath, parentPath);
    await tester.binding.handlePopRoute();
    await waitForText(tester, 'parent');
    expect(bloc.state.isRoot, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets(
    'folder cover scales its neutral icon within the poster at 320 double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        ComicFolderService.createFolder(
          '',
          '长名称的收藏文件夹',
          ComicFolderType.favorite,
        );
      });
      await pumpShelf(tester, textScale: 2);
      await waitForText(tester, '长名称的收藏文件夹');
      final cover = find.byType(BookshelfFolderVisual);
      final mark = find.descendant(
        of: cover,
        matching: find.byIcon(Icons.folder_outlined),
      );
      expect(mark, findsOneWidget);
      final markRect = tester.getRect(mark), coverRect = tester.getRect(cover);
      expect(markRect.width, inInclusiveRange(18, 28));
      expect(markRect.width, lessThan(coverRect.width - 12));
      expect(markRect.height, closeTo(markRect.width, .01));
      expect(coverRect.contains(markRect.topLeft), isTrue);
      expect(coverRect.contains(markRect.bottomRight), isTrue);
      final tint = tester.widget<AnimatedContainer>(
        find.descendant(of: cover, matching: find.byType(AnimatedContainer)),
      );
      final paint = tint.foregroundDecoration as BoxDecoration;
      expect(paint.gradient, isNull);
      expect(paint.color!.a, 0);
      expect(tint.duration, Duration.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
  for (final interfaceStyle in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          'comic shelf $interfaceStyle ${brightness.name} has three-column covers and a real list at scale $scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.runAsync(() async {
              for (var i = 0; i < 3; i++) {
                ComicFolderService.createFolder(
                  '',
                  'Shelf folder$i',
                  ComicFolderType.favorite,
                );
              }
            });
            await pumpShelf(
              tester,
              textScale: scale,
              interfaceStyle: interfaceStyle,
              brightness: brightness,
              sourceNames: {'source-a': '真实来源'},
            );
            await waitForText(tester, 'Shelf folder2');
            final bloc = tester
                .element(find.text('Shelf folder2'))
                .read<FolderShelfBloc>();
            bloc.emit(
              bloc.state.copyWith(
                comics: const [
                  ComicSimplifyEntryInfo(
                    title: '书架作品完整标题',
                    id: 'fixture',
                    fileServer: '',
                    path: '',
                    pictureType: PictureType.unknown,
                    from: 'source-a',
                    source: 'source-a',
                  ),
                ],
                comicSearchTexts: const {'source-a:fixture': '书架作品完整标题'},
              ),
            );
            await tester.pump();
            expect(find.byType(BookshelfContentToolbar), findsOneWidget);
            expect(
              Theme.of(
                tester.element(find.byType(BookshelfContentToolbar)),
              ).brightness,
              brightness,
            );
            expect(
              find.byType(UiKitView),
              interfaceStyle == 'system' ? findsWidgets : findsNothing,
            );
            final grid = tester.widget<GridView>(find.byType(GridView));
            expect(
              (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                  .crossAxisCount,
              3,
            );
            final folderRects = find
                .byType(FolderShelfItem)
                .evaluate()
                .map((e) => tester.getRect(find.byWidget(e.widget)))
                .toList();
            expect(folderRects.map((r) => r.top).toSet(), hasLength(1));
            expect(folderRects.map((r) => r.left).toSet(), hasLength(3));
            for (final suffix in ['filter', 'view', 'more']) {
              expect(
                find.byKey(ValueKey('comic-shelf.$suffix')),
                findsOneWidget,
              );
              expect(
                tester.getSize(find.byKey(ValueKey('comic-shelf.$suffix'))),
                const Size(44, 44),
              );
            }
            expect(
              find.byKey(const ValueKey('comic-shelf.new-folder')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('comic-shelf.manage')),
              findsNothing,
            );
            final more = tester.widget<NativeVideoMenu>(
              find.byWidgetPredicate(
                (w) => w is NativeVideoMenu && w.tooltip == t.common.more,
              ),
            );
            expect(more.hostPresentation, isTrue);
            final comic = find.byType(ComicSimplifyEntry);
            await tester.ensureVisible(comic);
            await tester.pump();
            final cover = find.descendant(
              of: comic,
              matching: find.byType(CoverWidget),
            );
            final coverRect = tester.getRect(cover);
            expect(coverRect.width / coverRect.height, closeTo(2 / 3, .001));
            expect(
              tester
                  .getTopLeft(
                    find.descendant(
                      of: comic,
                      matching: find.byType(BookshelfCardCaption),
                    ),
                  )
                  .dy,
              greaterThanOrEqualTo(coverRect.bottom),
            );
            expect(find.text('真实来源'), findsOneWidget);
            await pressControl(
              tester,
              find.byKey(const ValueKey('comic-shelf.view')),
            );
            await tester.pump();
            expect(find.byType(GridView), findsNothing);
            expect(find.byType(ListView), findsOneWidget);
            expect(tester.widget<ComicSimplifyEntry>(comic).horizontal, isTrue);
            expect(
              tester
                  .widget<FolderShelfItem>(find.byType(FolderShelfItem).first)
                  .view,
              BookshelfContentView.list,
            );
            await tester.ensureVisible(comic);
            tester
                .widget<NativeVideoMenu>(
                  find.byKey(const ValueKey('comic-shelf.more')),
                )
                .onSelected('__manage');
            await tester.pump();
            await tester.tap(comic);
            await tester.pump();
            expect(bloc.state.selectedComicKeys, {'source-a:fixture'});
            expect(tester.widget<ComicSimplifyEntry>(comic).isSelected, isTrue);
            await tester.binding.handlePopRoute();
            await tester.pump();
            expect(bloc.state.selectionMode, isFalse);
            expect(tester.widget<ComicSimplifyEntry>(comic).horizontal, isTrue);
            final folder = find.text('Shelf folder2');
            await tester.ensureVisible(folder);
            await tester.pump();
            await tester.tap(folder.hitTestable());
            await tester.pump();
            expect(bloc.state.currentPath, contains('Shelf folder2'));
            await tester.binding.handlePopRoute();
            await waitForText(tester, 'Shelf folder2');
            expect(bloc.state.isRoot, isTrue);
            expect(
              tester
                  .widget<BookshelfContentToolbar>(
                    find.byType(BookshelfContentToolbar),
                  )
                  .view,
              BookshelfContentView.list,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 5));
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  testWidgets(
    'default comic card retains its original cover geometry and callbacks',
    (tester) async {
      var tapped = 0, longPressed = 0;
      const info = ComicSimplifyEntryInfo(
        title: '旧卡标题',
        id: 'default-card',
        fileServer: '',
        path: '',
        pictureType: PictureType.unknown,
        from: 'fixture',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                height: 160,
                child: ComicSimplifyEntry(
                  info: info,
                  type: ComicEntryType.normal,
                  onTapOverride: (_) => tapped++,
                  onLongPressOverride: (_, _) => longPressed++,
                ),
              ),
            ),
          ),
        ),
      );
      final card = find.byType(ComicSimplifyEntry);
      expect(tester.widget<ComicSimplifyEntry>(card).caption, isNull);
      expect(tester.getSize(find.byType(CoverWidget)), const Size(120, 160));
      expect(find.text('旧卡标题'), findsOneWidget);
      await tester.tap(card);
      await tester.longPress(card);
      expect(tapped, 1);
      expect(longPressed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets(
    'history toolbar offers layout and management without directory actions',
    (tester) async {
      await pumpShelf(tester, mode: ShelfPageMode.history);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
      }
      final toolbar = tester.widget<BookshelfContentToolbar>(
        find.byType(BookshelfContentToolbar),
      );
      expect(toolbar.showCreateFolder, isFalse);
      expect(toolbar.onBack, isNull);
      expect(
        find.byKey(const ValueKey('comic-shelf.new-folder')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('comic-shelf.view')), findsOneWidget);
      final more = tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.tooltip == t.common.more,
        ),
      );
      expect(more.options, containsPair('help', t.common.help));
      expect(more.options.keys, isNot(contains('__new')));
      expect(more.options.keys, isNot(contains('root')));
      expect(more.hostPresentation, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'bookshelf loading skeleton uses the same three columns and list footprint',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> mount(BookshelfContentView view) => tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: BookshelfGridShimmer(itemCount: 3, view: view)),
        ),
      );
      await mount(BookshelfContentView.grid);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3,
      );
      final covers = find.byType(AspectRatio);
      expect(covers, findsNWidgets(3));
      for (final size in covers.evaluate().map(
        (e) => tester.getSize(find.byWidget(e.widget)),
      )) {
        expect(size.width / size.height, closeTo(2 / 3, .001));
      }
      await mount(BookshelfContentView.list);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      for (final size
          in find
              .byType(AspectRatio)
              .evaluate()
              .map((e) => tester.getSize(find.byWidget(e.widget)))) {
        expect(size, const Size(80, 120));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'comic grid and list restore independent scroll positions when switching',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          ComicFolderService.createFolder(
            '',
            'Position${i.toString().padLeft(2, '0')}',
            ComicFolderType.favorite,
          );
        }
      });
      await pumpShelf(tester);
      await waitForText(tester, 'Position29');
      ScrollPosition position(Type view) => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(view),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position(GridView).jumpTo(300);
      await tester.pump();
      final gridOffset = position(GridView).pixels;
      await tester.tap(find.byKey(const ValueKey('comic-shelf.view')));
      await tester.pump();
      position(ListView).jumpTo(500);
      await tester.pump();
      final listOffset = position(ListView).pixels;
      await tester.tap(find.byKey(const ValueKey('comic-shelf.view')));
      await tester.pump();
      expect(position(GridView).pixels, closeTo(gridOffset, .01));
      await tester.tap(find.byKey(const ValueKey('comic-shelf.view')));
      await tester.pump();
      expect(position(ListView).pixels, closeTo(listOffset, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  for (final mode in [ShelfPageMode.favorite, ShelfPageMode.download]) {
    testWidgets(
      '${mode.name} opens folders from content and returns home through the directory path',
      (tester) async {
        final type = mode == ShelfPageMode.favorite
            ? ComicFolderType.favorite
            : ComicFolderType.download;
        await tester.runAsync(() async {
          ComicFolderService.createFolder('', '菜单分类', type);
          ComicFolderService.createFolder('菜单分类', '子分类', type);
          ComicFolderService.createFolder('/菜单分类/子分类', '孙分类', type);
        });
        await pumpShelf(tester, mode: mode);
        await waitForText(tester, '菜单分类');
        NativeVideoMenu menu() => tester.widget<NativeVideoMenu>(
          find.byKey(const ValueKey('comic-shelf.more')),
        );
        final rootMenu = menu();
        expect(rootMenu.options, isNot(contains('root')));
        expect(
          rootMenu.options.containsKey('import'),
          mode == ShelfPageMode.download,
        );
        expect(rootMenu.options.values, isNot(contains('菜单分类')));
        await tester.tap(find.text('菜单分类'));
        await waitForText(tester, '子分类');
        final bloc = tester
            .element(find.byType(BookshelfContentToolbar))
            .read<FolderShelfBloc>();
        expect(bloc.state.currentPath, '/菜单分类');
        expect(menu().options.values, isNot(contains('子分类')));
        final root = find.byKey(const ValueKey('comic-shelf.root'));
        expect(root, findsNothing);
        await tester.tap(find.text('子分类'));
        await waitForText(tester, '孙分类');
        expect(bloc.state.currentPath, '/菜单分类/子分类');
        expect(menu().options, isNot(contains('root')));
        expect(root, findsOneWidget);
        final rootLabel = tester.widget<TextButton>(root).child as Text;
        expect(
          rootLabel.data,
          mode == ShelfPageMode.favorite ? t.common.root : t.bookshelf.download,
        );
        expect(rootLabel.semanticsLabel, t.bookshelf.returnToRoot);
        await tester.tap(root);
        await waitForText(tester, '菜单分类');
        expect(bloc.state.isRoot, isTrue);
        expect(root, findsNothing);
        menu().onSelected('help');
        await tester.pumpAndSettle();
        expect(
          tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
          isTrue,
        );
        expect(
          find.text(
            mode == ShelfPageMode.favorite
                ? t.bookshelf.helpFavoriteComic
                : t.bookshelf.helpDownloadComic,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(t.common.gotIt));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }
}
