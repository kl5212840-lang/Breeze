import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';

JmCollectionNavigationActions navigation() => JmCollectionNavigationActions(
  onSearch: () {},
  options: const {'sort.new': '最新', 'view.grid': '网格'},
  groups: const [
    ['sort.new'],
    ['view.grid'],
  ],
  onSelected: (_) {},
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'JM server total stays stable while its first or later pages arrive',
    () {
      for (final loaded in [20, 60, 180]) {
        expect(
          jmCollectionCountLabel(
            complete: false,
            shown: loaded,
            loaded: loaded,
            knownTotal: 267,
          ),
          t.videoLibrary.results(count: 267),
        );
      }
      expect(
        jmCollectionCountLabel(
          complete: true,
          shown: 3,
          loaded: 267,
          knownTotal: 267,
        ),
        t.videoLibrary.results(count: 3),
      );
    },
  );
  testWidgets(
    'many official folders are searched in a bounded selector without committing on cancel',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final selected = <String>[];
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: JmCollectionFolderChoice(
                  label: '收藏夹',
                  value: '0',
                  options: {for (var i = 0; i < 250; i++) '$i': '文件夹 $i'},
                  onChanged: selected.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('文件夹 0'));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('jm-folder.options'));
      expect(tester.getSize(list).height, lessThan(500));
      expect(find.byType(SearchFieldSurface), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('jm-folder.search')),
        '249',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '文件夹 249'), findsOneWidget);
      expect(find.widgetWithText(ListTile, '文件夹 1'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, '文件夹 249'));
      await tester.pumpAndSettle();
      expect(selected, ['249']);
      await tester.tap(find.text('文件夹 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(selected, ['249']);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'only the current source record owner can clear its borrowed AppBar actions',
    () {
      final controller = JmCollectionHeaderController();
      final first = Object(), second = Object();
      final old = navigation(), current = navigation();
      controller.publish(first, old);
      expect(controller.actions, same(old));
      controller.publish(second, current);
      controller.release(first);
      expect(controller.actions, same(current));
      controller.release(second);
      expect(controller.actions, isNull);
      controller.dispose();
      controller.release(first);
      controller.publish(first, old);
      expect(controller.actions, isNull);
    },
  );
  testWidgets(
    'record actions retain their positions when the destination publishes callbacks',
    (tester) async {
      final controller = JmCollectionHeaderController();
      final style = ValueNotifier('breeze');
      addTearDown(controller.dispose);
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('最近观看'),
                actions: [JmCollectionHeaderActions(controller: controller)],
              ),
            ),
          ),
        ),
      );
      final keys = ['jm-record.search', 'jm-record.sort', 'jm-record.more'];
      final before = {
        for (final key in keys)
          key: tester.getRect(find.byKey(ValueKey(key))),
      };
      controller.publish(Object(), navigation());
      await tester.pumpAndSettle();
      for (final key in keys) {
        expect(tester.getRect(find.byKey(ValueKey(key))), before[key]);
        expect(before[key]!.size, const Size(44, 44));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'three JM record destinations use icon-only More and a stable trailing filter',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      for (final title in ['站点收藏', '已收藏', '最近观看']) {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: Text(title), actions: [navigation()]),
                body: JmCollectionResultsRow(
                  countLabel: '267 部作品',
                  scope: title == '站点收藏'
                      ? SourceChoiceMenu<String>(
                          label: '默认',
                          tooltip: '收藏夹',
                          value: '',
                          options: const {'': '默认', '9': '其他收藏夹'},
                          onChanged: (_) {},
                        )
                      : null,
                  filterButton: IconButton(
                    key: const ValueKey('filter'),
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list_rounded),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final more = tester.widget<NativeVideoMenu>(
          find.byKey(const ValueKey('jm-collection.more')),
        );
        final sort = tester.widget<NativeVideoMenu>(
          find.byKey(const ValueKey('jm-collection.sort')),
        );
        expect(sort.options, {'sort.new': '最新'});
        expect(more.options.keys, isNot(contains('sort.new')));
        expect(more.optionIcons.keys, containsAll(more.options.keys));
        expect(sort.optionIcons.keys, containsAll(sort.options.keys));
        expect(
          tester.getSize(find.byKey(const ValueKey('jm-collection.sort'))),
          const Size(44, 44),
        );
        expect(more.label, isEmpty);
        expect(more.symbol, 'ellipsis');
        expect(more.selectionIndicator, isFalse);
        expect(
          tester.getSize(find.byKey(const ValueKey('jm-collection.more'))),
          const Size(44, 44),
        );
        final filter = tester.getRect(find.byKey(const ValueKey('filter')));
        expect(filter.width, 44);
        expect(filter.height, 44);
        expect(filter.right, 308);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(JmCollectionNavigationActions),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
