import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/download_admission.dart';

enum DownloadNoticeKind { none, completed, failed }

class _Completion {
  const _Completion(
    this.identity,
    this.token,
    this.completedAt, {
    this.revision,
  });
  final String identity, token;
  final int? completedAt;
  final int? revision;
  Map<String, Object?> toJson() => {
    'token': token,
    if (completedAt != null) 'completedAt': completedAt,
    if (revision != null) 'revision': revision,
  };
}

/// Device-only acknowledgments of exact completion and failure snapshots.
/// This key is outside PortablePreferences and ordinary file/cloud backups.
/// No task completion claim, access timestamp, disk scan or network call is used.
class DownloadCompletionNotice {
  DownloadCompletionNotice({this.maximumEntries = 2048}) {
    if (maximumEntries < 1 || maximumEntries > 2048) {
      throw ArgumentError(
        'Completion history must contain 1 to 2048 resources',
      );
    }
  }

  static final instance = DownloadCompletionNotice();
  static const storageKey = 'breeze.local.download-completion-seen.v1';
  static const _maximumTokens = 4;
  static const _maximumEncodedBytes = 1024 * 1024;
  static final _digest = RegExp(r'^[a-f0-9]{64}$');
  static Future<void> _writes = Future<void>.value();
  final int maximumEntries;
  final changes = ValueNotifier<int>(0);
  LinkedHashMap<String, List<_Completion>> _seen = LinkedHashMap();
  Future<void>? _initialization;
  bool _initialized = false;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    if (_initialization case final pending?) return pending;
    // Capture the existing queue before markSeen appends its own write.
    final pendingWrites = _writes;
    final operation = () async {
      await pendingWrites;
      final preferences = await SharedPreferences.getInstance();
      _seen = _decode(preferences.get(storageKey));
      _initialized = true;
      changes.value++;
    }();
    _initialization = operation;
    operation.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_initialization, operation)) _initialization = null;
      },
    );
    return operation;
  }

  bool isUnseen(DownloadCenterItem item) =>
      kind(item) != DownloadNoticeKind.none;

  DownloadNoticeKind kind(DownloadCenterItem item) {
    if (!_initialized) return DownloadNoticeKind.none;
    if (_failures(item).any((failure) => !_contains(_seen, failure))) {
      return DownloadNoticeKind.failed;
    }
    final completion = _completion(item);
    return completion != null && !_contains(_seen, completion)
        ? DownloadNoticeKind.completed
        : DownloadNoticeKind.none;
  }

  /// Call only after content or the collection page actually opened. Capture
  /// both completion and failures so acknowledging a red dot does not expose an
  /// older green one. New attempts during navigation remain unseen; task state
  /// and retry controls are never changed by an acknowledgment.
  Future<void> markSeen(DownloadCenterItem snapshot) {
    final captured = [
      ..._failures(snapshot),
      if (_completion(snapshot) case final completion?) completion,
    ];
    if (captured.isEmpty) return Future<void>.value();
    final ready = initialize();
    final operation = _writes.then((_) async {
      await ready;
      final preferences = await SharedPreferences.getInstance();
      final next = _decode(preferences.get(storageKey));
      if (captured.every((token) => _contains(next, token))) {
        if (captured.any((token) => !_contains(_seen, token))) {
          _seen = next;
          changes.value++;
        }
        return;
      }
      for (final completion in captured) {
        if (_contains(next, completion)) continue;
        final tokens = [...?next.remove(completion.identity), completion];
        // A logical attempt is not a timestamp. Both remain authentic values,
        // and unknown legacy completion times never become the visit time.
        final retained = tokens.length <= _maximumTokens
            ? tokens
            : (tokens..sort(
                    (a, b) => (b.revision ?? b.completedAt ?? -1).compareTo(
                      a.revision ?? a.completedAt ?? -1,
                    ),
                  ))
                  .take(_maximumTokens)
                  .toList();
        next[completion.identity] = retained;
      }
      while (next.length > maximumEntries) next.remove(next.keys.first);
      final encoded = jsonEncode({
        'version': 1,
        'seen': {
          for (final entry in next.entries)
            entry.key: entry.value.map((row) => row.toJson()).toList(),
        },
      });
      if (utf8.encode(encoded).length > _maximumEncodedBytes) {
        throw StateError('Completion acknowledgment history exceeds limit');
      }
      final previous = preferences.get(storageKey);
      try {
        if (!await preferences.setString(storageKey, encoded)) {
          throw StateError('Completion acknowledgment was not saved');
        }
      } catch (_) {
        // SharedPreferences updates its process cache before the backing write.
        // Restore only our value; do not clear a newer external replacement.
        if (preferences.get(storageKey) == encoded) {
          try {
            await switch (previous) {
              String value => preferences.setString(storageKey, value),
              bool value => preferences.setBool(storageKey, value),
              int value => preferences.setInt(storageKey, value),
              double value => preferences.setDouble(storageKey, value),
              List<String> value => preferences.setStringList(
                storageKey,
                value,
              ),
              _ => preferences.remove(storageKey),
            };
          } catch (_) {}
        }
        rethrow;
      }
      _seen = next;
      changes.value++;
    });
    _writes = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  static bool _contains(
    Map<String, List<_Completion>> values,
    _Completion completion,
  ) =>
      values[completion.identity]?.any(
        (row) => row.token == completion.token,
      ) ==
      true;

  static String _hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  static List<_Completion> _failures(DownloadCenterItem item) {
    if (item.isVideo) {
      final row = item.video!;
      final key = row['key'];
      if (row['status'] != 'failed' ||
          DownloadNetworkWait.fromCode(row['failureReason']) != null ||
          row['external'] == true ||
          row['fileRemoved'] == true ||
          key is! String ||
          key.isEmpty)
        return [];
      final rawTime = row['at'], rawAttempt = row['attempt'];
      final time = rawTime is int && rawTime > 0 ? rawTime : null;
      final attempt = rawAttempt is int && rawAttempt >= 0 ? rawAttempt : null;
      return [
        _Completion(
          _hash(['video-failure', item.source, key]),
          _hash(['failed', key, time, attempt]),
          null,
          revision: attempt ?? time,
        ),
      ];
    }
    final result = <_Completion>[];
    for (final task in item.tasks) {
      final payload = const DownloadTaskRepository().readPayload(task);
      if (task.id <= 0 ||
          task.isDownloading ||
          payload == null ||
          payload.stateCode != 'failed' ||
          payload.attempt < 0 ||
          const {'cancelling', 'fileRemoved'}.contains(payload.phaseCode) ||
          payload.from != item.source ||
          payload.comicId != item.comicId)
        continue;
      result.add(
        _Completion(
          _hash(['comic-failure', payload.from, payload.comicId, task.id]),
          _hash([
            'failed',
            task.id,
            payload.attempt,
            _hash([payload.lastErrorCode, payload.lastErrorMessage]),
          ]),
          null,
          revision: payload.attempt,
        ),
      );
    }
    return result;
  }

  static _Completion? _completion(DownloadCenterItem item) {
    if (item.isVideo) {
      final row = item.video!;
      final id = row['resourceId'], bytes = row['bytes'];
      if (row['status'] != 'saved' ||
          row['local'] != true ||
          row['external'] == true ||
          row['fileRemoved'] == true ||
          row['fileInvalid'] == true ||
          id is! String ||
          !VideoLocalResources.validId(id) ||
          bytes is! int ||
          bytes <= 12) {
        return null;
      }
      final rawTime = row['completedAt'];
      final int? time = rawTime is int && rawTime > 0 ? rawTime : null;
      return _Completion(_hash(['video', id]), _hash([id, time]), time);
    }
    final resource = item.resource;
    if (resource == null || resource.source.isEmpty || resource.comicId.isEmpty)
      return null;
    final identities = <String>{};
    for (final chapter in resource.chapters) {
      if (!chapter.images.any(
        (image) =>
            image.path.trim().isNotEmpty &&
            image.extern['downloadSkipped'] != true,
      ))
        continue;
      final identity = chapter.logicalKey.trim().isNotEmpty
          ? chapter.logicalKey.trim()
          : chapter.taskChapterId.trim().isNotEmpty
          ? chapter.taskChapterId.trim()
          : chapter.id.trim();
      if (identity.isNotEmpty) identities.add(identity);
    }
    if (identities.isEmpty) return null;
    final stamp = resource.downloadedAt.microsecondsSinceEpoch;
    final int? time = stamp > 0 ? stamp : null;
    return _Completion(
      _hash(['comic', resource.source, resource.comicId, resource.key]),
      _hash([time, identities.toList()..sort()]),
      time,
    );
  }

  LinkedHashMap<String, List<_Completion>> _decode(Object? encoded) {
    final result = LinkedHashMap<String, List<_Completion>>();
    if (encoded is! String || encoded.length > _maximumEncodedBytes)
      return result;
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map ||
          raw['version'] != 1 ||
          raw['seen'] is! Map ||
          (raw['seen'] as Map).length > 2048)
        return result;
      for (final entry in (raw['seen'] as Map).entries) {
        if (entry.key is! String ||
            !_digest.hasMatch(entry.key as String) ||
            entry.value is! List ||
            (entry.value as List).length > _maximumTokens)
          continue;
        final tokens = <_Completion>[];
        for (final value in entry.value as List) {
          if (value is! Map ||
              value['token'] is! String ||
              !_digest.hasMatch(value['token'] as String))
            continue;
          final time = value['completedAt'];
          if (time != null && (time is! int || time <= 0)) continue;
          final revision = value['revision'];
          if (revision != null && (revision is! int || revision < 0)) continue;
          tokens.add(
            _Completion(
              entry.key as String,
              value['token'] as String,
              time as int?,
              revision: revision as int?,
            ),
          );
        }
        if (tokens.isNotEmpty) result[entry.key as String] = tokens;
      }
      while (result.length > maximumEntries) result.remove(result.keys.first);
    } catch (_) {
      // Corrupt acknowledgment metadata must not manufacture viewed downloads.
    }
    return result;
  }
}
