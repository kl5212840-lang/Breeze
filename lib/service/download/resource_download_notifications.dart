import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/service/download/download_notification_reporter.dart';
import 'package:zephyr/service/download/download_task_repository.dart';

enum ResourceDownloadState { pending, completed, cancelled }

typedef ResourceDownloadItem = ({
  String work,
  String item,
  String title,
  String episode,
  int attempt,
  ResourceDownloadState state,
});

String _identity(List<Object> parts) =>
    sha256.convert(utf8.encode(jsonEncode(parts))).toString();

/// The queue's durable state is the source of truth. Only identities observed
/// pending can produce an alert, so upgrades never announce old downloads.
final class ResourceDownloadNotifications {
  ResourceDownloadNotifications({
    required Future<List<ResourceDownloadItem>> Function() read,
    required String Function() mode,
    required Future<void> Function(int id, String name) deliver,
  }) : _read = read,
       _mode = mode,
       _deliver = deliver;

  static final instance = ResourceDownloadNotifications(
    read: _readLocalTasks,
    mode: () =>
        objectbox.userSettingBox
            .get(1)
            ?.globalSetting
            .downloadCompletionNotice ??
        'off',
    deliver: (id, name) => DownloadNotificationReporter().sendWithId(
      id,
      t.download.notificationCompleteTitle,
      t.download.toastDownloadComplete(comicName: name),
    ),
  );

  static const storageKey = 'breeze.local.resource-download-notices.v1';
  final Future<List<ResourceDownloadItem>> Function() _read;
  final String Function() _mode;
  final Future<void> Function(int id, String name) _deliver;
  Future<void> _tail = Future.value();
  bool _ready = false, _observing = false, _dirty = false, _scheduled = false;
  StreamSubscription? _comicChanges, _settingsChanges;
  int? _comicRowCount;
  final _sending = <String>{};

  Future<void> startObserving() {
    if (_observing) return settle();
    _observing = true;
    _comicRowCount = objectbox.downloadTaskBox.count();
    _comicChanges = objectbox.downloadTaskBox.query().watch().listen((query) {
      final count = query.count();
      if (_comicRowCount == count) return;
      _comicRowCount = count;
      changed();
    });
    _settingsChanges = objectbox.userSettingBox.query().watch().listen(
      (_) => changed(),
    );
    VideoExportRecords.completionInputsChanged.addListener(changed);
    changed();
    return settle();
  }

  void stopObserving() {
    if (!_observing) return;
    _observing = false;
    _comicChanges?.cancel();
    _settingsChanges?.cancel();
    _comicChanges = _settingsChanges = null;
    VideoExportRecords.completionInputsChanged.removeListener(changed);
  }

  void enableDelivery() {
    _ready = true;
    changed();
  }

  void changed() {
    _dirty = true;
    if (_scheduled) return;
    _scheduled = true;
    unawaited(
      _tail = _tail.then((_) async {
        try {
          while (_dirty) {
            _dirty = false;
            await _reconcile();
          }
        } catch (error, stack) {
          logger.w(
            'Resource download notification state could not be saved',
            error: error,
            stackTrace: stack,
          );
        } finally {
          _scheduled = false;
          if (_dirty) changed();
        }
      }),
    );
  }

  Future<void> settle() => _tail;

  Future<void> observeBeforeWork() {
    if (!_observing) return Future.value();
    changed();
    return settle();
  }

