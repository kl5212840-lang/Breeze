import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef ApiVideoPluginCall =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> args,
    );

class ApiVideoRepository {
  ApiVideoRepository({
    required this.source,
    required this.home,
    required this.catalogFn,
    required this.detailFn,
    required this.playbackFn,
    this.batchDetailFn,
    ApiVideoPluginCall? pluginCall,
  }) : call =
           pluginCall ??
           ((path, args) => callUnifiedComicPlugin(
             pluginId: source,
             fnPath: path,
             core: args,
           ));
  final String source, catalogFn, detailFn, playbackFn;
  final String? batchDetailFn;
  final Uri home;
  final ApiVideoPluginCall call;

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic> args,
  ) async => asJsonMap(
    (await call(path, args).timeout(const Duration(seconds: 35)))['data'],
  );

  Future<ApiVideoResult> page({
    String query = '',
    String typeId = '',
    String year = '',
    int page = 1,
    Map<String, dynamic>? cursor,
    bool refresh = false,
    int recentHours = 0,
  }) async => ApiVideoResult.fromJson(
    await _request(catalogFn, {
      'query': query,
      'typeId': typeId,
      'year': year,
      'page': page,
      'cursor': cursor,
      'refresh': refresh,
      'recentHours': recentHours,
    }),
    home: home,
  );

  Future<ApiVideoItem> item(String id, {bool refresh = false}) async {
    final value = ApiVideoItem.fromJson(
      await _request(detailFn, {'id': id, 'refresh': refresh}),
      home: home,
    );
    if (value.id != id) throw const FormatException('Wrong video returned');
    return value;
  }

  Future<List<ApiVideoItem>> items(List<String> ids) async {
    if (ids.isEmpty || ids.length > 20) {
      throw ArgumentError.value(ids.length, 'ids');
    }
    if (batchDetailFn == null || batchDetailFn!.isEmpty) {
      final result = <ApiVideoItem>[];
      for (final id in ids) {
        result.add(await item(id, refresh: true));
      }
      return result;
    }
    final raw = await _request(batchDetailFn!, {'ids': ids});
    final result = <ApiVideoItem>[], seen = <String>{};
    for (final row in asJsonList(raw['items'])) {
      final item = ApiVideoItem.fromJson(asJsonMap(row), home: home);
      if (!ids.contains(item.id)) {
        throw const FormatException('Unexpected update item');
      }
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  Future<({ApiVideoItem item, NativePlaybackSession session})> session(
    String id, {
    String? lineId,
    String? episodeId,
    bool refresh = false,
  }) async {
    final raw = await _request(playbackFn, {
      'id': id,
      'lineId': lineId,
      'episodeId': episodeId,
      'refresh': refresh,
    });
    final item = ApiVideoItem.fromJson(asJsonMap(raw['item']), home: home);
    final selectedLine = apiVideoText(raw['lineId'], 160),
        selectedEpisode = apiVideoText(raw['episodeId'], 300);
    if (item.id != id ||
        (lineId != null && lineId != selectedLine) ||
        (episodeId != null && episodeId != selectedEpisode)) {
      throw const FormatException('Wrong episode returned');
    }
    final session = item.session(selectedLine, selectedEpisode);
    if (videoPlaybackIdentity(Uri.parse(apiVideoText(raw['watchUrl'], 4096))) !=
        session.watchUrl) {
      throw const FormatException('Episode identity mismatch');
    }
    return (item: item, session: session);
  }
}
