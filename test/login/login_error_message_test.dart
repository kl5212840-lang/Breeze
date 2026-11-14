import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/login/login_error_message.dart';

void main() {
  for (final message in [
    '賬號密碼錯誤.',
    '用户名或密码错误',
    'Invalid username or password',
    'email or password not match',
    '账号或密码不匹配',
    'These credentials do not match our records.',
  ]) {
    test('keeps explicit credential rejection: $message', () {
      final error =
          '[bundle:fixture fn:login source:fixture.cjs] $message\n'
          '[stack-hook] at webpack://private.js args:{"password":"fixture"}';
      expect(userFacingLoginErrorMessage(error), t.login.invalidCredentials);
    });
  }
  test(
    'describes client restrictions without repeating server accusations',
    () {
      const error =
          '[bundle:fixture fn:login] 請到官網更新最新APP(https://example.test/) '
          '請下載安裝正版之後等待1小時\n[stack-hook] private diagnostic';
      final message = userFacingLoginErrorMessage(error);
      expect(message, t.login.clientAccessRestricted);
      expect(message, isNot(contains('http')));
      expect(message, isNot(contains('正版')));
    },
  );
  test('preserves network classification and hides unknown diagnostics', () {
    expect(
      userFacingLoginErrorMessage('tls handshake eof\nat internal.js'),
      t.login.networkUnavailable,
    );
    expect(
      userFacingLoginErrorMessage('unknown failure\nat private.js'),
      isNot(contains('private.js')),
    );
  });
  test(
    'does not infer rejected credentials from stack or submitted values',
    () {
      const error = 'unknown failure\nargs:{"password":"invalid credentials"}';
      expect(
        userFacingLoginErrorMessage(error),
        isNot(t.login.invalidCredentials),
      );
    },
  );
  test('HTTP rejection is not proof of a bad password or expired session', () {
    for (final status in [
      'HTTP 401',
      'HTTP 403',
      '{"message":"Request rejected","status":401}',
    ]) {
      expect(userFacingLoginErrorMessage(status), t.login.requestRejected);
      expect(
        userFacingLoginErrorMessage(status),
        isNot(t.login.invalidCredentials),
      );
    }
  });
  test(
    'unknown errors and reflected secrets never become raw UI or credential evidence',
    () {
      for (final error in [
        'private account=short password=x token=y',
        'unknown failure password=invalid credentials',
        'unknown failure\nargs:{"password":"invalid credentials"}',
        '{"message":"unknown failure\\nargs:invalid credentials","password":"invalid credentials"}',
        '{"password":"invalid credentials"}',
      ]) {
        expect(userFacingLoginErrorMessage(error), t.login.unknownFailure);
      }
    },
  );
  test('explicit login attempt limits retain their reason', () {
    for (final message in [
      'Too many requests',
      'Too many attempts',
      'Too many login attempts',
      'Too many sign-in attempts',
    ]) {
      expect(classifyLoginFailure(message), LoginFailureKind.rateLimited);
    }
  });
  test(
    'failed envelopes retain top-level and nested confirmed HTTP statuses',
    () {
      for (final key in ['status', 'code']) {
        for (final status in [400, 401, 403, 429, 500, 599, '429']) {
          for (final nested in [false, true]) {
            final fields = <String, dynamic>{key: status};
            final response = nested
                ? <String, dynamic>{'data': fields}
                : fields;
            expect(
              loginResponseFailure(response),
              status == 429 || status == '429'
                  ? t.login.rateLimited
                  : t.login.requestRejected,
            );
          }
        }
      }
      expect(
        loginResponseFailure({'ok': false, 'status': 429, 'message': ''}),
        t.login.rateLimited,
      );
      expect(
        loginResponseFailure({
          'message': '',
          'data': {
            'success': false,
            'code': 401,
            'message': 'Invalid email or password',
          },
        }),
        t.login.invalidCredentials,
      );
      expect(
        loginResponseFailure({
          'ok': false,
          'status': 429,
          'message': 'unknown failure args:password=private',
        }),
        t.login.rateLimited,
      );
    },
  );
  test('non-HTTP business codes do not acquire a new failure meaning', () {
    for (final status in [0, 1, 200, 399, 600, 401.5, 'code 401', '1', true]) {
      expect(loginResponseFailure({'code': status}), isNull);
      expect(
        loginResponseFailure({
          'data': {'status': status},
        }),
        isNull,
      );
    }
    expect(
      loginResponseFailure({'ok': false, 'code': 1}),
      t.login.unknownFailure,
    );
  });
}
