import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';

void main() {
  test('hides plugin stack trace for a request timeout', () {
    final error = Exception(
      '[bundle:example fn:getFunctionPage] timeout of 10000ms exceeded\n'
      '[stack-hook] Error: timeout of 10000ms exceeded',
    );
    expect(pluginFunctionErrorMessage(error), t.sourceShell.requestTimedOut);
  });

  test('hides an otherwise unknown plugin stack trace', () {
    expect(
      pluginFunctionErrorMessage(
        Exception('load failed\ninternal stack frame'),
      ),
      '加载失败，请稍后重试',
    );
  });

  test('shows a short login action for a plugin credential error', () {
    final error = Exception('需要登录，请在设置中填写账号密码');
    expect(pluginFunctionNeedsLogin(error), isTrue);
    expect(pluginFunctionErrorMessage(error), t.navigation.needLoginTitle);
  });

  test('does not mistake a network error for a login requirement', () {
    expect(pluginFunctionNeedsLogin(Exception('连接超时')), isFalse);
  });
}
