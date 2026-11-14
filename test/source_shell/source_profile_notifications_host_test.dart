import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/source_shell/models/source_checkin_status.dart';
import 'package:zephyr/page/source_shell/view/source_notifications_view.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _source = 'profile-notifications-host-fixture';

/// Synthetic native boundary only. This fixture never loads a user account,
/// plugin file, socket, or real mark/check-in operation.
class _NotificationsApi extends RustLibApi {
  String account = 'account-a';
  String caption = 'initial';
  bool profileReceipt = false;
  Completer<void>? noticeGate;
  Completer<void>? markGate;
  List<String>? markConfirmed;
  List<String> markUnknown = [];
  final readIds = <String>{};
  final calls = <(String, Map<String, dynamic>)>[];
  String verificationStatus = 'confirmed';
  String? verificationAccount;
  String? verificationDate;
  String? receiptDate;
  String verificationSource = 'serverCalendar';

  void reset() {
    account = 'account-a';
    caption = 'initial';
    profileReceipt = false;
    noticeGate = null;
    markGate = null;
    markConfirmed = null;
    markUnknown = [];
    readIds.clear();
    calls.clear();
    verificationStatus = 'confirmed';
    verificationAccount = null;
    verificationDate = null;
    receiptDate = null;
    verificationSource = 'serverCalendar';
  }

