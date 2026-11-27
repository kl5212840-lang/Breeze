import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/json/shelf_metadata_fields.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';

part 'unified_comic_list_item.freezed.dart';
part 'unified_comic_list_item.g.dart';

@freezed
abstract class UnifiedComicListItem with _$UnifiedComicListItem {
  const factory UnifiedComicListItem({
    @JsonKey(fromJson: stringFromDynamic) required String source,
    @JsonKey(fromJson: stringFromDynamic) required String id,
    @JsonKey(fromJson: stringFromDynamic) required String title,
    @JsonKey(fromJson: stringFromDynamic) required String subtitle,
    @JsonKey(fromJson: boolFromDynamic) required bool finished,
    @JsonKey(fromJson: intFromDynamic) required int likesCount,
    @JsonKey(fromJson: intFromDynamic) required int viewsCount,
    @JsonKey(fromJson: stringFromDynamic) required String updatedAt,
    @JsonKey(fromJson: _coverFromDynamic, toJson: _coverToDynamic)
    required UnifiedComicCover cover,
    @JsonKey(fromJson: _metadataListFromDynamic, toJson: _metadataListToDynamic)
    required List<UnifiedComicMetadata> metadata,
    @JsonKey(fromJson: mapFromDynamic) required Map<String, dynamic> raw,
    @JsonKey(fromJson: mapFromDynamic) required Map<String, dynamic> extern,
  }) = _UnifiedComicListItem;

  const UnifiedComicListItem._();

  factory UnifiedComicListItem.fromJson(Map<String, dynamic> json) =>
      _$UnifiedComicListItemFromJson(json);

  String get from => source.trim();

  int? get publicLikesCount =>
      _publicCount('totalLikes', likesCount, raw['likesCount']);

  int? get publicViewsCount => _publicCount(
    'totalViews',
    viewsCount,
    raw['totalViews'] ?? raw['viewsCount'],
  );

  int? get publicPageCount {
    final received = parsePublicComicCount(raw['pagesCount']);
    if (received != null && received > 0) return received;
    for (final (prefix, value) in publicStoredTitleFacts) {
      if (prefix != '页数') continue;
      final count = parsePublicComicCount(value);
      if (count != null && count > 0) return count;
    }
    return null;
  }

  Iterable<(String, String)> get publicStoredTitleFacts sync* {
    final titleMeta = raw['titleMeta'];
    if (titleMeta is! String) return;
    for (final item in decodeJsonListOfMaps(titleMeta)) {
      final name = item['name'];
      if (name is! String) continue;
      final separator = name.indexOf('：');
      if (separator < 0) continue;
      final label = name.substring(0, separator).trim();
      final value = name.substring(separator + 1).trim();
      if (value.isNotEmpty &&
          const {'页数', '章节数', '更新时间', '更新'}.contains(label)) {
        yield (label, value);
      }
    }
  }

  int? _publicCount(String key, int value, Object? sourceValue) {
    if (value < 0) return null;
    final availability = extern[comicMetricAvailabilityKey];
    if (availability is Map && availability[key] == false) return null;
    if (comicMetricIsKnown(extern, key, value) ||
        value == 0 && parsePublicComicCount(sourceValue) == 0) {
      return value;
    }
    return null;
  }

  List<Object> metadataValues(String type) {
    for (final item in metadata) {
      if (item.type == type) {
        return item.value;
      }
    }
    return const <String>[];
  }

  String get primaryText {
    if (subtitle.trim().isNotEmpty) {
      return subtitle.trim();
    }

    final author = metadataValues('author').join(' / ').trim();
    if (author.isNotEmpty) {
      return author;
    }

    return '';
  }

  String get secondaryText {
    final lines = <String>[];
    for (final item in metadata) {
      if (item.value.isEmpty || item.type == 'author') {
        continue;
      }
      final value = item.value.join(' / ').trim();
      if (value.isEmpty) {
        continue;
      }
      final label = item.name.trim().isEmpty ? item.type : item.name.trim();
      lines.add('$label: $value');
      if (lines.length >= 2) {
        break;
      }
    }
    return lines.join('  ');
  }

  String get updatedAtText => updatedAt.trim();

  static const _publicDetailTypes = {
    'author',
    'category',
    'categories',
    'tag',
    'tags',
    'team',
    'chineseteam',
    'year',
    'area',
    'language',
    'works',
    'actors',
    'aliases',
    'status',
    'latest',
    'popularity',
  };

