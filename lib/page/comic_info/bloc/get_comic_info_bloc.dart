import 'dart:convert';
import 'dart:async';
import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_info/comic_info.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/models/comic_detail_presentation.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

export 'package:zephyr/page/comic_info/bloc/get_comic_info_event.dart';
export 'package:zephyr/page/comic_info/bloc/get_comic_info_state.dart';

const _throttleDuration = Duration(milliseconds: 100);

class _ComicInfoLoad {
  _ComicInfoLoad(this.event, this.scope, {this.automaticRecovery = false});
  final GetComicInfoEvent event;
  final Object scope;
  final bool automaticRecovery;
  final result = Completer<bool>();
  final done = Completer<void>();
  final retired = Completer<void>();
  final reads = PageReadTasks();
  void finish(bool committed) {
    if (!result.isCompleted) {
      result.complete(committed);
    }
  }

  void retire() {
    if (retired.isCompleted) return;
    finish(false);
    retired.complete();
    unawaited(reads.cancel());
  }
}

class GetComicInfoBloc extends Bloc<GetComicInfoEvent, GetComicInfoState> {
  GetComicInfoBloc({this.readDetail, ImageRecoveryHub? recoveryHub})
    : super(const GetComicInfoState()) {
    _recovery = ImageRecoveryController(
      hub: recoveryHub,
      retry: _retryFailed,
      onChanged: _notifyRecovery,
    );
    _sessionChanges = pluginSessionWriteFence.changes.listen(_sessionChanged);
    on<GetComicInfoEvent>(_fetchComicInfo, transformer: _transformLoads);
  }

  final Future<PluginComicDetail> Function(GetComicInfoEvent)? readDetail;
  late final ImageRecoveryController _recovery;
  late final StreamSubscription<PluginSessionBoundary> _sessionChanges;
  GetComicInfoEvent? _lastEvent;
  GetComicInfoEvent? _sessionRefresh;
  bool _recoveryActive = true;
  Object? _lastFailure;
  String? get failureDiagnosticMessage {
    final error = _lastFailure;
    return error == null ? null : normalizeSearchErrorMessage(error);
  }

  void setRecoveryActive(bool value) {
    _recoveryActive = value;
    _recovery.setActive(value);
    _refreshChangedSession();
  }

  void _refreshChangedSession() {
    final event = _sessionRefresh;
    if (event == null ||
        !_recoveryActive ||
        pluginSessionWriteFence.isChanging(normalizePluginId(event.from))) {
      return;
    }
    _sessionRefresh = null;
    unawaited(_refresh(event.copyWith()));
  }

  void _notifyRecovery() {
    if (isClosed || state.recovering == _recovery.recovering) return;
    emit(state.copyWith(recovering: _recovery.recovering));
  }

  void _sessionChanged(PluginSessionBoundary boundary) {
    if (isClosed) return;
    bool isRemoteFromSource(GetComicInfoEvent event) =>
        event.type != ComicEntryType.download &&
        normalizePluginId(event.from) == boundary.source;
    final pending = _refreshLoad;
    final visible = pending != null && !pending.result.isCompleted
        ? pending.event
        : _lastEvent;
    for (final load in _awaited.values) {
      if (isRemoteFromSource(load.event)) load.retire();
    }
    final active = _active;
    if (active != null && isRemoteFromSource(active.event)) active.retire();
    if (visible == null || !isRemoteFromSource(visible)) return;
    _lastEvent = visible;
    _lastFailure = null;
    _refreshError = null;
    _displayScope = null;
    _recovery.reset();
    emit(const GetComicInfoState());
    _sessionRefresh = visible;
    if (!boundary.changing) _refreshChangedSession();
  }

  Future<void> _retryFailed() async {
    final event = _lastEvent;
    if (isClosed ||
        event == null ||
        event.type == ComicEntryType.download ||
        _lastFailure == null) {
      return;
    }
    await _refresh(event, automaticRecovery: true);
  }

  final _awaited = HashMap<GetComicInfoEvent, _ComicInfoLoad>.identity();
  _ComicInfoLoad? _active;
  Future<bool>? _refreshTask;
  _ComicInfoLoad? _refreshLoad;
  Object? _refreshScope;
  Timer? _throttle;
  String? _refreshError;
  Object? _displayScope;
  String? get refreshError => _refreshError;
  Object _scope(GetComicInfoEvent event) =>
      (event.from, event.comicId, event.type, jsonEncode(event.extern ?? {}));

