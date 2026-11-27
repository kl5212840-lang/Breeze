import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoLineResolutionOutcome { resolved, failed, timedOut }

typedef VideoLineResolutionSample = ({
  Duration elapsed,
  VideoLineResolutionOutcome outcome,
});

/// Resolver readback is device-local and has no authority over playback.
final class VideoLineResolutionMeasurements extends ChangeNotifier {
  VideoLineResolutionMeasurements({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final shared = VideoLineResolutionMeasurements();
  static const storageKey = 'breeze.video.line-resolution.v1';
  static const _limit = 96;
  final DateTime Function() _now;
  final _rows = <String, ({int at, VideoLineResolutionSample sample})>{};
  Future<void>? _loading;
  Future<void>? _writes;
  bool _loaded = false;

  static String key({
    required String source,
    required String work,
    required String episode,
    required String line,
    required String route,
  }) => sha256
      .convert(utf8.encode(jsonEncode([source, work, episode, line, route])))
      .toString();

  bool _fresh(int at, VideoLineResolutionOutcome outcome) {
    final age = _now().millisecondsSinceEpoch - at;
    final ttl = Duration(
      minutes: outcome == VideoLineResolutionOutcome.resolved ? 10 : 2,
    ).inMilliseconds;
    return age >= 0 && age < ttl;
  }

  VideoLineResolutionSample? read(String key) {
    final row = _rows[key];
    return row != null && _fresh(row.at, row.sample.outcome)
        ? row.sample
        : null;
  }

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.length > 32 * 1024) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final validKey = RegExp(r'^[a-f0-9]{64}$');
      for (final entry in decoded.entries) {
        final key = entry.key, row = entry.value;
        if (key is! String ||
            !validKey.hasMatch(key) ||
            row is! List ||
            row.length != 3) {
          continue;
        }
        final at = row[0], elapsed = row[1];
        final outcome = switch (row[2]) {
          true => VideoLineResolutionOutcome.resolved,
          false => VideoLineResolutionOutcome.failed,
          'timeout' => VideoLineResolutionOutcome.timedOut,
          _ => null,
        };
        if (at is int &&
            elapsed is int &&
            elapsed >= 0 &&
            elapsed <= 120000 &&
            outcome != null &&
            _fresh(at, outcome)) {
          _rows[key] = (
            at: at,
            sample: (
              elapsed: Duration(milliseconds: elapsed),
              outcome: outcome,
            ),
          );
        }
      }
      _trim();
      if (_rows.isNotEmpty) notifyListeners();
    } catch (_) {
      // A missing local measurement has no effect on playback.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  void _trim() {
    _rows.removeWhere((_, row) => !_fresh(row.at, row.sample.outcome));
    if (_rows.length <= _limit) return;
    final oldest = _rows.keys.toList()
      ..sort((a, b) => _rows[a]!.at.compareTo(_rows[b]!.at));
    for (final key in oldest.take(_rows.length - _limit)) {
      _rows.remove(key);
    }
  }

  Future<void> record(String key, VideoLineResolutionSample sample) async {
    if (!_loaded) await load();
    _rows[key] = (at: _now().millisecondsSinceEpoch, sample: sample);
    _trim();
    notifyListeners();
    final pending = (_writes ?? Future<void>.value()).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          storageKey,
          jsonEncode({
            for (final entry in _rows.entries)
              entry.key: [
                entry.value.at,
                entry.value.sample.elapsed.inMilliseconds,
                switch (entry.value.sample.outcome) {
                  VideoLineResolutionOutcome.resolved => true,
                  VideoLineResolutionOutcome.failed => false,
                  VideoLineResolutionOutcome.timedOut => 'timeout',
                },
              ],
          }),
        );
      } catch (_) {
        // Keep this visit's display sample even if the cache cannot be saved.
      }
    });
    _writes = pending;
    try {
      await pending;
    } finally {
      if (identical(_writes, pending)) _writes = null;
    }
  }
}
