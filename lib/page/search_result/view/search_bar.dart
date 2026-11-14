import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/util/event/event.dart';
import 'dart:convert';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

String sourceBrowseTitle(SearchStates state) {
  final categories = blockedCategoryNames(state.pluginExtern['categories']);
  if (categories.isNotEmpty) {
    return categories.map(convertChineseForDisplay).join(' · ');
  }
  if (state.pluginExtern['mode'] == 'creator') return '作者作品';
  final url = Uri.tryParse('${state.pluginExtern['url'] ?? ''}');
  if (url?.path.endsWith('/random') == true) return '随机作品';
  final category = url?.queryParameters['c'];
  if (category != null && category.isNotEmpty) {
    return convertChineseForDisplay(category);
  }
  return '作品列表';
}

class SearchResultBar extends StatefulWidget implements PreferredSizeWidget {
  final SearchEvent searchEvent;

  const SearchResultBar({
    super.key,
    required this.searchEvent,
    this.toolbarHeight,
  });

  final double? toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);

  @override
  State<SearchResultBar> createState() => _SearchResultBarState();
}

class _SearchResultBarState extends State<SearchResultBar> {
  String? _schemeKey;
  Future<PluginAdvancedSearchScheme?>? _schemeFuture;
  bool _openingAdvancedSearch = false;

