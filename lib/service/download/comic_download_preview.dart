import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

/// Public cover metadata for an in-flight first chapter. No downloaded chapter
/// or durable completion is manufactured before its real commit.
abstract final class ComicDownloadPreview {
  static final changes = ValueNotifier<int>(0);
  static final _covers = LinkedHashMap<String, Map<String, dynamic>>();
  static Map<String, dynamic>? cover(String source, String comicId) =>
      _covers[buildDownloadTaskKey(source, comicId)];
  @visibleForTesting
  static void resetForTesting() {
    _covers.clear();
    changes.value++;
  }

  static void publish(
    String source,
    String comicId,
    Map<String, dynamic> cover,
  ) {
    final key = buildDownloadTaskKey(source, comicId);
    _covers.remove(key);
    _covers[key] = Map<String, dynamic>.unmodifiable(cover);
    while (_covers.length > 128) _covers.remove(_covers.keys.first);
    changes.value++;
  }
}
