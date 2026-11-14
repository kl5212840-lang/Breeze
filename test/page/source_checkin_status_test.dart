import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/source_shell/models/source_checkin_status.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 15, 59, 59);
  const receipt = <String, dynamic>{
    'accountId': 'account-a',
    'checkedIn': true,
    'checkedInDate': '2026-11-01',
  };

  SourceCheckinStatus initial() =>
      SourceCheckinStatus.forAccount('account-a', now: now);

  test('unknown differs from a confirmed same-account same-day receipt', () {
    expect(initial().checkedIn, isNull);
    final confirmed = initial().merge(
      receipt,
      accountId: 'account-a',
      now: now,
    );
    expect(confirmed.checkedIn, isTrue);
    expect(confirmed.date, '2026-11-01');
  });

  test(
    'unknown, explicit failure and refresh errors retain a valid receipt',
    () {
      final confirmed = initial().merge(
        receipt,
        accountId: 'account-a',
        now: now,
      );
      for (final payload in <Map<String, dynamic>?>[
        null,
        {},
        {...receipt, 'checkedIn': null},
        {...receipt, 'checkedIn': false},
        {...receipt, 'ok': false},
      ]) {
        expect(
          confirmed.merge(payload, accountId: 'account-a', now: now).checkedIn,
          isTrue,
        );
      }
    },
  );

  test('mismatched, incomplete and failed results never establish success', () {
    for (final payload in <Map<String, dynamic>>[
      {...receipt, 'accountId': 'account-b'},
      {...receipt, 'checkedInDate': '2026-10-31'},
      {...receipt, 'checkedInDate': '2026-11-02'},
      {...receipt}..remove('accountId'),
      {...receipt}..remove('checkedInDate'),
      {...receipt, 'checkedIn': 'true'},
      {...receipt, 'ok': false},
      {'ok': true, 'message': '签到成功'},
    ]) {
      expect(
        initial().merge(payload, accountId: 'account-a', now: now).checkedIn,
        isNull,
      );
    }
  });

  test('account switching and logout discard the old receipt', () {
    final confirmed = initial().merge(
      receipt,
      accountId: 'account-a',
      now: now,
    );
    expect(
      confirmed.merge(receipt, accountId: 'account-b', now: now).checkedIn,
      isNull,
    );
    expect(confirmed.merge(receipt, accountId: '', now: now).checkedIn, isNull);
  });

  test('UTC+8 midnight discards yesterday and accepts only the new day', () {
    final midnight = DateTime.utc(2026, 11, 1, 16);
    expect(sourceCheckinDate(now), '2026-11-01');
    expect(sourceCheckinDate(midnight), '2026-11-02');
    final confirmed = initial().merge(
      receipt,
      accountId: 'account-a',
      now: now,
    );
    final nextDay = confirmed.merge(
      receipt,
      accountId: 'account-a',
      now: midnight,
    );
    expect(nextDay.checkedIn, isNull);
    expect(nextDay.date, '2026-11-02');
    expect(
      nextDay
          .merge(
            {...receipt, 'checkedInDate': '2026-11-02'},
            accountId: 'account-a',
            now: midnight,
          )
          .checkedIn,
      isTrue,
    );
  });
}