  Future<PluginAdvancedSearchScheme?> _schemeFor(SearchStates state) {
    final key = jsonEncode([
      state.from,
      state.pluginExtern,
      pluginSessionWriteFence.generation(normalizePluginId(state.from)),
    ]);
    if (_schemeKey != key) {
      _schemeKey = key;
      _schemeFuture = _loadAdvancedSearchScheme(state.from, state.pluginExtern);
    }
    return _schemeFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<SearchCubit>().state;
    final extent = SearchToolbarScope.of(context);

    return AppBar(
      toolbarHeight: widget.toolbarHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      titleSpacing: 0, // 清除默认边距，完全自定义
      automaticallyImplyLeading: false, // 禁用默认返回键，我们自己画
      // 2. 核心内容区域
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            // 左侧返回按钮
            SourceBackButton(onPressed: () => context.maybePop()),
            if (extent != null) const SizedBox(width: 6),

            // 中间的紧凑搜索入口，点击后在原位置展开完整输入框
            Expanded(
              child: BlocBuilder<SearchCubit, SearchStates>(
                builder: (context, state) => state.searchKeyword.trim().isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          sourceBrowseTitle(state),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : SearchQueryField(
                        query: state.searchKeyword,
                        hintText: t.search.searchHint,
                        semanticLabel: t.search.title,
                        onTap: () => _openSearchPage(context),
                      ),
              ),
            ),

            if (state.from.trim().isNotEmpty &&
                state.searchKeyword.trim().isNotEmpty &&
                !state.pluginExtern.containsKey('url') &&
                state.pluginExtern['mode'] != 'creator')
              SourceSearchScopeControl(
                compact: MediaQuery.sizeOf(context).width < 352,
                onChanged: (_) => context.read<SearchBloc>().add(
                  SearchEvent(searchStates: context.read<SearchCubit>().state),
                ),
              ),
            if (state.from.trim().isNotEmpty)
              FutureBuilder<PluginAdvancedSearchScheme?>(
                key: ValueKey(jsonEncode([state.from, state.pluginExtern])),
                future: _schemeFor(state),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    return SourceChromeIconButton(
                      tooltip: t.search.advancedSearchOptions,
                      icon: Icons.tune,
                      symbol: 'slider.horizontal.3',
                      onPressed: () => _search(context),
                    );
                  }
                  return snapshot.connectionState == ConnectionState.waiting
                      ? SizedBox(width: SearchToolbarScope.actionExtent)
                      : const SizedBox.shrink();
                },
              ),
            if (extent != null) const SizedBox(width: 4),
            SourceMoreButton(source: state.from),
          ],
        ),
      ),
    );
  }

  void _openSearchPage(BuildContext context) {
    final stack = context.router.stack;
    if (stack.length > 1 && stack[stack.length - 2].name == SearchRoute.name) {
      context.maybePop();
      return;
    }

    context.pushRoute(
      SearchRoute(
        key: ValueKey(const Uuid().v4()),
        searchState: context.read<SearchCubit>().state,
        aggregateMode: false,
      ),
    );
  }

  Future<void> _search(BuildContext context) async {
    if (_openingAdvancedSearch) return;
    _openingAdvancedSearch = true;
    try {
      await _openAdvancedSearch(context);
    } finally {
      _openingAdvancedSearch = false;
    }
  }

  Future<void> _openAdvancedSearch(BuildContext context) async {
    final searchCubit = context.read<SearchCubit>();
    final query = searchCubit.state;
    if (query.from.trim().isEmpty) {
      showWarningToast(t.search.advancedSearchNotSupported);
      return;
    }
    final source = normalizePluginId(query.from);
    final owner = pluginSessionWriteFence.generation(source);
    bool ownsQuery() =>
        searchCubit.state.from == query.from &&
        searchCubit.state.searchKeyword == query.searchKeyword &&
        jsonEncode(searchCubit.state.pluginExtern) ==
            jsonEncode(query.pluginExtern) &&
        pluginSessionWriteFence.generation(source) == owner;

    final PluginAdvancedSearchScheme? loaded;
    try {
      loaded = await _schemeFor(query);
    } on PluginLoginRequiredException catch (error) {
      if (context.mounted &&
          ModalRoute.of(context)?.isCurrent != false &&
          ownsQuery()) {
        eventBus.fire(
          NeedLogin(
            from: error.payload.pluginId,
            message: error.payload.message,
          ),
        );
      }
      return;
    }
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent == false ||
        !ownsQuery()) {
      return;
    }
    final scheme = loaded;
    if (scheme == null) {
      showWarningToast(t.search.advancedSearchNotSupported);
      return;
    }
    final current = searchCubit.state;
    _mergeExternValues(scheme.fields, current.pluginExtern, scheme.values);
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PluginAdvancedSearchDialog(
        initialSort: current.sortBy,
        scheme: scheme,
      ),
    );
    if (changes == null || !context.mounted || !ownsQuery()) return;

    final latest = searchCubit.state;
    final next = latest.copyWith(
      sortBy:
          int.tryParse(changes['sortBy']?.toString() ?? '') ?? latest.sortBy,
      pluginExtern: {...latest.pluginExtern, ...changes},
    );
    searchCubit.update(next);
    context.read<SearchBloc>().add(SearchEvent(searchStates: next));
  }

  Future<PluginAdvancedSearchScheme?> _loadAdvancedSearchScheme(
    String from,
    Map<String, dynamic> extern,
  ) async {
    try {
      final response = await callUnifiedComicPlugin(
        from: from,
        fnPath: 'getAdvancedSearchScheme',
        core: const <String, dynamic>{},
        extern: keywordSearchRequestExtern(from, extern),
        notifyUnauthorized: false,
      );
      final scheme = Map<String, dynamic>.from(
        (response['scheme'] as Map?) ?? const <String, dynamic>{},
      );
      final data = Map<String, dynamic>.from(
        (response['data'] as Map?) ?? const <String, dynamic>{},
      );
      final fields = uniqueAdvancedFields(
        from,
        ((scheme['fields'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );

      if (fields.isEmpty) {
        return null;
      }

      final values = Map<String, dynamic>.from(
        (data['values'] as Map?) ?? const <String, dynamic>{},
      );
      return PluginAdvancedSearchScheme(fields: fields, values: values);
    } on PluginLoginRequiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  void _mergeExternValues(
    List<Map<String, dynamic>> fields,
    Map<String, dynamic> extern,
    Map<String, dynamic> values,
  ) {
    for (final field in fields) {
      final key = field['key']?.toString() ?? '';
      if (key.isEmpty || !extern.containsKey(key)) {
        continue;
      }
      final externValue = extern[key];
      if (externValue is Map) {
        values[key] = externValue.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key.toString())
            .toList();
      } else {
        values[key] = externValue;
      }
    }
  }
}