  /// Explicit refresh is awaitable and cannot disappear in ordinary throttling.
  /// The ordinary event path still drops busy/rapid duplicate loads.
  Future<bool> refresh(GetComicInfoEvent event) => _refresh(event);

  Future<bool> _refresh(
    GetComicInfoEvent event, {
    bool automaticRecovery = false,
  }) {
    if (isClosed) {
      return Future.value(false);
    }
    final active = _active;
    if (active != null &&
        !active.result.isCompleted &&
        active.scope == _scope(event)) {
      return active.result.future;
    }
    final scope = _scope(event);
    final pending = _refreshTask;
    if (pending != null &&
        _refreshScope == scope &&
        _refreshLoad?.result.isCompleted == false) {
      return pending;
    }
    _refreshLoad?.retire();
    if (active != null && active.scope != scope) active.retire();
    final load = _ComicInfoLoad(
      event,
      scope,
      automaticRecovery: automaticRecovery,
    );
    _awaited[event] = load;
    final task = load.result.future;
    _refreshTask = task;
    _refreshLoad = load;
    _refreshScope = scope;
    add(event);
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) {
        _refreshTask = null;
      }
    });
  }

  Stream<GetComicInfoEvent> _transformLoads(
    Stream<GetComicInfoEvent> events,
    EventMapper<GetComicInfoEvent> mapper,
  ) => events.concurrentAsyncExpand((event) async* {
    final requested = _awaited[event];
    if (requested == null && (_active != null || _throttle?.isActive == true)) {
      return;
    }
    while (_active != null) {
      await _active!.done.future;
    }
    if (isClosed || requested?.result.isCompleted == true) {
      if (identical(_awaited[event], requested)) _awaited.remove(event);
      return;
    }
    final load = requested ?? _ComicInfoLoad(event, _scope(event));
    _active = load;
    if (requested == null) {
      _throttle?.cancel();
      _throttle = Timer(_throttleDuration, () {});
    }
    try {
      yield* mapper(event);
    } finally {
      load.finish(false);
      if (!load.done.isCompleted) {
        load.done.complete();
      }
      if (identical(_active, load)) {
        _active = null;
      }
      if (identical(_awaited[event], requested)) _awaited.remove(event);
    }
  });

  @override
  Future<void> close() {
    _recovery.dispose();
    unawaited(_sessionChanges.cancel());
    _throttle?.cancel();
    for (final load in _awaited.values) {
      load.retire();
    }
    _active?.retire();
    return super.close();
  }

  Future<void> _fetchComicInfo(
    GetComicInfoEvent event,
    Emitter<GetComicInfoState> emit,
  ) async {
    final load = _active!;
    bool canCommit() => !emit.isDone && !isClosed && !load.result.isCompleted;
    final source = normalizePluginId(event.from);
    final generation = pluginSessionWriteFence.generation(source);
    bool sessionCurrent() =>
        generation == pluginSessionWriteFence.generation(source) &&
        !pluginSessionWriteFence.isChanging(source);
    _lastEvent = event;
    if (sessionCurrent()) _sessionRefresh = null;
    if (!load.automaticRecovery) _recovery.reset();
    final refreshing =
        _awaited.containsKey(event) &&
        _displayScope == _scope(event) &&
        state.allInfo != null;
    _refreshError = null;
    var remoteRead = false;
    try {
      if (!refreshing) emit(state.copyWith(status: GetComicInfoStatus.initial));

      late normal.NormalComicAllInfo normalComicInfo;
      late String resolvedComicId;
      dynamic comicInfo;

      if (event.type == ComicEntryType.download) {
        final query = objectbox.unifiedDownloadBox
            .query(
              UnifiedComicDownload_.uniqueKey.equals(
                '${event.from}:${event.comicId}',
              ),
            )
            .build();
        try {
          comicInfo = query.findFirst();
        } finally {
          query.close();
        }
      }

      if (comicInfo == null) {
        if (event.type == ComicEntryType.download) {
          throw StateError('本机下载资料暂时无法读取');
        }
        remoteRead = true;
        if (!sessionCurrent()) return;
        final pluginResult = await Future.any<PluginComicDetail?>([
          readDetail?.call(event) ??
              load.reads.run(
                source,
                (group) => getComicDetailByPlugin(
                  event.comicId,
                  event.from,
                  extern: event.extern,
                  canPublish: canCommit,
                  taskGroupKey: group,
                ),
              ),
          load.retired.future.then((_) => null),
        ]);
        if (pluginResult == null || !canCommit()) return;
        if (!sessionCurrent()) throw const PluginSessionChanged();
        comicInfo = pluginResult.source;
        normalComicInfo = pluginResult.normalInfo;
        resolvedComicId = pluginResult.comicId;
      } else {
        final download = comicInfo as UnifiedComicDownload;
        var localized = _localizeDownloadDetail(download);
        // 下载入口用记录里的目录快照给已下载章节排序（内存里排，不写库）。
        // 快照缺失的章节缀在最后，保证入口不丢。
        final catalog = readChapterCatalog(download);
        if (catalog.isNotEmpty) {
          localized = localized.copyWith(
            eps: _sortEpsByCatalog(localized.eps, catalog),
          );
        }
        normalComicInfo = localized;
        resolvedComicId = download.comicId;
      }

      if (!canCommit()) return;
      _lastFailure = null;
      _recovery.succeeded();
      _displayScope = (
        event.from,
        resolvedComicId,
        event.type,
        jsonEncode(event.extern ?? {}),
      );
      emit(
        state.copyWith(
          status: GetComicInfoStatus.success,
          result: '',
          allInfo: normalComicInfo,
          comicInfo: comicInfo,
          comicId: resolvedComicId,
          recovering: false,
        ),
      );
      load.finish(true);
    } catch (e, s) {
      if (!canCommit()) return;
      final error = remoteRead && !sessionCurrent()
          ? const PluginSessionChanged()
          : e;
      logger.e(error, stackTrace: s);
      _lastFailure = error;
      final failure = presentComicDetailFailure(error, remote: remoteRead);
      if (remoteRead) _recovery.failed(failure);
      final message = failure.message;
      if (refreshing) _refreshError = message;
      emit(
        state.copyWith(
          status: refreshing
              ? GetComicInfoStatus.success
              : GetComicInfoStatus.failure,
          result: message,
          recovering: _recovery.recovering,
        ),
      );
      load.finish(false);
    }
  }

  /// 按目录快照顺序排列本地 eps，快照里没有的缀在最后（保持原相对顺序）。
  List<normal.Ep> _sortEpsByCatalog(
    List<normal.Ep> localEps,
    List<DownloadChapter> catalog,
  ) {
    if (localEps.isEmpty || catalog.isEmpty) return localEps;
    const adapter = DownloadChapterAdapter();
    final chapters = localEps.map(adapter.fromEp).toList();
    final sorted = sortDownloadChaptersByCatalog(chapters, catalog);
    if (identical(sorted, chapters)) {
      return localEps;
    }
    return sorted.map((c) => localEps[chapters.indexOf(c)]).toList();
  }

  normal.NormalComicAllInfo _localizeDownloadDetail(
    UnifiedComicDownload comicInfo,
  ) {
    var normalComicInfo = normal.NormalComicAllInfo.fromJson(
      jsonDecode(comicInfo.detailJson) as Map<String, dynamic>,
    );
    final localCover = _deepCopyMap(normalComicInfo.comicInfo.cover.toJson());

    final localCreator = _deepCopyMap(
      normalComicInfo.comicInfo.creator.toJson(),
    );

    final localComicInfo = _deepCopyMap(normalComicInfo.comicInfo.toJson())
      ..['cover'] = localCover
      ..['creator'] = localCreator;

    return normalComicInfo.copyWith(
      comicInfo: normal.ComicInfo.fromJson(localComicInfo),
    );
  }

  Map<String, dynamic> _deepCopyMap(Object value) {
    final encoded = jsonEncode(value);
    final decoded = jsonDecode(encoded) as Map;
    return Map<String, dynamic>.from(decoded);
  }
}
