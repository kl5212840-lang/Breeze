// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_simplify_entry_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ComicSimplifyEntryInfo _$ComicSimplifyEntryInfoFromJson(
  Map<String, dynamic> json,
) => _ComicSimplifyEntryInfo(
  title: json['title'] as String,
  description: json['description'] as String? ?? '',
  detailMetadata: json['detailMetadata'] as String? ?? '',
  detailViewCount: (json['detailViewCount'] as num?)?.toInt() ?? 0,
  detailPopularity: (json['detailPopularity'] as num?)?.toInt() ?? 0,
  id: json['id'] as String,
  fileServer: json['fileServer'] as String,
  path: json['path'] as String,
  pictureType: $enumDecode(_$PictureTypeEnumMap, json['pictureType']),
  source: json['source'] as String? ?? '',
  from: json['from'] as String,
);

Map<String, dynamic> _$ComicSimplifyEntryInfoToJson(
  _ComicSimplifyEntryInfo instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'detailMetadata': instance.detailMetadata,
  'detailViewCount': instance.detailViewCount,
  'detailPopularity': instance.detailPopularity,
  'id': instance.id,
  'fileServer': instance.fileServer,
  'path': instance.path,
  'pictureType': _$PictureTypeEnumMap[instance.pictureType]!,
  'source': instance.source,
  'from': instance.from,
};

const _$PictureTypeEnumMap = {
  PictureType.comic: 'comic',
  PictureType.cover: 'cover',
  PictureType.creator: 'creator',
  PictureType.favourite: 'favourite',
  PictureType.user: 'user',
  PictureType.category: 'category',
  PictureType.avatar: 'avatar',
  PictureType.page: 'page',
  PictureType.unknown: 'unknown',
};
