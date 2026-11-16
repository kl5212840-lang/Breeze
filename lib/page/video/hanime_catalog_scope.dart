import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

const hanimeSourceId = '1e600cff-8ebe-4517-8aa4-6678aec46424';

bool hanimePreviewCoverBlur(Uri? page) =>
    kDebugMode &&
    const bool.fromEnvironment('BREEZE_HANIME_PREVIEW_BLUR') &&
    page?.scheme == 'https' &&
    page?.host == 'hanime1.me' &&
    page?.port == 443 &&
    page?.userInfo.isEmpty == true;

const hanimePreviewCoverScript = r'''
(() => {
  if (location.origin !== 'https://hanime1.me') return;
  const addStyles = () => {
    if (!document.documentElement) return false;
    const style = document.createElement('style');
    style.textContent = `
      a[href^="/watch"] img,
      a[href^="https://hanime1.me/watch"] img,
      .video-item-container img.main-thumb,
      .user-tab-item-wrapper img.main-thumb,
      .vjs-poster {
        filter: blur(24px) !important;
        clip-path: inset(0) !important;
      }
    `;
    document.documentElement.appendChild(style);
    return true;
  };
  if (!addStyles()) {
    const observer = new MutationObserver(() => {
      if (addStyles()) observer.disconnect();
    });
    observer.observe(document, {childList: true});
  }
})();
''';

const hanimeResultFilters = [
  VideoFilterSection.tags,
  VideoFilterSection.date,
  VideoFilterSection.duration,
];

enum HanimeRanking {
  today('本日排行'),
  week('本週排行'),
  month('本月排行');

  const HanimeRanking(this.wireValue);
  final String wireValue;

  static HanimeRanking? fromUri(Uri uri) => values
      .where((rank) => rank.wireValue == uri.queryParameters['sort'])
      .firstOrNull;
}

enum HanimeCatalogLayout { detail, large, compact }

bool hanimeResultSort(String value) =>
    !HanimeRanking.values.any((rank) => rank.wireValue == value);

VideoSearchFilters hanimeKeywordQuery(
  VideoSearchFilters current,
  VideoSearchFilters submitted, {
  required bool inResults,
  String? genre,
}) {
  if (submitted.author || !inResults) {
    return VideoSearchFilters(query: submitted.query, author: submitted.author);
  }
  return current.copyWith(
    query: submitted.query,
    genre: genre ?? '',
    author: false,
    page: 1,
  );
}
