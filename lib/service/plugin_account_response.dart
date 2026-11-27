import 'dart:convert';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/util/json/json_value.dart';

bool _belongsTo(String source, Map<String, dynamic> fields) {
  final declared = fields['source'];
  return declared == null ||
      declared is String &&
          (declared.isEmpty || canonicalQjsSource(declared) == source);
}

void requirePluginAccountResponseSource(
  String source,
  Map<String, dynamic> response,
) {
  final owner = canonicalQjsSource(source);
  if (!_belongsTo(owner, response) ||
      !_belongsTo(owner, asJsonMap(response['data']))) {
    throw const PluginAccountSwitchFailed();
  }
}

/// Account reads have historically returned errors as successful UI bundles.
/// Normalize those responses before any caller displays or verifies a profile.
Map<String, dynamic> readPluginAccountData(
  String source,
  Map<String, dynamic> response,
) {
  final data = asJsonMap(response['data']);
  final lines = asJsonList(data['lines']);
  final owner = canonicalQjsSource(source);
  requirePluginAccountResponseSource(source, response);
  final statusFields = [
    response,
    data,
    for (final member in [
      response['error'],
      response['message'],
      data['error'],
      data['message'],
      data['title'],
      ...lines.take(6),
    ])
      _structuredAccountError(member),
  ];
  var failure = loginResponseFailureKind(response);
  for (final fields in statusFields) {
    if (fields['type'] == 'unauthorized' ||
        fields['status']?.toString().trim() == '401' ||
        fields['code']?.toString().trim() == '401') {
      if (!_belongsTo(owner, fields)) throw const PluginAccountSwitchFailed();
      throw PluginLoginRequiredException(
        UnauthorizedPayload(
          pluginId: owner,
          message: t.navigation.loginExpired,
        ),
      );
    }
    if (fields['type'] == 'error') {
      failure ??= classifyLoginFailure(fields['message'] ?? '');
    }
    failure ??= loginResponseFailureKind(fields);
  }
  final title = data['title'];
  if (title is String && _signedOutTitle.hasMatch(title.trim())) {
    // Some legacy plugins use the same title for transport and auth errors.
    // A text label can offer sign-in, but never authorize replaying a password.
    final diagnostics = [
      ...lines.take(6),
      data['message'],
    ].whereType<String>().map(classifyLoginFailure);
    if (diagnostics.contains(LoginFailureKind.network)) {
      failure = LoginFailureKind.network;
    }
    if (failure == null) throw const PluginAccountNeedsLogin();
  }
  if (failure == LoginFailureKind.network) {
    throw const PluginAccountReadInterrupted();
  }
  if (failure != null) throw const PluginAccountSwitchFailed();

  return {
    ...data,
    if (title is String && _isWireText(title)) 'title': null,
    if (data.containsKey('lines'))
      'lines': lines
          .whereType<String>()
          .where((line) => !_isWireText(line))
          .toList(),
  };
}

class PluginAccountReadInterrupted implements Exception {
  const PluginAccountReadInterrupted();
  @override
  String toString() => 'Account network request failed';
}

final _signedOutTitle = RegExp(
  r'^(?:未登[录錄入]|尚未登[录錄入]|登[录錄入](?:已(?:經|经)?)?(?:失效|[過过]期)|'
  r'请先登录|請先登入|not logged in|signed out|session expired)'
  r'(?:[，,。]\s*(?:请重新登录|請重新登入)?)?$',
  caseSensitive: false,
);

final _wirePrefix = RegExp(
  r'^(?:\[(?:bundle|source):[^\]\r\n]+\]\s*)?(?:Error:\s*)?(?=\{)',
);

bool _isWireText(String value) {
  final text = value.trimLeft();
  return _wirePrefix.hasMatch(text) || text.startsWith('[{');
}

Map<String, dynamic> _structuredAccountError(Object? value) {
  if (value is! String) return asJsonMap(value);
  final text = value.trim().replaceFirst(_wirePrefix, '');
  if (!text.startsWith('{') || text.length > 8192) return const {};
  try {
    return asJsonMap(jsonDecode(text));
  } on FormatException {
    return const {};
  }
}
