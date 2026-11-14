import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/video_bookshelf_pane.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    debugShelfDbRootPath = TestObjectBoxHelper.tempPath;
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await workerManager.dispose();
    debugShelfDbRootPath = null;
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });

  testWidgets(
    'bookshelf migrates old sorts once, saves each list, and applies a changed default on return',
    (tester) async {
      const oldKey = 'breeze.bookshelf.video.sorts.v1';
      const key = 'breeze.bookshelf.video.sorts.v2';
      Future<void> reads() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 40));
        }
      }

      for (final remember in [false, true]) {
        for (final savedIndex in [0, 1, 2]) {
          final mode = savedIndex == 1
              ? ShelfPageMode.history
              : ShelfPageMode.favorite;
          SharedPreferences.setMockInitialValues({
            'breeze.bookshelf.media.v1': 'video',
            oldKey: ['da', 'da', 'da'],
          });
          final settings = GlobalSettingCubit();
          settings.updateBookshelfSetting(
            (s) => s.copyWith(
              homePageIndex: savedIndex,
              rememberFavoriteSort: remember && mode == ShelfPageMode.favorite,
              rememberHistorySort: remember && mode == ShelfPageMode.history,
              rememberDownloadSort: remember && mode == ShelfPageMode.download,
            ),
          );
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => settings),
                BlocProvider(create: (_) => PluginRegistryCubit()),
              ],
              child: MaterialApp(home: BookshelfPage(key: UniqueKey())),
            ),
          );
          await reads();
          final pane = find.byKey(ValueKey('video-shelf.${mode.name}'));
          expect(pane, findsOneWidget);
          expect(
            find.byKey(const ValueKey('video-shelf.download')),
            findsNothing,
            reason:
                'downloads live in the main download center; old saved index 2 safely opens favorites',
          );
          expect(
            tester.widget<VideoBookshelfPane>(pane).search.sort,
            remember ? 'da' : 'dd',
          );
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getStringList(key), [
            for (final m in [ShelfPageMode.favorite, ShelfPageMode.history])
              remember && mode == m ? 'da' : 'dd',
          ]);
          final scope = BookshelfActionsScope.forPane(
            tester.element(pane),
            video: true,
            mode: mode,
          )!;
          expect(scope.onSort, isNotNull);
          expect(scope.options.containsKey('__sort.reset'), isFalse);
          final more = tester.widget<NativeVideoMenu>(
            find.byKey(const ValueKey('video-shelf.more')),
          );
          expect(
            more.options.values,
            isNot(contains(t.bookshelf.ordering.reset)),
          );
          more.onSelected('__sort');
          await tester.pumpAndSettle();
          final reset = find.text(t.bookshelf.ordering.reset);
          expect(reset, remember ? findsOneWidget : findsNothing);
          await tester.tap(
            remember
                ? reset
                : find.byKey(const ValueKey('video-shelf.sort.__sort.da')),
          );
          await tester.pumpAndSettle();
          await reads();
          expect(
            preferences.getStringList(key),
            [
              for (final m in [ShelfPageMode.favorite, ShelfPageMode.history])
                !remember && mode == m ? 'da' : 'dd',
            ],
            reason:
                'Only the selected list is saved, regardless of the old switch',
          );
          expect(
            tester.widget<VideoBookshelfPane>(pane).search.sort,
            remember ? 'dd' : 'da',
          );
          expect(tester.takeException(), isNull);
          final other = mode == ShelfPageMode.history
              ? ShelfPageMode.favorite
              : ShelfPageMode.history;
          settings.updateBookshelfSetting(
            (state) => state.copyWith(homePageIndex: other.index),
          );
          await reads();
          await tester.pumpAndSettle();
          final otherPane = find.byKey(ValueKey('video-shelf.${other.name}'));
          expect(otherPane, findsOneWidget);
          expect(tester.widget<VideoBookshelfPane>(otherPane).isActive, isTrue);
          expect(
            tester.widget<VideoBookshelfPane>(otherPane).search.sort,
            'dd',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await reads();
        }
      }
    },
  );
}
