import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/util/json/json_value.dart';

part 'video_search_filters.freezed.dart';

enum VideoFilterSection { genre, tags, sort, date, duration, query }

/// One request identity for controls, paging, cache and return restoration.
@freezed
abstract class VideoSearchFilters with _$VideoSearchFilters {
  const VideoSearchFilters._();
  const factory VideoSearchFilters({
    @Default('') String query,
    @Default('') String genre,
    @Default('') String sort,
    @Default('') String date,
    @Default('') String duration,
    @Default([]) List<String> tags,
    @Default(false) bool anyTag,
    @Default(false) bool author,
    @Default(1) int page,
  }) = _VideoSearchFilters;

  factory VideoSearchFilters.fromUri(Uri uri) {
    final q = uri.queryParameters;
    return VideoSearchFilters(
      query: _text(q['query'], 300),
      genre: _text(q['genre']),
      sort: _text(q['sort']),
      date: _text(q['date']),
      duration: _text(q['duration']),
      tags: _tags(_queryTags(uri)),
      anyTag: const {'on', 'true', '1'}.contains(q['broad']),
      author: q['type'] == 'artist',
      page: (int.tryParse(q['page'] ?? '') ?? 1).clamp(1, 10000),
    );
  }

  static Iterable<String> _queryTags(Uri uri) {
    final parameters = uri.queryParametersAll;
    if (parameters['tags[]'] case final canonical?) return canonical;
    // The site's observed pagination uses tags[0]. Accept only numeric tag
    // keys, then keep the existing limit/cleanup/deduplication order below.
    final indexedKey = RegExp(r'^tags\[[0-9]+\]$');
    final indexed = parameters.entries
        .where((entry) => indexedKey.hasMatch(entry.key))
        .expand((entry) => entry.value);
    if (indexed.isNotEmpty) return indexed;
    final legacy = uri.queryParameters['tag'];
    return legacy == null ? const [] : [legacy];
  }

  static String _text(String? value, [int limit = 120]) {
    final clean = (value ?? '')
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .trim();
    return clean.length > limit ? clean.substring(0, limit) : clean;
  }

  static List<String> _tags(Iterable<String> values) =>
      (values
          .take(64)
          .map((value) => _text(value, 100))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  Uri toUri(Uri home, {int? pageNumber}) => home
      .resolve('/search')
      .replace(
        queryParameters: {
          if (_text(query, 300).isNotEmpty) 'query': _text(query, 300),
          if (_text(genre).isNotEmpty) 'genre': _text(genre),
          if (_text(sort).isNotEmpty) 'sort': _text(sort),
          if (_text(date).isNotEmpty) 'date': _text(date),
          if (_text(duration).isNotEmpty) 'duration': _text(duration),
          if (_tags(tags).isNotEmpty) 'tags[]': _tags(tags),
          if (anyTag) 'broad': 'on',
          if (author) 'type': 'artist',
          if ((pageNumber ?? page) > 1)
            'page': '${(pageNumber ?? page).clamp(1, 10000)}',
        },
      );

  VideoSearchFilters change(VideoFilterSection section, String value) =>
      switch (section) {
        VideoFilterSection.genre => copyWith(genre: value, page: 1),
        VideoFilterSection.sort => copyWith(sort: value, page: 1),
        VideoFilterSection.date => copyWith(date: value, page: 1),
        VideoFilterSection.duration => copyWith(duration: value, page: 1),
        VideoFilterSection.query => copyWith(query: value, page: 1),
        VideoFilterSection.tags => copyWith(
          tags: _tags([...tags, value]),
          page: 1,
        ),
      };

  VideoSearchFilters removeTag(String tag) =>
      copyWith(tags: tags.where((item) => item != tag).toList(), page: 1);
  VideoSearchFilters clearFilters() => copyWith(
    genre: '',
    sort: '',
    date: '',
    duration: '',
    tags: [],
    anyTag: false,
    page: 1,
  );

  int get activeCount =>
      [genre, sort, date, duration].where((value) => value.isNotEmpty).length +
      _tags(tags).length +
      (anyTag ? 1 : 0) +
      (author ? 1 : 0);
}

@freezed
abstract class VideoFilterChoice with _$VideoFilterChoice {
  const factory VideoFilterChoice({
    required String value,
    required String label,
  }) = _VideoFilterChoice;
}

@freezed
abstract class VideoFilterSchema with _$VideoFilterSchema {
  const VideoFilterSchema._();
  const factory VideoFilterSchema({
    @Default({}) Map<String, List<VideoFilterChoice>> options,
    @Default({}) Map<String, List<VideoFilterChoice>> tagGroups,
    @Default([]) List<String> years,
    @Default(false) bool customDate,
  }) = _VideoFilterSchema;

  factory VideoFilterSchema.fromWire(Map<String, dynamic> raw) {
    List<VideoFilterChoice> choices(dynamic raw, int limit) {
      final result = <VideoFilterChoice>[], seen = <String>{};
      for (final entry in asJsonList(raw).take(limit)) {
        final item = asJsonMap(entry);
        final value = VideoSearchFilters._text(item['value']?.toString()),
            label = VideoSearchFilters._text(item['label']?.toString());
        if (label.isNotEmpty && seen.add(value)) {
          result.add(VideoFilterChoice(value: value, label: label));
        }
      }
      return result;
    }

    final groups = <String, List<VideoFilterChoice>>{};
    for (final entry in asJsonMap(raw['tagGroups']).entries.take(16)) {
      final title = VideoSearchFilters._text(entry.key, 80),
          values = choices(entry.value, 400);
      if (title.isNotEmpty && values.isNotEmpty) groups[title] = values;
    }
    final options = <String, List<VideoFilterChoice>>{};
    for (final key in ['genre', 'sort', 'date', 'duration']) {
      final values = choices(asJsonMap(raw['options'])[key], 80);
      if (values.isNotEmpty) options[key] = values;
    }
    return VideoFilterSchema(
      options: options,
      tagGroups: groups,
      customDate: raw['customDate'] == true,
      years: asJsonList(raw['years'])
          .map((value) => value.toString())
          .where((value) => RegExp(r'^\d{4}$').hasMatch(value))
          .toSet()
          .take(150)
          .toList(),
    );
  }

  VideoFilterSchema merge(VideoFilterSchema fresh) => copyWith(
    options: {...options, ...fresh.options},
    tagGroups: fresh.tagGroups.isEmpty ? tagGroups : fresh.tagGroups,
    years: fresh.years.isEmpty ? years : fresh.years,
    customDate: customDate || fresh.customDate,
  );
}
