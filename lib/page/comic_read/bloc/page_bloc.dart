import 'dart:async';
import 'package:zephyr/service/image_recovery.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_read/bloc/page_event.dart';
import 'package:zephyr/page/comic_read/bloc/page_state.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/comic_read/method/get_plugin_read_snapshot.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/event/event.dart';

export 'package:zephyr/page/comic_read/bloc/page_event.dart';
export 'package:zephyr/page/comic_read/bloc/page_state.dart';

class PageBloc extends Bloc<PageEvent, PageState> {
  PageBloc({
    Future<NormalComicEpInfo> Function(PageEvent event)? loadPage,
    ImageRecoveryHub? recoveryHub,
  }) : _loadPage = loadPage,
       super(const PageState()) {
    _recovery = ImageRecoveryController(
      retry: () async {
        final event = _lastEvent;
        if (isClosed || event == null || !_canRecover) return;
        final completion = Completer<void>();
        _recoveryAttempt = completion;
        add(event);
        await completion.future;
      },
      hub: recoveryHub,
      onChanged: () {
        if (isClosed || !_canRecover) return;
        emit(
          state.copyWith(
            status: _recovery.recovering
                ? PageStatus.initial
                : PageStatus.failure,
          ),
        );
      },
    );
    on<PageEvent>(_fetchPages, transformer: restartable());
  }

  final _reads = PageReadTasks();
  late final ImageRecoveryController _recovery;
  PageEvent? _lastEvent;
  bool _canRecover = false;
  Completer<void>? _recoveryAttempt;
  void setRecoveryActive(bool active) => _recovery.setActive(active);

  @override
  Future<void> close() {
    _recovery.dispose();
    unawaited(_reads.cancel());
    final attempt = _recoveryAttempt;
    if (attempt != null && !attempt.isCompleted) attempt.complete();
    return super.close();
  }

  final Future<NormalComicEpInfo> Function(PageEvent event)? _loadPage;

  void _scheduleRecovery(PageEvent event, Object error) {
    _canRecover =
        event.type != ComicEntryType.download &&
        event.type != ComicEntryType.historyAndDownload &&
        imageFailureIsTransient(error);
    if (_canRecover) {
      _recovery.failed(error);
    }
  }

  Future<void> _fetchPages(PageEvent event, Emitter<PageState> emit) async {
    if (isClosed) return;
    unawaited(_reads.cancel());
    if (event != _lastEvent) {
      _recovery.reset();
    }
    final attempt = _recoveryAttempt;
    _recoveryAttempt = null;
    _lastEvent = event;
    _canRecover = false;
    emit(state.copyWith(status: PageStatus.initial));

    final isDownload =
        event.type == ComicEntryType.download ||
        event.type == ComicEntryType.historyAndDownload;
    final source = canonicalQjsSource(event.from);
    final generation = pluginSessionWriteFence.generation(source);
    bool ownsSession() =>
        isDownload ||
        generation == pluginSessionWriteFence.generation(source) &&
            !pluginSessionWriteFence.isChanging(source);

    try {
      if (!ownsSession()) throw const PluginSessionChanged();
      late final NormalComicEpInfo result;
      if (_loadPage != null) {
        result = await _loadPage(event);
      } else if (isDownload) {
        result = await getPluginInfoFromLocal(
          event.from,
          event.comicId,
          event.epsId,
          chapterKey: event.logicalKey.trim().isNotEmpty
              ? event.logicalKey
              : event.chapterId.trim().isNotEmpty
              ? event.chapterId
              : event.requestId,
        );
      } else {
        result = await _reads.run(
          event.from,
          (group) => getPluginReadSnapshot(
            event.comicId,
            event.epsId,
            event.from,
            event.comicInfo,
            event.chapterId,
            event.requestId,
            event.logicalKey,
            event.storageChapterId,
            event.chapterExtern,
            taskGroupKey: group,
            notifyUnauthorized: false,
          ),
        );
      }

      if (isClosed || emit.isDone) return;
      if (!ownsSession()) throw const PluginSessionChanged();
      _canRecover = false;
      _recovery.succeeded();
      emit(state.copyWith(status: PageStatus.success, epInfo: result));
    } catch (error) {
      if (isClosed || emit.isDone) return;
      final failure = ownsSession() ? error : const PluginSessionChanged();
      if (failure is PluginLoginRequiredException) {
        eventBus.fire(
          NeedLogin(
            from: failure.payload.pluginId,
            message: failure.payload.message,
          ),
        );
      } else {
        _scheduleRecovery(event, failure);
      }
      emit(
        state.copyWith(
          status: _canRecover && _recovery.recovering
              ? PageStatus.initial
              : PageStatus.failure,
          epInfo: failure is PluginSessionChanged ? null : state.epInfo,
          errorMessage: isDownload && failure is StateError
              ? 'no element'
              : normalizeSearchErrorMessage(failure),
        ),
      );
    } finally {
      if (attempt != null && !attempt.isCompleted) attempt.complete();
    }
  }
}