  static Map<String, dynamic> _load(SharedPreferences prefs) {
    final encoded = prefs.get(storageKey);
    if (encoded is! String || encoded.length > 4000000) return {};
    try {
      final data = jsonDecode(encoded);
      if (data is Map<String, dynamic> &&
          data['version'] == 1 &&
          data['pending'] is Map &&
          data['outbox'] is Map &&
          data['blocked'] is List) {
        final pending = data['pending'] as Map, outbox = data['outbox'] as Map;
        final blocked = data['blocked'] as List;
        bool text(Object? value) =>
            value is String && value.isNotEmpty && value.length <= 512;
        if (pending.length <= 12000 &&
            outbox.length <= 256 &&
            blocked.length <= 12000 &&
            blocked.every(text) &&
            pending.entries.every(
              (entry) =>
                  text(entry.key) &&
                  entry.value is List &&
                  entry.value.length == 2 &&
                  text(entry.value[0]) &&
                  entry.value[1] is int,
            ) &&
            outbox.entries.every(
              (entry) =>
                  entry.key is String &&
                  RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key) &&
                  entry.value is List &&
                  entry.value.length == 5 &&
                  text(entry.value[0]) &&
                  text(entry.value[1]) &&
                  text(entry.value[2]) &&
                  entry.value[3] is int &&
                  entry.value[4] is bool,
            ))
          return data;
      }
    } on FormatException {
      // A damaged ledger cannot safely claim that an old item was pending.
    }
    return {};
  }

  Future<void> _reconcile() async {
    final rows = await _read();
    final prefs = await SharedPreferences.getInstance();
    final before = _load(prefs);
    final pending = Map<String, dynamic>.from(before['pending'] as Map? ?? {});
    final outbox = Map<String, dynamic>.from(before['outbox'] as Map? ?? {});
    final blocked = (before['blocked'] as List? ?? []).cast<String>().toSet();
    final mode = _mode();
    final observed = {for (final row in rows) row.item: row};
    final discardedWorks = <String>{};
    final previouslyPending = pending.keys.toSet();
    for (final row in rows) {
      if (row.state == ResourceDownloadState.pending) {
        pending[row.item] = [row.work, row.attempt];
      }
    }
    final completed = <String, List<ResourceDownloadItem>>{};
    for (final item in previouslyPending) {
      final row = observed[item];
      if (row == null || row.state == ResourceDownloadState.cancelled) {
        final previous = pending.remove(item) as List;
        final work = previous.first as String;
        discardedWorks.add(work);
        blocked.add(work);
      } else if (row.state == ResourceDownloadState.completed) {
        final previous = pending.remove(item);
        if (previous is List &&
            previous.length == 2 &&
            previous[1] is int &&
            (previous[1] as int) <= row.attempt) {
          (completed[row.work] ??= []).add(row);
        }
      }
    }
    if (mode == 'off') {
      outbox.clear();
    } else {
      final waitingWorks = {
        for (final value in pending.values)
          if (value is List && value.isNotEmpty) value.first,
      };
      for (final group in completed.entries) {
        if (mode == 'episode') {
          for (final row in group.value) {
            outbox[_identity(['episode', row.item, row.attempt])] = [
              row.episode,
              row.work,
              row.item,
              row.attempt,
              false,
            ];
          }
        } else if (!waitingWorks.contains(group.key) &&
            !blocked.contains(group.key)) {
          final finalItems =
              group.value.map((row) => '${row.item}:${row.attempt}').toList()
                ..sort();
          outbox[_identity(['work', group.key, ...finalItems])] = [
            group.value.first.title,
            group.key,
            group.value.first.item,
            group.value.first.attempt,
            true,
          ];
        }
      }
    }
    blocked.removeWhere(
      (work) => !pending.values.any((value) => value[0] == work),
    );
    outbox.removeWhere(
      (_, value) =>
          !_canDeliver(value as List, observed) ||
          (value[4] == true && discardedWorks.contains(value[1])),
    );
    while (outbox.length > 256) {
      outbox.remove(outbox.keys.first);
    }
    final after = {
      'version': 1,
      'pending': pending,
      'outbox': outbox,
      'blocked': blocked.toList(),
    };
    if (jsonEncode(after) != jsonEncode(before)) await _save(prefs, after);
    if (!_ready || mode == 'off') return;
    for (final entry in outbox.entries) {
      if (_sending.add(entry.key)) {
        unawaited(_send(entry.key, entry.value as List));
      }
    }
  }

  static Future<void> _save(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    final previous = prefs.get(storageKey);
    try {
      if (!await prefs.setString(storageKey, jsonEncode(data))) {
        throw StateError('Download notification ledger was not saved');
      }
    } catch (_) {
      try {
        if (previous is String) {
          await prefs.setString(storageKey, previous);
        } else {
          await prefs.remove(storageKey);
        }
      } catch (_) {}
      rethrow;
    }
  }

  bool _canDeliver(List event, Map<String, ResourceDownloadItem> rows) {
    final row = rows[event[2]];
    return row?.state == ResourceDownloadState.completed &&
        row?.attempt == event[3] &&
        (!(event[4] as bool) ||
            !rows.values.any(
              (item) =>
                  item.work == event[1] &&
                  item.state == ResourceDownloadState.pending,
            ));
  }

  Future<void> _send(String key, List event) async {
    try {
      final rows = {for (final row in await _read()) row.item: row};
      if (_mode() != 'off' && _canDeliver(event, rows)) {
        // Reuse the platform notification ID if the process exits after the
        // platform accepted it but before the outbox acknowledgement.
        final id = int.parse(key.substring(0, 7), radix: 16);
        await _deliver(id, event.first as String);
      }
      await (_tail = _tail
          .then((_) async {
            final prefs = await SharedPreferences.getInstance();
            final data = _load(prefs);
            final outbox = Map<String, dynamic>.from(
              data['outbox'] as Map? ?? {},
            );
            if (outbox.remove(key) != null) {
              await _save(prefs, {...data, 'outbox': outbox});
            }
          })
          .catchError((Object error, StackTrace stack) {
            logger.w(
              'Download notification acknowledgement failed',
              error: error,
              stackTrace: stack,
            );
          }));
    } catch (error, stack) {
      logger.w(
        'Download notification delivery failed',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _sending.remove(key);
    }
  }

  static Future<List<ResourceDownloadItem>> _readLocalTasks() async {
    const repository = DownloadTaskRepository();
    final comic = <String, ResourceDownloadItem>{};
    for (final task
        in repository.getAll()..sort((a, b) => a.id.compareTo(b.id))) {
      final payload = repository.readPayload(task);
      if (payload == null || payload.from.isEmpty || payload.comicId.isEmpty)
        continue;
      final title = payload.comicName;
      final chapter = payload.chapterRef.title.trim();
      final identity = _identity([
        'comic',
        payload.from,
        payload.comicId,
        payload.chapterKey,
      ]);
      comic[identity] = (
        work: _identity(['comic', payload.from, payload.comicId]),
        item: _identity([identity, task.id]),
        title: title,
        episode: chapter.isEmpty ? title : '$title $chapter',
        attempt: payload.attempt,
        state:
            task.isCompleted &&
                payload.stateCode == 'completed' &&
                payload.phaseCode == 'completed'
            ? ResourceDownloadState.completed
            : task.isCompleted ||
                  payload.stateCode == 'cancelled' ||
                  payload.phaseCode == 'fileRemoved'
            ? ResourceDownloadState.cancelled
            : ResourceDownloadState.pending,
      );
    }
    final video = await VideoExportRecords.readCommittedTransferRows();
    final metadata = await VideoDownloadedDetails.readForResources(
      video,
      includeFavoriteFallback: false,
      includeLocalCover: false,
    );
    return [
      ...comic.values,
      for (final (index, row) in video.indexed)
        _videoItem(
          row,
          metadata[index]?.canonicalWorkId,
          metadata[index]?.moduleNamespace,
          metadata[index]?.title,
        ),
    ];
  }

  static ResourceDownloadItem _videoItem(
    Map<String, dynamic> row,
    String? work,
    String? namespace,
    String? title,
  ) {
    final source = row['source'] as String;
    final item = _identity(['video', source, row['key'] as String]);
    final grouped = work?.isNotEmpty == true && namespace?.isNotEmpty == true;
    return (
      work: grouped ? _identity(['video', source, namespace!, work!]) : item,
      item: item,
      title: grouped && title?.isNotEmpty == true
          ? title!
          : row['title'] as String,
      episode: row['title'] as String,
      attempt: row['attempt'] as int? ?? 0,
      state: row['status'] == 'saved' && row['resourceId'] is String
          ? ResourceDownloadState.completed
          : row['status'] == 'cancelled'
          ? ResourceDownloadState.cancelled
          : ResourceDownloadState.pending,
    );
  }
}
