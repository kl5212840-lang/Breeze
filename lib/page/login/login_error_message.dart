import 'dart:convert';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/util/error_filter.dart';

enum LoginFailureKind {
  credentials,
  verification,
  rateLimited,
  clientRestricted,
  accountRestricted,
  network,
  rejected,
  unknown,
}

/// Only a reason field or the first runtime error line is classified. Submitted
/// arguments, response bodies and stack frames never become a displayed reason.
String _reason(Object error) {
  var line = normalizeSearchErrorMessage(error).split(RegExp(r'[\r\n]')).first;
  line = line
      .split(
        RegExp(r'\[stack-hook\]|\bargs\s*:|\bconfig\s*:', caseSensitive: false),
      )
      .first;
  line = line.replaceFirst(RegExp(r'^\[(?:bundle|source):[^\]]*\]\s*'), '');
  line = line
      .replaceFirst(RegExp(r'^(?:Error|Exception|JmRequestError):\s*'), '')
      .trim();
  if (line.startsWith('{') || line.startsWith('[')) {
    try {
      final raw = jsonDecode(line);
      if (raw is! Map) return '';
      final nested = raw['data'] is Map ? raw['data'] as Map : const {};
      final error = raw['error'] is Map ? raw['error'] as Map : const {};
      final messages = [
        raw['message'],
        raw['errorMsg'],
        nested['message'],
        error['message'],
      ];
      final message = messages.whereType<String>().firstOrNull ?? '';
      final status = raw['status'] ?? raw['code'];
      final reason = message
          .split(
            RegExp(r'[\r\n]|\[stack-hook\]|\bargs\s*:', caseSensitive: false),
          )
          .first;
      final publicReason = reason
          .split(
            RegExp(
              r'\b(?:password|passwd|token|authorization|cookie|username|account)\s*[=:]',
              caseSensitive: false,
            ),
          )
          .first;
      return '$publicReason ${status is num ? 'HTTP $status' : ''}'.trim();
    } catch (_) {
      return '';
    }
  }
  return line
      .split(
        RegExp(
          r'\b(?:password|passwd|token|authorization|cookie|username|account)\s*[=:]',
          caseSensitive: false,
        ),
      )
      .first;
}

