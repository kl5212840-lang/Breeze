import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/playback_trace.dart';

void main() {
  test(
    'keeps actionable exception and stack while redacting embedded data',
    () {
      final trace = PlaybackTrace();
      trace.failure(
        'plugin_resolution',
        StateError(
          'ReferenceError: fetchBridge is not defined\n'
          'https://user:password@cdn.example/movie.m3u8?signature=hidden\n'
          'Cookie: session=secret; user=private\n'
          'Authorization: Bearer privateAuth\n'
          '{"networkContext":"privateToken","password":"privatePass"}\n'
          'account@private.example',
        ),
        StackTrace.fromString('at resolveMedia (bundle.js:42:8)'),
      );
      final report = trace.export();
      expect(report, contains('ReferenceError: fetchBridge is not defined'));
      expect(report, contains('bundle.js:42:8'));
      expect(report, contains('cdn.example'));
      for (final secret in [
        'password@',
        'movie.m3u8',
        'hidden',
        'secret',
        'privateAuth',
        'privateToken',
        'privatePass',
        'private.example',
        'account@',
      ]) {
        expect(report, isNot(contains(secret)), reason: secret);
      }
    },
  );

  test(
    'plugin failure redacts short private headers and credential fields through export',
    () async {
      final trace = PlaybackTrace();
      const privateValues = [
        'shortApiKey',
        'privateAuthKey',
        'privateAccess',
        'privateSession',
        'privateCsrf',
        'privateXsrf',
        'shortCamelKey',
        'shortSnakeKey',
        'shortClientSecret',
        'shortCamelSecret',
        'shortAccessToken',
        'shortRefreshToken',
        'shortSessionKey',
        'shortAccount',
        'shortUser',
      ];
      await trace.run('unknown-marketplace-plugin', () async {
        // Same capture path as QJS dispatch, using synthetic short values that
        // cannot be hidden accidentally by the long opaque-value rule.
        PlaybackTrace.error(
          'unknown-marketplace-plugin',
          'qjs_dispatch',
          StateError(
            'HTTP 403 at https://cdn.example/public/movie.m3u8?sig=privateQuery\n'
            'X-Api-Key: shortApiKey\n'
            'api-key = privateAuthKey\n'
            'X-Access-Token: privateAccess\n'
            'X-Session-Id: privateSession\n'
            'X-CSRF-Token: privateCsrf\n'
            'X-XSRF-Token: privateXsrf\n'
            '{"apiKey":"shortCamelKey","api_key":"shortSnakeKey",'
            '"client_secret":"shortClientSecret","clientSecret":"shortCamelSecret",'
            '"accessToken":"shortAccessToken","refreshToken":"shortRefreshToken",'
            '"session_key":"shortSessionKey","accountId":"shortAccount","user_id":"shortUser"}',
          ),
          StackTrace.fromString('at resolveMedia (bundle.js:42:8)'),
        );
      });
      final report = trace.export();
      for (final value in [...privateValues, 'privateQuery', 'movie.m3u8']) {
        expect(report, isNot(contains(value)), reason: value);
      }
      expect(report, contains('HTTP 403'));
      expect(report, contains('https://cdn.example/<redacted>'));
      expect(report, contains('bundle.js:42:8'));
      expect(report, contains('qjs_dispatch'));
    },
  );

  test(
    'captures native error code/message without arbitrary details payload',
    () {
      final trace = PlaybackTrace();
      trace.failure(
        'native_http',
        PlatformException(
          code: 'closed',
          message: 'Connection failed (-1009)',
          details: 'private body',
        ),
        StackTrace.current,
      );
      expect(trace.export(), contains('Connection failed (-1009)'));
      expect(trace.export(), isNot(contains('private body')));
    },
  );

  test('source subscriptions survive nesting and end even on error', () async {
    final trace = PlaybackTrace();
    await trace.run('source-a', () async {
      PlaybackTrace.note('source-b', 'bridge', 'other source');
      await expectLater(
        trace.run<void>('source-a', () async {
          PlaybackTrace.note('source-a', 'bridge', 'inner callback');
          throw StateError('fixture');
        }),
        throwsStateError,
      );
      PlaybackTrace.note('source-a', 'bridge', 'outer callback');
    });
    PlaybackTrace.note('source-a', 'bridge', 'after closing');
    expect(trace.export(), contains('inner callback'));
    expect(trace.export(), contains('outer callback'));
    expect(trace.export(), isNot(contains('other source')));
    expect(trace.export(), isNot(contains('after closing')));
  });

  test('recorder is bounded and keeps newest failure', () {
    final trace = PlaybackTrace();
    for (var i = 0; i < 100; i++) {
      trace.add('event', 'record-$i ${'x ' * 400}');
    }
    trace.add('failure', 'latest actionable message');
    expect(trace.export().length, lessThanOrEqualTo(24000));
    expect(trace.export(), contains('latest actionable message'));
    expect(trace.export(), isNot(contains('record-0 ')));
  });
}
