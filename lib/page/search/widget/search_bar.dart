import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/event/event.dart' show NeedLogin;
import 'dart:convert';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/widgets/toast.dart';

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.aggregateMode = true,
    this.compactSourceToolbar = false,
    this.optionsFollowingScope,
  });

  final bool aggregateMode;
  final bool compactSourceToolbar;
  final Widget? optionsFollowingScope;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  String? _schemeKey;
  Future<PluginAdvancedSearchScheme?>? _schemeFuture;

  Future<PluginAdvancedSearchScheme?> _schemeFor(SearchStates state) {
    final extern = widget.compactSourceToolbar
        ? const <String, dynamic>{}
        : state.pluginExtern;
    final key = jsonEncode([
      state.from,
      extern,
      pluginSessionWriteFence.generation(normalizePluginId(state.from)),
    ]);
    if (_schemeKey != key) {
      _schemeKey = key;
      _schemeFuture = _loadAdvancedSearchScheme(state.from, extern);
    }
    return _schemeFuture!;
  }

  bool _openingAdvancedSearch = false;

  void _submit(String keyword) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    onSearch(context, keyword, aggregateMode: widget.aggregateMode);
  }

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<SearchCubit>();
    return BlocBuilder<SearchCubit, SearchStates>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: CollectionToolbarMetrics.contentPaddingOf(
              context,
              top: 8,
              bottom: 8,
            ),
            child: SearchToolbarScope(
              extent: SearchToolbarScope.fieldExtent(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    key: const ValueKey('comic-search.input-row'),
                    spacing: CollectionToolbarMetrics.searchControlGap,
                    children: [
                      SourceChromeIconButton(
                        key: const ValueKey('comic-search.back'),
                        tooltip: t.common.back,
                        icon: Icons.arrow_back_ios_new_rounded,
                        symbol: 'chevron.left',
                        onPressed: () => context.maybePop(),
                      ),
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: searchCubit.queryRevision,
                          builder: (context, revision, _) => SearchQueryField(
                            query: searchCubit.state.searchKeyword,
                            queryRevision: revision,
                            autoExpand: true,
                            inline: true,
                            showSubmit: true,
                            dismissKeyboardOnTapOutside: true,
                            hintText: t.search.searchHint,
                            semanticLabel: t.search.title,
                            onSubmitted: _submit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.aggregateMode &&
                      (widget.compactSourceToolbar ||
                          widget.optionsFollowingScope != null ||
                          (state.from.trim().isNotEmpty &&
                              !isBikaExperienceSource(state.from)))) ...[
                    const SizedBox(height: 4),
                    Row(
                      key: const ValueKey('comic-search.options-row'),
                      spacing: CollectionToolbarMetrics.searchControlGap,
                      children: [
                        Expanded(
                          child:
                              widget.optionsFollowingScope ??
                              const SizedBox.shrink(),
                        ),
                        if (widget.compactSourceToolbar)
                          TextButton.icon(
                            key: const ValueKey('comic-search.date-filter'),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(t.comicList.filter),
                            style: TextButton.styleFrom(
                              minimumSize: Size.square(
                                CollectionToolbarMetrics.actionExtentOf(
                                  context,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () =>
                                _showSingleSourceAdvancedSearch(context),
                          )
                        else if (state.from.trim().isNotEmpty &&
                            !isBikaExperienceSource(state.from))
                          FutureBuilder<PluginAdvancedSearchScheme?>(
                            key: ValueKey(
                              jsonEncode([state.from, state.pluginExtern]),
                            ),
                            future: _schemeFor(state),
                            builder: (context, snapshot) =>
                                snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.data != null
                                ? SourceChromeIconButton(
                                    tooltip: t.search.advancedSearchOptions,
                                    icon: Icons.tune_rounded,
                                    symbol: 'slider.horizontal.3',
                                    bare: true,
                                    onPressed: () =>
                                        _showSingleSourceAdvancedSearch(
                                          context,
                                        ),
                                  )
                                : snapshot.connectionState ==
                                      ConnectionState.waiting
                                ? SizedBox(
                                    width:
                                        CollectionToolbarMetrics.actionExtentOf(
                                          context,
                                        ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSingleSourceAdvancedSearch(BuildContext context) async {
    if (_openingAdvancedSearch) return;
    final searchCubit = context.read<SearchCubit>();
    final state = searchCubit.state;
    final source = normalizePluginId(state.from);

    if (source.isEmpty) {
      showWarningToast(t.search.advancedSearchNotSupported);
      return;
    }
    final route = ModalRoute.of(context);
    final owner = pluginSessionWriteFence.generation(source);
    final revision = searchCubit.queryRevision.value;
    bool ownsQuery() =>
        mounted &&
        searchCubit.state.from == state.from &&
        searchCubit.state.searchKeyword == state.searchKeyword &&
        searchCubit.queryRevision.value == revision &&
        pluginSessionWriteFence.generation(source) == owner &&
        !pluginSessionWriteFence.isChanging(source);
    if (!ownsQuery()) return;
    _openingAdvancedSearch = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final scheme = await _schemeFor(state);
      if (!context.mounted || !ownsQuery() || route?.isCurrent == false) return;
      if (scheme == null) {
        _schemeKey = null;
        showWarningToast(t.search.advancedSearchNotSupported);
        return;
      }
      final current = searchCubit.state;
      final values = Map<String, dynamic>.of(scheme.values);
      _mergeExternValues(scheme.fields, current.pluginExtern, values);
      final changes = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => PluginAdvancedSearchDialog(
          initialSort: current.sortBy,
          scheme: PluginAdvancedSearchScheme(
            source: source,
            fields: scheme.fields,
            values: values,
          ),
        ),
      );
      if (changes == null || !ownsQuery() || route?.isCurrent == false) return;
      final latest = searchCubit.state;
      searchCubit.update(
        latest.copyWith(
          sortBy: int.tryParse('${changes['sortBy']}') ?? latest.sortBy,
          pluginExtern: {...latest.pluginExtern, ...changes},
        ),
      );
    } on PluginLoginRequiredException catch (error) {
      if (context.mounted &&
          ownsQuery() &&
          ModalRoute.of(context)?.isCurrent != false) {
        eventBus.fire(
          NeedLogin(
            from: error.payload.pluginId,
            message: error.payload.message,
          ),
        );
      }
    } finally {
      _openingAdvancedSearch = false;
    }
  }

  Future<PluginAdvancedSearchScheme?> _loadAdvancedSearchScheme(
    String source,
    Map<String, dynamic> extern,
  ) async {
    try {
      final response = await callUnifiedComicPlugin(
        pluginId: source,
        fnPath: 'getAdvancedSearchScheme',
        core: const <String, dynamic>{},
        extern: keywordSearchRequestExtern(source, extern),
        notifyUnauthorized: false,
      );
      final scheme = Map<String, dynamic>.from(
        (response['scheme'] as Map?) ?? const <String, dynamic>{},
      );
      final data = Map<String, dynamic>.from(
        (response['data'] as Map?) ?? const <String, dynamic>{},
      );
      final fields = uniqueAdvancedFields(
        source,
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
      _mergeExternValues(fields, extern, values);
      return PluginAdvancedSearchScheme(
        source: response['source']?.toString() ?? source,
        fields: fields,
        values: values,
      );
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
