import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/toast.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
const _jm = '6886291b-f524-441c-844b-c2efae9899a9';

/// This exact legacy Bika+ toast came from auto check-in, including old
/// bundles that emitted it after re-reading an existing check-in.
bool isLegacyBikaAutoCheckinToast(
  Object? runtime,
  Map<String, dynamic> toast,
) =>
    runtime is String &&
    canonicalQjsSource(runtime) == _bika &&
    toast.length == 3 &&
    toast['message'] == '哔咔签到成功' &&
    toast['seconds'] == 3 &&
    toast['level'] == 'success';

/// Device-local receipts and foreground delivery for freshly completed
/// automatic check-ins from the supported plugin runtimes.
class AutoCheckinNotices extends ChangeNotifier {
  AutoCheckinNotices({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static final instance = AutoCheckinNotices();
  static const enabledKey = 'breeze.local.auto-checkin.notices.v1';
  static const receiptKey = 'breeze.local.auto-checkin.receipts.v1';
  static const _maxReceipts = 128;
  static final _accountId = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final enabled = ValueNotifier<bool?>(null);
  final _pending = <String, ({String source, String runtime, String date})>{};
  Future<void>? _tail;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail?.then((_) => operation()) ?? Future.sync(operation);
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return result;
  }

  bool _isEnabled(SharedPreferences preferences) =>
      preferences.get(enabledKey) != false;

  Future<void> load() => _serial(() async {
    enabled.value = _isEnabled(await _preferences());
  });

  Future<void> setEnabled(bool value) => _serial(() async {
    final preferences = await _preferences();
    try {
      if (!await preferences.setBool(enabledKey, value)) {
        throw StateError('Auto check-in preference save failed');
      }
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
    enabled.value = value;
    if (!value) _pending.clear();
  });

  String get _siteDate {
    final date = _now().toUtc().add(const Duration(hours: 8));
    return date.toIso8601String().substring(0, 10);
  }

  Future<String> report(String data) async {
    if (data.length > 1024) return '';
    final String runtime, source, accountId, date;
    try {
      final args = jsonDecode(data);
      if (args is! List || args.length != 2) return '';
      final (name, payload) = (args[0], args[1]);
      if (name is! String || payload is! String) return '';
      runtime = name;
      source = canonicalQjsSource(runtime);
      if (source != _bika && source != _jm) return '';
      final receipt = jsonDecode(payload);
      if (receipt is! Map || receipt.length != 2) return '';
      final (id, siteDay) = (receipt['accountId'], receipt['date']);
      if (id is! String ||
          !_accountId.hasMatch(id) ||
          siteDay is! String ||
          siteDay != _siteDate) {
        return '';
      }
      accountId = id;
      date = siteDay;
    } on FormatException {
      return '';
    }

    final key = sha256
        .convert(utf8.encode(jsonEncode([source, accountId, date])))
        .toString();
    await _serial(() async {
      if (!pluginSessionWriteFence.permits(source, runtime) ||
          date != _siteDate) {
        return;
      }
      final preferences = await _preferences();
      final stored = preferences.get(receiptKey);
      final receipts =
          stored is List<String> && stored.isNotEmpty && stored.first == date
          ? stored.skip(1).toSet()
          : <String>{};
      if (receipts.contains(key) || receipts.length >= _maxReceipts) return;

      // Commit before queuing. A reload, duplicate callback or app restart
      // cannot replay a success that has already been handled on this device.
      try {
        if (!await preferences.setStringList(receiptKey, [
          date,
          ...receipts,
          key,
        ])) {
          throw StateError('Auto check-in receipt save failed');
        }
      } catch (_) {
        await preferences.reload();
        rethrow;
      }
      if (!_isEnabled(preferences) ||
          date != _siteDate ||
          !pluginSessionWriteFence.permits(source, runtime)) {
        return;
      }
      _pending.removeWhere((_, receipt) => receipt.date != date);
      _pending[key] = (source: source, runtime: runtime, date: date);
      notifyListeners();
    });
    return '';
  }

  /// Called only when the main navigation has a live foreground overlay.
  List<ToastEvent> takePending() {
    final date = _siteDate;
    final chinese = LocaleSettings.currentLocale.languageCode == 'zh';
    final notices = [
      for (final entry in _pending.entries)
        if (entry.value.date == date &&
            pluginSessionWriteFence.permits(
              entry.value.source,
              entry.value.runtime,
            ))
          ToastEvent(
            type: ToastType.success,
            message: t.notification.autoCheckinCompleted(
              source: entry.value.source == _bika
                  ? (chinese ? '哔咔＋' : 'Bika+')
                  : (chinese ? '禁漫＋' : 'JM+'),
            ),
            duration: const Duration(seconds: 3),
            deduplicationKey: entry.key,
          ),
    ];
    _pending.clear();
    return notices;
  }

  @override
  void dispose() {
    enabled.dispose();
    super.dispose();
  }
}
