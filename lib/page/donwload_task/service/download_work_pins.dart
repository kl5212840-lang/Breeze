import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';

String downloadWorkPinKey(DownloadCenterItem item) =>
    downloadVideoWorkIdentity(item)?.key ?? item.key;

/// Device-only presentation order, excluded from portable/cloud preferences.
/// Never changes queue priority, task state, or the order of chapters.
class DownloadWorkPins {
  static const storageKey = 'breeze.local.download-work-pins.v1';
  static final changes = ValueNotifier<int>(0);
  static Future<void>? _writes;

  static Map<String, int> _decode(String? raw) {
    try {
      if (raw == null || raw.length > 1024 * 1024) return {};
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 1 || value['pins'] is! Map) {
        return {};
      }
      return {
        for (final entry in (value['pins'] as Map).entries)
          if (entry.key is String &&
              (entry.key as String).isNotEmpty &&
              (entry.key as String).length <= 2048 &&
              entry.value is int &&
              (entry.value as int) > 0)
            entry.key as String: entry.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, int>> read() async {
    await _writes;
    return _decode(
      (await SharedPreferences.getInstance()).getString(storageKey),
    );
  }

  static Future<void> _change(bool Function(Map<String, int>) update) {
    final operation = (_writes ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(storageKey);
      final pins = _decode(before);
      if (!update(pins)) return;
      final encoded = jsonEncode({'version': 1, 'pins': pins});
      if (encoded == before) return;
      if (encoded.length > 1024 * 1024) {
        throw StateError('download_work_pins_too_large');
      }
      try {
        if (!await prefs.setString(storageKey, encoded)) {
          throw StateError('download_work_pin_save_failed');
        }
      } catch (_) {
        // The legacy API updates its cache before asking the platform to save.
        try {
          if (before == null) {
            await prefs.remove(storageKey);
          } else {
            await prefs.setString(storageKey, before);
          }
        } catch (_) {
          // The rollback has already restored the cache synchronously.
        }
        rethrow;
      }
      changes.value++;
    });
    late final Future<void> tail;
    tail = operation.catchError((Object _) {}).whenComplete(() {
      if (identical(_writes, tail)) _writes = null;
    });
    _writes = tail;
    return operation;
  }

  static Iterable<String> _aliases(DownloadCenterItem item) sync* {
    yield item.key;
    if (downloadVideoWorkIdentity(item) case final identity?) {
      yield identity.key;
    }
  }

  static int? rankFor(DownloadCenterItem item, Map<String, int> pins) {
    var highest = 0;
    for (final alias in _aliases(item)) {
      final rank = pins[alias] ?? 0;
      if (rank > highest) highest = rank;
    }
    return highest == 0 ? null : highest;
  }

  static Future<void> setPinnedItems(
    Iterable<DownloadCenterItem> items,
    bool pinned,
  ) {
    final aliases = items.expand(_aliases).toSet();
    if (aliases.isEmpty) return Future.value();
    return _change((pins) {
      final ranks = aliases.map((alias) => pins[alias]).nonNulls.toSet();
      if (!pinned) {
        if (ranks.isEmpty) return false;
        pins.removeWhere((_, rank) => ranks.contains(rank));
        return true;
      }
      var rank = ranks.fold(0, (a, b) => a > b ? a : b);
      if (rank == 0) {
        rank = DateTime.now().microsecondsSinceEpoch;
        for (final existing in pins.values) {
          if (existing >= rank) rank = existing + 1;
        }
      }
      pins.updateAll(
        (_, existing) => ranks.contains(existing) ? rank : existing,
      );
      for (final alias in aliases) {
        pins[alias] = rank;
      }
      return true;
    });
  }

  static Future<void> forget(String exactAlias) => _change((pins) {
    final rank = pins[exactAlias];
    if (rank == null) return false;
    pins.removeWhere((_, value) => value == rank);
    return true;
  });

  /// Reconcile only against the current complete, unfiltered inventory. The
  /// callback runs inside the write queue so older evidence cannot prune a pin.
  static Future<void> reconcile(
    List<DownloadCenterItem>? Function() readCurrent, {
    ({String alias, int rank})? removedPin,
  }) => _change((pins) {
    if (pins.isEmpty) return false;
    if (removedPin != null && pins[removedPin.alias] != removedPin.rank) {
      return false;
    }
    final all = readCurrent();
    if (all == null) return false;
    final byWork = <String, Set<String>>{};
    for (final item in all) {
      final work = downloadVideoWorkIdentity(item)?.key ?? item.key;
      (byWork[work] ??= {work}).add(item.key);
    }
    final byRank = <int, Set<String>>{};
    for (final entry in pins.entries) {
      (byRank[entry.value] ??= {}).add(entry.key);
    }
    for (final aliases in byWork.values) {
      final ranks = aliases.map((alias) => pins[alias]).nonNulls.toSet();
      if (ranks.isEmpty) continue;
      final newest = ranks.reduce((a, b) => a > b ? a : b);
      final merged = byRank[newest]!;
      for (final rank in ranks) {
        if (rank != newest) merged.addAll(byRank.remove(rank)!);
      }
      merged.addAll(aliases);
      for (final alias in merged) {
        pins[alias] = newest;
      }
    }
    final liveRanks = byWork.values
        .expand((aliases) => aliases)
        .map((alias) => pins[alias])
        .nonNulls
        .toSet();
    final removedRank = removedPin == null ? null : pins[removedPin.alias];
    pins.removeWhere(
      (_, rank) =>
          !liveRanks.contains(rank) &&
          (removedPin == null || rank == removedRank),
    );
    return true;
  });

  static List<DownloadCenterDisplayItem> arrange(
    List<DownloadCenterDisplayItem> rows,
    Map<String, int> pins,
  ) {
    if (pins.isEmpty) return rows;
    final indexed = [
      for (final (index, row) in rows.indexed)
        (
          index: index,
          row: row,
          rank: (row.work?.episodes ?? [row.item]).fold<int>(0, (rank, item) {
            final candidate = rankFor(item, pins) ?? 0;
            return candidate > rank ? candidate : rank;
          }),
        ),
    ];
    indexed.sort((a, b) {
      final pinnedOrder = b.rank.compareTo(a.rank);
      return pinnedOrder != 0 ? pinnedOrder : a.index.compareTo(b.index);
    });
    return [for (final entry in indexed) entry.row];
  }
}
