import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';

PluginChoiceOption _option(String value, String label) => PluginChoiceOption(
  label: label,
  value: value,
  result: {'selected': value},
  children: const [],
);

PluginListFilterSchema _scheme({bool longLabel = false}) =>
    PluginListFilterSchema(
      title: '筛选漫画',
      fields: [
        PluginChoiceField(
          key: 'theme',
          label: '题材',
          kind: 'choice',
          options: [
            _option('', '全部题材'),
            for (var i = 1; i < 40; i++)
              _option('$i', longLabel ? '题材$i 很长的题材名称用于检查窄屏和大字换行' : '题材$i'),
          ],
        ),
        PluginChoiceField(
          key: 'region',
          label: '地区',
          kind: 'choice',
          options: [
            _option('0', '日本'),
            _option('', '全部地区'),
            _option('1', '韩国'),
          ],
        ),
        PluginChoiceField(
          key: 'ordering',
          label: '排序',
          kind: 'choice',
          options: [_option('-updated', '最近更新'), _option('-popular', '热度最高')],
        ),
      ],
    );

Future<void> _mount(
  WidgetTester tester, {
  required Map<String, String> initial,
  required void Function(Map<String, String>?) onResult,
  bool longLabel = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              await showModalBottomSheet<Map<String, String>>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => PluginListFilterDialog(
                  scheme: _scheme(longLabel: longLabel),
                  initialSelections: initial,
                  defaultSelections: const {
                    'theme': '',
                    'region': '',
                    'ordering': '-updated',
                  },
                ),
              ),
            ),
            child: const Text('Open filters'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open filters'));
  await tester.pumpAndSettle();
}

void main() {
  test('an explicit empty All option wins over a nonempty default', () {
    final schema = _scheme();
    final resolved = schema.resolve(
      requestedSelections: const {'region': ''},
      defaultSelections: const {'region': '1'},
    );
    expect(resolved.selections['region'], '');
    expect(schema.fields[1].findPathByValue('')?.single.label, '全部地区');
    expect(schema.fields[1].findOptionByValue(null), isNull);
    expect(schema.fields[1].resolveOption(fallbackValue: '1')?.value, '1');
  });

  test('a nested All option retains its parent path', () {
    final field = PluginChoiceField(
      key: 'region',
      label: '',
      kind: 'choice',
      options: [
        PluginChoiceOption(
          label: '地区',
          value: 'root',
          result: const {},
          children: [_option('jp', '日本'), _option('', '全部地区')],
        ),
      ],
    );
    expect(field.findPathByValue('')?.map((option) => option.value), [
      'root',
      '',
    ]);
    expect(field.buildVisibleLevels('').single.pathIndex, 1);
  });

  testWidgets(
    'short fields stay first and a folded selected theme stays visible',
    (tester) async {
      final initial = {'theme': '28', 'region': '1', 'ordering': '-popular'};
      Map<String, String>? result;
      await _mount(
        tester,
        initial: initial,
        onResult: (value) => result = value,
      );
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('plugin-filter-fields')),
      );
      final fields = list.childrenDelegate as SliverChildListDelegate;
      expect(fields.children.map((field) => field.key), [
        const ValueKey('filter-field-region'),
        const ValueKey('filter-field-ordering'),
        const ValueKey('filter-field-theme'),
      ]);
      final selected = find.byKey(const ValueKey('filter-option-theme-0-28'));
      expect(tester.widget<ChoiceChip>(selected).selected, isTrue);
      expect(find.text('题材39'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('filter-search-theme-0')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('filter-search-theme-0')),
        '题材39',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('filter-option-theme-0-39')),
      );
      await tester.tap(find.byKey(const ValueKey('filter-option-theme-0-39')));
      await tester.pump();
      expect(
        initial['theme'],
        '28',
        reason: 'editing a draft must not mutate the caller',
      );
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect(result, {'theme': '39', 'region': '1', 'ordering': '-popular'});
    },
  );

  testWidgets(
    'closing discards the draft and reset returns valid empty All defaults',
    (tester) async {
      final initial = {'theme': '28', 'region': '1', 'ordering': '-popular'};
      Map<String, String>? result;
      await _mount(
        tester,
        initial: initial,
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('日本'));
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(initial['region'], '1');
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.reset));
      await tester.pump();
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect(result, {'theme': '', 'region': '', 'ordering': '-updated'});
      expect(initial, {'theme': '28', 'region': '1', 'ordering': '-popular'});
    },
  );

  testWidgets(
    'a phone sheet keeps large labels and keyboard actions scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _mount(
        tester,
        initial: {'theme': '28', 'region': '', 'ordering': '-updated'},
        onResult: (_) {},
        longLabel: true,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(PluginListFilterDialog));
      expect(sheet.left, 0);
      expect(sheet.right, 320);
      final search = find.byKey(const ValueKey('filter-search-theme-0'));
      await tester.ensureVisible(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'does not match');
      await tester.pumpAndSettle();
      expect(find.text(t.comicList.noMatchingOptions), findsOneWidget);
      expect(
        tester
            .getRect(find.widgetWithText(FilledButton, t.common.apply))
            .bottom,
        lessThanOrEqualTo(400),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
