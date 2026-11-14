import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/widgets/bika_category_grid_settings.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../test_helper.dart';

const _other = '83d82c45-7da1-45ec-9663-f93887b71947';
final _info = {
  'breezeExperience': {
    'bikaExperience': {
      'version': 1,
      'appearanceKey': bikaExperienceAppearanceKey,
      'loadingArtwork': bikaExperienceArtwork,
    },
  },
};

Widget _grid(BuildContext context, String source, {bool marked = true}) =>
    const DiscoverSchemeRenderer().buildPage(
      context,
      from: source,
      scheme: {
        'body': {
          'type': 'action-grid',
          'key': 'items',
          'bikaCategoryGrid': marked,
        },
      },
      data: {
        'items': [
          for (var i = 0; i < 10; i++)
            {
              'title': '分类标题很长需要两行并且允许省略 $i',
              'cover': <String, dynamic>{},
              'action': {
                'type': 'fixture',
                'payload': {'id': i},
              },
            },
        ],
      },
      onReachBottom: () async {},
      onAction: (_) async {},
      isLoadingMore: false,
      showLoadMoreRetry: false,
      onRetryLoadMore: () {},
    );

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 50 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
}

void _expectCardsFit(WidgetTester tester) {
  final cards = find.descendant(of: find.byType(GridView), matching: find.byType(Column));
  for (var index = 0; index < cards.evaluate().length; index++) {
    final card = cards.at(index);
    final title = find.descendant(of: card, matching: find.byType(Text));
    final image = find.descendant(of: card, matching: find.byType(AspectRatio)).first;
    final imageRect = tester.getRect(image);
    expect(imageRect.width, closeTo(imageRect.height, 0.01),
      reason: 'Title accommodation must retain the full square thumbnail.');
    expect(tester.getRect(title).bottom, lessThanOrEqualTo(tester.getRect(card).bottom + 0.01),
      reason: 'Actual laid-out text must fit without clipping or hiding overflow.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    for (final source in [bikaPlusSourceId, _other]) {
      await PluginRegistryService.I.upsert(
        PluginInfo(
          uuid: source,
          version: 'fixture',
          originScript: '',
          insertedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          isEnabled: true,
          isDeleted: false,
          lastLoadSuccess: true,
          debug: false,
          getInfoJson: jsonEncode(_info),
        ),
      );
    }
  });

  for (final width in [320.0, 390.0, 768.0]) {
    for (final columns in [3, 4]) {
      testWidgets(
        '$columns columns at $width preserve missing-image cards and long labels',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          savePluginConfigValueSync(
            bikaPlusSourceId,
            bikaCategoryGridColumnsKey,
            columns,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => _grid(context, bikaPlusSourceId),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final grid = tester.widget<GridView>(find.byType(GridView));
          expect(
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            columns,
          );
          final icons = find.byIcon(Icons.auto_stories_outlined);
          expect(icons, findsNWidgets(10));
          final firstRow = tester.getTopLeft(icons.first).dy;
          expect(
            tester.getTopLeft(icons.at(columns - 1)).dy,
            closeTo(firstRow, 0.1),
          );
          expect(
            tester.getTopLeft(icons.at(columns)).dy,
            greaterThan(firstRow),
          );
          expect(tester.takeException(), isNull);
          _expectCardsFit(tester);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('four-column cards fit actual two-line typography at large text and custom line height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    savePluginConfigValueSync(bikaPlusSourceId, bikaCategoryGridColumnsKey, 4);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 14, height: 1.8),
          child: _grid(context, bikaPlusSourceId),
        ),
      ),
    ))));
    await tester.pumpAndSettle();
    _expectCardsFit(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy five-column preference displays three columns without rewriting storage', (tester) async {
    savePluginConfigValueSync(bikaPlusSourceId, bikaCategoryGridColumnsKey, 5);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => _grid(context, bikaPlusSourceId),
    ))));
    await tester.pumpAndSettle();
    expect((tester.widget<GridView>(find.byType(GridView)).gridDelegate
      as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
    expect(loadPluginConfigValue<int>(bikaPlusSourceId, bikaCategoryGridColumnsKey,
      fallback: 0), 5);
    _expectCardsFit(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'saving Plus format updates the retained category grid and persists only its source',
    (tester) async {
      savePluginConfigValueSync(_other, bikaCategoryGridColumnsKey, 3);
      await tester.pumpWidget(
        MaterialApp(
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const BikaCategoryGridSetting(source: bikaPlusSourceId),
                  Expanded(child: _grid(context, bikaPlusSourceId)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrolling = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      );
      final retained = tester.state(scrolling);
      SettingChoiceTile<int> field() => tester.widget(
        find.byKey(const ValueKey('bika-category-grid-columns')),
      );
      expect(field().value, 3);
      expect(field().items.keys, [3, 4]);
      field().onChanged(5);
      await tester.pump();
      expect(loadPluginConfigValue<int>(bikaPlusSourceId, bikaCategoryGridColumnsKey,
        fallback: 0), 0);
      field().onChanged(4);
      await _until(tester, () => field().value == 4);
      expect(
        (tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        4,
      );
      expect(tester.state(scrolling), same(retained));
      expect(
        loadPluginConfigValue<int>(
          _other,
          bikaCategoryGridColumnsKey,
          fallback: 0,
        ),
        3,
      );
      expect(
        loadPluginConfigValue<int>(
          bikaPlusSourceId,
          bikaCategoryGridColumnsKey,
          fallback: 0,
        ),
        4,
      );
      expect(tester.takeException(), isNull);
      // The successful write leaves a notice in the real root overlay.
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unrelated sources and unmarked Plus grids keep the original layout',
    (tester) async {
      for (final (source, marked) in [
        (_other, true),
        (bikaPlusSourceId, false),
      ]) {
        savePluginConfigValueSync(source, bikaCategoryGridColumnsKey, 4);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => _grid(context, source, marked: marked),
              ),
            ),
          ),
        );
        expect(
          tester.widget<GridView>(find.byType(GridView)).gridDelegate,
          isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
        );
        _expectCardsFit(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
