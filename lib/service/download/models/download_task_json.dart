// To parse this JSON data, do
//
//     final downloadTaskJson = downloadTaskJsonFromJson(jsonString);

import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_task_json.freezed.dart';
part 'download_task_json.g.dart';

const currentDownloadTaskSchemaVersion = 2;

String buildDownloadTaskKey(String from, String comicId) {
  return '${from.trim()}:${comicId.trim()}';
}

DownloadTaskJson downloadTaskJsonFromJson(String str) =>
    DownloadTaskJson.fromJson(json.decode(str));

String downloadTaskJsonToJson(DownloadTaskJson data) =>
    json.encode(data.toJson());

@freezed
abstract class DownloadChapterTaskRef with _$DownloadChapterTaskRef {
  @JsonSerializable(explicitToJson: true)
  const factory DownloadChapterTaskRef({
    @Default('') String chapterId,
    @Default('') String requestId,
    @Default('') String storageChapterId,
    @Default('') String logicalKey,
    @Default('') String title,
    @Default(0) int order,
    @Default(<String, dynamic>{}) Map<String, dynamic> extern,
  }) = _DownloadChapterTaskRef;

  factory DownloadChapterTaskRef.fromJson(Map<String, dynamic> json) =>
      _$DownloadChapterTaskRefFromJson(json);
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class DownloadTaskJson with _$DownloadTaskJson {
  @JsonSerializable(explicitToJson: true)
  const factory DownloadTaskJson({
    required String from,
    required String comicId,
    required String comicName,
    required List<DownloadChapterTaskRef> chapterRefs,
    @Default(currentDownloadTaskSchemaVersion) int schemaVersion,
    @Default('queued') String stateCode,
    @Default('') String phaseCode,
    @Default(<String>[]) List<String> completedChapterKeys,
    @Default('') String currentChapterKey,
    @Default(0) int completedChapterCount,
    @Default(0) int totalChapterCount,
    @Default(0) int currentChapterCompletedImages,
    @Default(0) int currentChapterReusedImages,
    @Default(0) int currentChapterFailedImages,
    @Default(0) int currentChapterTotalImages,
    @Default(0) int attempt,
    @Default('') String lastErrorCode,
    @Default('') String lastErrorMessage,
  }) = _DownloadTaskJson;

  factory DownloadTaskJson.fromJson(Map<String, dynamic> json) =>
      _$DownloadTaskJsonFromJson(json);

  const DownloadTaskJson._();

  String get taskKey => buildDownloadTaskKey(from, comicId);

  bool get isChapterCompleted =>
      currentChapterTotalImages > 0 &&
      currentChapterCompletedImages >= currentChapterTotalImages &&
      currentChapterFailedImages == 0;
}
