part of '../comic_read.dart';

extension _ComicReadViewPart on _ComicReadPageState {
  void _prefetchImagesAroundSlot(int globalSlot, ReadSettingState readSetting) {
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        _readerRegionActive &&
        _historyController.ownsSession &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    _imagePrefetchController.setActive(active);
    seamlessCubit.configurePrefetch(
      count: readSetting.preloadChapterCount,
      active: active,
    );
    final entries = seamlessCubit.resolveImageEntriesForPrefetch(
      globalSlot: globalSlot,
      readSetting: readSetting,
      count: readSetting.preloadImageCount.clamp(2, 10).toInt(),
    );
    unawaited(
      _imagePrefetchController.prefetch(
        entries: entries,
        comicId: comicId,
        from: widget.from,
        count: entries.length,
      ),
    );
  }

  Widget _pendingReader(Widget body, {String? chapterTitle}) {
    final index = _jumpChapter.currentChapterIndexIn(_jumpChapter.chapters);
    final routeTitle = index < 0 ? '' : _jumpChapter.chapters[index].name;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleVisibility,
          child: SafeArea(child: body),
        ),
        _comicReadAppBar(title: chapterTitle ?? routeTitle),
        _readerBottom(),
      ],
    );
  }

  Widget _comicReadAppBar({String? title}) {
    final cubit = context.read<ReaderCubit>();
    return ComicReadAppBar(
      title: title ?? epInfo.epName,
      source: widget.from,
      isDesktopFullscreen: _lifecycleController.isDesktopFullscreen,
      onToggleFullscreen: _isDesktopPlatform
          ? () => unawaited(_lifecycleController.toggleDesktopFullscreen())
          : null,
      changePageIndex: (int value) {
        if (!_hasReadyReaderPages) return;
        cubit.updateCurrentSlot(value);
        cubit.updateSliderChanged(0.0);
      },
    );
  }

  bool get _hasReadyReaderPages =>
      context.read<PageBloc>().state.status == PageStatus.success &&
      _imageSizeContext?.mounted == true;

  Widget _pageCountWidget() {
    final readSetting = context.readEffectiveReadSetting();
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final seamlessEnabled = seamlessCubit.isSeamlessEnabled();
    return PageCountWidget(
      epPages: epInfo.epPages,
      getCurrentChapterStartSlot: seamlessEnabled
          ? () => seamlessCubit.currentChapterStartSlot
          : null,
      getCurrentChapterSlotCount: seamlessEnabled
          ? () => seamlessCubit.effectiveCurrentChapterSlotCount()
          : null,
      isTransitionSlot: seamlessEnabled
          ? (globalSlot) =>
                seamlessCubit.isTransitionSlot(globalSlot, readSetting)
          : null,
    );
  }

  Widget _bottomWidget(BuildContext innerContext) {
    final readSetting = context.readEffectiveReadSetting();
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final seamlessEnabled = seamlessCubit.isSeamlessEnabled();
    final slider = SliderWidget(
      observerController: observerController,
      pageController: _pageController,
      getCurrentChapterSlotCount: seamlessEnabled
          ? () => seamlessCubit.effectiveCurrentChapterSlotCount()
          : null,
      mapGlobalToLocalSlot: seamlessEnabled
          ? seamlessCubit.mapGlobalToLocalSlot
          : null,
      mapLocalToGlobalSlot: seamlessEnabled
          ? seamlessCubit.mapLocalToGlobalSlot
          : null,
      isTransitionSlot: seamlessEnabled
          ? (globalSlot) =>
                seamlessCubit.isTransitionSlot(globalSlot, readSetting)
          : null,
      estimateColumnOffset: seamlessEnabled
          ? (context, globalSlot) {
              final imageSizeCubit = context.read<ImageSizeCubit>();
              final viewportWidth = MediaQuery.sizeOf(context).width;
              final contentWidth = getConstrainedImageWidth(
                containerWidth: viewportWidth,
                enableSidePadding: readSetting.sidePaddingEnabled,
                sidePaddingPercent: readSetting.sidePaddingPercent,
              );
              final height = seamlessCubit.estimateColumnHeightBeforeGlobalSlot(
                globalSlot,
                readSetting,
                imageSizeCubit,
                contentWidth,
                viewportHeight: MediaQuery.sizeOf(context).height,
              );
              return height + getReaderTopOffset(context);
            }
          : null,
    );

    return _readerBottom(slider: slider);
  }

  Widget _readerBottom({Widget? slider}) {
    return BottomWidget(
      type: _type,
      comicInfo: comicInfo,
      sliderWidget: slider,
      order: widget.order,
      epsNumber: widget.epsNumber,
      comicId: comicId,
      from: widget.from,
      jumpChapter: _jumpChapter,
      readerContext: context,
      onLandscapeChanged: _setReaderLandscape,
      canChangePage: () => mounted && _hasReadyReaderPages,
    );
  }
}
