import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/sync_failure.dart';

enum SyncTaskPhase {
  preparing,
  accounts,
  artwork,
  artworkPreparing,
  artworkUploading,
  comics,
  videos,
  settings,
  finishing,
  waiting,
}

enum SyncTaskStatus { running, completed, failed, cancelled }

class SyncTaskSnapshot {
  const SyncTaskSnapshot({
    required this.id,
    required this.direction,
    required this.phase,
    this.status = SyncTaskStatus.running,
    this.completedItems,
    this.totalItems,
    this.failure,
  });
  final int id;
  final SyncDirection direction;
  final SyncTaskPhase phase;
  final SyncTaskStatus status;
  final int? completedItems, totalItems;
  final SyncFailureKind? failure;
  bool get running => status == SyncTaskStatus.running;
  // This fraction describes a known item batch only, never the whole round.
  double? get fraction =>
      completedItems != null && totalItems != null && totalItems! > 0
      ? completedItems! / totalItems!
      : null;
}

class SyncTaskAlreadyRunning implements Exception {
  const SyncTaskAlreadyRunning();
}

final syncTaskProgress = SyncTaskProgress();

/// A task belongs to the operation, not a settings State. The zone token also
/// fences callbacks retained by an older task after a newer round has started.
class SyncTaskProgress {
  final _state = ValueNotifier<SyncTaskSnapshot?>(null);
  final _zoneKey = Object();
  Object? _active;
  int _next = 0;
  ValueListenable<SyncTaskSnapshot?> get changes => _state;
  SyncTaskSnapshot? get value => _state.value;
  bool get running => value?.running == true;

  Future<T> run<T>({
    required SyncDirection direction,
    required Future<T> Function() action,
    bool Function(Object)? cancelled,
  }) {
    final inherited = Zone.current[_zoneKey];
    if (_active != null && identical(inherited, _active)) return action();
    if (_active != null || inherited != null) {
      return Future<T>.error(const SyncTaskAlreadyRunning());
    }
    final token = _active = Object();
    final id = ++_next;
    _state.value = SyncTaskSnapshot(
      id: id,
      direction: direction,
      phase: SyncTaskPhase.preparing,
    );
    return runZoned(() async {
      try {
        final result = await action();
        if (identical(_active, token)) {
          _state.value = SyncTaskSnapshot(
            id: id,
            direction: direction,
            phase: SyncTaskPhase.finishing,
            status: SyncTaskStatus.completed,
          );
        }
        return result;
      } catch (error) {
        if (identical(_active, token)) {
          _state.value = SyncTaskSnapshot(
            id: id,
            direction: direction,
            phase: value!.phase,
            status: cancelled?.call(error) == true
                ? SyncTaskStatus.cancelled
                : SyncTaskStatus.failed,
            failure: classifySyncFailure(error),
          );
        }
        rethrow;
      } finally {
        if (identical(_active, token)) _active = null;
      }
    }, zoneValues: {_zoneKey: token});
  }

  void markCancelled(int id) {
    final before = value;
    if (_active != null || before == null || before.id != id) return;
    _state.value = SyncTaskSnapshot(
      id: id,
      direction: before.direction,
      phase: before.phase,
      status: SyncTaskStatus.cancelled,
    );
  }

  void phase(SyncTaskPhase phase, {int? completed, int? total}) {
    if (_active == null || !identical(Zone.current[_zoneKey], _active)) return;
    if ((completed == null) != (total == null) ||
        (total != null && (total < 0 || completed! < 0 || completed > total))) {
      throw ArgumentError('Invalid synchronization item progress');
    }
    final before = value!;
    _state.value = SyncTaskSnapshot(
      id: before.id,
      direction: before.direction,
      phase: phase,
      completedItems: completed,
      totalItems: total,
    );
  }
}
