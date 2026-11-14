import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import '../ui_preview_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_detailed_content.dart';

void main() {
  setUpAll(loadUiPreviewFonts);
  test(
    'reading progress never repeats the work title or invents a chapter',
    () {
      expect(shelfReadingPosition('作品', '作品', 11), contains('12'));
      expect(shelfReadingPosition('作品', '第01话', 11), contains('第01话'));
      expect(shelfReadingPosition('作品', '作品', -1), isEmpty);
    },
  );

  testWidgets(
    'trailing marks stay joined and the accessible title is original',
    (tester) async {
      const title = '[Artist] Original title 【support plan ＋】';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 170,
              child: BookshelfDetailedCaption(title: title, source: '来源'),
            ),
          ),
        ),
      );
      final label = tester.widget<Text>(
        find.byKey(const ValueKey('shelf-detail.title')),
      );
      expect(label.data!.replaceAll('\u2060', ''), title);
      expect(label.data, endsWith('n\u2060 \u2060＋\u2060】'));
      expect(label.semanticsLabel, title);
    },
  );

  testWidgets('sparse records keep progress and time aligned to the cover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookshelfDetailedContent(
              cover: ColoredBox(
                key: ValueKey('sparse-cover'),
                color: Colors.grey,
              ),
              title: '作品名称',
              source: '来源',
              progress: '阅读至第12页',
              time: '上次阅读：2026-11-05 10:44',
            ),
          ),
        ),
      ),
    );
    final cover = tester.getRect(find.byKey(const ValueKey('sparse-cover')));
    final progress = tester.getRect(
      find.byKey(const ValueKey('shelf-detail.progress')),
    );
    final time = tester.getRect(
      find.byKey(const ValueKey('shelf-detail.time')),
    );
    expect(cover.size, const Size(80, 120));
    expect(time.bottom, closeTo(cover.bottom, .1));
    expect(progress.bottom, lessThan(time.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long synopsis uses at most one line in a roomy row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookshelfDetailedContent(
              cover: ColoredBox(color: Colors.grey),
              title: 'Work',
              source: 'Source',
              description:
                  'A long synopsis that would otherwise wrap through '
                  'multiple lines, even with no reading progress to display.',
            ),
          ),
        ),
      ),
    );
    final synopsis = tester.widget<Text>(
      find.byKey(const ValueKey('shelf-detail.description')),
    );
    expect(synopsis.maxLines, 1);
    expect(synopsis.overflow, TextOverflow.ellipsis);
  });

  testWidgets('cover fit updates preserve the bookshelf list and scroll', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ScrollController();
    final fit = CollectionCoverFitController.instance;
    final previous = fit.state.value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionCoverFitScope(
            child: ListView(
              key: const ValueKey('stable-shelf'),
              controller: controller,
              children: [
                Builder(
                  builder: (context) => SizedBox(
                    height: 400,
                    child: Text(
                      CollectionCoverFitScope.maybeOf(context)!.name,
                      key: const ValueKey('fit-probe'),
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.element(find.byKey(const ValueKey('stable-shelf')));
    controller.jumpTo(160);
    fit.state.value = BoxFit.cover;
    await tester.pump();
    expect(
      tester.element(find.byKey(const ValueKey('stable-shelf'))),
      same(list),
    );
    expect(controller.offset, 160);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fit-probe'))).data,
      'cover',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    fit.state.value = previous;
  });

  testWidgets('normal details align to the cover and large text grows safely', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: uiPreviewDirectory == null ? null : 'AccountPreview',
          ),
          home: RepaintBoundary(
            key: const ValueKey('shared-detail-preview'),
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SizedBox(
                  width: 320,
                  child: BookshelfDetailedContent(
                    cover: ColoredBox(
                      key: ValueKey('cover'),
                      color: Colors.grey,
                    ),
                    title: '很长的作品名称需要使用两行显示并且不能挤走进度和时间',
                    source: '来源名称',
                    metadata: '2026 · 日本 · 奇幻',
                    description: '为保护小镇而出发的旅行，伙伴们在途中揭开古老传说。',
                    progress: '观看至 12:29',
                    time: '上次观看：2026-11-02 10:44',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scale=$scale');
      await writeUiPreview(
        tester,
        const ValueKey('shared-detail-preview'),
        'shared-detail-$scale',
      );
      final cover = tester.getRect(find.byKey(const ValueKey('cover')));
      final title = tester.getRect(
        find.byKey(const ValueKey('shelf-detail.title')),
      );
      final time = tester.getRect(
        find.byKey(const ValueKey('shelf-detail.time')),
      );
      expect(title.top, cover.top);
      if (scale == 1) expect(time.bottom, closeTo(cover.bottom, .1));
      expect(find.text('暂无简介'), findsNothing);
    }
  });
}
