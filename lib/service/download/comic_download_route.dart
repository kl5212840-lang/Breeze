import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/model/unified_plugin_chapter.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/download/download_retry.dart';

/// The optional automatic download route contract. Legacy plug-ins can
/// continue to return the normal chapter response without a route.
class ComicDownloadRoute {
  const ComicDownloadRoute(
    this.key,
    this.apiHost,
    this.imageHost, {
    this.canSwitch = true,
  });

  final String key;
  final String apiHost;
  final String imageHost;
  final bool canSwitch;
  static final _keyPattern = RegExp(r'^[a-zA-Z0-9._|:-]{1,180}$');
  static final _hostPattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}$');

  static ComicDownloadRoute? fromChapter(UnifiedPluginChapterResponse value) {
    final route = value.chapter.extern['downloadRoute'];
    if (route is! Map || route['version'] != 1) return null;
    final key = route['key'], api = route['apiHost'];
    final image = route['imageHost'] ?? '';
    if (key is! String ||
        !_keyPattern.hasMatch(key) ||
        api is! String ||
        !_hostPattern.hasMatch(api) ||
        image is! String ||
        (image.isNotEmpty && !_hostPattern.hasMatch(image))) {
      throw const FormatException('Invalid automatic comic download route');
    }
    return ComicDownloadRoute(
      key,
      api.toLowerCase(),
      image.toLowerCase(),
      canSwitch: route['canSwitch'] != false,
    );
  }
}

class ComicDownloadRouteUnavailable implements Exception {
  const ComicDownloadRouteUnavailable([
    this.message,
    this.retryReason,
    this.noCandidate = false,
  ]);

  final String? message;
  final ComicDownloadRetryReason? retryReason;
  final bool noCandidate;

  static ComicDownloadRouteUnavailable? fromPluginError(Object error) {
    final message = quickJsErrorMessage(error);
    if (message == null || !message.startsWith('{')) return null;
    try {
      final value = jsonDecode(message);
      if (value is! Map) return null;
      final type = value['type'];
      if (type != 'comic_download_route_unavailable' &&
          type != 'comic_detail_error') {
        return null;
      }
      final retryable = value['retryable'];
      if (type == 'comic_detail_error' && retryable == null) return null;
      final reason = retryable == true
          ? switch (value['reason']) {
              'network' => ComicDownloadRetryReason.network,
              'timeout' => ComicDownloadRetryReason.timeout,
              'rateLimited' => ComicDownloadRetryReason.rateLimited,
              'sourceUnavailable' when value['httpStatus'] is int =>
                comicDownloadHttpRetryReason(value['httpStatus'] as int),
              _ => null,
            }
          : null;
      final detail = value['message'];
      return ComicDownloadRouteUnavailable(
        detail is String ? readableErrorMessage(detail) : null,
        reason,
        type == 'comic_download_route_unavailable' &&
            retryable != false &&
            (value['reason'] == 'noCandidate' ||
                (retryable == null && value['reason'] == null)),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() =>
      message ??
      (LocaleSettings.currentLocale == AppLocale.zhCn
          ? '当前线路无法完整下载这一话，请重试'
          : 'No available route could complete this chapter. Try again.');
}

// Reuse the latest partial generation with the exact same plan. The
// checkpoint stores these physical names alongside older owned files so
// cancellation, restart and explicit deletion retain their existing paths.
final _managedPage = RegExp(
  r'^breeze_page_v1_([a-f0-9]{64})_([a-f0-9]{32})_[0-9]+(?:\.[a-zA-Z0-9]{1,8})?$',
);
final _fileExtension = RegExp(r'^\.[a-zA-Z0-9]{1,8}$');

List<UnifiedPluginChapterDoc> isolateComicDownloadPages({
  required String taskKey,
  required UnifiedPluginChapterResponse response,
  required ComicDownloadRoute route,
  required Iterable<String> retainedPaths,
}) {
  final docs = response.chapter.docs;
  for (final doc in docs) {
    final uri = Uri.tryParse(doc.url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (route.imageHost.isNotEmpty && uri.host != route.imageHost)) {
      throw const FormatException('Invalid comic download page address');
    }
  }
  // Hash the ordered request plan; signed URLs stay in memory.
  final manifest = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            taskKey,
            response.chapter.epId,
            route.key,
            route.apiHost,
            route.imageHost,
            for (final doc in docs) [doc.id, doc.path, doc.url, doc.extern],
          ]),
        ),
      )
      .toString();
  String? generation;
  for (final path in retainedPaths) {
    final plan = _managedPage.firstMatch(path);
    if (plan?.group(1) == manifest) generation = plan!.group(2);
  }
  generation ??= const Uuid().v4().replaceAll('-', '');
  return [
    for (final (index, doc) in docs.indexed)
      UnifiedPluginChapterDoc(
        name: doc.name.trim().isNotEmpty ? doc.name : p.basename(doc.path),
        path:
            'breeze_page_v1_${manifest}_${generation}_${index + 1}'
            '${_fileExtension.stringMatch(p.extension(doc.path)) ?? ''}',
        url: doc.url,
        id: doc.id,
        extern: doc.extern,
      ),
  ];
}