  Map<String, dynamic> snapshot() => {
    'accountId': account,
    'items': [
      for (final (suffix, read) in [
        ('one', false),
        ('two', false),
        ('read', true),
        ('unknown', null),
      ])
        {
          'id': '$account-$suffix',
          'title': '$account $caption $suffix',
          'content': 'Synthetic notice body',
          'time': '2026-11-02 14:05:00',
          'type': 'site_notice',
          'read': readIds.contains('$account-$suffix') ? true : read,
          'readKnown': read != null,
        },
    ],
    'complete': false,
    'totalKnown': false,
    'unreadSummary': {
      'accountId': account,
      'countsKnown': true,
      'total':
          2 -
          [
            'one',
            'two',
          ].where((suffix) => readIds.contains('$account-$suffix')).length,
    },
  };

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-notifications-fixture');

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final args = Map<String, dynamic>.from(jsonDecode(argsJson) as Map);
    calls.add((fnPath, args));
    Map<String, dynamic> data;
    final today = sourceCheckinDate(DateTime.now());
    switch (fnPath) {
      case 'init':
        data = {'ok': true};
      case 'getUserInfoBundle':
        data = {
          'lines': [account],
          'extern': {
            'name': account,
            'accountId': account,
            'level': 3,
            'checkedIn': profileReceipt ? true : null,
            'checkedInDate': profileReceipt ? today : null,
            'checkinProof': profileReceipt
                ? {'source': 'savedReceipt', 'date': today}
                : null,
          },
        };
      case 'getCloudFavoriteData' || 'getFavoriteData':
        data = {'items': <Object>[]};
      case 'getNotifications':
        data =
            snapshot(); // Capture identity and contents before an old reply waits.
        final gate = noticeGate;
        noticeGate = null;
        if (gate != null) await gate.future;
      case 'markNotificationRead' || 'markNotificationsRead':
        final ids = fnPath == 'markNotificationRead'
            ? [args['id'] as String]
            : (args['ids'] as List).cast<String>();
        final confirmed = List<String>.of(markConfirmed ?? ids);
        final responseAccount = account;
        final gate = markGate;
        markGate = null;
        if (gate != null) await gate.future;
        readIds.addAll(confirmed);
        data = {
          'accountId': responseAccount, 'scope': 'requestedLoadedItems',
          'ok': confirmed.length == ids.length, 'confirmedIds': confirmed,
          'failedIds': ids
              .where(
                (id) => !confirmed.contains(id) && !markUnknown.contains(id),
              )
              .toList(),
          'unknownIds': markUnknown,
          // Deliberately untrustworthy bulk snapshot: the host must use only
          // confirmed requested IDs, not optimistically adopt every row here.
          'items': [
            for (final item in snapshot()['items'] as List)
              {...item as Map, 'read': true},
          ],
          'unreadSummary': snapshot()['unreadSummary'],
        };
      case 'getCheckinStatus':
        data = {
          'accountId': verificationAccount ?? account,
          'checkedIn': true,
          'checkedInDate': receiptDate ?? today,
          'verification': {
            'source': verificationSource,
            'date': verificationDate ?? today,
            'status': verificationStatus,
            'signed': verificationStatus == 'confirmed' ? true : null,
          },
        };
      case 'checkInToday':
        throw StateError('Read-only host verification must never sign in');
      default:
        throw StateError('Unexpected synthetic operation: $fnPath');
    }
    return Uint8List.fromList(
      utf8.encode(jsonEncode({'source': _source, 'data': data})),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _NotificationsApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.reset();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  Future<void> mount(
    WidgetTester tester, {
    String style = 'breeze',
    Brightness brightness = Brightness.light,
    bool calendarVerification = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = GlobalSettingCubit();
    final preference = ValueNotifier(style);
    addTearDown(cubit.close);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              bottomNavigationBar: const SizedBox(
                key: ValueKey('fixture-root-navigation'),
                height: 70,
              ),
              body: SourceProfileContent(
                source: _source,
                sourceName: 'Synthetic JM',
                profileKind: calendarVerification ? 'generic' : 'jm',
                notificationsFunction: 'getNotifications',
                checkinFunction: 'checkInToday',
                checkinStatusFunction: 'getCheckinStatus',
                markNotificationReadFunction: 'markNotificationRead',
                markNotificationsReadFunction: 'markNotificationsRead',
                onLogin: () async {
                  api.account = 'account-b';
                },
                onSettings: () async {},
                onCloudFavorite: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SourceNotificationsView current(WidgetTester tester) => tester
      .widget<SourceNotificationsView>(find.byType(SourceNotificationsView));

  Future<void> enter(WidgetTester tester) async {
    final entry = find.text(t.sourceNotices.entry);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(SourceNotificationsView), findsOneWidget);
  }

  Future<void> verify(WidgetTester tester) async {
    final action = find.byKey(const ValueKey('profile-checkin-verify'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets('notifications own a named route and pop back to the profile', (
    tester,
  ) async {
    await mount(tester);
    await enter(tester);
    final noticeContext = tester.element(find.byType(SourceNotificationsView));
    final route = ModalRoute.of(noticeContext)!;
    expect(route.settings.name, 'breeze.source.notifications');
    expect(route.isFirst, isFalse);
    expect(find.byKey(const ValueKey('fixture-root-navigation')), findsNothing);
    expect(find.text(t.sourceNotices.title), findsOneWidget);
    expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
    await Navigator.of(noticeContext).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(SourceNotificationsView), findsNothing);
    expect(
      find.byKey(const ValueKey('fixture-root-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-account-action')),
      findsOneWidget,
    );
    expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
    await enter(tester);
    expect(current(tester).notices, hasLength(4));
  });

  testWidgets('iOS notification back gesture can cancel and then return', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await mount(tester);
      await enter(tester);
      final cancelled = await tester.startGesture(const Offset(1, 550));
      await cancelled.moveBy(const Offset(110, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await cancelled.moveBy(const Offset(-105, 0));
      await cancelled.up();
      await tester.pumpAndSettle();
      expect(find.byType(SourceNotificationsView), findsOneWidget);
      expect(current(tester).notices, hasLength(4));
      await tester.dragFrom(const Offset(1, 550), const Offset(370, 0));
      await tester.pumpAndSettle();
      expect(find.byType(SourceNotificationsView), findsNothing);
      expect(
        find.byKey(const ValueKey('fixture-root-navigation')),
        findsOneWidget,
      );
      expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'real profile badge, open and explicit partial read actions preserve unconfirmed rows',
    (tester) async {
      await mount(tester);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect((badge.label! as Text).data, '2');
      await enter(tester);
      expect(current(tester).unreadCount, 2);
      expect(current(tester).notices, hasLength(4));
      expect(current(tester).notices.last.read, isNull);
      expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
      final open = find.byKey(
        const ValueKey('source-notice-open-account-a-one-0'),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();

      final gate = Completer<void>();
      api.markGate = gate;
      final single = find.byKey(
        const ValueKey('source-notice-mark-account-a-one-0'),
      );
      await tester.ensureVisible(single);
      await tester.tap(single);
      await tester.pump();
      expect(current(tester).marking, isTrue);
      expect(tester.widget<TextButton>(single).onPressed, isNull);
      current(tester).onMarkRead!(
        current(tester).notices.first,
      ); // Public callback also guards duplicates.
      await tester.pump();
      expect(
        api.calls.where((call) => call.$1 == 'markNotificationRead'),
        hasLength(1),
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(current(tester).notices.first.read, isTrue);
      expect(current(tester).notices[1].read, isFalse);
      expect(current(tester).notices.last.read, isNull);

      api.markConfirmed = [];
      final bulkGate = Completer<void>();
      api.markGate = bulkGate;
      final bulk = find.byKey(const ValueKey('source-notices-mark-loaded'));
      await tester.ensureVisible(bulk);
      await tester.tap(bulk);
      await tester.pump();
      expect(tester.widget<TextButton>(bulk).onPressed, isNull);
      bulkGate.complete();
      await tester.pumpAndSettle();
      expect(current(tester).error, contains('尚未确认'));
      expect(current(tester).notices[1].read, isFalse);
      final batch = api.calls
          .singleWhere((call) => call.$1 == 'markNotificationsRead')
          .$2;
      expect(batch['accountId'], 'account-a');
      expect(batch['ids'], ['account-a-two']);
      await current(tester).onRefresh();
      await tester.pumpAndSettle();
      expect(current(tester).error, isNull);
      expect(current(tester).notices.first.read, isTrue);
      expect(current(tester).notices[1].read, isFalse);
    },
  );

  testWidgets(
    'unconfirmed message writes become unknown until a fresh server read',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text(t.sourceNotices.entry));
      await tester.pumpAndSettle();
      api.markConfirmed = [];
      api.markUnknown = ['account-a-one'];
      current(tester).onMarkRead!(current(tester).notices.first);
      await tester.pumpAndSettle();
      expect(current(tester).notices.first.read, isNull);
      expect(current(tester).notices.first.canMarkRead, isFalse);
      expect(current(tester).notices[1].read, isFalse);
      expect(current(tester).error, contains('尚未确认'));
      await current(tester).onRefresh();
      await tester.pumpAndSettle();
      expect(current(tester).notices.first.read, isFalse);
      expect(current(tester).notices.first.canMarkRead, isTrue);
      expect(
        api.calls.where((call) => call.$1.startsWith('mark')),
        hasLength(1),
      );
    },
  );

  testWidgets('account switch rejects a late private notification snapshot', (
    tester,
  ) async {
    await mount(tester, style: 'system', brightness: Brightness.dark);
    await enter(tester);
    final gate = Completer<void>();
    api.noticeGate = gate;
    final oldRead = current(tester).onRefresh();
    await tester.pump();
    current(tester).onBack!();
    await tester.pumpAndSettle();
    final change = find.byKey(const ValueKey('profile-account-action'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saved-account-add')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await enter(tester);
    expect(
      current(
        tester,
      ).notices.every((notice) => notice.id.startsWith('account-b-')),
      isTrue,
    );
    gate.complete();
    await oldRead;
    await tester.pumpAndSettle();
    expect(
      current(
        tester,
      ).notices.every((notice) => notice.id.startsWith('account-b-')),
      isTrue,
    );
    expect(api.calls.where((call) => call.$1.startsWith('mark')), isEmpty);
  });

  testWidgets(
    'a newer refresh snapshot wins when an earlier read finishes last',
    (tester) async {
      await mount(tester);
      await enter(tester);
      api.caption = 'old-request';
      final gate = Completer<void>();
      api.noticeGate = gate;
      final oldRead = current(tester).onRefresh();
      await tester.pump();
      api.caption = 'new-request';
      await current(tester).onRefresh();
      await tester.pumpAndSettle();
      expect(current(tester).notices.first.title, contains('new-request'));
      gate.complete();
      await oldRead;
      await tester.pumpAndSettle();
      expect(current(tester).notices.first.title, contains('new-request'));
      expect(current(tester).loading, isFalse);
    },
  );

  testWidgets(
    'calendar verification is read-only and a later failure retains the confirmed receipt',
    (tester) async {
      await mount(
        tester,
        brightness: Brightness.dark,
        calendarVerification: true,
      );
      await verify(tester);
      final evidence = find.byKey(const ValueKey('profile-checkin-evidence'));
      expect(tester.widget<Text>(evidence).data, contains('源站日历确认已签到'));
      final checkin = find.byKey(const ValueKey('profile-checkin-action'));
      expect(tester.widget<FilledButton>(checkin).onPressed, isNull);
      api.verificationStatus = 'failed';
      await verify(tester);
      expect(tester.widget<Text>(evidence).data, contains('暂时无法核对源站状态'));
      expect(tester.widget<Text>(evidence).data, isNot(contains('源站日历确认已签到')));
      expect(tester.widget<FilledButton>(checkin).onPressed, isNull);
      expect(
        api.calls.where((call) => call.$1 == 'getCheckinStatus'),
        hasLength(2),
      );
      expect(api.calls.where((call) => call.$1 == 'checkInToday'), isEmpty);
    },
  );

  testWidgets(
    'calendar confirmation requires matching account, both dates and the server-calendar source',
    (tester) async {
      await mount(tester, calendarVerification: true);
      final checkin = find.byKey(const ValueKey('profile-checkin-action'));
      api.verificationAccount = 'other-account';
      await verify(tester);
      expect(find.textContaining('源站日历确认已签到'), findsNothing);
      expect(tester.widget<FilledButton>(checkin).onPressed, isNotNull);
      api.verificationAccount = null;
      api.verificationDate = '2000-01-01';
      await verify(tester);
      expect(find.textContaining('源站日历确认已签到'), findsNothing);
      expect(tester.widget<FilledButton>(checkin).onPressed, isNotNull);
      api.verificationDate = null;
      api.receiptDate = '2000-01-01';
      await verify(tester);
      expect(find.textContaining('源站日历确认已签到'), findsNothing);
      expect(tester.widget<FilledButton>(checkin).onPressed, isNotNull);
      api.receiptDate = null;
      api.verificationSource = 'unknown';
      await verify(tester);
      expect(find.textContaining('源站日历确认已签到'), findsNothing);
      expect(tester.widget<FilledButton>(checkin).onPressed, isNotNull);
      expect(api.calls.where((call) => call.$1 == 'checkInToday'), isEmpty);
    },
  );
}
