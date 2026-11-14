import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/donwload_task/service/download_interaction_trace.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_source_manager.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'dart:async';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/donwload_task/view/download_video_work_page.dart';
import 'package:zephyr/page/donwload_task/view/download_help.dart';
import 'package:zephyr/page/setting/download/download_settings_page.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/donwload_task/view/download_filter_sheet.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/page/comic_info/view/comic_info.dart';
import 'package:zephyr/page/donwload_task/bloc/dowload_task_bloc.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';
import 'package:zephyr/page/donwload_task/service/download_comic_archive.dart';
import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_read_queue.dart';
import 'package:zephyr/page/donwload_task/service/download_chapter_reader.dart';
import 'package:zephyr/page/donwload_task/service/download_completion_notice.dart';
import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';
import 'package:zephyr/page/donwload_task/service/download_storage_usage.dart';
import 'package:zephyr/page/donwload_task/view/download_storage_status.dart';
import 'package:zephyr/page/donwload_task/service/download_video_snapshot_merge.dart';
import 'package:zephyr/page/donwload_task/view/download_card_details.dart';
import 'package:zephyr/page/donwload_task/view/download_episode_management.dart';
import 'package:zephyr/page/donwload_task/view/download_comic_chapter_groups.dart';
import 'package:zephyr/page/donwload_task/view/download_work_sections.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';
import 'package:zephyr/service/reader/reader_history_service.dart';
import 'package:zephyr/page/donwload_task/view/download_queue_pause_notice.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/page/donwload_task/view/download_task_cover.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_download.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_retry_action.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_download_retry_host.dart';
import 'package:zephyr/page/video/video_download_failure.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_local_playback.dart';
import 'package:zephyr/page/video/video_download_progress.dart';
import 'package:zephyr/page/video/video_download_progress_text.dart';
import 'package:zephyr/page/video/video_download_cancel_action.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/download_delete_service.dart';
import 'package:zephyr/service/download/download_chapter_removal.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_task_progress.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/download_admission.dart';
import 'package:zephyr/service/download/models/download_task_json.dart'
    show buildDownloadTaskKey, DownloadTaskJson, downloadTaskDeletionPhase;
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_selection_mark.dart';
import 'package:zephyr/widgets/plugin_installation_guard.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'package:zephyr/widgets/scroll_return_to_top.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/widgets/list_position_scrollbar.dart';
import 'package:zephyr/widgets/toast.dart';

