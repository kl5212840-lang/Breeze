import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';
import 'package:zephyr/util/json/json_value.dart';

const comicDetailErrorType = 'comic_detail_error';

class UnifiedPluginDetailResponse {
  const UnifiedPluginDetailResponse({
    required this.source,
    required this.comicId,
    required this.extern,
    required this.scheme,
    required this.normal,
    required this.raw,
  });

  final String source;
  final String comicId;
  final Map<String, dynamic> extern;
  final Map<String, dynamic> scheme;
  final Map<String, dynamic> normal;
  final Map<String, dynamic> raw;

  /// JM's normalized numeric field has a legacy default of zero. The original
  /// availability flag and matching album identities establish a real count.
  int? confirmedLikes({required String source, required String comicId}) {
    final comic = asJsonMap(normal['comicInfo']);
    final declared = asJsonMap(normal['extern'])[comicMetricAvailabilityKey];
    if (this.source != source ||
        this.comicId != comicId ||
        comic['id']?.toString() != comicId ||
        declared is! Map ||
        declared['totalLikes'] != true) {
      return null;
    }
    return parsePublicComicCount(normal['totalLikes']);
  }

  factory UnifiedPluginDetailResponse.fromMap(Map<String, dynamic> map) {
    final data = asJsonMap(map['data']);
    final normal = data.isNotEmpty
        ? asJsonMap(data['normal'])
        : asJsonMap(map['normal']);
    final raw = data.isNotEmpty
        ? asJsonMap(data['raw'])
        : asJsonMap(map['raw']);

    for (final envelope in [map, data, normal]) {
      final failure =
          ComicFollowCheckException.fromPluginEnvelope(
            envelope,
            type: comicDetailErrorType,
          ) ??
          ComicFollowCheckException.fromPluginEnvelope(envelope);
      if (failure != null) throw failure;
      requireSuccessfulPluginEnvelope(envelope);
    }

    return UnifiedPluginDetailResponse(
      source: map['source']?.toString() ?? '',
      comicId: map['comicId']?.toString() ?? '',
      extern: asJsonMap(map['extern']),
      scheme: asJsonMap(map['scheme']),
      normal: normal,
      raw: raw,
    );
  }
}
