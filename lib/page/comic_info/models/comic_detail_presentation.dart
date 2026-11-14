import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/page/comic_info/models/unified_plugin_detail.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/util/error_filter.dart';

class ComicDetailReadFailure implements ImageFailureEvidence {
  const ComicDetailReadFailure({
    required this.message,
    required this.retryable,
  });

  final String message;
  @override
  final bool retryable;
}

ComicDetailReadFailure presentComicDetailFailure(
  Object error, {
  required bool remote,
}) {
  if (!remote) {
    return ComicDetailReadFailure(
      message: userFacingErrorMessage(error),
      retryable: false,
    );
  }
  final failure = classifyComicFollowCheckFailure(
    error,
    additionalEnvelopeType: comicDetailErrorType,
  );
  final readable =
      failure.message ??
      readableErrorMessage(switch (error) {
        PluginLoginRequiredException(:final payload) => payload.message,
        _ => quickJsErrorMessage(error) ?? normalizeSearchErrorMessage(error),
      });
  final message = switch (failure.reason) {
    ComicFollowCheckFailure.invalidResponse =>
      failure.message ?? t.comicFollow.checkInvalidResponse,
    ComicFollowCheckFailure.network =>
      failure.message ?? t.comicFollow.checkNetworkUnavailable,
    ComicFollowCheckFailure.signInRequired =>
      readable ?? t.comicFollow.checkSignInRequired,
    ComicFollowCheckFailure.notFound =>
      readable ?? t.comicFollow.checkComicNotFound,
    ComicFollowCheckFailure.sourceUnavailable =>
      readable ?? t.comicFollow.checkSourceUnavailable,
    _ => readable ?? t.comicList.loadFailedRetry,
  };
  final status = failure.httpStatus;
  final retryable = switch (failure.reason) {
    ComicFollowCheckFailure.network => failure.retryable,
    ComicFollowCheckFailure.sourceUnavailable =>
      failure.retryable ||
          status != null && (status == 425 || status == 429 || status >= 500),
    ComicFollowCheckFailure.unknown => imageFailureIsTransient(error),
    _ => false,
  };
  return ComicDetailReadFailure(message: message, retryable: retryable);
}

/// The legacy public titleMeta convention is already consumed by the shelf
/// mapper. New sources can tag the metric explicitly without localized parsing.
String? _metric(ComicInfoActionItem item) {
  final declared = item.extern['metric'];
  if (const ['totalViews', 'totalLikes', 'totalComments'].contains(declared))
    return declared as String;
  if (item.name.startsWith('浏览：')) return 'totalViews';
  return null;
}

ComicInfo comicInfoForDetailPresentation(NormalComicAllInfo info) =>
    info.comicInfo.copyWith(
      titleMeta: info.comicInfo.titleMeta.where((item) {
        final metric = _metric(item);
        if (metric == null) return true;
        final value = switch (metric) {
          'totalViews' => info.totalViews,
          'totalLikes' => info.totalLikes,
          _ => info.totalComments,
        };
        return comicMetricIsKnown(info.extern, metric, value);
      }).toList(),
    );

/// Absence is declared by a source that knows its response contract. A truly
/// empty optional value does not imply a failed read for arbitrary plugins.
bool comicDetailHasMissingFields(NormalComicAllInfo info) {
  final fields = info.extern['fieldsMissing'];
  return fields is List &&
      fields.any((field) => field == 'description' || field == 'tags');
}
