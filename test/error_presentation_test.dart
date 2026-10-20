import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/util/error_filter.dart';

void main() {
  test('hides TLS and plugin stack details from readers', () {
    const error =
        '[bundle:plugin fn:getReadSnapshot args:{"comicId":"secret"}] '
        '发送 HTTP 请求失败: client error (Connect): tls handshake eof\n'
        '[stack-hook] at webpack:/node_modules/axios/core.js';
    expect(isTransientNetworkError(error), isTrue);
    final message = userFacingErrorMessage(error);
    expect(message, contains('连接暂时中断'));
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('webpack')));
  });

  test('keeps short actionable validation errors', () {
    expect(userFacingErrorMessage(const FormatException('头像图片过大')), '头像图片过大');
  });

  test('does not expose unknown multiline runtime diagnostics', () {
    expect(
      userFacingErrorMessage('request failed\nat internal.js:10'),
      '加载失败，请稍后重试',
    );
  });
}
