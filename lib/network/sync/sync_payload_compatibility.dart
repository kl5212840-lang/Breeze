import 'package:zephyr/i18n/strings.g.dart';

/// Never include payload values, keys, paths or account details in this error.
class SyncCompatibilityException implements Exception {
  const SyncCompatibilityException();
  @override
  String toString() => t.settings.syncUpdateRequired;
}

abstract final class SyncPayloadCompatibility {
  static void keys(Map data, Iterable<String> supported) {
    final known = supported.toSet();
    if (data.keys.any((key) => key is! String || !known.contains(key))) {
      throw const SyncCompatibilityException();
    }
  }

  static void version(
    Map data,
    String field,
    Set<Object> supported, {
    bool legacyMissing = false,
  }) {
    if (!data.containsKey(field) && legacyMissing) return;
    if (!supported.contains(data[field])) {
      throw const SyncCompatibilityException();
    }
  }

  /// Compare structured host settings to their known serialization contract.
  /// PluginConfig and comic metadata remain opaque strings, never projected.
  static void tree(Object? incoming, Object? supported) {
    if (incoming is! Map || supported is! Map) return;
    keys(incoming, supported.keys.cast<String>());
    for (final key in incoming.keys) {
      tree(incoming[key], supported[key]);
    }
  }
}
