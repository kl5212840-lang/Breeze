import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/bottom.dart';

void main() {
  testWidgets(
    'reader opens current range and keeps chapter identity across interleaved groups',
    (tester) async {
      final refs = [
        for (var i = 100; i >= 0; i--)
          UnifiedComicChapterRef(
            id: '$i',
            name: 'Chapter $i',
            order: i,
            groupTitle: i.isEven ? 'A' : 'B',
          ),
      ];
      UnifiedComicChapterRef? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterPickerDialog(
              refs: refs,
              initialIndex: 50,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chapter 50'), findsOneWidget);
      await tester.tap(find.text('1-50'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 100'), findsOneWidget);
      await tester.tap(find.text('Chapter 100'));
      expect(selected?.id, '100');
      await tester.tap(find.text('51-100'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 50'), findsOneWidget);
    },
  );
}
