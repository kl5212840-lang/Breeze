import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';

/// Portable sign-in details belong to the installed plugin's own namespace.
class VideoAccountCredentials {
  const VideoAccountCredentials(this.account, this.password, this.origin);
  final String account, password;
  final Uri origin;

  static const key = 'account.credentials';

  static bool validOrigin(Uri uri) =>
      uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;

  static VideoAccountCredentials? decode(Object? value, Uri home) {
    if (!validOrigin(home) ||
        value is! Map ||
        value['version'] != 1 ||
        value['deleted'] != false ||
        value['account'] is! String ||
        value['password'] is! String ||
        value['origin'] is! String) {
      return null;
    }
    final origin = Uri.tryParse(value['origin'] as String);
    final account = value['account'] as String,
        password = value['password'] as String;
    if (origin == null ||
        !validOrigin(origin) ||
        origin.origin != home.origin ||
        origin.toString() != origin.origin ||
        account.trim().isEmpty ||
        password.isEmpty) {
      return null;
    }
    return VideoAccountCredentials(account, password, origin);
  }

  static VideoAccountCredentials? load(String source, Uri home) {
    try {
      return decode(
        loadPluginConfigValue<Map>(source, key, fallback: const {}),
        home,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String source,
    Uri home,
    String account,
    String password,
  ) async {
    if (source.trim().isEmpty ||
        !validOrigin(home) ||
        account.trim().isEmpty ||
        password.isEmpty) {
      return;
    }
    final snapshot = <String, dynamic>{
      'version': 1,
      'account': account.trim(),
      'password': password,
      'origin': home.origin,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'deleted': false,
    };
    // Preflight future formats before changing the legacy active projection.
    PluginAccountProfiles.read(source);
    await savePluginConfigValue(source, key, snapshot);
    await PluginAccountProfiles.rememberCredentials(source, snapshot);
  }

  static Future<void> clear(String source, Uri home) async {
    if (source.trim().isEmpty || !validOrigin(home)) return;
    await savePluginConfigValue(source, key, {
      'version': 1,
      'origin': home.origin,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'deleted': true,
    });
  }
}
