import 'dart:collection';

/// Session-only snapshots. Never stores browser credentials or playable URLs.
/// Freshness avoids repeated navigation; stale entries remain useful while a
/// foreground refresh runs. Clear on website/account/verification transitions.
class VideoCatalogCache extends MapBase<String, Map<String, dynamic>> {
  VideoCatalogCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const freshFor = Duration(seconds: 30);
  static const capacity = 8;
  final DateTime Function() _now;
  final _entries = <String, ({DateTime saved, Map<String, dynamic> data})>{};

  bool isFresh(String key) {
    final saved = _entries[key]?.saved;
    if (saved == null) return false;
    final age = _now().difference(saved);
    return !age.isNegative && age < freshFor;
  }

  @override
  Map<String, dynamic>? operator [](Object? key) => _entries[key]?.data;

  @override
  void operator []=(String key, Map<String, dynamic> value) {
    _entries.remove(key);
    if (_entries.length >= capacity) _entries.remove(_entries.keys.first);
    _entries[key] = (saved: _now(), data: value);
  }

  @override
  Iterable<String> get keys => _entries.keys;

  @override
  void clear() => _entries.clear();

  @override
  Map<String, dynamic>? remove(Object? key) => _entries.remove(key)?.data;
}
