import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/util/json/json_value.dart';

/// Only public page/poster pairs. Reuses the device-only snapshot lifecycle so
/// cache clearing and plugin removal also remove these observations.
class VideoPublicCoverStore {
  VideoPublicCoverStore({required this.source, required this.home})
    : _store = VideoPersonalSnapshotStore(cacheSource: source);

  final String source;
  final Uri home;
  final VideoPersonalSnapshotStore _store;
  Future<void> _pending = Future.value();
  static const capacity = 128;
  String get _scope => VideoPersonalSnapshotStore.scope(
    source,
    home,
    home.resolve('/?breeze-public-covers=v1'),
  );

  String? _page(Object? raw) {
    final url = apiVideoHttps(raw);
    if (url == null || url.origin != home.origin) return null;
    return videoPublicPage(url)?.toString();
  }

  Future<Map<String, String>> _read() async {
    final snapshot = await _store.read(_scope);
    // An explicit cache clear invalidates pending observations as well.
    if (snapshot == null || !_store.fresh(snapshot)) return {};
    return {
      for (final row in asJsonList(snapshot['videos']).whereType<Map>())
        if (_page(row['pageUrl']) case final page?)
          if (apiVideoHttps(row['coverUrl']) case final cover?)
            page: cover.toString(),
    };
  }

  Future<Map<String, dynamic>> supplement(
    Map<String, dynamic> data, {
    required bool refresh,
  }) async {
    try {
      await _pending;
      final known = refresh ? <String, String>{} : await _read();
      final rows = [
        for (final raw in asJsonList(data['items']))
          if (raw is Map)
            {
              ...asJsonMap(raw),
              if (apiVideoHttps(raw['coverUrl']) == null)
                'coverUrl': ?known[_page(raw['detailUrl'])],
            },
      ];
      await remember([
        for (final row in rows) ApiVideoItem.fromJson(row, home: home),
      ]);
      return {...data, 'items': rows};
    } catch (_) {
      return data;
    }
  }

  Future<void> remember(Iterable<ApiVideoItem> items) {
    final observed = {
      for (final item in items)
        if (_page(item.detailUrl.toString()) case final page?)
          if (item.coverUrl case final cover?) page: cover.toString(),
    };
    if (observed.isEmpty) return Future.value();
    final generation = _store.generation;
    final task = _pending.then((_) async {
      if (generation != _store.generation) return;
      final values = await _read();
      var changed = false;
      for (final entry in observed.entries) {
        if (values[entry.key] == entry.value) continue;
        values.remove(entry.key);
        values[entry.key] = entry.value;
        changed = true;
      }
      if (!changed) return;
      while (values.length > capacity) {
        values.remove(values.keys.first);
      }
      await _store.write(_scope, {
        'videos': [
          for (final entry in values.entries)
            {'pageUrl': entry.key, 'coverUrl': entry.value},
        ],
      }, generation);
    });
    _pending = task.catchError((Object _) {});
    return _pending;
  }
}
