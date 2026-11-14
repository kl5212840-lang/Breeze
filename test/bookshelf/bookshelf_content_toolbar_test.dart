import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_actions_scope.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'bookshelf keeps four common actions and one complete menu $style ${brightness.name} $scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            final actions = <String>[];
            var sort = 'dd';
            var active = true, filterActive = false, nested = false;
            var folderLayout = false;
            late ValueChanged<bool> showNested;
            var view = BookshelfContentView.grid;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, update) {
                        showNested = (value) => update(() {
                          folderLayout = true;
                          nested = value;
                        });
                        return BookshelfActionsScope(
                          video: false,
                          mode: ShelfPageMode.favorite,
                          sort: sort,
                          onSort: (value) => update(() {
                            sort = value;
                            actions.add('sort:$value');
                          }),
                          onManageSources: () => actions.add('sources'),
                          child: Builder(
                            builder: (context) => BookshelfContentToolbar(
                              keyPrefix: 'test-shelf',
                              canRun: () => active,
                              title: folderLayout && !nested
                                  ? ''
                                  : '长标题的当前书架文件夹',
                              subtitle: folderLayout ? '' : '12 部',
                              onBack: nested
                                  ? () => actions.add('parent')
                                  : null,
                              folderRootLabel: t.bookshelf.favorite,
                              onRoot: nested ? () => actions.add('root') : null,
                              view: view,
                              privacyAction: SourceChromeIconButton(
                                key: const ValueKey('test-shelf.privacy'),
                                icon: Icons.visibility_outlined,
                                symbol: 'eye',
                                tooltip: '保护封面',
                                onPressed: () => actions.add('privacy'),
                              ),
                              showFilter: true,
                              filterActive: filterActive,
                              onFilter: () => update(() {
                                filterActive = !filterActive;
                                actions.add('filter');
                              }),
                              onToggleView: () => update(() {
                                view = view == BookshelfContentView.grid
                                    ? BookshelfContentView.list
                                    : BookshelfContentView.grid;
                                actions.add('view');
                              }),
                              onManage: () => actions.add('manage'),
                              showCreateFolder: true,
                              onCreateFolder: () => actions.add('new'),
                              arrangement: BookshelfActionsScope.forPane(
                                context,
                                video: false,
                                mode: ShelfPageMode.favorite,
                              ),
                              moreOptions: {'__help': t.common.help},
                              moreGroups: const [
                                ['__help'],
                              ],
                              onMore: actions.add,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            Finder action(String name) =>
                find.byKey(ValueKey('test-shelf.$name'));
            final ordered = [
              'privacy',
              'filter',
              'view',
              'more',
            ].map(action).toList();
            final rects = ordered.map(tester.getRect).toList();
            for (var index = 0; index < rects.length; index++) {
              final rect = rects[index];
              expect(rect.width, greaterThanOrEqualTo(44));
              expect(rect.height, greaterThanOrEqualTo(44));
              expect(rect.left, greaterThanOrEqualTo(12));
              expect(rect.right, lessThanOrEqualTo(308));
              if (index > 0) {
                expect(rects[index - 1].right, lessThanOrEqualTo(rect.left));
                expect(rects[index - 1].center.dy, closeTo(rect.center.dy, .5));
              }
            }
            expect(find.byType(NativeVideoMenu), findsOneWidget);
            expect(find.bySubtype<SourceChromeIconButton>(), findsNWidgets(3));
            expect(action('new-folder'), findsNothing);
            expect(action('manage'), findsNothing);
            for (final name in ['privacy', 'filter', 'view']) {
              // The UI event itself remains native in system style. This invokes
              // its public callback instead of sending a Flutter tap behind it.
              if (style == 'system') {
                tester
                    .widget<SourceChromeIconButton>(action(name))
                    .onPressed!();
              } else {
                await tester.tap(action(name));
              }
              await tester.pumpAndSettle();
            }
            expect(actions, ['privacy', 'filter', 'view']);
            final selectedFilter = tester.widget<SourceChromeIconButton>(
              action('filter'),
            );
            expect(selectedFilter.tooltip, t.videoFilters.active);
            expect(selectedFilter.symbol, 'line.3.horizontal.decrease');
            expect(selectedFilter.selected, isTrue);
            expect(
              find.ancestor(
                of: action('filter'),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.selected == true,
                ),
              ),
              findsOneWidget,
            );
            expect(tester.getRect(action('filter')), rects[1]);
            expect(
              tester
                  .widget<BookshelfContentToolbar>(
                    find.byType(BookshelfContentToolbar),
                  )
                  .view,
              BookshelfContentView.list,
            );
            expect(ordered.map(tester.getRect), rects);
            Future<void> choose(String value) async {
              final menu = tester.widget<NativeVideoMenu>(action('more'));
              expect(menu.hostPresentation, isTrue);
              expect(menu.options, contains(value));
              if (style == 'system') {
                menu.onSelected(value);
              } else {
                await tester.tap(action('more'));
                await tester.pumpAndSettle();
                final item = find.text(menu.options[value]!);
                await tester.ensureVisible(item);
                await tester.tap(item);
              }
              await tester.pumpAndSettle();
            }

            final initial = tester.widget<NativeVideoMenu>(action('more'));
            expect(initial.selected, '');
            expect(
              initial.optionIcons['__help']?.symbol,
              'questionmark.circle',
            );
            expect(initial.groups.last, ['__help']);
            expect(initial.options.keys, [
              '__manage',
              '__new',
              '__sort',
              '__cover_settings',
              '__help',
            ]);
            expect(initial.options['__manage'], t.bookshelf.manage);
            expect(initial.options, isNot(contains('__sources')));
            await choose('__new');
            await choose('__manage');
            await choose('__sort');
            expect(
              tester
                  .widget<ListTile>(
                    find.byKey(const ValueKey('test-shelf.sort.__sort.dd')),
                  )
                  .selected,
              isTrue,
            );
            final oldestRead = find.byKey(
              const ValueKey('test-shelf.sort.__sort.va'),
            );
            await tester.ensureVisible(oldestRead);
            await tester.tap(oldestRead);
            await tester.pumpAndSettle();
            expect(actions, [
              'privacy',
              'filter',
              'view',
              'new',
              'manage',
              'sort:va',
            ]);
            expect(
              tester.widget<NativeVideoMenu>(action('more')).options['__sort'],
              contains(t.bookshelf.ordering.oldReading),
            );
            expect(ordered.map(tester.getRect), rects);
            final retained = tester
                .widget<NativeVideoMenu>(action('more'))
                .onSelected;
            active = false;
            final before = List<String>.of(actions);
            for (final command in [
              '__manage',
              '__new',
              '__sort',
              '__cover_settings',
            ]) {
              retained(command);
            }
            await tester.pump();
            expect(
              actions,
              before,
              reason:
                  'A closing menu cannot act on a pane that has left its scope',
            );
            for (final width in [320.0, 440.0]) {
              tester.view.physicalSize = Size(width, 900);
              showNested(false);
              await tester.pumpAndSettle();
              final beforeFolder = ordered.map(tester.getRect).toList();
              showNested(true);
              await tester.pumpAndSettle();
              final parent = tester.getRect(action('back'));
              final root = tester.getRect(action('root'));
              final name = tester.getRect(find.text('长标题的当前书架文件夹'));
              expect(ordered.map(tester.getRect), beforeFolder);
              expect(parent.right, lessThanOrEqualTo(root.left));
              expect(root.right, lessThanOrEqualTo(name.left));
              expect(root.width, greaterThanOrEqualTo(44));
              expect(root.height, greaterThanOrEqualTo(44));
              if (width == 440 && scale == 1.0) {
                expect(name.right, lessThanOrEqualTo(beforeFolder.first.left));
                expect(
                  parent.center.dy,
                  closeTo(beforeFolder.first.center.dy, .5),
                );
              } else {
                expect(
                  parent.top,
                  greaterThanOrEqualTo(beforeFolder.first.bottom),
                );
              }
              final rootButton = tester.widget<TextButton>(action('root'));
              expect(
                (rootButton.child as Text).semanticsLabel,
                t.bookshelf.returnToRoot,
              );
            }
            final parent = tester.widget<SourceChromeIconButton>(
              action('back'),
            );
            expect(parent.tooltip, t.bookshelf.returnToParent);
            if (style == 'system') {
              parent.onPressed!();
            } else {
              await tester.tap(action('back'));
            }
            await tester.tap(action('root'));
            await tester.pumpAndSettle();
            expect(actions, [...before, 'parent', 'root']);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
