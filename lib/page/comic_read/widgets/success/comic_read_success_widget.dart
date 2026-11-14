import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_state.dart';
import 'package:zephyr/page/comic_read/method/image_size_cache_store.dart';
import 'package:zephyr/page/comic_read/method/prefetch_image_sizes.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class ComicReadSuccessWidget extends StatefulWidget {
  final String comicId;
  final String from;
  final NormalComicEpInfo epInfo;
  final int chapterOrder;
  final bool offlineReader;
  final bool Function() ownsReaderSession;
  final WidgetBuilder buildInteractiveViewer;
  final WidgetBuilder buildPageCount;
  final WidgetBuilder buildAppBar;
  final WidgetBuilder buildBottom;
  final WidgetBuilder buildPending;
  final WidgetBuilder buildAutoReadControl;
  final WidgetBuilder buildEinkControl;
  final int Function(ReadSettingState readSetting)? resolveTotalSlots;
  final void Function(
    BuildContext innerContext,
    ReadSettingState readSetting,
    int readMode,
  )
  onReady;

  const ComicReadSuccessWidget({
    super.key,
    required this.comicId,
    required this.from,
    required this.epInfo,
    required this.chapterOrder,
    this.offlineReader = false,
    required this.ownsReaderSession,
    required this.buildInteractiveViewer,
    required this.buildPageCount,
    required this.buildAppBar,
    required this.buildBottom,
    required this.buildPending,
    required this.buildAutoReadControl,
    required this.buildEinkControl,
    this.resolveTotalSlots,
    required this.onReady,
  });

  @override
  State<ComicReadSuccessWidget> createState() => _ComicReadSuccessWidgetState();
}

class _ComicReadSuccessWidgetState extends State<ComicReadSuccessWidget> {
  late final List<String> _pageKeys;
  late final Future<Map<int, Size>> _persistedSizeFuture;
  // A null cursor means the chapter is running or its scan has finished.
  final _sizePrefetchCursorByOrder = <int, int?>{};
  AppLifecycleListener? _sizePrefetchLifecycle;
  bool _sizePrefetchRouteCurrent = false;

  @override
  void initState() {
    super.initState();
    _pageKeys = _buildPageKeys();
    _persistedSizeFuture = ImageSizeCacheStore(
      sourceTag: widget.from,
      pageKeys: _pageKeys,
    ).readIndexedSizes(pageKeys: _pageKeys, count: widget.epInfo.length);
  }

  @override
  void dispose() {
    _sizePrefetchLifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = context.screenWidth;
    return FutureBuilder<Map<int, Size>>(
      future: _persistedSizeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.buildPending(context);
        }

        final persistedSize = snapshot.data ?? const <int, Size>{};
        return BlocProvider(
          create: (_) => ImageSizeCubit.create(
            defaultWidth: width,
            count: widget.epInfo.length,
            sourceTag: widget.from,
            pageKeys: _pageKeys,
            chapterOrder: widget.chapterOrder,
            persistedCache: persistedSize,
          ),
          child: Builder(
            builder: (innerContext) {
              _scheduleImageSizePrefetch(innerContext);
              final cubit = innerContext.read<ReaderCubit>();
              final readSetting = innerContext.watchEffectiveReadSetting();
              final readMode = readSetting.readMode;
              final backgroundColor = readSetting.resolveReaderBackgroundColor(
                Theme.of(innerContext).brightness,
              );
              final isDarkMode =
                  Theme.of(innerContext).brightness == Brightness.dark;
              final filterOpacityPercent = readSetting.readFilterOpacityPercent
                  .clamp(0, 100)
                  .toDouble();
              final enableReaderFilter =
                  isDarkMode &&
                  readSetting.readFilterEnabled &&
                  filterOpacityPercent > 0;

              final totalSlots = getReadModeSlotCount(
                imageCount: widget.epInfo.length,
                enableDoublePage: readSetting.doublePageMode,
                insertLeadingBlank:
                    readSetting.doublePageMode &&
                    readSetting.doublePageLeadingBlank,
              );
              final resolvedTotalSlots =
                  widget.resolveTotalSlots?.call(readSetting) ?? totalSlots;
              cubit.updateTotalSlots(resolvedTotalSlots);
              widget.onReady(innerContext, readSetting, readMode);

              return BlocListener<ReaderSeamlessCubit, ReaderSeamlessState>(
                listenWhen: (previous, current) =>
                    previous.loadedChapters.length !=
                    current.loadedChapters.length,
                listener: _prefetchLoadedChapterSizes,
                child: Container(
                  color: backgroundColor,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: widget.buildInteractiveViewer(innerContext),
                      ),
                      if (enableReaderFilter)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: true,
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: filterOpacityPercent / 100,
                              ),
                            ),
                          ),
                        ),
                      widget.buildPageCount(innerContext),
                      widget.buildAppBar(innerContext),
                      widget.buildBottom(innerContext),
                      widget.buildAutoReadControl(innerContext),
                      widget.buildEinkControl(innerContext),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _scheduleImageSizePrefetch(BuildContext innerContext) {
    final current = ModalRoute.isCurrentOf(innerContext) != false;
    if (current == _sizePrefetchRouteCurrent) return;
    _sizePrefetchRouteCurrent = current;
    if (!current) return;

    void prefetch() {
      if (!mounted || !innerContext.mounted) return;
      _prefetchLoadedChapterSizes(
        innerContext,
        innerContext.read<ReaderSeamlessCubit>().state,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !innerContext.mounted) return;
      _sizePrefetchLifecycle ??= AppLifecycleListener(onResume: prefetch);
      prefetch();
    });
  }

