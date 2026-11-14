import 'package:flutter/services.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 740), const Size(390, 740), const Size(740, 320)]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('JM focused draft $size/$scale/$brightness', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          ShelfFacetSelection? result;
          final entries = List.generate(100, (index) => ShelfFacetEntry(
            key: '$index', source: 'jm', searchText: 'work $index',
            fields: {'tags': {'tag $index long public label'}, 'author': {'author ${index % 3}'}}));
          await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale)), child: child!),
            home: Builder(builder: (context) => Scaffold(body: TextButton(
              child: const Text('open'), onPressed: () async {
                result = await showShelfFilterSheet(context, entries: entries,
                  initial: const ShelfFacetSelection(), preferenceKey: 'jm-focused',
                  scopeLabel: 'Not a visible heading', currentFolder: null,
                  hierarchical: false, focusedLayout: true);
              },
            )))));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('Not a visible heading'), findsNothing);
          expect(find.byKey(const ValueKey('shelf-scope-all-label')), findsNothing);
          expect(find.byKey(const ValueKey('shelf-facet-year')), findsNothing);
          expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
          final author = find.byKey(const ValueKey('shelf-facet-author'));
          await tester.ensureVisible(author);
          await tester.tap(author);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('shelf-facet-search')), findsOneWidget);
          final tags = find.byKey(const ValueKey('shelf-facet-tags'));
          await tester.ensureVisible(tags);
          await tester.tap(tags);
          await tester.pumpAndSettle();
          final search = find.byKey(const ValueKey('shelf-facet-search'));
          await tester.ensureVisible(search);
          await tester.enterText(search, 'tag 0 ');
          await tester.pumpAndSettle();
          final option = find.byKey(const ValueKey('shelf-option-tags-tag 0 long public label'));
          await tester.ensureVisible(option);
          expect(tester.getSize(option).height, greaterThanOrEqualTo(44));
          await tester.tap(option);
          await tester.pumpAndSettle();
          final apply = find.byKey(const ValueKey('shelf-filter-apply'));
          await tester.ensureVisible(apply);
          await tester.pumpAndSettle();
          expect(find.text(t.bookshelf.facets.resultTitle(count: 1)), findsOneWidget);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(result?.values['tags'], {'tag 0 long public label'});
          expect(result?.applied, isTrue);
          result = null;
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
          await tester.tap(find.byKey(const ValueKey('shelf-focused-cancel')));
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }, variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));
      }
    }
  }
  testWidgets('focused single dimension keeps selected zero result removable', (tester) async {
    ShelfFacetSelection? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(child: const Text('open'), onPressed: () async {
        result = await showShelfFilterSheet(context,
          entries: const [ShelfFacetEntry(key: 'one', source: 'jm', searchText: '',
            fields: {'tags': {'available'}})],
          initial: const ShelfFacetSelection(values: {'tags': {'missing'}}),
          preferenceKey: 'jm-focused', scopeLabel: 'scope', currentFolder: null,
          hierarchical: false, focusedLayout: true);
      }),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text(t.bookshelf.facets.resultTitle(count: 0)), findsOneWidget);
    final missing = find.byKey(const ValueKey('shelf-option-tags-missing'));
    await tester.ensureVisible(missing);
    expect(tester.widget<TextButton>(missing).onPressed, isNotNull);
    await tester.tap(missing);
    await tester.pumpAndSettle();
    expect(find.text(t.bookshelf.facets.resultTitle(count: 1)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
    await tester.pumpAndSettle();
    expect(result?.values['tags'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JM facets use shared material and keep panel height when switching dimensions', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger, channels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') { final args = call.arguments as Map; final channel = MethodChannel('${args['viewType']}.${args['id']}'); channels.add(channel); messenger.setMockMethodCallHandler(channel, (_) async => null); }
      return null;
    });
    addTearDown(() { messenger.setMockMethodCallHandler(SystemChannels.platform_views, null); for (final channel in channels) messenger.setMockMethodCallHandler(channel, null); });
    final appearance = ValueNotifier('system'); addTearDown(appearance.dispose);
    for (final style in ['system', 'breeze']) {
      appearance.value = style;
      ShelfFacetSelection? result;
      await tester.pumpWidget(AppInterfaceStyleScope(style: appearance, child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(child: const Text('open material'), onPressed: () async {
        result = await showShelfFilterSheet(context, entries: const [ShelfFacetEntry(key: 'one', source: 'jm', searchText: '', fields: {'tags': {'标签甲'}, 'category': {'分类甲'}, 'author': {'作者甲'}})], initial: const ShelfFacetSelection(), preferenceKey: 'jm-native-short', scopeLabel: 'scope', currentFolder: null, hierarchical: false, focusedLayout: true, nativeMaterial: true);
      }))))));
      await tester.tap(find.text('open material')); await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate((widget) => widget is NativeMaterialSurface && widget.topOnly);
      expect(surface, findsOneWidget);
      expect(tester.widget<NativeMaterialSurface>(surface).systemStyle, style == 'system');
      final panelHeight = tester.getSize(surface).height;
      expect(panelHeight, lessThanOrEqualTo(600.01), reason: 'The panel stays bounded by its host, independent of option counts');
      for (final dimension in ['tags', 'category', 'author']) expect(find.byKey(ValueKey('shelf-facet-$dimension')), findsOneWidget);
      expect(find.byKey(const ValueKey('shelf-facet-year')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-facet-category'))); await tester.pumpAndSettle();
      expect(tester.getSize(surface).height, closeTo(panelHeight, .1));
      expect(find.byKey(const ValueKey('shelf-option-category-分类甲')), findsOneWidget);
      expect(find.byKey(const ValueKey('shelf-option-tags-分类甲')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-option-category-分类甲')));
      await tester.tap(find.byKey(const ValueKey('shelf-filter-apply'))); await tester.pumpAndSettle();
      expect(result?.values['category'], {'分类甲'}); expect(result?.values['tags'] ?? <String>{}, isEmpty);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

}
