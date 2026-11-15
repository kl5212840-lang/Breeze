import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_task_repository.dart';

part 'dowload_task_bloc.freezed.dart';
part 'dowload_task_event.dart';
part 'dowload_task_state.dart';

class DowloadTaskBloc extends Bloc<DowloadTaskEvent, DowloadTaskState> {
  static const _backgroundReadThreshold = 64;

  StreamSubscription<Query<DownloadTask>>? _watchSubscription;
  Timer? _refresh;
  bool _hasSnapshot = false;
  bool _reading = false;
  bool _refreshNeeded = false;
  bool _closing = false;
  var _previousTasks = <int, DownloadTask>{};

  DowloadTaskBloc() : super(_Initial()) {
    on<DowloadTaskEvent>(_onEvent);
  }

  void _onEvent(DowloadTaskEvent event, Emitter<DowloadTaskState> emit) {
    event.when(
      started: _watchTasks,
      tasksUpdated: (tasks) => _handleTasksUpdated(tasks, emit),
      taskDeleted: (taskId) => _deleteTask(taskId, emit),
      cancelCurrentTask: () => _cancelCurrentTask(emit),
      clearCompleted: () => _clearCompletedTasks(emit),
    );
  }

  void _watchTasks() {
    if (_watchSubscription != null) return;
    final watchedQuery = objectbox.downloadTaskBox
        .query()
        .order(DownloadTask_.id)
        .watch(triggerImmediately: true);

    late Query<DownloadTask> query;

    void schedule() {
      if (_closing || _reading || _refresh != null) return;
      _refresh = Timer(
        _hasSnapshot ? const Duration(milliseconds: 64) : Duration.zero,
        () {
          _refresh = null;
          unawaited(_readSnapshot(query, schedule));
        },
      );
    }

    _watchSubscription = watchedQuery.listen((watched) {
      query = watched;
      _refreshNeeded = true;
      schedule();
    });
  }

  Future<void> _readSnapshot(
    Query<DownloadTask> query,
    void Function() schedule,
  ) async {
    if (_closing) return;
    _reading = true;
    _refreshNeeded = false;
    try {
      // ObjectBox starts an isolate for each async read. Keep tiny snapshots
      // synchronous and move larger reads away from the frame scheduler.
      final rows = query.count() < _backgroundReadThreshold
          ? query.find()
          : await query.findAsync();
      if (_closing) return;
      final tasks = reuseDownloadTaskRows(rows, _previousTasks);
      if (_hasSnapshot &&
          tasks.length == _previousTasks.length &&
          tasks.every((task) => identical(task, _previousTasks[task.id]))) {
        return;
      }
      _hasSnapshot = true;
      _previousTasks = {for (final task in tasks) task.id: task};
      add(DowloadTaskEvent.tasksUpdated(tasks));
    } catch (error, stackTrace) {
      if (!_closing) addError(error, stackTrace);
    } finally {
      _reading = false;
      if (_refreshNeeded) schedule();
    }
  }

  void _handleTasksUpdated(
    List<DownloadTask> tasks,
    Emitter<DowloadTaskState> emit,
  ) {
    emit(
      DowloadTaskState.loaded(
        tasks: tasks,
        pendingCount: tasks.where((task) => !task.isCompleted).length,
      ),
    );
  }

  void _deleteTask(int taskId, Emitter<DowloadTaskState> emit) {
    final task = objectbox.downloadTaskBox.get(taskId);
    if (task == null) return;
    String? taskKey;
    try {
      taskKey = task.taskInfo?.taskKey;
    } catch (_) {
      taskKey = null;
    }
    // 先排空在途后台写再删，防止旧写复活已删除的任务。
    final removal = taskKey == null
        ? Future.value()
        : const DownloadTaskRepository().flushTaskWrites(taskKey);
    unawaited(removal.then((_) => objectbox.downloadTaskBox.remove(taskId)));
  }

  void _cancelCurrentTask(Emitter<DowloadTaskState> emit) {
    DownloadQueueManager.instance.cancelCurrentTask();
  }

  void _clearCompletedTasks(Emitter<DowloadTaskState> emit) {
    final completedTasks = objectbox.downloadTaskBox
        .query(DownloadTask_.isCompleted.equals(true))
        .build()
        .find();

    for (final task in completedTasks) {
      objectbox.downloadTaskBox.remove(task.id);
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    _refresh?.cancel();
    _watchSubscription?.cancel();
    return super.close();
  }
}
