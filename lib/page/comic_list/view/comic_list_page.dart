import 'package:zephyr/widgets/collection_results_row.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_schema.dart';
import 'package:zephyr/page/comic_list/view/jm_cloud_folder_controls.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart'
    show videoFolderName;
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/widgets/applied_filter_bar.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'dart:async';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/search_result/view/source_loaded_result_filter.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/annotations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/comic_list/cubit/comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/scene_filter/plugin_list_filter_dialog.dart';
import 'package:zephyr/page/comic_list/scene_filter/cloud_favorite_filter.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/short_alert.dart';

@RoutePage()
class ComicListPage extends StatelessWidget {
  const ComicListPage({
    super.key,
    this.title,
    this.scene,
    this.sceneSource,
    this.sceneBundleFnPath,
    this.sceneBundleFnPathFallback,
    this.embedded = false,
    this.jmCollection = false,
    this.titleInParent = false,
  });

  final String? title;
  final ComicListScene? scene;
  final String? sceneSource;
  final String? sceneBundleFnPath;
  final String? sceneBundleFnPathFallback;

  /// Render inside a source shell without a second navigation scaffold.
  final bool embedded;
  final bool jmCollection;
  final bool titleInParent;

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: scene?.from ?? sceneSource ?? '',
    builder: _buildSourcePage,
  );

  Widget _buildSourcePage(BuildContext context) {
    return BlocProvider(
      create: (_) => ComicListCubit(
        initialScene: scene,
        sceneSource: sceneSource,
        sceneBundleFnPath: sceneBundleFnPath,
        sceneBundleFnPathFallback: sceneBundleFnPathFallback,
        observeSessionChanges:
            sceneBundleFnPath == 'getCloudFavoriteSceneBundle' ||
            sceneBundleFnPath == 'get_cloud_favorite_scene_bundle' ||
            scene?.body.request?.fnPath == 'getCloudFavoriteData' ||
            scene?.body.request?.extern['source'] == 'cloudFavorite',
      ),
      child: Builder(
        builder: (context) => ReadRecoveryHost(
          onActiveChanged: context.read<ComicListCubit>().setReadActive,
          child: _ComicListView(
            title: title,
            embedded: embedded,
            titleInParent: titleInParent,
            jmCollection: jmCollection,
            cloudFavoriteEntryPoint:
                sceneBundleFnPath == 'getCloudFavoriteSceneBundle' ||
                sceneBundleFnPath == 'get_cloud_favorite_scene_bundle',
          ),
        ),
      ),
    );
  }
}

class _ComicListView extends StatefulWidget {
  const _ComicListView({
    this.title,
    required this.embedded,
    required this.titleInParent,
    this.jmCollection = false,
    required this.cloudFavoriteEntryPoint,
  });

  final String? title;
  final bool embedded, jmCollection, titleInParent;
  final bool cloudFavoriteEntryPoint;

  @override
  State<_ComicListView> createState() => _ComicListViewState();
}

