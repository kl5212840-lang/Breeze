import 'dart:convert';

import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/util/json/json_value.dart';

// Capability discovery must not emit NeedLogin and gate unrelated content.
// Actual user tasks retain callUnifiedComicPlugin's authentication handling.
Future<Map<String, dynamic>> _readBundle(String source, String function) async {
  final pluginId = normalizePluginId(source);
  final result = await executeQjsCall(
    pluginId: pluginId,
    runtimeName: pluginId,
    fnPath: function,
    argsJson: jsonEncode({'extern': <String, dynamic>{}}),
  );
  return requireJsonMap(
    jsonDecode(result),
    message: 'Invalid capability bundle',
  );
}

/// Explicit settings declarations win; older schemas keep their successful
/// getLoginBundle capability probe. This is a transient read, never a config.
Future<bool> resolvePluginLoginSupported(
  String source, {
  Map<String, dynamic>? settingsData,
}) async {
  var data = settingsData;
  if (data == null) {
    try {
      data = UnifiedPluginEnvelope.fromMap(
        await _readBundle(source, 'getSettingsBundle'),
      ).data;
    } catch (_) {
      // Legacy sources can expose login without a settings bundle.
    }
  }
  if (data?.containsKey('canLogin') == true) return data!['canLogin'] == true;
  try {
    await _readBundle(source, 'getLoginBundle');
    return true;
  } catch (_) {
    return false;
  }
}
