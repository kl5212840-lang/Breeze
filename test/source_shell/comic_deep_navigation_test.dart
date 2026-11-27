import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/app_bar.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_bar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';

void main() {
  testWidgets(
    'reader exit stays available alongside fullscreen and hides with chrome',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reader = ReaderCubit();
      final settings = GlobalSettingCubit();
      addTearDown(reader.close);
      addTearDown(settings.close);
      var fullscreenToggles = 0;

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ReaderCubit>.value(value: reader),
            BlocProvider<GlobalSettingCubit>.value(value: settings),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Stack(
                          children: [
                            const SizedBox.expand(),
                            ComicReadAppBar(
                              title:
                                  'A long comic chapter title that must leave actions usable',
                              changePageIndex: (_) {},
                              onToggleFullscreen: () => fullscreenToggles++,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Discover'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(t.reader.enterFullscreen));
      expect(fullscreenToggles, 1);

      reader.updateMenuVisible(visible: false);
      await tester.pumpAndSettle();
      expect(find.byType(SourceMoreButton).hitTestable(), findsNothing);
      reader.updateMenuVisible(visible: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SourceMoreButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.exitPlugin));
      await tester.pumpAndSettle();
      expect(find.text('Discover'), findsOneWidget);
      expect(find.byType(ComicReadAppBar), findsNothing);
    },
  );

  testWidgets(
    'narrow keyword results keep the query and ordinary back usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = SearchCubit(
        const SearchStates(searchKeyword: 'A long search phrase'),
      );
      addTearDown(search.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<SearchCubit>.value(
                      value: search,
                      child: const Scaffold(
                        appBar: SearchResultBar(searchEvent: SearchEvent()),
                      ),
                    ),
                  ),
                ),
                child: const Text('Search origin'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Search origin'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('A long search phrase'), findsOneWidget);
      expect(find.byTooltip(t.common.search).hitTestable(), findsOneWidget);
      expect(find.byType(SourceMoreButton), findsNothing);

      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Search origin'), findsOneWidget);
      expect(find.byType(SearchResultBar), findsNothing);
      expect(search.state.searchKeyword, 'A long search phrase');
    },
  );
}
