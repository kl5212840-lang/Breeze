import 'package:zephyr/page/video/video_search_filters.dart';

const hanimeSourceId = '1e600cff-8ebe-4517-8aa4-6678aec46424';

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
