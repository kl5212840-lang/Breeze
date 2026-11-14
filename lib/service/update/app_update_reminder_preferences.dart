import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/update/app_update_version.dart';

class AppUpdateReminderPreferences {
  AppUpdateReminderPreferences._(this._store);

  static const _enabledKey = 'breeze.appUpdate.reminderEnabled.v1';
  static const _lastCheckKey = 'breeze.appUpdate.lastAutomaticCheck.v1';
  static const _lastNotifiedKey = 'breeze.appUpdate.lastNotifiedVersion.v1';
  static const automaticCheckInterval = Duration(hours: 6);

  final SharedPreferences _store;

  static Future<AppUpdateReminderPreferences> load() async =>
      AppUpdateReminderPreferences._(await SharedPreferences.getInstance());

  bool get enabled => _store.getBool(_enabledKey) ?? true;

  Future<void> setEnabled(bool value) async {
    try {
      if (!await _store.setBool(_enabledKey, value)) {
        throw StateError('Could not save app update reminder preference');
      }
    } catch (_) {
      await _store.reload();
      rethrow;
    }
  }

  Future<bool> beginAutomaticCheck(DateTime now) async {
    if (!enabled) return false;
    final previous = _store.getInt(_lastCheckKey);
    if (previous != null) {
      final elapsed = Duration(
        milliseconds: now.millisecondsSinceEpoch - previous,
      );
      if (!elapsed.isNegative && elapsed < automaticCheckInterval) return false;
    }
    return _store.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
  }

  bool canNotify(AppUpdateVersion version) {
    final previous = AppUpdateVersion.parse(
      _store.getString(_lastNotifiedKey) ?? '',
    );
    return enabled && (previous == null || version.compareTo(previous) > 0);
  }

  Future<bool> markNotified(AppUpdateVersion version) =>
      _store.setString(_lastNotifiedKey, version.toString());
}