class _ComicListViewState extends State<_ComicListView>
    with AutomaticKeepAliveClientMixin {
  final _jmSearch = TextEditingController();
  final _jmSearchFocus = FocusNode();
  var _jmSearchScope = KeywordSearchScope.all;
  bool _jmSearching = false;
  late (String, int) _searchSession;
  bool _filterOpening = false;
  bool _systemSearchSurface = false;
  ModalRoute<dynamic>? _remoteFilterRoute;

  final _selectionBarKey = GlobalKey();
  bool _selecting = false;
  bool _folderBusy = false;
  bool _movingWorks = false;
  int _uncachedListRevision = 0;
  Set<String> _selectedIds = {};
  ModalRoute<dynamic>? _folderRoute;
  ModalRoute<dynamic>? _folderManagerRoute;
  bool _managerOpen = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _folderFeedback;

  bool _folderManagement(ComicListState state) =>
      state.currentFrom == PluginAccountAuthenticationService.jm &&
      state.scene?.cloudFavoriteFolderManagement == true;

  Map<String, String> _customFolders(ComicListState state) => {
    for (final field
        in state.filterBundle?.scheme.fields ?? const <PluginChoiceField>[])
      if (field.key == 'folderId')
        for (final option in field.options)
          if (option.value.isNotEmpty && option.value != '0')
            option.value: option.label,
  };

  void _endSelection() => setState(() {
    _selecting = false;
    _selectedIds = {};
  });

  void _toggleWork(String id) {
    if (_folderBusy || !_selecting || id.isEmpty) return;
    setState(() {
      final next = {..._selectedIds};
      if (!next.add(id)) next.remove(id);
      _selectedIds = next;
    });
  }

  void _closeFolderRoute() {
    final routes = [_folderRoute, _folderManagerRoute];
    _folderRoute = null;
    _folderManagerRoute = null;
    _managerOpen = false;
    scheduleMicrotask(() {
      for (final route in routes) {
        if (route != null && route.isActive) {
          route.navigator?.removeRoute(route);
        }
      }
    });
  }

  Future<void> _manageJmFolders() async {
    if (_managerOpen || _folderBusy || _selecting) return;
    final cubit = context.read<ComicListCubit>();
    final session = _sessionOf(cubit.state);
    bool current() =>
        mounted &&
        _sessionOf(cubit.state) == session &&
        !pluginSessionWriteFence.isChanging(session.$1);
    if (!current() || !_folderManagement(cubit.state)) return;
    _managerOpen = true;
    try {
      final picked = await showBookshelfManagementIsland<String>(
        context: context,
        builder: (context) {
          _folderManagerRoute = ModalRoute.of(context);
          return JmCloudFolderManager(
            options: () => !current()
                ? {}
                : {
                    for (final field
                        in cubit.state.filterBundle?.scheme.fields ??
                            const <PluginChoiceField>[])
                      if (field.key == 'folderId')
                        for (final row in field.options) row.value: row.label,
                  },
            currentId: () => cubit.state.filterSelections['folderId'] ?? '',
            onAction: (action, target, feedback) async {
              if (current()) {
                await _folderAction(action, target: target, report: feedback);
              }
            },
          );
        },
      );
      if (current() &&
          picked != null &&
          (picked.isEmpty ||
              picked == '0' ||
              _customFolders(cubit.state).containsKey(picked))) {
        cubit.applyFilterSelections({
          ...cubit.state.filterSelections,
          'folderId': picked,
        });
      }
    } finally {
      if (current()) {
        _managerOpen = false;
        _folderManagerRoute = null;
      }
    }
  }

  Future<void> _folderAction(
    String action, {
    String? target,
    void Function(String message, String? openId)? report,
  }) async {
    if (_folderBusy) return;
    final cubit = context.read<ComicListCubit>();
    final state = cubit.state;
    final source = state.currentFrom;
    if (!_folderManagement(state) || pluginSessionWriteFence.isChanging(source))
      return;
    final session = _sessionOf(state);
    final snapshots = JmCollectionSnapshots.instance;
    final account = snapshots.accountScope(source);
    final currentId = target ?? state.filterSelections['folderId'] ?? '';
    final fromFolder = _customFolders(state).containsKey(currentId);
    final selected = {..._selectedIds};
    bool current() =>
        mounted &&
        _sessionOf(cubit.state) == session &&
        !pluginSessionWriteFence.isChanging(source);
    Future<void> refreshMoveCollections() async {
      if (!current()) return;
      if (account != null) {
        try {
          await snapshots.recheckAfterUnconfirmedWrite(
            source: source,
            account: account,
            generation: session.$2,
          );
          return;
        } catch (_) {}
      }
      if (current()) setState(() => _uncachedListRevision++);
    }

    void feedback(String label, {String? openId}) {
      if (!current()) return;
      if (report != null) {
        report(label, openId);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      final barHeight = _selectionBarKey.currentContext?.size?.height ?? 0;
      final controller = messenger.showSnackBar(
        SnackBar(
          content: Text(label),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, barHeight + 8),
          duration: Duration(seconds: openId == null ? 2 : 4),
          action: openId == null
              ? null
              : SnackBarAction(
                  label: t.videoLibrary.viewFolder,
                  onPressed: () {
                    if (!current() ||
                        _selecting ||
                        _folderRoute?.isActive == true ||
                        !_customFolders(cubit.state).containsKey(openId))
                      return;
                    cubit.applyFilterSelections({
                      ...cubit.state.filterSelections,
                      'folderId': openId,
                    });
                  },
                ),
        ),
      );
      _folderFeedback = controller;
      unawaited(
        controller.closed.then((_) {
          if (identical(_folderFeedback, controller)) _folderFeedback = null;
        }),
      );
    }

    Future<Map<String, dynamic>> write(
      String fnPath,
      Map<String, dynamic> core,
    ) async {
      if (!current()) throw const PluginSessionChanged();
      final result = await callUnifiedComicPlugin(
        from: source,
        fnPath: fnPath,
        core: core,
      );
      if (!current()) throw const PluginSessionChanged();
      requireSuccessfulPluginEnvelope(result);
      if (result['ok'] != true) throw const FormatException();
      return result;
    }

    String? recoveredName;
    Future<String?> editName({bool rename = false}) async {
      final previous = _customFolders(cubit.state)[currentId];
      if (!current() || rename && previous == null) return null;
      final info = PluginRegistryService.I.getCachedPluginInfo(source);
      final supportsPreparation =
          asJsonMap(info?['breezeExperience'])['jmFavoriteFolderPreparation'] ==
          1;
      String? preflightId;
      Future<void> prepare() async {
        try {
          final result = await callUnifiedComicPlugin(
            from: source,
            fnPath: 'prepareJmFavoriteFolderChange',
            core: {if (rename) 'folderId': currentId},
            notifyUnauthorized: false,
          );
          final id = result['preflightId'];
          if (current() && id is String && id.isNotEmpty) preflightId = id;
        } catch (_) {
          // Save can perform its own check if preparation is unavailable.
        }
      }

      if (supportsPreparation) unawaited(prepare());
      String? confirmedId;
      final saved = await videoFolderName(
        context,
        initial: rename ? previous! : '',
        onRoute: (route) => _folderRoute = route,
        save: (name) async {
          if (!current()) return t.videoLibrary.saveFailed;
          if (rename && _customFolders(cubit.state)[currentId] == name)
            return null;
          final before = _customFolders(cubit.state);
          final prepared = preflightId;
          preflightId = null;
          try {
            final result = await write(
              rename ? 'renameFavoriteFolder' : 'createFavoriteFolder',
              {
                'folderName': name,
                if (rename) 'folderId': currentId,
                if (supportsPreparation) 'reportFolderFailure': true,
                if (prepared != null) 'preflightId': prepared,
              },
            );
            final folder = result['folder'];
            if (folder is! Map ||
                folder['id'] is! String ||
                folder['name'] is! String)
              throw const FormatException();
            final id = folder['id'] as String,
                confirmedName = folder['name'] as String;
            if (id.isEmpty ||
                id == '0' ||
                confirmedName.isEmpty ||
                rename && id != currentId)
              throw const FormatException();
            cubit.applyConfirmedJmFolderChange(
              result['folders'],
              id: id,
              name: confirmedName,
            );
            confirmedId = id;
            return null;
          } catch (error) {
            if (!current()) return t.videoLibrary.saveFailed;
            final message = quickJsErrorMessage(error) ?? '';
            final failure = message.startsWith('{')
                ? decodeJsonMap(message)
                : const <String, dynamic>{};
            final phase = failure['type'] == 'jm_folder_change'
                ? failure['phase']
                : null;
            final reason = failure['reason'];
            if (phase == 'rejected' && reason == 'limit') {
              final count = failure['folderCount'];
              return count is int && count > 0
                  ? t.sourceProfile.jmFolderLimitDetail(count: count)
                  : t.sourceProfile.jmFolderLimit;
            }
            if (message == '收藏夹已达上限') {
              return t.sourceProfile.jmFolderLimit;
            }
            if (phase == 'notSubmitted' && reason == 'duplicate' ||
                message == '已存在同名收藏夹') {
              return t.videoLibrary.duplicateFolder;
            }
            if (phase == 'notSubmitted' && reason == 'missing') {
              unawaited(cubit.loadFilter(refresh: true));
              return t.sourceProfile.jmFolderMissing;
            }
            if (phase == 'notSubmitted' ||
                error is PluginLoginRequiredException) {
              return t.videoLibrary.saveFailed;
            }
            // The write can land even when its receipt is unavailable. Recover
            // from a fresh directory read without repeating the write.
            await cubit.loadFilter(refresh: true);
            if (!current()) return t.videoLibrary.saveFailed;
            if (cubit.state.filterError == null) {
              final folders = _customFolders(cubit.state);
              final matches = folders.entries
                  .where((entry) => entry.value == name)
                  .toList();
              if (rename && folders[currentId] == name) {
                confirmedId = currentId;
                return null;
              }
              if (!rename &&
                  matches.length == 1 &&
                  !before.containsValue(name) &&
                  !before.containsKey(matches.single.key)) {
                confirmedId = matches.single.key;
                recoveredName = name;
                return null;
              }
              if (matches.any(
                (entry) => entry.key != (rename ? currentId : null),
              )) {
                return t.videoLibrary.duplicateFolder;
              }
            }
            return t.sourceProfile.jmFolderUnconfirmed;
          }
        },
      );
      return saved == null || !current() ? null : confirmedId;
    }

    setState(() => _folderBusy = true);
    try {
      if (action == 'refresh') {
        await cubit.loadFilter(refresh: true);
        if (current()) {
          feedback(
            cubit.state.filterError == null
                ? t.common.refreshChecked
                : t.common.refreshFailed,
          );
        }
        return;
      }
      if (action == 'create' || action == 'rename') {
        final rename = action == 'rename';
        final id = await editName(rename: rename);
        if (id != null && current()) {
          feedback(
            rename
                ? t.sourceProfile.jmFolderRenamed
                : recoveredName != null
                ? t.sourceProfile.jmFolderAvailable(name: recoveredName!)
                : t.bookshelf.folderCreated,
            openId: !rename && !_selecting ? id : null,
          );
        }
        return;
      }
      if (action == 'delete') {
        final name = _customFolders(cubit.state)[currentId];
        if (name == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            _folderRoute = ModalRoute.of(context);
            return ShortAlert(
              title: Text(t.sourceProfile.jmDeleteFolder(name: name)),
              actions: [
                ShortAlertAction(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.common.cancel),
                ),
                ShortAlertAction(
                  destructive: true,
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t.common.delete),
                ),
              ],
            );
          },
        );
        if (!current() || confirmed != true) return;
        final result = await write('deleteFavoriteFolder', {
          'folderId': currentId,
          'folderName': name,
        });
        cubit.applyConfirmedJmFolderChange(result['folders'], id: currentId);
        feedback(t.sourceProfile.jmFolderDeleted);
        return;
      }
      if (action != 'move' || selected.isEmpty) return;
      String? created;
      while (current() && mounted) {
        final folders = _customFolders(cubit.state);
        final target = await pickJmCloudFolder(
          context,
          label: fromFolder
              ? t.sourceProfile.jmMoveToFolder
              : t.bookshelf.addToFolder,
          options: {
            if (created != null && folders.containsKey(created))
              created: folders[created]!,
            for (final e in folders.entries)
              if (e.key != created && e.key != currentId) e.key: e.value,
          },
          onRoute: (route) => _folderRoute = route,
        );
        if (!current() || target == null) return;
        if (target == jmCreateFolderChoice) {
          created = await editName();
          continue;
        }
        final name = folders[target];
        if (name == null) return;
        setState(() => _movingWorks = true);
        await write('moveFavoriteToFolder', {
          'comicIds': selected.toList(),
          'folderId': target,
          'folderName': name,
        });
        if (!current()) return;
        if (account == null) _uncachedListRevision++;
        if (account != null) {
          try {
            for (final id in selected) {
              if (!current()) return;
              await snapshots.mutate(
                source: source,
                account: account,
                generation: session.$2,
                id: id,
                previouslyFavorited: true,
                favorited: true,
                movedToFolder: target,
              );
            }
          } catch (_) {
            await refreshMoveCollections();
          }
        }
        if (!current()) return;
        _endSelection();
        feedback(
          fromFolder
              ? t.sourceProfile.jmMovedToFolder(name: name)
              : t.comicInfo.addedToFolder(name: name),
          openId: target,
        );
        return;
      }
    } catch (_) {
      if (current()) {
        if (_movingWorks) await refreshMoveCollections();
        if (!current()) return;
        feedback(t.sourceProfile.jmFolderUnconfirmed);
        await cubit.loadFilter(refresh: true);
      }
    } finally {
      if (current()) {
        setState(() {
          _folderBusy = false;
          _movingWorks = false;
          _folderRoute = null;
        });
      }
    }
  }

  void _dismissRemoteFilter() {
    final route = _remoteFilterRoute;
    final navigator = route?.navigator;
    if (route == null || navigator == null) return;
    scheduleMicrotask(() {
      if (route.isActive && route.navigator == navigator)
        navigator.removeRoute(route);
    });
  }

  (String, int) _sessionOf(ComicListState state) => (
    state.currentFrom,
    pluginSessionWriteFence.generation(state.currentFrom),
  );

  @override
  void initState() {
    super.initState();
    _searchSession = _sessionOf(context.read<ComicListCubit>().state);
  }

  @override
  void dispose() {
    _dismissRemoteFilter();
    _closeFolderRoute();
    _jmSearch.dispose();
    _jmSearchFocus.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool _isCloudFavoriteScene(ComicListScene scene) {
    final request = scene.body.request;
    return request != null &&
        (request.fnPath == 'getCloudFavoriteData' ||
            request.extern['source']?.toString() == 'cloudFavorite');
  }

  bool _usesCollectionTools(ComicListState state) =>
      widget.jmCollection ||
      widget.cloudFavoriteEntryPoint ||
      state.scene?.profileRecords == true ||
      (state.scene != null && _isCloudFavoriteScene(state.scene!));

  void _toggleCategory(
    String category,
    Set<String> blocked,
    ValueChanged<Set<String>> change,
  ) {
    final next = {...blocked};
    if (!next.add(category)) next.remove(category);
    change(next);
  }

  void _closeJmSearch() {
    _jmSearchFocus.unfocus();
    setState(() => _jmSearching = false);
  }

  Widget _buildJmCollection(
    BuildContext context,
    ComicListState state,
    bool detailed,
    ValueChanged<bool> onViewChanged,
    Set<String> blocked,
  ) {
    final sort = cloudFavoriteSortField(state.filterBundle);
    final remoteFilters = cloudFavoriteHasRemoteResultFilters(
      state.filterBundle,
    );
    final searching = _jmSearching && !remoteFilters;
    final sortSession = _sessionOf(state);
    final sortAction = sort == null
        ? null
        : JmCollectionSortAction(
            key: const ValueKey('jm-collection.sort'),
            bare: true,
            options: {
              for (final option in sort.options) option.value: option.label,
            },
            selected:
                state.filterSelections[sort.key] ??
                state.filterBundle?.defaultSelections[sort.key] ??
                sort.options.first.value,
            onSelected: (value) {
              if (!context.mounted) return;
              final cubit = context.read<ComicListCubit>();
              if (_sessionOf(cubit.state) != sortSession ||
                  pluginSessionWriteFence.isChanging(state.currentFrom)) {
                return;
              }
              cubit.applyFilterSelections({
                ...cubit.state.filterSelections,
                sort.key: value,
              });
            },
          );
    final canOrganize = _folderManagement(state) && state.hasResolvedFilter;
    final canEditFolder =
        canOrganize &&
        _customFolders(state).containsKey(state.filterSelections['folderId']);
    final body = Column(
      children: [
        if (remoteFilters && !_selecting)
          CollectionResultsRow(
            scope: _cloudFolderChoice(state),
            startInset: _folderManagement(state)
                ? CollectionToolbarMetrics.horizontalInset
                : null,
            countLabel: '',
            sortAction: sortAction,
            filterButton: SourceChromeIconButton(
              key: const ValueKey('jm-cloud-remote-filter'),
              bare: true,
              tooltip: t.comicList.filter,
              icon: CollectionCommandIcons.filter.icon,
              symbol: CollectionCommandIcons.filter.symbol,
              onPressed: _filterOpening
                  ? null
                  : () => _openFilterDialog(context),
            ),
            viewAction: SourceListViewToggle(
              key: const ValueKey('jm-cloud-view'),
              bare: true,
              detailed: detailed,
              onChanged: onViewChanged,
            ),
          ),
        if (remoteFilters)
          _filterSummary(
            state,
            inset: CollectionToolbarMetrics.horizontalInset,
          ),
        Expanded(
          child: JmCloudSelection(
            active: _selecting,
            enabled: !_folderBusy,
            ids: _selectedIds,
            toggle: _toggleWork,
            child: CollectionCoverPrivacyScope(
              child: _buildBody(
                context,
                state,
                detailed,
                blocked,
                jmViewChanged: onViewChanged,
                jmSortAction: sortAction,
              ),
            ),
          ),
        ),
        if (_selecting)
          JmCloudSelectionBar(
            key: _selectionBarKey,
            count: _selectedIds.length,
            busy: _folderBusy,
            moving: _movingWorks,
            moveLabel: canEditFolder
                ? t.sourceProfile.jmMoveToFolder
                : t.bookshelf.addToFolder,
            onCreate: () => _folderAction('create'),
            onMove: () => _folderAction('move'),
            onCancel: _endSelection,
          ),
      ],
    );
    final actions = <Widget>[
      if (_selecting)
        Padding(
          padding: CollectionToolbarMetrics.contentPaddingOf(context),
          child: Text(t.videoLibrary.selectedCount(count: _selectedIds.length)),
        )
      else
        JmCollectionNavigationActions(
          source: state.currentFrom,
          showSearch: !remoteFilters,
          onSearch: remoteFilters
              ? null
              : () {
                  final accountGeneration = pluginSessionWriteFence.generation(
                    state.currentFrom,
                  );
                  setState(() => _jmSearching = true);
                  requestSearchKeyboard(
                    _jmSearchFocus,
                    isCurrent: () =>
                        mounted &&
                        _jmSearching &&
                        context.read<ComicListCubit>().state.currentFrom ==
                            state.currentFrom &&
                        !pluginSessionWriteFence.isChanging(
                          state.currentFrom,
                        ) &&
                        pluginSessionWriteFence.generation(state.currentFrom) ==
                            accountGeneration &&
                        ModalRoute.of(context)?.isCurrent != false,
                  );
                },
          options: {
            if (canOrganize) ...{
              'cloud-folder.select': t.bookshelf.multiSelect,
              'cloud-folder.create': t.bookshelf.createFolder,
              'cloud-folder.refresh': t.sourceProfile.jmRefreshFolders,
              if (canEditFolder)
                'cloud-folder.rename': t.bookshelf.renameFolder,
              if (canEditFolder)
                'cloud-folder.delete': t.videoLibrary.deleteFolder,
            },
            if (!remoteFilters &&
                cloudFavoriteNeedsFilterDialog(state.filterBundle))
              'remote-filter': t.comicList.filter,
            collectionCoverSettingsAction: collectionCoverSettingsLabel(
              context,
            ),
          },
          groups: [
            if (canOrganize)
              [
                'cloud-folder.select',
                'cloud-folder.create',
                'cloud-folder.refresh',
                if (canEditFolder) 'cloud-folder.rename',
                if (canEditFolder) 'cloud-folder.delete',
              ],
            [
              if (!remoteFilters &&
                  cloudFavoriteNeedsFilterDialog(state.filterBundle))
                'remote-filter',
              collectionCoverSettingsAction,
            ],
          ],
          onSelected: (value) {
            if (value.startsWith('cloud-folder.')) {
              if (_folderBusy ||
                  !context.mounted ||
                  _sessionOf(context.read<ComicListCubit>().state) !=
                      sortSession)
                return;
              if (value == 'cloud-folder.select') {
                setState(() => _selecting = true);
              } else {
                unawaited(
                  _folderAction(value.substring('cloud-folder.'.length)),
                );
              }
            } else if (value == 'remote-filter') {
              unawaited(_openFilterDialog(context));
            } else if (value == collectionCoverSettingsAction) {
              unawaited(openCollectionCoverSettings(context));
            }
          },
        ),
    ];
    final headerHeight = SearchToolbarScope.stableHeight(
      context,
      kToolbarHeight,
    );
    final searchField = searching
        ? SearchToolbarScope(
            extent: SearchToolbarScope.fieldExtent(context),
            onClose: _closeJmSearch,
            closeKey: const ValueKey('jm-collection.search'),
            child: SourceLoadedSearchField(
              controller: _jmSearch,
              focusNode: _jmSearchFocus,
              scopeMenu: KeywordScopeMenu(
                key: const ValueKey('source-loaded.search-scope'),
                scope: _jmSearchScope,
                onChanged: (scope) {
                  if (!context.mounted ||
                      !_jmSearching ||
                      _sessionOf(context.read<ComicListCubit>().state) !=
                          sortSession) {
                    return;
                  }
                  setState(() => _jmSearchScope = scope);
                },
              ),
            ),
          )
        : null;
    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: CollectionToolbarMetrics.contentPaddingOf(context),
            child: SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child:
                        searchField ??
                        (widget.titleInParent
                            ? const SizedBox.shrink()
                            : Text(widget.title ?? '站点收藏')),
                  ),
                  if (!searching) ...actions,
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return PopScope(
      canPop: !searching && !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _folderBusy) return;
        if (_selecting) {
          _endSelection();
        } else if (searching) {
          _closeJmSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: headerHeight,
          leadingWidth: CollectionToolbarMetrics.leadingExtentOf(context),
          leading: searching
              ? null
              : CollectionToolbarMetrics.leading(
                  context,
                  const SourceBackButton(),
                ),
          title: searchField == null
              ? Text(
                  widget.title ?? state.scene?.title ?? '站点收藏',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Padding(
                  padding: CollectionToolbarMetrics.contentPaddingOf(context),
                  child: searchField,
                ),
          titleSpacing: 0,
          actionsPadding: CollectionToolbarMetrics.trailingPadding,
          actions: searching ? null : actions,
        ),
        body: body,
      ),
    );
  }

  Widget _jmControls(
    BuildContext context,
    ComicListState state,
    SourceLoadedResultChrome chrome,
    bool detailed,
    ValueChanged<bool> onViewChanged,
    Widget? sortAction,
  ) => _selecting
      ? const SizedBox.shrink()
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CollectionResultsRow(
              scope: _cloudFolderChoice(state) ?? chrome.pageNavigation,
              inlineScope:
                  chrome.pageNavigation != null &&
                  _cloudFolderChoice(state) == null,
              startInset: _folderManagement(state)
                  ? CollectionToolbarMetrics.horizontalInset
                  : null,
              countLabel: chrome.pageNavigation == null
                  ? chrome.countLabel
                  : chrome.total > 0 ||
                        chrome.knownTotal != null ||
                        chrome.complete
                  ? _numberedCollectionCount(chrome)
                  : '',
              countSemanticsLabel: chrome.pageNavigation == null
                  ? null
                  : _numberedCollectionCount(chrome, compact: false),
              countKey: chrome.pageNavigation == null
                  ? null
                  : const ValueKey('plugin-list.numbered-count'),
              filterButton: chrome.filterButton,
              sortAction: sortAction,
              viewAction: SourceListViewToggle(
                key: const ValueKey('jm-cloud-view'),
                bare: true,
                detailed: detailed,
                onChanged: onViewChanged,
              ),
            ),
            if (chrome.pageNavigation case final navigation?
                when _cloudFolderChoice(state) != null)
              Padding(
                padding: CollectionToolbarMetrics.contentPaddingOf(context),
                child: navigation,
              ),
            if (chrome.appliedFilters case final applied?) applied,
          ],
        );

  String _numberedCollectionCount(
    SourceLoadedResultChrome chrome, {
    bool compact = true,
  }) {
    if (chrome.filtersActive ||
        _jmSearch.text.trim().isNotEmpty ||
        chrome.shown != chrome.total) {
      return t.videoLibrary.filteredLoaded(
        loaded: chrome.total,
        shown: chrome.shown,
      );
    }
    final total = chrome.knownTotal;
    if (total != null && chrome.total < total) {
      if (compact) return '${chrome.total}/$total';
      return t.sourceShell.collectionLoadingCount(
        loaded: chrome.total,
        total: total,
      );
    }
    return t.videoLibrary.results(count: chrome.total);
  }

  Widget _cloudToolbar(
    ComicListState state,
    bool detailed,
    ValueChanged<bool> onChanged,
    Set<String> blocked,
    ValueChanged<Set<String>> onBlockedChanged,
  ) {
    final sort = cloudFavoriteSortField(state.filterBundle);
    return SourceListFilterBar(
      contentInset: CollectionToolbarMetrics.sourceContentInset,
      categories: const [],
      blockedCategories: blocked,
      onCategoryTap: (category) =>
          _toggleCategory(category, blocked, onBlockedChanged),
      onClearBlockedCategories: () => onBlockedChanged({}),
      sortValue: sort == null ? '' : state.filterSelections[sort.key] ?? '',
      sortOptions: {
        if (sort != null)
          for (final option in sort.options) option.value: option.label,
      },
      onSortChanged: (value) {
        if (sort == null) return;
        context.read<ComicListCubit>().applyFilterSelections({
          ...state.filterSelections,
          sort.key: value,
        });
      },
      detailedView: detailed,
      onViewChanged: onChanged,
      viewToggleKey: const ValueKey('cloud-favorite-view-toggle'),
      leading: _cloudFolderChoice(state),
    );
  }

  Widget? _cloudFolderChoice(ComicListState state) {
    final folders = state.filterBundle?.scheme.fields
        .where(
          (field) =>
              field.key == 'folderId' &&
              field.options.isNotEmpty &&
              field.options.every((option) => option.children.isEmpty),
        )
        .firstOrNull;
    if (folders == null) {
      if (_usesCollectionTools(state) && state.filterLoading)
        return Row(
          key: const ValueKey('cloud-favorite.folder-loading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_outlined, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                t.common.loading,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      return null;
    }
    if (!_usesCollectionTools(state) && folders.options.length < 2) return null;
    final value = state.filterSelections[folders.key] ?? '';
    final options = {
      for (final option in folders.options) option.value: option.label,
    };
    final session = _sessionOf(state);
    void select(String value) {
      if (!mounted ||
          _folderBusy ||
          _selecting ||
          pluginSessionWriteFence.isChanging(session.$1))
        return;
      final cubit = context.read<ComicListCubit>();
      if (_sessionOf(cubit.state) != session) return;
      cubit.applyFilterSelections({
        ...cubit.state.filterSelections,
        folders.key: value,
      });
    }

    if (_folderManagement(state)) {
      return JmCloudFolderButton(
        key: const ValueKey('cloud-favorite.folder'),
        label: options[value] ?? options.values.first,
        onPressed: _folderBusy || _selecting ? null : _manageJmFolders,
      );
    }
    final Widget choice =
        _usesCollectionTools(state) && folders.options.length > 8
        ? JmCollectionFolderChoice(
            key: const ValueKey('cloud-favorite.folder'),
            label: folders.label,
            value: value,
            options: options,
            onRoute: (route) => _folderRoute = route,
            onChanged: folders.options.length == 1 ? null : select,
          )
        : SourceChoiceMenu<String>(
            key: const ValueKey('cloud-favorite.folder'),
            tooltip: folders.label,
            label:
                folders.findOptionByValue(value)?.label ??
                folders.options.first.label,
            value: value,
            options: options,
            selectionIndicator: !_usesCollectionTools(state),
            maximumWidth: _usesCollectionTools(state) ? 160 : 180,
            onChanged:
                _usesCollectionTools(state) && folders.options.length == 1
                ? null
                : select,
          );
    if (!_usesCollectionTools(state)) return choice;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_outlined, size: 18),
        const SizedBox(width: 4),
        Flexible(child: choice),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _systemSearchSurface = usesSystemSearchSurface(context);
    return BlocConsumer<ComicListCubit, ComicListState>(
      listenWhen: (_, state) => _searchSession != _sessionOf(state),
      listener: (_, state) {
        _searchSession = _sessionOf(state);
        _folderFeedback?.close();
        _closeFolderRoute();
        _folderBusy = false;
        _movingWorks = false;
        _selectedIds = {};
        _selecting = false;
        _jmSearching = false;
        _jmSearchScope = KeywordSearchScope.all;
        _jmSearch.clear();
        _jmSearchFocus.unfocus();
      },
      builder: (context, state) {
        final isBikaRanking = _usesBikaRankingLayout(state);
        final isCloudFavorite =
            widget.cloudFavoriteEntryPoint ||
            (state.scene != null && _isCloudFavoriteScene(state.scene!));
        final title =
            widget.title ?? (state.scene?.title ?? t.comicList.defaultTitle);
        final publicLoadedFacets = _copyPublicLoadedFacets(state);

        return SourceCategoryBlockScope(
          scope:
              '${state.currentFrom}|${isCloudFavorite ? 'cloudFavorite' : state.scene?.body.request?.fnPath ?? 'list'}',
          builder: (context, blocked, onBlockedChanged) =>
              SourceListPresentation(
                source: state.currentFrom,
                detailedByDefault:
                    isCloudFavorite || state.scene?.profileRecords == true,
                builder: (context, detailed, onViewChanged) {
                  Widget loadedTools(
                    BuildContext context,
                    SourceLoadedResultChrome chrome,
                  ) => _publicLoadedToolbar(
                    context,
                    chrome,
                    title: widget.embedded && !widget.titleInParent
                        ? title
                        : null,
                    detailed: detailed,
                    onViewChanged: onViewChanged,
                  );
                  if ((isCloudFavorite ||
                          state.scene?.profileRecords == true) &&
                      _usesCollectionTools(state)) {
                    return _buildJmCollection(
                      context,
                      state,
                      detailed,
                      onViewChanged,
                      blocked,
                    );
                  }
                  final remoteFilter =
                      state.requiresFilter &&
                          !isBikaRanking &&
                          (!isCloudFavorite ||
                              cloudFavoriteNeedsFilterDialog(
                                state.filterBundle,
                              ))
                      ? SourceChromeIconButton(
                          bare:
                              widget.embedded ||
                              !usesNativeSourceChrome(context),
                          tooltip: t.comicList.filter,
                          icon: CollectionCommandIcons.filter.icon,
                          symbol: CollectionCommandIcons.filter.symbol,
                          onPressed: _filterOpening
                              ? null
                              : () => _openFilterDialog(context),
                        )
                      : null;
                  if (widget.embedded) {
                    final viewInPageRow =
                        widget.titleInParent &&
                        state.scene?.body.request != null &&
                        !state.requiresFilter &&
                        !publicLoadedFacets &&
                        !isCloudFavorite &&
                        !isBikaRanking;
                    return Column(
                      children: [
                        if (!publicLoadedFacets && !viewInPageRow)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              CollectionToolbarMetrics.sourceContentInset,
                              4,
                              CollectionToolbarMetrics.sourceContentInset,
                              4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: widget.titleInParent
                                      ? const SizedBox.shrink()
                                      : Text(
                                          title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                ),
                                if (isBikaRanking)
                                  _rankingTypeChoice(context, state),
                                if (isCloudFavorite) ...[
                                  const CollectionCoverPrivacyButton(),
                                  const CollectionCoverSettingsMoreButton(),
                                ],
                                ?remoteFilter,
                                if (!isBikaRanking && !isCloudFavorite)
                                  SourceListViewToggle(
                                    detailed: detailed,
                                    onChanged: onViewChanged,
                                  ),
                              ],
                            ),
                          ),
                        if (isCloudFavorite)
                          _cloudToolbar(
                            state,
                            detailed,
                            onViewChanged,
                            blocked,
                            onBlockedChanged,
                          ),
                        if (isBikaRanking) _rankingPeriodBar(context, state),
                        _filterSummary(state),
                        Expanded(
                          child: CollectionCoverPrivacyScope(
                            enabled: isCloudFavorite,
                            child: _buildBody(
                              context,
                              state,
                              detailed,
                              blocked,
                              publicLoadedTools: publicLoadedFacets
                                  ? loadedTools
                                  : null,
                              pageViewAction: viewInPageRow
                                  ? SourceListViewToggle(
                                      detailed: detailed,
                                      onChanged: onViewChanged,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Scaffold(
                    appBar: AppBar(
                      leading: const SourceBackButton(),
                      title: Text(title),
                      actionsPadding: const EdgeInsetsDirectional.only(
                        end: CollectionToolbarMetrics.sourceContentInset,
                      ),
                      actions: [
                        if (isBikaRanking) _rankingTypeChoice(context, state),
                        if (isCloudFavorite)
                          const CollectionCoverPrivacyButton(),
                        ?remoteFilter,
                        if (!isBikaRanking &&
                            !isCloudFavorite &&
                            !publicLoadedFacets)
                          SourceListViewToggle(
                            detailed: detailed,
                            onChanged: onViewChanged,
                          ),
                        SourceMoreButton(
                          source: state.currentFrom,
                          showCoverSettings: isCloudFavorite,
                        ),
                      ],
                    ),
                    body: Column(
                      children: [
                        if (isCloudFavorite)
                          _cloudToolbar(
                            state,
                            detailed,
                            onViewChanged,
                            blocked,
                            onBlockedChanged,
                          ),
                        if (isBikaRanking) _rankingPeriodBar(context, state),
                        _filterSummary(state),
                        Expanded(
                          child: CollectionCoverPrivacyScope(
                            enabled: isCloudFavorite,
                            child: _buildBody(
                              context,
                              state,
                              detailed,
                              blocked,
                              publicLoadedTools: publicLoadedFacets
                                  ? loadedTools
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        );
      },
    );
  }

  bool _copyPublicLoadedFacets(ComicListState state) =>
      state.currentFrom == copyComicSourceId &&
      !state.requiresFilter &&
      const {
        'getHomeRecommend',
        'getHomeNewest',
      }.contains(state.scene?.body.request?.fnPath);

  Widget _publicLoadedToolbar(
    BuildContext context,
    SourceLoadedResultChrome chrome, {
    required String? title,
    required bool detailed,
    required ValueChanged<bool> onViewChanged,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (chrome.pageNavigation case final navigation?)
        Padding(
          padding: CollectionToolbarMetrics.contentPaddingOf(context),
          child: navigation,
        ),
      Padding(
        padding: CollectionToolbarMetrics.contentPaddingOf(
          context,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          key: const ValueKey('comic-list.public-loaded-tools'),
          spacing: CollectionToolbarMetrics.searchControlGap,
          children: [
            Expanded(
              child: Text(
                title ??
                    (chrome.filtersActive
                        ? chrome.countLabel
                        : chrome.total == 0
                        ? ''
                        : t.sourceShell.collectionLoadedCount(
                            count: chrome.total,
                          )),
                style: title == null
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (chrome.hasFilterOptions) chrome.filterButton,
            SourceListViewToggle(detailed: detailed, onChanged: onViewChanged),
          ],
        ),
      ),
      SourceLoadedFacetSummary(chrome: chrome, showCount: title != null),
    ],
  );

  Widget _filterSummary(
    ComicListState state, {
    double inset = CollectionToolbarMetrics.sourceContentInset,
  }) {
    final bundle = state.filterBundle;
    if (bundle == null) return const SizedBox.shrink();
    final selected = <AppliedFilter>[];
    final cubit = context.read<ComicListCubit>();
    final defaults = bundle.defaultSelections;
    void clearFields(Iterable<String> fields) {
      final next = {...cubit.state.filterSelections};
      for (final field in fields) {
        if (defaults[field] case final value?) {
          next[field] = value;
        } else {
          next.remove(field);
        }
      }
      cubit.applyFilterSelections(next);
    }

    for (final field in bundle.scheme.fields) {
      // The period segmented control already expresses this exact condition.
      // Keep any additional user-selected conditions in the summary.
      if (_usesBikaRankingLayout(state) && field.key == 'ranking') continue;
      if ((widget.cloudFavoriteEntryPoint ||
              state.scene != null && _isCloudFavoriteScene(state.scene!)) &&
          (field == cloudFavoriteSortField(bundle) || field.key == 'folderId'))
        continue;
      final value = state.filterSelections[field.key];
      if (value == null || value == bundle.defaultSelections[field.key]) {
        continue;
      }
      final option = field.findOptionByValue(value);
      if (option != null && option.value.isNotEmpty) {
        selected.add((
          id: field.key,
          label: convertChineseForDisplay('${field.label} · ${option.label}'),
          edit: _filterOpening ? null : () => _openFilterDialog(context),
          remove: () => clearFields([field.key]),
        ));
      }
    }
    return AppliedFilterBar(
      entries: selected,
      inset: inset,
      compact: _usesCollectionTools(state),
      onClearAll: () => clearFields(selected.map((entry) => entry.id)),
    );
  }

  Widget _rankingPeriodBar(BuildContext context, ComicListState state) {
    final selected = state.filterSelections['ranking'] ?? 'day';
    final selectedType = state.filterSelections['rankingType'] ?? 'comic';
    if (selectedType != 'comic') return const SizedBox.shrink();
    final periods = <String, String>{
      'day': t.bikaRanking.day,
      'week': t.bikaRanking.week,
      'month': t.bikaRanking.month,
    };
    void select(String key, String value) {
      context.read<ComicListCubit>().applyFilterSelections({
        ...state.filterSelections,
        key: value,
      });
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        CollectionToolbarMetrics.sourceContentInset,
        0,
        CollectionToolbarMetrics.sourceContentInset,
        4,
      ),
      child: Tooltip(
        message: '${t.bikaRanking.period}: ${periods.values.join(' / ')}',
        child: NativeVideoSegmentedControl(
          key: const ValueKey('bika-ranking.period'),
          options: periods,
          selected: selected,
          enabled: state.hasResolvedFilter,
          onSelected: state.hasResolvedFilter
              ? (value) => select('ranking', value)
              : null,
        ),
      ),
    );
  }

  bool _usesBikaRankingLayout(ComicListState state) =>
      state.scene?.body.request?.fnPath == 'getRankingData' &&
      (state.currentFrom == 'e9f18928-3ba8-4d86-a12e-b53a62f47933' ||
          state.scene?.body.params['layout'] == 'bikaRanking');

  Widget _rankingTypeChoice(BuildContext context, ComicListState state) {
    final selected = state.filterSelections['rankingType'] ?? 'comic';
    final types = {
      'comic': t.bikaRanking.popular,
      'creator': t.bikaRanking.creators,
    };
    return SourceChoiceMenu<String>(
      key: const ValueKey('bika-ranking.type'),
      label: types[selected] ?? types.values.first,
      tooltip: t.bikaRanking.type,
      value: selected,
      options: types,
      selectionIndicator: true,
      onChanged: state.hasResolvedFilter
          ? (value) => context.read<ComicListCubit>().applyFilterSelections({
              ...state.filterSelections,
              'rankingType': value,
            })
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ComicListState state,
    bool detailed,
    Set<String> blocked, {
    Widget Function(BuildContext, SourceLoadedResultChrome)? publicLoadedTools,
    ValueChanged<bool>? jmViewChanged,
    Widget? jmSortAction,
    Widget? pageViewAction,
  }) {
    final currentFrom = state.currentFrom;

    if (currentFrom.isEmpty) {
      return Center(child: Text(t.comicList.missingSource));
    }

    if (state.sceneLoading && state.scene == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.sceneError != null &&
        (state.scene == null ||
            state.scene!.body.request?.fnPath.trim().isNotEmpty != true)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                userFacingErrorMessage(state.sceneError!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<ComicListCubit>().reload(),
              child: Text(t.comicList.reload),
            ),
          ],
        ),
      );
    }

    if (state.requiresFilter &&
        state.filterLoading &&
        !state.hasResolvedFilter) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.requiresFilter &&
        state.filterError != null &&
        !state.hasResolvedFilter) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                userFacingErrorMessage(state.filterError!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<ComicListCubit>().loadFilter(),
              child: Text(t.comicList.reload),
            ),
          ],
        ),
      );
    }

    final scene = state.scene;
    if (scene != null) {
      return _buildSceneBody(
        state,
        scene,
        detailed,
        blocked,
        publicLoadedTools,
        jmViewChanged,
        jmSortAction,
        pageViewAction,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSceneBody(
    ComicListState state,
    ComicListScene scene,
    bool detailed,
    Set<String> blocked,
    Widget Function(BuildContext, SourceLoadedResultChrome)? publicLoadedTools,
    ValueChanged<bool>? jmViewChanged,
    Widget? jmSortAction,
    Widget? pageViewAction,
  ) {
    final request = scene.body.request!;
    final filterCore = state.resolvedFilterCore;
    final filterExtern = state.resolvedFilterExtern;
    final listCore = <String, dynamic>{...request.core, ...filterCore};
    final listExtern = <String, dynamic>{...request.extern, ...filterExtern};
    final collectionTargetId = _resolveCollectionTargetId(
      request: request,
      core: listCore,
      extern: listExtern,
    );

    return PluginPagedComicListView(
      key: ValueKey(
        '${state.currentFrom}_${request.fnPath}_${listCore}_${listExtern}_${pluginSessionWriteFence.generation(state.currentFrom)}_$_uncachedListRevision',
      ),
      pluginId: state.currentFrom,
      fnPath: request.fnPath,
      pageViewAction: pageViewAction,
      tabReselectEnabled:
          widget.embedded &&
          !_jmSearching &&
          !_filterOpening &&
          !_systemSearchSurface,
      coreBuilder: (page) => {...listCore, 'page': page},
      externBuilder: (_) => listExtern,
      collectionTargetId: collectionTargetId,
      rankingLayout: _usesBikaRankingLayout(state),
      cloudFavorite:
          widget.cloudFavoriteEntryPoint || _isCloudFavoriteScene(scene),
      flatCollectionControls: scene.profileRecords,
      detailedView: detailed,
      blockedCategories: blocked,
      localResultTools: !cloudFavoriteHasRemoteResultFilters(
        state.filterBundle,
      ),
      publicLoadedFacets: publicLoadedTools != null,
      loadedSearchController: _usesCollectionTools(state) ? _jmSearch : null,
      loadedSearchFocusNode: _usesCollectionTools(state)
          ? _jmSearchFocus
          : null,
      loadedSearchExpanded: !_usesCollectionTools(state) || _jmSearching,
      loadedSearchScope: _usesCollectionTools(state) ? _jmSearchScope : null,
      focusedFacets: _usesCollectionTools(state),
      loadedChromeBuilder: _usesCollectionTools(state) && jmViewChanged != null
          ? (context, chrome) => _jmControls(
              context,
              state,
              chrome,
              detailed,
              jmViewChanged,
              jmSortAction,
            )
          : publicLoadedTools,
    );
  }

  String? _resolveCollectionTargetId({
    required ComicListRequestConfig request,
    required Map<String, dynamic> core,
    required Map<String, dynamic> extern,
  }) {
    final isCloudFavoriteScene =
        request.fnPath == 'getCloudFavoriteData' ||
        extern['source']?.toString() == 'cloudFavorite';
    if (!isCloudFavoriteScene) {
      return null;
    }
    final targetId = core['folderId'] ?? extern['folderId'];
    final normalized = targetId?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _openFilterDialog(BuildContext context) async {
    if (_filterOpening) return;
    setState(() => _filterOpening = true);
    final cubit = context.read<ComicListCubit>();
    final source = cubit.state.currentFrom;
    final generation = pluginSessionWriteFence.generation(source);
    final sessionChanges = pluginSessionWriteFence.changes.listen((boundary) {
      if (boundary.source == source) _dismissRemoteFilter();
    });
    try {
      if (!cubit.state.hasResolvedFilter) await cubit.loadFilter();
      if (!context.mounted) return;
      if (generation != pluginSessionWriteFence.generation(source) ||
          pluginSessionWriteFence.isChanging(source)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.comicList.loadedFiltersChanged)),
        );
        return;
      }
      final bundle = cubit.state.filterBundle;
      if (bundle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                cubit.state.filterError ?? t.common.loadingFailed,
              ),
            ),
          ),
        );
        return;
      }
      final scene = cubit.state.scene;
      final role =
          widget.cloudFavoriteEntryPoint ||
              (scene != null && _isCloudFavoriteScene(scene))
          ? 'cloudFavorite'
          : scene?.body.request?.fnPath ?? 'list';
      final favoriteScope =
          'source-filter|$source|comic-list|${Uri.encodeComponent(role)}';
      FocusManager.instance.primaryFocus?.unfocus();
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.none,
        elevation: 0,
        builder: (sheetContext) {
          _remoteFilterRoute = ModalRoute.of(sheetContext);
          return PluginListFilterDialog(
            favoriteScope: favoriteScope,
            scheme: bundle.scheme,
            defaultSelections: bundle.defaultSelections,
            initialSelections: cubit.state.filterSelections.isNotEmpty
                ? cubit.state.filterSelections
                : bundle.defaultSelections,
          );
        },
      );
      if (result != null && context.mounted) {
        if (generation != pluginSessionWriteFence.generation(source)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.comicList.loadedFiltersChanged)),
          );
          return;
        }
        cubit.applyFilterSelections(result);
      }
    } finally {
      // The broadcast subscription detaches synchronously. Its completion is
      // cleanup, not part of the sheet's interactive lifetime (and can belong
      // to a different async zone in an embedded host).
      final cancellation = sessionChanges.cancel();
      await _remoteFilterRoute?.completed;
      _remoteFilterRoute = null;
      if (mounted) {
        setState(() => _filterOpening = false);
      } else {
        _filterOpening = false;
      }
      await cancellation;
    }
  }
}
