import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

const _a = 'Tag A';
const _b = 'Tag B with a fairly long label which wraps onto another line';
final _entries = [
  for (final value in [_a, _b, for (var i = 0; i < 10; i++) 'Other $i'])
    ShelfFacetEntry(key: value, source: 'one', searchText: '', fields: {'tags': {value}}),
];

Future<void> _waitForPin(WidgetTester tester, Finder pin, bool pinned) async {
  // SharedPreferences is mocked; drain the finite save/listener microtasks
  // without advancing animation time or depending on a platform I/O delay.
  for (var i = 0; i < 12; i++) {
    await tester.pump();
    if (tester.widget<ShelfTagPinButton>(pin).pinned == pinned) return;
  }
  expect(tester.widget<ShelfTagPinButton>(pin).pinned, pinned);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final branch in ['ordinary', 'focused', 'download']) {
    for (final reduce in [false, true]) {
      testWidgets('$branch pin and unpin move briefly, retain the draft/query/focus and honor reduce=$reduce', (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final style = ValueNotifier('breeze');
        addTearDown(style.dispose);
        ShelfFacetSelection? result;
        const initial = ShelfFacetSelection(values: {'tags': {_a}});
        await tester.pumpWidget(AppInterfaceStyleScope(style: style, child: MaterialApp(
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
            disableAnimations: reduce, textScaler: const TextScaler.linear(1.4),
          ), child: child!),
          home: Builder(builder: (context) => Scaffold(body: TextButton(
            child: const Text('open'),
            onPressed: () async {
              result = branch == 'download'
                  ? await showDownloadFilterSheet(context, entries: _entries, initial: initial)
                  : await showShelfFilterSheet(context, entries: _entries, initial: initial,
                      preferenceKey: 'one', scopeLabel: '', currentFolder: null,
                      focusedLayout: branch == 'focused');
            },
          ))),
        )));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final search = find.byKey(ValueKey(branch == 'download' ? 'download-filter-search' : 'shelf-facet-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Tag');
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(find.descendant(of: search, matching: find.byType(EditableText)));
        final focus = editable.focusNode;
        expect(focus.hasFocus, isTrue);
        final prefix = branch == 'download' ? 'download-filter-option-tags-' : 'shelf-option-tags-';
        final a = find.byKey(ValueKey('$prefix$_a'));
        final b = find.byKey(ValueKey('$prefix$_b'));
        final pin = find.byKey(ValueKey('${branch == 'download' ? 'download-star-' : 'shelf-star-'}$_b'));
        await tester.ensureVisible(pin);
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(find.ancestor(of: b, matching: find.byType(Scrollable)).first);
        final pixels = scrollable.position.pixels;
        final before = tester.getTopLeft(b).dy;
        expect(before, greaterThan(tester.getTopLeft(a).dy));
        await tester.tap(pin);
        await _waitForPin(tester, pin, true);
        // forward() is requested after the reorder paint; prime the first
        // vsync timestamp before measuring an elapsed middle frame.
        await tester.pump();
        final first = tester.getTopLeft(b).dy;
        if (reduce) {
          expect(first, lessThan(before));
        } else {
          expect(first, closeTo(before, .1), reason: 'The reordered row first paints at its measured old position.');
        }
        await tester.pump(const Duration(milliseconds: 80));
        final middle = tester.getTopLeft(b).dy;
        await tester.pump(const Duration(milliseconds: 160));
        final after = tester.getTopLeft(b).dy;
        expect(after, lessThan(tester.getTopLeft(a).dy));
        if (reduce) {
          expect(middle, closeTo(after, .1));
        } else {
          expect(middle, lessThan(before));
          expect(middle, greaterThan(after), reason: 'The middle frame must be a real position between the two orders.');
        }
        expect(scrollable.position.pixels, closeTo(pixels, .1));
        expect(focus.hasFocus, isTrue);
        expect(editable.controller.text, 'Tag');
        expect(find.descendant(of: a, matching: find.byIcon(Icons.check_box_outlined)), findsOneWidget);
        expect(find.descendant(of: b, matching: find.byIcon(Icons.check_box_outline_blank)), findsOneWidget);
        expect(tester.getSize(pin).width, greaterThanOrEqualTo(44));
        await tester.tap(pin);
        await _waitForPin(tester, pin, false);
        await tester.pump();
        if (!reduce) expect(tester.getTopLeft(b).dy, closeTo(after, .1));
        await tester.pump(const Duration(milliseconds: 240));
        expect(tester.getTopLeft(b).dy, greaterThan(tester.getTopLeft(a).dy));
        final apply = find.byKey(ValueKey(branch == 'download' ? 'download-filter-apply' : 'shelf-filter-apply'));
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(result?.values['tags'], {_a});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
