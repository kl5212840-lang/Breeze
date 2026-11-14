import 'dart:convert';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/page/source_shell/models/source_profile_records.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/comic_entry/comic_entry.dart';
import 'package:zephyr/widgets/comic_entry/comic_record_time.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/main.dart' show objectbox;

import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'stored history has a distinct complete reading line in all comic hosts $style $brightness',
        (tester) async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final channels = <MethodChannel>[];
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
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
          await tester.binding.setSurfaceSize(const Size(320, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final readAt = DateTime(2026, 11, 1, 9, 5);
          final record =
              createTestHistory(
                  'last-read-fixture',
                  updatedAt: DateTime(2030, 2, 3),
                )
                ..lastReadAt = readAt
                ..title = '真实历史中的漫画'
                ..chapterTitle = '第12话'
                ..description = List.filled(8, '较长的简介不应吞没真实的最后阅读时间。').join()
                ..metadata = jsonEncode([
                  {
                    'type': 'tags',
                    'name': '标签',
                    'value': List.generate(8, (i) => '长标签$i'),
                  },
                ]);
          objectbox.unifiedHistoryBox.put(record);
          final item = loadSourceProfileRecords(['test']).history.single;
          expect(
            DateTime.parse(
              '${item.raw['lastReadAt']}',
            ).isAtSameMomentAs(readAt),
            isTrue,
          );
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          for (final host in ['bookshelf', 'shared-tile', 'profile']) {
            final child = switch (host) {
              'bookshelf' => ListView(
                children: [
                  ComicEntryWidget(comic: item, type: ComicEntryType.history),
                ],
              ),
              'shared-tile' => ListView(
                children: [
                  SourceSearchDetailTile(
                    entry: item,
                    type: ComicEntryType.history,
                    localRecord: true,
                  ),
                ],
              ),
              _ => SourceProfileRecordsView(
                mode: ShelfPageMode.history,
                entries: [item],
                onBack: () {},
                onRefresh: () {},
              ),
            };
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
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(body: child),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final profile = host == 'profile';
            final time = find.byKey(
              ValueKey(
                profile
                    ? 'shelf-detail.time'
                    : 'comic-last-read:test:last-read-fixture',
              ),
            );
            expect(time, findsOneWidget, reason: host);
            final text = tester.widget<Text>(time);
            final label = t.comicEntry.lastReadAt(time: '2026-11-01 09:05');
            if (profile) {
              expect(text.data, contains('2026-11-01 09:05'));
              expect(
                tester
                    .widget<Semantics>(
                      find
                          .ancestor(of: time, matching: find.byType(Semantics))
                          .first,
                    )
                    .properties
                    .label,
                label,
              );
            } else {
              expect(text.data, label);
              expect(text.maxLines, isNull);
              expect(text.overflow, isNot(TextOverflow.ellipsis));
            }
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: time, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: host);
            expect(text.style?.fontWeight, FontWeight.w400);
            expect(
              text.style?.color,
              Theme.of(tester.element(time)).colorScheme.onSurfaceVariant,
            );
            final frame = tester.getRect(time);
            expect(frame.left, greaterThanOrEqualTo(0));
            expect(frame.right, lessThanOrEqualTo(320));
            final progress = find.textContaining('第12话');
            expect(progress, findsOneWidget);
            expect(
              tester.getRect(progress).bottom,
              lessThanOrEqualTo(frame.top),
            );
            expect(find.textContaining('2030-02-03'), findsNothing);
            expect(find.textContaining('T09:05'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'unknown history time never uses record revision and sorting uses actual reading events',
    (tester) async {
      final older = createTestHistory(
        'older-read',
        updatedAt: DateTime(2031, 1, 1),
      )..lastReadAt = DateTime(2026, 1, 1);
      final newer = createTestHistory(
        'newer-read',
        updatedAt: DateTime(2030, 1, 1),
      )..lastReadAt = DateTime(2026, 2, 1);
      objectbox.unifiedHistoryBox.putMany([older, newer]);
      final entries = loadSourceProfileRecords(['test']).history;
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: Scaffold(
              body: SourceProfileRecordsView(
                mode: ShelfPageMode.history,
                entries: entries,
                onBack: () {},
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('profile-detailed-list'));
      Finder record(String id) => find.descendant(
        of: list,
        matching: find.byKey(ValueKey('profile-record.test:$id')),
      );
      final newerRow = record('newer-read');
      final olderRow = record('older-read');
      expect(newerRow, findsOneWidget);
      expect(olderRow, findsOneWidget);
      expect(
        tester.getTopLeft(newerRow).dy,
        lessThan(tester.getTopLeft(olderRow).dy),
      );

      await tester.tap(find.byKey(const ValueKey('profile-record.sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最早'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(olderRow).dy,
        lessThan(tester.getTopLeft(newerRow).dy),
      );
      final unknown = unifiedComicFromUnifiedHistory(
        older,
      ).copyWith(raw: {'lastReadAt': 'not-a-date'});
      for (final child in [
        SingleChildScrollView(
          child: ComicEntryWidget(comic: unknown, type: ComicEntryType.history),
        ),
        SingleChildScrollView(
          child: SourceSearchDetailTile(
            entry: unknown,
            type: ComicEntryType.history,
          ),
        ),
        SourceProfileRecordsView(
          mode: ShelfPageMode.history,
          entries: [unknown],
          onBack: () {},
          onRefresh: () {},
        ),
      ]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
        await tester.pumpAndSettle();
        expect(find.byType(ComicLastReadLine), findsNothing);
        expect(find.byKey(const ValueKey('shelf-detail.time')), findsNothing);
        expect(find.textContaining('2031-01-01'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
