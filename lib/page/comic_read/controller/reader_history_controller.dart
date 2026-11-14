import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/main.dart' show logger;
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';

/// 阅读器历史记录控制器。
///
/// 封装历史服务调用、状态文本同步与历史位置恢复。
/// 所有 ObjectBox 与 worker isolate 副作用均已下沉到 [ReaderHistoryService]。
class ReaderHistoryController {
  ReaderHistoryController({
    required this.comicId,
    required this.order,
    required this.from,
    required this.comicInfo,
    required this.stringSelectCubit,
    required this.getSnapshot,
    required this.getEntryChapterId,
    required this.isHistoryEntry,
    required this.isDownloadEntry,
    required this.jumpToGlobalSlot,
    this.getEntryPageCount,
    this.getEntryChapterKeys,
    ReaderHistoryService? historyService,
  }) : _service = historyService ?? ReaderHistoryService.instance;

  final String comicId;
  final int order;
  final String from;
  final dynamic comicInfo;
  final StringSelectCubit stringSelectCubit;
  final HistorySnapshot? Function() getSnapshot;
  final String Function() getEntryChapterId;
  final bool Function() isHistoryEntry;
  final bool Function() isDownloadEntry;
  final int Function()? getEntryPageCount;
  final Iterable<String> Function()? getEntryChapterKeys;
  final Future<void> Function(int target) jumpToGlobalSlot;

  final ReaderHistoryService _service;
  StreamSubscription<String>? _statusSubscription;
  bool _restoreScheduled = false;
  bool _readyToSave = false;
  int? _owner;
  bool _stopped = false;
  bool get hasRestoredPosition => _readyToSave && _ownsSession;
  bool get ownsSession => _ownsSession;
  bool get _ownsSession =>
      !_stopped && _owner != null && _service.owns(_owner!);

  Future<void> init() async {
    if (_stopped || _owner != null) return;
    _owner = _service.loadHistory(
      source: from,
      comicId: comicId,
      comicInfo: comicInfo,
    );
    _statusSubscription = _service.statusStream.listen((status) {
      if (_ownsSession && !stringSelectCubit.isClosed) {
        stringSelectCubit.setDate(status);
      }
    });
  }

  void _allowSaving() {
    if (!_ownsSession || _readyToSave) return;
    _readyToSave = true;
    _service.markLoaded(_owner!);
    _service.startPeriodicSave(_owner!, getSnapshot);
  }

  void flush() {
    if (_ownsSession) unawaited(_service.flush(_owner!));
  }

  void observePages(List<ReaderChapterPage> Function() getPages) {
    if (!hasRestoredPosition) return;
    for (final page in getPages()) {
      _service.observeChapterPage(_owner!, page);
    }
  }

  void stop() {
    if (_stopped) return;
    if (_ownsSession) unawaited(_service.stop(_owner!));
    _stopped = true;
    unawaited(_statusSubscription?.cancel());
  }

  /// Do not persist the placeholder first page while the resume jump is
  /// waiting for layout. A close or background event can land in that gap.
  void handleHistoryScroll(BuildContext context) {
    if (!_ownsSession || _restoreScheduled || _readyToSave) return;
    if (context.read<ReaderCubit>().state.totalSlots <= 0) return;

    final seamless = context.read<ReaderSeamlessCubit>();
    final downloaded = isDownloadEntry();
    final chapterLoading = downloaded ? _service.loadChapterProgress() : null;
    final historyIndex = isHistoryEntry() || downloaded
        ? _service.historyPageIndex(_owner!, getEntryChapterId())
        : 0;
    if (chapterLoading == null &&
        historyIndex <= 1 &&
        !seamless.isSeamlessEnabled()) {
      _allowSaving();
      return;
    }

    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (chapterLoading != null) {
          try {
            await chapterLoading;
          } catch (error, stackTrace) {
            logger.w(
              'Comic chapter progress could not be loaded',
              error: error,
            );
            logger.d(stackTrace);
          }
        }
        // Let the list or pager attach before translating the saved page.
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted || !_ownsSession) return;
        final totalSlots = context.read<ReaderCubit>().state.totalSlots;
        if (totalSlots <= 0) return;
        final readSetting = context.readEffectiveReadSetting();
        final entryPage = downloaded
            ? _service.downloadedHistoryPageIndex(
                _owner!,
                getEntryChapterId(),
                getEntryPageCount?.call() ?? 0,
                chapterKeys: getEntryChapterKeys?.call(),
              )
            : historyIndex;
        var target = seamless.resolveEntryDefaultGlobalSlot(readSetting);
        if (entryPage > 1) {
          final doublePage = readSetting.doublePageMode;
          target = getSlotIndexFromStoredHistoryPage(
            storedHistoryPage: entryPage,
            enableDoublePage: doublePage,
            insertLeadingBlank:
                doublePage && readSetting.doublePageLeadingBlank,
          );
          if (seamless.isSeamlessEnabled()) {
            target = seamless.resolveHistoryGlobalSlot(target, readSetting);
          }
        }
        target = target.clamp(0, totalSlots - 1);
        if (entryPage > 1 || target != 0) {
          await jumpToGlobalSlot(target);
        }
        _allowSaving();
      } catch (error, stackTrace) {
        logger.w(
          'Reader resume could not settle',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _restoreScheduled = false;
      }
    });
  }
}
