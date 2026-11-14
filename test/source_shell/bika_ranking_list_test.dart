import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_list/view/bika_ranking_list.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

void main() {
  setUpAll(() async {
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
    objectbox.userSettingBox.put(UserSetting());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('ranking shows order, author, category and period count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = UnifiedComicListItem.fromJson({
      'source': 'e9f18928-3ba8-4d86-a12e-b53a62f47933',
      'id': 'ranked-1',
      'title': '榜单作品',
      'subtitle': '',
      'finished': false,
      'likesCount': 8,
      'viewsCount': 999999,
      'updatedAt': '',
      'cover': {
        'id': 'ranked-1',
        'url': '',
        'path': '',
        'extern': <String, dynamic>{},
      },
      'metadata': [
        {
          'type': 'author',
          'name': '作者',
          'value': ['作者甲'],
        },
        {
          'type': 'categories',
          'name': '分类',
          'value': ['短篇'],
        },
      ],
      'raw': {'leaderboardCount': 39682},
      'extern': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BikaRankingList(
            entries: [entry],
            hasReachedMax: true,
            isLoadingMore: false,
            loadMoreFailed: false,
            onRetryLoadMore: () {},
            onLoadMore: () {},
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('榜单作品'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.text('短篇'), findsOneWidget);
    expect(find.text('指名次数  39682'), findsOneWidget);
    expect(find.textContaining('999999'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));

    tester.view.physicalSize = const Size(960, 2000);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: Scaffold(
          body: BikaRankingList(
            entries: [
              entry.copyWith(title: '这是一部标题非常长并且需要在较大字体下仍能完整布局的排行榜漫画作品'),
            ],
            hasReachedMax: true,
            isLoadingMore: false,
            loadMoreFailed: false,
            onRetryLoadMore: () {},
            onLoadMore: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'loaded filter preserves original source rank $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(320, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final channels = <MethodChannel>[];
          final byTooltip = <String, MethodChannel>{};
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (update) async {
                if (update.method == 'update' && update.arguments is Map) {
                  final tooltip = (update.arguments as Map)['tooltip'];
                  if (tooltip is String) byTooltip[tooltip] = channel;
                }
                return null;
              });
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in channels)
              messenger.setMockMethodCallHandler(channel, null);
          });
          UnifiedComicListItem entry(String id, String category) =>
              UnifiedComicListItem.fromJson({
                'source': 'e9f18928-3ba8-4d86-a12e-b53a62f47933',
                'id': id,
                'title': '榜单作品$id',
                'subtitle': '',
                'finished': false,
                'likesCount': 0,
                'viewsCount': 0,
                'updatedAt': '',
                'cover': {
                  'id': id,
                  'url': '',
                  'path': '',
                  'extern': <String, dynamic>{},
                },
                'metadata': [
                  {
                    'type': 'categories',
                    'name': '分类',
                    'value': [category],
                  },
                ],
                'raw': {'leaderboardCount': 300},
                'extern': <String, dynamic>{},
              });
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final textScale = ValueNotifier(2.0);
          addTearDown(textScale.dispose);
          var loads = 0;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  platform: TargetPlatform.iOS,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  builder: (context, scale, _) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                      key: const ValueKey('bika-ranking-preview'),
                      child: child!,
                    ),
                  ),
                ),
                home: Scaffold(
                  body: BikaRankingList(
                    entries: [
                      for (var rank = 1; rank <= 17; rank++)
                        entry('$rank', rank == 9 || rank == 17 ? '短篇' : '长篇'),
                    ],
                    hasReachedMax: false,
                    isLoadingMore: false,
                    loadMoreFailed: false,
                    onRetryLoadMore: () => loads++,
                    onLoadMore: () => loads++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('bika-ranking-preview'),
            'bika-ranking-$style-${brightness.name}-large',
          );
          textScale.value = 1;
          await tester.binding.setSurfaceSize(const Size(430, 932));
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('bika-ranking-preview'),
            'bika-ranking-$style-${brightness.name}-standard',
          );
          textScale.value = 2;
          await tester.binding.setSurfaceSize(const Size(320, 1000));
          await tester.pumpAndSettle();
          Future<void> openFilter() async {
            final control = find.byKey(const ValueKey('bika-ranking.filters'));
            final native = find.descendant(
              of: control,
              matching: find.byType(UiKitView),
            );
            if (native.evaluate().isEmpty) {
              await tester.tap(control);
            } else {
              final tooltip =
                  (tester.widget<UiKitView>(native).creationParams
                      as Map)['tooltip'];
              await messenger.handlePlatformMessage(
                byTooltip[tooltip]!.name,
                const StandardMethodCodec().encodeMethodCall(
                  const MethodCall('press'),
                ),
                (_) {},
              );
            }
            await tester.pumpAndSettle();
          }

          await openFilter();
          expect(find.byKey(const ValueKey('shelf-facet-year')), findsNothing);
          expect(
            find.byKey(const ValueKey('shelf-facet-category')),
            findsNothing,
            reason: 'Category is the only dimension and opens directly.',
          );
          await tester.tap(
            find.byKey(const ValueKey('shelf-option-category-短篇')),
          );
          await tester.pumpAndSettle();
          Navigator.of(
            tester.element(find.byKey(const ValueKey('shelf-filter-apply'))),
          ).pop();
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.2')),
            findsOneWidget,
          );
          await openFilter();
          await tester.tap(
            find.byKey(const ValueKey('shelf-option-category-短篇')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.1')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.9')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.17')),
            findsOneWidget,
          );
          final firstTitle = tester.getTopLeft(find.text('榜单作品9'));
          final secondTitle = tester.getTopLeft(find.text('榜单作品17'));
          expect(firstTitle.dx, secondTitle.dx);
          final firstRank = tester.getSize(
            find.byKey(const ValueKey('bika-ranking.rank.9')),
          );
          final secondRank = tester.getSize(
            find.byKey(const ValueKey('bika-ranking.rank.17')),
          );
          expect(firstRank.width, secondRank.width);
          expect(
            find.text(t.bikaRanking.loadedScope(loaded: 17, shown: 2)),
            findsOneWidget,
          );
          final filter = find.byKey(const ValueKey('bika-ranking.filters'));
          expect(
            tester.widget<SourceFilterIconButton>(filter).selected,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('bika-ranking.reset')),
            findsNothing,
          );
          expect(loads, 0);
          await tester.tap(find.text(t.oldHome.loadMore));
          expect(loads, 1);
          await openFilter();
          await tester.tap(find.byKey(const ValueKey('shelf-filter-reset')));
          await tester.tap(find.byKey(const ValueKey('shelf-filter-apply')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<SourceFilterIconButton>(filter).selected,
            isFalse,
          );
          expect(
            find.byKey(const ValueKey('bika-ranking.rank.1')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