  void _prefetchLoadedChapterSizes(
    BuildContext context,
    ReaderSeamlessState state,
  ) {
    final imageSizeCubit = context.read<ImageSizeCubit>();
    final route = ModalRoute.of(context);
    bool ownsSession() =>
        mounted &&
        context.mounted &&
        route?.isCurrent != false &&
        widget.ownsReaderSession();

    bool canStart() {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return !imageSizeCubit.isClosed &&
          ownsSession() &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    }

    if (!canStart()) return;
    for (final chapter in state.loadedChapters) {
      final cursor = _sizePrefetchCursorByOrder.putIfAbsent(
        chapter.order,
        () => 0,
      );
      if (cursor == null) continue;
      _sizePrefetchCursorByOrder[chapter.order] = null;
      final readSetting = context.readEffectiveReadSetting();
      final scan = prefetchChapterImageSizes(
        imageSizeCubit: imageSizeCubit,
        docs: chapter.epInfo.docs,
        comicId: widget.comicId,
        from: widget.from,
        chapterId: chapter.epInfo.epId,
        chapterOrder: chapter.order,
        contentWidth: _resolveContentWidth(context, readSetting),
        startPage: cursor,
        offlineReader: widget.offlineReader,
        ownsReaderSession: ownsSession,
      );
      unawaited(
        scan.then((nextPage) {
          if (!mounted || nextPage >= chapter.epInfo.docs.length) return;
          _sizePrefetchCursorByOrder[chapter.order] = nextPage;
          // A foreground or route callback may have seen this scan in flight.
          if (canStart()) {
            _prefetchLoadedChapterSizes(
              context,
              context.read<ReaderSeamlessCubit>().state,
            );
          }
        }),
      );
    }
  }

  double _resolveContentWidth(
    BuildContext context,
    ReadSettingState readSetting,
  ) {
    return getConstrainedImageWidth(
      containerWidth: context.screenWidth,
      enableSidePadding: readSetting.sidePaddingEnabled,
      sidePaddingPercent: readSetting.sidePaddingPercent,
    );
  }

  List<String> _buildPageKeys() {
    return List<String>.generate(widget.epInfo.length, (index) {
      if (index >= widget.epInfo.docs.length) {
        return '${widget.comicId}|${widget.epInfo.epId}|index_$index';
      }

      final doc = widget.epInfo.docs[index];
      final imageId = doc.id.isNotEmpty
          ? doc.id
          : (doc.originalName.isNotEmpty ? doc.originalName : doc.path);
      final key = '${widget.comicId}|${widget.epInfo.epId}|$imageId';
      final variant = onlinePictureCacheVariant(
        from: widget.from,
        url: doc.fileServer,
        type: PictureType.page,
      );
      return variant.isEmpty ? key : '$key|$variant';
    }, growable: false);
  }
}
