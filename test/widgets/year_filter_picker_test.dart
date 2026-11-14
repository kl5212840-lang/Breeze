import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('adjacent year needs one tap, reduce motion $reduceMotion', (
      tester,
    ) async {
      var year = '2025';
      final changed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => YearFilterPicker(
                keyPrefix: 'year',
                label: '年份',
                options: const {
                  '': '全部',
                  '2026': '2026',
                  '2025': '2025',
                  '2024': '2024',
                  '2023': '2023',
                },
                selected: year,
                onSelected: (value) => update(() {
                  year = value;
                  changed.add(value);
                }),
              ),
            ),
          ),
        ),
      );
      final frame = tester.getRect(find.byKey(const ValueKey('year.wheel')));
      await tester.tap(find.byKey(const ValueKey('year.item.2024')));
      await tester.pumpAndSettle();
      expect(year, '2024');
      expect(changed, ['2024']);
      expect(tester.getRect(find.byKey(const ValueKey('year.wheel'))), frame);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('year.all')));
      await tester.pumpAndSettle();
      expect(year, '');
      expect(changed, ['2024', '']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('external reset and larger text retain the selected year', (
    tester,
  ) async {
    var year = '2024', scale = 1.0;
    late StateSetter update;
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 320,
                  child: YearFilterPicker(
                    keyPrefix: 'year',
                    label: '年份',
                    options: const {
                      '': '全部',
                      '2026': '2026',
                      '2025': '2025',
                      '2024': '2024',
                      '2023': '2023',
                    },
                    selected: year,
                    onSelected: (value) => set(() {
                      year = value;
                      changes.add(value);
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final controller = tester
        .widget<CupertinoPicker>(find.byType(CupertinoPicker))
        .scrollController!;
    expect(controller.selectedItem, 3);
    update(() => year = '2023');
    await tester.pumpAndSettle();
    expect(controller.selectedItem, 4);
    expect(changes, isEmpty);
    update(() => scale = 2);
    await tester.pumpAndSettle();
    expect(year, '2023');
    expect(controller.selectedItem, 4);
    expect(changes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
