import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_info/widgets/reading_history_banner.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

import '../test_helper.dart';

const title = 'とても長い日本語の作品タイトルが何度も繰り返される一冊の漫画についての長い作品名';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => objectbox.unifiedHistoryBox.removeAll());

  test('stored display page offset and unknown positions are not guessed', () {
    final record = createTestHistory('fixture:comic')
      ..chapterOrder = 1
      ..pageIndex = 23
      ..chapterTitle = title
      ..lastReadAt = DateTime.utc(2026, 11, 3, 8, 9, 45);
    final known = ComicReadingProgress(record, title);
    expect(known.chapter, 1);
    expect(known.page, 22);
    expect(known.chapterTitle, isEmpty);
    expect(
      known.label,
      t.comicInfo.readProgressChapterPage(chapter: '1', page: '22'),
    );
    record
      ..chapterOrder = 0
      ..pageIndex = 1
      ..lastReadAt = DateTime.fromMillisecondsSinceEpoch(0);
    final unknown = ComicReadingProgress(record, title);
    expect(unknown.chapter, isNull);
    expect(unknown.page, isNull);
    expect(unknown.readAt, isEmpty);
    expect(unknown.label, t.comicInfo.readHistory);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'long saved reading position remains layered and tappable $style $brightness $scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            var opened = 0;
            final record = createTestHistory('fixture:comic')
              ..source = 'fixture'
              ..comicId = 'comic'
              ..chapterOrder = 1
              ..pageIndex = 23
              ..chapterTitle = title;
            objectbox.unifiedHistoryBox.put(record);
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: TouchHoverIntentScope(child: child!),
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ComicReadingHistoryBanner(
                        source: 'fixture',
                        comicId: 'comic',
                        comicTitle: title,
                        onContinueRead: () => opened++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final progress = find.byKey(
              const ValueKey('comic-reading-history.progress'),
            );
            final time = find.byKey(
              const ValueKey('comic-reading-history.time'),
            );
            final target = find.byKey(
              const ValueKey('comic-reading-history.open'),
            );
            expect(find.text(title), findsNothing);
            expect(find.text(t.comicInfo.continueRead), findsNothing);
            expect(tester.widget<Text>(progress).maxLines, 2);
            expect(
              tester.getRect(time).top,
              greaterThan(tester.getRect(progress).bottom),
            );
            expect(
              tester.widget<Text>(time).style!.fontSize,
              lessThan(tester.widget<Text>(progress).style!.fontSize!),
            );
            expect(tester.getRect(target).right, lessThanOrEqualTo(304));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: tester.getCenter(target));
            await tester.pump();
            expect(
              tester.widget<InkWell>(target).hoverColor,
              Colors.transparent,
            );
            final down = await tester.startGesture(tester.getCenter(target));
            await tester.pump();
            expect(opened, 0);
            await down.cancel();
            await tester.pumpAndSettle();
            expect(opened, 0);
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(opened, 1);
            await mouse.removePointer();
            record
              ..pageIndex = 24
              ..lastReadAt = record.lastReadAt.add(const Duration(minutes: 1));
            objectbox.unifiedHistoryBox.put(record);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(
                t.comicInfo.readProgressChapterPage(chapter: '1', page: '23'),
              ),
              findsOneWidget,
            );
            // A missing/deleted saved record removes the card, rather than showing current time or 0.
            record.deleted = true;
            objectbox.unifiedHistoryBox.put(record);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pumpAndSettle();
            expect(find.byType(ComicReadingHistoryCard), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
            objectbox.unifiedHistoryBox.put(record..deleted = false);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  testWidgets(
    'unknown chapter retains a two-line name and absent history stays absent',
    (tester) async {
      final history = createTestHistory('a:comic')
        ..chapterOrder = 0
        ..pageIndex = 0
        ..chapterTitle = title;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: ComicReadingHistoryCard(
                progress: ComicReadingProgress(history, 'a different book'),
              ),
            ),
          ),
        ),
      );
      expect(find.text(title), findsOneWidget);
      expect(tester.widget<Text>(find.text(title)).maxLines, 2);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComicReadingHistoryBanner(
              source: 'missing',
              comicId: 'comic',
              comicTitle: title,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ComicReadingHistoryCard), findsNothing);
    },
  );
}