  List<({String type, String label, List<String> values})>
  publicDetailMetadata({bool localRecord = false}) {
    final rawMetadata = raw['metadata'];
    final rows = localRecord && rawMetadata is String
        ? decodeJsonListOfMaps(rawMetadata)
        : localRecord && rawMetadata is List
        ? rawMetadata.whereType<Map>().toList()
        : metadata.map((group) => group.toJson()).toList();
    final groups = <({String type, String label, List<String> values})>[];
    for (final group in rows) {
      final type = group['type']?.toString().trim().toLowerCase() ?? '';
      if (type.isEmpty || localRecord && !_publicDetailTypes.contains(type)) {
        continue;
      }
      final rawValue = group['value'];
      final values = (rawValue is List ? rawValue : [rawValue])
          .map((value) => value is Map ? value['name'] : value)
          .where((value) => value is String || value is num)
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      if (values.isEmpty) continue;
      final name = group['name'];
      groups.add((
        type: type,
        label: name is String && name.trim().isNotEmpty ? name.trim() : type,
        values: values,
      ));
    }
    return groups;
  }

  ComicSimplifyEntryInfo toSimplifyEntryInfo({
    PictureType pictureType = PictureType.cover,
  }) {
    // Persisted rows retain the original metadata in raw. Prefer it so malformed
    // object values cannot become labels through the general list mapper.
    final rawMetadata = raw['metadata'];
    final metadataJson = rawMetadata is String
        ? rawMetadata
        : jsonEncode(
            rawMetadata is List
                ? rawMetadata
                : metadata.map((item) => item.toJson()).toList(),
          );
    final fields = shelfFacetFieldsFromMetadata(metadataJson);
    final detailMetadata = <String>[
      for (final (field, _) in const [
        ('author', '作者'),
        ('category', '分类'),
        ('tags', '标签'),
      ])
        if (fields[field]?.isNotEmpty == true) fields[field]!.join(' / '),
      for (final group in publicDetailMetadata(localRecord: true))
        if (!const {
          'author',
          'category',
          'categories',
          'tag',
          'tags',
        }.contains(group.type))
          '${group.label} ${group.values.join(' / ')}',
      for (final (label, value) in publicStoredTitleFacts) '$label $value',
    ].join(' · ');
    var detailPopularity = 0;
    final rawTitleMeta = raw['titleMeta'];
    if (viewsCount <= 0 && rawTitleMeta is String) {
      for (final item in decodeJsonListOfMaps(rawTitleMeta)) {
        final name = item['name'];
        const prefix = '热度：';
        if (name is String && name.startsWith(prefix)) {
          detailPopularity = int.tryParse(name.substring(prefix.length)) ?? 0;
          break;
        }
      }
    }
    return ComicSimplifyEntryInfo(
      title: title,
      description: raw['description'] is String
          ? (raw['description'] as String).trim()
          : '',
      detailMetadata: detailMetadata,
      detailViewCount: viewsCount,
      detailPopularity: detailPopularity,
      id: id,
      fileServer: cover.url,
      path: cover.cachePath,
      pictureType: pictureType,
      source: source.trim(),
      from: from,
    );
  }
}

@freezed
abstract class UnifiedComicCover with _$UnifiedComicCover {
  const factory UnifiedComicCover({
    @JsonKey(fromJson: stringFromDynamic) required String id,
    @JsonKey(fromJson: stringFromDynamic) required String url,
    @JsonKey(fromJson: stringFromDynamic) required String path,
    @JsonKey(fromJson: mapFromDynamic) required Map<String, dynamic> extern,
  }) = _UnifiedComicCover;

  const UnifiedComicCover._();

  factory UnifiedComicCover.fromJson(Map<String, dynamic> json) =>
      _$UnifiedComicCoverFromJson(json);

  String get cachePath => path.trim();
}

@freezed
abstract class UnifiedComicMetadata with _$UnifiedComicMetadata {
  const factory UnifiedComicMetadata({
    @JsonKey(fromJson: stringFromDynamic) required String type,
    @JsonKey(fromJson: stringFromDynamic) required String name,
    @JsonKey(fromJson: _metadataValueFromDynamic) required List<Object> value,
  }) = _UnifiedComicMetadata;

  const UnifiedComicMetadata._();

  factory UnifiedComicMetadata.fromJson(Map<String, dynamic> json) =>
      _$UnifiedComicMetadataFromJson(json);
}

UnifiedComicCover _coverFromDynamic(dynamic value) {
  final json = asJsonMap(value);
  if (json.isEmpty) {
    throw const FormatException('Invalid UnifiedComicCover payload');
  }
  return UnifiedComicCover.fromJson(json);
}

Map<String, dynamic> _coverToDynamic(UnifiedComicCover cover) => cover.toJson();

List<UnifiedComicMetadata> _metadataListFromDynamic(dynamic value) =>
    asJsonList(
      value,
    ).map((item) => UnifiedComicMetadata.fromJson(asJsonMap(item))).toList();

List<Map<String, dynamic>> _metadataListToDynamic(
  List<UnifiedComicMetadata> metadata,
) => metadata.map((item) => item.toJson()).toList();

List<Object> _metadataValueFromDynamic(dynamic value) =>
    asJsonList(value).map((item) {
      if (item is Map) {
        return (item['name'] ?? item.toString()).toString();
      }
      return item.toString();
    }).toList();
