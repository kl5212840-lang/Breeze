import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_follow/comic_follow_navigation.dart';
import 'package:zephyr/widgets/toast.dart';

enum ComicFollowReminderMode { silent, badge, inApp }

/// These are device-owned attention preferences, never account/cloud settings.
/// No permission request, OS notification or background task belongs here.
class ComicFollowReminderController {
  ComicFollowReminderController({
    Future<SharedPreferences> Function()? preferences,
    void Function(ToastEvent)? emit,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _emit = emit ?? eventBus.fire;

  static final instance = ComicFollowReminderController();
  static const modeKey = 'breeze.local.comic-follow.reminder-mode.v1';
  static const seenKey = 'breeze.local.comic-follow.reminder-seen.v1';
  static const maximumReceipts = 4096;
  static const maximumReceiptBytes = 512 * 1024;
  final Future<SharedPreferences> Function() _preferences;
  final void Function(ToastEvent) _emit;
  final mode = ValueNotifier<ComicFollowReminderMode?>(null);
  Future<void>? _loading;
  Future<void> _tail = Future.value();

  bool get showsBadge =>
      mode.value != null && mode.value != ComicFollowReminderMode.silent;

  Future<void> load() {
    if (mode.value != null) return Future.value();
    return _loading ??= (() async {
      final preferences = await _preferences();
      final stored = preferences.get(modeKey);
      final name = stored is String ? stored : null;
      mode.value = ComicFollowReminderMode.values.firstWhere(
        (value) => value.name == name,
        orElse: () => ComicFollowReminderMode.badge,
      );
    })().whenComplete(() => _loading = null);
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final work = _tail.then((_) => operation());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<void> setMode(ComicFollowReminderMode value) => _serial(() async {
    await load();
    if (value == mode.value) return;
    final preferences = await _preferences();
    try {
      if (!await preferences.setString(modeKey, value.name)) {
        throw StateError('Reminder mode save failed');
      }
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
    mode.value = value;
  });

  Map<String, int> _readSeen(SharedPreferences preferences) {
    final stored = preferences.get(seenKey);
    if (stored is! String || stored.length > maximumReceiptBytes) return {};
    final raw = stored;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded.length > maximumReceipts) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String &&
              (entry.key as String).length <= 2048 &&
              entry.value is int &&
              (entry.value as int) >= 0)
            entry.key as String: entry.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  /// [updates] contains only successful, newly observed unread chapter growth.
  /// A persisted high-water receipt prevents repeat notices after restart or a
  /// source briefly returning a smaller chapter list. Lists keep the real count.
  /// Revalidate [canDeliver] before recording and after saving the receipt:
  /// the work may be read or removed, or the app may leave the foreground.
  Future<void> notifyUpdates(
    Map<String, int> updates, {
    bool Function(String key, int chapterCount)? canDeliver,
  }) => _serial(() async {
    if (updates.isEmpty) return;
    await load();
    final preferences = await _preferences();
    final seen = _readSeen(preferences);
    final fresh = <String, int>{};
    for (final entry in updates.entries) {
      if (entry.key.isEmpty ||
          entry.key.length > 2048 ||
          entry.value <= 0 ||
          entry.value <= (seen[entry.key] ?? 0) ||
          canDeliver?.call(entry.key, entry.value) == false) {
        continue;
      }
      fresh[entry.key] = entry.value;
      seen.remove(entry.key);
      seen[entry.key] = entry.value;
    }
    if (fresh.isEmpty) return;
    final costs = <String, int>{};
    var size = 2;
    for (final entry in seen.entries) {
      final cost = utf8.encode(jsonEncode({entry.key: entry.value})).length - 2;
      size += cost + (costs.isEmpty ? 0 : 1);
      costs[entry.key] = cost;
    }
    while ((seen.length > maximumReceipts || size > maximumReceiptBytes) &&
        seen.isNotEmpty) {
      final first = seen.keys.first;
      size -= costs[first]! + (seen.length > 1 ? 1 : 0);
      seen.remove(first);
    }
    final encoded = jsonEncode(seen);
    // Commit a receipt before showing a transient notice, so a repeated read
    // cannot create another notification. A failure keeps the list's unread state.
    try {
      if (!await preferences.setString(seenKey, encoded)) {
        throw StateError('Reminder receipt save failed');
      }
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
    if (mode.value != ComicFollowReminderMode.inApp) return;
    if (canDeliver != null) {
      fresh.removeWhere((key, count) => !canDeliver(key, count));
    }
    if (fresh.isEmpty) return;
    final count = fresh.length;
    _emit(
      ToastEvent(
        type: ToastType.info,
        title: t.comicFollow.updateTitle,
        message: count == 1
            ? t.comicFollow.updatedComicsSingle
            : t.comicFollow.updatedComicsMultiple(count: count),
        duration: const Duration(seconds: 4),
        actionLabel: t.followReminders.openFollowing,
        onTap: () async {
          await ComicFollowNavigation.open();
        },
      ),
    );
  });

  void dispose() => mode.dispose();
}
