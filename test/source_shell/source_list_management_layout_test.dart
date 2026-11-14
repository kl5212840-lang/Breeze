import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final compact in [false, true]) {
        testWidgets(
          'shared record management aligns and wraps $style $brightness compact=$compact',
          (tester) async {
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            final channels = <MethodChannel>[];
            final controls = <String, MethodChannel>{};
            messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
              call,
            ) async {
              if (call.method == 'create') {
                final args = call.arguments as Map;
                final channel = MethodChannel(
                  '${args['viewType']}.${args['id']}',
                );
                channels.add(channel);
                final params = args['params'];
                if (params is Uint8List) {
                  final control = const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(params),
                  );
                  if (control is Map && control['tooltip'] is String) {
                    controls[control['tooltip'] as String] = channel;
                  }
                }
                messenger.setMockMethodCallHandler(channel, (_) async => null);
              }
              return null;
            });
            addTearDown(() {
              messenger.setMockMethodCallHandler(
                SystemChannels.platform_views,
                null,
              );
              for (final channel in channels) {
                messenger.setMockMethodCallHandler(channel, null);
              }
            });
            await tester.binding.setSurfaceSize(Size(compact ? 320 : 420, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            final blocked = <String>{};
            var sort = 'new', detailed = true;
            late StateSetter update;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    platform: TargetPlatform.iOS,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return SourceListFilterBar(
                          categories: const ['短篇', '全彩', '长标签用于横向滚动'],
                          blockedCategories: blocked,
                          onCategoryTap: (value) =>
                              setState(() => blocked.add(value)),
                          onClearBlockedCategories: () =>
                              setState(blocked.clear),
                          sortValue: sort,
                          sortOptions: const {'new': '最新', 'old': '最早'},
                          onSortChanged: (value) =>
                              setState(() => sort = value),
                          detailedView: detailed,
                          onViewChanged: (value) =>
                              setState(() => detailed = value),
                          viewToggleKey: const ValueKey('fixture-view-toggle'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final actions = tester.getRect(
              find.byKey(const ValueKey('source-list.manage-actions')),
            );
            final sortRect = tester.getRect(
              find.byKey(const ValueKey('source-list.sort')),
            );
            final view = tester.getRect(
              find.byKey(const ValueKey('fixture-view-toggle')),
            );
            expect(view.size, const Size(44, 44));
            expect(sortRect.height, greaterThanOrEqualTo(44));
            expect(sortRect.center.dy, closeTo(view.center.dy, .5));
            expect(actions.right, lessThanOrEqualTo((compact ? 320 : 420) - 8));
            final chip = tester.getRect(
              find.byKey(const ValueKey('category-短篇')),
            );
            expect(chip.height, greaterThanOrEqualTo(44));
            expect(
              chip.bottom,
              lessThanOrEqualTo(
                tester
                    .getRect(
                      find.byKey(const ValueKey('source-list.management')),
                    )
                    .top,
              ),
            );
            expect(
              find.byKey(const ValueKey('source-list.category-hint')),
              findsNothing,
              reason:
                  'The compact category strip explains blocking in its tooltips',
            );
            tester
                .widget<SourceChoiceMenu<String>>(
                  find.byKey(const ValueKey('source-list.sort')),
                )
                .onChanged!('old');
            tester
                .widget<SourceListViewToggle>(
                  find.byKey(const ValueKey('fixture-view-toggle')),
                )
                .onChanged(false);
            await tester.pumpAndSettle();
            expect(sort, 'old');
            expect(detailed, isFalse);
            await tester.tap(find.byKey(const ValueKey('category-短篇')));
            await tester.pumpAndSettle();
            expect(blocked, {'短篇'});
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('source-list.clear-blocked')),
                  )
                  .height,
              greaterThanOrEqualTo(44),
            );
            final clear = find.byKey(
              const ValueKey('source-list.clear-blocked'),
            );
            if (style == 'system') {
              final tooltip = tester
                  .widget<SourceChromeIconButton>(clear)
                  .tooltip;
              final channel = controls[tooltip];
              expect(channel, isNotNull);
              await messenger.handlePlatformMessage(
                channel!.name,
                const StandardMethodCodec().encodeMethodCall(
                  const MethodCall('press'),
                ),
                (_) {},
              );
            } else {
              await tester.tap(clear);
            }
            await tester.pumpAndSettle();
            expect(blocked, isEmpty);
            update(() {});
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
