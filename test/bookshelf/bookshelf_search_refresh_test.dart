import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/object_box/model.dart';

import '../test_helper.dart';

Future<void> _localReads(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

FolderShelfBloc _comicBloc(WidgetTester tester) => tester
    .element(find.byType(BookshelfContentToolbar).first)
    .read<FolderShelfBloc>();

Set<String> _titles(FolderShelfBloc bloc) => {
  for (final row in bloc.state.comics) row.title,
};

Finder _editor() => find.descendant(
  of: find.byType(SearchQueryField),
  matching: find.byType(TextField),
);

Future<void> _mount(WidgetTester tester, {double navInset = 0}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final style = ValueNotifier('breeze');
  addTearDown(style.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GlobalSettingCubit()),
        BlocProvider(create: (_) => PluginRegistryCubit()),
      ],
      child: AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: NativeNavigationInset(
            bottom: navInset,
            child: const BookshelfPage(),
          ),
        ),
      ),
    ),
  );
  await _localReads(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final entry in {
      'needle': ('Needle Alpha', 'red'),
      'beta': ('Beta', 'red'),
      'gamma': ('Gamma', 'blue'),
    }.entries) {
      final row = createTestFavorite('unregistered-source:${entry.key}')
        ..source = 'unregistered-source'
        ..comicId = entry.key
        ..title = entry.value.$1
        ..metadata = jsonEncode([
          {
            'type': 'tags',
            'value': [entry.value.$2],
          },
        ]);
      objectbox.unifiedFavoriteBox.put(row);
      ComicLinkService.addComic(row.uniqueKey, null, ComicFolderType.favorite);
    }
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  testWidgets(
    'comic debounce filters the real host without submitting and clear retains facets',
    (tester) async {
      await _mount(tester);
      final bloc = _comicBloc(tester);
      expect(_titles(bloc), {'Needle Alpha', 'Beta', 'Gamma'});
      bloc.add(
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            values: {
              'tags': {'red'},
            },
          ),
        ),
      );
      await _localReads(tester);
      expect(_titles(bloc), {'Needle Alpha', 'Beta'});
      await tester.tap(find.byTooltip(t.bookshelf.searchList));
      await tester.pump();
      await tester.enterText(_editor(), 'Needle');
      await tester.pump(const Duration(milliseconds: 499));
      expect(_titles(bloc), {'Needle Alpha', 'Beta'});
      await tester.pump(const Duration(milliseconds: 1));
      await _localReads(tester);
      expect(bloc.state.search?.keyword, 'Needle');
      expect(_titles(bloc), {'Needle Alpha'});
      expect(find.text('Needle Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      await tester.enterText(_editor(), '');
      await _localReads(tester);
      expect(bloc.state.search?.keyword, '');
      expect(bloc.state.facets.values['tags'], {'red'});
      expect(_titles(bloc), {'Needle Alpha', 'Beta'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _localReads(tester);
      // PictureBloc's stream throttle owns a 100ms trailing timer. Its close
      // future can finish only after fake time advances; runAsync above drains
      // worker IO, but deliberately does not advance the debounce test clock.
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'comic positions survive media, record, source and filter changes',
    (tester) async {
      for (var id = 0; id < 72; id++) {
        final row = createTestFavorite('unregistered-source:long$id')
          ..source = 'unregistered-source'
          ..comicId = 'long$id';
        objectbox.unifiedFavoriteBox.put(row);
        ComicLinkService.addComic(
          row.uniqueKey,
          null,
          ComicFolderType.favorite,
        );
      }
      final short = createTestFavorite('short-source:only')
        ..source = 'short-source'
        ..comicId = 'only';
      objectbox.unifiedFavoriteBox.put(short);
      ComicLinkService.addComic(
        short.uniqueKey,
        null,
        ComicFolderType.favorite,
      );

      await _mount(tester, navInset: 72);
      final favorite = find.byKey(const ValueKey('comic-shelf.favorite'));
      final grid = find.descendant(
        of: favorite,
        matching: find.byType(GridView),
      );
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(of: grid, matching: find.byType(Scrollable)),
          )
          .position;
      final top = find.byKey(const ValueKey('bookshelf.return-to-top'));
      expect(top, findsNothing);
      position().jumpTo(position().viewportDimension * 2.5);
      await tester.pumpAndSettle();
      final offset = position().pixels;
      expect(top, findsOneWidget);
      expect(
        tester.getRect(top).bottom,
        lessThan(tester.getRect(grid).bottom - 72),
      );

      await tester.tap(find.byTooltip(t.bookshelf.searchList));
      await tester.pumpAndSettle();
      expect(top, findsNothing);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(top, findsOneWidget);

      await tester.tap(find.text(t.bookshelf.mediaVideos));
      await _localReads(tester);
      expect(top, findsNothing);
      await tester.tap(find.text(t.bookshelf.mediaComics));
      await _localReads(tester);
      expect(position().pixels, closeTo(offset, 1));

      final tabs = find.byKey(const ValueKey('bookshelf.records'));
      await tester.tap(
        find.descendant(of: tabs, matching: find.text(t.bookshelf.history)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _localReads(tester);
      expect(top, findsNothing);
      await tester.tap(
        find.descendant(of: tabs, matching: find.text(t.bookshelf.favorite)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _localReads(tester);
      expect(position().pixels, closeTo(offset, 1));

      await tester.tap(
        find.byKey(const ValueKey('bookshelf.source.short-source')),
      );
      await _localReads(tester);
      expect(position().pixels, 0);
      expect(top, findsNothing);
      await tester.tap(find.byKey(const ValueKey('bookshelf.source.')));
      await _localReads(tester);
      expect(position().pixels, closeTo(offset, 1));

      final bloc = _comicBloc(tester);
      bloc.add(
        const FolderShelfSetFacets(
          ShelfFacetSelection(
            values: {
              'tags': {'red'},
            },
          ),
        ),
      );
      await _localReads(tester);
      expect(position().pixels, 0);
      expect(top, findsNothing);
      bloc.add(const FolderShelfSetFacets(ShelfFacetSelection()));
      await _localReads(tester);
      expect(position().pixels, closeTo(offset, 1));
      final refresh = bloc.refresh();
      await _localReads(tester);
      expect(await refresh, isTrue);
      expect(position().pixels, closeTo(offset, 1));
      await tester.tap(top);
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      expect(top, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _localReads(tester);
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'leaving a pending comic editor flushes its own scope across media changes',
    (tester) async {
      await _mount(tester);
      final bloc = _comicBloc(tester);
      final comicSearch = tester
          .element(find.byType(FolderShelfPage).first)
          .read<BookshelfSearchCubit>();
      final videoSearch = tester
          .element(find.byType(VideoBookshelfPane, skipOffstage: false).first)
          .read<BookshelfSearchCubit>();
      await tester.tap(find.byTooltip(t.bookshelf.searchList));
      await tester.pump();
      await tester.enterText(_editor(), 'Needle');
      // Leave before the debounce expires. Returning to the media chooser must
      // commit and refresh comics, without writing the pending word to videos.
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pump();
      expect(_editor(), findsNothing);
      await tester.tap(find.text(t.bookshelf.mediaVideos));
      await _localReads(tester);
      expect(comicSearch.state.favorite.keyword, 'Needle');
      expect(videoSearch.state.favorite.keyword, '');
      expect(bloc.state.search?.keyword, 'Needle');
      expect(_titles(bloc), {'Needle Alpha'});
      await tester.pump(const Duration(milliseconds: 600));
      expect(videoSearch.state.favorite.keyword, '');
      await tester.tap(find.text(t.bookshelf.mediaComics));
      await _localReads(tester);
      expect(_titles(bloc), {'Needle Alpha'});
      expect(find.text('Needle Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bookshelf.search')));
      await tester.pump();
      expect(tester.widget<TextField>(_editor()).controller!.text, 'Needle');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _localReads(tester);
      // PictureBloc's stream throttle owns a 100ms trailing timer. Its close
      // future can finish only after fake time advances; runAsync above drains
      // worker IO, but deliberately does not advance the debounce test clock.
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
