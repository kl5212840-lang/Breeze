import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart'
    show canonicalQjsSource;

/// Per-installation defaults for new remote search tasks. Explicit requests
/// and stored searches keep their own scope.
abstract final class SearchScopePreferences {
  static const comic = 'comic';
  static const video = 'video';
  static const aggregate = 'aggregate';
  static const _prefix = 'breeze.search.default-scope.v1.';

  static String? _key(String? source, String surface) {
    if (surface == aggregate && source == null) return '$_prefix$aggregate';
    if (surface != comic && surface != video || source == null) return null;
    final id = canonicalQjsSource(source.trim());
    if (id.isEmpty) return null;
    return '$_prefix$surface.${Uri.encodeComponent(id)}';
  }

  static Future<String?> read({String? source, required String surface}) async {
    final key = _key(source, surface);
    if (key == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  static Future<void> save({
    String? source,
    required String surface,
    required String value,
    required Iterable<String> supported,
  }) async {
    final key = _key(source, surface);
    if (key == null || value.isEmpty || !supported.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported search scope');
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, value)) {
      throw StateError('Could not save search default');
    }
  }
}
