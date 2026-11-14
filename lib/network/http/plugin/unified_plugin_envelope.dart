import 'package:zephyr/util/json/json_value.dart';

class UnifiedPluginEnvelope {
  const UnifiedPluginEnvelope({
    required this.source,
    required this.scheme,
    required this.data,
    required this.extern,
  });

  final String source;
  final Map<String, dynamic> scheme;
  final Map<String, dynamic> data;
  final Map<String, dynamic> extern;

  factory UnifiedPluginEnvelope.fromMap(Map<String, dynamic> map) {
    return UnifiedPluginEnvelope(
      source: map['source']?.toString() ?? '',
      scheme: asJsonMap(map['scheme']),
      data: asJsonMap(map['data']),
      extern: asJsonMap(map['extern']),
    );
  }
}

void requireSuccessfulPluginEnvelope(
  Map<String, dynamic> map, {
  String message = '插件返回错误响应',
}) {
  final status = map['status']?.toString().toLowerCase();
  if (map['ok'] == false ||
      map['success'] == false ||
      map['type'] == 'error' ||
      status == 'error' ||
      status == 'failed' ||
      status == 'failure' ||
      _hasError(map['error']) ||
      _hasError(map['errors'])) {
    // Keep upstream details out of diagnostics: they may contain private URLs.
    throw FormatException(message);
  }
}

bool _hasError(dynamic value) {
  if (value == null || value == false) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Map || value is List) return value.isNotEmpty;
  return value != 0;
}
