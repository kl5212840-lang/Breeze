import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_row_actions.dart';

void main() {
  testWidgets(
    'outside taps dismiss once and navigation leaves on the first tap',
    (tester) async {
      final openRow = ValueNotifier<String?>(null);
      addTearDown(openRow.dispose);
      var bodyTaps = 0, outsideTaps = 0, navigationTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ComicFollowRowActions(
                  rowKey: 'follow',
                  openRow: openRow,
                  onUnfollow: () => fail('A tap or swipe cannot unfollow'),
                  child: InkWell(
                    onTap: () => bodyTaps++,
                    child: const SizedBox(width: double.infinity, height: 140),
                  ),
                ),
                TextButton(
                  onPressed: () => outsideTaps++,
                  child: const Text('Outside'),
                ),
                TapRegion(
                  groupId: openRow,
                  child: TextButton(
                    onPressed: () {
                      openRow.value = null;
                      navigationTaps++;
                    },
                    child: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> reveal() async {
        await tester.drag(
          find.byType(ComicFollowRowActions),
          const Offset(-130, 0),
        );
        await tester.pumpAndSettle();
        expect(openRow.value, 'follow');
      }

      await reveal();
      await tester.tap(find.text('Outside'));
      await tester.pumpAndSettle();
      expect(openRow.value, isNull);
      expect(outsideTaps, 0);
      await tester.tap(find.text('Outside'));
      expect(outsideTaps, 1);
      await reveal();
      await tester.tap(find.byType(ComicFollowRowActions));
      await tester.pumpAndSettle();
      expect(openRow.value, isNull);
      expect(bodyTaps, 0);
      await reveal();
      await tester.tap(find.text('Navigate'));
      expect(openRow.value, isNull);
      expect(navigationTaps, 1);
    },
  );

  for (final (size, brightness, direction) in [
    (const Size(320, 568), Brightness.light, TextDirection.ltr),
    (const Size(844, 390), Brightness.dark, TextDirection.rtl),
  ]) {
    testWidgets('follow commands fit at large size in $direction $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final openRow = ValueNotifier<String?>(null);
      addTearDown(openRow.dispose);
      int markCount = 0;
      int unfollowCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2.2),
                disableAnimations: true,
              ),
              child: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ComicFollowRowActions(
                      rowKey: 'fixture',
                      openRow: openRow,
                      onMarkRead: () => markCount++,
                      onUnfollow: () => unfollowCount++,
                      child: const SizedBox(
                        width: double.infinity,
                        height: 140,
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
      final row = find.byType(ComicFollowRowActions);
      final opening = direction == TextDirection.rtl ? 145.0 : -145.0;
      await tester.drag(row, Offset(opening, 0));
      await tester.pumpAndSettle();

      for (final label in [t.sourceNotices.read, t.comicFollow.unfollow]) {
        final text = find.text(label);
        final action = find.ancestor(of: text, matching: find.byType(InkWell));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(44));
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(of: text, matching: find.byType(RichText)),
              )
              .didExceedMaxLines,
          isFalse,
        );
      }
      expect(markCount, 0);
      expect(unfollowCount, 0);
      await tester.tap(find.text(t.sourceNotices.read));
      await tester.pump();
      expect(markCount, 1);
      expect(unfollowCount, 0);
      expect(find.text(t.comicFollow.unfollow), findsNothing);
    });
  }
}
