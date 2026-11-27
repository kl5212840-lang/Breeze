import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/temporary_data_cache.dart';

/// Short-lived, memory-only snapshots of successfully decoded JM account rows.
class JmAccountReadCache<T> implements TemporaryDataCache {
  JmAccountReadCache() {
    TemporaryDataCaches.register(this);
    pluginSessionWriteFence.changes.listen((change) {
      if (change.source == cacheSource) clearTemporaryData();
    });
    PluginAccountIdentities.changes.listen((source) {
      if (source != cacheSource) return;
      final account = PluginAccountIdentities.current(source);
      final owner = (account?.serverIdentity, account?.origin);
      if (_owner != owner) _generation++;
      _owner = owner;
      _rows.removeWhere(
        (key, _) =>
            key.$1 != account?.serverIdentity || key.$2 != account?.origin,
      );
    });
  }

  final _rows = <(String, String, String), ({T data, DateTime time})>{};
  (String?, String?)? _owner;
  int _generation = 0;
  int get generation => _generation;

  @override
  String get cacheSource => PluginAccountAuthenticationService.jm;

  @override
  int get cacheEntryCount => _rows.length;

  @override
  void clearTemporaryData() {
    _generation++;
    _rows.clear();
  }

  (String, String, String)? _key(String source, String? account, String kind) {
    if (source != cacheSource || account == null || account.isEmpty) {
      return null;
    }
    final owner = PluginAccountIdentities.current(source);
    return owner != null && owner.serverIdentity == account
        ? (account, owner.origin, kind)
        : null;
  }

  ({T data, DateTime time})? read(String source, String? account, String kind) {
    final key = _key(source, account, kind);
    final row = _rows[key];
    final age = row == null ? null : DateTime.now().difference(row.time);
    if (age != null && (age.isNegative || age >= const Duration(minutes: 10))) {
      _rows.remove(key);
      return null;
    }
    return row;
  }

  void write(String source, String? account, String kind, T data, int epoch) {
    if (epoch != generation) return;
    final key = _key(source, account, kind);
    if (key != null) _rows[key] = (data: data, time: DateTime.now());
  }

  void remove(String source, String? account, String kind) {
    final key = _key(source, account, kind);
    if (key == null) return;
    _generation++;
    _rows.remove(key);
  }
}
