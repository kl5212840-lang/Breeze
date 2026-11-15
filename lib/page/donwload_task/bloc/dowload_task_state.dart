part of 'dowload_task_bloc.dart';

@freezed
class DowloadTaskState with _$DowloadTaskState {
  const factory DowloadTaskState.initial() = _Initial;
  const factory DowloadTaskState.loaded({
    required List<DownloadTask> tasks,
    required int pendingCount,
  }) = _Loaded;
}

final _taskIndexes = Expando<_DownloadTaskIndex>();

class _DownloadTaskIndex {
  _DownloadTaskIndex(this._tasks);

  final List<DownloadTask> _tasks;
  late final byId = {for (final task in _tasks) task.id: task};
  late final byWork = _groupByWork();

  Map<(String, String), List<DownloadTask>> _groupByWork() {
    const repository = DownloadTaskRepository();
    final groups = <(String, String), List<DownloadTask>>{};
    for (final task in _tasks) {
      final payload = repository.readPayload(task);
      if (payload == null) continue;
      groups.putIfAbsent((payload.from, payload.comicId), () => []).add(task);
    }
    return groups;
  }
}

extension DownloadTaskLookup on DowloadTaskState {
  _DownloadTaskIndex? get _index => switch (this) {
    _Loaded(:final tasks) => _taskIndexes[this] ??= _DownloadTaskIndex(tasks),
    _ => null,
  };

  DownloadTask? taskById(int id) => _index?.byId[id];

  Iterable<DownloadTask> tasksForComic(String source, String comicId) =>
      _index?.byWork[(source, comicId)] ?? const [];
}
