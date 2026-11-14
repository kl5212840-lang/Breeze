import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

const entries = [
  ShelfFacetEntry(key: 'a', source: 'one', searchText: '', fields: {'tags': {'A'}}),
  ShelfFacetEntry(key: 'b', source: 'one', searchText: '', fields: {'tags': {'B'}}),
  ShelfFacetEntry(key: 'unknown', source: 'one', searchText: '', fields: {}),
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('focused plugin filter pins real tags immediately, keeps Unknown unpinnable and Cancel leaves the filter unchanged', (tester) async {
    final style = ValueNotifier('breeze'); addTearDown(style.dispose);
    ShelfFacetSelection? result;
    await tester.pumpWidget(AppInterfaceStyleScope(style: style, child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async { result = await showShelfFilterSheet(context, entries: entries,
        initial: const ShelfFacetSelection(), preferenceKey: 'source-results|one', scopeLabel: '', currentFolder: null, focusedLayout: true); }, child: const Text('open'),
    ))))));
    await tester.tap(find.text('open')); await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shelf-option-tags-__breeze_unknown__')), findsNothing);
    expect(find.byKey(const ValueKey('shelf-star-__breeze_unknown__')), findsNothing);
    final pin = find.byKey(const ValueKey('shelf-star-B'));
    expect(tester.getSize(pin).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(pin).height, greaterThanOrEqualTo(44));
    expect(tester.widget<IconButton>(find.descendant(of: pin, matching: find.byType(IconButton))).iconSize, 22);
    await tester.tap(pin); await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('shelf-option-tags-B'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('shelf-option-tags-A'))).dy));
    await tester.tap(find.byKey(const ValueKey('shelf-focused-cancel'))); await tester.pumpAndSettle();
    expect(result, isNull); expect(await ShelfFacetPreferences.load('source-results|one'), {'B'});
    expect(await ShelfFacetPreferences.load('source-results|two'), isEmpty);
  });
  testWidgets('download filter uses the same pins and keeps a damaged preference intact until a reliable retry', (tester) async {
    const scope = 'download|video|one';
    final key = 'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(scope)}';
    final prefs = await SharedPreferences.getInstance(); await prefs.setString(key, '{broken');
    final style = ValueNotifier('breeze'); addTearDown(style.dispose);
    await tester.pumpWidget(AppInterfaceStyleScope(style: style, child: MaterialApp(home: Scaffold(body: DownloadFilterSheet(
      entries: entries, initial: const ShelfFacetSelection(), preferenceKey: scope,
    )))));
    await tester.pumpAndSettle();
    expect(find.text(t.bookshelf.facets.loadFavoritesFailed), findsOneWidget);
    expect(tester.widget<ShelfTagPinButton>(find.byKey(const ValueKey('download-star-B'))).onPressed, isNull);
    expect(prefs.getString(key), '{broken');
    await prefs.setString(key, '["B"]');
    await tester.tap(find.text(t.common.retry)); await tester.pumpAndSettle();
    expect(tester.widget<ShelfTagPinButton>(find.byKey(const ValueKey('download-star-B'))).pinned, isTrue);
    await tester.tap(find.byKey(const ValueKey('download-star-A'))); await tester.pumpAndSettle();
    expect(await ShelfFacetPreferences.load(scope), {'A', 'B'});
    expect(await ShelfFacetPreferences.load('download|video|two'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
  });
}
