// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DownloadChapterTaskRef _$DownloadChapterTaskRefFromJson(
  Map<String, dynamic> json,
) => _DownloadChapterTaskRef(
  chapterId: json['chapterId'] as String? ?? '',
  requestId: json['requestId'] as String? ?? '',
  storageChapterId: json['storageChapterId'] as String? ?? '',
  logicalKey: json['logicalKey'] as String? ?? '',
  title: json['title'] as String? ?? '',
  order: (json['order'] as num?)?.toInt() ?? 0,
  extern: json['extern'] as Map<String, dynamic>? ?? const <String, dynamic>{},
);

Map<String, dynamic> _$DownloadChapterTaskRefToJson(
  _DownloadChapterTaskRef instance,
) => <String, dynamic>{
  'chapterId': instance.chapterId,
  'requestId': instance.requestId,
  'storageChapterId': instance.storageChapterId,
  'logicalKey': instance.logicalKey,
  'title': instance.title,
  'order': instance.order,
  'extern': instance.extern,
};

_DownloadTaskJson _$DownloadTaskJsonFromJson(
  Map<String, dynamic> json,
) => _DownloadTaskJson(
  from: json['from'] as String,
  comicId: json['comicId'] as String,
  comicName: json['comicName'] as String,
  chapterRefs: (json['chapterRefs'] as List<dynamic>)
      .map((e) => DownloadChapterTaskRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ??
      currentDownloadTaskSchemaVersion,
  stateCode: json['stateCode'] as String? ?? 'queued',
  phaseCode: json['phaseCode'] as String? ?? '',
  completedChapterKeys:
      (json['completedChapterKeys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  currentChapterKey: json['currentChapterKey'] as String? ?? '',
  completedChapterCount: (json['completedChapterCount'] as num?)?.toInt() ?? 0,
  totalChapterCount: (json['totalChapterCount'] as num?)?.toInt() ?? 0,
  currentChapterCompletedImages:
      (json['currentChapterCompletedImages'] as num?)?.toInt() ?? 0,
  currentChapterReusedImages:
      (json['currentChapterReusedImages'] as num?)?.toInt() ?? 0,
  currentChapterFailedImages:
      (json['currentChapterFailedImages'] as num?)?.toInt() ?? 0,
  currentChapterTotalImages:
      (json['currentChapterTotalImages'] as num?)?.toInt() ?? 0,
  attempt: (json['attempt'] as num?)?.toInt() ?? 0,
  lastErrorCode: json['lastErrorCode'] as String? ?? '',
  lastErrorMessage: json['lastErrorMessage'] as String? ?? '',
);

Map<String, dynamic> _$DownloadTaskJsonToJson(_DownloadTaskJson instance) =>
    <String, dynamic>{
      'from': instance.from,
      'comicId': instance.comicId,
      'comicName': instance.comicName,
      'chapterRefs': instance.chapterRefs.map((e) => e.toJson()).toList(),
      'schemaVersion': instance.schemaVersion,
      'stateCode': instance.stateCode,
      'phaseCode': instance.phaseCode,
      'completedChapterKeys': instance.completedChapterKeys,
      'currentChapterKey': instance.currentChapterKey,
      'completedChapterCount': instance.completedChapterCount,
      'totalChapterCount': instance.totalChapterCount,
      'currentChapterCompletedImages': instance.currentChapterCompletedImages,
      'currentChapterReusedImages': instance.currentChapterReusedImages,
      'currentChapterFailedImages': instance.currentChapterFailedImages,
      'currentChapterTotalImages': instance.currentChapterTotalImages,
      'attempt': instance.attempt,
      'lastErrorCode': instance.lastErrorCode,
      'lastErrorMessage': instance.lastErrorMessage,
    };