String _label(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
const _repository = DownloadTaskRepository();

bool _hasComicDetails(DownloadCenterItem item) =>
    item.source.trim().isNotEmpty && item.comicId?.trim().isNotEmpty == true;

bool _activeVideo(Map<String, dynamic> row) =>
    const {'preparing', 'downloading', 'saving'}.contains(row['status']);

bool _hasVerifiedVideoProgressTarget(Map<String, dynamic> row) =>
    row['status'] == 'saved' &&
    row['local'] == true &&
    row['available'] == true &&
    row['filePresent'] == true &&
    row['resourceReadPending'] != true &&
    row['fileRemoved'] != true &&
    row['fileInvalid'] != true &&
    !isVideoExternalReceipt(row) &&
    row['source'] is String &&
    row['resourceId'] is String &&
    VideoLocalResources.validId(row['resourceId'] as String);

class DownloadTaskPage extends StatelessWidget {
  const DownloadTaskPage({super.key, this.embedded = false});
  final bool embedded;

  static Future<void> openComicDownloads(
    BuildContext context, {
    required String source,
    required String comicId,
    required StringSelectCubit stringSelectCubit,
  }) async {
    final record = _repository.findDownloadRecord(source, comicId);
    if (record == null || record.deleted) {
      showErrorToast(t.download.fileUnavailable);
      return;
    }
    final item = projectDownloadCenter(
      tasks: [],
      comics: [DownloadComicResource(record)],
      videos: [],
    ).single;
    if (item.chapterKeys.isEmpty) {
      showErrorToast(t.download.fileUnavailable);
      return;
    }

    final router = context.router.root;
    final navigator = Navigator.of(context, rootNavigator: true);
    var openingChapter = false;
    await navigator.push<void>(
      _comicDownloadsRoute(
        item,
        openChapter: (origin, key) async {
          if (openingChapter || ModalRoute.isCurrentOf(origin) != true) return;
          openingChapter = true;
          try {
            await _pushDownloadedComicChapter(
              item,
              key,
              router: router,
              stringSelectCubit: stringSelectCubit,
            );
          } finally {
            openingChapter = false;
          }
        },
        openDetails: (_) => navigator.pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DowloadTaskBloc()..add(const DowloadTaskEvent.started()),
    child: _DownloadCenter(embedded: embedded),
  );
}

Future<void> _pushDownloadedComicChapter(
  DownloadCenterItem item,
  String chapterKey, {
  required StackRouter router,
  required StringSelectCubit stringSelectCubit,
}) async {
  if (item.comicId == null) return;
  final route = DownloadChapterReader.findRoute(
    source: item.source,
    comicId: item.comicId!,
    chapterKey: chapterKey,
    stringSelectCubit: stringSelectCubit,
  );
  if (route == null) {
    showErrorToast(t.download.fileUnavailable);
    return;
  }
  try {
    // Opening another chapter can replace the route without resolving the
    // original push's pop future. Hold the tap guard only through navigation.
    await router.pushAll([route]);
    await WidgetsBinding.instance.endOfFrame;
  } catch (_) {
    showErrorToast(t.download.fileUnavailable);
    return;
  }
  try {
    await DownloadCompletionNotice.instance.markSeen(item);
  } catch (_) {
    // Retain the notification if saving the acknowledgment fails.
  }
}

Route<void> _comicDownloadsRoute(
  DownloadCenterItem item, {
  required void Function(BuildContext, String) openChapter,
  required ValueChanged<BuildContext>? openDetails,
  DowloadTaskBloc? bloc,
}) => videoPageRoute<void>(
  settings: const RouteSettings(name: 'breeze.download.comic-chapters'),
  matchAutoRouteTransition: true,
  builder: (_) {
    final page = _DownloadChaptersPage(
      initial: item,
      openChapter: openChapter,
      openDetails: openDetails,
    );
    return bloc == null
        ? BlocProvider(
            create: (_) =>
                DowloadTaskBloc()..add(const DowloadTaskEvent.started()),
            child: page,
          )
        : BlocProvider.value(value: bloc, child: page);
  },
);

/// Header transitions change layout only. Native surfaces are never faded,
/// clipped or transformed, and departed actions are removed immediately.
const _downloadContentInset = 16.0;

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({
    required this.embedded,
    required this.searching,
    required this.managing,
    required this.working,
    required this.inventoryReady,
    required this.rowCount,
    required this.totalCount,
    required this.selectedCount,
    required this.selectableCount,
    required this.query,
    required this.keywordScope,
    required this.onKeywordScope,
    required this.focusNode,
    required this.onSearch,
    required this.onQuery,
    required this.onManage,
    required this.onSelectAll,
  });
  final bool embedded, searching, managing, working, inventoryReady;
  final int rowCount, totalCount, selectedCount, selectableCount;
  final String query;
  final KeywordSearchScope keywordScope;
  final ValueChanged<KeywordSearchScope> onKeywordScope;
  final FocusNode focusNode;
  final VoidCallback onSearch, onManage, onSelectAll;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      _downloadContentInset,
      8,
      _downloadContentInset,
      0,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final titleStyle = theme.textTheme.headlineSmall;
        final countStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        const extent = CollectionToolbarMetrics.actionExtent;
        final titleWidth = (constraints.maxWidth - extent * (embedded ? 3 : 4))
            .clamp(48.0, constraints.maxWidth)
            .toDouble();
        Size measure(String value, TextStyle? style, double width) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: width);
          final size = painter.size;
          painter.dispose();
          return size;
        }

        final title = measure(t.common.download, titleStyle, titleWidth);
        var headerHeight = extent;
        // Reserve both modes' labels so filtering/selection/search cannot move
        // the content. Large text wraps within this same header, never shrinks.
        for (final count in [
          t.common.itemsCount(count: totalCount),
          '$totalCount/$totalCount',
        ]) {
          final measured = measure(count, countStyle, titleWidth);
          final inline = title.width + 8 + measured.width <= titleWidth;
          final height = inline
              ? (title.height > measured.height
                    ? title.height
                    : measured.height)
              : title.height + 2 + measured.height;
          if (height > headerHeight) headerHeight = height;
        }
        final reduced = MediaQuery.disableAnimationsOf(context);
        final searchWidth = constraints.maxWidth - extent;
        final searchStart = titleWidth < 160
            ? (searchWidth < 160 ? searchWidth : 160.0)
            : titleWidth;
        return SizedBox(
          key: const ValueKey('download-header'),
          height: headerHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: searching ? 1 : 0),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => Row(
              children: [
                if (!searching && !embedded) const SourceBackButton(),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: searching
                          ? searchStart + (searchWidth - searchStart) * progress
                          : titleWidth,
                      child: searching
                          ? SearchQueryField(
                              key: const ValueKey('download-search-field'),
                              query: query,
                              focusNode: focusNode,
                              inline: true,
                              closeOnSubmit: false,
                              hintText: _label(
                                context,
                                '查找下载',
                                'Search downloads',
                              ),
                              onChanged: onQuery,
                            )
                          : Transform.translate(
                              offset: Offset(0, -4 * progress),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(t.common.download, style: titleStyle),
                                  if (inventoryReady)
                                    Semantics(
                                      label: managing
                                          ? t.bookshelf.selectedCount(
                                              count: selectedCount,
                                            )
                                          : t.common.itemsCount(
                                              count: rowCount,
                                            ),
                                      excludeSemantics: true,
                                      child: Text(
                                        managing
                                            ? '$selectedCount/$selectableCount'
                                            : t.common.itemsCount(
                                                count: rowCount,
                                              ),
                                        key: const ValueKey('download-count'),
                                        style: countStyle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                if (searching) ...[
                  const SizedBox(width: 8),
                  KeywordScopeMenu(
                    scope: keywordScope,
                    onChanged: onKeywordScope,
                  ),
                  SourceChromeIconButton(
                    key: const ValueKey('download-search-close'),
                    tooltip: _label(context, '关闭查找', 'Close search'),
                    icon: Icons.close_rounded,
                    symbol: 'xmark',
                    onPressed: onSearch,
                  ),
                ] else ...[
                  SourceChromeIconButton(
                    key: const ValueKey('download-search-action'),
                    tooltip: !managing
                        ? t.common.search
                        : selectableCount > 0 &&
                              selectedCount == selectableCount
                        ? t.bookshelf.deselectAll
                        : t.common.selectAll,
                    icon: managing ? Icons.select_all_rounded : Icons.search,
                    symbol: managing ? 'checkmark.circle' : 'magnifyingglass',
                    onPressed: working || managing && selectableCount == 0
                        ? null
                        : managing
                        ? onSelectAll
                        : onSearch,
                  ),
                  if (managing)
                    SourceChromeIconButton(
                      key: const ValueKey('download-manage-action'),
                      tooltip: managing ? t.common.done : t.bookshelf.manage,
                      icon: managing ? Icons.done_rounded : Icons.checklist,
                      symbol: managing ? 'checkmark' : 'checklist',
                      onPressed: working || !inventoryReady ? null : onManage,
                    ),
                  if (!managing) ...[
                    const SizedBox.square(
                      dimension: extent,
                      child: CollectionCoverPrivacyButton(),
                    ),
                    SizedBox.square(
                      dimension: extent,
                      child: VideoControlAppearance(
                        systemControls: usesNativeSourceChrome(context),
                        child: NativeVideoMenu(
                          key: const ValueKey('download-more'),
                          width: extent,
                          label: '',
                          tooltip: t.common.more,
                          selected: '',
                          icon: Icons.more_horiz,
                          symbol: 'ellipsis',
                          hostPresentation: true,
                          selectAfterDismissal: const {
                            'manage',
                            'download-settings',
                            collectionCoverSettingsAction,
                            'help',
                          },
                          options: {
                            if (inventoryReady && !working)
                              'manage': t.bookshelf.manage,
                            'download-settings': t.download.settings,
                            collectionCoverSettingsAction:
                                collectionCoverSettingsLabel(context),
                            'help': t.common.help,
                          },
                          optionIcons: {
                            'manage': (
                              icon: Icons.checklist,
                              symbol: 'checklist',
                            ),
                            'download-settings': (
                              icon: Icons.settings_outlined,
                              symbol: 'gearshape',
                            ),
                            collectionCoverSettingsAction: (
                              icon: Icons.visibility_off_outlined,
                              symbol: 'eye.slash',
                            ),
                            'help': (
                              icon: Icons.help_outline_rounded,
                              symbol: 'questionmark.circle',
                            ),
                          },
                          groups: const [
                            ['manage', 'download-settings'],
                            [collectionCoverSettingsAction],
                            ['help'],
                          ],
                          onSelected: (value) {
                            if (working || !context.mounted) return;
                            if (value == 'manage') {
                              onManage();
                            } else if (value == 'download-settings') {
                              unawaited(openDownloadSettings(context));
                            } else if (value == 'help') {
                              unawaited(openDownloadHelp(context));
                            } else if (value == collectionCoverSettingsAction) {
                              unawaited(openCollectionCoverSettings(context));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _DownloadCenter extends StatefulWidget {
  const _DownloadCenter({required this.embedded});
  final bool embedded;
  @override
  State<_DownloadCenter> createState() => _DownloadCenterState();
}

class _DownloadCenterState extends State<_DownloadCenter> {
  Map<String, int> _pins = {};
  bool _pinsReady = false;
  int _pinsEpoch = 0;
  final _pinWrites = <String>{};
  Object? _pinInventoryInputs;
  bool _pinReconcileScheduled = false, _pinVideoReady = false;
  int _pinVideoRevision = 0;

  Future<void> _loadPins() async {
    final epoch = ++_pinsEpoch;
    try {
      final pins = await DownloadWorkPins.read();
      if (!mounted || epoch != _pinsEpoch) return;
      setState(() {
        _pins = pins;
        _pinsReady = true;
      });
    } catch (_) {
      if (mounted) showErrorToast(t.error.loadFailed);
    }
  }

  Future<void> _togglePin(DownloadCenterItem item) async {
    final key = downloadWorkPinKey(item);
    if (_working || _managing || !_pinsReady || !_pinWrites.add(key)) return;
    _closeSwipe();
    try {
      final current = _items(_tasks(context.read<DowloadTaskBloc>().state));
      final members = current
          .where((row) => downloadWorkPinKey(row) == key)
          .toList();
      if (members.isEmpty) return;
      await DownloadWorkPins.setPinnedItems(
        members,
        !members.any((row) => DownloadWorkPins.rankFor(row, _pins) != null),
      );
      await _loadPins();
    } catch (_) {
      if (mounted)
        showErrorToast(
          _label(context, '置顶设置未保存，请重试', 'Could not save pin. Please retry.'),
        );
    } finally {
      _pinWrites.remove(key);
    }
  }

  void _reconcilePins(List<DownloadCenterItem> all, {required bool ready}) {
    if (!ready ||
        !_pinsReady ||
        !_pinVideoReady ||
        _comicFailed ||
        _videoFailed ||
        _pins.isEmpty)
      return;
    final inputs = (all, _pins, _pinVideoRevision);
    if (_pinInventoryInputs == inputs || _pinReconcileScheduled) return;
    _pinInventoryInputs = inputs;
    _pinReconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await DownloadWorkPins.reconcile(() {
          if (!mounted ||
              !_inventoryReady ||
              !_pinVideoReady ||
              _comicFailed ||
              _videoFailed)
            return null;
          // Tasks and comic resources have independent UI streams. Read both
          // authoritative boxes now, not their potentially mixed UI snapshots.
          return projectDownloadCenter(
            tasks: _repository.getAll(),
            comics: DownloadCenterResources.readComics(),
            videos: _videos,
          );
        });
      } catch (_) {
        _pinInventoryInputs = null;
      } finally {
        _pinReconcileScheduled = false;
      }
    });
  }

  static const _mediaTypes = ['all', 'comic', 'video'];

  List<DownloadComicResource> _comics = [];
  List<Map<String, dynamic>> _videos = [];
  final _videoProgress = <String, ValueNotifier<Map<String, dynamic>>>{};
  final _verifiedVideoVersions = <(String, String), Set<String>>{};
  StreamSubscription<List<DownloadComicResource>>? _watch;
  StreamSubscription<List<Type>>? _comicHistoryChanges;
  final _chapterReading = ComicChapterReadingProgress.instance;
  Map<String, UnifiedComicHistory> _comicHistory = {};
  Map<String, DownloadVideoWorkHistory> _videoHistory = {};
  int _comicHistoryRevision = 0, _videoHistoryRevision = 0;
  bool _historyVisible = false;
  late final _comicHistoryReads = DownloadReadQueue(
    _readComicHistory,
    isActive: () => mounted && _historyVisible,
  );
  late final _videoHistoryReads = DownloadReadQueue(
    _readVideoHistory,
    isActive: () => mounted && _historyVisible,
  );
  bool _hasComicSnapshot = false, _loadingVideos = true;
  bool _comicFailed = false, _videoFailed = false, _working = false;
  bool get _inventoryReady =>
      _hasComicSnapshot && _verifiedVideoRevision != null;
  Future<void>? _manualRefresh;
  int _storageRefreshRevision = 0;
  bool _searching = false, _managing = false;
  bool _removalPromptOpen = false;
  int _videoEpoch = 0;
  int? _verifiedVideoRevision;
  bool _verifyVideoFiles = false;
  late final _videoReads = DownloadReadQueue(
    _readVideosNow,
    isActive: () => mounted,
  );
  String _query = '', _type = 'all';
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;
  String? _source;
  final _sourcePreferenceStore = BookshelfSourcePreferenceStore();
  BookshelfSourcePreferences _sourcePreferences = BookshelfSourcePreferences();
  bool _sourcePreferencesReady = false, _sourceManagerOpen = false;
  int _sourcePreferenceEpoch = 0;

  Future<void> _loadSourcePreferences() async {
    final epoch = ++_sourcePreferenceEpoch;
    try {
      final value = await _sourcePreferenceStore.read(
        BookshelfSourceMedium.download,
      );
      if (!mounted || epoch != _sourcePreferenceEpoch) return;
      setState(() {
        _sourcePreferences = value;
        _sourcePreferencesReady = true;
        if (value.hidden.contains(_source)) {
          _source = null;
          _selected.clear();
        }
      });
    } catch (_) {
      if (mounted && epoch == _sourcePreferenceEpoch) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(t.error.loadFailed)));
      }
    }
  }

  Future<void> _manageSourceLabels(Map<String, String> sources) async {
    if (_working || _sourceManagerOpen) return;
    if (!_sourcePreferencesReady) await _loadSourcePreferences();
    if (!mounted ||
        !_sourcePreferencesReady ||
        _working ||
        _sourceManagerOpen) {
      return;
    }
    _searchFocus.unfocus();
    setState(() => _sourceManagerOpen = true);
    try {
      await showBookshelfSourceManager(
        context: context,
        sources: sources,
        initial: _sourcePreferences,
        onSave: (value) async {
          await _sourcePreferenceStore.save(
            BookshelfSourceMedium.download,
            value,
          );
          if (mounted)
            setState(() {
              _sourcePreferences = value;
              if (value.hidden.contains(_source)) {
                _source = null;
                _selected.clear();
              }
            });
        },
      );
    } finally {
      if (mounted) setState(() => _sourceManagerOpen = false);
    }
  }

  Set<String> _categories = {}, _tags = {};
  Map<String, Set<String>> _facetValues = {};
  final _openSwipe = ValueNotifier<String?>(null);
  void _closeSwipe() => _openSwipe.value = null;
  bool _orderBySize = false;
  final _scroll = ScrollController();
  final _scrollEdges = ValueNotifier((up: false, footer: false));
  int _sizeOrderEpoch = 0;
  Map<String, SavedComicSize> _orderedComicSizes = {};
  final _navigationOrigins = <ModalRoute<dynamic>>{};
  final _selected = <String>{};
  final _searchFocus = FocusNode();
  final _readerSelection = StringSelectCubit();
  final _notices = DownloadCompletionNotice.instance;
  void _noticeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _markViewed(DownloadCenterItem snapshot) async {
    try {
      await _notices.markSeen(snapshot);
    } catch (_) {
      // Retain the notification when local acknowledgment cannot be saved.
    }
  }

  void _toggleSearch() {
    _closeSwipe();
    setState(() {
      _searching = !_searching;
      if (!_searching && _query.isNotEmpty) {
        _query = '';
        _selected.clear();
      }
    });
    if (!_searching) {
      _searchFocus.unfocus();
    } else {
      requestSearchKeyboard(
        _searchFocus,
        isCurrent: () =>
            mounted && _searching && ModalRoute.of(context)?.isCurrent != false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _chapterReading.changes.addListener(_chapterReadingChanged);
    unawaited(_chapterReading.ensureLoaded().catchError((Object _) {}));
    _comicHistoryChanges = objectbox.store.entityChanges.listen((types) {
      if (types.contains(UnifiedComicHistory)) _refreshComicHistory();
    });
    VideoWatchHistory.changes.addListener(_refreshVideoHistory);
    VideoPlaybackPreferences.changes.addListener(_refreshVideoHistory);
    DownloadWorkPins.changes.addListener(_loadPins);
    unawaited(_loadPins());
    BookshelfSourcePreferenceStore.changes.addListener(_loadSourcePreferences);
    PortablePreferences.changes.addListener(_loadSourcePreferences);
    unawaited(_loadSourcePreferences());
    _notices.changes.addListener(_noticeChanged);
    _scroll.addListener(_updateScrollEdges);
    unawaited(_notices.initialize().catchError((Object _) {}));
    _watch = DownloadCenterResources.watchComics().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          _comics = rows;
          DownloadResourceMetrics.instance.retainResources(rows);
          _hasComicSnapshot = true;
          _comicFailed = false;
        });
        _refreshComicHistory();
        unawaited(_refreshSizeOrder(rows));
      },
      onError: (Object _) {
        if (mounted)
          setState(() {
            _comicFailed = true;
          });
      },
    );
    VideoExportRecords.changes.addListener(_videoChanged);
    VideoLocalResources.changes.addListener(_readVideos);
    VideoDownloadedDetails.changes.addListener(_readVideos);
    unawaited(_readVideos());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        ModalRoute.isCurrentOf(context) != false && TickerMode.of(context);
    if (visible == _historyVisible) return;
    _historyVisible = visible;
    if (visible) {
      _refreshComicHistory();
      _refreshVideoHistory();
    }
  }

  void _chapterReadingChanged() {
    if (mounted && _historyVisible) setState(() {});
  }

  void _refreshComicHistory() {
    _comicHistoryRevision++;
    unawaited(_comicHistoryReads.request());
  }

  Future<void> _readComicHistory() async {
    final revision = _comicHistoryRevision;
    final keys = [
      for (final comic in _comics)
        if (comic.chapterCount == 1) comic.key,
    ];
    final history = <String, UnifiedComicHistory>{};
    if (keys.isNotEmpty) {
      final query = objectbox.unifiedHistoryBox
          .query(
            UnifiedComicHistory_.deleted
                .equals(false)
                .and(UnifiedComicHistory_.uniqueKey.oneOf(keys)),
          )
          .build();
      try {
        for (final record in await query.findAsync()) {
          history[record.uniqueKey] = record;
        }
      } catch (_) {
        // The inventory remains usable if optional history cannot be read.
      } finally {
        query.close();
      }
    }
    if (mounted && _historyVisible && revision == _comicHistoryRevision) {
      setState(() => _comicHistory = history);
    }
  }

  void _refreshVideoHistory() {
    _videoHistoryRevision++;
    unawaited(_videoHistoryReads.request());
  }

  Future<void> _readVideoHistory() async {
    final revision = _videoHistoryRevision;
    final sources = _videos
        .where(_hasVerifiedVideoProgressTarget)
        .map((row) => row['source'] as String)
        .toSet();
    final history = <String, DownloadVideoWorkHistory>{};
    for (final source in sources) {
      if (!mounted || !_historyVisible || revision != _videoHistoryRevision) {
        return;
      }
      history[source] = await readDownloadVideoWorkHistory(source);
    }
    if (mounted && _historyVisible && revision == _videoHistoryRevision) {
      setState(() => _videoHistory = history);
    }
  }

  void _videoChanged() {
    var changed = false, needsRead = false;
    final snapshot = VideoExportRecords.sessionTaskSnapshot();
    for (final row in snapshot) {
      final notifier = _videoProgress[row['key']];
      if (notifier == null || row['status'] == 'saved') {
        needsRead = true;
        continue;
      }
      final previous = notifier.value;
      if ([
        'status',
        'received',
        'receivedSource',
        'packageBytes',
        'networkBytes',
        'networkTotal',
        'progressRevision',
        'total',
        'mediaProgress',
        'recordingFailed',
        'quality',
        'format',
        'resourceId',
        'failureReason',
        'attempt',
      ].any((key) => previous[key] != row[key])) {
        notifier.value = mergeVideoDownloadSnapshot(previous, row);
        changed = true;
        if (const [
              'resourceId',
              'format',
              'quality',
              'attempt',
            ].any((key) => previous[key] != row[key]) ||
            previous['status'] != row['status'] && !_activeVideo(row)) {
          needsRead = true;
        }
      }
    }
    if (needsRead || snapshot.isEmpty || !changed) unawaited(_readVideos());
  }

  void _publishVideos(List<Map<String, dynamic>> rows, {bool complete = true}) {
    if (!mounted) return;
    final session = {
      for (final row in VideoExportRecords.sessionTaskSnapshot())
        if (row['status'] != 'saved') row['key']: row,
    };
    // Metadata and native file checks may finish after the task has advanced.
    // Only a verified resource read can publish a newly saved file.
    rows = rows.map((row) {
      final key = row['key'];
      final latest = session[key];
      if (latest != null) return mergeVideoDownloadSnapshot(row, latest);
      final published = _videoProgress[key]?.value;
      final capturedAttempt = row['attempt'];
      final latestAttempt = published?['attempt'];
      if (published != null &&
          capturedAttempt is int &&
          latestAttempt is int &&
          (latestAttempt > capturedAttempt ||
              (latestAttempt == capturedAttempt &&
                  _activeVideo(row) &&
                  !_activeVideo(published)))) {
        return mergeVideoDownloadSnapshot(row, published);
      }
      return row;
    }).toList();
    const equality = DeepCollectionEquality();
    for (final row in rows) {
      final key = row['key'] as String;
      final notifier = _videoProgress[key];
      if (notifier == null)
        _videoProgress[key] = ValueNotifier(row);
      else if (!equality.equals(notifier.value, row))
        notifier.value = row;
    }
    // Progress-only fields are intentionally handled by the row listeners.
    final structureChanged =
        rows.length != _videos.length ||
        rows.indexed.any((entry) {
          final (index, row) = entry;
          final old = _videos[index];
          return const [
            'key',
            'source',
            'url',
            'status',
            'available',
            'filePresent',
            'fileRemoved',
            'fileInvalid',
            'recordingFailed',
            'bytes',
            'completedAt',
            'at',
            'failureReason',
            'attempt',
            'publicTags',
            'quality',
            'format',
            'resourceId',
            'resourceVersion',
            'local',
            'resourceReadPending',
            'publicWorkIdentity',
            'publicModuleNamespace',
            'publicWorkTitle',
            'publicPlannedEpisodes',
            'publicEpisodeLabel',
            'publicEpisodeOrder',
            'publicSearchText',
            'metadata',
            'cover',
            'durationMs',
            'sourceDuration',
            'title',
          ].any((field) => !equality.equals(old[field], row[field]));
        });
    if (_loadingVideos || _videoFailed || structureChanged)
      setState(() {
        _videos = rows;
        if (complete) {
          _loadingVideos = false;
          _videoFailed = false;
        }
      });
    if (structureChanged) {
      _verifiedVideoVersions.clear();
      for (final row in _videos) {
        if (!_hasVerifiedVideoProgressTarget(row) || row['url'] is! String) {
          continue;
        }
        final key = (row['source'] as String, row['url'] as String);
        (_verifiedVideoVersions[key] ??= {}).add(row['resourceId'] as String);
      }
      _refreshVideoHistory();
    }
  }

  Future<void> _readVideos({bool verifyFiles = false}) {
    _verifyVideoFiles |= verifyFiles;
    _pinVideoReady = false;
    _pinVideoRevision++;
    return _videoReads.request();
  }

  void _publishEarlyVideos(
    int epoch,
    List<Map<String, dynamic>> rows, {
    required bool transfers,
  }) {
    if (!mounted || epoch != _videoEpoch || _verifiedVideoRevision != null) {
      return;
    }
    final byKey = {
      for (final row in _videos)
        if (!transfers || row['status'] == 'saved') row['key']: row,
      for (final row in rows) row['key']: row,
    };
    _publishVideos(byKey.values.toList(), complete: false);
  }

  void _videoReadFailed(int epoch, {List<Map<String, dynamic>>? checkedRows}) {
    if (!mounted || epoch != _videoEpoch) return;
    if (checkedRows != null) {
      _publishEarlyVideos(epoch, checkedRows, transfers: false);
    }
    setState(() {
      _loadingVideos = false;
      _videoFailed = true;
    });
  }

  Future<void> _readVideosNow() async {
    final pinRevision = _pinVideoRevision;
    final epoch = ++_videoEpoch;
    final verifyFiles = _verifyVideoFiles;
    _verifyVideoFiles = false;
    try {
      final read = DownloadCenterResources.readVideoPhases(
        afterRevision: _verifiedVideoRevision,
        fresh: verifyFiles,
      );
      if (_verifiedVideoRevision == null) {
        unawaited(
          read.readTransfers().then((rows) {
            _publishEarlyVideos(epoch, rows, transfers: true);
          }, onError: (Object _, StackTrace _) {}),
        );
        unawaited(
          read.readCheckedMp4().then((rows) {
            _publishEarlyVideos(epoch, rows, transfers: false);
          }, onError: (Object _, StackTrace _) {}),
        );
      }
      final verified = await read.verified;
      if (!mounted || epoch != _videoEpoch) return;
      _verifiedVideoRevision = read.revision;
      final previous = {for (final row in _videos) row['key']: row};
      _publishVideos([
        for (final row in verified)
          _retainVideoPresentation(row, previous[row['key']]),
      ]);
      // Legacy display fields do not hold the refresh queue or restore an
      // older snapshot after a newer task or file projection has started.
      unawaited(
        read.enriched.then((rows) {
          if (mounted && epoch == _videoEpoch) {
            setState(() => _pinVideoReady = pinRevision == _pinVideoRevision);
            _publishVideos(rows);
          }
        }, onError: (Object _, StackTrace _) {}),
      );
    } on IncompleteDownloadVideoInventory catch (error) {
      _videoReadFailed(epoch, checkedRows: error.checkedRows);
    } catch (_) {
      _videoReadFailed(epoch);
    }
  }

  Map<String, dynamic> _retainVideoPresentation(
    Map<String, dynamic> row,
    Map<String, dynamic>? previous,
  ) {
    if (previous == null ||
        const [
          'source',
          'url',
          'resourceId',
          'resourceVersion',
          'attempt',
        ].any((field) => previous[field] != row[field])) {
      return row;
    }
    return {
      ...row,
      for (final field in const [
        'cover',
        'durationMs',
        'sourceDuration',
        'metadata',
        'publicTags',
      ])
        if (row[field] == null && previous[field] != null)
          field: previous[field],
    };
  }

  @override
  void dispose() {
    _pinsEpoch++;
    DownloadWorkPins.changes.removeListener(_loadPins);
    _sourcePreferenceEpoch++;
    BookshelfSourcePreferenceStore.changes.removeListener(
      _loadSourcePreferences,
    );
    PortablePreferences.changes.removeListener(_loadSourcePreferences);
    _notices.changes.removeListener(_noticeChanged);
    _searchFocus.dispose();
    _scroll.dispose();
    _scrollEdges.dispose();
    _openSwipe.dispose();
    unawaited(_readerSelection.close());
    unawaited(_watch?.cancel());
    unawaited(_comicHistoryChanges?.cancel());
    _chapterReading.changes.removeListener(_chapterReadingChanged);
    VideoWatchHistory.changes.removeListener(_refreshVideoHistory);
    VideoPlaybackPreferences.changes.removeListener(_refreshVideoHistory);
    VideoExportRecords.changes.removeListener(_videoChanged);
    VideoLocalResources.changes.removeListener(_readVideos);
    VideoDownloadedDetails.changes.removeListener(_readVideos);
    for (final notifier in _videoProgress.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh({bool verifyFiles = false}) async {
    DownloadResourceMetrics.instance.invalidateAll();
    try {
      final rows = DownloadCenterResources.readComics();
      if (mounted) {
        setState(() {
          _comics = rows;
          _comicFailed = false;
          _hasComicSnapshot = true;
        });
        unawaited(_refreshSizeOrder(rows, force: true));
      }
    } catch (_) {
      if (mounted) setState(() => _comicFailed = true);
    }
    await _readVideos(verifyFiles: verifyFiles);
  }

  Future<PullRefreshResult> _refreshFromPull() async {
    final comics = _comics, videos = _videos;
    final alreadyLoaded = _inventoryReady;
    await _refreshVerifiedInventory();
    // The retry row already describes failures next to the retained list.
    if (!mounted || _comicFailed || _videoFailed) {
      return PullRefreshResult.ignored;
    }
    if (!alreadyLoaded) return PullRefreshResult.checked;
    final sameComics = const IterableEquality().equals(
      comics.map((row) => (row.key, row.metricsVersion, row.title)),
      _comics.map((row) => (row.key, row.metricsVersion, row.title)),
    );
    return sameComics && const DeepCollectionEquality().equals(videos, _videos)
        ? PullRefreshResult.unchanged
        : PullRefreshResult.updated;
  }

  Future<void> _refreshVerifiedInventory() {
    final pending = _manualRefresh;
    if (pending != null) return pending;
    final task = _refresh(verifyFiles: true).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _manualRefresh = null;
        _storageRefreshRevision++;
      });
    });
    setState(() {
      _manualRefresh = task;
    });
    return task;
  }

  void _setSizeOrder(bool bySize) {
    if (_working || _managing || bySize == _orderBySize) return;
    _closeSwipe();
    _sizeOrderEpoch++;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _orderBySize = bySize;
      if (!bySize) _orderedComicSizes = {};
    });
    unawaited(_refreshSizeOrder(_comics));
  }

  void _updateScrollEdges([ScrollMetrics? metrics]) {
    if (metrics == null) {
      if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
      metrics = _scroll.position;
    }
    final next = (
      up: ScrollReturnToTop.canReturn(metrics),
      footer: metrics.extentAfter < 120,
    );
    if (next != _scrollEdges.value) _scrollEdges.value = next;
  }

  void _returnToTop() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _closeSwipe();
    final target = position.minScrollExtent;
    if (!MediaQuery.disableAnimationsOf(context) &&
        position.extentBefore < position.viewportDimension * 2) {
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      position.jumpTo(target);
    }
  }

  Widget _inventoryLoading(BuildContext context, {bool compact = false}) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _downloadContentInset,
          vertical: compact ? 12 : 16,
        ),
        child: Center(
          child: Semantics(
            liveRegion: !compact,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        key: const ValueKey('download-inventory-loading'),
                        strokeWidth: 2,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? .5
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    t.common.loading,
                    style: compact
                        ? theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storageFooter(double inset, {required bool inventoryReady}) =>
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder(
              valueListenable: _scrollEdges,
              builder: (context, edges, _) => DownloadStorageStatus(
                enabled: edges.footer && inventoryReady && !_managing,
                comics: _comics,
                videos: _videos,
                refreshRevision: _storageRefreshRevision,
                partial: _comicFailed || _videoFailed,
                builder: (context, used, free) {
                  final parts = [
                    if (used != null && used != t.download.spaceUnavailable)
                      t.download.compactStorageUsed(size: used),
                    if (free != null && free != t.download.spaceUnavailable)
                      t.download.compactStorageFree(size: free),
                  ];
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 54),
                    child: _managing || parts.isEmpty
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: 1,
                            child: Text(
                              parts.join('  /  '),
                              key: const ValueKey('download-storage-footer'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      );

  Future<void> _refreshSizeOrder(
    List<DownloadComicResource> rows, {
    bool force = false,
  }) async {
    if (!_orderBySize) return;
    final epoch = ++_sizeOrderEpoch;
    bool current() => mounted && _orderBySize && epoch == _sizeOrderEpoch;
    final pending = rows
        .where(
          (row) =>
              force ||
              _orderedComicSizes[row.key]?.version != row.metricsVersion,
        )
        .toList();
    if (pending.isEmpty && _orderedComicSizes.length == rows.length) return;
    final measured = await measureSavedComicSizes(pending, current: current);
    if (!current()) return;
    setState(() {
      _orderedComicSizes = {
        for (final row in rows)
          if ((measured[row.key] ?? _orderedComicSizes[row.key])
              case final size?)
            row.key: size,
      };
    });
  }

  List<DownloadTask> _tasks(DowloadTaskState state) => state.maybeWhen(
    loaded: (rows, _) => rows,
    orElse: () => const <DownloadTask>[],
  );

  (List<DownloadTask>, List<DownloadComicResource>, List<Map<String, dynamic>>)?
  _projectedInputs;
  List<DownloadCenterItem> _projectedItems = const [];

  List<DownloadCenterItem> _items(List<DownloadTask> tasks) {
    final inputs = (tasks, _comics, _videos);
    if (_projectedInputs == inputs) return _projectedItems;
    final items = projectDownloadCenter(
      tasks: tasks,
      comics: _comics,
      videos: _videos,
    );
    _projectedInputs = inputs;
    return _projectedItems = items;
  }

  bool _canRemove(DownloadCenterItem item) {
    final video = item.video;
    return video == null
        ? item.priority != 0
        : !_activeVideo(
            mergeVideoDownloadSnapshot(
              video,
              _videoProgress[video['key']]?.value,
            ),
          );
  }

  String _sourceTitle(String source) {
    final name =
        PluginRegistryService.I
            .getCachedPluginInfo(source)?['name']
            ?.toString()
            .trim() ??
        '';
    return name.isEmpty ? (source.isEmpty ? t.common.unknown : source) : name;
  }

  String? _comicProgressLabel(BuildContext context, DownloadCenterItem item) {
    final resource = item.resource;
    if (resource == null ||
        resource.chapters.length != 1 ||
        resource.downloadChapters.length != 1 ||
        item.chapterKeys.length != 1) {
      return null;
    }
    final chapter = resource.downloadChapters.single;
    final pageCount = chapter.images.length;
    if (pageCount == 0 || chapter.id.trim().isEmpty) return null;
    final stored = resource.chapters.single;
    final chapterKeys = {
      chapter.id,
      stored.logicalKey.trim(),
      stored.taskChapterId.trim(),
      stored.id.trim(),
    }..remove('');
    final progress = _chapterReading.lookup(
      resource.source,
      resource.comicId,
      chapterKeys,
    );
    if (progress?.completed == true && progress?.pageCount == pageCount) {
      return _label(context, '已读完', 'Read');
    }
    final legacy = _comicHistory[resource.key];
    final page =
        progress?.pageIndex ??
        (legacy != null &&
                legacy.source.trim() == resource.source.trim() &&
                legacy.comicId == resource.comicId &&
                chapterKeys.contains(legacy.chapterId)
            ? legacy.pageIndex - 1
            : 0);
    if (page <= 0) return null;
    final position = page.clamp(1, pageCount);
    return _label(context, '已阅读至第 $position 页', 'Read to page $position');
  }

  String? _videoProgressLabel(BuildContext context, Map<String, dynamic> row) {
    if (!_hasVerifiedVideoProgressTarget(row)) return null;
    final source = row['source'] as String;
    final snapshot = _videoHistory[source];
    if (snapshot == null ||
        snapshot.historyRevision != VideoWatchHistory.changes.value ||
        snapshot.settingsRevision != VideoPlaybackPreferences.changes.value) {
      return null;
    }
    final uri = Uri.tryParse('${row['url'] ?? ''}');
    final watch = uri == null ? null : VideoWatchRecord.canonicalUrl(uri);
    if (watch == null || watch != uri) return null;
    final record = snapshot.records
        .where((record) => record.watchUrl == watch)
        .firstOrNull;
    if (record == null) return null;
    final resourceId = row['resourceId'];
    final recordedResource = record.localResourceId;
    if (recordedResource != null) {
      if (recordedResource != resourceId) return null;
    } else {
      // A URL-only history entry is usable only when the full checked
      // inventory can identify this exact local version, even under filters.
      if (_verifiedVideoRevision == null || _videoFailed) return null;
      final versions = _verifiedVideoVersions[(source, watch.toString())];
      if (versions?.length != 1 || !versions!.contains(resourceId)) return null;
    }
    if (record.completed) return t.videoPlayback.watchedComplete;
    if (!snapshot.resumeEnabled ||
        record.position.inSeconds <= 0 ||
        record.position >= record.duration) {
      return null;
    }
    final time = formatKnownVideoDuration(record.position).padLeft(5, '0');
    return _label(context, '已观看至 $time', 'Watched to $time');
  }

  Widget _buildDownloadRow(
    BuildContext context,
    DownloadCenterItem item, {
    bool inWork = false,
    bool allowManage = false,
    bool showVideoFileFormat = false,
    Duration? resumeAt,
  }) {
    final episode = inWork ? DownloadEpisodeRowScope.of(context) : null;
    final episodeLabel = item.video?['publicEpisodeLabel'];
    final episodeTitle = episodeLabel is String
        ? episodeLabel.trim().replaceFirstMapped(
            RegExp(r'^(\d+)\s*集$'),
            (match) => '第${match[1]}集',
          )
        : '';
    final display = inWork && episodeTitle.isNotEmpty
        ? DownloadCenterItem(
            key: item.key,
            source: item.source,
            title: episodeTitle,
            priority: item.priority,
            at: item.at,
            video: item.video,
            videoFields: item.videoFields,
          )
        : item;
    return _DownloadRow(
      key: ValueKey(item.key),
      item: display,
      openSwipe: episode?.openSwipe ?? _openSwipe,
      notice: _notices.kind(item),
      sourceTitle: _sourceTitle(item.source),
      managing: episode?.selecting ?? (!inWork && _managing),
      selected: episode?.selected ?? (!inWork && _selected.contains(item.key)),
      enabled: !_working && episode?.busy != true,
      allowManage: !inWork && allowManage,
      compactVideoEpisode: inWork,
      resumeAt: resumeAt,
      readingPosition: inWork || item.isVideo
          ? null
          : _comicProgressLabel(context, item),
      watchingPosition: inWork || !item.isVideo ? null : _videoProgressLabel,
      showVideoFileFormat: showVideoFileFormat,
      pinned: !inWork && DownloadWorkPins.rankFor(item, _pins) != null,
      onTogglePin: !inWork && _pinsReady && allowManage
          ? () => unawaited(_togglePin(item))
          : null,
      onOpen: () {
        if (episode?.selecting == true) {
          episode?.onSelect?.call();
          return;
        }
        if (item.video case final row? when inWork) {
          unawaited(_videoAction('play-local', row, playbackContext: context));
          return;
        }
        _open(item, playbackContext: context, fromMainList: widget.embedded);
      },
      onManage: inWork
          ? episode?.onManage
          : allowManage
          ? () => setState(() {
              _closeSwipe();
              _managing = true;
              if (_canRemove(item)) _selected.add(item.key);
            })
          : null,
      onRemove: (visibleVideo) => _remove([
        if (visibleVideo == null)
          item
        else
          projectDownloadCenter(
            tasks: [],
            comics: [],
            videos: [visibleVideo],
          ).single,
      ], origin: context),
      videoProgress: item.video == null
          ? null
          : _videoProgress[item.video!['key']],
      onExportVideo: (row) =>
          _videoAction('export', row, playbackContext: context),
      onRetryVideo: (row) =>
          _videoAction('retry-exact', row, playbackContext: context),
      onOpenDetails: (row) => row == null
          ? _openComicDetails(item, context)
          : _navigateFrom(
              context,
              () => openVideoDownloadWork(
                context,
                row,
                forDownloadRecovery: false,
              ),
            ),
      onExportComic: () => _exportComic(item),
    );
  }

  Future<void> _retryVideoEpisodes(
    Iterable<DownloadCenterItem> items, {
    BuildContext? origin,
  }) async {
    for (final item in items) {
      if (!mounted || _working) return;
      final current = _videoProgress[item.video?['key']]?.value;
      if (current != null && current['attempt'] != item.video?['attempt'])
        continue;
      final row = mergeVideoDownloadSnapshot(item.video!, current);
      if (VideoDownloadRetry.isWaitingForNetwork(row)) continue;
      if (!const {
        'failed',
        'interrupted',
        'unavailable',
        'unsupported',
        'routeUnavailable',
        'busy',
      }.contains(row['status']))
        continue;
      if (VideoDownloadRetry.canRetry(row) &&
          !VideoDownloadRetry.needsSource(row)) {
        await _videoAction('retry-exact', row, playbackContext: origin);
      }
    }
  }

  Future<void> _navigateFrom(
    BuildContext origin,
    Future<void> Function() open,
  ) async {
    if (!origin.mounted || _working) return;
    final route = ModalRoute.of(origin);
    if (route == null || !route.isCurrent || !_navigationOrigins.add(route)) {
      return;
    }
    try {
      _closeSwipe();
      await open();
    } finally {
      _navigationOrigins.remove(route);
    }
  }

  Future<void> _openVideoWork(DownloadVideoWork work) async {
    if (_working) return;
    if (_managing) {
      if (!work.episodes.every(_canRemove)) return;
      final keys = work.episodes.map((item) => item.key).toSet();
      setState(
        () => _selected.containsAll(keys)
            ? _selected.removeAll(keys)
            : _selected.addAll(keys),
      );
      return;
    }
    await _navigateFrom(context, () async {
      DownloadVideoWorkHistory? readyHistory;
      final initialHistory = readDownloadVideoWorkHistory(
        work.identity.source,
      ).then((history) => readyHistory = history);
      await Navigator.of(context, rootNavigator: true).push<void>(
        videoPageRoute<void>(
          settings: const RouteSettings(name: 'breeze.download.video-work'),
          matchAutoRouteTransition: true,
          builder: (workContext) => DownloadVideoWorkPage(
            initial: work,
            initialHistory: initialHistory,
            readyHistory: readyHistory,
            readItems: () async => projectDownloadCenter(
              tasks: [],
              comics: [],
              videos: await DownloadCenterResources.readVideos(),
            ),
            refreshItems: () async => projectDownloadCenter(
              tasks: [],
              comics: [],
              videos: await DownloadCenterResources.readVideos(fresh: true),
            ),
            matches: _matchesDownloadItem,
            canRemoveEpisode: _canRemove,
            onRemoveEpisodes: (origin, items) => _remove(items, origin: origin),
            onRetryFailed: (items) =>
                _retryVideoEpisodes(items, origin: workContext),
            onContinueWatching: (origin, item) => _videoAction(
              'play-local',
              item.video!,
              playbackContext: origin,
            ),
            onScroll: _closeSwipe,
            rowBuilder: (context, item, showFileFormat, resumeAt) =>
                _buildDownloadRow(
                  context,
                  item,
                  inWork: true,
                  showVideoFileFormat: showFileFormat,
                  resumeAt: resumeAt,
                ),
          ),
        ),
      );
      if (!mounted) return;
      for (final item in work.episodes) {
        unawaited(_markViewed(item));
      }
    });
  }

  Future<void> _openComicDetails(
    DownloadCenterItem item,
    BuildContext origin,
  ) => _navigateFrom(origin, () async {
    if (!_hasComicDetails(item)) return;
    final source = item.source.trim();
    if (!await ensurePluginInstalled(origin, source) ||
        !origin.mounted ||
        ModalRoute.of(origin)?.isCurrent != true) {
      return;
    }
    await Navigator.of(origin, rootNavigator: true).push<void>(
      videoPageRoute<void>(
        settings: const RouteSettings(name: ComicInfoRoute.name),
        matchAutoRouteTransition: true,
        builder: (_) => ComicInfoPage(
          comicId: item.comicId!.trim(),
          from: source,
          type: ComicEntryType.normal,
        ),
      ),
    );
  });

  Future<void> _openChapter(
    DownloadCenterItem item,
    String chapterKey,
    BuildContext origin,
  ) => _navigateFrom(
    origin,
    () => _pushDownloadedComicChapter(
      item,
      chapterKey,
      router: context.router.root,
      stringSelectCubit: _readerSelection,
    ),
  );

  void _open(
    DownloadCenterItem item, {
    required BuildContext playbackContext,
    required bool fromMainList,
  }) {
    if (_working) return;
    _closeSwipe();
    if (_managing) {
      if (!_canRemove(item)) return;
      setState(
        () => _selected.contains(item.key)
            ? _selected.remove(item.key)
            : _selected.add(item.key),
      );
    } else if (item.isVideo) {
      unawaited(
        _videoAction(
          'play',
          item.video!,
          playbackContext: playbackContext,
          fromMainList: fromMainList,
        ),
      );
    } else if (item.resource != null && item.chapterKeys.isEmpty) {
      showErrorToast(t.download.fileUnavailable);
    } else if (item.chapterKeys.length > 1 || item.resource == null) {
      final bloc = context.read<DowloadTaskBloc>();
      unawaited(
        _navigateFrom(playbackContext, () async {
          await Navigator.of(context, rootNavigator: true).push<void>(
            _comicDownloadsRoute(
              item,
              bloc: bloc,
              openChapter: (origin, key) => _openChapter(item, key, origin),
              openDetails: _hasComicDetails(item)
                  ? (origin) => _openComicDetails(item, origin)
                  : null,
            ),
          );
          if (mounted) unawaited(_markViewed(item));
        }),
      );
    } else {
      unawaited(_openChapter(item, item.chapterKeys.single, playbackContext));
    }
  }

  Future<bool> _confirm(
    BuildContext origin,
    String title,
    String message, {
    DownloadInteractionTrace? trace,
  }) async =>
      await showDialog<bool>(
        context: origin,
        builder: (dialog) {
          trace?.mark('dialog-build');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            trace?.mark('dialog-frame');
          });
          return AlertDialog(
            scrollable: true,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(t.common.cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialog).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(t.common.delete),
              ),
            ],
          );
        },
      ) ==
      true;

  Future<void> _remove(
    List<DownloadCenterItem> selected, {
    BuildContext? origin,
    String? workTitle,
  }) async {
    if (_working || _removalPromptOpen || selected.isEmpty) return;
    final host = origin ?? context;
    if (!host.mounted || ModalRoute.of(host)?.isCurrent != true) return;
    // Bind the identities and labels before opening the confirmation. Selection
    // or filtering while the dialog closes must not change its target set.
    final snapshot = List<DownloadCenterItem>.unmodifiable(selected);
    if (!snapshot.every(_canRemove)) {
      showInfoToast(t.download.cancelBeforeDelete);
      return;
    }
    final trace = DownloadInteractionTrace('remove.${snapshot.length}');
    final comicVersions = <String, ComicDownloadRemovalToken>{};
    final videoVersions = <String, VideoDownloadRemovalToken>{};
    final unknownVersions = <String, List<UnknownDownloadTaskRemovalToken>>{};
    _removalPromptOpen = true;
    try {
      for (final item in snapshot) {
        trace.mark('bind-start.${item.isVideo ? 'video' : 'comic'}');
        if (item.isVideo) {
          videoVersions[item.key] = await bindVideoDownloadRemoval(
            source: item.source,
            page: Uri.parse(item.video!['url'] as String),
            quality: item.video!['quality'] as String? ?? '',
            format: item.video!['format'] as String? ?? 'mp4',
            displayedTask: item.video,
          );
        } else if (item.comicId != null) {
          comicVersions[item.key] = bindComicDownloadRemoval(
            from: item.source,
            comicId: item.comicId!,
          );
        } else {
          unknownVersions[item.key] = item.tasks
              .map((task) => bindUnknownDownloadTaskRemoval(task.id))
              .toList();
        }
        trace.mark('bind-complete');
      }
    } catch (_) {
      trace.mark('bind-error');
      _removalPromptOpen = false;
      if (mounted && host.mounted && ModalRoute.of(host)?.isCurrent == true) {
        showErrorToast(t.download.removeFileFailed);
      }
      return;
    }
    if (!mounted || !host.mounted || ModalRoute.of(host)?.isCurrent != true) {
      _removalPromptOpen = false;
      return;
    }
    final recordsOnly = snapshot.every(
      (item) =>
          item.isVideo &&
          (isVideoDownloadRecordOnly(item.video!) ||
              item.video!['local'] != true),
    );
    final names = snapshot.take(3).map((item) => '《${item.title}》').join('、');
    final targets = workTitle != null
        ? '《$workTitle》'
        : snapshot.length > 3
        ? '$names…'
        : names;
    final downloads = snapshot.length == 1
        ? '1 download'
        : '${snapshot.length} downloads';
    final message = recordsOnly
        ? _label(
            context,
            '$targets\n删除 ${snapshot.length} 项下载记录，保留导出文件、收藏和历史。',
            '$targets\nRemove $downloads from the list. Exported files, favorites and history are kept.',
          )
        : _label(
            context,
            '$targets\n删除 ${snapshot.length} 项下载记录，并清理对应的应用内文件。已导出的副本、收藏和历史会保留。',
            '$targets\nDelete $downloads and associated in-app files. Exported files, favorites and history are kept.',
          );
    bool confirmed;
    try {
      trace.mark('dialog-request');
      confirmed = await _confirm(host, t.common.delete, message, trace: trace);
    } finally {
      _removalPromptOpen = false;
    }
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    var failures = 0;
    for (final item in snapshot) {
      try {
        if (item.isVideo) {
          await removeVideoDownload(
            source: item.source,
            page: Uri.parse(item.video!['url'] as String),
            quality: item.video!['quality'] as String? ?? '',
            format: item.video!['format'] as String? ?? 'mp4',
            expected: videoVersions[item.key]!,
          );
        } else if (item.comicId != null) {
          await removeComicDownload(
            from: item.source,
            comicId: item.comicId!,
            expected: comicVersions[item.key]!,
          );
        } else {
          // Unreadable legacy payloads cannot authorize a file deletion.
          await removeUnknownDownloadTasks(
            expected: unknownVersions[item.key]!,
          );
        }
        _selected.remove(item.key);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    setState(() => _working = false);
    if (failures > 0) showErrorToast(t.download.removeFileFailed);
    await _refresh();
  }

  Future<void> _videoAction(
    String action,
    Map<String, dynamic> row, {
    BuildContext? playbackContext,
    bool fromMainList = false,
  }) async {
    if (_working) return;
    final origin = playbackContext ?? context;
    if (!origin.mounted || ModalRoute.of(origin)?.isCurrent != true) return;
    final visible = row;
    row = mergeVideoDownloadSnapshot(
      visible,
      _videoProgress[visible['key']]?.value,
    );
    final explicit = action == 'play-local' || action == 'retry-exact';
    if (explicit &&
        (row['attempt'] != visible['attempt'] ||
            row['resourceId'] != visible['resourceId'])) {
      return;
    }
    if ((action == 'play' || action == 'play-local') &&
        isVideoExternalReceipt(row)) {
      showInfoToast(t.download.videoExternalFiles);
      return;
    }
    if (action == 'play' && VideoDownloadRetry.isWaitingForNetwork(row)) return;
    if (action == 'play' && videoDownloadRequiresSourceDetails(row)) {
      showInfoToast(
        videoDownloadSourceTarget(row) == null
            ? t.download.sourceUnavailableHint
            : t.download.swipeForWorkDetails,
      );
      return;
    }
    if (action == 'play' && VideoDownloadRetry.canRetry(row)) return;
    if (action == 'play' &&
        const {'preparing', 'downloading', 'saving'}.contains(row['status'])) {
      showInfoToast(t.download.playWhenComplete);
      return;
    }
    if (action == 'play' && row['resourceReadPending'] == true) {
      showInfoToast(t.common.loading);
      return;
    }
    if (action == 'retry-exact') {
      if (VideoDownloadRetry.isWaitingForNetwork(row) ||
          VideoDownloadRetry.needsSource(row) ||
          !VideoDownloadRetry.canRetry(row)) {
        return;
      }
      if (VideoDownloadRetryHosts.canContinue(
        '${row['source']}',
        taskKey: '${row['key']}',
      )) {
        VideoDownloadRetryHosts.continueVerification(
          '${row['source']}',
          taskKey: '${row['key']}',
        );
        return;
      }
      return retryVideoDownload(origin, row);
    }
    final id = row['resourceId'];
    if (action == 'play' || action == 'play-local') {
      if (row['status'] != 'saved' ||
          row['local'] != true ||
          row['fileRemoved'] == true ||
          row['fileInvalid'] == true ||
          id is! String) {
        showErrorToast(
          row['status'] == 'saved' &&
                  row['fileRemoved'] != true &&
                  row['fileInvalid'] != true
              ? t.download.videoExternalFiles
              : t.download.fileUnavailable,
        );
        return;
      }
      return _navigateFrom(origin, () async {
        try {
          await openLocalVideo(
            origin,
            id,
            matchAutoRouteTransition: fromMainList,
            resource: row,
          );
          if (mounted) {
            unawaited(
              _markViewed(
                projectDownloadCenter(
                  tasks: [],
                  comics: [],
                  videos: [row],
                ).single,
              ),
            );
          }
        } catch (_) {
          if (mounted) showErrorToast(t.common.loadingFailed);
        }
      });
    }
    if (action != 'export') return;
    final version = visible['resourceVersion'];
    if (row['local'] != true ||
        row['fileRemoved'] == true ||
        row['fileInvalid'] == true ||
        row['format'] == 'hls' ||
        id is! String ||
        version is! String ||
        version != row['resourceVersion'] ||
        visible['resourceId'] != id ||
        visible['attempt'] != row['attempt']) {
      showErrorToast(t.download.fileUnavailable);
      return;
    }
    setState(() => _working = true);
    try {
      final result = await VideoSystemDownload.exportLocal(
        id,
        row['title'] as String,
        expectedResourceVersion: version,
      );
      if (!mounted) return;
      if (result == VideoDownloadStatus.saved) {
        showSuccessToast(t.download.exportCopySaved);
      } else if (result != VideoDownloadStatus.cancelled) {
        showErrorToast(
          result == VideoDownloadStatus.busy
              ? t.download.exportBusy
              : t.download.exportFailed,
        );
      }
    } catch (_) {
      if (mounted) showErrorToast(t.common.loadingFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _comicExportError(ComicArchiveFailure? reason) => switch (reason) {
    ComicArchiveFailure.changed => t.download.exportChanged,
    ComicArchiveFailure.noSpace => t.download.exportNoSpace,
    ComicArchiveFailure.limit => t.download.exportTooMany,
    ComicArchiveFailure.unsafe => t.download.exportChanged,
    _ => t.download.exportFailed,
  };

  Future<void> _exportComic(DownloadCenterItem item) async {
    if (_working || item.isVideo || item.comicId == null) return;
    setState(() => _working = true);
    PreparedComicArchive? archive;
    try {
      archive = await const DownloadComicArchiveService().prepare(
        item.source,
        item.comicId!,
        cancelled: () => !mounted,
      );
      if (!mounted) return;
      var decided = false;
      final selected = archive;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          void finish(bool value) {
            if (decided ||
                !dialog.mounted ||
                ModalRoute.of(dialog)?.isCurrent != true)
              return;
            decided = true;
            Navigator.pop(dialog, value);
          }

          return AlertDialog(
            title: Text(t.download.exportFiles),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected.title),
                const SizedBox(height: 12),
                Text(
                  t.download.exportComicScope(
                    chapters: selected.chapters,
                    pages: selected.pages,
                  ),
                ),
                if (selected.missingPages > 0 ||
                    selected.unavailableChapters > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.download.exportComicMissing(
                      pages: selected.missingPages,
                      chapters: selected.unavailableChapters,
                    ),
                  ),
                ],
              ],
            ),
            scrollable: true,
            actions: [
              TextButton(
                onPressed: () => finish(false),
                child: Text(t.common.cancel),
              ),
              TextButton(
                key: const ValueKey('download-comic-export-confirm'),
                onPressed: () => finish(true),
                child: Text(t.common.export),
              ),
            ],
          );
        },
      );
      if (confirm != true || !mounted) return;
      final status = await archive.export();
      if (!mounted) return;
      if (status == ComicArchiveExportStatus.saved) {
        showSuccessToast(t.download.exportCopySaved);
      } else if (status != ComicArchiveExportStatus.cancelled) {
        showErrorToast(
          status == ComicArchiveExportStatus.busy
              ? t.download.exportBusy
              : _comicExportError(archive.failure),
        );
      }
    } on ComicArchiveEmpty {
      if (mounted) showErrorToast(t.download.exportNothing);
    } on ComicArchiveException catch (error) {
      if (mounted && error.reason != ComicArchiveFailure.cancelled)
        showErrorToast(_comicExportError(error.reason));
    } catch (_) {
      if (mounted) showErrorToast(t.download.exportFailed);
    } finally {
      try {
        await archive?.dispose();
      } catch (_) {
        /* Cleanup never reverses an acknowledged system save. */
      }
      if (mounted) setState(() => _working = false);
    }
  }

  bool _matchesDownloadItem(DownloadCenterItem item) => item.matches(
    query: _query,
    titleOnly: _keywordScope == KeywordSearchScope.title,
    type: _type,
    source: _source,
    categories: _categories,
    tags: _tags,
    facetValues: _facetValues,
  );

  void _selectMedia(String value, List<DownloadCenterItem> items) {
    if (_working || value == _type || !_mediaTypes.contains(value)) return;
    _closeSwipe();
    setState(() {
      _selected.clear();
      _type = value;
      if (_source != null &&
          !items.any(
            (item) => item.source == _source && item.matches(type: value),
          )) {
        _source = null;
      }
    });
  }

  void _clearFilters() {
    _closeSwipe();
    setState(() {
      _selected.clear();
      _categories = {};
      _tags = {};
      _facetValues = {};
    });
  }

  Future<void> _filters(List<DownloadCenterItem> items) async {
    final scoped = items
        .where(
          (item) => item.matches(
            type: _type,
            query: _query,
            titleOnly: _keywordScope == KeywordSearchScope.title,
            source: _source,
          ),
        )
        .toList();
    final initial = ShelfFacetSelection(
      values: {
        if (_categories.isNotEmpty) 'category': _categories,
        if (_tags.isNotEmpty) 'tags': _tags,
        for (final entry in _facetValues.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      },
    );
    final result = await showDownloadFilterSheet(
      context,
      preferenceKey: 'download|$_type|${_source ?? '*'}',
      entries: scoped
          .map(
            (item) => ShelfFacetEntry(
              key: item.key,
              source: item.source,
              searchText: '',
              fields: item.facetFields,
            ),
          )
          .toList(),
      initial: initial,
      initialSizeOrder: _orderBySize,
      onApplySizeOrder: (value) {
        if (mounted) _setSizeOrder(value);
      },
    );
    if (result != null && mounted)
      setState(() {
        _closeSwipe();
        if (result.copyWith(applied: initial.applied) != initial) {
          _selected.clear();
        }
        _categories = {...?result.values['category']};
        _tags = {...?result.values['tags']};
        _facetValues = {
          for (final e in result.values.entries)
            if (e.key != 'category' && e.key != 'tags' && e.value.isNotEmpty)
              e.key: {...e.value},
        };
      });
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<DowloadTaskBloc, DowloadTaskState>(
      buildWhen: (before, after) =>
          before.runtimeType != after.runtimeType ||
          !sameDownloadTaskStructure(_tasks(before), _tasks(after)),
      builder: (context, state) {
        final tasksReady = state.maybeWhen(
          loaded: (_, _) => true,
          orElse: () => false,
        );
        final inventoryReady = tasksReady && _inventoryReady;
        final inventoryPending =
            !inventoryReady && !_comicFailed && !_videoFailed;
        final all = _items(_tasks(state));
        _reconcilePins(all, ready: inventoryReady);
        final waitingForQueue = all.any(
          (item) => item.isVideo
              ? const {
                  'queued',
                  'pending',
                  'preparing',
                }.contains(item.video?['status'])
              : item.tasks.any(_isWaitingComicTask),
        );
        final rows = all.where(_matchesDownloadItem).toList();
        final groupedRows = inventoryReady
            ? groupVideoDownloadItems(rows, universe: all)
            : [for (final item in rows) DownloadCenterDisplayItem(item)];
        final orderedRows = _orderBySize
            ? orderDownloadsBySize(
                groupedRows,
                comicSizes: _orderedComicSizes,
                videoSizes: savedVideoSizes(_videos),
              )
            : groupedRows;
        final displayRows = DownloadWorkPins.arrange(orderedRows, _pins);
        final displayIndexes = {
          for (final (index, row) in displayRows.indexed) row.key: index,
        };
        final selectable = !_managing
            ? const <DownloadCenterItem>[]
            : <DownloadCenterItem>[
                for (final entry in displayRows)
                  if (entry.work case final work?) ...[
                    if (work.episodes.every(_canRemove)) ...work.episodes,
                  ] else if (_canRemove(entry.item))
                    entry.item,
              ];
        final chosen = selectable
            .where((item) => _selected.contains(item.key))
            .toList();
        final options = {
          'all': t.common.all,
          'comic': _label(context, '漫画', 'Comics'),
          'video': _label(context, '视频', 'Videos'),
        };
        final filterCount =
            _categories.length +
            _tags.length +
            _facetValues.values.fold<int>(
              0,
              (count, values) => count + values.length,
            );
        final filtered = filterCount > 0;
        final sourceIds =
            (_sourcePreferencesReady ? all : const <DownloadCenterItem>[])
                .where((item) => item.matches(type: _type))
                .map((item) => item.source)
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final sources = _sourcePreferences.arrange({
          for (final source in sourceIds) source: _sourceTitle(source),
        });
        return Column(
          children: [
            _DownloadHeader(
              embedded: widget.embedded,
              searching: _searching,
              managing: _managing,
              working: _working,
              inventoryReady: inventoryReady,
              rowCount: rows.length,
              totalCount: inventoryReady ? all.length : 0,
              selectedCount: chosen.length,
              selectableCount: selectable.length,
              query: _query,
              keywordScope: _keywordScope,
              onKeywordScope: (scope) => setState(() {
                _closeSwipe();
                _selected.clear();
                _keywordScope = scope;
              }),
              focusNode: _searchFocus,
              onSearch: _toggleSearch,
              onQuery: (value) => setState(() {
                if (_query != value) {
                  _closeSwipe();
                  _selected.clear();
                }
                _query = value;
              }),
              onManage: () => setState(() {
                _closeSwipe();
                _managing = !_managing;
                if (!_managing) _selected.clear();
              }),
              onSelectAll: () => setState(() {
                final keys = selectable.map((item) => item.key).toSet();
                if (_selected.containsAll(keys)) {
                  _selected.removeAll(keys);
                } else {
                  _selected.addAll(keys);
                }
              }),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                _downloadContentInset,
                4,
                _downloadContentInset,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: NativeVideoSegmentedControl(
                      options: options,
                      selected: _type,
                      enabled: !_working,
                      onSelected: (value) => _selectMedia(value, all),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SourceFilterIconButton(
                    key: const ValueKey('download-filter'),
                    bare: false,
                    active: filtered || _orderBySize,
                    tooltip: [
                      _label(context, '筛选与排序', 'Filter and sort'),
                      if (filtered)
                        '${t.comicList.activeFilters} · $filterCount',
                      if (_orderBySize) t.download.largestDownloadsFirst,
                    ].join(' · '),
                    onPressed: _working || !inventoryReady || _managing
                        ? null
                        : () => _filters(all),
                  ),
                ],
              ),
            ),
            VideoControlAppearance(
              systemControls: usesNativeSourceChrome(context),
              child: BookshelfSourceNavigation(
                sources: sources,
                hidden: _sourcePreferences.hidden,
                selected: [if (_source != null) _source!],
                showManage: true,
                classicChips: true,
                quietChips: true,
                allLabel: _label(context, '全部来源', 'All sources'),
                horizontalInset: _downloadContentInset,
                onManage: !inventoryReady || _working || _sourceManagerOpen
                    ? null
                    : () => _manageSourceLabels({
                        for (final item in all)
                          item.source: _sourceTitle(item.source),
                      }),
                onChanged:
                    _working ||
                        !_sourcePreferencesReady ||
                        (!inventoryReady && sources.isEmpty && _source == null)
                    ? null
                    : (sources) => setState(() {
                        final source = sources.isEmpty ? null : sources.single;
                        if (_source != source) {
                          _closeSwipe();
                          _selected.clear();
                        }
                        _source = source;
                      }),
              ),
            ),
            if (waitingForQueue && !_managing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DownloadQueuePauseNotice(onResumeStarted: _closeSwipe),
              ),
            if (_comicFailed || _videoFailed)
              TextButton.icon(
                onPressed: _manualRefresh == null && !_working
                    ? _refreshVerifiedInventory
                    : null,
                icon: _manualRefresh == null
                    ? const Icon(Icons.refresh)
                    : const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                label: Text(
                  '${rows.isEmpty ? t.common.loadingFailed : t.common.refreshRetained} · ${t.common.retry}',
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) {
                      if (notification.depth == 0)
                        _updateScrollEdges(notification.metrics);
                      return false;
                    },
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0 &&
                            notification.dragDetails != null) {
                          _closeSwipe();
                        }
                        return false;
                      },
                      child: PullRefreshFeedback.indicator(
                        active: !_working && !_managing,
                        scope: (
                          _type,
                          _source,
                          _query,
                          _keywordScope,
                          _categories,
                          _tags,
                          _facetValues,
                          _orderBySize,
                        ),
                        onRefresh: _refreshFromPull,
                        child: ListPositionScrollbar(
                          bottomInset: NativeNavigationInset.scrollBottom(
                            context,
                          ),
                          child: CustomScrollView(
                            key: const PageStorageKey(
                              'download-center.unified',
                            ),
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (inventoryPending && rows.isEmpty)
                                _inventoryLoading(context),
                              if (rows.isEmpty && inventoryReady)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _query.isNotEmpty ||
                                                    filtered ||
                                                    _source != null ||
                                                    _type != 'all'
                                                ? t.bookshelf.facets.noResults
                                                : t.download.noTasks,
                                          ),
                                          if (filtered)
                                            TextButton(
                                              key: const ValueKey(
                                                'download-clear-filters',
                                              ),
                                              onPressed: _working
                                                  ? null
                                                  : _clearFilters,
                                              child: Text(
                                                t.bookshelf.facets.clear,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else if (rows.isNotEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  sliver: SliverList.separated(
                                    findItemIndexCallback: (key) =>
                                        key is ValueKey<String>
                                        ? displayIndexes[key.value]
                                        : null,
                                    itemCount: displayRows.length,
                                    separatorBuilder: (_, _) =>
                                        const WorkListDivider(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = displayRows[index],
                                          work = entry.work;
                                      if (work == null) {
                                        return _buildDownloadRow(
                                          context,
                                          entry.item,
                                          allowManage: inventoryReady,
                                        );
                                      }
                                      final keys = work.episodes
                                          .map((item) => item.key)
                                          .toSet();
                                      return DownloadVideoWorkCard(
                                        key: ValueKey(work.key),
                                        work: work,
                                        pinned: work.episodes.any(
                                          (item) =>
                                              DownloadWorkPins.rankFor(
                                                item,
                                                _pins,
                                              ) !=
                                              null,
                                        ),
                                        onTogglePin: _pinsReady
                                            ? () => unawaited(
                                                _togglePin(entry.item),
                                              )
                                            : null,
                                        openSwipe: _openSwipe,
                                        sourceTitle: _sourceTitle(
                                          work.identity.source,
                                        ),
                                        progress: _videoProgress,
                                        enabled: !_working,
                                        managing: _managing,
                                        selected: _selected.containsAll(keys),
                                        unread: work.episodes.any(
                                          (item) =>
                                              _notices.kind(item) !=
                                              DownloadNoticeKind.none,
                                        ),
                                        onOpen: () =>
                                            unawaited(_openVideoWork(work)),
                                        onOpenDetails: (row) => _navigateFrom(
                                          context,
                                          () => openVideoDownloadWork(
                                            context,
                                            row,
                                            includeEpisode: false,
                                            forDownloadRecovery: false,
                                          ),
                                        ),
                                        onRetryFailed: (live) => unawaited(
                                          _retryVideoEpisodes(
                                            live.failedEpisodes,
                                          ),
                                        ),
                                        onManage: () => setState(() {
                                          _closeSwipe();
                                          _managing = true;
                                          _selected.addAll(keys);
                                        }),
                                        onRemove: (live) => _remove(
                                          live.episodes,
                                          origin: context,
                                          workTitle: live.title,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (inventoryPending && rows.isNotEmpty)
                                _inventoryLoading(context, compact: true),
                              _storageFooter(
                                NativeNavigationInset.scrollBottom(context),
                                inventoryReady: inventoryReady,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _scrollEdges,
                    builder: (context, edges, _) => ValueListenableBuilder(
                      valueListenable: _openSwipe,
                      builder: (context, swipe, _) => ScrollReturnToTop(
                        actionKey: const ValueKey('download-list-top'),
                        visible:
                            edges.up &&
                            swipe == null &&
                            !_managing &&
                            !_searching &&
                            !_working,
                        bottom:
                            NativeNavigationInset.scrollBottom(context) + 16,
                        onPressed: _returnToTop,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 16,
                    end: 16,
                    bottom: 8 + NativeNavigationInset.scrollBottom(context),
                    child: Center(
                      child: IgnorePointer(
                        ignoring: !_managing,
                        child: ExcludeSemantics(
                          excluding: !_managing,
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 140),
                            child: !_managing
                                ? null
                                : Material(
                                    key: const ValueKey(
                                      'download-batch-actions',
                                    ),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                    shape: const StadiumBorder(),
                                    elevation: 2,
                                    child: TextButton.icon(
                                      onPressed: _working || chosen.isEmpty
                                          ? null
                                          : () => _remove(chosen),
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(t.common.delete),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    final body = Stack(
      children: [
        content,
        if (_working)
          const PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
    return CollectionCoverPrivacyScope(
      child: widget.embedded
          ? Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(bottom: false, child: body),
            )
          : Scaffold(body: SafeArea(bottom: false, child: body)),
    );
  }
}

class _DownloadRow extends StatefulWidget {
  const _DownloadRow({
    super.key,
    required this.item,
    required this.openSwipe,
    required this.notice,
    required this.sourceTitle,
    required this.managing,
    required this.selected,
    required this.enabled,
    required this.onOpen,
    required this.onManage,
    required this.onRemove,
    required this.onExportVideo,
    required this.onExportComic,
    required this.onRetryVideo,
    required this.onOpenDetails,
    this.videoProgress,
    this.allowManage = true,
    this.compactVideoEpisode = false,
    this.resumeAt,
    this.readingPosition,
    this.watchingPosition,
    this.showVideoFileFormat = false,
    this.pinned = false,
    this.onTogglePin,
  });
  final DownloadCenterItem item;
  final ValueNotifier<String?> openSwipe;
  final DownloadNoticeKind notice;
  final String sourceTitle;
  final bool managing, selected, enabled;
  final bool allowManage;
  final bool compactVideoEpisode;
  final Duration? resumeAt;
  final String? readingPosition;
  final String? Function(BuildContext, Map<String, dynamic>)? watchingPosition;
  final bool showVideoFileFormat;
  final bool pinned;
  final VoidCallback? onTogglePin;
  final VoidCallback onOpen, onExportComic;
  final VoidCallback? onManage;
  final ValueChanged<Map<String, dynamic>?> onRemove;
  final ValueChanged<Map<String, dynamic>> onExportVideo, onRetryVideo;
  final ValueChanged<Map<String, dynamic>?> onOpenDetails;
  final ValueNotifier<Map<String, dynamic>>? videoProgress;
  @override
  State<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends State<_DownloadRow> {
  Future<DownloadResourceSize>? _size;
  String? _cancellingVideoTaskKey;
  int? _cancellingVideoAttempt;
  bool _cancellingVideo(Map<String, dynamic> row) =>
      _cancellingVideoTaskKey == row['key'] &&
      _cancellingVideoAttempt == row['attempt'];
  bool _videoCancelPromptOpen = false;

  Future<void> _requestVideoCancel(Map<String, dynamic> row) async {
    final key = row['key'] as String;
    final attempt = row['attempt'] as int?;
    if (_videoCancelPromptOpen || _cancellingVideo(row)) return;
    _videoCancelPromptOpen = true;
    try {
      final submitted = await _cancelVideo(
        context,
        row,
        onConfirmed: () {
          if (mounted)
            setState(() {
              _cancellingVideoTaskKey = key;
              _cancellingVideoAttempt = attempt;
            });
        },
      );
      if (!submitted &&
          mounted &&
          _cancellingVideoTaskKey == key &&
          _cancellingVideoAttempt == attempt) {
        setState(() => _cancellingVideoTaskKey = null);
      }
    } finally {
      _videoCancelPromptOpen = false;
    }
  }

  final _clock = Stopwatch()..start();
  VideoDownloadRateSampler _rate = VideoDownloadRateSampler();
  VideoDownloadRate? _currentRate;
  @override
  void initState() {
    super.initState();
    _readSize();
    widget.videoProgress?.addListener(_sampleRate);
    _sampleRate();
  }

  @override
  void didUpdateWidget(covariant _DownloadRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoProgress != widget.videoProgress) {
      oldWidget.videoProgress?.removeListener(_sampleRate);
      widget.videoProgress?.addListener(_sampleRate);
      _rate = VideoDownloadRateSampler();
      _currentRate = null;
      _sampleRate();
    }
    // The service returns a shared versioned future; no scan occurs on byte
    // progress. Explicit refresh invalidates it and provides a fresh future.
    _readSize();
  }

  void _readSize() {
    final resource = widget.item.resource;
    _size = resource == null
        ? null
        : DownloadResourceMetrics.instance.readComic(resource);
  }

  void _sampleRate() {
    final video = widget.videoProgress?.value ?? widget.item.video;
    if (video == null) return;
    _currentRate = _rate.update(video, elapsed: _clock.elapsed);
  }

  @override
  void dispose() {
    widget.videoProgress?.removeListener(_sampleRate);
    _clock.stop();
    super.dispose();
  }

  Widget _sizeAndTime(
    Map<String, dynamic>? video,
    DownloadResourceSize? size,
    VideoDownloadRate? rate,
  ) {
    final item = widget.item;
    final transferring = video?['status'] == 'downloading';
    final savedVideo =
        video?['status'] == 'saved' &&
        video?['local'] == true &&
        video?['fileRemoved'] != true &&
        video?['fileInvalid'] != true;
    final bytes = video == null
        ? size?.sizeBytes
        : savedVideo
        ? item.sizeBytes
        : null;
    final partial =
        size?.status == DownloadResourceSizeStatus.partial &&
        (size?.knownBytes ?? 0) > 0;
    return DownloadCardFooter(
      itemKey: item.key,
      completedAt: video == null || savedVideo ? item.completedAt : null,
      metrics: [
        if (transferring)
          ...videoDownloadProgressText(
            row: video,
            rate: rate,
            formatBytes: downloadByteAmount,
          )
        else if (bytes != null)
          downloadByteAmount(bytes)
        else if (partial)
          '≥ ${downloadByteAmount(size!.knownBytes, lowerBound: true)}',
      ],
    );
  }

  Widget _videoEpisodeContents(
    BuildContext context,
    Map<String, dynamic> video,
    _Status status, {
    required bool active,
    required bool showProgress,
  }) {
    final item = widget.item;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle =
        (theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)).copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
    final bodyStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          color: colors.onSurfaceVariant,
          height: 1.25,
        );
    final cancelling = active && _cancellingVideo(video);
    final external = isVideoExternalReceipt(video);
    final selection = DownloadEpisodeRowScope.of(context);
    final managing = selection?.selecting == true;
    final canManage = widget.enabled && canManageDownloadedVideoEpisode(video);
    final quality = video['quality'] is String
        ? (video['quality'] as String).trim()
        : '';
    final variant = [
      if (quality.isNotEmpty) quality,
      if (widget.showVideoFileFormat && video['format'] == 'hls') 'HLS',
      if (widget.showVideoFileFormat && video['format'] == 'mp4') 'MP4',
    ].join(' · ');
    if (_playableVideoEpisode(video)) {
      final live = DownloadCenterItem(
        key: item.key,
        source: item.source,
        title: item.title,
        priority: item.priority,
        at: item.at,
        video: video,
      );
      return DownloadEpisodePlayRow(
        key: ValueKey('download-play-local.${item.key}'),
        title: item.title,
        variant: variant,
        bytes: live.sizeBytes,
        resumeAt: widget.resumeAt,
        onPlay: widget.enabled
            ? managing
                  ? selection?.onSelect
                  : widget.onOpen
            : null,
        selecting: managing,
        selected: canManage && selection?.selected == true,
        onManage: widget.enabled ? widget.onManage : null,
      );
    }

    final needsDetails =
        widget.enabled &&
        videoDownloadRequiresSourceDetails(video) &&
        !VideoDownloadRetry.isWaitingForNetwork(video) &&
        videoDownloadSourceTarget(video) != null;
    final action = active
        ? TextButton(
            key: ValueKey('download-cancel.${item.key}'),
            onPressed: widget.enabled && !cancelling
                ? () => _requestVideoCancel(video)
                : null,
            child: Text(t.download.cancelTask),
          )
        : needsDetails
        ? null
        : VideoDownloadRetryAction(
            row: video,
            enabled: widget.enabled,
            includeSourceDetails: false,
            retryLabel: t.download.retryEpisodeDownload,
            onRetry: () => widget.onRetryVideo(video),
          );
    final caption = [
      if (cancelling)
        t.download.statusCancelling
      else ...[
        status.message,
        ?status.reason,
      ],
      if (variant.isNotEmpty) variant,
      if (video['status'] == 'downloading' && showProgress)
        ...videoDownloadProgressText(
          row: video,
          rate: _currentRate,
          formatBytes: downloadByteAmount,
        ),
    ].where((line) => line.isNotEmpty).join(' · ');

    return InkWell(
      onTap: managing
          ? (canManage ? selection?.onSelect : null)
          : (external && widget.enabled ? widget.onOpen : null),
      onLongPress: widget.enabled ? widget.onManage : null,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 38,
                child: managing
                    ? Center(
                        child: CollectionSelectionMark(
                          visible: true,
                          selected: canManage && selection?.selected == true,
                        ),
                      )
                    : Icon(
                        status.failed
                            ? Icons.error_outline_rounded
                            : external
                            ? Icons.insert_drive_file_outlined
                            : Icons.downloading_rounded,
                        color: status.failed
                            ? colors.error
                            : colors.onSurfaceVariant,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      item.title,
                      key: ValueKey('download-title.${item.key}'),
                      style: titleStyle,
                    ),
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        key: ValueKey('download-status.${item.key}'),
                        style: status.failed
                            ? bodyStyle.copyWith(color: colors.error)
                            : bodyStyle,
                      ),
                    if (needsDetails)
                      Visibility(
                        visible: !managing,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Text(
                          t.download.swipeForWorkDetails,
                          style: bodyStyle,
                        ),
                      ),
                    if (showProgress)
                      LinearProgressIndicator(
                        key: ValueKey('download-work-progress.${item.key}'),
                        value: status.progress,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: TextButtonTheme(
                    data: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    child: Visibility(
                      visible: !managing,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: action,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _playableVideoEpisode(Map<String, dynamic> video) =>
      !isVideoExternalReceipt(video) &&
      video['status'] == 'saved' &&
      video['local'] == true &&
      video['fileRemoved'] != true &&
      video['fileInvalid'] != true &&
      video['resourceReadPending'] != true &&
      video['resourceId'] is String &&
      (video['resourceId'] as String).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final coverImage = SizedBox(
      key: ValueKey('download-cover.${item.key}'),
      width: DownloadCardMetrics.coverWidth,
      height: DownloadCardMetrics.coverHeight,
      child: item.isVideo
          ? DownloadVideoTaskCover(
              row: item.video!,
              width: DownloadCardMetrics.coverWidth,
              height: DownloadCardMetrics.coverHeight,
              fallback: Icon(
                isVideoExternalReceipt(item.video!)
                    ? Icons.insert_drive_file_outlined
                    : Icons.play_arrow_rounded,
              ),
            )
          : DownloadComicTaskCover(
              source: item.source,
              comicId: item.comicId ?? '',
              width: DownloadCardMetrics.coverWidth,
              height: DownloadCardMetrics.coverHeight,
            ),
    );
    final cover = Stack(
      clipBehavior: Clip.none,
      children: [
        coverImage,
        if (widget.pinned) const DownloadCardPin(),
        if (widget.notice != DownloadNoticeKind.none)
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              label: widget.notice == DownloadNoticeKind.failed
                  ? _label(
                      context,
                      '下载失败，尚未查看',
                      'Download failed, not yet reviewed',
                    )
                  : _label(
                      context,
                      '下载完成，尚未查看',
                      'Download complete, not yet reviewed',
                    ),
              child: Container(
                key: ValueKey('download-notice.${item.key}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.notice == DownloadNoticeKind.failed
                      ? Theme.of(context).colorScheme.error
                      : CupertinoDynamicColor.resolve(
                          CupertinoColors.systemGreen,
                          context,
                        ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    Widget row(List<DownloadTask> tasks, Map<String, dynamic>? video) {
      if (video == null && item.comicId != null) {
        _size = DownloadResourceMetrics.instance.readComicProgress(
          source: item.source,
          comicId: item.comicId!,
          resource: item.resource,
          tasks: tasks
              .map(_repository.readPayload)
              .whereType<DownloadTaskJson>(),
        );
      }
      final colors = Theme.of(context).colorScheme;
      final chapterProgress = item.chapterProgress(tasks);
      final multi = !item.isVideo && chapterProgress.keys.length > 1;
      final networkWait = video != null
          ? DownloadNetworkWait.fromCode(video['failureReason'])
          : tasks
                .map(
                  (task) => DownloadNetworkWait.fromCode(
                    _repository.readPayload(task)?.phaseCode,
                  ),
                )
                .whereType<DownloadNetworkWait>()
                .firstOrNull;
      final comicQueue = DownloadQueueManager.instance;
      final queuedComic = video == null
          ? tasks.where(comicQueue.canPrioritize).firstOrNull
          : null;
      final videoKey = video?['key'], attempt = video?['attempt'];
      final queuedVideo =
          videoKey is String &&
          attempt is int &&
          VideoSystemDownload.canPrioritize(videoKey, attempt);
      final _Status status = queuedVideo && networkWait == null
          ? (
              message: t.download.statusWaiting,
              reason: null,
              progress: null,
              failed: false,
            )
          : video == null
          ? _comicStatus(tasks, item.resource, aggregate: multi)
          : _videoStatus(video, compactEpisode: widget.compactVideoEpisode);
      final completed = video == null
          ? item.priority == 3
          : video['status'] == 'saved' &&
                video['fileRemoved'] != true &&
                video['fileInvalid'] != true;
      // The notifier can receive native completion before the slower full
      // resource projection rebuilds item.priority. Actions follow this row.
      final active = video == null
          ? tasks.any((task) => downloadComicPriority(task) == 0)
          : _activeVideo(video);
      final checked = widget.managing && !active && widget.selected;
      final canRetryComics =
          !item.isVideo && tasks.any(comicQueue.canResumeTask);
      final pausableComics = video == null
          ? tasks.where(comicQueue.canPauseTask).toList()
          : const <DownloadTask>[];
      final recovery = active
          ? IconButton(
              tooltip: video == null
                  ? _label(context, '暂停此作品的下载', 'Pause downloads for this work')
                  : t.download.cancelTask,
              icon: Icon(
                video == null ? Icons.pause_rounded : Icons.close_rounded,
              ),
              onPressed:
                  widget.enabled &&
                      (video == null
                          ? pausableComics.isNotEmpty
                          : !_cancellingVideo(video))
                  ? () => video != null
                        ? _requestVideoCancel(video)
                        : _pauseComicTasks(pausableComics)
                  : null,
            )
          : video != null && !VideoDownloadRetry.isWaitingForNetwork(video)
          ? VideoDownloadRetryAction(
              row: video,
              iconOnly: true,
              enabled: widget.enabled,
              includeSourceDetails: false,
              onRetry: () => widget.onRetryVideo(video),
            )
          : canRetryComics
          ? IconButton(
              tooltip: t.common.retry,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: widget.enabled ? () => _retry(tasks) : null,
            )
          : null;
      final exportLabel = _label(context, '导出副本', 'Export copy');
      void prioritize() {
        final moved = queuedVideo
            ? VideoSystemDownload.prioritize(videoKey, attempt)
            : queuedComic != null && comicQueue.prioritize(queuedComic);
        if (moved) showSuccessToast(t.download.downloadPrioritized);
      }

      final canPrioritize =
          widget.enabled &&
          !widget.managing &&
          (queuedVideo || queuedComic != null);
      final canExport = video == null
          ? item.resource != null &&
                chapterProgress.keys.isNotEmpty &&
                DownloadComicArchiveService.supported
          : video['status'] == 'saved' &&
                video['local'] == true &&
                video['fileRemoved'] != true &&
                video['fileInvalid'] != true &&
                video['format'] != 'hls' &&
                video['resourceId'] is String &&
                video['resourceVersion'] is String;
      final rate = video == null ? null : _currentRate;
      final oneChapter = item.resource?.chapters.length == 1
          ? item.resource!.chapters.single.name
          : tasks.length == 1
          ? _repository.readPayload(tasks.single)?.chapterRef.title
          : null;
      final bodyStyle = Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(height: 1.2);
      final position = !completed || active || multi
          ? null
          : video == null
          ? widget.readingPosition
          : widget.watchingPosition?.call(context, video);
      final chapter = oneChapter?.trim() ?? '';
      final chapterMetadata = multi
          ? Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.collections_bookmark_outlined,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _label(
                      context,
                      '已完成 ${chapterProgress.completed.length}/${chapterProgress.keys.length} 章',
                      '${chapterProgress.completed.length} of ${chapterProgress.keys.length} chapters completed',
                    ),
                    style: bodyStyle?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!widget.managing)
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(width: 20),
              ],
            )
          : chapter.isNotEmpty && chapter != item.title.trim()
          ? Text(
              chapter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            )
          : null;
      final showStatus =
          !completed ||
          status.reason != null ||
          status.failed ||
          networkWait != null ||
          (video != null &&
              (video['local'] != true || isVideoExternalReceipt(video)));
      final statusMetadata = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (completed || status.failed) ...[
            ExcludeSemantics(
              child: Icon(
                status.failed
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: status.failed ? colors.error : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              status.message,
              key: ValueKey('download-status.${item.key}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle?.copyWith(
                color: status.failed ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
      final content = CollectionPressFeedback(
        enabled: widget.enabled,
        child: TouchHoverIntent(
          identity: item.key,
          builder: (context, hover) => InkWell(
            key: ValueKey('download-open.${item.key}'),
            borderRadius: BorderRadius.circular(12),
            hoverColor: hover.hoverColor(),
            onTap: widget.enabled && (!widget.managing || !active)
                ? widget.onOpen
                : null,
            onLongPress:
                widget.enabled &&
                    !active &&
                    !widget.managing &&
                    widget.allowManage
                ? widget.onManage
                : null,
            child: Padding(
              padding: DownloadCardMetrics.padding,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      cover,
                      if (widget.managing)
                        DownloadCardSelection(
                          key: ValueKey('download-select.${item.key}'),
                          label: item.title,
                          selected: checked,
                          onTap: widget.enabled && !active
                              ? widget.onOpen
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DownloadCardDetails(
                      key: ValueKey('download-details.${item.key}'),
                      heading: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                key: ValueKey('download-title.${item.key}'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          [
                            widget.sourceTitle,
                            item.isVideo
                                ? t.bookshelf.mediaVideos
                                : t.bookshelf.mediaComics,
                            if (item.isVideo &&
                                '${video?['quality'] ?? ''}'.isNotEmpty)
                              '${video!['quality']}',
                          ].join(' · '),
                          key: ValueKey('download-source.${item.key}'),
                          maxLines:
                              MediaQuery.textScalerOf(context).scale(12) > 16
                              ? 2
                              : 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyStyle?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (chapterMetadata != null) chapterMetadata,
                        if (position != null)
                          Text(
                            position,
                            key: ValueKey('download-position.${item.key}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        if (item.isVideo &&
                            (item.fields['tags']?.isNotEmpty ?? false))
                          Text(
                            item.fields['tags']!.take(3).join(' · '),
                            key: ValueKey('download-tags.${item.key}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                      footer: [
                        if (showStatus || active)
                          Row(
                            key: ValueKey('download-state-row.${item.key}'),
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 4,
                                  children: [
                                    statusMetadata,
                                    if (status.reason case final reason?)
                                      Text(
                                        reason,
                                        key: ValueKey(
                                          'download-reason.${item.key}',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: bodyStyle?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (recovery != null)
                                Visibility(
                                  visible: !widget.managing,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  maintainSize: true,
                                  child: recovery,
                                ),
                            ],
                          ),
                        if (active && networkWait == null && !queuedVideo)
                          LinearProgressIndicator(
                            key: ValueKey('download-work-progress.${item.key}'),
                            value: status.progress,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        if (_size case final sizeFuture?)
                          FutureBuilder<DownloadResourceSize>(
                            key: ValueKey((
                              item.resource?.key,
                              item.resource?.metricsVersion,
                            )),
                            future: sizeFuture,
                            builder: (context, result) => _sizeAndTime(
                              video,
                              result.data?.resourceKey ==
                                      (item.resource?.key ??
                                          buildDownloadTaskKey(
                                            item.source,
                                            item.comicId ?? '',
                                          ))
                                  ? result.data
                                  : null,
                              rate,
                            ),
                          )
                        else
                          _sizeAndTime(video, null, rate),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final pageColor =
          Scaffold.maybeOf(context)?.widget.backgroundColor ??
          Theme.of(context).scaffoldBackgroundColor;
      final card = Material(
        key: ValueKey('download-card.${item.key}'),
        color: checked
            ? Color.alphaBlend(colors.primary.withValues(alpha: .06), pageColor)
            : pageColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: widget.compactVideoEpisode && video != null
            ? _videoEpisodeContents(
                context,
                video,
                status,
                active: active,
                showProgress: active && networkWait == null && !queuedVideo,
              )
            : content,
      );
      final canShowDetails =
          !widget.managing &&
          widget.enabled &&
          (video == null
              ? _hasComicDetails(item)
              : videoDownloadSourceTarget(video) != null);
      final showActions =
          !active &&
          !widget.managing &&
          widget.enabled &&
          (!widget.compactVideoEpisode ||
              video == null ||
              canManageDownloadedVideoEpisode(video));
      return DownloadSwipeActions(
        rowKey: item.key,
        openRow: widget.openSwipe,
        exposeActions: true,
        completedAt:
            widget.compactVideoEpisode &&
                video != null &&
                _playableVideoEpisode(video)
            ? item.completedAt
            : null,
        actionVersion: video == null
            ? (item.resource?.metricsVersion, queuedComic?.id, active)
            : (
                videoKey,
                attempt,
                video['status'],
                video['resourceId'],
                video['resourceVersion'],
                video['fileRemoved'],
                video['fileInvalid'],
                video['url'],
                video['retryItemId'],
                video['publicWorkIdentity'],
              ),
        actions: [
          if (widget.onTogglePin != null && widget.enabled && !widget.managing)
            (
              id: widget.pinned ? 'unpin' : 'pin',
              label: widget.pinned
                  ? _label(context, '取消置顶', 'Unpin')
                  : _label(context, '置顶', 'Pin'),
              icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              run: widget.onTogglePin!,
            ),
          if (canShowDetails)
            (
              id: 'details',
              label: t.download.workDetails,
              icon: Icons.info_outline_rounded,
              run: () => widget.onOpenDetails(video),
            ),
          if (canPrioritize)
            (
              id: 'next',
              label: t.download.prioritizeDownload,
              icon: Icons.vertical_align_top_rounded,
              run: prioritize,
            ),
          if (showActions) ...[
            if (canExport)
              (
                id: 'export',
                label: exportLabel,
                icon: Icons.ios_share_rounded,
                run: video == null
                    ? widget.onExportComic
                    : () => widget.onExportVideo(video),
              ),
            (
              id: 'delete',
              label: t.common.delete,
              icon: Icons.delete_outline,
              run: () => widget.onRemove(video),
            ),
          ],
        ],
        child: card,
      );
    }

    if (item.isVideo) {
      return ValueListenableBuilder(
        valueListenable: VideoSystemDownload.waitingChanges,
        builder: (context, _, _) {
          final notifier = widget.videoProgress;
          return notifier == null
              ? row(const [], item.video)
              : ValueListenableBuilder(
                  valueListenable: notifier,
                  builder: (_, value, _) => row(
                    const [],
                    mergeVideoDownloadSnapshot(item.video!, value),
                  ),
                );
        },
      );
    }
    final ids = item.tasks.map((task) => task.id).toSet();
    return BlocSelector<DowloadTaskBloc, DowloadTaskState, String>(
      selector: (state) => state.maybeWhen(
        loaded: (tasks, _) => tasks
            .where((task) => ids.contains(task.id))
            .map((task) => task.dbTaskInfoStr)
            .join('\n'),
        orElse: () => '',
      ),
      builder: (context, _) {
        final tasks = context.read<DowloadTaskBloc>().state.maybeWhen(
          loaded: (rows, _) =>
              rows.where((task) => ids.contains(task.id)).toList(),
          orElse: () => item.tasks,
        );
        return row(tasks, null);
      },
    );
  }
}

typedef _Status = ({
  String message,
  String? reason,
  double? progress,
  bool failed,
});

bool _isWaitingComicTask(DownloadTask task) {
  final payload = _repository.readPayload(task);
  return payload != null &&
      !task.isCompleted &&
      !task.isDownloading &&
      const {'', 'pending', 'queued'}.contains(payload.stateCode);
}

int _comicWorkAttemptRank(DownloadTask task, DownloadTaskJson? payload) =>
    switch (payload?.stateCode) {
      'cancelled' => 5,
      'paused' => 4,
      'failed' => 3,
      'completed' when payload?.phaseCode != 'fileRemoved' => 6,
      'queued' when payload?.phaseCode == 'waitingRetry' => 2,
      _ when task.isDownloading => 0,
      _ when task.isCompleted => 3,
      _ => 1,
    };

_Status _comicStatus(
  List<DownloadTask> tasks,
  DownloadComicResource? resource, {
  bool aggregate = false,
}) {
  final sorted = tasks.toList()
    ..sort((a, b) {
      final priority = downloadComicPriority(
        a,
      ).compareTo(downloadComicPriority(b));
      if (priority != 0 || a.isDownloading == b.isDownloading) return priority;
      return a.isDownloading ? -1 : 1;
    });
  if (sorted.isEmpty)
    return (
      message: t.download.completed,
      reason: null,
      progress: null,
      failed: false,
    );
  final task = sorted.first, payload = _repository.readPayload(sorted.first);
  final waiting = _isWaitingComicTask(task);
  final failed = payload?.stateCode == 'failed';
  final cancelling = const {
    'cancelling',
    downloadTaskDeletionPhase,
  }.contains(payload?.phaseCode);
  final networkWait = DownloadNetworkWait.fromCode(payload?.phaseCode);
  final message =
      networkWait?.label ??
      (payload?.phaseCode == 'fileRemoved'
          ? t.download.fileRemoved
          : cancelling
          ? t.download.statusCancelling
          : payload?.stateCode == 'paused'
          ? t.download.paused
          : payload?.stateCode == 'cancelled'
          ? t.download.cancelled
          : failed
          ? t.download.notificationFailedTitle
          : payload?.stateCode == 'completed'
          ? t.download.completed
          : payload?.phaseCode == 'waitingRetry'
          ? t.download.statusWaitingRetry
          : waiting
          ? t.download.statusWaiting
          : payload != null && payload.totalImages > 0
          ? downloadTaskPayloadProgressMessage(payload)
          : task.status.isNotEmpty
          ? task.status
          : t.download.downloading);
  final detail = failed ? payload?.lastErrorMessage.trim() ?? '' : '';
  final failedCount = aggregate
      ? tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  _repository.readPayload(task)?.stateCode == 'failed',
            )
            .length
      : 0;

  final workProgress = aggregate
      ? downloadWorkProgressFraction(
          tasks.map(_repository.readPayload).whereType<DownloadTaskJson>(),
          storedChapterKeys:
              resource?.downloadChapters.map((chapter) => chapter.id) ??
              const <String>[],
        )
      : null;
  final workMessage =
      aggregate &&
          networkWait == null &&
          !waiting &&
          downloadComicPriority(task) == 0 &&
          payload != null &&
          payload.totalImages > 0 &&
          !cancelling
      ? workProgress == null
            ? t.download.downloading
            : t.download.statusDownloadProgress(
                percent: (workProgress * 100).floor(),
              )
      : message;
  return (
    message: [
      if (aggregate && failed)
        '${t.download.failed} $failedCount'
      else
        workMessage,
      if (failedCount > 0 && !failed) '${t.download.failed} $failedCount',
    ].join(' · '),
    reason: detail.isNotEmpty ? detail : null,
    progress: cancelling || networkWait != null || (waiting && !aggregate)
        ? null
        : aggregate
        ? (downloadComicPriority(task) == 0 ? workProgress : null)
        : downloadComicPriority(task) == 0 && payload != null
        ? downloadTaskPayloadProgressFraction(payload)
        : null,
    failed: failed,
  );
}

_Status _videoStatus(Map<String, dynamic> row, {bool compactEpisode = false}) {
  final status = row['status'];
  final reason = row['failureReason'];
  final chinese = LocaleSettings.currentLocale.languageCode == 'zh';
  final networkWait = DownloadNetworkWait.fromCode(reason);
  final message = switch (status) {
    'queued' ||
    'pending' ||
    'preparing' when networkWait != null => networkWait.label,
    'queued' || 'pending' || 'preparing'
        when row['phaseCode'] == 'waitingRetry' =>
      t.download.statusWaitingRetry,
    'queued' || 'pending' || 'preparing' => t.download.videoQueued,
    'paused' => t.download.paused,
    'downloading' => t.download.downloading,
    'saving' => t.download.videoSaving,
    'saved' when isVideoExternalReceipt(row) => t.bookshelf.exportedVideo,
    'saved' =>
      row['resourceReadPending'] == true
          ? t.common.loading
          : row['fileRemoved'] == true
          ? t.download.fileRemoved
          : row['fileInvalid'] == true
          ? t.download.fileUnavailable
          : row['local'] == true
          ? t.common.saved
          : t.download.videoExternalFiles,
    'cancelled' => t.download.videoCancelled,
    'interrupted' when compactEpisode =>
      chinese ? '下载已中断' : 'Download interrupted',
    'interrupted' => t.download.videoInterrupted,
    'failed' => networkWait?.label ?? t.download.notificationFailedTitle,
    'unavailable' => t.videoDownload.unavailable,
    'unsupported' => t.videoDownload.unsupportedMedia,
    'routeUnavailable' => videoDownloadFailureText(
      'routeUnavailable',
      chinese: chinese,
    ),
    'busy' => t.videoCommunity.busy,
    _ => t.common.unknown,
  };
  final needsSource =
      videoDownloadRequiresSourceDetails(row) &&
      !VideoDownloadRetry.isWaitingForNetwork(row);
  final reasonText = status == 'failed' && networkWait == null
      ? videoDownloadFailureText(reason, chinese: chinese)
      : null;
  final recoveryHint = needsSource
      ? videoDownloadSourceTarget(row) == null
            ? t.download.sourceUnavailableHint
            : compactEpisode
            ? null
            : t.download.swipeForWorkDetails
      : row['recordingFailed'] == true
      ? t.download.videoRecordFailed
      : null;
  final details = [?reasonText, ?recoveryHint].join(' · ');
  return (
    message: message,
    reason: details.isEmpty ? null : details,
    progress: status == 'downloading'
        ? VideoDownloadByteProgress.fromRow(row).fraction
        : null,
    failed:
        networkWait == null &&
            const {
              'failed',
              'interrupted',
              'unavailable',
              'unsupported',
              'routeUnavailable',
              'busy',
            }.contains(status) ||
        row['fileInvalid'] == true ||
        row['recordingFailed'] == true,
  );
}

Future<void> _retry(Iterable<DownloadTask> tasks) async {
  try {
    await DownloadQueueManager.instance.resumeTasks(tasks);
  } on DownloadSourceDisabled {
    showErrorToast(t.download.sourceDisabled);
  } catch (_) {
    showErrorToast(t.common.loadingFailed);
  }
}

void _pauseComicTasks(Iterable<DownloadTask> tasks) {
  try {
    DownloadQueueManager.instance.pauseTasks(tasks);
  } catch (_) {
    showErrorToast(t.common.loadingFailed);
  }
}

Future<bool> _cancelVideo(
  BuildContext context,
  Map<String, dynamic> row, {
  required VoidCallback onConfirmed,
}) => confirmVideoDownloadCancellation(context, row, onConfirmed: onConfirmed);

class _DownloadChaptersPage extends StatefulWidget {
  const _DownloadChaptersPage({
    required this.initial,
    required this.openChapter,
    required this.openDetails,
  });
  final DownloadCenterItem initial;
  final void Function(BuildContext origin, String key) openChapter;
  final ValueChanged<BuildContext>? openDetails;
  @override
  State<_DownloadChaptersPage> createState() => _DownloadChaptersPageState();
}

class _DownloadChaptersPageState extends State<_DownloadChaptersPage> {
  static const _groupIconSize = 24.0;
  static const _groupIconGap = 6.0;
  static const _groupTextStart = _groupIconSize + _groupIconGap;
  static const _chapterTextInset = 2.0;

  DownloadComicResource? _resource;
  StreamSubscription<DownloadComicResource?>? _watch;
  StreamSubscription<List<Type>>? _historyChanges;
  UnifiedComicHistory? _history;
  bool _removingChapters = false, _changingChapterTasks = false;
  bool get _workingOnChapters => _removingChapters || _changingChapterTasks;
  final _savedSelection = DownloadEpisodeSelection();
  final _activeSelection = DownloadEpisodeSelection();
  late DownloadWorkPane _pane;
  DownloadEpisodeSelection get _selection =>
      _pane == DownloadWorkPane.saved ? _savedSelection : _activeSelection;
  final _reading = ComicChapterReadingProgress.instance;
  bool _pickedGroup = false;
  String? _expandedChapterKey;

  void _switchPane(DownloadWorkPane pane) {
    if (_pane == pane || _workingOnChapters) return;
    _openChapterSwipe.value = null;
    setState(() => _pane = pane);
  }

  final _chapterErrors = <String, String>{};
  final _openChapterSwipe = ValueNotifier<String?>(null);
  late final _savedScroll = _workScroll();
  late final _activeScroll = _workScroll();
  ScrollController _workScroll() =>
      ScrollController()..addListener(() => _openChapterSwipe.value = null);

  void _chapterReadingChanged() {
    if (mounted && _pane == DownloadWorkPane.saved) setState(() {});
  }

  void _chapterQueueOrderChanged() {
    if (mounted && _pane == DownloadWorkPane.active) setState(() {});
  }

  Future<DownloadResourceSize>? _metrics;

  void _readMetrics([List<DownloadTask> tasks = const []]) {
    if (_resource == null && tasks.isEmpty) {
      _metrics = null;
      return;
    }
    _metrics = DownloadResourceMetrics.instance.readComicProgress(
      source: widget.initial.source,
      comicId: widget.initial.comicId ?? '',
      resource: _resource,
      tasks: tasks.map(_repository.readPayload).whereType<DownloadTaskJson>(),
    );
  }

  String? _spaceLabel(DownloadResourceSize? size) {
    final exact = size?.sizeBytes;
    if (exact != null) return downloadByteAmount(exact);
    if (size?.status == DownloadResourceSizeStatus.partial &&
        (size?.knownBytes ?? 0) > 0) {
      return '≥ ${downloadByteAmount(size!.knownBytes, lowerBound: true)}';
    }
    return null;
  }

  UnifiedComicHistory? _readHistory() {
    final query = objectbox.unifiedHistoryBox
        .query(
          UnifiedComicHistory_.uniqueKey.equals(
            '${widget.initial.source.trim()}:${widget.initial.comicId}',
          ),
        )
        .build();
    try {
      final history = query.findFirst();
      return history == null || history.deleted ? null : history;
    } finally {
      query.close();
    }
  }

  String _sourceTitle() {
    final name =
        PluginRegistryService.I
            .getCachedPluginInfo(widget.initial.source)?['name']
            ?.toString()
            .trim() ??
        '';
    return name.isNotEmpty
        ? name
        : widget.initial.source.isNotEmpty
        ? widget.initial.source
        : t.common.unknown;
  }

  Object _chapterVersion(Object? taskVersion, {required bool canRemove}) =>
      (taskVersion, canRemove ? _resource?.metricsVersion : null);

  String _chapterAttemptKey(DownloadTask task) => 'task:${task.id}';

  bool _canRemoveCancelled(DownloadTask task, DownloadTaskJson? payload) =>
      task.isCompleted &&
      !task.isDownloading &&
      payload?.stateCode == 'cancelled' &&
      payload?.phaseCode == 'cancelled';

  String _chapterTaskTitle(DownloadTask task, DownloadTaskJson? payload) {
    final title = payload?.chapterRef.title.trim() ?? '';
    return title.isEmpty ? task.comicName : title;
  }

  Future<void> _changeChapterTasks(
    Map<String, DownloadTask> targets, {
    required bool pause,
  }) async {
    if (_workingOnChapters || targets.isEmpty) return;
    setState(() {
      _changingChapterTasks = true;
      _openChapterSwipe.value = null;
    });
    try {
      if (pause) {
        _pauseComicTasks(targets.values);
      } else {
        await _retry(targets.values);
      }
    } finally {
      if (mounted) {
        setState(() {
          _selection.clearKeys(targets.keys);
          _changingChapterTasks = false;
        });
      }
    }
  }

  Future<void> _removeChapters(
    Map<String, String> targets, {
    Map<String, DownloadTask> transfers = const {},
    Map<String, DownloadTask> cancelled = const {},
  }) async {
    if (_workingOnChapters ||
        (targets.isEmpty && transfers.isEmpty && cancelled.isEmpty) ||
        [
          ...targets.keys,
          ...transfers.keys,
          ...cancelled.keys,
        ].any((key) => key.trim().isEmpty)) {
      return;
    }
    final comicId = widget.initial.comicId;
    if (comicId == null) return;
    final trace = DownloadInteractionTrace('remove-chapters');
    final allKeys = {...targets.keys, ...transfers.keys, ...cancelled.keys};
    final transferCount = transfers.length;
    setState(() {
      _removingChapters = true;
      _openChapterSwipe.value = null;
      allKeys.forEach(_chapterErrors.remove);
    });
    try {
      ComicDownloadRemovalToken? expected;
      if (targets.isNotEmpty) {
        final record = _repository.findDownloadRecord(
          widget.initial.source,
          comicId,
        );
        final currentVersion = record == null
            ? null
            : DownloadComicResource(record).metricsVersion;
        if (currentVersion != _resource?.metricsVersion) {
          throw StateError('Displayed chapter resources have changed');
        }
        expected = bindComicDownloadRemoval(
          from: widget.initial.source,
          comicId: comicId,
        );
      }
      trace.mark('bind-complete');
      final count = targets.length;
      final names = [
        ...targets.values,
        for (final task in transfers.values)
          _chapterTaskTitle(task, _repository.readPayload(task)),
        for (final task in cancelled.values)
          _chapterTaskTitle(task, _repository.readPayload(task)),
      ].take(3).join(' · ');
      final displayNames = allKeys.length > 3 ? '$names…' : names;
      final description = [
        if (transferCount > 0)
          _label(
            context,
            '停止并删除所选 $transferCount 个任务及其未完成文件。',
            'Stop and delete $transferCount selected tasks and their unfinished files.',
          ),
        if (cancelled.isNotEmpty)
          _label(
            context,
            '移除所选 ${cancelled.length} 条已取消的下载记录。',
            'Remove ${cancelled.length} selected cancelled download records.',
          ),
        if (count > 0)
          _label(
            context,
            '删除所选 $count 章的下载文件与下载项？收藏和历史保留。',
            'Delete downloads and their files for ${count == 1 ? 'the selected chapter' : '$count selected chapters'}? Favorites and history are kept.',
          )
        else
          _label(
            context,
            '已下载的章节、收藏和历史会保留。',
            'Downloaded chapters, favorites and history are kept.',
          ),
        displayNames,
      ].join('\n');
      trace.mark('dialog-request');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          trace.mark('dialog-build');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            trace.mark('dialog-frame');
          });
          return AlertDialog(
            scrollable: true,
            title: Text(t.common.delete),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(t.common.cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialog).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(t.common.delete),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      final removed = <String>{};
      final errors = <String, String>{};
      if (expected != null) {
        try {
          await const ChapterDownloadRemoval().removeChapters(
            expected,
            targets.keys,
          );
          removed.addAll(targets.keys);
        } catch (_) {
          if (!mounted) return;
          for (final key in targets.keys) {
            errors[key] = t.download.removeFileFailed;
          }
        }
      }
      if (transfers.isNotEmpty) {
        final receipt = await DownloadQueueManager.instance.stopAndDeleteTasks(
          transfers.values,
        );
        if (!mounted) return;
        for (final entry in transfers.entries) {
          final id = entry.value.id;
          if (receipt.removed.contains(id)) {
            removed.add(entry.key);
          } else if (receipt.skipped.contains(id)) {
            errors[entry.key] = _label(
              context,
              '下载状态已变化，请重新选择。',
              'Download changed. Select it again.',
            );
          } else {
            errors[entry.key] = t.download.removeFileFailed;
          }
        }
      }
      for (final entry in cancelled.entries) {
        if (await _repository.removeCancelledRecord(entry.value)) {
          removed.add(entry.key);
        } else {
          errors[entry.key] = _label(
            context,
            '下载状态已变化，请重新选择。',
            'Download changed. Select it again.',
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _resource = DownloadCenterResources.readComics()
            .where(
              (row) =>
                  row.source == widget.initial.source && row.comicId == comicId,
            )
            .firstOrNull;
        _selection.clearKeys({...removed, ...errors.keys});
        _chapterErrors.addAll(errors);
      });
      if (errors.isNotEmpty) {
        showWarningToast(
          _label(
            context,
            '已删除 ${removed.length} 项，${errors.length} 项未删除。',
            '${removed.length} removed, ${errors.length} not removed.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      final message = t.download.removeFileFailed;
      setState(() {
        for (final key in allKeys) {
          _chapterErrors[key] = message;
        }
      });
      showErrorToast(message);
    } finally {
      DownloadResourceMetrics.instance.invalidate(
        buildDownloadTaskKey(widget.initial.source, comicId),
      );
      if (mounted) {
        setState(() {
          _removingChapters = false;
          _readMetrics();
        });
      }
    }
  }

  Widget _resumeEntry(DownloadedReaderPosition? resume) {
    final key = resume?.key;
    final canResume = key != null;
    final title = resume?.title ?? _history?.chapterTitle ?? '';
    final historyLabel = resume == null
        ? null
        : t.comicInfo.readProgressPage(page: resume.page);
    final label = canResume
        ? _label(context, '继续阅读', 'Continue reading')
        : _label(context, '上次阅读的章节当前不可用', 'Last-read chapter is unavailable');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const ValueKey('download-reading-card'),
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('download-resume-entry'),
        borderRadius: BorderRadius.circular(12),
        onTap: canResume && !_selection.active && !_workingOnChapters
            ? () => widget.openChapter(context, key)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    if (title.isNotEmpty || historyLabel != null)
                      Text(
                        [
                          if (title.isNotEmpty) title,
                          ?historyLabel,
                        ].join(' · '),
                        key: const ValueKey('download-resume-position'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (canResume)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workDownloadActions(
    Map<String, DownloadTask> pausable,
    Map<String, DownloadTask> paused,
  ) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Wrap(
      spacing: 8,
      children: [
        if (pausable.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('download-work-pause'),
            onPressed: _workingOnChapters
                ? null
                : () => _changeChapterTasks(pausable, pause: true),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: Text(
              _label(
                context,
                '暂停 ${pausable.length} 话',
                'Pause ${pausable.length}',
              ),
            ),
          ),
        if (paused.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('download-work-resume'),
            onPressed: _workingOnChapters
                ? null
                : () => _changeChapterTasks(paused, pause: false),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(
              _label(
                context,
                '继续 ${paused.length} 话',
                'Resume ${paused.length}',
              ),
            ),
          ),
      ],
    ),
  );

  Widget _chapterEntry({
    required String key,
    required String title,
    required String status,
    DownloadResourceSize? size,
    VoidCallback? onOpen,
    VoidCallback? onResume,
    VoidCallback? onPause,
    String? resumeLabel,
    VoidCallback? onPrioritize,
    VoidCallback? onRetryNow,
    Object? taskVersion,
    bool failed = false,
    double? progress,
    bool currentReading = false,
    bool grouped = false,
    DateTime? completedAt,
    DateTime? lastReadAt,
    required bool canRemove,
    DownloadTask? removableTransfer,
    DownloadTask? removableCancelled,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metadata = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final titleStyle = grouped
        ? theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface)
        : theme.textTheme.titleSmall;
    final managing = _selection.active;
    final enabled = !_workingOnChapters;
    final selectable =
        canRemove ||
        removableTransfer != null ||
        removableCancelled != null ||
        onResume != null ||
        onPause != null;
    final version = _chapterVersion(taskVersion, canRemove: canRemove);
    final selected =
        managing && selectable && _selection.contains(key, version);
    final actionLabel = onPause != null
        ? _label(context, '暂停', 'Pause')
        : failed
        ? _label(context, '重试', 'Retry')
        : _label(context, '继续', 'Resume');
    final actionHint = onPause != null
        ? _label(context, '暂停下载', 'Pause download')
        : resumeLabel ?? _label(context, '继续下载', 'Resume download');
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: DownloadSwipeActions(
        rowKey: key,
        openRow: _openChapterSwipe,
        exposeActions: true,
        actionVersion: version,
        completedAt: completedAt,
        lastReadAt: lastReadAt,
        actions: [
          if (enabled && !managing) ...[
            if (widget.openDetails case final open?)
              (
                id: 'details',
                label: t.download.workDetails,
                icon: Icons.info_outline_rounded,
                run: () => open(context),
              ),
            if (onPrioritize != null)
              (
                id: 'next',
                label: t.download.prioritizeDownload,
                icon: Icons.playlist_add_check_rounded,
                run: onPrioritize,
              ),
            if (onRetryNow != null)
              (
                id: 'retry-now',
                label: t.download.retryNow,
                icon: Icons.refresh_rounded,
                run: onRetryNow,
              ),
            if (canRemove ||
                removableTransfer != null ||
                removableCancelled != null)
              (
                id: 'delete',
                label: t.common.delete,
                icon: Icons.delete_outline,
                run: () => _removeChapters(
                  {if (canRemove) key: title},
                  transfers: {
                    if (removableTransfer != null) key: removableTransfer,
                  },
                  cancelled: {
                    if (removableCancelled != null) key: removableCancelled,
                  },
                ),
              ),
          ],
        ],
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          child: Semantics(
            checked: managing ? selected : null,
            enabled: managing ? enabled && selectable : null,
            button: managing || onOpen != null,
            child: InkWell(
              key: ValueKey('download-chapter-open.$key'),
              onTap: !enabled
                  ? null
                  : managing
                  ? selectable
                        ? () => setState(() => _selection.toggle(key, version))
                        : null
                  : onOpen,
              onLongPress: enabled && !managing && selectable
                  ? () {
                      _openChapterSwipe.value = null;
                      setState(() => _selection.start(key, version));
                    }
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    grouped ? 0 : _chapterTextInset,
                    8,
                    _chapterTextInset,
                    8,
                  ),
                  child: Row(
                    children: [
                      if (managing) ...[
                        SizedBox.square(
                          dimension: grouped ? _groupIconSize : 38,
                          child: Center(
                            child: Opacity(
                              opacity: selectable ? 1 : .48,
                              child: CollectionSelectionMark(
                                visible: true,
                                selected: selected,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _groupIconGap),
                      ] else if (grouped)
                        const SizedBox(width: _groupTextStart),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            Semantics(
                              label: currentReading
                                  ? '${t.comicInfo.lastRead} · $title'
                                  : null,
                              excludeSemantics: currentReading,
                              child: Text(
                                title,
                                key: currentReading
                                    ? ValueKey('download-chapter-reading.$key')
                                    : null,
                                style: currentReading
                                    ? titleStyle?.copyWith(
                                        color: colors.primary,
                                      )
                                    : titleStyle,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                Text(
                                  status,
                                  style: failed
                                      ? metadata?.copyWith(color: colors.error)
                                      : metadata,
                                ),
                                if (_spaceLabel(size) case final chapterSize?)
                                  Text(
                                    chapterSize,
                                    key: ValueKey('download-chapter-size.$key'),
                                    style: metadata,
                                  ),
                              ],
                            ),
                            if (progress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: LinearProgressIndicator(
                                  key: ValueKey(
                                    'download-chapter-progress.$key',
                                  ),
                                  value: progress,
                                  minHeight: 3,
                                ),
                              ),
                            if (_chapterErrors[key] case final message?)
                              Text(
                                message,
                                key: ValueKey('download-chapter-error.$key'),
                                style: metadata?.copyWith(color: colors.error),
                              ),
                          ],
                        ),
                      ),
                      if (!managing && (onPause != null || onResume != null))
                        Tooltip(
                          message: actionHint,
                          child: TextButton(
                            key: ValueKey(
                              onPause != null
                                  ? 'download-chapter-pause.$key'
                                  : 'download-chapter-resume.$key',
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: enabled ? onPause ?? onResume : null,
                            child: Text(
                              resumeLabel != null && !failed
                                  ? resumeLabel
                                  : actionLabel,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _resource = widget.initial.resource;
    _pane =
        _resource?.chapters.any((chapter) => chapter.images.isNotEmpty) == true
        ? DownloadWorkPane.saved
        : DownloadWorkPane.active;
    _reading.changes.addListener(_chapterReadingChanged);
    DownloadQueueManager.instance.priorityChanges.addListener(
      _chapterQueueOrderChanged,
    );
    unawaited(
      _reading.ensureLoaded().then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          logger.w('Cannot load local chapter positions', error: error);
        },
      ),
    );
    _history = _readHistory();
    _historyChanges = objectbox.store.entityChanges.listen((types) {
      if (!mounted || !types.contains(UnifiedComicHistory)) return;
      final next = _readHistory();
      final old = _history;
      if (old?.chapterId == next?.chapterId &&
          old?.chapterTitle == next?.chapterTitle &&
          old?.chapterOrder == next?.chapterOrder &&
          old?.pageIndex == next?.pageIndex &&
          old?.lastReadAt == next?.lastReadAt) {
        return;
      }
      setState(() => _history = next);
    });
    _readMetrics();
    _watch =
        DownloadCenterResources.watchComic(
          widget.initial.source,
          widget.initial.comicId ?? '',
        ).listen((resource) {
          if (!mounted) return;
          if (identical(resource, _resource)) return;
          setState(() {
            _resource = resource;
            _readMetrics();
          });
        });
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    unawaited(_historyChanges?.cancel());
    _reading.changes.removeListener(_chapterReadingChanged);
    DownloadQueueManager.instance.priorityChanges.removeListener(
      _chapterQueueOrderChanged,
    );
    _savedScroll.dispose();
    _activeScroll.dispose();
    _openChapterSwipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_selection.active,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_removingChapters && _selection.active) {
        setState(_selection.close);
      }
    },
    child: CollectionCoverPrivacyScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initial.title),
          actions: [
            TextButton(
              key: const ValueKey('download-episodes-manage'),
              onPressed: _removingChapters
                  ? null
                  : () {
                      _openChapterSwipe.value = null;
                      setState(() {
                        if (_selection.active) {
                          _selection.close();
                        } else {
                          _selection.start();
                        }
                      });
                    },
              child: Text(
                _selection.active ? t.common.done : t.bookshelf.manage,
              ),
            ),
          ],
        ),
        body: BlocBuilder<DowloadTaskBloc, DowloadTaskState>(
          buildWhen: (before, after) {
            List<DownloadTask> rows(DowloadTaskState state) => state.maybeWhen(
              loaded: (tasks, _) => tasks,
              orElse: () => <DownloadTask>[],
            );
            bool belongs(DownloadTask task) {
              final payload = _repository.readPayload(task);
              return payload?.from == widget.initial.source &&
                  payload?.comicId == widget.initial.comicId;
            }

            final prior = rows(before).where(belongs).toList();
            final next = rows(after).where(belongs).toList();
            if (prior.length != next.length) return true;
            return next.indexed.any((entry) {
              final old = prior[entry.$1], current = entry.$2;
              return !identical(old, current) &&
                  (old.id != current.id ||
                      old.status != current.status ||
                      old.isCompleted != current.isCompleted ||
                      old.isDownloading != current.isDownloading ||
                      old.dbTaskInfoStr != current.dbTaskInfoStr);
            });
          },
          builder: (context, state) {
            final tasks = state.maybeWhen(
              loaded: (rows, _) => rows.where((task) {
                final payload = _repository.readPayload(task);
                return payload?.from == widget.initial.source &&
                    payload?.comicId == widget.initial.comicId &&
                    downloadCenterShowsComicTask(task, payload, _resource);
              }).toList(),
              orElse: () => <DownloadTask>[],
            );
            final stored =
                _resource?.chapters ??
                const <UnifiedComicDownloadStoredChapter>[];
            final resource = _resource;
            final lastRead = resource == null
                ? null
                : resolveDownloadedReaderPosition(
                    resource,
                    ReaderHistoryService.instance.currentResumePosition(
                      source: resource.source,
                      comicId: resource.comicId,
                    ),
                    _reading,
                  );
            final lastReadKey = lastRead?.key;
            final payloads = {
              for (final task in tasks) task.id: _repository.readPayload(task),
            };
            final ranks = {
              for (final task in tasks)
                task.id: _comicWorkAttemptRank(task, payloads[task.id]),
            };
            final queue = DownloadQueueManager.instance;
            tasks.sort((a, b) {
              final rank = ranks[a.id]!;
              final order = rank.compareTo(ranks[b.id]!);
              if (order != 0) return order;
              if (rank == 1 || rank == 2) {
                return queue.compareQueuedTasks(
                  a,
                  payloads[a.id],
                  b,
                  payloads[b.id],
                );
              }
              return a.id.compareTo(b.id);
            });
            final active = [
              for (final task in tasks)
                if (ranks[task.id] != 6) task,
            ];
            final activeKeys = {
              for (final task in active)
                if (payloads[task.id]?.chapterKey case final key?) key,
            };
            final saved = _pane == DownloadWorkPane.saved;
            final canRemove = !active.any(
              (task) => downloadComicPriority(task) == 0,
            );
            final candidates = <String, Object>{};
            final titles = <String, String>{};
            final stoppable = <String, DownloadTask>{};
            final cancelled = <String, DownloadTask>{};
            final pausable = <String, DownloadTask>{};
            final resumable = <String, DownloadTask>{};
            final manuallyPaused = <String, DownloadTask>{};
            final aliasCounts = <String, int>{};
            final canonicalCounts = <String, int>{};
            for (final chapter in stored) {
              canonicalCounts.update(
                _storedKey(chapter),
                (count) => count + 1,
                ifAbsent: () => 1,
              );
              for (final alias in _storedAliases(chapter)) {
                aliasCounts.update(
                  alias,
                  (count) => count + 1,
                  ifAbsent: () => 1,
                );
              }
            }

            Object taskVersion(
              DownloadTask task,
              DownloadTaskJson? payload,
              bool unfinished,
            ) => (
              task.id,
              payload?.attempt,
              unfinished ? 'transfer' : payload?.stateCode,
            );

            if (saved) {
              for (final chapter in stored) {
                final key = _storedKey(chapter);
                if (canRemove &&
                    key.isNotEmpty &&
                    !_storedAliases(chapter).any(activeKeys.contains)) {
                  candidates[key] = _chapterVersion(null, canRemove: true);
                  titles[key] = chapter.name;
                }
              }
            } else {
              for (final task in active) {
                final payload = payloads[task.id];
                if (payload == null || payload.chapterKey.isEmpty) continue;
                final key = _chapterAttemptKey(task);
                final pause = queue.canPauseTask(task);
                final resume = queue.canResumeTask(task);
                final stop = queue.canStopAndDeleteTask(task);
                final removeRecord = _canRemoveCancelled(task, payload);
                if (stop) stoppable[key] = task;
                if (removeRecord) cancelled[key] = task;
                if (pause) pausable[key] = task;
                if (resume) resumable[key] = task;
                if (resume &&
                    payload.stateCode == 'paused' &&
                    payload.phaseCode == 'userPaused') {
                  manuallyPaused[key] = task;
                }
                if (removeRecord || stop || pause || resume) {
                  candidates[key] = _chapterVersion(
                    taskVersion(task, payload, stop || pause),
                    canRemove: false,
                  );
                }
              }
            }
            final selected = _selection.matching(candidates);
            final selectedToPause = {
              for (final key in selected)
                if (pausable[key] case final task?) key: task,
            };
            final selectedToResume = {
              for (final key in selected)
                if (resumable[key] case final task?) key: task,
            };
            final selectedToDelete = {
              for (final key in selected)
                if (titles[key] case final title?) key: title,
            };
            final selectedToStopAndDelete = {
              for (final key in selected)
                if (stoppable[key] case final task?) key: task,
            };
            final selectedCancelled = {
              for (final key in selected)
                if (cancelled[key] case final task?) key: task,
            };
            _readMetrics(tasks);
            final ready = [
              for (final chapter in stored)
                if (chapter.images.isNotEmpty) chapter,
            ];
            final groups = saved
                ? groupDownloadedComicChapters(ready)
                : const <DownloadComicChapterGroup>[];
            final expandable =
                groups.length > 1 ||
                groups.any((group) => group.chapters.length >= 30);
            final groupAnchor = _pickedGroup
                ? _expandedChapterKey
                : lastReadKey;
            final expandedGroup = _pickedGroup && groupAnchor == null
                ? null
                : groups.firstWhereOrNull(
                        (group) => group.chapters.any(
                          (chapter) => _storedKey(chapter) == groupAnchor,
                        ),
                      ) ??
                      groups.firstOrNull;
            final chinese =
                Localizations.localeOf(context).languageCode == 'zh';
            final list = FutureBuilder<DownloadResourceSize>(
              future: _metrics,
              builder: (context, snapshot) {
                final measured = snapshot.data;
                final metrics =
                    measured?.resourceKey ==
                        (widget.initial.resource?.key ??
                            buildDownloadTaskKey(
                              widget.initial.source,
                              widget.initial.comicId ?? '',
                            ))
                    ? measured
                    : null;
                final colors = Theme.of(context).colorScheme;
                final header = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        key: const ValueKey('download-chapters-summary'),
                        children: [
                          SizedBox(
                            key: const ValueKey('download-chapters-cover'),
                            width: 60,
                            height: 90,
                            child: DownloadComicTaskCover(
                              source: widget.initial.source,
                              comicId: widget.initial.comicId ?? '',
                              width: 60,
                              height: 90,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sourceTitle(),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  _label(
                                    context,
                                    '已下载 ${ready.length} 话',
                                    '${ready.length} downloaded chapters',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (_spaceLabel(metrics) case final size?)
                                  Text(
                                    _label(
                                      context,
                                      '本机占用：$size',
                                      'On-device size: $size',
                                    ),
                                    key: const ValueKey(
                                      'download-chapters-total-size',
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DownloadWorkSectionControl(
                        selected: _pane,
                        onSelected: _switchPane,
                        enabled: !_workingOnChapters,
                      ),
                    ],
                  ),
                );

                final rows = <({Key key, WidgetBuilder build, bool fold})>[];
                void add(Key key, WidgetBuilder build, {bool fold = false}) =>
                    rows.add((key: key, build: build, fold: fold));

                if (saved && (lastRead != null || _history != null))
                  add(
                    const ValueKey('work-resume'),
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _resumeEntry(lastRead),
                    ),
                  );
                if (!saved && active.any(_isWaitingComicTask))
                  add(
                    const ValueKey('work-queue'),
                    (_) => DownloadQueuePauseNotice(
                      onResumeStarted: () => _openChapterSwipe.value = null,
                    ),
                  );
                if (!saved &&
                    !_selection.active &&
                    (pausable.isNotEmpty || manuallyPaused.isNotEmpty)) {
                  add(
                    const ValueKey('work-queue-actions'),
                    (_) => _workDownloadActions(pausable, manuallyPaused),
                  );
                }

                void addSavedChapter(
                  UnifiedComicDownloadStoredChapter chapter, {
                  bool grouped = false,
                }) {
                  final key = _storedKey(chapter);
                  add(ValueKey(('download-stored', key)), (_) {
                    final aliases = [
                      if (canonicalCounts[key] == 1) key,
                      ..._storedAliases(
                        chapter,
                      ).where((id) => id != key && aliasCounts[id] == 1),
                    ];
                    final progress = chapter.images.isEmpty
                        ? null
                        : _reading.lookup(
                            widget.initial.source,
                            widget.initial.comicId ?? '',
                            aliases,
                          );
                    final status = chapter.images.isEmpty
                        ? t.download.fileUnavailable
                        : progress?.completed == true &&
                              progress?.pageCount == chapter.images.length
                        ? _label(context, '已读完', 'Read')
                        : progress != null
                        ? t.comicInfo.readProgressPage(
                            page: progress.pageIndex.clamp(
                              1,
                              chapter.images.length,
                            ),
                          )
                        : key == lastReadKey && lastRead != null
                        ? t.comicInfo.readProgressPage(page: lastRead.page)
                        : _label(
                            context,
                            '${chapter.images.length} 页',
                            '${chapter.images.length} pages',
                          );
                    return WorkListRow(
                      divided: true,
                      startInset: grouped ? _groupTextStart : null,
                      inset: grouped ? _chapterTextInset : 0,
                      child: _chapterEntry(
                        key: key,
                        canRemove: titles.containsKey(key),
                        title: chapter.name,
                        grouped: grouped,
                        status: status,
                        size: metrics?.chapters[key],
                        currentReading: key == lastReadKey,
                        completedAt: chapter.completedAt,
                        lastReadAt: _history?.chapterId == key
                            ? _history?.lastReadAt
                            : null,
                        onOpen: _removingChapters || chapter.images.isEmpty
                            ? null
                            : () => widget.openChapter(context, key),
                      ),
                    );
                  });
                }

                if (saved) {
                  for (final group in groups) {
                    final expanded =
                        !expandable || expandedGroup?.key == group.key;
                    if (expandable)
                      add(ValueKey(('download-chapter-group', group.key)), (
                        headingContext,
                      ) {
                        final heading = Semantics(
                          header: true,
                          button: true,
                          enabled: true,
                          expanded: expanded,
                          child: InkWell(
                            onTap: () {
                              _openChapterSwipe.value = null;
                              setState(() {
                                _pickedGroup = true;
                                _expandedChapterKey = expanded
                                    ? null
                                    : _storedKey(group.chapters.first);
                              });
                              final expected = _expandedChapterKey;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    !headingContext.mounted ||
                                    _pane != DownloadWorkPane.saved ||
                                    expected != _expandedChapterKey ||
                                    !_savedScroll.hasClients)
                                  return;
                                final render = headingContext
                                    .findRenderObject();
                                if (render == null || !render.attached) return;
                                unawaited(
                                  _savedScroll.position.ensureVisible(
                                    render,
                                    alignmentPolicy:
                                        ScrollPositionAlignmentPolicy
                                            .keepVisibleAtStart,
                                  ),
                                );
                              });
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: _chapterTextInset,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      expanded
                                          ? Icons.expand_more
                                          : Icons.chevron_right,
                                      color: colors.onSurfaceVariant,
                                      size: _groupIconSize,
                                    ),
                                    const SizedBox(width: _groupIconGap),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.title(
                                                fallback: t
                                                    .download
                                                    .downloadedChapters,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                            ),
                                            Text(
                                              group.subtitle(chinese: chinese),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        return WorkListRow(
                          divided: true,
                          startInset: _groupTextStart,
                          inset: _chapterTextInset,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: heading,
                          ),
                        );
                      }, fold: true);
                    if (expanded) {
                      for (final chapter in group.chapters) {
                        addSavedChapter(chapter, grouped: expandable);
                      }
                    }
                  }
                  for (final chapter in stored.where(
                    (chapter) => chapter.images.isEmpty,
                  )) {
                    addSavedChapter(chapter);
                  }
                } else {
                  for (final task in active) {
                    final rowKey = ValueKey('download-chapter.${task.id}');
                    add(
                      rowKey,
                      (_) => _ChapterRow(
                        task: task,
                        builder: (current) {
                          final payload = _repository.readPayload(current);
                          final chapterKey = payload?.chapterKey ?? '';
                          final key = _chapterAttemptKey(current);
                          final status = _comicStatus([current], null);
                          final pause =
                              chapterKey.isNotEmpty &&
                              queue.canPauseTask(current);
                          final resume =
                              chapterKey.isNotEmpty &&
                              queue.canResumeTask(current);
                          final stop =
                              chapterKey.isNotEmpty &&
                              queue.canStopAndDeleteTask(current);
                          return WorkListRow(
                            divided: true,
                            child: _chapterEntry(
                              key: key,
                              title: _chapterTaskTitle(current, payload),
                              status: [
                                status.message,
                                ?status.reason,
                              ].join(' · '),
                              size: metrics?.chapters[chapterKey],
                              failed: status.failed,
                              progress: status.progress,
                              taskVersion: taskVersion(
                                current,
                                payload,
                                stop || pause,
                              ),
                              removableTransfer: stop ? current : null,
                              canRemove: false,
                              removableCancelled:
                                  _canRemoveCancelled(current, payload)
                                  ? current
                                  : null,
                              onResume: resume
                                  ? () => _changeChapterTasks({
                                      key: current,
                                    }, pause: false)
                                  : null,
                              resumeLabel: payload?.stateCode == 'cancelled'
                                  ? _label(context, '重新下载', 'Download again')
                                  : status.failed
                                  ? t.download.retryEpisodeDownload
                                  : null,
                              onPrioritize:
                                  payload?.phaseCode != 'waitingRetry' &&
                                      queue.canPrioritize(current)
                                  ? () {
                                      if (queue.prioritize(current))
                                        showSuccessToast(
                                          t.download.downloadPrioritized,
                                        );
                                    }
                                  : null,
                              onRetryNow:
                                  resume && payload?.phaseCode == 'waitingRetry'
                                  ? () => _changeChapterTasks({
                                      key: current,
                                    }, pause: false)
                                  : null,
                              onPause: pause
                                  ? () => _changeChapterTasks({
                                      key: current,
                                    }, pause: true)
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
                  }
                }

                if (saved ? stored.isEmpty : active.isEmpty) {
                  add(
                    const ValueKey('download-work-empty'),
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            saved
                                ? _label(
                                    context,
                                    '暂无已下载章节',
                                    'No downloaded chapters',
                                  )
                                : _label(
                                    context,
                                    '暂无正在下载的章节',
                                    'No downloads in progress',
                                  ),
                          ),
                          if (!saved && ready.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  _switchPane(DownloadWorkPane.saved),
                              child: Text(
                                _label(context, '查看已下载', 'View downloads'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                final listKey = PageStorageKey((
                  'download-chapters-list',
                  _pane,
                ));
                const listPadding = EdgeInsets.fromLTRB(16, 4, 16, 32);
                Widget buildRow(BuildContext context, int index) =>
                    KeyedSubtree(
                      key: rows[index].key,
                      child: rows[index].build(context),
                    );
                Widget buildSliver(int start, int end) {
                  final indices = <Key, int>{
                    for (var index = start; index < end; index++)
                      rows[index].key: index - start,
                  };
                  return SliverList.builder(
                    key: ValueKey(('download-chapter-rows', rows[start].key)),
                    itemCount: end - start,
                    findChildIndexCallback: (key) => indices[key],
                    itemBuilder: (context, index) =>
                        buildRow(context, start + index),
                  );
                }

                final Widget body;
                if (saved && expandable) {
                  final slivers = <Widget>[
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  ];
                  var start = 0;
                  for (var index = 0; index < rows.length; index++) {
                    final row = rows[index];
                    if (!row.fold) continue;
                    if (index > start) slivers.add(buildSliver(start, index));
                    slivers.add(
                      SliverToBoxAdapter(
                        key: row.key,
                        child: Builder(builder: row.build),
                      ),
                    );
                    start = index + 1;
                  }
                  if (start < rows.length)
                    slivers.add(buildSliver(start, rows.length));
                  slivers.add(
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  );
                  body = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomScrollView(
                      key: listKey,
                      controller: _savedScroll,
                      slivers: slivers,
                    ),
                  );
                } else {
                  final indices = <Key, int>{
                    for (var index = 0; index < rows.length; index++)
                      rows[index].key: index,
                  };
                  body = ListView.builder(
                    key: listKey,
                    controller: saved ? _savedScroll : _activeScroll,
                    padding: listPadding,
                    itemCount: rows.length,
                    findChildIndexCallback: (key) => indices[key],
                    itemBuilder: buildRow,
                  );
                }
                return Column(
                  children: [
                    header,
                    Expanded(child: body),
                  ],
                );
              },
            );
            return Column(
              children: [
                Expanded(child: list),
                if (_selection.active)
                  DownloadEpisodeManagementBar(
                    count: selected.length,
                    allSelected:
                        candidates.isNotEmpty &&
                        selected.length == candidates.length,
                    onToggleAll: _workingOnChapters || candidates.isEmpty
                        ? null
                        : () =>
                              setState(() => _selection.toggleAll(candidates)),
                    showDelete:
                        titles.isNotEmpty ||
                        stoppable.isNotEmpty ||
                        cancelled.isNotEmpty,
                    onDelete:
                        _workingOnChapters ||
                            (selectedToDelete.isEmpty &&
                                selectedToStopAndDelete.isEmpty &&
                                selectedCancelled.isEmpty)
                        ? null
                        : () => _removeChapters(
                            selectedToDelete,
                            transfers: selectedToStopAndDelete,
                            cancelled: selectedCancelled,
                          ),
                    pauseCount: pausable.isEmpty
                        ? null
                        : selectedToPause.length,
                    onPause: _workingOnChapters || selectedToPause.isEmpty
                        ? null
                        : () =>
                              _changeChapterTasks(selectedToPause, pause: true),
                    resumeCount: resumable.isEmpty
                        ? null
                        : selectedToResume.length,
                    onResume: _workingOnChapters || selectedToResume.isEmpty
                        ? null
                        : () => _changeChapterTasks(
                            selectedToResume,
                            pause: false,
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Set<String> _storedAliases(UnifiedComicDownloadStoredChapter chapter) => {
    for (final value in [chapter.logicalKey, chapter.taskChapterId, chapter.id])
      if (value.trim().isNotEmpty) value,
  };

  String _storedKey(UnifiedComicDownloadStoredChapter chapter) =>
      chapter.logicalKey.isNotEmpty
      ? chapter.logicalKey
      : chapter.taskChapterId.isNotEmpty
      ? chapter.taskChapterId
      : chapter.id;
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.task, required this.builder});
  final DownloadTask task;
  final Widget Function(DownloadTask task) builder;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<DowloadTaskBloc, DowloadTaskState, String>(
        selector: (state) => state.maybeWhen(
          loaded: (rows, _) =>
              rows
                  .where((row) => row.id == task.id)
                  .firstOrNull
                  ?.dbTaskInfoStr ??
              '',
          orElse: () => '',
        ),
        builder: (context, _) {
          final current =
              context.read<DowloadTaskBloc>().state.maybeWhen(
                loaded: (rows, _) =>
                    rows.where((row) => row.id == task.id).firstOrNull,
                orElse: () => null,
              ) ??
              task;
          return builder(current);
        },
      );
}
