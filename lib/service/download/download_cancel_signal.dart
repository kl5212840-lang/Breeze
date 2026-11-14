import 'dart:async';

const downloadTaskCancelledMessage = '__DOWNLOAD_TASK_CANCELLED__';

class DownloadTaskCancelledException implements Exception {
  const DownloadTaskCancelledException();

  @override
  String toString() => downloadTaskCancelledMessage;
}

final Map<String, Completer<void>> _downloadCancelSignals = {};
final Set<String> _preserveCancelledFiles = {};

void prepareDownloadCancelSignal(String taskKey) {
  _downloadCancelSignals.remove(taskKey);
  _preserveCancelledFiles.remove(taskKey);
}

void triggerDownloadCancelSignal(String taskKey, {bool preserveFiles = false}) {
  if (preserveFiles) _preserveCancelledFiles.add(taskKey);
  final completer = _downloadCancelSignals.putIfAbsent(
    taskKey,
    () => Completer<void>(),
  );
  if (!completer.isCompleted) {
    completer.complete();
  }
}

void clearDownloadCancelSignal(String taskKey) {
  _downloadCancelSignals.remove(taskKey);
  _preserveCancelledFiles.remove(taskKey);
}

bool preserveCancelledDownloadFiles(String taskKey) =>
    _preserveCancelledFiles.contains(taskKey);

bool isDownloadCancelSignaled(String taskKey) {
  final completer = _downloadCancelSignals[taskKey];
  return completer?.isCompleted ?? false;
}

Future<T> raceWithDownloadCancel<T>(String taskKey, Future<T> future) async {
  if (isDownloadCancelSignaled(taskKey)) {
    throw const DownloadTaskCancelledException();
  }

  final completer = _downloadCancelSignals.putIfAbsent(
    taskKey,
    () => Completer<void>(),
  );
  return Future.any([
    future,
    completer.future.then<T>(
      (_) => throw const DownloadTaskCancelledException(),
    ),
  ]);
}
