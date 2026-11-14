import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/api_video_models.dart';

/// Local viewing metadata only. Never stores cookies, credentials or media
/// source URLs, and never shares the comic reader's page/episode model.
class VideoWatchRecord {
  const VideoWatchRecord({
    required this.watchUrl,
    required this.title,
    required this.position,
    required this.duration,
    required this.updatedAt,
    required this.completed,
    this.coverUrl,
    this.localResourceId,
    this.metadata = const {},
  });

  final Uri watchUrl;
  final String title;
  final Uri? coverUrl;
  final Duration position, duration;
  final DateTime updatedAt;
  final bool completed;
  final String? localResourceId;
  final Map<String, String> metadata;

  static Map<String, String> _metadata(Object? raw) => raw is Map
      ? {
          for (final key in [
            'typeName',
            'genres',
            'year',
            'area',
            'language',
            'writers',
          ])
            if (raw[key] is String && (raw[key] as String).trim().isNotEmpty)
              key: apiVideoText(raw[key], key == 'year' ? 100 : 500),
        }
      : {};

  static Map<String, String> metadataFromItem(ApiVideoItem item) => _metadata({
    'typeName': item.typeName,
    'genres': item.genres,
    'year': item.year,
    'area': item.area,
    'language': item.language,
    'writers': item.writers,
  });

  static Uri? canonicalUrl(Uri url) {
    return videoPlaybackIdentity(url);
  }

  String get legacyProgressKey => videoPlaybackProgressKey(watchUrl);

  Map<String, Object?> toJson() => {
    'watchUrl': watchUrl.toString(),
    'title': title,
    'coverUrl': coverUrl?.toString(),
    'position': position.inMilliseconds,
    'duration': duration.inMilliseconds,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'completed': completed,
    if (localResourceId != null) 'localResourceId': localResourceId,
    if (metadata.isNotEmpty) 'metadata': _metadata(metadata),
  };

  static VideoWatchRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = Uri.tryParse('${raw['watchUrl'] ?? ''}');
    final watch = url == null ? null : canonicalUrl(url);
    final title = raw['title'];
    final position = raw['position'];
    final duration = raw['duration'];
    final timestamp = raw['updatedAt'];
    if (watch == null ||
        title is! String ||
        title.trim().isEmpty ||
        position is! int ||
        duration is! int ||
        timestamp is! int ||
        position < 0 ||
        duration <= 0 ||
        duration > 604800000 ||
        timestamp < 0 ||
        timestamp > 8640000000000000) {
      return null;
    }
    final cover = Uri.tryParse('${raw['coverUrl'] ?? ''}');
    final resource = raw['localResourceId'];
    return VideoWatchRecord(
      watchUrl: watch,
      title: title.trim().substring(0, title.trim().length.clamp(0, 300)),
      position: Duration(milliseconds: position.clamp(0, duration)),
      duration: Duration(milliseconds: duration),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
      completed: raw['completed'] == true,
      localResourceId:
          resource is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(resource)
          ? resource
          : null,
      metadata: Map.unmodifiable(_metadata(raw['metadata'])),
      coverUrl:
          cover?.scheme == 'https' &&
              cover?.host.isNotEmpty == true &&
              cover?.userInfo.isEmpty == true
          ? cover
          : null,
    );
  }
}

class VideoWatchHistory {
  static final changes = ValueNotifier<int>(0);
  static const limit = 200;
  static const _prefix = 'breeze.video.history.v1.';
  static Future<void>? _writes;

  static Future<void> flush() async {
    await _writes;
  }

  /// Keep whole-history import and recovery in the queue with normal writes.
  static Future<T> serializePortableWrite<T>(Future<T> Function() write) =>
      _serialize(write);

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final job = (_writes ?? Future<void>.value()).then((_) => action());
    final tail = job.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _writes = tail;
    unawaited(
      tail.then((_) {
        if (identical(_writes, tail)) _writes = null;
      }),
    );
    return job;
  }

  static String _key(String source) {
    if (source.trim().isEmpty || source.length > 200) {
      throw ArgumentError.value(source, 'source');
    }
    return '$_prefix$source';
  }

  static List<VideoWatchRecord> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final seen = <Uri>{};
      final result = <VideoWatchRecord>[];
      for (final item in decoded.take(limit)) {
        final record = VideoWatchRecord.fromJson(item);
        if (record != null && seen.add(record.watchUrl)) result.add(record);
      }
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (_) {
      // A malformed local record must not prevent opening the video source.
      return [];
    }
  }

  static Future<List<VideoWatchRecord>> read(String source) async {
    await flush();
    final store = await SharedPreferences.getInstance();
    return List.unmodifiable(_decode(store.getString(_key(source))));
  }

  static Future<void> _change(
    String source,
    Future<void> Function(
      SharedPreferences store,
      List<VideoWatchRecord> records,
    )
    change,
  ) {
    final key = _key(source);
    return _serialize(() async {
      final store = await SharedPreferences.getInstance();
      final records = _decode(store.getString(key));
      await change(store, records);
      final saved = await store.setString(
        key,
        jsonEncode(
          records.take(limit).map((record) => record.toJson()).toList(),
        ),
      );
      if (!saved) throw StateError('Video history was not saved');
      changes.value++;
    });
  }

  static Future<void> record(String source, VideoWatchRecord record) {
    final valid = VideoWatchRecord.fromJson(record.toJson());
    if (valid == null) return Future<void>.value();
    return _change(source, (_, records) async {
      final page = videoPublicPage(valid.watchUrl);
      final previous = records
          .where(
            (item) =>
                item.metadata.isNotEmpty &&
                videoPublicPage(item.watchUrl) == page,
          )
          .firstOrNull;
      final merged = VideoWatchRecord.fromJson({
        ...valid.toJson(),
        'metadata': {...?previous?.metadata, ...valid.metadata},
      })!;
      records.removeWhere((item) => item.watchUrl == valid.watchUrl);
      records.insert(0, merged);
    });
  }

  static Future<void> remove(String source, Uri? watchUrl) => _change(source, (
    store,
    records,
  ) async {
    final target = watchUrl == null
        ? null
        : VideoWatchRecord.canonicalUrl(watchUrl);
    if (watchUrl != null && target == null) return;
    for (final record in records.where(
      (item) => target == null || item.watchUrl == target,
    )) {
      if (!await store.remove(record.legacyProgressKey)) {
        throw StateError('Video resume position was not removed');
      }
    }
    records.removeWhere((item) => target == null || item.watchUrl == target);
  });
}