LoginFailureKind classifyLoginFailure(Object error) {
  final text = _reason(error).toLowerCase();
  bool matches(String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
  if (matches(
    r'验证码|驗證碼|captcha|turnstile|cloudflare|人机验证|人機驗證|two.factor|verification (?:required|failed)|verify (?:your )?(?:email|account)|email (?:is )?not verified',
  )) {
    return LoginFailureKind.verification;
  }
  if (matches(
    r'(?:http\s*|status(?:\s+code)?\s*[:=]?\s*)429\b|too many (?:(?:login|sign[ -]?in) )?(?:requests|attempts)|rate.limit|请求.{0,8}频繁|請求.{0,8}頻繁|尝试.{0,8}频繁|嘗試.{0,8}頻繁',
  )) {
    return LoginFailureKind.rateLimited;
  }
  if (matches(
    r'(?:官网|官網).{0,20}更新.{0,20}(?:app|客户端|客戶端)|(?:客户端|客戶端|设备|裝置|device|client).{0,25}(?:限制|不支持|restricted|blocked|not allowed)|unsupported client|client access restricted|限制.{0,8}(?:客户端|客戶端)',
  )) {
    return LoginFailureKind.clientRestricted;
  }
  if (matches(
    r'(?:账号|帳號|賬號|账户|帳戶|用户|用戶|account).{0,20}(?:停用|封禁|封鎖|冻结|凍結|disabled|suspended|banned|locked)',
  )) {
    return LoginFailureKind.accountRestricted;
  }
  if (matches(
    r'(?:账号|帳號|賬號|用户名|用戶名|邮箱|郵箱|username|email).{0,20}(?:密码|密碼|password).{0,16}(?:错误|錯誤|有误|有誤|不正确|不正確|不匹配|incorrect|invalid|not match|mismatch)|(?:invalid|incorrect|wrong) (?:credentials|(?:username|email) or password)|账号不存在|帳號不存在|用户名不存在|用戶名不存在|password (?:is )?(?:incorrect|invalid|wrong)|credentials (?:do not|don.t) match',
  )) {
    return LoginFailureKind.credentials;
  }
  if (isTransientNetworkError(text) ||
      matches(
        r'网络.{0,6}(?:失败|错误|中断)|網路.{0,6}(?:失敗|錯誤|中斷)|连接.{0,6}(?:超时|失败|中断)|連線.{0,6}(?:逾時|失敗|中斷)|无法连接|無法連線',
      )) {
    return LoginFailureKind.network;
  }
  // HTTP 401/403 alone does not prove a bad password or an expired session.
  if (matches(
    r'(?:http\s*|status(?:\s+code)?\s*[:=]?\s*)[45]\d\d\b|unauthorized|forbidden|登录.{0,3}失效|登入.{0,3}失效|请先登录|請先登入|not authenticated',
  )) {
    return LoginFailureKind.rejected;
  }
  return LoginFailureKind.unknown;
}

LoginFailureKind loginFailureKindFromCode(String? code) =>
    LoginFailureKind.values.where((kind) => kind.name == code).firstOrNull ??
    LoginFailureKind.unknown;

/// Fixed, localized text prevents credentials, URLs or arbitrary plugin/runtime
/// diagnostics from leaking through even when the server echoes submitted data.
String userFacingLoginErrorMessage(Object error) =>
    userFacingLoginFailureMessage(classifyLoginFailure(error));

String userFacingLoginFailureMessage(LoginFailureKind kind) => switch (kind) {
  LoginFailureKind.credentials => t.login.invalidCredentials,
  LoginFailureKind.verification => t.login.verificationRequired,
  LoginFailureKind.rateLimited => t.login.rateLimited,
  LoginFailureKind.clientRestricted => t.login.clientAccessRestricted,
  LoginFailureKind.accountRestricted => t.login.accountRestricted,
  LoginFailureKind.network => t.login.networkUnavailable,
  LoginFailureKind.rejected => t.login.requestRejected,
  LoginFailureKind.unknown => t.login.unknownFailure,
};

int? _httpFailureStatus(Object? value) {
  int? status;
  if (value is num && value.isFinite && value == value.toInt()) {
    status = value.toInt();
  } else if (value is String &&
      RegExp(r'^[45][0-9]{2}$').hasMatch(value.trim())) {
    status = int.parse(value.trim());
  }
  return status != null && status >= 400 && status <= 599 ? status : null;
}

String? loginResponseFailure(Map<String, dynamic> response) {
  final kind = loginResponseFailureKind(response);
  return kind == null ? null : userFacingLoginFailureMessage(kind);
}

/// Legacy plugins can return a rejected envelope or an HTTP status without
/// throwing. Keep the complete top-level map: the envelope does not relocate
/// its status/code into data. Other business codes retain their old meaning.
LoginFailureKind? loginResponseFailureKind(Map<String, dynamic> response) {
  final data = UnifiedPluginEnvelope.fromMap(response).data;
  bool failed(Map value) =>
      value['ok'] == false ||
      value['success'] == false ||
      value['status'] == 'error' ||
      value['status'] == 'failed';
  final statuses = [
    response['status'],
    response['code'],
    data['status'],
    data['code'],
  ].map(_httpFailureStatus).whereType<int>().toSet();
  if (!failed(response) && !failed(data) && statuses.isEmpty) return null;
  final outerError = response['error'] is Map
      ? response['error'] as Map
      : const {};
  final innerError = data['error'] is Map ? data['error'] as Map : const {};
  final message =
      [
            response['message'],
            data['message'],
            outerError['message'],
            innerError['message'],
            response['error'],
            data['error'],
          ]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .firstOrNull ??
      '';
  var kind = classifyLoginFailure(message);
  // Preserve confirmed rate limiting even when no public message survived.
  // An explicit verification reason can still explain a site's challenge.
  if (statuses.contains(429) && kind != LoginFailureKind.verification) {
    kind = LoginFailureKind.rateLimited;
  } else if (kind == LoginFailureKind.unknown && statuses.isNotEmpty) {
    kind = LoginFailureKind.rejected;
  }
  return kind;
}
