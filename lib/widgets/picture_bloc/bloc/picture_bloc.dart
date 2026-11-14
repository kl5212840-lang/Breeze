import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_event.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_state.dart';

export 'package:zephyr/widgets/picture_bloc/bloc/picture_event.dart';
export 'package:zephyr/widgets/picture_bloc/bloc/picture_state.dart';

const throttleDuration = Duration(milliseconds: 100);
EventTransformer<E> throttleDroppable<E>(Duration duration) =>
    (events, mapper) => droppable<E>().call(events.throttle(duration), mapper);

typedef PicturePathLoader = Future<String> Function(GetPicture request);

class _PublishPictureState {
  const _PublishPictureState(this.value, this.epoch);
  final PictureLoadState value;
  final int epoch;
}

class PictureBloc extends Bloc<Object, PictureLoadState> {
  PictureBloc({
    bool autoRecover = true,
    bool initiallyActive = true,
    bool useDownloads = true,
    ImageRecoveryHub? recoveryHub,
    PicturePathLoader? loader,
  }) : _active = initiallyActive,
       _loader = loader,
       _useDownloads = useDownloads,
       super(const PictureLoadState()) {
    on<_PublishPictureState>((event, emit) {
      if (event.epoch == _epoch) emit(event.value);
    });
    if (autoRecover)
      _recovery = ImageRecoveryController(
        active: initiallyActive,
        hub: recoveryHub,
        imageHost: () => Uri.tryParse(_last?.pictureInfo.url ?? '')?.host,
        retry: () async {
          if (_last != null) await _execute(_last!);
        },
        onChanged: _recoveryChanged,
      );
    _session = pluginSessionWriteFence.changes.listen((boundary) {
      final request = _last;
      if (request != null &&
          request.usePlugin &&
          normalizePluginId(request.pictureInfo.from) == boundary.source &&
          !boundary.changing &&
          _waitingForSession &&
          _active &&
          !_inflight &&
          !isClosed) {
        unawaited(_execute(request));
      }
    });
    on<GetPicture>((event, _) async {
      _last = event;
      _failure = null;
      _decodeRepairs = 0;
      _recovery?.reset();
      if (_active) await _execute(event);
    }, transformer: droppable());
  }
  final PicturePathLoader? _loader;
  final bool _useDownloads;
  late final StreamSubscription<PluginSessionBoundary> _session;
  ImageRecoveryController? _recovery;
  GetPicture? _last;
  Object? _failure;
  bool _active, _inflight = false, _waitingForSession = false;
  int _epoch = 0, _decodeRepairs = 0;
  bool get recovering => _recovery?.recovering ?? false;
  bool get isLoading => _inflight;
  Object? get lastFailure => _failure;
  bool get pictureNotFound => switch (_failure) {
    DownloadPictureNotFoundException() => true,
    DownloadPictureHttpException(statusCode: 404 || 422) => true,
    _ => false,
  };
  void _publish(PictureLoadState value) {
    if (!isClosed) add(_PublishPictureState(value, _epoch));
  }

  void _recoveryChanged() {
    if (isClosed || _failure == null || _inflight) return;
    _publish(
      state.copyWith(
        status: recovering
            ? PictureLoadStatus.initial
            : PictureLoadStatus.failure,
        result: normalizeSearchErrorMessage(_failure!),
      ),
    );
  }

  void setRecoveryActive(bool active) {
    if (_active == active) return;
    _active = active;
    _recovery?.setActive(active);
    if (active &&
        _last != null &&
        _failure == null &&
        state.status == PictureLoadStatus.initial &&
        !_inflight)
      unawaited(_execute(_last!));
    _recoveryChanged();
  }

  Future<void> retryFailed() async {
    if (_last == null ||
        _inflight ||
        !_active ||
        _failure == null ||
        !imageFailureIsTransient(_failure!))
      return;
    _recovery?.reset();
    await _execute(_last!);
  }

  Future<void> _execute(GetPicture event) async {
    if (_inflight || !_active || isClosed) return;
    _inflight = true;
    _waitingForSession = false;
    final epoch = ++_epoch;
    final source = normalizePluginId(event.pictureInfo.from);
    final session = pluginSessionWriteFence.generation(source);
    var resumeWhenActive = false;
    _publish(state.copyWith(status: PictureLoadStatus.initial, result: null));
    try {
      final info = event.pictureInfo;
      final path =
          await (_loader?.call(event) ??
              getCachePicture(
                from: info.from,
                url: info.url,
                path: info.path,
                cartoonId: info.cartoonId,
                chapterId: info.chapterId,
                storageChapterId: info.storageChapterId,
                pictureType: info.pictureType,
                extern: info.extern,
                usePlugin: event.usePlugin,
                useDownloads: _useDownloads,
                priority: 1,
                isCurrent: () => !isClosed && epoch == _epoch && _active,
              ));
      if (isClosed || epoch != _epoch) return;
      if (path == '404') {
        throw DownloadPictureNotFoundException(info.url);
      }
      _failure = null;
      _recovery?.succeeded();
      _publish(
        state.copyWith(
          status: PictureLoadStatus.success,
          imagePath: path,
          result: null,
        ),
      );
    } catch (error) {
      if (isClosed || epoch != _epoch) return;
      if (error is ImageRecoverySuperseded) {
        _waitingForSession = event.usePlugin;
        // A request cancelled by a changing account must wait for that
        // boundary to settle. Retrying immediately would spin while the
        // session fence keeps refusing admission.
        resumeWhenActive =
            event.usePlugin &&
            !pluginSessionWriteFence.isChanging(source) &&
            session != pluginSessionWriteFence.generation(source);
        _failure = null;
        _publish(state.copyWith(status: PictureLoadStatus.initial));
      } else {
        _failure = error;
        _recovery?.failed(error);
        _publish(
          state.copyWith(
            status: recovering
                ? PictureLoadStatus.initial
                : PictureLoadStatus.failure,
            result: normalizeSearchErrorMessage(error),
          ),
        );
      }
    } finally {
      _inflight = false;
      if (resumeWhenActive && _active && !isClosed && epoch == _epoch)
        unawaited(_execute(event));
    }
  }

  /// A decoder may invalidate one exact cache once. Local downloads are never
  /// deleted, and repeated invalid server bytes remain an explicit failure.
  Future<void> reportDecodeFailure(Object error, {String? imagePath}) async {
    if (isClosed ||
        _last == null ||
        _inflight ||
        imagePath == null ||
        imagePath != state.imagePath)
      return;
    final epoch = _epoch, request = _last!;
    if (_decodeRepairs++ >= 1) {
      _failure = const FormatException('Invalid image data');
      _recovery?.failed(_failure!);
      _recoveryChanged();
      return;
    }
    final info = request.pictureInfo;
    final removed = await invalidateCachedPicture(
      from: info.from,
      path: info.path,
      url: info.url,
      imagePath: imagePath,
      cartoonId: info.cartoonId,
      chapterId: info.chapterId,
      storageChapterId: info.storageChapterId,
      pictureType: info.pictureType,
    );
    if (isClosed || epoch != _epoch) return;
    if (!removed) {
      _failure = const FormatException('Invalid local image');
      _recovery?.failed(_failure!);
      _recoveryChanged();
      return;
    }
    await _execute(request);
  }

  @override
  Future<void> close() {
    _epoch++;
    _recovery?.dispose();
    unawaited(_session.cancel());
    return super.close();
  }
}
