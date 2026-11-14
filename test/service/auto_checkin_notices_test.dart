import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/plugin/bridge/dart_tools_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/checkin/auto_checkin_notices.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/toast.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
const _jm = '6886291b-f524-441c-844b-c2efae9899a9';
const _unsupported = '0a0e5858-a467-4702-994a-79e608a4589d';

String _payload(
  String source, {
  String account = 'account123',
  String date = '2026-11-11',
}) => jsonEncode([
  source,
  jsonEncode({'accountId': account, 'date': date}),
]);

class _BridgeApi extends RustLibApi {
  final routes = <String, FutureOr<String> Function(String)>{};

  @override
  void crateApiQjsRegisterFunction({
    required String functionName,
    required FutureOr<String> Function(String) dartCallback,
  }) {
    routes[functionName] = dartCallback;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late AutoCheckinNotices notices;
  setUp(() {
    now = DateTime.utc(2026, 11, 11, 8);
    SharedPreferences.setMockInitialValues({});
    notices = AutoCheckinNotices(now: () => now);
  });
  tearDown(() => notices.dispose());

  test(
    'buffers confirmed notices and deduplicates concurrent reports and restart',
    () async {
      await notices.load();
      expect(notices.enabled.value, isTrue);
      await Future.wait([
        notices.report(_payload(_bika)),
        notices.report(_payload('($_bika@net.0123456789ab)')),
        notices.report(_payload(_jm)),
        notices.report(_payload(_bika, account: 'account456')),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final receipts = prefs.getStringList(AutoCheckinNotices.receiptKey)!;
      expect(receipts.first, '2026-11-11');
      expect(receipts.skip(1), hasLength(3));
      expect(receipts.skip(1), everyElement(matches(r'^[a-f0-9]{64}$')));
      expect(receipts.join(), isNot(contains('account123')));

      final shown = notices.takePending();
      expect(shown, hasLength(3));
      expect(shown.map((event) => event.type), everyElement(ToastType.success));
      expect(
        shown.map((event) => event.deduplicationKey).toSet(),
        hasLength(3),
      );
      final zh = LocaleSettings.currentLocale.languageCode == 'zh';
      expect(
        shown.map((event) => event.message),
        containsAll([
          t.notification.autoCheckinCompleted(source: zh ? '哔咔＋' : 'Bika+'),
          t.notification.autoCheckinCompleted(source: zh ? '禁漫＋' : 'JM+'),
        ]),
      );
      expect(notices.takePending(), isEmpty);

      final restarted = AutoCheckinNotices(now: () => now);
      addTearDown(restarted.dispose);
      await restarted.report(_payload(_bika));
      expect(restarted.takePending(), isEmpty);
    },
  );

  test(
    'rejects malformed, stale and untrusted events and renews at site midnight',
    () async {
      for (final input in [
        '[',
        _payload(_unsupported),
        _payload('global'),
        _payload(_bika, account: 'credential@example.com'),
        _payload(_bika, date: '2026-11-10'),
        _payload(_bika, date: '2026-11-12'),
        _payload(_bika, date: '2026-11-11T00:00:00'),
        jsonEncode([
          _bika,
          jsonEncode({
            'accountId': 'account123',
            'date': '2026-11-11',
            'token': 'x',
          }),
        ]),
        jsonEncode([
          _bika,
          jsonEncode({'date': '2026-11-11', 'displayName': 'account123'}),
        ]),
      ]) {
        expect(await notices.report(input), '');
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AutoCheckinNotices.receiptKey), isFalse);
      await notices.report(_payload(_bika));

      now = DateTime.utc(2026, 11, 11, 16);
      expect(notices.takePending(), isEmpty);
      await notices.report(_payload(_bika, date: '2026-11-12'));
      expect(notices.takePending(), hasLength(1));
      expect(prefs.getStringList(AutoCheckinNotices.receiptKey), hasLength(2));
    },
  );

  test(
    'turning off clears queued notices and does not replay muted completions',
    () async {
      await notices.report(_payload(_bika));
      await notices.setEnabled(false);
      expect(notices.takePending(), isEmpty);
      expect(await notices.report(_payload(_jm)), '');
      expect(notices.takePending(), isEmpty);
      final restarted = AutoCheckinNotices(now: () => now);
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.enabled.value, isFalse);

      await notices.setEnabled(true);
      await notices.report(_payload(_bika));
      await notices.report(_payload(_jm));
      expect(notices.takePending(), isEmpty);
      await notices.report(_payload(_jm, account: 'differentAccount'));
      expect(notices.takePending(), hasLength(1));
    },
  );

  test('ignores a replaced plugin session before or after queuing', () async {
    await notices.report(_payload(_jm));
    final generation = pluginSessionWriteFence.advance(_jm);
    expect(notices.takePending(), isEmpty);
    await notices.report(_payload(_jm, account: 'differentAccount'));
    expect(notices.takePending(), isEmpty);
    await notices.report(
      _payload('$_jm.breeze-session.$generation', account: 'differentAccount'),
    );
    expect(notices.takePending(), hasLength(1));
  });

  test(
    'registered bridge queues typed success and preserves manual toast',
    () async {
      final api = _BridgeApi();
      RustLib.initMock(api: api);
      addTearDown(RustLib.dispose);
      registerDartTools();
      final events = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(events.add);
      addTearDown(subscription.cancel);
      final toast = api.routes['flutter.showToast']!;
      FutureOr<String> sendToast(String message) => toast(
        jsonEncode([
          _bika,
          jsonEncode({'message': message, 'seconds': 3, 'level': 'success'}),
        ]),
      );
      expect(await sendToast('哔咔签到成功'), '');
      expect(await sendToast('签到成功'), '');
      await Future<void>.delayed(Duration.zero);
      expect(events.map((event) => event.message), ['签到成功']);

      final date = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 8))
          .toIso8601String()
          .substring(0, 10);
      final report = api.routes['breeze.checkin.completed']!;
      expect(await report(_payload(_bika, date: date)), '');
      expect(AutoCheckinNotices.instance.takePending(), hasLength(1));
      expect(await report(_payload(_bika, date: date)), '');
      expect(AutoCheckinNotices.instance.takePending(), isEmpty);
    },
  );

  test('only matches the exact Bika+ legacy automatic toast', () {
    const old = {'message': '哔咔签到成功', 'seconds': 3, 'level': 'success'};
    expect(isLegacyBikaAutoCheckinToast(_bika, old), isTrue);
    expect(
      isLegacyBikaAutoCheckinToast('($_bika@net.0123456789ab)', old),
      isTrue,
    );
    expect(isLegacyBikaAutoCheckinToast(_jm, old), isFalse);
    expect(isLegacyBikaAutoCheckinToast(_unsupported, old), isFalse);
    expect(
      isLegacyBikaAutoCheckinToast(_bika, {...old, 'title': '签到'}),
      isFalse,
    );
    expect(
      isLegacyBikaAutoCheckinToast(_bika, {...old, 'message': '签到成功'}),
      isFalse,
    );
    expect(
      isLegacyBikaAutoCheckinToast(_bika, {...old, 'seconds': 4}),
      isFalse,
    );
  });
}
