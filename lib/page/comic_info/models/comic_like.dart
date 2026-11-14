import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show logger;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/page/comic_info/models/unified_plugin_detail.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/jm_list_like_counts.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef ComicLikeResult = ({bool liked, int? totalLikes});

class ComicLikeUnconfirmed implements Exception {
  const ComicLikeUnconfirmed();
}

Object _jmLikePluginError(Object error) {
  final message = quickJsErrorMessage(error);
  if (message == '暂时无法确认点赞状态，请重新打开作品详情查看') {
    return const ComicLikeUnconfirmed();
  }
  if (message == null || !message.startsWith('{')) return error;
  final Map<String, dynamic> payload;
  try {
    payload = asJsonMap(jsonDecode(message));
  } on FormatException {
    return error;
  }
  switch (payload['type']) {
    case 'comic_like_unconfirmed':
      _recordJmLikeDiagnostic(payload['diagnostic']);
      return const ComicLikeUnconfirmed();
    case 'comic_like_rejected':
      _recordJmLikeDiagnostic(payload['diagnostic']);
      final detail = payload['message'];
      return detail is String ? StateError(detail) : error;
    default:
      return error;
  }
}

const _jmLikeStageResults = {
  'login-required',
  'http-rejected',
  'business-rejected',
  'unreadable',
  'readable',
  'transport',
};
const _jmLikeVerificationFields = {
  'result': {'confirmed', 'unconfirmed'},
  'work': {'match', 'mismatch', 'unknown'},
  'likedType': {
    'missing',
    'null',
    'array',
    'boolean',
    'string',
    'number',
    'object',
  },
  'liked': {'true', 'false', 'unknown'},
  'total': {'present', 'invalid', 'missing'},
  'totalChange': {'changed', 'unchanged', 'unknown'},
};
Map<String, Object?> _lastJmLikeDiagnostic = const {};
bool _jmLikeExtensionRegistered = false;

void _beginJmLikeDiagnostic() {
  _lastJmLikeDiagnostic = const {};
  if (kReleaseMode || _jmLikeExtensionRegistered) return;
  developer.registerExtension('ext.breeze.jmLike', (_, _) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(_lastJmLikeDiagnostic),
    );
  });
  _jmLikeExtensionRegistered = true;
}

void _recordJmLikeDiagnostic(Object? value) {
  final raw = asJsonMap(value);
  final safe = <String, Object?>{};
  for (final name in ['submit', 'readback']) {
    final stage = asJsonMap(raw[name]);
    final result = stage['result'];
    if (!_jmLikeStageResults.contains(result)) continue;
    final http = stage['http'];
    safe[name] = {
      'result': result,
      if (http is int && http >= 100 && http <= 599) 'http': http,
    };
  }
  final rawVerify = asJsonMap(raw['verify']);
  final verify = {
    for (final field in _jmLikeVerificationFields.entries)
      if (field.value.contains(rawVerify[field.key]))
        field.key: rawVerify[field.key],
  };
  if (verify.isNotEmpty) safe['verify'] = verify;
  if (safe.isEmpty) return;
  _lastJmLikeDiagnostic = safe;
  logger.i('[jm.like] ${jsonEncode(safe)}');
}

Future<ComicLikeResult> toggleCloudComicLike({
  required String from,
  required String comicId,
  required bool currentStatus,
  int? previousTotalLikes,
  @visibleForTesting
  Future<Map<String, dynamic>> Function(
    String function,
    Map<String, dynamic> payload,
  )?
  invoke,
}) async {
  final source = normalizePluginId(from);
  final session = pluginSessionWriteFence.generation(source);
  void requireCurrent() {
    if (pluginSessionWriteFence.isChanging(source) ||
        pluginSessionWriteFence.generation(source) != session) {
      throw const PluginSessionChanged();
    }
  }

  Future<Map<String, dynamic>> request(
    String function,
    Map<String, dynamic> payload,
  ) =>
      invoke?.call(function, payload) ??
      callUnifiedComicPlugin(
        from: source,
        fnPath: function,
        notifyUnauthorized: false,
        core: payload,
      );

  requireCurrent();
  final isJm = source == JmListLikeCounts.source;
  final isBika = PluginAccountAuthenticationService.bika.contains(source);
  if (isJm && currentStatus) throw StateError(t.comicInfo.likeDisabled);
  if (isJm) _beginJmLikeDiagnostic();
  final Map<String, dynamic> response;
  try {
    response = await request('toggleLike', {
      'comicId': comicId,
      'currentLiked': currentStatus,
      if ((isBika || isJm) && previousTotalLikes != null)
        'previousTotalLikes': previousTotalLikes,
      if (isJm) 'includeLikeDiagnostic': true,
    });
  } catch (error) {
    requireCurrent();
    if (isJm) {
      final mapped = _jmLikePluginError(error);
      if (!identical(error, mapped)) throw mapped;
    }
    rethrow;
  }
  requireCurrent();
  if (isJm) _recordJmLikeDiagnostic(response['likeDiagnostic']);
  requireSuccessfulPluginEnvelope(response);
  final reported = response['liked'];
  if (reported is! bool) throw FormatException(t.comicInfo.likeUnconfirmed);

  var liked = reported;
  var total = parsePublicComicCount(response['totalLikes']);
  if (response['verified'] != true && (isJm || isBika)) {
    // Older maintained bundles returned only a guessed state. Read the exact
    // work once after the write, without a second write or detail side effects.
    final detail = UnifiedPluginDetailResponse.fromMap(
      await request('getComicDetail', {'comicId': comicId}),
    );
    requireCurrent();
    if (detail.source != source ||
        detail.comicId != comicId ||
        asJsonMap(detail.normal['comicInfo'])['id']?.toString() != comicId) {
      throw FormatException(t.comicInfo.likeUnconfirmed);
    }
    if (isJm) {
      // Old JM normalizes a missing liked field to false. Only a positive
      // readback can confirm this one-way action.
      if (detail.normal['isLiked'] != true) {
        throw FormatException(t.comicInfo.likeUnconfirmed);
      }
      liked = true;
      total = detail.confirmedLikes(source: source, comicId: comicId);
    } else {
      final raw = asJsonMap(detail.raw['comicInfo']);
      liked = switch (raw['isLiked']) {
        true || 'true' => true,
        false || 'false' => false,
        _ => throw FormatException(t.comicInfo.likeUnconfirmed),
      };
      total =
          parsePublicComicCount(raw['totalLikes']) ??
          parsePublicComicCount(raw['likesCount']);
    }
  }

  if (isJm && total != null) {
    JmListLikeCounts.instance.remember({comicId: total}, generation: session);
  }
  return (liked: liked, totalLikes: total);
}
