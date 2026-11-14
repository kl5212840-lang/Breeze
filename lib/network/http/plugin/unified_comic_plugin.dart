import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/service/jm_list_like_counts.dart' show JmListLikeCounts;
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/util/json/json_value.dart';

final _jmForegroundComicReads = ValueNotifier<int>(0);
ValueListenable<int> get jmForegroundComicReads => _jmForegroundComicReads;

Future<Map<String, dynamic>> callUnifiedComicPlugin({
  String? from,
  String? pluginId,
  required String fnPath,
  required Map<String, dynamic> core,
  Map<String, dynamic>? extern,
  String? runtimeName,
  bool notifyUnauthorized = true,
  bool sessionChange = false,
  String? taskGroupKey,
  bool refresh = false,
  bool jmCoverLikeRead = false,
}) async {
  final resolvedFnPath = fnPath.trim();
  if (resolvedFnPath.isEmpty) {
    throw StateError('callUnifiedComicPlugin missing fnPath');
  }

  final resolvedPluginId = normalizePluginId(
    (pluginId?.trim().isNotEmpty ?? false) ? pluginId! : (from ?? ''),
  );
  if (resolvedPluginId.isEmpty) {
    throw StateError('callUnifiedComicPlugin missing valid plugin identity');
  }

  // These maintained functions explicitly accept the cache-bypass field.
  final supportsRefresh = switch (resolvedPluginId) {
    'e9f18928-3ba8-4d86-a12e-b53a62f47933' => const {
      'getFunctionPage',
      'getHomeData',
      'getRankingData',
    },
    '6886291b-f524-441c-844b-c2efae9899a9' => const {
      'getFunctionPage',
      'getHomeRecommendData',
      'getHomeLatestData',
      'getRankingData',
      'getPromoteListData',
      'getLatestData',
      'getWeekRankingData',
    },
    _ => const <String>{},
  }.contains(resolvedFnPath);
  final payload = <String, dynamic>{
    ...core,
    if (refresh && supportsRefresh) 'refresh': true,
    'extern': extern ?? const {},
  };
  final argsJson = jsonEncode(payload);
  final runtime = runtimeName ?? resolvedPluginId;
  final foregroundJmRead =
      resolvedPluginId == JmListLikeCounts.source &&
      !jmCoverLikeRead &&
      (const {
            'searchComic',
            'getFunctionPage',
            'getHomeRecommendData',
            'getHomeLatestData',
            'getRankingData',
            'getPromoteListData',
            'getLatestData',
            'getWeekRankingData',
            'getCloudFavoriteData',
            'toggleLike',
          }.contains(resolvedFnPath) ||
          resolvedFnPath == 'getComicDetail' &&
              extern?['comicFollow'] != true &&
              extern?['comicDownload'] != true);
  if (foregroundJmRead) _jmForegroundComicReads.value++;
  try {
    final raw = await executeQjsCall(
      pluginId: resolvedPluginId,
      runtimeName: runtime,
      fnPath: resolvedFnPath,
      argsJson: argsJson,
      sessionChange: sessionChange,
      taskGroupKey: taskGroupKey,
      // Callers that manage their own login handling also own result delivery.
      requireCurrentResult: notifyUnauthorized,
    );
    final decoded = requireJsonMap(jsonDecode(raw), message: '插件返回格式错误');
    return _normalizePluginSourceFields(decoded, resolvedPluginId);
  } catch (error) {
    final unauthorized = parseUnauthorizedPayload(
      error,
      fallbackPluginId: resolvedPluginId,
      function: resolvedFnPath,
    );
    if (unauthorized != null) {
      if (notifyUnauthorized) {
        eventBus.fire(
          NeedLogin(from: unauthorized.pluginId, message: unauthorized.message),
        );
      }
      throw PluginLoginRequiredException(unauthorized);
    }
    rethrow;
  } finally {
    if (foregroundJmRead) _jmForegroundComicReads.value--;
  }
}

Map<String, dynamic> _normalizePluginSourceFields(
  Map<String, dynamic> input,
  String pluginId,
) {
  dynamic walk(dynamic node, {bool preserveEvidenceSource = false}) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      if (!preserveEvidenceSource && map.containsKey('source')) {
        map['source'] = pluginId;
      }
      for (final entry in map.entries.toList()) {
        // These sources name the evidence (calendar / saved receipt), not
        // a plugin identity. Keep legacy comic/source normalization elsewhere.
        map[entry.key] = walk(
          entry.value,
          preserveEvidenceSource:
              entry.key == 'checkinProof' || entry.key == 'verification',
        );
      }
      return map;
    }
    if (node is List) {
      return node.map(walk).toList();
    }
    return node;
  }

  return walk(input) as Map<String, dynamic>;
}
