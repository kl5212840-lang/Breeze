part of '../comic_read.dart';

extension _ComicReadInitPart on _ComicReadPageState {
  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // 初始化输入控制器：键盘、手势、缩放。
  void _initInputController() {
    _inputController = ReaderInputController(
      context: context,
      readerCubit: context.read<ReaderCubit>(),
      pageController: _pageController,
      transformationController: _transformationController,
      vsync: this,
      onToggleMenu: _toggleVisibility,
      onToggleDesktopFullscreen: _lifecycleController.toggleDesktopFullscreen,
      onRefreshState: () => _refreshState(() {}),
      isScrollLockedByMultiTouch: () => _isScrollLockedByMultiTouch,
      onUpdateScrollLock: (locked) {
        _refreshState(() {
          _isScrollLockedByMultiTouch = locked;
        });
      },
      buildColumnMode: (enableDoublePage) =>
          _columnModeWidget(enableDoublePage: enableDoublePage),
      buildRowMode: () => _rowModeWidget(),
    );
  }

  // 初始化阅读动作控制器：键盘、点击、自动阅读、音量键共用入口。
  void _initActionController() {
    _actionController = ReaderActionController(
      context: context,
      scrollController: scrollController,
      pageController: _pageController,
      onBeforeTurnPage: _inputController.restoreScaleBeforeTurnPage,
      isUserScrolling: () => _isUserScrollActive,
    );
  }

  // 初始化自动阅读控制器。
  void _initAutoReadController() {
    _autoReadController = ReaderAutoReadController();
  }

  // 初始化系统 UI 控制器。
  void _initSystemUiController() {
    _systemUiController = ReaderSystemUiController();
  }

  // 初始化音量键翻页控制，并监听设置项热更新。
  void _initVolumeController() {
    _volumeController = ReaderVolumeController();
    _volumeController.listen();
  }

  void _setVolumeControllerAction() {
    _volumeController.setActionController(_actionController);
  }

  void _initVolumeKeyPageTurnSubscription() {
    _volumeKeyPageTurnSubscription = context
        .read<GlobalSettingCubit>()
        .stream
        .map((state) => state.readSetting.volumeKeyPageTurn)
        .distinct()
        .listen((_) {
          if (!mounted) return;
          _syncVolumeInterception();
        });
    // 本漫覆盖改了音量键也要重同步（读侧已是有效值）。
    _perComicVolumeKeySubscription = context
        .read<ComicReadPreferenceCubit>()
        .stream
        .map((state) => state.override?.setting.volumeKeyPageTurn)
        .distinct()
        .listen((_) {
          if (!mounted) return;
          _syncVolumeInterception();
        });
  }

  // 初始化历史记录控制器，处理进度恢复与落盘。
  void _initHistoryController() {
    // 周期性保存的回调可能在 widget 卸载后仍被触发一次，
    // 因此在这里直接拿到 cubit 引用，避免闭包中继续使用 BuildContext。
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final perComicCubit = context.read<ComicReadPreferenceCubit>();
    final readerCubit = context.read<ReaderCubit>();
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    ReadSettingState effectiveSetting() =>
        ComicReadPreferenceService.resolveEffective(
          globalSettingCubit.state.readSetting,
          perComicCubit.state.override,
        );
    (int, int, bool, bool)? lastChapterSlot;
    ReaderSeamlessState? lastSeamlessState;
    var lastChapterPages = const <ReaderChapterPage>[];
    List<ReaderChapterPage> chapterPages(int slot, ReadSettingState setting) {
      final state = seamlessCubit.state;
      final key = (
        slot,
        setting.readMode,
        setting.doublePageMode,
        setting.doublePageLeadingBlank,
      );
      if (key != lastChapterSlot || !identical(state, lastSeamlessState)) {
        lastChapterPages = _resolveChapterPages(seamlessCubit, slot, setting);
        lastChapterSlot = key;
        lastSeamlessState = state;
      }
      return lastChapterPages;
    }

    final decodedPages = <(String, int)>{};
    HistorySnapshot? lastDecodedSnapshot;
    List<ReaderChapterPage> displayedPages(int slot, ReadSettingState setting) {
      final pages = chapterPages(slot, setting);
      return [
        for (final page in pages)
          if (decodedPages.contains((page.chapterId, page.pageIndex)))
            (
              chapterId: page.chapterId,
              pageIndex: page.pageIndex,
              lastVisiblePage:
                  decodedPages.contains((page.chapterId, page.lastVisiblePage))
                  ? page.lastVisiblePage
                  : page.pageIndex,
              pageCount: page.pageCount,
            ),
      ];
    }

    HistorySnapshot? decodedSnapshot(List<ReaderChapterPage> pages) {
      if (pages.isEmpty) return lastDecodedSnapshot;
      final primary = pages.first;
      final chapter = seamlessCubit.state.loadedChapters
          .where((chapter) => chapter.epInfo.epId == primary.chapterId)
          .firstOrNull;
      return lastDecodedSnapshot = HistorySnapshot(
        pageIndex: primary.pageIndex + 1,
        chapterOrder: chapter?.order ?? widget.order,
        epInfo: chapter?.epInfo ?? _initialEpInfo,
        chapterPages: pages,
      );
    }

    _observeChapterPages = (slot) {
      final setting = effectiveSetting();
      _historyController.observePages(() {
        final pages = displayedPages(slot, setting);
        decodedSnapshot(pages);
        return pages;
      });
    };
    _onPageDecoded = (chapter, page) {
      final key = (chapter, page);
      decodedPages
        ..remove(key)
        ..add(key);
      if (decodedPages.length > 128) decodedPages.remove(decodedPages.first);
      _observeChapterPages(readerCubit.state.currentSlot);
    };

    _historyController = ReaderHistoryController(
      comicId: comicId,
      order: widget.order,
      from: widget.from,
      comicInfo: widget.comicInfo,
      stringSelectCubit: context.read<StringSelectCubit>(),
      getSnapshot: () => decodedSnapshot(
        displayedPages(readerCubit.state.currentSlot, effectiveSetting()),
      ),
      getEntryChapterId: () => _initialEpInfo.epId,
      getEntryPageCount: () => _initialEpInfo.docs.length,
      getEntryChapterKeys: () {
        final download = comicInfo;
        return download is UnifiedComicDownload
            ? localDownloadChapterHistoryKeys(download, _initialEpInfo.epId)
            : [_initialEpInfo.epId];
      },
      isHistoryEntry: () => _isHistory,
      isDownloadEntry: () => _isOffline,
      jumpToGlobalSlot: (target) async {
        await _jumpToGlobalSlot(
          target,
          isStillActive: () => _historyController.ownsSession,
        );
        await WidgetsBinding.instance.endOfFrame;
      },
    );

    unawaited(_historyController.init());
  }

