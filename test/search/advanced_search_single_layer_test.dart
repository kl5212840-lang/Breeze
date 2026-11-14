import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';

void main() {
  test('favorite eligibility follows dimension identity rather than size', () {
    PluginChoiceField field(String key, {String? semantic}) =>
        PluginChoiceField(
          key: key,
          label: 'Label',
          kind: 'choice',
          options: const [],
          semantic: semantic,
        );
    for (final key in [
      'order',
      'sortBy',
      'category',
      'language',
      'week',
      'year',
    ]) {
      expect(field(key).supportsFavorites, isFalse);
    }
    for (final key in ['tags', 'author', 'theme']) {
      expect(field(key).supportsFavorites, isTrue);
    }
    expect(field('custom', semantic: 'tags').supportsFavorites, isTrue);
    expect(field('tags', semantic: 'language').supportsFavorites, isFalse);
  });

  testWidgets('multi selection has one draft and cancel leaves inputs intact', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.enUs);
    final original = <String, dynamic>{
      'categories': ['A'],
    };
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => PluginAdvancedSearchDialog(
                    initialSort: 1,
                    scheme: PluginAdvancedSearchScheme(
                      fields: const [
                        {
                          'key': 'categories',
                          'kind': 'multiChoice',
                          'label': 'Categories',
                          'options': [
                            {'label': 'A', 'value': 'A'},
                            {'label': 'B', 'value': 'B'},
                          ],
                        },
                      ],
                      values: original,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(original['categories'], ['A']);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(original['categories'], ['A']);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.tap(find.text(t.common.apply));
    await tester.pumpAndSettle();
    expect(result?['categories'], ['A', 'B']);
    expect(original['categories'], ['A']);
  });
}
