import 'package:flutter/foundation.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/page/comic_info/models/unified_plugin_detail.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/comic_like_updates.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/util/json/json_value.dart';

export 'package:zephyr/service/comic_like_updates.dart' show ComicLikeResult;

typedef ComicLikeRequest =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> payload,
    );

class ComicLikeUnconfirmed implements Exception {
  const ComicLikeUnconfirmed();
}

bool isJmComicLikeSource(String from) => const {
  JmListLikeCounts.source,
  'bf99008d-010b-4f17-ac7c-61a9b57dc3d9',
}.contains(normalizePluginId(from));

bool _isBikaComicLikeSource(String source) =>
    source == '0a0e5858-a467-4702-994a-79e608a4589d' ||
    PluginAccountAuthenticationService.bika.contains(source);

void _requireLikeSession(String source, int session) {
  if (pluginSessionWriteFence.isChanging(source) ||
      pluginSessionWriteFence.generation(source) != session) {
    throw const PluginSessionChanged();
  }
}

Future<ComicLikeResult> readCloudComicLike({
  required String from,
  required String comicId,
  @visibleForTesting ComicLikeRequest? invoke,
}) async {
  final source = normalizePluginId(from);
  final session = pluginSessionWriteFence.generation(source);
  _requireLikeSession(source, session);
  final payload = {'comicId': comicId};
  try {
    final detail = UnifiedPluginDetailResponse.fromMap(
      await (invoke?.call('getComicDetail', payload) ??
          callUnifiedComicPlugin(
            from: source,
            fnPath: 'getComicDetail',
            notifyUnauthorized: false,
            core: payload,
          )),
    );
    return comicLikeFromDetail(detail, source: source, comicId: comicId);
  } finally {
    _requireLikeSession(source, session);
  }
}

ComicLikeResult comicLikeFromDetail(
  UnifiedPluginDetailResponse detail, {
  required String source,
  required String comicId,
}) {
  if (detail.source != source ||
      detail.comicId != comicId ||
      asJsonMap(detail.normal['comicInfo'])['id']?.toString() != comicId) {
    throw const ComicLikeUnconfirmed();
  }
  final raw = asJsonMap(detail.raw['comicInfo']);
  final isBika = _isBikaComicLikeSource(source);
  final liked = switch (isBika ? raw['isLiked'] : detail.normal['isLiked']) {
    true || 'true' => true,
    false || 'false' => false,
    _ => throw const ComicLikeUnconfirmed(),
  };
  return (
    liked: liked,
    totalLikes: isBika
        ? detail.confirmedLikes(source: source, comicId: comicId) ??
              parsePublicComicCount(raw['totalLikes']) ??
              parsePublicComicCount(raw['likesCount'])
        : comicMetricIsKnown(
            asJsonMap(detail.normal['extern']),
            'totalLikes',
            parsePublicComicCount(detail.normal['totalLikes']) ?? 0,
          )
        ? parsePublicComicCount(detail.normal['totalLikes'])
        : null,
  );
}

Future<ComicLikeResult> toggleCloudComicLike({
  required String from,
  required String comicId,
  required bool currentStatus,
  int? previousTotalLikes,
  @visibleForTesting ComicLikeRequest? invoke,
}) async {
  final source = normalizePluginId(from);
  final session = pluginSessionWriteFence.generation(source);
  _requireLikeSession(source, session);
  if (isJmComicLikeSource(source)) throw StateError(t.comicInfo.likeDisabled);
  final isBika = _isBikaComicLikeSource(source);
  final Map<String, dynamic> response;
  try {
    final payload = {
      'comicId': comicId,
      'currentLiked': currentStatus,
      if (isBika && previousTotalLikes != null)
        'previousTotalLikes': previousTotalLikes,
    };
    response =
        await (invoke?.call('toggleLike', payload) ??
            callUnifiedComicPlugin(
              from: source,
              fnPath: 'toggleLike',
              notifyUnauthorized: false,
              core: payload,
            ));
  } on PluginLoginRequiredException {
    _requireLikeSession(source, session);
    rethrow;
  } on PluginSessionChanged {
    rethrow;
  } catch (_) {
    _requireLikeSession(source, session);
    // Once the invocation leaves the host a missing receipt is ambiguous.
    // The next gesture reads state instead of invoking the toggle again.
    throw const ComicLikeUnconfirmed();
  }
  _requireLikeSession(source, session);
  requireSuccessfulPluginEnvelope(response);
  final reported = response['liked'];
  if (reported is! bool) throw const ComicLikeUnconfirmed();

  var liked = reported;
  var total = parsePublicComicCount(response['totalLikes']);
  if (response['verified'] != true && isBika) {
    // Older maintained bundles returned only a guessed state. Read the exact
    // work once after the write, without a second write or detail side effects.
    try {
      final observed = await readCloudComicLike(
        from: source,
        comicId: comicId,
        invoke: invoke,
      );
      liked = observed.liked;
      total = observed.totalLikes;
    } on PluginSessionChanged {
      rethrow;
    } catch (_) {
      throw const ComicLikeUnconfirmed();
    }
    _requireLikeSession(source, session);
  }

  return (liked: liked, totalLikes: total);
}