  List<ReaderChapterPage> _resolveChapterPages(
    ReaderSeamlessCubit seamless,
    int slot,
    ReadSettingState setting,
  ) {
    if (!seamless.isSeamlessEnabled()) {
      final pageCount = _initialEpInfo.docs.length;
      final doublePage = setting.doublePageMode;
      final leadingBlank = doublePage && setting.doublePageLeadingBlank;
      final page = getDisplayPageNumber(
        slotIndex: slot,
        enableDoublePage: doublePage,
        insertLeadingBlank: leadingBlank,
      );
      if (slot < 0 || page > pageCount) return const [];
      final spread = doublePage && (!leadingBlank || slot > 0);
      return [
        (
          chapterId: _initialEpInfo.epId,
          pageIndex: page,
          lastVisiblePage: spread && page < pageCount ? page + 1 : page,
          pageCount: pageCount,
        ),
      ];
    }

    final images = seamless.resolveHistorySlotImages(slot, setting);
    if (images == null) return const [];
    final (first, second) = images;
    ReaderChapterPage? progress(ReadModeEntry entry, ReadModeEntry? trailing) {
      final chapter = seamless.state.loadedChapters
          .where((chapter) => chapter.order == entry.chapterOrder)
          .firstOrNull;
      final page = entry.chapterPageIndex! + 1;
      if (chapter == null) return null;
      return (
        chapterId: chapter.epInfo.epId,
        pageIndex: page,
        lastVisiblePage: trailing == null
            ? page
            : trailing.chapterPageIndex! + 1,
        pageCount: chapter.epInfo.docs.length,
      );
    }

    final sameChapter = second?.chapterOrder == first.chapterOrder;
    return [
      ?progress(first, sameChapter ? second : null),
      if (second != null && !sameChapter) ?progress(second, null),
    ];
  }

  // 初始化生命周期控制器，订阅菜单/设置变化并执行首帧同步。
  void _initLifecycleController() {
    _lifecycleController = ReaderLifecycleController(
      context: context,
      readerCubit: context.read<ReaderCubit>(),
      systemUiController: _systemUiController,
      volumeController: _volumeController,
      autoReadController: _autoReadController,
      historyController: _historyController,
      onRefreshState: () => _refreshState(() {}),
      onSyncSystemUi: ({force = false}) => _syncSystemUi(force: force),
      onFlushImageSizeCache: () {
        final imageContext = _imageSizeContext;
        if (imageContext != null && imageContext.mounted) {
          unawaited(imageContext.read<ImageSizeCubit>().flushNow());
        }
      },
      isDesktopPlatform: () => _isDesktopPlatform,
    );
  }

  // 根据当前章节 order 同步 JumpChapter 和 epInfo，供章节选择器/上下章跳转使用。
  void _syncJumpChapterState({required int order}) {
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final ref = seamlessCubit.chapterRefByOrder(order);
    final chapter = seamlessCubit.state.loadedChapters.firstWhere(
      (item) => item.order == order,
      orElse: () => seamlessCubit.state.loadedChapters.first,
    );
    if (ref != null) {
      _jumpChapter.order = order;
      _jumpChapter.chapterId = ref.id;
      _jumpChapter.requestId = ref.requestId;
      _jumpChapter.storageChapterId = ref.storageChapterId;
      _jumpChapter.logicalKey = ref.logicalKey;
      _jumpChapter.chapterExtern = Map<String, dynamic>.from(ref.extern);
      final index = seamlessCubit.catalogIndexByOrder(order);
      _jumpChapter.havePrev = index > 0;
      _jumpChapter.haveNext = index < seamlessCubit.catalogLength - 1;
    }
    epInfo = chapter.epInfo;
  }

  // 章节跳转器集中初始化，后续查找和替换更快。
  void _initJumpChapter(bool isMenuVisible) {
    _jumpChapter = JumpChapter.create(
      _type,
      isMenuVisible,
      comicInfo,
      widget.order,
      widget.chapterId,
      widget.requestId,
      widget.storageChapterId,
      widget.logicalKey,
      Map<String, dynamic>.from(widget.chapterExtern),
      widget.epsNumber,
      comicId,
      widget.from,
    );
  }
}
