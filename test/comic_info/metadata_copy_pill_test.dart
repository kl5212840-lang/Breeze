import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/particulars.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets(
    'metadata copy target cancels gestures and copies once per long press',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ComicMetadataCopyPill(
                item: ComicInfoActionItem(name: '标签', onLongPress: '  原始内容  '),
              ),
            ),
          ),
        ),
      );
      final target = find.byType(InkWell);
      final bounds = tester.getRect(target);
      expect(bounds.height, greaterThanOrEqualTo(44));
      expect(bounds.width, greaterThanOrEqualTo(44));

      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(copied, isEmpty);

      final moved = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 100));
      await moved.moveBy(const Offset(150, 0));
      await tester.pump(const Duration(seconds: 1));
      await moved.up();
      await tester.pumpAndSettle();
      expect(copied, isEmpty);

      final cancelled = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 100));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(copied, isEmpty);

      final held = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(seconds: 1));
      expect(copied, ['原始内容']);
      await tester.pump(const Duration(seconds: 1));
      await held.up();
      await tester.pumpAndSettle();
      expect(copied, ['原始内容']);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComicMetadataCopyPill(
              item: ComicInfoActionItem(name: '回退标签'),
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(ComicMetadataCopyPill));
      await tester.pumpAndSettle();
      expect(copied, ['原始内容', '回退标签']);
      expect(tester.takeException(), isNull);
    },
  );
}
