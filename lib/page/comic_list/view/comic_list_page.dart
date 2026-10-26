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
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/search_result/view/source_list_filter_bar.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

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
  });

  final String? title;
  final ComicListScene? scene;
  final String? sceneSource;
  final String? sceneBundleFnPath;
  final String? sceneBundleFnPathFallback;

  /// Render inside a source shell without a second navigation scaffold.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ComicListCubit(
        initialScene: scene,
        sceneSource: sceneSource,
        sceneBundleFnPath: sceneBundleFnPath,
        sceneBundleFnPathFallback: sceneBundleFnPathFallback,
      ),
      child: _ComicListView(
        title: title,
        embedded: embedded,
        cloudFavoriteEntryPoint:
            sceneBundleFnPath == 'getCloudFavoriteSceneBundle' ||
            sceneBundleFnPath == 'get_cloud_favorite_scene_bundle',
      ),
    );
  }
}

class _ComicListView extends StatefulWidget {
  const _ComicListView({
    this.title,
    required this.embedded,
    required this.cloudFavoriteEntryPoint,
  });

  final String? title;
  final bool embedded;
  final bool cloudFavoriteEntryPoint;

  @override
  State<_ComicListView> createState() => _ComicListViewState();
}

class _ComicListViewState extends State<_ComicListView>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _blockedCategories = {};

  @override
  bool get wantKeepAlive => true;

  bool _isCloudFavoriteScene(ComicListScene scene) {
    final request = scene.body.request;
    return request != null &&
        (request.fnPath == 'getCloudFavoriteData' ||
            request.extern['source']?.toString() == 'cloudFavorite');
  }

  void _toggleCategory(String category) {
    final wasBlocked = _blockedCategories.contains(category);
    setState(() {
      if (wasBlocked) {
        _blockedCategories.remove(category);
      } else {
        _blockedCategories.add(category);
      }
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wasBlocked
              ? '已恢复「${convertChineseForDisplay(category)}」'
              : '已屏蔽「${convertChineseForDisplay(category)}」· 再点恢复',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _cloudToolbar(
    ComicListState state,
    bool detailed,
    ValueChanged<bool> onChanged,
  ) => SourceListFilterBar(
    categories: sourceQuickCategories(state.currentFrom),
    blockedCategories: _blockedCategories,
    onCategoryTap: _toggleCategory,
    onClearBlockedCategories: () => setState(_blockedCategories.clear),
    sortValue: state.filterSelections['order'] ?? 'dd',
    sortOptions: const {'dd': '收藏最新', 'da': '收藏最早'},
    onSortChanged: (value) => context
        .read<ComicListCubit>()
        .applyFilterSelections({...state.filterSelections, 'order': value}),
    detailedView: detailed,
    onViewChanged: onChanged,
    viewToggleKey: const ValueKey('cloud-favorite-view-toggle'),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<ComicListCubit, ComicListState>(
      builder: (context, state) {
        final isBikaRanking =
            state.currentFrom == 'e9f18928-3ba8-4d86-a12e-b53a62f47933' &&
            state.scene?.body.request?.fnPath == 'getRankingData';
        final isCloudFavorite =
            widget.cloudFavoriteEntryPoint ||
            (state.scene != null && _isCloudFavoriteScene(state.scene!));
        final title =
            widget.title ?? (state.scene?.title ?? t.comicList.defaultTitle);

        return SourceListPresentation(
          source: state.currentFrom,
          detailedByDefault: isCloudFavorite,
          builder: (context, detailed, onViewChanged) {
            if (widget.embedded) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!isBikaRanking && !isCloudFavorite)
                          SourceListViewToggle(
                            detailed: detailed,
                            onChanged: onViewChanged,
                          ),
                        if (state.requiresFilter &&
                            !isBikaRanking &&
                            !isCloudFavorite)
                          IconButton(
                            tooltip: t.comicList.filter,
                            icon: const Icon(Icons.filter_alt_outlined),
                            onPressed: () => _openFilterDialog(context),
                          ),
                      ],
                    ),
                  ),
                  if (isCloudFavorite)
                    _cloudToolbar(state, detailed, onViewChanged),
                  if (isBikaRanking) _rankingPeriodBar(context, state),
                  if (!isCloudFavorite) _filterSummary(state),
                  Expanded(child: _buildBody(context, state, detailed)),
                ],
              );
            }

            return Scaffold(
              appBar: AppBar(
                leading: const SourceBackButton(),
                title: Text(title),
                actions: [
                  if (!isBikaRanking && !isCloudFavorite)
                    SourceListViewToggle(
                      detailed: detailed,
                      onChanged: onViewChanged,
                    ),
                  if (state.requiresFilter &&
                      !isBikaRanking &&
                      !isCloudFavorite)
                    SourceChromeIconButton(
                      tooltip: t.comicList.filter,
                      icon: Icons.filter_alt_outlined,
                      symbol: 'line.3.horizontal.decrease',
                      onPressed: () => _openFilterDialog(context),
                    ),
                  SourceMoreButton(source: state.currentFrom),
                ],
              ),
              body: Column(
                children: [
                  if (isCloudFavorite)
                    _cloudToolbar(state, detailed, onViewChanged),
                  if (isBikaRanking) _rankingPeriodBar(context, state),
                  if (!isCloudFavorite) _filterSummary(state),
                  Expanded(child: _buildBody(context, state, detailed)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterSummary(ComicListState state) {
    final bundle = state.filterBundle;
    if (bundle == null) return const SizedBox.shrink();
    final selected = <String>[];
    for (final field in bundle.scheme.fields) {
      final value = state.filterSelections[field.key];
      if (value == null || value == bundle.defaultSelections[field.key]) {
        continue;
      }
      final option = field.findOptionByValue(value);
      if (option != null && option.value.isNotEmpty) {
        selected.add('${field.label} · ${option.label}');
      }
    }
    if (selected.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: selected.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Center(
                child: ActionChip(
                  label: Text(convertChineseForDisplay(selected[index])),
                  onPressed: () => _openFilterDialog(context),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: t.comicList.clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () => context
                .read<ComicListCubit>()
                .applyFilterSelections(bundle.defaultSelections),
          ),
        ],
      ),
    );
  }

  Widget _rankingPeriodBar(BuildContext context, ComicListState state) {
    final selected = state.filterSelections['ranking'] ?? 'day';
    final selectedType = state.filterSelections['rankingType'] ?? 'comic';
    const periods = <String, String>{
      'day': '过去 24 小时',
      'week': '过去 7 天',
      'month': '过去 30 天',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final type in const <String, String>{
                'comic': '最热门',
                'creator': '骑士榜',
              }.entries)
                Expanded(
                  child: TextButton(
                    onPressed: state.hasResolvedFilter
                        ? () => context
                              .read<ComicListCubit>()
                              .applyFilterSelections({
                                ...state.filterSelections,
                                'rankingType': type.key,
                              })
                        : null,
                    child: Text(
                      type.value,
                      style: TextStyle(
                        fontWeight: selectedType == type.key
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (selectedType == 'comic')
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final period in periods.entries)
                  ChoiceChip(
                    label: Text(period.value),
                    selected: selected == period.key,
                    onSelected: state.hasResolvedFilter
                        ? (_) => context
                              .read<ComicListCubit>()
                              .applyFilterSelections({
                                ...state.filterSelections,
                                'ranking': period.key,
                              })
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ComicListState state, bool detailed) {
    final currentFrom = state.currentFrom;

    if (currentFrom.isEmpty) {
      return Center(child: Text(t.comicList.missingSource));
    }

    if (state.sceneLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.sceneError != null) {
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
      return _buildSceneBody(state, scene, detailed);
    }

    return const SizedBox.shrink();
  }

  Widget _buildSceneBody(
    ComicListState state,
    ComicListScene scene,
    bool detailed,
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
      key: ValueKey('${request.fnPath}_${listCore}_$listExtern'),
      pluginId: state.currentFrom,
      fnPath: request.fnPath,
      coreBuilder: (page) => {'page': page, ...listCore},
      externBuilder: (_) => listExtern,
      collectionTargetId: collectionTargetId,
      rankingLayout:
          state.currentFrom == 'e9f18928-3ba8-4d86-a12e-b53a62f47933' &&
          request.fnPath == 'getRankingData',
      cloudFavorite:
          widget.cloudFavoriteEntryPoint || _isCloudFavoriteScene(scene),
      detailedView: detailed,
      blockedCategories: _blockedCategories,
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
    final cubit = context.read<ComicListCubit>();

    if (!cubit.state.hasResolvedFilter) {
      await cubit.loadFilter();
    }

    final bundle = cubit.state.filterBundle;
    if (!context.mounted || bundle == null) {
      return;
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      clipBehavior: Clip.antiAlias,
      builder: (context) => PluginListFilterDialog(
        scheme: bundle.scheme,
        defaultSelections: bundle.defaultSelections,
        initialSelections: cubit.state.filterSelections.isNotEmpty
            ? cubit.state.filterSelections
            : bundle.defaultSelections,
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    cubit.applyFilterSelections(result);
  }
}
