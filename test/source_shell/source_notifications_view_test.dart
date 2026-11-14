import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/view/source_notifications_view.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

const _notices = [
  SourceNotice(
    id: 'unread',
    title: '未读站内通知',
    content: '官方消息正文',
    time: '2026-11-02 14:05:00',
    type: 'site_notice',
    read: false,
  ),
  SourceNotice(
    id: 'tracking',
    title: '漫画追更通知',
    type: 'comic_follow',
    read: true,
  ),
  SourceNotice(id: 'unknown', title: '状态未知通知', type: 'new_type'),
  SourceNotice(title: '没有标识的未读通知', read: false),
];

Widget _host(
  Widget child, {
  String style = 'breeze',
  Brightness brightness = Brightness.light,
  double scale = 1,
}) {
  return AppInterfaceStyleScope(
    style: ValueNotifier(style),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, platform: TargetPlatform.iOS),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

void main() {
  test(
    'notice mapping preserves unknown read state and requires a real ID to mark',
    () {
      expect(
        SourceNotice.fromMap({'read': true, 'readKnown': false}).read,
        isNull,
      );
      expect(SourceNotice.fromMap({'read': 'unexpected'}).read, isNull);
      expect(SourceNotice.fromMap({'read': 0, 'id': 12}).canMarkRead, isTrue);
      expect(SourceNotice.fromMap({'read': false}).canMarkRead, isFalse);
      expect(
        SourceNotice.fromMap({'read': false, 'id': {}}).canMarkRead,
        isFalse,
      );
      expect(
        SourceNotice.fromMap({'read': true, 'id': 'known'}).canMarkRead,
        isFalse,
      );
      expect(SourceNotice.fromMap({'date': 1793664000}).time, '1793664000');
      expect(SourceNotice.fromMap({'type': 'unknown'}).isSiteNotice, isFalse);
    },
  );

  test(
    'date presentation accepts real dates and timestamps without normalizing invalid dates',
    () {
      expect(formatSourceNoticeTime('2026-11-02'), '2026年11月2日');
      expect(formatSourceNoticeTime('2026-11-02 14:05:00'), '2026年11月2日 14:05');
      expect(formatSourceNoticeTime('2026-02-30'), isEmpty);
      expect(formatSourceNoticeTime('2026-11-02T25:10:00Z'), isEmpty);
      expect(formatSourceNoticeTime('unknown'), isEmpty);
      expect(formatSourceNoticeTime('0'), isEmpty);
      expect(
        formatSourceNoticeTime('1793664000'),
        formatSourceNoticeTime('1793664000000'),
      );
      expect(
        formatSourceNoticeTime('2026-11-02T10:00:00+08:00'),
        formatSourceNoticeTime('2026-11-02T02:00:00Z'),
      );
    },
  );

  testWidgets(
    'groups use known states, opening does not mark and missing IDs cannot mark',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final opened = <SourceNotice>[];
      final marked = <SourceNotice>[];
      var bulk = 0;
      await tester.pumpWidget(
        _host(
          SourceNotificationsView(
            notices: _notices,
            loading: false,
            marking: false,
            complete: false,
            onRefresh: () async {},
            onOpen: opened.add,
            onMarkRead: marked.add,
            onMarkLoadedRead: () => bulk++,
          ),
        ),
      );
      expect(find.text('未读数量暂不可用'), findsOneWidget);
      expect(find.textContaining('其他消息不会改变'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('source-notice-mark-unread-0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('source-notice-mark--3')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('source-notice-open-unread-0')),
      );
      expect(opened, [_notices.first]);
      expect(marked, isEmpty);
      expect(bulk, 0);
      await tester.tap(
        find.byKey(const ValueKey('source-notices-filter-unread')),
      );
      await tester.pump();
      expect(find.text('未读站内通知'), findsOneWidget);
      expect(find.text('状态未知通知'), findsNothing);
      expect(find.text('漫画追更通知'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('source-notices-filter-tracking')),
      );
      await tester.pump();
      expect(find.text('漫画追更通知'), findsOneWidget);
      expect(find.text('未读站内通知'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('source-notices-filter-site')),
      );
      await tester.pump();
      expect(find.text('未读站内通知'), findsOneWidget);
      expect(find.text('漫画追更通知'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('source-notice-mark-unread-0')),
      );
      expect(marked, [_notices.first]);
      await tester.tap(
        find.byKey(const ValueKey('source-notices-mark-loaded')),
      );
      expect(bulk, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final compact in [false, true]) {
        testWidgets(
          'notification host readable with 44pt actions $style $brightness compact=$compact',
          (tester) async {
            final width = compact ? 320.0 : 420.0;
            await tester.binding.setSurfaceSize(Size(width, 1000));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              _host(
                SourceNotificationsView(
                  notices: const [
                    SourceNotice(
                      id: 'long',
                      title: '很长的官方站内通知标题，需要换行也不能挤掉操作',
                      content: '消息正文保留自己的阅读区域，不与日期和已读操作互相覆盖。',
                      time: '2026-11-02T10:00:00+08:00',
                      type: 'site_notice',
                      read: false,
                    ),
                  ],
                  loading: false,
                  marking: false,
                  complete: false,
                  total: 20,
                  unreadCount: 2,
                  error: '刷新失败，现有消息已保留',
                  onRefresh: () async {},
                  onOpen: (_) {},
                  onMarkRead: (_) {},
                  onMarkLoadedRead: () {},
                  onBack: () {},
                ),
                style: style,
                brightness: brightness,
                scale: compact ? 2 : 1,
              ),
            );
            await tester.pump();
            expect(find.byTooltip('刷新消息'), findsNothing);
            final retry = tester.getRect(
              find.byKey(const ValueKey('source-notices-retry')),
            );
            expect(retry.height, greaterThanOrEqualTo(44));
            expect(retry.width, greaterThanOrEqualTo(44));
            final chip = tester.getRect(
              find.byKey(const ValueKey('source-notices-filter-site')),
            );
            expect(chip.height, greaterThanOrEqualTo(44));
            expect(chip.right, lessThanOrEqualTo(width - 16));
            final mark = find.byKey(
              const ValueKey('source-notices-mark-loaded'),
            );
            final markRect = tester.getRect(mark);
            expect(markRect.height, greaterThanOrEqualTo(44));
            expect(markRect.right, lessThanOrEqualTo(width - 16));
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('source-notices-scope')))
                  .top,
              greaterThanOrEqualTo(markRect.bottom),
            );
            final open = find.byKey(
              const ValueKey('source-notice-open-long-0'),
            );
            await tester.ensureVisible(open);
            await tester.pump();
            expect(tester.getRect(open).width, lessThanOrEqualTo(width));
            expect(
              find.byKey(const ValueKey('source-notice-time-long-0')),
              findsOneWidget,
            );
            final singleMark = find.byKey(
              const ValueKey('source-notice-mark-long-0'),
            );
            await tester.ensureVisible(singleMark);
            expect(tester.getRect(singleMark).height, greaterThanOrEqualTo(44));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'loading and marking keep existing rows and disable duplicate actions',
    (tester) async {
      var refreshes = 0, marks = 0;
      for (final marking in [false, true]) {
        await tester.pumpWidget(
          _host(
            SourceNotificationsView(
              notices: [_notices.first],
              loading: !marking,
              marking: marking,
              complete: true,
              onRefresh: () async => refreshes++,
              onOpen: (_) {},
              onMarkRead: (_) => marks++,
              onMarkLoadedRead: () => marks++,
            ),
          ),
        );
        expect(find.text('未读站内通知'), findsOneWidget);
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('source-notices-mark-loaded')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('source-notice-mark-unread-0')),
              )
              .onPressed,
          isNull,
        );
      }
      expect(refreshes, 0);
      expect(marks, 0);
    },
  );

  testWidgets(
    'pull retains existing notices and guards failure retry until completion',
    (tester) async {
      var refreshes = 0;
      final gate = Completer<void>();
      await tester.pumpWidget(
        _host(
          SourceNotificationsView(
            notices: [_notices.first],
            loading: false,
            marking: false,
            complete: false,
            error: '读取失败，请重试',
            onRefresh: () {
              refreshes++;
              return gate.future;
            },
            onOpen: (_) {},
          ),
        ),
      );
      expect(find.text('未读站内通知'), findsOneWidget);
      await tester.drag(find.byType(Scrollable), const Offset(0, 320));
      for (var frame = 0; frame < 80 && refreshes == 0; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(refreshes, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      final retry = find.byKey(const ValueKey('source-notices-retry'));
      expect(tester.widget<TextButton>(retry).onPressed, isNull);
      expect(find.text('未读站内通知'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(refreshes, 2);
    },
  );
}
