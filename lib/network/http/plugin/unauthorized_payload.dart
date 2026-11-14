import 'dart:convert';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/json/json_value.dart';

const _copySource = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
final _legacyCopyMemberUnauthorized = RegExp(
  r'^(?:\[bundle:[^\]\r\n]+\]\s*)?(?:HTTPError: )?'
  r'Request failed with status code 401(?: Unauthorized)?: GET (https://\S+)$',
  caseSensitive: false,
);

// need-login 错误只携带插件身份与提示文案。
// 旧插件可能在错误里附带 scheme/data，解析时直接忽略：
// 登录页统一跳转后再调 getLoginBundle 现取表单。
class UnauthorizedPayload {
  const UnauthorizedPayload({required this.pluginId, required this.message});

  final String pluginId;
  final String message;
}

/// Retains the sign-in requirement after dispatching the navigation event.
/// The message format stays compatible with existing error presentation.
class PluginLoginRequiredException implements Exception {
  const PluginLoginRequiredException(this.payload);

  final UnauthorizedPayload payload;

  @override
  String toString() => 'Exception: ${payload.message}';
}

UnauthorizedPayload? parseUnauthorizedPayload(
  Object error, {
  required String fallbackPluginId,
  String? function,
}) {
  if (error is PluginLoginRequiredException) return error.payload;
  if (error is! AnyhowException) return null;
  final text = error.message.trim().split('\n').first.trimRight();
  // Older Copy bundles throw Ky's raw HTTPError from member/info. Only the
  // actual account endpoint and status authorize this compatibility mapping.
  if (fallbackPluginId == _copySource && function == 'getUserInfoBundle') {
    final match = _legacyCopyMemberUnauthorized.firstMatch(text);
    final url = match == null ? null : Uri.tryParse(match.group(1)!);
    if (url != null &&
        url.host.isNotEmpty &&
        url.path == '/api/v3/member/info') {
      return UnauthorizedPayload(
        pluginId: fallbackPluginId,
        message: t.navigation.loginExpired,
      );
    }
  }
  final regExp = RegExp(
    r'(?:bundle:.*?cjs\]|source:.*?cjs\])\s*(\{.*\})',
    dotAll: true,
  );
  final match = regExp.firstMatch(text);
  final jsonText = match != null ? match.group(1)! : text;
  try {
    final parsed = requireJsonMap(jsonDecode(jsonText));
    if (parsed['type']?.toString() != 'unauthorized') {
      return null;
    }
    final pluginId = parsed['source']?.toString().trim();
    return UnauthorizedPayload(
      pluginId: pluginId?.isNotEmpty == true ? pluginId! : fallbackPluginId,
      message: parsed['message']?.toString().trim().isNotEmpty == true
          ? parsed['message'].toString().trim()
          : '登录过期，请重新登录',
    );
  } catch (_) {
    return null;
  }
}
