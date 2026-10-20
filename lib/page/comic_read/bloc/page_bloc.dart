import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:zephyr/page/comic_read/bloc/page_event.dart';
import 'package:zephyr/page/comic_read/bloc/page_state.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/comic_read/method/get_plugin_read_snapshot.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';

export 'package:zephyr/page/comic_read/bloc/page_event.dart';
export 'package:zephyr/page/comic_read/bloc/page_state.dart';

const throttleDuration = Duration(milliseconds: 100);

EventTransformer<E> throttleDroppable<E>(Duration duration) {
  return (events, mapper) {
    return droppable<E>().call(events.throttle(duration), mapper);
  };
}

class PageBloc extends Bloc<PageEvent, PageState> {
  PageBloc() : super(const PageState()) {
    on<PageEvent>(
      _fetchPages,
      transformer: throttleDroppable(throttleDuration),
    );
  }

  Future<void> _fetchPages(PageEvent event, Emitter<PageState> emit) async {
    emit(state.copyWith(status: PageStatus.initial));

    try {
      final isDownload =
          event.type == ComicEntryType.download ||
          event.type == ComicEntryType.historyAndDownload;

      late final NormalComicEpInfo result;
      if (isDownload) {
        result = await getPluginInfoFromLocal(
          event.from,
          event.comicId,
          event.epsId,
        );
      } else {
        Future<NormalComicEpInfo> load() => getPluginReadSnapshot(
          event.comicId,
          event.epsId,
          event.from,
          event.comicInfo,
          event.chapterId,
          event.requestId,
          event.logicalKey,
          event.storageChapterId,
          event.chapterExtern,
        );
        try {
          result = await load();
        } catch (error) {
          if (!isTransientNetworkError(error)) rethrow;
          // Read-only snapshot requests can safely be retried once. Never
          // loop indefinitely while the reader has no content.
          await Future<void>.delayed(const Duration(milliseconds: 350));
          result = await load();
        }
      }

      if (emit.isDone) return;
      emit(state.copyWith(status: PageStatus.success, epInfo: result));
    } on StateError catch (error) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: PageStatus.failure,
          errorMessage:
              event.type == ComicEntryType.download ||
                  event.type == ComicEntryType.historyAndDownload
              ? 'no element'
              : normalizeSearchErrorMessage(error),
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: PageStatus.failure,
          errorMessage: normalizeSearchErrorMessage(e),
        ),
      );
    }
  }
}
