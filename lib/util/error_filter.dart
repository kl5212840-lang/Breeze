import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:logger/logger.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:zephyr/i18n/strings.g.dart';

bool shouldIgnoreError(dynamic error) {
  final errorStr = error.toString();
  if (error is PathNotFoundException ||
      errorStr.contains('PathNotFoundException') ||
      errorStr.contains('Cannot retrieve length of file') ||
      errorStr.contains('No such file or directory')) {
    return true;
  }
  return false;
}

class TersePrettyPrinter extends PrettyPrinter {
  TersePrettyPrinter({
    super.methodCount = 2,
    super.errorMethodCount = 8,
    super.lineLength = 120,
    super.colors = true,
    super.printEmojis = true,
    super.dateTimeFormat = DateTimeFormat.onlyTimeAndSinceStart,
  });

  @override
  String? formatStackTrace(StackTrace? stackTrace, int? methodCount) {
    if (stackTrace == null) return null;

    // 使用 stack_trace 库的 terse 过滤掉非项目代码的冗余帧
    var terseTrace = Trace.from(stackTrace).terse;

    // 将过滤后的 Trace 转换回符合 logger 格式的行列表
    return super.formatStackTrace(
      StackTrace.fromString(terseTrace.toString()),
      methodCount,
    );
  }
}

String normalizeSearchErrorMessage(Object error) {
  final message = switch (error) {
    AnyhowException(message: final message) => message.trim(),
    _ => error.toString().trim(),
  };
  // Dart 侧 StateError.toString() 会带上 `Bad state: ` 前缀，直接展示会让用户困惑；
  // 与 plugin_cloud_download_utils 的 _rawPluginErrorText 保持一致，展示前剥掉。
  var result = message;
  const prefixes = ['Bad state: ', 'Exception: '];
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (result.startsWith(prefix)) {
        result = result.substring(prefix.length).trim();
        changed = true;
        break;
      }
    }
  }
  if (result.isNotEmpty) {
    return result;
  }
  return t.error.executionFailed;
}

/// Keep plugin/runtime diagnostics in logs, never in an end-user error view.
bool isTransientNetworkError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('tls handshake') ||
      text.contains('connection reset') ||
      text.contains('connection refused') ||
      text.contains('connection closed') ||
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network error') ||
      text.contains('network request failed') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('connectexception');
}

String userFacingErrorMessage(Object error) {
  if (error is FormatException &&
      error.message.isNotEmpty &&
      error.message.length <= 80 &&
      !error.message.contains('\n') &&
      !error.message.contains('://')) {
    return error.message;
  }
  final text = normalizeSearchErrorMessage(error);
  final lower = text.toLowerCase();
  if (isTransientNetworkError(text)) {
    return '连接暂时中断，请检查网络或切换插件线路后重试';
  }
  if (lower.contains('401') ||
      lower.contains('unauthorized') ||
      lower.contains('登录已失效') ||
      lower.contains('请先登录')) {
    return '登录状态可能已失效，请重新登录后重试';
  }
  if (lower.contains('404') || lower.contains('not found')) {
    return '内容暂时无法访问，请稍后重试';
  }
  // Runtime traces and wrapped request payloads can be enormous and may
  // contain URLs or other internal details. Never pass them to Text widgets.
  if (text.length > 160 ||
      text.contains('\n') ||
      lower.contains('[bundle:') ||
      lower.contains('[stack-hook]') ||
      lower.contains('webpack:') ||
      lower.contains('http://') ||
      lower.contains('https://') ||
      lower.contains('typeerror:') ||
      lower.contains('referenceerror:') ||
      lower.contains('platformexception') ||
      lower.contains('formatexception') ||
      lower.contains('node_modules') ||
      lower.contains('args:') ||
      lower.contains(' at ') ||
      lower.contains('http 请求失败')) {
    return '加载失败，请稍后重试';
  }
  return text;
}
